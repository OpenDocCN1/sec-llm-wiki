---
title: 代码审计中的文件操作漏洞挖掘方法论：越权访问、上传、下载与删除
description: 系统梳理代码审计中文件操作相关漏洞的挖掘方法论，覆盖文件越权访问搜索技巧（wooyun-2010-098084）、文件上传漏洞挖掘流程、文件下载与删除漏洞的危险函数识别、代码缺陷模式、利用验证及通用检测清单。基于『代码审计的艺术系列』第七季与第十篇文章整理，由资深白帽子李斌撰写。
category: program-analysis
tags:
- 代码审计
- 文件越权访问
- 文件上传漏洞
- 文件下载漏洞
- 任意文件删除
- PHP安全
- 危险函数
- 白盒测试
- 漏洞挖掘方法论
- wooyun-2010-098084
- 代码审计的艺术系列
date: '2017-08-15'
updated: '2026-11-16'
---

## 概述

本页面沉淀自「代码审计的艺术系列」第七季与第十篇文章，由资深白帽子李斌（现汽车之家高级安全工程师、前360安全工程师、乌云核心白帽子）撰写。文章系统介绍了代码审计中**文件越权访问**、**文件上传**、**任意文件下载**、**任意文件删除**四大典型文件操作漏洞的挖掘方法论，涵盖搜索技巧、危险函数识别、代码缺陷模式、利用验证流程及通用检测建议。

文件操作漏洞属于代码审计必备核心技能，常出现在下载、备份、上传、模板编辑、权限控制等功能模块。掌握其搜索定位技巧、危险函数特征与变量追踪技巧，可快速定位高危漏洞点。

## 文件越权访问搜索技巧与案例

### 核心判定逻辑

PHP 应用中，全局引入文件（如 `global.php`、`common.php`、`init.php`）通常承担用户登录态校验职责：未登录则跳转登录页。**未包含这些全局校验文件的 PHP 文件，即为潜在的越权访问入口**。

### 搜索技巧：Linux `find` 命令快速定位

在 Linux 环境下，可使用 `find` 配合 `grep` 快速筛选未包含全局校验文件的 PHP 文件：

```bash
# 查找当前目录下所有 .php 文件，且不包含 "global.php" 字符串
find . -name "*.php" -type f | xargs grep -L "global.php"

# 进阶：同时排除 common.php、init.php 等常见全局文件
find . -name "*.php" -type f | xargs grep -L "global.php" | xargs grep -L "common.php" | xargs grep -L "init.php"
```

> **审计口诀**：全局校验缺失即越权，`find` 配合 `grep -L` 快速收割。

### 实战案例：wooyun-2010-098084

**漏洞编号**：wooyun-2010-098084  
**漏洞成因**：目标系统存在多个功能文件未包含根目录下的 `global.php`，导致无需登录即可直接访问核心功能接口。

**挖掘复现流程**：

1.  **定位可疑文件**：执行 `find . -name "*.php" | xargs grep -L "global.php"`。
2.  **结果筛选**：获得未包含 `global.php` 的文件列表（如 `admin/xxx.php`、`api/yyy.php` 等）。
3.  **访问验证**：直接在浏览器访问这些文件对应的 URL，观察是否跳转登录页。若直接执行业务逻辑（如导出数据、修改配置、执行 SQL），确认越权存在。
4.  **利用扩展**：结合文件上传、下载、删除等功能点，构造组合攻击链（如越权上传 WebShell、越权删除安装锁触发重装）。

**修复建议**：
- 强制在所有入口文件顶部 `require_once` 全局校验文件。
- 采用框架统一路由分发，在基类控制器 `__construct` 或中间件中强制鉴权。
- 部署 WAF/应用层防护规则，拦截未携带有效 Session/Cookie 的敏感路径访问。

## 文件上传漏洞搜索技巧与案例

### 搜索入口点定位

#### 前端表单搜索：`type="file"`

全局搜索前端上传表单，快速发现上传功能入口：

