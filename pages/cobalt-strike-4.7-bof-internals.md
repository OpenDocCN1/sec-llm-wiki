---
title: Cobalt Strike 4.7 BOF 内部实现深度解析
description: 深度解析 Cobalt Strike 4.7 更新中 BOF 加载器内部实现、新增配置项、Relocation 处理缺陷、动态函数槽位限制、Sleep
  Kit BOF 化及令牌窃取改进等核心技术细节，新增 PPL 进程注入 CreateProcess 句柄继承绕过实战案例
category: program-analysis
tags:
- Cobalt Strike
- BOF
- Beacon Object Files
- Relocation
- Red Teaming
- C2 Framework
- Windows Internals
- Memory Management
- PPL
- Protected Process Light
- CreateProcess
- bInheritHandles
date: 2023-04-16
updated: '2026-11-15'
---

## 概述

Cobalt Strike 4.7 作为十周年纪念版发布，核心设计理念保持**稳定性与可扩展性**并重：不在核心内置前沿免杀技术，避免陷入特征对抗循环，而是通过 Arsenal Kit 等扩展机制赋予用户灵活性。本版本重点更新集中在 BOF（Beacon Object Files）加载器内部实现修复、新增内存管理配置项、Sleep Kit BOF 化、令牌窃取权限最小化等工程化改进。

> 交叉参考：Cobalt Strike 整体架构、Staging 机制、External C2 规范、SMB Beacon 横向移动详见 [[cobalt-strike-external-c2-smb-beacon]]；C2 重定向器与 Malleable C2 Profile 流量混淆详见 [[c2-redirectors-malleable-c2-profiles]]。

---

## 一、BOF 核心配置项新增

4.7 引入三个 Malleable C2 Profile 配置项，直接作用于 BOF 在内存中的布局与生命周期：

| 配置项 | 可选值 / 类型 | 作用 |
|--------|---------------|------|
| `bof_allocator` | `VirtualApp` \| `MapViewOfFile` \| `HeapAlloc` | 指定 BOF 代码与数据节区的内存分配 API |
| `bof_reuse_memory` | `true` \| `false` | `true` 时执行完毕后清空并复用同一块内存，减少重复分配特征 |
| `userwx` | `true` \| `false` | 全局 RWX 页面策略，BOF 受其影响（若为 `false` 则分配 RW → 执行前改 RX） |

官方说明称此变更解决了两个长期遗留问题：
1. 支持 `.xdata`、`.pdata`、`.bss` 等额外重定位节区，修复 **地址偏移 > 4 GB 导致 BOF 无法运行** 的缺陷。
2. 可用动态函数槽位从 **32 提升至 64**。

> **作者注**：配置项与上述两问题的因果链条在官方博客中表述不清；结合实战 BOF Loader 开发经验，下文逐项拆解底层根因。

---

## 二、BOF Loader 既有实现缺陷深度复盘

### Relocation Truncated to Fit（地址差 > 4 GB）

#### 触发场景
COFF 中 `IMAGE_REL_AMD64_REL32` 重定位项要求 **符号地址与重定位处地址差值 ≤ 0xFFFFFFFF**。CS 旧实现出现该报错的两大原因：

1. **内部符号跨节距离过大**  
   旧 Loader 仅为 `.text`、`.data` 等常用节区分配内存，**未将 `.xdata`、`.pdata`、`.bss` 等节区纳入同一连续内存块**，导致节区间虚拟地址差可能超过 4 GB。

2. **外部符号（动态导入函数）映射表与节区非连续分配**  
   典型错误模式（参考开源项目 CoffeLdr）：
   ```c
   // 节区映射表与函数映射表分离分配
   Coffee.SecMap = LocalAlloc(LPTR, ...);
   Coffee.FunMap = VirtualAlloc(NULL, 2048, MEM_COMMIT|MEM_RESERVE|MEM_TOP_DOWN, PAGE_READWRITE);
   ```
   处理 `REL32` 时直接用 `FunMap` 入口地址减去节区内偏移，极易触发 >4GB 判断。

#### 修复要点
- **统一连续分配**：所有节区（含 `.xdata/.pdata/.bss`）+ 符号表 + 函数映射表在一次 `VirtualAlloc` / `MapViewOfFile` 中完成，保证任意两地址差 < 4 GB。
- 正确处理重定位伪码（参考 lld COFF/Chunks.cpp）：
  ```c
  // REL32 处理
  int64_t delta = (int64_t)SymbolAddr - (int64_t)RelocAddr - 4;
  if (delta < INT32_MIN || delta > INT32_MAX) error("Relocation truncated");
  *(int32_t*)RelocAddr = (int32_t)delta;
  ```

