---
title: 每日安全看点 2019-11-27
description: 2019年11月27日每日安全看点汇总，涵盖uClibc unlink堆利用、勒索病毒常用漏洞工具、Chrome沙箱逃逸PoC、Pwn2Own
  WebKit漏洞分析、Java反序列化原理、Wasm逆向静态分析、HTTP API认证授权及AppLocker详解等安全资讯。
category: ai-security
tags:
- 每日安全看点
- 2019年11月
- 堆利用
- uClibc
- 勒索病毒
- Chrome沙箱逃逸
- WebKit
- Pwn2Own
- Java反序列化
- Wasm逆向
- API安全
- AppLocker
date: 2019-11-27
updated: '2026-11-13'
---
# 每日安全看点 2019-11-27

## 概述
本期汇总了 2019 年 11 月 27 日的安全技术资讯，涉及堆漏洞利用、勒索病毒工具链、浏览器沙箱逃逸、顶级竞赛漏洞分析、Java 反序列化原理、WebAssembly 逆向、API 认证授权体系及 Windows AppLocker 机制详解等多个方向。

---

## 堆漏洞利用：uClibc unlink 利用技术
- **主题**：嵌入式 Linux 广泛使用的 uClibc 堆管理器中的 unlink 利用方法。
- **来源**：[uClibc unlink heap exploitation](https://blog.infosectcbr.com.au/2019/11/uclibc-unlink-heap-exploitation.html)
- **要点**：分析 uClibc 内存分配器的实现细节，演示如何通过构造恶意 chunk 触发 unlink 操作实现任意地址写入，适用于路由器、IoT 设备等嵌入式场景的漏洞挖掘与利用。

---

## 威胁情报：近几年勒索病毒常用的漏洞与工具
- **主题**：梳理勒索病毒家族常利用的漏洞类型（如永恒之蓝、RDP 暴力破解、WebLogic/Struts2 等中间件漏洞）及常用攻击工具（Mimikatz、PsExec、Cobalt Strike 等）。
- **来源**：[FreeBuf 文章](https://www.freebuf.com/articles/system/219837.html)
- **要点**：从攻击面视角总结勒索病毒的初始入侵、横向移动、权限提升及文件加密全链路工具集，为防御部署提供参考。

---

## 浏览器安全：Chrome 沙箱逃逸 PoC
- **主题**：Chrome 浏览器沙箱逃逸的概念验证代码仓库。
- **来源**：[chrome-sbx-db](https://github.com/allpaca/chrome-sbx-db)
- **要点**：收集了多个历史版本 Chrome 沙箱逃逸漏洞的 PoC，涉及 Mojo IPC、Renderer 进程逃逸、GPU 进程漏洞等攻击面，适合浏览器安全研究者复现与学习。

---

## 竞赛漏洞分析：Pwn2Own 使用的 WebKit 漏洞深度解析
- **主题**：ZDI 博客详细分析 Pwn2Own 2019 比赛中获胜选手利用的 WebKit 漏洞。
- **来源**：[Diving Deep into a Pwn2Own Winning WebKit Bug](https://www.thezdi.com/blog/2019/11/25/diving-deep-into-a-pwn2own-winning-webkit-bug)
- **要点**：剖析 JavaScriptCore 引擎中的类型混淆或 JIT 优化逻辑缺陷，展示从漏洞触发到任意代码执行的完整利用链构造过程。

---

## Java 安全：Java 反序列化漏洞原理解析
- **主题**：系统性讲解 Java 反序列化漏洞的底层机制、Gadget Chain 构造原理及常见利用链（CommonsCollections、Jdk7u21 等）。
- **来源**：[阿里云安全](https://xz.aliyun.com/t/6787)
- **关联**：[[java-deserialization-fundamentals]] 页面系统梳理了 Java 序列化/反序列化核心机制（Serializable、Externalizable、serialVersionUID、ObjectInputStream/OutputStream），可作为本文的基础知识延伸阅读。

---

## 逆向工程：一种 Wasm 逆向静态分析方法
- **主题**：针对 WebAssembly (Wasm) 二进制模块的静态分析思路与工具实践。
- **来源**：[阿里云安全](https://xz.aliyun.com/t/5170)
- **要点**：介绍 Wasm 结构特点（模块、段、指令集），结合 IDA Pro、Ghidra 及开源工具（wasm2wat、wabt）进行控制流恢复、函数识别、导入导出分析，辅助恶意 Wasm 样本（如挖矿、混淆逻辑）分析。

---

## Web 安全：HTTP API 认证授权术
- **主题**：酷壳博客深度长文，系统梳理 HTTP API 认证与授权的演进历程、主流方案对比及最佳实践。
- **来源**：[HTTP API 认证授权术](https://coolshell.cn/articles/19395.html)
- **要点**：
  - 基础认证、Digest 认证、Session-Cookie、Token-Based (JWT、Opaque Token)、OAuth 2.0 / OpenID Connect、API Key、mTLS 等方案优缺点。
  - 授权模型：RBAC、ABAC、PBAC。
  - 刷新令牌轮换、短期访问令牌、撤销机制、防重放、PKCE 等安全增强细节。

---

## 终端安全：详解 AppLocker（Part 3）
- **主题**：Windows AppLocker 应用程序控制策略的深度配置与绕过测试第三部分。
- **来源**：[安详科技](https://www.anquanke.com/post/id/193567)
- **要点**：聚焦 AppLocker 规则的高级配置（发布者规则、哈希规则、路径规则组合）、脚本拦截（PowerShell、WSF、JScript/VBScript）、DLL 绑定规则、配合 WDAC (Windows Defender Application Control) 的防御纵深部署，以及常见绕过技术（安装程序滥用、签名劫持、COM 对象滥用）的检测与缓解。

---

## 关联阅读
- [[daily-security-digest-20191128]] - 翌日安全看点（AWD、VS Online、Peach Fuzzing 等）
- [[daily-security-digest-20191129]] - 后日安全看点（XSS、Frida、PHP 0day 等）
- [[java-deserialization-fundamentals]] - Java 序列化/反序列化核心机制基础页
- [[0th3rs-security-team-wechat-archive-201911-202204]] - 0th3rs 安全团队微信归档总索引（含 2019 年 11 月起文章）

---

> 本页面基于 0th3rs 安全团队微信公众号 2019-11-27 推送内容整理，旨在构建结构化、可交叉引用的安全知识库。

## 来源

- [0th3rs安全团队-201911-202204_126](../sources/0th3rs安全团队-201911-202204_126.md)
