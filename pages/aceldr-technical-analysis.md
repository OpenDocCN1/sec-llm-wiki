---
title: AceLdr 用户态反射加载器核心规避技术深度解析
description: 深度解析 AceLdr 用户态反射加载器的四大核心规避技术：基于 FOLIAGE 的 Sleep_Hook（APC队列ROP链延时混淆）、Heap_Hook（自定义堆加密Beacon数据）、Return
  Address Spoofing（关键API调用栈欺骗）、动态内存加密（SystemFunction032 RC4），并附实测 moneta/pe-sieve
  检出情况分析。
category: program-analysis
tags:
- AceLdr
- User-Mode Reflective Loader
- UDRL
- Memory Evasion
- FOLIAGE
- Sleep Hook
- Heap Hook
- Return Address Spoofing
- Dynamic Memory Encryption
- SystemFunction032
- RC4
- APC Queue ROP
- moneta
- pe-sieve
- Cobalt Strike
- Beacon
- Red Teaming
- Defense Evasion
date: 2023-04-16
updated: '2026-11-15'
---

## 概述

本页面系统梳理 AceLdr（A Cobalt Strike User-Mode Reflective Loader）的四大核心内存规避技术实现细节，并对比主流内存扫描工具（Hunt-Sleeping-Beacons、BeaconHunter、BeaconEye、patriot、moneta、pe-sieve、MalMemDetect）的检测原理，最后给出实测对抗效果分析。AceLdr 通过 **Sleep_Hook（FOLIAGE APC-ROP 延时混淆）**、**Heap_Hook（自定义堆加密）**、**Return Address Spoofing（调用栈欺骗）**、**动态内存加密（SystemFunction032 RC4）** 四大技术组合，试图绕过基于线程状态、内存完整性、调用栈分析、YARA 特征匹配等多维度的内存查杀。

> 相关背景：用户态反射加载器（UDRL）是 Cobalt Strike Beacon 免杀对抗中的关键组件，详见 [[memory-scanning-tools-evasion-techniques]] 所整理的内存扫描工具体系与 UDRL 对抗全景。

---

## 主流内存扫描工具检测原理对比

AceLdr 的 README 列举了七款代表性工具，覆盖线程状态枚举、ETW 行为分析、YARA 特征匹配、内存完整性校验、PE 结构异常检测等核心技术点。

### Hunt-Sleeping-Beacons

- **线程状态筛选**：`NtQuerySystemInformation` 枚举所有线程，筛选 `WaitReason == DelayExecution`（即 `Sleep` 线程）；若使用 `WaitForSingleObject` 则状态为 `UserRequest`，可绕过此筛选。
- **三大检测模块**：
  1. **调用栈模块完整性**（`checkCallstack`）：`StackWalk64` 遍历栈帧模块，检测 Module Stomping（.text 段被修改）或模块不存在于磁盘（忽略 .NET、NTDLL/KERNELBASE hook）。
  2. **KernelTime/UserTime 比值**（`checkLandDiff`）：Beacon 大部分时间处于等待，内核/用户态时间比值异常可作为指纹。
  3. **KERNEL32 Inline Hook 检测**（`checkInlineHooks`）：专门针对 hook `Sleep` 的场景。

### BeaconHunter

- 同样先筛选 `DelayExecution` 线程，再通过 ETW 采集 HTTP/HTTPS 回连、DNS 查询、文件系统操作、进程终止、Shell 命令执行等行为日志，计算可疑分值。

### BeaconEye

- 读取进程内存，配合 YARA 规则匹配 Beacon 静态特征（配置块、Watermark、导入表哈希等）。

### patriot

针对性极强的五大检测：

1. **线程 EIP 指向 VM Protect 函数**（`FindSuspiciousContext`）：针对 **Ekko** / **NightHawk** 的 Timer+APC-ROP 延时混淆，8 字节步长暴力搜索可执行内存。
2. **内存 PE/DOS 头检测**：识别 Process Hollowing。
3. **高权限进程可疑内存块**（`EnumerateMemory`）：非 Image、可执行、已提交的私有内存。
4. **模块内容完整性校验**（`ValidateIntegrity`）：检测 Stomping/Overwriting 导致的 .text 段修改。
5. **PE 结构异常**（`ParseHeader`）：RWX 节、PE 头/节越界等。

