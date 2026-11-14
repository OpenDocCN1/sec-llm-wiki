---
title: .NET CLR 使用日志篡改技术实现 EDR 绕过
description: 深度解析 .NET CLR 使用日志的工作原理、四大规避手法（配置旋钮滥用、环境变量注入、进程强制终止、模块卸载）及防御检测思路，涵盖注册表键值篡改、COMPlus_
  环境变量继承、Process.Kill() 中断、DInvoke 卸载模块等实战技术细节。
category: program-analysis
tags:
- .NET
- CLR
- Usage Logs
- EDR Evasion
- Defense Evasion
- NGenAssemblyUsageLog
- COMPlus
- DInvoke
- FreeLibrary
- ETW
- Red Teaming
- DFIR
date: '2021-03-16'
updated: '2026-11-14'
---

## 概述

.NET 公共语言运行时 (CLR) 在托管程序集首次执行完成且进程**优雅退出**时，会在用户或系统配置目录下生成 **使用日志**，记录程序集模块信息供原生映像自动生成参考。端点检测与响应 (EDR) 解决方案常监控此类日志文件的创建事件，以识别异常进程加载 CLR（如 Cobalt Strike `execute-assembly`、非托管宿主注入等）。

本文系统梳理攻击者篡改/阻断 CLR 使用日志输出的四大核心手法，并给出相应的防御检测建议。

## CLR 使用日志基础

### 日志生成条件与路径

- **触发时机**：托管程序集执行结束，进程**正常退出**（隐式/显式 `return`、`Environment.Exit()`）。
- **典型路径**：
  - 用户上下文：`<SystemDrive>:\Users\<User>\AppData\Local\Microsoft\CLR_<Version>_(arch)\UsageLogs\<ProcessName>.log`
  - 系统上下文：`<SystemDrive>:\Windows\<System32|SysWOW64>\config\systemprofile\AppData\Local\Microsoft\CLR_<Version>_(arch)\UsageLogs\<ProcessName>.log`
- **取证价值**：可用于威胁狩猎、DFIR 溯源，识别非常规进程加载 CLR。

### 监控现状

