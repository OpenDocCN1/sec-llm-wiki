---
title: 每日安全看点 2020-03-02
description: 汇总 2020 年 3 月 2 日每日安全看点，涵盖持续 Fuzzing、SRC 逻辑漏洞挖掘、XSS Payload 集合、Android
  混淆工具、ThinkPHP5 漏洞分析、CORS 配置检测、Web 源码泄漏利用、Python 格式化字符串、Linux 内核 XFRM UAF PoC 及 Web
  隐私测量框架等内容。
category: ai-security
tags:
- 每日安全看点
- Fuzzing
- SRC
- XSS
- Android安全
- ThinkPHP
- CORS
- 源码泄漏
- Python
- Linux内核
- 隐私测量
- 2020年3月
date: '2020-03-02'
updated: '2026-11-12'
---

## 概览

本期每日安全看点收录了 2020 年 3 月 2 日发布的多篇安全技术文章与工具资源，涵盖 **DevSecOps 持续 Fuzzing**、**SRC 逻辑漏洞挖掘**、**XSS Payload 实战集合**、**Android 代码混淆工具**、**ThinkPHP5 版本漏洞深度分析**、**CORS 配置错误检测**、**Web 源码泄漏利用**、**Python 格式化字符串安全**、**Linux 内核 XFRM UAF 提权 PoC** 以及 **Mozilla OpenWPM Web 隐私测量框架** 等主题。

---

## 主要内容

