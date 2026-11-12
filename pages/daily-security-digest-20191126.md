---
title: 每日安全看点 2019-11-26
description: 2019年11月26日每日安全看点汇总，涵盖VNC多漏洞、JavaScript DDoS、Shiro 721 Padding Oracle攻击、iOS逆向免费课程、Docker
  CVE-2019-14271分析、Burp/Cobalt Strike/PHP审计实战教程、调试器安全隐患及AppLocker深度解析等安全资讯。
category: ai-security
tags:
- 每日安全看点
- 2019年11月
- VNC
- JavaScript DDoS
- Shiro
- Padding Oracle
- iOS逆向
- Docker
- CVE-2019-14271
- Burp Suite
- Cobalt Strike
- PHP代码审计
- 调试器安全
- AppLocker
date: 2019-11-26
updated: '2026-11-13'
---

## 概述

本期每日安全看点汇总了 2019 年 11 月 26 日的安全技术资讯，涵盖远程桌面漏洞、Web 攻击技术、Java 反序列化、移动端逆向、容器安全、渗透测试工具链、代码审计教程、调试器安全风险及 Windows 应用控制策略等多个方向。

---

## 漏洞预警与分析

### VNC 远程桌面软件多漏洞

> 来源：The Hacker News

在 4 款流行的开源 VNC 软件中发现数十个严重漏洞，攻击者可利用这些漏洞实现远程代码执行、权限提升等攻击。VNC 作为远程桌面协议的常见实现，其安全性直接影响远程运维场景的资产安全。

### JavaScript 驱动的 DDoS 攻击

> 来源：FreeBuf

介绍基于 JavaScript 的 DDoS 攻击原理与实现方式。此类攻击利用浏览器原生执行 JS 的特性，通过诱导用户访问恶意页面或植入恶意脚本，形成分布式攻击流量，具有部署简单、溯源困难等特点。

### Shiro 721 Padding Oracle 攻击

> 来源：m0te.top

Apache Shiro 721 版本存在 Padding Oracle 漏洞（CVE-2019-12422），攻击者可利用 AES-CBC 模式下的填充 oracle 攻击解密并伪造 RememberMe Cookie，进而触发反序列化 RCE。详见 [[java-deserialization-fundamentals]] 了解 Java 反序列化基础机制，以及 [[spring-boot-actuator配置不当rce利用]] 中关于 Shiro 利用链的扩展分析。

### Docker CVE-2019-14271 `docker cp` 漏洞分析

> 来源：阿里云先知社区

Docker `cp` 命令在处理容器内符号链接时存在路径遍历漏洞，攻击者可利用此漏洞突破容器隔离，读写宿主机任意文件。详细技术分析请参考 [[docker-container-security-fundamentals]] 中的容器逃逸与攻击审计章节。

---

## 学习资源与课程

### iOS 应用逆向工程免费在线课程

> 来源：GitHub - ivRodriguezCA/RE-iOS-Apps

一个完全免费、开源且在线的 iOS 应用逆向工程课程，涵盖静态分析、动态调试、Hook 技术、加密算法逆向等核心内容，适合移动安全入门与进阶学习。

---

## 实战工具与教程

### Burp Suite 综合工具插件

> 来源：GitHub - lyxhh/lxhToolHTTPDecrypt

集成 HTTP 解密、签名验证绕过、参数加密解密等功能的 Burp Suite 扩展插件，适用于 APP 渗透测试中常见的接口加密场景。相关 Burp 实战技巧亦可参考 [[daily-security-digest-20191216]] 中的 BurpSuite 插件专题。

### Cobalt Strike 使用详解 Wiki

> 来源：GitHub - aleenzz/Cobalt_Strike_wiki

系统梳理 Cobalt Strike 核心功能、Beacon 通信机制、Malleable C2 配置、横向移动模块等实战用法。后渗透框架对比与免杀技术可参考 [[daily-security-digest-20191218]] 中的 Cobalt Strike 免杀与 SysWhispers 系统调用绕过内容。

### PHP 代码审计入门到弃坑

> 来源：GitHub - aleenzz/php_bug_wiki

从基础语法审计到常见漏洞模式（SQLi、XSS、文件上传、反序列化、RCE 等）的完整教程，包含 CMS 实战案例。配合 [[zzzphp-sql-injection-analysis]]、[[zzzcms-v1.7.5-audit]]、[[cmseasy-7.3.8-code-audit]] 等实战审计案例可形成完整学习闭环。

### evil7 师傅《拿 WordPress 开刀》系列

> 来源：阿里云先知社区

以 WordPress 核心代码为切入点，深入剖析 PHP 框架级漏洞挖掘思路，包含对象注入、链式利用、沙箱绕过等高阶技巧。

---

## 安全机制与防御分析

### 常见调试器的安全隐患浅析

> 来源：微信公众号文章

分析 OllyDbg、x64dbg、IDA Pro 等主流调试器在处理恶意样本、畸形文件、反调试机制时可能触发的漏洞（如缓冲区溢出、格式化字符串、DLL 劫持等），提醒逆向工程师在分析不可信样本时需采取沙箱隔离、虚拟机快照等防护措施。

### AppLocker 深度解析（Part 2）

> 来源：安全客

Windows AppLocker 作为应用程序控制策略的核心组件，Part 2 重点讲解规则集设计、脚本规则绕过技术、DLL 规则生效条件、事件日志审计配置及红队视角的绕过实战。前序内容可关联 [[daily-security-digest-20191127]] 中的 AppLocker 标签专题。

---

## 关联阅读

- [[daily-security-digest-20191127]] - 翌日看点：堆利用、Chrome 沙箱逃逸、Java 反序列化、AppLocker 等
- [[daily-security-digest-20191128]] - AWD 攻防、Peach 模糊测试、Chrome 扩展安全、符号执行等
- [[docker-container-security-fundamentals]] - Docker 容器安全核心机制与逃逸审计体系
- [[java-deserialization-fundamentals]] - Java 序列化/反序列化基础机制
- [[spring-boot-actuator配置不当rce利用]] - Spring Boot Actuator 与 Shiro 反序列化利用链
- [[daily-security-digest-20191216]] - BurpSuite 插件、Docker 安全、C2 框架等
- [[daily-security-digest-20191218]] - Cobalt Strike 免杀、SysWhispers、AppLocker 相关技术
- [[zzzphp-sql-injection-analysis]] - zzzphp SQL 注入审计实战
- [[zzzcms-v1.7.5-audit]] - zzzcms 代码审计全链路分析
- [[cmseasy-7.3.8-code-audit]] - CmsEasy 任意文件操作与 SQL 注入链

---

## 标签索引

`每日安全看点` `2019年11月` `VNC` `JavaScript DDoS` `Shiro` `Padding Oracle` `iOS逆向` `Docker` `CVE-2019-14271` `Burp Suite` `Cobalt Strike` `PHP代码审计` `调试器安全` `AppLocker`

## 来源

- [0th3rs安全团队-201911-202204_128](../sources/0th3rs安全团队-201911-202204_128.md)
