---
title: 每日安全看点 2019-12-10
description: 汇总 2019 年 12 月 10 日每日安全看点，涵盖 H1ve 攻防训练平台、Linux 逆向 Hook 与注入、360 杀软绕过、Nexus
  CVE-2019-15588 漏洞、Java Web 安全知识库等资讯
category: ai-security
tags:
- 每日安全看点
- 2019年12月
- 攻防训练平台
- Linux逆向
- Hook技术
- 杀软绕过
- CVE-2019-15588
- Nexus
- Java Web安全
- 安全知识库
date: '2019-12-10'
updated: '2026-11-13'
---

## 概述

本期每日安全看点汇总了 2019 年 12 月 10 日的六条安全技术资讯，涵盖攻防训练平台开源、Linux 逆向工程实战、杀毒软件绕过技术、Nexus 组件漏洞披露、工程师成长思考以及 Java Web 安全知识库开源项目。

---

## 详细内容

### H1ve - 开源攻防训练平台

**来源**：阿里云先知社区  
**链接**：<https://xz.aliyun.com/t/6889>

H1ve 是一个开源的攻防训练平台，旨在为安全研究人员和爱好者提供实战化的靶场环境。平台集成了多种漏洞场景，支持 Web 漏洞、系统漏洞、逻辑漏洞等多类别的攻防演练。

**关键特性**：
- 模块化设计，易于扩展新的漏洞场景
- 支持多用户隔离环境
- 提供详细的漏洞原理文档与复现指导

> **关联阅读**：[[daily-security-digest-20191211]] 翌期看点中收录了 DroneSploit 无人机渗透测试框架，同属攻防工具体系；[[docker-container-security-fundamentals]] 梳理了容器安全核心机制，可作为搭建隔离靶场环境的参考。

---

### Linux 逆向之 Hook 与注入

**来源**：阿里云先知社区  
**链接**：<https://xz.aliyun.com/t/6883>

文章深入讲解 Linux 平台下的 Hook 技术与代码注入原理，涵盖：
- **LD_PRELOAD** 环境变量劫持动态链接库
- **ptrace** 系统调用实现进程附着与内存修改
- **PLT/GOT 表** 劫持机制
- **Inline Hook** 与 **Trampoline** 技术实现函数重定向
- 共享对象注入的实战技巧

适合逆向工程初学者及恶意软件分析人员构建基础知识体系。

> **关联阅读**：[[daily-security-digest-20191216]] 收录了 WinRAR 逆向破解、RealWorldCTF 2019 Safari 漏洞利用等逆向实战案例；[[daily-security-digest-20191226]] 涵盖 FLIRT 符号恢复、Binary Ninja 去混淆、OLLVM 混淆对抗等进阶逆向工程资源。

---

### 过 360 杀软

**来源**：微信公众号  
**链接**：<https://mp.weixin.qq.com/s/sPv0WvkOM7OsgxFgdd-T-Q>

实战分享绕过 360 杀毒软件查杀的技术路线，主要涉及：
- Shellcode 加密与编码混淆
- 内存执行技术（如 `VirtualAlloc` + `CreateThread`）
- 免杀框架（如 Cobalt Strike、Metasploit）的定制化 Loader 开发
- 行为规避：延迟执行、环境检测、父进程欺骗

> **关联阅读**：[[daily-security-digest-20191218]] 详细记录了 Cobalt Strike 免杀、SysWhispers 系统调用绕过 AV、勒索病毒报告等红队免杀技术栈；[[daily-security-digest-20200213]] 涵盖 CS Shellcode 免杀及 WAF 绕过 SQL 注入技巧。

---

### Nexus CVE-2019-15588 漏洞披露

**来源**：HackerOne  
**链接**：<https://hackerone.com/reports/688270>

Sonatype Nexus Repository Manager 存在远程代码执行漏洞（CVE-2019-15588），CVSS 评分高危。漏洞源于特定端点未正确验证用户输入，攻击者可通过构造恶意请求实现未授权 RCE。

**影响版本**：Nexus Repository Manager 3.x 特定版本范围  
**修复建议**：升级至官方发布的修复版本，限制管理端口网络暴露，启用强认证策略。

> **关联阅读**：[[cve-digest-20200426]]、[[cve-digest-20210325]] 等 CVE 聚合页面收录了同期多组件高危漏洞，可对比 Nexus 漏洞在供应链安全中的定位；[[spring-boot-actuator配置不当rce利用]]、[[spring-cloud-config目录穿越漏洞]] 涉及 Java 生态中间件常见配置不当导致的 RCE 利用链。

