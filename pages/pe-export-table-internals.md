---
title: PE 导出表内部结构深度解析
description: 系统梳理 PE 导出表的数据结构、三大表寻址机制、手动解析流程，并延伸探讨 EXE 导出表、模块隐藏技术与 DLL/库文件关系。
category: program-analysis
tags:
- PE 格式
- 导出表
- 逆向工程
- Windows Internals
- DLL
- 手动映射
- 模块隐藏
date: 2024-01-15
updated: '2026-11-14'
---

## 概述

**导出表** 将模块对外开放的函数集中成表，供外部通过查表方式动态加载调用。它位于 **数据目录表** 的第一项（索引值为 0）：

```c
// 资源目录表，索引值为零的元素存储导出表结构地址
_IMAGE_DATA_DIRECTORY DataDirectory[0];
```

关键特性：

- 一个 PE 文件**仅有一个**导出表，记录当前文件对外开放的函数接口
- 导出表**常见于 DLL**，但 EXE 同样可以包含导出表（如 `ntoskrnl.exe`）
- 与之对应，一个 PE 文件可拥有**多个导入表**（调用不同 DLL）

> 相关基础：[[reverse-engineering-beginner-learning-path]] 逆向工程入门路径中涵盖 PE 结构基础知识。

---

## DLL 文件与导出函数声明

### DLL 骨架与入口函数

```cpp
#include "stdafx.h"

BOOL APIENTRY DllMain(
    HMODULE hModule,
    DWORD   ul_reason_for_call,
    LPVOID  lpReserved
) {
    switch (ul_reason_for_call) {
        case DLL_PROCESS_ATTACH:
        case DLL_THREAD_ATTACH:
        case DLL_THREAD_DETACH:
        case DLL_PROCESS_DETACH:
            break;
    }
    return TRUE; // 必须返回 TRUE
}
```

### 导出函数声明

```cpp
// extern "C" 防止 C++ Name Mangling
extern "C" _declspec(dllexport) int dllFunAdd(int a, int b);
```

### 模块定义文件

```def
LIBRARY "dllTest"
EXPORTS
dllFunAdd @ 1
```

### 两种加载方式

| 方式 | 关键 API | 特点 |
|------|----------|------|
| **隐式加载** | `#pragma comment(lib, "dllTest.lib")` | 编译期链接，启动时自动加载 |
| **显式加载** | `LoadLibrary` + `GetProcAddress` | 运行时动态加载，灵活可控 |

```cpp
// 显式加载示例
typedef int (*dllFunAdd)(int a, int b);
HMODULE hModule = LoadLibrary(TEXT("dllTest.dll"));
dllFunAdd fun = (dllFunAdd)GetProcAddress(hModule, "dllFunAdd");
fun(1, 2);
```

> 手动映射加载器实现细节见 [[pe-manual-mapping-loader-implementation]]。

---

## 导出表目录结构与手动解析

### 数据目录表项

```c
typedef struct _IMAGE_DATA_DIRECTORY {
    DWORD VirtualAddress;  // RVA
    DWORD Size;            // 表大小
} IMAGE_DATA_DIRECTORY, *PIMAGE_DATA_DIRECTORY;
```

示例数值：

- 导出表 RVA：`0x16CA0`
- 导出表大小：`0x156`
- 所在节区：`.rdata`（RVA `0x15000`，FOA `0x3E00`）

### 导出表目录结构

```c
typedef struct _IMAGE_EXPORT_DIRECTORY {
    DWORD   Characteristics;
    DWORD   TimeDateStamp;
    WORD    MajorVersion;
    WORD    MinorVersion;
    DWORD   Name;                    // DLL 名称 RVA
    DWORD   Base;                    // 起始序号
    DWORD   NumberOfFunctions;       // 函数地址表项数
    DWORD   NumberOfNames;           // 函数名称表项数
    DWORD   AddressOfFunctions;      // 函数地址表 RVA (EAT)
    DWORD   AddressOfNames;          // 函数名称表 RVA (ENT)
    DWORD   AddressOfNameOrdinals;   // 函数序号表 RVA (EOT)
} IMAGE_EXPORT_DIRECTORY, *PIMAGE_EXPORT_DIRECTORY;
```

示例偏移换算：

| 表 | RVA | FOA |
|----|-----|-----|
| AddressOfFunctions (EAT) | `0x16CC8` | `0x5AC8` |
| AddressOfNames (ENT) | `0x16CCC` | `0x5ACC` |
| AddressOfNameOrdinals (EOT) | `0x16CD0` | `0x5AD0` |

---

## 三大表寻址机制

### 表结构对照

| 表名 | 成员类型 | 作用 |
|------|----------|------|
| **函数名称表 (ENT)** | `DWORD[]` | 每元素存储一个函数名称字符串的 RVA |
| **函数序号表 (EOT)** | `WORD[]` | 每元素存储对应函数在**地址表**中的索引 |
| **函数地址表 (EAT)** | `DWORD[]` | 每元素存储函数代码入口的 RVA |

