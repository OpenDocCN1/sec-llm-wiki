---
title: 301在路上微信归档：PKAV创始人only_guest黑客寻爱故事——渗透校园官网挂留言板全校围观
description: 记录301在路上微信归档中PKAV创始人only_guest早年黑客寻爱故事：利用QQ校友六度人脉定位初恋所在高校，渗透校园官网挂留言板引发全校围观，最终电话联系得知对方已有新欢的完整叙事，展示早期黑客圈技术与情感交织的经典案例。
category: program-analysis
tags:
- 301在路上
- PKAV
- only_guest
- 黑客寻爱
- QQ校友
- 六度人脉
- 校园官网渗透
- 留言板
- 社会工程学
- 情感叙事
- 微信归档
- 2016年
- 杨蔚
date: '2016-01-01'
updated: '2026-11-17'
---

## 概述

本页面沉淀自 **301在路上** 微信公众号（作者：杨蔚/301）的一篇投稿文章，记录国内知名安全团队 **PKAV创始人 only_guest** 在年轻时为寻找初恋女友而实施的**校园官网渗透与留言板挂马事件**。案例展示了从 **QQ校友六度人脉关联分析**、**高校官网漏洞挖掘**、**查询接口利用**、**首页篡改挂载留言板** 到 **发动全校师生协助人肉搜索** 的完整攻击链，且全程嵌入情感叙事，是早期黑客圈「技术与情感交织」的经典案例，也引发了主流媒体广泛报道。

> **原文链接**：http://mp.weixin.qq.com/s?__biz=MzIwMTQ2NzY4NA==&mid=403247984&idx=1&sn=9974d4054350f14c37f2906c82ba6e86&chksm=0b10c13b3c67482d0c68a4d17b7ae8488e642d833849016110d44eb99a2af03aff1112d1e9ea&scene=126&sessionid=1681656792#rd  
> **发布时间**：2016 年初（推测）  
> **归档范围**：301在路上 201508-202208 微信归档索引

---

## 攻击链全景复盘

### 阶段一：开源情报搜集——QQ校友六度人脉关联定位

| 步骤 | 动作 | 技术手段 | 产出 |
|------|------|----------|------|
| 1 | 登录腾讯朋友网（QQ校友） | 社交图谱平台、六度人脉功能 | 利用「六度人脉关系」对好友圈进行数据关联查询 |
| 2 | 输入初恋女友姓名检索 | 姓名模糊匹配、关联图谱遍历 | 定位到目标就读于 **国内某省科技大学**（文中称「内科大」） |
| 3 | 确认目标学校信息 | 跨平台身份关联 | 获取关键线索：目标高校名称、疑似在校状态 |

> **关键洞察**：**早期社交平台（QQ校友）的「六度人脉」功能实质上是基于好友关系图谱的关联分析引擎**，攻击者利用该功能实现了从「仅知姓名」到「定位组织机构」的跨越。  
> **关联页面**：[[social-engineering-attack-techniques]]（OSINT与社工库关联分析）、[[threat-attribution-tracing-techniques]]（攻击者画像与跨平台关联）

---

### 阶段二：目标资产侦察与漏洞挖掘——高校官网渗透

| 步骤 | 动作 | 技术细节 | 结果 |
|------|------|----------|------|
| 1 | 访问目标高校官方网站 | Web应用指纹识别、目录扫描 | 发现官网服务器网段与教务系统**不在同一网段** |
| 2 | 深入分析教务系统架构 | 网段隔离分析、接口审计 | 教务系统为独立网段，存在**查询接口**可直接调用 |
| 3 | 接口参数分析 | 接口测试、参数枚举 | 查询接口**前置条件：需学生学号**，仅知姓名无法直接查询 |
| 4 | 同名同姓消歧难题 | 逻辑分析、攻击面评估 | 偌大学校同名概率高，无学号无法精准定位身份 |

> **技术对应页**：[[info-gathering-tools-collection]]（资产测绘与指纹识别）、[[ssrf-bypass-techniques]]（内网接口探测与利用）、[[api-business-logic-phone-enumeration]]（业务逻辑接口枚举风险）

---