---

### 别让自己“墙”了自己

**来源**：酷壳  
**链接**：<https://coolshell.cn/articles/20276.html>

陈皓（左耳朵耗子）的经典随笔，从技术人成长角度探讨：
- 打破技术栈舒适区，主动接触新领域
- 避免“以偏概全”的认知局限
- 建立系统性知识体系而非碎片化收集
- 拥抱变化，持续学习底层原理

对安全从业者同样适用：安全技术迭代快，需跨越 Web/二进制/移动/云原生等领域边界构立全栈视野。

---

### Java Web 安全知识归纳总结与培训项目

**来源**：GitHub  
**仓库**：<https://github.com/anbai-inc/javaweb-sec>

anbai-inc 开源的 Java Web 安全知识库，系统梳理：
- Java Web 常见漏洞原理（SQLi、XSS、反序列化、SSRF、模板注入等）
- 主流框架安全配置与加固
- 漏洞复现环境搭建与 PoC 编写
- 安全开发生命周期（SDL）实践指南
- 培训课件与实战靶场

适合企业内部安全培训、开发人员安全意识提升及渗透测试人员查漏补缺。

> **关联阅读**：[[java-deserialization-fundamentals]] 系统梳理 Java 序列化/反序列化核心机制，为反序列化漏洞利用链分析奠定基础；[[spring-boot-actuator配置不当rce利用]]、[[spring-boot-devtools-deserialization-rce]]、[[spring-boot-spel表达式注入]]、[[spring-cloud-config目录穿越漏洞]] 详细记录 Spring 生态典型 RCE 利用链；[[h2-console-jndi注入rce利用]] 实战复现 H2 Database JNDI 注入 RCE 攻击链；[[jd-freefuck-panel-rce-analysis]] 分析默认弱口令结合命令执行接口的实战案例。

---

## 同期安全看点导航

| 日期 | 页面 | 核心看点 |
|------|------|----------|
| 2019-12-11 | [[daily-security-digest-20191211]] | DroneSploit、2019年网络攻击回顾、PHP sprintf漏洞、iOS内核漏洞 |
| 2019-12-12 | [[daily-security-digest-20191212]] | Apple AirDos、深度学习恶意软件分类、浏览器安全、JQ命令注入 |
| 2019-12-16 | [[daily-security-digest-20191216]] | 内网渗透、WinRAR逆向、Docker容器安全、RealWorldCTF Safari漏洞 |
| 2019-12-17 | [[daily-security-digest-20191217]] | 鱼叉式攻击、针孔摄像头检测、CTF PWN、远控免杀 |
| 2019-12-18 | [[daily-security-digest-20191218]] | TP-Link漏洞、比特币区块链隐藏C2、Cobalt Strike免杀、SysWhispers |
| 2019-12-19 | [[daily-security-digest-20191219]] | 区块链智能合约逆向、儿童GPS手表隐私、DLL镂空技术 |
| 2019-12-20 | [[daily-security-digest-20191220]] | APT-C-08蔓灵花、zzzphp SQL注入、Facebook数据泄露 |
| 2019-12-23 | [[daily-security-digest-20191223]] | ATT&CK/APT归因、Project Zero在野漏洞、Chrome RCE、Mozi僵尸网络 |
| 2019-12-24 | [[daily-security-digest-20191224]] | 内网穿透、PHP木马、零知识证明、Hypervisor虚拟化安全 |
| 2019-12-25 | [[daily-security-digest-20191225]] | 机器学习测试WAF、Django CVE-2019-19844、Empire 3.0 |
| 2019-12-26 | [[daily-security-digest-20191226]] | FLIRT符号恢复、Binary Ninja去混淆、Fuzzing会议资料 |
| 2019-12-27 | [[daily-security-digest-20191227]] | Web API安全、Google Cloud Shell漏洞、iOS代码签名、SOP绕过 |
| 2019-12-30 | [[daily-security-digest-20191230]] | Google XSS、Metasploit DoS、移动端渗透测试、Fuzzing漏洞挖掘 |

---

## 标签索引

#每日安全看点 #2019年12月 #攻防训练平台 #Linux逆向 #Hook技术 #注入技术 #杀软绕过 #免杀 #CVE-2019-15588 #Nexus #JavaWeb安全 #安全知识库 #供应链安全 #逆向工程 #红队技术

## 来源

- [0th3rs安全团队-201911-202204_116](../sources/0th3rs安全团队-201911-202204_116.md)
