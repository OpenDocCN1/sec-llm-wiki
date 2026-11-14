---
title: Windows 内核回调拦截进程注入防御技术分析
description: 深度解析利用 ObRegisterCallbacks 注册内核回调拦截进程句柄创建与复制操作，移除 PROCESS_VM_WRITE 与
  PROCESS_VM_OPERATION 权限以阻断进程注入的防御原理、实现流程、拦截效果及绕过思路。基于 pi-defender 项目实战复现。
category: program-analysis
tags:
- Windows Internals
- Kernel Callback
- ObRegisterCallbacks
- Process Injection Defense
- Anti-Injection
- Memory Protection
- Red Teaming
- Blue Teaming
- Driver Development
date: 2023-04-16
updated: '2026-11-15'
---
## 概述

本页面分析一种基于 **Windows 内核回调机制** 的进程注入防御技术。核心思路是通过 `ObRegisterCallbacks` 注册 **Pre-operation 回调**，拦截所有用户态（Ring 3）发起的进程句柄创建（`OB_OPERATION_HANDLE_CREATE`）与句柄复制（`OB_OPERATION_HANDLE_DUPLICATE`）操作，在满足拦截条件时**剥离句柄的 `PROCESS_VM_WRITE` 与 `PROCESS_VM_OPERATION` 权限**，从而使攻击者无法在目标进程中分配内存、写入 Shellcode 或 PE 镜像，达到**通用阻断进程注入**的效果。