```bash
grep -rn 'type="file"' --include="*.php" --include="*.html" --include="*.htm" .
```

#### 后端处理逻辑搜索：`$_FILES`

全局搜索 PHP 超全局变量 `$_FILES`，定位文件上传处理核心代码：

```bash
grep -rn '\$_FILES' --include="*.php" .
```

> **审计口诀**：前端找入口 `type=file`，后端找逻辑 `$_FILES`，前后呼应锁定上传点。

### 实战案例：某厂商 MVC 框架上传漏洞 (xx00.com)

**目标结构分析**：
- 通过 URL 路由推断 MVC 结构：`www.xx00.com/gold_auction/auction_details/532` → `domain/controller/action/param`。
- 控制器目录定位：`/application/controller/`。

**漏洞挖掘流程**：

1.  **前端入口发现**：搜索 `type="file"` 定位到 `/application/views/phone_test/display.php`，表单 `action="upload"`。
2.  **后端逻辑定位**：对应控制器 `/application/controller/phone_test.php` 中的 `upload` 函数。
3.  **代码审计分析**：
    ```php
    // 简化后的漏洞代码逻辑
    public function upload() {
        $file = $_FILES['file'];
        // 缺陷：仅校验扩展名，无 Content-Type 验证、无文件内容检测、无随机重命名
        $ext = pathinfo($file['name'], PATHINFO_EXTENSION);
        if (in_array($ext, ['jpg','png','gif'])) {
            move_uploaded_file($file['tmp_name'], "./uploads/{$file['name']}");
            echo "上传成功";
        }
    }
    ```
4.  **漏洞利用**：
    - 绕过扩展名黑名单（如 `.php.jpg`、`.phtml`、`.htaccess`、大小写混淆 `.PhP`）。
    - 结合解析漏洞（Apache `AddHandler`、Nginx `cgi.fix_pathinfo`）或 `.htaccess` 重写规则实现 Getshell。

**修复建议**：
- 白名单校验扩展名 + MIME 类型 + 文件头魔数（`getimagesize`/`finfo_file`）。
- 重命名文件（UUID/哈希值），存储于非 Web 可执行目录。
- 设置上传目录禁止脚本执行（Nginx `location ~ \.php$ { deny all; }`、Apache `SetHandler default-handler`）。
- 实施 CSRF Token 校验，防止跨站上传。

## 文件下载漏洞挖掘实战

### 核心危险函数识别

| 函数 | 说明 | 常见风险场景 |
|------|------|--------------|
| `file_get_contents()` | 将整个文件读入字符串 | 直接拼接用户可控参数作为文件路径 |
| `fopen()` | 打开文件或 URL | 模式参数未限制，配合 `fread()`/`fpassthru()` 输出 |
| `readfile()` | 直接输出文件内容 | 未校验路径合法性直接回显 |
| `file()` | 将文件读入数组 | 遍历输出时未做路径规范化 |
| `include/require` 类 | 文件包含导致的下载 | 当包含非 PHP 文件时可能回显源码 |

> **审计口诀**：见文件读取输出，必查参数来源与校验逻辑。

### 典型代码缺陷模式

#### 模式一：`file_get_contents()` 直接拼接用户输入

```php
// 缺陷代码示例（来源：某 OA 系统）
$file = $_GET['file'];
$content = file_get_contents($file);
echo $content;
```

**漏洞成因**：
- `$file` 直接来源于 `$_GET`，未做任何过滤
- 支持相对路径 `../` 穿越、绝对路径、协议流（`php://filter` 等）
- 无文件后缀白名单、无目录限制、无权限校验

**利用验证**：
```
http://target/download.php?file=../../../etc/passwd
http://target/download.php?file=php://filter/read=convert.base64-encode/resource=config.php
```

#### 模式二：`fopen()` + `fread()`/`fpassthru()` 组合

```php
// 缺陷代码示例
$name = $_GET['name'];
$fp = fopen($name, 'r');
fpassthru($fp);
```

