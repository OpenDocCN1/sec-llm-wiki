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

> 来源：226安全团队微信公众号归档文章《[总结]回首我们做过的》（2021-03-15），汇总团队成立五年以来发布的十大开源项目及进行中项目。本页在既有内容基础上，**大幅完善 Webug 4.0 靶场的漏洞覆盖清单、虚拟机环境特性、新增模块（乌云知识库、MD5 解密、计划中的 CMS/CTF 模块）等细节**，并补充团队 400 天间歇期的心路历程与招聘信息。

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

### Webug 靶场（v4.0）—— 重点完善

> **“我们的漏洞”** —— 覆盖基础、中级、高级三层次的 Web 安全实战环境。v4.0 版本历经 400 余天打磨，代码全量重构，漏洞覆盖面大幅扩展，新增多个实战辅助模块。

#### 架构与部署

- **基础环境**：PHP + MySQL，纯净版 Windows Server 2003 虚拟机镜像分发（含中/高级环境所需的真实 CVE/历史漏洞复现场景：Struts2、ThinkPHP、Fastjson、Shiro 等）。
- **部署方式**：一键导入虚拟机即用，无需额外配置环境依赖。
- **配套教程**：公众号历史消息「webug基础教程视频学习」（B 站 35 集系统视频）。
- **交叉引用**：
  - [[ctf-training-platforms-collection]] 已收录 Webug 4.0 为离线靶场合集核心成员。
  - [[pikachu-target-writeup-part1-setup-brute-force]]、[[pikachu-target-writeup-part2-xss]] 等 Pikachu 系列可作为同类靶场对比学习。

#### 详细漏洞覆盖清单（v4.0 新增/完善）

##### SQL 注入（7 大类，含 Flag 验证）

| 编号 | 注入类型 | 说明 | Flag 验证 |
|------|----------|------|-----------|
| 1.1 | 报错注入 | 利用 `floor(rand(0)*2)`、`extractvalue`、`updatexml` 等函数触发报错回显 | ✅ |
| 1.2 | 布尔注入 | 基于页面真/假响应差异的布尔盲注 | ✅ |
| 1.3 | 延时注入 | 基于 `SLEEP()`/`BENCHMARK()` 等时间延迟的盲注 | ✅ |
| 1.4 | CSV 注入 | 导出 CSV 文件时公式注入（`=cmd|' /C calc'!A0` 等） | — |
| 1.5 | POST 注入 | HTTP POST 参数体中的注入点 | ✅ |
| 1.6 | XML 注入 | XML 格式参数中的注入（如 SOAP、XML-RPC） | ✅ |
| 1.7 | 注入过滤绕过 | 针对常见 WAF/过滤规则（空格、注释、关键字、大小写、编码）的绕过技巧 | ✅ |

> 关联技术页：[[sqlmap-comprehensive-guide]]、[[ctfshow-web-sql-injection-bypass-basics]]、[[mysql-duplicate-entry-error-based-sqli]]、[[mysql-dnslog-injection-loadfile-unc]]

##### XSS 跨站脚本攻击（5 大类，含 Flag 验证）

| 编号 | XSS 类型 | 说明 | Flag 验证 |
|------|----------|------|-----------|
| 2.1 | 反射型 XSS | URL 参数直接回显未过滤，构造恶意链接触发 | ✅ |
| 2.2 | 存储型 XSS | 恶意脚本存入数据库，后续访问页面触发 | ✅ |
| 2.3 | DOM 型 XSS | 前端 JS 处理 `location.hash`/`document.referrer` 等导致 DOM 渲染时执行 | ✅ |
| 2.4 | 链接注入 | `href`/`src` 等属性注入 `javascript:` 伪协议或 `data:` 协议 | — |
| 2.5 | 基于过滤的存储型 XSS | 针对 `htmlspecialchars`、关键字过滤、标签白名单等防御的绕过技巧 | ✅ |

> 关联技术页：[[pikachu-target-writeup-part2-xss]]、[[xss-haozi-lab-walkthrough]]、[[discuz-x32-stored-dom-xss-bbcode-analysis]]、[[websocket-vulnerabilities-analysis]]、[[cookie-security-fundamentals]]

##### 任意文件下载（1 类）

- 利用 `../` 目录穿越、绝对路径、编码绕过等手法下载服务器敏感文件（`/etc/passwd`、`web.config`、源码备份等）。

##### 文件上传漏洞（5 大类，含 Flag 验证）

