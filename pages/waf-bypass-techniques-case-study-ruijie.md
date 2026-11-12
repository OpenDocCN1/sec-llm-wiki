---
title: 锐捷校园网自助服务系统反射型 XSS 与 WAF 绕过实战案例
description: 记录从锐捷校园网自助服务系统反射型 XSS 入手，逐步绕过内置过滤、WAF-A 关键词拦截、WAF-B (WiseGrid) 深度检测的完整实战绕过链，涵盖
  HTML 标签嵌套逃逸、Data URI Base64 编码绕过、超长注释填充触发检测超时/长度限制等通用 WAF 绕过技巧。
category: uncategorized
tags:
- XSS
- WAF绕过
- 反射型XSS
- 锐捷
- 校园网
- WiseGrid
- HTML标签嵌套
- Data URI
- Base64编码
- 注释填充绕过
date: 2023-04-14
updated: '2026-11-13'
---
## 概述

本页面记录一次针对 **锐捷校园网自助服务系统** 的安全测试全过程：从发现一个看似「鸡肋」的反射型 XSS 出发，到在多套同型号线上系统中遇到三层递进的防护（系统内置过滤、WAF-A、WAF-B / WiseGrid），再到逐层攻克并总结出可复用的通用 WAF 绕过技巧。

> **核心价值**：实战演示了 **HTML 标签嵌套逃逸**、**Data URI + Base64 编码**、**超长注释填充触发检测超时/长度限制** 三大通用绕过手法，并验证了 Session Cookie 缺失 `HttpOnly` 导致的钓鱼利用风险。

---

## 漏洞发现与初步评估

### 目标系统信息

| 项目 | 详情 |
|------|------|
| 系统名称 | 锐捷校园网自助服务系统 |
| 技术栈 | Apache-Coyote/1.1, Servlet 2.5, JBoss-5.0/JBossWeb-2.1 |
| 接口后缀 | `.jsf`, `.jsp` |
| 端口/路径特征 | 移动端错误回显接口含 `mobile`，PC 端去掉 `mobile` 同理 |

### 反射型 XSS 触发点

- **参数位置**：错误信息回显接口的查询参数（未在文中显式给出参数名，实测为 URL 查询字符串直接反射在错误页面中）
- **触发示例**：`<script>alert(1)</script>` 直接弹窗
- **影响面**：SESSION Cookie **未设置 `HttpOnly`**，可通过 XSS 窃取 Cookie 实施会话劫持 / 钓鱼

> ⚠️ **初步判定**：单点反射型 XSS，需用户点击恶意链接，属「鸡肋」；但若为该厂商通用默认配置，则影响范围极大。

---

## 多站点验证与防护分层

对搜索引擎收录的同型号线上系统逐一测试，发现三类截然不同的拦截行为：

| 编号 | 现象 | 归因 |
|------|------|------|
| ① | 直接拦截 `<` `>` `script` `on*` 等关键字 | 系统自带 XSS 过滤模块 |
| ② | 允许部分标签（如 `<input>`），但拦截 `on*` 事件、`alert`、`javascript:` 等 | **WAF-A**（厂商/运维部署的第一层网关型 WAF） |
| ③ | 拦截 `<embed>`、`data:` 伪协议、长 Payload，提示 `WiseGrid` | **WAF-B (WiseGrid)**，深度语义分析型网关 |

> **关键洞察**：同一套业务系统，因部署环境不同叠加了不同层级的防护，形成「洋葱模型」；绕过需由内向外、逐层攻破。

---

## 逐层绕过技术详解

### 绕过系统内置过滤：HTML 标签嵌套逃逸

#### Fuzz 发现
- 系统仅过滤 `<script>`、`<img>` 等「高危标签」
- `<input>`、`<textarea>`、`<select>` 等表单标签 **未被过滤**，可正常渲染

#### 逃逸原理
利用浏览器对 **非标准嵌套** 的容错解析：
```html
<!-- 攻击者输入 -->
<input <input <a href="x">x</a>
```
渲染后 DOM 结构：
```html
<input <input <a href="x">x</a> >   <!-- 第一个 > 闭合首个 <input -->
<!-- 逃逸出的 <a> 标签生效 -->
<a href="x">x</a>
```
- **关键点**：外层标签未闭合，内层标签被浏览器「修正」为合法兄弟节点，从而逃逸出原标签上下文。

#### 通用化
- 该技巧可复用于 **任意允许 `<input>` 但过滤事件属性** 的场景
- 经测试：`<input>`、`<textarea>`、`<select>`、`<option>` 等均可作为「外壳标签」

