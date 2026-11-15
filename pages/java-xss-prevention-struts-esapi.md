---
title: Java XSS 漏洞修复方案：Struts 框架内置转义机制与 ESAPI 多上下文编码器
description: 系统梳理 Java Web 应用中 XSS 漏洞的修复方案，重点解析 Struts 1/2 框架内置的输出转义标签机制（bean:write、s:property）、ESAPI
  编码器的五大上下文编码方法（HTML、HTML属性、JavaScript、CSS、URL），并提供基于 Servlet Filter + HttpServletRequestWrapper
  的全局参数过滤修复思路。
category: program-analysis
tags:
- Java
- XSS
- Struts
- ESAPI
- 漏洞修复
- 安全编码
- 输出转义
- commons-lang3
date: '2024-01-15'
updated: '2026-11-15'
---

## 概述

跨站脚本攻击（XSS）是 Java Web 应用中最常见的安全漏洞之一。本文基于微信公众号归档文章《JAVA漏洞修复-XSS漏洞》，系统整理 **Struts 框架内置转义机制**、**ESAPI 多上下文编码器** 以及 **全局过滤器方案** 三大防御体系，适用于遗留系统改造与新项目安全编码规范落地。

> 原文链接：[http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901561&idx=1&sn=1aa373746e10fb016b4136dab4fc5f47](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901561&idx=1&sn=1aa373746e10fb016b4136dab4fc5f47)

---

## Struts 框架内置转义机制

### Struts 1：`<bean:write>` 标签

Struts 1 的 `<bean:write>` 标签提供 `filter` 属性控制输出转义：

| 属性值 | 行为 |
|--------|------|
| `filter="true"`（默认） | 将输出内容中的 HTML 特殊字符转义为实体编码，作为普通字符串显示 |
| `filter="false"` | 直接输出原始内容，**存在 XSS 风险** |

**示例代码：**

```jsp
<% 
    String test = "<script>alert(1)</script>"; 
    request.setAttribute("test", test); 
%>
<!-- 安全：默认开启 filter，脚本会被转义显示 -->
<bean:write name="test"/><BR>
<!-- 危险：关闭 filter，脚本会执行 -->
<bean:write name="test" filter="false"/>
```

**最佳实践：** 始终保持 `filter="true"`（默认），仅在确信内容安全且需要渲染 HTML 时显式设置 `filter="false"`。

### Struts 2：`<s:property>` 标签

Struts 2 的 `<s:property>` 标签**默认开启 HTML 转义**，核心属性如下：

| 属性 | 默认值 | 说明 |
|------|--------|------|
| `escapeHtml` | `true` | HTML 实体编码转义 |
| `escapeJavaScript` | `false` | JavaScript 上下文转义 |
| `escapeXml` | `false` | XML 实体编码转义 |
| `escapeCsv` | `false` | CSV 格式转义 |

**源码关键片段（`PropertyTag.java`）：**

```java
public class PropertyTag extends ComponentTagSupport {
    private boolean escapeHtml = true;
    private boolean escapeJavaScript = false;
    private boolean escapeXml = false;
    private boolean escapeCsv = false;

    protected void populateParams() {
        super.populateParams();
        Property tag = (Property) component;
        tag.setEscape(escapeHtml);
        tag.setEscapeJavaScript(escapeJavaScript);
        tag.setEscapeXml(escapeXml);
        tag.setEscapeCsv(escapeCsv);
    }
}
```

**底层实现：** 依赖 **Apache Commons Lang3** 的 `StringEscapeUtils.escapeHtml4(String)` 方法完成 HTML4 规范的实体编码。

> **交叉引用**：Java 中另一类常见注入漏洞的参数化防御方案见 [[java-preparedstatement-sql-injection-defense]]；XML 外部实体注入防御见 [[xxe-prevention-java-jaxp]]。

---

## ESAPI 多上下文编码器

OWASP ESAPI（Enterprise Security API）提供针对 **五大输出上下文** 的专用编码器，是构建安全输出的标准化选择。

### HTML 编码

```java
String safe = ESAPI.encoder().encodeForHTML(input);
```

