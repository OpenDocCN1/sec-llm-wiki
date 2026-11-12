---
title: 每日安全看点 - 2019年11月25日
description: 2019年11月25日每日安全看点汇总，收录PowerShell反混淆工具、Flan Scan漏洞扫描器、IoT渗透工具、Peach Fuzzing实战、CobaltStrike插件、ThinkPHP扫描器、AppLocker详解、Mimblewimble隐私分析、ATT&CK及网络空间测绘等安全资讯。
category: ai-security
tags:
- 每日安全看点
- 2019年11月
- PowerShell
- 反混淆
- Flan Scan
- 漏洞扫描
- IoT渗透
- Peach Fuzzing
- CobaltStrike
- ThinkPHP
- AppLocker
- Mimblewimble
- ATT&CK
- 网络空间测绘
date: 2019-11-25
updated: '2026-11-13'
---

## 概述

本页面汇总 2019 年 11 月 25 日「每日安全看点」栏目发布的安全技术资讯，涵盖工具发布、实战教程、深度分析文章等多个维度，为安全从业者提供当日值得关注的技术动态速览。

## 工具与实用资源

### PowerShell 自动反混淆工具

Unit42 发布 PowerShell 自动反混淆工具，助力分析人员还原混淆后的 PowerShell 脚本逻辑，提升恶意脚本分析效率。

- 来源：FreeBuf 文章《Unit42发布powershell自动反混淆工具》

### Flan Scan：Cloudflare 开源轻量级网络漏洞扫描器

Cloudflare 开源的轻量级网络漏洞扫描软件 Flan Scan，基于 Nmap 封装，适合快速资产发现与漏洞评估。

- 来源：NOSEC 文章《Flan Scan：Cloudflare开源轻量级网络漏洞扫描软件》

### 面向物联网的渗透测试工具集

汇总针对 IoT 设备的渗透测试工具与技术，覆盖固件分析、协议逆向、设备指纹识别等场景。

- 来源：FreeBuf 文章《针对物联网的渗透工具》

### CobaltStrike 后渗透测试插件 —— Erebus

GitHub 项目 `DeEpinGh0st/Erebus` 提供 CobaltStrike 后渗透阶段常用功能插件，扩展团队作战能力。

- 仓库地址：<https://github.com/DeEpinGh0st/Erebus>

### Windows 常用密码提取工具 —— USBStealer

GitHub 项目 `XXH3X/USBStealer` 实现 Windows 系统常用密码（浏览器、Wi-Fi、RDP 等）的自动化提取，适用于实战后渗透凭证收集。

- 仓库地址：<https://github.com/XXH3X/USBStealer>

### ThinkPHP 一键漏洞检测工具 —— TPscan

GitHub 项目 `Lucifer1993/TPscan` 集成 ThinkPHP 系列历史漏洞检测 PoC，支持批量扫描与快速验证。

- 仓库地址：<https://github.com/Lucifer1993/TPscan>

## 技术深度文章

### 使用 Peach 结合 Web API 进行 Fuzzing 实例讲解

详细演示如何使用 Peach Fuzzer 框架对 Web API 接口进行模糊测试，涵盖 DataModel 定义、StateModel 状态机建模、Agent 部署与监控等完整流程。

- 来源：FreeBuf 文章《使用 Peach 结合 Web API 进行 Fuzzing 实例讲解》

### 详解 AppLocker（Part 1）

系统梳理 Windows AppLocker 应用控制策略的原理、配置方法、规则类型（路径、哈希、发布者）及绕过技术，为红蓝双方提供攻防参考。

- 来源：安全客文章《详解AppLocker（Part 1）》

### 打破 Mimblewimble 的隐私模型

Dragonfly Research 深度分析 Mimblewimble 协议（Grin、Beam 等隐私币底层）的隐私假设与攻击面，展示交易图谱重构与地址关联的可行性攻击。

- 来源：Medium 文章《Breaking Mimblewimble Privacy Model》

### 连连看逆向工程实战

通过经典「连连看」游戏为例，演示逆向分析思路：内存搜索、关键函数定位、Hook 拦截、自动化通关脚本编写。

- 来源：微信公众号文章《连连看逆向》

## 学习资源与社区动态

### 国内 SRC 漏洞挖掘经验与技巧分享（视频课程）

i春秋平台公开课，资深白帽子分享 SRC（安全应急响应中心）漏洞挖掘实战方法论、逻辑漏洞挖掘技巧及避坑指南。

- 课程链接：<https://www.ichunqiu.com/open/63178>

### ATT&CK 知识库与应用讨论

汇总 MITRE ATT&CK 框架最新进展、矩阵更新、导航工具及落地实践案例，助力威胁建模与检测规则编写。

- 来源：微信公众号文章《ATT&CK》

### 网络空间测绘观点与技术演进

探讨网络空间测绘（资产测绘）的核心技术体系、数据融合方法、主流平台对比（Shodan、Censys、FOFA、ZoomEye 等）及在攻击面管理中的应用。

- 来源：微信公众号文章《网络空间测绘观点》

## 关联页面

- [[daily-security-digest-20191126]] — 翌日（11月26日）安全看点，涵盖 VNC 多漏洞、Shiro Padding Oracle、Docker CVE-2019-14271 等
- [[daily-security-digest-20191127]] — 11月27日安全看点，涵盖堆利用、Chrome 沙箱逃逸、Pwn2Own WebKit 分析等
- [[0th3rs-security-team-wechat-archive-201911-202204]] — 0th3rs 安全团队微信公众号 2019年11月 至 2022年4月 文章汇总索引，含同期多篇安全研究与工具分享文章
- [[docker-container-security-fundamentals]] — Docker 容器安全核心机制系统梳理，补充容器逃逸与加固视角
- [[frp内网渗透应用]] — frp 内网穿透在渗透测试中的四大典型应用场景实战记录
- [[hvv-2021-vulnerability-collection]] — 2021 年 HVV 期间常用漏洞利用代码聚合仓库与实战复现细节

## 小结

2019年11月25日安全看点聚焦 **工具链建设**（反混淆、漏扫、IoT渗透、C2插件、凭证导出、框架扫描）、**实战技能提升**（Peach Fuzzing、AppLocker、逆向案例）、**前沿理论研究**（Mimblewimble 隐私、ATT&CK、网络空间测绘）三大维度，反映当时安全社区从「工具使用」向「原理深挖与体系化建设」转型的趋势。

## 来源

- [0th3rs安全团队-201911-202204_129](../sources/0th3rs安全团队-201911-202204_129.md)
