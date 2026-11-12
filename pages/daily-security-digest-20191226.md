---
title: 每日安全看点 2019-12-26
description: 2019年12月26日每日安全看点汇总，涵盖FLIRT符号恢复、Binary Ninja去混淆、区块链教程、Fuzzing会议资料、隐私安全、网络安全赛事及学术会议等技术资讯链接。
category: ai-security
tags:
- 每日安全看点
- 逆向工程
- FLIRT
- Binary Ninja
- OLLVM
- 区块链
- Fuzzing
- 隐私安全
- 网络安全竞赛
- 学术会议
- 2019年12月
date: 2019-12-26
updated: '2026-11-12'
---

## 概述

本页面汇总 2019 年 12 月 26 日「每日安全看点」推送的安全技术资讯，涉及逆向工程符号恢复、混淆对抗、区块链入门教程、Fuzzing 会议资料、隐私安全事件、行业赛事与学术会议等多个方向。可作为该日期安全动态的结构化索引，配合同系列页面（如 [[daily-security-digest-20191227]]、[[daily-security-digest-20191230]]、[[daily-security-digest-20200102]]）构建连续的安全情报时间线。

---

## 逆向工程与二进制分析

### FLIRT 符号恢复技术

- **主题**：利用 IDA FLIRT（Fast Library Identification and Recognition Technology）恢复静态编译程序中的库函数符号
- **来源**：阿里云安全技术分享
- **链接**：<https://xz.aliyun.com/t/4484>
- **关键点**：
  - 静态编译导致二进制体积膨胀且符号剥离，增加逆向难度
  - FLIRT 签名库可识别常见静态链接库函数（如 libc、OpenSSL、Boost 等）
  - 介绍 `.pat`/`.sig` 签名制作流程及 `pelf`/`pcf` 工具使用
  - 实战演示如何对静态编译的 CTF 题目/恶意样本快速还原函数名

### Binary Ninja 去除 OLLVM 控制流平坦化

- **主题**：基于 Binary Ninja 中级表达式（IL）编写插件，自动化还原 O-LLVM `Control Flow Flattening` 混淆
- **来源**：微信公众号技术文章
- **链接**：<https://mp.weixin.qq.com/s/h4rLdQ_GKxT2Nowv2F7tMg>
- **关键点**：
  - 分析平坦化后的 CFG 特征：调度器基本块 + 状态变量 `switch-case` 分发
  - 利用 BN MLIL/SSA 形式追踪状态变量赋值与跳转逻辑
  - 编写 Python 插件识别调度器、提取原始基本块顺序、重建自然控制流
  - 提供脚本下载与对比演示（混淆前/后反汇编视图）

> **关联阅读**：后续每日看点中亦多次出现逆向工程专题，如 [[daily-security-digest-20191227]] 涉及 Nightmare 逆向入门，[[daily-security-digest-20200114]] 涵盖 IoT 逆向函数识别。

---

## 区块链与密码学基础

### 深入浅出区块链系列教程

- **主题**：系统性区块链入门文档，覆盖比特币核心原理、共识机制、脚本系统、闪电网络等
- **来源**：LearnBlockchain 社区维护的开源教程
- **链接**：<https://wiki.learnblockchain.cn/bitcoin/readme.html>
- **章节结构**：
  1. 比特币白皮书逐段解读
  2. 交易与 UTXO 模型
  3. Script 脚本语言与可编程性
  4. 挖矿、难度调整与共识
  5. P2P 网络与 SPV 轻节点
  6. 隔离见证、Taproot 等升级提案
  7. 闪电网络与 Layer2 扩容
- **适用场景**：安全研究人员快速建立区块链威胁建模基础（如智能合约审计、共识攻击分析、跨链桥漏洞挖掘）

---

## Fuzzing 与漏洞挖掘

### Bay Area Fuzzing Meetup 会议资料

- **主题**：旧金山湾区 Fuzzing 技术聚会幻灯片与视频集合
- **来源**：GitHub 仓库 `FuzzTesting/BayAreaMeetups`
- **链接**：<https://github.com/FuzzTesting/BayAreaMeetups/>
- **典型议题**：
  - 覆盖率引导型 Fuzzing 最新进展（AFL++、LibFuzzer、Honggfuzz）
  - 结构感知 Fuzzing（Protobuf、WASM、内核系统调用）
  - 符号执行与 Fuzzing 混合策略（QSYM、Driller）
  - 真实漏洞挖掘案例分享（Chrome、Firefox、Linux Kernel、OpenSSL）
