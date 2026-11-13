---
title: PE 手动映射加载器完整实现详解
description: 从零构建 Windows PE 手动映射加载器：涵盖文件解析、内存映射、节区拉伸、导入表修复、重定位修正、PE 头抹除与入口点执行的全流程
  C++ 代码实现与原理剖析。
category: program-analysis
tags:
- PE 格式
- 手动映射
- Manual Mapping
- Windows Internals
- 逆向工程
- C++
- 加载器
- 内存注入
- 导入表修复
- 重定位表
date: '2024-01-15'
updated: '2026-11-14'
---

## 概述

**PE 手动映射加载器** 是一种在用户态完全模拟 Windows 加载器行为的技术，它不依赖 `LoadLibrary`/`CreateProcess` 等系统 API 将 PE 文件映射到内存并执行。本文基于微信公众号「二进制安全」文章《手动展开PE文件》，系统拆解一个完整的 **控制台程序 PE 加载器** 的 C++ 实现，覆盖：

1. **文件读取与 PE 结构解析**
2. **按 `SizeOfImage` 申请内存并按节区对齐拉伸映射**
3. **导入表（IAT）修复**：加载依赖 DLL、解析函数地址、填充 `FirstThunk`
4. **重定位表修正**：处理基址冲突时的地址重定位
5. **PE 头抹除**：清除内存中 DOS/NT/节区头，对抗内存扫描与进程枚举
6. **入口点跳转执行**：内联汇编跳转到 `AddressOfEntryPoint`

> **适用场景**：无文件落地加载、加壳/解壳存根、恶意代码分析还原、EDR 绕过研究、CTF PWN/RE 题目中自定义加载器分析。

---

## 核心数据结构设计

### `CPE` 类成员布局（`PELoad.h`）

| 成员 | 类型 | 作用 |
|------|------|------|
| `pMemData` | `PBYTE` | 映射后镜像基址（`VirtualAlloc` 返回） |
| `pDosHeader` | `PIMAGE_DOS_HEADER` | 内存中 DOS 头指针 |
| `pNtHeader` | `PIMAGE_NT_HEADERS` | 内存中 NT 头指针 |
| `pFileHeader` | `PIMAGE_FILE_HEADER` | 文件头指针（`pNtHeader->FileHeader`） |
| `pOperationHeader` | `PIMAGE_OPTIONAL_HEADER` | 可选头指针（含 `DataDirectory`、`ImageBase`、`EntryPoint` 等关键字段） |
| `pSectionHeader` | `PIMAGE_SECTION_HEADER` | 第一节区头指针（`IMAGE_FIRST_SECTION(pNtHeader)`） |

> **设计意图**：构造时仅保存指针，解析逻辑集中在 `MapFile`，避免重复计算偏移。

---

## 完整流程逐节详解

### 文件读取与镜像大小获取

```cpp
DWORD CPE::GetSizeOfImage(PBYTE pFileBuff) {
    PIMAGE_DOS_HEADER pDos = (PIMAGE_DOS_HEADER)pFileBuff;
    PIMAGE_NT_HEADERS pNt = (PIMAGE_NT_HEADERS)(pFileBuff + pDos->e_lfanew);
    return pNt->OptionalHeader.SizeOfImage;  // 已按 SectionAlignment 对齐
}
```

- `SizeOfImage` = 所有节区按内存对齐后的总大小，含头部。
- 用于 `VirtualAlloc` 申请**连续、可读写可执行**（`PAGE_EXECUTE_READWRITE`）内存。

### 节区拉伸映射（`MapFile` 核心循环）