### moneta

基于 **"Masking Malicious Memory Artifacts"** 理念，分三层扫描：

1. **动态/未知代码**：可执行私有内存、被修改的映射代码段、PEB/线程起始地址越界、未签名 Image 未修改代码（软指标）。
2. **映射 PE Image 自身异常**：内存/磁盘节保护属性不一致、PE 头被改、无 `FILE_OBJECT`（无磁盘映射文件）。
3. **进程自身异常**：PEB 模块链表缺失、PEB 记录路径与 `FILE_OBJECT` 不符。

> moneta 作者博客 [[memory-scanning-tools-evasion-techniques]] 已收录深度解析。

### pe-sieve

全面扫描 replaced/injected PE、Shellcode、Inline Hook、Process Hollowing/Doppelgänging、Reflective DLL Injection 等：

- `scanModules`：模块名/磁盘存在性/PEB 存在性/头部修改/Inline Hook
- `scanModuleIATs`：IAT Hook
- `scanThreads` + `thread_scanner`：线程栈、Context 异常

> 作者 hasherezade 同时开源大量攻防对抗技术（Process Ghosting、Doppelgänging、pe_to_shellcode、hollows_hunter），pe-sieve 体现"左右互搏"实战沉淀。

### MalMemDetect

DLL 注入式检测：Hollowing 检测 + Hook `RtlAllocateHeap`/`NtWaitForSingleObject`/`InternetConnect` 等关键 API，回溯调用栈定位可疑内存（`HookedInternetConnectW`、`DetectHollowingAndHooks`）。

---

## AceLdr 四大核心规避技术实现深度解析

### Sleep_Hook —— 基于 FOLIAGE 的 APC 队列 ROP 链延时混淆

**源码位置**：`src/hooks/delay.c#L468`  
**参考实现**：FOLIAGE、NightHawk "Obfuscate and Sleep"

#### 核心流程

1. **创建专用 Wait Thread**（挂起状态）
2. **向其 APC 队列压入一系列伪造 `CONTEXT` 记录**，构成 ROP 链，依次执行：
   - **VM Protect**：将 Beacon 代码内存 `PAGE_EXECUTE_READ` → `PAGE_READWRITE`（或 `PAGE_NOACCESS`）
   - **堆栈加密**：调用 `advapi32!SystemFunction032`（RC4）加密 Beacon 堆数据、代码段
   - **真实延时**：`WaitForSingleObjectEx` 等待信号量/事件（此时线程状态为 `UserRequest`，规避 `DelayExecution` 筛选）
   - **逆操作**：解密内存、恢复保护属性、恢复执行流
3. **主线程调用 `NtSignalAndWaitForSingleObject`** 触发 Wait Thread 执行 APC 链，并同步等待其退出。

#### 对抗效果

- **绕过 Hunt-Sleeping-Beacons**：线程无 `DelayExecution` 状态，调用栈无 `Sleep`，Inline Hook 检测失效。
- **绕过 patriot EIP 扫描**：EIP 指向合法 `WaitForSingleObjectEx`，非 VM Protect 代码区。
- **绕过 moneta/pe-sieve 代码段完整性检查**：Sleep 期间代码段被加密/权限降低，内存与磁盘不一致窗口极短。

> 技术渊源：FOLIAGE 与 NightHawk 同源，详见 [[memory-scanning-tools-evasion-techniques]] 中 Ekko/FOLIAGE 专节。

---

### Heap_Hook —— 自定义堆隔离与整体加密

**源码位置**：`src/hooks/heap.c`（关键片段见文中代码块）

#### 实现要点

