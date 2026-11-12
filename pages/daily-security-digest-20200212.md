---
title: 每日安全看点 2020-02-12
description: 汇总 2020 年 2 月 12 日每日安全看点，涵盖机器学习对抗规则生成、Darkhotel APT 双 0day 攻击分析、Windows
  Defender 驱动剖析、Chrome 运行原理与漏洞分析、Docker Registry 代码泄露、前端加密绕过、JSONP 挖掘、Blind SSRF 利用及
  Facebook BountyCon CTF Writeup 等内容。
category: ai-security
tags:
- 每日安全看点
- 机器学习
- 对抗样本
- Darkhotel
- APT
- 0day
- Windows Defender
- 驱动分析
- Chrome
- 浏览器安全
- Docker Registry
- 代码泄露
- 前端加密
- JSONP
- Blind SSRF
- CTF Writeup
- Facebook BountyCon
date: '2020-02-12'
updated: '2026-11-12'
---

## 机器学习对抗规则生成

### 从 hihttps 谈机器学习之生成对抗规则过程

探讨如何利用机器学习技术生成对抗规则，绕过安全检测系统。文章详细分析了对抗样本生成的原理与实战应用，为 AI 安全攻防提供了理论基础。

**来源**：[secpulse.com](https://www.secpulse.com/archives/122490.html)

---

## APT 攻击分析

### Darkhotel（APT-C-06）使用“双星”0Day 漏洞针对中国发起的 APT 攻击分析

深度剖析 Darkhotel APT 组织（APT-C-06）利用两个 0day 漏洞（CVE-2019-17026、CVE-2020-0674）对中国目标发起的定向攻击活动。文章包含漏洞利用链复现、攻击基础设施关联分析及归因证据。

**涉及漏洞**：
- **CVE-2019-17026** - Firefox 类型混淆漏洞
- **CVE-2020-0674** - Internet Explorer 脚本引擎内存破坏漏洞

**来源**：[360 安全大脑](http://blogs.360.cn/post/apt-c-06_0day.html)

---

## Windows 内核安全

### 剖析 Windows Defender 驱动

系列文章深入分析 Windows Defender 核心驱动 `WdFilter.sys` 的内部实现，涵盖文件系统过滤架构、回调机制、扫描逻辑及规则匹配引擎。为理解杀毒软件内核防护机制、研究绕过技术提供详尽参考。

**来源**：[n4r1b.netlify.com](https://n4r1b.netlify.com/posts/2020/01/dissecting-the-windows-defender-driver-wdfilter-part-1/)

---

## Chrome 浏览器安全

### Chrome University：了解 Chrome 的运行原理

Google 官方发布的 Chrome 内部培训视频系列，系统讲解 Chrome 多进程架构、渲染管线、V8 引擎、网络栈、安全模型等核心组件原理。是浏览器安全研究者的必看入门资料。

**来源**：[YouTube Playlist](https://www.youtube.com/playlist?list=PLNYkxOF6rcICgS7eFJrGDhMBwWtdTgzpx)

### 深入研究 Chrome 的一个 Bug（Google Project Zero 系列）

Project Zero 团队详细记录一个 Chrome 漏洞从发现、分析、利用到修复的完整生命周期。两篇文章分别覆盖漏洞根因分析（Part 1）与利用链构造细节（Part 2），展示顶级漏洞研究方法论。

**来源**：
- [Part 1](https://googleprojectzero.blogspot.com/2020/02/several-months-in-life-of-part1.html)
- [Part 2](https://googleprojectzero.blogspot.com/2020/02/several-months-in-life-of-part2.html)

---

## 容器安全

### 【翻译】Docker Registry 代码泄露报告

分析 Docker Registry 暴露 `.git` 目录导致源代码泄露的事件，梳理泄露路径、敏感信息范围（配置、密钥、内部 API 设计）及修复建议。强调容器镜像仓库配置不当带来的供应链安全风险。

**来源**：[安全客](https://www.anquanke.com/post/id/198483)

---

## Web 前端安全

### 【渗透测试】突破前端加密方法总结

系统总结渗透测试中绕过前端加密的常见技巧：逆向分析 JS 加密逻辑、Hook 关键函数动态获取密钥、利用调试器绕过反调试、重写加密库实现自动化解密、结合无头浏览器批量处理等实战方法论。

**来源**：[阿里云先知](https://xz.aliyun.com/t/7190)

### 【工具】Burpsuite JSONP 挖掘插件

开源 Burp Suite 扩展插件，自动化检测 JSONP 接口、回调函数名可控、敏感信息泄露等问题。支持主动扫描与被动分析两种模式，提升 JSONP 漏洞挖掘效率。

**项目地址**：[GitHub - p1g3/JSONP-Hunter](https://github.com/p1g3/JSONP-Hunter)

---

## SSRF 漏洞利用

### 【文章】Blind SSRF 挖掘

深入讲解盲打 SSRF（Blind SSRF）的检测与利用技术：利用 DNS 回连、HTTP 回连、时间盲注、云元数据服务探测、内网端口扫描等手法验证漏洞存在性，并结合绕过 WAF、利用重定向、协议封装等技巧实现数据外带。

**来源**：[Wallarm Lab](https://lab.wallarm.com/blind-ssrf-exploitation/)

---

## CTF 竞赛题解

### 【题解】Facebook BountyCon 2020 CTF Writeup

详细记录 Facebook BountyCon 2020 CTF 竞赛多道题目的解题过程，涵盖 Web、Crypto、Reverse、Pwn 等类别。展示漏洞挖掘思路、利用链构造、Flag 获取全过程，适合 CTF 选手与漏洞研究者学习参考。

**来源**：[shoebpatel.com](https://blog.shoebpatel.com/2020/01/31/Facebooks-BountyCon-2020-CTF-Writeup/)

---

## 相关页面

- [[daily-security-digest-20200213]] - 2020-02-13 每日安全看点
- [[daily-security-digest-20200214]] - 2020-02-14 每日安全看点
- [[daily-security-digest-20200217]] - 2020-02-17 每日安全看点
- [[daily-security-digest-20200218]] - 2020-02-18 每日安全看点
- [[daily-security-digest-20200220]] - 2020-02-20 每日安全看点
- [[daily-security-digest-20200221]] - 2020-02-21 每日安全看点
- [[daily-security-digest-20200224]] - 2020-02-24 每日安全看点
- [[daily-security-digest-20200225]] - 2020-02-25 每日安全看点
- [[daily-security-digest-20200226]] - 2020-02-26 每日安全看点（含 Windows Defender 驱动分析补充）
- [[daily-security-digest-20200227]] - 2020-02-27 每日安全看点
- [[docker-container-security-fundamentals]] - Docker 容器安全基础架构

## 来源

- [0th3rs安全团队-201911-202204_083](../sources/0th3rs安全团队-201911-202204_083.md)