---

### 绕过 WAF-A：Data URI + Base64 编码

#### WAF-A 拦截规则画像
| 拦截目标 | 示例 |
|----------|------|
| `on*` 事件属性 | `onclick` `onload` `onerror` |
| 危险函数名 | `alert` `prompt` `confirm` |
| 伪协议关键词 | `javascript:` `vbscript:` `data:` |

#### 绕过构造
利用 `<embed>` 标签的 `src` 属性支持 **Data URI** 且可执行 JS：
```html
<embed src="data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==">
```
- `PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==` = `<script>alert(1)</script>` 的 Base64
- **优势**：Payload 中无 `on*`、`alert`、`javascript:` 等敏感字符串，绕过关键词匹配

#### 结果
- ✅ 绕过 WAF-A
- ❌ 被 WAF-B (WiseGrid) 直接拦截 `<embed>` 标签及 `data:` 协议

---

### 绕过 WAF-B (WiseGrid)：超长注释填充触发检测超时/长度限制

#### 突破口发现
- 尝试在 Payload 前插入大量无效字符（`a`、`%20` 等）均失败
- 偶然尝试 **HTML 注释 `<!-- ... -->`** 填充，**触发异常延迟后返回正常页面**（未拦截）

#### 根因分析（推测）
WiseGrid 对请求体 / 参数长度设有 **检测阈值** 或 **正则回溯超时保护**：
- 超长注释导致解析器耗时过长 → 触发 **超时熔断** → 放行请求
- 或 超过 **最大检测长度** → 截断后段 Payload → 后段恶意代码未被检测

#### 最终通用 Payload
```html
<input <!-- [约 50KB+ 注释填充] --> <embed src="data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==">
```
- 外层 `<input>` 逃逸系统内置过滤
- 超长注释绕过 WiseGrid 深度检测
- Data URI Base64 绕过 WAF-A 关键词匹配
- **三层防护一次性穿透**

---

## 通用化复用指南

| 场景 | 适用技巧 | 关键点 |
|------|----------|--------|
| 仅过滤高危标签，放行表单标签 | **标签嵌套逃逸** | 选用 `<input>`/`<textarea>` 等无需闭合的空标签 |
| 关键词匹配型 WAF (WAF-A) | **Data URI + Base64** | 编码后无敏感明文；配合 `<embed>`/`<object>`/`<iframe>` |
| 深度语义分析型 WAF (WAF-B) | **超长注释/垃圾数据填充** | 探测长度阈值 / 正则回溯超时；注释、空白字符、重复参数均可 |
| 组合防护 | **分层叠加** | 先逃逸标签上下文 → 再编码混淆 → 最后填充触发熔断 |

> 💡 **实战建议**：先用最小 Payload 探测各层拦截规则，再按「由内向外」顺序叠加 Bypass 技巧，避免一次性投放过大 Payload 导致无法定位拦截点。

---

## 关联知识与延伸阅读

- [[qwb2019-随便注-sql注入复现]] — SQL 注入场景下的 WAF 绕过（堆叠查询、预编译绕过、表重命名）可作对比参考
- [[php伪协议与反序列化利用]] — `data://`、`php://filter` 等伪协议在文件读取 / RCE 中的利用姿势，与 Data URI 思路同源
- [[ctf-flask-path-traversal-vim-crypto]] — CTF 实战中绕过 Flask 路径规范化、结合编码解密的综合案例
- [[usb流量取证与隐写综合实战]] — 取证溯源视角下的流量混淆与隐写技术，可启发 WAF 检测规则逆向分析

---

## 时间线与版本记录

| 日期 | 版本 | 说明 |
|------|------|------|
| 2023-04-14 | 1.0 | 首版发布，整理自微信公众号「007攻防实验室」2020-10 归档文章 |
| — | — | 后续可补充：WiseGrid 规则逆向细节、自动化 Fuzz 脚本、其他厂商同类系统验证结果 |

---

## 参考来源

- 原文：[从锐捷某系统鸡肋XSS到通用WAF绕过](http://mp.weixin.qq.com/s?__biz=MzU5MjMzODY0NQ==&mid=2247483746&idx=1&sn=5b4648e7aa253b5e7fa72185f6cb9092&chksm=fe200ad8c95783ce32588af385ed15d3e63f798218c635b5dd19291c34d791512218f7df8bc6&scene=126&sessionid=1681442960#rd)
- 同期归档入口：[[007攻防实验室]]

## 来源

- [0th3rs安全团队-201911-202204_127](../sources/0th3rs安全团队-201911-202204_127.md)
