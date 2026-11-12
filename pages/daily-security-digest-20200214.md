---
title: 每日安全看点 2020-02-14
description: 汇总 2020 年 2 月 14 日安全动态：Android 逆向工具 GDA、angr 自动化漏洞利用生成缓冲区溢出案例、腾讯安全招聘、工信部涉疫情网络安全风险提示、Safari
  字体处理 RCE 漏洞及分布式密码暴力破解工具 Kraken。
category: ai-security
tags:
- 每日安全看点
- Android逆向
- angr
- 漏洞利用自动化
- 招聘
- 疫情网络安全
- Safari RCE
- 分布式暴力破解
date: '2020-02-14'
updated: '2026-11-12'
---

## 概述

本期每日安全看点汇总了 2020 年 2 月 14 日的六条安全资讯，涵盖逆向工程工具发布、漏洞利用自动化研究、企业招聘、监管部门风险提示、浏览器零日漏洞分析以及分布式破解工具开源等内容。

## 逆向工程

### GDA：Android 逆向分析工具

- **项目地址**：<https://github.com/charles2gan/GDA-android-reversing-Tool>
- **简介**：GDA (GDA Android Reversing Tool) 是一款面向 Android 应用的静态逆向分析工具，支持反编译、代码分析、漏洞扫描等功能，适用于恶意代码分析、漏洞挖掘及安全审计场景。

## 漏洞利用自动化

### 基于 angr 的漏洞利用自动生成：缓冲区溢出案例分析

- **文章链接**：<https://xz.aliyun.com/t/7199>
- **核心内容**：详细阐述了如何利用符号执行框架 **angr** 自动化生成缓冲区溢出漏洞的利用代码（Exploit），涵盖约束求解、ROP 链构造、绕过 ASLR/DEP 等关键步骤，展示了二进制漏洞利用自动化的可行性路径。

## 招聘信息

### 腾讯安全平台部招聘

- **详情页**：<https://mp.weixin.qq.com/s/zT0if1DCx6iSjbc_-72KQQ>
- **岗位方向**：安全平台建设、威胁检测、漏洞挖掘、红蓝对抗等多个安全研发与工程方向。

## 政策法规与风险提示

### 工信部网络安全管理局：涉新冠肺炎疫情网络安全风险提示

- **来源**：FreeBuf <https://www.freebuf.com/news/227209.html>
- **要点**：
  - 针对疫情期间网络钓鱼、恶意软件传播、虚假 APP、数据泄露等风险发出预警
  - 要求相关单位加强监测预警、应急处置与安全防护
  - 强调个人信息保护与关键信息基础设施安全责任

## 浏览器安全

### Safari 字体处理远程代码执行漏洞

- **分析报告**：Talos Intelligence <https://blog.talosintelligence.com/2020/02/vuln-spotlight-apple-safari-code-execution-feb-2020.html>
- **漏洞详情**：
  - 根因：WebKit 在处理特定字体格式（如 OTF/TTF）时存在内存破坏缺陷
  - 影响：攻击者可构造恶意网页诱导用户访问，触发 RCE，逃逸沙箱
  - 修复：Apple 已在 2020 年 2 月安全更新中修复（CVE 编号待补充）

## 密码安全与攻击工具

### Kraken：分布式密码暴力破解工具

- **项目地址**：<https://github.com/arcaneiceman/kraken-client>
- **特性**：
  - 基于分布式架构，支持多节点协同破解
  - 兼容 Hashcat 规则与掩码模式
  - 提供 Web 管理界面，便于任务调度与进度监控
  - 适用于密码强度审计、渗透测试授权场景

## 关联页面

- [[daily-security-digest-20200217]] — 2020-02-17 每日安全看点（钓鱼攻击、开源漏洞、Ghidra 逆向、ARM ROP 等）
- [[daily-security-digest-20200218]] — 2020-02-18 每日安全看点（红队资源、PortSwigger Top 10、APT 报告等）
- [[daily-security-digest-20200220]] — 2020-02-20 每日安全看点（GitHub 敏感信息采集、以太坊蜜罐、CVE-2020-0618 等）
- [[daily-security-digest-20200221]] — 2020-02-21 每日安全看点（Tomcat AJP CVE-2020-1938、iOS 虚拟机 UTM 等）
- [[daily-security-digest-20200224]] — 2020-02-24 每日安全看点（Android 厂商漏洞披露、APT TTPs、Linux SUID 提权等）
- [[daily-security-digest-20200225]] — 2020-02-25 每日安全看点（RSAC 2020、Docker 安全、硬件调试 SWD/OpenOCD、MariaDB CVE-2020-7221 等）
- [[daily-security-digest-20200226]] — 2020-02-26 每日安全看点（LLVM/Clang Pass、账号接管、挖矿木马应急、Linux 内核栈溢出、Windows Defender 驱动分析等）
- [[daily-security-digest-20200227]] — 2020-02-27 每日安全看点（Django PostgreSQL 注入、微盟删库、sudo 漏洞回顾、PHP 静态查杀绕过等）
- [[cve-digest-20200426]] — 2020-04-26 CVE 漏洞聚合（Windows 提权、Chrome V8 堆溢出、Firefox XSS 等）
- [[docker-container-security-fundamentals]] — Docker 容器安全核心机制体系化梳理
- [[java-deserialization-fundamentals]] — Java 序列化/反序列化基础机制详解
- [[spring-boot-actuator配置不当rce利用]] — Spring Boot Actuator 多种 RCE 利用链复现
- [[wechat-pc-v8-rce-0day-analysis]] — 微信 PC 版 V8 RCE 0day 深度分析与内网渗透实战

## 来源

- [0th3rs安全团队-201911-202204_081](../sources/0th3rs安全团队-201911-202204_081.md)