> 交叉参考：PE 手工映射加载器中导入表修复、重定位表修正完整流程详见 [[pe-manual-mapping-loader-implementation]]。

---

### `_chkstk_ms` 符号缺失

**成因**：函数栈帧 > 4 KB 时 MSVC 插入 `__chkstk` 调用（用于分页提交栈内存）。BOF 静态链接 CRT 时若未提供该符号，链接/加载阶段报错。

**对策**：Loader 在解析外部符号表时，将 `_chkstk_ms` / `__chkstk` 绑定到自实现的栈扩展函数（仅需按页探测并触发页错误即可）。

---

### 动态函数槽位限制（32 → 64）

**旧实现推测**：静态定义 `void* func_map[32]`，超出部分强制开发者自行 `GetProcAddress` / `LoadLibrary` 动态解析（如 PPLDump_BOF 中大量手工填充函数指针结构体）。

**影响**：
- 开发复杂 BOF 必须维护庞大的动态解析样板代码。
- 并未节省内存、体积或加载耗时，纯粹是任意工程限制。

**4.7 改进**：配合新内存分配策略将槽位扩至 64，但**本质上仍应改为动态扩容数组或哈希表**，彻底移除硬编码上限。

---

### BOF 执行阻塞 Beacon 主循环

**现象**：BOF 在 Beacon 主线程同步执行，运行期间**完全阻塞**心跳、任务分发、SOCKS 代理转发等所有异步逻辑。

**设计缺陷**：无任何技术必要性强制串行；应改为**线程池 / 纤程**异步执行，或至少提供 `async_bof` 原语。长耗时能力建议改用 Reflective DLL + 牺牲进程（Sacrificial Process）模式。

> 交叉参考：Cobalt Strike 团队服务器部署、监听器配置、Beacon 上线与提权插件加载实战详见 [[xd-security-internal-network-penetration-notes-day69-70]]。

---

## 三、Sleep Kit BOF 化

| 版本 | 实现方式 | 限制 |
|------|----------|------|
| ≤ 4.6 | UDRL 风格：编译后 `.text` 直接拷贝覆盖 Beacon `.text` | 无法调用 BOF API / 动态导入函数；体积受限；驻留在 Beacon `.text` 易被内存扫描 |
| 4.7  | 真正的 BOF 实现 | 可调用 `LIBRARY$func` 与 Beacon API；体积上限 4 KB；代码段不再位于 Beacon `.text` |

**意义**：Sleep Mask 现在具备完整 BOF 运行时能力，可在休眠钩子中执行复杂逻辑（如动态解密、环境检测），且内存特征与普通 BOF 一致，更难被静态特征匹配。

---

## 四、令牌窃取权限最小化（`steal_token_access_mask`）

### 新增配置
- **Profile**：`steal_token_access_mask` 指定 `OpenProcessToken` 请求的访问掩码。
- **GUI**：执行 `steal_token` 时可勾选自定义掩码。

### 实践最小权限链
```c
// 1. 以最小权限打开目标进程
HANDLE hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);

// 2. 仅请求 TOKEN_DUPLICATE 打开令牌
HANDLE hTok;
OpenProcessToken(hProc, TOKEN_DUPLICATE, &hTok);

// 3. 按需复制新令牌（推荐 MAXIMUM_ALLOWED 由系统计算有效权限）
HANDLE hNewTok;
DuplicateTokenEx(hTok, MAXIMUM_ALLOWED, NULL, SecurityImpersonation, TokenPrimary, &hNewTok);
```

### `TOKEN_ALL_ACCESS` 隐性缺陷
Windows SDK 定义：
```c
#if (_WIN32_WINNT > 0x0400)
#define TOKEN_ALL_ACCESS (TOKEN_ALL_ACCESS_P | TOKEN_ADJUST_SESSIONID)
#else
#define TOKEN_ALL_ACCESS TOKEN_ALL_ACCESS_P
#endif
```
- 绑定层（如 `microsoft/win32metadata`、Golang `syscall`）常仅定义 `_WIN32_WINNT <= 0x0400` 分支，**缺失 `TOKEN_ADJUST_SESSIONID`**。
- 缺失该权限导致 `CreateProcessWithTokenW` / `CreateProcessAsUserW` 失败（无法指定会话 ID）。
- **排查提示**：若 `TOKEN_ALL_ACCESS` 令牌无法创建进程，检查绑定层是否包含 `TOKEN_ADJUST_SESSIONID`。

