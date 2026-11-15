---
title: 226安全团队开源项目全景
description: 系统梳理 226 安全团队发布的十大开源安全工具与平台，涵盖 Struts2 利用工具、MySQL 日志审计、Webug 靶场、we-report
  报告生成、SecEssay 知识分享、rce工具插件化框架等核心项目的功能定位、技术栈与获取地址
category: program-analysis
tags:
- 226安全团队
- 开源工具
- 安全工具
- 漏洞利用
- 靶场
- 报告自动化
- 知识管理
- 插件化框架
- CTF
- 渗透测试
date: 2021-03-15
updated: '2026-11-15'
---

# 226安全团队开源项目全景

> 来源：226安全团队微信公众号归档文章《[总结]回首我们做过的》（2021-03-15），汇总团队成立五年以来发布的十大开源项目及进行中项目。

---

## 项目速览表

| 序号 | 项目名称 | 核心定位 | 作者 | 开源地址 | 状态 |
|------|----------|----------|------|----------|------|
| 1 | Struts2漏洞利用工具Devmode版 | Struts2 漏洞利用/PoC 验证 | Poacher | [FreeBuf](https://www.freebuf.com/sectool/108896.html) | 已发布 |
| 2 | MySQL日志监控工具 | MySQL 审计日志分析/监控 | Poacher | [GitHub](https://github.com/wangai3176/mysql_Monitor_tools_code) | 已发布 |
| 3 | **Webug 靶场** | Web 漏洞实战靶场（基础/中级/高级） | 王艾、怪大叔等 | [GitHub](https://github.com/wangai3176/webug4.0) | 已发布 v4.0 |
| 4 | **we-report 报告生成平台** | 渗透测试/漏洞报告一键生成 | Poacher | [GitHub](https://github.com/wangai3176/we-report) | 已发布 |
| 5 | 招聘网站源码 (226job) | 基于乌云招聘前端的后端实现 | Poacher | [GitHub](https://github.com/wangai666/226job) | 已发布 |
| 6 | MD5 解密平台 (226md5) | 社区协作式 MD5 碰撞/字典解密 | — | [GitHub](https://github.com/wangai3176/226md5) | 已发布 |
| 7 | **SecEssay** | 团队/个人安全知识碎片化收藏与分享 | shiyan | [GitHub](https://github.com/wangai3176/SecEssay_Collect) | 已发布 |
| 8 | **rce工具 (rcetool)** | 图形化、插件化漏洞利用框架（Java 插件） | 霾 | [GitHub](https://github.com/kuiguansec/rcetool) | 已发布 |
| 9 | Telegram 机器人 | 文章聚合/查询类 Bot | 肥二星 | [GitHub](https://github.com/wangai3176/TelegramBotDemoService) | 已发布 |
| 10 | 安全招聘平台 | 面向安全行业的招聘系统 | — | 未开源 | 规划中 |

---

## 核心项目深度解析

### Struts2漏洞利用工具 Devmode 版

- **功能**：针对 Struts2 系列漏洞（如 S2-045、S2-046 等）提供统一图形化利用界面，支持命令执行、反弹 Shell、文件上传等常见利用场景。
- **技术栈**：Java（Swing/JavaFX），附带完整源码便于二次开发。
- **获取**：FreeBuf 文章附件或团队历史 Release。
- **关联**：可配合 [[struts2-memory-shell-injection]] 理解 Struts2 内存马注入的后利用链路。

### MySQL 日志监控工具

- **来源**：在 [seay](https://github.com/seay) 代码审计工具中提取的日志分析模块二次开发。
- **能力**：解析 MySQL General Log / Slow Query Log / Audit Log，提取可疑 SQL、高频报错、敏感操作（`LOAD_FILE`、`INTO OUTFILE`、UDF 注册等）。
- **定位**：代码审计辅助、事后取证、合规审计。
- **地址**：`github.com/wangai3176/mysql_Monitor_tools_code`

### Webug 靶场（v4.0）

> **“我们的漏洞”** —— 覆盖基础、中级、高级三层次的 Web 安全实战环境。

- **架构**：
  - 基础环境：PHP + MySQL，纯净 Windows Server 2003 虚拟机镜像分发。
  - 中/高级环境：真实 CVE/历史漏洞复现场景（Struts2、ThinkPHP、Fastjson、Shiro 等）。
- **特色**：
  - 一键部署，无需配置环境依赖。
  - 配套视频教程（公众号历史消息「webug基础教程视频学习」）。
- **地址**：`github.com/wangai3176/webug4.0`
- **交叉引用**：
  - [[ctf-training-platforms-collection]] 已收录 Webug 4.0 为离线靶场合集核心成员。
  - [[pikachu-target-writeup-part1-setup-brute-force]]、[[pikachu-target-writeup-part2-xss]] 等 Pikachu 系列可作为同类靶场对比学习。

### we-report 报告生成平台

- **痛点**：乙方渗透测试报告撰写繁琐、格式不统一、耗时长。
- **方案**：Web 端一键导入漏洞数据（支持 CSV/JSON/手工录入）→ 模板化渲染（Word/PDF/HTML）→ 自动生成符合等保/HVV/PCI-DSS 等合规规范的报告。
- **技术栈**：Python (Flask/Django) + 前端模板引擎 + `python-docx` / `reportlab`。
- **地址**：`github.com/wangai3176/we-report`
- **同类对比**：
  - [[0x727-bugreporter-automated-report-platform]]：0x727 团队基于 Python/PHP 实现的同类平台，含 Nginx 安全加固配置。
  - [[codetest-visual-poc-exploitation-tool]]：红队可视化漏洞扫描/利用工具，亦含报告导出功能。

### 招聘网站源码 (226job)

- **背景**：参考已关闭的「乌云招聘」前端风格，补全后端业务逻辑。
- **特性**：前后端分离可选、后台无登录态（演示用）、开源协议允许商用二开。
- **地址**：`github.com/wangai666/226job`

### MD5 解密平台 (226md5)

- **模式**：社区众包字典 + 去重存储，类似早期 somd5 / cmd5。
- **现状**：代码开源，运营实例因精力停止维护。
- **地址**：`github.com/wangai3176/226md5`

### SecEssay — 安全知识碎片化收藏平台

- **灵感**：Sec-News / 团队内部分享链接沉淀难、搜索难。
- **核心流程**：
  1. 一键转发链接/标题/标签 → 后台自动抓取正文/摘要。
  2. 全文检索 + 标签聚合 + 作者/时间线维度。
  3. 支持 Markdown 导出、PDF 归档、团队私有部署。
- **定位**：轻量级「团队知识库」或「个人安全笔记本」。
- **地址**：`github.com/wangai3176/SecEssay_Collect`

### rce工具 (rcetool) — 插件化漏洞利用框架

- **架构**：
  - **核心框架**：Java Swing/JavaFX 图形化主程序，负责插件加载、任务调度、结果聚合。
  - **插件规范**：标准 Java 接口 `ExploitPlugin`，实现 `exploit(target, params)`、`getInfo()` 等方法。
  - **现状**：仅内置 Java 插件示例，支持热加载、第三方 Jar 放入 `plugins/` 即用。
- **路线图**：
  - 多语言插件支持（Python/Go/JS 通过子进程/Embedded 解释器）。
  - 插件市场、签名验证、自动更新。
  - 配套《插件开发手册》编写中（作者：霾）。
- **地址**：`github.com/kuiguansec/rcetool`
- **关联生态**：
  - [[pocsuite3-vulnerability-testing-framework]]：Knownsec 404 团队的 PoC 编写/验证框架，CLI 为主，可作为插件来源参考。
  - [[codetest-visual-poc-exploitation-tool]]：同为可视化漏洞利用工具，支持 Python PoC/EXP 统一管理。

### Telegram 机器人 (TelegramBotDemoService)

- **定位**：文章聚合推送、关键词订阅、CVE/工具快速检索。
- **技术栈**：Java/Kotlin + Telegram Bot API + 定时任务抓取 RSS/公众号/安全资讯源。
- **地址**：`github.com/wangai3176/TelegramBotDemoService`

---

## 进行中项目（规划/开发中）

| 项目 | 负责人 | 关键目标 | 预计交付 |
|------|--------|----------|----------|
| 自动化漏洞扫描工具（半自动化结合） | 肥二星、王艾 | 资产发现 → 指纹识别 → PoC 验证 → 漏洞确证 → 报告输出全流程自动化 | — |
| 下一代靶场（已研发 2 年） | 怪大叔、王艾 | 真实业务逻辑漏洞复现、动态 Flag、容器化部署、CTFd 集成 | — |
| rcetool 插件生态 & 开发手册 | 霾 | 标准化插件 SDK、签名分发、文档化降低门槛 | — |

---

## 团队历史技术文章索引（节选）

文章涵盖：**漏洞挖掘复现**、**代码审计**、**内网渗透**、**CTF 实战**、**工具开发**、**区块链安全**、**移动安全** 等方向。

| 类别 | 代表标题 | 发布时间 |
|------|----------|----------|
| CMS 漏洞 | Catfish CMS 任意图片删除 / 存储型 XSS / IWebShop 任意删除文件 / 蝉知 CMS 7.0.1 后台 Getshell | 2018-2019 |
| 框架漏洞 | Metinfo 6.1.2 SQL注入 / ThinkPHP 3.2 学习 / Fastjson 最新利用（内部分享） | 2019-2020 |
| 内网渗透 | 一次内网渗透端口转发引发的思考 / 内网记录(一) | 2019 |
| 免杀/对抗 | Excel 4.0 宏躲避杀软检测 / QQ社工神器之我发EXE你敢点吗 | 2019-2020 |
| 代码审计 | 后台数据库任意删除/下载文件 / Windows 任意文件读取 | 2019 |
| 学员作品 | SQLMAP手册 / upload-labs 上传绕过总结 / PHP入门基础 / FFmpeg 任意文件读取 (CVE-2016-1897) / IIS PUT 写入 | 2020 |
| 基础科普 | 浅谈 Cookie 安全 / 从开发角度浅谈 CSRF 攻击及防御 / 关于 HTTP 长连接 | 2019-2020 |
| 移动/硬件 | nodeMCU 固件刷入到 WiFi 扫描 / 安卓逆向入门（一~三） | 2019 |
| 区块链 | SIM token 自动化薅羊毛攻击还原 | 2019 |
| 其它 | 好奇驱使我对 XSS 平台的一次小研究 / 保护宅男——拒绝黄赌毒 / 我是如何用度娘拿下 CSDN 钓鱼网站 | 2019-2020 |

> 完整文章列表及链接见归档页：[[226-security-team-wechat-archive-201805-202103]]

---

## 关联知识库页面

- [[226-security-team-wechat-archive-201805-202103]] — 226安全团队微信归档索引页（含本文来源）。
- [[ctf-training-platforms-collection]] — CTF Web 靶场离线合集（含 Webug 4.0）。
- [[0x727-bugreporter-automated-report-platform]] — 0x727 团队同类报告自动化平台。
- [[pocsuite3-vulnerability-testing-framework]] — PoC 编写/验证框架，可为 rcetool 提供插件来源。
- [[struts2-memory-shell-injection]] — Struts2 内存马注入技术，关联 Struts2 利用工具后利用。
- [[xd-security-pentest-course-curriculum]] — 小迪安全渗透测试课程，含报告撰写、靶场实战等配套教学。

---

## 结语

226安全团队五年间以「实战需求驱动开源」为主线，产出覆盖 **漏洞利用、靶场建设、报告自动化、知识管理、插件化框架** 五大赛道的十余个项目。虽部分项目因人员变动停止维护，但其**工程化思路（模板化报告、插件化框架、众包字典）与实战沉淀（真实漏洞环境、乙方痛点）** 仍具参考价值。进行中的「下一代靶场」「自动化扫描」「rcetool 插件生态」若能落地，将进一步补全「从侦察到报告」的红队工程化链路。

## 来源

- [226安全团队-201805-202103_02](../sources/226安全团队-201805-202103_02.md)