参考实现项目：[pi-defender](https://github.com/PI-Defender/pi-defender) （Process Injection Defender）。

> **适用场景**：主机入侵防御系统（HIPS）、EDR 核心防护模块、反作弊驱动、沙箱逃逸缓解。
> **局限性**：仅拦截用户态句柄操作；内核态直接操作内存（如 `MmMapIoSpace`、手动映射）不在拦截范围；白名单与签名校验逻辑若被篡改（注册表、磁盘文件替换）可被绕过。

## 核心原理

### ObRegisterCallbacks 回调机制

`ObRegisterCallbacks` 是 Windows 驱动开发接口（DDI），允许内核驱动注册**对象操作回调**，支持拦截的对象类型包括：
- `PsProcessType` —— 进程对象
- `PsThreadType` —— 线程对象

每个注册项可指定：
| 字段 | 说明 |
|------|------|
| `ObjectType` | 目标对象类型（进程/线程） |
| `Operations` | 位掩码：`OB_OPERATION_HANDLE_CREATE`、`OB_OPERATION_HANDLE_DUPLICATE` |
| `PreOperation` | 操作发生**前**调用，可修改 `DesiredAccess`、拒绝操作 |
| `PostOperation` | 操作发生**后**调用，可做审计、清理 |
| `Altitude` | 回调高度（字符串），决定多个过滤驱动的调用顺序 |

> **文档参考**：[ObRegisterCallbacks - Microsoft Learn](https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/nf-wdm-obregistercallbacks)

### 回调注册关键代码（节选自 `K_ObCallback.cpp`）

```cpp
// 仅注册进程对象的创建与复制操作，只实现 PreOperation
ObOperationRegistrations[0].ObjectType = PsProcessType;
ObOperationRegistrations[0].Operations |= OB_OPERATION_HANDLE_CREATE;
ObOperationRegistrations[0].Operations |= OB_OPERATION_HANDLE_DUPLICATE;
ObOperationRegistrations[0].PreOperation = _PreObCallback;
ObOperationRegistrations[0].PostOperation = NULL;

ObRegistration.Version = OB_FLT_REGISTRATION_VERSION;
ObRegistration.OperationRegistrationCount = NumberOfOperations;
ObRegistration.Altitude = szAltitude;           // 如 "320000" 保证在大多数 EDR 之上
ObRegistration.RegistrationContext = NULL;
ObRegistration.OperationRegistration = ObOperationRegistrations;

ObRegisterCallbacks(&ObRegistration, &globalDriverData.pObCallback);
```

### PreOperation 回调核心逻辑（伪代码）

```c
OB_PREOP_CALLBACK_STATUS _PreObCallback(
    PVOID RegistrationContext,
    POB_PRE_OPERATION_INFORMATION OperationInformation
) {
    // 1. 仅处理进程对象
    if (OperationInformation->ObjectType != PsProcessType) return OB_PREOP_SUCCESS;

    // 2. 仅拦截 Ring3 发起的操作
    if (OperationInformation->KernelHandle) return OB_PREOP_SUCCESS;

    // 3. 获取目标进程 EPROCESS 与调用进程 EPROCESS
    PEPROCESS targetProcess = (PEPROCESS)OperationInformation->Object;
    PEPROCESS callerProcess = PsGetCurrentProcess();

    // 4. 仅拦截跨进程操作（排除自身打开自身）
    if (targetProcess == callerProcess) return OB_PREOP_SUCCESS;

    // 5. 白名单校验：调用进程路径在注册表白名单中 -> 放行
    if (IsInWhitelist(callerProcess)) return OB_PREOP_SUCCESS;

    // 6. 签名校验：调用进程映像有可信签名 -> 放行
    if (HasTrustedSignature(callerProcess)) return OB_PREOP_SUCCESS;

    // 7. 仅当请求权限包含 VM_WRITE | VM_OPERATION 时才剥离
    ACCESS_MASK desired = OperationInformation->Parameters->CreateHandleInformation.DesiredAccess;
    if ((desired & (PROCESS_VM_WRITE | PROCESS_VM_OPERATION)) == 0) return OB_PREOP_SUCCESS;

    // 8. 剥离关键权限
    OperationInformation->Parameters->CreateHandleInformation.DesiredAccess &=
        ~(PROCESS_VM_WRITE | PROCESS_VM_OPERATION);

    return OB_PREOP_SUCCESS;  // 允许操作继续，但权限已被修改
}
```

## 处理流程图解

```mermaid
flowchart TD
    A[用户态调用 OpenProcess / CreateProcess / DuplicateHandle] --> B{内核对象管理器<br>分发到 ObRegisterCallbacks 回调链}
    B --> C[PreOperation 回调 _PreObCallback]
    C --> D{目标是否为进程对象?}
    D -- 否 --> E[放行]
    D -- 是 --> F{是否为内核句柄?}
    F -- 是 --> E
    F -- 否 --> G{是否为跨进程操作?}
    G -- 否 --> E
    G -- 是 --> H{调用进程在白名单?}
    H -- 是 --> E
    H -- 否 --> I{调用进程有可信签名?}
    I -- 是 --> E
    I -- 否 --> J{请求权限含 VM_WRITE/VM_OPERATION?}
    J -- 否 --> E
    J -- 是 --> K[剥离 PROCESS_VM_WRITE | PROCESS_VM_OPERATION]
    K --> E
```

> **原文流程图**：![pi-defender 流程图](../Images/53c34a2f007867146700efd9ef9dc2f8.png)

## 拦截效果分析

| 注入技术 | 关键步骤 | 是否被拦截 | 说明 |
|----------|----------|------------|------|
| **Classic DLL Injection** | `OpenProcess` → `VirtualAllocEx` → `WriteProcessMemory` → `CreateRemoteThread` | ✅ | 无 `VM_WRITE/VM_OPERATION` 无法分配/写入内存 |
| **Process Hollowing / RunPE** | `CreateProcess(SUSPENDED)` → `ZwUnmapViewOfSection` → `VirtualAllocEx` → `WriteProcessMemory` → `SetThreadContext` → `ResumeThread` | ✅ | 同理 |
| **Reflective DLL Injection (RDI)** | `OpenProcess` → 手动映射 PE → `WriteProcessMemory` Shellcode → `CreateRemoteThread` | ✅ | 核心写入内存环节被阻断 |
| **Thread Execution Hijacking** | `OpenThread` → `Get/SetThreadContext` → 指向 Shellcode | ⚠️ 部分 | 若不需写目标进程内存（如复用现有代码洞）可能绕过，但实战难度极高 |
| **Kernel-mode Injection** | 直接在内核操作 `MmMapIoSpace`、`MmCopyVirtualMemory`、手动构建 MDL | ❌ | **不在拦截范围**，需配合内核完整性保护（HVCI、VBS、PatchGuard） |

> **结论**：该技术可**通用阻断所有依赖用户态句柄写入目标进程内存的注入手法**，是当前 EDR/HIPS 防注入的基石能力之一。

## 绕过与对抗思路

文章作者给出两个侧面绕过方向，均利用**策略判断逻辑的信任链薄弱点**：

### 篡改注册表白名单
- pi-defender 将白名单存储在注册表（如 `HKLM\SYSTEM\CurrentControlSet\Services\PI-Defender\Whitelist`）
- **无自我保护**：若攻击者已获管理员权限，可直接写注册表添加恶意进程路径
- **对抗**：驱动应实现**注册表回调**（`CmRegisterCallbackEx`）保护自身配置键值，或将白名单存储在驱动内存/加密文件中

### 白加黑 / 签名滥用
- 利用**合法签名程序**（如 `msbuild.exe`、`installutil.exe`、`rundll32.exe`、签名有效的第三方软件）作为载荷加载器
- 由于签名校验通过，回调直接放行，获得完整权限句柄
- **对抗**：
  - 引入**行为审计**：结合 ETW / Sysmon Event ID 8/10/11（`CreateRemoteThread`、`ProcessAccess`、`FileCreate`）做二次关联
  - 启用 **HVCI (Hypervisor-Protected Code Integrity)**，禁止未签名内核代码执行，提升内核攻击成本
  - 部署 **内存扫描**（如 `MmMapIoSpace` 扫描可疑 RWX 区域、PE 头特征）作为纵深防御

### 进阶绕过研究方向（文献扩展）
| 方向 | 技术点 | 参考 |
|------|--------|------|
| **内核句柄滥用** | 通过漏洞驱动（BYOVD）获取内核句柄，绕过 `KernelHandle` 判断 | [[phantom-dll-hollowing-technique]] |
| **Direct Kernel Object Manipulation (DKOM)** | 直接修改 `EPROCESS` 对象权限位、解链隐藏进程 | [[windows-syscall-internals-sysenter-kifastcallentry]] |
| **Hardware Breakpoint / Debug Register** | 利用 `DR0-DR3` 硬件断点劫持执行流，无需写内存 | [[heap-overflow-principles-unlink-exploitation]]（调试器原理通用） |
| **Memory Mapped Section Injection** | `CreateFileMapping` + `MapViewOfFile` + `NtMapViewOfSection` 共享内存注入 | 需拦截 `SECTION_MAP_WRITE`、`SECTION_MAP_EXECUTE` 等 Section 权限 |

## 相关技术交叉引用

| 主题 | 关联点 |
|------|--------|
| [[phantom-dll-hollowing-technique]] | 幽灵 DLL 空洞化属于内存注入变种，若攻击者已有内核执行能力可绕过用户态回调拦截 |
| [[cobalt-strike-external-c2-smb-beacon]] | Cobalt Strike SMB Beacon 进程注入（`spawnto`、`inject`）会被此类回调拦截，红队常配合 BYOVD 绕过 |
| [[named-pipe-smb-detection-sysmon]] | Sysmon Event ID 8/10 可作为回调拦截的**审计补充**，检测被剥离权限后的异常重试行为 |
| [[windows-syscall-internals-sysenter-kifastcallentry]] | 理解系统调用入口有助于分析 `NtOpenProcess`/`NtCreateThreadEx` 从用户态到内核态的完整路径 |
| [[windows-x86-stack-overflow-shellcode-execution]] | 经典栈溢出 Shellcode 执行流程，若注入阶段被拦截则无法落地执行 |
| [[pe-manual-mapping-loader-implementation]] | 手动映射加载器原理分析，对应注入链中“写入 PE 镜像”环节被回调阻断 |
| [[rust-proc-macro-win32-dynamic-import]] | 红队工具开发中动态解析 Win32 API 绕过静态导入表检测，但运行时仍需句柄权限 |

## 防御纵深建议

1. **内核回调 + ETW 双层审计**：回调拦截为**阻断面**，ETW（`Microsoft-Windows-Kernel-Process`、`Microsoft-Windows-Kernel-Image`）提供**可视面**，关联 `ProcessId`、`ImageFileName`、`CallStack` 做溯源。
2. **保护自身配置**：注册 `CmRegisterCallbackEx` 监控自身注册表键值、`ObRegisterCallbacks` 监控自身驱动对象、注册 `PsSetCreateProcessNotifyRoutineEx` 监控驱动加载卸载。
3. **启用 HVCI + VBS**：将内核代码完整性提升到虚拟化层，防止 BYOVD 篡改回调链或直接内核注入。
4. **内存完整性扫描**：定期扫描关键进程（`lsass.exe`、`svchost.exe` 等）内存区域，检测 RWX、非模块映射、PE 头异常。
5. **最小权限原则**：结合 **AppLocker / WDAC** 限制可执行文件白名单，减少“白加黑”攻击面。

## 参考资源

- [pi-defender GitHub](https://github.com/PI-Defender/pi-defender)
- [ObRegisterCallbacks - Microsoft Learn](https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/nf-wdm-obregistercallbacks)
- [K_ObCallback.cpp 源码](https://github.com/PI-Defender/pi-defender/blob/main/Sources/PI-Defender/K_ObCallback.cpp)
- 《Windows Internals, Part 1 & 2》—— Object Manager, Callback Mechanisms, Process/Thread Objects
- 《Rootkits and Bootkits》—— Chapter 7: Kernel Callbacks & Filter Drivers

## 来源

- [0x4d5a-202103-202209_02](../sources/0x4d5a-202103-202209_02.md)
