---
title: Phantom DLL Hollowing 技术原理与恶意内存隐藏分析
description: 深度解析 Phantom DLL Hollowing（幽灵 DLL 空洞化）技术，该技术通过劫持已加载合法 DLL 的内存区段实现恶意代码注入与持久化，利用模块加载伪装绕过内存扫描与
  EDR 检测，属于无文件攻击与内存隐藏的高级利用手法。
category: program-analysis
tags:
- Malware Analysis
- Memory Injection
- DLL Hollowing
- Module Stomping
- Defense Evasion
- Windows Internals
- Red Teaming
date: 2019-12-19
updated: '2026-11-13'
---
## 概述

**Phantom DLL Hollowing**（幽灵 DLL 空洞化）是一种高级的恶意代码注入与内存隐藏技术，由安全研究员 Forrest Orr 在其系列文章 *"Malicious Memory Artifacts: Part I - DLL Hollowing"* 中系统阐述。该技术的核心思想是：**不创建新的内存区域、不加载新的模块文件，而是定位进程地址空间中已存在的、合法的 DLL 模块，将其代码区段（通常是 `.text` 节）卸载或覆写为恶意载荷，同时保留该模块在 PEB（Process Environment Block）模块链表中的原始元数据（路径、基址、大小等）。**

这种“原地替换”策略使得恶意代码在内存中呈现为合法签名 DLL 的一部分，有效绕过基于模块列举、磁盘文件对比、内存权限异常（RWX）等传统检测手段，是典型的 **Living-off-the-Land** 与 **Fileless Malware** 技术演进形式。

## 核心原理

### 攻击面：PEB 模块链表与内存映射不一致
Windows 进程加载 DLL 时，`ntdll!LdrLoadDll` 会在 PEB 的 `Ldr->InMemoryOrderModuleList` / `InLoadOrderModuleList` / `InInitializationOrderModuleList` 中插入 `LDR_DATA_TABLE_ENTRY` 结构，记录模块基址、完整路径、入口点等信息。同时，内存管理器将 DLL 文件映射为镜像区段（Section Object），建立虚拟地址到物理页/磁盘文件的映射关系。

**Phantom DLL Hollowing 利用的核心矛盾**：
- **静态视图（磁盘/模块列表）**：显示为合法系统 DLL（如 `ntdll.dll`、`kernel32.dll`、`combase.dll` 等）。
- **动态视图（进程虚拟内存内容）**：该地址范围内实际存放的是攻击者注入的 Shellcode 或 PE 镜像。

### 关键步骤流程

#### 步骤一：目标模块枚举与筛选
攻击者遍历 PEB 模块链表，寻找满足条件的候选 DLL：
- **已加载且常驻内存**：避免延迟加载导致的竞争条件。
- **代码区段足够大**：`.text` 节尺寸需容纳恶意载荷（或分段存放）。
- **低可疑度**：优选系统核心 DLL 或高频加载的第三方库，减少因模块异常触发告警的概率。
- **非关键系统调用依赖**：避免破坏进程正常运行所必需的核心功能入口（如 `ntdll.dll` 的关键导出函数被覆写可能导致进程崩溃）。

#### 步骤二：内存保护修改与区段卸载/覆写
由于 DLL 代码区段默认权限为 **RX**（读/执行），需先修改为 **RWX** 或 **RW**：
```c
// 伪代码示例
DWORD oldProtect;
VirtualProtect(targetModuleBase + textSectionOffset, textSectionSize, PAGE_READWRITE, &oldProtect);
```
随后有两种主流实现路径：
1. **区段卸载重映射**：调用 `NtUnmapViewOfSection` 卸载原有镜像区段，再通过 `NtMapViewOfSection` 映射攻击者准备好的恶意 Section Object（需拥有 Section 句柄，通常涉及内核对象操作或利用共享内存）。
2. **直接内存覆写**：利用 `WriteProcessMemory`、`memcpy` 或 ROP 链直接将恶意代码写入 `.text` 区段，随后恢复权限为 `PAGE_EXECUTE_READ`。这是用户态实现更常见的方式。

