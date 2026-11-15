---
title: Discuz X3.2 存储型 DOM XSS 漏洞分析：BBCode 解析阶段实体编码绕过导致编辑模式下触发跨站脚本执行
description: 深度剖析 Discuz X3.2 存储型 DOM XSS 漏洞成因：BBCode 标签在入库时未过滤，编辑模式下经 bbcode2html
  转换为 HTML 后，因 JS 原生取值导致实体编码被还原，最终在 writeEditorContents 输出触发跨站脚本执行。
category: program-analysis
tags:
- Discuz
- XSS
- DOM XSS
- BBCode
- Stored XSS
- Entity Encoding Bypass
- Vulnerability Analysis
- JavaScript
date: '2023-04-13'
updated: '2026-11-15'
---

## 漏洞概述

Discuz! X3.2 (TC_BIG5 2014.6) 存在一处**存储型 DOM XSS** 漏洞。攻击者通过发布包含恶意 BBCode 的帖子，利用 BBCode 解析阶段的实体编码绕过缺陷，在拥有编辑权限的用户点击“编辑”并将光标移至特定位置时，触发 JavaScript 代码执行。

**核心攻击链**：
1. 恶意 BBCode 入库时未经过 XSS 过滤
2. 编辑模式下，后端将 BBCode 经 `bbcode2html()` 转换为 HTML 并输出至页面
3. 前端 JS 通过 `$('e_textarea')` 取值时，将服务端转义的 `&quot;` 实体编码还原为原生双引号
4. `newEditor()` 调用 `writeEditorContents()` 将处理后的 HTML 直接写入编辑器，导致 Payload 执行

## 复现环境与条件

| 组件 | 版本/配置 |
|------|-----------|
| 操作系统 | Windows 7 |
| 集成环境 | phpStudy 2018 |
| PHP 版本 | 5.2.17 |
| Web 服务器 | Apache |
| 目标程序 | Discuz_X3.2_TC_BIG5 (2014.6) |

**触发前置条件**：
- 攻击者账号：可发帖的普通用户
- 受害者账号：拥有帖子**编辑权限**的用户（版主、管理员或作者本人）
- 交互动作：受害者点击“编辑”按钮，并将鼠标移动至编辑框内的恶意内容上方

## 漏洞触发流程

1. **注入阶段**  
   攻击者发布帖子，内容包含 BBCode Payload：  
   `[email=7"onmouseover="alert(7)]7[/email]`

2. **存储阶段**  
   程序在 `source/module/post/post_newthread.php` 等入口处直接入库，**未对 BBCode 内容进行 XSS 过滤**。

3. **触发阶段**  
   受害者访问编辑页面：  
   `forum.php?mod=post&action=edit&fid=2&tid=11&pid=11&page=1`  
   页面加载时，后端将数据库中的 BBCode 经 `bbcode2html()` 转换为 HTML，输出至 `<textarea id="e_textarea">` 中。

4. **执行阶段**  
   - 前端 JS 通过 `$('e_textarea')` 获取 `textarea` 的 `value`（此时 `&quot;` 已被浏览器还原为 `"`）  
   - 变量 `wysiwyg = 1` 满足条件，进入 `newEditor(1, bbcode2html(textobj.value))`  
   - `bbcode2html()` 将 Payload 转换为：  
     `<a href="mailto:7"onmouseover="alert(7)" target="_blank">7</a>`  
   - `writeEditorContents()` 将该 HTML 直接写入编辑器文档，**`onmouseover` 事件绑定生效**，鼠标移过即触发 `alert(7)`。

## 代码深度剖析

### 入口与路由机制

Discuz 采用 `mod`、`action` 双参数路由：

- **mod**：引入 `source/module/forum/forum_{mod}.php`  
  例：`mod=viewthread` → `forum_viewthread.php`
- **action**：引入 `source/module/{mod}/{mod}_{action}.php`  
  例：`mod=post&action=edit` → `source/module/post/post_edit.php`

关键参数：
- `tid`：帖子 ID
- `pid`：楼层/回复 ID
- `fid`：版块 ID

### 数据入库无过滤

在发帖处理流程（`post_newthread.php` / `post_reply.php`）中，用户提交的 `message` 字段**直接写入数据库**，未调用 `dhtmlspecialchars()` 等转义函数，亦未针对 BBCode 属性值进行过滤。

```php
// 伪代码示意
$message = $_POST['message']; // [email=7"onmouseover="alert(7)]7[/email]
DB::insert('forum_post', array('message' => $message, ...));
```

### 编辑模式下的输出与实体编码绕过

编辑页面模板（`forum/post_editor.htm`）将数据库原始 BBCode 输出至 `<textarea id="e_textarea">`。浏览器渲染时，将双引号实体化为 `&quot;`：

