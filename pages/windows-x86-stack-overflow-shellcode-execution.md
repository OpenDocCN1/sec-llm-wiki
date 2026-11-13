---
title: Windows x86 栈溢出 Shellcode 执行全流程解析
description: 系统梳理 Windows x86 环境下基于栈溢出的 Shellcode 执行全流程：栈帧布局分析、strcpy 溢出覆盖返回地址、利用
  jmp esp 动态定位 Shellcode、通过 FS:[0x30] 遍历 PEB 定位 kernel32.dll 并解析导出表获取 LoadLibraryA/GetProcAddress
  地址、以及 Shellcode 零字节截断问题的加解密绕过方案。
category: program-analysis
tags:
- Windows Internals
- x86 Assembly
- Stack Overflow
- Shellcode
- PEB
- Export Table
- Exploit Development
- Reverse Engineering
- 0w1Club
date: '2023-04-16'
updated: '2026-11-14'
---

## 概览

本页面系统整理 Windows x86 环境下栈溢出漏洞利用的核心技术链路。从函数调用栈帧布局入手，剖析 `strcpy` 等不安全函数如何破坏栈结构并覆盖返回地址；进而引入 `jmp esp` 技术实现 Shellcode 地址的动态定位；随后通过 `FS:[0x30]` 访问 PEB（进程环境块），遍历模块链表定位 `kernel32.dll` 基址，手动解析 PE 导出表获取 `LoadLibraryA` 与 `GetProcAddress` 地址，实现 Shellcode 在无导入表依赖下的动态 API 解析；最后讨论 Shellcode 中零字节（`\x00`）导致的字符串截断问题，给出加解密编码绕过方案。

> **来源**：0w1Club 微信公众号文章《深度剖析堆栈中ShellCode的利用原理》（2023-04-16）。文章大纲涵盖四大模块：① 栈帧基础与 Shellcode 操作理论；② 利用 `fs` 寄存器定位 DLL 入口；③ 从 DLL 导出表寻找 `LoadLibraryA`；④ Shellcode 零字节截断与加解密绕过。本页面在忠实原文核心内容（模块 ① 及 `jmp esp` 实战）基础上，补全模块 ②③④ 的技术脉络，并建立交叉引用。

---

## 栈帧布局与函数调用约定

### x86 函数调用的栈变化

在 `__cdecl` 调用约定下，函数调用流程如下：

1. **参数压栈**：调用者从右向左压入参数。
2. **`call` 指令**：将下一条指令地址（返回地址）压栈，跳转至被调函数。
3. **函数序言**：
   ```asm
   push ebp           ; 保存旧栈帧基址
   mov  ebp, esp      ; 建立新栈帧
   sub  esp, 0xC0     ; 分配局部变量空间（示例中为 0xC0 字节）
   push ebx / esi / edi   ; 保存被调用者保存寄存器
   ```
4. **函数体执行**：访问参数用 `[ebp+8]`、`[ebp+0xC]`…，访问局部变量用 `[ebp-x]`。
5. **函数尾声**：
   ```asm
   pop  edi / esi / ebx
   add  esp, 0xC0     ; 释放局部变量空间
   pop  ebp           ; 恢复旧栈帧基址
   ret                ; 弹出返回地址跳转
   ```

### 栈帧示意图

```
高地址
+------------------+
|   调用者参数     |  <-- [ebp+8] 第一个参数
+------------------+
|   返回地址 (EIP) |  <-- [ebp+4]  关键控制流目标
+------------------+
|   旧 EBP 值      |  <-- [ebp]    栈帧链表指针
+------------------+
|   局部变量       |  <-- [ebp-x]  如 char arr[4] 在 [ebp-8]
|   ...            |
|   保存的寄存器   |
+------------------+
|   新栈顶 (ESP)   |
低地址
```

> **关键点**：局部缓冲区（如 `arr[4]`）位于旧 EBP 与返回地址**下方**（低地址方向）。若向缓冲区写入超长数据，将依次覆盖：旧 EBP → 返回地址 → 甚至更高地址的调用者栈帧。

---

## `strcpy` 栈溢出覆盖返回地址

### 危险函数特性

`strcpy(char *dest, const char *src)` **不检查长度**，遇 `\0` 才停止。若 `src` 可控且长度超过 `dest` 分配空间，必然发生栈溢出。

### 实战汇编还原

```asm
; fun(const char *c) { char arr[4]; strcpy(arr, c); }
; 参数 c 在 [ebp+8]
mov  eax, [ebp+8]      ; eax = src 指针
push eax               ; 压入 src
lea  ecx, [ebp-8]      ; ecx = &arr (dest)
push ecx               ; 压入 dest
call strcpy            ; 执行拷贝
add  esp, 8            ; 清理参数栈
```

### 溢出后的栈状态变化

输入 `11111111111111111111`（20 字节）覆盖 `arr[4]`（4 字节）后：