```cpp
// 拷贝头部（SizeOfHeaders 已按 FileAlignment 对齐）
RtlCopyMemory(pMemData, pFileData, dwSizeOfHeaders);

// 逐节区按 VirtualAddress / SizeOfRawData 拷贝
for (int i = 0; i < nNumerOfSections; i++) {
    if (pSection->VirtualAddress == 0 || pSection->SizeOfRawData == 0) { pSection++; continue; }
    chSrcMem  = pFileData + pSection->PointerToRawData;   // 文件偏移
    chDestMem = pMemData  + pSection->VirtualAddress;     // 内存 RVA
    RtlCopyMemory(chDestMem, chSrcMem, pSection->SizeOfRawData);
    pSection++;
}
```

**关键点**：
- 文件中按 `FileAlignment`（通常 0x200）对齐，内存中按 `SectionAlignment`（通常 0x1000）对齐。
- `PointerToRawData` → `VirtualAddress` 的映射实现了“**拉伸**”。
- 节区属性（可读/可写/可执行）此时尚未按 `Characteristics` 设置，后续可补充 `VirtualProtect`。

### 导入表修复（`ImportTable`）

```cpp
PIMAGE_IMPORT_DESCRIPTOR pImportTable = (PIMAGE_IMPORT_DESCRIPTOR)(
    pMemData + pOperationHeader->DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress);

while (pImportTable->OriginalFirstThunk) {
    // 1. 定位 DLL 名称并加载
    lpDllName = pMemData + pImportTable->Name;
    hDll = GetModuleHandleA(lpDllName) ?: LoadLibraryA(lpDllName);

    // 2. 遍历 INT（OriginalFirstThunk）与 IAT（FirstThunk）平行数组
    lpImportNameArray  = (PIMAGE_THUNK_DATA)(pMemData + pImportTable->OriginalFirstThunk);
    lpImportFuncAddrArray = (PIMAGE_THUNK_DATA)(pMemData + pImportTable->FirstThunk);

    for (i = 0; lpImportNameArray[i].u1.AddressOfData; i++) {
        lpImportByName = (PIMAGE_IMPORT_BY_NAME)(pMemData + lpImportNameArray[i].u1.AddressOfData);

        // 3. 区分序号导出 / 名称导出
        if (lpImportNameArray[i].u1.Ordinal & 0x80000000) {
            lpFuncAddress = GetProcAddress(hDll, (LPCSTR)(lpImportNameArray[i].u1.Ordinal & 0xFFFF));
        } else {
            lpFuncAddress = GetProcAddress(hDll, lpImportByName->Name);
        }
        // 4. 回填 IAT
        lpImportFuncAddrArray[i].u1.Function = (DWORD)lpFuncAddress;
    }
    pImportTable++;
}
```

**结构关系速查**：

```
IMAGE_IMPORT_DESCRIPTOR
├─ Name                      → DLL 名字符串 (RVA)
├─ OriginalFirstThunk (INT)  → IMAGE_THUNK_DATA[] (以 0 结尾)
│   └─ u1.AddressOfData      → IMAGE_IMPORT_BY_NAME (Hint + Name) / 序号(高位=1)
└─ FirstThunk (IAT)          → IMAGE_THUNK_DATA[] (同长度，加载器回填 Function 地址)
```

> **实战提示**：若目标进程已加载同名 DLL，`GetModuleHandle` 可避免重复加载；若需隐蔽，可改用 `LdrLoadDll` 或手动映射依赖 DLL（递归）。

### 重定位表修正（`RelocationTable`）

```cpp
PIMAGE_BASE_RELOCATION pLoc = (PIMAGE_BASE_RELOCATION)(
    pMemData + pOperationHeader->DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].VirtualAddress);

if (pLoc->SizeOfBlock == 0 && pLoc->VirtualAddress == 0) return TRUE;  // 无重定位表

while (pLoc->VirtualAddress + pLoc->SizeOfBlock) {
    WORD* pLocData = (WORD*)((PBYTE)pLoc + sizeof(IMAGE_BASE_RELOCATION));
    int nNumberOfReloc = (pLoc->SizeOfBlock - sizeof(IMAGE_BASE_RELOCATION)) / sizeof(WORD);

    for (int i = 0; i < nNumberOfReloc; i++) {
        if ((pLocData[i] & 0xF000) == 0x3000) {  // IMAGE_REL_BASED_HIGHLOW (32 位)
            DWORD* pAddress = (DWORD*)(pMemData + pLoc->VirtualAddress + (pLocData[i] & 0x0FFF));
            DWORD dwDelta = *pAddress + (DWORD)pMemData - pNtHeader->OptionalHeader.ImageBase;
            *pAddress = dwDelta;
        }
    }
    pLoc = (PIMAGE_BASE_RELOCATION)((PBYTE)pLoc + pLoc->SizeOfBlock);
}
```