- **价值**：可作为 Fuzzing 方向文献追踪、工具链选型、会议演讲复现的一次性入口

> **关联阅读**：后续看点 [[daily-security-digest-20200120]] 提及 Fuzzing 平台建设，[[daily-security-digest-20200212]] 涉及 AFL++ 实战 Vim 漏洞挖掘。

---

## 隐私安全与物联网威胁

### 摄像头失控背后的「黑帽子」圣诞老人

- **主题**：家用智能摄像头被黑、隐私直播泄露事件分析及地下产业链揭露
- **来源**：FreeBuf 资讯
- **链接**：<https://www.freebuf.com/news/223729.html>
- **核心内容**：
  - 攻击面：弱默认口令、固件漏洞（CVE-2019-XXXX 系列）、云端 API 授权缺陷
  - 地下产业：扫描器、僵尸网络（Mirai 变种）、黑市售卖摄像头访问权限
  - 防护建议：修改默认凭证、固件升级、网络隔离、关闭 UPnP/公网映射
- **延伸关注**：IoT 设备大规模暴露问题，关联 [[daily-security-digest-20200114]]（小米路由器 R3G 漏洞）、[[daily-security-digest-20200224]]（Android 厂商漏洞披露对比）。

---

## 赛事与学术会议

### X-NUCA 2019 网络安全竞赛与技术论坛

- **主题**：西安市网络安全协会主办的年度赛事，含 CTF 决赛、漏洞挖掘马拉松、学术论坛
- **来源**：微信公众号赛事公告
- **链接**：<https://mp.weixin.qq.com/s/q_z2V_poL2nVprz_ZEci-A>
- **亮点**：
  - 面向高校/企业队伍的实战攻防赛制
  - 同期邀请国内外专家作 Web/二进制/密码学/AI 安全专题报告
  - 优胜队伍直通全国性赛事（如强网杯、CISC）

### 网安国际论坛·网络空间安全学术成果研讨会

- **主题**：聚焦前沿理论与工程落地的高水平学术会议
- **来源**：微信公众号会议通知
- **链接**：<https://mp.weixin.qq.com/s/vkZitFDRx7gs4naXUXzj6g>
- **议题方向**：
  - 密码学新假设与协议证明
  - 形式化验证在协议/系统安全中的应用
  - 联邦学习/隐私计算安全性
  - 关键基础设施供应链安全

> **关联阅读**：同系列看点 [[daily-security-digest-20191227]] 提及 Vlunstack ATT&CK 实战赛，[[daily-security-digest-20200211]] 涉及 RSA 2020 创新沙盒十强。

---

## 导航与关联页面

| 日期 | 页面 | 核心专题 |
|------|------|----------|
| 2019-12-27 | [[daily-security-digest-20191227]] | Web API 安全、Google Cloud Shell 漏洞、ATT&CK 实战、iOS 代码签名、SOP 绕过、Nightmare 逆向入门 |
| 2019-12-30 | [[daily-security-digest-20191230]] | Google XSS 技巧、Metasploit DoS (CVE-2019-5645)、移动端渗透测试 4-6、Fuzzing 漏洞挖掘艺术 |
| 2020-01-02 | [[daily-security-digest-20200102]] | KNN 恶意流量检测、微信 RCE (CVE-2019-17151)、Tesla Model S Wi-Fi 漏洞、供应链攻击防御 |
| 2020-01-13 | [[daily-security-digest-20200113]] | ATT&CK 防御逃逸、Kelinci Java Fuzz、SpringBoot+H2 RCE、PHP mt_rand 预测、Radare2 缓冲区溢出 |

---

## 标签索引

`#每日安全看点` `#逆向工程` `#FLIRT` `#Binary_Ninja` `#OLLVM` `#区块链` `#Fuzzing` `#隐私安全` `#网络安全竞赛` `#学术会议` `#2019年12月`

## 来源

- [0th3rs安全团队-201911-202204_103](../sources/0th3rs安全团队-201911-202204_103.md)
