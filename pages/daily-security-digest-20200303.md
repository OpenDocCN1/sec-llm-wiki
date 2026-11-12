---
title: 每日安全看点 2020-03-03
description: 汇总 2020 年 3 月 3 日每日安全看点，涵盖红队 Shellcode 启动器、Joplin XSS 任意文件读取、Messenger
  无点击漏洞利用、AWS 文档签名绕过、CVE-2020-9546/7/8 及 Android 篡改检测研究
category: ai-security
tags:
- 每日安全看点
- 红队工具
- Shellcode
- Joplin
- XSS
- 任意文件读取
- Messenger
- 无点击漏洞
- AWS
- 文档签名绕过
- CVE-2020-9546
- CVE-2020-9547
- CVE-2020-9548
- Android安全
- 篡改检测
- 2020年3月
date: 2020-03-03
updated: '2026-11-12'
---

## 概述

本期每日安全看点汇总了 2020 年 3 月 3 日的安全技术资讯，涵盖红队工具开发、知名应用漏洞披露、云安全配置绕过、多个 CVE 漏洞分析以及 Android 应用安全防护研究等多个方向的内容。

## 红队工具：通用 Shellcode 启动器

### 核心内容
来自 Nagarro Security 博客的系列文章第一部分，详细介绍了红队行动中使用的**通用 Shellcode 启动器**技术。文章重点关注如何以隐蔽方式加载并执行 Shellcode，规避常见的端点检测与响应（EDR）方案。

### 技术要点
- Shellcode 加载器的基础架构设计
- 内存分配与权限修改技术（VirtualAlloc、VirtualProtect 等）
- 线程创建与执行流劫持方法
- 免杀对抗思路初探