**原理**：
- `ImageBase` 为链接时假定基址，实际映射基址 `pMemData` 可能不同。
- **Delta = 实际基址 - ImageBase**。
- 每个重定位项：`高 4 位=类型(0x3=HIGHLOW)`，`低 12 位=页内偏移`。
- 修正公式：`*pAddress += Delta`（源码写法等价）。

> **64 位扩展**：类型改为 `IMAGE_REL_BASED_DIR64 (0xA)`，`pAddress` 为 `ULONGLONG*`，其余逻辑不变。

### PE 头抹除（`ErasurePEHeader`）

```cpp
bool CPE::ErasurePEHeader() {
    RtlZeroMemory(pDosHeader, sizeof(IMAGE_DOS_HEADER));
    RtlZeroMemory(pNtHeader, sizeof(IMAGE_NT_HEADERS));
    RtlZeroMemory(pSectionHeader, sizeof(IMAGE_SECTION_HEADER));
    pDosHeader = pNtHeader = pFileHeader = pOperationHeader = pSectionHeader = NULL;
    return TRUE;
}
```

**防御意义**：
- 破坏 `PEB->Ldr` 模块链遍历、工具（如 Process Hacker、Volatility）的内存 PE 头特征扫描。
- 配合**不链接到 `PEB.Ldr`** 可实现“幽灵模块”效果，参考 [[phantom-dll-hollowing-technique]] 中的模块伪装思路。

### 入口点执行（`CallEntry`）

```cpp
bool CPE::CallEntry() {
    PBYTE ExeEntry = pMemData + pNtHeader->OptionalHeader.AddressOfEntryPoint;
    if (!ImportTable()) return FALSE;
    if (!RelocationTable()) return FALSE;
    ErasurePEHeader();

    __asm {
        mov eax, ExeEntry
        jmp eax
    }
    return TRUE;  // 永不返回
}
```

- **执行顺序**：必须先修复 IAT/重定位，**再**抹除头，最后跳转。
- **内联汇编** 仅适用于 x86；x64 需用 `((void(*)())ExeEntry)()` 或汇编桩。
- **控制台程序**入口通常为 `mainCRTStartup` → 初始化 CRT → 调用 `main`。

---

## 编译与运行演示

### `main.cpp` 极简调用

```cpp
#include <iostream>
#include "PELoad.h"
using namespace std;

int main() {
    char arr[128];
    cin >> arr;                 // 输入目标 EXE 路径
    CPE cpe(arr);               // 构造 -> MapFile
    cpe.CallEntry();            // 修复 -> 执行 (不返回)
    return 0;
}
```

### 运行效果对比

| 场景 | 表现 |
|------|------|
| 直接双击 `z.exe` | 正常弹窗/输出 |
| 加载器输入 `z.exe` 路径 | 同等输出，**进程名仍为加载器**，`z.exe` 无独立进程、无磁盘落地 |

---

## 进阶强化方向

