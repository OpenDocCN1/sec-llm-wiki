---
title: Java JAXP API 中四种禁用 XXE 处理的防御技术详解
description: 系统梳理 Java JAXP API 中防御 XXE 漏洞的四种核心技术：禁止 DOCTYPE 声明、禁用外部实体声明（一般实体与参数实体）、启用安全处理特性、禁用实体引用扩展。结合
  CVE-2018-20318 修复案例，对比各方法适用场景与局限性，提供配置代码示例与防御策略组合建议。
category: program-analysis
tags:
- Java
- JAXP
- XXE
- XML External Entity
- 安全编码
- 漏洞防御
- CVE-2018-20318
- DocumentBuilderFactory
- SAX
- DOM
date: '2023-04-13'
updated: '2026-11-15'
---
## 概述

XXE（XML External Entity Injection，XML 外部实体注入）是因 XML 解析器在处理外部实体声明时未做限制，导致攻击者可读取任意文件、发起 SSRF、甚至执行远程代码的漏洞类别。Java 生态中广泛使用 JAXP（Java API for XML Processing）统一接口调用 DOM、SAX、StAX 等解析器实现，**正确配置解析器特性是防御 XXE 的关键**。

本页基于 0x00实验室归档文章《禁用XXE处理漫谈》整理，系统总结 JAXP API 中四种主流禁用 XXE 处理的防御技术，并结合实战案例（CVE-2018-20318）说明常见误区与组合防御策略。

> 交叉引用：XXE 漏洞基础原理、DTD 实体分类、Blind XXE 利用链、自动化扫描工具等详见 [[xxe-xml-dtd-fundamentals]]；实战笔记中的 XXE 利用与绕过技巧详见 [[xd-security-deserialization-xxe-notes-day37-39]]。

---

## 四种核心防御技术详解

### 禁止 DOCTYPE 声明（`disallow-doctype-decl`）

**适用场景**：确定业务不需要任何 DTD 声明（包括内部子集）时。

```java
DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
```

- **机制**：XML 处理器遇到 `<!DOCTYPE ...>` 直接抛出 `SAXParseException`。
- **优点**：最彻底，连内部实体声明也一并禁止，攻击面归零。
- **局限**：若业务依赖 DTD 做合法性校验或实体复用，会导致功能中断。

> **注意**：该特性为 Apache Xerces 专有，若运行时替换为其他实现（如 Oracle 内置实现），需确认特性支持情况。

---

### 禁用外部实体声明（`external-general-entities` / `external-parameter-entities`）

**适用场景**：需保留 DTD 内部子集（如内部实体定义），但必须阻断外部资源加载。

```java
factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
```

| 特性 | 作用对象 | 典型攻击向量 |
|------|----------|--------------|
| `external-general-entities` | 一般实体（`&entity;`） | 文件读取、SSRF、RCE |
| `external-parameter-entities` | 参数实体（`%entity;`） | Blind XXE 带外数据外带、DTD 远程加载 |

- **机制**：解析器在展开外部实体前检查特性标志，为 `false` 时抛出异常。
- **对比 PHP**：PHP `libxml` 默认禁用外部实体，仅当显式传入 `LIBXML_NOENT` 时才启用，默认更安全。

> **补充**：参数实体常用于 Blind XXE 攻击链（通过外部 DTD 定义参数实体再引用），**务必同时关闭两项特性**。

---

### 启用安全处理特性（`FEATURE_SECURE_PROCESSING` / FSP）

```java
import javax.xml.XMLConstants;

factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
```

- **定位**：JDK 核心机制，旨在通过**应用级限制**（实体展开深度、实体数量、文件大小等）防御 XML 拒绝服务（XDoS）与 XXE。
- **默认行为**：JDK 8+ 默认**部分启用**（仅防 XDoS），**XXE 防护需显式调用 `setFeature` 开启完全启用**。
- **实现差异**：
  - Oracle JDK / OpenJDK 内置实现：完全启用后限制外部连接。
  - **Apache Xerces**：FSP **不限制外部连接**，无法单独依赖 FSP 防御 XXE。
- **建议**：**必须结合技术 1 或 2 组合使用**，并针对目标运行时解析器实测验证。

