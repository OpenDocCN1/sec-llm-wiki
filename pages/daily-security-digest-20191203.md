---
title: 每日安全看点 - 2019年12月3日
description: 汇总 2019 年 12 月 3 日每日安全看点，涵盖 D3CTF 题目源码、Kerberos 域用户枚举、SQL 注入原理、WebLogic
  密文解密、ATT&CK Website Docker、杀软绕过 0day 及 XSS payload 缩短技巧等资讯
category: ai-security
tags:
- 每日安全看点
- 2019年12月
- CTF
- Kerberos
- SQL注入
- WebLogic
- ATT&CK
- 杀软绕过
- XSS
- 0day
date: '2019-12-03'
updated: '2026-11-13'
---

## 概述

本期每日安全看点汇总了 2019 年 12 月 3 日的 8 条安全技术资讯，涉及 CTF 竞赛、内网渗透、Web 漏洞分析、中间件解密、威胁建模工具、杀毒软件绕过技术及 XSS 利用技巧等多个方向。

## CTF 竞赛资源

### D3CTF 2019 题目源码公开

D3CTF 组织方在 GitHub 发布了 2019 年比赛的完整题目源码，包含 Web、Pwn、Reverse、Crypto、Misc 等多个方向的挑战实现与解题脚本。

- **资源地址**：https://github.com/D-3CTF/D3CTF-2019-Challenges
- **适用场景**：CTF 训练、题目复现、安全技术学习

> **关联阅读**：同期 CTF 题目解析可参考 [[ctftime-writeup-digest-20210325]]、[[ctftime-writeup-digest-20210327]] 等后续整理的 CTFtime Writeup 汇总。

## 内网渗透技术

### Kerberos 域用户枚举

Attackdebris 博客详细介绍了利用 Kerberos 协议特性进行域用户枚举的方法，包括 AS-REQ 枚举、Kerbrute 工具使用、Pre-auth 绕过等技术细节。

- **文章地址**：https://www.attackdebris.com/?p=311
- **核心技术点**：
  - Kerberos 预认证机制滥用
  - 用户名有效性验证（不触发账户锁定）
  - 常用工具：Kerbrute、Rubeus、Impacket 脚本

> **延伸关联**：内网渗透体系化实战可参考 [[daily-security-digest-20191216]] 中的「内网渗透实战」、[[frp内网渗透应用]] 中的隧道技术应用。

## Web 漏洞原理与案例

### SQL 注入漏洞原理与实战案例

阿里云安全团队（先知社区）发布系统性文章，从原理分类、利用方式、绕过技巧、实战案例四个维度剖析 SQL 注入漏洞。

- **文章地址**：https://xz.aliyun.com/t/6872
- **涵盖内容**：
  - 报错注入、布尔盲注、时间盲注、联合查询注入、堆叠注入
  - WAF 绕过技巧（编码、注释、大小写、等价替换）
  - 真实 CMS 漏洞案例复现

> **关联漏洞分析**：同类 SQL 注入深度审计可参考 [[ecshop-414-sql-injection-analysis]]、[[zzzphp-sql-injection-analysis]]、[[cmseasy-7.3.8-code-audit]]、[[zzzcms-v1.7.5-audit]]。

## 学术前沿

### NeurIPS 顶会接收：PyTorch 官方论文首次曝光完整设计思路

PyTorch 核心团队在 NeurIPS 2019 提交的论文首次系统阐述了 PyTorch 的架构设计理念、动态计算图机制、自动微分引擎实现及分布式训练框架。

- **文章地址**：https://mp.weixin.qq.com/s/_hZSIha2MURdH3oUKhWVRw
- **核心看点**：
  - Tensor 与 Variable 合并后的内存管理优化
  - Autograd 反向传播图构建与执行机制
  - 分布式 RPC 框架与参数服务器设计

## 中间件安全

### 一文解密所有 WebLogic 密文

FreeBuf 文章详细记录了 WebLogic 控制台、数据源、JMS、LDAP 等配置中加密密文的解密方法，覆盖 3DES、AES 等算法及密钥导出流程。

- **文章地址**：https://www.freebuf.com/articles/web/220147.html
- **技术要点**：
  - `SerializedSystemIni.dat` 与 `boot.properties` 密钥提取
  - `weblogic.security.internal.encryption.ClearOrEncryptedService` 调用链
  - 自动化解密脚本编写

> **关联中间件漏洞**：WebLogic 反序列化 RCE 利用链可参考 [[spring-boot-actuator配置不当rce利用]]、[[h2-console-jndi注入rce利用]]、[[java-urlconnection-ssrf-protocol-bypass]] 中的 JNDI 注入利用思路。

## 威胁建模工具

### ATT&CK Website Docker (Blacksmith 0.0.1)

Blacksmith 项目提供基于 Docker 的 ATT&CK 知识库本地化部署方案，支持离线查询技术矩阵、组织档案、缓解措施、检测规则等内容。

- **文档地址**：https://blacksmith.readthedocs.io/en/latest/attack_website_docker.html
- **部署优势**：
  - 内网隔离环境可用
  - 版本锁定，避免上游变更影响
  - 支持自定义扩展标签与导航

> **关联 ATT&CK 实战**：[[daily-security-digest-20191206]]、[[daily-security-digest-20191223]]、[[daily-security-digest-20191227]]、[[daily-security-digest-20200113]]、[[daily-security-digest-20200210]] 均包含 ATT&CK 落地应用案例。

## 杀毒软件绕过技术

### R3 与 R0 层 0day 组合绕过杀毒软件演示

