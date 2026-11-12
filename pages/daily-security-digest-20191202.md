---
title: 每日安全看点 2019-12-02
description: 汇总 2019 年 12 月 2 日每日安全看点，涵盖 Frida 移动端 Fuzzing、CPU 漏洞详解、D3CTF Writeup、恶意流量检测系统实战、Adama
  威胁检索工具、ret2dlresolve 技术分析、HFish 蜜罐心得、挖矿处置手册、VMpwn 学习笔记及信息安全入门指引等资讯。
category: ai-security
tags:
- 每日安全看点
- 2019年12月
- Frida
- Fuzzing
- CPU漏洞
- D3CTF
- 恶意流量检测
- Adama
- ret2dlresolve
- 蜜罐
- 挖矿处置
- VMpwn
- 信息安全入门
date: '2019-12-02'
updated: '2026-11-13'
---

## 概述

本期每日安全看点汇总了 2019 年 12 月 2 日的 10 条安全技术资讯，涵盖移动端 Fuzzing、CPU 硬件漏洞、CTF 竞赛复盘、流量检测工程实践、威胁情报工具、二进制利用技术、蜜罐部署经验、挖矿木马应急响应、虚拟机逃逸学习以及安全入门指引等多个方向。

## 详细内容

### Frida 框架在移动端 Fuzzing 中的应用思路

- **链接**：<http://riusksk.me/2019/11/30/Frida%E6%A1%86%E6%9E%B6%E5%9C%A8Fuzzing%E4%B8%AD%E7%9A%84%E5%BA%94%E7%94%A8/>
- **要点**：探讨如何利用 Frida 动态插装框架对移动应用进行模糊测试，包括 Hook 关键函数、输入数据变异、覆盖率引导等核心思路。

### CPU 漏洞详解

- **链接**：<https://mp.weixin.qq.com/s/TzRUUJr19HL8WzKWoPTJCg>
- **要点**：系统梳理 CPU 侧信道漏洞（如 Spectre、Meltdown 等变种）的原理、影响范围及缓解措施，适合作为硬件安全入门参考。

### D3CTF Writeup

- **链接**：<https://www.anquanke.com/post/id/193939>
- **要点**：D3CTF 竞赛题目详细解析，涵盖 Web、Pwn、Reverse、Crypto 等多个方向的解题思路与利用链构造。

### 自己动手制作一个恶意流量检测系统（后记部分反映了一些思考）

- **链接**：<https://www.freebuf.com/articles/system/220565.html>
- **要点**：从数据采集、特征工程、模型训练到部署落地的完整工程实践，后记部分分享了规则与 AI 融合、误报降低、样本迭代等实战心得。

### Adama – 威胁检索和安全分析工具

- **链接**：<https://github.com/randomuserid/Adama>
- **要点**：开源威胁情报检索平台，支持对 IP、域名、文件哈希等 IOC 进行批量查询、关联分析与可视化展示，适合威胁狩猎与应急响应场景。

### 通过一道 Pwn 题详细分析 ret2dlresolve 技术

- **链接**：<https://mp.weixin.qq.com/s/WHyZuu6p00CjZy-h-NdE4Q>
- **要点**：以实战题目为例，逐步拆解 ret2dlresolve（Return to dl-resolve）技术原理：伪造链接器数据结构、控制解析流程、在无 libc 基址泄露情况下实现任意函数调用。

### HFish 蜜罐使用心得

- **链接**：<https://www.freebuf.com/vuls/220646.html>
- **要点**：分享 HFish 蜜罐部署配置、多协议模拟（SSH、HTTP、MySQL 等）、攻击日志分析与告警对接实战经验，适合中小型团队快速建设威胁感知能力。

### 挖矿处置手册：安全研究员的套路都在这儿了

- **链接**：<https://www.freebuf.com/articles/system/220132.html>
- **要点**：系统总结挖矿木马的常见入侵向量、持久化手法、横向移动技术，并给出排查清单、清理步骤、加固建议与溯源取证要点。

### VMpwn 学习笔记

- **链接**：<https://xz.aliyun.com/t/6865>
- **要点**：记录虚拟机逃逸（VM escape）相关漏洞原理、QEMU/KVM/VMware 等虚拟化组件攻击面分析、CVE 复现环境搭建与调试技巧。

### 信息安全入门

- **链接**：<https://mp.weixin.qq.com/s/34hHV_uDapF7GE5ODPbf9w>
- **要点**：面向初学者的知识体系梳理，涵盖 Web 安全、二进制逆向、密码学、CTF 竞赛、学习资源推荐及职业发展路径建议。

## 关联页面

- [[daily-security-digest-20191203]] — 翌日（12 月 3 日）安全看点，含 D3CTF 题目源码、Kerberos 枚举、WebLogic 密文解密等
- [[daily-security-digest-20191204]] — 12 月 4 日看点，涵盖 pydictor、AI 军事应用、IoT 逆向、Strandhogg 漏洞等
- [[0th3rs-security-team-wechat-archive-201911-202204]] — 0th3rs 安全团队微信归档总索引，本期内容来源于该公众号 2019-12-02 推送
- [[docker-container-security-fundamentals]] — 容器安全基础，可关联恶意流量检测与蜜罐部署中的容器化场景
- [[frp内网渗透应用]] — 内网渗透隧道技术，可关联挖矿木马横向移动与蜜罐诱捕场景

## 小结

本期看点以**实战技术分享**为主，覆盖移动端动态分析、硬件漏洞原理、CTF 竞赛复盘、流量检测工程化、威胁情报工具、二进制利用进阶、蜜罐建设、挖矿应急、虚拟化安全及入门指引十大方向，体现了 2019 年底安全社区关注的热点技术栈。

## 来源

- [0th3rs安全团队-201911-202204_123](../sources/0th3rs安全团队-201911-202204_123.md)
