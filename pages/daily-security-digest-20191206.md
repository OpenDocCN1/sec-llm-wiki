---
title: 每日安全看点 2019-12-06
description: 2019年12月6日每日安全看点汇总，涵盖网络空间测绘、ATT&CK应用、Strapi RCE、Java代码审计入门、XPath注入、newlib堆利用、2020安全趋势及Chrome扩展安全等资讯
category: ai-security
tags:
- 每日安全看点
- 2019年12月
- 网络空间测绘
- ATT&CK
- Strapi
- RCE
- Java代码审计
- XPath注入
- newlib
- 堆利用
- 安全趋势
- Chrome扩展安全
date: 2019-12-06
updated: '2026-11-13'
---

## 概述

本期每日安全看点汇总了 2019 年 12 月 6 日的安全技术资讯，涵盖威胁情报框架应用、CMS 远程代码执行漏洞、代码审计入门指南、XML 注入技术、嵌入式堆利用、年度安全趋势预测及浏览器扩展安全等多个方向。

## 威胁情报与攻防框架

### 网络空间测绘
- **资源链接**：[网络空间测绘](https://mp.weixin.qq.com/s/jffEOTF3n028USQujIzmmw)
- **要点**：介绍网络空间测绘的基本概念、工具及在资产发现、攻击面管理中的应用。

### ATT&CK 框架应用实践
- **资源链接**：[ATT&CK应用](https://mp.weixin.qq.com/s/YiPwcJkmzpHj_b4NCbXnDA)
- **要点**：探讨 MITRE ATT&CK 框架在威胁狩猎、检测规则编写、红队演练中的落地方法论。
- **关联阅读**：[[apt-c-08-mobile-attack-analysis]] 中对 APT-C-08 组织攻击链的 ATT&CK 技术标签映射分析。

### MITRE ATT&CK 官方资源仓库
- **资源链接**：[attack-website](https://github.com/mitre-attack/attack-website)
- **要点**：MITRE 官方维护的 ATT&CK 知识库前端代码，包含完整的战术、技术、子技术定义及导航结构，适合二次开发构建内部威胁情报平台。

## 漏洞分析与利用

### CVE-2019-19609：Strapi Framework 远程代码执行
- **资源链接**：[Strapi Framework RCE 分析](https://bittherapy.net/post/strapi-framework-remote-code-execution/)
- **要点**：
  - 影响版本：Strapi < 3.0.0-beta.17.4
  - 根因：反序列化处理不当，攻击者可通过恶意序列化对象实现 RCE
  - 利用链：利用 Node.js `serialize-javascript` 库缺陷，结合原型链污染触发任意代码执行
- **修复建议**：升级至 3.0.0-beta.17.4 或更高版本。

### StackOverflow 高赞 Java 代码片段存在漏洞
- **资源链接**：[FreeBuf 报道](https://www.freebuf.com/news/222093.html)
- **要点**：
  - 被复制最多的 Java 代码片段（约 6000+ 次复制）用于生成随机字符串，但实现存在偏差导致熵不足
  - 启示：代码克隆检测在漏洞挖掘中的价值——广泛复制的不安全模式可能批量引入风险
- **同文重复提示**：原文中“新闻”栏目重复收录此链接，已合并。

## 代码审计与安全开发

### Java 代码审计入门指南
- **资源链接**：[JavaCodeAudit](https://github.com/cn-panda/JavaCodeAudit)
- **要点**：
  - 系统梳理 Java Web 常见漏洞类型（SQLi、XSS、反序列化、SSRF、RCE 等）
  - 提供漏洞代码样例、审计思路、工具链推荐（SpotBugs、FindSecBugs、CodeQL 等）
  - 适合白盒审计入门者建立知识体系
- **关联阅读**：[[cmseasy-7.3.8-code-audit]] 实战审计案例；[[java-deserialization-fundamentals]] 反序列化基础机制。

## 注入攻击技术

### XPath 注入数据窃取
- **资源链接**：[Hacking XML Data](https://medium.com/swlh/hacking-xml-data-a64c870b0988)
- **要点**：
  - XPath 注入原理：用户输入未经过滤拼接进 XPath 查询，导致逻辑绕过或数据遍历
  - 盲注技术：利用 `substring()`、`count()`、`boolean()` 等函数逐字符提取 XML 数据
  - 实战场景：SAML 断言处理、XML 配置文件解析、Web 服务接口
- **防御**：参数化 XPath 查询、输入白名单校验、禁用外部实体解析。

## 二进制漏洞利用

### 嵌入式设备 C 运行库 newlib 的 unlink 堆利用
- **资源链接**：[newlib unlink heap exploitation](https://blog.infosectcbr.com.au/2019/12/newlib-unlink-heap-exploitation.html)
- **要点**：
  - 目标：newlib（嵌入式常用 libc）的 `malloc`/`free` 实现
  - 技术：经典 unlink 攻击利用堆块合并时的指针校验缺陷，通过伪造 chunk 实现任意地址写
  - 约束绕过：newlib 校验相对宽松（无 size 对齐强校验、无双向链表完整性检查），利用门槛低于 glibc
  - 适用场景：路由器、IoT 设备、工控设备固件漏洞利用开发

## 安全趋势与前瞻

### 年安全趋势研究
- **资源链接**：[FreeBuf 趋势分析](https://www.freebuf.com/articles/network/220732.html)
- **核心观点**：
  1. **APT 攻击方式转变**：更隐蔽的供应链攻击、云基础设施为目标、利用合法工具
  2. **勒索软件演进**：定向勒索、数据窃取+加密双重勒索、攻击备份系统
  3. **基础设施攻击增多**：DNS 劫持、BGP 劫持、证书透明度滥用、供水/电力等关键基础设施
  4. **云原生安全挑战**：容器逃逸、Kubernetes 配置错误、Serverless 攻击面
  5. **隐私法规驱动**：GDPR、CCPA 等合规要求倒逼数据安全建设
- **参考价值**：为年度安全规划、威胁建模、红蓝对抗演练提供方向性指引。

## 浏览器扩展安全

### 从 0 开始入门 Chrome Ext 安全（二）—— 安全的 Chrome Ext
- **资源链接**：[Chrome Ext 安全 Part 2](https://lorexxar.cn/2019/12/05/chrome-ext-2/)
- **要点**：
  - Manifest V2/V3 权限模型对比：`host_permissions` 与 `permissions` 分离、声明式网络请求替代 `webRequest`
  - 内容安全策略（CSP）配置最佳实践：禁止 `unsafe-eval`、`unsafe-inline`，配置 `script-src`、`object-src`
  - 消息传递验证：`externally_connectable` 限制外部通信、校验 `sender.id`
  - 存储安全：敏感数据避免写入 `localStorage`/`sync storage`，优先使用 `chrome.storage` 并加密
  - 典型漏洞案例：XSS（内容脚本注入）、权限过度申请、中间人劫持更新
- **系列定位**：面向扩展开发者与安全测试人员的系统性入门教程。

## 关联页面索引

- [[daily-security-digest-20191209]] — 12 月 9 日看点：Linux 逆向、Firefox 漏洞利用、YARA 规则生成
- [[daily-security-digest-20191210]] — 12 月 10 日看点：H1ve 平台、Linux Hook、Nexus 漏洞
- [[daily-security-digest-20191223]] — 12 月 23 日看点：ATT&CK/APT 归因、Chrome WebSQL RCE、Mozi 僵尸网络
- [[apt-c-08-mobile-attack-analysis]] — APT-C-08 移动端攻击 ATT&CK 映射分析
- [[cmseasy-7.3.8-code-audit]] — CMS 代码审计实战案例
- [[java-deserialization-fundamentals]] — Java 反序列化基础机制
- [[spring-boot-actuator配置不当rce利用]] — Spring Boot Actuator RCE 利用链（含反序列化、JNDI 注入）
- [[spring-boot-devtools-deserialization-rce]] — Spring Boot DevTools 反序列化 RCE 深度分析
- [[h2-console-jndi注入rce利用]] — H2 Database JNDI 注入 RCE 复现
- [[java-urlconnection-ssrf-protocol-bypass]] — Java URLConnection SSRF 协议绕过技术

## 标签总览

`每日安全看点` `2019年12月` `网络空间测绘` `ATT&CK` `Strapi` `RCE` `Java代码审计` `XPath注入` `newlib` `堆利用` `安全趋势` `Chrome扩展安全` `代码克隆检测` `嵌入式安全` `威胁情报` `漏洞分析`

## 来源

- [0th3rs安全团队-201911-202204_118](../sources/0th3rs安全团队-201911-202204_118.md)
