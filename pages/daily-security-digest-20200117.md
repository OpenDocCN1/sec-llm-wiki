---
title: 2020年1月17日每日安全看点
description: 汇总 2020 年 1 月 17 日安全动态：PHP/ASP Shell后门集合、CVE-2020-0601 (CurveBall) 漏洞分析与
  PoC、Windows 驱动漏洞研究环境 HackSysExtremeVulnerableDriver、QEMU PWN 入门教程、Chrome IPC 漏洞概述
category: ai-security
tags:
- 每日安全看点
- WebShell
- CVE-2020-0601
- Windows驱动漏洞
- QEMU PWN
- Chrome IPC
- 2020年1月
date: 2020-01-17
updated: '2026-11-12'
---

## 概述

本期每日安全看点收录 6 项安全技术资源，涵盖 WebShell 后门收集、Windows 证书验证漏洞深度分析、内核驱动漏洞实战靶场、虚拟化 PWN 入门、浏览器进程间通信漏洞研究等方向。

## 核心内容

### PHP 与 ASP Shell 后门集合

**项目地址**：[backdoorhub/shell-backdoor-list](https://github.com/backdoorhub/shell-backdoor-list)

汇总常见 PHP 与 ASP 语言编写的 WebShell 后门样本，供应急响应、威胁狩猎及特征库构建参考。包含单行木马、大马、变种混淆等多类型后门代码。

### CVE-2020-0601 (CurveBall) 漏洞分析与 PoC

**分析文章**：[Kudelski Security - CVE-2020-0601: The ChainOfFools Attack Explained with PoC](https://research.kudelskisecurity.com/2020/01/15/cve-2020-0601-the-chainoffools-attack-explained-with-poc/)

**通告更新**：[微信公众号跟进解读](https://mp.weixin.qq.com/s/gl-KGvIQ3HCbHH9kBM5enQ)

Windows CryptoAPI (crypt32.dll) 在验证 ECC 证书时未正确校验基点参数，攻击者可伪造任意代码签名证书、TLS 证书，实现恶意代码签名绕过、中间人劫持等攻击。文章详细拆解漏洞原理、数学基础及 PoC 构造过程。

### Windows 驱动漏洞研究与利用实战

**靶场项目**：[HackSysExtremeVulnerableDriver](https://github.com/hacksysteam/HackSysExtremeVulnerableDriver)

经典 Windows 内核驱动漏洞练习环境，包含栈溢出、堆溢出、UAF、类型混淆、整数溢出、未初始化内存、任意写等典型内核漏洞类型。配套提供利用模板、Shellcode 编写指南，适合内核漏洞利用入门与进阶练习。

### QEMU PWN 基础教程

**教程链接**：[微信文章 - QEMU PWN 基础](https://mp.weixin.qq.com/s/TR-JuE2nl3W7ZmufAfpBZA)

从 QEMU 架构、虚拟设备模拟机制入手，讲解虚拟机逃逸漏洞挖掘基础：设备模型注册、MMIO/DMA 处理、virtio 协议交互、常见漏洞类型（堆溢出、UAF、类型混淆）及调试环境搭建（GDB + QEMU + 内核调试）。

### Chrome IPC 漏洞概述

**研究报告**：[GitHub Security Lab - Chromium IPC Vulnerabilities](https://securitylab.github.com/research/chromium-ipc-vulnerabilities/)

系统梳理 Chrome 多进程架构下 IPC (Inter-Process Communication) 机制的攻击面：Mojo 接口定义、序列化/反序列化流程、渲染器进程与 Browser 进程的信任边界。分析历史高危 IPC 漏洞利用模式，包括类型混淆、逻辑绕过、竞争条件等，并提供变异 Fuzzing 思路。

## 关联阅读

- [[daily-security-digest-20200120]] — 同日系列后续期，涵盖 IE 0day CVE-2020-0674、Hacker101 教程、Linux 内核 CFI 等内容
- [[daily-security-digest-20200121]] — SRC 挖掘经验、中间件漏洞检测、WAF 绕过技巧
- [[daily-security-digest-20200122]] — Project Zero 披露 CVE-2019-6250 修复绕过、恶意软件逆向教程、Fuzzing 发展史
- [[cve-digest-20200426]] — 2020 年 4 月 CVE 聚合，含 Windows 提权 CVE-2020-1054、Chrome V8 堆溢出等漏洞详情

## 来源

- [0th3rs安全团队-201911-202204_093](../sources/0th3rs安全团队-201911-202204_093.md)
