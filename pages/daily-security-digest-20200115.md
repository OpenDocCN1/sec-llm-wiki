---
title: 每日安全看点 2020-01-15
description: 汇总 2020 年 1 月 15 日安全动态：ThinkPHP 6.0 任意文件创建、Weblogic RCE (CVE-2020-2546/2551)、CSRF
  Token 前端获取技巧、NDSS 2020 论文列表、微软 CurveBall 加密欺骗漏洞 (CVE-2020-0601)、360 阻击 Win7 0day
  攻击及 CTF 在线题库资源
category: ai-security
tags:
- 每日安全看点
- ThinkPHP
- Weblogic
- CVE-2020-2546
- CVE-2020-2551
- CSRF
- NDSS 2020
- CVE-2020-0601
- CurveBall
- Windows 7
- 0day
- CTF
date: 2020-01-15
updated: '2026-11-12'
---

## 概述

本期每日安全看点汇总了 2020 年 1 月 15 日的关键安全动态，涵盖 Web 框架漏洞、中间件远程代码执行、前端安全技巧、顶级学术会议论文、密码学漏洞、操作系统生命周期结束后的 0day 攻击以及 CTF 学习资源。

## 主要安全动态

### ThinkPHP 6.0 任意文件创建漏洞

**风险通告来源**：[安全风险通告](https://mp.weixin.qq.com/s/qgjf55CWNXNNzmLQgzUOpQ)

ThinkPHP 6.0 版本存在任意文件创建漏洞，攻击者可利用该漏洞在服务器上创建任意文件，进而可能导致远程代码执行。建议使用 ThinkPHP 6.0 的用户尽快关注官方补丁并升级修复。

### Weblogic 远程代码执行漏洞 (CVE-2020-2546、CVE-2020-2551)

**威胁通告来源**：[威胁通告](https://mp.weixin.qq.com/s/Q-ZtX-7vt0JnjNbBmyuG0w)

Oracle Weblogic 曝出两个远程代码执行漏洞：
- **CVE-2020-2546**：IIOP 协议反序列化漏洞
- **CVE-2020-2551**：JNDI 注入导致的 RCE 漏洞

这两个漏洞均无需认证即可利用，影响范围广泛，建议 Weblogic 用户立即应用 Oracle 1 月关键补丁更新 (CPU)。

### CSRF Token 前端获取技巧思考

**文章来源**：[魔法才能打败魔法：关于获取 csrf-token 前端技巧思考](https://xz.aliyun.com/t/7084)

阿里云安全团队分享了关于前端获取 CSRF Token 的多种技巧与思考，包括：
- 通过 DOM 解析获取 meta 标签或表单隐藏字段中的 Token
- 利用 JavaScript 框架特性（如 Vue、React）获取全局状态中的 Token
- 通过 Ajax 拦截器自动附加 Token
- 绕过 SameSite Cookie 限制的场景分析

文章从攻防对抗角度探讨了 CSRF 防护的前端实现细节与潜在绕过路径。

### NDSS 2020 接收论文列表公开

**官方列表**：[NDSS 2020 Accepted Papers](https://www.ndss-symposium.org/ndss2020/accepted-papers/)

网络与分布式系统安全会议 (NDSS) 2020 公布了接收论文列表，涵盖网络安全、隐私保护、应用安全、密码学、系统安全等前沿研究方向，是学术界与工业界跟踪安全研究最新进展的重要参考。

### 微软修复 CurveBall 加密欺骗漏洞 (CVE-2020-0601)

**报道来源**：[Microsoft Patches Major Crypto Spoofing Bug](https://threatpost.com/microsoft-patches-crypto-bug/151842/)

微软在 1 月补丁周二修复了一个严重的加密欺骗漏洞 **CVE-2020-0601**（代号 CurveBall），该漏洞存在于 Windows CryptoAPI (crypt32.dll) 对椭圆曲线加密 (ECC) 证书的验证逻辑中。

**漏洞影响**：
- 攻击者可伪造任意代码签名证书，使恶意软件看起来像合法签名
- 可伪造 TLS 证书实施中间人攻击
- 影响 Windows 10、Windows Server 2016/2019 等版本

**关联阅读**：后续分析与 PoC 详见 [[daily-security-digest-20200117]] 中的 CVE-2020-0601 专题。

### 阻击 Win7 停服后首例“双星” 0day 攻击

**报道来源**：[360安全大脑阻击微软Win7停服后首例“双星”0day漏洞攻击](https://mp.weixin.qq.com/s/ofKKhLwB_6snc47yKHn8zA)

Windows 7 于 2020 年 1 月 14 日正式停止主流支持。次日，360 安全大脑捕获到首例针对 Win7 的“双星” 0day 攻击（利用了两个 0day 漏洞组合），并上线“Win 7 盾甲”提供免费防护。

**关键点**：
- 攻击链结合内核提权漏洞与浏览器沙箱逃逸漏洞
- 针对仍在使用 Win7 的用户，建议开启 360 盾甲防护或尽快迁移至受支持的操作系统
- 微软为企业用户提供付费扩展安全更新 (ESU)

### CTF 赛题在线图书馆资源

**资源来源**：[CTF赛题线上图书馆](https://mp.weixin.qq.com/s/cobllAGcMGZBQArifC9xNw)

推荐了一个 CTF 赛题在线练习平台汇总，包含多个国内外知名 CTF 平台的题目归档与 Writeup 链接，适合安全入门者与选手系统性练习 Web、Pwn、Reverse、Crypto、Forensics 等方向题目。

**关联资源**：更多 CTF Writeup 汇总可参考 [[ctftime-writeup-digest-20210325]] 等后续整理页面。

## 关联页面

- [[daily-security-digest-20200117]] - 后续两日看点，含 CVE-2020-0601 深度分析与 PoC
- [[daily-security-digest-20200120]] - 1 月 20 日看点，含 IE 0day CVE-2020-0674 等
- [[ctftime-writeup-digest-20210325]] - CTF Writeup 聚合资源参考

## 时间线摘要

| 时间 | 事件 |
|------|------|
| 2020-01-14 | Windows 7 正式停止主流支持 |
| 2020-01-15 | ThinkPHP 6.0 任意文件创建漏洞通告 |
| 2020-01-15 | Weblogic CVE-2020-2546/2551 RCE 漏洞通告 |
| 2020-01-15 | 微软发布 1 月补丁修复 CVE-2020-0601 (CurveBall) |
| 2020-01-15 | 360 捕获 Win7 停服后首例 0day 攻击，上线 Win7 盾甲 |
| 2020-01-15 | NDSS 2020 Accepted Papers 列表公开 |

## 防护建议

1. **ThinkPHP 用户**：升级至最新修复版本，排查是否已被利用创建可疑文件
2. **Weblogic 用户**：立即应用 Oracle 1 月 CPU 补丁，或临时禁用 IIOP/T3 协议
3. **Windows 用户**：尽快安装 2020-01 补丁周二更新，修复 CVE-2020-0601
4. **Win7 用户**：评估迁移计划，短期内开启第三方防护（如 360 盾甲）或购买 ESU
5. **开发人员**：参考 CSRF Token 前端获取技巧，审查前端防 CSRF 实现是否存在逻辑缺陷
6. **安全研究员**：关注 NDSS 2020 论文，跟踪前沿防御与攻击技术演进

## 来源

- [0th3rs安全团队-201911-202204_094](../sources/0th3rs安全团队-201911-202204_094.md)
