---
title: PE 手动映射加载器完整实现详解
description: 从零构建 Windows PE 手动映射加载器：涵盖文件解析、内存映射、节区拉伸、导入表修复、重定位修正、导出表解析与自定义 GetProcAddress、PE
  头抹除、模块隐藏技术对比、DEP 绕过与 Shellcode 提取难点、入口点执行的全流程 C++ 代码实现与原理剖析。补充延迟导入表处理、API Set Schema
  解析避免转发循环、MEM_IMAGE 内存分配降低疑似度三大关键细节。
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
- 延迟导入表
- API Set Schema
- MEM_IMAGE
- 内存属性伪装
date: '2024-01-15'
updated: '2026-11-15'
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

## PE Loader 三大关键实现细节补充

本节基于归档文章《关于PE不落地执行技术的思考》补充，针对生产级/对抗级 PE Loader 必须处理的三个易被忽视的工程细节。

### 延迟导入表处理

**问题**：主流开源 Loader（如 `MemoryModule`）常忽略 `IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT`，导致依赖延迟加载 DLL 的程序（典型案例：**`cmd.exe` 依赖 `cmdext.dll`**）在映射执行时崩溃或功能缺失。

**机制**：
- 延迟导入表结构 `ImgDelayDescr` 包含：目标 DLL 名、延迟导入 IAT (`pIAT`)、延迟导入 INT (`pINT`)、绑定时间戳、属性标志、处理程序指针 (`pfnDelayLoadHelper`)。
- 系统加载器首次调用该函数时，通过 `__delayLoadHelper2` 触发：`LoadLibrary` → `GetProcAddress` → 回填 IAT → 跳转目标函数。

**手动映射实现要点**：
1. 解析 `OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT]` 定位描述符数组。
2. 遍历每个 `ImgDelayDescr`：
   - 获取 DLL 名（`rvaDLLName` → `LoadLibrary`）。
   - 遍历 `rvaINT`/`rvaIAT` 平行数组，按名称/序号解析函数地址。
   - 直接回填 `rvaIAT` 对应项，**无需保留 Helper 桩代码**。
3. 若目标 PE 自带 `pfnDelayLoadHelper`，可选择调用它（需确保其依赖的 CRT 初始化已完成），但**完全手动回填更稳健、无依赖**。

**伪代码片段**：

```cpp
BOOL CPE::ProcessDelayImportTable() {
    auto& delayDir = pOperationHeader->DataDirectory[IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT];
    if (!delayDir.VirtualAddress) return TRUE;

    PImgDelayDescr pDelayDesc = (PImgDelayDescr)(pMemData + delayDir.VirtualAddress);
    while (pDelayDesc->rvaDLLName) {
        LPCSTR szDllName = (LPCSTR)(pMemData + pDelayDesc->rvaDLLName);
        HMODULE hMod = GetModuleHandleA(szDllName) ?: LoadLibraryA(szDllName);
        if (!hMod) return FALSE; // 或记录错误继续

        PIMAGE_THUNK_DATA pINT = (PIMAGE_THUNK_DATA)(pMemData + pDelayDesc->rvaINT);
        PIMAGE_THUNK_DATA pIAT = (PIMAGE_THUNK_DATA)(pMemData + pDelayDesc->rvaIAT);

        for (; pINT->u1.AddressOfData; ++pINT, ++pIAT) {
            FARPROC pFunc = nullptr;
            if (pINT->u1.Ordinal & IMAGE_ORDINAL_FLAG) {
                pFunc = GetProcAddress(hMod, (LPCSTR)IMAGE_ORDINAL(pINT->u1.Ordinal));
            } else {
                PIMAGE_IMPORT_BY_NAME pName = (PIMAGE_IMPORT_BY_NAME)(pMemData + pINT->u1.AddressOfData);
                pFunc = GetProcAddress(hMod, (LPCSTR)pName->Name);
            }
            if (!pFunc) return FALSE;
            pIAT->u1.Function = (ULONG_PTR)pFunc;
        }
        pDelayDesc++;
    }
    return TRUE;
}
```

