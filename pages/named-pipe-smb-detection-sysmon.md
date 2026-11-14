---
title: 基于 Sysmon Event ID 17/18 与网络流量基线的恶意命名管道与异常 SMB 会话检测体系
description: 系统梳理 SMB 协议与命名管道原理、Cobalt Strike SMB Beacon 与 External C2 通信模型、主机层面基于
  Sysmon Event ID 17/18 的命名管道创建/连接检测策略、网络层面基于流量基线的异常 SMB 会话识别方法，以及微软官方推荐的防火墙阻断、审核与清单管理等缓解措施。
category: program-analysis
tags:
- SMB
- Named Pipe
- Sysmon
- Event ID 17
- Event ID 18
- Cobalt Strike
- SMB Beacon
- External C2
- Lateral Movement
- Defense Evasion
- Network Traffic Baseline
- Threat Detection
- Red Teaming
- Blue Teaming
date: 2023-04-16
updated: '2026-11-14'
---

## 概述

本页面基于微信公众号文章《域渗透 | SMB的原理与外部C2的应用》整理，系统构建 **恶意命名管道与异常 SMB 会话的多层检测体系**。核心检测面包含：

- **主机层**：利用 Sysmon Event ID 17（管道创建）与 Event ID 18（管道连接）结合进程基线、管道命名模式基线、安全描述符异常分析
- **网络层**：通过内部网络流量基线识别异常的主机到主机 SMB 连接、远程命名管道访问模式
- **缓解层**：防火墙阻断入站/出站 445 端口、启用 SMB 审核、清点共享、禁用未用 SMB 服务

> 相关红队视角技术实现详见：[[cobalt-strike-external-c2-smb-beacon]]、[[smb-named-pipe-c2-communication]]

---

## SMB 协议与命名管道基础

### SMB 协议定位

- **协议层级**：OSI 应用层/表示层，常通过 TCP/IP (NBT) 传输，现代版本可直接跑 TCP 445
- **安全模型**：用户级（用户名/密码、NTLM/LM 质询-响应）与共享级（共享密码）
- **防火墙默认行为**：Windows Defender 防火墙默认**允许** SMB 入站/出站，使其成为绕过网络边界限制的天然通道

### 命名管道机制

| 维度 | 说明 |
|------|------|
| 本质 | 基于 SMB 的进程间通信 (IPC) 机制，支持本地与跨网络通信 |
| 服务端 API | `CreateNamedPipe`、`ConnectNamedPipe` |
| 客户端 API | `CreateFile`、`CallNamedPipe` |
| 默认安全描述符 | LocalSystem/Administrators/Creator Owner：完全控制；Everyone/Anonymous：读取访问 |

> 命名管道因其“合法系统功能、防火墙默认放行、跨主机通信”三大特性，成为 C2 横向通道与权限提升（如 MSF `getsystem` 利用模拟客户端）的高频利用面。

---

## Cobalt Strike SMB Beacon 与 External C2 通信模型

### SMB Beacon 通信流程

1. **前提条件**：已控制一台主机（父 Beacon），目标主机开放 445 端口且拥有 Administrator 凭据
2. **建立会话**：
   ```bash
   # 1. 凭据填充
   shell net use \\TARGET_IP\admin$ /user:"administrator" "password"
   # 2. 横向生成 SMB Beacon
   jump psexec64 TARGET_IP smb
   ```
3. **会话管理**：
   - `unlink [ip] [pid]`：断开指定子 Beacon，进入等待重连状态
   - `link [host] [pipename]`：从任意 Beacon 重连现有 SMB Beacon
4. **通信封装**：命名管道流量封装于 SMB 协议，点对点通信，难以在网络层区分正常文件共享流量

### External C2 扩展性

- **规范允许**：自定义协议、融合合法服务流量（Office 365、Google Drive、Dropbox、Slack、OneDrive 等）
- **内网融合**：文件共享、AD 读写等合法业务通道传输 C2 数据
- **权衡**：External C2 隐蔽性强但实现难度大；可扩展 C2（Malleable Profile）配置简单但特征明显

---

## 主机层检测体系（基于 Sysmon）

### 数据源配置

需在 Sysmon 配置中启用：
- **Event ID 17**：Pipe Created（命名管道创建）
- **Event ID 18**：Pipe Connected（命名管道连接）

```xml
<!-- Sysmon 配置片段 -->
<PipeEvent>on</PipeEvent>  <!-- 同时捕获 17 与 18 -->
```

### 检测维度 1：已知恶意管道名称特征匹配

| C2 框架 | 默认管道名称 | 可变性 |
|---------|-------------|--------|
| Cobalt Strike | `msagent` | 可在 Malleable Profile 中修改 |
| Covenant | `gruntsvc` | 可配置修改 |
| Metasploit | `meterpreter_*` | 可变 |

**检测逻辑**：对 `PipeName` 字段做精确/正则匹配，纳入 Sigma/ES 规则库。