### 阶段三：攻击策略转向——首页篡改挂载留言板（发动群众力量）

| 维度 | 实施细节 | 技术实现 |
|------|----------|----------|
| **攻击构想** | 「挂个页面，发动全校同胞力量寻找当年的她」 | 将高校官网首页替换为寻人启事页面 |
| **页面内容** | 煽情文案 + 留言板表单 | 「任帅，你在哪？」「我是一个黑客，我没有别的办法！」「希望发动大家力量帮我找到你」「认识任帅、包头人请留下QQ号码」 |
| **技术手段** | Web服务器入侵、首页篡改、留言板部署 | 可能利用：CMS漏洞、文件上传、模板注入、或服务器配置错误实现首页写入权限 |
| **传播效果** | 百度贴吧沸腾、全校讨论、留言板数百条 | **物理空间与网络空间联动**：贴吧成舆论放大器，留言板成线索收集器 |

**留言板关键截图内容**：

> **任帅，你在哪？**  
> 依稀记得你的样子，记得我们那段青涩的感情，却始终寻不到你。  
> 昨日在腾讯的朋友网上发现了你的足迹，知道你在这所学校，但无法联系到你。  
> 不知道该怎么办，我是一个黑客，我没有别的办法！  
> 希望能够发动大家的力量帮我找到你。  
> 大家如果认识一个女孩，名字叫做任帅，包头人，请在这里留下她的QQ号码，号码？

> **关联页面**：[[web-cache-poisoning-techniques]]（首页篡改与缓存投毒）、[[catfish-cms-stored-xss-analysis]]（留言板存储型XSS风险）、[[http-header-forgery-stored-xss]]（HTTP头伪造导致存储型XSS）

---

### 阶段四：群众力量响应与线索获取

| 事件节点 | 发展过程 | 关键产出 |
|----------|----------|----------|
| 1 | 百度贴吧全校围观 | 数百条跟帖讨论「网站被黑」、寻人启事真假 |
| 2 | 自称女主角帖子出现 | 将事件推向高潮，真假难辨 |
| 3 | 热心同学提供手机号码 | 留言板出现疑似目标手机号，**攻击者删除含手机号评论以防骚扰** |
| 4 | 攻击者拨打电话确认 | 电话接通，听到「陌生又熟悉的声音」，寒暄几句后得知：**对方已有男友、过得很幸福** |
| 5 | 攻击者心理闭环 | 「虽然301不知道是不是真的…」，主观满足感达成 |

---

### 阶段五：媒体曝光与舆论发酵

| 媒体渠道 | 报道标题 | 社会影响 |
|----------|----------|----------|
| 新华网内蒙古频道等主流媒体 | 「内科大网站被『黑』竟为『人肉』爱情」 | 将技术性入侵事件包装为「黑客为爱渗透校园网」的情感新闻，引发公众对黑客群体、网络安全、隐私边界的讨论 |

![媒体报道截图](../Images/e48f246ba9cc87cefa2b0ad72b738bee.png)

---

## 技术战术矩阵总结（MITRE ATT&CK 映射）

| ATT&CK 战术 | 技术编号 | 技术名称 | 本案实施方式 |
|-------------|----------|----------|--------------|
| **Reconnaissance** | T1590.005 | Active Scanning: Social Media | QQ校友六度人脉关联分析定位目标高校 |
| | T1590.001 | Active Scanning: Web Application | 高校官网指纹识别、教务系统接口审计 |
| **Resource Development** | T1587.001 | Develop Capabilities: Web Exploits | 构建首页篡改页面、留言板表单 |
| **Initial Access** | T1190 | Exploit Public-Facing Application | 渗透高校官网Web服务器获取首页写入权限 |
| **Execution** | T1505.003 | Server Software Component: Web Shell | 部署留言板功能实现持久化交互 |
| **Collection** | T1115 | Clipboard Data / T1213 | 通过留言板收集全校师生提供的线索（手机号、QQ号） |
| **Command and Control** | T1102 | Web Service | 利用高校官网作为C2前端展示与数据收集平台 |
| **Impact** | T1491.001 | Defacement: External | 首页篡改为寻人启事，造成服务不可用与声誉损害 |
| | T1565.001 | Data Manipulation: Stored Data | 留言板数据写入、含敏感信息评论删除 |

