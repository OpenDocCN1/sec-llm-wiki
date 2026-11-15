---
title: 0xfafu攻防实验室微信公众号文章归档索引（2020年10月-2021年12月）
description: 0xfafu攻防实验室微信公众号在2020年10月至2021年12月期间发布文章的汇总索引页面，涵盖AI安全、网络安全攻防实战、CTF竞赛、漏洞分析等技术内容。新增
  FAFU01 战队 CISCN 2021 线上赛详细 Writeup 条目。
category: ai-security
tags:
- 0xfafu
- 攻防实验室
- 微信归档
- 文章索引
- 网络安全
- AI安全
- 2020年
- 2021年
- CTF
- 漏洞分析
date: '2021-12-31'
updated: '2026-11-15'
---

## 概述

本页面汇总 **0xfafu攻防实验室** 微信公众号在 **2020年10月至2021年12月** 期间发布的全部文章。该团队专注于 AI 安全、网络安全攻防实战、CTF 竞赛、漏洞挖掘与分析等前沿技术领域，文章风格偏向实战复现、源码级漏洞分析与红蓝对抗复盘。

> **数据来源**：微信公众号历史消息（[mp.weixin.qq.com](http://mp.weixin.qq.com)）
> **归档状态**：索引建立中，欢迎补充完善具体文章标题与链接

---

## 按月份浏览

### 2020年

#### 2020-10
- *待补充文章条目*

#### 2020-11
- *待补充文章条目*

#### 2020-12
- *待补充文章条目*

### 2021年

#### 2021-01
- *待补充文章条目*

#### 2021-02
- *待补充文章条目*

#### 2021-03
- *待补充文章条目*

#### 2021-04
- *待补充文章条目*

#### 2021-05
- *待补充文章条目*

#### 2021-06
- [[fafu01-ciscn-online-writeup]] **FAFU01-CISCN线上赛部分WP** — FAFU01战队在CISCN 2021 线上赛中的五道题目完整复现：SQL注入绕过information_schema过滤（无列名注入）、PHP源码泄露利用ReflectionMethod读取类注释、Session Upload Progress LFI Getshell、堆UAF结合Tcache Poisoning劫持malloc_hook、RSA三重攻击（低加密指数攻击/共模攻击/Coppersmith部分已知p攻击）。供稿人：FAFU01，编辑：A1andNS。

#### 2021-07
- *待补充文章条目*

#### 2021-08
- *待补充文章条目*

#### 2021-09
- *待补充文章条目*

#### 2021-10
- *待补充文章条目*

#### 2021-11
- *待补充文章条目*

#### 2021-12
- *待补充文章条目*

---

## 核心技术专题分类

| 专题方向 | 典型关键词 | 关联页面示例 |
|----------|------------|--------------|
| **AI 安全 / 对抗样本** | 对抗攻击、模型窃取、数据投毒、鲁棒性评估 | — |
| **CTF 竞赛 Writeup** | Crypto、Reverse、Pwn、Web、Misc | [[fafu01-ciscn-online-writeup]], [[0w1club-ctf-crypto-writeup-easyrsa-t9]], [[mtctf-2021-crypto-writeup]] |
| **漏洞复现与分析** | RCE、SQLi、SSRF、反序列化、0day | [[cve-2022-23131-zabbix-saml-auth-bypass]], [[spring-boot-actuator配置不当rce利用]] |
| **红蓝对抗 / HVV** | 免杀、C2、横向移动、域渗透 | [[hvv-2021-vulnerability-collection]], [[kerberos-golden-ticket-attack-mimikatz-implementation]] |
| **代码审计 / CMS 漏洞** | ThinkPHP、Spring Boot、ECShop、zzzphp | [[ecshop-414-sql-injection-analysis]], [[zzzphp-cve-2021-32605-rce]] |
| **移动端 / IoT 安全** | Android 逆向、蓝牙协议、固件分析 | [[apt-c-08-mobile-attack-analysis]], [[knob-bluetooth-bredr-key-negotiation-vulnerability]] |

---

## 同类团队归档对比

| 团队 | 归档时间跨度 | 侧重领域 | 索引页面 |
|------|--------------|----------|----------|
| **0th3rs** | 2019-11 ~ 2022-04 | CTF、AWD、漏洞分析、工具分享 | [[0th3rs-security-team-wechat-archive-201911-202204]] |
| **0x4d5a** | 2021-03 ~ 2022-09 | 漏洞分析、CTF、红蓝对抗 | [[0x4d5a-wechat-archive-202103-202209]] |
| **0x536d72** | 2021-12 ~ 2022-05 | 安全研究、技术分享 | [[0x536d72-wechat-archive-202112-202205]] |
| **0W1Club** | 2017-07 ~ 2022-07 | 校内 CTF、萌新培养、Web/Pwn/Reverse | [[0w1club-wechat-archive-201707-201903]], [[0w1club-wechat-archive-201908-202207]] |

---

## 如何贡献完善

1. **补充文章元数据**  
   若你保存了该期间的历史推送，请按以下格式向对应月份追加：
   ```markdown
   - [文章标题](原文链接) — 简要摘要（含核心技术点、CVE 编号、CTF 赛事名等）
   ```

2. **标注专题标签**  
   在摘要后追加 `#标签`，便于后续自动聚合生成专题页。

3. **交叉引用关联页**  
   文中涉及的漏洞、工具、赛事若已有独立页面，请用 `[[wikilink]]` 链接。

---

## 相关导航

- [[0th3rs-security-team-wechat-archive-201911-202204]] — 另一支活跃于同期的 CTF 战队公众号归档
- [[0x4d5a-wechat-archive-202103-202209]] — 2021 年起同期安全团队归档
- [[hvv-2021-vulnerability-collection]] — 2021 年 HVV 期间高危漏洞聚合，便于对照团队复现进度
- [[daily-security-digest-20200102]] — 每日安全看点系列，可作为同期外部威胁情报参考
- [[fafu01-ciscn-online-writeup]] — FAFU01 战队 CISCN 2021 线上赛详细 Writeup 独立页面

---

> **维护提示**  
> 本页面为**索引骨架**，核心价值在于“文章级条目”的完整度。建议以“月份+专题”双维度同步维护，后续可脚本化生成专题聚合页（如《0xfafu 2021 年 AI 安全专题合集》）。

## 来源

- [0xfafu攻防实验室-202010-202112_13](../sources/0xfafu攻防实验室-202010-202112_13.md)
