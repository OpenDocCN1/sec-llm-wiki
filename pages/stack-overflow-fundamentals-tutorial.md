---
title: 栈溢出基础教程：栈帧结构、寄存器作用与最简利用链构造
description: 系统讲解栈溢出原理：栈帧结构、EBP/ESP/EIP 寄存器作用、gets() 缓冲区溢出成因、返回地址覆盖劫持 EIP 执行 system("/bin/sh")
  的最简利用链及 pwntools 载荷构造
category: program-analysis
tags:
- Stack Overflow
- Buffer Overflow
- EBP
- ESP
- EIP
- gets()
- Return Address Overwrite
- system()
- pwntools
- Payload Construction
- CTF
- Binary Exploitation
- Reverse Engineering
date: '2024-01-15'
updated: '2026-11-15'
---

## 栈溢出基础教程：栈帧结构、寄存器作用与最简利用链构造

> 本页面基于 0xfafu攻防实验室微信归档文章《手把手教你栈溢出入门》整理沉淀，系统梳理栈溢出漏洞的内存层面成因、栈帧生命周期、关键寄存器交互机制，以及最简 `ret2system` 利用链的构造与 `pwntools` 实战载荷编写。

---

## 栈与栈帧：函数调用的内存模型

### 栈的生长方向与栈帧概念

- **栈** 是内存中一种后进先出（LIFO）的数据结构，**从高地址向低地址生长**。
- 每次 **函数调用** 都会在栈上分配一个 **栈帧**，包含该函数的局部变量、保存的寄存器、返回地址等。
- 一个函数对应一个栈帧；函数返回时栈帧被释放，栈指针回退。

> 交叉引用：[[rop-linux-x86-beginner-tutorial]] 中对 Linux x86 栈帧布局、参数传递约定有更详细的图解与实战演示。

### 三大关键寄存器

| 寄存器 | 全称 | 作用 |
|--------|------|------|
| **EBP** | Extended Base Pointer | 栈帧基址指针，指向当前栈帧底部（高地址端），用于通过固定偏移访问局部变量、参数。 |
| **ESP** | Extended Stack Pointer | 栈顶指针，始终指向栈帧顶部（低地址端），随 `push`/`pop`、`sub`/`add` 移动。 |
| **EIP** | Extended Instruction Pointer | 指令指针，存放 **下一条将执行指令的地址**；函数调用时将返回地址压栈，返回时弹回 EIP 控制流跳转。 |

> 交叉引用：[[windows-x86-stack-overflow-shellcode-execution]] 详细剖析了 Windows x86 环境下 EBP/ESP/EIP 在栈溢出利用中的动态变化。

---

## 栈帧的形成与释放全过程

以示例代码为例：

```c
#include <stdio.h>

void vulnerable() {
    char buf[10];
    gets(buf);
}

int main() {
    vulnerable();
    printf("运行完毕");
}
```

### 进入 `vulnerable()` 时的栈帧形成（Prologue）

1. **返回地址入栈**  
   `call vulnerable` 指令将 **下一条指令地址**（即 `printf` 处）压入栈中，作为返回地址。
2. **旧 EBP 入栈**  
   `push ebp` 保存调用者（`main`）的栈帧基址。
3. **建立新 EBP**  
   `mov ebp, esp` 令 EBP 指向当前栈顶，成为新栈帧基址。
4. **分配局部变量空间**  
   `sub esp, 0x10`（或更大）在栈上预留 `buf[10]` 等局部变量空间（通常按 16 字节对齐）。

> **栈帧分界线**：通常以 **保存的 EBP** 与 **返回地址** 之间的边界视为栈帧起点。

### `gets()` 缓冲区溢出成因

- `gets(buf)` **不检查输入长度**，直接从标准输入读取直到换行或 EOF。
- `buf` 仅 10 字节，若输入超过 10 字节，多余字节将 **从低地址向高地址** 依次覆盖：
  1. `buf` 本身（10 字节）
  2. **保存的 EBP**（4 字节）
  3. **返回地址**（4 字节）
  4. 更高地址的调用者栈帧数据……

> 交叉引用：[[attack-defense-world-pwn-writeup]] 实战演示了如何通过 IDA Pro 定位 `vulnerable_function` 并精确计算偏移（0x88 字节覆盖返回地址）。

### 离开 `vulnerable()` 时的栈帧释放（Epilogue）

