---
title: Windows 系统调用内核转储：sysenter 与 KiFastCallEntry 深度解析
description: 以 OpenProcess 为例，全链路剖析 Windows 用户态至内核态的系统调用流程：NtOpenProcess 参数校验、KiFastSystemCall/sysenter
  指令、KiFastCallEntry 陷阱帧构建、SSDT/SSSDT 表索引分发、用户参数拷贝至内核栈等核心机制，并附 IDA 逆向关键代码片段与 _KUSER_SHARED_DATA
  共享页利用思路。
category: program-analysis
tags:
- Windows Internals
- System Calls
- sysenter
- KiFastCallEntry
- SSDT
- SSSDT
- Reverse Engineering
- IDA Pro
- Kernel Exploitation
- _KUSER_SHARED_DATA
date: 2023-04-16
updated: '2026-11-14'
---

## 概述

Windows 系统中，凡涉及内核对象操作的 API（如 `OpenProcess`），均需从用户态（Ring3）跃迁至内核态（Ring0）执行对应的内核例程，再将结果返回用户态。本文以 `OpenProcess` 为切入点，结合 Windows Research Kernel (WRK) 源码与 IDA 静态分析，系统梳理**用户态 → `sysenter` → `KiFastCallEntry` → SSDT/SSSDT 分发 → 内核实体函数**的完整调用链路。

## 用户态入口：`OpenProcess` → `NtOpenProcess` → `ZwOpenProcess`

### `OpenProcess` 封装逻辑（WRK 源码）

```c
HANDLE WINAPI OpenProcess(
    DWORD dwDesiredAccess,
    BOOL  bInheritHandle,
    DWORD dwProcessId
) {
    NTSTATUS Status;
    OBJECT_ATTRIBUTES Obja;
    HANDLE Handle;
    CLIENT_ID ClientId;

    ClientId.UniqueThread = NULL;
    ClientId.UniqueProcess = LongToHandle(dwProcessId);

    InitializeObjectAttributes(&Obja, NULL,
        (bInheritHandle ? OBJ_INHERIT : 0), NULL, NULL);

    Status = NtOpenProcess(&Handle,
                           (ACCESS_MASK)dwDesiredAccess,
                           &Obja,
                           &ClientId);

    if (NT_SUCCESS(Status)) return Handle;
    BaseSetLastNTError(Status);
    return NULL;
}
```

> **关键点**：`OpenProcess` 直接调用 `NtOpenProcess`，未显式体现 Ring3→Ring0 转换。转换实际发生在 `NtOpenProcess` 的用户态存根（stub）中，即 `ZwOpenProcess`。

### `NtOpenProcess` 参数校验（WRK 源码节选）

```c
NTSTATUS NtOpenProcess(
    OUT PHANDLE ProcessHandle,
    IN ACCESS_MASK DesiredAccess,
    IN POBJECT_ATTRIBUTES ObjectAttributes,
    IN PCLIENT_ID ClientId OPTIONAL
) {
    KPROCESSOR_MODE PreviousMode = KeGetPreviousMode();

    if (PreviousMode != KernelMode) {           // 用户态调用
        try {
            ProbeForWriteHandle(ProcessHandle); // 探测写句柄地址
            ProbeForReadSmallStructure(ObjectAttributes,
                                       sizeof(OBJECT_ATTRIBUTES),
                                       sizeof(ULONG)); // 读取对象属性
            // ... 校验 ClientId、ObjectName 等 ...
        } except (EXCEPTION_EXECUTE_HANDLER) {
            return GetExceptionCode();
        }
    }
    // ... 后续内核侧逻辑：SeCreateAccessState、ObOpenObjectByPointer 等 ...
}
```

- `KeGetPreviousMode()` 判断调用者模式，**用户态调用需经 `ProbeForRead/Write` 校验指针有效性**，防止恶意指针导致内核崩溃。
- 校验通过后，内核侧通过 `PsLookupProcessByProcessId` → `ObOpenObjectByPointer` 完成句柄创建。

### IDA 视角下的 `ZwOpenProcess` 存根

```asm
; __stdcall ZwOpenProcess(x, x, x, x)
public _ZwOpenProcess@16
_ZwOpenProcess@16 proc near
    mov     eax, 0BEh               ; 系统调用号 (SSDT 索引)
    mov     edx, 7FFE0300h          ; _KUSER_SHARED_DATA.SystemCall
    call    dword ptr [edx]         ; 跳转 KiFastSystemCall / KiIntSystemCall
    retn    10h
_ZwOpenProcess@16 endp
```

