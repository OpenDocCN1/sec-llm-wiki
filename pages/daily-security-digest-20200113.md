---
title: 每日安全看点 2020-01-13
description: 汇总 2020 年 1 月 13 日安全动态：ATT&CK 防御逃逸技术、Kelinci Java Fuzz 工具、SpringBoot
  Actuator+H2 数据库 RCE 利用链、安全会议排名、纯 HTML 漏洞挖掘、PHP mt_rand 随机数预测、Radare2 缓冲区溢出分析等技术资源。
category: ai-security
tags:
- 每日安全看点
- ATT&CK
- Java Fuzz
- SpringBoot
- H2 Database
- RCE
- PHP mt_rand
- Radare2
- 缓冲区溢出
- 安全会议
- HTML 漏洞
date: 2020-01-13
updated: '2026-11-12'
---

## 概览

本期每日安全看点收录 8 个技术专题，涵盖 **威胁建模**、**Fuzzing 工具**、**漏洞利用链**、**学术资源**、**前端安全**、**密码学攻击**、**逆向分析** 等方向，为安全研究人员提供当日值得关注的技术文章与工具链接。

---

## ATT&CK 之防御逃逸

> **来源**：FreeBuf 专栏文章  
> **链接**：https://www.freebuf.com/articles/network/223910.html

系统梳理 MITRE ATT&CK 矩阵中 **Defense Evasion（防御逃逸）** 战术下的常用技术与子技术，包括但不限于：

- 禁用/修改安全工具
- 伪造签名与代码签名绕过
- 进程注入与 Hollow Process
- 时间戳篡改
- 日志清理与审计规则修改

适合红队人员在渗透后阶段参考，也可作为蓝队检测规则编写的基线。

---

## Kelinci：基于 AFL 的 Java 程序 Fuzz 工具

> **来源**：FreeBuf 工具介绍  
> **链接**：https://www.freebuf.com/sectool/224294.html

**Kelinci** 将 AFL（American Fuzzy Lop）的变异能力引入 JVM 生态，通过插桩字节码实现对 Java 程序的覆盖引导模糊测试。

| 特性 | 说明 |
|------|------|
| 目标语言 | Java / JVM 字节码 |
| 变异引擎 | AFL（C 语言实现）+ JNI 桥接 |
| 插桩方式 | 字节码重写（ASM/ByteBuddy） |
| 适用场景 | 解析器、序列化库、协议实现等纯 Java 组件 |

> 💡 同类工具还包括 **JQF**、**java-afl**、**jazzer** 等，可根据项目构建体系选择。

---

## SpringBoot Actuator + H2 Database RCE 利用链

> **来源**：spaceraccoon.dev 技术博客  
> **链接**：https://spaceraccoon.dev/remote-code-execution-in-three-acts-chaining-exposed-actuators-and-h2-database

详细复现 **SpringBoot 2.x Actuator 暴露 `env` 与 `restart` 端点** 结合 **H2 Database `CREATE ALIAS`** 实现远程代码执行的完整利用链（“三幕剧”）。

### 核心利用路径
1. **Actuator `/env` 端点** → 修改 `spring.datasource.hikari.connection-test-query` 或 `spring.datasource.url` 指向恶意 H2 Console
2. **Actuator `/restart` 端点** → 触发应用重载，使新数据源配置生效
3. **H2 `CREATE ALIAS`** → 定义 Java 静态方法别名，执行任意命令

### 相关知识页面
- [[spring-boot-actuator配置不当rce利用]] — 系统记录 Actuator 端点暴露、H2 RCE、Eureka XStream、SpEL 注入等完整利用链
- [[h2-console-jndi注入rce利用]] — H2 Console JNDI 注入 RCE 另一条利用路径
- [[spring-boot-devtools-deserialization-rce]] — DevTools 弱默认密钥导致的反序列化 RCE
- [[spring-boot-spel表达式注入]] — Whitelabel Error Page SpEL 表达式注入
- [[spring-cloud-config目录穿越漏洞]] — Spring Cloud Config 目录穿越（CVE-2020-5410）

> ⚠️ 防御建议：生产环境**禁用或强认证保护**所有 Actuator 端点；H2 Console 默认不应暴露公网；升级 Spring Boot 至 2.2.6+ / 2.3.0+ 修复相关默认配置。

---

## 安全会议排名（学术参考）

> **来源**：知乎专栏整理  
> **链接**：https://zhuanlan.zhihu.com/p/101558816

