---
title: CTF Web靶场离线打包合集与快速部署指南
description: 汇总主流CTF Web靶场离线打包合集，含BWVS、Pikachu、Webug4.0、Sqlilabs、Uploadlabs、XXE、XSS七大平台，基于Win2003+phpStudy快速部署指南
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
date: 2024-01-15
updated: '2026-11-15'
---

## 概述

本页面整理主流 CTF Web 靶场离线打包合集，包含 **7 个经典平台**，涵盖综合靶场与单项漏洞专项靶场两大类别。所有靶场均预配置在 **Windows Server 2003 + phpStudy** 环境中，下载解压后即可通过 phpStudy 一键启动，无需手动配置数据库、虚拟主机等繁琐步骤，极大降低初学者环境搭建门槛。

> 来源：微信公众号归档文章《靶场合辑来了》，原文提供百度网盘下载链接（公众号回复“靶场”获取）。

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

---

## 靶场清单分类

### 一、 综合靶场（多漏洞类型集成）

| 靶场名称 | 核心特点 | 适用阶段 | 相关进阶页面 |
|----------|----------|----------|--------------|
| **BWVS** (Broken Web Vulnerability Suite) | 涵盖 SQLi、XSS、文件上传、命令执行、文件包含等 20+ 漏洞模块，分级设计 | 入门→进阶系统练习 | — |
| **Pikachu** | PHP 原生漏洞演示，含暴力破解、XSS、CSRF、SQLi、RCE、文件包含/上传、越权、反序列化、XXE、SSRF 等完整模块 | 入门→进阶系统练习 | [[pikachu-target-writeup-part1-setup-brute-force]], [[pikachu-target-writeup-part2-xss]], [[pikachu-target-writeup-part3]], [[pikachu-target-writeup-part4]], [[pikachu-target-writeup-part5]] |
| **Webug 4.0** | 国内早期经典综合靶场，漏洞类型齐全，附带详细帮助文档 | 入门系统练习 | — |

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

## 学习路径建议

### 阶段 1：基础入门（1-2 周）
1. 部署环境，熟悉 phpStudy、phpMyAdmin、Burp Suite 基础操作
2. 从 **Pikachu** 的“暴力破解/验证码绕过”开始，掌握 Burp Intruder 四种模式 → [[pikachu-target-writeup-part1-setup-brute-force]]
3. 系统过一遍 **Pikachu XSS** 全类型 → [[pikachu-target-writeup-part2-xss]] / [[xss-haozi-lab-walkthrough]]

### 阶段 2：核心漏洞深度（2-4 周）
| 漏洞类型 | 推荐靶场 | 关键练习目标 |
|----------|----------|--------------|
| SQL 注入 | **Sqlilabs** Less-1 到 Less-65 依次通关 | 手工构造 Payload、盲注脚本编写、WAF 绕过思路 |
| 文件上传 | **Uploadlabs** Pass-01 到 Pass-20 | 每种绕过方式至少手工成功一次，总结通用方法论 |
| XXE | **XXE Lab** + 真实 CVE 复现 | 掌握 Blind XXE 带外数据外带、内网探测、Gopher 利用 MySQL/Redis |
| 命令/代码执行 | **Pikachu RCE** + **BWVS** | `system/exec/passthru/shell_exec` 绕过、`disable_functions` 绕过、Nginx 日志投毒 |

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

### 核心漏洞技术深度页面
- **SQLi**：[[mysql-duplicate-entry-error-based-sqli]], [[mysql-dnslog-injection-loadfile-unc]], [[ctf-show-php-command-execution-bypass-techniques]]
- **XSS**：[[xss-haozi-lab-walkthrough]], [[xd-security-xss-vulnerability-notes-day25-28]]
- **XXE**：[[xxe-xml-dtd-fundamentals]], [[xxe-prevention-java-jaxp]]
- **文件上传/包含**：[[php-file-inclusion-vulnerability]], [[cnvd-2021-49104-eoffice-v9-file-upload-rce]], [[xd-security-waf-bypass-techniques-day46-49]]
- **反序列化**：[[xd-security-deserialization-xxe-notes-day37-39]], [[thinkphp5-deserialization-chain-analysis]], [[python-pickle-deserialization-rce]]
- **SSRF**：[[ssrf-bypass-techniques]], [[ssrf-ctf-exploitation-guide]]
- **命令执行/RCE**：[[ctf-show-php-command-execution-bypass-techniques]], [[php-non-alphanumeric-webshell-construction]]

### 实战渗透测试方法论
- [[xd-security-pentest-basic-stage-notes]] —— 基础阶段 24 天知识清单
- [[xd-security-logic-vulnerability-notes-day33-36]] —— 逻辑漏洞/越权系统梳理
- [[xd-security-internal-network-penetration-notes-day65-66]] —— 内网渗透横向移动实战
- [[info-gathering-tools-collection]] —— 信息收集工具链全景

---

## 结语

这 7 个靶场覆盖了 **Web 安全入门到进阶 90% 以上的核心漏洞类型**。建议采用“靶场实战 + 技术页面深度阅读 + 编写利用脚本”三位一体的学习模式：先在离线环境通关，再回顾知识库对应页面夯实原理，最后尝试将手工利用转化为自动化 PoC/Exp，形成可复用的个人武器库。

> **获取方式**：关注原公众号回复“靶场”获取百度网盘下载链接（约 2-3 GB）。建议校验文件完整性（MD5/SHA256）后再导入虚拟机。

## 来源

- [102网络攻防实验室-202102-202203_5](../sources/102网络攻防实验室-202102-202203_5.md)
