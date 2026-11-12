---
title: 每日安全看点 2019-11-29
description: 2019年11月29日每日安全看点汇总，涵盖Facebook XSS账户接管、Frida绕过SSL Pinning、小米Mi6浏览器RCE、PHP
  0day攻破Pornhub等安全资讯。
category: ai-security
tags:
- 每日安全看点
- 2019年11月
- XSS
- 账户接管
- Frida
- SSL Pinning
- Android安全
- 小米
- RCE
- PHP 0day
- Pornhub
- 漏洞赏金
- CTF
- Fuzzing
- 恶意软件分析
- Web渗透
date: '2019-11-29'
updated: '2026-11-13'
---

## 概述

本页面汇总 2019 年 11 月 29 日发布的每日安全看点，涵盖 Web 安全、移动端安全、漏洞分析、CTF 技术、恶意软件分析及渗透测试工具等多个方向的技术资讯。

## 主要安全资讯

### Facebook graph.facebook.com XSS 导致 IE/Edge 账户接管

- **链接**：<https://ysamm.com/?p=343>
- **要点**：graph.facebook.com 存在跨站脚本漏洞（XSS），攻击者可利用该漏洞在 Internet Explorer 和 Edge 浏览器上实现用户账户接管。
- **关联**：[[daily-security-digest-20191202]]、[[daily-security-digest-20191203]] 等后续每日看点中亦多次出现 XSS 与账户接管相关技术分享。

### 使用 Frida 绕过 Android App 的 SSL Pinning

- **链接**：<https://www.freebuf.com/articles/terminal/214540.html>
- **要点**：介绍如何利用 Frida 动态插桩框架绕过 Android 应用的 SSL Pinning（证书绑定）保护，便于中间人代理（MITM）抓包分析加密流量。
- **关联**：移动端安全专题可参考 [[apt-c-08-mobile-attack-analysis]] 中的恶意样本动态分析技术；Frida 亦常用于 [[wechat-pc-v8-rce-0day-analysis]] 等客户端漏洞调试。

### 恶意软件分析资源集合

- **链接**：<https://malwareanalysis.co/>
- **要点**：整理了恶意软件分析相关的工具、论文、博客、沙箱等资源导航站，适合逆向工程与威胁情报研究人员查阅。
- **关联**：后续每日看点如 [[daily-security-digest-20191205]]、[[daily-security-digest-20200212]] 均持续推荐恶意软件分析教程与公开课。

### 小米 Mi6 浏览器 RCE 漏洞

- **链接**：<https://labs.f-secure.com/advisories/xiaomi/>
- **要点**：F-Secure 实验室披露小米 Mi6 预置浏览器存在远程代码执行漏洞，攻击者可通过恶意网页触发 RCE。
- **关联**：IoT/移动端漏洞挖掘可参考 [[daily-security-digest-20191204]] 中的 IoT 逆向与 U-Boot 分析、[[daily-security-digest-20200114]] 小米路由器漏洞 POC。

### CTF：通过 Fuzzing 找到漏洞点并进一步分析

- **链接**：<http://matshao.com/2019/11/11/Redhat2019-Kaleidoscope/>
- **要点**：记录 RedHat 2019 CTF 题目 Kaleidoscope 的解题过程，展示如何利用 Fuzzing 发现漏洞点并深入分析利用。
- **关联**：Fuzzing 专题可参考 [[daily-security-digest-20191202]]、[[daily-security-digest-20200302]]、[[daily-security-digest-20200306]] 等多期看点中的 AFL++、持续 Fuzzing 等内容。

### OWASP Android Uncrackable 1~3 练习

- **链接**：<https://xz.aliyun.com/t/6819>
- **要点**：详细演示 OWASP MSTG 推荐的 Android Uncrackable 系列三个 Crackme 练习的逆向破解过程，涵盖反调试绕过、Root 检测绕过、代码混淆分析等技巧。
- **关联**：Android 逆向入门可结合 [[daily-security-digest-20200214]] GDA 工具、[[daily-security-digest-20191211]] iOS 内核漏洞分析等跨平台逆向资料。

### Web 渗透字典项目推荐

- **链接**：<https://github.com/TheKingOfDuck/fuzzDicts>
- **要点**：开源 Web 渗透测试常用字典集合，包含目录扫描、参数 Fuzzing、密码爆破等多场景词表。
- **关联**：字典构建工具 [[daily-security-digest-20191204]] 提及 pydictor；实战中常配合 [[frp内网渗透应用]] 等内网穿透工具使用。

### Web 应用指纹识别

- **链接**：<http://www.blogsir.com.cn/safe/681.html>
- **要点**：介绍 Web 应用指纹识别的原理、常用工具（WhatWeb、Wappalyzer 等）及自定义指纹编写方法，用于资产梳理与攻击面收敛。
- **关联**：资产测绘专题可参考 [[daily-security-digest-20191206]] 网络空间测绘、[[secquan-bugwarning-1071987-device-credential-leak]] Fofa 语法搜索。

### 利用 PHP 0day 攻破 Pornhub 获得 2 万美元赏金

- **链接**：<https://www.secpulse.com/archives/119239.html>
- **要点**：作者详细复现发现 PHP 核心组件的 0day 漏洞（GC 机制导致的 UAF），结合 Pornhub 业务逻辑实现远程代码执行，最终获得 20,000 美元漏洞赏金。
- **关联**：PHP 反序列化/GC 利用链可参考 [[diwuzhijian-2020-web-writeup]] 中 PHP 反序列化 POP 链构造、[[cmseasy-7.3.8-code-audit]] 代码审计实战。

### 漏洞检测的那些事儿

- **链接**：<https://blog.knownsec.com/2016/06/how-to-scan-and-check-vulnerabilities/>
- **要点**：知道创宇早期博文，系统阐述漏洞扫描与检测的方法论，涵盖主动扫描、被动检测、漏洞验证、误报处理等工程化实践。
- **关联**：后续 [[cve-digest-20200426]]、[[cve-digest-20210325]] 等 CVE 聚合页面均体现漏洞情报收集与 PoC 复现的标准化流程。

## 横向关联：同期每日安全看点

- [[daily-security-digest-20191202]]（12 月 2 日）
- [[daily-security-digest-20191203]]（12 月 3 日）
- [[daily-security-digest-20191204]]（12 月 4 日）
- [[daily-security-digest-20191205]]（12 月 5 日）
- [[daily-security-digest-20191206]]（12 月 6 日）

以上页面均属 2019 年 12 月同系列每日看点，技术主题延续性强，建议配合阅读。

## 来源

- [0th3rs安全团队-201911-202204_124](../sources/0th3rs安全团队-201911-202204_124.md)
