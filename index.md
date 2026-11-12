# Index

## ai-security

- [[frp内网渗透应用]] `frp` `内网穿透` `内网渗透` `Socks5` `Metasploit` `端口转发` `隧道技术` — 详细记录 frp 在内网渗透中的四大典型应用场景：Socks5 隧道搭建、多级隧道串联、代理本地 Metasploit 反弹、以及 RDP 等服务的远程端口转发，附完整配置示例与拓扑说明。
- [[h2-console-jndi注入rce利用]] `H2 Database` `JNDI Injection` `RCE` `Spring Boot` `漏洞复现` `JNDI-Injection-Exploit` — 详细记录 H2 Database 控制台未授权访问配合 JNDI 注入（搭配 JNDI-Injection-Exploit 工具）实现远程代码执行的实战攻击链。
- [[java-deserialization-fundamentals]] `Java` `序列化` `反序列化` `Serializable` `Externalizable` `serialVersionUID` `ObjectOutputStream` `ObjectInputStream` `基础机制` — 系统梳理 Java 序列化/反序列化核心机制：Serializable 与 Externalizable 接口对比、serialVersionUID 版本控制、ObjectOutputStream/ObjectInputStream 标准用法，为后续反序列化漏洞利用链分析奠定基础。
- [[jwt漏洞原理与实战利用]] `JWT` `漏洞利用` `DDCTF` `垂直越权` `算法混淆` `密钥爆破` `信息泄露` — 系统梳理 JWT 结构、常见漏洞（算法混淆、密钥爆破、信息泄露）及利用工具，结合 DDCTF 实战复现垂直越权全过程。
- [[spring-boot-actuator配置不当rce利用]] `Spring Boot` `Actuator` `RCE` `H2 Database` `JNDI Injection` `Spring Cloud Config` `目录穿越` `Eureka` `XStream` `SpEL` `漏洞复现` — 详细记录 Spring Boot 2.x Actuator 暴露 env 与 restart 端点结合 H2 CREATE ALIAS 实现 RCE 的完整利用链；补充 Eureka XStream 反序列化 RCE 利用链、SpEL 表达式注入、完整 Actuator 端点清单及 /env /refresh 交互利用细节、H2 Console JNDI 注入及 Spring Cloud Config 目录穿越利用方式。
- [[spring-boot-spel表达式注入]] `Spring Boot` `SpEL` `表达式注入` `Whitelabel Error Page` `RCE` `漏洞复现` — 记录 Spring Boot Whitelabel Error Page SpEL 表达式注入原理、影响版本、验证步骤与命令执行 Payload 构造方法
- [[spring-cloud-config目录穿越漏洞]] `Spring Cloud Config` `目录穿越` `CVE-2020-5410` `双重编码` `任意文件读取` `漏洞复现` — 详细记录 Spring Cloud Config Server 目录穿越漏洞（CVE-2020-5410 等变种）的两种双重编码绕过 PoC 与任意文件读取利用方式。
- [[tctf-2021-1linephp-zip-include]] `TCTF` `PHP` `ZIP协议` `文件包含` `临时文件` `Session` `利用链` — 记录 2021 TCTF 1linephp 题目利用 zip:// 协议包含临时上传文件与 Session 文件，通过 ZIP 头偏移绕过 upload_progress_ 前缀实现任意文件包含的完整利用链
- [[tctf-2021-worldcup-xss-go-ssti]] `TCTF` `XSS` `SSTI` `Go` `模板注入` `2021` — 复现 2021 TCTF worldcup 三关挑战：Level 1/2 利用反引号逃逸与 Unicode 编码绕过实现 XSS 窃取 Nonce，Level 3 结合 Go 模板注入（SSTI）泄露服务端变量从而精准押注拿 Flag
- [[wechat-pc-v8-rce-0day-analysis]] `WeChat` `0day` `RCE` `V8引擎` `Chromium` `CobaltStrike` `内网渗透` `社会工程学` `漏洞复现` — 深度解析微信 PC 版 3.2.1.141 及以下版本因内嵌 Chromium V8 引擎漏洞且沙箱默认关闭，导致点击恶意链接即触发 RCE，配合 CobaltStrike 实现内网横向渗透的完整攻击链复现与防护指南。

