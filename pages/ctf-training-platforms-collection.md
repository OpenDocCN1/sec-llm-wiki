---
title: CTF Web靶场离线打包合集与快速部署指南
description: 汇总主流CTF Web靶场离线打包合集，含BWVS、Pikachu、Webug4.0、Sqlilabs、Uploadlabs、XXE、XSS七大平台，基于Win2003+phpStudy快速部署指南，新增Webug
  4.0详细漏洞类型分类（报错/布尔/延时/CSV/POST/XML注入、反射/存储/DOM XSS、前端/解析/畸形/.htaccess/截断上传、越权/支付/邮箱轰炸逻辑漏洞、SSRF/CSRF/命令执行/文件包含/URL跳转）、系统性视频教程目录（B站35集）、Docker部署指引及官网下载地址
category: program-analysis
tags:
- CTF
- Web安全
- 靶场
- BWVS
- Pikachu
- Webug
- Sqlilabs
- Uploadlabs
- XXE
- XSS
- phpStudy
- Win2003
- 离线部署
- 渗透测试练习
- Docker
- 视频教程
- SQL注入
- XSS
- 文件上传
- 逻辑漏洞
- SSRF
- CSRF
date: 2024-01-15
updated: '2026-11-15'
---

## 概述

本页面整理主流 CTF Web 靶场离线打包合集，包含 **7 个经典平台**，涵盖综合靶场与单项漏洞专项靶场两大类别。所有靶场均预配置在 **Windows Server 2003 + phpStudy** 环境中，下载解压后即可通过 phpStudy 一键启动，无需手动配置数据库、虚拟主机等繁琐步骤，极大降低初学者环境搭建门槛。

> 来源：微信公众号归档文章《靶场合辑来了》，原文提供百度网盘下载链接（公众号回复“靶场”获取）。

**本次更新亮点**：
- **全面扩充 Webug 4.0 条目**：细化其 30+ 个漏洞子类型分类（SQL注入6类、XSS 5类、文件上传5类、逻辑漏洞4类、其他5类），并建立与知识库现有技术页面的交叉引用
- **补充官方下载地址与官网链接**：百度网盘下载、Webug 官网、GitHub 源码仓库
- **保留 Webug 4.0 系统性视频教程目录（B站 35 集）**、**Docker 部署指引** 及 **学习路径建议**，完善靶场实战学习资源链路

---

## 快速部署指南

### 环境要求
- **宿主机**：VMware Workstation / VirtualBox 等虚拟化软件
- **客户机**：Windows Server 2003 (32位/64位均可)
- **集成环境**：phpStudy 2016/2018 版本（已内置 Apache + MySQL + PHP 5.4+）

### 部署步骤
1. **导入虚拟机**：将下载的 Win2003 虚拟机镜像导入虚拟化软件，启动并进入系统
2. **启动 phpStudy**：桌面双击 `phpStudy.exe`，点击“启动”按钮，待 Apache 与 MySQL 状态均变为“运行中”
3. **验证访问**：在虚拟机内部浏览器访问 `http://localhost` 或宿主机浏览器访问 `http://<VM_IP>`，出现靶场导航页即为成功
4. **数据库确认**：phpStudy 默认 MySQL root 密码为 `root`，如靶场需单独导入 SQL 文件，请使用 phpStudy 自带的 phpMyAdmin 或命令行导入

> ⚠️ **注意**：Win2003 已停止安全更新，仅建议在**隔离网络/仅主机模式**下用于教学练习，切勿暴露在公网。

### Webug 4.0 官方资源链接
| 资源类型 | 地址 | 备注 |
|----------|------|------|
| **官方下载 (百度网盘)** | https://pan.baidu.com/s/1u_N58cb10rlDZ-FsH_BTSw | 226安全团队官方发布，含 Win2003 虚拟机镜像 |
| **Webug 官网** | http://www.webug.org | 靶场官方主页，含文档、更新日志 |
| **GitHub 源码仓库** | https://github.com/wangai3176/webug4.0 | 源码、Dockerfile、Issue 追踪 |

