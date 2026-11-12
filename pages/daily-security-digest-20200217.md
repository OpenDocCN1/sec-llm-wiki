---
title: 每日安全看点 2020-02-17
description: 汇总 2020 年 2 月 17 日每日安全看点，涵盖新冠病毒主题钓鱼攻击分析、2019 年开源软件十大漏洞、Ghidra 逆向破解 Sketch、ARM
  架构 ROP 利用、代码相似性研究综述、Shodan 渗透测试指南、DNSSEC 原理分析及云环境 SSRF 检测防御（以 AWS 为例）等内容。
category: ai-security
tags:
- 每日安全看点
- 钓鱼攻击
- 开源漏洞
- 逆向工程
- ARM ROP
- 代码相似性
- Shodan
- DNSSEC
- SSRF
- 云安全
- AWS
date: '2020-02-17'
updated: '2026-11-12'
---

## 概述

本期每日安全看点汇总了 2020 年 2 月 17 日的八项安全技术资讯，涵盖威胁情报、漏洞研究、逆向工程、程序分析、渗透测试工具、协议安全及云环境防御等多个方向。正值新冠疫情早期，攻击者利用疫情主题开展钓鱼活动成为热点；同时开源供应链安全、二进制逆向与漏洞利用技术、云原生安全等议题持续受到关注。

## 新冠病毒主题钓鱼攻击分析

**来源**：Trustwave SpiderLabs Blog  
**链接**：<https://www.trustwave.com/en-us/resources/blogs/spiderlabs-blog/multiple-phishing-attacks-discovered-using-the-coronavirus-theme/>

Trustwave SpiderLabs 团队披露了多起利用新型冠状病毒（COVID-19）主题的邮件钓鱼攻击活动。攻击者伪装成世界卫生组织（WHO）、疾病控制中心（CDC）等权威机构，诱导受害者点击恶意链接或下载携带恶意软件的附件。主要攻击向量包括：

- 伪造的疫情通报、防护指南 PDF 附件，内嵌恶意宏或漏洞利用代码
- 钓鱼页面收集凭证、个人信息或投放远控木马
- 利用社会工程学制造紧迫感，降低受害者警惕性

**防御建议**：部署邮件网关过滤、开展员工安全意识培训、启用多因素认证（MFA）、监控异常登录行为。

## 2019 年开源软件十大漏洞

**来源**：WhiteSource Blog  
**链接**：<https://resources.whitesourcesoftware.com/blog-whitesource/top-security-open-source-vulnerabilities>

WhiteSource 发布 2019 年度开源软件十大安全漏洞榜单，基于其漏洞数据库统计。榜单反映了开源组件在企业应用中的广泛使用及其带来的供应链安全风险。典型漏洞类型包括：

- 远程代码执行（RCE）
- 权限提升
- 信息泄露
- 拒绝服务（DoS）

**关键启示**：企业需建立软件物料清单（SBOM），持续监控依赖组件的 CVE 披露，自动化补丁管理流程，纳入 DevSecOps 流水线。

## 使用 Ghidra 分析并破解 Sketch 软件

**来源**：Duraki's Blog  
**链接**：<https://duraki.github.io/posts/o/20200214-sketch.app-patch-in-ghidra.html>

作者演示如何使用 NSA 开源的逆向工程框架 **Ghidra** 对 macOS 设计工具 Sketch 进行静态分析，定位许可证验证逻辑并实现补丁破解。核心步骤包括：

1. 将 Sketch 二进制文件导入 Ghidra，自动识别 Objective-C 运行时结构
2. 通过字符串搜索（如 "license"、"trial"、"validate"）定位关键类与方法
3. 利用 Ghidra 的反编译视图分析控制流，找到授权检查的判断分支
4. 修补二进制指令（如将条件跳转改为无条件跳转）绕过验证

该案例展示了 Ghidra 在 macOS/mach-O 二进制分析中的实用能力，也反映了软件保护机制对抗的技术演进。

## ARM 架构 ROP 利用实战记录

**来源**：微信公众号文章  
**链接**：<https://mp.weixin.qq.com/s/G1ozzLm-jIO2lDLh9-KjPw>

文章详细记录了一次基于 ARM 架构的返回导向编程（ROP）漏洞利用过程。主要技术点：

- ARM 指令集特性（Thumb 模式、条件执行、寄存器约定）对 ROP 链构造的影响
- 利用 `pop {pc}`、`bx sp` 等 gadget 控制程序流
- 绕过 ASLR、NX/DEP 等缓解措施的技巧（信息泄露、栈迁移）
- 实战调试与 payload 构建细节

ARM 平台（移动设备、IoT、嵌入式设备）的普及使得 ARM 漏洞利用技能成为安全研究者必备。

## 代码相似性研究综述

**来源**：arXiv 预印本 (1909.11424)  
**链接**：<https://arxiv.org/pdf/1909.11424.pdf>

该综述系统梳理了代码相似性检测领域的学术研究进展，涵盖：

- **静态方法**：基于令牌、AST、CFG、PDG 的结构相似性度量
- **动态方法**：基于执行轨迹、系统调用序列的行为相似性
- **机器学习/深度学习方法**：code2vec、code2seq、Graph Neural Networks 等嵌入式表示学习
- **应用场景**：漏洞克隆检测、恶意代码变种识别、抄袭检测、补丁分析、二进制代码匹配

