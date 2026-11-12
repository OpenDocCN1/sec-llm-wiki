---
title: 每日安全看点 2019-12-20
description: 汇总2019年12月20日安全资讯，涵盖蔓灵花APT-C-08移动攻击分析、zzzphp SQL注入漏洞、逆向工程资源库及Facebook手机号泄露事件
category: ai-security
tags:
- 每日安全看点
- APT-C-08
- 蔓灵花
- 移动端安全
- zzzphp
- SQL注入
- 逆向工程
- 数据泄露
- Facebook
- 2019年12月
date: 2019-12-20
updated: '2026-11-12'
---

## 概述

本期每日安全看点汇总了 2019 年 12 月 20 日的四条核心安全资讯：360 披露蔓灵花（APT-C-08）移动平台攻击活动细节；阿里云先知社区曝光 zzzphp CMS 存在大量 SQL 注入漏洞；GitHub 上整理的逆向工程优质资源库；以及 Elasticsearch 数据库配置不当导致 2.67 亿 Facebook 用户手机号泄露。

---

## 蔓灵花（APT-C-08）移动平台攻击活动揭露

> 来源：360 安全大脑博客  
> 链接：<http://blogs.360.cn/post/analysis_of_APT_C_08.html>

360 威胁情报中心发布深度分析报告，系统披露 **蔓灵花（APT-C-08）** 组织针对移动平台的持续攻击活动。报告涵盖：

- **攻击载体**：伪装成正常应用的恶意 APK，通过社工诱导受害者安装
- **C2 通信**：采用 HTTP/HTTPS 协议，结合域名生成算法（DGA）与动态域名解析，增强基础设施韧性
- **功能模块**：设备指纹采集、短信/通讯录/通话记录窃取、音频录制、定位跟踪、文件管理、远程 Shell 执行等完整间谍功能集
- **归因线索**：代码复用、基础设施重叠、目标选择特征（主要针对南亚地区特定人群）与历史活动高度一致

该报告为移动端 APT 攻击溯源提供了详尽的技术细节与 IOC 指标。

---

## zzzphp CMS 普遍存在 SQL 注入漏洞

> 来源：阿里云先知社区  
> 链接：<https://xz.aliyun.com/t/6942>

文章详细分析 **zzzphp** CMS 多个模块中存在的 SQL 注入漏洞，核心成因在于：

- **过滤不足**：框架对用户输入的过滤函数存在黑名单绕过问题
- **拼接执行**：多处业务逻辑直接将外部参数拼接进 SQL 语句，未使用预编译
- **影响范围**：涉及前台搜索、列表筛选、会员中心等多个高频接口，攻击者无需认证即可利用

作者提供了完整的漏洞触发路径分析与 PoC 验证代码，建议使用该 CMS 的站点立即升级或应用临时防护规则。

> 🔗 关联阅读：[[zzzphp-cve-2021-32605-rce]]（zzzphp 后续版本中发现的模板注入 RCE 漏洞）、[[zzzcms-v1.7.5-audit]]（同属 zzz 系列的 zzzcms 代码审计分析）

---

## GitHub 逆向工程优质资源库

> 来源：GitHub  
> 链接：<https://github.com/alphaSeclab/awesome-reverse-engineering>

**alphaSeclab/awesome-reverse-engineering** 是一个持续维护的逆向工程学习资源聚合仓库，收录内容包括：

| 类别 | 典型资源 |
|------|----------|
| 入门教程 | 《逆向工程核心原理》、Lena151 教程、Crackmes 练习平台 |
| 静态分析 | IDA Pro / Ghidra / Binary Ninja 插件与脚本集合 |
| 动态调试 | x64dbg、Frida、Unicorn、QEMU 用户态模拟脚本 |
| 反混淆/反反调试 | OLLVM、Tigress、VMProtect、Themida 分析资料 |
| 固件/物联网 | Binwalk、Firmware Analysis Toolkit、嵌入式架构参考手册 |
| 移动端 | Android / iOS 逆向工具链、Hook 框架、沙箱逃逸技术 |
| 学术论文 | 顶会（NDSS, USENIX Security, CCS, S&P）逆向相关论文索引 |

适合从入门到进阶的逆向工程师系统性查阅与技能树构建。

---

## Facebook 2.67 亿用户手机号泄露事件

> 来源：Threatpost  
> 链接：<https://threatpost.com/267m-facebook-phone-numbers-exposed-online/151327/>

安全研究人员发现一个 **公开暴露的 Elasticsearch 数据库**，包含约 **2.67 亿条 Facebook 用户记录**，字段涵盖：

- 用户唯一 ID
- 手机号码（部分带国家代码）
- 姓名、性别、地区等画像信息

**根因**：数据库未启用认证鉴权，直接绑定在公网 IP 上，任意访问者可通过简单查询导出全量数据。数据疑源于早期 Facebook API 权限宽松时期的爬虫采集，或第三方开发者违规存储。

**影响**：手机号可用于 SIM 卡劫持、钓鱼短信、账号撞库、定向社工等二次攻击。Facebook 回应称数据为旧数据集，已修复相关 API 滥用问题，但暴露的数据库归属方及存储时长仍在调查中。

---

## 结语

> 顺祝明后两天考研顺利！！！

---

## 关联页面

- [[daily-security-digest-20191223]] — 12 月 23 日看点：ATT&CK/APT 归因、Chrome 0day、VMware Fusion RCE、Mozi 僵尸网络
- [[daily-security-digest-20191224]] — 12 月 24 日看点：内网穿透、PHP 木马、零知识证明、Hypervisor 入门
- [[daily-security-digest-20191225]] — 12 月 25 日看点：机器学习测 WAF、Django 漏洞、DarkRat、Empire 3.0
- [[daily-security-digest-20191226]] — 12 月 26 日看点：FLIRT、Binary Ninja 去混淆、区块链、Fuzzing 会议
- [[daily-security-digest-20191227]] — 12 月 27 日看点：Web API 安全、Google Cloud Shell、iOS 代码签名、Nightmare 逆向入门

## 来源

- [0th3rs安全团队-201911-202204_109](../sources/0th3rs安全团队-201911-202204_109.md)
