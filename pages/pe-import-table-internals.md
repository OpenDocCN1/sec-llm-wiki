---
title: PE 导入表内部结构与加载机制详解
description: 系统梳理 PE 文件导入表（Import Table）的数据结构、双桥机制（INT/IAT）、加载时地址修复流程、绑定导入表原理及静态分析实战定位方法
category: program-analysis
tags:
- PE 格式
- 导入表
- 逆向工程
- Windows Internals
- IAT
- INT
- 绑定导入
- 静态分析
date: '2024-01-15'
updated: '2026-11-14'
---

## 概述

导入表位于 PE 文件可选 PE 头中 `DataDirectory` 字段的第二项（索引值为 1）。Windows 为减少应用程序间的重复功能代码，将常用功能函数抽离形成 DLL 文件，DLL 通过导出表对外提供函数，应用程序通过导入表引用这些函数。

> 相关页面：[[pe-export-table-internals]] 详细描述了导出表的三大表寻址机制，与导入表形成对应关系。

## 可选 PE 头与数据目录表

### `IMAGE_OPTIONAL_HEADER` 关键字段

```c
typedef struct _IMAGE_OPTIONAL_HEADER {
    // ...
    WORD    Magic;                      // 0x10B (PE32) / 0x20B (PE32+)
    DWORD   AddressOfEntryPoint;        // 程序执行入口 OEP (RVA)
    DWORD   ImageBase;                  // 首选装载地址
    DWORD   SectionAlignment;           // 内存对齐粒度
    DWORD   FileAlignment;              // 文件对齐粒度
    DWORD   SizeOfImage;                // 映像装入内存后总尺寸
    DWORD   SizeOfHeaders;              // 头部总大小
    DWORD   NumberOfRvaAndSizes;        // 数据目录项数，固定 16
    IMAGE_DATA_DIRECTORY DataDirectory[16]; // 数据目录表
} IMAGE_OPTIONAL_HEADER, *PIMAGE_OPTIONAL_HEADER;
```

### `IMAGE_DATA_DIRECTORY` 结构

```c
typedef struct _IMAGE_DATA_DIRECTORY {
    DWORD VirtualAddress;  // 相对虚拟地址 (RVA)
    DWORD Size;            // 表大小
} IMAGE_DATA_DIRECTORY, *PIMAGE_DATA_DIRECTORY;
```

数据目录表第 1 项（索引 1）存储导入表的 RVA 与大小。

| 索引 | 名称 | 说明 |
|------|------|------|
| 0 | Export Table | 导出表 |
| **1** | **Import Table** | **导入表** |
| 2 | Resource Table | 资源表 |
| 11 | Bound Import Table | 绑定导入表 |
| 12 | Import Address Table (IAT) | 导入地址表 |
| 13 | Delay Import Descriptor | 延迟导入表 |

## 导入表核心数据结构

### `IMAGE_IMPORT_DESCRIPTOR` —— 每个被导入 DLL 对应一个

```c
typedef struct _IMAGE_IMPORT_DESCRIPTOR {
    union {
        DWORD   Characteristics;            // 0 为终止符
        DWORD   OriginalFirstThunk;         // RVA → INT (导入名称表)
    } DUMMYUNIONNAME;
    DWORD   TimeDateStamp;                  // 时间戳 / 绑定标记
    DWORD   ForwarderChain;                 // 转发器链索引
    DWORD   Name;                           // RVA → DLL 名称 ASCII 字符串
    DWORD   FirstThunk;                     // RVA → IAT (导入地址表)
} IMAGE_IMPORT_DESCRIPTOR, *PIMAGE_IMPORT_DESCRIPTOR;
```

| 字段 | 含义 | 加载前 | 加载后 |
|------|------|--------|--------|
| `OriginalFirstThunk` | 指向 **INT** 数组 | 指向 `IMAGE_THUNK_DATA` 数组 | 不变 |
| `FirstThunk` | 指向 **IAT** 数数组 | 与 INT 指向相同内容 | 被重写为函数真实虚拟地址 |
| `TimeDateStamp` | 0 = 未绑定；`0xFFFFFFFF` = 已绑定 | — | — |
| `Name` | DLL 文件名 (ASCII) | — | — |

> **终止条件**：连续两个全零的 `IMAGE_IMPORT_DESCRIPTOR` 标志导入表结束。