> **参考链接**：[Evasive Shellcode Launchers - Part 1](https://www.nagarrosecurity.com/blog/evasive-shellcode-launchers)

## Joplin Markdown 笔记 XSS 任意文件读取漏洞 (CVE-2020-9038)

### 漏洞概况
Joplin 是一款开源的 Markdown 笔记应用，支持跨平台同步。研究者 Javier Olmedo 发现并披露了一个 **XSS 漏洞可导致任意文件读取** 的安全问题，编号为 **CVE-2020-9038**。

### 影响范围
- Joplin 桌面客户端（Electron 架构）
- 受影响版本：披露时的最新版本及之前版本

### 攻击链分析
1. **XSS 触发**：通过恶意构造的 Markdown 内容，在渲染阶段注入 JavaScript 代码
2. **Electron 上下文利用**：利用 Electron 的 `nodeIntegration` 或 `contextIsolation` 配置不当，突破渲染进程沙箱
3. **任意文件读取**：结合 Node.js `fs` 模块读取本地敏感文件（如 SSH 私钥、配置文件、数据库等）
4. **数据外带**：通过网络请求将窃取的文件内容发送至攻击者服务器

### 修复建议
- 升级至修复版本
- 确保 Electron 应用启用 `contextIsolation: true` 并禁用 `nodeIntegration`
- 对用户输入的 Markdown 内容实施严格的内容安全策略（CSP）与清洗

> **参考链接**：[CVE-2020-9038 GitHub 仓库](https://github.com/JavierOlmedo/CVE-2020-9038)

## Messenger 无点击漏洞利用

### 技术背景
由知名安全研究员 **saelo** 在 OffensiveCon 2020 大会上演示的 **Facebook Messenger 无点击（Zero-Click）漏洞利用** 技术。该利用链无需用户交互，仅通过发送特制消息即可在目标设备上实现代码执行。

### 核心利用链
- **攻击面**：Messenger 的消息解析与渲染管道（涉及 WebKit/JavaScriptCore）
- **漏洞类型**：内存破坏漏洞（Use-After-Free / Type Confusion 等）
- **利用技术**：
  - JIT 编译器优化逻辑缺陷利用
  - 堆喷射与堆布局控制
  - JIT 代码页读写权限翻转
  - ROP/JOP 链构建绕过 PAC（指针认证码）等缓解措施
- **沙箱逃逸**：结合渲染器沙箱逃逸漏洞实现完整设备控制

### 防御启示
- 即时通讯应用的消息解析组件是高风险攻击面
- 零点击漏洞对用户零感知，传统“勿点不明链接”防护失效
- 需要从架构层面引入更强隔离（如站点隔离、进程级沙箱、内存安全语言重写关键组件）

> **参考链接**：[OffensiveCon 2020 - No Clicks: Exploiting Messenger (PDF)](https://saelo.github.io/presentations/offensivecon_20_no_clicks.pdf)

## AWS 文档签名安全控制绕过

### 场景描述
作者 Ozgur Alp 在 Medium 上分享了一个 **AWS 文档签名安全控制绕过** 的实战案例。该绕过涉及 AWS 服务间请求签名验证机制的实现缺陷。

### 技术细节
- **签名机制**：AWS 使用 SigV4 对 API 请求进行签名，防止篡改与重放
- **绕过根因**：
  - 签名验证逻辑对某些 Header/参数的规范化处理不一致
  - 允许攻击者在不破坏签名的前提下注入额外参数或修改请求语义
  - 部分服务对签名覆盖范围校验不全（如未包含完整 URI、Query String 或 Body Hash）
- **影响**：可能导致权限提升、跨服务请求伪造、资源未授权访问等

### 缓解措施
- 严格遵循 SigV4 规范实现签名验证
- 启用 AWS IAM 条件键（如 `aws:SourceArn`、`aws:SourceAccount`）限制调用来源
- 定期审计自定义签名验证中间件逻辑

> **参考链接**：[Write-up: AWS Document Signing Security Control Bypass](https://medium.com/@ozguralp/write-up-aws-document-signing-security-control-bypass-2b13a9c22a4d)

## CVE-2020-9546 / CVE-2020-9547 / CVE-2020-9548 漏洞分析

### 漏洞概况
安恒研究院发布的分析文章详细介绍了三个连续编号的 CVE 漏洞，具体影响组件与类型需结合原文进一步确认，典型涉及 **内存破坏、权限提升或信息泄露** 等高危类型。

### 关键信息
- **CVE 编号**：CVE-2020-9546、CVE-2020-9547、CVE-2020-9548
- **发布时间**：2020 年 3 月前后
- **分析来源**：安恒研究院（Anquanke）

> **参考链接**：[安恒研究院分析文章](https://www.anquanke.com/post/id/200010)

## Android App 篡改检测研究

### 研究背景
Darvinci Tech 博客发表的技术文章，系统梳理了 **Android 应用完整性校验与篡改检测** 的多种实现方案，并提供可直接集成的验证代码示例。

### 核心检测技术
| 检测维度 | 典型实现方式 | 绕过难度 |
|----------|-------------|----------|
| **签名校验** | `PackageManager.getPackageInfo(GET_SIGNATURES)` 对比预置签名哈希 | 中（Hook getPackageInfo / 修改预置哈希） |
| **APK 文件哈希** | 读取自身 APK 文件计算 SHA-256/MD5 与内置值比对 | 中高（需 Hook 文件读取或修改内置值） |
| **代码完整性** | 校验 `classes.dex` / `base.apk` CRC32、校验关键类字节码 | 高（需精准 Hook 或重打包时保持一致） |
| **调试器检测** | `Debug.isDebuggerConnected()`、检测 `TracerPid`、ptrace 自反调试 | 低中（常规反调试对抗） |
| **运行环境异常** | 检测 Root（su 二进制、Magisk 特征）、模拟器指纹、Xposed/EdXposed/框架特征文件 | 中高（取决于隐藏方案成熟度） |
| **动态加载监控** | 监控 `DexClassLoader`/`PathClassLoader` 加载路径、检测插件化框架 | 中 |

### 代码集成建议
- 将检查逻辑分散在多个生命周期点（Application.onCreate、Activity.onResume、关键业务入口）
- 使用 NDK 将核心校验下沉至 native 层（`.so`），提高逆向分析与 Hook 成本
- 引入**白盒加密**保护关键常量（签名哈希、校验密钥）
- 结合**应用加固**（如 dex 加密、资源加密、控制流平坦化）提升整体防护等级

> **参考链接**：[Yet Another Tamper Detection in Android](https://darvincitech.wordpress.com/2020/03/01/yet-another-tamper-detection-in-android/)

## 关联阅读

- [[daily-security-digest-20200304]] — 2020 年 3 月 4 日每日安全看点
- [[daily-security-digest-20200306]] — 2020 年 3 月 6 日每日安全看点
- [[daily-security-digest-20200309]] — 2020 年 3 月 9 日每日安全看点
- [[daily-security-digest-20200311]] — 2020 年 3 月 11 日每日安全看点
- [[daily-security-digest-20200312]] — 2020 年 3 月 12 日每日安全看点
- [[daily-security-digest-20200316]] — 2020 年 3 月 16 日每日安全看点
- [[daily-security-digest-20200317]] — 2020 年 3 月 17 日每日安全看点
- [[daily-security-digest-20200318]] — 2020 年 3 月 18 日每日安全看点

## 时间线标签
`2020年3月` `每日安全看点` `红队工具` `漏洞分析` `云安全` `移动安全`

## 来源

- [0th3rs安全团队-201911-202204_070](../sources/0th3rs安全团队-201911-202204_070.md)
