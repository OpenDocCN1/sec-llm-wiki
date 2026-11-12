---
title: 每日安全看点 2020-02-18
description: 汇总 2020 年 2 月 18 日每日安全看点，涵盖红队资源合集、PortSwigger 2019 年度十大 Web 攻击技术、奇安信
  APT 2019 报告、WordPress 主题插件漏洞、勒索病毒年度报告、隐私友好软件清单及网络安全支出趋势。
category: ai-security
tags:
- 每日安全看点
- 红队资源
- PortSwigger
- APT报告
- WordPress漏洞
- 勒索病毒
- 隐私保护
- 安全支出趋势
- 2020年2月
date: 2020-02-18
updated: '2026-11-12'
---

## 概述

本期每日安全看点汇总了 2020 年 2 月 18 日的七条安全资讯，涵盖实战资源、年度技术盘点、威胁情报报告、漏洞预警、隐私工具清单及行业趋势分析，为安全从业者提供全方位的知识摄入。

## 红队实战资源合集

### 国外红队常用的 21 种资源

FreeBuf 发布的资源整理文章，系统梳理红队作业中常用的工具、框架、情报收集平台、C2 基础设施、免杀技术等 21 类资源，适合渗透测试人员、红队成员建立个人知识库与工具箱。

> **原文链接**：https://www.freebuf.com/geek/226811.html

## 年度 Web 攻击技术盘点

### PortSwigger Research：2019 年度十大 Web 攻击技术

PortSwigger（Burp Suite 研发团队）发布年度盘点，精选 2019 年最具影响力、创新性的 10 项 Web 攻击技术，涵盖：

- HTTP 请求走私（HTTP Request Smuggling）新变种
- 服务端模板注入（SSTI）利用新思路
- 原型链污染在现代框架中的利用
- WebSocket 漏洞新攻击面
- GraphQL 安全问题
- 客户端攻击新技术
- 绕过 WAF/过滤器的新方法
- 供应链攻击在 Web 领域的体现
- 云原生环境下的配置错误利用
- 业务逻辑漏洞挖掘新方法

每项技术均附带详细技术解析、利用条件、影响范围及缓解建议，是 Web 安全研究者的必读参考。

> **原文链接**：https://portswigger.net/research/top-10-web-hacking-techniques-of-2019

## 威胁情报报告

### 奇安信发布《全球高级可持续威胁（APT）2019 报告》

奇安信威胁情报中心发布年度 APT 报告，核心内容包括：

- **APT 组织画像**：追踪全球 30+ 活跃 APT 组织的攻击基础设施、工具链演变、目标选择偏好
- **攻击技术演进**：供应链攻击、零日漏洞利用、云环境渗透、移动端间谍软件等趋势分析
- **重点攻击活动复盘**：2019 年重大 APT 活动时间线、攻击链还原、归因分析
- **行业威胁画像**：政府、能源、金融、高科技、教育等重点行业面临的 APT 威胁特征
- **防御建议**：基于 ATT&CK 框架的检测响应策略、威胁情报运营建议

报告 PDF 可供下载研读，适合威胁情报分析师、安全运营团队、高层决策参考。

> **报告下载**：https://ti.qianxin.com/uploads/2020/02/13/cb78386a082f465f259b37dae5df4884.pdf

## 漏洞预警

### WordPress 主题插件严重漏洞，影响近 20 万网站

WordPress 生态两款广泛使用的主题/插件被曝存在严重安全漏洞，累计影响近 20 万个网站：

- **漏洞类型**：未授权任意文件上传 / 远程代码执行（RCE）
- **影响组件**：具体主题/插件名称见原文
- **利用条件**：无需认证，远程可利用
- **修复状态**：官方已发布补丁版本，强建议立即更新

站长请尽快自查资产、应用补丁、排查是否已被利用（检查可疑文件上传记录、Webshell、异常管理员账号）。

> **原文链接**：https://www.freebuf.com/news/227490.html

## 勒索病毒年度报告

### 年度勒索病毒专题报告

FreeBuf 发布年度勒索病毒趋势分析报告，核心看点：