**漏洞成因**：
- `fopen` 以读模式打开用户指定路径
- `fpassthru` 直接输出文件流至浏览器
- 同样缺乏路径规范化与白名单校验

**利用验证**：
```
http://target/filedown.php?name=phpinfo.php
http://target/filedown.php?name=../../config/database.php
```

### 审计定位技巧

1.  **关键词搜索**：全局搜索 `file_get_contents`、`fopen`、`readfile`、`fpassthru`、`fread`、`file(`
2.  **文件名定向**：重点排查 `download.php`、`file.php`、`down.php`、`export.php`、`backup.php` 等文件
3.  **变量回溯**：从危险函数参数倒推，确认是否可控、是否经过 `basename()`/`realpath()`/白名单校验
4.  **上下文分析**：检查是否有 `Content-Disposition: attachment` 等下载头，判断是否为下载功能

## 文件删除漏洞挖掘实战

### 核心危险函数识别

| 函数 | 说明 | 常见风险场景 |
|------|------|--------------|
| `unlink()` | 删除文件 | 直接拼接用户可控参数，缺乏路径穿越校验 |
| `rmdir()` | 删除目录 | 递归删除时未限制目录范围 |
| `@unlink()` | 抑制错误的删除 | 静默失败掩盖异常，配合条件竞争利用 |

> **审计口诀**：见 `unlink` 等破坏性操作，必查路径规范化、权限校验、白名单机制。

### 典型代码缺陷模式

#### 模式：`unlink()` 直接拼接用户输入

```php
// 缺陷代码示例（来源：某知名 Mail 系统）
$filename = $_POST['filename'];
unlink($filename);
echo 1; // 返回成功标识
```

**漏洞成因**：
- `$filename` 直接来源于 `$_POST`，未做任何过滤
- 支持相对路径穿越 `../`、绝对路径
- 无文件存在性检查、无权限校验、无操作日志审计
- 返回值直接作为成功标识，便于自动化利用

**利用验证**：
```
POST /delete.php
filename=../../db.sql
```
返回 `1` 表示删除成功，可批量删除核心配置、数据库备份、安装锁文件等。

### 审计定位技巧

1.  **关键词搜索**：全局搜索 `unlink`、`rmdir`、`@unlink`
2.  **功能点定向**：重点排查：
    - 后台数据库备份管理（删除旧备份）
    - 头像/附件/模板编辑（删除旧文件）
    - 缓存清理、日志清理、临时文件清理接口
3.  **变量回溯**：确认删除路径是否可控、是否拼接了不可控前缀、是否有 `basename()` 等防护
4.  **权限上下文**：检查是否有 CSRF Token、权限校验、操作审计日志

## 通用检测清单

### 文件越权访问检测清单

| 检测项 | 判断标准 | 修复建议 |
|--------|----------|----------|
| 全局校验文件包含 | 入口文件缺失 `require_once 'global.php'` | 强制框架基类/中间件统一鉴权，禁止裸露入口 |
| 敏感功能权限校验 | 核心功能（导出、配置、用户管理）无 RBAC 校验 | 基于角色/资源的细粒度权限控制 (ACL/RBAC) |
| 直接对象引用 (IDOR) | 参数 `id`/`uid` 直接操作他人资源 | 服务端校验当前用户归属权，而非仅依赖前端隐藏 |
| 接口未授权访问 | API 接口无 Token/签名/鉴权 | 网关层统一鉴权、签名验签、频率限制 |

### 文件上传漏洞检测清单

| 检测项 | 判断标准 | 修复建议 |
|--------|----------|----------|
| 扩展名校验 | 仅黑名单/仅前端校验/大小写敏感 | 白名单 + 强制小写 + 后缀归一化 |
| 文件内容校验 | 无魔数检测、无图片重绘 | `finfo_file` 检测 MIME + GD/Imagick 重绘剥离脚本 |
| 存储路径 | 存储于 Web 目录且可执行 | 存储非 Web 目录、随机文件名、配置 Web 服务器禁止执行 |
| 解析漏洞防护 | 依赖 Web 服务器默认解析 | 禁用 `.htaccess`/`.user.ini`、配置 `cgi.fix_pathinfo=0` |
| 并发/竞争 | 条件竞争窗口 (TOCTOU) | 原子操作、文件锁、随机临时名落地后再校验重命名 |