文中对比分了主流工具（如 SSDEEP、BinDiff、VulSeeker、Gemini、SAFE）的优劣，指出跨架构、跨编译优化级别的鲁棒性仍是核心挑战。

## Shodan 渗透测试指南

**来源**：TurgenSec Community  
**链接**：<https://community.turgensec.com/shodan-pentesting-guide/>

Shodan 作为“互联网设备搜索引擎”，是资产发现与攻击面测绘的核心工具。指南涵盖：

- **基础查询语法**：端口、服务、产品、版本、地理位置、组织、SSL 指纹、HTTP 标题等过滤器
- **高级用法**：Favicon 哈希关联、漏洞 CVE 标签筛选、API 自动化脚本
- **实战场景**：
  - 发现暴露在公网的管理接口（RDP、SSH、VNC、数据库、IoT 设备）
  - 识别未修补的已知漏洞组件（如旧版本 Web 服务器、CMS、VPN 网关）
  - 供应链资产监测（子公司、关联域名、云存储桶）
- **配合工具**：`shodan-cli`、Python SDK、Nmap 联动扫描

合规前提下，Shodan 是红队侦察、蓝队资产梳理、威胁情报收集的力乘数。

## DNSSEC 原理与分析

**来源**：TheCJW's Blog  
**链接**：<https://blog.thecjw.me/?p=1221>

文章深入解析 **DNSSEC（DNS Security Extensions）** 的核心机制，旨在解决 DNS 协议固有的缓存投毒、中间人篡改风险。关键概念：

- **信任链**：根区 → 顶级域 → 权威域，层层签名验证
- **资源记录类型**：
  - `DNSKEY`：公钥
  - `RRSIG`：记录集签名
  - `DS`：委派签名（指向子区 DNSKEY 的哈希）
  - `NSEC`/`NSEC3`：认证不存在（防止区域枚举）
- **验证流程**：解析器递归查询，自顶向下验证签名链
- **部署现状与挑战**：密钥滚换复杂性、NSEC3 枚举风险、大包分片导致的可用性问题、验证端部署率

DNSSEC 与 DoH/DoT、RPKI 共同构建更可信的互联网基础设施安全体系。

## 云环境 SSRF 检测与防御（以 AWS 为例）

**来源**：阿里云先知社区  
**链接**：<https://xz.aliyun.com/t/7198>

文章针对 **服务端请求伪造（SSRF）** 在云环境下的特殊攻击面展开分析，以 AWS 为例阐述检测与防御策略。云环境 SSRF 风险放大的原因：

- **元数据服务**：`http://169.254.169.254/latest/meta-data/` 可获取 IAM 角色临时凭证、实例 ID、网络配置等敏感信息
- **内网服务访问**：绕过安全组、访问 VPC 内部 RDS、Redis、Kubernetes API Server 等
- **协议扩展**：`file://`、`gopher://`、`dict://` 等协议实现文件读取、任意 TCP 交互

**检测手段**：

- WAF 规则拦截可疑 URL 模式（内网 IP 段、元数据端点、非标准协议）
- 应用层日志审计：出站请求目标、频率、响应码异常分析
- VPC 流日志关联：识别异常的实例间访问模式

**防御措施**：

- **IMDSv2 强制使用**：要求会话令牌，防止无状态 SSRF 窃取凭证
- **最小权限 IAM 角色**：实例角色仅授予必要权限，减少凭证泄露影响
- **网络层隔离**：安全组出站规则限制、VPC 端点策略、私有链接
- **应用层防护**：URL 白名单、禁止重定向、限制协议、请求超时、响应大小限制
- **运维审计**：定期轮换密钥、启用 CloudTrail 记录 API 调用

云原生安全需要“纵深防御”理念，从网络、身份、应用、数据多层面构建 SSRF 防线。

## 关联知识页面

- [[daily-security-digest-20200218]] — 2020-02-18 每日安全看点，涵盖红队资源、PortSwigger 年度榜单、APT 报告等
- [[daily-security-digest-20200220]] — 2020-02-20 每日安全看点，含 GitHub 敏感信息采集、以太坊蜜罐、SQL Server RCE 等
- [[daily-security-digest-20200221]] — 2020-02-21 每日安全看点，聚焦 Tomcat AJP 漏洞 (CVE-2020-1938)、iOS 虚拟机等
- [[cve-digest-20200426]] — 2020-04-26 CVE 漏洞聚合，含 Windows 提权、Chrome/Firefox 漏洞等
- [[frp内网渗透应用]] — frp 内网穿透在渗透测试中的典型应用场景
- [[java-urlconnection-ssrf-protocol-bypass]] — Java URLConnection 协议前缀绕过 SSRF 黑名单的技术细节
- [[spring-cloud-config目录穿越漏洞]] — Spring Cloud Config 目录穿越 (CVE-2020-5410) 利用分析
- [[spring-boot-actuator配置不当rce利用]] — Spring Boot Actuator 暴露导致的 RCE 利用链
- [[docker-container-security-fundamentals]] — Docker 容器安全核心机制体系梳理
- [[elastic-stack-vulnerabilities-may2021]] — Elastic Stack 组件 2021 年 5 月披露的多个安全漏洞汇总

## 来源

- [0th3rs安全团队-201911-202204_080](../sources/0th3rs安全团队-201911-202204_080.md)