> **调用时机**：在 `CallEntry` 中，**导入表修复之后、重定位修正之前/之后均可**，但必须在入口点执行前完成。

---

### API Set Schema 解析避免转发循环

**问题**：自实现 `GetProcAddress`/`LoadLibrary` 时，遇到 `api-ms-win-*-l1-*-*` 类虚拟 DLL 会陷入**转发循环**。
典型案例：`kernel32!InitializeProcThreadAttributeList` → Forwarder `api-ms-win-core-processthreads-l1-1-0!InitializeProcThreadAttributeList` → `LoadLibrary("api-ms-win-core-processthreads-l1-1-0")` → 该虚拟 DLL 导出表再次 Forward 回 `kernel32` → 无限递归。

**根因**：API Set Contract (`api-ms-win-*`) 是**虚拟 DLL**，真实实现宿主通常在 `kernelbase.dll`（或 `kernel32.dll`、`ntdll.dll`）。Windows 加载器内部维护 **API Set Schema 映射表**（存储于 `api-ms-win-core-apiquery-l1-1-0.dll` 资源中，进程启动时映射至 `PEB->ApiSetMap`），实现 Contract Name → Host DLL 的重定向。

**解决方案对比**：

| 方案 | 原理 | 优点 | 缺点 |
|------|------|------|------|
| **方案 A：解析 API Set Schema（正统）** | 1. 从 `PEB->ApiSetMap` (PVOID) 定位 `API_SET_NAMESPACE` 结构<br>2. 遍历 `API_SET_NAMESPACE_ENTRY` 数组，按 `Name` (Counted Unicode String) 匹配 Contract<br>3. 取 `API_SET_VALUE_ENTRY` 中 `Value` (Host DLL 名，如 `kernelbase.dll`)<br>4. 递归在 Host DLL 中查找导出 | 完美兼容系统行为，支持所有版本 Win10/11、Server | 实现复杂，结构未文档化（需逆向 `apiset.h` / `ntdll`），跨版本兼容性需测试 |
| **方案 B：启发式 Fallback（DarkLoadLibrary 风格）** | 1. 检测 DLL 名以 `api-ms-win-` 或 `ext-ms-win-` 开头<br>2. 依次尝试 `LoadLibrary/GetProcAddress` 于 `kernelbase.dll` → `kernel32.dll` → `ntdll.dll`<br>3. 均失败则回退 `LdrGetProcedureAddress` (ntdll 导出) | 代码极简，无需解析未公开结构，覆盖 99% 常见 ApiSet | 极少数转发链较长或宿主非三大核心 DLL 时失效（如 `dbghelp!MiniDumpWriteDump`） |
| **方案 C：混合策略（推荐）** | 优先方案 B 快速命中；失败则方案 A 精确解析；最终回退 `LdrGetProcedureAddress` | 兼顾性能、兼容性、鲁棒性 | 代码量最大 |

**方案 B 核心逻辑（参考 `DarkLoadLibrary::GetProcAddressEx`）**：

```cpp
// 伪代码：启发式解析 ApiSet 转发
FARPROC ResolveApiSetForwarder(LPCSTR lpDllName, LPCSTR lpProcName) {
    if (strncmp(lpDllName, "api-ms-win-", 11) != 0 && strncmp(lpDllName, "ext-ms-win-", 11) != 0)
        return nullptr; // 非 ApiSet 虚拟 DLL

    static const CHAR* s_coreDlls[] = { "kernelbase.dll", "kernel32.dll", "ntdll.dll" };
    for (const CHAR* core : s_coreDlls) {
        HMODULE hMod = GetModuleHandleA(core) ?: LoadLibraryA(core);
        if (hMod) {
            FARPROC pFunc = GetProcAddress(hMod, lpProcName);
            if (pFunc) return pFunc;
        }
    }
    // 最终兜底：系统加载器入口（需确保 ntdll 已映射）
    typedef NTSTATUS(NTAPI* pLdrGetProcedureAddress)(HMODULE, PANSI_STRING, WORD, PVOID*);
    static pLdrGetProcedureAddress LdrGetProcAddr = (pLdrGetProcedureAddress)
        GetProcAddress(GetModuleHandleA("ntdll.dll"), "LdrGetProcedureAddress");
    if (LdrGetProcAddr) {
        ANSI_STRING procName; RtlInitAnsiString(&procName, lpProcName);
        PVOID pFunc = nullptr;
        if (NT_SUCCESS(LdrGetProcAddr(GetModuleHandleA("ntdll.dll"), &procName, 0, &pFunc)))
            return (FARPROC)pFunc;
    }
    return nullptr;
}
```