| 偏移 (相对 arr) | 原内容 | 溢出后内容 | 影响 |
|----------------|--------|------------|------|
| 0x00 ~ 0x03    | arr[4] | `1111`     | 缓冲区填满 |
| 0x04 ~ 0x07    | 旧 EBP | `1111`     | **栈帧链表破坏** |
| 0x08 ~ 0x0B    | 返回地址 | `1111`  | **控制流劫持** |
| 0x0C ~ ...     | 调用者栈帧 | `1111` | 连带破坏 |

> **结论**：精心构造输入，可将返回地址覆盖为 Shellcode 起始地址，函数 `ret` 时即跳转执行 Shellcode。

---

## 动态定位 Shellcode：`jmp esp` 技术

### 问题：地址不固定

由于 ASLR、栈地址随机化、环境差异，Shellcode 在栈上的绝对地址每次运行不同，**硬编码地址不可行**。

### 解决思路：寻找固定地址的 `jmp esp` / `call esp` 指令

1. **原理**：系统 DLL（如 `kernel32.dll`、`user32.dll`）加载基址相对固定（早期 Windows 无 ASLR 时完全固定，有 ASLR 时模块基址随机化但模块内偏移不变）。
2. **操作**：在调试器中搜索 `jmp esp` (`FF E4`) 或 `call esp` (`FF D4`) 机器码，记录其虚拟地址（如 `0x7C8369F0`）。
3. **利用链**：
   - 将返回地址覆盖为 `jmp esp` 地址。
   - 函数 `ret` → 跳转到 `jmp esp` → `esp` 此时指向栈上紧随返回地址之后的数据 → **恰好是 Shellcode 开头**。
   - 实现“返回地址 → 固定指令 → 动态栈地址”两级跳转。

### 为什么选系统 DLL？

- 系统 DLL 随进程启动**最早加载**，基址冲突概率低。
- 同版本 OS、同补丁级别下，`jmp esp` 偏移**跨进程复用**可能性高。
- 现代 Windows 开启 ASLR 后，模块基址随机化，需配合**信息泄露**或**模块基址暴力破解**（32 位空间较小可行）。

> **关联阅读**：[[pe-export-table-internals]] 了解 DLL 导出表结构，[[pe-manual-mapping-loader-implementation]] 理解手动映射与基址计算。

---

## 通过 PEB 定位 `kernel32.dll` 并解析导出表

> **注**：原文大纲模块 ②③ 未展开正文，此处补全技术脉络以形成完整知识链路。

### 为何需要 PEB 遍历？

Shellcode 运行时**无导入表**，无法直接调用 API。必须在内存中动态查找：
1. `kernel32.dll` 基址
2. `LoadLibraryA` 地址 → 加载其他 DLL
3. `GetProcAddress` 地址 → 解析任意导出函数

### `FS:[0x30]` 访问 PEB

- x86 下 `FS` 段寄存器指向 **TEB（线程环境块）**。
- `FS:[0x30]` 偏移处存储 **PEB 指针**。
- PEB 结构关键字段（偏移基于 32 位）：

```c
typedef struct _PEB {
    BYTE Reserved1[2];
    BYTE BeingDebugged;
    BYTE Reserved2[1];
    PVOID Reserved3[2];
    PPEB_LDR_DATA Ldr;        // +0x0C  指向加载器数据
    // ...
} PEB, *PPEB;
```

### 遍历 `InLoadOrderModuleList` 定位 `kernel32.dll`

1. 从 `PEB->Ldr` (`+0x0C`) 获取 `PEB_LDR_DATA*`。
2. 取 `InLoadOrderModuleList` 列表头 (`+0x0C`)。
3. 遍历 `LDR_DATA_TABLE_ENTRY` 链表，每个节点包含：
   - `DllBase` (`+0x18`)：模块基址
   - `BaseDllName` (`+0x2C`)：`UNICODE_STRING` 模块名
4. 比对模块名（不区分大小写）为 `KERNEL32.DLL`，获取其 `DllBase`。

### 手动解析 PE 导出表获取 `LoadLibraryA` / `GetProcAddress`

1. 从 `DllBase` 读取 `IMAGE_DOS_HEADER` → `e_lfanew` 定位 `IMAGE_NT_HEADERS`。
2. 从 `OptionalHeader.DataDirectory[0]` (Export Directory) 获取导出表 RVA/Size。
3. 导出表关键字段：
   - `AddressOfNames`：函数名 RVA 数组
   - `AddressOfFunctions`：函数地址 RVA 数组
   - `AddressOfNameOrdinals`：序号数组（与 Names 对应）
4. 遍历 `AddressOfNames`，计算哈希或直接比对字符串 `"LoadLibraryA"`、`"GetProcAddress"`。
5. 找到索引 `i` → 序号 `ordinal = AddressOfNameOrdinals[i]` → 函数 RVA `AddressOfFunctions[ordinal]` → 绝对地址 `DllBase + RVA`。

> **详细数据结构与解析流程**：参见 [[pe-export-table-internals]]、[[pe-manual-mapping-loader-implementation]]。

---

## Shellcode 零字节截断问题与加解密绕过

### 问题根源

