---
title: PE 手动映射加载器完整实现详解
description: 从零构建 Windows PE 手动映射加载器：涵盖文件解析、内存映射、节区拉伸、导入表修复、重定位修正、导出表解析与自定义 GetProcAddress、PE
  头抹除、模块隐藏技术对比、DEP 绕过与 Shellcode 提取难点、入口点执行的全流程 C++ 代码实现与原理剖析。
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
- 导出表解析
- 重定位表
- 模块隐藏
- DEP 绕过
- Shellcode
date: '2024-01-15'
updated: '2026-11-14'
---

## 概述

**PE 手动映射加载器** 是一种在用户态完全模拟 Windows 加载器行为的技术，它不依赖 `LoadLibrary`/`CreateProcess` 等系统 API 将 PE 文件映射到内存并执行。本文基于微信公众号「二进制安全」文章《手动展开PE文件》与《PE结构 | 导出表详解》，系统拆解一个完整的 **控制台程序 PE 加载器** 的 C++ 实现，覆盖：

1. **文件读取与 PE 结构解析**
2. **按 `SizeOfImage` 申请内存并按节区对齐拉伸映射**
3. **导入表（IAT）修复**：加载依赖 DLL、解析函数地址、填充 `FirstThunk`
4. **导出表解析与自定义 `GetProcAddress` 实现**：支持对外导出函数、实现无 API 导出查找
5. **重定位表修正**：处理基址冲突时的地址重定位
6. **PE 头抹除**：清除内存中 DOS/NT/节区头，对抗内存扫描与进程枚举
7. **模块隐藏技术对比**：链表摘除 vs 手动映射的优劣势分析
8. **DEP 绕过与 Shellcode 提取难点**：`VirtualProtect` 权限修改、函数边界识别挑战
9. **入口点跳转执行**：内联汇编跳转到 `AddressOfEntryPoint`

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

### 导出表解析与自定义 `GetProcAddress` 实现

手动映射加载器若需**对外提供导出函数**（如实现 Stager、Reflective DLL）或**在无 API 环境下解析依赖模块导出**，必须实现导出表遍历逻辑。参考 [[pe-export-table-internals]] 详细结构。

#### 导出表核心数据结构（`IMAGE_EXPORT_DIRECTORY`）

```cpp
typedef struct _IMAGE_EXPORT_DIRECTORY {
    DWORD   Characteristics;
    DWORD   TimeDateStamp;
    WORD    MajorVersion;
    WORD    MinorVersion;
    DWORD   Name;                    // DLL 名称 RVA
    DWORD   Base;                    // 起始序号
    DWORD   NumberOfFunctions;       // 函数地址表项数
    DWORD   NumberOfNames;           // 函数名称表项数
    DWORD   AddressOfFunctions;      // 函数地址表 (EAT) RVA
    DWORD   AddressOfNames;          // 函数名称表 (ENT) RVA
    DWORD   AddressOfNameOrdinals;   // 函数序号表 (EOT) RVA
} IMAGE_EXPORT_DIRECTORY, *PIMAGE_EXPORT_DIRECTORY;
```

#### 三表寻址关系

| 表名 | 类型 | 作用 |
|------|------|------|
| **函数名称表 (ENT)** | `DWORD[]` (RVA) | 每项存储函数名字符串 RVA，按字母序排序 |
| **函数序号表 (EOT)** | `WORD[]` | 每项存储对应名称在 **函数地址表** 中的索引 |
| **函数地址表 (EAT)** | `DWORD[]` (RVA) | 每项存储函数入口点 RVA，索引 = `Base + 序号` |

**查找流程**：
1. 遍历 `AddressOfNames` 找到目标函数名 → 得到索引 `i`
2. 用 `i` 索引 `AddressOfNameOrdinals` → 得到 `EAT` 索引 `ordinal`
3. 用 `ordinal` 索引 `AddressOfFunctions` → 得到函数 RVA
4. `FunctionVA = ImageBase + RVA`

#### 自定义 `GetProcAddress` 实现骨架

