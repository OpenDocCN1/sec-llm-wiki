---
title: 'MTCTF 2021 Pwn Writeups: baby_focal & zlink'
description: MTCTF 2021 中两道 Pwn 题目的详细解析。baby_focal 利用堆溢出构造 UAF 泄露 stdout 绕过检查，再借助
  setcontext+mprotect 执行 Shellcode；zlink 通过 Off-by-null 触发 Fastbin Consolidation 与
  Unlink 实现 Double Free 劫持 __free_hook，同样使用 setcontext 获取 Shell。
category: program-analysis
tags:
- CTF
- Pwn
- Heap Exploitation
- UAF
- Fastbin
- Unlink
- Double Free
- setcontext
- mprotect
- Shellcode
- MTCTF 2021
date: '2021-01-01'
updated: '2026-11-12'
---
## 概述

本页面记录 MTCTF 2021 竞赛中两道堆利用题目的核心思路与关键技术点。两题均基于 Glibc 堆管理机制，通过精细的堆布局绕过完整性检查，最终均因禁用 `execve` 系统调用而采用 `setcontext` + `mprotect` 修改内存权限执行 Shellcode 的方式获取 Shell。

## baby_focal

### 漏洞成因

- **堆溢出**：申请缓冲区时将大小字段设置为 `size + 0x10`，且允许溢出 `0x10` 字节，可覆盖相邻 Chunk 的 `size` 与 `FD` 指针。
- **无显示功能**：程序未提供直接打印堆内容的接口，需借助修改 `stdout` 结构体指针实现地址泄露。

### 利用链

1. **构造 Unsorted Bin 绕过检查**  
   布局堆使目标 Chunk 进入 Unsorted Bin，并设置关键字段（`bk`、`fd`、`size` 等）通过 Libc 完整性校验。
2. **Fastbin Attack + 单字节爆破泄露 Libc**  
   - 将两个 Chunk 放入 Fastbin，利用溢出修改最后一个 Chunk 的 `FD` 低字节指向 Unsorted Bin Chunk。  
   - 再次申请该大小 Chunk 使 Fastbin 残留 Libc 地址，爆破 `stdout` 附近地址低字节实现任意地址读，泄露 Libc 基址。
3. **任意地址写**  
   程序未开启 PIE，溢出修改 `FD` 指向存储 Chunk 指针的全局数组，获得任意地址写原语。
4. **setcontext + mprotect 执行 Shellcode**  
   - 禁用 `execve`，利用 `setcontext` 恢复寄存器上下文并调用 `mprotect` 将 Shellcode 所在内存标记 RWX。  
   - Libc-2.31 中 `setcontext` 使用 `rdx` 而非 `rdi` 传递第一个参数，需额外寻找 `mov rdi, rdx; call ...` 类 Gadget 完成参数传递。

### 关键技术点

- **堆溢出转 UAF**  
- **Unsorted Bin / Fastbin 交互利用**  
- **stdout 结构体泄露技巧**  
- **单字节爆破绕过 ASLR**  
- **setcontext 栈迁移与寄存器控制**  

> 完整 Exploit 脚本见原文（此处省略）。

## zlink

### 漏洞成因

- **Off-by-NULL**：释放时可向前覆盖一个字节，清除相邻 Chunk 的 `prev_inuse` 位。
- **申请限制**：仅允许一次或两次大内存申请，常规 Off-by-null 利用受限。
- **环境**：Libc-2.23，保护机制较弱。

### 利用链

1. **Fastbin Consolidation 构造 Unsorted Bin**  
   先大量申请 Fastbin Chunk，再触发大内存申请迫使 Libc 合并 Fastbin 并放入 Unsorted Bin。
2. **Off-by-NULL + Unlink 实现 Chunk Overlap**  
   - 修改大 Chunk 的 `prev_inuse=0` 并伪造 `prev_size`，释放触发 `unlink` 合并。  
   - 合并后产生重叠 Chunk，进而实现 **Double Free**。
3. **Fastbin Attack 劫持 `__free_hook`**  
   题目提供一次将 `__free_hook` 附近值设为 `0x7f` 的能力，配合 Double Free 将 Fastbin `FD` 指向 `__free_hook`，写入 `setcontext` 地址。
4. **setcontext + mprotect 执行 Shellcode**  
   同 baby_focal，通过 `setcontext` 调用 `mprotect` 修改内存权限并跳转 Shellcode。

### 关键技术点

- **Fastbin Consolidation 利用**  
- **Off-by-NULL 触发 Unlink**  
- **Chunk Overlap 导致 Double Free**  
- **__free_hook 劫持与 setcontext 复用**  

> 完整 Exploit 脚本见原文（此处省略）。

## 总结与对比

| 技术点 | baby_focal | zlink |
|--------|------------|-------|
| 初始漏洞 | 堆溢出 (0x10 字节) | Off-by-NULL |
| 核心堆技术 | UAF + Fastbin Attack + Unsorted Bin 泄露 | Fastbin Consolidation + Unlink + Double Free |
| Libc 版本 | 2.31 | 2.23 |
| 绕过检查手段 | 伪造 Unsorted Bin 字段 + 单字节爆破 stdout | 利用题目给定的 `__free_hook` 附近写 0x7f |
| 最终执行流 | setcontext → mprotect → Shellcode | setcontext → mprotect → Shellcode |
| 关键 Gadget 差异 | 需 `mov rdi, rdx` 适配 Libc-2.31 setcontext | Libc-2.23 setcontext 直接用 `rdi`，无需额外 Gadget |

两题均展示了在禁用 `execve` 场景下，**setcontext + mprotect** 作为通用的代码执行后利用手段的有效性，并体现了堆利用中 **精确内存布局** 与 **Libc 内部结构绕过** 的核心思想。

## 相关主题

- [[linux-kernel-hardening-mechanisms]] — 了解内核层面的内存保护机制（如 KPTI、SMAP/SMEP、CET）对用户态堆利用的间接影响。
- [[ida-pro-tips-plugins-python]] — 逆向分析阶段可使用 FLIRT 恢复符号、Findcrypt-Yara 识别加密常量、Keypatch 快速修补二进制辅助调试。
- [[google-ctf-2021-full-chain-v8-exploitation]] — 对比浏览器内核漏洞利用链（TypedArray OOB、指针压缩、MojoJS 沙箱逃逸）与传统堆利用的异同。

## 来源

- [0th3rs安全团队-201911-202204_006](../sources/0th3rs安全团队-201911-202204_006.md)
