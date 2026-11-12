---
title: ECShop 4.1.4 SQL注入漏洞深度分析
description: 详细分析 ECShop 4.1.4 最新版中仍存在的 SQL 注入漏洞，梳理从 X-FORWARDED-HOST 头到 insert_pay_log
  函数的完整利用链，包含漏洞触发条件、代码路径追踪及验证方法。
category: ai-security
tags:
- ECShop
- SQL注入
- 漏洞分析
- 利用链
- X-FORWARDED-HOST
- insert_pay_log
- 模板引擎
date: 2021-04-13
updated: '2026-11-12'
---
## 漏洞概述

ECShop 作为老牌开源商城系统，虽在 4.1 版本后修复了支付宝支付插件、HTTP REFER 头等已知 SQL 注入点，但在 **2021-02-05 发布的 V4.1.4 版本** 中仍存在一处可利用的 SQL 注入漏洞。该漏洞利用链起始于用户可控的 `X-FORWARDED-HOST` 头，经模板引擎渲染流程进入 `insert_mod` 函数，最终调用 `includes/libclips.php` 中的 `insert_pay_log` 函数实现注入。**利用前提：攻击者需拥有普通注册用户权限。**

## 利用链完整路径

### 入口点：`user.php` → `collection_list` 接口

在 `user.php` 的 `collection_list` 接口处，给模板变量赋值时调用了 `url` 函数：

```php
// user.php 相关代码片段
$smarty->assign('url', url(...));  // 触发 url 函数
```

### `url` 函数 → `getdomain` 函数（用户输入可控点）

`url` 函数内部调用 `getdomain`，后者直接从 HTTP 头 `X-FORWARDED-HOST` 获取输入并返回，**无任何过滤**：

```php
// getdomain 函数简化逻辑
function getdomain() {
    return isset($_SERVER['HTTP_X_FORWARDED_HOST']) ? $_SERVER['HTTP_X_FORWARDED_HOST'] : '';
}
```

> **关键点**：`X-FORWARDED-HOST` 头完全可控，成为注入载荷的初始注入口。

### 模板引擎渲染：`display` → `insert_mod`

模板引擎（ECShop 自行实现，非标准 Smarty）在 `display` 阶段将模板变量合并，通过 `$this->_echash` 分割后传入 `insert_mod` 处理。  
4.1.4 版本中 `$this->_echash` 硬编码为特定字符串（各版本不同）。

### `insert_mod` 函数：反序列化 + 动态函数调用

```php
// insert_mod 核心逻辑
function insert_mod($name, $args = '') {
    $args = explode('|', $args);          // 以 | 分割参数
    $func = 'insert_' . $name;            // 拼接函数名 insert_xxx
    return call_user_func_array($func, unserialize($args[1]));  // 反序列化后动态调用
}
```

**风险点**：
- 函数名可控（`insert_` 前缀固定，后缀来自模板变量）
- 参数经 `unserialize` 后直接传入目标函数

### 历史利用函数已修复

官方已修复以下 `insert_*` 函数的注入问题：
- `insert_ads`
- `insert_buy_notes`
- `insert_payment_list` 等

### 仍可利用的函数：`insert_pay_log` (`includes/libclips.php`)

```php
// insert_pay_log 关键代码片段
function insert_pay_log($args) {
    $log_id = $args['log_id'];
    $sql = "SELECT * FROM " . $GLOBALS['ecs']->table('pay_log') . " WHERE log_id = '$log_id'";
    return $GLOBALS['db']->getRow($sql);  // 直接拼接 SQL，无参数化
}
```

`$args['log_id']` 来源于反序列化后的用户输入，**未做任何转义或预编译**，直接拼接进 SQL 语句，导致注入。

## 漏洞验证条件与步骤

| 条件 | 说明 |
|------|------|
| **账号权限** | 需至少一个普通注册用户账号（需登录态） |
| **HTTP 头** | 构造恶意 `X-FORWARDED-HOST` 头，嵌入序列化后的 Payload |
| **触发页面** | 访问 `user.php?act=collection_list`（或同调用链的其他入口） |

**验证截图**（原文）：  
![漏洞验证成功](../Images/68614f436b786b16c747ccba8f776977.png)

## 关键代码定位速查表

| 文件 | 函数/位置 | 作用 |
|------|-----------|------|
| `user.php` | `collection_list` | 入口，调用 `url()` |
| `includes/lib_main.php` | `url()` → `getdomain()` | 读取 `X-FORWARDED-HOST` |
| `includes/cls_template.php` | `display()` → `insert_mod()` | 模板渲染与动态调用分发 |
| `includes/lib_clips.php` | `insert_pay_log()` | **最终 SQL 拼接注入点** |

## 修复建议

1. **禁止直接拼接 SQL**：在 `insert_pay_log` 等处改用预处理语句（`prepare`/`execute`）。
2. **过滤/校验 `X-FORWARDED-HOST`**：在 `getdomain` 中对该头做白名单或格式校验，避免污染模板变量。
3. **加固 `insert_mod`**：
   - 维护允许调用的 `insert_*` 函数白名单
   - 拒绝反序列化不可信数据，或改用 JSON + 严格类型校验
4. **升级模板引擎**：若业务允许，迁移至成熟模板引擎（如 Smarty 3+）并开启沙箱模式。

## 相关漏洞对比与扩展阅读

- [[mtctf-2021-web-writeup]]：MTCTF 2021 Web 方向题解，涵盖 SQL 注入过滤绕过、PHP 反序列化条件竞争等技巧，可对比不同框架下的注入利用思路。
- [[zzzphp-cve-2021-32605-rce]]：zzzphp CMS 模板注入导致 RCE，展示模板引擎渲染阶段的代码执行风险，与本文模板渲染链条有相似性。
- [[cve-digest-20210406]]、`[[cve-digest-20210420]]`：同期 CVE 聚合中均包含多款 CMS/插件的 SQL 注入案例，可横向对比修复模式。

## 时间线

| 日期 | 事件 |
|------|------|
| 2021-02-05 | ECShop 发布 V4.1.4 版本 |
| 2021-04-xx | 团队成员 yunsle 发现并记录该漏洞利用链 |
| 2021-04-13 | 本知识页面整理归档 |

---

> **声明**：本页面仅供安全研究与防御加固参考，请勿用于未授权系统测试。实际修复请以官方补丁为准。

## 来源

- [0th3rs安全团队-201911-202204_054](../sources/0th3rs安全团队-201911-202204_054.md)
