---
title: 2022 版网络安全面试题库知识地图
description: 基于微信公众号归档文章整理的网络安全面试题库结构化索引，覆盖基础漏洞、渗透思路、内网渗透、框架中间件、反序列化、安全工具、免杀、应急响应、安全防御、HR
  面试十大板块，交叉引用现有技术详解页面。
category: program-analysis
tags:
- 网络安全面试
- 渗透测试
- 内网渗透
- 漏洞利用
- 应急响应
- 免杀技术
- 安全工具
- HR面试
date: '2022-01-01'
updated: '2026-11-14'
---
## 概述

本页面将 2022 版《网络安全面试合集 | 2022精华版》归档文章结构化为十大知识板块，并在每个板块下通过交叉引用链接至知识库中已有的深度技术详解页面，形成「面试题索引 → 原理深度解析 → 实战复现案例」的三层知识图谱。

> **使用说明**：正文各小节标题对应原文大纲编号（0x00~0x10），**粗体** 标注的关键词可直接跳转至对应详解页；未建立页面的条目保留为纯文本，便于后续扩充。

---

## 0x00 基础漏洞篇（TOP10 + 扩展）

### 核心漏洞类型
| 漏洞 | 核心原理 | 关联详解页 |
|------|----------|------------|
| **SQL 注入** | 拼接查询未校验，导致恶意 SQL 执行 | [[sqlmap-api-automation]] 自动化检测实战 |
| **CSRF** | 盗用受害者身份发送伪造请求 | — |
| **文件包含 (LFI/RFI)** | 动态包含用户可控路径 | — |
| **文件上传** | 后缀/内容校验缺失导致 Getshell | [[php-webshell-obfuscation-av-evasion]] Webshell 免杀对抗 |
| **SSRF** | 服务端发起可控网络请求攻击内网 | [[c2-redirectors-malleable-c2-profiles]] 重定向器拓扑复用 SSRF 思路 |
| **逻辑漏洞** | 业务流程设计缺陷（越权、重置、并发等） | — |
| **XSS** | 恶意脚本注入浏览器执行 | — |
| **XXE** | XML 解析器处理外部实体导致读文件/SSRF | — |
| **代码执行** | `eval`/`assert` 等危险函数直接执行用户输入 | [[php-webshell-obfuscation-av-evasion]] PHP 代码执行免杀 |
| **路径覆盖 (RPO)** | 相对路径差异导致静态资源劫持 | — |

### 扩展基础知识点
- **邮件系统漏洞**：协议固有缺陷（SMTP/POP3/IMAP）+ 编码失误
- **DNS 欺骗 / DDoS / CC 攻击**：流量层面攻击与缓解 [[linux-kernel-hardening-mechanisms]] 内核级防护参考
- **常见端口服务表**：Web、数据库、中间件、运维端口速查
- **身份认证 / 验证码 / DOM-XSS / 参数化查询 / 状态码 / DLL 劫持 / 一句话木马 / 命令执行函数表** 等零散考点

### 经典实战绕过技巧索引
| 场景 | 关键绕过思路 | 实战复现页 |
|------|--------------|------------|
| `sleep` 被禁用延时注入 | `BENCHMARK` / `GET_LOCK` / 重计算语句 | — |
| `HttpOnly` 绕过 | `TRACE` 方法 / Header 泄露 / Flash/Ajax | — |
| **SQL 二次注入** | 存储时转义、取用时信任 | — |
| **SQL Server 提权** | `xp_cmdshell` / `sp_oacreate` / Agent Job / 沙盒 | — |
| `magic_quotes_gpc` 绕过 | 宽字节 / 编码差异 / 二次编码 | — |
| **Webshell 查杀对抗** | 变形 / 加密 / 动态加载 / 分离加载 | [[php-webshell-obfuscation-av-evasion]] 两阶段混淆实战 |
| `disable_functions` 绕过 | 黑名单漏网 / `LD_PRELOAD` / `putenv` / `imap` / `mail` | — |
| **不出网落地** | `regsvr32` / `rundll32` / DNS/ICMP 隧道 / 正向连接 | [[cobalt-strike-external-c2-smb-beacon]] SMB Beacon 通信模型 |
| **脏牛提权 (CVE-2016-5195)** | 竞争条件写 `/etc/passwd` | [[vulnhub-doubletrouble-writeup]] 完整复现链 |
| **MySQL 写 Shell 条件** | `root` + 绝对路径 + `secure_file_priv=''` | — |
| **宽字节注入** | `%df%27` 吃掉反斜杠 | — |
| **报错注入函数** | `updatexml` / `extractvalue` / `floor` / `exp` | — |
| **MongoDB / Fastjson / Shiro / Weblogic / JBoss / Jenkins / Docker / Redis / Memcache / MongoDB** 未授权/反序列化 | 见 0x04 反序列化篇 | — |

---

## 0x01 渗透思路篇