- **编码规则**：空格、字母、数字保持不变；特殊字符替换为 HTML 实体引用
- **典型映射**：`"` → `&quot;`、`>` → `&gt;`、`<` → `&lt;`、`&` → `&amp;`
- **适用场景**：HTML 标签内容区（`<div>`, `<span>`, `<p>` 等）

### HTML 属性编码

```java
String safe = ESAPI.encoder().encodeForHTMLAttribute(input);
```

- **差异点**：**不编码空格**，其余规则同 HTML 编码
- **适用场景**：HTML 标签属性值（`value="..."`、`title="..."`、`href="..."` 等）

### JavaScript 编码

```java
String safe = ESAPI.encoder().encodeForJavaScript(input);
```

- **编码规则**：
  - 字母、数字 → 直接返回
  - 字符码 < 256 → `\xHH` 形式（十六进制）
  - 字符码 ≥ 256 → `\uHHHH` 形式（Unicode 转义）
- **适用场景**：内联脚本、事件处理器、JS 变量赋值（`var x = '...';`）

### CSS 编码

```java
String safe = ESAPI.encoder().encodeForCSS(input);
```

- **编码规则**：反斜杠 `\` + 十六进制字符码
- **适用场景**：`<style>` 块、内联 `style` 属性、CSS `url()` 等

### URL 编码

```java
String safe = ESAPI.encoder().encodeForURL(input);
```

- **编码规则**：先 UTF-8 编码字节流，再对每字节 `%HH` 形式百分号编码
- **适用场景**：URL 查询参数、表单提交数据、AJAX 请求参数

### 编码器选择决策表

| 输出位置 | 推荐编码器 | 备选 |
|----------|------------|------|
| HTML 文本节点 | `encodeForHTML` | — |
| HTML 属性值（已加引号） | `encodeForHTMLAttribute` | `encodeForHTML` |
| JavaScript 字符串字面量 | `encodeForJavaScript` | — |
| CSS 字符串/标识符 | `encodeForCSS` | — |
| URL 查询参数 | `encodeForURL` | — |
| URL 路径段 | `encodeForURL` + 路径规范化 | — |

> **注意**：ESAPI 编码器**不替代**输入验证。应采用「输入验证 + 输出编码」纵深防御策略。

---

## 全局参数过滤器方案（面试题实战）

### 问题背景

> 面试高频题：「测试发现几十个 XSS 漏洞，如何批量修复？」

### 解决方案架构

```
┌─────────────────────────────────────┐
│         XssFilter (Servlet Filter)  │
│  1. 拦截所有 HTTP 请求               │
│  2. 用 XssWrapper 包装 request      │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│     XssWrapper (HttpServletRequestWrapper) │
│  重写 getParameter* 方法             │
│  调用 StringEscapeUtils.escapeHtml4() │
└─────────────────────────────────────┘
```

### 核心代码实现

**1. 过滤器类**

```java
@WebFilter("/*")
public class XssFilter implements Filter {
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        chain.doFilter(new XssWrapper((HttpServletRequest) request), response);
    }
}
```

**2. 请求包装器**

```java
public class XssWrapper extends HttpServletRequestWrapper {
    public XssWrapper(HttpServletRequest request) {
        super(request);
    }

    @Override
    public String getParameter(String name) {
        String value = super.getParameter(name);
        return escapeXss(value);
    }

    @Override
    public String[] getParameterValues(String name) {
        String[] values = super.getParameterValues(name);
        if (values == null) return null;
        return Arrays.stream(values).map(this::escapeXss).toArray(String[]::new);
    }

    @Override
    public Map<String, String[]> getParameterMap() {
        Map<String, String[]> map = super.getParameterMap();
        map.replaceAll((k, v) -> Arrays.stream(v).map(this::escapeXss).toArray(String[]::new));
        return map;
    }

    private String escapeXss(String input) {
        if (input == null) return null;
        // 使用 Commons Lang3 的 HTML4 转义
        return StringEscapeUtils.escapeHtml4(input);
    }
}
```

**3. Maven 依赖**

```xml
<dependency>
    <groupId>org.apache.commons</groupId>
    <artifactId>commons-lang3</artifactId>
    <version>3.14.0</version> <!-- 或更新版本 -->