---

## 关键风控盲区与防御启示

| 风控层面 | 盲区表现 | 加固建议 | 关联知识库页面 |
|----------|----------|----------|----------------|
| **社交平台图谱泄露** | QQ校友六度人脉支持任意姓名关联查询，无访问控制、无审计日志 | 关联查询需双向好友确认、敏感字段脱敏、异常查询频控告警 | [[social-engineering-attack-techniques]]、[[threat-attribution-tracing-techniques]] |
| **Web应用网段隔离不彻底** | 官网服务器与教务系统虽分网段，但官网被突破后可作为跳板探测内网接口 | 严格实施零信任网络分段、东西向流量审计、堡垒机统一运维入口 | [[docker-container-security-fundamentals]]、[[kubernetes-penetration-testing]] |
| **业务接口缺乏强鉴权** | 教务查询接口仅凭学号即可调用，无Token、无频控、无审计 | 接口强鉴权（OAuth2/JWT）、基于角色的访问控制（RBAC）、敏感查询二次验证 | [[api-business-logic-phone-enumeration]]、[[openid-connect-acr-amr-2fa-bypass]] |
| **首页篡改检测缺失** | 官网首页被长时间篡改未触发告警，缺乏完整性监控 | 部署网页防篡改系统（核心目录锁定、定时校验哈希）、CDN边缘缓存防篡改、实时告警 | [[nginx-security-hardening-guide]]、[[apache-security-hardening-guide]] |
| **用户生成内容（UGC）风控** | 留言板无内容审核、无敏感信息脱敏、无防刷机制，导致手机号泄露 | UGC内容安全审核（规则+AI）、手机号/身份证号自动脱敏、验证码/设备指纹防刷 | [[catfish-cms-stored-xss-analysis]]、[[feifei-cms-arbitrary-file-deletion]] |
| **事件响应流程缺失** | 从发现篡改到恢复、取证、溯源无标准化流程，媒体报道先于官方通报 | 建立Web安全事件响应SOP：监测→确认→熔断→取证→溯源→恢复→复盘→通报 | [[security-incident-response-webshell-case-study]]、[[xd-security-incident-response-notes]] |

---

## 法律与伦理边界标注

| 行为 | 涉嫌触犯法条 | 伦理判定 |
|------|--------------|----------|
| 未经授权渗透高校官网服务器、篡改首页 | 《刑法》第 285 条（非法侵入计算机信息系统罪）、第 286 条（破坏计算机信息系统罪） | **严重违法**：破坏公共服务系统完整性、造成社会不良影响 |
| 部署留言板收集他人隐私信息（手机号、QQ号） | 《刑法》第 253 条（侵犯公民个人信息罪）、《网络安全法》第 42 条 | **严重违规**：非法收集、存储、处理他人敏感个人信息 |
| 利用媒体传播放大攻击影响、美化黑客行为 | 《网络安全法》第 27 条（禁止传播非法侵入、破坏计算机信息系统的工具、方法） | **不当宣传**：将违法攻击行为包装为「浪漫故事」，误导公众认知 |
| 删除含手机号评论「防骚扰」 | 自证具备数据控制权、主观故意篡改电子数据 | **销毁证据/篡改数据**：掩盖隐私泄露事实，干扰后续取证 |

> **白帽子职业操守警示**：**技术能力不等于道德豁免权**。only_guest 后成为 PKAV 创始人、国内知名安全专家，但此早年「失足」案例始终是其职业生涯的污点。白帽子群体应以此为反面教材，强化「授权前提、最小必要、尊重隐私、合规披露」四大底线。  
> **关联页面**：[[whitehat-legal-boundaries]]（建议建立）、[[security-engineer-ethics]]（建议建立）、[[white-hat-enterprise-collaboration-guide]]（测试边界与授权机制）

---

## 知识图谱交叉引用