### 文件下载漏洞检测清单

| 检测项 | 判断标准 | 修复建议 |
|--------|----------|----------|
| 参数来源 | 直接使用 `$_GET/$_POST/$_REQUEST` | 使用白名单映射，如 `id => 真实路径` |
| 路径规范化 | 无 `realpath()`/`basename()` 处理 | 规范化后校验是否在允许目录内 |
| 目录限制 | 可穿越 Web 根目录 | `chroot` 思想：强制前缀 + 规范化后前缀匹配 |
| 后缀校验 | 无文件后缀白名单 | 仅允许 `.pdf/.zip/.txt` 等业务必要后缀 |
| 协议流防护 | 可触发 `php://`/`data://` 等 | 禁止协议流，或仅允许 `file://` 本地文件 |
| 权限校验 | 无登录/权限/CSRF 校验 | 必须鉴权 + CSRF Token + 业务权限矩阵 |
| 审计日志 | 无操作记录 | 记录下载人、文件、时间、IP |

### 文件删除漏洞检测清单

| 检测项 | 判断标准 | 修复建议 |
|--------|----------|----------|
| 参数来源 | 直接使用用户输入作为路径 | 使用数据库 ID 映射真实路径，不直接暴露路径 |
| 路径穿越防护 | 无 `../` 过滤或 `realpath` 校验 | `realpath` 后强制前缀匹配允许目录 |
| 文件存在性 | 删除前未检查文件是否存在 | 先查数据库记录，再删除物理文件 |
| 权限模型 | 无所有者校验、无 RBAC | 校验当前用户是否为文件所有者或有管理权限 |
| 软删除机制 | 直接物理删除 | 改为标记删除 + 定时任务清理，保留回滚窗口 |
| 操作审计 | 无日志 | 记录删除人、文件路径、时间、IP、前端 Referer |
| CSRF 防护 | 无 Token | 所有破坏性操作强制 POST + CSRF Token |

## 实战案例关联

本方法论在以下 CMS 审计实战中得到验证与应用：

- [[arbitrary-file-download-vulnerability-analysis]] — HDWiki 后台数据库备份功能中任意文件下载与删除漏洞完整审计链
- [[catfish-cms-arbitrary-image-deletion]] — Catfish CMS 用户头像上传功能中任意图片删除漏洞（`isLegalPicture` 校验缺陷 + `unlink` 路径拼接）
- [[feifei-cms-arbitrary-file-deletion]] — 飞飞 CMS 后台数据库恢复功能中 `delall()` 缺失路径校验导致任意文件删除
- [[iwebshop-cms-arbitrary-file-deletion]] — IWebShop CMS 后台数据库备份管理中路径遍历导致任意文件删除
- [[upload-labs-file-upload-bypass-writeup]] — Upload-Labs 靶场全 19 关文件上传绕过技术实战总结
- [[cnvd-2021-49104-eoffice-v9-file-upload-rce]] — 泛微 E-Office `uploadType=eoffice_logo` 参数任意文件上传 RCE 复现

## 进阶扩展：组合利用与变种

### 越权访问 + 文件操作组合链
1.  **越权上传**：利用未鉴权上传接口写入 WebShell/恶意文件。
2.  **越权下载/删除**：利用未鉴权下载接口窃取配置/源码；利用未鉴权删除接口删除 `install.lock` 触发重装 Getshell。
3.  **越权 + 逻辑漏洞**：越权访问安装向导、密码重置、支付回调等敏感逻辑接口。

### 下载后删除链
某些场景下，文件下载接口与删除接口共用路径构造逻辑，可先下载敏感文件（如配置、备份），再删除安装锁（`install.lock`）触发重装 Getshell。