### 标准渗透流程
1. **信息收集** → 绕过 CDN 查真实 IP（多地 Ping / 历史解析 / SSL 证书 / 邮件头 / 子域名枚举）  
2. **漏洞扫描与验证** → 手工 + 自动化（Nmap、Nessus、AWVS、SQLMap）  
3. **漏洞利用拿 Shell** → Webshell / 反序列化 / 命令执行 / 文件上传  
4. **权限提升** → 系统漏洞 / 配置错误 / 服务提权 / 数据库 UDF/MOF  
5. **内网横向 / 持久化 / 清理痕迹** → 见 0x02 内网渗透篇

### 典型场景决策树
| 场景 | 判断依据 | 处理策略 |
|------|----------|----------|
| 目标仅开放 80 端口 | 站库分离 / 端口修改 / 防火墙策略 | 端口扫描全端口 / 旁站 / C 段 / 供应链 |
| 上传脚本访问 403 | 目录执行权限被禁 | 解析漏洞 / `.user.ini` / `.htaccess` / 后缀大小写 / 双写绕过 |
| 3389 无法连接 | 端口未开/修改/防护/内网 | 端口转发 / 隧道代理 / 修改注册表 |
| 拿到 UID=100 注入点 | `INTO OUTFILE` / `sqlmap --os-shell` / 后台 Getshell | 结合 [[sqlmap-api-automation]] 批量化利用 |