| 编号 | 绕过类型 | 核心技术点 | Flag 验证 |
|------|----------|------------|-----------|
| 4.1 | 前端拦截绕过 | 禁用 JS、修改 `accept` 属性、Burp Suite 修改包绕过前端校验 | ✅ |
| 4.2 | 解析漏洞利用 | IIS 6.0/7.5、Nginx `<=0.8.37`、Apache 多后缀解析漏洞 | ✅ |
| 4.3 | 畸形文件上传 | 文件头伪造（GIF89a）、内容混淆、多文件上传数组绕过 | ✅ |
| 4.4 | `.htaccess` 文件上传 | 上传 `.htaccess` 修改解析规则（`AddType application/x-httpd-php .jpg`） | ✅ |
| 4.5 | 截断上传 | PHP `<5.3.4` `%00` 截断、长文件名截断、数组键名截断 | ✅ |

> 关联技术页：[[upload-labs-file-upload-bypass-writeup]]、[[pikachu-target-writeup-part4]]、[[java-arbitrary-file-upload-mitigation]]、[[cnvd-2021-49104-eoffice-v9-file-upload-rce]]

##### 逻辑漏洞（4 大类，含 Flag 验证）

| 编号 | 逻辑漏洞类型 | 攻击场景 | Flag 验证 |
|------|--------------|----------|-----------|
| 5.1 | 越权修改密码 | 水平/垂直越权修改任意用户密码（IDOR、未校验当前用户权限） | — |
| 5.2 | 支付漏洞 | 修改支付金额、订单状态、重复支付、绕过支付流程 | — |
| 5.3 | 邮箱轰炸 | 短信/邮件接口无频率限制、无验证码、可批量发送 | — |
| 5.4 | 越权信息查看 | 遍历 ID/参数查看他人订单、个人信息、后台管理员数据 | ✅ |

> 关联技术页：[[xd-security-logic-vulnerability-notes-day33-36]]、[[wecenter-v334-phar-deserialization-sqli]]、[[leanote-markdown-xss-to-electron-rce-case-study]]

##### 其他漏洞类型（6 类）

| 编号 | 漏洞类型 | 核心利用点 |
|------|----------|------------|
| 6.1 | URL 跳转/重定向 | `Location` 头未校验域、JS `location.href` 可控、开放重定向链 |
| 6.2 | 文件包含 (LFI/RFI) | `include/require` 动态参数未过滤、`php://filter` 读取源码、`data://` 协议执行代码 |
| 6.3 | 命令执行 (RCE) | `system/exec/shell_exec/passthru/popen` 等函数参数可控、反引号、管道符注入 |
| 6.5 | SSRF (服务端请求伪造) | `file_get_contents/curl/fopen` 访问内网服务、`file://` 读文件、`gopher://` 攻击 Redis/MySQL、`dict://` 探测端口 |
| 6.8 | CSRF (跨站请求伪造) | 关键操作无 Token/Referer 校验、Token 固定/泄露、GET 型 CSRF |

> 关联技术页：[[php-file-inclusion-vulnerability]]、[[ssrf-bypass-techniques]]、[[ssrf-ctf-exploitation-guide]]、[[xd-security-csrf-ssrf-rce-notes-day29-30]]、[[php-webshell-fundamentals-chopper-analysis]]

#### 新增特色模块

