---
title: 'Inceptor: AV/EDR 免杀框架工作流与核心技术栈深度解析'
description: 系统梳理 Inceptor 免杀框架的完整工作流：Shellcode/EXE/DLL 统一转换、Shikata-Ga-Nai 编码、AMSI/WLDP/ETW/沙箱绕过、Full
  Unhooking/Manual DLL Mapping/Direct Syscalls EDR 对抗、OLLVM/ConfuserEx 混淆与 CarbonCopy
  签名伪造，并对比作者私有框架 nucleus 的实现思路。
category: program-analysis
tags:
- Inceptor
- AV Evasion
- EDR Evasion
- Shellcode
- Donut
- pe2shc
- sRDI
- Shikata-Ga-Nai
- AMSI Bypass
- WLDP Bypass
- ETW Bypass
- Sandbox Evasion
- Full Unhooking
- Manual DLL Mapping
- Direct Syscalls
- OLLVM
- ConfuserEx
- CarbonCopy
- Red Teaming
- FreeKill
date: 2023-08-02
updated: '2026-11-15'
---

## 概述

**Inceptor** 是一个于 2023 年 8 月发布的开源免杀框架（GitHub: [klezVirus/inceptor](https://github.com/klezVirus/inceptor)），集成了主流的 AV/EDR 绕过方案，形成了一条从 Payload 处理、编码、加载器生成、编译、混淆到签名的完整工程化流水线。虽然此类框架通常很快会被安全产品标记，但其集成的技术栈构成了极佳的 **Red Teaming 技术学习清单**。

本页面系统拆解 Inceptor 的工作流各阶段，关联知识库中已有的底层实现细节页面，并补充作者私有框架 **nucleus**（Rust 实现、零依赖、约 5K 行）的对比思路，帮助读者构建「免杀对抗」的结构化知识体系。

---

## 核心工作流总览

Inceptor 的处理管线可概括为七阶段：

1. **Payload 统一转换** — Shellcode/EXE/DLL → 统一为 Shellcode  
2. **加载器无关编码** — Shikata-Ga-Nai 多态编码  
3. **加载器强相关编码** — 针对特定加载器的二次编码/加密  
4. **源码模版渲染** — 内置 AV/EDR Bypass 技术的 C#/C 模版  
5. **编译链接** — .NET 用 `csc`，Native 用 `clang`  
6. **混淆** — .NET: ConfuserEx / AsStrongAsFuck / LoGIC.NET；Native: OLLVM  
7. **签名伪造** — CarbonCopy 复制合法签名  

下文逐阶段展开，并给出交叉引用。

---

## Payload 统一转换：Shellcode / EXE / DLL → Shellcode

| 输入类型 | 转换手段 | 关键工具/库 | 备注 |
|----------|----------|-------------|------|
| **Shellcode** | 直透 | — | 无需转换 |
| **EXE (Native)** | PE → Shellcode | **PE2SH** / **Donut** | PE2SH 将 PE 重定向为位置无关 Shellcode；Donut 支持 .NET Assembly 与 Native PE 统一转换 |
| **EXE (.NET)** | .NET Assembly → Shellcode | **Donut** | 利用 CLR Hosting 在进程内加载托管代码 |
| **DLL** | Reflective Loading → Shellcode | **sRDI** (Shellcode Reflective DLL Injection) | 将 DLL 转换为可自举的 Shellcode，支持导出函数调用 |

> **关联页面**：  
> - [[aceldr-technical-analysis]] — 系统梳理 **Donut、pe2shc、sRDI、RDI** 等反射式加载器原理与 PE 不落地执行技术谱系  
> - [[pe-manual-mapping-loader-implementation]] — 手动映射加载器完整实现：导入表修复、重定位、延迟导入、API Set Schema、MEM_IMAGE 伪装  

---

## 加载器无关编码：Shikata-Ga-Nai

- **来源**：Metasploit Framework 默认集成、效果最佳的多态编码器  
- **原理**：基于 **FPU 指令集** 的解码存根 + 异或/加法/减法/循环等可变指令序列，每次生成指令流不同，实现静态特征消除  
- **定位**：Inceptor 将其作为 **第一层编码**，与后续加载器强相关编码叠加，形成「双层编码」链  

> **延伸**：Shikata-Ga-Nai 仍属「已知编码器」，单独使用极易被 YARA/启发式捕获；实战中常配合 **自定义编码器** 或 **运行时解密存根** 进一步降低熵值。

---

## 加载器强相关编码

文章未展开细节，工程实践中常见手段包括：

- **AES/RC4/XOR + 密钥派生**（基于环境指纹：进程名、域名、时间戳等）  
- **分段加密 + 运行时按需解密**（降低内存常驻明文窗口）  
- **调用约定/栈帧混淆**（配合 Direct Syscalls 使用）  

> 可参考 [[rust-proc-macro-win32-dynamic-import]] 中「符号哈希 + 栈上 UTF-16 字符串 + 动态解析」的思路迁移到 C/C++ 加载器。

---

## 源码模版与 AV Evasion 技术集成

模版内预置四大主流 AV 行为绕过：

| 技术 | 绕过目标 | 典型实现要点 |
|------|----------|--------------|
| **AMSI Bypass** | `amsi.dll` 扫描回调 | 修补 `AmsiScanBuffer`/`AmsiScanString` 首字节为 `RET` / `xor eax,eax; ret`；或篡改 `CLR` 内部 `g_amsiContext` |
| **WLDP Bypass** | Windows Lockdown Policy (AppLocker/WDAC) | 修补 `WldpQueryDynamicCodeTrust` / `WldpIsClassInApprovedList` 返回 `S_OK` |
| **ETW Bypass** | Event Tracing for Windows 威胁感知 | 修补 `EtwEventWrite` / `NtTraceEvent`；或设置 `ETW_PROVIDER_TRAIT` 禁用提供程序 |
| **Sandbox Deception** | 行为沙箱/动态分析 | 进程/线程/模块枚举反制、时间加速检测、CPUID/虚拟化指纹检测、鼠标/键盘交互检测、睡眠加速（`NtDelayExecution` Hook） |

> **关联页面**：  
> - [[dotnet-clr-usage-log-tampering-edr-evasion]] — .NET CLR 使用日志四大规避手法（配置旋钮、环境变量、强制终止、模块卸载）  
> - [[memory-scanning-tools-evasion-techniques]] — Hunt-Sleeping-Beacons / BeaconHunter / MalMemDetect 等内存扫描工具原理与 UDRL（FOLIAGE/Ekko/AceLdr）对抗细节  
> - [[argument-spoofing-edr-evasion]] — 进程创建监控对抗：命令行欺骗、PEB `RTL_USER_PROCESS_PARAMETERS` 篡改  

---

## EDR Evasion：内核/用户态对抗三板斧

| 技术 | 核心思想 | 关键实现点 | 局限性 |
|------|----------|------------|--------|
| **Full Unhooking** | 恢复用户态 `ntdll.dll`/`kernel32.dll` `.text` 段原始字节 | ① 从磁盘读取干净 DLL → ② 手动映射至私有内存 → ③ 拷贝 `.text` 段覆盖当前进程同名模块 → ④ 修复重定位/IAT | 若 EDR 在 **Ring0 (内核回调/过滤驱动)** 挂钩，用户态卸钩无效 |
| **Manual DLL Mapping** | 完全用户态实现 PE Loader，避免 `LoadLibrary` 触发回调 | 手动解析 PE、节区映射、导入表修复（含 API Set Schema）、重定位、TLS 回调、延迟加载、入口点调用 | 需自行处理异常、SEH、安全 Cookie、Control Flow Guard (CFG) 等 |
| **Direct Syscalls** | 绕过用户态 `ntdll` 导出表，直接 `syscall`/`sysenter` 进入内核 | ① 静态/动态获取 SSN (System Service Number) → ② 内联汇编发起系统调用 → ③ 栈帧对齐、参数拷贝、返回值处理 | **x86 无意义**（内核已在 Ring0 Hook）；x64 需应对 **SSN 随机化/变动**、**间接系统调用 (Indirect Syscall)**、以及 **内核回调/过滤驱动** 的深度检测 |

> **作者 nucleus 框架对比**：  
> - 自实现 `kernel32!GetProcAddress` + PE Loader → 递归加载纯净 DLL → IAT 指向自维护模块  
> - 遭遇 **API Set Schema** 导致系统 DLL 加载失败，改为 **以内存中现有 DLL 为重定位基准，拷贝 `.text` 段刷新** 实现通用非侵入式 Unhooking  
> - **无 AMSI/WLDP/ETW/.NET Loader** 模块（侧重 Native Binary）  
> - **无 OLLVM**（Rust toolchain 与 LLVM 版本冲突）  
> - **额外集成**：Microsoft Signature Restricted、ACG (Arbitrary Code Guard)、Image Path Spoofing  

> **关联页面**：  
> - [[pe-manual-mapping-loader-implementation]] — 手动映射全流程 C++ 实现（延迟导入、API Set Schema、MEM_IMAGE、内存属性伪装）  
> - [[windows-syscall-internals-sysenter-kifastcallentry]] — `sysenter`/`KiFastCallEntry`/`SSDT` 全链路剖析，辅助 Direct Syscall SSN 获取  
> - [[ppl-injection-createprocess-bof-fix]] — PPL 进程注入中 `CreateProcess` `bInheritHandles=FALSE` 绕过与 BOF 落地输出技巧  
> - [[windows-token-nerfing-pplguard-trusted-labels]] — Token Nerfing 攻击与 PPLGuard (Trusted Labels/SACL) 缓解，关联 WinTcb-Light 级进程注入规避内存扫描  
> - [[cobalt-strike-4.7-bof-internals]] — BOF 加载器内部实现、Relocation 缺陷、Sleep Kit BOF 化、PPL 进程注入案例  

---

## 编译工具链

| 目标类型 | 编译器 | 典型参数/特性 |
|----------|--------|---------------|
| **.NET (C#)** | `csc.exe` (Roslyn) | `/optimize+ /platform:x64 /debug- /unsafe+`；配合 **ConfuserEx / AsStrongAsFuck / LoGIC.NET** 混淆 |
| **Native (C/C++)** | `clang` (LLVM) | `-O2 -fno-ident -fvisibility=hidden -nostdlib` (可选)；配合 **OLLVM** 控制流平坦化/指令替换/虚假控制流 |

> **关联页面**：  
> - [[binary-ninja-ollvm-deobfuscation]] — OLLVM 控制流平坦化原理与 Binary Ninja IL 层去平坦化插件开发  
> - [[rust-proc-macro-win32-dynamic-import]] — Rust 宏实现 Win32 动态导入、符号哈希、栈上字符串，适配 Shellcode/免杀武器化开发  

---

## 混淆与签名伪造

### 混淆层

| 平台 | 工具 | 核心混淆手段 |
|------|------|--------------|
| **.NET** | **ConfuserEx** | 符号重命名、常量加密、控制流混淆、反调试/反转储、资源加密 |
|  | **AsStrongAsFuck** | 基于 dnlib 的深度混淆：方法内联、字符串加密、控制流扁平化、虚拟化保护 |
|  | **LoGIC.NET** | 逻辑混淆：不透明谓词、死代码插入、算术/布尔表达式复杂化 |
| **Native** | **OLLVM** (Obfuscator-LLVM) | **控制流平坦化 (CFF)**、**指令替换 (SUB)**、**虚假控制流 (BCF)**、**函数内联/轮廓化** |

### 签名伪造：CarbonCopy

- **项目**：[paranoidninja/CarbonCopy](https://github.com/paranoidninja/CarbonCopy)  
- **原理**：解析合法签名文件的 **Authenticode 签名块 (WIN_CERTIFICATE)**，提取 **签名者证书链、时间戳、哈希算法** 等元数据，重新计算目标 PE 的哈希并 **追加/替换** 签名块，使目标文件看起来拥有合法厂商签名  
- **局限**：  
  1. **证书吊销检查 (CRL/OCSP)** 会失效  
  2. **Windows 10+ 内核模式代码签名 (KMCI) / HVCI** 会验证签名链信任根，伪造签名无法通过内核加载校验  
  3. **SmartScreen/Defender 云引擎** 仍可基于文件信誉、行为、证书指纹拦截  

> **实战建议**：签名伪造仅作为 **静态特征降噪** 手段，需配合 **内存执行/模块隐藏/调用链断裂** 等运行时对抗。

---

## 与同类技术页面的交叉引用速查表

| 领域 | 知识库页面 | 关联点 |
|------|------------|--------|
| **PE 不落地执行 / 反射加载** | [[aceldr-technical-analysis]] | Donut / pe2shc / sRDI / RDI 原理与检测对抗 |
| **手动映射 / PE Loader 深度实现** | [[pe-manual-mapping-loader-implementation]] | 导入表修复、重定位、延迟导入、API Set Schema、MEM_IMAGE |
| **进程镂空/篡改技术谱系** | [[process-injection-tampering-techniques]] | Hollowing / Doppelganging / Ghosting / Herpaderping / Transacted Hollowing 与 Sysmon Event ID 25 |
| **内存扫描对抗 / UDRL** | [[memory-scanning-tools-evasion-techniques]] | Hunt-Sleeping-Beacons / BeaconHunter / FOLIAGE / Ekko / AceLdr |
| **Direct Syscall / 系统调用内核流程** | [[windows-syscall-internals-sysenter-kifastcallentry]] | `sysenter` / `KiFastCallEntry` / SSDT / `_KUSER_SHARED_DATA` |
| **PPL 进程注入与 Token 对抗** | [[ppl-injection-createprocess-bof-fix]]、[[windows-token-nerfing-pplguard-trusted-labels]] | `bInheritHandles`、Token Nerfing、PPLGuard (Trusted Labels/SACL) |
| **C2 基础设施与流量混淆** | [[c2-redirectors-malleable-c2-profiles]]、[[cobalt-strike-external-c2-smb-beacon]]、[[smb-named-pipe-c2-communication]] | Redirector / Malleable C2 / SMB Beacon / External C2 / 命名管道检测 |
| **OLLVM 混淆与逆向去混淆** | [[binary-ninja-ollvm-deobfuscation]] | 控制流平坦化原理、Binary Ninja IL 分析、插件开发 |
| **Rust 红队武器化原语** | [[rust-proc-macro-win32-dynamic-import]] | 过程宏动态导入、符号哈希、栈上 UTF-16 字符串、Shellcode 友好 |
| **.NET CLR 运行时日志篡改** | [[dotnet-clr-usage-log-tampering-edr-evasion]] | NGenAssemblyUsageLog、COMPlus 环境变量、FreeLibrary、ETW 绕过 |

---

## 结语与实战建议

1. **框架即「技术清单」，而非「银弹」** — Inceptor 集成的每项技术单独拎出来都有成熟的检测规则；实战免杀的核心在于 **组合拳的定制化、运行时环境感知、以及持续的红蓝对抗迭代**。  
2. **工程化能力 > 单点技巧** — 手写 PE Loader、自实现 GetProcAddress、动态 SSN 获取、编译器插件化混淆、签名块手工重组，这些 **工程落地细节** 决定了免杀存活周期。  
3. **关注「检测侧」视角** — 阅读 [[memory-scanning-tools-evasion-techniques]]、[[named-pipe-smb-detection-sysmon]]、[[windows-token-nerfing-pplguard-trusted-labels]] 等蓝队视角页面，理解 EDR 如何从 **内存完整性、调用链、令牌完整性、网络流量基线** 多维建模，才能做到「知己知彼」。  
4. **合规前提** — 所有技术仅限 **授权红队演练、安全研究、防御能力建设** 场景使用，严禁用于未授权渗透或恶意代码投递。

---

## 参考资料

1. Inceptor 项目地址：https://github.com/klezVirus/inceptor  
2. CarbonCopy 项目地址：https://github.com/paranoidninja/CarbonCopy  
3. 原文微信文章：《inceptor——一个不错的免杀框架》（2023-08-02）  
4. 知识库关联页面（见上文交叉引用）

## 来源

- [0x4d5a-202103-202209_13](../sources/0x4d5a-202103-202209_13.md)