- Shellcode 常作为**字符串参数**传入（如 `strcpy`、`gets`、`sprintf`）。
- C 字符串以 `\0` 结尾，**Shellcode 中出现 `0x00` 会导致拷贝/传输截断**，Payload 不完整。
- 常见产生 `0x00` 的指令：
  - `mov eax, 0` → `B8 00 00 00 00`
  - `call 0x00401000` → 相对偏移含 `00`
  - 字符串字面量结尾 `\0`

### 绕过方案：编码 / 加密 + 解码存根

| 方案 | 原理 | 典型实现 |
|------|------|----------|
| **XOR 编码** | 用单字节密钥异或全体 Shellcode，密钥选非 `0x00` 且使结果无 `0x00` | `encoder.py` 生成，解码存根 `xor byte [esi], al` 循环 |
| **Alpha2 / Alpha3 编码** | 将 Shellcode 编码为纯字母数字字符（`A-Z, a-z, 0-9`），天然无 `0x00` | `msfvenom -e x86/alpha_mixed` |
| **Shikata Ga Nai** | 多态编码器，每次生成不同指令序列，避免特征匹配 | Metasploit 默认编码器 |
| **自定义加密** | AES/RC4 等，解密存根放前端，密钥硬编码或派生 | 需更大存根体积 |

### 解码存根设计要点

1. **位置无关**：使用 `call $+5 / pop esi` 获取当前 EIP，计算 Shellcode 地址。
2. **长度已知**：存根中硬编码 Payload 长度，或以特殊标记结尾。
3. **避免坏字符**：存根本身也不含 `0x00`、`\n`、`\r` 等上下文敏感字符。
4. **内存可写**：若栈不可写（DEP），需先 `VirtualProtect` 或跳转到可写可执行区（如堆、`.data` 节）。

> **实战提示**：现代 Windows 开启 DEP（NX）后，栈默认不可执行，单纯栈溢出执行 Shellcode 会失败。需结合 **ROP 链** 调用 `VirtualProtect`/`VirtualAlloc` 修改内存属性，或使用 **Ret2Libc** 直接调用 `system("cmd")`。详见 [[rop-linux-x86-beginner-tutorial]]（Linux 原理通用）、[[mtctf-2021-pwn-writeup]]（`setcontext+mprotect` 实战）。

---

## 完整利用链小结

```
[输入缓冲区溢出]
       │
       ▼
[覆盖返回地址 = jmp esp 地址]
       │
       ▼
[ret → jmp esp → ESP 指向 Shellcode]
       │
       ▼
[Shellcode 解码存根] → 还原真实 Payload
       │
       ▼
[FS:[0x30] → PEB → Ldr → kernel32.dll 基址]
       │
       ▼
[手动解析导出表 → LoadLibraryA / GetProcAddress]
       │
       ▼
[动态加载 DLL & 解析任意 API] → 业务逻辑（反弹 Shell、加载插件…）
```

---

## 关键防御与缓解措施

| 机制 | 作用 | 对本利用链的影响 |
|------|------|------------------|
| **GS / Stack Canary** | 在返回地址前放置随机 Cookie，函数尾声校验 | 覆盖返回地址前必覆盖 Cookie → 触发终止 |
| **DEP / NX** | 标记栈/堆不可执行 | `jmp esp` 跳转栈执行 Shellcode 直接失败 |
| **ASLR** | 模块基址、栈、堆随机化 | `jmp esp` 固定地址失效，PEB 遍历仍可行但需泄露基址 |
| **SafeSEH / SEHOP** | 保护异常处理链 | 防止利用 SEH 覆盖绕过 GS |
| **CFG / CET** | 间接跳转目标合法性校验 | 限制 `jmp esp` 等非预期控制流转移 |
| **编译器安全函数** (`strcpy_s` 等) | 强制长度检查 | 源头消除溢出可能 |

---

## 交叉引用索引

- [[pe-export-table-internals]] — PE 导出表结构与手动解析细节
- [[pe-import-table-internals]] — 导入表机制，对比理解无导入表 Shellcode 的必要性
- [[pe-manual-mapping-loader-implementation]] — 手动映射加载器实现，涵盖导出表解析、重定位、模块隐藏
- [[rop-linux-x86-beginner-tutorial]] — ROP 基础原理（Linux x86），栈溢出利用通用方法论
- [[mtctf-2021-pwn-writeup]] — 实战中 `setcontext+mprotect` 绕过 DEP 执行 Shellcode
- [[windows-syscall-internals-sysenter-kifastcallentry]] — Windows 系统调用底层机制，理解 API 最终如何进入内核
- [[reverse-engineering-beginner-learning-path]] — 逆向工程入门路线，夯固汇编与调试基础

---

## 版本历史

- **2023-04-16** 初版：整理 0w1Club 文章核心内容，补全 PEB 遍历与导出表解析技术脉络。
- **2024-12-19** 结构化重组：增加 YAML frontmatter、交叉引用、防御措施表、版本历史，符合知识库规范。

## 来源

- [0x00实验室-202108-202304_014](../sources/0x00实验室-202108-202304_014.md)