1. **释放局部变量**  
   `mov esp, ebp` / `leave` 指令将 ESP 回退到保存的 EBP 位置，局部变量空间逻辑上失效。
2. **恢复旧 EBP**  
   `pop ebp` 将栈顶 4 字节弹回 EBP，调用者栈帧基址恢复。
3. **返回地址弹回 EIP**  
   `ret` / `pop eip` 将栈顶 4 字节弹入 EIP，**控制流跳转至该地址继续执行**。

> **关键点**：若返回地址被覆盖为攻击者指定地址，`ret` 执行后 EIP 将指向攻击者代码，实现控制流劫持。

---

## 最简利用链：覆盖返回地址执行 `system("/bin/sh")`

### 利用前提

- 程序**未开启栈保护**（Canary）、**NX 位关闭** 或**存在可执行代码段**（如 PLT/GOT 中的 `system`）。
- 能够泄露或推断 `system` 与 `"/bin/sh"` 字符串地址（或程序内置 `system("/bin/sh")` 封装函数）。
- 32 位程序（示例为 x86），地址宽度 4 字节，便于直接构造 Payload。

> 交叉引用：[[buuctf-pwn-writeup-collection]] 汇总了大量 `ret2libc`、`ret2system` 实战案例；[[mtctf-2021-pwn-writeup]] 展示了 `setcontext + mprotect` 等进阶链。

### 载荷结构设计

```
[ buf 填充 (10 字节) ] [ 伪造 EBP (4 字节) ] [ 目标返回地址 (4 字节) ]
```

- **buf 填充**：任意字符，如 `'a' * 10`。
- **伪造 EBP**：可任意值，常用 `'b' * 4` 或 `0xdeadbeef`，不影响利用。
- **目标返回地址**：`system("/bin/sh")` 的地址（或包含该调用的函数地址，如示例中的 `0x111111`）。

### pwntools 载荷构造示例

```python
from pwn import *

# 假设目标二进制为 ./vuln，system("/bin/sh") 封装函数地址 0x0804856b
context.arch = 'i386'
context.os   = 'linux'

p = process('./vuln')          # 或 remote('ip', port)

payload = b'a' * 10            # 填满 buf
payload += b'b' * 4            # 覆盖保存的 EBP
payload += p32(0x0804856b)     # 覆盖返回地址 -> system("/bin/sh")

p.sendline(payload)
p.interactive()                # 获得 Shell
```

> **`p32()`** 自动处理小端序编码；64 位环境请用 `p64()` 并注意栈对齐（通常需额外 8 字节填充）。

---

## 实战调试与偏移精确定位技巧

| 技巧 | 工具/命令 | 说明 |
|------|-----------|------|
| **Pattern 生成/搜索** | `pwn cyclic 100` / `pwn cyclic -l <offset>` | 快速定位覆盖返回地址所需精确字节数。 |
| **GDB + PEDA/GEF** | `pattern create` / `pattern search $eip` | 动态调试中自动计算偏移。 |
| **IDA Pro 静态分析** | `F5` 伪代码查看栈布局 | 直观获取 `buf` 到返回地址的静态偏移。 |
| **检查保护机制** | `checksec ./vuln` | 确认 Canary、NX、PIE、RELRO 状态，决定利用策略。 |

> 交叉引用：[[peda-buffer-overflow-analysis-guide]] 完整记录了 PEDA `pattern_create`/`pattern_search` 定位偏移、ROP 链构造至提权的全流程；[[vulnhub-dawn2-writeup]] 展示了 Windows Immunity Debugger + mona.py 同类实战。

---

## 从最简利用链到进阶利用的演进路线

| 阶段 | 核心技术 | 典型场景 |
|------|----------|----------|
| **Ret2system** | 直接覆盖返回地址跳转 `system("/bin/sh")` | 无 PIE、有 `system` 符号、栈可执行或 NX 关闭。 |
| **Ret2libc** | 泄露 libc 基址 → 计算 `system`、`/bin/sh`、`gadget` 地址 | ASLR 开启、NX 开启、无栈执行权限。 |
| **ROP 链** | 串联 `pop ret` 等 gadget 设置参数、调用函数 | 无可直接跳转的 `system("/bin/sh")` 封装函数。 |
| **栈迁移** | `leave; ret` / `xchg esp, eax` 将栈指针劫持到可控区域 | 栈空间受限、需构造长 ROP 链。 |
| **SROP / Sigreturn** | 伪造 `sigcontext` 结构控制全寄存器 | 极度受限环境，需 `sys_sigreturn` gadget。 |

