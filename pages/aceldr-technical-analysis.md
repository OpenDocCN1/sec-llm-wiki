---
title: PE内存执行技术谱系与反射式加载器对比分析
description: 系统梳理 PE 不落地执行技术的三大类别：反射式加载器（RDI、sRDI、Donut/pe2shc）、Section 相关技术（Process
  Doppelganging/Ghosting/Herpaderping）、镂空傀儡进程（Process Hollowing/Transacted Hollowing），深度解析各技术核心流程、PE
  Loader 关键实现细节（延迟导入表、API Set Schema、MEM_IMAGE 内存分配）及 Sysmon Event ID 25 检测对抗现状。
category: program-analysis
tags:
- PE Memory Execution
- Reflective DLL Injection
- RDI
- sRDI
- Donut
- pe2shc
- Process Hollowing
- Process Doppelganging
- Process Ghosting
- Process Herpaderping
- Transacted Hollowing
- PE Loader
- Delayed Import Table
- API Set Schema
- MEM_IMAGE
- Sysmon Event ID 25
- Defense Evasion
- Red Teaming
date: 2023-04-16
updated: '2026-11-15'
---

## 概述

本页面基于 0x4d5a 微信归档文章《关于PE不落地执行技术的思考》整理，系统构建 **PE 内存执行技术谱系**，重点关联 **RDI、sRDI、Donut/pe2shc 等主流反射式加载器**，补全用户态反射加载器对比视角。文章将 PE 不落地执行分为三大类：

1. **PE 加载器类**：常规 PE Loader、RDI、sRDI、pe2shellcode (Donut/pe2shc) —— 核心均为用户态 PE 解析与映射
2. **Section 相关类**：Process Doppelganging、Process Ghosting、Process Herpaderping —— 核心利用 TxF/DELETE_PENDING 创建 IMAGE Section
3. **镂空傀儡进程类**：Process Hollowing、Transacted Hollowing —— 复用进程创建流程，替换镜像内存

> 相关背景：用户态反射加载器（UDRL）是 Cobalt Strike Beacon 免杀对抗中的关键组件，详见 [[memory-scanning-tools-evasion-techniques]] 所整理的内存扫描工具体系与 UDRL 对抗全景。AceLdr 作为新一代 UDRL 的实现细节见 [[aceldr-technical-analysis]]。

---

## 一、反射式加载器技术谱系（PE Loader 类）

### 核心定位