### 查找流程

1. 在 **ENT** 中按字符串匹配找到目标函数名，获得下标 `i`
2. 用 `i` 索引 **EOT**，得到 `ordinal = EOT[i]`
3. 用 `ordinal` 索引 **EAT**，得到 `funcRVA = EAT[ordinal]`
4. `funcRVA + ImageBase` 即为函数真实入口地址

> 该机制也是 [[pe-manual-mapping-loader-implementation]] 中导入表修复阶段解析导出函数的核心逻辑。

### 关键推论

> 如果已知函数入口地址，即使没有导出表，也可**手工构造导出表**供外部调用。导出表本质是「函数名 → 入口地址」的索引映射。

---

## 进阶话题：模块隐藏与手动映射

### 传统隐藏局限

- 从内核模块链表摘除仅隐藏链表视图
- 内存遍历仍能发现 `LoadLibrary` 加载的模块痕迹（VAD、节区映射等）

> Windows 内核系统调用链路见 [[windows-syscall-internals-sysenter-kifastcallentry]]。

### 手动映射实现隐藏

核心思路：**不调用 `LoadLibrary`，自行解析 PE、映射节区、修复导入/重定位、执行入口点**。

```cpp
// 伪代码流程
BYTE* raw = ReadFile("target.dll");
ParseHeaders(raw);
MapSections(raw);
FixImports(raw);      // 需解析目标 DLL 的导出表
FixRelocations(raw);
ExecuteEntryPoint(raw);
```

> 完整 C++ 实现参考 [[pe-manual-mapping-loader-implementation]]。

### Shellcode 形式调用导出函数

1. 反汇编提取目标函数机器码（需处理多 `ret`、跳转等控制流）
2. 写入可执行内存（`VirtualAlloc` + `PAGE_EXECUTE_READWRITE` 或 `VirtualProtect` 修改栈页属性）
3. 函数指针强转调用

```cpp
BYTE addFun[] = { 0x55, 0x8B, 0xEC, ... }; // 机器码
((int(*)(int,int))addFun)(1, 2);
```

### 面临的工程挑战

| 维度 | 问题 |
|------|------|
| **提取准确性** | 自动识别函数边界（多出口、异常处理、尾跳转） |
| **时间开销** | 重复解析耗时 → 需缓存机制 |
| **空间开销** | 常驻内存体积膨胀 |
| **安全性** | 关闭 DEP 易遭 Shellcode 注入；开启 DEP 需动态修改页属性，扩大攻击面 |

> 类似思路的高级内存注入技术见 [[phantom-dll-hollowing-technique]]（Phantom DLL Hollowing）。

---

## 进阶话题：EXE 也可以导出函数

### 实验验证

```c
// dllExportExe.c
#include <stdio.h>
extern "C" __declspec(dllexport) int ExeExportAdd(int a, int b) {
    return a + b;
}
```

```def
LIBRARY "dllExportExe"
EXPORTS
ExeExportAdd @ 1
```

编译生成 `exe`、`lib`、`pdb`。使用 `dumpbin /exports` 可见导出表。

### 典型案例：`ntoskrnl.exe`

Windows 内核镜像导出大量内核例程（`PsCreateSystemThread`、`KeDelayExecutionThread` 等），供驱动动态链接。

---

## 附录：.dll 与 .lib 关系速查

| 场景 | 说明 |
|------|------|
| **动态链接** | `.lib` = 导入库，含符号索引与 RVA；`.dll` = 运行时代码实现 |
| **静态链接** | `.lib` = 完整代码+数据，链接期合并进 EXE，无需 DLL |
| **仅有 .lib** | 若为静态库，部署简单但体积大、升级需重发布 EXE |
| **PDB** | 调试符号文件，含源文件/行号/变量名/FPO 信息，通常仅 Debug 生成 |

---

## 交叉引用索引

- [[pe-manual-mapping-loader-implementation]] — 手动映射加载器完整实现（导入表修复、重定位、入口点执行）
- [[phantom-dll-hollowing-technique]] — 幽灵 DLL 空洞化技术（合法模块内存劫持）
- [[windows-syscall-internals-sysenter-kifastcallentry]] — 用户态到内核态系统调用全链路
- [[reverse-engineering-beginner-learning-path]] — 逆向工程入门学习路径
- [[crackme-analysis-keygen-development-case-study]] — CrackMe 算法分析与注册机编写实战
- [[ida-pro-tips-plugins-python]] — IDA Pro 签名生成、插件安装、IDAPython 配置
- [[binary-ninja-ollvm-deobfuscation]] — Binary Ninja IL 分析去除 OLLVM 流程平坦化

## 来源

- [0x00实验室-202108-202304_006](../sources/0x00实验室-202108-202304_006.md)
