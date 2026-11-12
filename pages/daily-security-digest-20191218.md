---
title: 每日安全看点 2019-12-18
description: 2019年12月18日每日安全看点汇总，涵盖TP-Link路由器漏洞、比特币区块链隐藏C2、Linode令牌窃取、Cobalt Strike免杀、SysWhispers系统调用绕过、eGain邮件头注入、PathAuditor工具、勒索病毒报告、Chrome
  UAF沙箱逃逸、Mac安全威胁趋势等。
category: ai-security
tags:
- 每日安全看点
- 2019年12月
- TP-Link
- 比特币
- 区块链
- C2
- Linode
- Cobalt Strike
- 免杀
- SysWhispers
- 系统调用
- 绕过AV
- eGain
- 邮件头注入
- PathAuditor
- 勒索病毒
- Chrome
- UAF
- 沙箱逃逸
- Mac
- 安全趋势
date: 2019-12-18
updated: '2026-11-13'
---

## 概述

本期每日安全看点汇总了 2019 年 12 月 18 日的安全资讯，涉及路由器漏洞、区块链威胁情报、云服务商安全事件、红队免杀技术、系统调用绕过、应用层漏洞分析、漏洞挖掘工具、勒索软件趋势报告、浏览器沙箱逃逸漏洞及 Mac 平台威胁态势等多个方向。

## 漏洞分析

### TP-Link Archer 系列路由器管理员密码保护失效

**来源**：FreeBuf 漏洞分析

TP-Link Archer 系列路由器存在安全漏洞，导致 Admin 账户密码保护机制失效，攻击者可利用该漏洞绕过认证或重置密码，进而控制设备。

> 相关阅读：[[cve-digest-20210327]]、[[cve-digest-20210413]]、[[cve-digest-20210330]]（后续年份 TP-Link 相关漏洞聚合）

### eGain 邮件头注入漏洞 (CVE-2019-17123)

**来源**：Maveris Labs 分析文章

eGain 产品存在邮件头注入漏洞 (CVE-2019-17123)，攻击者可通过构造恶意输入注入邮件头字段（如 Bcc、Subject 等），实现垃圾邮件发送、钓鱼攻击或绕过邮件过滤规则。

### Chrome OfflinePageAutoFetcher UAF 沙箱逃逸 (CVE-2019-13686)

**来源**：Chromium Issue Tracker

Chrome 浏览器 `OfflinePageAutoFetcher` 组件存在 Use-After-Free (UAF) 漏洞 (Issue 1000002)，该漏洞可被利用实现沙箱逃逸，属于高危浏览器内核漏洞。

## 威胁情报与攻击技术

### 比特币区块链中隐藏的 Pony C&C 服务器

**来源**：FreeBuf 区块链安全文章

分析发现攻击者利用比特币区块链的不可篡改性和公开性，将 Pony 僵尸网络的命令控制 (C&C) 服务器地址隐藏在交易数据中，实现弹性、抗封锁的 C2 基础设施。

### Linode 令牌窃取案例

**来源**：Medium 技术博客

文章详述了滥用 Linode 平台特定功能（如元数据服务或 API 交互方式）窃取用户 API Token 的攻击手法，提醒云资源凭证管理的安全风险。

## 红队工具与免杀技术

### Cobalt Strike Payload 混淆绕过 Windows Defender

**来源**：OffensiveOps 技术博客

介绍通过对 Cobalt Strike 生成的 Payload 进行混淆处理（如加密、编码、打桩等），绕过 Windows Defender 静态查杀与动态行为监控的实战技巧。

### SysWhispers：直接系统调用绕过 AV/EDR

**来源**：GitHub 项目 (jthuraisamy/SysWhispers)

SysWhispers 是一个自动化工具，生成直接调用 Windows 系统服务 (System Calls) 的汇编/内联代码，避免调用被 Hook 严重的 `ntdll.dll` 导出函数，从而绕过用户态 AV/EDR 的 API 监控。

## 漏洞挖掘与代码审计工具

### PathAuditor：检测不安全路径访问模式

**来源**：Google Security Blog

Google 开源工具 PathAuditor 基于预加载二进制插桩技术，在运行时监控文件系统路径访问调用（如 `open`, `fopen`, `access` 等），检测 TOCTOU (Time-of-Check to Time-of-Use) 竞争条件、路径遍历及符号链接攻击等不安全模式。

## 安全趋势报告

### 年美国活跃勒索病毒总结报告

**来源**：Emsisoft 官方博客

报告统计分析了 2019 年美国境内活跃的勒索软件家族、攻击目标分布（政府、医疗、教育、企业）、赎金支付情况及造成的经济损失，展示了勒索软件持续高发、定向化趋势。

### Mac 平台安全威胁增加趋势

**来源**：FreeBuf 资讯

综述指出随着 Mac 市场份额增长，针对 macOS 的恶意软件（Adware、后门、窃密木马）、利用链及 0day 漏洞显著增加，安全对抗重心逐渐向苹果生态倾斜。

## 关联页面

- 后续每日看点：[[daily-security-digest-20191219]]、[[daily-security-digest-20191220]]、[[daily-security-digest-20191223]]、[[daily-security-digest-20191224]]、[[daily-security-digest-20191225]]、[[daily-security-digest-20191226]]、[[daily-security-digest-20191227]]、[[daily-security-digest-20191230]]
- 相关 APT 组织分析：[[apt-c-08-mobile-attack-analysis]]（蔓灵花 APT-C-08 移动端攻击，后续看点中提及）
- 相关漏洞聚合：[[cve-digest-20210327]]、[[cve-digest-20210413]]、[[cve-digest-20210330]]（包含 TP-Link 等厂商后续漏洞）

## 参考链接

1.  TP-Link Archer 系列路由器漏洞分析：<https://www.freebuf.com/vuls/223076.html>
2.  比特币区块链隐藏 Pony C&C 分析：<https://www.freebuf.com/articles/blockchain-articles/221822.html>
3.  Linode 令牌窃取案例：<https://medium.com/@rootxharsh_90844/abusing-feature-to-steal-your-tokens-f15f78cebf74>
4.  Cobalt Strike 混淆绕过 Defender：<http://www.offensiveops.io/tools/cobalt-strike-bypassing-windows-defender-with-obfuscation/>
5.  SysWhispers 项目地址：<https://github.com/jthuraisamy/SysWhispers>
6.  eGain 邮件头注入 CVE-2019-17123 分析：<https://medium.com/maverislabs/cve-2019-17123-cbc946c99f8>
7.  PathAuditor 发布博客：<https://security.googleblog.com/2019/12/detecting-unsafe-path-access-patterns.html>
8.  2019 美国勒索病毒报告：<https://blog.emsisoft.com/en/34822/the-state-of-ransomware-in-the-us-report-and-statistics-2019/>
9.  Chrome CVE-2019-13686 Issue：<https://bugs.chromium.org/p/chromium/issues/detail?id=1000002>
10. Mac 安全威胁趋势：<https://www.freebuf.com/news/223121.html>

## 来源

- [0th3rs安全团队-201911-202204_111](../sources/0th3rs安全团队-201911-202204_111.md)