- **攻击量级**：2019 年全球勒索攻击事件数、赎金支付总额、平均停机损失统计
- **主要家族画像**：Ryuk、Sodinokibi (REvil)、Maze、DoppelPaymer、Nemty 等主流家族技术特征、分发渠道、勒索谈判策略对比
- **演变趋势**：
  - "双重勒索"（加密+窃取数据威胁公开）成为主流
  - 定向攻击大型企业/机构（大游猎）替代大规模无差别传播
  - 勒索即服务（RaaS）模式成熟，分工细化
  - 利用 RDP 暴力破解、VPN 漏洞、供应链渗透作为主要初始入口
- **行业分布**：制造业、医疗、政府、教育、IT 服务为重灾区
- **防御建议**：备份策略、网络分段、EDR 部署、应急预案演练、网络保险考量

> **原文链接**：https://www.freebuf.com/articles/paper/226835.html

## 隐私保护工具清单

### 关于隐私的服务和软件的策划列表

GitHub 精选项目 `nikitavoloboev/privacy-respecting`，系统收录尊重用户隐私的替代性服务与软件，分类包括：

- **浏览器与扩展**：Firefox、Brave、Tor Browser、uBlock Origin、Privacy Badger 等
- **搜索引擎**：DuckDuckGo、Searx、Startpage 等
- **即时通讯**：Signal、Session、Element (Matrix)、Threema 等
- **邮件服务**：ProtonMail、Tutanota、Posteo 等
- **云存储/同步**：Nextcloud、Syncthing、Tresorit、Sync.com 等
- **VPN/代理**：Mullvad、IVPN、ProtonVPN、WireGuard 自建等
- **操作系统**：Linux 发行版、GrapheneOS、CalyxOS 等
- **DNS/网络**：NextDNS、Pi-hole、DNSCrypt 等
- **密码管理**：Bitwarden、KeePassXC、Pass 等
- **支付/金融**：Privacy.com、Monero、Wasabi Wallet 等
- **地图/导航**：Organic Maps、OsmAnd 等

项目持续维护，适合隐私关注者构建个人数字隐私防御体系。

> **项目地址**：https://github.com/nikitavoloboev/privacy-respecting

## 行业趋势分析

### 年网络安全支出趋势

FreeBuf 发布行业分析文章，预测 2020 年全球及中国网络安全支出关键趋势：

- **整体规模**：全球安全支出预计超 1200 亿美元，中国市场增速领跑全球
- **重点投入方向**：
  - 云安全（CSPM、CWPP、CASB）
  - 零信任架构落地
  - 端点检测响应（EDR/XDR）
  - 威胁情报平台（TIP）与 SOAR 自动化编排
  - 数据安全与隐私合规（GDPR、等保 2.0、数据安全法预期）
  - 应用安全（DevSecOps、IAST/RAASP）
  - 身份与访问管理（IAM、PAM、MFA）
- **驱动因素**：远程办公常态化、供应链攻击频发、监管合规压力、董事会网络安全治理意识提升
- **采购模式变化**：从单点产品采购转向平台化、服务化（MSSP、MDR）、订阅制

文章为安全预算规划、厂商市场策略、投资决策提供参考。

> **原文链接**：https://www.freebuf.com/articles/network/227362.html

## 关联阅读

本系列其他日期看点：

- [[daily-security-digest-20200220]] — 2020-02-20 看点：GitHub 敏感信息采集、以太坊蜜罐、SQL Server SSRS RCE (CVE-2020-0618)
- [[daily-security-digest-20200221]] — 2020-02-21 看点：Tomcat AJP 协议漏洞 (CVE-2020-1938)、iOS 虚拟机 UTM
- [[daily-security-digest-20200224]] — 2020-02-24 看点：Android 厂商漏洞披露、APT TTPs 分析、Linux SUID 提权
- [[daily-security-digest-20200225]] — 2020-02-25 看点：RSAC 2020、Docker 安全、硬件调试 SWD/OpenOCD、MariaDB 提权 (CVE-2020-7221)
- [[daily-security-digest-20200226]] — 2020-02-26 看点：LLVM/Clang Pass、账号接管、挖矿木马应急、Linux 内核栈溢出
- [[daily-security-digest-20200227]] — 2020-02-27 看点：Django PostgreSQL 注入、微盟删库、sudo 历史漏洞、PHP 静态查杀绕过

## 来源

- [0th3rs安全团队-201911-202204_079](../sources/0th3rs安全团队-201911-202204_079.md)