| 方向 | 关键点 | 参考关联 |
|------|--------|----------|
| **节区权限精细化** | 解析 `Characteristics` 调用 `VirtualProtect` 设置 `PAGE_READONLY`/`PAGE_EXECUTE_READ` 等 | [[windows-syscall-internals-sysenter-kifastcallentry]] 中内存保护机制 |
| **TLS 回调支持** | 处理 `IMAGE_DIRECTORY_ENTRY_TLS`，在入口点前执行 `TLSCallback` | 逆向分析加壳存根常见 |
| **延迟加载导入** | 解析 `IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT`，实现 `__delayLoadHelper2` 逻辑 |  |
| **异常处理/SEH** | 注册 `RtlAddFunctionTable` (x64) 或构建 `EXCEPTION_REGISTRATION_RECORD` (x86) |  |
| **无依赖加载器** | 移除 `GetModuleHandle`/`LoadLibrary`/`GetProcAddress`，改用 PEB 遍历 + 导出表解析 | [[reverse-engineering-beginner-learning-path]] 进阶篇 |
| **x64 适配** | `IMAGE_NT_HEADERS64`、`RIP` 相对寻址、`DIR64` 重定位、栈对齐、调用约定 |  |
| **反调试/反注入** | 在 `CallEntry` 前插入 `NtGlobalFlag`、`BeingDebugged` 检查、时间检测 |  |

---

## 常见坑点速查表

| 症状 | 可能原因 | 排查建议 |
|------|----------|----------|
| `Access Violation` 于 `CallEntry` | IAT 未修复 / 函数地址为 0 | 打印 `lpFuncAddress`、检查 DLL 是否真加载成功 |
| 重定位后立即崩溃 | `Delta` 计算错误 / 类型判断遗漏 `DIR64` | 对比 `ImageBase` 与 `pMemData`，打印每个修正项 |
| 控制台无输出/闪退 | 入口点为 GUI (`/SUBSYSTEM:WINDOWS`) | 检查 `OptionalHeader.Subsystem`，或改用 `CreateProcess` + `DEBUG_PROCESS` 调试 |
| 抹除头后无法调试 | 调试器依赖 PE 头定位模块 | 调试前先不调用 `ErasurePEHeader`，或使用硬件断点 |
| 依赖 DLL 版本不匹配 | `LoadLibrary` 加载了系统目录不同版本 | 使用 `LoadLibraryEx` + `LOAD_WITH_ALTERED_SEARCH_PATH` 指定目录 |

---

## 交叉引用与延伸阅读

- [[phantom-dll-hollowing-technique]] — 幽灵 DLL 空洞化：利用已加载合法 DLL 内存区段注入，配合 PE 头抹除实现更隐蔽的无文件执行。
- [[windows-syscall-internals-sysenter-kifastcallentry]] — 系统调用全链路：理解 `LoadLibrary`/`GetProcAddress` 底层如何经 `ntdll` → `sysenter` → `KiFastCallEntry` 进入内核，辅助实现无 API 导入表解析。
- [[reverse-engineering-beginner-learning-path]] — 逆向入门路线：从 PE 结构、导入/导出表、重定位表到手动映射器编写的完整学习曲线。
- [[ida-pro-tips-plugins-python]] — IDA Pro 技巧：利用 FLIRT 签名识别静态库函数、Findcrypt-Yara 识别加密常量、Keypatch 修补二进制，辅助分析加载器壳代码。
- [[binary-ninja-ollvm-deobfuscation]] — Binary Ninja 去混淆：若加载器本身被 OLLVM 平坦化，可用 IL 分析还原控制流。

---

## 结语

本页完整还原了一个 **教学级 PE 手动映射加载器** 的核心逻辑与代码实现。掌握该流程可助你：

- **阅读/编写** 任意自定义加载器（加壳器、Shellcode Runner、C2 Stager）
- **动态脱壳**：在 `CallEntry` 前下断点，内存镜像即为解密后原始 PE
- **对抗分析**：理解抹除 PE 头、不挂载 PEB 链表、手动修复 IAT/重定位如何绕过静态/动态检测

> **合规提示**：本技术仅用于安全研究、CTF 竞赛、恶意样本分析及防御规则编写，请遵守所在法律法规与道德规范。

## 来源

- [0x00实验室-202108-202304_005](../sources/0x00实验室-202108-202304_005.md)