### 301在路上系列内部链接
- [[301-security-team-building-first-season]] — 301在路上安全团队建设第一季（杨蔚/301/smarttang）
- [[301-security-team-building-second-season]] — 301在路上安全团队建设第二季（杨蔚/301/smarttang）
- [[whitehat-arrest-baihe-case]] — 301在路上白帽子被抓事件复盘（杨蔚/世纪佳缘/百合网/乌云）
- [[security-career-development-guide]] — 安全从业者职业成长指南（301在路上/心态建设/非科班入行）
- [[security-team-hc-planning-work-quantification]] — 安全团队HC规划与工作量化（301在路上/杨蔚/smarttang）
- [[security-vendor-incident-response-behavior]] — 安全厂商应急响应行为批判（301在路上/杨蔚/Struts2 S2-032）
- [[white-hat-enterprise-collaboration-guide]] — 白帽子企业协作指南（301在路上/SRC运营/漏洞披露）
- [[competitor-cyber-espionage-kumi-case]] — 酷米客商业间谍案复盘（301在路上/威胁情报/大数据安全）
- [[sim-swap-attack-case-study-alipay-bank-theft]] — SIM Swap补卡攻击案例（301在路上/360天眼/支付宝盗刷）
- [[qrljacking-qr-code-login-hijacking]] — QRLJacking二维码登录劫持（301在路上/OWASP/微信网页版）

### 社会工程学与攻击溯源技术专题
- [[social-engineering-attack-techniques]] — 社会工程学攻击技术全谱系（借口、钓鱼、水坑、物理渗透、PKAV、iCloud钓鱼）
- [[threat-attribution-tracing-techniques]] — 威胁溯源追踪技术（攻击者画像、社工库碰撞、跨平台关联、PKAV钓鱼站渗透溯源）
- [[credential-stuffing-password-hygiene]] — 撞库攻击与密码卫生（密码复用、密保安全、手机号枚举、PKAV、4000万iCloud撞库案）

### Web安全与应急响应技术专题
- [[info-gathering-tools-collection]] — 信息收集工具合集（资产测绘、指纹识别、子域名枚举、WAF探测）
- [[web-cache-poisoning-techniques]] — Web缓存投毒技术（首页篡改、Cache Poisoning、CP-DoS）
- [[nginx-security-hardening-guide]] — Nginx安全加固配置指南（日志审计、访问控制、防篡改）
- [[apache-security-hardening-guide]] — Apache安全加固配置指南（目录控制、日志审计、版本隐藏）
- [[security-incident-response-webshell-case-study]] — Webshell应急响应实战讨论（301在路上/杨蔚/六阶段标准化流程）
- [[xd-security-incident-response-notes]] — XD安全应急响应学习笔记（日志分析、Webshell排查、勒索病毒处置）

### CMS漏洞与留言板安全
- [[catfish-cms-stored-xss-analysis]] — Catfish CMS存储型XSS分析（filterJs绕过、img onerror）
- [[catfish-cms-arbitrary-image-deletion]] — Catfish CMS任意图片删除（路径遍历、代码审计）
- [[feifei-cms-arbitrary-file-deletion]] — 飞飞CMS任意文件删除（DataAction.class.php、delall函数）
- [[iwebshop-cms-arbitrary-file-deletion]] — IWebShop CMS任意文件删除（数据库备份管理、路径遍历）
- [[chanzhi-cms-7-0-1-template-getshell]] — 蝉知CMS模板Getshell（str_replace参数顺序错误）
- [[http-header-forgery-stored-xss]] — HTTP头伪造导致存储型XSS（X-Forwarded-For、Client-IP、AppCMS/TaoCMS）

---

## 版本记录

| 版本 | 日期 | 变更摘要 |
|------|------|----------|
| v1.0 | 2026-01-17 | 初版：基于 301在路上 归档文章构建 PKAV创始人 only_guest 黑客寻爱故事知识页，含攻击链五阶段拆解、ATT&CK映射、风控盲区分析、法律伦理标注、交叉引用网络 |

---

> **维护提示**：本页面为技术复盘与警示教育目的，严禁将文中技术细节用于非授权测试或恶意目的。各重点技术专题建议拆分建立独立详情页，通过 `[[wikilink]]` 双向链接形成知识网络。

## 来源

- [301在路上-201508-202208_188](../sources/301在路上-201508-202208_188.md)
