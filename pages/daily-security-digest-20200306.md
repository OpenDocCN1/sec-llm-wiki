---
title: 每日安全看点 2020-03-06
description: 汇总 2020 年 3 月 6 日每日安全看点，涵盖恶意软件分析公开课、POC 编写经验、ThinkPHP 历史漏洞防御视角、DNS 数据渗漏案例、Android
  三月补丁、AFL++ Fuzzing Vim 实战及 OpenSMTPD 信息泄露漏洞 (CVE-2020-8793)
category: ai-security
tags:
- 每日安全看点
- 恶意软件分析
- 逆向工程
- POC编写
- ThinkPHP
- DNS渗透
- Android安全
- Fuzzing
- AFL++
- Vim
- OpenSMTPD
- CVE-2020-8793
- 2020年3月
date: '2020-03-06'
updated: '2026-11-12'
---

## 概述

本期每日安全看点汇总了 2020 年 3 月 6 日的安全技术资讯，涵盖恶意软件分析公开课程、POC 编写实战经验、ThinkPHP 历史漏洞的防御视角分析、DNS 数据渗漏案例研究、Android 三月安全补丁公告、AFL++ 对 Vim 进行 Fuzzing 的实战教程，以及 OpenSMTPD 邮件服务器信息泄露漏洞 (CVE-2020-8793) 的详细披露。

## 恶意软件分析及逆向工程公开课

**资源链接**：<https://class.malware.re/>

提供系统性的恶意软件分析与逆向工程教学课程，适合安全研究人员入门及进阶学习。课程涵盖静态分析、动态分析、反调试对抗、加壳脱壳等核心技能点。

## POC 编写实战经验分享

**文章链接**：<https://www.freebuf.com/vuls/228111.html>

FreeBuf 发表的 POC 编写经验总结，从漏洞挖掘到利用代码编写的完整流程，包含漏洞触发条件分析、Payload 构造技巧、绕过防护机制等实战心得。

## ThinkPHP 历史漏洞防御视角分析

**文章链接**：<https://www.freebuf.com/vuls/229093.html>

从防护角度复盘 ThinkPHP 框架历史漏洞，分析漏洞根因、攻击向量及检测规则编写方法，为 WAF/RASP 规则制定和应用层加固提供参考。

## DNS 数据渗漏案例研究

**文章链接**：<https://insinuator.net/2020/03/dns-exfiltration-case-study/>

深度剖析真实环境中利用 DNS 协议进行数据渗漏的攻击案例，涵盖隧道构建、编码技术、流量特征分析及检测对抗策略。

## Android 三月安全补丁公告

**公告链接**：<https://source.android.com/security/bulletin/2020-03-01>

Google 发布 2020 年 3 月 Android 安全公告，修复框架层、系统组件、内核驱动、Qualcomm 闭源组件等多处高危漏洞，建议设备厂商及时推送 OTA 更新。

## AFL++ Fuzzing Vim 实战教程

**教程链接**：<https://www.inputzero.io/2020/03/fuzzing-vim.html>

详细记录使用 AFL++ 对 Vim 编辑器进行模糊测试的完整过程：环境搭建、种子选取、编译插桩、持续 Fuzzing、崩溃样本去重与漏洞根因分析，展示现代灰盒 Fuzzing 工作流。

## CVE-2020-8793 OpenSMTPD 信息泄露漏洞

**披露详情**：<https://www.qualys.com/2020/02/24/cve-2020-8793/local-information-disclosure-opensmtpd.txt>

Qualys 披露 OpenSMTPD 邮件服务器本地信息泄露漏洞 (CVE-2020-8793)，攻击者可利用该漏洞读取敏感文件内容。漏洞源于邮件队列处理逻辑缺陷，影响特定版本范围，建议升级至修复版本。

## 关联阅读

- [[daily-security-digest-20200309]] — 2020 年 3 月 9 日每日安全看点，涵盖 Java 白盒审计工具 Hades、IoT PWN 实战、Fuzzing 学习资源等
- [[daily-security-digest-20200311]] — 2020 年 3 月 11 日每日安全看点，涵盖 SRC 漏洞挖掘、IoT 实验室搭建、逆向工程书籍推荐
- [[daily-security-digest-20200312]] — 2020 年 3 月 12 日每日安全看点，涵盖 wget CVE 分析、渗透测试案例、JSC/WebKit 架构资料
- [[daily-security-digest-20200316]] — 2020 年 3 月 16 日每日安全看点，涵盖 Linux 内核动态调试、NETGEAR RCE、V8 利用入门、SMBGhost 分析
- [[daily-security-digest-20200317]] — 2020 年 3 月 17 日每日安全看点，涵盖 CVE-2020-0768 ChakraCore 漏洞、苹果剪贴板隐私泄漏、VSCode RCE 隐患
- [[daily-security-digest-20200318]] — 2020 年 3 月 18 日每日安全看点，涵盖 fastjson/Shiro/Weblogic 反序列化漏洞复现、ATT&CK 欺骗防御、Windows 提权

## 来源

- [0th3rs安全团队-201911-202204_068](../sources/0th3rs安全团队-201911-202204_068.md)