> **集成点**：在自定义 `MyGetProcAddress` 遇到 Forwarder 字符串形如 `api-ms-win-*.dll.Function` 时，调用上述解析器提取宿主 DLL 与函数名，递归查找。

---

### 将 PE Image 分配至 MEM_IMAGE 内存降低疑似度

**问题**：常规 `VirtualAlloc(..., MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE)` 分配的内存，**VAD 节点类型为 `MEM_PRIVATE`**。携带 `RWX` 权限的 `MEM_PRIVATE` 区域是内存扫描器（Moneta、pe-sieve、MalMemDetect、EDR 内存扫描）的**高优先级检测目标**，极易被标记为 Shellcode/注入载荷。

**目标**：使映射后的 PE 镜像在 VAD 中呈现为 **`MEM_IMAGE`** 类型，模拟合法模块加载的内存特征。

**实现路径**：

#### 路径 A：Section 对象映射（标准方式）
1. `NtCreateSection(&hSection, SECTION_ALL_ACCESS, NULL, &maxSize, PAGE_READONLY, SEC_IMAGE, hFile)`
   - `hFile`：合法 PE 文件句柄（磁盘文件或 **TxF 事务文件** 实现无文件落地）。
   - `SEC_IMAGE`：标记为镜像节区，内存管理器将按节区属性建立 VAD，类型为 `MEM_IMAGE`。
2. `NtMapViewOfSection(hSection, NtCurrentProcess(), &pBase, 0, 0, NULL, &viewSize, ViewShare, 0, PAGE_READWRITE)`
   - 映射至当前进程，获得基址 `pBase`。
3. **后续流程**：在 `pBase` 基础上做重定位修正（若基址冲突）、IAT 修复、TLS 回调、入口点执行。
   - **注意**：`SEC_IMAGE` 映射要求文件为有效 PE，且映射基址倾向于 `ImageBase`。若冲突，`NtMapViewOfSection` 返回 `STATUS_IMAGE_NOT_AT_BASE`，需手动重定位（同用户态重定位逻辑）。

#### 路径 B：Transacted Hollowing 复用（文件落地）
利用 [[process-injection-tampering-techniques]] 中 `Transacted Hollowing` 技巧：
1. 创建 TxF 事务 → 写入 PE Payload → 创建 Image Section → 回滚事务（文件消失，Section 存活）。
2. `NtMapViewOfSection` 将该 Section 映射到**当前进程**（而非傀儡进程）。
3. 此时内存为 `MEM_IMAGE`，且无磁盘文件对应，**完美规避磁盘扫描与 `MEM_PRIVATE` RWX 检测**。

#### 路径 C：手动伪装 VAD（极高难度，不推荐）
尝试通过内核驱动修改 VAD 节点 `u.VadFlags.PrivateMemory=0, ImageMap=1`，但需绕过 PatchGuard，且极易导致系统崩溃，**工程上不可行**。

**代码骨架（路径 A + 磁盘文件示例）**：