### 检测维度 2：进程-管道关联基线异常

**基线建立方法**：
1. 持续收集 `Event ID 17` 中的 `Image`（创建进程）与 `PipeName` 映射关系
2. 对高频进程（如 `chrome.exe`、`sqlservr.exe`、`lsass.exe`）建立管道命名模式画像

**异常示例**：
- 正常：`chrome.exe` 创建管道匹配 `mojo.\d+.\d+.\d+`
- 异常：`chrome.exe` 创建管道 `pipe123`、`msagent`、`randomstring`

**实施建议**：
- 结合 MITRE ATT&CK T1570 (Lateral Tool Transfer) / T1021.002 (SMB/Windows Admin Shares)
- 与进程命令行、父进程、网络连接等上下文关联降低误报

### 检测维度 3：异常安全描述符

- **特征**：Covenant 默认赋予 `Everyone` 组 `FullControl` 权限
- **检测手段**：需配合工具（如 James Forshaw NtObjectManager）解析管道 SDDL，或部署内核回调监控 `SeSecurityDescriptor` 变更
- **定位**：作为**辅助指标**提升其他指标严重级，单独使用误报率高

### 检测维度 4：远程管道连接识别

**Event ID 18 关键字段**：
- `Image` = `System` → 表示远程连接（本地连接通常显示具体进程路径）
- `SourceAddress` / `SourcePort`：Sysmon 14+ 版本开始补充网络源信息

**关联分析**：
- 结合 Windows Security Event 4624 (Logon Type 3) 确认远程认证来源
- 关联防火墙日志确认 445 端口入站连接

---

## 网络层检测体系（基于流量基线）

### 数据采集点位

| 采集位置 | 优势 | 劣势 |
|----------|------|------|
| 核心交换机镜像/NetFlow | 全量覆盖、不可篡改 | 明文 SMB 可见，SMB 3.x 加密后载荷不可见 |
| 关键服务器主机抓包 | 可解密会话密钥（若掌握密钥） | 部署成本高、易被攻击者干扰 |
| Zeek/Suricata 内网传感器 | 协议解析丰富、支持脚本扩展 | 需维护规则库 |

### 检测维度 1：远程命名管道访问基线

**Zeek 脚本示例逻辑**：
```zeek
event smb_pipe_open(c: connection, pipe_name: string, ...) {
    if (pipe_name in known_malicious_pipes) {
        NOTICE([$note=Malicious_Pipe, $msg=fmt("Known malicious pipe: %s", pipe_name)]);
    }
    # 记录主机-管道访问矩阵，离线建模基线
}
```

**基线指标**：
- 主机对访问的管道集合稳定性
- 管道名称熵值分布（合法管道如 `mojo.xxx`、`spoolss`、`lsarpc` 等有固定前缀）

### 检测维度 2：异常主机到主机 SMB 流量

**基线建立**：
1. 统计内网各子网/主机对之间的 SMB 会话频次、数据量、持续时间
2. 识别“高价值服务器 → 用户工作站”反向连接、“工作站 ↔ 工作站”非业务连接

**异常场景**：
- 文件服务器突然向大量工作站发起 SMB 会话（横向移动）
- 非管理员工作站访问 DC `admin$`/`IPC$` 共享
- 非业务时间段的 SMB 爆发流量

**关联主机日志**：
- 将网络异常与主机 Event ID 17/18、4624、5140 (Share Access) 关联，构建攻击链完整视图

---

## 缓解与加固措施

### 网络边界控制

| 措施 | 实施要点 |
|------|----------|
| 阻断入站 TCP 445 | 企业边界防火墙拦截 Internet → 内网 445 |
| 阻断出站 TCP 445 | 防止内网主机向 Internet 发起 SMB（数据外泄、凭据中继） |
| Azure Files / O365 例外 | 仅放行微软官方 IP 范围，强制 SMB 3.x + AES-128 加密 |
| QUIC 上的 SMB | 使用 UDP 443 + TLS 1.3 替代传统 445，提供类 VPN 隧道 |

### 主机防火墙策略

启用 Windows Defender 防火墙**入站规则**阻断：
- `File and Printer Sharing (SMB-In)`：所有配置文件
- `File and Printer Sharing (SMB-In)` for Domain/Private/Public

> 默认这些规则为**未启用**状态，需通过 GPO/Intune 统一下发启用。

### 审核与清单

1. **启用 SMB 访问审核**：
   - GPO：`Security Settings → Advanced Audit Policy → Object Access → Audit File Share`（Success/Failure）
   - 事件 ID：5140 (Share Accessed)、5145 (Detailed Share Access)
2. **共享清单脚本**：定期执行 `Get-SmbShare`、`net share` 导出基线对比
3. **禁用未用 SMB 服务**：
   - `Set-SmbServerConfiguration -EnableSMB1Protocol $false`
   - `Set-Service -Name LanmanServer -StartupType Disabled`（非文件服务器）

---

