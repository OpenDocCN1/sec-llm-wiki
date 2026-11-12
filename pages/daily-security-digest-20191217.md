---
title: 每日安全看点 2019-12-17
description: 2019年12月17日每日安全看点汇总，涵盖鱼叉式攻击分析、针孔摄像头检测、CTF PWN实战、远控免杀技术等安全资讯
category: ai-security
tags:
- 每日安全看点
- 2019年12月
- 鱼叉式攻击
- 针孔摄像头检测
- CTF PWN
- 远控免杀
- 腾讯安全招聘
date: 2019-12-17
updated: '2026-11-13'
---

## 概览

本期每日安全看点汇总了 2019 年 12 月 17 日的六条安全技术资讯，涵盖攻击技术分析、物理安全检测、CTF 实战复现、远控免杀技术专题及安全人才招聘等多个维度。

## 文章列表

### 除邮件以外的鱼叉式攻击分析

**来源**：xorl.wordpress.com  
**链接**：<https://xorl.wordpress.com/2019/12/16/bsides-cyprus-2019-beyond-phishing-emails/>

深度分析超越传统钓鱼邮件的鱼叉式攻击手法，探讨攻击者如何通过社交工程、供应链攻击、水坑攻击等多元化渠道实施定向渗透。文章源自 BSides Cyprus 2019 会议演讲内容。

> 关联主题：[[apt-c-08-mobile-attack-analysis]] 中亦涉及 APT 组织利用鱼叉式攻击投递移动端恶意样本的实战案例。

### 找出房间里的针孔摄像头，不靠肉眼靠什么

**来源**：微信公众号  
**链接**：<https://mp.weixin.qq.com/s/VvlUpup-wjZJSTZMxHypJg>

介绍检测隐蔽针孔摄像头的技术手段，包括红外扫描、射频信号检测、镜头反光识别、网络流量分析等非肉眼可见的检测方法，适用于酒店、民宿、会议室等隐私敏感场景。

> 关联领域：物理安全与 IoT 设备隐私保护，可参考 [[secquan-bugwarning-1071987-device-credential-leak]] 中关于设备未授权访问风险的分析。

### 【CTF】pwnhub内部赛 WP

**来源**：微信公众号  
**链接**：<https://mp.weixin.qq.com/s/2QKCM5kOuf-MvfjzOlO3Pg>

pwnhub 平台内部 CTF 比赛的 PWN 方向题目详细 Writeup，涵盖栈溢出、堆利用、格式化字符串、ROP 链构造等经典二进制漏洞利用技术的实战复现过程。

> 关联资源：更多 CTF Writeup 汇总可参考 [[ctftime-writeup-digest-20210325]] 等系列页面，涵盖 2021 年多场国际 CTF 赛事的 Pwn、Reverse、Web 等题目解析。

### 远控免杀专题文章（一）

**来源**：微信公众号  
**链接**：<https://mp.weixin.qq.com/s/3LZ_cj2gDC1bQATxqBfweg>

远控免杀技术专题第一部分，系统介绍 Shellcode 加载器免杀、进程注入技术（如进程镂空 Process Hollowing、APC 注入、线程劫持）、反沙箱与反虚拟机检测绕过、AV/EDR 规则对抗等核心对抗技术。

> 关联技术：[[daily-security-digest-20191218]] 中提及的 Cobalt Strike 免杀、SysWhispers 系统调用绕过 AV 等技术与此专题形成互补。

### 远控免杀专题文章（二）

**来源**：微信公众号  
**链接**：<https://mp.weixin.qq.com/s/1r0iakLpnLrjCrOp2gT10w>

远控免杀技术专题第二部分，深入探讨 C2 通信流量混淆、域前置、加密通道构建、动态域名生成算法 (DGA)、合法云服务滥用（如 GitHub、Cloudflare Workers 作为 C2 中转）等隐蔽通信技术，以及持久化与横向移动阶段的免杀实践。

> 关联阅读：[[daily-security-digest-20191218]] 涉及比特币区块链隐藏 C2 基础设施的创新技术；[[frp内网渗透应用]] 记录 frp 在内网渗透中搭建 Socks5 隧道、多级隧道串联等实战隧道技术。

### 【招聘】腾讯安全科恩实验室日常/寒假实习生招聘

**来源**：微信公众号  
**链接**：<https://mp.weixin.qq.com/s/84yPXaML0-tAu7-YyZe6Bw>

腾讯安全科恩实验室发布的日常实习生与寒假实习生招聘信息，岗位方向覆盖二进制安全、Web 安全、移动安全、密码学、AI 安全等多个研究方向，提供顶级安全研究平台与导师资源。

## 技术标签云

`鱼叉式攻击` `物理安全检测` `针孔摄像头` `CTF PWN` `二进制漏洞利用` `远控免杀` `Shellcode加载器` `进程注入` `C2隐蔽通信` `域前置` `DGA` `红队对抗` `安全招聘` `腾讯科恩实验室`

## 关联页面

- [[daily-security-digest-20191218]] — 翌日安全看点，涵盖 Cobalt Strike 免杀、SysWhispers 系统调用绕过等技术延伸
- [[daily-security-digest-20191219]] — 后续看点，包含 DLL 镂空技术详解等二进制对抗内容
- [[daily-security-digest-20191220]] — 蔓花 APT-C-08 移动攻击分析，关联鱼叉式攻击投递链条
- [[apt-c-08-mobile-attack-analysis]] — APT-C-08 组织移动端攻击深度解析，含鱼叉式钓鱼投递恶意 APK
- [[frp内网渗透应用]] — 内网渗透隧道技术实战，补充 C2 通信隐蔽通道构建
- [[ctftime-writeup-digest-20210325]] — CTF Writeup 汇总系列，提供更多 PWN/Reverse 实战参考
- [[secquan-bugwarning-1071987-device-credential-leak]] — 设备凭证泄露与未授权访问风险，关联 IoT 物理安全检测

## 来源

- [0th3rs安全团队-201911-202204_112](../sources/0th3rs安全团队-201911-202204_112.md)
