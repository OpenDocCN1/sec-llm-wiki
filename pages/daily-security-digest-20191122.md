---
title: 每日安全看点 2019-11-22
description: 2019年11月22日每日安全看点汇总，涵盖Modlishka钓鱼工具分析、永恒之蓝后渗透利用、渗透常用端口利用总结、Chrome 0day漏洞分析等安全技术资讯。
category: ai-security
tags:
- 每日安全看点
- 2019年11月
- Modlishka
- 钓鱼工具
- 永恒之蓝
- 后渗透
- 端口利用
- Chrome 0day
- 漏洞分析
- 网络钓鱼
- 渗透测试
date: '2019-11-22'
updated: '2026-11-13'
---

## 概述

本期每日安全看点收录了 2019 年 11 月 22 日的多篇安全技术文章，涵盖社会工程学钓鱼工具深度分析、经典漏洞利用的后渗透实战、渗透测试常用端口利用总结、浏览器 0day 漏洞技术分析，以及两条行业新闻动态。

## 核心技术文章

### Modlishka 网络钓鱼工具细节分析

> 来源：FreeBuf 文章《网络钓鱼工具Modlishka的细节分析》

**Modlishka** 是一款功能强大的反向代理钓鱼工具，能够实现实时的双因素认证（2FA）绕过。文章深度解析了其核心原理与攻击流程：

- **核心机制**：作为反向代理位于受害者与目标站点之间，实时转发请求/响应，动态重写域名、Cookie、CSP 等安全头
- **2FA 绕过**：捕获受害者输入的一次性验证码（TOTP、短信码、推送确认），攻击者可在有效期内完成登录
- **会话劫持**：获取完整的会话 Cookie，实现无需凭证的持久化访问
- **部署便捷**：单二进制文件，支持自动化证书申请（Let's Encrypt），配置简单

**防御建议**：
- 部署 FIDO2 / WebAuthn 硬件密钥（如 YubiKey），因其基于源站验证，天然免疫反向代理钓鱼
- 启用严格的 CSP 策略，限制外部资源加载
- 用户教育：检查地址栏域名、证书指纹，警惕异常登录提示

### 从永恒之蓝看后渗透

> 来源：FreeBuf 文章《从永恒之蓝看后渗透》

以 **EternalBlue (MS17-010, CVE-2017-0144)** 为切入点，系统梳理了利用成功后的后渗透攻击面：

| 阶段 | 关键技术与工具 | 说明 |
|------|----------------|------|
| **权限维持** | 创建隐藏账户、注册表 Run 键、WMI 事件订阅、计划任务、服务安装、DLL 劫持 | 实现长期驻留 |
| **凭证获取** | Mimikatz (lsass 内存读取)、SAM 注册表离线破解、DCSync (域控同步)、LSA Secrets、浏览器凭证导出 | 横向移动核心燃料 |
| **横向移动** | PsExec、WMI、SMB 共享投放、Pass-the-Hash / Pass-the-Ticket、RDP 劫持、SCM 远程服务创建 | 向高价值资产渗透 |
| **域控制** | 黄金/白银票据、Skeleton Key、DCShadow、ACL 修改、域信任利用 | 完全控制域环境 |
| **数据窃取** | 阶段性打包、加密压缩、DNS/HTTP/HTTPS 隐蔽通道、云存储上传 | 规避 DLP 检测 |
| **痕迹清理** | 清除 Windows 事件日志 (wevtutil)、USN Journal、Prefetch、MFT 时间戳修改 (Timestomp)、PowerShell 历史清理 | 对抗取证分析 |

**检测视角**：
- 关注 445 端口异常连接、SMB 会话枚举、服务创建事件 (Event ID 4697)、WMI 进程创建 (Event ID 5861)、计划任务注册 (Event ID 4698)、LSASS 访问 (Event ID 4663/1000)
- 部署蜜罐账户、Canary Token、ETW/AMSI 增强监控

### 渗透常用端口利用总结

> 来源：微信公众号文章《渗透常用端口利用总结》

