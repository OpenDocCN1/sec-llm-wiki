---
title: PPLDump用户态绕过PPL保护与对抗内存扫描技术详解
description: 深度解析PPLDump利用DefineDosDevice/KnownDLLs漏洞绕过PPL保护转储LSASS，以及将恶意代码注入Antimalware/WinTcb级PPL进程对抗内存扫描的实战技术链
category: program-analysis
tags:
- PPL
- Protected Process Light
- PPLDump
- DefineDosDevice
- KnownDLLs
- LSASS Dump
- Memory Scanning Evasion
- Antimalware
- WinTcb
- Userland Exploit
- Red Teaming
- Windows Internals
date: 2021-04-22
updated: '2026-11-15'
---
## 概述

本页面系统梳理 **PPLDump** 项目实现的两大核心攻击场景：

1. **绕过 PPL 保护**：利用 `DefineDosDevice` 在用户态劫持 `KnownDLLs` 目录，将恶意 DLL 注入受保护进程（如 `services.exe`），从而在该进程上下文中打开并转储开启 `RunAsPPL` 的 LSASS 进程内存。
2. **利用 PPL 对抗内存扫描**：将 Shellcode 注入 `MsMpEng.exe` (Antimalware-Light) 或 `wininit.exe` (WinTcb-Light) 等高签名等级 PPL 进程，利用内核拒绝非同级或更高级进程访问的特性，躲避 AV/EDR 的用户态内存扫描。