- `eax` = 系统调用号（此处 `0xBE` 对应 `NtOpenProcess`）
- `edx` = `0x7FFE0300`，指向 `_KUSER_SHARED_DATA.SystemCall` 字段，**运行时由内核根据 CPU 支持情况填充 `KiFastSystemCall` 或 `KiIntSystemCall` 地址**。

## 共享页机制：`_KUSER_SHARED_DATA`

| 映射视角 | 虚拟地址 | 权限 | 说明 |
|----------|----------|------|------|
| 用户态   | `0x7FFE0000` | 只读 | 所有进程共享同一物理页 |
| 内核态   | `0xFFDF0000` | 读写 | 内核可动态修改字段 |

```windbg
1: kd> dt _KUSER_SHARED_DATA 0x7FFE0000
hal!_KUSER_SHARED_DATA
   ...
   +0x300 SystemCall        : 0x775464f0  -> ntdll!KiFastSystemCall
   +0x304 SystemCallReturn  : 0x775464f4  -> ntdll!KiFastSystemCallRet
   ...
```

> **防御/攻击启示**：修改 `SystemCall` 或 `SystemCallReturn` 可劫持系统调用入口/返回，实现无 Hook SSDT 的隐蔽拦截（参考文章末尾“待考究实现”思路）。

## 快速系统调用入口：`KiFastSystemCall` 与 `sysenter`

```asm
public _KiFastSystemCall@0
_KiFastSystemCall@0 proc near
    mov     edx, esp            ; 保存用户栈指针到 edx
    sysenter                    ; 执行快速系统调用指令
_KiFastSystemCall@0 endp
```

### `sysenter` 硬件动作（Intel SDM）

1. `IA32_SYSENTER_CS_MSR`  → `CS`  (Ring0 代码段)
2. `IA32_SYSENTER_EIP_MSR` → `EIP` (内核入口 `KiFastCallEntry`)
3. `IA32_SYSENTER_CS_MSR+8`→ `SS`  (Ring0 数据段)
4. `IA32_SYSENTER_ESP_MSR` → `ESP` (内核栈顶，指向预留的 `_KTRAP_FRAME`)

> **对比**：`int 2e` 通过 IDT 查找中断门，需内存访问；`sysenter` 仅用 MSR 寄存器，**效率显著更高**，成为现代 Windows 默认方式。

## 内核入口：`KiFastCallEntry` 陷阱帧构建

`KiFastCallEntry` 负责：
1. 切换 GDT/FS 指向当前 CPU 的 `KPCR`
2. 保存用户态上下文（SS, ESP, EFLAGS, CS, EIP, 通用寄存器）到 `_KTRAP_FRAME`
3. 设置 `PreviousMode = UserMode`
4. 根据系统调用号分发至 SSDT/SSSDT

### 关键汇编片段（IDA 反汇编）

```asm
_KiFastCallEntry:
    mov     ecx, 23h
    push    30h
    pop     fs                      ; FS = KPCR 自映射选择子

    mov     ecx, large fs:KPCR.TSS
    mov     esp, [ecx+_KTSS.Esp0]   ; ESP 指向内核栈预留的 _KTRAP_FRAME

    push    23h                     ; 用户态 SS
    push    edx                     ; 用户态 ESP (KiFastSystemCall 保存)
    pushf                           ; 用户态 EFLAGS
    push    2
    add     edx, 8                  ; EDX 指向用户栈参数首地址
    popf
    or      byte ptr [esp+1], 2     ; EFLAGS.VM=0, IF=1
    push    1Bh                     ; 用户态 CS
    push    dword ptr ds:0FFDF0304h ; SystemCallReturn 地址
    push    0                       ; ErrorCode = 0
    push    ebp
    push    ebx
    push    esi
    push    edi

    mov     ebx, large fs:KPCR.SelfPcr
    push    3Bh                     ; 用户态 FS
    mov     esi, [ebx+124h]         ; ESI = 当前 ETHREAD
    push    dword ptr [ebx]         ; 保存 ExceptionList
    mov     dword ptr [ebx], 0FFFFFFFFh ; 清异常链

    mov     ebp, [esi+_ETHREAD.Tcb.InitialStack]
    push    1                       ; PreviousMode = UserMode
    sub     esp, 48h                ; 预留调试寄存器空间
    sub     ebp, 29Ch               ; EBP = _KTRAP_FRAME 基址
    mov     [esi+_ETHREAD.Tcb.PreviousMode], 1
    cmp     ebp, esp
    jnz     loc_43566B              ; 栈溢出检查
    and     [ebp+_KTRAP_FRAME.Dr7], 0
    test    byte ptr [esi+3], 0DFh  ; 检查调试寄存器使用
    mov     [esi+_KTHREAD.TrapFrame], ebp
    jnz     Dr_FastCallDrSave
    ...
```