系统整理了渗透测试中高频遇到的端口服务、常见漏洞类型及利用工具/命令速查表：

| 端口 | 服务 | 典型攻击面 | 常用工具/命令 |
|------|------|------------|---------------|
| 21 | FTP | 匿名登录、弱口令、目录遍历、后门 (vsftpd 2.3.4) | `ftp`, `lftp`, `hydra`, `msf> auxiliary/scanner/ftp/ftp_login` |
| 22 | SSH | 弱口令、密钥泄露、CVE-2018-15473 (用户枚举)、SSH Agent 转发滥用 | `hydra`, `ssh-audit`, `ssh-keygen`, `msf> auxiliary/scanner/ssh/ssh_enumusers` |
| 23 | Telnet | 明文传输、弱口令、路由器/设备后门 | `telnet`, `hydra`, `msf> auxiliary/scanner/telnet/telnet_login` |
| 25/465/587 | SMTP | 用户枚举 (VRFY/EXPN/RSET)、开放中继、钓鱼发信 | `smtp-user-enum`, `swaks`, `msf> auxiliary/scanner/smtp/smtp_enum` |
| 53 | DNS | 区域传送 (AXFR)、子域名枚举、DNS 隧道 (dnscat2)、缓存投毒 | `dig axfr @target`, `dnsrecon`, `fierce`, `dnscat2` |
| 80/443 | HTTP/HTTPS | Web 漏洞全谱系 (SQLi, XSS, RCE, SSRF, 文件上传/包含, 逻辑漏洞)、CMS 指纹识别、目录扫描、WAF 绕过 | `nmap --script http-*`, `nikto`, `dirsearch`, `gobuster`, `sqlmap`, `Burp Suite`, `nuclei` |
| 135/139/445 | SMB/RPC | MS17-010、SMB 信息泄露、空会话/IPC$、SMB 签名未强制、Pass-the-Hash | `smbclient`, `enum4linux`, `crackmapexec`, `impacket`, `msf> exploit/windows/smb/ms17_010_eternalblue` |
| 1433 | MSSQL | 弱口令、SA 权限、xp_cmdshell、存储过程滥用、链接服务器 | `sqsh`, `mssqlclient.py`, `msf> auxiliary/admin/mssql/mssql_exec` |
| 3306 | MySQL | 弱口令、UDF 提权、MOF 提权、读写文件 (LOAD DATA INFILE)、CVE-2016-6662 | `mysql`, `mysqldump`, `msf> auxiliary/scanner/mysql/mysql_login` |
| 3389 | RDP | 弱口令、CVE-2019-0708 (BlueKeep)、凭证复用、剪贴板重定向、驱动加载 | `xfreerdp`, `rdesktop`, `hydra`, `msf> auxiliary/scanner/rdp/rdp_scanner` |
| 5432 | PostgreSQL | 弱口令、COPY 文件读写、UDF、大对象 (lo) 导入导出 | `psql`, `msf> auxiliary/scanner/postgres/postgres_login` |
| 5900/5901 | VNC | 弱口令、无认证、CVE-2019-15681 等多漏洞 | `vncviewer`, `vncpwd`, `msf> auxiliary/scanner/vnc/vnc_none_auth` |
| 6379 | Redis | 未授权访问、写 SSH 公钥、写 crontab、写 Webshell、主从复制 RCE (CVE-2022-0543 等) | `redis-cli`, `msf> auxiliary/scanner/redis/redis_server` |
| 27017 | MongoDB | 未授权访问、匿名读取、NoSQL 注入 | `mongo`, `msf> auxiliary/scanner/mongodb/mongodb_login` |
| 50000 | SAP | 信息泄露、默认凭证、RFC 调用 | `SAPDetector`, `msf> auxiliary/scanner/sap/sap_router_version` |

**实战技巧**：
- 使用 `nmap -sV -sC -p- -T4 --min-rate 1000` 快速全端口扫描并识别服务版本
- 结合 `searchsploit`、`vulners.nse`、`nuclei` 自动化漏洞匹配
- 内网环境优先关注 SMB、RDP、数据库、Redis 等高价值横向移动跳板