## program-analysis

- [[google-ctf-2021-full-chain-v8-exploitation]] `V8` `Chrome` `CTF` `Browser Exploitation` `TypedArray` `Pointer Compression` `MojoJS` `Sandbox Escape` — Google CTF 2021 Full Chain 题目中 V8 部分的漏洞分析与利用过程：TypedArray.set 越界写漏洞、指针压缩下的任意读写原语构造、通过修改 RenderFrameImpl.enabled_bindings_ 开启 MojoJS 实现沙箱逃逸第一步
- [[ida-pro-tips-plugins-python]] `IDA Pro` `FLIRT` `签名生成` `Findcrypt-Yara` `Keypatch` `IDAPython` `逆向工程` `插件安装` — 汇总 IDA Pro 逆向分析中的常用实用技巧，包括使用 FLIRT 从静态库生成签名恢复符号表、Windows 下安装 Findcrypt-Yara 与 Keypatch 插件、配置第三方 Python 库路径以便在 IDAPython 中直接导入。
- [[linux-kernel-hardening-mechanisms]] `Linux Kernel` `Hardening` `Security Mitigations` `Grsecurity` `PaX` `Memory Protection` `Control Flow Integrity` `Side-channel Mitigation` — 系统梳理 Linux 内核主流防御机制，涵盖编译期硬化、内存保护、控制流完整性、硬件辅助防护、侧信道缓解及 Grsecurity/PaX 核心特性

## uncategorized

- [[007攻防实验室]] `007攻防实验室` `网络安全` `CTF` `安全研究` `微信归档` — 007攻防实验室 2020-07 至 2020-10 微信归档的入口、来源与待补全条目
- [[03sec-network-security-team-202105-wechat-archive]] `03sec` `网络安全` `微信归档` `2021年5月` `文章索引` — 03sec网络安全团队微信公众号2021年5月份文章归档索引页面，汇总当月发布的安全技术文章、工具分享、漏洞分析等内容。
- [[0th3rs-security-team-wechat-archive-201911-202204]] `0th3rs` `安全团队` `微信归档` `文章索引` `网络安全` `2019` `2020` `2021` `2022` — 0th3rs安全团队微信公众号 2019年11月至2022年4月期间发布文章的汇总索引页面，涵盖安全研究、CTF实战、漏洞分析、工具分享等技术内容。
- [[ctf-flask-path-traversal-vim-crypto]] `CTF` `Flask` `目录穿越` `Vim加密` `Writeup` `实战复现` — 记录一道 Flask CTF 题目通过 move 接口目录穿越读取 flag、并结合剧集台词破解 Vim 加密文件的完整解题过程
- [[ctf-misc入门与工具箱]] `CTF` `Misc` `隐写术` `流量分析` `内存取证` `文件修复` `工具箱` — 系统梳理 CTF Misc 方向常见考点：编码转换、隐写术、文件修复、流量/内存取证，以及核心工具链（binwalk、foremost、steghide、Volatility 等）速查表。
- [[php伪协议与反序列化利用]] `PHP` `伪协议` `反序列化` `__toString` `CTF` `文件读取` — 系统梳理 PHP 伪协议（php://filter、php://input、data:// 等）利用技巧，结合 __toString 魔术方法反序列化漏洞实现任意文件读取。基于赣网杯2020题目实战复现。
- [[qwb2019-随便注-sql注入复现]] `CTF` `SQL注入` `强网杯2019` `MariaDB` `堆叠查询` `WAF绕过` `预编译` `表重命名` — 强网杯2019随便注题目完整复现，涵盖报错注入、WAF绕过、堆叠查询、预编译绕过、表重命名等MySQL/MariaDB注入实战技巧
- [[usb流量取证与隐写综合实战]] `CTF` `Misc` `USB取证` `流量分析` `隐写术` `PDF隐写` `视频隐写` `Steghide` `wbStego4open` `Base85` `赣网杯2020` — 基于赣网杯2020题目复现，系统梳理 USB 键盘流量按键码提取与 HID 映射还原明文、PDF 隐写工具 wbStego4open 解密、视频文件分离图片后结合 Steghide 爆破与 Base85 解码的完整实战链路。