两种手法均基于 **@itm4n** 的 [PPLDump](https://github.com/itm4n/PPLdump) 项目，漏洞细节参考其博客 [Bypassing LSA Protection in Userland](https://blog.scrt.ch/2021/04/22/bypassing-lsa-protection-in-userland/)。

---

## PPL 机制核心原理

### 保护类型与签名等级

Windows 8.1+ 引入 **Protected Process Light (PPL)**，在 `EPROCESS` 中通过 `Protection` 字段记录：

| 字段 | 含义 |
|------|------|
| `PsProtectedType` | `None (0)` / `ProtectedLight (1)` / `Protected (2)` |
| `PsProtectedSigner` | `None (0)` `Authenticode (1)` `CodeGen (2)` `Antimalware (3)` `Lsa (4)` `Windows (5)` `WinTcb (6)` `WinSystem (7)` `App (8)` |

常见组合十六进制值：
- `PS_PROTECTED_SYSTEM` = `0x72` (WinSystem, PP)
- `PS_PROTECTED_WINTCB` = `0x62` (WinTcb, PP)
- `PS_PROTECTED_WINTCB_LIGHT` = `0x61` (WinTcb, PPL) —— **Ring3 最高**
- `PS_PROTECTED_WINDOWS` = `0x52`
- `PS_PROTECTED_WINDOWS_LIGHT` = `0x51`
- `PS_PROTECTED_LSA_LIGHT` = `0x41` (LSASS RunAsPPL)
- `PS_PROTECTED_ANTIMALWARE_LIGHT` = `0x31` (Windows Defender `MsMpEng.exe`)

### 访问规则

1. **PP 始终高于 PPL**：受保护进程 (PP) 可访问 PPL，反之不可。
2. **同类型比较 Signer**：`Signer` 等级高或相等的进程可打开低等级进程句柄（需 `SeDebugPrivilege`）。
3. **无保护进程无法访问 PP/PPL**：普通管理员进程无法以 `PROCESS_VM_READ | PROCESS_QUERY_INFORMATION` 打开 LSASS (Lsa-Light)。

> 这就是为何 `procdump` / `mimikatz` 在 `RunAsPPL=1` 时返回 `Access Denied`。

---

## 绕过 PPL：PPLDump 漏洞利用链

### 攻击面：`DefineDosDevice` + `KnownDLLs` 劫持

`KnownDLLs` 目录 (`\KnownDlls`) 存储 **Section 对象**，系统加载 DLL 时优先查找此目录。若能在此植入恶意 Section，后续启动的受保护进程会映射攻击者控制的镜像。

PPLDump 利用 **CSRSS 处理 `DefineDosDevice` RPC 时未正确 Impersonate** 的逻辑缺陷，在 SYSTEM 上下文中创建伪造 `\GLOBAL??\KnownDlls` 目录及符号链接。

### 利用步骤 (Exploit Flow)

1. **提升至 SYSTEM** (如 `GetSystem` / Token 窃取)，以便在 `\GLOBAL??` 创建对象。
2. **创建伪造目录** `\GLOBAL??\KnownDlls` 及符号链接 `\GLOBAL??\KnownDlls\FOO.dll` → 指向恶意 DLL 的 Section。
3. **降权回管理员上下文**。
4. **在当前用户 DOS 设备目录创建符号链接** `GLOBALROOT` → `\GLOBAL??` (必须非 SYSTEM，否则落入真实 `\GLOBAL??\GLOBALROOT`)。
5. **调用 `DefineDosDevice(..., "GLOBALROOT\KnownDlls\FOO.dll", <恶意DLL路径>)`**  
   - CSRSS (SYSTEM) 解析路径：`\??\GLOBALROOT\KnownDlls\FOO.dll` → `\GLOBAL??\GLOBALROOT\KnownDlls\FOO.dll` → `\KnownDlls\FOO.dll`  
   - 因未 Impersonate，实际在 SYSTEM 上下文操作真实 `\KnownDlls`，完成劫持。
6. **触发受保护进程加载** (如启动 `services.exe` / `WinTcb-Light`)，其映射劫持后的 `EventAggregation.dll` 等 KnownDLL。
7. **在受保护进程上下文执行代码**，继而以同等级权限 `OpenProcess` 目标 PPL (如 LSASS) 并 `ReadProcessMemory` 转储内存。

### 关键点图解

```text
攻击者 (Admin)                          CSRSS (SYSTEM)
    │                                      │
    ├── Create \GLOBAL??\KnownDlls         │
    ├── Create \GLOBAL??\KnownDlls\FOO.dll │
    │                                      │
    ├── RevertToSelf()                     │
    ├── Create \??\GLOBALROOT -> \GLOBAL?? │
    │                                      │
    └── DefineDosDevice("GLOBALROOT\KnownDlls\FOO.dll", malicious.dll)
                                           │
                                           ├── 解析 \??\GLOBALROOT\KnownDlls\FOO.dll
                                           │     → \GLOBAL??\GLOBALROOT\KnownDlls\FOO.dll
                                           │     → \KnownDlls\FOO.dll  (真实目录!)
                                           │
                                           └── 以 SYSTEM 写入真实 \KnownDlls 劫持成功
```

> **无文件落地变体**：结合 [Process Doppelgänging / Ghosting]([[process-injection-tampering-techniques]]) 技术，通过 `TxF` 事务 + `NtCreateSection` 在内存中构建恶意 Section，避免 DLL 落盘。

---

## 利用 PPL 对抗内存扫描：高签名进程注入

### 核心思路

AV/EDR 常通过用户态 API (`OpenProcess` + `ReadProcessMemory` / `VirtualQueryEx` / `EnumProcessModulesEx`) 扫描可疑内存区域。内核拒绝**低签名等级**进程打开**高签名 PPL** 句柄，因此将 Shellcode 注入 `Antimalware-Light` 或 `WinTcb-Light` 进程可天然规避用户态扫描器。

| 目标进程 | PPL 等级 | 签名等级 | 典型用途 |
|----------|----------|----------|----------|
| `MsMpEng.exe` | `Antimalware-Light (0x31)` | 3 | Windows Defender 核心服务 |
| `wininit.exe` | `WinTcb-Light (0x61)` | 6 (Ring3 最高) | 关键系统初始化进程 |

### 实战注入流程 (PPLDump 实现)

1. 利用上述 **KnownDLLs 劫持** 将恶意 DLL 注入 `services.exe` (WinTcb-Light)。
2. 在 `services.exe` 上下文中 `OpenProcess` 目标 PPL (`MsMpEng.exe` / `wininit.exe`) 获取 `PROCESS_ALL_ACCESS`。
3. 分配 RWX 内存 (`VirtualAllocEx`)、写入 Shellcode (`WriteProcessMemory`)、创建远程线程 (`CreateRemoteThread` / `NtCreateThreadEx`) 执行。

### 实测限制与绕过

| 场景 | 现象 | 原因分析 | 绕过方案 |
|------|------|----------|----------|
| Shellcode 中调用 `CreateProcess` | 返回 `ERROR_INVALID_PARAMETER (87)` | PPL 进程创建子进程需 `bInheritHandles=FALSE`，Cobalt Strike Beacon 默认 `TRUE` 导致管道继承冲突 | 使用 **BOF** 替代 Beacon 内置 `CreateProcess`，显式设置 `bInheritHandles=FALSE` 或改用文件落地输出 [[ppl-injection-createprocess-bof-fix]] |
| 内存扫描器枚举模块/线程 | 仍可被内核回调/ETW 发现 | 用户态隐匿不代表内核不可见 | 结合 [UDRL]([[aceldr-technical-analysis]]) / [FOLIAGE]([[memory-scanning-tools-evasion-techniques]]) / [Ekko]([[memory-scanning-tools-evasion-techniques]]) 等内存加密/隐藏技术 |

> **注**：Win10 21H1 实测 `MsMpEng.exe` 与 `wininit.exe` 均可成功注入 Shellcode 并执行文件系统操作，但原生 Beacon 命令 (需 `CreateProcess`) 受限于上述 `bInheritHandles` 问题。

---

## 关联技术与交叉引用

| 技术领域 | 相关页面 | 关联点 |
|----------|----------|--------|
| PPL 注入与 CreateProcess 绕过 | [[ppl-injection-createprocess-bof-fix]] | `bInheritHandles=FALSE`、BOF 文件落地输出、WinTcb-Light 注入实战 |
| Token Nerfing 与 PPLGuard | [[windows-token-nerfing-pplguard-trusted-labels]] | PPL 令牌保护缺口、Trusted Labels (SACL) 缓解、同源 CreateProcess 87 错误分析 |
| 内存扫描对抗工具体系 | [[memory-scanning-tools-evasion-techniques]] | Hunt-Sleeping-Beacons / BeaconHunter / patriot / moneta / pe-sieve / MalMemDetect 检测原理与 UDRL 对抗 |
| Cobalt Strike BOF 内部实现 | [[cobalt-strike-4.7-bof-internals]] | BOF 加载器、Relocation 处理、Sleep Kit、PPL 场景下的句柄继承问题 |
| 进程注入/篡改技术谱系 | [[process-injection-tampering-techniques]] | Hollowing / Doppelgänging / Ghosting / Herpaderping / Transacted Hollowing 对比 |
| PE 手工映射与不落地执行 | [[aceldr-technical-analysis]]、[[pe-manual-mapping-loader-implementation]] | 反射式加载、Section 构造、KnownDLLs 劫持的无文件变体实现基础 |
| 命令行欺骗与参数分离 | [[argument-spoofing-edr-evasion]] | 同属 EDR 规避维度，可结合 PPL 注入隐藏命令行特征 |

---

## 检测与缓解建议

1. **KnownDLLs 完整性监控**  
   - 内核回调监控 `\KnownDlls` 目录对象创建/修改 (需签名驱动)。
   - 审计 `DefineDosDevice` 调用 (ETW `Microsoft-Windows-Kernel-Object` / Sysmon Event ID 12/13)。

2. **PPL 进程异常模块/线程告警**  
   - 定期枚举 `Antimalware-Light` / `WinTcb-Light` 进程的 `PPEB->Ldr` 与线程列表，对比已知基线。
   - 结合 **内核回调** (`PsSetCreateThreadNotifyRoutine` / `PsSetLoadImageNotifyRoutine`) 捕获非法注入。

3. **启用 PPLGuard / Trusted Labels** (Win11 22H2+)  
   - 通过 SACL 保护 AntiMalware PPL 令牌防篡改 [[windows-token-nerfing-pplguard-trusted-labels]]。

4. **内存扫描器部署**  
   - 部署 [patriot]([[memory-scanning-tools-evasion-techniques]]) / [Moneta]([[memory-scanning-tools-evasion-techniques]]) 等内核/用户态混合扫描器，检测 RWX、非签名镜像、PE 结构异常。

---

## 参考资料

1. **PPLDump** - https://github.com/itm4n/PPLdump  
2. **Bypassing LSA Protection in Userland** - https://blog.scrt.ch/2021/04/22/bypassing-lsa-protection-in-userland/  
3. **Microsoft Docs: Protected Processes** - https://learn.microsoft.com/windows/win32/procthread/protected-processes  
4. **Elastic Security: PPLGuard - Protecting AntiMalware PPLs** - https://www.elastic.co/security-labs/pplguard-protecting-antimalware-ppls  
5. **Cobalt Strike 4.7 BOF Internals** - [[cobalt-strike-4.7-bof-internals]]  
6. **PPL Injection CreateProcess BOF Fix** - [[ppl-injection-createprocess-bof-fix]]

## 来源

- [0x4d5a-202103-202209_11](../sources/0x4d5a-202103-202209_11.md)