### `IMAGE_THUNK_DATA32` / `IMAGE_THUNK_DATA64` —— INT/IAT 数组元素

```c
// 32 位
typedef struct _IMAGE_THUNK_DATA32 {
    union {
        DWORD ForwarderString;      // RVA → 转发器字符串
        DWORD Function;             // 函数地址 (加载后)
        DWORD Ordinal;              // 序号 (高位置 1)
        DWORD AddressOfData;        // RVA → IMAGE_IMPORT_BY_NAME
    } u1;
} IMAGE_THUNK_DATA32, *PIMAGE_THUNK_DATA32;

// 64 位同理，字段宽度为 64 位
```

- **INT 数组**：每个元素的 `AddressOfData` 指向 `IMAGE_IMPORT_BY_NAME`  
- **IAT 数组**：加载前与 INT 相同；加载后 `Function` 字段被填入函数实际虚拟地址

### `IMAGE_IMPORT_BY_NAME` —— 函数名或序号

```c
typedef struct _IMAGE_IMPORT_BY_NAME {
    WORD    Hint;                   // 建议序号 (加快导出表查找)
    CHAR    Name[1];                // 以 '\0' 结尾的函数名字符串 (变长)
} IMAGE_IMPORT_BY_NAME, *PIMAGE_IMPORT_BY_NAME;
```

> `Name[1]` 仅为占位，实际字符串紧随其后，静态分析时按 C 风格字符串读取即可。

## 双桥机制：INT 与 IAT

```
                    ┌─────────────────────┐
                    │ IMAGE_IMPORT_DESCRIPTOR │
                    │  OriginalFirstThunk ──────┐
                    │  FirstThunk ─────────────┐│
                    └─────────────────────┘   ││
                                              ▼▼
                                    ┌───────────────────┐
                                    │ IMAGE_THUNK_DATA[] │  ← 数组，每项 4/8 字节
                                    │  (INT / IAT 共用)  │
                                    └─────────┬─────────┘
                                              │
                        ┌─────────────────────┼─────────────────────┐
                        ▼                     ▼                     ▼
               ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
               │ IMAGE_IMPORT_│      │ IMAGE_IMPORT_│      │   (更多)     │
               │   BY_NAME    │      │   BY_NAME    │      │              │
               │  (Hint+Name) │      │  (Hint+Name) │      │              │
               └──────────────┘      └──────────────┘      └──────────────┘
```

| 别名 | 字段 | 作用 | 加载前内容 | 加载后内容 |
|------|------|------|------------|------------|
| **INT** (Import Name Table) | `OriginalFirstThunk` | 保存函数名/序号索引 | `AddressOfData` → `IMAGE_IMPORT_BY_NAME` | **不变** |
| **IAT** (Import Address Table) | `FirstThunk` | 运行时直接调用入口 | 同 INT | `Function` = 函数真实虚拟地址 |