#### 步骤三：执行流劫持与载荷触发
恶意代码植入后，需将执行流重定向至空洞化区域。常见手法：
- **导出函数表 Hook**：修改目标 DLL 导出表（EAT）中特定函数的 RVA 指向恶意代码入口。当宿主程序或其他线程调用该导出函数时触发执行。
- **线程劫持/APC 注入**：将目标线程上下文（RIP/EIP）指向空洞化地址，或排队 APC (Asynchronous Procedure Call) 指向该地址。
- **IAT 修改**：修改调用者模块的导入地址表 (IAT)，使其指向空洞化模块内的恶意地址。

#### 步骤四：伪装恢复与持久化
- 恢复 `.text` 区段内存权限为 `RX`，消除 RWX 异常特征。
- 保持 PEB 模块链表条目不变，`DllBase`、`SizeOfImage`、`FullDllName` 均指向合法磁盘路径。
- 可选：实现“双模态”代码，即恶意代码执行完毕后跳转回原始合法代码逻辑（需保留原始字节或通过 Trampoline），维持宿主程序功能正常，实现长期潜伏。

## 关键技术细节对比

| 特性 | 经典 DLL 注入 | 进程空洞化 | 模块踩踏 | **Phantom DLL Hollowing** |
| :--- | :--- | :--- | :--- | :--- |
| **磁盘落盘** | 是 (恶意 DLL) | 否 (目标 EXE 落盘) | 否 | **否** |
| **新增 VAD 节点** | 是 (新映射) | 否 (替换主镜像) | 否 (覆写现有) | **否** (覆写现有 DLL 区段) |
| **PEB 模块列表** | 新增条目 | 条目不变(路径欺骗) | 条目不变 | **条目完全不变** (合法路径/基址/大小) |
| **内存内容 vs 磁盘** | 一致 (恶意 DLL) | 不一致 (主镜像) | 不一致 (目标 DLL .text) | **严重不一致** (合法 DLL 路径 vs 恶意代码) |
| **内存权限异常** | 正常 RW->RX | 正常 | 临时 RWX | **临时 RWX -> 恢复 RX** |
| **检测难点** | 文件监控/模块枚举 | 内存/磁盘对比、PEB 篡改 | 内存/磁盘对比、模块完整性 | **极高：静态视图完美，动态需逐页比对** |

> **术语澄清**：学术界/工业界常将 “Module Stomping”（模块踩踏）与 “DLL Hollowing” 交替使用。Forrest Orr 文章中将“针对已加载 DLL 的 .text 节覆写”定义为 **DLL Hollowing**；而 “Module Stomping” 有时特指利用 `NtUnmapViewOfSection` 卸载后重映射恶意镜像的变体。本页面统称该类“利用合法模块内存空洞化隐藏代码”技术为 Phantom DLL Hollowing。

## 内存取证与检测对抗

### 典型检测向量
- **VAD (Virtual Address Descriptor) 遍历 + 磁盘对比**：扫描进程 VAD 树，针对 `MEM_IMAGE` 类型的节点，读取内存内容计算哈希/特征码，与磁盘对应文件（由 `FileObject` 指向）对比。Phantom DLL Hollowing 会导致 **内容哈希不匹配**，但 `FileObject` 指向合法系统文件。
- **PEB 模块列表与 VAD 一致性校验**：对比 `LDR_DATA_TABLE_ENTRY.DllBase` 覆盖的 VAD 范围，检查该 VAD 的 `ControlArea->FilePointer` 是否指向同一文件对象。Hollowing 技术下二者指向一致，**仅内容异常**。
- **内存权限审计**：监控 `VirtualProtect`/`NtProtectVirtualMemory` 调用，捕获 `PAGE_EXECUTE_READ` -> `PAGE_READWRITE` -> `PAGE_EXECUTE_READ` 的翻转模式。
- **导出表/代码完整性校验**：定期校验关键系统 DLL (ntdll, kernel32, kernelbase) 导出函数入口指令字节 (如 `mov r10, rcx; mov eax, ...; syscall`)，检测 Inline Hook 或 EAT Hook。

