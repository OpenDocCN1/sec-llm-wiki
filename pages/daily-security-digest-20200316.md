---
title: 每日安全看点 2020-03-16
description: 汇总 2020 年 3 月 16 日每日安全看点，涵盖 Linux 内核动态调试、NETGEAR RCE、终端安全运营、V8 利用入门、SSH
  客户端蠕虫、fastjson Shiro-core gadget、CVE-2020-0796 分析等安全资讯
category: ai-security
tags:
- 每日安全看点
- Linux内核
- 动态调试
- NETGEAR
- RCE
- 终端安全
- V8引擎
- 浏览器利用
- SSH蠕虫
- fastjson
- Shiro
- 反序列化
- CVE-2020-0796
- SMBGhost
- 2020年3月
date: '2020-03-16'
updated: '2026-11-12'
---

## 概述

本页面汇总 2020 年 3 月 16 日发布的每日安全看点，涵盖内核调试技术、路由器漏洞分析、终端安全运营实践、浏览器引擎利用入门、蠕虫恶意代码分析、反序列化利用链挖掘以及高危 SMB 漏洞深度分析等多个安全领域的技术文章。

## 核心内容

### Linux 内核动态调试手段

**来源**：[Linux内核常用的动态调试手段](https://mp.weixin.qq.com/s?__biz=MzI3NzA5MzUxNA==&mid=2664607260&idx=1&sn=76025afa61c40a939fc7ed053377f7f9&scene=21#wechat_redirect)

系统梳理 Linux 内核开发与安全研究中常用的动态调试技术，为内核漏洞挖掘、利用开发及根因分析提供工具链参考。

### NETGEAR 远程代码执行漏洞分析

**来源**：[NETGEAR 远程代码执行漏洞分析](https://mp.weixin.qq.com/s?__biz=MzI5MDQ2NjExOQ==&mid=2247492417&idx=1&sn=13b05a2ce8f9cdc15e87ce002f6ff790&scene=21#wechat_redirect)

深度分析 NETGEAR 路由器产品中的远程代码执行漏洞成因、触发条件及利用方式，属于 IoT 设备安全研究范畴。后续在 [[cve-digest-20210330]] 中亦有 NETGEAR 相关漏洞跟进。

### 终端安全运营年度笔记

**来源**：[终端安全运营年度笔记](https://mp.weixin.qq.com/s?__biz=MzI2MjQ1NTA4MA==&mid=2247485019&idx=1&sn=afa508ddba050837ca6ebbdd3c380e6e&scene=21#wechat_redirect)

从实战运营视角总结终端安全建设的年度经验，涵盖资产梳理、基线核查、威胁检测、应急响应等运营体系构建思路。

### V8 利用入门：从越界到 RCE

**来源**：[V8 利用入门：从越界到 RCE](https://paper.seebug.org/1145/)

Seebug Paper 系列教程，循序渐进讲解 V8 引擎漏洞利用核心技术：从越界访问（OOB）原理出发，逐步构建任意读写原语，最终实现远程代码执行（RCE）。适合浏览器安全入门研究者。

### SSH 客户端蠕虫

**来源**：[TEA: SSH Client Worm](http://amp.kitploit.com/2020/03/tea-ssh-client-worm.html?amp=0)

分析一款名为 TEA 的 SSH 客户端蠕虫恶意代码，其通过窃取 SSH 私钥/凭证在内网横向移动，展示了凭证复用攻击在蠕虫传播中的实战应用。

### fastjson 反序列化漏洞最新 Gadget：Shiro-core

**来源**：[fastjson反序列化漏洞最新gadget-shiro-core](https://mp.weixin.qq.com/s?__biz=MzA4NjQxMDcxNA==&mid=2709352858&idx=1&sn=bdb3b316714f2451e99413f85b06a647&scene=21#wechat_redirect)

披露 fastjson 反序列化利用链新 Gadget —— Shiro-core 组件，补充了 Java 反序列化攻击面。相关 Java 反序列化基础机制可参考 [[java-deserialization-fundamentals]]。

### CVE-2020-0796 技术分析（SMBGhost）

**来源**：[CVE-2020-0796 技术分析](http://blogs.360.cn/post/CVE-2020-0796.html)

360 安全团队对 SMBv3 协议栈压缩处理整数溢出漏洞（CVE-2020-0796，又称 SMBGhost）的深度技术分析，涵盖漏洞原理、触发路径、利用可行性评估及缓解建议。该漏洞为 WannaCry 级别的可蠕虫传播高危漏洞，影响 Windows 10 1903/1909 及 Server 1903/1909。

## 关联页面

- [[daily-security-digest-20200317]] — 次日安全看点，涵盖 CVE-2020-0768、苹果隐私泄漏、VSCode RCE 等
- [[daily-security-digest-20200318]] — 后续安全看点，含 fastjson-ShiroCore 反序列化复现、Weblogic CVE-2020-2555 等
- [[java-deserialization-fundamentals]] — Java 序列化/反序列化核心机制基础，支撑 fastjson/Shiro 利用链分析
- [[cve-digest-20210330]] — 2021 年 NETGEAR 等厂商漏洞聚合，可作横向对比
- [[spring-boot-devtools-deserialization-rce]] — Spring Boot DevTools 反序列化 RCE 利用链实战
- [[h2-console-jndi注入rce利用]] — H2 Database JNDI 注入 RCE 利用链实战

## 时间线上下文

| 日期 | 页面 | 核心关注 |
|------|------|----------|
| 2020-03-16 | **本页面** | Linux内核调试、NETGEAR RCE、V8利用、SSH蠕虫、fastjson Shiro-core、CVE-2020-0796 |
| 2020-03-17 | [[daily-security-digest-20200317]] | CVE-2020-0768 ChakraCore、苹果剪贴板隐私、VSCode RCE |
| 2020-03-18 | [[daily-security-digest-20200318]] | Win10 Exp合集、ATT&CK欺骗防御、fastjson-ShiroCore复现、Weblogic CVE-2020-2555 |

## 参考资源汇总

| 类别 | 标题 | 链接 |
|------|------|------|
| 内核技术 | Linux内核常用的动态调试手段 | https://mp.weixin.qq.com/s/mflepEtoemR6aM8lQwGOMw |
| 漏洞分析 | NETGEAR 远程代码执行漏洞分析 | https://mp.weixin.qq.com/s/QUrErOgaUcQVhQz5fGhc_w |
| 运营实践 | 终端安全运营年度笔记 | https://mp.weixin.qq.com/s/cHYu7Ayni5mkjWpn6_XrwA |
| 浏览器安全 | V8 利用入门：从越界到 RCE | https://paper.seebug.org/1145/ |
| 恶意代码 | TEA: SSH Client Worm | http://amp.kitploit.com/2020/03/tea-ssh-client-worm.html |
| 反序列化 | fastjson反序列化漏洞最新gadget-shiro-core | https://mp.weixin.qq.com/s/O90M916ksZ_Jld9qtr9_-A |
| 高危漏洞 | CVE-2020-0796 技术分析 | http://blogs.360.cn/post/CVE-2020-0796.html |

## 来源

- [0th3rs安全团队-201911-202204_064](../sources/0th3rs安全团队-201911-202204_064.md)
