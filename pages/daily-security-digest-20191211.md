---
title: 每日安全看点 - 2019年12月11日
description: 汇总 2019 年 12 月 11 日每日安全看点，涵盖无人机渗透测试框架 DroneSploit、2019 年全球重大网络攻击回顾、2010
  年代漏洞研究视角、Google Play 恶意应用绕过验证、PHP sprintf 格式化字符串漏洞、iOS 12.0.4 内核漏洞分析等安全资讯
category: ai-security
tags:
- 每日安全看点
- 2019年12月
- DroneSploit
- 无人机安全
- 网络攻击回顾
- 漏洞研究
- Google Play
- 恶意应用
- PHP漏洞
- 格式化字符串
- iOS内核漏洞
- Google Project Zero
date: 2019-12-11
updated: '2026-11-13'
---

## 概述

本期每日安全看点汇总了 2019 年 12 月 11 日的六条核心安全资讯，涵盖新兴攻击面（无人机）、年度威胁态势回顾、漏洞研究方法论演进、移动应用供应链安全、PHP 核心函数漏洞以及移动操作系统内核漏洞深度分析。

## 详细内容

### 无人机渗透测试框架 DroneSploit

**项目地址**：
- GitHub：https://github.com/dhondta/dronesploit
- Black Hat EU 2019 Arsenal 资料：https://github.com/dhondta/dronesploit/blob/master/docs/blackhat-eu19-arsenal.pdf

**要点**：
- DroneSploit 是首个专注于无人机渗透测试的开源框架
- 涵盖无人机通信协议分析、固件逆向、射频攻击、GPS 欺骗、C2 劫持等攻击面
- 框架模块化设计，支持主流消费级/工业级无人机平台
- Black Hat EU 2019 Arsenal 演示展示了端到端攻击链实战

**关联领域**：IoT 安全、射频安全、嵌入式设备渗透测试

### 2019 年全球重大网络攻击及数据泄露事件回顾

**来源**：FreeBuf《2019年全球重大网络攻击及数据泄露事件回顾》
**链接**：https://www.freebuf.com/articles/network/222565.html

**核心内容**：
- 统计 2019 年全球范围内影响面广、损失大的典型网络攻击事件
- 涵盖勒索软件攻击、供应链攻击、APT 活动、云配置错误导致的数据泄露、DDoS 攻击等类型
- 分析攻击向量演变趋势：凭证填充、VPN 漏洞利用、远程桌面暴露成为主要入口
- 给出企业安全防御建议：零信任架构、攻击面管理、威胁狩猎、事件响应预案演练

**趋势洞察**：2019 年标志着「以身份为新边界」的安全模式加速落地，传统边界防护失效加剧。

### 从研究者视角看漏洞研究之 2010 年代

**来源**：微信公众号文章
**链接**：https://mp.weixin.qq.com/s/UBZv0pd7Nr-o-NMxjV53RQ

**核心观点**：
- 回顾 2010-2019 十年间漏洞研究方法论的演进：从手工代码审计向自动化 Fuzzing、符号执行、污点分析、机器学习辅助挖掘转变
- 关键里程碑：AFL (2013) 掀起覆盖率引导 Fuzzing 热潮；Project Zero 成立 (2014) 推动 0day 公开披露规范化；CTF 竞技推动二进制利用技术快速迭代
- 漏洞类型焦点转移：内存破坏漏洞缓解技术 (CFI, PAC, MTE) 成熟，逻辑漏洞、侧信道攻击、硬件漏洞 (Spectre/Meltdown) 成为新战场
- 研究生态变化：漏洞赏金计划普及、漏洞买卖市场成熟、国家级网络武器库泄露 (Shadow Brokers) 改变威胁格局

### Google Play 中绕过 Google 验证机制的恶意应用（奇虎 libjiagu 库被用于加固）

**来源**：Evina 安全分析报告
**链接**：https://www.evina.fr/evina-security-analyst-found-a-new-trojan-family-on-google-play/

**关键发现**：
- 发现新型木马家族潜伏 Google Play 官方商店，下载量达数万级
- 恶意应用采用 **奇虎 360 libjiagu 加固库** 对 Dex 文件加密、反调试、反注入，显著提升静态分析难度
- 绕过 Google Play Protect 核心手法：动态加载解密 Payload、利用反射调用隐藏 API、滥用 Accessibility Service 实现权限提升
- C2 通信采用域前置、证书绑定绕过、流量混淆等反检测技术
- 归因分析指向特定威胁组织，涉及金融欺诈、短信拦截、设备指纹采集等功能模块

