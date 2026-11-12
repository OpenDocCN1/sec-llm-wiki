---
title: 每日安全看点 2020-01-20
description: 汇总 2020 年 1 月 20 日安全动态：浏览器利用资料库、IE 0day CVE-2020-0674、Hacker101 教程、2019
  威胁情报 Top20、Linux 内核 CFI、Fuzzing 平台建设、免杀技术学习路线
category: ai-security
tags:
- 每日安全看点
- 浏览器安全
- IE漏洞
- CVE-2020-0674
- Hacker101
- 威胁情报
- Linux内核
- CFI
- Fuzzing
- 免杀技术
- 2020年1月
date: 2020-01-20
updated: '2026-11-12'
---

## 概述

本期每日安全看点汇总了 2020 年 1 月 20 日的七条安全技术动态，涵盖浏览器利用资料整理、IE 浏览器 0day 漏洞预警、白帽黑客入门教程、年度威胁情报热点回顾、Linux 内核控制流完整性技术、Fuzzing 平台工程化建设以及免杀技术系统学习路线。

## 浏览器利用资料库

**browser-pwn** 是一个聚焦浏览器漏洞利用技术的开源资料仓库，收录了主流浏览器引擎（V8、SpiderMonkey、JavaScriptCore、Chakra 等）的漏洞分析、利用技巧、调试工具及相关会议演讲资料。

- **项目地址**：https://github.com/m1ghtym0/browser-pwn
- **适用场景**：浏览器安全研究入门、漏洞利用技术对标、CTF 浏览器题目备战
- **关联阅读**：[[daily-security-digest-20200316]] 中涵盖 V8 引擎利用入门资料；[[wechat-pc-v8-rce-0day-analysis]] 实战复现微信内嵌 Chromium V8 0day 攻击链

## IE 浏览器 0day：CVE-2020-0674

微软 Internet Explorer 存在脚本引擎内存破坏漏洞 **CVE-2020-0674**，攻击者可通过诱导用户访问恶意网页触发远程代码执行。该漏洞在披露时已被在野利用，属于典型的「0day」攻击面。

- **Reddit 讨论**：https://www.reddit.com/r/blueteamsec/comments/equ1hq/cve20200674_microsoft_internet_explorer_0day/
- **影响版本**：IE 9/10/11（Windows 7/8.1/10 及 Server 对应版本）
- **缓解建议**：启用「增强保护模式」、限制脚本引擎、部署微软官方缓解补丁（KB4534251 等）、尽快迁移至 Edge/Chrome
- **关联阅读**：[[daily-security-digest-20200317]] 分析 ChakraCore 另一 IE 漏洞 CVE-2020-0768；[[cve-digest-20200426]] 汇总 Chrome V8 堆溢出 CVE-2018-6065 等浏览器漏洞

## Hacker101：白帽黑客进阶教程

**Hacker101** 由 HackerOne 出品，面向零基础到进阶的 Web 安全系统化教程，涵盖 XSS、SQLi、CSRF、SSRF、认证绕过、业务逻辑漏洞等核心模块，配套可交互的练习靶场。

- **免费翻译版**：https://www.freebuf.com/video/225882.html
- **官方站点**：https://www.hacker101.com/
- **学习建议**：按章节完成视频+靶场实战，配合《Web 安全开发指南》夯实理论基础
- **关联阅读**：[[daily-security-digest-20200211]] 推荐 JavaScript 原型链污染分析、RSA 2020 创新沙盒等进阶资源

## 年威胁情报领域议题 Top-20

威胁情报社区 **ThreatIntel.eu** 复盘 2019 年最受关注的 20 个 CTI（Cyber Threat Intelligence）议题，涵盖 APT 组织画像、勒索软件演进、供应链攻击、威胁狩猎方法论、ATT&CK 落地实践等。

- **原文地址**：https://threatintel.eu/2020/01/09/top-20-cti-presos-for-2019/
- **核心看点**：
  - APT41/APT29 等高级持续威胁组织 TTPs 深度剖析
  - 勒索即服务（RaaS）生态与赎金支付决策模型
  - 软件供应链攻击（如 SolarWinds 前身案例）检测思路
  - 基于 ATT&CK 的紫队演练与检测规则工程化
