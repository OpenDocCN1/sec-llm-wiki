---
title: SassyKitdi：内核态 TDI 反向 Shell 与 LSASS 转储技术详解
description: 深度解析 SassyKitdi 内核态载荷：利用 TDI (Transport Driver Interface) 建立反向 TCP 连接，通过
  KeStackAttachProcess 附加至 LSASS 进程上下文，配合 ZwQueryVirtualMemory 遍历虚拟内存区域，通过 PEB->Ldr.InLoadOrderLinks
  枚举已加载模块，生成 Mimikatz 可解析的 minidump 三大流，实现无文件凭据窃取。
category: program-analysis
tags:
- TDI
- Transport Driver Interface
- Kernel Mode
- Reverse Shell
- TCP Socket
- LSASS Dump
- KeStackAttachProcess
- ZwQueryVirtualMemory
- MEMORY_BASIC_INFORMATION
- PEB
- LDR_DATA_TABLE_ENTRY
- Minidump
- Mimikatz
- Rust
- Shellcode
- Rootkit
- EternalBlue
- BlueKeep
- SMBGhost
- Red Teaming
- Windows Internals
- Credential Theft
date: 2020-08-01
updated: '2026-11-15'
---
## 概述

**SassyKitdi** 是一个 Windows NT 内核模式载荷，整合了 **TDI 反向 TCP 连接**、**内核态 LSASS 内存转储** 与 **Rust 编写的位置无关 Shellcode** 三大核心能力。该载荷可通过远程内核漏洞（如 EternalBlue、BlueKeep、SMBGhost）或本地内核漏洞（易受攻击驱动）部署，覆盖 Windows 2000 至 Windows 10 全版本，且不依赖特定 DKOM 偏移。

核心创新点：
1. **用户态不落地**：全流程在 Ring 0 完成，无需用户态进程交互，天然规避用户态 AV/EDR 对 LSASS 的保护（如 RunAsPPL、PPL）。
2. **TDI 网终栈**：复用古老但稳定的 Transport Driver Interface（`tdi.sys`），建立反向 TCP 连接传输凭据数据。
3. **三大流生成**：按 Mimikatz minidump 格式产出 System Information、Memory Ranges、Module List 三大流，直接兼容 `sekurlsa::minidump` 解析。
4. **Rust 零开销抽象**：利用 `no_std`、RAII、`Result` 等高级特性编写高质量 PIC Shellcode，体积约 3300 字节。

