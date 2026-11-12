---
title: 每日安全看点 2020-02-24
description: 汇总 2020 年 2 月 24 日每日安全看点，涵盖 Android 厂商漏洞披露对比、APT 攻击 TTPs 分析方法、Linux SUID
  提权技术、手机定位追踪冠状病毒患者轨迹等内容。
category: ai-security
tags:
- 每日安全看点
- Android安全
- APT攻击
- TTPs
- Linux提权
- SUID
- 疫情追踪
- 隐私安全
- 2020年2月
date: 2020-02-24
updated: '2026-11-12'
---
## 概述

本期每日安全看点精选了四篇高质量技术文章，涉及移动安全厂商响应对比、高级持续性威胁 (APT) 战术技术与过程 (TTPs) 分析方法论、Linux 本地提权核心技术 SUID 机制深度解析，以及疫情背景下利用手机定位数据追踪患者轨迹的技术实现与隐私考量。

## Android 厂商漏洞披露对比：华为、三星、LG

> **来源链接**：[华为、三星、LG的Android漏洞披露哪家强](https://mp.weixin.qq.com/s?__biz=MzA5MzQ1MDI2MA==&mid=2456040341&idx=1&sn=b596e50ccac53c031cc1bdb9197d1c1b&scene=21#wechat_redirect)

**核心看点**：
- 横向对比主流 Android 手机厂商（华为、三星、LG）在漏洞披露流程、响应速度、补丁发布节奏及详情透明度方面的差异。
- 分析厂商安全公告的完整性，包括 CVE 编号分配、影响版本说明、修复方案获取途径等关键指标。
- 探讨厂商漏洞响应能力对用户设备安全生命周期的实际影响，为企业移动设备管理 (MDM) 策略制定提供参考依据。

## APT 攻击 TTPs 分析方法论

> **来源链接**：[APT 攻击方式及分析方法（针对 TTP 的描述）](https://projectsharp.org/2020/02/23/APT%20%E5%88%86%E6%9E%90%E5%8F%8A%20TTPs%20%E6%8F%90%E5%8F%96/?from=timeline&isappinstalled=0)

**核心看点**：
- 系统阐述基于 **MITRE ATT&CK** 框架对 APT 攻击战术 (Tactics)、技术 (Techniques) 与过程 (Procedures) 进行结构化描述的方法论。
- 详细拆解 TTP 提取流程：从威胁情报报告、样本沙箱行为、网络流量日志中识别关键行为模式，映射至 ATT&CK 矩阵技术编号 (如 T1059, T1003 等)。
- 强调行为分析而非单一 IOC (指标) 匹配的重要性，提升对未知变种攻击的检测与溯源能力。
- 适用于威胁狩猎、红队复盘及安全运营中心 (SOC) 告警归因分析场景。

## Linux SUID 提权技术深度解析

> **来源链接**：[谈一谈 Linux 与 suid 提权](https://www.leavesongs.com/PENETRATION/linux-suid-privilege-escalation.html)

**核心看点**：
- **原理剖析**：深入讲解 SUID (Set User ID) 位机制，即可执行文件以文件所有者 (通常为 root) 权限运行，而非调用者权限。
- **利用条件**：梳理可被利用的 SUID 二进制文件特征——内部调用外部命令未使用绝对路径、环境变量注入 (PATH/LD_PRELOAD)、Shell 转义功能 (如 `vim`, `find`, `bash` 等)、缓冲区溢出漏洞等。
- **实战技巧**：
    - **GTFOBins** 利用清单：收集常见可利用二进制文件的提权 Payload。
    - **环境变量劫持**：通过控制 `PATH` 或 `LD_PRELOAD` 劫持库加载顺序执行恶意代码。
    - **通配符注入**：利用 `tar`, `chmod`, `chown` 等命令的参数解析特性实现代码执行。
- **防御建议**：最小权限原则审计 SUID 文件、移除不必要的 SUID 位、使用 `capabilities` 替代 SUID、文件完整性监控 (FIM) 监控关键二进制变更。

## 手机定位追踪冠状病毒患者轨迹

> **来源链接**：[手机定位 | 快速锁定冠状病毒患者轨迹](https://mp.weixin.qq.com/s?__biz=MzIzMzE2OTQyNA==&mid=2648949608&idx=1&sn=d72bd43114827d7c85f728611385411a&scene=21#wechat_redirect)

**核心看点**：
- **技术手段**：介绍基于基站定位、GPS、Wi-Fi 探针、蓝牙信标及 APP SDK 采集的多源位置数据融合技术，实现人员轨迹高精度重构。
- **应用场景**：流行病学调查中密切接触者快速筛查、重点区域人员流动热力图分析、隔离人员电子围栏监管。
- **隐私与合规挑战**：
    - 数据最小化采集与脱敏处理 (差分隐私、联邦学习)。
    - 目的限制原则：数据仅用于疫情防控，严禁挪作他用。
    - 存储期限控制：疫情结束后依法销毁。
    - 法律依据：《网络安全法》、《个人信息保护法》(草案阶段) 及突发公共卫生事件应对条例。
- **社会价值与风险平衡**：探讨公共卫生紧急状态下个人隐私让渡的边界与治理规范。

## 关联阅读

- 下一期看点：[[daily-security-digest-20200225]]（RSAC 2020、Docker 安全、硬件调试 SWD/OpenOCD、Linux 文件描述符、MariaDB 提权漏洞）
- 后续看点：[[daily-security-digest-20200226]]、[[daily-security-digest-20200227]]、[[daily-security-digest-20200302]]
- 相关漏洞聚合视角：[[cve-digest-20200426]]（Windows 内核提权、Chrome V8 堆溢出等 PoC 聚合）
- 容器安全基础关联：[[docker-container-security-fundamentals]]（Namespace/Cgroup 隔离机制，与 Linux 提权防御相关）

## 来源

- [0th3rs安全团队-201911-202204_076](../sources/0th3rs安全团队-201911-202204_076.md)