### `_KTRAP_FRAME` 关键字段

| 偏移 | 字段 | 含义 |
|------|------|------|
| `HardwareSegSs` | 用户态 SS |
| `HardwareEsp`   | 用户态 ESP |
| `EFlags`        | 用户态 EFLAGS |
| `HardwareSegCs` | 用户态 CS |
| `Eip`           | 用户态返回地址 (`KiFastSystemCallRet`) |
| `DbgArgPointer` | 用户栈参数指针 (EDX) |
| `DbgArgMark`    | `0xBADB0D00` 调试标记 |
| `PreviousMode`  | `1` = UserMode |

## 系统调用分发：SSDT / SSSDT 索引解析

### 索引编码规则

- `eax` 低 12 位：函数索引 (0~0xFFF)
- `eax` 第 13 位 (bit 12)：**表选择位**
  - `0` → `KeServiceDescriptorTable` (SSDT, 核心子系统)
  - `1` → `KeServiceDescriptorTableShadow[1]` (SSSDT, Win32k.sys 图形子系统)

### 分发逻辑汇编

```asm
loc_4356FF:
    mov     edi, eax                ; EDI = 系统调用号
    shr     edi, 8                  ; 右移 8 位，保留高位 (含表选择位)
    and     edi, 10h                ; 仅保留 bit 12 → 0 或 0x10
    mov     ecx, edi                ; ECX = 表选择标志 (0/0x10)
    add     edi, [esi+_KTHREAD.ServiceTable] ; 基址 + 偏移 → 目标描述符表地址
    mov     ebx, eax                ; EBX = 原始调用号
    and     eax, 0FFFh              ; EAX = 纯函数索引
    cmp     eax, [edi+8]            ; 越界检查 (NumberOfServices)
    jnb     _KiBBTUnexpectedRange
    cmp     ecx, 10h
    jnz     short SSDT_Dispatch     ; ECX=0 → SSDT
    ; SSSDT 路径
    mov     ecx, [esi+_ETHREAD.Tcb.Teb] ; 获取 TEB
    xor     esi, esi
    ...
```

### 描述符表内存布局 (WinDbg)

```windbg
0: kd> dd KeServiceDescriptorTable
841ac940  840a95f4 00000000 00000191 840a9c3c  ; SSDT: FuncTable, Counter, Count, ArgTable
841ac950  00000000 00000000 00000000 00000000
841ac960  00000011 00000100 5385d2ba d717548f
841ac970  00000000 00000000 00000210 00000000
841ac980  840a95f4 00000000 00000191 840a9c3c  ; SSSDT (Shadow[0] 同 SSDT)
841ac990  95a65000 00000000 00000339 95a6602c  ; SSSDT (Shadow[1] Win32k)
...
```

- **表项结构**：`[FunctionTable, CounterTable, ServiceLimit, ArgumentTable]`
- `ArgumentTable` 每项 1 字节，记录参数**字节数**（如 `0x10` = 16 字节 = 4 个 DWORD 参数）。

## 参数拷贝与内核函数调用

```asm
inc     large dword ptr fs:6B0h     ; KeSystemCalls++
mov     esi, edx                    ; ESI = 用户栈参数地址
xor     ecx, ecx
mov     edx, [edi+0Ch]              ; EDX = ArgumentTable 基址
mov     edi, [edi]                  ; EDI = FunctionTable 基址
mov     cl, [eax+edx]               ; CL = 参数字节数
mov     edx, [edi+eax*4]            ; EDX = 目标内核函数地址
sub     esp, ecx                    ; 在内核栈预留参数空间
shr     ecx, 2                      ; 参数个数 (DWORD 数)
mov     edi, esp                    ; EDI = 内核栈参数目标地址
cmp     esi, ds:_MmUserProbeAddress ; 确认用户地址合法
jnb     loc_435995
loc_435767:
rep movsd                           ; 拷贝参数：用户栈 → 内核栈
```

