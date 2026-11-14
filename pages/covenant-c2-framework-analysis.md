---
title: Covenant C2 框架深度解析：HTTP 出口协议与 SMB 命名管道网状通信机制
description: 系统解析 Covenant C2 框架的核心架构设计，重点剖析其基于 HTTP 的出口协议、基于 SMB 命名管道的 P2P 网状通信机制、.NET
  实现细节，以及在受限出站环境下的战术适用性。对比 Cobalt Strike 架构差异，结合外部 C2 规范与重定向器技术，形成完整的 C2 基础设施知识体系。
category: program-analysis
tags:
- Covenant
- C2 Framework
- Command and Control
- HTTP Egress
- SMB Named Pipe
- P2P Mesh
- .NET
- External C2
- Red Teaming
- Traffic Obfuscation
date: 2024-12-19
updated: '2026-11-14'
---
## 概述

Covenant 是一个基于 **.NET Core** 开发的跨平台命令与控制（C2）框架，由 [cobbr](https://github.com/cobbr) 开发并开源。其核心设计目标是提供一个现代化、模块化、支持协作操作的 C2 平台，并在通信协议层面针对 **受限出站环境** 做了深度优化。

与 Cobalt Strike 的 Java/TeamServer 架构不同，Covenant 采用 **ASP.NET Core** 构建服务端（Covenant Server），植入体（Grunt）基于 .NET 运行时，原生支持 Windows/Linux/macOS 跨平台部署。其最显著的协议层特征是：

- **出口协议**：默认使用 **HTTP/HTTPS** 作为植入体与 C2 服务器之间的命令下发与结果回传通道
- **网状协议**：利用 **SMB 命名管道** 在内网横向建立 P2P 网状通信拓扑，实现流量汇聚与出口复用

这种 **HTTP 出口 + SMB 命名管道网状** 的双通道设计，直接对标 Cobalt Strike 的 External C2 与 SMB Beacon 机制，但在 .NET 生态下实现了更原生的跨平台一致性。

---

## 核心架构对比：Covenant vs Cobalt Strike

| 维度 | Cobalt Strike | Covenant |
|------|---------------|----------|
| **服务端语言** | Java (TeamServer) | C# / ASP.NET Core |
| **植入体语言** | C (Beacon, Reflective DLL) | C# (.NET Assembly, Grunt) |
| **跨平台支持** | 仅 Windows Beacon 原生；Linux/macOS 需外部 C2 | 原生 Windows/Linux/macOS (Grunt) |
| **出口协议** | HTTP/S、DNS、External C2 (可扩展) | HTTP/S (默认)、可扩展 Listener Profile |
| **内网网状通信** | SMB Beacon (命名管道)、TCP Beacon | SMB 命名管道 (P2P Mesh) |
| **分阶段加载** | Stager + Stage (Shellcode/Reflective DLL) | Grunt 阶段化下载 (Assembly 加载) |
| **心跳机制** | 可配置 Sleep/Jitter，Cookie 承载加密元数据 | 可配置 Delay/Jitter，HTTP Header/Body 承载 |
| **重定向器支持** | Malleable C2 Profile + 外部重定向器 | Listener Profile + 标准 HTTP 重定向器兼容 |
| **协作模型** | 多客户端连单 TeamServer，多 TeamServer 分布式 | 多用户 Web UI 连单 Covenant Server，支持多 Listener |

> **交叉引用**：Cobalt Strike 的分布式团队服务器模型、External C2 规范、SMB Beacon 命名管道横向移动细节见 [[cobalt-strike-external-c2-smb-beacon]]；SMB 命名管道在 C2 通信中的通用原理与检测对抗见 [[smb-named-pipe-c2-communication]]、[[named-pipe-smb-detection-sysmon]]。

---

## HTTP 出口协议深度解析

### 通信模型

Covenant 的 Grunt 植入体与 Covenant Server 之间采用 **异步轮询** 模式：

```
[Grunt] --(HTTP GET/POST)--> [Covenant Server / Redirector] --(Task Queue)--> [Grunt]
      <--(Task Response)---       <--(Result Storage)---
```

- **心跳间隔**：可配置 `Delay` (基础睡眠) 与 `Jitter` (随机抖动)，默认 60s ± 20%
- **任务下发**：Server 将任务序列化为 JSON，经加密编码后置于 HTTP 响应体
- **结果回传**：Grunt 执行完成后，将结果加密编码置于后续请求的 Body 或 Header 中

### 流量特征与混淆

Covenant 提供 **Listener Profile** 机制（对标 Cobalt Strike 的 Malleable C2 Profile），支持对 HTTP 通信的以下特征进行定制：

| 特征 | 可定制项 |
|------|----------|
| **URI 路径** | 静态/动态路径、随机化、模仿合法 API 端点 |
| **HTTP 方法** | GET / POST / 自定义 |
| **Header 字段** | User-Agent、Cookie、自定义 Header 的键值模板 |
| **Body 编码** | Base64、Base64URL、Gzip+Base64、自定义编码器 |
| **加密层** | AES-256-GCM (默认)、可替换为 ChaCha20-Poly1305 等 |
| **Server 标识** | 模仿 Apache/IIS/nginx 等 Server Header |

> **交叉引用**：Malleable C2 Profile 的设计哲学、域名前置、CDN 隐匿、重定向器拓扑部署详见 [[c2-redirectors-malleable-c2-profiles]]。

### 代码层面实现要点 (Grunt 侧)

```csharp
// 简化版心跳循环伪代码
public async Task RunAsync() {
    while (!cancellationToken.IsCancellationRequested) {
        var request = BuildHttpRequest();           // 构造携带元数据的 HTTP 请求
        var response = await httpClient.SendAsync(request);
        var tasks = DecryptAndDeserialize(response); // 解密、反序列化任务队列
        foreach (var task in tasks) {
            var result = ExecuteTask(task);         // 执行命令/加载程序集
            QueueResult(result);                    // 入队待发送结果
        }
        await Task.Delay(GetNextSleepInterval());   // Delay + Jitter
    }
}
```

- **加密密钥协商**：首次上线时通过 RSA 密钥交换协商会话 AES 密钥，后续通信对称加密
- **会话标识**：通过 Cookie 或自定义 Header 传递 `SessionId`，Server 端维护会话状态机
- **抗重放/完整性**：AES-GCM 提供认证加密，防篡改与重放

---

## SMB 命名管道网状通信机制

### 设计动机

在企业内网中，**高价值目标（域控、数据库服务器、核心应用服务器）往往位于受限制的网段**，其出站 HTTP 流量被严格管控或完全禁止。Covenant 通过 SMB 命名管道在内网主机间建立 **P2P 网状拓扑**，仅需 **边界节点** 具备 HTTP 出口能力，即可实现对全网植入体的统一管控。

### 网状拓扑模型

```
[Covenant Server] <--HTTP--> [Grunt A (边界节点, 有出口)]
                                   |
                    +--------------+--------------+
                    |              |              |
              [SMB Pipe]     [SMB Pipe]     [SMB Pipe]
                    |              |              |
              [Grunt B]       [Grunt C]       [Grunt D]
              (内网主机)      (内网主机)      (内网主机)
```

- **Grunt A** 充当 **网关节点** ：既连接 HTTP 出口，又监听 SMB 命名管道
- **Grunt B/C/D** 无需直接访问互联网，仅通过 SMB 命名管道与 Grunt A 通信
- **任务下发路径**：Server → HTTP → Grunt A → SMB Pipe → Grunt B/C/D
- **结果回传路径**：Grunt B/C/D → SMB Pipe → Grunt A → HTTP → Server

### 命名管道通信协议细节

| 层面 | 实现细节 |
|------|----------|
| **管道名称** | 可配置，默认随机 GUID 格式 (如 `\\.\pipe\covenant-{GUID}`)，支持模仿合法管道名 (如 `\\.\pipe\lsarpc`, `\\.\pipe\spoolss`) |
| **通信模式** | 双向异步：`CreateNamedPipe` (Server 端) + `CreateFile` (Client 端) + `ReadFile`/`WriteFile` |
| **消息帧结构** | `[Length: 4 bytes][MessageType: 1 byte][Payload: N bytes][MAC: 16 bytes (AES-GCM Tag)]` |
| **加密** | 复用会话 AES-GCM 密钥，或派生独立管道会话密钥 |
| **多路复用** | 单管道支持多 Grunt 会话复用，通过 `SessionId` 字段区分 |
| **连接管理** | 心跳保活、断线自动重连、管道生命周期随 Grunt 进程 |

### P2P 网状拓扑的战术优势

| 优势 | 说明 |
|------|------|
| **出口最小化** | 仅边界节点产生 HTTP 流量，大幅降低网络边界检测面 |
| **流量融合** | SMB 命名管道流量混杂于合法 Windows 管理流量 (DCE/RPC、文件共享、打印服务) 中，难以基于协议特征单独封锁 |
| **天然横向移动通道** | 建立管道连接的过程本身即利用 `IPC$` 共享与有效凭据，实现 **C2 通信与横向移动融合** |
| **抗单点故障** | 支持多边界节点冗余，单节点失联不导致全网失控 |
| **权限继承** | 管道通信在发起进程的安全上下文中执行，天然继承域用户/系统权限，无需额外提权即可访问目标主机资源 |

> **交叉引用**：Cobalt Strike SMB Beacon 的 `link`/`unlink`、`jump psexec` 实战流程、管道命名伪装技巧、Sysmon Event ID 17/18 检测对抗见 [[cobalt-strike-external-c2-smb-beacon]]、[[named-pipe-smb-detection-sysmon]]。

---

## .NET 实现细节与工程化特性

### 运行时与部署模型

| 组件 | 技术栈 | 部署形态 |
|------|--------|----------|
| **Covenant Server** | ASP.NET Core 6+/7+、Entity Framework Core、SignalR | 单文件自包含部署 或 Docker 容器 |
| **Grunt (植入体)** | .NET 6+/7+ (可裁剪为 Native AOT) | 反射加载 Assembly (内存执行)、支持 Donut 转 Shellcode |
| **C2 通信库** | `System.Net.Http`、`System.IO.Pipes`、`System.Security.Cryptography` | 共享库，Server/Grunt 双端复用 |

### 核心模块架构

```
Covenant (Solution)
├── Covenant.Server          // ASP.NET Core Web API + Web UI (Blazor/Razor)
│   ├── Controllers          // Listener、Grunt、Task、ListenerProfile 管理
│   ├── Models               // 数据库实体、DTO、Crypto 实体
│   ├── Services             // GruntRegistry、TaskQueue、CryptoService、ProfileParser
│   └── Hubs                 // SignalR 实时推送 (Web UI 协作)
├── Covenant.Core            // 共享核心库
│   ├── Crypto               // AES-GCM、RSA、KeyExchange
│   ├── Protocol             // 消息序列化、帧编解码
│   ├── Pipes                // SMB Named Pipe 客户端/服务端封装
│   └── Tasks                // 任务基类、内置命令实现
├── Grunt                    // 植入体项目
│   ├── EntryPoint           // 启动、反射加载、心跳循环
│   ├── Communication        // HttpClient 封装、PipeClient 封装
│   └── Commands             // 内置命令 (shell, upload, download, execute-assembly 等)
└── Donut                    // 集成 Donut 生成位置无关 Shellcode
```

### 关键技术点

#### 反射加载与内存执行 (Execute-Assembly)
```csharp
// 简化版 Execute-Assembly 实现
public object ExecuteAssembly(byte[] assemblyBytes, string[] args) {
    var assembly = Assembly.Load(assemblyBytes);      // 纯内存加载，不落地
    var entryPoint = assembly.EntryPoint;
    var parameters = entryPoint.GetParameters().Length == 0 ? null : new object[] { args };
    return entryPoint.Invoke(null, parameters);       // 在当前 AppDomain 执行
}
```
- 无需 `Assembly.LoadFrom` 磁盘路径，规避文件监控
- 配合 **AMSI 绕过**、**ETW 绕过** 可进一步降低内存扫描风险

#### Native AOT 编译 (Grunt 瘦身)
```xml
<!-- Grunt.csproj 片段 -->
<PropertyGroup>
  <PublishAot>true</PublishAot>
  <StripSymbols>true</StripSymbols>
  <InvariantGlobalization>true</InvariantGlobalization>
</PropertyGroup>
```
- 产出 **无运行时依赖的原生二进制**，体积 ~2-3 MB
- 无托管堆元数据，极大增加静态分析与特征匹配难度

#### 任务队列与异步执行
- Server 端：`ConcurrentDictionary<Guid, ConcurrentQueue<Task>>` 按 SessionId 分发
- Grunt 端：单线程事件循环 + `Task.Run` 并行执行耗时命令，结果回调入队

---

## 受限出站环境下的适用场景与战术组合

### 典型受限场景

| 场景 | 网络限制 | Covenant 应对策略 |
|------|----------|-------------------|
| **DMZ/边界服务器** | 仅允许特定域名/端口出站 | Listener Profile 模仿合法 API 流量；域名前置 |
| **核心数据库/域控所在网段** | 完全禁止出站 HTTP | 部署边界 Grunt 作为网关，内网主机仅走 SMB 命名管道 |
| **OT/ICS 隔离网络** | 单向光闸/数据二极管 | 仅利用 SMB 命名管道单向回传，配合定时任务/计划任务触发 |
| **高强度流量检测环境** | TLS 指纹识别、JA3、HTTP 异常检测 | 证书伪造/真实证书、HTTP/2、Header 顺序模仿、流量填充 |

### 战术组合拳

```
初始访问 (Phishing/Exploit/Valid Accounts)
    ↓
Grunt 上线 (HTTP Listener) → 建立会话、密钥协商
    ↓
权限提升 / 凭据获取 (Mimikatz/SharpHound/Seatbelt via Execute-Assembly)
    ↓
横向移动 (SMB/IPC$/WMI/WinRM) → 目标主机部署 Grunt (SMB Listener)
    ↓
网状拓扑形成: 边界节点汇聚 SMB Pipe 流量 → 统一 HTTP 出口
    ↓
持久化 (Registry/Scheduled Task/Service/COM) + 防御规避 (AMSI/ETW/Patch)
    ↓
目标完成 (Data Staging → Exfiltration via HTTP/SMB/External C2)
```

### 与 External C2 规范的兼容性

Covenant 的 Listener Profile 机制设计上兼容 **Cobalt Strike External C2 规范** 的核心概念：
- 第三方可开发 **External C2 Controller** 对接 Covenant Server
- 支持自定义传输层 (DNS、WebSocket、gRPC、ICMP、Twitter API 等)
- 管道帧格式可映射为 External C2 的 `FRAME` 结构

> **交叉引用**：External C2 通信规范、第三方控制器开发模式、流量融合技巧见 [[cobalt-strike-external-c2-smb-beacon]]、[[c2-redirectors-malleable-c2-profiles]]。

---

## 检测与对抗视角

### 主机层面检测点

| 检测点 | 数据源 | 典型特征 | 对抗思路 |
|--------|--------|----------|----------|
| **进程创建** | Sysmon EID 1 | `dotnet.exe` / `Grunt.exe` 启动、命令行参数 | 重命名、签名伪造、父进程欺骗 (PPID Spoofing) |
| **模块加载** | Sysmon EID 7 | 加载 `System.Management.Automation.dll`、反射加载 Assembly | 模块隐藏、Native AOT 无托管模块 |
| **命名管道创建/连接** | Sysmon EID 17/18 | 管道名模式 `covenant-*`、高频创建/连接 | 模仿合法管道名、复用现有管道、低频心跳 |
| **网络连接** | Sysmon EID 3 / NetFlow | 非标准端口 HTTP、异常 JA3、长连接心跳 | 域名前置、CDN、TLS 指纹模仿、流量填充 |
| **文件系统** | Sysmon EID 11/23 | 临时目录写入 `.dll`/`.exe`、Donut Shellcode 落地 | 纯内存执行、内存模块、ADS 隐藏 |

### 网络层面检测点

| 检测维度 | 特征 | 对抗 |
|----------|------|------|
| **TLS 指纹 (JA3/JA3S)** | 默认 .NET `HttpClient` JA3 固定 | `HttpClientHandler.ServerCertificateCustomValidationCallback` + 自定义 `SslStream`、BoringSSL/Go TLS 指纹模仿 |
| **HTTP 语义** | Header 顺序、缺失标准 Header、Body 熵值高 | Profile 精细模仿目标 User-Agent/浏览器 Header 顺序、Gzip 压缩、Chunked 编码 |
| **流量统计** | 固定间隔心跳、请求/响应大小稳定 | Jitter 随机化、随机填充、动态调整 Sleep |
| **域名/证书** | 新注册域名、自签证书、证书不匹配 | 过期域名复用、Let's Encrypt 合法证书、域名前置 CDN |

> **交叉引用**：Sysmon Event ID 17/18 命名管道检测规则编写、网络流量基线建模、微软官方缓解措施见 [[named-pipe-smb-detection-sysmon]]。

---

## 总结

Covenant 以 **.NET 生态原生跨平台**、**HTTP 出口协议高度可定制**、**SMB 命名管道 P2P 网状通信** 三大核心特性，构建了一个在 **受限出站环境** 下极具竞争力的 C2 框架。其架构设计体现了现代红队基础设施的核心理念：

1. **协议层融合**：将 C2 通信融入合法业务流量 (HTTP API、SMB/RPC 管理流量)
2. **拓扑层最小化**：仅在网络边界暴露单一出口，内网横向通信复用现有信任关系
3. **运行时层隐蔽**：利用 .NET 反射加载、Native AOT、内存执行降低静态/动态特征
4. **工程化协作**：Web UI 多用户协作、Listener Profile 版本化、任务队列持久化

对于蓝队而言，重点防御应聚焦于 **命名管道异常创建/连接行为**、**HTTP 流量语义异常 (JA3、Header、熵值)**、**进程内存中非预期 .NET Assembly 加载** 等高置信度指标，而非单一 IOC 匹配。

---

## 相关知识页面索引

- [[c2-redirectors-malleable-c2-profiles]] — C2 重定向器拓扑、Malleable C2 Profile 配置、域名前置/CDN 隐匿
- [[cobalt-strike-external-c2-smb-beacon]] — Cobalt Strike External C2 规范、SMB Beacon 命名管道横向移动、link/unlink 实战
- [[smb-named-pipe-c2-communication]] — SMB 命名管道原理、C2 通信通道利用机制、通用检测手段
- [[named-pipe-smb-detection-sysmon]] — Sysmon Event ID 17/18 命名管道检测规则、网络流量基线、缓解措施
- [[dotnet-clr-usage-log-tampering-edr-evasion]] — .NET CLR 使用日志规避、AMSI/ETW 绕过、内存执行对抗
- [[pe-manual-mapping-loader-implementation]] — PE 手动映射、反射加载、模块隐藏技术对比（Grunt 内存执行底层原理）

---

*页面维护者：数字知识库策展人*  
*最后更新：2024-12-19*  
*数据来源：归档文章《攻防对抗中的C2架构解析》、Covenant 官方文档与源码、Cobalt Strike 官方文档、相关红队基础设施实战经验*

## 来源

- [0x00实验室-202108-202304_033](../sources/0x00实验室-202108-202304_033.md)
