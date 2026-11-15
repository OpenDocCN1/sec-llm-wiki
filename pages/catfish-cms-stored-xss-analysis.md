---
title: Catfish CMS 存储型 XSS 漏洞分析：filterJs 过滤绕过
description: 深度分析 Catfish CMS 评论功能中存储型 XSS 漏洞成因：filterJs 仅检测 <script> 关键字，可通过 img
  onerror 事件绕过过滤，实现存储型 XSS 攻击。包含漏洞代码溯源、绕过 Payload 构造、实战复现全流程。
category: program-analysis
tags:
- Catfish CMS
- 存储型 XSS
- filterJs
- 过滤绕过
- img onerror
- 代码审计
- 漏洞复现
- CMS 漏洞
date: 2023-04-13
updated: '2026-11-15'
---
## 漏洞概述

Catfish CMS（鲶鱼CMS）在评论功能处理用户输入时，调用 `filterJs` 方法进行过滤。该方法仅检测 `<script>` 关键字，未对其他可执行 JavaScript 的 HTML 标签及事件处理器进行过滤，导致攻击者可构造 `<img src="1" onerror=alert(1)>` 等 Payload 绕过过滤，实现存储型 XSS 攻击。

## 漏洞详情

### 影响版本
- Catfish CMS 相关版本（文章未明确版本号，涉及文件为 `\application\index\controller\Common.php`）

### 漏洞类型
- 存储型跨站脚本攻击

### 危害等级
- 高：可在前台页面及后台管理界面触发，窃取用户 Cookie、会话凭证，执行任意 JavaScript 代码

## 代码审计溯源

### 入口点分析
入口文件：`\application\index\controller\Index.php` 第 566 行

```php
// 伪代码还原
$content = filterJs($input); // 对用户输入调用 filterJs 过滤
```

### 核心过滤函数 `filterJs`
文件：`\application\index\controller\Common.php` 第 734-736 行

```php
function filterJs($str) {
    if (strpos($str, '<script>') !== false) {
        // 仅过滤 <script> 标签
        $str = str_replace('<script>', '', $str);
        $str = str_replace('</script>', '', $str);
    }
    return $str;
}
```

**缺陷分析**：
1. 仅检测 `<script>` 关键字，大小写敏感
2. 未过滤其他事件处理器属性（`onerror`、`onload`、`onclick` 等）
3. 未过滤可执行脚本的 HTML 标签（`<img>`、`<svg>`、`<iframe>`、`<body>` 等）
4. 替换方式为简单字符串替换，易被绕过

## 绕过 Payload 构造

### 核心思路
利用 `<img>` 标签的 `onerror` 事件，在图片加载失败时执行 JavaScript 代码。

### 实战 Payload
```html
<p><img+src="1"+onerror=alert(1)+_src="http://img.baidu.com/hi/jx2/j_0002.gif"/>111111111</p>
```

**构造要点**：
- 使用 `+` 替代空格，绕过可能的空格过滤
- `src="1"` 为无效图片地址，必然触发 `onerror`
- `_src` 保留原表情包图片地址，保持界面正常显示，隐蔽攻击
- 外层 `<p>` 标签符合评论内容格式要求

## 实战复现流程

### 前台评论提交抓包
在前台文章页面提交评论，选择一个表情包，使用 Burp Suite 抓包。

### 修改评论参数
定位 `pinglun` 参数，将其值替换为构造的 Payload：
```
<p><img+src="1"+onerror=alert(1)+_src="http://img.baidu.com/hi/jx2/j_0002.gif"/>111111111</p>
```

### 验证触发
- **后台管理界面**：管理员查看评论管理页面时触发弹窗
- **前台文章页面**：普通用户访问含恶意评论的文章页面时触发弹窗

## 漏洞利用场景

| 场景 | 触发条件 | 危害 |
|------|----------|------|
| 后台管理员查看评论 | 管理员登录后台访问评论管理 | 窃取管理员 Session、执行后台敏感操作 |
| 前台用户浏览文章 | 任意用户访问含恶意评论页面 | 窃取用户 Cookie、钓鱼登录、植入键盘记录器 |
| 评论列表聚合页面 | 任何包含评论列表的页面 | 批量攻击访问者 |

## 修复建议

### 采用成熟的 XSS 过滤库
推荐使用 [HTMLPurifier](http://htmlpurifier.org/) 等成熟库，基于白名单机制过滤 HTML 标签和属性。

### 实施输出编码
在模板渲染时，对用户可控数据进行上下文感知的输出编码：
- HTML 上下文：`htmlspecialchars()`
- JavaScript 上下文：JSON 编码
- HTML 属性上下文：属性值编码

### 设置 Content Security Policy (CSP)
```http
Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none';
```

### 完善 filterJs 函数（临时缓解）
```php
function filterJs($str) {
    // 过滤事件处理器属性
    $str = preg_replace('/\s+on\w+\s*=/i', '', $str);
    // 过滤 javascript: 伪协议
    $str = preg_replace('/javascript\s*:/i', '', $str);
    // 过滤 script 标签（不区分大小写）
    $str = preg_replace('/<\s*script[^>]*>.*?<\s*\/\s*script\s*>/is', '', $str);
    // 过滤危险标签
    $dangerous_tags = ['iframe', 'object', 'embed', 'applet', 'meta', 'link'];
    foreach ($dangerous_tags as $tag) {
        $str = preg_replace('/<\s*' . $tag . '[^>]*>.*?<\s*\/\s*' . $tag . '\s*>/is', '', $str);
    }
    return $str;
}
```

**注意**：黑名单过滤终究有绕过风险，根本修复仍应采用白名单过滤 + 输出编码的纵深防御策略。

## 相关技术关联

- [[discuz-x32-stored-dom-xss-bbcode-analysis]] — Discuz X3.2 存储型 DOM XSS 漏洞分析，另一典型 CMS 存储型 XSS 案例
- [[pikachu-target-writeup-part2-xss]] — Pikachu 靶场 XSS 全类型实战，涵盖存储型、反射型、DOM 型 XSS 攻防
- [[xd-security-xss-vulnerability-notes-day25-28]] — XD安全渗透测试课程 XSS 专题笔记，含存储型 XSS 代码审计案例
- [[xss-haozi-lab-walkthrough]] — XSS HaoZi 靶场 19 关通关指南，系统化 XSS 绕过技巧实战
- [[cve-2022-30489-wavlink-wn535g3-post-xss-analysis]] — WAVLINK 路由器 POST 型反射 XSS 漏洞分析，IoT 设备 XSS 案例
- [[leanote-markdown-xss-to-electron-rce-case-study]] — Leanote Markdown XSS 到 Electron RCE 攻击链，客户端 XSS 利用进阶

## 参考资源
- 原文链接：http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901314&idx=1&sn=2c7caf2f6eca5d9108e301b318024b74
- HTMLPurifier 官方文档：http://htmlpurifier.org/docs
- OWASP XSS Prevention Cheat Sheet：https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html

## 来源

- [226安全团队-201805-202103_46](../sources/226安全团队-201805-202103_46.md)