研究员 huoji120 在 GitHub 发布演示代码，展示如何结合 Ring 3 (用户态) 与 Ring 0 (内核态) 两个 0day 漏洞，实现对主流杀毒软件的完全绕过并执行任意代码。

- **项目地址**：https://github.com/huoji120/Antivirus_R3_bypass_demo
- **技术架构**：
  - R3 层：利用用户态漏洞实现初步代码执行与 Shellcode 加载
  - R0 层：内核驱动漏洞实现内存保护绕过、回调函数劫持、EDR 钩子清除
  - 联动：用户态触发内核态提权，最终获得 SYSTEM 权限免杀执行

> **关联免杀技术**：[[daily-security-digest-20191210]]、[[daily-security-digest-20191218]]、[[daily-security-digest-20200117]]、[[daily-security-digest-20200212]]、[[wechat-pc-v8-rce-0day-analysis]] 涉及 Cobalt Strike 免杀、SysWhispers 系统调用绕过、V8 引擎 0day 等进阶对抗技术。

## XSS 利用技巧

### 特殊字符缩短 XSS Payload 长度

Javier Lajara 博客分析了利用 Unicode 特殊字符、HTML 实体编码、浏览器解析差异等手段，将 XSS Payload 压缩至 20 字符以内的技巧。

- **文章地址**：https://jlajara.gitlab.io/posts/2019/11/30/XSS_20_characters.html
- **核心技巧**：
  - `<svg/onload=alert()>` 等短标签利用
  - 利用 `'` `"` 反引号闭合属性
  - JavaScript 取反 `~`、逗号表达式、模板字符串缩短代码
  - 浏览器自动补全标签特性滥用

> **关联 XSS 实战**：[[tctf-2021-worldcup-xss-go-ssti]]、[[xmind-xss-to-rce-vulnerability]]、[[jwt漏洞原理与实战利用]]、[[cve-digest-20210328]]、[[cve-digest-20210406]] 涵盖 XSS 到 RCE 链、SSTI 组合、CMS 插件 XSS 等进阶利用。

## 同期每日安全看点导航

| 日期 | 页面 | 核心看点 |
|------|------|----------|
| 2019-12-04 | [[daily-security-digest-20191204]] | pydictor、AI 军事应用、IoT 逆向 U-Boot、TP-LINK 漏洞、Strandhogg Android 漏洞 |
| 2019-12-05 | [[daily-security-digest-20191205]] | Linux 加壳脱壳、Redis RCE、iOS 内核 QEMU、Geost 僵尸网络、GitLab 路径遍历 |
| 2019-12-06 | [[daily-security-digest-20191206]] | 网络空间测绘、ATT&CK 应用、Strapi RCE、Java 代码审计、XPath 注入、newlib 堆利用 |
| 2019-12-09 | [[daily-security-digest-20191209]] | Linux 逆向反调试、Firefox 漏洞利用链、Chrome DevTools CSP、YARA 规则生成 |
| 2019-12-10 | [[daily-security-digest-20191210]] | H1ve 攻防平台、Linux Hook、360 杀软绕过、CVE-2019-15588、Java Web 安全知识库 |
| 2019-12-11 | [[daily-security-digest-20191211]] | DroneSploit、2019 网络攻击回顾、PHP sprintf 漏洞、iOS 12.0.4 内核漏洞 |
| 2019-12-12 | [[daily-security-digest-20191212]] | Apple AirDos、深度学习恶意软件分类、浏览器安全、Outlook 漏洞、JQ 命令注入 |
| 2019-12-16 | [[daily-security-digest-20191216]] | 内网渗透、WinRAR 逆向、Docker 容器安全、RealWorldCTF Safari、CDPSvc 提权 |
| 2019-12-17 | [[daily-security-digest-20191217]] | 鱼叉式攻击、针孔摄像头检测、CTF PWN、远控免杀 |
| 2019-12-18 | [[daily-security-digest-20191218]] | TP-Link 漏洞、比特币区块链隐藏 C2、Cobalt Strike 免杀、SysWhispers、Chrome UAF |
| 2019-12-19 | [[daily-security-digest-20191219]] | 区块链智能合约逆向、儿童 GPS 手表隐私、DLL 镂空、网站镜像复制 |
| 2019-12-20 | [[daily-security-digest-20191220]] | APT-C-08 蔓灵花、zzzphp SQL注入、逆向工程资源库、Facebook 手机号泄露 |
| 2019-12-23 | [[daily-security-digest-20191223]] | ATT&CK/APT 归因、Project Zero 在野漏洞、Chrome WebSQL RCE、Mozi 僵尸网络 |
| 2019-12-24 | [[daily-security-digest-20191224]] | 内网穿透、PHP 木马、零知识证明、PHP 动态特性、Hypervisor 入门 |
| 2019-12-25 | [[daily-security-digest-20191225]] | 机器学习测试 WAF、Django CVE-2019-19844、DarkRat、Empire 3.0 |
| 2019-12-26 | [[daily-security-digest-20191226]] | FLIRT 符号恢复、Binary Ninja 去混淆、区块链教程、Fuzzing 会议 |
| 2019-12-27 | [[daily-security-digest-20191227]] | Web API 安全、Google Cloud Shell 漏洞、iOS 代码签名、SOP 绕过、Nightmare 逆向 |
| 2019-12-30 | [[daily-security-digest-20191230]] | Google XSS 技巧、Metasploit DoS、移动端渗透测试、Fuzzing 漏洞挖掘 |

## 来源

- [0th3rs安全团队-201911-202204_121](../sources/0th3rs安全团队-201911-202204_121.md)