> **原文**：“1.PE加载器：除了常规的PE加载器，还有RDI，sRDI和pe2shellcode (如Donut / pe2shc）等，它们的核心都是PE加载器。”

反射式加载器的本质是**在用户态完整实现 Windows Loader 的核心功能**：分配内存、映射节区、处理重定位、解析导入表（含延迟导入、API Set Schema）、执行 TLS 回调、转入入口点。其优势在于**无需落地 PE 文件、无需创建进程/线程即可执行代码**，是 Shellcode、Beacon、后利用框架的核心加载组件。

### 主流实现对比

| 加载器 | 形态 | 关键特性 | 典型场景 |
|--------|------|----------|----------|
| **RDI (Reflective DLL Injection)** | DLL 导出 `ReflectiveLoader` | Stephen Fewer 经典实现；DLL 自加载；支持 x86/x64 | Metasploit `exploit/windows/local/reflective_dll_injection`、Cobalt Strike 早期 Beacon |
| **sRDI (Shellcode Reflective DLL Injection)** | 纯 Shellcode | 将 RDI 编译为位置无关 Shellcode；剥离 DLL 头；通过 `CallReflectiveLoader` 入口 | Cobalt Strike `artifact kit`、CrossC2、Sliver 等框架 Payload 生成 |
| **Donut** | Shellcode 生成器 | 支持 .NET Assembly、PE 文件、VBScript/JS 转 Shellcode；内置 Changeling/Unmanaged CLR Hosting；支持 AMSI/ETW 绕过 | 红队武器化首选；`donut -f <payload> -o loader.bin` |
| **pe2shc / pe2shellcode** | PE→Shellcode 转换器 | 将任意 PE（EXE/DLL）重写为位置无关 Shellcode；保留原导出表/资源；支持压缩/加密 | 免杀二次开发；将 C/C++/Rust/Go 编译产物直接 Shellcode 化 |

> 技术渊源：RDI→sRDI 是“DLL 转 Shellcode”的标准化演进；Donut/pe2shc 进一步泛化为“任意 PE 转 Shellcode”，解决了 .NET、Go、Rust 等非传统 C/C++ 产物的内存执行问题。

### PE Loader 通用核心流程（原文 1.6 节）

```text
1. 为 PE Image 分配内存（VirtualAlloc / NtAllocateVirtualMemory）
2. 依次写入 PE 头与节区（按 SectionAlignment 对齐）
3. 处理重定位表（Base Relocation）
4. 处理导入表（Import Address Table）
5. 处理延迟导入表（Delay Import Table）← 关键补全点
6. 恢复节区 DEP 属性（PAGE_EXECUTE_READ / PAGE_READONLY 等）
7. 执行 TLS 回调（TLS Callback）
8. 执行 EntryPoint（AddressOfEntryPoint）
```

#### 关键工程化补全（原文 2.7 节）

| 细节 | 问题现象 | 解决方案 |
|------|----------|----------|
| **延迟导入表** | `MemoryModule` 等开源 Loader 未处理 → `cmd.exe` 等依赖 `cmdext.dll` 的程序无法运行 | 解析 `IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT`，按需 `LoadLibrary`+`GetProcAddress` 并回填 IAT |
| **API Set Schema** | 自实现 `GetProcAddress` 遇 `api-ms-win-core-*-l1-1-0` 虚拟 DLL 循环转发（如 `kernel32!InitializeProcThreadAttributeList` → `api-ms-win-core-processthreads-l1-1-0` → `kernel32`） | 指定 Base Module 解析虚拟 DLL 直接指向 `kernelbase`；或参考 `DarkLoadLibrary` 回退搜索 `kernel32/kernelbase/ntdll` 最终调用 `LdrGetProcedureAddress` |
| **MEM_IMAGE 内存分配** | `VirtualAlloc` 产生 `MEM_PRIVATE` 可执行内存，极易被内存扫描标记（如 `pe-sieve` `Implanted shc`、`moneta` `Abnormal private executable memory`） | 通过 `NtCreateSection` + `SEC_IMAGE` 映射合法镜像文件、或 `NtMapViewOfSection` 伪装模块，使内存呈现 `MEM_IMAGE` 属性 |

> 相关实现参考：[[pe-manual-mapping-loader-implementation]] 从零构建手动映射加载器全流程，含导入表修复、重定位、延迟导入、API Set Schema、MEM_IMAGE 伪装等工程化细节。

---

## 二、Section 相关技术（TxF / DELETE_PENDING 创建 IMAGE Section）

三大技术共同核心：**不落地/近似不落地创建合法 IMAGE Section，再通过 `NtCreateProcessEx` 直接由内核完成映射、重定位、导入表解析、主线程创建**，省去用户态 Loader 代码。

### Process Doppelganging（TxF 事务）

**流程**（原文 1.2 节）：
1. `CreateTransaction` 创建 NTFS 事务
2. 事务内创建/覆写文件，写入 Payload PE
3. 文件句柄传给 `NtCreateSection(SEC_IMAGE)` 创建 IMAGE Section
4. 关闭文件句柄
5. `RollbackTransaction` 回滚事务 → 磁盘无文件残留
6. `NtCreateProcessEx` 通过 Section 创建进程
7. 写入 PEB `ProcessParameters` 与 `Environment`
8. 创建主线程

**特点**：**真正不落地**（ProcMon 无文件创建/写入事件）；**无需手动重定位/导入表**；但创建进程**异常**（任务管理器进程名不符、Process Hacker 显示源文件不存在）。

### Process Ghosting（DELETE_PENDING）

**流程**（原文 1.3 节）：
1. 创建文件
2. `SetFileInformation(FILE_DISPOSITION_INFORMATION.DeleteFile=TRUE)` 标记删除待定
3. 写入 Payload PE
4. 文件句柄创建 IMAGE Section
5. 关闭句柄 → 文件物理删除
6. `NtCreateProcessEx` 创建进程
7. 写入 PEB 参数
8. 创建主线程

**特点**：**近似不落地**（内核层监控仍可见写文件行为）；同样享受内核自动重定位/导入表；进程异常特征同 Doppelganging。

> Windows 删除文件两种方式（原文脚注 [1][2]）：`FILE_DELETE_ON_CLOSE` 创建时指定、或句柄设置 `FILE_DISPOSITION_INFORMATION`。`DeleteFileW` 最终调用后者。

### Process Herpaderping

原文 1.4 节略过，实为 **Doppelganging/Ghosting 变体**：创建 Section 后、创建进程前，覆写/截断源文件内容，使磁盘文件与内存镜像不一致。核心利用点相同：**IMAGE Section 创建瞬间锁定镜像内容，后续文件变更不影响已创建 Section**。

---

## 三、镂空傀儡进程技术（Process Hollowing / Transacted Hollowing）

### Process Hollowing（经典镂空）

**流程**（原文 1.1 节）：
1. `CREATE_SUSPENDED` 创建傀儡进程
2. （可选）`NtUnmapViewOfSection` 卸载原镜像
3. 写入 Payload PE 头
4. 按节区写入并展开（手动做 Section Alignment → File Alignment 转换）
5. **手动处理重定位表**（因主线程未运行，系统 Loader 尚未处理）
6. 修改 PEB `ImageBaseAddress`
8. 修改主线程 Context `RIP/EIP` → OEP
9. `NtResumeThread` 恢复执行

**核心洞察**（原文 2.1 节）：**系统 Loader 处理导入表、重定位发生在主线程恢复之后**（挂起进程仅加载自身 + ntdll），故镂空时**必须手动重定位，但无需处理导入表**——恢复后由系统完成。

> 推测机制：APC 或进程挂靠机制延迟执行 Loader 收尾工作。

### Transacted Hollowing（混合最优解）

**流程**（原文 1.5 节）：
1. TxF 事务内创建文件、写 Payload
2. 文件句柄创建 IMAGE Section
3. 关闭句柄、回滚事务
4. 创建挂起傀儡进程
5. `NtMapViewOfSection` 将 IMAGE Section 映射入傀儡进程
6. 修改 PEB `ImageBaseAddress`
7. 修改主线程 OEP
8. 恢复主线程

**优势融合**（原文 2.5 节表格）：

| 维度 | Process Hollowing | Process Doppelganging | Transacted Hollowing |
|------|-------------------|-----------------------|----------------------|
| 重定位 | 手动 | **内核自动**（映射 IMAGE Section 触发） | **内核自动** |
| PEB 处理 | 仅改 ImageBase | 需重建 ProcessParameters/Environment | 仅改 ImageBase |
| 内存属性 | `MEM_PRIVATE` | `MEM_IMAGE` | **`MEM_IMAGE`** |
| 进程外观 | 正常傀儡进程 | **异常**（名字/路径不符） | **正常傀儡进程** |
| 落地性 | 无 | 真不落地 | 真不落地 |

**关键机制**：`NtMapViewOfSection` 映射 IMAGE Section 时尝试按 `ImageBase` 映射，失败返回 `STATUS_IMAGE_NOT_AT_BASE` 并标记，**主线程恢复后内核自动重定位**；且映射内存为 `MEM_IMAGE`，规避 `MEM_PRIVATE` 可执行内存检测。

---

## 四、Sysmon Event ID 25 (Process Tampering) 检测对抗现状

原文 2.6 节实测结论：

- **检测覆盖**：Process Hollowing、Doppelganging、Ghosting、Herpaderping 均被检出
- **盲区**：**Transacted Hollowing 目前无法检测**

**Sysmon 官方定义两类检测**：
1. `Image is locked for access` —— 文件被锁定无法读取哈希
2. `Image is replaced` —— 内存镜像与磁盘文件不一致

**为何 Transacted Hollowing 逃逸**：TxF 回滚后磁盘**根本不存在源文件**，无“替换”可言；傀儡进程本身合法，内存镜像来自事务内 Section，与磁盘无可比对对象。属**高可用规避技术**。

> 防御视角参考：[[windows-kernel-callback-injection-defense]] 利用 `ObRegisterCallbacks` 拦截进程句柄创建/复制，从内核层面阻断镂空操作。

---

## 五、技术谱系总结与选型建议

| 需求场景 | 推荐技术 | 核心理由 |
|----------|----------|----------|
| **纯内存执行 Shellcode/Beacon，无进程创建** | **sRDI / Donut / pe2shc** | 无进程树异常、无线程注入、配合 UDRL（AceLdr/Ekko/FOLIAGE）做睡眠混淆、堆加密、调用栈欺骗 |
| **需落地可执行文件伪装（签名、路径、进程名）** | **Transacted Hollowing** | 真不落地 + `MEM_IMAGE` + 正常傀儡进程外观 + 免手动重定位/导入表 + 绕过 Sysmon Event ID 25 |
| **需利用合法签名二进制（Living-off-the-land）** | **Process Hollowing** | 成熟稳定、工具链丰富（Cobalt Strike `spawnto`、Sliver `hollow`），但需手动重定位、内存为 `MEM_PRIVATE` |
| **.NET Assembly / 非传统语言产物内存执行** | **Donut** | 内置 CLR Hosting、支持 AMSI/ETW 绕过、输出纯 Shellcode 可接 UDRL |
| **红队武器化二次开发（C/Rust/Go 编译产物 Shellcode 化）** | **pe2shc** | 保留导出表/资源、支持压缩加密、直接产出位置无关 Shellcode |

---

## 六、交叉引用与延伸阅读

- [[aceldr-technical-analysis]] —— AceLdr 四大核心规避技术（Sleep_Hook/Heap_Hook/Return Address Spoofing/动态内存加密）实测对抗 moneta/pe-sieve
- [[memory-scanning-tools-evasion-techniques]] —— 七大主流内存扫描工具检测原理全景与 UDRL 对抗技术谱系
- [[pe-manual-mapping-loader-implementation]] —— PE 手动映射加载器全流程实现（导入表/重定位/延迟导入/API Set Schema/MEM_IMAGE 伪装）
- [[process-injection-tampering-techniques]] —— Process Hollowing/Doppelganging/Ghosting/Herpaderping/Transacted Hollowing 五大技术原理对比与 Sysmon Event ID 25 检测规避
- [[phantom-dll-hollowing-technique]] —— Phantom DLL Hollowing 合法模块内存劫持隐藏技术，替代方案参考
- [[cobalt-strike-external-c2-smb-beacon]] —— SMB Beacon 与 External C2 通信模型，结合反射加载器实战落地
- [[windows-kernel-callback-injection-defense]] —— 内核回调拦截进程注入/镂空的蓝队防御实现

---

## 七、参考资料（文中引用锚点）

1. 原文：http://mp.weixin.qq.com/s?__biz=Mzg5MjU2NTc1Mg==&mid=2247483721&idx=1&sn=5ce84fc04adbedce1a40a348d28e7a10  
2. Windows删除文件两种方法：https://www.osronline.com/article.cfm^article=245.htm  
3. ReactOS DeleteFileW 实现：https://doxygen.reactos.org/dd/db0/dll_2win32_2kernel32_2client_2file_2delete_8c.html#a6ef6fb74f843f5a3a7ce135d57411806  
4. Transacted Hollowing 结合双方优势：https://blog.malwarebytes.com/threat-analysis/2018/08/process-doppelganging-meets-process-hollowing_osiris/  
5. Sysmon Event ID 25 Process Tampering：https://docs.microsoft.com/en-us/sysinternals/downloads/sysmon#event-id-25-processtampering-process-image-change  
6. API Set Schema 解析：https://lucasg.github.io/2017/10/15/Api-set-resolution/  
7. DarkLoadLibrary 回退搜索实现：https://github.com/bats3c/DarkLoadLibrary/blob/master/DarkLoadLibrary/src/pebutils.c#L413

## 来源

- [0x4d5a-202103-202209_05](../sources/0x4d5a-202103-202209_05.md)
- [0x4d5a-202103-202209_09](../sources/0x4d5a-202103-202209_09.md)