**启示**：应用加固服务可能被攻击者反向利用，应用商店审核需引入行为动态分析与威胁情报关联。

### PHP sprintf 格式化字符串漏洞

**来源**：微信公众号技术分析
**链接**：https://mp.weixin.qq.com/s/eEJPvbH7xwINjQvJGY_A_A

**漏洞详情**：
- **影响版本**：PHP 7.x 特定版本范围（需确认具体补丁版本）
- **根因**：`sprintf()`/`vsprintf()` 处理格式化字符串时，对 `%n` 等格式说明符的参数索引解析存在逻辑缺陷，导致栈内存任意写
- **攻击向量**：用户可控格式化字符串传入 `sprintf()`，结合参数索引操纵实现任意地址写入
- **利用条件**：应用代码直接拼接用户输入作为格式化字符串参数（如日志记录、模板渲染场景）
- **修复建议**：升级 PHP 至修复版本；代码层面禁止用户输入作为格式化字符串，改用固定格式模板

**关联知识**：格式化字符串漏洞是 C 语言经典漏洞类型，PHP 内核实现层面同理。可参考 [[cve-digest-20210406]] 中关于格式化字符串漏洞的聚合分析。

### iOS 12.0.4 内核漏洞过程分析

**来源**：Google Project Zero 博客《Sockpuppet: Walkthrough of a Kernel Vulnerability》
**链接**：https://googleprojectzero.blogspot.com/2019/12/sockpuppet-walkthrough-of-kernel.html

**技术深度解析**：
- **漏洞编号**：CVE-2019-8789 (SockPuppet)
- **漏洞类型**：XNU 内核 `socket` 子系统 Use-After-Free (UAF)
- **触发路径**：`setsockopt` 处理 `SO_NREAD`/`SO_NWRITE` 选项时，竞争条件导致 `so_rcv`/`so_snd` 缓冲区指针释放后重用
- **利用链构造**：
  1. 堆风水布局：喷射 `mbuf`/`socket` 对象控制释放内存
  2. 伪造 `sockbuf` 结构实现内核任意读写
  3. 绕过 PAC (Pointer Authentication Codes) 与 KTRR (Kernel Text Read-Only Region)
  4. 修改 `proc->p_ucred` 提权至 root，逃逸沙箱
- **缓解措施**：iOS 12.1.1 修复；后续版本引入 `kalloc_type` 隔离、指针认证强化、内核堆随机化增强

**研究价值**：Project Zero 详细披露了从漏洞发现、根因分析、利用原语构建到完整 Exploit 的全过程，是 iOS 内核漏洞利用技术演进的重要案例研究素材。

## 关联页面

- [[daily-security-digest-20191212]] - 翌日安全看点，涵盖 Apple AirDos 漏洞、深度学习恶意软件分类等
- [[daily-security-digest-20191216]] - 本周汇总，含内网渗透、WinRAR 逆向、Docker 容器安全、RealWorldCTF Safari 漏洞利用等
- [[daily-security-digest-20191220]] - 蔓花 APT-C-08 移动攻击分析、zzzphp SQL 注入等
- [[daily-security-digest-20191223]] - ATT&CK/APT 归因、Project Zero 在野漏洞统计、Chrome WebSQL RCE、Mozi 僵尸网络分析
- [[cve-digest-20210406]] - 格式化字符串漏洞聚合分析（关联 PHP sprintf 类漏洞）
- [[wechat-pc-v8-rce-0day-analysis]] - 微信 PC 版 V8 RCE 0day 分析（同属客户端浏览器内核漏洞利用领域）

## 时间线标签

`2019-12-11` `每日安全看点` `无人机安全` `威胁情报` `漏洞研究方法论` `移动应用安全` `PHP内核漏洞` `iOS内核利用` `Google Project Zero` `DroneSploit` `SockPuppet` `CVE-2019-8789` `libjiagu` `Google Play Protect` `格式化字符串漏洞` `Use-After-Free` `沙箱逃逸` `提权` `供应链攻击` `加固对抗`

## 来源

- [0th3rs安全团队-201911-202204_115](../sources/0th3rs安全团队-201911-202204_115.md)