```html
<textarea id="e_textarea">[email=7&quot;onmouseover=&quot;alert(7)]7[/email]</textarea>
```

**关键绕过点**：前端 JS 使用原生方法获取值：

```javascript
function $(id) { return !id ? null : document.getElementById(id); }
var textobj = $('e_textarea'); // 获取 DOM 元素
var content = textobj.value;   // 浏览器自动将 &quot; 还原为 "
```

`content` 此时已变回 `[email=7"onmouseover="alert(7)]7[/email]`，实体编码保护失效。

### BBCode 解析与 HTML 注入

`static/js/bbcode.js` 中的 `bbcode2html()` 使用正则替换：

```javascript
str = str.replace(/\[email=([^\[\]]*)\](.*?)\[\/email\]/ig,
    '<a href="mailto:$1" target="_blank">$2</a>');
```

Payload 替换过程：
- `$1` = `7"onmouseover="alert(7)`
- `$2` = `7`
- 结果：`<a href="mailto:7"onmouseover="alert(7)" target="_blank">7</a>`

**属性闭合注入**：双引号闭合了 `href` 属性，注入 `onmouseover` 事件处理器。

### 编辑器初始化与 Payload 执行

`static/js/editor.js` 中 `newEditor()`：

```javascript
function newEditor(wysiwyg, initialtext) {
    if (isUndefined(initialtext)) {
        initialtext = bbcode2html(textobj.value); // 再次转换（此处已为 HTML）
    }
    if (wysiwyg) {
        writeEditorContents(initialtext); // 直接写入编辑器文档
    }
}
```

调用链：`newEditor(1, bbcode2html(textobj.value))` → `wysiwyg=1` → `writeEditorContents(htmlString)`。编辑器以 `designMode`/`contentEditable` 模式渲染 HTML，**事件处理器即时生效**。

## Payload 构造原理

1. **选择可注入属性的 BBCode 标签**  
   `email` 标签允许自定义 `href` 属性值（`mailto:` 前缀可控），且正则未对引号转义。

2. **利用正则贪婪/非贪婪特性**  
   `([^\[\]]*)` 匹配非方括号字符，双引号不在排除范围内，可直接闭合属性。

3. **事件处理器选型**  
   `onmouseover` 等鼠标事件在编辑器聚焦时易触发，无需额外用户交互即可在移动光标过程中执行。

4. **绕过实体编码**  
   依赖 `textarea.value` 的浏览器原生解码行为，将服务端输出的 `&quot;` 还原为 `"`，完成属性闭合。

## 关键技术点总结

| 技术点 | 说明 |
|--------|------|
| **漏洞类型** | 存储型 DOM XSS（数据经数据库存储，前端 JS 处理不当导致执行） |
| **根因** | 1. 入库无过滤 2. `textarea.value` 导致实体编码还原 3. `bbcode2html` 正则未转义引号 4. `writeEditorContents` 直接写入 HTML |
| **攻击面** | 编辑帖子功能（需编辑权限） |
| **影响版本** | Discuz X3.2 及可能更早版本（BBCode 解析逻辑未变） |
| **修复建议** | 1. 入库前对 BBCode 属性值做严格白名单/转义 2. `bbcode2html` 对 `$1` 等捕获组进行 `htmlspecialchars` 3. 编辑器初始化时使用 `textContent`/`innerText` 而非 `innerHTML` 写入内容 |

## 交叉引用与延伸阅读

- [[xss-haozi-lab-walkthrough]] — XSS 靶场通关笔记，涵盖实体编码绕过、上下文逃逸等核心技巧
- [[pikachu-target-writeup-part2-xss]] — Pikachu 靶场 XSS 全类型复现，含存储型、DOM 型及过滤绕过实战
- [[xd-security-xss-vulnerability-notes-day25-28]] — XD 安全课程 XSS 专题：原理分类、HttpOnly 绕过、代码审计案例（某shop 存储型 XSS）
- [[leanote-markdown-xss-to-electron-rce-case-study]] — 存储型 XSS 结合 Electron RCE 的完整攻击链复现
- [[cve-2022-30489-wavlink-wn535g3-post-xss-analysis]] — IoT 设备 POST 型反射 XSS 分析，对比不同注入点的利用方式
- [[websocket-vulnerabilities-analysis]] — WebSocket 协议下的 XSS 与 CSWSH 劫持漏洞原理

> **防御启示**：富文本/BBCode 编辑场景下，**“存储原始标记、渲染时转换”**的架构极易引入 XSS。必须在**解析渲染层**实施严格的上下文感知编码（HTML 属性值编码、JS 字符串编码），而非仅依赖入库过滤或前端实体编码。

## 来源

- [226安全团队-201805-202103_18](../sources/226安全团队-201805-202103_18.md)