### 对抗与绕过思路
- **最小化覆写**：仅覆写极少量字节（如导出函数前 5-12 字节 JMP 指令），保留绝大部分合法代码，降低哈希匹配阈值触发概率。
- **利用合法可写区段**：部分 DLL 拥有合法的可写代码区段（极少见）或 `.data` 节可执行（配置错误），利用现有 RWX 区域避免权限修改痕迹。
- **硬件断点/页保护绕过**：利用硬件调试寄存器 (DR0-DR3) 或页面保护异常 (#PF) 处理机制实现隐形执行流转移，避免修改内存内容。
- **跨进程/会话攻击**：针对高权限进程 (lsass.exe, svchost.exe) 实施，配合 PPL (Protected Process Light) 绕过技术，增加取证难度。

## 实战化工具与实现参考

- **SharpBlock / DllHollowing-BoF**: Cobalt Strike Beacon Object Files (BOF) 实现，支持在内存中对指定 DLL 执行 Hollowing。
- **ModuleStomper / PhantomDLL**: 开源 C/C++ 实现，演示 `VirtualProtect` + `WriteProcessMemory` + `CreateRemoteThread` / `NtQueueApcThread` 完整链路。
- **EDR Evasion Frameworks (e.g., ScareCrow, Freeze, Lazarus)**: 集成 Module Stomping/DLL Hollowing 作为标准 Shellcode 加载器模块。

## 关联技术生态

- **逆向分析视角**：分析此类样本需重点关注 [[ida-pro-tips-plugins-python]] 中提到的 FLIRT 签名识别失效场景、内存镜像与磁盘文件的二进制对比（可结合 [[binary-ninja-ollvm-deobfuscation]] 中的 IL 分析思路还原混淆后的注入逻辑）。
- **内核防护视角**：Windows 10/11 引入的 **VBS (Virtualization-Based Security)**、 **HVCI (Hypervisor-Protected Code Integrity)** 通过二级地址转换 (SLAT/EPT) 强制内存页权限，可在 hipervisor 层面拦截 `PAGE_EXECUTE_READ` 页的写入尝试，从根本上缓解用户态内存覆写攻击。相关机制可参考 [[linux-kernel-hardening-mechanisms]] 中关于内存保护、控制流完整性 (CFI) 及硬件辅助防护的通用设计原则。
- **推测执行侧信道**：恶意代码在空洞化模块中执行时，可能受 [[oo7-spectre-defense-binary-analysis]] 所述 Spectre 类漏洞影响，或被利用侧信道泄露其内存布局。

## 总结

Phantom DLL Hollowing 代表了 Windows 平台上**内存级对抗**的高水位线：它不再依赖文件系统、不创建可疑进程/线程/模块，而是寄生于合法模块的虚拟地址空间之中，通过“静态元数据真、动态代码假”的极致伪装，挑战基于特征码、行为启发式、模块完整性校验的主流防御体系。防御端必须转向**内存语义完整性验证**（如 VBS/HVCI、内存页哈希实时监控、异常控制流图偏离检测）以及**硬件辅助的不可篡改执行环境**才能从根本上遏制此类技术。

## 参考来源
- Forrest Orr, "[Malicious Memory Artifacts: Part I - DLL Hollowing](https://www.forrest-orr.net/post/malicious-memory-artifacts-part-i-dll-hollowing)" (2019-12-19)
- Matt Graeber, "Module Stomping for Shellcode Execution" (Black Hat / Derived works)
- Microsoft Docs: "Virtualization-Based Security (VBS) and HVCI"
- MITRE ATT&CK: **T1055.012** (Process Injection: Module Stomping / DLL Hollowing)

## 来源

- [0th3rs安全团队-201911-202204_110](../sources/0th3rs安全团队-201911-202204_110.md)