```c
// 初始化阶段创建私有堆
BeaconHeap = Api.ntdll.RtlCreateHeap(HEAP_GROWABLE, NULL, 0, 0, NULL, NULL);
fillStub(MemoryBuffer, BeaconHeap, Reg.Full);

// Hook GetProcessHeap，强制 Beacon 使用自定义堆
SECTION(D) HANDLE GetProcessHeap_Hook(){
    return ((PSTUB)OFFSET(Stub))->Heap;
}
```

- **堆隔离**：Beacon 所有堆分配（`HeapAlloc`/`RtlAllocateHeap`）落在 AceLdr 私有堆，与进程默认堆物理分离。
- **Sleep 时整体加密**：Sleep_Hook ROP 链中调用 `SystemFunction032` 对**整个私有堆内存区域**做 RC4 加密，醒来后解密。
- **效果**：moneta/pe-sieve 扫描 "可执行私有内存" 或 "堆异常" 时，看到的是高熵加密块，YARA 特征匹配失效；堆元数据（LFH/段头）也被加密，堆完整性校验工具（如 `!heap -p`）失效。

---

### Return Address Spoofing —— 关键 API 调用栈欺骗

**源码位置**：`src/hooks/spoof.c`  
**理论基础**：x64 Return Address Spoofing（UnknownCheats）

#### Hook 目标 API

| API | 场景 | 欺骗目的 |
|-----|------|----------|
| `RtlAllocateHeap` / `HeapAlloc` | 堆分配 | 隐藏调用者为 Beacon 代码区（加密/非镜像内存） |
| `InternetConnectA` | C2 网络回连 | 绕过 MalMemDetect/patriot 对网络 API 调用栈回溯 |
| `NtWaitForSingleObject` | 同步/延时 | 绕过 Hunt-Sleeping-Beacons/patriot 线程上下文检查 |

#### 实现原理（x64）

1. **构造伪造栈帧**：在受控内存（如线程栈或单独分配的 RW 内存）布置伪造 `CONTEXT` / 返回地址链，指向合法模块（如 `ntdll.dll`、`kernel32.dll` 导出函数中间指令）。
2. **劫持控制流**：Hook 入口处保存原始返回地址，将 `RSP` 指向伪造栈帧，执行真实 API。
3. **返回时落入伪造链**：API 返回时按伪造链逐级 `RET`，最终回到真实调用者，调用栈呈现"合法模块 → 合法模块 → ..."假象。

#### 对抗效果

- **MalMemDetect** Hook 回溯失效：调用栈无 Beacon 地址。
- **patriot `EnumerateMemory`/`ValidateIntegrity`**：线程上下文显示合法模块地址。
- **moneta 线程起始地址/PEB 校验**：配合 Sleep_Hook，主线程看似在合法 `WaitForSingleObjectEx` 中休眠。

---

### 动态内存加密 —— SystemFunction032 (RC4) 全生命周期加密

**算法**：`advapi32!SystemFunction032` 实现的 RC4（Windows 系统库，无需自带加密代码，减少静态特征）。

#### 加密范围与时机

| 阶段 | 加密对象 | 触发点 |
|------|----------|--------|
| **Sleep 入口** | Beacon 代码段（`MemoryBuffer`）、私有堆（`BeaconHeap`）、关键数据结构 | Sleep_Hook ROP 链第 2 步 |
| **Sleep 期间** | 全内存高熵密文态 | 持续 |
| **Wake-up** | 原地解密，恢复执行权限 | Sleep_Hook ROP 链逆操作步骤 |

#### 关键代码片段（初始化分配 RWX 内存）

```c
Status = Api.ntdll.NtAllocateVirtualMemory((HANDLE)-1, &MemoryBuffer, 0, &Reg.Full, MEM_COMMIT, PAGE_READWRITE);
if (Status == STATUS_SUCCESS) {
    ...
    Status = Api.ntdll.NtProtectVirtualMemory((HANDLE)-1, &MemoryBuffer, &Reg.Exec, PAGE_EXECUTE_READ, &OldProtection);
    ...
}
```

> **注**：初始化阶段仍存在 **RW→RX 变更** 与 **私有可执行内存** 窗口，这是实测被 moneta/pe-sieve 检出的根因（见下节）。

---

## 实测对抗效果分析：moneta / pe-sieve 检出细节

