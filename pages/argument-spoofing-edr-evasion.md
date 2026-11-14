---
title: 'Argument Spoofing EX: EDR进程创建监控对抗技术'
description: 深度解析Argument Spoofing技巧对抗EDR进程创建监控，通过分离Image与CommandLine实现命令行混淆绕过，包含PsSetCreateProcessNotifyRoutineEx回调机制、Sysmon
  Event ID 1监控字段、cmd双引号混淆原理、CreateProcess/NtCreateUserProcess底层调用差异、PEB中RTL_USER_PROCESS_PARAMETERS结构利用，以及Cobalt
  Strike argue命令的增强实现。
category: program-analysis
tags:
- Argument Spoofing
- EDR Evasion
- Process Creation Monitoring
- PsSetCreateProcessNotifyRoutineEx
- Sysmon
- Command Line Obfuscation
- NtCreateUserProcess
- PEB
- RTL_USER_PROCESS_PARAMETERS
- Cobalt Strike
- Red Teaming
- Defense Evasion
date: 2022-06-14
updated: '2026-11-15'
---

## 概述

Argument Spoofing（参数欺骗）是终端对抗中的常见技巧，本文系统记录该技术对抗 EDR 进程创建监控的核心原理与实现细节。通过分离进程镜像路径与命令行参数，利用 Windows 进程创建底层机制差异，实现命令行混淆绕过 EDR 基于命令行的恶意行为判断。

## EDR 进程创建监控机制

### 内核回调：PsSetCreateProcessNotifyRoutineEx

64 位系统上 Patch Guard 限制了 EDR 在内核层面的能力，但微软提供了 `PsSetCreateProcessNotifyRoutineEx` API，EDR 可注册回调函数监控进程创建。回调函数接收 `PS_CREATE_NOTIFY_INFO` 结构体，关键字段如下：

```c
typedef struct _PS_CREATE_NOTIFY_INFO {
    SIZE_T              Size;
    union {
        ULONG Flags;
        struct {
            ULONG FileOpenNameAvailable : 1;
            ULONG IsSubsystemProcess : 1;
            ULONG Reserved : 30;
        };
    };
    HANDLE              ParentProcessId;
    CLIENT_ID           CreatingThreadId;
    struct _FILE_OBJECT *FileObject;
    PCUNICODE_STRING    ImageFileName;   // 进程镜像路径
    PCUNICODE_STRING    CommandLine;     // 命令行参数
    NTSTATUS            CreationStatus;
} PS_CREATE_NOTIFY_INFO, *PPS_CREATE_NOTIFY_INFO;
```

EDR 可依据 `ImageFileName`、`CommandLine`、哈希值、PID 等字段判断进程是否恶意。其中 **CommandLine 最直观反映攻击者意图**（如 `net user /add`）。

### Sysmon Event ID 1 记录字段

以 Sysmon 为例，其 EVENT ID 1 通过 ETW 记录进程创建详细信息，核心字段包括：

- `Image`：可执行文件完整路径
- `CommandLine`：完整命令行字符串
- `ParentImage` / `ParentCommandLine`：父进程信息
- `Hashes`：MD5/SHA256 文件哈希
- `ProcessGuid` / `ParentProcessGuid`：进程唯一标识
- `IntegrityLevel` / `LogonId` / `SessionId`：安全上下文

> **交叉引用**：内存扫描与规避技术体系详见 [[memory-scanning-tools-evasion-techniques]]；Cobalt Strike Beacon 睡眠钩子与堆钩子规避详见 [[aceldr-technical-analysis]]。

## cmd 命令行混淆局限性

### Shell 层面混淆无效

常见混淆基于 `cmd /c` 后的命令拼接，如 `ne^t user`。但经 `cmd.exe` 解释后，内核回调看到的已是解析后的纯净命令行。特殊符号 `( ) & ^ ;` 均会被 `cmd` 解释消除，**唯独双引号 (`"`) 会被原封不动传递给子进程**。

### 双引号混淆实测

执行 `ne""t1 u""ser`，Sysmon 记录的 `CommandLine` 为 `ne""t1  u""ser`。若子进程通过 `CommandLineToArgvW` 或 CRT (`__argv`/`argv`) 解析命令行，可正确还原参数：

```c
// 测试代码片段
wprintf(L"GetCommandLineW: %s\n", GetCommandLineW());
for (int i = 0; i < __argc; i++) wprintf(L"crt __argv %d: %s\n", i, __wargv[i]);
int _argc = 0;
wchar_t** _argv = CommandLineToArgvW(GetCommandLineW(), &_argc);
for (int i = 0; i < _argc; i++) wprintf(L"CommandLineToArgvW %d: %s\n", i, _argv[i]);
```

输出示例：
```
GetCommandLineW: Wtest.exe  a""aa bb""b cc""c
crt __argv 1: aaa
crt __argv 2: bbb
crt __argv 3: ccc
CommandLineToArgvW 1: aaa
CommandLineToArgvW 2: bbb
CommandLineToArgvW 3: ccc
```

> **注意**：`wmic`、`notepad` 等不使用标准解析器的程序无法正确处理。

### cmd 处理流程推测

1. 输入 `net1 user`
2. 解释 `^ & ;` 等特殊符号
3. `CommandLineToArgvW` 解析（双引号被解析消除）
4. 通过环境变量查找 `Image` 绝对路径（如 `C:\Windows\System32\net1.exe`）
5. 创建进程，**设置命令行为步骤 2 解析后的字符串（保留双引号）**

## 创建 Image 与 CommandLine 不一致的进程

### CreateProcess 直接调用失败