```cpp
FARPROC CPE::MyGetProcAddress(LPCSTR lpProcName) {
    // 1. 定位导出表目录项
    auto& exportDirEntry = pOperationHeader->DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT];
    if (exportDirEntry.VirtualAddress == 0) return nullptr;

    PIMAGE_EXPORT_DIRECTORY pExportDir = (PIMAGE_EXPORT_DIRECTORY)(pMemData + exportDirEntry.VirtualAddress);

    // 2. 获取三表指针
    PDWORD pAddrOfFuncs  = (PDWORD)(pMemData + pExportDir->AddressOfFunctions);
    PDWORD pAddrOfNames  = (PDWORD)(pMemData + pExportDir->AddressOfNames);
    PWORD  pAddrOfOrds   = (PWORD)(pMemData + pExportDir->AddressOfNameOrdinals);

    // 3. 遍历名称表查找
    for (DWORD i = 0; i < pExportDir->NumberOfNames; ++i) {
        LPCSTR pName = (LPCSTR)(pMemData + pAddrOfNames[i]);
        if (strcmp(pName, lpProcName) == 0) {
            WORD ordinal = pAddrOfOrds[i];           // EAT 索引
            DWORD funcRVA = pAddrOfFuncs[ordinal];   // 函数 RVA
            // 4. 处理转发导出
            if (funcRVA >= exportDirEntry.VirtualAddress &&
                funcRVA < exportDirEntry.VirtualAddress + exportDirEntry.Size) {
                // Forwarder: "DLLName.FunctionName" 或 "DLLName.#Ordinal"
                return ResolveForwarder((LPCSTR)(pMemData + funcRVA));
            }
            return (FARPROC)(pMemData + funcRVA);
        }
    }
    // 5. 支持序号查找 (高位标志或直接 ordinal)
    if ((ULONG_PTR)lpProcName <= 0xFFFF) {
        WORD ordinal = (WORD)(ULONG_PTR)lpProcName;
        if (ordinal >= pExportDir->Base && ordinal < pExportDir->Base + pExportDir->NumberOfFunctions) {
            DWORD funcRVA = pAddrOfFuncs[ordinal - pExportDir->Base];
            return (FARPROC)(pMemData + funcRVA);
        }
    }
    return nullptr;
}
```

> **进阶**：实现 `ResolveForwarder` 需递归解析 `"DLLName.FunctionName"` 或 `"DLLName.#Ordinal"`，结合 PEB 遍历查找已加载模块基址，实现**完全无 API 导入表解析**，参考 [[windows-syscall-internals-sysenter-kifastcallentry]] 中 PEB 遍历思路。

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

---

## 模块隐藏技术对比：链表摘除 vs 手动映射

文章《PE结构 | 导出表详解》通过双机调试（Win7 + Windbg）对比了两种隐藏模块的手段：

| 维度 | 内核模块链表摘除 (DKOM) | 手动映射 + PE 头抹除 |
|------|------------------------|----------------------|
| **原理** | 驱动层从 `PEB->Ldr->InLoadOrderModuleList` 等三条链表摘除 `LDR_DATA_TABLE_ENTRY` | 用户态 `VirtualAlloc` 映射 PE、修复 IAT/重定位、抹除头部、**不插入 PEB 链表** |
| **内存痕迹 (VAD)** | **仍存在** — `!vad` 仍能看到映射的 DLL 节区范围、权限 | **极小** — 仅 `VirtualAlloc` 分配的私有内存 (`MEM_PRIVATE`)，无文件映射特征，无节区名 |
| **PE 头特征** | 完整保留在内存中，内存扫描可发现 | **已抹除**（DOS/NT/Section Headers 均清零） |
| **导入/导出表** | 正常解析，可被 `GetProcAddress` 找到 | 手动修复 IAT，**可选择不实现导出表**（或实现自定义 `MyGetProcAddress`） |
| **实现门槛** | 需内核驱动签名/测试模式/漏洞利用 | 纯用户态 C++，无需驱动 |
| **稳定性风险** | 驱动崩溃导致 BSOD；PatchGuard 检测 | 进程崩溃仅影响自身；无内核风险 |
| **适用场景** | Rootkit、持久化、对抗内核级枚举 | 无文件落地加载、Shellcode Runner、C2 Stager、CTF 绕过用户态扫描 |