- **关联阅读**：[[daily-security-digest-20200218]] 收录奇安信 APT 2019 年度报告；[[daily-security-digest-20200217]] 分析 Darkhotel APT 双 0day 攻击

## Linux 内核控制流完整性

来自 Linux Conf Australia 2020 的演讲幻灯片，系统阐述 **Linux 内核 CFI（Control Flow Integrity）** 的设计原理、实现现状（Clang CFI、KCFI、eBPF CFI）、部署挑战及性能开销权衡。

- **幻灯片下载**：https://outflux.net/slides/2020/lca/cfi.pdf
- **关键技术点**：
  - 间接调用/跳转目标合法性验证（前向边缘 CFI）
  - 返回地址保护（后向边缘 CFI，配合 Shadow Stack/CET）
  - 内核模块、eBPF JIT、ftrace 等动态代码场景的 CFI 适配
- **关联阅读**：[[daily-security-digest-20200316]] 涉及 Linux 内核动态调试技术；[[daily-security-digest-20200226]] 覆盖 Linux 内核栈溢出利用技术

## Fuzzing 平台建设的研究与设计

腾讯安全团队分享 **Fuzzing 平台工程化建设** 的架构设计与实践经验，覆盖种子管理、任务调度、覆盖率收集、崩溃去重分级、漏洞挖掘闭环自动化等核心模块。

- **文章地址**：https://security.tencent.com/index.php/blog/msg/143
- **架构亮点**：
  - 多引擎融合（AFL++、LibFuzzer、Honggfuzz、QSYM 等）
  - 分布式扩展：Kubernetes + 自定义 Operator 管理 Fuzzing Job
  - 种子进化策略：结构感知变弭 + 语法约束 + 种子池动态裁剪
  - 崩溃分析管线：ASAN/MSAN/TSAN 三重编译 + 根因定向分型
- **关联阅读**：[[daily-security-digest-20200302]] 推荐持续 Fuzzing 实践与 vfuzz 学习资源；[[daily-security-digest-20200306]] 实战 AFL++ Fuzzing Vim；[[daily-security-digest-20200212]] 回顾 Fuzzing 技术 30 年演进

## 免杀技术学习路线

系统梳理 **免杀技术（Anti-AV/EDR 绕过）** 的知识体系与进阶路径，适合红队工程化能力建设参考。

- **学习路线图**：https://mp.weixin.qq.com/s/ru9Y7j50wzEqGRj94bs4qA
- **核心模块**：
  1. **基础原理**：静态特征匹配、动态行为监控、内存扫描、云查杀机制
  2. **Shellcode 免杀**：编码器、加密器、多态/变形引擎、Donut/SharpShooter 等加载器
  3. **C2 流量隐匿**：域前置、CDN 隐匿、TLS 指纹伪造、DNS/HTTP/WS 协议隧道
  4. **进程注入与内存操作**：经典注入、APC/线程劫持、PPID 欺骗、模块踩踏、syscall 直接调用
  5. **EDR 规避**：ETW 绕过、AMSI 绕过、事件日志篡改、内核回调清理、EDR 传感器卸载
  6. **工程化落地**：Cobalt Strike BOF/UDRL、Sliver/C3/Brute Ratel 等框架二次开发
- **关联阅读**：[[daily-security-digest-20200213]] 涵盖 CS Shellcode 免杀与 WAF 绕过；[[daily-security-digest-20200214]] 介绍免杀工具综合评估；[[wechat-pc-v8-rce-0day-analysis]] 实战 Cobalt Strike 结合 0day 实现内网横向

## 关联每日安全看点

- [[daily-security-digest-20200121]] —— 1月21日：SRC挖掘经验库、中间件漏洞检测、360webscan WAF绕过
- [[daily-security-digest-20200122]] —— 1月22日：CVE-2019-6250修复绕过、恶意软件逆向教程、Fuzzing 30年演进
- [[daily-security-digest-20200210]] —— 2月10日：ATT&CK渗透手册、智能合约审计、ysoserial C3P0利用链、疫情远程办公安全
- [[daily-security-digest-20200302]] —— 3月2日：持续Fuzzing、SRC逻辑漏洞、XSS Payload、Linux内核XFRM UAF PoC

## 来源

- [0th3rs安全团队-201911-202204_091](../sources/0th3rs安全团队-201911-202204_091.md)
