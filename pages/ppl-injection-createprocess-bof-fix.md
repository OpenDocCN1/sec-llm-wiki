---
title: PPL注入后CreateProcess失败根因分析与BOF修复方案
description: 详细记录 PPL 进程注入后创建子进程失败的根因（bInheritHandles 必须为 FALSE）、Cobalt Strike Beacon
  默认行为导致的管道输出机制冲突、BOF 替代方案设计（文件落地替代匿名管道）、注入 WinTcb-Light 级别 wininit.exe/MsMpEng.exe
  实现反内存扫描的完整复现步骤与代码逻辑
category: program-analysis
tags:
- PPL
- Protected Process Light
- WinTcb-Light
- CreateProcess
- bInheritHandles
- Cobalt Strike
- Beacon Object Files
- BOF
- Memory Scanning Evasion
- Windows Internals
- Red Teaming
- Defense Evasion
date: 2023-04-16
updated: '2026-11-15'
---
## 概述

本页面记录在 **PPL (Protected Process Light)** 级别进程中进行 Shellcode 注入并上线 Cobalt Strike Beacon 后，因 `CreateProcess` 调用失败（错误码 87 `ERROR_INVALID_PARAMETER`）导致无法执行 `shell`、`execute`、`execute-assembly` 等需要创建子进程的操作的根因分析、Beacon 默认管道输出机制与 PPL 限制的冲突细节，以及基于 **BOF (Beacon Object Files)** 的文件落地输出替代方案的设计与实现。同时涵盖注入 `WinTcb-Light` 级别关键系统进程（`wininit.exe`、`MsMpEng.exe`）以规避 `Antimalware-Light` 级别安全产品内存扫描的实战复现步骤。

## 问题现象

- **注入目标**：`services.exe`（PPL 级别为 `WinTcb-Light`），成功上线 CS Beacon。
- **症状**：Beacon 中一切需要启动新进程的操作（`shell`、`execute`、`execute-assembly` 等）均失败，返回 **Error Code 87 (Invalid Parameters)**；不需要创建进程的操作（文件系统访问、进程注入）正常。
- **环境**：Windows 系统，目标进程为 PPL 保护进程，子进程（如 `cmd.exe`）为非 PPL 进程。

## 根因分析：MSDN 文档与 `bInheritHandles` 限制

### MSDN 明确限制

根据 Microsoft 官方文档 `kernel32!CreateProcess` 参数 `bInheritHandles` 说明：

> **一个 PPL 进程中启动非 PPL 进程时，不能要求子进程继承句柄。**  
> 即：当父进程为 PPL、子进程为非 PPL 时，`bInheritHandles` **必须设置为 `FALSE`**，否则直接返回 `ERROR_INVALID_PARAMETER (87)`。

由于 `services.exe` 属于 `WinTcb-Light` 级别 PPL，而 `cmd.exe` 为普通非 PPL 进程，Beacon 在调用 `CreateProcess` 时若传入 `bInheritHandles=TRUE` 便会触发该错误。

### Beacon 默认行为冲突

Beacon 所有创建进程的操作默认将 `bInheritHandles` 设为 `TRUE`，根在于 **匿名管道输出捕获机制**：

1. 调用 `CreatePipe` 创建匿名管道（读端 `hReadPipe`、写端 `hWritePipe`），并将管道句柄标记为可继承 (`SECURITY_ATTRIBUTES.bInheritHandle = TRUE`)。
2. 在 `STARTUPINFO` 中将子进程的 `hStdOutput` 与 `hStdError` 指向管道写端，并设置 `dwFlags = STARTF_USESTDHANDLES`。
3. 调用 `CreateProcess` / `CreateProcessWithTokenW` 时传入 `bInheritHandles=TRUE`，使子进程继承管道句柄。
4. 父进程从管道读端读取子进程输出。

**冲突点**：PPL 父进程无法将可继承句柄传递给非 PPL 子进程，导致整个管道输出链路在 PPL 注入场景下失效。

> 相关代码片段参考：`PrintSpoofer` 项目中 `CreateProcessWithOutput` 函数实现（见原文链接）。

## 解决方案对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| **魔改 CS 代码，强制 `bInheritHandles=FALSE`** | 修改简单 | 彻底破坏 `shell` 等命令的输出捕获能力 |
| **编写 BOF 实现自定义创建进程与输出获取** | 在当前进程空间执行，不受 Beacon 默认逻辑约束；可灵活替换输出通道 | 需额外开发 BOF，维护成本略高 |

**结论**：采用 **BOF 方案**，在 BOF 内部实现创建进程并另辟蹊径获取输出。

## BOF 替代输出机制设计：文件落地替代匿名管道

### 核心思路

因子进程无法继承父进程句柄，**匿名管道不可用**。可选替代 IPC 机制：