### 测试环境

- **Loader**：AceLdr 编译版本（含上述四大 Hook）
- **Beacon**：Cobalt Strike 4.x x64 Beacon
- **扫描器**：moneta v1.0、pe-sieve64（最新 release）

### moneta 输出关键发现

```text
0x0000000000100000:0x00001000 | Private | RX | 0x00000000 | Abnormal private executable memory...
```

- **触发规则**：`Private` + `RX` + `非 Image` → **"Abnormal private executable memory"**（软指标 IOC）
- **根因**：初始化 `NtAllocateVirtualMemory` + `NtProtectVirtualMemory` 产生的私有可执行内存区，**未在 Sleep 前释放或转为 RW/加密**。
- **对抗建议**：
  1. 初始化后立即 `PAGE_READWRITE`，仅在执行 Beacon 入口前 `PAGE_EXECUTE_READ`（缩小 RX 窗口）。
  2. Sleep 时连同代码段一并 RC4 加密 + `PAGE_NOACCESS`（FOLIAGE 已做，需确保覆盖 `MemoryBuffer` 全范围）。
  3. 考虑 **模块伪装**（Module Stomping 合法 DLL）或 **映射镜像内存**（`SEC_IMAGE`）替代私有内存。

### pe-sieve 输出关键发现

```text
---SUMMARY:
Total scanned:      53
Hooked:             3
Hdrs Modified:      52
Implanted:          1
Implanted shc:      1
Total suspicious:   56
```

- **Hooked: 3** → `GetProcessHeap`/`InternetConnectA`/`NtWaitForSingleObject` Inline Hook 被 `scanModules`/`scanModuleIATs` 捕获。
- **Hdrs Modified: 52** → PE 头被修改（可能含 AceLdr 自身 PE 伪造、Beacon PE 头抹除、或模块 Stomping 残留）。
- **Implanted shc: 1** → 即上述 `0x100000` 私有 RX 内存被判定为 Shellcode 植入。

#### 误报说明

> 扫描输出中 "ARM Windows xtajit64" 相关模块为 JIT 编译器生成的合法动态代码，属 pe-sieve 误报，非 AceLdr 问题。

---

## 总结与工程化建议

| 技术 | 核心价值 | 现存短板 | 强化方向 |
|------|----------|----------|----------|
| **Sleep_Hook (FOLIAGE)** | 彻底消除 `Sleep` 线程特征、代码段加密窗口极短 | 依赖单独 Wait Thread，线程对象可被枚举 | 融合 **Ekko** 无线程 Timer APC 方案，或 **Stack Spoofing** 使主线程直接执行 ROP 链 |
| **Heap_Hook** | 堆隔离+整体加密，消除堆特征与 YARA 命中 | 堆句柄泄露（`GetProcessHeap` Hook 可被 `EnumProcessHeaps` 绕过） | Hook `RtlCreateHeap`/`RtlDestroyHeap` 全链路，配合 **堆元数据混淆** |
| **Return Address Spoofing** | 关键 API 调用栈"洗白" | 仅覆盖 4 个 API，调用栈深度固定易被启发式识别 | 扩展 Hook 列表（`NtCreateThreadEx`/`NtQueueApcThread` 等），引入 **动态栈帧生成** 与 **随机化合法返回地址池** |
| **动态内存加密** | 系统库 RC4 无静态特征，Sleep 期全内存高熵 | **初始化 RX 私有内存** 成硬伤 | **模块伪装/镜像映射** 替代私有内存；**延迟提交 RX** 至 Beacon 真正执行前 |

> **定位**：AceLdr 作为 **教学/原型级 UDRL**，完整演示了"Sleep 混淆+堆隔离+调用栈欺骗+动态加密"四大支柱，**实战部署需补齐初始化阶段内存伪装、Hook 面扩展、对抗主动扫描（如 patriot 8 字节搜索）的工程化细节**。

---

## 交叉引用与延伸阅读