汇总国内外主流安全学术会议、顶会（CCF A/B/C 类）及行业会议的 **排名、影响因子、投稿周期、历史录用率** 等元信息，适合科研人员、高校师生选题投稿参考。

| 会议 | CCF 等级 | 领域 |
|------|----------|------|
| IEEE S&P (Oakland) | A | 系统安全、密码学、隐私 |
| ACM CCS | A | 计算机与通信安全 |
| USENIX Security | A | 系统与网络安全 |
| NDSS | A | 网络与分布式系统安全 |
| Black Hat / DEFCON | — | 行业技术会议（非学术排名） |

---

## 纯 HTML 的漏洞挖掘

> **来源**：Medium 技术文章  
> **链接**：https://medium.com/@know.0nix/hunting-good-bugs-with-only-html-d8fd40d17b38

展示**仅利用 HTML 标签与属性**（无 JavaScript）即可触发的安全问题：

- `<meta http-equiv="refresh">` 引导跳转钓鱼
- `<form>` + `autocomplete` 窃取凭据
- `<iframe sandbox>` 绕过 CSP 策略
- `<details>` / `<summary>` 点击劫持变体
- `accesskey` 全局快捷键劫持

> 💡 此类漏洞常被 WAF/前端过滤器忽略，适合在 CSP 严格、JS 执行受限的场景下挖掘。

---

## 破坏 PHP `mt_rand()` 随机性预测

> **来源**：ambionics.io 博客  
> **链接**：https://www.ambionics.io/blog/php-mt-rand-prediction

深入分析 **PHP `mt_rand()`（Mersenne Twister）** 伪随机数生成器的内部状态结构，演示如何通过**观测少量输出值（约 624 个 32-bit 整数）反推内部状态**，从而**预测后续所有随机数**。

### 攻击前提
- 同一进程多次调用 `mt_rand()` 且未重新播种
- 能够获取连续输出（如密码重置 Token、Session ID、CSRF Token 等）

### 缓解措施
- 使用 `random_int()` / `random_bytes()`（PHP 7+ CSPRNG）
- 避免在安全敏感场景使用 `mt_rand()`、`rand()`、`uniqid()`
- 定期 `mt_srand()` 重播种（但仍不具备前向安全性）

---

## 通过 Radare2 理解缓冲区溢出漏洞

> **来源**：rderik.com 技术博客  
> **链接**：https://rderik.com/blog/understanding-buffer-overflows-using-radare2/

以 **Radare2 (r2)** 为分析平台，逐步演示经典栈缓冲区溢出的**静态分析 → 动态调试 → 漏洞利用构造**全流程：

1. `aaa` 自动分析 → 识别函数、栈帧、字符串
2. `pdf @ sym.vuln` 反汇编易受攻击函数
3. `db main` 下断点 → `dc` 运行 → `drr` 查看寄存器
4. 计算偏移 → 构造 Payload 覆盖返回地址
5. `r2 -d ./vuln -e dbg.profile=...` 自动化调试脚本

> 🛠️ 适合初学者通过可视化逆向框架建立“栈布局 → 控制流劫持”的直观认知。

---

## 杂谈：科恩面试与实习感悟

> **来源**：微信公众号文章  
> **链接**：https://mp.weixin.qq.com/s/GiIIUZbzq2IOp5-arkUCfg

作者分享安全研究方向求职面试经历、实习期间的项目复盘、心态调整与技能树构建建议，适合**在校生/转行者**参考职业发展路径。

---

## 关联阅读

- [[daily-security-digest-20200114]] — 翌日看点：IoT 逆向、Citrix CVE-2019-19781、小米路由器 RCE、钓鱼攻击、Shellcode 编写等
- [[daily-security-digest-20200115]] — 后续看点：ThinkPHP 6.0、Weblogic RCE、NDSS 2020 论文、CurveBall 漏洞等
- [[remote-work-security-covid19-20200210]] — 疫情期远程办公安全专题（后续汇总）

---

## 标签索引

`#每日安全看点` `#ATT&CK` `#Java_Fuzz` `#Kelinci` `#SpringBoot` `#H2_Database` `#RCE` `#安全会议` `#HTML_漏洞` `#PHP_mt_rand` `#Radare2` `#缓冲区溢出` `#职业发展`

## 来源

- [0th3rs安全团队-201911-202204_096](../sources/0th3rs安全团队-201911-202204_096.md)