### 关键工具链速查
- **Nmap** 全参数速查 → [[#0x05-安全工具篇]]
- **SQLMap** `--level`/`--risk`/交互式写 Shell / API 自动化 → [[sqlmap-api-automation]]
- **流量特征识别**：菜刀 / 蚁剑 / 冰蝎 / 哥斯拉 → Wireshark 过滤规则
- **MSF 基础模块**：`exploit/multi/handler` / `auxiliary/scanner/*` / `post/*`

---

## 0x02 内网渗透篇

### 核心流程
```text
跳板机 → 信息收集(net view / net user /domain / ipconfig / arp / route) 
       → 存活探测(fping / nmap -sn / 伪造 ARP) 
       → 凭证获取(mimikatz / procdump / 注册表 / 浏览器) 
       → 横向移动(IPC$ / WMI / PTH / SMB / RDP / SSH) 
       → 域控定位 / 域管定位 / 票据伪造(黄金/白银) 
       → 权限维持(计划任务 / 服务 / WMI / 注册表 / SSH Key / Golden Ticket) 
       → 隧道代理(frp / ew / ssh / Neo-reGeorg / nps / ligolo-ng) 
       → 清理日志(wevtutil / auditpol / sed / shred)
```

### 关键技术深度链接
| 技术点 | 详解页 | 核心价值 |
|--------|--------|----------|
| **Kerberos 认证流程 / 票据伪造** | [[mimikatz-source-code-architecture-golden-ticket-audit]] | 源码级剖析 `krbtgt` Hash → Golden Ticket 生成全链路 |
| **SMB / 命名管道 C2 通信** | [[smb-named-pipe-c2-communication]]、[[cobalt-strike-external-c2-smb-beacon]]、[[named-pipe-smb-detection-sysmon]] | 协议原理、Beacon 实现、Sysmon Event ID 17/18 检测对抗 |
| **C2 重定向器 / Malleable Profile** | [[c2-redirectors-malleable-c2-profiles]] | 域名前置、CDN 隐匿、流量混淆完整拓扑 |
| **Covenant P2P Mesh / External C2** | [[covenant-c2-framework-analysis]] | .NET 实现、HTTP/SMB 双通道、受限出站适用性对比 |
| **内网隧道工具对比** | — | `frp`/`ew`/`ssh`/`Neo-reGeorg`/`nps`/`ligolo-ng`/`chisel` 选型指南 |
| **横向移动命令执行** | — | `psexec`/`wmic`/`smbexec`/`winrm`/`schtasks`/`sc`/`dcom`/`rpc` |
| **权限维持技术谱系** | — | Windows: 计划任务/服务/WMI/注册表/启动项/COM 劫持/镜像劫持/SSP/ACL/计划任务/Shadow Copy；Linux: SSH Key/cron/systemd/ld.so.preload/pam/内核模块/容器逃逸 |
| **凭证导出对抗** | [[dotnet-clr-usage-log-tampering-edr-evasion]] | .NET CLR Usage Log 规避、ETW 绕过、DInvoke 卸载模块 |
| **免杀加载器原理** | [[phantom-dll-hollowing-technique]]、[[pe-manual-mapping-loader-implementation]] | Phantom DLL Hollowing / 手动映射 / 模块隐藏 / 导入表修复 / 重定位修正 |

### 实战靶场复现索引（VulnHub 系列）
| 靶机 | 核心攻击链 | 关联页面 |
|------|------------|----------|
| **DOUBLETROUBLE** | Shellshock (CVE-2014-6271) → Dirty COW (CVE-2016-5195) | [[vulnhub-doubletrouble-writeup]]、[[0w1club-training-shellshock-cgi-exploitation]] |
| **hard-socnet2** | 文件上传 → SQLi → XML-RPC 爆破 → CVE-2021-3493 → 缓冲区溢出 (PEDA) | [[vulnhub-hard-socnet2-writeup]]、[[peda-buffer-overflow-analysis-guide]] |
| **Chronos** | JS 混淆 → Base58 → 命令注入 → 原型链污染 RCE → `sudo node` 提权 | [[vulnhub-chronos-writeup]] |
| **Dawn2** | Windows 栈溢出 (Immunity+mona) → `msfvenom` → Python Exploit → 第二服务提权 | [[vulnhub-dawn2-writeup]] |
| **更多 750+ 靶机索引** | — | [[vulnhub-platform-resource-index]] |

---

## 0x03 框架与中间件篇

| 框架/中间件 | 典型漏洞 | 关联详解/实战页 |
|-------------|----------|-----------------|
| **Python Flask** | SSTI (模板注入) | — |
| **Django** | 目录遍历 / 反序列化 | — |
| **IIS 6.0/7.5/8.x** | 解析漏洞 (`/xx.asp/xx.jpg`、`%00`、短文件名) | — |
| **Struts2** | OGNL 表达式注入 (S2-045/046/048/052/053/057/059/061) | — |
| **WebLogic** | T3 反序列化 / XMLDecoder / SSRF / 权限绕过 (CVE-2020-14882/14883) | — |
| **Fastjson** | `autoType` 绕过 / `Throwable` / `JdbcRowSetImpl` / 无回显 DNSLog | — |
| **Shiro** | RememberMe AES Key 硬编码 / Padding Oracle / SHIRO-550/721 | — |
| **JBoss** | `invoker.war` 反序列化 / JMX 控制台弱口令 | — |
| **Jenkins** | 未授权脚本控制台 / CVE-2018-1000861 / CVE-2024-23897 | — |
| **Docker** | Remote API 未授权 (2375) / `docker.sock` 挂载逃逸 | — |
| **Redis** | 未授权写 SSH Key / Cron / Webshell / 主从复制 RCE (CVE-2022-0543) | — |
| **Memcache / MongoDB** | 未授权访问 / 信息泄露 | — |

> **扩展阅读**：[[v8-issue-944062-gc-arbitrary-write]]、[[v8-turbofan-changeint32toint64-1day-analysis]]、[[google-ctf-2021-full-chain-v8-exploitation]] 覆盖 V8/Chrome 0day 利用链，属于高阶浏览器安全面试储备。

---

## 0x04 反序列化篇

### 统一原理模型
```text
序列化：对象 → 字节流 (存储/传输)
反序列化：字节流 → 对象 (读取/重构)
漏洞点：可控字节流进入反序列化入口，且类路径可达危险 Gadget Chain
```

### 语言/框架矩阵
| 语言 | 典型入口 | 关键 Gadget / 利用链 | 检测特征 |
|------|----------|----------------------|----------|
| **Java** | `ObjectInputStream.readObject()` / `readResolve()` / `readObjectNoData()` | CommonsCollections / Spring / Rome / Hibernate / Jdk7u21 / JSON (Fastjson/Jackson/Gson) / Shiro / WebLogic / Struts2 | `aced 0005` / `rO0AB` (Base64) / `Content-Type: application/x-java-serialized-object` |
| **PHP** | `unserialize()` / `__wakeup()` / `__destruct()` / `__toString()` / `__call()` | `Phar` 反序列化 / `SoapClient` SSRF / `SplFileObject` / Laravel/RCE / ThinkPHP | `O:8:"stdClass"` / `a:1:{i:0;` / `phar://` wrapper |
| **Python** | `pickle.loads()` / `yaml.load()` / `marshal.loads()` | `__reduce__()` / `__setstate__()` / `subprocess.Popen` / `os.system` | `b'\x80\x03'` (pickle v3) / `!!python/object/apply:` (YAML) |
| **.NET** | `BinaryFormatter.Deserialize()` / `ObjectStateFormatter` / `LosFormatter` / `Json.NET TypeNameHandling` | `TypeConfuseDelegate` / `TextFormattingRunProperties` / `WindowsIdentity` / `ClaimsIdentity` | `AAEAAAD/////` (Base64 BinaryFormatter) |
| **Node.js** | `node-serialize` / `unserialize()` / `eval()` | `IIFE` / `Function` constructor / `child_process` | `{"rce":"_$$ND_FUNC$$_` |

### 高频考点速查
- **Log4j2 (CVE-2021-44228)**：JNDI 注入 → `ldap://` / `rmi://` / `dns://` 绕过高版本 JDK 限制
- **Fastjson 版本判断**：错误 POST 触发报错回显版本号 / `autoType` 绕过史 (1.2.24 → 1.2.47 → 1.2.68 → 1.2.80)
- **Shiro RememberMe**：硬编码 Key → AES-CBC → Padding Oracle → `ysoserial` Gadget
- **WebLogic T3**：`Channel` 处理 `ObjectInputStream` → 绕过黑名单 `resolveClass` / `resolveProxyClass`
- **无回显利用**：DNSLog / HTTP 请求外带 / 延时注入 / 文件写入 / 反向连接

---

## 0x05 安全工具篇

### 核心工具链速查表
| 类别 | 工具 | 核心参数/模块 | 进阶用法页 |
|------|------|---------------|------------|
| **C2 框架** | **Cobalt Strike** | Beacon / Malleable Profile / Aggressor Script / External C2 / SMB Beacon | [[cobalt-strike-external-c2-smb-beacon]]、[[c2-redirectors-malleable-c2-profiles]] |
| | **Covenant** | Grunt / Listener / Task / P2P Mesh / HTTP/SMB / External C2 | [[covenant-c2-framework-analysis]] |
| **扫描器** | **Nmap** | `-sS/-sU/-sV/-O/-A/-sn/-p-/-Pn/--script=vuln` | — |
| | **SQLMap** | `-u/--data/--batch/--dbs/--tables/--dump/--os-shell/--level/--risk/--tamper` | [[sqlmap-api-automation]] REST API 批量化 |
| **流量分析** | **Wireshark** | `ip.addr==x && http` / `tcp.stream eq N` / `smb2` / `kerberos` / `dns` | [[named-pipe-smb-detection-sysmon]] SMB 流量基线 |
| **后渗透** | **Mimikatz** | `sekurlsa::logonpasswords` / `lsadump::secrets` / `kerberos::golden` / `privilege::debug` | [[mimikatz-source-code-architecture-golden-ticket-audit]] 源码级原理 |
| | **Meterpreter** | `getsystem` / `hashdump` / `portfwd` / `autoroute` / `kiwi` (集成 mimikatz) | — |
| **代理/隧道** | **frp / nps / ew / ssh / Neo-reGeorg / ligolo-ng / chisel** | TCP/UDP/SOCKS/HTTP/SMB 转发 | — |
| **逆向/调试** | **IDA Pro / Ghidra / Binary Ninja / x64dbg / OllyDbg / GDB+PEDA** | FLIRT / Findcrypt-Yara / Keypatch / IDAPython / OLLVM 去平坦化 | [[ida-pro-tips-plugins-python]]、[[binary-ninja-ollvm-deobfuscation]]、[[peda-buffer-overflow-analysis-guide]] |
| **Webshell 管理** | **蚁剑 / 冰蝎 / 哥斯拉 / 菜刀** | 动态密钥 / 流量加密 / 虚拟终端 / 文件管理 | [[php-webshell-obfuscation-av-evasion]] 免杀对抗 |
| **漏洞利用框架** | **Metasploit / Cobalt Strike / Covenant / Sliver / Brute Ratel** | Exploit / Payload / Encoder / Post / Auxiliary | — |

---

## 0x06 木马免杀篇

### 免杀核心对抗模型
```text
静态特征查杀 → 动态行为查杀 → 内存扫描查杀 → 云引擎查杀
      ↓              ↓              ↓              ↓
  代码混淆/加密   API 解耦/延迟执行  反射/手动映射/无文件  多态/分离加载/白利用
```

### 技术分类与详解页
| 分类 | 典型技术 | 关联详解页 |
|------|----------|------------|
| **Shellcode 免杀** | 编码 / 加密 / 多态 / 分离存储 (图片/网页/注册表) / 白名单加载器 (MSBuild/InstallUtil/RegSvcs/RegAsm/WMIC) | [[pe-manual-mapping-loader-implementation]] 手动映射加载器原理 |
| **分离免杀** | 加载器 + 远程 Shellcode (HTTP/DNS/SMB/命名管道) | [[cobalt-strike-external-c2-smb-beacon]] SMB Beacon 通信模型 |
| **PowerShell 免杀** | `IEX (New-Object Net.WebClient).DownloadString()` / `Invoke-Expression` / `AMSI Bypass` / `ScriptBlock Logging` 绕过 / 模块化加载 (Invoke-Mimikatz/Invoke-PowerPicker) | — |
| **无文件落地** | `regsvr32` / `rundll32` / `mshta` / `wmic` / `dotnet` / `csc` / `msbuild` / `installutil` / `wscript` / `cscript` / `powershell -enc` / WMI / COM / DCOM / WinRM / SMB / Named Pipe | [[phantom-dll-hollowing-technique]] Phantom DLL Hollowing、[[dotnet-clr-usage-log-tampering-edr-evasion]] .NET CLR 日志规避 |
| **免杀框架/生成器** | **Veil / Shellter / Donut / sRDI / Pe2Sh / SharpShooter / GreatSCT / Chimera / ScareCrow / Freeze / NimPlant / Sliver / Brute Ratel** | — |

### 实战对抗清单
1. **Fuzz 定位特征** → `DefenderCheck` / `ThreatCheck` / `AMSITrigger` / `RealTimeProtection`  
2. **静态对抗**：字符串加密 / 控制流平坦化 (OLLVM) / 死代码插入 / 导入表混淆 / 资源加密 / 签名伪造  
3. **动态对抗**：延迟执行 / 环境检测 (沙箱/虚拟机/调试器/EDR 进程) / 进程注入 (经典/线程劫持/APC/早鸟/进程幽灵/模块踩踏/Phantom DLL Hollowing) / 系统调用直接调用 (HellsGate/Halo's Gate) / 绕过 ETW/AMSI/WDAC/AppLocker  
4. **内存对抗**：`VirtualProtect` / `NtProtectVirtualMemory` / RWX → RX / 堆喷射 / 反射加载 / 手动映射 / 模块隐藏 (Unlink/InLoadOrder/InMemoryOrder/InInitializationOrder)  
5. **通信对抗**：域名前置 / CDN / Malleable Profile / SMB Named Pipe / DNS Tunnel / HTTPS / QUIC / WebSocket / gRPC / 合法网站托管 (GitHub/Gist/OneDrive/Google Drive)

---

## 0x07 应急与响应篇

### 标准响应流程 (NIST SP 800-61 / PDCA)
```text
准备 → 检测/识别 → 抑制/遏制 → 根除 → 恢复 → 复盘/溯源/完善
```

### 场景化排查清单
| 场景 | 关键排查点 | 取证工具/命令 |
|------|------------|---------------|
| **Web 挂马 / Webshell** | 文件时间戳 / 用户 / 后缀 / 内容特征 / 访问日志关联 / WAF 日志 / 中间件日志 | `find / -mtime -1 -name "*.php" -size -10k` / `grep -r "eval\|assert\|system\|exec\|shell_exec\|passthru\|popen\|proc_open" /var/www/` / `D盾/河马/深信服Webshell检测` |
| **Windows 中毒 / 入侵** | 账号异常 (隐藏/克隆/新建) / 启动项 / 计划任务 / 服务 / 注册表 Run Key / WMI 订阅 / 计划任务 / DLL 劫持 / 影子副本 / 防火墙规则 / RDP 日志 (Event ID 4624/4625/4672/4720/4722/4723/4724/4725/4726/4738/4740/4767/4768/4769/4770/4771/4776/4688/4689/4697/4698/4699/4700/4701/4702/5140/5145/5156/5158/4663/4670) | `wevtutil qe Security /rd:true /f:text /q:"*[System[EventID=4624]]"` / `autoruns.exe` / `procdump -ma lsass.exe` / `mimikatz` / `Volatility` / `Kape` / `FastIR` / `Chainsaw` / `Hayabusa` |
| **Linux 入侵 / 挖矿** | `/etc/passwd` `/etc/shadow` `/etc/sudoers` `/root/.ssh/` `/var/spool/cron/` `/etc/crontab` `/etc/rc.local` `/etc/init.d/` `/lib/systemd/system/` `/usr/lib/systemd/system/` `/tmp/` `/var/tmp/` `/dev/shm/` 进程树 / 网络连接 / 开放端口 / 可疑二进制 / `ld.so.preload` / PAM 后门 / 内核模块 / 容器逃逸痕迹 | `last` / `lastb` / `who` / `w` / `netstat -antulp` / `ss -antulp` / `ps auxf` / `top` / `htop` / `lsof -p PID` / `cat /proc/PID/exe` / `ls -la /proc/PID/fd/` / `stat /proc/PID/exe` / `rpm -Va` / `dpkg -V` / `chkrootkit` / `rkhunter` / `lynis` / `clamav` / `maldet` / `Volatility` / `Rekall` / `Kape` |
| **SSH 爆破** | `/var/log/secure` / `/var/log/auth.log` / `/var/log/btmp` / `lastb` / `fail2ban` / `denyhosts` / 密钥登录 / 端口修改 / 禁用密码登录 / 限制 IP / 2FA | `grep "Failed password" /var/log/secure | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr` |
| **内存马 / 不死马** | `JSP` / `Servlet` / `Filter` / `Listener` / `Interceptor` / `Agent` / `JVMTI` / `Attach API` / `Thread` / `ClassLoader` / 定时任务 / `cron` / `systemd` / `rc.local` / `init.d` / 内存镜像分析 | `grep -r "defineClass\|defineHiddenClass\|Unsafe\|Instrumentation\|Transformer\|ClassFileTransformer" /path/to/webapp/` / `java -jar arthas-boot.jar` / `jmap -dump:live,format=b,file=heap.hprof PID` / `jhat` / `Eclipse MAT` / `JVisualVM` / `BTrace` / `Greys-Anatomy` |
| **日志被清除** | 备份文件 MD5 对比 / 磁盘残留 / 审计策略 / 远程日志服务器 / 云厂商审计日志 / 卷影副本 / `USN Journal` / `MFT` / `$LogFile` / `$J` / `$Secure` / `$Extend` | `fc.exe` / `Beyond Compare` / `DiffMerge` / `md5deep` / `hashdeep` / `Volatility` / `MFTECmd` / `MFTECmd` / `UsnJrnl2Csv` / `EvtxECmd` / `EvtxHunt` / `Chainsaw` / `Hayabusa` |

### 关键技术深度链接
- **Windows 日志分析体系** → [[named-pipe-smb-detection-sysmon]] Sysmon Event ID 17/18 命名管道检测
- **内存马原理与检测** → [[phantom-dll-hollowing-technique]] 幽灵 DLL 空洞化内存隐藏技术
- **EDR 规避与对抗** → [[dotnet-clr-usage-log-tampering-edr-evasion]] .NET CLR 使用日志规避四大手法
- **内核级 Rootkit 检测** → [[linux-kernel-hardening-mechanisms]] Grsecurity/PaX/内存保护/CFI/侧信道缓解
- **Spectre 类漏洞检测修复** → [[oo7-spectre-defense-binary-analysis]] 污点分析定位三元组 `<CB, IM1, IM2>`

---

## 0x08 安全防御篇

### 企业安全建设体系
| 领域 | 核心控制点 | 合规/标准参考 |
|------|------------|---------------|
| **物理安全** | 机房门禁 / 环境监控 / 资产标签 / 介质销毁 | ISO 27001 A.11 |
| **网络边界** | 防火墙 / UTM / WAF / IPS/IDS / 负载均衡 / DDoS 清洗 / 沙箱 / 威胁情报 / 流量镜像 / NTA/NDR | 等保三级 / PCI-DSS / GDPR |
| **主机安全** | EDR / EPP / HIDS / 基线核查 / 漏洞管理 / 补丁管理 / 应用白名单 / 内存保护 / 启动防护 | MITRE ATT&CK / CIS Benchmark |
| **应用安全** | SDL / SAST / DAST / IAST / SCA / RASP / WAF / API 网关 / DevSecOps 流水线 | OWASP Top 10 / ASVS / SAMM |
| **数据安全** | 分类分级 / 加密 / DLP / 备份恢复 / 脱敏 / 密钥管理 / 访问控制 / 审计 | DSMM / GB/T 39786 |
| **身份与访问** | IAM / PAM / MFA / SSO / RBAC/ABAC / 零信任 / 最小权限 / 生命周期管理 | NIST 800-53 / ISO 27001 A.9 |
| **安全运营** | SOC / SIEM / SOAR / 威胁狩猎 / 红蓝对抗 / 应急响应 / 情报驱动 / 红队评估 | NIST 800-61 / ISO 27035 / MITRE ATT&CK Navigator |
| **合规法务** | 等保测评 / 关保 / 数据出境 / 个人信息保护 / 供应链安全 / 法律法规库 | 网络安全法 / 数据安全法 / 个信法 / 关基条例 / 密码法 |

### 技术栈落地参考
- **日志平台**：ELK (Elasticsearch + Logstash + Kibana) / ClickHouse + Vector + Grafana / Loki + Promtail + Grafana / Splunk / QRadar / ArcSight
- **威胁情报**：MISP / OpenCTI / TAXII/STIX / ATT&CK STIX / 威胁图谱 / 攻击面管理 (ASM)
- **自动化编排**：Cortex XSOAR / Splunk SOAR / Shuffle / n8n / StackStorm / Ansible / Terraform
- **红队基础设施**：[[c2-redirectors-malleable-c2-profiles]] 重定向器拓扑 / [[cobalt-strike-external-c2-smb-beacon]] 分布式 C2 / [[covenant-c2-framework-analysis]] P2P Mesh

---

## 0x09 综合基础题篇

| 知识点 | 核心考点 | 关联深度页 |
|--------|----------|------------|
| **常用加密算法** | 对称 (AES/DES/3DES/RC4/ChaCha20/SM4) / 非对称 (RSA/ECC/ElGamal/SM2) / 哈希 (MD5/SHA1/256/512/SM3) / 签名 (RSA-PSS/ECDSA/EdDSA/SM2) / 密钥协商 (DH/ECDH/Kyber) / 模式 (ECB/CBC/CTR/GCM/CCM/OCB) / 填充 (PKCS#7/ISO10126/OAEP/PSS) | [[lm-ntlm-hash-generation-analysis]] LM/NTLM Hash 生成算法深度解析 |
| **网络七层模型** | 应用/表示/会话/传输/网络/数据链路/物理 → TCP/IP 四层映射 / 典型协议端口 / 报文结构 / 分片重组 / 流量控制 / 拥塞控制 / 三次握手四次挥手 / TIME_WAIT / CLOSE_WAIT | — |
| **HTTPS 建立流程** | TLS 1.2/1.3 握手 / 密钥套件协商 / 证书链验证 / OCSP Stapling / SCT / HPKP / HSTS / 0-RTT / PSK / 早期数据 / 会话恢复 / 扩展字段 (SNI/ALPN/KeyShare/SupportedVersions/SignatureAlgorithms) | — |
| **HTTP Keep-Alive** | `Connection: keep-alive` / `Keep-Alive: timeout=5, max=100` / 队头阻塞 / 管道化 / 复用限制 / 服务端并发压力 | — |
| **最新高危漏洞跟踪** | Log4j2 / ProxyLogon / ProxyShell / PrintNightmare / Log4Shell / Spring4Shell / Dirty Pipe / CVE-2022-22965 / CVE-2022-30190 (Follina) / CVE-2023-34362 (MOVEit) / CVE-2024-3400 (PAN-OS) / CVE-2024-6387 (regreSSHion) | 建立 **漏洞情报订阅源**：NVD / CVE / CNVD / CNNVD / GitHub Security Advisories / 厂商公告 / 0day.today / Exploit-DB / Packet Storm / 全球威胁情报平台 |

---

## 0x10 HR 终面篇

### 高频问题与 STAR 回答策略
| 问题 | 考察维度 | 回答要点 (STAR: Situation/Task/Action/Result) |
|------|----------|------------------------------------------------|
| **为什么选我们？** | 企业认知度 / 业务契合度 / 长期意向 | 调研过产品/技术栈/文化/行业地位 → 结合自身技能匹配 → 表达成长预期 |
| **为什么想做安全？** | 内驱力 / 热情 / 职业认知 | CTF/漏洞挖掘/应急响应/红蓝对抗经历 → 解决实际问题的成就感 → 防御视角转化 |
| **离职原因？** | 稳定性 / 情商 / 负面规避 | 个人规划与平台不匹配 / 缺乏成长空间 / 技术栈转型 / **避免吐槽前东家/薪资/人际** |
| **职业规划？** | 目标清晰度 / 晋升路径认知 | 初级工程师(1-3年)→ 高级/专家(3-5年)→ 架构师/技术负责人/咨询顾问(5-8年)→ 管理/创业/专家顾问，配合证书/论文/社区影响力 |
| **期望薪资？** | 市场行情 / 自我定价 / 谈判空间 | 调研同城同级岗位 75 分位 → 上浮 20-30% 作为期望 → 给出可接受区间 → 强调非薪福利 (培训/大会/证书/期权/弹性/补贴) |
| **值得这薪资？** | 价值锚定 / 核心竞争力 | 列举 3-5 个硬性产出 (CVE/工具/文档/攻防演练/应急案例/专利/论文/培训) → 映射 JD 核心要求 → 表达快速上手/低管理成本 |
| **接受加班？** | 抗压 / 边界感 / 执行力 | **原则接受项目刚性加班** → 强调效率提升/自动化/流程优化减少无效加班 → 询问加班文化/调休/补贴机制 |
| **反问环节？** | 主动性 / 关注点 / 判断力 | 晋升通道/导师制/技术分享/参会预算/攻防演练参与/工具采购/技术债治理/团队技术栈/业务安全痛点/考核维度/入职培训/试用期考核 |

---

## 交叉引用总表（按页面字母序）

| 页面文件名 | 关联板块 | 核心贡献 |
|------------|----------|----------|
| [[0w1club-training-shellshock-cgi-exploitation]] | 0x00/0x02 | Shellshock + Dirty COW 完整攻击链教学案例 |
| [[binary-ninja-ollvm-deobfuscation]] | 0x06 | OLLVM 去平坦化自动化插件开发 |
| [[c2-redirectors-malleable-c2-profiles]] | 0x02/0x05/0x08 | C2 基础设施隐匿拓扑设计 |
| [[cobalt-strike-external-c2-smb-beacon]] | 0x02/0x05/0x06 | CS 核心架构 / External C2 / SMB Beacon 实战 |
| [[covenant-c2-framework-analysis]] | 0x02/0x05 | Covenant P2P Mesh / .NET 实现 / 受限出站适用性 |
| [[d3ctf-2021-d3dev-qemu-escape-writeup]] | 0x02/0x09 | QEMU PCI 设备 OOB → VM Escape 利用链 |
| [[dotnet-clr-usage-log-tampering-edr-evasion]] | 0x02/0x06/0x07 | .NET CLR 日志规避四大手法 / EDR 对抗 |
| [[edu-src-penetration-test-case-study]] | 0x01 | EduSRC 实战渗透全链路 (弱口令/XSS/上传/蚁剑) |
| [[glasgowsmile-vulnhub-writeup]] | 0x01/0x02 | Joomla 爆破 → 多层编码 → 定时任务提权 |
| [[google-ctf-2021-full-chain-v8-exploitation]] | 0x09 | V8 TypedArray OOB → MojoJS 沙箱逃逸 |
| [[heap-overflow-principles-unlink-exploitation]] | 0x00/0x09 | glibc malloc Unlink 经典利用原理 |
| [[ida-pro-tips-plugins-python]] | 0x05/0x06 | FLIRT/Findcrypt-Yara/Keypatch/IDAPython 工程化 |
| [[linux-kernel-hardening-mechanisms]] | 0x07/0x08 | 编译期/内存/CFI/硬件/侧信道全维度硬化 |
| [[lm-ntlm-hash-generation-analysis]] | 0x09 | LM/NTLM Hash 生成算法 C++/OpenSSL 级解析 |
| [[mfc-message-map-internals-reverse-engineering]] | 0x06 | MFC 消息映射/序列化宏逆向识别模式 |
| [[mfc-serialization-internals]] | 0x06 | MFC 序列化运行时类结构/版本控制 |
| [[mimikatz-source-code-architecture-golden-ticket-audit]] | 0x02/0x05 | KUHL_M 架构 / Golden Ticket 源码级构造流程 |
| [[mtctf-2021-pwn-writeup]] | 0x09 | UAF/Fastbin/Unlink/Double Free/setcontext 利用链 |
| [[named-pipe-smb-detection-sysmon]] | 0x02/0x07 | SMB 命名管道检测基线 / Sysmon Event ID 17/18 |
| [[oo7-spectre-defense-binary-analysis]] | 0x07/0x09 | 跨过程污点分析定位 Spectre 三元组 / 修复手法 |
| [[pe-export-table-internals]] | 0x06 | PE 导出表三大表寻址 / 手动映射 / 模块隐藏 |
| [[pe-import-table-internals]] | 0x06 | IAT/INT 双桥 / 绑定导入 / 静态分析定位 |
| [[pe-manual-mapping-loader-implementation]] | 0x06 | 从零手写 PE 手动映射加载器全流程 C++ 实现 |
| [[peda-buffer-overflow-analysis-guide]] | 0x00/0x02/0x09 | PEDA + GDB 栈溢出偏移定位 → ROP → Root 提权 |
| [[phantom-dll-hollowing-technique]] | 0x06/0x07 | Phantom DLL Hollowing 内存隐藏 / 无文件持久化 |
| [[phishing-website-creation-tutorial]] | 0x01 | SET/Docker/PHP 三种钓鱼网站快速搭建入门 |
| [[php-webshell-obfuscation-av-evasion]] | 0x00/0x05/0x06 | PHP Webshell 两阶段混淆 (算术拆分 + XOR 拆分) 多态生成 |
| [[reverse-engineering-beginner-learning-path]] | 0x09 | 逆向入门路线/书籍/视频/任务驱动法/搜索技巧 |
| [[rop-linux-x86-beginner-tutorial]] | 0x09 | Linux x86 ROP 入门 (栈溢出/保护机制/偏移/Shellcode) |
| [[smb-named-pipe-c2-communication]] | 0x02 | SMB 协议/命名管道原理 / C2 通道利用 / 检测缓解 |
| [[sourcerercc-code-clone-detection]] | 0x08 | 大规模 Token 级代码克隆检测 (ICSE 2016) |
| [[sqlmap-api-automation]] | 0x00/0x01/0x05 | SQLMap REST API 批量化/可编程化注入检测 |
| [[v8-issue-944062-gc-arbitrary-write]] | 0x09 | V8 TurboFan GC Marking Bitmap 任意读写利用链 |
| [[v8-turbofan-changeint32toint64-1day-analysis]] | 0x09 | ChangeInt32ToInt64 类型混淆 1day 利用全链路 |
| [[vulnhub-bbs-cute-102-writeup]] | 0x01/0x02 | CuteNews 文件上传绕过 GIF89 → Shell → 提权 |
| [[vulnhub-boredhackerblog-social-network-writeup]] | 0x02 | Web 注入 → Docker 逃逸 → 内网穿透 → 横向 → 宿主机 RCE → SSH |
| [[vulnhub-chronos-writeup]] | 0x01/0x02 | JS 混淆/Base58/命令注入/原型链污染/EJS RCE/sudo node 提权 |
| [[vulnhub-dawn2-writeup]] | 0x02 | Windows 栈溢出 Immunity+mona → msfvenom → Python Exploit → 双服务提权 |
| [[vulnhub-doubletrouble-writeup]] | 0x00/0x02 | Shellshock → Dirty COW 完整复现 (OSCP 风格) |
| [[vulnhub-hard-socnet2-writeup]] | 0x01/0x02 | 文件上传/SQLi/XML-RPC/CVE-2021-3493/缓冲区溢出全链路 |
| [[vulnhub-infosecprep-oscp-writeup]] | 0x02 | WordPress 目录遍历 → SSH Key Base64 → SUID bash 提权 |
| [[vulnhub-platform-resource-index]] | 0x02 | 750+ 靶机 1053G 资源合集 / Writeup 交叉索引 |
| [[vulnhub-pwned-writeup]] | 0x02 | FTP 凭证复用 → SSH Key → sudo 提权 → Docker 逃逸 Root |
| [[vulnhub-sar-writeup]] | 0x02 | sar2HTML RCE → 计划任务/CVE-2021-3493 双提权路径 |
| [[windows-syscall-internals-sysenter-kifastcallentry]] | 0x06/0x09 | 用户态→内核态系统调用全链路 (NtOpenProcess 为例) |
| [[windows-x86-stack-overflow-shellcode-execution]] | 0x00/0x09 | Windows x86 栈溢出 Shellcode 执行全流程 (PEB/导出表/零字节绕过) |
| [[xihulunjian-2020-iot-pwn3-ezarmpwn-writeup]] | 0x09 | ARM 32位 栈溢出/UAF/Off-by-null/ROP/Double Free/Chunk Overlap |

---

## 维护指南

1. **新增面试题** → 追加至对应板块小节，同步更新「交叉引用总表」  
2. **新增详解页** → 在本页面相关条目后添加 `[[wikilink]]`，并在详解页顶部回链 `[[cybersecurity-interview-guide-2022]]`  
3. **漏洞情报更新** → 0x09「最新高危漏洞跟踪」滚动维护，建议接入自动化 RSS/推送  
4. **工具版本迭代** → 0x05 参数表随主流版本 (CS 4.x / Covenant 0.7+ / SQLMap 1.6+ / Nmap 7.94+) 同步  
5. **合规法规变更** → 0x08 合规法务栏同步《网络安全法》《数据安全法》《个信法》《关基条例》《密码法》修订版条款映射

---

> **结语**：本页面旨在为「面试复习 → 技术深究 → 实战复现」提供一站式导航。面试是检验体系化程度的试金石，**真正的护城河在于能否将零散知识点串联成可复用的攻防方法论**。祝各位在 2022 及之后的求职/攻防征途中「历经磨难后 依旧继续从容向前」。

## 来源

- [0x00实验室-202108-202304_039](../sources/0x00实验室-202108-202304_039.md)