- [[memory-scanning-tools-evasion-techniques]] —— 内存扫描工具全景与 UDRL 对抗技术谱系
- [[cobalt-strike-4.7-bof-internals]] —— Cobalt Strike 4.7 BOF 加载器内部实现，关联 Beacon 交互模型
- [[cobalt-strike-external-c2-smb-beacon]] —— SMB Beacon 与 External C2 通信模型，横向移动视角
- [[phantom-dll-hollowing-technique]] —— Phantom DLL Hollowing 内存注入隐藏技术，模块伪装替代方案
- [[pe-manual-mapping-loader-implementation]] —— PE 手动映射加载器全流程，导入表修复/重定位/模块隐藏细节
- [[windows-kernel-callback-injection-defense]] —— 内核回调拦截注入防御视角，蓝队对抗参考

---

## 参考资料（文中引用锚点）

1. AceLdr: https://github.com/kyleavery/AceLdr  
2. Hunt-Sleeping-Beacons: https://github.com/thefLink/Hunt-Sleeping-Beacons  
3. checkCallstack: https://github.com/thefLink/Hunt-Sleeping-Beacons/blob/main/Hunt-Sleeping-Beacons.c#L58  
4. checkLandDiff: https://github.com/thefLink/Hunt-Sleeping-Beacons/blob/main/Hunt-Sleeping-Beacons.c#L305  
5. checkInlineHooks: https://github.com/thefLink/Hunt-Sleeping-Beacons/blob/main/Hunt-Sleeping-Beacons.c#L396  
6. BeaconHunter: https://github.com/3lp4tr0n/BeaconHunter  
7. BeaconEye: https://github.com/CCob/BeaconEye  
8. patriot: https://github.com/joe-desimone/patriot  
9. FindSuspiciousContext: https://github.com/joe-desimone/patriot/blob/main/patriot.cpp#L54  
10. Ekko: https://github.com/Cracked5pider/Ekko  
11. NightHawk's Attempt At Obfuscate and Sleep: https://suspicious.actor/2022/05/05/mdsec-nighthawk-study.html  
12. EnumerateMemory: https://github.com/joe-desimone/patriot/blob/main/patriot.cpp#L157  
13. ValidateIntegrity: https://github.com/joe-desimone/patriot/blob/main/pefile.cpp#L231  
14. ParseHeader: https://github.com/joe-desimone/patriot/blob/main/pefile.cpp#L36  
15. moneta: https://github.com/forrest-orr/moneta  
16. Masking Malicious Memory Artifacts – Part II: https://www.forrest-orr.net/post/masking-malicious-memory-artifacts-part-ii-insights-from-moneta  
17. pe-sieve: https://github.com/hasherezade/pe-sieve  
18. scanModules: https://github.com/hasherezade/pe-sieve/blob/master/scanners/scanner.cpp#L314  
19. scanModuleIATs: https://github.com/hasherezade/pe-sieve/blob/master/scanners/scanner.cpp#L402  
20. scanThreads: https://github.com/hasherezade/pe-sieve/blob/master/scanners/scanner.cpp#L449  
21. thread_scanner: https://github.com/hasherezade/pe-sieve/blob/master/scanners/thread_scanner.cpp  
22. MalMemDetect: https://github.com/waldo-irc/MalMemDetect/  
23. HookedInternetConnectW: https://github.com/waldo-irc/MalMemDetect/blob/main/MalMemDetect/Source.cpp#L204  
24. DetectHollowingAndHooks: https://github.com/waldo-irc/MalMemDetect/blob/main/MalMemDetect/Hollow.h#L2  
25. Sleep_Hook: https://github.com/kyleavery/AceLdr/blob/main/src/hooks/delay.c#L468  
26. FOLIAGE: https://github.com/SecIdiot/FOLIAGE  
27. Spoof: https://github.com/kyleavery/AceLdr/blob/main/src/hooks/spoof.c  
28. x64 return address spoofing: https://www.unknowncheats.me/forum/anti-cheat-bypass/268039-x64-return-address-spoofing-source-explanation.html

## 来源

- [0x4d5a-202103-202209_05](../sources/0x4d5a-202103-202209_05.md)