模拟 `cmd` 行为尝试 `CreateProcessW(NULL, L"n\"\"et1 user", ...)` 返回 **Error Code 2**（文件未找到）。逆向发现 `NtCreateUserProcess` 通过 `AttributeList` 中的 `PS_ATTRIBUTE_IMAGE_NAME` 指定 Image，而 `ImagePath` 与 `CommandLine` 通过 `RTL_USER_PROCESS_PARAMETERS` 传递，**二者在 PEB 中无必然绑定关系**。

### 正确姿势：指定 ApplicationName

`CreateProcessW` 的 `lpApplicationName` 参数对应 `PS_ATTRIBUTE_IMAGE_NAME`，需传入绝对路径：

```c
STARTUPINFOW si = { 0 };
PROCESS_INFORMATION pi = { 0 };
WCHAR cmdline[] = L"a us\"\"er";
if (!CreateProcessW(L"C:\\Windows\\System32\\net1.exe", cmdline, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
    wprintf(L"%d\n", GetLastError());
    return -1;
}
```

此时进程 `Image` 为 `C:\Windows\System32\net1.exe`，但 `CommandLine` 为 `a us""er`，实现 **Image 与命令行完全分离**。

> **交叉引用**：PE 手动映射加载器中导入表修复与 PEB 操作详见 [[pe-manual-mapping-loader-implementation]]；Windows 系统调用流程与 KiFastCallEntry 详见 [[windows-syscall-internals-sysenter-kifastcallentry]]。

## Argument Spoofing EX：增强版实现

### Cobalt Strike argue 命令局限

CS `argue` 命令[[1]](#references) 仅能混淆 `argv[1...n]`，无法修改 `argv[0]`（即程序名），表现为 `net1 AAAAAAAAA`。

### 全命令行混淆实现

利用上述 `CreateProcessW` 指定 `ApplicationName` + 自定义 `CommandLine`，**可实现 `argv[0]` 至 `argv[n]` 全混淆**：

![Argument Spoofing 效果图](../Images/083c4e74cbfb3397ebd1038d0e071f65.png)

### 优化点：免 PEB 修改

触碰其他进程 PEB 属敏感行为（易被 EDR 检测）。**若无需传递实参**，可将 `malware.exe` 直接混淆为受信路径（如 `C:/path/to/trusted/process`），**无需挂起进程修改 PEB**，因绝大多数程序不依赖 `argv[0]` 值。

> **交叉引用**：Cobalt Strike 4.7 BOF 内部实现与动态函数槽位限制详见 [[cobalt-strike-4.7-bof-internals]]；.NET CLR 使用日志篡改规避详见 [[dotnet-clr-usage-log-tampering-edr-evasion]]；内核回调拦截进程注入防御详见 [[windows-kernel-callback-injection-defense]]。

## 核心数据结构对照

| 结构体/机制 | 作用 | 关键字段 |
|-------------|------|----------|
| `PS_CREATE_NOTIFY_INFO` | 内核回调通知结构 | `ImageFileName`, `CommandLine`, `ParentProcessId` |
| `RTL_USER_PROCESS_PARAMETERS` | PEB 中进程参数块 | `ImagePathName`, `CommandLine`, `CurrentDirectory` |
| `PS_ATTRIBUTE_IMAGE_NAME` | `NtCreateUserProcess` 属性项 | 指定进程镜像路径（对应 `CreateProcess` 的 `lpApplicationName`） |
| `CommandLineToArgvW` | 标准命令行解析 API | 正确处理双引号转义，还原参数数组 |

## 实战检测与对抗视角

### 蓝队检测思路
1. **关联 Image 与 CommandLine 不一致**：如 `Image: net1.exe` 但 `CommandLine: a us""er`
2. **监控 `PS_ATTRIBUTE_IMAGE_NAME` 显式指定**：非标准启动路径
3. **命令行熵值/特殊字符统计**：双引号成对出现但非标准路径格式
4. **父子进程上下文关联**：`cmd.exe` 非直接父进程时的异常启动

### 红队规避建议
- 优先使用受信签名程序路径作为 `ApplicationName`
- `CommandLine` 模拟合法调用格式（如带路径参数的系统工具调用）
- 结合 [[phantom-dll-hollowing-technique]] 类内存注入技术减少磁盘落地
- 利用 [[cobalt-strike-external-c2-smb-beacon]] 等 C2 通道隐匿通信流量

## 参考资料

<a id="references">[1]</a> **Cobalt Strike argue 命令实现分析**：<https://blog.xpnsec.com/how-to-argue-like-cobalt-strike/>

## 相关技术页面

- [[memory-scanning-tools-evasion-techniques]] - 内存扫描工具检测原理与 UDRL 规避技术体系
- [[aceldr-technical-analysis]] - AceLdr 反射加载器四大核心规避技术深度解析
- [[cobalt-strike-4.7-bof-internals]] - Cobalt Strike 4.7 BOF 加载器内部实现细节
- [[dotnet-clr-usage-log-tampering-edr-evasion]] - .NET CLR 使用日志篡改规避四大手法
- [[windows-kernel-callback-injection-defense]] - 内核回调拦截进程注入防御原理与实现
- [[pe-manual-mapping-loader-implementation]] - PE 手动映射加载器全流程实现（含 PEB 操作）
- [[phantom-dll-hollowing-technique]] - Phantom DLL Hollowing 内存注入与模块伪装技术
- [[cobalt-strike-external-c2-smb-beacon]] - Cobalt Strike SMB Beacon 与 External C2 通信模型
- [[windows-syscall-internals-sysenter-kifastcallentry]] - Windows 系统调用全链路剖析
- [[named-pipe-smb-detection-sysmon]] - Sysmon Event ID 17/18 命名管道检测策略

## 来源

- [0x4d5a-202103-202209_07](../sources/0x4d5a-202103-202209_07.md)