### 条件竞争 (TOCTOU)
`unlink` 与文件上传/写入、`move_uploaded_file` 与校验逻辑存在 TOCTOU 窗口，配合多线程可实现绕过扩展名校验写入 WebShell、绕过 `unlink` 保护保留文件等。

### PHAR 反序列化触发点
文件操作函数（`file_get_contents`/`fopen`/`unlink`/`file_exists`/`is_file`/`copy`/`rename` 等）均可触发 PHAR 反序列化，结合 [[wecenter-v334-phar-deserialization-sqli]]、[[php伪协议与反序列化利用]] 等页面理解反序列化攻击面。

## 工具化辅助

| 工具/脚本 | 用途 |
|-----------|------|
| `find . -name "*.php" | xargs grep -L "global.php"` | 快速定位缺失全局校验的潜在越权文件 |
| `grep -rn 'type="file"'` / `grep -rn '\$_FILES'` | 快速定位文件上传前后端入口 |
| `grep -rn "file_get_contents\|fopen\|readfile\|unlink" --include="*.php" .` | 快速定位文件读写删除危险函数调用点 |
| IDE 静态分析（PhpStorm + Psalm/PHPStan） | 数据流追踪、污点分析、未授权路由检测 |
| [[pocsuite3-vulnerability-testing-framework]] | 编写 PoC 批量验证文件操作漏洞 |
| [[sqlmap-comprehensive-guide]] | 结合 SQL 注入获取路径后验证文件操作 |

## 小结

文件操作漏洞（越权访问、上传、下载、删除）虽属「基础类」，但因业务场景广泛、危害直接（敏感文件泄露、核心文件删除、重装 Getshell、远程代码执行），在代码审计与渗透测试中极具性价比。**核心方法论四步走**：

1.  **入口定位**：
    - 越权：`find` + `grep -L` 找缺失全局校验文件
    - 上传：`type="file"` + `$_FILES` 前后呼应
    - 下载/删除：危险函数关键词搜索
2.  **污点追踪**：参数回溯 → 确认可控性 → 评估校验缺失（路径规范化、白名单、权限、协议流）
3.  **利用验证**：构造穿越/协议流/绕过 Payload → 验证回显/副作用/文件落地 → 评估业务影响
4.  **组合扩展**：越权+上传、下载+删除、TOCTOU、PHAR 反序列化、安装重装等组合攻击链

建议审计者建立个人**危险函数字典**、**漏洞模式库**、**搜索命令速查表**，持续积累各类 CMS/框架中的变种写法，形成肌肉记忆。

## 交叉引用索引

- 代码审计系列：[[code-audit-installation-reinstallation-vulnerabilities]]、[[xd-security-code-audit-notes-day50-57]]
- 文件包含相关：[[php-file-inclusion-vulnerability]]、[[xd-security-file-inclusion-notes]]
- 反序列化触发：[[php伪协议与反序列化利用]]、[[wecenter-v334-phar-deserialization-sqli]]
- 实战案例：[[arbitrary-file-download-vulnerability-analysis]]、[[catfish-cms-arbitrary-image-deletion]]、[[feifei-cms-arbitrary-file-deletion]]、[[iwebshop-cms-arbitrary-file-deletion]]、[[upload-labs-file-upload-bypass-writeup]]、[[cnvd-2021-49104-eoffice-v9-file-upload-rce]]
- 工具框架：[[pocsuite3-vulnerability-testing-framework]]、[[sqlmap-comprehensive-guide]]

## 来源

- [301在路上-201508-202208_085](../sources/301在路上-201508-202208_085.md)
- [301在路上-201508-202208_085](../sources/301在路上-201508-202208_085.md) (第七季)
- [301在路上-201508-202208_085](../sources/301在路上-201508-202208_085.md) (第十篇)
- [301在路上-201508-202208_113](../sources/301在路上-201508-202208_113.md)