**Windbg 验证片段（摘自文章）**：
```text
!process 0 0 loadDll.exe          ; 找到 EPROCESS
.process /p /r <EPROCESS>         ; 切换上下文
!vad <VadRoot>                    ; 遍历 VAD 树，仍可见 dllTest.dll 映射区域
```
即使链表摘除，`!vad` 仍能泄露模块基址、大小、保护属性。手动映射则 **无 VAD 文件映射记录**，仅显示 `MEM_PRIVATE` `PAGE_EXECUTE_READWRITE` 区域，极难通过内存枚举关联到原始 DLL 文件。

> **结论**：追求**用户态最大隐蔽性**时，手动映射 + PE 头抹除 + 不挂载 PEB 链表 是首选；若需对抗内核级检测（如 EDR 内核回调），需结合 DKOM 或更高级技术（如 [[phantom-dll-hollowing-technique]] 的模块伪装）。

---

## DEP 绕过与 Shellcode 提取难点

文章在“额外的小知识（模块隐藏）”中演示了将 DLL 函数硬编码为 Shellcode 并执行，涉及两个核心工程难点：

### DEP (Data Execution Prevention) 绕过

- **默认开启**：栈/堆/数据段 `NX` (No-eXecute)，直接跳转 Shellcode 会触发 `STATUS_ACCESS_VIOLATION` (0xC0000005)。
- **解决方案**：`VirtualProtect` 修改目标内存页属性为 `PAGE_EXECUTE_READWRITE` (0x40) 或 `PAGE_EXECUTE_READ` (0x20)。

```cpp
DWORD oldProtect;
VirtualProtect(shellcodeBuf, shellcodeSize, PAGE_EXECUTE_READWRITE, &oldProtect);
// 执行 shellcode...
VirtualProtect(shellcodeBuf, shellcodeSize, oldProtect, &oldProtect); // 恢复权限
```
- **手动映射器集成点**：在 `CallEntry` 前对 **整个映射镜像** 或 **特定节区** 调用 `VirtualProtect`，按 `SectionHeader->Characteristics` 设置精细权限（`IMAGE_SCN_MEM_EXECUTE` → `PAGE_EXECUTE_READ` 等），而非全局 `RWX`，降低特征码匹配率。

### Shellcode / 函数边界提取难点

文章指出：**“有的函数不仅仅只有一个 ret，需要搞个模块做专门的判断，准确的截取出完整的函数”**。

| 难点 | 说明 | 対策 |
|------|------|------|
| **多出口** | 函数含多个 `ret` / `retn N` / `jmp` 尾调用 | 静态分析构建 CFG，从入口点遍历所有可达 `ret`，取并集范围 |
| **嵌入跳转表** | `switch` 产生的跳转表位于函数体内（`.text`） | 识别 `jmp [reg*4 + table]` 模式，将跳转表纳入提取范围 |
| **异常处理/SEH** | `__try/__except` 生成 `EXCEPTION_REGISTRATION` 在栈上，代码中含 `fs:[0]` 操作 | 识别 prologue/epilogue 模式，或直接提取整个 `.text` 节区（体积增大） |
| **位置无关性** | 硬编码 Shellcode 若含绝对地址（全局变量、字符串、IAT 调用）直接拷贝会崩溃 | **重定位感知提取**：解析函数内重定位项、字符串引用、调用指令，生成位置无关 Shellcode 或携带重定位表 |
| **编译器优化** | 函数内联、尾调用合并、COMDAT 折叠导致边界模糊 | 依赖 PDB / IDA Pro / Binary Ninja 精确识别函数边界，而非纯特征码 |

> **工程建议**：生产级 Loader 不提取单函数 Shellcode，而是**整体映射 PE**（含导入表、重定位、TLS、导出表），仅在极度受限环境（如漏洞利用小内存载荷）才考虑单函数提取，且建议用 **ROR (Reflective DLL)** 模式而非裸 Shellcode。

---

## 入口点执行（`CallEntry`）

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
| **无依赖加载器** | 移除 `GetModuleHandle`/`LoadLibrary`/`GetProcAddress`，改用 PEB 遍历 + 导出表解析 | [[reverse-engineering-beginner-learning-path]] 进阶篇、[[pe-export-table-internals]] |
| **x64 适配** | `IMAGE_NT_HEADERS64`、`RIP` 相对寻址、`DIR64` 重定位、栈对齐、调用约定 |  |
| **反调试/反注入** | 在 `CallEntry` 前插入 `NtGlobalFlag`、`BeingDebugged` 检查、时间检测 |  |
| **导出表构建/转发** | 为映射模块构建导出表，支持外部 `GetProcAddress`、转发导出 | [[pe-export-table-internals]] |

