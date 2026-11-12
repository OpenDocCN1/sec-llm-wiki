---
title: 每日安全看点 2020-03-18
description: 汇总 2020 年 3 月 18 日每日安全看点，涵盖 Win10 Exp 合集、ATT&CK 欺骗防御、fastjson-ShiroCore
  反序列化、Weblogic CVE-2020-2555、APP 手动解析、Shiro 反序列化复现等安全资讯与技术文章链接
category: ai-security
tags:
- 每日安全看点
- 漏洞复现
- 反序列化
- fastjson
- Shiro
- Weblogic
- CVE-2020-2555
- ATT&CK
- 欺骗防御
- APP渗透测试
- Windows提权
date: 2020-03-18
updated: '2026-11-12'
---

## 概述

本期每日安全看点收录 2020 年 3 月 18 日的 7 条安全资讯与技术文章，涉及 **Windows 漏洞利用合集**、**ATT&CK 欺骗防御实战**、**fastjson 新 Gadget (ShiroCore)**、**Weblogic CVE-2020-2555 POC 构造**、**APP 手动解析实战**、**Shiro 反序列化复现** 等方向，为安全研究人员提供漏洞分析、利用复现与防御体系构建的参考资料。

## 资讯目录

### Win10 Exp 合集
- **链接**：<https://github.com/nu11secur1ty/Windows10Exploits>
- **说明**：GitHub 仓库汇总 Windows 10 相关漏洞利用代码，便于研究者快速获取本地提权、绕过 UAC 等 Exp 样本。

### 基于 ATT&CK 框架的欺骗防御应用
- **链接**：<https://mp.weixin.qq.com/s/S4Tboao5kqcuK9bC_lxvX>
- **说明**：介绍如何结合 MITRE ATT&CK 矩阵部署欺骗防御（Deception）体系，通过蜜签、蜜令牌、高交互蜜罐等技术在横向移动、凭证窃取、持久化等战术阶段实现早期发现与溯源。

### fastjson 反序列化漏洞最新 Gadget——ShiroCore
- **链接**：<https://mp.weixin.qq.com/s/O90M916ksZ_Jld9qtr9_-A>
- **说明**：分析 fastjson 近期新增的 `shiro-core` 反序列化利用链，梳理触发条件、调用栈与绕过限制手法，属于 Java 反序列化漏洞研究的重要补充。相关基础机制可参考 [[java-deserialization-fundamentals]]。

### Weblogic & Coherence POC 构造之路 (CVE-2020-2555)
- **链接**：<https://mp.weixin.qq.com/s/vrDHMFEwHyaKH8yxxyF6Cw>
- **说明**：详细记录 CVE-2020-2555 (Weblogic Coherence 反序列化 RCE) 的 POC 构造过程，包括利用链挖掘、序列化数据生成、绕过黑名单过滤等关键步骤。

### 【手把手教你搞定所有 APP】——手动解析 APP 数据篇
- **链接**：<https://mp.weixin.qq.com/s/ro_4lYg1L9jWRf2CSWGMvg>
- **说明**：实战演示如何在无自动化工具辅助下，手动逆向分析 APP 通信协议、数据加密逻辑与接口签名算法，适合移动安全入门与进阶。

### Shiro 反序列化漏洞测试复现方法
- **链接**：<https://mp.weixin.qq.com/s/0WCfJH_JeUIIgkfmzBk2WA>
- **说明**：提供 Shiro 反序列化漏洞 (Shiro-550 / CVE-2016-4437 等) 的完整复现环境搭建、Payload 生成 (ysoserial/ysoserial.shiro) 与验证步骤，配合 [[java-deserialization-fundamentals]] 可深入理解利用原理。

## 关联专题

- [[java-deserialization-fundamentals]] — Java 序列化/反序列化核心机制，夯实 fastjson、Shiro、Spring Boot 等利用链分析基础
- [[spring-boot-devtools-deserialization-rce]] — Spring Boot DevTools 弱默认密钥导致的反序列化 RCE 利用链
- [[h2-console-jndi注入rce利用]] — H2 Console JNDI 注入 RCE 实战攻击链
- [[spring-boot-actuator配置不当rce利用]] — Spring Boot Actuator 多端点组合利用实现 RCE
- [[spring-cloud-config目录穿越漏洞]] — Spring Cloud Config 目录穿越任意文件读取
- [[java-urlconnection-ssrf-protocol-bypass]] — Java URLConnection 协议前缀绕过 SSRF 转任意文件读取

## 参考来源

- 微信公众号「每日安全看点」2020-03-18 期原文
- GitHub 仓库 nu11secur1ty/Windows10Exploits
- 相关技术公众号文章 (见各条目链接)

## 来源

- [0th3rs安全团队-201911-202204_062](../sources/0th3rs安全团队-201911-202204_062.md)