> 交叉参考：内网渗透中令牌窃取、PTH/PTK/PTT、黄金/白银票据生成详见 [[xd-security-internal-network-penetration-notes-day67-68]]。

---

## 五、Module Stomping 改进

**原机制**：Profile 指定 `module_x64 / module_x86` 加载合法 DLL，将 Beacon 镜像写入其镜像内存，规避可执行私有内存（RWX/Private）检测。

**旧缺陷**：仅当目标 DLL **导出函数序数在 1~15 之间** 时才真正 Stomping；否则回退 `VirtualAlloc`。

**4.7 修复**：新增可选语法指定**搜索起始序数**，突破 1~15 限制，提高可用 DLL 覆盖面。

> 交叉参考：Phantom DLL Hollowing 等进阶内存隐藏技术对比详见 [[phantom-dll-hollowing-technique]]。

---

## 六、其他功能性更新

| 特性 | 说明 |
|------|------|
| **SOCKS5 代理** | 新增认证 + UDP 转发支持；未来计划将 Beacon 与代理分离，采用反射 DLL 注入实现 |
| **剪贴板窃取** | `clipboard` 命令 / CNA `bclipboard` 可读取 ≤ 204,800 字节 |
| **Stageless Shellcode 退出策略** | 可配置退出进程或仅退出线程 |
| **UI/UX** | 新增暗黑模式等界面优化 |

---

## 七、实战案例：PPL 进程注入 CreateProcess 句柄继承绕过

### 问题背景

在 PPL（Protected Process Light）级别为 `WinTcb-Light` 的进程（如 `services.exe`、`wininit.exe`、`MsMpEng.exe`）中进行 Shellcode 注入并上线 CS 后，发现**无法创建子进程**。所有需要启动新进程的操作（`shell`、`execute`、`execute-assembly` 等）均失败，返回 **Error Code 87 (ERROR_INVALID_PARAMETER)**，但文件系统访问、进程注入等不需创建进程的操作正常。

> 交叉参考：PPL 注入技术细节、WinTcb-Light 级别进程特性、内存扫描规避原理详见 [[ppl-injection-createprocess-bof-fix]]、[[windows-token-nerfing-pplguard-trusted-labels]]。

### 根因分析：MSDN 文档与 Beacon 默认行为冲突

根据 MSDN `CreateProcess` 文档，参数 `bInheritHandles` 说明：

> **一个 PPL 进程创建非 PPL 子进程时，`bInheritHandles` 必须为 FALSE**，否则返回 ERROR_INVALID_PARAMETER (87)。

Beacon 内置的进程创建逻辑（`shell`、`execute` 等）默认将 `bInheritHandles` 设为 **TRUE**，目的是通过匿名管道（`CreatePipe` + `STARTUPINFO.hStdOutput/hStdError`）捕获子进程输出。该机制要求子进程继承父进程的管道句柄。

**冲突点**：
- 注入目标为 PPL 进程（如 `wininit.exe` / `MsMpEng.exe`）
- 目标子进程为非 PPL（如 `cmd.exe`）
- Beacon 强制 `bInheritHandles=TRUE` → 触发 PPL 限制 → 创建失败

### 解决方案：BOF 替代 Beacon 内置进程创建

利用 BOF **在当前进程空间直接执行** 的特性，绕过 Beacon 内置的 `CreateProcess` 封装，实现自定义进程创建与输出回传逻辑。

#### 核心思路

1. **`bInheritHandles = FALSE`** 调用 `CreateProcessWithTokenW` / `CreateProcessAsUserW` 创建子进程
2. **放弃匿名管道**，改用 **文件落地** 作为输出中转：
   - 子进程重定向 stdout/stderr 到临时文件
   - BOF 等待进程结束后读取文件内容
   - 通过 Beacon Output API (`BeaconPrintf` / `BeaconOutput`) 回传给 Team Server
3. 临时文件执行完毕后删除，减少磁盘残留

#### 关键代码逻辑（简化）