---

## 常见坑点速查表

| 症状 | 可能原因 | 排查建议 |
|------|----------|----------|
| `Access Violation` 于 `CallEntry` | IAT 未修复 / 函数地址为 0 | 打印 `lpFuncAddress`、检查 DLL 是否真加载成功 |
| 重定位后立即崩溃 | `Delta` 计算错误 / 类型判断遗漏 `DIR64` | 对比 `ImageBase` 与 `pMemData`，打印每个修正项 |
| 控制台无输出/闪退 | 入口点为 GUI (`/SUBSYSTEM:WINDOWS`) | 检查 `OptionalHeader.Subsystem`，或改用 `CreateProcess` + `DEBUG_PROCESS` 调试 |
| 抹除头后无法调试 | 调试器依赖 PE 头定位模块 | 调试前先不调用 `ErasurePEHeader`，或使用硬件断点 |
| 依赖 DLL 版本不匹配 | `LoadLibrary` 加载了系统目录不同版本 | 使用 `LoadLibraryEx` + `LOAD_WITH_ALTERED_SEARCH_PATH` 指定目录 |
| Shellcode 执行崩溃 | DEP 开启 / 函数边界不全 / 绝对地址未重定位 | `VirtualProtect` + 完整 CFG 边界提取 + 重定位感知 |
| 导出函数外部调用失败 | 导出表未映射 / 名称表未排序 / 转发导出未处理 | 严格按规范构建三表、实现 `MyGetProcAddress` 测试 |

---

## 交叉引用与延伸阅读

- [[phantom-dll-hollowing-technique]] — 幽灵 DLL 空洞化：利用已加载合法 DLL 内存区段注入，配合 PE 头抹除实现更隐蔽的无文件执行。
- [[windows-syscall-internals-sysenter-kifastcallentry]] — 系统调用全链路：理解 `LoadLibrary`/`GetProcAddress` 底层如何经 `ntdll` → `sysenter` → `KiFastCallEntry` 进入内核，辅助实现无 API 导入/导出表解析。
- [[reverse-engineering-beginner-learning-path]] — 逆向入门路线：从 PE 结构、导入/导出表、重定位表到手动映射器编写的完整学习曲线。
- [[ida-pro-tips-plugins-python]] — IDA Pro 技巧：利用 FLIRT 签名识别静态库函数、Findcrypt-Yara 识别加密常量、Keypatch 修补二进制，辅助分析加载器壳代码。
- [[binary-ninja-ollvm-deobfuscation]] — Binary Ninja 去混淆：若加载器本身被 OLLVM 平坦化，可用 IL 分析还原控制流。
- [[pe-export-table-internals]] — PE 导出表深度解析：数据结构、三表寻址、手动解析流程、EXE 导出表、模块隐藏关联技术。

---

## 结语

本页完整还原了一个 **教学级 PE 手动映射加载器** 的核心逻辑与代码实现，并结合「二进制安全」导出表文章补充了：

1. **导出表解析与自定义 `GetProcAddress`** —— 实现无 API 依赖的符号解析、支持 Reflective DLL 导出。
2. **模块隐藏技术对比** —— 实测对比“链表摘除”留存 VAD 痕迹 vs “手动映射”仅留私有内存，量化隐蔽性差异。
3. **DEP 绕过与 Shellcode 提取难点** —— `VirtualProtect` 权限控制、多出口/跳转表/重定位感知提取的工程挑战。

掌握该流程可助你：

- **阅读/编写** 任意自定义加载器（加壳器、Shellcode Runner、C2 Stager）
- **动态脱壳**：在 `CallEntry` 前下断点，内存镜像即为解密后原始 PE
- **对抗分析**：理解抹除 PE 头、不挂载 PEB 链表、手动修复 IAT/重定位/导出表如何绕过静态/动态检测
- **工程权衡**：在“提取单函数 Shellcode”与“整体映射 PE”之间根据载荷大小、稳定性、隐蔽性做取舍

> **合规提示**：本技术仅用于安全研究、CTF 竞赛、恶意样本分析及防御规则编写，请遵守所在法律法规与道德规范。

## 来源

- [0x00实验室-202108-202304_006](../sources/0x00实验室-202108-202304_006.md)