> **关键保护**：`_MmUserProbeAddress` (通常 `0x7FFF0000`) 限制用户地址上界，防止内核误读内核地址。

### 最终调用

```asm
mov     ecx, large fs:124h          ; ECX = 当前 ETHREAD
mov     edi, [esp]
mov     [ecx+_KTHREAD.SystemCallNumber], ebx
mov     [ecx+_KTHREAD.FirstArgument], edi
...
call    ebx                         ; 调用内核实体函数 (如 nt!NtOpenProcess)
```

调用返回后，`KiFastCallEntry` 继续执行返回用户态的恢复逻辑（`KiFastSystemCallRet`），此处不再展开。

## 进阶利用与研究方向（文章作者留存思路）

1. **GDT/IDT 劫持**  
   内核线程 `KPCR` 中记录 GDT/IDT 基址。若修改该基址指向攻击者控制的描述符表，能否实现“内核重载”式的隐蔽执行？

2. **`_KUSER_SHARED_DATA.SystemCall` 重定向**  
   无需 Hook SSDT，仅修改共享页 `SystemCall` 指向自定义分发器，即可全局拦截/过滤系统调用，且难以被常规 Rootkit 扫描器发现。

3. **`SystemCallReturn` 劫持**  
   修改返回地址指向自定义 `KiFastSystemCallRet`，可在系统调用返回时窃取/篡改返回值、寄存器、用户栈数据。

> 上述思路需结合内核写入漏洞（如 CVE-2021-1732、CVE-2020-0796 等）实现写入共享页，属于**后利用/持久化**阶段技术。

## 关键数据结构速查表

| 结构体 | 关键字段 | 作用 |
|--------|----------|------|
| `_KUSER_SHARED_DATA` | `SystemCall`, `SystemCallReturn` | 用户/内核共享页，决定系统调用入口方式 |
| `_KPCR` | `SelfPcr`, `TSS`, `GDT`, `IDT` | 每 CPU 内核控制区，FS 基址指向此处 |
| `_KTSS` | `Esp0` | Ring0 栈顶，`sysenter` 后 ESP 初值 |
| `_KTRAP_FRAME` | 完整用户态上下文 | `KiFastCallEntry` 构建，供内核异常/系统调用使用 |
| `_KTHREAD` / `_ETHREAD` | `ServiceTable`, `TrapFrame`, `PreviousMode` | 线程上下文，记录当前系统调用表、陷阱帧、调用者模式 |
| `KSERVICE_TABLE_DESCRIPTOR` | `ServiceTableBase`, `ServiceCounterTableBase`, `NumberOfServices`, `ArgumentTableBase` | SSDT/SSSDT 描述符，分发核心 |

## 参考与延伸阅读

- **Intel SDM Vol. 2A/2B** – `SYSENTER`/`SYSEXIT` 指令规范
- **Windows Internals, Part 1/2 (7th Ed.)** – Chapter 3 “System Mechanisms” / Chapter 13 “System Service Dispatching”
- **WRK (Windows Research Kernel) Source** – `base/ntos/ob/obopen.c`, `base/ntos/ke/i386/trap.asm`
- **《Windows Kernel Programming》** – Pavel Yosifovich, Chapter 8 “System Calls”
- **相关页面**：
  - [[linux-kernel-hardening-mechanisms]] – 对比 Linux `syscall`/`sysenter` 与缓解措施
  - [[ida-pro-tips-plugins-python]] – IDA 分析内核模块、定位 SSDT 的插件技巧
  - [[binary-ninja-ollvm-deobfuscation]] – 逆向混淆后的系统调用存根分析方法论
  - [[v8-issue-944062-gc-arbitrary-write]] – 浏览器沙箱逃逸中同样利用共享内存/用户态回调劫持思路

---

> **注**：本页面基于 32 位 Windows (x86) 环境分析；x64 环境下 `syscall` 替代 `sysenter`，参数通过寄存器 (`RCX, RDX, R8, R9`) 传递，`_KTRAP_FRAME` 结构亦有差异，核心分发逻辑 (SSDT/SSSDT) 保持一致。

## 来源

- [0x00实验室-202108-202304_004](../sources/0x00实验室-202108-202304_004.md)