### Chrome 最新 0day 漏洞分析

> 来源：FreeBuf 文章《Chrome 最新 0-day 漏洞分析》

分析了当时在野利用的 Chrome V8 引擎类型混淆漏洞（**CVE-2019-13720**，后经确认为 **CVE-2019-5786** 关联变种或同期另一 0day），核心要点：

- **漏洞成因**：V8 JIT 编译优化阶段（TurboFan）对对象类型推断错误，导致类型混淆，进而实现任意读写原语
- **利用链**：
  1. 构造特定 JS 对象布局，触发 JIT 优化中的边界检查消除
  2. 通过类型混淆构造 `fakeobj` / `addrof` 原语
  3. 泄露堆地址绕过 ASLR，修改 `ArrayBuffer` backing store 指针实现任意地址读写
  4. 覆盖 WASM RWX 页面或 JIT 代码区实现 Shellcode 执行
- **沙箱逃逸**：文章提及该 0day 可能配合 Windows 内核提权漏洞（如 win32k.sys）实现完整利用链
- **修复时间线**：Google Project Zero 披露 → Chrome 78.0.3904.87 紧急修复（2019-10-31/11-01 推送）

**缓解措施**：
- 及时更新 Chrome 至最新稳定版
- 启用站点隔离 (`chrome://flags/#enable-site-per-process`)
- 企业环境部署 Chrome Enterprise 策略强制自动更新
- 关注 Google Threat Analysis Group (TAG) 发布的在野利用报告

## 行业动态

### 年中国科学院院士增选结果公布

中国科学院发布 2019 年院士增选当选名单，共 64 人当选（数学物理学部 13 人、化学部 8 人、生命科学和医学学部 14 人、地学部 9 人、信息技术科学部 10 人、技术科学部 10 人），标志着国家在基础研究与前沿技术领域的最新学术权威布局。

### 美国打造全球最大网络武器库引发军备竞赛

报道指出美国网络司令部（USCYBERCOM）持续扩充网络武器储备，推行“持续接触”与“前沿防御”战略，加速漏洞收集、武器化与部署，引发国际社会对网络军备竞赛升级、零日漏洞囤积风险及关键基础设施安全的深切担忧。

## 关联知识页面

- [[daily-security-digest-20191123]] — 翌日安全看点，涵盖 uniFuzzer、OLLVM 去混淆、TextCNN 恶意软件检测、Bad Binder 漏洞等
- [[daily-security-digest-20191125]] — 后续安全看点，含 PowerShell 反混淆、Flan Scan、IoT 渗透、Peach Fuzzing、CobaltStrike 插件等
- [[frp内网渗透应用]] — 内网渗透隧道技术实战，可作为后渗透横向移动阶段的补充工具参考
- [[h2-console-jndi注入rce利用]] — 典型后渗透凭证利用与 RCE 实战案例
- [[spring-boot-actuator配置不当rce利用]] — Spring Boot 后渗透常见攻击面
- [[wechat-pc-v8-rce-0day-analysis]] — 另一基于 V8 引擎的客户端 RCE 0day 深度分析，可对比 Chrome 0day 利用异同

## 参考链接

1. Modlishka 分析：https://www.freebuf.com/articles/network/217091.html
2. 永恒之蓝后渗透：https://www.freebuf.com/articles/system/219200.html
3. 端口利用总结：https://mp.weixin.qq.com/s/y4TCYqgV_YfDXpkQt1BMLQ
4. Chrome 0day 分析：https://www.freebuf.com/articles/network/218899.html
5. 中科院院士名单：https://mp.weixin.qq.com/s/hLO520DECqZ6vE7oNHREiw
6. 美网络军备竞赛：https://mp.weixin.qq.com/s/MK1-rPo9lg9y30f74uf3cw

## 来源

- [0th3rs安全团队-201911-202204_131](../sources/0th3rs安全团队-201911-202204_131.md)