### 持续 Fuzzing 在 DevSecOps 中的应用
- **来源**：微信公众号文章
- **链接**：[https://mp.weixin.qq.com/s/IzxaRuNKhxbycguXOsoeNw](https://mp.weixin.qq.com/s?__biz=MzU0MzgzNTU0Mw==&mid=2247484124&idx=1&sn=428b365ca517bb7d32d58ccb19b3d87e&scene=21#wechat_redirect)
- **要点**：探讨如何在 DevSecOps 流水线中集成持续模糊测试，实现代码提交、构建、部署各阶段的自动化漏洞发现与回归验证。

### 【挖洞技巧】逻辑漏洞小结之 SRC 篇
- **来源**：FreeBuf
- **链接**：[https://www.freebuf.com/articles/web/225770.html](https://www.freebuf.com/articles/web/225770.html)
- **要点**：总结 SRC（安全应急响应中心）漏洞挖掘中常见的逻辑漏洞类型、挖掘思路及实战案例，涉及权限绕过、业务流程滥用、状态机缺陷等。

### 【收集】2020 年仍然有效的 XSS Payload
- **来源**：FreeBuf
- **链接**：[https://www.freebuf.com/articles/web/226719.html](https://www.freebuf.com/articles/web/226719.html)
- **要点**：整理 2020 年实测有效的跨站脚本攻击 Payload 集合，覆盖反射型、存储型、DOM 型 XSS 及各类 WAF 绕过技巧，适合渗透测试与漏洞验证参考。

### Obfuscapk：Android 混淆工具
- **来源**：FreeBuf
- **链接**：[https://www.freebuf.com/sectool/226391.html](https://www.freebuf.com/sectool/226391.html)
- **要点**：介绍开源工具 **Obfuscapk**，支持对 APK 进行字符串加密、类/方法重命名、控制流混淆、垃圾代码插入等多层次混淆，提升逆向分析难度。

### ThinkPHP5 各个版本漏洞详细分析
- **来源**：博客园
- **链接**：[https://www.cnblogs.com/nongchaoer/p/12029478.html](https://www.cnblogs.com/nongchaoer/p/12029478.html)
- **要点**：系统梳理 ThinkPHP 5.0.x 与 5.1.x 系列的历史漏洞，包括反序列化 RCE、SQL 注入、任意文件操作等，附带漏洞触发条件、代码级分析与修复建议。

### CORS 错误配置识别工具 —— CORScanner
- **来源**：GitHub
- **链接**：[https://github.com/chenjj/CORScanner](https://github.com/chenjj/CORScanner)
- **要点**：自动化扫描工具，检测目标站点的跨域资源共享 (CORS) 配置错误，识别 `Access-Control-Allow-Origin` 过度放宽、凭证泄露、预检请求缺失等风险。

### 常见的 Web 源码泄漏漏洞及其利用
- **来源**：微信公众号文章
- **链接**：[https://mp.weixin.qq.com/s/2sjGHIiLICxHl91xIqdXfg](https://mp.weixin.qq.com/s?__biz=MzA3NzE2MjgwMg==&mid=2448904933&idx=1&sn=ca7c99074ca9dc190e245a40895941e4&scene=21#wechat_redirect)
- **要点**：归纳 `.git`、`.svn`、`.DS_Store`、备份文件、编辑器临时文件等常见源码泄漏向量，演示如何通过泄漏源码进一步挖掘业务逻辑漏洞与敏感信息。

### Python 格式化字符串研究
- **来源**：微信公众号文章
- **链接**：[https://mp.weixin.qq.com/s/Ww1QviZyYxnNbIil_0BW2Q](https://mp.weixin.qq.com/s?__biz=MjM5MTYxNjQxOA==&mid=2652853801&idx=1&sn=fd37e270154a5a1c1cea2cdba078f2da&scene=21#wechat_redirect)
- **要点**：深入分析 Python `str.format()`、`%` 操作符、f-string 等格式化机制的安全隐患，演示格式化字符串注入导致的信息泄露、任意代码执行与拒绝服务场景。

### IEEE 2020 年 12 大技术趋势排行榜
- **来源**：头条文章
- **链接**：[https://www.toutiao.com/i6797474144087704071/](https://www.toutiao.com/i6797474144087704071/?tt_from=weixin_moments&utm_campaign=client_share&wxshare_count=2&from=timeline&timestamp=1582853009&app=news_article&utm_source=weixin_moments&isappinstalled=0&utm_medium=toutiao_ios&req_id=202002280923290100200470122762089B&group_id=6797474144087704071&pbid=6764235809942291976)
- **要点**：IEEE 发布 2020 年度技术趋势前 12 位，涵盖 AI、5G、边缘计算、量子计算、网络安全、区块链等方向，供安全从业者把握技术演进脉络。

### Linux Kernel XFRM UAF PoC (3.x - 5.x kernels)
- **来源**：博客 & GitHub
- **链接**：
  - [https://duasynt.com/blog/ubuntu-centos-redhat-privesc](https://duasynt.com/blog/ubuntu-centos-redhat-privesc)
  - [https://github.com/duasynt/xfrm_poc](https://github.com/duasynt/xfrm_poc)
- **要点**：公开 Linux 内核 XFRM 子系统 Use-After-Free 漏洞利用代码，影响 3.x 至 5.x 广泛内核版本，可在 Ubuntu、CentOS、RHEL 等主流发行版上实现本地提权。

### Web 隐私测量框架 —— OpenWPM
- **来源**：GitHub (Mozilla)
- **链接**：[https://github.com/mozilla/OpenWPM](https://github.com/mozilla/OpenWPM)
- **要点**：Mozilla 开源的大规模 Web 隐私测量平台，基于 Firefox 自动化采集 Cookie、指纹追踪、第三方请求、CSP 策略等隐私相关数据，支持学术研究与合规审计。

---

## 关联页面

- [[daily-security-digest-20200303]] — 2020-03-03 每日安全看点
- [[daily-security-digest-20200304]] — 2020-03-04 每日安全看点
- [[daily-security-digest-20200306]] — 2020-03-06 每日安全看点
- [[daily-security-digest-20200309]] — 2020-03-09 每日安全看点
- [[daily-security-digest-20200311]] — 2020-03-11 每日安全看点
- [[daily-security-digest-20200312]] — 2020-03-12 每日安全看点
- [[daily-security-digest-20200316]] — 2020-03-16 每日安全看点
- [[daily-security-digest-20200317]] — 2020-03-17 每日安全看点
- [[daily-security-digest-20200318]] — 2020-03-18 每日安全看点

---

## 标签索引

`#每日安全看点` `#Fuzzing` `#SRC` `#XSS` `#Android安全` `#ThinkPHP` `#CORS` `#源码泄漏` `#Python` `#Linux内核` `#隐私测量` `#2020年3月`

## 来源

- [0th3rs安全团队-201911-202204_071](../sources/0th3rs安全团队-201911-202204_071.md)