| 模块名称 | 状态 | 功能描述 |
|----------|------|----------|
| **乌云知识库** | 已上线 | 集成乌云漏洞平台历史漏洞库（Wooyun 已关闭），提供漏洞检索、详情查看、复现参考，辅助学习真实漏洞案例。 |
| **MD5 解密** | 已上线 | 集成社区协作式 MD5 碰撞/字典解密接口（关联团队开源项目 [[226md5](https://github.com/wangai3176/226md5)]），后续计划上线自建解密集群。 |
| **CMS 模块** | 规划中 | 对比 v3.0 优势，有序整理主流 CMS（DedeCMS、ThinkCMF、Phpcms、WordPress 等）漏洞复现环境，提供一键部署的 CMS 靶场矩阵。 |
| **CTF 模块** | 规划中 | 面向 CTF 竞技训练，收录 Web/Misc/Crypto/Pwn/Reverse 多方向题目环境，支持动态 Flag、容器化部署、CTFd 集成。 |
| **靶场分类/难度选择** | 已上线 | 新增按「简易度/难度」分类浏览靶场，便于新手按阶梯进阶。 |
| **招聘模块** | 已上线 | 嵌入团队招聘官网 `http://job.226safe.com`，面向安全人才招聘（开发、运营、逆向、UI、大数据处理等）。 |

#### 社区共建机制

> **“如果小伙伴们有自己的环境，也可以发送给我们进行添加至 webug 中，请将环境搭建及环境利用过程以 word 格式发送至 3176184967@qq.com，我们将审核后带版权添加至环境中。”**

- 接受外部贡献的漏洞环境、复现文档、利用脚本。
- 审核通过后以贡献者署名形式纳入靶场，形成「官方维护 + 社区共建」的生态闭环。

#### 下载与官网

- **百度网盘下载**：`https://pan.baidu.com/s/1u_N58cb10rlDZ-FsH_BTSw`（含纯净 Win2003 虚拟机镜像 + 靶场源码 + 使用手册）
- **Webug 官网**：`http://www.webug.org`

#### 团队心声：400 天的间歇与坚持

> 原文摘录：“曾几何时，说实话我放弃过 Webug 的更新，因为它对我来说并不盈利，而且是开源……最终让我决定更新的是他们：**猪哥（下辈子做头猪）、鑫哥、K师傅（K0r4dji）**，在他们的支持下完成了 Webug4.0 更新。”

- **背景**：v3.0 发布后 400 余天未更新，团队曾因“非盈利、开源维护成本高、竞品涌现”考虑放弃。
- **转折**：核心成员相互支持，坚持“为新手提供免费基础靶场”的初心，完成 v4.0 重构。
- **定位**：不追求“大而全”，专注“基础扎实、部署简单、配套教程全”的入门级靶场，作为安全初学者踏上梦想道路的“稻草之一”。

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
- **现状**：代码开源，运营实例因精力停止维护；Webug 4.0 集成该模块接口。
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

## 团队招聘信息（v4.0 发布同期）

- **联系方式**：QQ 3176184967 / E-mail 3176184967@qq.com
- **简历模板**：`http://t.cn/Ec2FDjn`
- **需求方向**：开发、运营、逆向、UI、大数据处理等（“只要有一技之长，我们欢迎你”）

---

## 关联知识库页面

- [[226-security-team-wechat-archive-201805-202103]] — 226安全团队微信归档索引页（含本文来源）。
- [[ctf-training-platforms-collection]] — CTF Web 靶场离线合集（含 Webug 4.0）。
- [[0x727-bugreporter-automated-report-platform]] — 0x727 团队同类报告自动化平台。
- [[pocsuite3-vulnerability-testing-framework]] — PoC 编写/验证框架，可为 rcetool 提供插件来源。
- [[struts2-memory-shell-injection]] — Struts2 内存马注入技术，关联 Struts2 利用工具后利用。
- [[xd-security-pentest-course-curriculum]] — 小迪安全渗透测试课程，含报告撰写、靶场实战等配套教学。
- [[sqlmap-comprehensive-guide]] — SQLMap 实战指南，可配合 Webug 注入关卡练习。
- [[upload-labs-file-upload-bypass-writeup]] — 文件上传绕过全技法，对标 Webug 4.1-4.5 关卡。
- [[pikachu-target-writeup-part2-xss]] / [[xss-haozi-lab-walkthrough]] — XSS 实战对比学习。
- [[xd-security-logic-vulnerability-notes-day33-36]] — 逻辑漏洞系统化梳理，对标 Webug 5.1-5.4 关卡。
- [[ssrf-bypass-techniques]] / [[ssrf-ctf-exploitation-guide]] — SSRF 绕过与利用链，对标 Webug 6.5 关卡。

---

## 结语

226安全团队五年间以「实战需求驱动开源」为主线，产出覆盖 **漏洞利用、靶场建设、报告自动化、知识管理、插件化框架** 五大赛道的十余个项目。虽部分项目因人员变动停止维护，但其**工程化思路（模板化报告、插件化框架、众包字典）与实战沉淀（真实漏洞环境、乙方痛点）** 仍具参考价值。Webug 4.0 作为团队旗舰级开源靶场，通过**代码全量重构、7 大类 SQLi / 5 类 XSS / 5 类上传 / 4 类逻辑漏洞的系统性覆盖、Win2003 虚拟机一键部署、乌云知识库/MD5 解密等辅助模块内置、社区共建机制引入**，显著降低了 Web 安全初学者的环境搭建与知识检索门槛。进行中的「下一代靶场」「自动化扫描」「rcetool 插件生态」若能落地，将进一步补全「从侦察到报告」的红队工程化链路。

## 来源

- [226安全团队-201805-202103_02](../sources/226安全团队-201805-202103_02.md)
- [226安全团队-201805-202103_26](../sources/226安全团队-201805-202103_26.md)