**加载器流程**：
1. 遍历导入表每个 `IMAGE_IMPORT_DESCRIPTOR`
2. 根据 `Name` 加载对应 DLL（见 [DLL 搜索顺序](#dll-搜索顺序)）
3. 遍历 INT 数组，取 `Hint`/`Name` 在 DLL 导出表查找函数地址
4. 将地址写入 IAT 对应位置（覆盖原 `AddressOfData`）
5. 代码通过 `CALL [IAT入口]` 间接调用目标函数

## 加载时地址修复流程

### DLL 搜索顺序（经典顺序，现代系统有 SafeDllSearchMode 差异）

1. 已加载模块列表（同名 DLL 直接复用）
2. 系统已知 DLL 列表（注册表 `KnownDLLs`）
3. 应用程序所在目录
4. 系统目录 (`%SystemRoot%\System32`)
5. 16 位系统目录 (`%SystemRoot%\System`)
6. Windows 目录 (`%SystemRoot%`)
7. 当前工作目录
8. `PATH` 环境变量目录

> ⚠️ 不同 Windows 版本顺序可能差异，且可能引发 **DLL 劫持** 风险。

### 绑定导入表 —— 预先固化 IAT 加速启动

#### 原理
- 链接器/工具（如 `Bind.exe`）在构建阶段预先解析 DLL 导出表，将函数地址直接写入 IAT
- `TimeDateStamp = 0xFFFFFFFF` 标记已绑定
- 绑定信息记录在 **绑定导入表**（数据目录索引 11）中，包含目标 DLL 时间戳与校验和

#### 失效与修复
| 失效原因 | 修复机制 |
|----------|----------|
| DLL 基址冲突导致重定位 | 加载器检测时间戳不匹配，回退到 INT 重新解析 |
| DLL 版本更新导出地址变化 | 同上 |
| DLL 缺失 | 加载失败 |

> **关键点**：INT 始终保留完整导入信息，作为回退路径。

#### 判断是否绑定
```c
if (pImportDesc->TimeDateStamp == 0)          // 未绑定
if (pImportDesc->TimeDateStamp == 0xFFFFFFFF) // 已绑定
```

## 静态分析实战：手工定位导入函数

### RVA → 文件偏移 转换公式
```
FileOffset = TargetRVA - SectionRVA + SectionPointerToRawData
```
前提：目标 RVA 位于该节区范围内。

### 分析步骤（以 32 位 PE 为例）

1. **定位可选 PE 头**  
   `DOS头.e_lfanew` → `NT_HEADERS` → `OptionalHeader.DataDirectory[1]` 获取导入表 RVA 与大小

2. **定位导入表所在节区**  
   遍历节区表，找到包含导入表 RVA 的节区，计算文件偏移

3. **遍历 `IMAGE_IMPORT_DESCRIPTOR` 数组**  
   - 读取 `Name` → DLL 名称  
   - 读取 `OriginalFirstThunk` → INT 数组 RVA  
   - 读取 `FirstThunk` → IAT 数组 RVA

4. **遍历 INT 数组**  
   - 每项取 `AddressOfData` → `IMAGE_IMPORT_BY_NAME`  
   - 读取 `Hint` 与 `Name` 字符串

5. **（可选）对比 IAT**  
   - 文件中 IAT 与 INT 内容一致 → 未绑定  
   - IAT 已为真实地址 → 已绑定或已在内存中执行过（动态调试时）

### 实战示例：简单 PE（单 DLL 单函数）

| 项目 | 值 |
|------|-----|
| 文件对齐 | `0x200` |
| 导入表 RVA | `0x19188` |
| 节区 RVA | `0x19000` |
| 节区文件偏移 | `0x6400` |
| **导入表文件偏移** | `0x19188 - 0x19000 + 0x6400 = 0x6588` |

在 `0x6588` 处解析 `IMAGE_IMPORT_DESCRIPTOR`，随后按链路追踪即可得到函数名 `MessageBoxA` 等。

### 复杂 PE：记事本 多 DLL 多函数

- 每个 DLL 对应一个 `IMAGE_IMPORT_DESCRIPTOR`
- INT 数组以全零项结束
- 同一 DLL 的多个函数在 INT 数组中连续排布
- 不同 DLL 的描述符在导入表中连续排布

## 结构对齐与保留字段观察

- 所有 PE 结构体均按 **4 字节对齐** 设计
- 空隙由 `Reserved` / 填充字段占位，便于版本扩展
- 64 位 PE 仅指针字段扩展为 8 字节，其余逻辑不变

## 交叉引用速查

| 主题 | 页面 |
|------|------|
| 导出表对应结构 | [[pe-export-table-internals]] |
| 手动映射加载器中导入表修复实现 | [[pe-manual-mapping-loader-implementation]] |
| 内存注入与模块隐藏技术 | [[phantom-dll-hollowing-technique]] |
| 系统调用与内核入口 | [[windows-syscall-internals-sysenter-kifastcallentry]] |

## 小结

1. **导入表入口**：`DataDirectory[1]` → `IMAGE_IMPORT_DESCRIPTOR` 数组  
2. **双桥设计**：INT 保留静态索引，IAT 运行时填充真实地址，支持绑定回退  
3. **加载流程**：DLL 搜索 → 导出表匹配 → IAT 重写 → 间接调用  
4. **绑定优化**：预填 IAT，`TimeDateStamp=0xFFFFFFFF` 标记，失效自动回退 INT  
5. **静态分析核心**：RVA→Offset 转换 + 结构体链式追踪（DESCRIPTOR → INT → BY_NAME）

> 本页结合微信公众号文章《详解二进制PE文件 \| 导入表技术》及经典参考资料《Windows下32位汇编语言程序设计(第3版)》整理而成。

## 来源

- [0x00实验室-202108-202304_008](../sources/0x00实验室-202108-202304_008.md)