```cpp
PBYTE CPE::MapAsMemImage(LPCWSTR wszPePath) {
    HANDLE hFile = CreateFileW(wszPePath, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    if (hFile == INVALID_HANDLE_VALUE) return nullptr;

    HANDLE hSection = NULL;
    LARGE_INTEGER maxSize = {0};
    NTSTATUS status = NtCreateSection(&hSection, SECTION_MAP_READ | SECTION_MAP_WRITE | SECTION_MAP_EXECUTE,
                                      NULL, &maxSize, PAGE_READONLY, SEC_IMAGE, hFile);
    CloseHandle(hFile);
    if (!NT_SUCCESS(status)) return nullptr;

    PVOID pBase = nullptr;
    SIZE_T viewSize = 0;
    status = NtMapViewOfSection(hSection, NtCurrentProcess(), &pBase, 0, 0, NULL, &viewSize, ViewShare, 0, PAGE_READWRITE);
    NtClose(hSection);
    if (!NT_SUCCESS(status)) return nullptr;

    // 此时 pBase 为 MEM_IMAGE 映射基址，后续可直接按本文前文流程做重定位/IAT/TLS/EntryPoint
    // 注意：若 pBase != ImageBase，需手动处理重定位表（同 RelocationTable 逻辑）
    return (PBYTE)pBase;
}
```

**对抗效果对比**：

| 内存属性 | `VirtualAlloc` (RWX) | `SEC_IMAGE` Mapping |
|----------|----------------------|---------------------|
| **VAD Type** | `MEM_PRIVATE` | `MEM_IMAGE` |
| **权限粒度** | 整块 RWX | 按节区 `Characteristics` 自动分页 (RX/RW/RO) |
| **Moneta/pe-sieve 扫描** | **高危告警** | 视为合法模块，**通常跳过** 或仅做签名校验 |
| **磁盘文件关联** | 无 | 有（除非 TxF） |
| **实现复杂度** | 低 | 中（需文件句柄/Section 管理） |

