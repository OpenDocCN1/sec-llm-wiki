---
title: 226安全团队微信公众号文章归档索引（201805-202103）
description: 226安全团队微信公众号2018年5月至2021年3月期间发布文章的汇总索引页面，新增「回首我们做过的」总结文章条目，汇总团队十大开源项目与历年技术文章链接，涵盖安全研究、漏洞分析、CTF实战、工具分享等技术内容。新增
  Webug 4.0 发布文章条目，记录漏洞覆盖范围（SQLi/XSS/上传/逻辑/SSRF等）、集成乌云知识库/MD5解密模块及团队招聘信息。新增社区奖励活动获奖名单公示及征文投稿启事条目。
category: ai-security
tags:
- 226安全团队
- 微信归档
- 文章索引
- 网络安全
- 开源项目
- 漏洞分析
- CTF实战
- 工具分享
- 2018年
- 2019年
- 2020年
- 2021年
- Webug
- 靶场
- 社区运营
- 征文活动
date: '2018-05-01'
updated: '2026-11-15'
---

# 226安全团队微信公众号文章归档索引（201805-202103）

> 来源：[http://mp.weixin.qq.com](http://mp.weixin.qq.com)

本页面汇总 226安全团队微信公众号自 2018 年 5 月至 2021 年 3 月期间发布的历史文章。重点收录「回首我们做过的」总结文章，系统梳理团队十大开源项目与历年技术文章链接，为安全研究人员提供结构化的内容检索入口，便于追溯团队技术分享脉络。

---

## 团队开源项目汇总

「回首我们做过的」文章中整理了团队近五年开源的十个核心项目，涵盖漏洞利用工具、靶场环境、报告平台、招聘系统、密码解密、知识管理、RCE框架、Telegram机器人等方向。

### Struts2漏洞利用工具Devmode版
- **作者**：Poacher
- **描述**：基于Struts2 Devmode模式的漏洞利用工具，附带源码发布
- **相关地址**：[FreeBuf发布页](https://www.freebuf.com/sectool/108896.html)
- **关联技术**：[[struts2-memory-shell-injection]] - Struts2内存马注入技术深度解析

### MySQL日志监控工具
- **作者**：Poacher
- **描述**：基于Seay代码审计工具提取并修改的MySQL日志监控程序
- **下载地址**：[GitHub](https://github.com/wangai3176/mysql_Monitor_tools_code)
- **关联技术**：数据库审计、日志分析

### WeBug靶场 v4.0
- **作者**：王艾、怪大叔、下辈子做头猪、霾
- **描述**："我们的漏洞"靶场环境，基于PHP/MySQL搭建，包含基础/中级/高级三级环境，中高级环境基于真实互联网漏洞事件构建，运行于纯净版Windows 2003虚拟机
- **下载地址**：[GitHub](https://github.com/wangai3176/webug4.0)
- **关联技术**：
  - [[ctf-training-platforms-collection]] - CTF Web靶场离线打包合集
  - [[pikachu-target-writeup-part1-setup-brute-force]] - Pikachu靶场搭建与实战
  - [[xd-security-pentest-basic-stage-notes]] - 渗透测试基础阶段学习笔记

### We-Report报告生成平台
- **作者**：Poacher
- **描述**：针对乙方安全测试报告编写痛点开发的WEB一键生成测试报告平台
- **下载地址**：[GitHub](https://github.com/wangai3176/we-report)
- **关联技术**：[[0x727-bugreporter-automated-report-platform]] - 0x727团队漏洞报告自动化生成平台

### 招聘网站源码 (226job)
- **作者**：Poacher
- **描述**：基于乌云招聘前端开发的后端招聘网站，支持前后台分离，开源可自主修改
- **下载地址**：[GitHub](https://github.com/wangai666/226job)

### MD5解密平台 (226md5)
- **作者**：团队
- **描述**：类似somd5的协作式MD5解密平台，支持社区提交密码自动去重
- **下载地址**：[GitHub](https://github.com/wangai3176/226md5)
- **关联技术**：[[crypto-basics-xor-stream-cipher-tutorial]] - 密码学基础与异或加密教程

### SecEssay 安全知识收集平台
- **作者**：shiyan
- **描述**：灵感来源于Sec-News，解决团队技术分享碎片化问题，支持链接式分享与知识沉淀
- **下载地址**：[GitHub](https://github.com/wangai3176/SecEssay_Collect)
- **关联技术**：[[security-study-group-methodology]] - 0w1Club零基础安全学习小组组建方法论

### RCE工具框架 (rcetool)
- **作者**：霾
- **描述**：图形化框架式漏洞利用工具，支持用户编写Java插件，可扩展其他语言
- **下载地址**：[GitHub](https://github.com/kuiguansec/rcetool)
- **关联技术**：[[codetest-visual-poc-exploitation-tool]] - CodeTest可视化漏洞扫描与利用工具

### Telegram机器人
- **作者**：肥二星
- **描述**：面向文章整合查询场景的Telegram Bot，由团队提出需求完善
- **下载地址**：[GitHub](https://github.com/wangai3176/TelegramBotDemoService)

### 安全招聘平台
- **状态**：已开发，暂未开源

---

## 进行中项目

1. **自动化漏洞扫描工具** - 结合半自动化扫描，作者：肥二星、王艾
2. **新一代靶场平台** - 已进行2年开发，作者：怪大叔、王艾
3. **rcetool插件及插件开发手册** - 作者：霾

---

## 技术文章汇总

### 微信公众号原创文章

#### 漏洞分析与复现系列
| 标题 | 关键技术点 | 关联知识库页面 |
|------|-----------|---------------|
| [一个猥琐的持续性攻击思路](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901348&idx=1&sn=41de18b1c56982c51595d607ee85869d) | 持续性攻击、后渗透 | [[xd-security-internal-network-penetration-notes-day65-66]] |
| [Catfish(鲶鱼) CMS任意图片删除](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901300&idx=1&sn=b25348946d8363f3165419cfef7c87a8) | CMS漏洞、任意文件删除 | [[oasys-system-code-audit]] |
| [Catfish(鲶鱼) CMS存储型XSS一枚](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901314&idx=1&sn=2c7caf2f6eca5d9108e301b318024b74) | 存储型XSS、CMS漏洞 | [[xd-security-xss-vulnerability-notes-day25-28]]、[[pikachu-target-writeup-part2-xss]] |
| [网站被"黑"了，域名商这锅你别想甩！！！](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901330&idx=1&sn=53fb8ca84fca18c38beebe2232965bc9) | 供应链安全、域名劫持 | [[cve-id-application-guide]] |
| [IWebShopCMS后台存在任意删除文件](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901355&idx=1&sn=f6d0dc2407845eaa6deb1f2cc23b8b21) | 任意文件删除、CMS漏洞 | |
| [飞飞影视导航系统漏洞](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901363&idx=1&sn=342a6a6bb0b59df49ffd6853ebcd56e3) | CMS漏洞分析 | |
| [蝉知CMS7.0.1后台模板Getshell](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901373&idx=1&sn=36e0568da8ca1703f6b05c61d3246af3) | 模板注入、Getshell | [[php-webshell-fundamentals-chopper-analysis]] |
| [一次内网渗透端口转发引发的思考](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901398&idx=1&sn=9d1f316585239366cb48c625d5c55458) | 内网渗透、端口转发、隧道技术 | [[xd-security-internal-network-penetration-notes-day69-70]]、[[frp内网渗透应用]] |
| [SIM token 自动化薅羊毛攻击还原](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901406&idx=1&sn=ea616e58440b2d15532934dc06b0b2c8) | 区块链安全、自动化攻击 | |
| [QQ社工神器之我发EXE你敢点吗](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901436&idx=1&sn=727a609d49eac827926470eb6845f25c) | 社会工程学、恶意软件分发 | [[phishing-website-creation-tutorial]]、[[badusb-hid-attack-arduino-leonardo]] |
| [Metinfo 6.1.2 SQL注入](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901440&idx=1&sn=65ec52830e13404a62e53e3d4acd6dbc) | SQL注入、CMS漏洞 | [[xd-security-pentest-basic-stage-notes]]、[[mysql-duplicate-entry-error-based-sqli]] |
| [nodeMCU捣鼓笔记(从固件刷入到wifi扫描)](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901459&idx=1&sn=acbbc30f86035d76498d51259191abc6) | IoT安全、固件分析、硬件调试 | [[ft232h-spi-flash-firmware-extraction]]、[[ble-packet-capture-comparison]] |
| [代码审计之某系统后台数据库存在任意删除文件漏洞](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901469&idx=1&sn=6c70e0863457a0b9ffbcb4fb7494a28d) | 代码审计、任意文件删除 | [[xd-security-code-audit-notes-day50-57]]、[[oasys-system-code-audit]] |
| [代码审计之某系统后台数据库存在任意文件下载](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901479&idx=1&sn=82507c7fe7714e55fd5abb80487fb066) | 代码审计、任意文件下载 | |
| [Windows任意文件读取漏洞](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901485&idx=1&sn=ccf88a58759e6550789468f87c4b7dd7) | Windows漏洞、文件读取 | |
| [Excel 4.0宏躲避杀软检测](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901499&idx=1&sn=3b91fc7033f66f7977a009be659beb93) | 免杀技术、宏病毒、红队工具 | [[inceptor-av-edr-evasion-framework]]、[[php-webshell-obfuscation-av-evasion]] |

#### 【新增】Webug 4.0 发布与靶场体系建设 (2019-02)
| 标题 | 关键技术点 | 关联知识库页面 |
|------|-----------|---------------|
| [[新年礼物]Webug4.0 基础是梦的基石](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901539&idx=1&sn=0192fb8e09d81d62a9c7704ac63d316f) | **靶场平台**、SQL注入(报错/布尔/延时/CSV/POST/XML/过滤)、XSS(反射/存储/DOM/链接/过滤绕过)、文件上传(前端拦截/解析漏洞/畸形文件/.htaccess/截断)、逻辑漏洞(越权/支付/邮箱轰炸)、SSRF/CSRF/命令执行/文件包含/URL跳转、乌云知识库集成、MD5解密模块、CMS/CTF/招聘模块规划 | [[ctf-training-platforms-collection]]、[[xd-security-pentest-basic-stage-notes]]、[[upload-labs-file-upload-bypass-writeup]]、[[xd-security-logic-vulnerability-notes-day33-36]]、[[ssrf-bypass-techniques]]、[[php-file-inclusion-vulnerability]] |

#### 学员作品与教学系列
| 标题 | 关键技术点 | 关联知识库页面 |
|------|-----------|---------------|
| [FFmpeg任意文件读取复现（CVE-2016-1897）](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901509&idx=1&sn=9e8b12094505f55c05ab3dff8420761b) | FFmpeg漏洞、任意文件读取、CVE复现 | |
| [IIS PUT写入漏洞](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901522&idx=1&sn=871495a402acbaf3ae756f3e7b79d8ff) | 经典漏洞、IIS配置错误 | |
| [浅谈cookie安全](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901556&idx=1&sn=b839c154f60c39db10450838aee95372) | Cookie安全、HttpOnly、SameSite | [[xd-security-xss-vulnerability-notes-day25-28]]、[[jwt漏洞原理与实战利用]] |
| [保护宅男——拒绝黄赌毒](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901589&idx=1&sn=fb836dff7cbe35e2c65bfc1d287ee620) | 内容安全、网络治理 | |
| [我是如何用度娘拿下CSDN钓鱼网站的](https://zhuanlan.zhihu.com/p/60889777) | 钓鱼攻击、搜索引擎利用 | [[phishing-website-creation-tutorial]] |
| [SQLMAP手册](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901651&idx=1&sn=b3907c763d7a59fb5719d17f80acc2e9) | SQLMap使用、自动化注入 | [[sqlmap-api-automation]]、[[xd-security-pentest-basic-stage-notes]] |
| [从upload-labs总结上传漏洞及其绕过](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901715&idx=1&sn=ecba10d0794a1bee145d549c9e4c2c94) | 文件上传漏洞、绕过技巧 | [[xd-security-pentest-basic-stage-notes]]、[[pikachu-target-writeup-part4]] |
| [PHP入门基础学习笔记](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901719&idx=1&sn=59aff33423556cef9c463f91ae51d9ae) | PHP基础、Web安全入门 | |
| [中职生技能大赛赛题分析](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901740&idx=1&sn=0e28528d1002eda3d94de520d65cc2a6) | CTF竞赛、技能大赛 | [[attack-defense-world-beginner-web-writeup]]、[[bailu-ctf-2023-writeup]] |
| [最新Fastjson漏洞利用（团队内部周分享）](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901750&idx=1&sn=5a3e5a26af0ad02773b46f463afcacd7) | Fastjson反序列化、RCE | |
| [某shop存储XSS](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901801&idx=1&sn=1bb911dbbf86ace065cb3c561034a605) | 存储型XSS、实战分析 | [[xd-security-xss-vulnerability-notes-day25-28]] |
| [webug基础教程视频学习](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901806&idx=1&sn=58ad9a7b356c0d8021ffbfa0d56b103c) | 靶场教学、视频教程 | [[ctf-training-platforms-collection]] |

#### 【新增】社区运营与激励活动 (2020)
| 标题 | 关键技术点 | 关联知识库页面 |
|------|-----------|---------------|
| [226安全团队&启维安全 - 奖励活动获奖名单公示及征文投稿启事](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901410&idx=1&sn=6f41847b3d5e58dd6803fc9802cf8954) | **社区激励**、获奖名单公示、征文投稿活动、原创文章奖励、书籍赠送、团队共建 | [[0w1club-tiesan-training-camp]]、[[0w1club-wechat-archive-201707-201903]]、[[security-study-group-methodology]] |

### 知乎专栏文章

#### 漏洞复现与实战
| 标题 | 链接 | 关键技术点 |
|------|------|-----------|
| 利用Flash漏洞进行钓鱼复现演示（附视频） | [知乎](https://zhuanlan.zhihu.com/p/27082975) | Flash漏洞、钓鱼攻击、视频演示 |
| 安卓逆向入门（一） | [知乎](https://zhuanlan.zhihu.com/p/27087285) | Android逆向、基础入门 |
| 安卓逆向入门（二） | [知乎](https://zhuanlan.zhihu.com/p/27089242) | Android逆向、进阶技巧 |
| 安卓逆向入门（三） | [知乎](https://zhuanlan.zhihu.com/p/37841535) | Android逆向、实战案例 |
| btslab测试实验室之XSS娱乐 | [知乎](https://zhuanlan.zhihu.com/p/27233637) | XSS平台、漏洞利用 |
| 关于Http长连接 | [知乎](https://zhuanlan.zhihu.com/p/36371469) | HTTP协议、长连接机制 |
| 好奇驱使我对XSS平台的一次小研究 | [知乎](https://zhuanlan.zhihu.com/p/36401042) | XSS平台构建、攻击面分析 |
| 内网记录(一) | [知乎](https://zhuanlan.zhihu.com/p/36469796) | 内网渗透、实战记录 |
| ThinkPHP3.2学习内容 | [知乎](https://zhuanlan.zhihu.com/p/37054902) | ThinkPHP框架、代码审计 |
| 从开发角度浅谈CSRF攻击及防御 | [知乎](https://zhuanlan.zhihu.com/p/37056545) | CSRF原理、防御方案 | [[xd-security-csrf-ssrf-rce-notes-day29-30]] |
| 乌.试炼 | [知乎](https://zhuanlan.zhihu.com/p/37251429) | CTF训练、乌云漏洞复现 |

---

## Webug 4.0 核心漏洞覆盖矩阵

基于发布文章整理的漏洞类型与绕过技术覆盖情况：

### SQL注入 (7大类型)
| 类型 | Flag标识 | 对应实战技术页 |
|------|---------|---------------|
| 报错注入 | ✅ | [[mysql-duplicate-entry-error-based-sqli]] |
| 布尔盲注 | ✅ | [[xd-security-pentest-basic-stage-notes]] |
| 延时盲注 | ✅ | [[xd-security-pentest-basic-stage-notes]] |
| CSV注入 | ✅ | 数据导出场景注入 |
| POST注入 | ✅ | [[xd-security-pentest-basic-stage-notes]] |
| XML注入 | ✅ | XXE/XML注入变种 |
| 注入过滤绕过 | ✅ | [[xd-security-waf-bypass-techniques-day46-49]] |

### XSS跨站脚本 (5大类型)
| 类型 | Flag标识 | 对应实战技术页 |
|------|---------|---------------|
| 反射型XSS | ✅ | [[xd-security-xss-vulnerability-notes-day25-28]]、[[pikachu-target-writeup-part2-xss]] |
| 存储型XSS | ✅ | [[xd-security-xss-vulnerability-notes-day25-28]]、[[pikachu-target-writeup-part2-xss]] |
| DOM型XSS | ✅ | [[xd-security-xss-vulnerability-notes-day25-28]]、[[discuz-x32-stored-dom-xss-bbcode-analysis]] |
| 链接注入XSS | ✅ | href/src属性注入场景 |
| 过滤绕过存储型XSS | ✅ | [[xd-security-xss-vulnerability-notes-day25-28]] |

### 文件上传漏洞 (5大绕过技术)
| 绕过方式 | Flag标识 | 对应实战技术页 |
|---------|---------|---------------|
| 前端JS拦截绕过 | ✅ | [[upload-labs-file-upload-bypass-writeup]]、[[pikachu-target-writeup-part4]] |
| 解析漏洞利用 | ✅ | [[upload-labs-file-upload-bypass-writeup]]、[[pikachu-target-writeup-part4]] |
| 畸形文件上传 | ✅ | 文件头/结构畸形绕过检测 |
| .htaccess配置攻击 | ✅ | [[upload-labs-file-upload-bypass-writeup]]、[[pikachu-target-writeup-part4]] |
| %00截断上传 | ✅ | [[upload-labs-file-upload-bypass-writeup]]、[[php-file-inclusion-vulnerability]] |

### 逻辑漏洞 (4大场景)
| 场景 | Flag标识 | 对应实战技术页 |
|------|---------|---------------|
| 越权修改密码 | ✅ | [[xd-security-logic-vulnerability-notes-day33-36]] |
| 支付金额篡改 | ✅ | [[xd-security-logic-vulnerability-notes-day33-36]] |
| 邮箱轰炸接口 | ⚠️ 需配置 | 业务接口滥用 |
| 越权查看管理员信息 | ✅ | [[xd-security-logic-vulnerability-notes-day33-36]]、[[jwt漏洞原理与实战利用]] |

### 其他高危漏洞类型
| 漏洞类型 | 覆盖情况 | 对应实战技术页 |
|---------|---------|---------------|
| SSRF服务端请求伪造 | ✅ | [[ssrf-bypass-techniques]]、[[ssrf-ctf-exploitation-guide]] |
| CSRF跨站请求伪造 | ✅ | [[xd-security-csrf-ssrf-rce-notes-day29-30]] |
| 命令执行/RCE | ✅ | [[xd-security-csrf-ssrf-rce-notes-day29-30]]、[[attack-defense-world-beginner-web-writeup]] |
| 文件包含(LFI/RFI) | ✅ | [[php-file-inclusion-vulnerability]]、[[xd-security-file-inclusion-notes]] |
| URL跳转/重定向 | ✅ | 非授权跳转利用 |
| 任意文件下载 | ✅ | [[oasys-system-code-audit]] |

---

## Webug 4.0 扩展模块规划

| 模块名称 | 状态 | 说明 | 关联生态 |
|---------|------|------|---------|
| **乌云知识库** | ✅ 已集成 | 历史漏洞案例库离线镜像 | 乌云存档项目 |
| **MD5解密平台** | ✅ 已集成 | 协作式彩虹表查询，计划上线独立版 | [[crypto-basics-xor-stream-cipher-tutorial]]、226md5开源项目 |
| **CMS靶场模块** | 🚧 规划中 | 对比Webug 3.0优势，整理主流CMS漏洞环境 | [[oasys-system-code-audit]]、各类CMS漏洞复现页 |
| **CTF竞技模块** | 🚧 规划中 | 社区贡献CTF题目环境与思路 | [[ctf-training-platforms-collection]]、[[attack-defense-world-beginner-web-writeup]] |
| **招聘系统嵌入** | ✅ 已上线 | 嵌入 job.226safe.com 招聘门户 | 226job开源项目、团队招聘长期有效 |
| **靶场难度分级** | ✅ 新增 | 简易/中级/高级三级选择机制 | 适配不同阶段学习者 |

---

## 社区激励机制详情

### 奖励活动获奖名单 (2020)
本次奖励活动获奖用户（微信昵称）：
- **难得糊涂**
- **小明小红和静静**
- **wind**
- **a**

> 活动说明：参与者众多但实际推文转发较少，团队表示理解并持续优化激励机制。

### 征文投稿活动长期启事 (即日起长期有效)
| 投稿类型 | 奖励标准 | 审核要求 |
|---------|---------|---------|
| **原创首发文章** | 怪大叔挑选技术书籍一本 | 文章为原创且首发于本公众号，经团队审核质量达标 |
| **原创非首发文章** (累计5篇) | 小笼包挑选技术书籍一本 | 近期发表的原创文章，非首发但质量过审 |
| **投稿方式** | 将原创文章地址发送至公众号后台 | 团队核实确认后安排发布与奖励发放 |

**活动初衷**：鼓励安全技术原创内容创作，促进团队与社区知识共建，打造高质量技术分享生态。

---

## 相关归档页面

- [[0w1club-wechat-archive-201707-201903]] — 0w1Club微信归档索引（201707-201903）
- [[0th3rs-security-team-wechat-archive-201911-202204]] — 0th3rs安全团队微信归档索引（201911-202204）
- [[0x4d5a-wechat-archive-202103-202209]] — 0x4d5a安全团队微信归档索引（202103-202209）
- [[0xfafu-security-team-wechat-archive-202010-202112]] — 0xfafu攻防实验室微信归档索引（202010-202112）
- [[102-network-security-lab-wechat-archive-202102-202203]] — 102网络攻防实验室微信归档索引（202102-202203）
- [[0x00lab-wechat-archive-202108-202304]] — 0x00实验室微信归档索引（202108-202304）
- [[0x727-security-team-wechat-archive-202108-202110]] — 0x727开源安全团队微信归档索引（202108-202110）
- [[0x6270-security-team-wechat-archive-202203-202304]] — 0x6270安全团队微信归档索引（202203-202304）

---

## 团队成员贡献致谢

感谢以下团队成员多年来的技术贡献与内容创作：
- **Poacher** - Struts2工具、MySQL监控、We-Report、招聘网站、MD5平台
- **王艾** - WeBug靶场、自动化扫描工具、新一代靶场
- **怪大叔** - WeBug靶场、新一代靶场、书籍挑选奖励
- **下辈子做头猪** - WeBug靶场
- **霾** - WeBug靶场、RCE工具框架、插件开发手册
- **shiyan** - SecEssay知识平台
- **肥二星** - Telegram机器人、自动化扫描工具
- **小笼包** - 书籍挑选奖励
- **各位学员** - 众多学员作品与实战复现文章
- **社区投稿作者** - 持续贡献原创技术内容的安全研究者

---

*页面持续更新中，欢迎补充更多历史文章条目与交叉引用。*

## 来源

- [226安全团队-201805-202103_37](../sources/226安全团队-201805-202103_37.md)