- **Sysmon-Modular**（[@olafhartong](https://github.com/olafhartong/Sysmon-Modular)）提供针对 .NET 2.0 及高风险 LOLBIN 的使用日志监控规则。
- 商业 EDR 普遍部署同类文件创建/修改监控，捕获 `execute-assembly` 等红队常用技术。

## 规避手法一：滥用 CLR 配置旋钮（注册表）

### 原理

`NGenAssemblyUsageLog` 配置旋钮控制使用日志输出路径。将其设为任意无效字符串，CLR 会将该字符串拼接进硬编码路径后缀，导致路径不存在、日志写入失败。

### 实施路径

| 注册表配置单元 | 作用范围 | 影响日志目录 |
|----------------|----------|--------------|
| `HKCU\SOFTWARE\Microsoft\.NETFramework` | 当前用户 | `%LocalAppData%\Microsoft\CLR_<Version>_(arch)\UsageLogs` |
| `HKLM\SOFTWARE\Microsoft\.NETFramework` | 系统级 | `%Windir%\System32\config\systemprofile\AppData\Local\Microsoft\CLR_<Version>_(arch)\UsageLogs` |

### 实战示例

```cmd
reg add HKCU\SOFTWARE\Microsoft\.NETFramework /v NGenAssemblyUsageLog /t REG_SZ /d "invalid_path" /f
```

- CLR 内部硬编码路径后缀（可从 `clr.dll` 逆向提取），任意值均会导致目录不存在。
- 无需重启进程，即时生效。

### 关联技术

- 同类配置旋钮滥用：`ETWEnabled` 禁用 ETW ([[mimikatz-source-code-architecture-golden-ticket-audit]] 中涉及 ETW 绕过)、`GCName` 加载自定义 GC DLL 实现代码执行。
- `COR_PROFILER` 非托管探查器注入 ([[phantom-dll-hollowing-technique]] 模块隐藏思路同源)。

## 规避手法二：环境变量注入（COMPlus_ 前缀）

### 原理

CLR 启动时读取 `COMPlus_<ConfigKnob>` 格式环境变量，优先级高于注册表。通过父进程注入环境变量，使子进程继承并禁用日志。

### 实施方式

1. **命令行直接设置**：
   ```cmd
   set COMPlus_NGenAssemblyUsageLog=zzzz && powershell.exe
   ```
2. **代码注入子进程**（C# 示例）：
   ```csharp
   var psi = new ProcessStartInfo("powershell.exe") {
       EnvironmentVariables = { ["COMPlus_NGenAssemblyUsageLog"] = "zz" },
       UseShellExecute = false
   };
   Process.Start(psi);
   ```

### 特点

- **无磁盘落地**：仅内存环境块修改，注册表不变。
- **继承链隐蔽**：可通过多层进程链传递，难以静态审计。

## 规避手法三：强制进程终止中断日志写入

### 原理

使用日志仅在**优雅退出**时写入。调用 `Process.Kill()` / `TerminateProcess()` 可强制中断 CLR 关闭流程，导致日志缓冲区未刷盘。

### 代码片段

```csharp
// 托管代码主动自杀
Process.GetCurrentProcess().Kill();
// 或 P/Invoke TerminateProcess(GetCurrentProcess(), 0);
```

### 风险权衡

- **优势**：无需修改配置、环境变量，极简可靠。
- **劣势**：进程异常退出易触发 EDR 行为告警；可能丢失内存数据、导致 Shell 断连。

## 规避手法四：模块卸载破坏 CLR 稳定性

### 原理

通过 `FreeLibrary` 卸载关键 .NET 模块（`clr.dll`、`clrjit.dll`、`mscoreei.dll` 等），导致进程崩溃/提前退出，中断日志写入。

### 实施工具链

- **DInvoke** ([@TheRealWover](https://github.com/TheWover), [@FuzzySec](https://github.com/FuzzySec))：动态调用非托管 API，避免静态导入表暴露。
- **委托函数指针**：`GetDelegateForFunctionPointer` 将 `FreeLibrary` 地址转为可调用委托。

### 核心流程

```csharp
// 1. 获取 FreeLibrary 地址
IntPtr freeLibAddr = DInvoke.DynamicInvoke.Generic.GetLibraryAddress("kernel32.dll", "FreeLibrary");
var freeLib = (FreeLibraryDelegate)Marshal.GetDelegateForFunctionPointer(freeLibAddr, typeof(FreeLibraryDelegate));

// 2. 遍历 PEB LDR 模块列表，定位目标模块基址
foreach (var mod in targetModules) {
    IntPtr hMod = DInvoke.DynamicInvoke.Generic.GetPebLdrModuleEntry(mod);
    freeLib(hMod); // 卸载
}
```

### 效果

- 进程因关键模块缺失崩溃，CLR 无机会执行关闭例程。
- 同属 **无文件/内存隐藏** 高级利用手法，与 [[phantom-dll-hollowing-technique]]、[[pe-manual-mapping-loader-implementation]] 中的模块隐藏、手动映射思路一脉相承。

## 防御检测体系

### 文件层面监控

- **持续监控** UsageLogs 目录创建/修改/删除事件（Sysmon Event ID 11/26/23）。
- **基线规则**：参考 [Sysmon-Modular](https://github.com/olafhartong/Sysmon-Modular) 及 Elastic Security 规则集。
- **异常进程画像**：非托管宿主（`winword.exe`、`excel.exe`、`wmiprvse.exe`、`svchost.exe` 等）生成使用日志即为高危 IOC。

### 审计配置旋钮篡改

| 数据源 | 关键指标 | 参考规则 |
|--------|----------|----------|
| **注册表审计** (Event ID 4657, SACL) | `HKCU\Software\Microsoft\.NETFramework\NGenAssemblyUsageLog` 新增/修改 | [@Cyb3rWard0g](https://posts.specterops.io/detecting-etw-enabled-clr-configuration-knob-modifications) Sigma/YARA 规则可直接复用 |
| **环境变量** | 进程命令行含 `COMPlus_NGenAssemblyUsageLog`、WMI `Win32_Environment` 变更、PowerShell 转录日志 | 同 ETWEnabled 检测逻辑 |

### 进程/模块异常行为

- **模块卸载追踪**：ETW `Microsoft-Windows-Kernel-Process` 提供器可捕获 `Unload Image` 事件（[@spotheplanet](https://spotheplanet.github.io/) 博文详述）。
- **异常终止关联**：`Process.Kill()` 导致的进程退出码（0xC000013A / -1073741510）结合调用栈回溯。
- **CLR 加载异常**：监控非预期进程加载 `clr.dll`/`coreclr.dll`（[[windows-syscall-internals-sysenter-kifastcallentry]] 系统调用层面可关联 `LdrLoadDll` 监控）。

### 补偿性检测

- **行为关联**：使用日志缺失 + 进程网络连接/命令执行/内存注入等高危动作。
- **内存扫描**：结合 [[pe-manual-mapping-loader-implementation]] 思路，扫描无 PE 头、手动映射的模块。
- **威胁情报**：已知红队框架（Cobalt Strike、Sliver、Metasploit）的 `execute-assembly` 特征模式。

## 总结对比

| 手法 | 隐蔽性 | 稳定性 | 检测难度 | 典型场景 |
|------|--------|--------|----------|----------|
| 注册表配置旋钮 | 中（落地键值） | 高 | 低（审计成熟） | 持久化、横向移动前置准备 |
| 环境变量注入 | 高（仅内存） | 高 | 中（命令行/继承链审计） | 即时执行、子进程欺骗 |
| 强制终止 | 低（异常退出） | 高 | 低（行为告警敏感） | 紧急规避、一次性任务 |
| 模块卸载 | 高（内存操作） | 低（易崩溃） | 高（需 ETW/内核回调） | 高隐蔽需求、配合无文件加载器 |

## 交叉引用与延伸阅读

- [[pe-manual-mapping-loader-implementation]] — PE 手动映射、导入表修复、模块隐藏完整实现，理解 CLR 加载器层面对抗。
- [[phantom-dll-hollowing-technique]] — DLL Hollowing/Module Stomping 内存注入与隐藏，模块卸载思路同源。
- [[windows-syscall-internals-sysenter-kifastcallentry]] — 系统调用层监控 `LdrLoadDll`/`NtTerminateProcess` 等关键调用。
- [[windows-x86-stack-overflow-shellcode-execution]] — PEB 遍历、导出表解析、动态获取 API 地址基础技巧。
- [[pe-export-table-internals]] / [[pe-import-table-internals]] — 模块枚举与地址解析底层原理。
- [[reverse-engineering-beginner-learning-path]] — 逆向分析 CLR 内部结构（`clr.dll` 路径后缀提取）的入门路径。
- [[ida-pro-tips-plugins-python]] / [[binary-ninja-ollvm-deobfuscation]] — 逆向工具链辅助 CLR 组件静态分析。
- [[mimikatz-source-code-architecture-golden-ticket-audit]] — 红队工程化视角下的配置旋钮滥用（ETWEnabled/GCName/COR_PROFILER）。
- [[vulnhub-platform-resource-index]] — 实战靶场练习 EDR 绕过与日志审计对抗。

---

> **原文来源**：[Investigating .NET CLR Usage Log Tampering Techniques for EDR Evasion](https://bohops.com/2021/03/16/investigating-net-clr-usage-log-tampering-techniques-for-edr-evasion/) (bohops, 2021-03-16)  
> **归档日期**：2021-03-16  
> **分类**：program-analysis

## 来源

- [0x00实验室-202108-202304_030](../sources/0x00实验室-202108-202304_030.md)
