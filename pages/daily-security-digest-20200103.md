---
title: 每日安全看点 2020-01-03
description: 2020年1月3日每日安全看点汇总：工信部下架侵害用户权益App、Python钓鱼包供应链攻击分析、CVE-2019-10758 mongo-express
  RCE、Twitter设置覆写漏洞、Shodan挖掘XSS技巧及漏洞猎人入门资源
category: ai-security
tags:
- 每日安全看点
- 工信部
- App下架
- 供应链攻击
- Python
- CVE-2019-10758
- mongo-express
- RCE
- Twitter
- Shodan
- XSS
- 漏洞赏金
- 入门资源
date: 2020-01-03
updated: '2026-11-12'
---

## 概览

本期每日安全看点涵盖监管动态、供应链安全、漏洞披露、漏洞挖掘技巧及入门资源六大板块，时间跨度为 2020 年 1 月 3 日。

## 监管动态

### 工信部通报下架首批侵害用户权益 App

工业和信息化部发布通报，下架首批侵害用户权益的 App 名单。因未按要求完成整改，以下 3 款 App 被责令下架：

- **人人视频**
- **春雨计步器**
- **微唱-原创音乐**

> 相关阅读：[[daily-security-digest-20200210]] 中亦提及工信部针对疫情期间涉疫 App 的安全风险提示。

## 供应链安全

### Python 钓鱼包事件后续——软件供应链攻击防御探索

腾讯安全发布深度分析文章，针对此前发生的 Python 钓鱼包（PyPI 供应链投毒）事件进行复盘，探讨软件供应链攻击的防御体系建设思路。

- **文章链接**：https://security.tencent.com/index.php/blog/msg/140
- **核心议题**：依赖混淆攻击、包名伪装、签名验证缺失、SBOM（软件物料清单）落地建议

## 漏洞披露

### CVE-2019-10758：mongo-express < 0.54.0 远程代码执行

**影响组件**：mongo-express（MongoDB Web 管理界面）  
**影响版本**：< 0.54.0  
**漏洞类型**：RCE（远程代码执行）  
**利用条件**：默认配置下无需认证或弱口令登录后台

- **PoC 仓库**：https://github.com/masahiro331/CVE-2019-10758
- **Shodan 搜索语法**（定位中国地区暴露实例）：
  ```
  Mongo Express country:"CN"
  ```
  https://www.shodan.io/search?query=Mongo+Express+country%3A%22CN%22

> 同类数据库管理组件 RCE 可参考 [[h2-console-jndi注入rce利用]]、[[spring-boot-actuator配置不当rce利用]] 中的 H2 Console、Spring Boot Actuator 利用链。

### Twitter 设置覆写漏洞

**报告平台**：HackerOne  
**报告编号**：#664038  
**漏洞描述**：攻击者可通过特定参数篡改其他用户的账号设置（如邮箱、手机号、密码重置流程等），导致账号接管。

- **报告详情**：https://hackerone.com/reports/664038

## 漏洞挖掘技巧

### 如何通过 Shodan 发现 XSS 漏洞

作者分享利用 Shodan 搜索引擎结合特定指纹/响应特征，批量发现反射型/存储型 XSS 的实战方法论。

- **文章链接**：https://medium.com/bugbountywriteup/how-i-found-xss-by-searching-in-shodan-6943b799e648
- **核心思路**：
  1. 搜索特定报错页面、调试接口、版本号泄露页面
  2. 利用 `http.html:"<script>"` 等关键词过滤潜在注入点
  3. 结合自动化工具批量验证 Payload 触发情况

> 更多 Shodan 实战技巧可参考 [[daily-security-digest-20200217]] 中的「Shodan 渗透测试指南」。

## 入门资源

### 漏洞猎人入门者资源集合

GitHub 精选仓库，汇总漏洞赏金新手所需的学习路线、工具清单、实战平台、Writeup 集合等。

- **仓库地址**：https://github.com/nahamsec/Resources-for-Beginner-Bug-Bounty-Hunters
- **维护者**：[@nahamsec](https://twitter.com/nahamsec) — 知名 Bug Bounty 猎人与教育者
- **主要目录**：
  - 学习路线图
  - 推荐书籍/课程/视频
  - 常用工具（Burp Suite 插件、子域名枚举、Fuzzing 等）
  - 实战平台（HackerOne、Bugcrowd、Intigriti 等）
  - 高质量 Writeup 分类索引

## 关联页面

- [[daily-security-digest-20200113]] — 1 月 13 日看点：ATT&CK、Java Fuzz、SpringBoot RCE 等
- [[daily-security-digest-20200114]] — 1 月 14 日看点：IoT 逆向、Citrix CVE-2019-19781、小米路由器漏洞
- [[daily-security-digest-20200115]] — 1 月 15 日看点：ThinkPHP、Weblogic RCE、CurveBall 漏洞
- [[daily-security-digest-20200217]] — 2 月 17 日看点：Shodan 渗透指南、APT 攻击分析
- [[cve-digest-20200426]] — 2020 年 4 月 CVE 聚合：Windows 提权、Chrome V8、Firefox XSS 等

## 来源

- [0th3rs安全团队-201911-202204_098](../sources/0th3rs安全团队-201911-202204_098.md)