> 交叉引用：[[rop-linux-x86-beginner-tutorial]] 系统讲解 ROP 入门、x86/x64 参数传递差异、ASLR/NX/PIE/Canary 绕过思路；[[xihulunjian-2020-iot-pwn3-ezarmpwn-writeup]] 实战演示 ARM 32 位下栈上 libc 泄露 + ROP 利用。

---

## 防御与缓解措施速查

| 机制 | 原理 | 绕过难点 |
|------|------|----------|
| **Stack Canary** | 函数序言在栈帧插入随机 cookie，尾声校验 | 需泄露或爆破 cookie；格式化字符串漏洞可读取。 |
| **NX / DEP** | 栈/堆标记不可执行 | 需 ROP/Ret2libc 复用现有可执行代码。 |
| **ASLR / PIE** | 代码段、栈、堆、库基址随机化 | 需信息泄露漏洞泄露基址。 |
| **RELRO (Full)** | GOT 只读，延迟绑定关闭 | 无法劫持 GOT 表项，需攻击 `.fini_array` 或其他。 |
| **FORTIFY_SOURCE** | 危险函数编译期替换为带长度检查版本 | 仅对已知缓冲区大小的调用有效。 |
| **CET / Shadow Stack** | 硬件影子栈保护返回地址 | 需劫持控制流前绕过影子栈校验（极难）。 |

> 交叉引用：[[linux-kernel-hardening-mechanisms]] 系统梳理了内核层面内存保护、控制流完整性、硬件辅助防护等纵深防御机制。

---

## 相关实战靶场与练习推荐

| 靶场/平台 | 题目/方向 | 核心考点 |
|-----------|-----------|----------|
| **攻防世界 PWN** | `Level0` | 栈溢出、ROP 调用 `callsystem`、pwntools 远程利用 | [[attack-defense-world-pwn-writeup]] |
| **BUUCTF PWN** | 多题集合 | 栈溢出、ROP、ret2libc、堆利用、格式化字符串等 | [[buuctf-pwn-writeup-collection]] |
| **VulnHub** | `Dawn2` (Windows) | Immunity Debugger + mona.py JMP ESP、msfvenom 生成载荷 | [[vulnhub-dawn2-writeup]] |
| **VulnHub** | `hard-socnet2` | 缓冲区溢出 + PEDA/GDB 动态调试 + ROP 提权 | [[vulnhub-hard-socnet2-writeup]] |
| **西湖论剑 2020 IoT** | `ezarmpwn` | ARM 32 位栈溢出、UAF、Off-by-null、ROP、Chunk Overlap | [[xihulunjian-2020-iot-pwn3-ezarmpwn-writeup]] |

---

## 小结

1. **栈帧生命周期**（形成→执行→释放）决定了返回地址在栈上的固定相对位置。
2. **`gets()` 等无边界检查函数** 是栈溢出的典型诱因，输入长度可控即可覆盖返回地址。
3. **EIP 控制流劫持** 的本质：利用 `ret` 指令将攻击者构造的地址加载进 EIP。
4. **最简 `ret2system` 载荷** = `padding` + `fake_ebp` + `target_addr`，配合 `pwntools` 快速构造。
5. **实战中需结合保护机制**（Canary/NX/ASLR/PIE/RELRO）选择 Ret2libc、ROP、栈迁移等进阶链。

> 后续可延伸阅读：[[rop-linux-x86-beginner-tutorial]]（ROP 系统入门）、[[buuctf-pwn-writeup-collection]]（大量实战 Writeup）、[[peda-buffer-overflow-analysis-guide]]（PEDA 动态调试全流程）、[[linux-kernel-hardening-mechanisms]]（纵深防御视角）。

---

> 页面维护者提示：本页作为「栈溢出基础」知识锚点，后续可继续沉淀 **x64 栈帧差异**、**栈迁移实战**、**SROP 构造**、**Windows SEH 覆盖** 等进阶专题，并通过 `[[wikilink]]` 形成完整的二进制漏洞利用知识图谱。

## 来源

- [0xfafu攻防实验室-202010-202112_18](../sources/0xfafu攻防实验室-202010-202112_18.md)
