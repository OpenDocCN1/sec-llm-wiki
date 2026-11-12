---
title: 每日安全看点 2020-02-11
description: 汇总 2020 年 2 月 11 日每日安全看点，涵盖网络安全资源库、JavaScript 原型链污染分析、RSA 2020 创新沙盒十强、AWS
  Lambda Serverless 实践与安全、密码学精品课程推荐等内容。
category: ai-security
tags:
- 每日安全看点
- 网络安全资源
- JavaScript原型链污染
- RSA 2020
- AWS Lambda
- Serverless安全
- 密码学课程
date: 2020-02-11
updated: '2026-11-12'
---
## 概述

本期每日安全看点汇总了 2020 年 2 月 11 日的五条安全技术资讯，涵盖安全资源导航、Web 前端漏洞深度分析、安全行业创新风向标、云原生 Serverless 安全实践以及密码学学习路线推荐。

## 网络空间安全资源导航

> **awesome-cyber-security**  
> GitHub 仓库：[alphaSeclab/awesome-cyber-security](https://github.com/alphaSeclab/awesome-cyber-security)

系统性收集网络空间安全相关的工具、学习资料、论文、会议等资源，适合安全研究人员建立个人知识库或快速检索特定领域参考材料。

## JavaScript 原型链污染攻击深度解析

> **浅析 JavaScript 原型链污染攻击**  
> 先知社区：[https://xz.aliyun.com/t/7182](https://xz.aliyun.com/t/7182)

详细剖析 JavaScript 原型链污染的成因、利用方式及防御思路，涵盖 `__proto__`、`constructor.prototype`、`Object.create` 等污染向量，以及结合常见库（如 Lodash、jQuery）的实战利用链构造。

## RSA 2020 创新沙盒十强盘点

> **RSA 2020 创新沙盒决赛十强一览**  
> FreeBuf：[https://www.freebuf.com/articles/network/226895.html](https://www.freebuf.com/articles/network/226895.html)

梳理 RSA Conference 2020 创新沙盒入围的十家初创公司及其核心技术方向，反映当年安全创业最前沿的投资热点：云原生安全、数据隐私计算、API 安全、零信任架构、软件供应链安全等。

## AWS Lambda Serverless 实践与安全防护

> **AWS 无服务器 Lambda Hello World 实践与安全防护简析**  
> FreeBuf：[https://www.freebuf.com/articles/network/226014.html](https://www.freebuf.com/articles/network/226014.html)

从零开始部署 AWS Lambda 函数，演示 Serverless 架构下的身份认证（IAM 角色最小权限）、代码依赖供应链风险、环境变量敏感信息管理、VPC 隔离与网络访问控制、日志审计与异常检测等安全配置要点。可结合 [[docker-container-security-fundamentals]] 中的最小权限、命名空间隔离等容器安全原理对比理解 Serverless 运行时的安全边界差异。

## 密码学精品课程推荐汇总

> **密码学精品课程汇总**  
> 微信公众号：[https://mp.weixin.qq.com/s/wETirinJDf4hoi3OzJYOpg](https://mp.weixin.qq.com/s?__biz=MzI2NTUyODMwNA==&mid=2247484502&idx=1&sn=d99fc1e2e529acb2313eb6243eba9083&scene=21#wechat_redirect)

整理国内外高校、在线平台（Coursera、edX、B 站等）的经典密码学课程，涵盖对称/非对称加密、哈希函数、数字签名、零知识证明、同态加密、后量子密码学等模块，附带先修数学基础建议与实验环境搭建指引。

## 关联阅读

- [[daily-security-digest-20200212]] — 次日看点：机器学习对抗样本、Darkhotel APT 双 0day、Windows Defender 驱动分析、Chrome 漏洞利用、Docker Registry 代码泄露等
- [[daily-security-digest-20200213]] — XSS 扫描器开发、Pwn 堆入门、Django SQL 注入 POC、移动端安全清单、Cobalt Strike 免杀与 WAF 绕过
- [[daily-security-digest-20200214]] — Android 逆向工具 GDA、angr 自动化漏洞利用、Safari RCE、分布式暴力破解工具 Kraken
- [[daily-security-digest-20200217]] — 新冠钓鱼攻击、2019 开源十大漏洞、Ghidra 逆向、ARM ROP、代码相似性、Shodan 渗透指南、DNSSEC、云环境 SSRF 检测防御
- [[daily-security-digest-20200218]] — 红队资源合集、PortSwigger 2019 十大 Web 攻击技术、奇安信 APT 2019 报告、WordPress 漏洞、勒索病毒报告、隐私友好软件、安全支出趋势

## 来源

- [0th3rs安全团队-201911-202204_084](../sources/0th3rs安全团队-201911-202204_084.md)
