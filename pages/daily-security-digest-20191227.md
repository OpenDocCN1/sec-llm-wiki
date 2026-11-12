---
title: 每日安全看点 2019-12-27
description: 汇总2019年12月27日每日安全看点，涵盖Web API安全、Google Cloud Shell漏洞、Vlunstack ATT&CK实战、iOS代码签名、浏览器缓存绕过SOP、Nightmare逆向入门、移动端渗透测试教程1-3等安全技术资讯
category: ai-security
tags:
- 每日安全看点
- Web API安全
- Google Cloud Shell
- ATT&CK
- iOS代码签名
- SOP绕过
- 逆向工程
- 移动端渗透测试
- Nightmare
- 2019年12月
date: '2019-12-27'
updated: '2026-11-12'
---

## 每日安全看点【2019.12.27】

> 原文：[微信公众号文章](http://mp.weixin.qq.com/s?__biz=MzU5MjMzODY0NQ==&mid=2247483887&idx=1&sn=7c96e6f7eb48647f23cf924c50c3e9ad&chksm=fe200a55c9578343bc3f8f0c67ed52e041f4a7536d0e954509f2403b5056b91ad7e00be11fa8&scene=126&sessionid=1681442950#rd)

![每日安全看点](../Images/fe5d884dda10b09f2473cb6e49629d83.png)

---

### Web API安全

- **来源**：[Web API安全实战指南](https://mp.weixin.qq.com/s?__biz=MzAwNjA3MzEwNg==&mid=2651329712&idx=1&sn=e6afca8b64a906c3091ca206a25aa904&scene=21#wechat_redirect)
- **内容**：深入分析 Web API 安全常见漏洞类型、攻击面分析及防护策略，涵盖认证授权、输入验证、速率限制、数据加密等核心安全控制点。

---

### 【漏洞】4个Google Cloud Shell的漏洞

- **来源**：[阿里云先知社区](https://xz.aliyun.com/t/6982)
- **内容**：详细披露 Google Cloud Shell 环境中发现的 4 个安全漏洞，涉及权限提升、容器逃逸、敏感信息泄露等风险，附带漏洞复现步骤及影响范围分析。

---

### Vlunstack ATT&CK实战系列——红队实战（三）Writeup

- **来源**：[阿里云先知社区](https://xz.aliyun.com/t/6988?from=timeline)
- **内容**：基于 ATT&CK 框架的红队实战演练第三部分完整复盘，涵盖初始访问、权限维持、横向移动、凭证获取等战术技术的实战应用与检测规避技巧。
- **关联**：[[daily-security-digest-20191230]] 中延续了移动端渗透测试教程第4-6部分，形成系列化实战技能栈。

---

### 深入研究iOS代码签名

- **来源**：[Umangis Blog](https://blog.umangis.me/a-deep-dive-into-ios-code-signing/)
- **内容**：系统性剖析 iOS 代码签名机制，包括签名结构、Provisioning Profile 解析、Entitlements 权限控制、签名验证流程及常见绕过技术，为 iOS 逆向与安全分析提供理论基础。

---

### 通过浏览器缓存绕过SOP

- **来源**：[Enumerated Blog](https://enumerated.wordpress.com/2019/12/24/sop-bypass-via-browser-cache/)
- **内容**：探讨利用浏览器缓存机制绕过同源策略（SOP）的新型攻击手法，分析缓存污染、侧信道泄露等技术原理，演示跨域数据窃取的实战可行性。

---

### 【逆向】Nightmare - 逆向入门

- **来源**：[GitHub - guyinatuxedo/nightmare](https://github.com/guyinatuxedo/nightmare)
- **内容**：面向初学者的逆向工程入门教程系列，涵盖汇编基础、栈帧分析、函数调用约定、常见反调试技术识别及 IDA Pro/Ghidra 基础操作，配套练习题循序渐进。

---

### 移动端应用测试教程 1-3

- **Part 1**：[Mobile Application Pentesting Part 1](https://medium.com/@patilpiyush/mobile-application-pentesting-part-1-596e82e56e83)
  - 环境搭建、基础架构认证、静态分析入门、APK/IPA 解包与组件枚举
- **Part 2**：[Mobile Application Pentesting Part 2](https://medium.com/@patilpiyush/mobile-application-pentesting-part-2-feda7659eb12)
  - 动态分析技术、Frida/Hooking 实战、网络流量拦截、本地存储安全审计
- **Part 3**：[Mobile Application Pentesting Part 3](https://medium.com/@patilpiyush/mobile-application-pentesting-part-3-a9acbb487e6)
  - 高级攻击向量、加密实现缺陷、IPC 机制滥用、代码混淆绕过及自动化测试框架构建
- **后续**：[[daily-security-digest-20191230]] 继续更新第 4-6 部分，形成完整移动端渗透测试知识体系。

---

## 相关页面

- [[daily-security-digest-20191230]] - 2019年12月30日每日安全看点，延续移动端渗透测试教程及Fuzzing漏洞挖掘内容
- [[daily-security-digest-20200102]] - 2020年1月2日每日安全看点，涵盖机器学习恶意流量检测、微信RCE漏洞等
- [[daily-security-digest-20200113]] - 2020年1月13日每日安全看点，包含ATT&CK防御逃逸、SpringBoot RCE利用链等

## 来源

- [0th3rs安全团队-201911-202204_102](../sources/0th3rs安全团队-201911-202204_102.md)