</dependency>
```

### 方案局限与增强

| 局限点 | 增强建议 |
|--------|----------|
| 仅覆盖 HTML 上下文，不适用于 JS/CSS/URL | 引入 ESAPI，按输出上下文选择编码器 |
| 破坏合法 HTML 富文本需求 | 配合白名单标签过滤器（如 JSoup `Whitelist`） |
| 对 `multipart/form-data` 文件上传字段误转义 | 在包装器中排除 `Content-Type` 含 `multipart` 的请求 |
| 双重编码风险（前端已编码，后端再编码） | 仅在「输出时」编码，而非「输入时」；或增加编码状态标记 |

> **架构建议**：新项目优先采用 **模板引擎自动转义**（Thymeleaf、Freemarker、Velocity 默认开启）+ **显式上下文编码**；遗留系统可用全局过滤器作为「最小成本」应急修复，再逐步迁移到上下文感知编码。

---

## 相关技术栈对比

| 方案 | 优点 | 缺点 | 适用场景 |
|------|------|------|----------|
| Struts 1 `bean:write filter=true` | 零代码改动，框架原生 | 仅限 Struts 1 视图层 | 遗留 Struts 1 系统 |
| Struts 2 `s:property escapeHtml=true` | 默认安全，可按上下文切换 | 仅限 Struts 2 标签 | Struts 2 项目 |
| ESAPI 编码器 | 标准化、多上下文、社区维护 | 需显式调用，学习成本 | 通用 Java 项目、安全要求高 |
| 全局 Filter + Wrapper | 一次配置全局生效，改动最小 | 过度转义、上下文不敏感 | 应急修复、低风险内部系统 |
| 模板引擎自动转义 | 开发无感、默认安全 | 依赖特定模板引擎 | 新项目、现代化技术栈 |

---

## 最佳实践清单

1. **默认拒绝**：所有动态输出默认视为不受信，必须编码
2. **上下文感知**：根据输出位置（HTML/属性/JS/CSS/URL）选择对应编码器
3. **框架优先**：优先使用框架/模板引擎内置转义机制（Struts 标签、Thymeleaf `th:text` 等）
4. **库标准化**：引入 **OWASP Java Encoder** 或 **ESAPI** 作为统一编码库，避免自造轮子
5. **测试验证**：集成 **OWASP ZAP**、**Burp Suite** 自动化扫描；编写 XSS 回归测试用例
6. **内容安全策略 (CSP)**：部署严格 CSP 头作为最后一道防线，限制内联脚本、外部源加载
7. **代码审计**：在 CI/CD 中集成 **SpotBugs FindSecBugs**、**SonarQube** 规则检测未转义输出

---

## 参考资源

- OWASP XSS Prevention Cheat Sheet：<https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html>
- OWASP Java Encoder：<https://github.com/OWASP/owasp-java-encoder>
- ESAPI Java：<https://github.com/ESAPI/esapi-java-legacy>
- Apache Commons Lang3 `StringEscapeUtils`：<https://commons.apache.org/proper/commons-lang/javadocs/api-3.14.0/org/apache/commons/lang3/StringEscapeUtils.html>
- Struts 2 `PropertyTag` 源码：<https://github.com/apache/struts/blob/master/core/src/main/java/org/apache/struts2/views/jsp/PropertyTag.java>

---

## 交叉引用索引

- [[java-preparedstatement-sql-injection-defense]] — Java SQL 注入参数化防御
- [[xxe-prevention-java-jaxp]] — Java XXE 漏洞防御配置
- [[fastjson-deserialization-gadgets-shiro-anteros]] — FastJSON 反序列化利用链分析
- [[shiro-internal-penetration-case-study]] — Shiro RCE 实战内网渗透案例
- [[log4j2-rce-reproduction]] — Log4j2 Log4Shell RCE 复现与修复
- [[xd-security-xss-vulnerability-notes-day25-28]] — XD安全 XSS 专题学习笔记（含 HttpOnly 绕过、WAF 绕过、BeEF 实战）

## 来源

- [226安全团队-201805-202103_23](../sources/226安全团队-201805-202103_23.md)
