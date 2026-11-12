---
title: 每日安全看点 2019-12-23
description: 汇总2019年12月23日安全资讯，涵盖ATT&CK/APT归因讨论、Google Project Zero在野漏洞统计、Chrome WebSQL/SQLite
  RCE漏洞、RealWorldCTF VMware Fusion RCE分析、Mozi P2P僵尸网络分析
category: ai-security
tags:
- 每日安全看点
- ATT&CK
- APT归因
- Google Project Zero
- 在野漏洞
- Chrome漏洞
- WebSQL
- SQLite
- RCE
- VMware Fusion
- RealWorldCTF
- Mozi
- P2P僵尸网络
- DHT协议
- 2019年12月
date: 2019-12-23
updated: '2026-11-12'
---

## 概述

本期每日安全看点汇总了 2019 年 12 月 23 日的五条重要安全资讯，涉及威胁情报框架讨论、在野漏洞统计项目、浏览器核心组件漏洞、虚拟化逃逸研究以及新型 P2P 僵尸网络分析。

## 详细内容

### ATT&CK/APT/归因讨论

微博文章深入探讨了 MITRE ATT&CK 框架在 APT 攻击归因中的应用与局限性。讨论聚焦于如何将观测到的 TTPs（战术、技术与过程）映射到 ATT&CK 矩阵，以及基于技术指标进行攻击者归因时面临的挑战——包括误导性工件、共享基础设施、工具代码重用等干扰因素。文章强调归因需结合战略情报、受害学特征与行为模式综合研判，而非单纯依赖技术指标匹配。

> 相关背景：ATT&CK 框架在防御侧的应用可参考 [[daily-security-digest-20200113]] 中关于 ATT&CK 防御逃逸技术的讨论。

### Google Project Zero 在野漏洞统计项目

Google Project Zero 发起公开电子表格，持续追踪并记录**在野利用的 0day 漏洞**。该项目旨在通过透明化数据，推动行业对在野攻击趋势的理解，并为防御优先级排序提供实证依据。表格字段涵盖 CVE 编号、发现时间、利用时间、厂商、组件、漏洞类型、攻击向量、归因组织等维度，是威胁情报与漏洞管理的重要参考数据源。

> 类似的漏洞聚合视角可见 [[cve-digest-20200426]]、[[cve-digest-20210325]] 等 CVE 汇总页面。

### Chrome WebSQL / SQLite 远程代码执行漏洞 (CNVD-2019-XXXXX)

国家信息安全漏洞共享平台 (CNVD) 发布安全公告，披露 Chrome 浏览器中 **WebSQL** 组件（基于 SQLite）存在任意代码执行漏洞。攻击者可通过构造恶意网页，诱导用户访问触发 SQLite 引擎中的内存破坏（如类型混淆、越界访问），结合浏览器渲染进程沙箱逃逸实现 RCE。该漏洞凸显了废弃但仍保留的遗留组件（WebSQL 已被 W3C 废弃，Chrome 仍为兼容性保留）成为高风险攻击面。

> 浏览器内存安全漏洞利用技术可参考 [[daily-security-digest-20200120]] 中的浏览器利用资料库与 V8 引擎分析。

### RealWorld CTF 2019: VMware Fusion REST API 漏洞分析 (Bifröst)

长亭科技研究员周智在 RealWorld CTF 2019 上演示题目 **"Bifröst: 揭秘 VMware Fusion REST API 漏洞"**。该研究针对 VMware Fusion 的 REST API 接口，分析了其认证绕过与命令注入漏洞链，实现从非受信网络对宿主机的远程代码执行（VM Escape）。�ides 详细剖析了 API 端点枚举、输入验证缺陷、权限提升路径及最终利用链构造。

> 虚拟化安全与 Hypervisor 逃逸相关基础可参考 [[daily-security-digest-20191224]] 中的 Hypervisor 入门教程；VMware 近期漏洞汇总见 [[cve-digest-20210401]]。

### Mozi: 继 Hajime 后又一使用 DHT 协议组网的 P2P 僵尸网络

360 Netlab 发布深度分析报告，披露 **Mozi** 僵尸网络技术细节。Mozi 采用 **DHT (Distributed Hash Table)** 协议构建去中心化 C2 网络，继 Hajime 后成为又一主流 P2P 僵尸网络家族。主要特征包括：

- **传播向量**：利用网络设备（路由器、DVR、IP 摄像头等）的弱口令、未授权访问及已知漏洞（如 EternalBlue、ThinkPHP RCE、GPON 漏洞）进行横向扩散
- **C2 通信**：基于 Mainline DHT 协议，使用 `infohash` 标识僵尸网络，配置与指令通过 DHT 存储/检索分发，抗封锁、抗取证
- **功能模块**：DDoS 攻击（SYN/ACK/UDP/HTTP Flood）、HTTP 代理、敏感信息窃取、payload 更新、自我保护（杀掉竞争恶意软件、修改 iptables）
- **样本特征**：Go 语言编写，静态链接，UPX 壳，针对多架构（x86, ARM, MIPS 等）交叉编译

报告提供了 IOC、DHT 爬取监测方法及缓解建议，为 IoT 威胁狩猎提供参考。

> IoT 设备安全与僵尸网络分析方法论可关注同类 P2P 僵尸网络演进；内网渗透与横向移动技术参考 [[frp内网渗透应用]]。

## 关联阅读

- [[daily-security-digest-20191224]] - 次日安全看点：内网穿透、PHP 木马、零知识证明、Hypervisor 入门
- [[daily-security-digest-20191225]] - 机器学习测试 WAF、Django CVE-2019-19844、Empire 3.0
- [[daily-security-digest-20200113]] - ATT&CK 防御逃逸、Java Fuzz、SpringBoot RCE 链
- [[cve-digest-20200426]] - Chrome V8 堆溢出 (CVE-2018-6065) 等漏洞聚合
- [[cve-digest-20210401]] - VMware vRealize SSRF 等虚拟化产品漏洞
- [[frp内网渗透应用]] - frp 内网穿透与横向移动实战
- [[docker-container-security-fundamentals]] - 容器安全架构与隔离机制基础

## 时间线摘要

| 时间 | 事件 | 类别 |
|------|------|------|
| 2019-12-23 | ATT&CK/APT 归因方法论讨论发布 | 威胁情报 |
| 2019-12-23 | Google Project Zero 在野 0day 统计表公开 | 漏洞情报 |
| 2019-12-23 | CNVD 发布 Chrome WebSQL/SQLite RCE 公告 | 浏览器安全 |
| 2019-12-23 | RealWorld CTF VMware Fusion 逃逸 Slides 发布 | 虚拟化安全 |
| 2019-12-23 | 360 Netlab 披露 Mozi P2P 僵尸网络分析报告 | IoT 威胁 / 僵尸网络 |

## 来源

- [0th3rs安全团队-201911-202204_107](../sources/0th3rs安全团队-201911-202204_107.md)