---

### 禁用实体引用扩展（`setExpandEntityReferences(false)`）

```java
factory.setExpandEntityReferences(false);
```

- **作用点**：DOM 树构建阶段。`true`（默认）时，解析器将实体引用替换为实体值；`false` 时保留 `EntityReference` 节点，不做值替换。
- **防御效果**：
  - 阻断实体值替换导致的敏感数据泄露（如 `&xxe;` 不再展开为 `/etc/passwd` 内容）。
  - **不阻止外部资源请求**：解析器仍会发起 HTTP/FTP 请求获取外部实体内容，仅不将其塞入 DOM 树。
- **残留风险**：攻击者仍可发起 **Blind SSRF**（探测内网端口、触发 DNS 查询），但难以直接窃取文件内容。
- **适用性**：作为**纵深防御**层，配合技术 1/2 使用。

---

## 实战案例：CVE-2018-20318 修复演进

某开发团队针对 CVE-2018-20318 按官方建议仅设置：

```java
factory.setExpandEntityReferences(false); // 仅禁用实体引用扩展
```

**结果**：后续仍有研究员提交 XXE 绕过，根因是外部实体请求仍会发出，配合其他向量（如 XXE + SSRF 链）仍可造成危害。

**最终修正方案**（参考社区总结图）：
1. 优先 `disallow-doctype-decl = true`（若业务允许）
2. 否则 `external-general-entities = false` + `external-parameter-entities = false`
3. **叠加** `FEATURE_SECURE_PROCESSING = true`
4. **叠加** `setExpandEntityReferences(false)` 作为兜底

> **核心教训**：单一特性往往不足以覆盖所有解析器实现与攻击向量，**组合拳**才是稳健姿势。

---

## 配置清单速查表

| 防御层级 | 推荐配置组合 | 适用性评估 |
|----------|--------------|------------|
| **L1 基础** | `disallow-doctype-decl=true` | 无 DTD 依赖的新项目首选 |
| **L2 兼容** | `external-general-entities=false`<br>`external-parameter-entities=false` | 需保留内部 DTD 的存量系统 |
| **L3 纵深** | + `FEATURE_SECURE_PROCESSING=true`<br>+ `setExpandEntityReferences(false)` | 所有生产环境**必须**叠加 |
| **L4 验证** | 单元测试 + 集成测试覆盖 XXE Payload（含参数实体、Blind XXE、大实体 DoS） | CI/CD 强制门禁 |

---

## 常见误区与避坑指南

| 误区 | 真相 |
|------|------|
| “设置 `FEATURE_SECURE_PROCESSING=true` 就万无一失” | Xerces 不限制外部连接；需实测目标运行时解析器行为 |
| “`setExpandEntityReferences(false)` 就能防 XXE” | 仅阻断值替换，外部请求仍会发出，Blind SSRF 依然可行 |
| “SAX/DOM/StAX 配置方式完全一致” | StAX 使用 `XMLInputFactory`，特性名不同（如 `IS_SUPPORTING_EXTERNAL_ENTITIES`） |
| “只需配置 `DocumentBuilderFactory`” | `SAXParserFactory`、`SchemaFactory`、`TransformerFactory` 等**同理需配置** |

---

## 扩展阅读与工具链

- **自动化扫描**：[[xxe-xml-dtd-fundamentals]] 中提及的 `XXEinjector` 可用于回归测试。
- **安全编码规范**：OWASP [XXE Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html)。
- **解析器实现差异测试**：建议在项目依赖中显性声明 `xercesImpl` 版本，避免 JDK 内置与第三方实现混用导致特性表现不一致。

---

## 小结

Java JAXP API 防御 XXE 的**最小可行组合**：

```java
DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
// 1. 彻底禁止 DOCTYPE（推荐）
factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
// 2. 若必须保留 DTD，改用双重外部实体禁用
// factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
// factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
// 3. 纵深防御：安全处理 + 禁用实体展开
factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
factory.setExpandEntityReferences(false);
```

**原则**：**默认拒绝、显性放行、分层验证、持续测试**。

## 来源

- [0x6270安全团队-202203-202304_09](../sources/0x6270安全团队-202203-202304_09.md)