> 原文来源：[@zerosum0x0's blog](https://zerosum0x0.blogspot.com/2020/08/sassykitdi-kernel-mode-tcp-sockets.html) | [PoC 仓库](https://github.com/zerosum0x0/SassyKitdi)

---

## TDI 内核态网络通信

### 设备对象打开与地址绑定

TDI 通过 `ZwCreateFile` 打开 `\Device\Tcp` 设备对象，利用 **File Extended Attributes (FEA)** 传递配置：

| FEA 名称 | 用途 | 关键结构体 |
|----------|------|------------|
| `TransportAddress` | 创建传输句柄，绑定本地 IP/端口 | `TRANSPORT_ADDRESS` (含 `TA_ADDRESS`、`TDI_ADDRESS_IP`) |
| `ConnectionContext` | 创建连接句柄，关联上下文 | 自定义 `PVOID` (示例置 NULL) |

```c
// 绑定 0.0.0.0:0，由内核分配临时源端口
TRANSPORT_ADDRESS ta = { .TAAddressCount = 1 };
ta.Address[0].AddressType = TDI_ADDRESS_TYPE_IP;
ta.Address[0].AddressLength = sizeof(TDI_ADDRESS_IP);
((TDI_ADDRESS_IP*)ta.Address[0].Address)->sin_port = 0;
((TDI_ADDRESS_IP*)ta.Address[0].Address)->in_addr = 0;
```

### 连接建立与数据发送

所有后续操作通过 `IRP_MJ_INTERNAL_DEVICE_CONTROL` 分发 TDI IOCTL：

| MinorFunction (Opcode) | 说明 | 参数结构体 |
|------------------------|------|------------|
| `TDI_CONNECT` | 主动连接远端 | `TRANSPORT_ADDRESS` (目标 IP/端口，大端序) |
| `TDI_SEND` | 发送数据 | `TDI_REQUEST_SEND` + MDL 描述缓冲区 |
| `TDI_DISCONNECT` | 断开连接 | `TDI_REQUEST_DISCONNECT` |

**发送流程**：
1. `ExAllocatePool` 分配缓冲区 → `RtlCopyMemory` 填充数据
2. `IoAllocateMdl` 构造 MDL → `MmProbeAndLockPages` 锁定物理页
3. `IoBuildDeviceIoControlRequest` 构造 IRP → `IofCallDriver` 分发
4. 完成后 `MmUnlockPages`、`IoFreeMdl`、`ExFreePool` 释放资源

> 完整 IRP 构造、分发、等待模式参考 [[tdi-kernel-mode-networking]] 的 “TDI 反向 Shell 实战流程” 一节。

---

## 内核态 LSASS 转储核心流程

### 进程上下文附加：`KeStackAttachProcess`

内核通过 `KeStackAttachProcess(PEPROCESS TargetProcess, PKAPC_STATE ApcState)` 将当前线程内核栈附加到目标进程（LSASS）地址空间，使后续 `ZwQueryVirtualMemory` 等系统调用在 LSASS 上下文执行。**附加后必须配对 `KeUnstackDetachProcess` 还原**。

```c
KAPC_STATE apcState;
KeStackAttachProcess(lsassProcess, &apcState);
// 此时当前线程可见 LSASS 的用户态虚拟地址空间
// ... 遍历内存、枚举模块 ...
KeUnstackDetachProcess(&apcState);
```

> 该技术亦可用于用户态注入（如 [[ppldump-userland-ppl-bypass-evasion]] 利用 KnownDLLs 劫持进入 PPL 上下文），但内核态附加无需任何用户态句柄权限，完全绕过 `OpenProcess` 访问检查。

### 虚拟内存区域遍历：`ZwQueryVirtualMemory`

在附加上下文中，以 `ProcessHandle = (HANDLE)-1`（当前进程伪句柄）和 `BaseAddress = 0` 起始，循环调用：

```c
MEMORY_BASIC_INFORMATION mbi;
SIZE_T returnLength;
NTSTATUS status = ZwQueryVirtualMemory(
    (HANDLE)-1, baseAddress, MemoryBasicInformation, &mbi, sizeof(mbi), &returnLength
);
```

**关键字段**：

| 字段 | 用途 |
|------|------|
| `BaseAddress` | 区域起始地址 |
| `RegionSize` | 区域大小（下次迭代 `baseAddress += RegionSize`） |
| `State` | `MEM_COMMIT` 表示已提交，需转储 |
| `Protect` | 页保护属性（如 `PAGE_READWRITE`、`PAGE_EXECUTE_READ`） |
| `Type` | `MEM_PRIVATE`/`MEM_IMAGE`/`MEM_MAPPED` 区分映射类型 |

仅收集 `State == MEM_COMMIT` 且 `Protect` 非 `PAGE_NOACCESS` 的区域，写入 **Memory Ranges 流**。

### 模块列表枚举：`PEB->Ldr.InLoadOrderLinks`

获取 PEB 两种路径：
1. `ZwQueryInformationProcess(ProcessHandle, ProcessBasicInformation, ...)` 返回 `PROCESS_BASIC_INFORMATION.PebBaseAddress`
2. 直接读段寄存器：x64 `gs:[0x60]`、x86 `fs:[0x30]`（更常用于 Shellcode）

遍历双向链表 `PEB->Ldr->InLoadOrderModuleList`，每个节点为 `LDR_DATA_TABLE_ENTRY`：

```c
typedef struct _LDR_DATA_TABLE_ENTRY {
    LIST_ENTRY InLoadOrderLinks;
    LIST_ENTRY InMemoryOrderLinks;
    LIST_ENTRY InInitializationOrderLinks;
    PVOID DllBase;
    PVOID EntryPoint;
    ULONG SizeOfImage;
    UNICODE_STRING FullDllName;
    UNICODE_STRING BaseDllName;
    // ...
} LDR_DATA_TABLE_ENTRY, *PLDR_DATA_TABLE_ENTRY;
```

提取 `FullDllName`、`DllBase`、`SizeOfImage` 写入 **Module List 流**。

> 该枚举逻辑与用户态工具（如 [[mimikatz-sekurlsa-pth-internals]]、[[pe-manual-mapping-loader-implementation]]）一致，仅运行环境从 Ring3 移至 Ring0。

---

## Minidump 三大流构造与 Mimikatz 兼容

| 流类型 | Stream Type | 核心内容 | 生成来源 |
|--------|-------------|----------|----------|
| **System Information** | `SystemInfoStream` (7) | `OSVERSIONINFOEX` (Major/Minor/Build)、CPU 架构 | `RtlGetVersion` (导出函数) |
| **Memory Ranges** | `MemoryListStream` (5) | `MINIDUMP_MEMORY_LIST` + 连续 `MINIDUMP_MEMORY_DESCRIPTOR64` 数组 | `ZwQueryVirtualMemory` 遍历结果 |
| **Module List** | `ModuleListStream` (4) | `MINIDUMP_MODULE_LIST` + `MINIDUMP_MODULE64` 数组 | `PEB->Ldr.InLoadOrderLinks` 枚举结果 |

**传输格式**：载荷按顺序发送三个流的原始二进制块，攻击者接收端拼接为标准 minidump 文件（添加 `MINIDUMP_HEADER`、目录索引、流目录），即可直接拖入 Mimikatz：

```bash
mimikatz # sekurlsa::minidump sassykitdi.dmp
mimikatz # sekurlsa::logonpasswords
```

> 详细 minidump 结构定义参考 Windows SDK `dbghelp.h` 与 [[mimikatz-source-code-architecture-golden-ticket-audit]] 中的 “黄金票据生成与序列化” 部分（同属 BER/结构化二进制编码范畴）。

---

## Rust Shellcode 工程化实践

### 编译工具链与目标

```toml
# Cargo.toml
[profile.release]
opt-level = 'z'      # 优化体积
lto = true           # 链接时优化
codegen-units = 1    # 单代码单元最大化内联
panic = 'abort'      # 无 panic 运行时
```

交叉编译目标：`x86_64-pc-windows-gnu` (MinGW) 或 `x86_64-pc-windows-msvc` (MSVC，推荐用于原生 API 兼容性)。产物为 DLL，提取 `_DllMainCRTStartup` 至 `malloc` 间代码作为 PIC Shellcode。

### 核心抽象与零开销优势

| Rust 特性 | Shellcode 场景应用 | 开销 |
|-----------|-------------------|------|
| `no_std` + `core` | 无运行时、无标准库，仅用 `core::ptr`、`core::mem` | 零 |
| `Result<T, NTSTATUS>` + `?` | 系统调用错误传播，避免冗长 `if !NT_SUCCESS` | 双字宽返回值，等同手写 C |
| RAII (`Drop` trait) | `HANDLE`、`MDL`、内核池自动释放，防止泄漏 | 编译期内联，无运行时 |
| `stacklstr` 栈上宽字符串 | `UNICODE_STRING` 无堆分配构造 | 栈内存，无池分配 |
| `ntdef` 类型定义库 | 纯类型定义，无静态数据段 | 纯编译期 |

**示例：安全封装 `ZwQueryVirtualMemory`**

```rust
fn query_virtual_memory(base: *mut c_void) -> Result<MEMORY_BASIC_INFORMATION, NTSTATUS> {
    let mut mbi = MEMORY_BASIC_INFORMATION::default();
    let mut ret_len = 0;
    let status = unsafe {
        ZwQueryVirtualMemory(
            -1isize as HANDLE, base, MemoryBasicInformation,
            &mut mbi as *mut _ as _, size_of::<MEMORY_BASIC_INFORMATION>() as u32, &mut ret_len
        )
    };
    if status >= 0 { Ok(mbi) } else { Err(status) }
}
```

> 更多 Rust Shellcode 模式参考 [[rust-proc-macro-win32-dynamic-import]]（动态导入 Win32 API）、[[aceldr-technical-analysis]]（反射式加载器 Rust 实现）。

---

## 部署场景与攻击链集成

| 部署向量 | 前置条件 | 典型利用链 |
|----------|----------|------------|
| **远程内核漏洞** | EternalBlue (MS17-010)、BlueKeep (CVE-2019-0708)、SMBGhost (CVE-2020-0796) | 漏洞触发 → Ring0 代码执行 → 降低 IRQL 至 `PASSIVE_LEVEL` → 部署 SassyKitdi |
| **本地内核漏洞** | 易受攻击驱动 (CVE-2020-XXXX、Bring Your Own Vulnerable Driver) | 驱动加载 → `DeviceIoControl` 触发 → Ring0 执行 → 部署 SassyKitdi |
| **后渗透持久化** | 已获 SYSTEM/内核执行 | 修补内核回调 (`PsSetCreateProcessNotifyRoutine`)、注册过滤驱动、计划任务加载签名驱动 |

**Stage 0 预处理**：远程漏洞通常在 `DISPATCH_LEVEL` 触发，必须先通过 `KeLowerIrql(PASSIVE_LEVEL)` 或工作项 (`IoQueueWorkItem`) 降级，再执行 TDI/内存操作（均要求 `PASSIVE_LEVEL`）。

**扩展性**：初始 Shellcode (~1.5 KB 压缩后) 可下载更大二阶段内核模块（反射式驱动加载，参考 [[aceldr-technical-analysis]] “反射式加载器”），实现令牌窃取、文件系统访问、网络隧道等完整后渗透框架。

---

## 交叉引用与关联技术谱系

| 技术领域 | 相关页面 | 关联点 |
|----------|----------|--------|
| **TDI 内核网络完整实现** | [[tdi-kernel-mode-networking]] | `ZwCreateFile` 打开 `\Device\Tcp`、IRP 构造、`TDI_CONNECT`/`TDI_SEND`、MDL 管理、反向 Shell 完整代码 |
| **Mimikatz LSASS 补丁与凭据提取** | [[mimikatz-sekurlsa-pth-internals]] | `sekurlsa::minidump` 解析流程、LogonSessionList 定位、LSA Protect 密钥提取 |
| **Mimikatz 模块架构与序列化** | [[mimikatz-source-code-architecture-golden-ticket-audit]] | KUHL_M 分发、BER 编码、PAC 构造、minidump 文件格式兼容性 |
| **PE 手工映射与不落地执行** | [[pe-manual-mapping-loader-implementation]]、[[aceldr-technical-analysis]] | 反射式 DLL 注入、Section 构造、导入表修复、二阶段内核模块加载基础 |
| **进程注入/篡改技术对比** | [[process-injection-tampering-techniques]] | Hollowing/Doppelgänging/Ghosting 等用户态技术与内核态附加的对比 |
| **Windows 系统调用内部机制** | [[windows-syscall-internals-sysenter-kifastcallentry]] | `ZwQueryVirtualMemory` 等系统调用从用户态到内核态的完整分发路径 |
| **内核回调防御与绕过** | [[windows-kernel-callback-injection-defense]] | `ObRegisterCallbacks` 拦截句柄创建、内核态载荷对抗策略 |
| **EDR 规避综合框架** | [[inceptor-av-edr-evasion-framework]]、[[memory-scanning-tools-evasion-techniques]] | AMSI/ETW/WDLP 绕过、Full Unhooking、Direct Syscalls、内存加密隐藏 |
| **PPL 绕过与用户态 LSASS 转储** | [[ppldump-userland-ppl-bypass-evasion]]、[[ppl-injection-createprocess-bof-fix]] | 用户态 KnownDLLs 劫持 vs 内核态直接附加的互补关系 |
| **参数欺骗与命令行隐藏** | [[argument-spoofing-edr-evasion]] | 同属红队规避维度，可结合内核态载荷隐藏命令行特征 |
| **幽灵 DLL 空洞化** | [[phantom-dll-hollowing-technique]] | 合法模块内存劫持技术，可作为二阶段内核模块落地伪装 |

---

## 检测与缓解建议

1. **内核驱动签名策略 (HVCI/VBS)**  
   - 强制启用 **Hypervisor-Protected Code Integrity (HVCI)**，禁止未签名/恶意驱动加载，从源头阻断内核载荷部署。

2. **TDI 设备对象访问审计**  
   - 监控 `ZwCreateFile` 打开 `\Device\Tcp`、`\Device\Udp` 等传输设备（ETW `Microsoft-Windows-Kernel-File` / Sysmon Event ID 12/13）。
   - 审计 `IRP_MJ_INTERNAL_DEVICE_CONTROL` 分发至 `tdi.sys` 的异常调用栈。

3. **内核线程附加异常检测**  
   - 部署内核回调 `PsSetCreateThreadNotifyRoutineEx` / `PsSetLoadImageNotifyRoutine`，检测非系统线程调用 `KeStackAttachProcess` 附加至 `lsass.exe`/`csrss.exe` 等关键进程。
   - 定期扫描 `ETHREAD.TrapFrame` 与 `KAPC_STATE` 异常，发现未授权上下文切换。

4. **内存完整性与 minidump 特征扫描**  
   - 网络层：识别异常 TCP 连接中传输的 minidump 结构特征（`MDMP` 魔数、流目录签名）。
   - 主机层：使用 [patriot]([[memory-scanning-tools-evasion-techniques]]) / [Moneta]([[memory-scanning-tools-evasion-techniques]]) 等工具扫描内核池异常分配、非签名代码段、RWX 页面。

5. **漏洞修补与攻击面收缩**  
   - 及时修补 EternalBlue/BlueKeep/SMBGhost 等远程内核漏洞。
   - 禁用 SMBv1、限制 RDP 暴露、部署带外补丁（如 0patch）。

---

## 参考资料

1. **SassyKitdi PoC** - https://github.com/zerosum0x0/SassyKitdi  
2. **原文博客** - https://zerosum0x0.blogspot.com/2020/08/sassykitdi-kernel-mode-tcp-sockets.html  
3. **TDI 参考书籍** - *Professional Rootkits* (Vieler, 2007) / *Rootkits: Subverting the Windows Kernel* (Hoglund & Butler, 2009)  
4. **Microsoft Docs: TDI** - https://learn.microsoft.com/windows-hardware/drivers/network/transport-driver-interface  
5. **Microsoft Docs: MDL** - https://learn.microsoft.com/windows-hardware/drivers/kernel/using-mdls  
6. **MmProbeAndLockPages** - https://learn.microsoft.com/windows-hardware/drivers/ddi/wdm/nf-wdm-mmprobeandlockpages  
7. **min-sized-rust** - https://github.com/johnthagen/min-sized-rust  
8. **stacklstr** - https://github.com/jmage-rs/stacklstr  
9. **memexec (用户态模块枚举参考)** - https://github.com/eddieivan01/memexec  

---

## 来源

- [0x4d5a-202103-202209_11](../sources/0x4d5a-202103-202209_11.md)
- [0x4d5a-202103-202209_17](../sources/0x4d5a-202103-202209_17.md)