### Webug 4.0 Docker 部署（现代环境替代方案）
除传统虚拟机部署外，可使用 Docker 快速拉起 Webug 4.0 环境，适合 Linux/macOS/Windows (WSL2) 用户：

```bash
# 1. 克隆源码（含 Dockerfile）
git clone https://github.com/wangai3176/webug4.0.git
cd webug4.0

# 2. 构建镜像
docker build -t webug4.0 .

# 3. 运行容器（映射 80 端口，后台运行）
docker run -d -p 80:80 --name webug4 webug4.0

# 4. 访问验证
# 浏览器打开 http://localhost 或 http://<Docker_HOST_IP>
```

> 详细 Docker 搭建步骤参考：[Webug Docker 部署指引](https://linuz.me/2019/08/04/Webug-docker/)  
> 源码仓库：[wangai3176/webug4.0](https://github.com/wangai3176/webug4.0)

---

## 靶场清单分类

### 一、 综合靶场（多漏洞类型集成）

| 靶场名称 | 核心特点 | 适用阶段 | 相关进阶页面 |
|----------|----------|----------|--------------|
| **BWVS** (Broken Web Vulnerability Suite) | 涵盖 SQLi、XSS、文件上传、命令执行、文件包含等 20+ 漏洞模块，分级设计 | 入门→进阶系统练习 | — |
| **Pikachu** | PHP 原生漏洞演示，含暴力破解、XSS、CSRF、SQLi、RCE、文件包含/上传、越权、反序列化、XXE、SSRF 等完整模块 | 入门→进阶系统练习 | [[pikachu-target-writeup-part1-setup-brute-force]], [[pikachu-target-writeup-part2-xss]], [[pikachu-target-writeup-part3]], [[pikachu-target-writeup-part4]], [[pikachu-target-writeup-part5]] |
| **Webug 4.0** | 国内早期经典综合靶场，**漏洞类型齐全（30+子类）**，附带详细帮助文档、乌云知识库、MD5解密模块，**现已补充 B站 35 集系统视频教程** | 入门系统练习 | [[webug-4.0-video-tutorial-catalog]], **下文详细漏洞分类表** |

> **Pikachu 靶场深度复现系列** 已在知识库建立 5 篇专题页面，覆盖从环境搭建到各漏洞模块的完整利用链分析，建议按顺序阅读。

---

### 二、 单项漏洞专项靶场（深度攻防）

| 靶场名称 | 专注漏洞类型 | 核心价值 | 相关进阶页面 |
|----------|--------------|----------|--------------|
| **Sqlilabs** (Less-1 ~ Less-65) | SQL 注入全谱系：报错注入、布尔盲注、时间盲注、堆叠注入、宽字节注入、二阶注入、WAF 绕过等 | SQLi 从入门到精通的“教科书”级靶场 | [[ctfshow-web-sql-injection-bypass-basics]], [[mysql-duplicate-entry-error-based-sqli]], [[mysql-dnslog-injection-loadfile-unc]], [[ctf-show-php-command-execution-bypass-techniques]] |
| **Uploadlabs** (Pass-01 ~ Pass-20) | 文件上传绕过：前端 JS 校验、Content-Type、魔数、二次渲染、解析漏洞、.htaccess、大小写、空格/点绕过、条件竞争等 | 文件上传 Getshell 实战技巧大全 | [[php-file-inclusion-vulnerability]], [[cnvd-2021-49104-eoffice-v9-file-upload-rce]], [[xd-security-waf-bypass-techniques-day46-49]] |
| **XXE Lab** | XML 外部实体注入：基础文件读取、Blind XXE 带外外带、UTF-16BE 绕过、内网探测、Gopher/HTTP 协议利用 | XXE 攻击链完整复现 | [[xxe-xml-dtd-fundamentals]], [[xxe-prevention-java-jaxp]], [[xd-security-deserialization-xxe-notes-day37-39]] |
| **XSS Platform / XSS Lab** | 跨站脚本攻击：反射型、存储型、DOM 型、盲打、过滤绕过、CSP 绕过、XSS 钓鱼、键盘记录等 | XSS 利用与绕过技巧系统训练 | [[xss-haozi-lab-walkthrough]], [[pikachu-target-writeup-part2-xss]], [[xd-security-xss-vulnerability-notes-day25-28]] |

---

## Webug 4.0 详细漏洞分类与对应知识库页面 {#webug-4.0-vulnerability-classification}

> 基于 226安全团队官方发布文章《[新年礼物]Webug4.0 基础是梦的基石》整理，覆盖 **6 大类 30+ 子类** 漏洞场景。每项均标注是否含 Flag 验证机制，并映射至知识库现有深度技术页面，形成“靶场实战 → 原理深挖 → 交叉引用”闭环。

### SQL 注入（7 子类）

| 编号 | 漏洞子类型 | Flag验证 | 核心技术点 | 对应知识库深度页面 |
|------|------------|:--------:|------------|-------------------|
| 1.1 | **报错注入** | ✅ | `floor(rand(0)*2)` + `GROUP BY` 触发 Duplicate Entry 报错回显 | [[mysql-duplicate-entry-error-based-sqli]], [[ctfshow-web-sql-injection-bypass-basics]] |
| 1.2 | **布尔盲注** | ✅ | 条件判断推断、逐位提取、脚本自动化 | [[ctfshow-web-sql-injection-bypass-basics]] |
| 1.3 | **延时注入** | ✅ | `sleep()`/`benchmark()` 时间差推断、盲注脚本 | [[ctfshow-web-sql-injection-bypass-basics]] |
| 1.4 | **CSV 注入** | ❌ | 公式注入导出 CSV、远程执行/数据外带 | — |
| 1.5 | **POST 注入** | ✅ | HTTP Body 参数注入、Burp Suite 实战、Content-Type 处理 | [[ctfshow-web-sql-injection-bypass-basics]] |
| 1.6 | **XML 注入** | ✅ | XML 实体注入、XXE 结合 SQLi、解析器差异 | [[xxe-xml-dtd-fundamentals]] |
| 1.7 | **注入过滤绕过** | ✅ | WAF/关键字过滤绕过、编码/注释/大小写变形 | [[xd-security-waf-bypass-techniques-day46-49]], [[ctfshow-web-sql-injection-bypass-basics]] |

> **宽字节注入** 原在 Webug 3.x 单独列出，4.0 融合至“注入过滤绕过”实战中，参考 [[ctfshow-web-sql-injection-bypass-basics]] 宽字节专节。

---

### XSS 跨站脚本攻击（5 子类）

| 编号 | 漏洞子类型 | Flag验证 | 核心技术点 | 对应知识库深度页面 |
|------|------------|:--------:|------------|-------------------|
| 2.1 | **反射型 XSS** | ✅ | URL 参数直接回显、未过滤输出、钓鱼链接构造 | [[xss-haozi-lab-walkthrough]], [[pikachu-target-writeup-part2-xss]] |
| 2.2 | **存储型 XSS** | ✅ | 恶意脚本持久化存储、后台/前台触发、蠕虫传播 | [[pikachu-target-writeup-part2-xss]], [[xd-security-xss-vulnerability-notes-day25-28]] |
| 2.3 | **DOM 型 XSS** | ✅ | 前端 JS 动态渲染、source/sink 分析、无服务端交互 | [[pikachu-target-writeup-part2-xss]], [[discuz-x32-stored-dom-xss-bbcode-analysis]] |
| 2.4 | **链接注入** | ❌ | `<a href>` 属性注入、伪协议 `javascript:`、`data:` 利用 | [[xss-haozi-lab-walkthrough]] |
| 2.5 | **基于过滤的存储型 XSS** | ✅ | 过滤规则绕过、事件处理器、编码混淆、CSP 绕过 | [[xd-security-xss-vulnerability-notes-day25-28]], [[xss-haozi-lab-walkthrough]] |

---

### 任意文件下载（1 子类）

| 编号 | 漏洞子类型 | Flag验证 | 核心技术点 | 对应知识库深度页面 |
|------|------------|:--------:|------------|-------------------|
| 3.1 | **任意文件下载** | ✅ | 目录遍历 `../`、路径拼接缺陷、敏感文件泄露（配置、源码、数据库） | [[php-file-inclusion-vulnerability]], [[xd-security-file-inclusion-notes]] |

---

### 文件上传漏洞（5 子类）

| 编号 | 漏洞子类型 | Flag验证 | 核心技术点 | 对应知识库深度页面 |
|------|------------|:--------:|------------|-------------------|
| 4.1 | **前端拦截绕过** | ✅ | JS 校验失效、Burp Suite 改包、禁用 JS、修改 Content-Type | [[upload-labs-file-upload-bypass-writeup]], [[xd-security-waf-bypass-techniques-day46-49]] |
| 4.2 | **解析漏洞利用** | ✅ | Apache/Nginx/IIS 解析规则、双后缀 `.php.jpg`、`.htaccess` 重写 | [[cnvd-2021-49104-eoffice-v9-file-upload-rce]], [[upload-labs-file-upload-bypass-writeup]] |
| 4.3 | **畸形文件上传** | ✅ | 魔数绕过 `GIF89a`、图片马制作、二次渲染绕过、Exif 注入 | [[upload-labs-file-upload-bypass-writeup]], [[php-webshell-fundamentals-chopper-analysis]] |
| 4.4 | **.htaccess 文件上传** | ✅ | 上传 `.htaccess` 修改解析配置、`AddType application/x-httpd-php .jpg` | [[upload-labs-file-upload-bypass-writeup]] |
| 4.5 | **截断上传** | ✅ | `%00` 空字节截断、PHP < 5.3.4、文件名长度截断、`move_uploaded_file` 绕过 | [[upload-labs-file-upload-bypass-writeup]], [[php-file-inclusion-vulnerability]] |

---

### 逻辑漏洞（4 子类）

| 编号 | 漏洞子类型 | Flag验证 | 核心技术点 | 对应知识库深度页面 |
|------|------------|:--------:|------------|-------------------|
| 5.1 | **越权修改密码** | ❌ | 水平越权/IDOR、用户 ID 可控、缺乏权限校验、密码重置链接泄露 | [[xd-security-logic-vulnerability-notes-day33-36]], [[pikachu-target-writeup-part4]] |
| 5.2 | **支付漏洞** | ❌ | 金额篡改（负数、0、小数）、并发竞争、订单状态绕过、回调接口伪造 | [[xd-security-logic-vulnerability-notes-day33-36]] |
| 5.3 | **邮箱轰炸** | ❌ | 接口无频率限制、验证码复用、批量发送、配置文件需填写发件邮箱 | — |
| 5.4 | **越权信息查看** | ✅ | 垂直越权、低权限访问高权限数据、会话固定、越权查看 admin 后台 | [[xd-security-logic-vulnerability-notes-day33-36]], [[pikachu-target-writeup-part4]] |

---

### 其他漏洞类型（5 子类）

| 编号 | 漏洞子类型 | Flag验证 | 核心技术点 | 对应知识库深度页面 |
|------|------------|:--------:|------------|-------------------|
| 6.1 | **URL 跳转/开放重定向** | ❌ | 302 跳转、Header Location、JS `location.href`、钓鱼利用、SSRF 结合 | [[ssrf-bypass-techniques]], [[xd-security-csrf-ssrf-rce-notes-day29-30]] |
| 6.2 | **文件包含 (LFI/RFI)** | ❌ | `include/require` 动态包含、目录遍历、伪协议 `php://filter`、`php://input`、`data://`、日志包含 Getshell | [[php-file-inclusion-vulnerability]], [[xd-security-file-inclusion-notes]], [[php伪协议与反序列化利用]] |
| 6.3 | **命令执行 (RCE)** | ❌ | `system/exec/passthru/shell_exec`、`backticks`、`proc_open`、管道符 `;` `|` `&` 绕过、`disable_functions` 绕过 | [[ctf-show-php-command-execution-bypass-techniques]], [[php-non-alphanumeric-webshell-construction]] |
| 6.4 | **SSRF (服务端请求伪造)** | ❌ | `file_get_contents/curl` 任意 URL 访问、内网探测、协议利用 `file://` `gopher://` `dict://`、绕过技巧 | [[ssrf-bypass-techniques]], [[ssrf-ctf-exploitation-guide]], [[xd-security-csrf-ssrf-rce-notes-day29-30]] |
| 6.5 | **CSRF (跨站请求伪造)** | ❌ | 无 Token 验证、Referer 校验缺失、SameSite Cookie 缺失、GET/POST 型 CSRF、构造 POC 自动提交 | [[xd-security-logic-vulnerability-notes-day33-36]], [[xd-security-csrf-ssrf-rce-notes-day29-30]], [[websocket-vulnerabilities-analysis]] |

---

## Webug 4.0 系统性视频教程目录（B站 35 集） {#webug-4.0-video-tutorial-catalog}

> 视频地址：[https://www.bilibili.com/video/av70249823/](https://www.bilibili.com/video/av70249823/)  
> 由安全研究员录制，覆盖 Webug 4.0 全关卡解题思路，配合“补充知识”章节夯实原理，适合**零基础入门 → 系统通关**的学习路径。

| 集数 | 标题 | 核心知识点 | 对应漏洞分类编号 | 对应知识库深度页面 |
|------|------|------------|------------------|-------------------|
| 01 | webug介绍与4.0安装 | 靶场简介、环境部署 | — | 本页面部署指南 |
| 02 | 补充知识之Mysql注入 | SQL 注入基础原理 | 1.1-1.7 | [[ctfshow-web-sql-injection-bypass-basics]] |
| 03 | 第1关_显错注入 | 报错注入实战 | 1.1 | [[mysql-duplicate-entry-error-based-sqli]] |
| 04 | 补充知识之布尔注入 | 布尔盲注原理 | 1.2 | [[ctfshow-web-sql-injection-bypass-basics]] |
| 05 | 布尔盲注(上) | 手工逐位提取 | 1.2 | — |
| 06 | 布尔盲注(下) | 脚本自动化提取 | 1.2 | — |
| 07 | 延时注入 | 时间盲注、sleep() 利用 | 1.3 | [[ctfshow-web-sql-injection-bypass-basics]] |
| 08 | POST注入 | POST 型注入、Burp 实战 | 1.5 | [[ctfshow-web-sql-injection-bypass-basics]] |
| 09 | 过滤注入 | WAF 绕过、编码/注释技巧 | 1.7 | [[xd-security-waf-bypass-techniques-day46-49]] |
| 10 | 补充知识之宽字节 | 宽字节注入原理（GBK） | 1.7 | [[ctfshow-web-sql-injection-bypass-basics]] |
| 11 | 宽字节注入 | 实战绕过 `addslashes` | 1.7 | — |
| 12 | 补充知识之XXE注入 | XXE 原理、实体声明 | 1.6 | [[xxe-xml-dtd-fundamentals]] |
| 13 | xxe注入 | 文件读取、Blind XXE 外带 | 1.6 | [[xxe-xml-dtd-fundamentals]], [[xd-security-deserialization-xxe-notes-day37-39]] |
| 14 | 补充知识之xss | XSS 分类、Payload 构造 | 2.1-2.5 | [[xss-haozi-lab-walkthrough]] |
| 15 | 三种xss | 反射型/存储型/DOM 型 | 2.1, 2.2, 2.3 | [[pikachu-target-writeup-part2-xss]] |
| 16 | 过滤xss | 过滤绕过、事件处理器 | 2.5 | [[xd-security-xss-vulnerability-notes-day25-28]] |
| 17 | 万能密码登录 | SQL 注入绕过登录认证 | 1.1/1.7 | [[ctfshow-web-sql-injection-bypass-basics]] |
| 18 | 链接注入 | 超链接参数注入 | 2.4 | — |
| 19 | 补充知识之任意文件下载 | 目录遍历、路径拼接缺陷 | 3.1 | [[php-file-inclusion-vulnerability]] |
| 20 | 任意文件下载 | 实战下载敏感文件 | 3.1 | — |
| 21 | mysql配置文件下载 | 读取 `my.cnf`/`my.ini` 拿凭证 | 3.1 | — |
| 22 | 补充知识之文件上传漏洞 | 上传绕过分类、解析漏洞 | 4.1-4.5 | [[php-file-inclusion-vulnerability]], [[xd-security-waf-bypass-techniques-day46-49]] |
| 23 | 文件上传(前端拦截) | JS 校验绕过、Burp 改包 | 4.1 | — |
| 24 | 文件上传(解析和截断) | 解析漏洞、%00 截断 | 4.2, 4.5 | [[cnvd-2021-49104-eoffice-v9-file-upload-rce]] |
| 25 | 文件上传(畸形文件) | 魔数绕过、图片马制作 | 4.3 | — |
| 26 | 补充知识之htaccess | .htaccess 解析配置利用 | 4.4 | — |
| 27 | 文件上传(htaccess) | 上传 .htaccess 解析 PHP | 4.4 | — |
| 28 | 越权修改密码 | 水平/垂直越权、IDOR | 5.1 | [[xd-security-logic-vulnerability-notes-day33-36]] |
| 29 | 支付漏洞 | 金额篡改、并发竞争 | 5.2 | [[xd-security-logic-vulnerability-notes-day33-36]] |
| 30 | 邮箱轰炸 | 接口滥用、验证码绕过 | 5.3 | — |
| 31 | 越权查看admin | 垂直越权、会话固定 | 5.4 | [[xd-security-logic-vulnerability-notes-day33-36]] |
| 32 | URL跳转 | 开放重定向、钓鱼利用 | 6.1 | [[ssrf-bypass-techniques]] |
| 33 | 文件包含漏洞 | LFI/RFI、伪协议利用 | 6.2 | [[php-file-inclusion-vulnerability]] |
| 34 | webshell爆破 | 弱口令爆破、字典攻击 | — | [[ctfshow-web-info-gathering-brute-force]] |
| 35 | 写到最后 | 学习心得、后续路线 | — | — |

> **学习建议**：按集数顺序观看，**先看“补充知识”再做对应关卡**，遇到不懂的原理即跳转右侧知识库深度页面查阅，形成“视频实战 + 理论深挖 + 交叉引用”的闭环。

---

## 学习路径建议

### 阶段 1：基础入门（1-2 周）
1. 部署环境，熟悉 phpStudy、phpMyAdmin、Burp Suite 基础操作
2. 从 **Pikachu** 的“暴力破解/验证码绕过”开始，掌握 Burp Intruder 四种模式 → [[pikachu-target-writeup-part1-setup-brute-force]]
3. 系统过一遍 **Pikachu XSS** 全类型 → [[pikachu-target-writeup-part2-xss]] / [[xss-haozi-lab-walkthrough]]
4. **新增**：跟随 **Webug 4.0 视频教程 01-03 集** 快速上手靶场环境与报错注入入门

### 阶段 2：核心漏洞深度（2-4 周）
| 漏洞类型 | 推荐靶场 | 关键练习目标 |
|----------|----------|--------------|
| SQL 注入 | **Sqlilabs** Less-1 到 Less-65 依次通关、**Webug 4.0 视频 02-11 集** | 手工构造 Payload、盲注脚本编写、WAF 绕过思路、宽字节注入实战 |
| 文件上传 | **Uploadlabs** Pass-01 到 Pass-20、**Webug 4.0 视频 22-27 集** | 每种绕过方式至少手工成功一次，总结通用方法论 |
| XXE | **XXE Lab** + 真实 CVE 复现、**Webug 4.0 视频 12-13 集** | 掌握 Blind XXE 带外数据外带、内网探测、Gopher 利用 MySQL/Redis |
| XSS | **XSS Lab** + **Webug 4.0 视频 14-16 集** + **Pikachu XSS** | 反射/存储/DOM 三型通杀、过滤绕过、CSP 绕过、盲打实战 |
| 命令/代码执行 | **Pikachu RCE** + **BWVS** | `system/exec/passthru/shell_exec` 绕过、`disable_functions` 绕过、Nginx 日志投毒 |
| 逻辑漏洞/越权 | **Webug 4.0 视频 17-18, 28-32 集** + **Pikachu 越权** | 万能密码、链接注入、水平/垂直越权、支付漏洞、URL 跳转、邮箱轰炸 |
| 文件包含/下载 | **Webug 4.0 视频 19-21, 33 集** | 任意文件下载、MySQL 配置文件泄露、LFI/RFI、伪协议利用 |
| 后渗透/持久化 | **Webug 4.0 视频 34 集** | Webshell 爆破、密码字典构建 |

### 阶段 3：综合实战与 CTF 转化（持续）
- 在 **BWVS / Webug 4.0** 中进行混合漏洞链演练（如：SQLi → 文件上传 → RCE → 提权）
- 结合 [[attack-defense-world-beginner-web-writeup]]、[[buuctf-web-writeup-collection]]、[[ctfshow-web-info-gathering-brute-force]] 等平台 Writeup，补全实战技巧
- 尝试编写自动化扫描/利用脚本（参考 [[pocsuite3-vulnerability-testing-framework]]、[[sqlmap-api-automation]]）

---

## 常见问题排查

| 现象 | 可能原因 | 解决方案 |
|------|----------|----------|
| phpStudy 启动失败，Apache 端口被占用 | 宿主机/虚拟机已有 IIS/其他服务占用 80 端口 | `netstat -ano \| findstr :80` 找到 PID 并 `taskkill /PID <pid> /F`，或修改 phpStudy Apache 端口为 8080 |
| 访问靶场首页报错 “Can't connect to MySQL” | MySQL 未启动或密码不匹配 | phpStudy 面板点击“启动” MySQL；检查靶场配置文件 `config.php` 中数据库密码是否为 `root` |
| 文件上传靶场提示 “上传目录不可写” | Windows 权限问题 | 右键上传目录 → 属性 → 安全 → 给 Everyone 完全控制权限 |
| XXE/SSRF 靶场无法回连攻击机 | 虚拟机网络模式为“仅主机”，无法访问宿主机 | 改为“NAT”模式并配置端口转发，或在虚拟机内直接使用 `127.0.0.1` 回环测试 |
| Sqlilabs Less-37 以后宽字节注入失败 | PHP 版本过高（>5.4）默认关闭 `magic_quotes_gpc` | 确认 phpStudy 使用 PHP 5.4.x 分支；或手工在 `php.ini` 开启 `magic_quotes_gpc = On` 重启 Apache |
| Docker 容器启动后无法访问 | 端口映射冲突、防火墙拦截 | 检查宿主机 80 端口占用 `netstat -tlnp \| grep :80`；放行防火墙 `ufw allow 80` 或 `firewall-cmd --add-port=80/tcp` |

---

## 扩展资源与交叉引用

### 同类靶场平台 Writeup 索引
- [[attack-defense-world-beginner-web-writeup]] —— 攻防世界 Web 新手区 11 题全解
- [[attack-defense-world-master-advanced-writeup]] —— 攻防世界高手进阶区 18 题全解
- [[buuctf-web-writeup-collection]] —— BUUCTF Web 47 道题分类汇总
- [[ctfshow-web-info-gathering-brute-force]] —— CTFshow 信息收集与爆破专题
- [[ctfshow-web-sql-injection-bypass-basics]] —— CTFshow / BUUCTF SQLi 进阶绕过合集
- [[gkctf-2021-web-writeup]] —— GKCTF 2021 Web 五题深度复现
- [[huxiangbei-willphp-file-inclusion-writeup]] —— 湖湘杯 WillPHP 文件包含链复现

### 核心漏洞技术深度页面（按 Webug 4.0 分类映射）
- **SQLi (1.1-1.7)**：[[mysql-duplicate-entry-error-based-sqli]], [[mysql-dnslog-injection-loadfile-unc]], [[ctf-show-php-command-execution-bypass-techniques]], [[xd-security-waf-bypass-techniques-day46-49]]
- **XSS (2.1-2.5)**：[[xss-haozi-lab-walkthrough]], [[xd-security-xss-vulnerability-notes-day25-28]], [[discuz-x32-stored-dom-xss-bbcode-analysis]]
- **文件下载 (3.1)**：[[php-file-inclusion-vulnerability]], [[xd-security-file-inclusion-notes]]
- **文件上传 (4.1-4.5)**：[[php-file-inclusion-vulnerability]], [[cnvd-2021-49104-eoffice-v9-file-upload-rce]], [[xd-security-waf-bypass-techniques-day46-49]], [[upload-labs-file-upload-bypass-writeup]]
- **逻辑漏洞 (5.1-5.4)**：[[xd-security-logic-vulnerability-notes-day33-36]], [[pikachu-target-writeup-part4]]
- **其他 (6.1-6.5)**：[[ssrf-bypass-techniques]], [[ssrf-ctf-exploitation-guide]], [[php-file-inclusion-vulnerability]], [[ctf-show-php-command-execution-bypass-techniques]], [[xd-security-csrf-ssrf-rce-notes-day29-30]], [[websocket-vulnerabilities-analysis]]

### 实战渗透测试方法论
- [[xd-security-pentest-basic-stage-notes]] —— 基础阶段 24 天知识清单
- [[xd-security-logic-vulnerability-notes-day33-36]] —— 逻辑漏洞/越权系统梳理
- [[xd-security-internal-network-penetration-notes-day65-66]] —— 内网渗透横向移动实战
- [[info-gathering-tools-collection]] —— 信息收集工具链全景

---

## 结语

这 7 个靶场覆盖了 **Web 安全入门到进阶 90% 以上的核心漏洞类型**。其中 **Webug 4.0** 凭借其系统性的漏洞分类（30+子类）、配套视频教程（35集）、官方文档与社区生态（乌云知识库、MD5解密、CMS/CTF模块规划），成为**零基础入门最完整的单一靶场**。

建议采用“靶场实战 + 技术页面深度阅读 + 编写利用脚本”三位一体的学习模式：先在离线环境通关，再回顾知识库对应页面夯实原理，最后尝试将手工利用转化为自动化 PoC/Exp，形成可复用的个人武器库。

**本次更新亮点回顾**：
- ✅ **Webug 4.0 漏洞分类全景图**：6大类 30+子类，逐项映射知识库深度页面
- ✅ **官方资源三件套**：百度网盘下载、官网 http://www.webug.org、GitHub 源码
- ✅ **视频教程与漏洞分类双向索引**：35集视频目录与漏洞编号对齐，便于定向学习
- ✅ **Docker 部署方案**：打破 Win2003 虚拟机依赖，适配现代开发环境

> **获取方式**：访问百度网盘链接 https://pan.baidu.com/s/1u_N58cb10rlDZ-FsH_BTSw 下载（约 2-3 GB）。建议校验文件完整性（MD5/SHA256）后再导入虚拟机。

## 来源

- [102网络攻防实验室-202102-202203_5](../sources/102网络攻防实验室-202102-202203_5.md)
- 微信公众号归档文章《[新年礼物]Webug4.0 基础是梦的基石》（226安全团队，2019）
- B站视频：[av70249823](https://www.bilibili.com/video/av70249823/)
- Docker 部署指引：[linuz.me/2019/08/04/Webug-docker/](https://linuz.me/2019/08/04/Webug-docker/)
- GitHub 仓库：[wangai3176/webug4.0](https://github.com/wangai3176/webug4.0)
- [226安全团队-201805-202103_06](../sources/226安全团队-201805-202103_06.md)
- [226安全团队-201805-202103_26](../sources/226安全团队-201805-202103_26.md)