```c
// BOF 入口
void go(char* args, int len) {
    datap parser;
    BeaconDataParse(&parser, args, len);
    char* command = BeaconDataExtract(&parser, NULL);
    
    // 1. 生成唯一临时文件路径
    char tmpPath[MAX_PATH];
    GetTempPathA(MAX_PATH, tmpPath);
    strcat(tmpPath, "bof_out_XXXXXX");
    // 使用 GetTempFileNameA 或自行生成随机名
    
    // 2. 构造命令行：cmd.exe /c "command > tmpfile 2>&1"
    char cmdLine[4096];
    wsprintfA(cmdLine, "cmd.exe /c \"%s > %s 2>&1\"", command, tmpPath);
    
    // 3. 启动进程：bInheritHandles = FALSE
    STARTUPINFOA si = { sizeof(si) };
    PROCESS_INFORMATION pi;
    BOOL ok = CreateProcessWithTokenW(hToken, LOGON_WITH_PROFILE, 
        NULL, cmdLine, CREATE_NO_WINDOW, NULL, curDir, &si, &pi);
    
    // 4. 等待结束并读取输出文件
    WaitForSingleObject(pi.hProcess, 30000);
    HANDLE hFile = CreateFileA(tmpPath, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    char buf[4096]; DWORD read;
    while (ReadFile(hFile, buf, sizeof(buf)-1, &read, NULL) && read) {
        buf[read] = 0;
        BeaconPrintf(CALLBACK_OUTPUT, "%s", buf);
    }
    CloseHandle(hFile);
    DeleteFileA(tmpPath);
    // 清理句柄...
}
```

#### 注册为 Beacon 命令（CNA）

```cna
command t-shell {
    local('$handle $data');
    $handle = openf(script_resource("tshell.o"));
    $data = readb($handle, -1);
    closef($handle);
    btask($1, "Tasked BOF to execute command via file-based output");
    beacon_inline_execute($1, $data, "tshell", $2);
}
```

### 实战效果验证

| 注入目标进程 | PPL 级别 | 原 Beacon `shell` | BOF `tshell` |
|--------------|----------|-------------------|--------------|
| `wininit.exe` | `WinTcb-Light` | ❌ Error 87 | ✅ 正常执行并回显 |
| `MsMpEng.exe` (Defender) | `Antimalware-Light` | ❌ Error 87 | ✅ 正常执行并回显 |
| `services.exe` | `WinTcb-Light` | ❌ Error 87 | ✅ 正常执行并回显 |

**防御规避价值**：
- 注入 `WinTcb-Light` 级别进程（`wininit.exe`、`services.exe`）可**阻断 `Antimalware-Light` 级别的 AV/EDR 服务（如 Defender `MsMpEng.exe`）打开句柄进行内存扫描**，实现反内存查杀。
- 注入 AV 自身服务进程（`MsMpEng.exe`）可直接监控/干扰其行为。

> 交叉参考：内存扫描工具对抗技术、UDRL 规避实现详见 [[memory-scanning-tools-evasion-techniques]]。

---

## 八、工程化建议与检测对抗视角

### BOF 开发规范
- 统一使用 `bof_allocator = MapViewOfFile` + `bof_reuse_memory = true` 降低堆分配特征。
- 超过 64 个动态导入时，改用 **哈希表 + 单次 `GetProcAddress` 批量解析** 模板，避免硬编码槽位。
- 长耗时任务**强制**迁移至 Sacrificial Process + Reflective DLL，勿阻塞 Beacon 主循环。
- **PPL/高权限进程注入场景**：务必实现 `bInheritHandles=FALSE` 的进程创建 BOF，配合文件/命名管道/共享内存等非继承句柄的输出回传机制。

### Sleep Mask 武器化
- 利用 4 KB 预算实现**运行时环境指纹检测**（EDR 模块枚举、ETW 提供者检查）、**动态内存权限翻转**（RW↔RX）、**关键数据结构加密**（Beacon 元数据、C2 地址）。

### 令牌窃取 OPSEC
- 默认 Profile 设置 `steal_token_access_mask = TOKEN_DUPLICATE | TOKEN_QUERY | TOKEN_IMPERSONATE`。
- 结合 `make_token` / `runas` 替代高权限 `steal_token`，减少 `OpenProcess(PROCESS_ALL_ACCESS)` 触发的 EDR 回调。

### 检测规则建议（蓝队）
- **Sysmon Event ID 8/10**：监控 `MapViewOfFile` / `VirtualAlloc` 后紧跟 `CreateThread` 且调用栈无模块回溯。
- **内存扫描**：重点检查 `MEM_IMAGE` 非模块映射区域、`PAGE_EXECUTE_READWRITE` 私有内存、Beacon `.text` 段完整性（Sleep Mask 修改前后哈希对比）。
- **令牌审计**：关注 `OpenProcessToken(TOKEN_ADJUST_SESSIONID)` 与 `CreateProcessWithTokenW` 组合调用链。
- **PPL 进程异常子进程**：监控 `WinTcb-Light`/`Antimalware-Light` 进程创建非 PPL 子进程且 `bInheritHandles=FALSE` 的异常模式（可通过 ETW/Kernel Callback 捕获）。