- **写文件**（最简单，落地风险略高）
- 命名管道
- 共享内存
- 套接字

本实现暂采用 **写文件** 方案：子进程将输出重定向到临时文件，父进程（BOF）读取文件内容后返回 Beacon，再删除临时文件。

### 关键实现步骤

1. **生成唯一临时文件路径**（如 `%TEMP%\\beacon_out_<PID>_<TICK>.tmp`）。
2. **构造 `STARTUPINFO`**：
   - `hStdOutput` / `hStdError` = `CreateFile` 打开的临时文件句柄（`FILE_ATTRIBUTE_TEMPORARY | FILE_FLAG_DELETE_ON_CLOSE` 可选，或手动清理）。
   - `dwFlags = STARTF_USESTDHANDLES`。
   - **`bInheritHandles = FALSE`**（关键）。
3. **调用 `CreateProcess` / `CreateProcessWithTokenW` / `CreateProcessAsUser`** 启动子进程。
4. **等待子进程退出**（`WaitForSingleObject`）。
5. **读取临时文件内容**，通过 Beacon 输出 API（`BeaconPrintf` / `BeaconOutput`）回传。
6. **清理临时文件**（若未使用 `FILE_FLAG_DELETE_ON_CLOSE`）。

### BOF 入口与注册

- 导出函数 `go(char *args, int len)` 解析命令行参数。
- 通过 `BeaconRegisterCommand("tshell", "tshell <command>", "execute command via BOF with file output", 0, go)` 注册 `tshell` 命令，用法与原生 `shell` 一致。

> 详细 BOF 开发规范参考 [[cobalt-strike-4.7-bof-internals]]。

## 实战复现：注入 WinTcb-Light 级别进程规避内存扫描

### PPL 等级与访问控制

| PPL 级别 | 典型进程 | 可被打开访问的最低 PPL 级别 |
|----------|----------|-----------------------------|
| `WinTcb-Light` | `wininit.exe`、`services.exe`、`csrss.exe` | `WinTcb-Light` 及以上 |
| `Antimalware-Light` | `MsMpEng.exe` (Windows Defender)、腾讯管家等 AV 服务进程 | `Antimalware-Light` 及以上 |

**规则**：低 PPL 级别进程**无法**打开高 PPL 级别进程句柄（`OpenProcess` 失败，`ERROR_ACCESS_DENIED`）。

### 攻击链

1. 利用 PPLDump 或类似工具，在 `services.exe` (WinTcb-Light) 中执行 Shellcode 注入，上线 Beacon。
2. 使用 Beacon `inject` / `shinject` 将 Beacon 迁移至 **`wininit.exe` (WinTcb-Light)** 或 **`MsMpEng.exe` (Antimalware-Light)**。
   - 迁移至 `wininit.exe`：处于最高 PPL 等级，**所有 Antimalware-Light 级别的 AV/EDR 服务进程均无法打开其句柄进行内存扫描**，实现 **反内存扫描**。
   - 迁移至 `MsMpEng.exe`：直接寄生于 Windows Defender 自身进程，隐蔽性极强。
3. 在目标 PPL 进程中使用 **BOF `tshell`** 执行命令，绕过 `bInheritHandles` 限制，正常获取输出。

### 复现截图要点

- **注入 `wininit.exe`**：Beacon 上下文显示 PID 对应 `wininit.exe`，`tshell whoami` 正常返回输出。
- **注入 `MsMpEng.exe`**：Beacon 上下文显示 PID 对应 `MsMpEng.exe`，同理命令执行正常。

> 内存扫描对抗技术体系详见 [[memory-scanning-tools-evasion-techniques]]、[[windows-token-nerfing-pplguard-trusted-labels]]。

## 代码逻辑要点（伪代码）