> **权衡建议**：
> - **纯用户态、追求极简、无文件落地**：继续用 `VirtualAlloc` + 精细 `VirtualProtect` 设置节区权限（RX/RW），配合 PE 头抹除、不挂 PEB 链表，对抗用户态扫描。
> - **追求最高隐蔽性、可接受文件落地或 TxF 复杂度**：**强烈建议 `SEC_IMAGE` 映射**，配合 TxF 实现真正 `MEM_IMAGE` 无文件加载，结合 [[process-injection-tampering-techniques]] 中 Transacted Hollowing 技巧。

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
    if (!ProcessDelayImportTable()) return FALSE; // 新增：延迟导入处理
    if (!RelocationTable()) return FALSE;
    ErasurePEHeader();

    __asm {
        mov eax, ExeEntry
        jmp eax
    }
    return TRUE;  // 永不返回
}
```

- **执行顺序**：必须先修复 IAT/延迟导入/重定位，**再**抹除头，最后跳转。
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
| **延迟加载导入** | 解析 `IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT`，实现 `__delayLoadHelper2` 逻辑 | **本页已补充详细实现** |
| **异常处理/SEH** | 注册 `RtlAddFunctionTable` (x64) 或构建 `EXCEPTION_REGISTRATION_RECORD` (x86) |  |
| **无依赖加载器** | 移除 `GetModuleHandle`/`LoadLibrary`/`GetProcAddress`，改用 PEB 遍历 + 导出表解析 + **API Set Schema 解析** | [[reverse-engineering-beginner-learning-path]] 进阶篇、[[pe-export-table-internals]] |
| **x64 适配** | `IMAGE_NT_HEADERS64`、`RIP` 相对寻址、`DIR64` 重定位、栈对齐、调用约定 |  |
| **反调试/反注入** | 在 `CallEntry` 前插入 `NtGlobalFlag`、`BeingDebugged` 检查、时间检测 |  |
| **导出表构建/转发** | 为映射模块构建导出表，支持外部 `GetProcAddress`、转发导出 | [[pe-export-table-internals]] |
| **MEM_IMAGE 映射** | 使用 `SEC_IMAGE` Section 映射替代 `VirtualAlloc`，实现 `MEM_IMAGE` VAD 类型 | **本页已补充详细路径**、[[process-injection-tampering-techniques]] |

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
| `cmd.exe` 等程序启动崩溃 | **未处理延迟导入表** (cmdext.dll) | 补充 `ProcessDelayImportTable` 调用 |
| 自定义 GetProcAddress 死循环/栈溢出 | **ApiSet 转发循环** (api-ms-win-* -> kernel32 -> api-ms-win-*) | 接入 **API Set Schema 解析** 或 **启发式 Fallback** |
| 内存扫描器报警 "RWX MEM_PRIVATE" | 使用 `VirtualAlloc` + `PAGE_EXECUTE_READWRITE` | 改用 **`SEC_IMAGE` 映射** 获得 `MEM_IMAGE`，或精细 `VirtualProtect` 分节区权限 |

---

## 交叉引用与延伸阅读

- [[phantom-dll-hollowing-technique]] — 幽灵 DLL 空洞化：利用已加载合法 DLL 内存区段注入，配合 PE 头抹除实现更隐蔽的无文件执行。
- [[windows-syscall-internals-sysenter-kifastcallentry]] — 系统调用全链路：理解 `LoadLibrary`/`GetProcAddress` 底层如何经 `ntdll` → `sysenter` → `KiFastCallEntry` 进入内核，辅助实现无 API 导入/导出表解析。
- [[reverse-engineering-beginner-learning-path]] — 逆向入门路线：从 PE 结构、导入/导出表、重定位表到手动映射器编写的完整学习曲线。
- [[ida-pro-tips-plugins-python]] — IDA Pro 技巧：利用 FLIRT 签名识别静态库函数、Findcrypt-Yara 识别加密常量、Keypatch 修补二进制，辅助分析加载器壳代码。
- [[binary-ninja-ollvm-deobfuscation]] — Binary Ninja 去混淆：若加载器本身被 OLLVM 平坦化，可用 IL 分析还原控制流。
- [[pe-export-table-internals]] — PE 导出表深度解析：数据结构、三表寻址、手动解析流程、EXE 导出表、模块隐藏关联技术。
- [[process-injection-tampering-techniques]] — 进程注入篡改技术对比：Process Hollowing/Doppelganging/Ghosting/Herpaderping/Transacted Hollowing 原理与 Sysmon Event ID 25 检测对抗，含 `SEC_IMAGE` Section 映射实战细节。
- [[memory-scanning-tools-evasion-techniques]] — 内存扫描工具与规避技术：Moneta、pe-sieve、patriot、BeaconHunter 等检测原理，及 UDRL (FOLIAGE/Ekko/AceLdr) 对抗实测。

---

## 结语

本页完整还原了一个 **教学级 PE 手动映射加载器** 的核心逻辑与代码实现，并结合归档文章《关于PE不落地执行技术的思考》补充了生产级/对抗级 Loader 必须攻克的三大关键细节：

1. **延迟导入表处理** — 解决 `cmd.exe` 等依赖 Delay Load DLL 程序的加载失败问题。
2. **API Set Schema 解析避免转发循环** — 实现健壮的无 API `GetProcAddress`，攻克 `api-ms-win-*` 虚拟 DLL 转发死循环难题。
3. **将 PE Image 分配至 MEM_IMAGE 内存** — 通过 `SEC_IMAGE` Section 映射（可结合 TxF 实现无文件），从 VAD 层面消除 `MEM_PRIVATE` RWX 高危特征，大幅降低内存扫描疑似度。

掌握该流程可助你：

- **阅读/编写** 任意自定义加载器（加壳器、Shellcode Runner、C2 Stager）
- **动态脱壳**：在 `CallEntry` 前下断点，内存镜像即为解密后原始 PE
- **对抗分析**：理解抹除 PE 头、不挂载 PEB 链表、手动修复 IAT/重定位/延迟导入/导出表、API Set 解析、MEM_IMAGE 映射如何协同绕过静态/动态/内存多层检测
- **工程权衡**：在“提取单函数 Shellcode”与“整体映射 PE”、`VirtualAlloc` 与 `SEC_IMAGE` 映射之间根据载荷大小、稳定性、隐蔽性、文件落地约束做取舍

> **合规提示**：本技术仅用于安全研究、CTF 竞赛、恶意样本分析及防御规则编写，请遵守所在法律法规与道德规范。

## 来源

- [0x00实验室-202108-202304_006](../sources/0x00实验室-202108-202304_006.md)
- [0x4d5a-202103-202209_09](../sources/0x4d5a-202103-202209_09.md)
