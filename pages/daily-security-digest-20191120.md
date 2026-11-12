---
title: 2019年11月20日每日安全看点汇总
description: 汇总2019年11月20日安全资讯，涵盖Fuzzing平台建设、CodeQL初体验、CCS'19会议、对抗AI教程、Gmail XSS、MySQL字符集、PHP序列化差异、Dream
  CMS XSS、iCloud绕过、macOS取证工具及网络安全威胁信息发布管理办法
category: ai-security
tags:
- 每日安全看点
- 2019年11月
- Fuzzing
- CodeQL
- CCS2019
- 对抗AI
- Gmail XSS
- MySQL
- PHP序列化
- Dream CMS
- iCloud绕过
- macOS取证
- 网络安全政策
date: '2019-11-20'
updated: '2026-11-13'
---

## 概述

本页面汇总 2019 年 11 月 20 日发布的每日安全看点，涵盖模糊测试平台建设、代码分析引擎、学术会议、对抗机器学习、多个漏洞分析（Gmail XSS、MySQL 字符集、PHP 序列化、Dream CMS XSS）、iCloud 绕过、macOS 取证工具以及网络安全政策文件等内容。

## Fuzzing 平台建设研究与设计

**资源链接**：[Fuzzing平台建设的研究与设计 PDF](http://riusksk.me/media/Fuzzing%E5%B9%B3%E5%8F%B0%E5%BB%BA%E8%AE%BE%E7%9A%84%E7%A0%94%E7%A9%B6%E4%B8%8E%E8%AE%BE%E8%AE%A1.pdf)

概要介绍构建 Fuzzing 平台需要考虑的核心要素，包括目标选择、种子语料库管理、变异策略、执行环境隔离、崩溃去重分类、覆盖率反馈机制及分布式调度等基础模块。

## CodeQL 代码分析引擎初体验

**资源链接**：[代码分析引擎 CodeQL 初体验](https://blog.knownsec.com/2019/11/%E4%BB%A3%E7%A0%81%E5%88%86%E6%9E%90%E5%BC%95%E6%93%8E-codeql-%E5%88%9D%E4%BD%93%E9%AA%8C/)

介绍 GitHub CodeQL（原 Semmle QL）的基本使用流程：数据库创建、QL 查询编写、变体分析实战，展示如何利用声明式查询语言快速挖掘代码库中的漏洞模式。

## CCS'19 学术会议参会记录

**资源链接**：[白泽带你去参会@CCS’19](https://mp.weixin.qq.com/s/gYqamT3WXiyj79mjBQYRiA)

白泽安全团队记录的 2019 ACM CCS 会议见闻，涵盖重点论文解读、会议侧写及学术前沿动态。

## 对抗 AI 模型系列教程

**资源链接**：[HackingNeuralNetworks](https://github.com/Kayzaks/HackingNeuralNetworks)

系统性教程仓库，覆盖对抗样本生成、模型窃取、成员推理、模型反转等经典攻击手法，配合代码实现与论文复现，适合 AI 安全入门与进阶。

## Gmail XSS 漏洞分析

**资源链接**：[Gmail XSS 漏洞](https://www.anquanke.com/post/id/19315)

详细分析 Gmail 中发现的跨站脚本漏洞成因、触发条件及利用链条，展示邮件客户端解析 HTML 过滤不当导致的脚本执行风险。

## MySQL 字符集研究

**资源链接**：[MySql字符研究](https://www.secpulse.com/archives/118629.htm)

深入探讨 MySQL 字符集与排序规则的内部机制，涉及 `utf8` 与 `utf8mb4` 差异、字符集转换导致的截断注入、排序规则绕过 WAF 等安全相关特性。

## PHP 序列化与反序列化语法差异

**资源链接**：[PHP序列化和反序列化语法差异问题](https://www.secpulse.com/archives/118807.html)

梳理 PHP `serialize()` 与 `unserialize()` 在不同版本、不同配置下的语法兼容性差异，分析利用差异绕过检测、构造恶意对象链的实战技巧。

## Dream CMS v1.4 XSS 漏洞分析

**资源链接**：[梦想v1.4 CMS平台XSS漏洞分析](https://www.freebuf.com/vuls/218838.html)

针对 Dream CMS v1.4 后台多处反射型与存储型 XSS 进行代码审计，定位过滤缺失参数，给出 PoC 与修复建议。

## iCloud 绕过工具

**资源链接**：[iCloudBypassCA](https://github.com/crazymind90/iCloudBypassCA)

开源工具集合，演示利用配置描述文件、激活锁绕过等技术手段在特定条件下规避 iCloud 激活锁，供安全研究参考。

## AutoMacTC：macOS 自动化取证采集工具

**资源链接**：[AutoMacTC：一款针对macOS环境的自动化取证分类采集器](https://www.freebuf.com/sectool/218812.html)

基于 Python 开发的 macOS 取证自动化框架，支持日志、浏览器历史记录、邮件、Wi-Fi 记录、时间线等 30+ 类工件的一键采集与分类打包，便于事件响应快速取证。

## 网络安全威胁信息发布管理办法（征求意见稿）

**资源链接**：[网络安全威胁信息发布管理办法（征求意见稿）](http://www.cac.gov.cn/2019-11/20/c_1575785387932969.htm)

国家互联网信息办公室发布的征求意见稿，规定网络安全威胁信息的发布主体、发布流程、内容规范、保密要求及法律责任，旨在规范威胁情报共享秩序。

## 关联页面

- 下一日看点：[[daily-security-digest-20191121]]
- 同期归档索引：[[0th3rs-security-team-wechat-archive-201911-202204]]

## 来源

- [0th3rs安全团队-201911-202204_134](../sources/0th3rs安全团队-201911-202204_134.md)
