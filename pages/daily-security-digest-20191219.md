---
title: 每日安全看点 2019-12-19
description: 2019年12月19日每日安全看点汇总，涵盖区块链智能合约逆向分析、儿童GPS手表隐私泄露事件、2018-2019年漏洞合集、DLL镂空技术详解、网站镜像复制技巧等安全资讯。
category: ai-security
tags:
- 每日安全看点
- 区块链安全
- 智能合约逆向
- IoT隐私
- 儿童GPS手表
- 漏洞合集
- DLL镂空
- Phantom DLL Hollowing
- 网站镜像
- 2019年12月
date: 2019-12-19
updated: '2026-11-12'
---

## 概述

本期每日安全看点汇总了 2019 年 12 月 19 日的五条核心安全资讯，涉及区块链智能合约逆向工程入门、儿童智能手表大规模隐私泄露、历史漏洞集合整理、恶意代码内存隐藏技术（Phantom DLL Hollowing）以及网站全站镜像复制实战技巧。

## 详细内容

### 区块链智能合约逆向初探

**来源**：阿里云先知社区  
**链接**：<https://xz.aliyun.com/t/6934>

介绍智能合约字节码结构、常见漏洞模式（重入、整数溢出、访问控制缺失等）及逆向分析工具链（如 Porosity、Ethersplay、Manticore），为区块链安全审计提供入门指引。

> **关联主题**：区块链安全审计、智能合约漏洞挖掘、字节码逆向工程

### 1.5 亿儿童 GPS 手表暴露在互联网上

**来源**：PentestPartners 官方博客  
**链接**：<https://www.pentestpartners.com/security-blog/kids-tracker-watches-cloudpets-exploiting-athletes-and-hijacking-reality-tv/>

PentestPartners 披露多款儿童 GPS 定位手表存在严重安全缺陷：云端 API 未授权访问、设备与账号绑定逻辑缺陷、位置历史数据泄露、甚至可远程控制设备拍照/录音。受影响设备数量高达 1.5 亿，波及全球多个品牌。

**核心风险点**：
- 未授权访问儿童实时位置、历史轨迹
- 可篡改设备配置、植入恶意固件
- 家长账号体系存在横向越权
- 部分设备开放调试端口，可获取 Root Shell

> **关联主题**：IoT 设备安全、隐私合规、儿童数据保护、供应链安全

### 2018-2019 年漏洞集合整理

**来源**：某安全团队整理（百度网盘）  
**链接**：<https://pan.baidu.com/s/1HnoiLM-Z4Hombh7OMKEe7A>  
**提取码**：qip9

该合集收录 2018-2019 年主流组件、框架、中间件、CMS 等公开漏洞的 PoC/EXP 及复现脚本，适合漏洞复现学习、应急响应检索及红队武器库建设。

> **关联页面**：[[cve-digest-20200426]]、[[cve-digest-20210325]] 等后续漏洞聚合页面可作对比参考

### 掩盖恶意内存第一部—— Phantom DLL Hollowing 技术

**来源**：Forrest Orr 个人技术博客  
**链接**：<https://www.forrest-orr.net/post/malicious-memory-artifacts-part-i-dll-hollowing>

深度解析 **Phantom DLL Hollowing**（幽灵 DLL 镂空）技术：攻击者在合法进程中卸载正版 DLL，随后在原内存区域映射恶意 DLL，保持模块列表、内存权限、PE 头特征看似合法，从而绕过 EDR/内存扫描器的模块完整性校验。

**关键技术点**：
- 利用 `NtUnmapViewOfSection` 卸载目标 DLL
- 手动映射恶意 PE 至原基址
- 修复 PEB `Ldr` 链表、VAD 节点、Section 对象
- 对比传统 Process Hollowing、DLL Injection 的检测面差异

> **关联主题**：内存免杀、EDR 绕过、恶意代码分析、Windows 内部机制

### 论如何优雅地复制一个网站的所有页面

**来源**：阿里云先知社区  
**链接**：<https://xz.aliyun.com/t/6941>

实战分享网站全站镜像复制的工程化方案：  
- 爬虫去重策略（URL 规范化、Bloom Filter、SimHash 近似去重）  
- 动态渲染处理（Headless Chrome / Playwright）  
- 资源本地化重写（CSS/JS/图片/字体路径转换、Base64 内联）  
- 断点续传、增量更新、分布式调度（Scrapy-Redis / Scrapy-Cluster）  
- 反爬绕过（Cookie 池、IP 代理池、JS 逆向签名还原）  
- 合规性提示：尊重 robots.txt、频率控制、数据合规

> **关联主题**：Web 爬虫工程、资产测绘、攻击面管理、数据采集合规

## 关联阅读

- 同系列前一日：[[daily-security-digest-20191220]]（蔓灵花 APT-C-08 移动攻击分析、zzzphp SQL 注入、Facebook 手机号泄露）
- 同系列后续：[[daily-security-digest-20191223]]（ATT&CK 归因讨论、Google Project Zero 在野漏洞统计、Chrome WebSQL RCE、Mozi P2P 僵尸网络）
- 同系列更多：[[daily-security-digest-20191224]]、[[daily-security-digest-20191225]]、[[daily-security-digest-20191226]]、[[daily-security-digest-20191227]]、[[daily-security-digest-20191230]]

## 小结

本期看点覆盖 **区块链逆向、IoT 隐私泄露、漏洞情报聚合、内存对抗技术、Web 爬虫工程** 五大方向，反映 2019 年底安全社区关注的热点：新兴技术（区块链）安全基建、消费级 IoT 设备隐私合规危机、红蓝对抗中的内存级免杀演进、以及自动化资产发现工程化实践。

## 来源

- [0th3rs安全团队-201911-202204_110](../sources/0th3rs安全团队-201911-202204_110.md)