## 检测规则示例（Sigma 规则片段）

### 规则 1：已知恶意命名管道创建

```yaml
title: Suspicious Named Pipe Creation - Known Malicious Pipe Names
id: 0a1b2c3d-4e5f-6g7h-8i9j-0k1l2m3n4o5p
status: stable
description: Detects creation of named pipes used by common C2 frameworks (Cobalt Strike, Covenant, Metasploit)
author: Knowledge Base Curator
date: 2023/04/16
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 17
    PipeName|contains:
      - 'msagent'
      - 'gruntsvc'
      - 'meterpreter_'
      - 'postex_'
  condition: selection
falsepositives:
  - Legitimate administrative tools using similar pipe names (rare)
level: high
tags:
  - attack.t1570
  - attack.t1021.002
  - car.2019-04-001
```

### 规则 2：浏览器进程创建非标准命名管道

```yaml
title: Browser Process Creating Anomalous Named Pipe
id: 1b2c3d4e-5f6g-7h8i-9j0k-1l2m3n4o5p6q
status: experimental
description: Chrome/Firefox/Edge creating named pipes not matching known mojo/* pattern
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 17
    Image|endswith:
      - '\chrome.exe'
      - '\firefox.exe'
      - '\msedge.exe'
  filter_main_mojo:
    PipeName|re: 'mojo\.\d+\.\d+\.\d+'
  condition: selection and not filter_main_mojo
falsepositives:
  - Browser extensions or automated testing frameworks
level: medium
tags:
  - attack.t1055
  - attack.t1570
```

### 规则 3：远程命名管道连接 (Sysmon Event ID 18)

```yaml
title: Remote Named Pipe Connection via SMB
id: 2c3d4e5f-6g7h-8i9j-0k1l-2m3n4o5p6q7r
status: stable
description: Detects remote connections to named pipes (Image=System) indicating lateral movement
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 18
    Image: 'System'
  filter_legit_pipes:
    PipeName|startswith:
      - '\\\\.\\pipe\\lsarpc'
      - '\\\\.\\pipe\\samr'
      - '\\\\.\\pipe\\spoolss'
      - '\\\\.\\pipe\\eventlog'
  condition: selection and not filter_legit_pipes
falsepositives:
  - Legitimate remote administration (PSExec, SCCM, backup agents)
level: medium
tags:
  - attack.t1021.002
  - attack.t1570
```

---

## 交叉引用与延伸阅读

- **红队实战视角**：[[cobalt-strike-external-c2-smb-beacon]]（External C2 规范、SMB Beacon 横向流程、link/unlink 会话管理、流量融合技巧）
- **协议原理与检测对抗**：[[smb-named-pipe-c2-communication]]（SMB/命名管道原理、C2 通道利用、主机/网络层检测手段、缓解措施）
- **内存隐藏与规避**：[[phantom-dll-hollowing-technique]]（模块踩踏/空洞化技术、绕过内存扫描、EDR 对抗）
- **EDR 规避案例**：[[dotnet-clr-usage-log-tampering-edr-evasion]]（.NET CLR 使用日志篡改、四大规避手法、防御检测思路）

---

## 附录：关键事件字段速查

### Sysmon Event ID 17 (Pipe Created)

| 字段 | 说明 | 检测价值 |
|------|------|----------|
| `PipeName` | 管道全名（如 `\\.\pipe\msagent`） | 特征匹配、基线建模 |
| `Image` | 创建管道的进程完整路径 | 进程-管道关联基线 |
| `ProcessId` | 创建进程 PID | 关联进程树、命令行 |
| `UtcTime` | 事件时间 | 时间序列分析 |

### Sysmon Event ID 18 (Pipe Connected)

| 字段 | 说明 | 检测价值 |
|------|------|----------|
| `PipeName` | 被连接的管道名 | 远程访问目标识别 |
| `Image` | 连接方进程（远程连接显示 `System`） | 区分本地/远程连接 |
| `SourceAddress` | 来源 IP (Sysmon 14+) | 直接定位攻击主机 |
| `SourcePort` | 来源端口 | 关联防火墙/NetFlow 日志 |

### Windows Security Event 关联

| Event ID | 名称 | 关联场景 |
|----------|------|----------|
| 4624 | Logon (Type 3 = Network) | SMB 会话认证来源 |
| 5140 | Network Share Accessed | 共享访问审核（含 `admin$`、`IPC$`） |
| 5145 | Detailed File Share Access | 文件级访问审核（需开启 Detailed Audit） |

---

## 更新记录

| 日期 | 版本 | 变更摘要 |
|------|------|----------|
| 2023-04-16 | 1.0 | 初始版本：整合 SMB/命名管道原理、Cobalt Strike SMB Beacon、Sysmon 17/18 检测体系、网络流量基线、缓解措施、Sigma 规则示例 |

## 来源

- [0x00实验室-202108-202304_032](../sources/0x00实验室-202108-202304_032.md)