```c
// BOF 入口
void go(char *args, int len) {
    datap parser;
    BeaconDataParse(&parser, args, len);
    char *cmd = BeaconDataExtract(&parser, NULL);  // 获取命令行

    // 1. 生成临时文件
    char tmpPath[MAX_PATH];
    GetTempPathA(MAX_PATH, tmpPath);
    strcat(tmpPath, "beacon_out_");
    char pidStr[16]; itoa(GetCurrentProcessId(), pidStr, 10);
    strcat(tmpPath, pidStr);
    strcat(tmpPath, "_");
    char tickStr[16]; itoa(GetTickCount(), tickStr, 10);
    strcat(tmpPath, tickStr);
    strcat(tmpPath, ".tmp");

    // 2. 打开临时文件作为 stdout/stderr
    HANDLE hFile = CreateFileA(tmpPath,
                               GENERIC_WRITE,
                               FILE_SHARE_READ,
                               NULL,
                               CREATE_ALWAYS,
                               FILE_ATTRIBUTE_TEMPORARY | FILE_FLAG_DELETE_ON_CLOSE,
                               NULL);

    // 3. 配置 STARTUPINFO
    STARTUPINFOA si = {0};
    si.cb = sizeof(si);
    si.hStdOutput = hFile;
    si.hStdError  = hFile;
    si.dwFlags    = STARTF_USESTDHANDLES;
    // si.wShowWindow = SW_HIDE;  // 可选

    // 4. 命令行包装
    char fullCmd[1024];
    sprintf(fullCmd, "cmd.exe /c %s", cmd);

    // 5. 创建进程（关键：bInheritHandles = FALSE）
    PROCESS_INFORMATION pi = {0};
    BOOL ok = CreateProcessA(NULL, fullCmd, NULL, NULL,
                             FALSE,          // <<< 关键：不继承句柄
                             CREATE_NO_WINDOW,
                             NULL, NULL, &si, &pi);

    if (!ok) {
        BeaconPrintf(CALLBACK_ERROR, "CreateProcess failed: %d", GetLastError());
        CloseHandle(hFile);
        return;
    }

    // 6. 等待退出
    WaitForSingleObject(pi.hProcess, INFINITE);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);

    // 7. 读取文件内容回传
    CloseHandle(hFile);  // 触发 FILE_FLAG_DELETE_ON_CLOSE 自动删除，或手动读取后 DeleteFile
    HANDLE hRead = CreateFileA(tmpPath, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    if (hRead != INVALID_HANDLE_VALUE) {
        char buf[4096];
        DWORD readBytes;
        while (ReadFile(hRead, buf, sizeof(buf)-1, &readBytes, NULL) && readBytes) {
            buf[readBytes] = 0;
            BeaconPrintf(CALLBACK_OUTPUT, "%s", buf);
        }
        CloseHandle(hRead);
    }
    DeleteFileA(tmpPath);  // 兜底清理
}
```

## 交叉引用与延伸阅读

- [[windows-token-nerfing-pplguard-trusted-labels]] — PPL 等级体系、Token Nerfing 攻击与 PPLGuard 缓解、`bInheritHandles=TRUE` 导致 CreateProcess 失败的根因分析、BOF 无句柄继承创建进程利用链、WinTcb-Light 注入规避内存扫描实战案例。
- [[cobalt-strike-4.7-bof-internals]] — BOF 加载器内部实现、动态函数槽位限制、Relocation 处理、Sleep Kit BOF 化等细节，辅助理解 BOF 开发约束。
- [[cobalt-strike-external-c2-smb-beacon]] — Beacon 进程创建与管道通信模型、SMB Beacon 命名管道通信、External C2 规范。
- [[memory-scanning-tools-evasion-techniques]] — Hunt-Sleeping-Beacons、BeaconHunter、BeaconEye、patriot、moneta、pe-sieve、MalMemDetect 等内存扫描工具检测原理与 UDRL（FOLIAGE、Ekko、AceLdr）对抗效果。
- [[process-injection-tampering-techniques]] — Process Hollowing、Doppelganging、Ghosting、Herpaderping、Transacted Hollowing 五大镂空/篡改技术原理对比与 Sysmon Event ID 25 检测规避。
- [[argument-spoofing-edr-evasion]] — EDR 进程创建监控回调 `PsSetCreateProcessNotifyRoutineEx`、Sysmon Event ID 1 字段、命令行混淆绕过、PEB `RTL_USER_PROCESS_PARAMETERS` 利用、Cobalt Strike `argue` 命令增强实现。
- [[pe-manual-mapping-loader-implementation]] — PE 手动映射加载器全流程：导入表修复、重定位修正、导出表解析、模块隐藏、MEM_IMAGE 内存分配、延迟导入表与 API Set Schema 处理，供 Shellcode/BOF 落地执行参考。

## 小结

| 要点 | 说明 |
|------|------|
| **失败根因** | PPL 父进程创建非 PPL 子进程时，`bInheritHandles` 必须为 `FALSE`（MSDN 限制）。 |
| **Beacon 冲突** | 默认通过匿名管道捕获输出，要求 `bInheritHandles=TRUE`，导致 PPL 场景全系创建进程操作失效。 |
| **修复方案** | BOF 实现自定义 `CreateProcess`，`bInheritHandles=FALSE`，输出重定向至临时文件回传。 |
| **实战价值** | 注入 `WinTcb-Light` (`wininit.exe`) 或 `Antimalware-Light` (`MsMpEng.exe`) 可规避同级或更低 PPL 级别的内存扫描，配合 BOF 实现完整交互能力。 |
| **后续优化** | 临时文件落地可被文件监控发现，后续可替换为命名管道、共享内存或套接字等无文件 IPC 机制。 |

---
*页面基于微信公众号文章《解决PPL注入技术的bug》整理，归档日期 2023-04-16。*

## 来源

- [0x4d5a-202103-202209_10](../sources/0x4d5a-202103-202209_10.md)