> 交叉参考：SMB Beacon 命名管道通信的主机/网络层检测规则、Sysmon Event ID 17/18 详见 [[named-pipe-smb-detection-sysmon]]、[[smb-named-pipe-c2-communication]]。

---

## 九、参考资料

1. Cobalt Strike 4.7: The 10th Anniversary Edition — <https://www.cobaltstrike.com/blog/cobalt-strike-4-7-the-10th-anniversary-edition/>
2. A Developer's Introduction to Beacon Object Files (TrustedSec) — <https://www.trustedsec.com/blog/a-developers-introduction-to-beacon-object-files/>
3. lld COFF Relocation Handling (Chunks.cpp) — <https://android.googlesource.com/toolchain/lld/+/refs/heads/master/COFF/Chunks.cpp>
4. CoffeLdr BOF Loader (Cracked5pider) — <https://github.com/Cracked5pider/CoffeeLdr>
5. PPLDump_BOF (EspressoCake) — <https://github.com/EspressoCake/PPLDump_BOF>
6. microsoft/win32metadata — <https://github.com/microsoft/win32metadata>
7. Golang Issue #25775: TOKEN_ALL_ACCESS inconsistency — <https://github.com/golang/go/issues/25775>
8. Cobalt Strike 3.11 – The snake that eats its tail — <https://www.cobaltstrike.com/blog/cobalt-strike-3-11-the-snake-that-eats-its-tail/>
9. PPL 注入 CreateProcess 句柄继承绕过实战文章 — 微信公众号归档

---

## 十、相关知识库页面导航

- [[cobalt-strike-external-c2-smb-beacon]] — CS 核心架构、Staging、Heartbeat、External C2、SMB Beacon 横向移动全链路
- [[c2-redirectors-malleable-c2-profiles]] — 重定向器拓扑、Malleable C2 Profile 混淆配置、域名前置/CDN 隐匿
- [[named-pipe-smb-detection-sysmon]] — Sysmon Event ID 17/18 命名管道检测、网络流量基线异常识别
- [[smb-named-pipe-c2-communication]] — SMB 命名管道 C2 通信原理、Cobalt Strike/Covenant 实现对比
- [[xd-security-internal-network-penetration-notes-day69-70]] — CS Team Server 部署、监听器/Beacon 配置、提权插件、SOCKS 代理实战
- [[xd-security-incident-response-notes]] — CS 与 Metasploit 双向会话移交、Web 攻击应急溯源
- [[pe-manual-mapping-loader-implementation]] — PE 手工映射全流程：节区拉伸、导入表修复、重定位修正、模块隐藏
- [[phantom-dll-hollowing-technique]] — Phantom DLL Hollowing 幽灵空洞化内存注入技术细节
- [[xd-security-internal-network-penetration-notes-day67-68]] — PTH/PTK/PTT、黄金/白银票据、Mimikatz/Kekeo 实战
- [[xd-security-privilege-escalation-notes-day58-64]] — Windows/Linux 提权、令牌窃取、烂土豆、DLL 劫持、内核漏洞利用体系
- [[ppl-injection-createprocess-bof-fix]] — PPL 进程注入 CreateProcess 句柄继承绕过完整复现与 BOF 实现细节
- [[windows-token-nerfing-pplguard-trusted-labels]] — Token Nerfing、PPLGuard、Trusted Labels 机制与 PPL 注入规避内存扫描实战
- [[memory-scanning-tools-evasion-techniques]] — Hunt-Sleeping-Beacons、BeaconHunter、pe-sieve、Moneta 等内存扫描工具原理与 UDRL/FOLIAGE/Ekko/AceLdr 规避对抗
- [[argument-spoofing-edr-evasion]] — Argument Spoofing 对抗 EDR 进程创建监控、命令行混淆绕过、Cobalt Strike argue 命令增强
- [[process-injection-tampering-techniques]] — Process Hollowing/Doppelganging/Ghosting/Herpaderping/Transacted Hollowing 五大技术原理对比与 Sysmon Event ID 25 检测规避
- [[aceldr-technical-analysis]] — PE 不落地执行技术全景：RDI/sRDI/Donut、Section 相关技术、镂空傀儡进程、PE Loader 关键细节

---

## 来源

- [0x4d5a-202103-202209_10](../sources/0x4d5a-202103-202209_10.md)
