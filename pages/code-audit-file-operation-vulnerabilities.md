---
title: 代码审计中的文件操作漏洞挖掘方法论：文件下载与删除
description: 系统梳理代码审计中文件下载与删除漏洞的挖掘方法论，覆盖危险函数识别、漏洞成因分析、利用验证及通用检测清单。基于『代码审计的艺术系列』第十篇文章整理，由资深白帽子李斌撰写。
category: program-analysis
tags:
- 代码审计
- 文件下载漏洞
- 任意文件删除
- PHP安全
- 危险函数
- 白盒测试
- 漏洞挖掘方法论
date: '2017-08-15'
updated: '2026-11-16'
---

## 概述

本页面沉淀自「代码审计的艺术系列」第十篇文章，由资深白帽子李斌（现汽车之家高级安全工程师、前360安全工程师、乌云核心白帽子）撰写。文章系统介绍了代码审计中**任意文件下载**与**任意文件删除**两大典型文件操作漏洞的挖掘方法论，涵盖危险函数识别、代码缺陷模式、利用验证流程及通用检测建议。

文件操作漏洞属于代码审计必备核心技能，常出现在下载、备份、上传、模板编辑等功能模块。掌握其危险函数特征与变量追踪技巧，可快速定位高危漏洞点。

## 核心危险函数识别

### 文件下载类危险函数

| 函数 | 说明 | 常见风险场景 |
|------|------|--------------|
| `file_get_contents()` | 将整个文件读入字符串 | 直接拼接用户可控参数作为文件路径 |
| `fopen()` | 打开文件或 URL | 模式参数未限制，配合 `fread()`/`fpassthru()` 输出 |
| `readfile()` | 直接输出文件内容 | 未校验路径合法性直接回显 |
| `file()` | 将文件读入数组 | 遍历输出时未做路径规范化 |
| `include/require` 类 | 文件包含导致的下载 | 当包含非 PHP 文件时可能回显源码 |

> **审计口诀**：见文件读取输出，必查参数来源与校验逻辑。

### 文件删除类危险函数

| 函数 | 说明 | 常见风险场景 |
|------|------|--------------|
| `unlink()` | 删除文件 | 直接拼接用户可控参数，缺乏路径穿越校验 |
| `rmdir()` | 删除目录 | 递归删除时未限制目录范围 |
| `@unlink()` | 抑制错误的删除 | 静默失败掩盖异常，配合条件竞争利用 |

> **审计口诀**：见 `unlink` 等破坏性操作，必查路径规范化、权限校验、白名单机制。

## 文件下载漏洞挖掘实战

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

1. **关键词搜索**：全局搜索 `file_get_contents`、`fopen`、`readfile`、`fpassthru`、`fread`、`file(`
2. **文件名定向**：重点排查 `download.php`、`file.php`、`down.php`、`export.php`、`backup.php` 等文件
3. **变量回溯**：从危险函数参数倒推，确认是否可控、是否经过 `basename()`/`realpath()`/白名单校验
4. **上下文分析**：检查是否有 `Content-Disposition: attachment` 等下载头，判断是否为下载功能

## 文件删除漏洞挖掘实战

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

1. **关键词搜索**：全局搜索 `unlink`、`rmdir`、`@unlink`
2. **功能点定向**：重点排查：
   - 后台数据库备份管理（删除旧备份）
   - 头像/附件/模板编辑（删除旧文件）
   - 缓存清理、日志清理、临时文件清理接口
3. **变量回溯**：确认删除路径是否可控、是否拼接了不可控前缀、是否有 `basename()` 等防护
4. **权限上下文**：检查是否有 CSRF Token、权限校验、操作审计日志

## 通用检测清单

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

## 进阶扩展：组合利用与变种

### 下载后删除链
某些场景下，文件下载接口与删除接口共用路径构造逻辑，可先下载敏感文件（如配置、备份），再删除安装锁（`install.lock`）触发重装 Getshell。

### 条件竞争
`unlink` 与文件上传/写入存在 TOCTOU 窗口，配合多线程可实现绕过扩展名校验写入 WebShell。

### PHAR 反序列化触发点
文件操作函数（`file_get_contents`/`fopen`/`unlink`/`file_exists`/`is_file` 等）均可触发 PHAR 反序列化，结合 [[wecenter-v334-phar-deserialization-sqli]]、[[php伪协议与反序列化利用]] 等页面理解反序列化攻击面。

## 工具化辅助

| 工具/脚本 | 用途 |
|-----------|------|
| `grep -rn "file_get_contents\|fopen\|readfile\|unlink" --include="*.php" .` | 快速定位危险函数调用点 |
| IDE 静态分析（PhpStorm + Psalm/PHPStan） | 数据流追踪、污点分析 |
| [[pocsuite3-vulnerability-testing-framework]] | 编写 PoC 批量验证 |
| [[sqlmap-comprehensive-guide]] | 结合 SQL 注入获取路径后验证文件操作 |

## 小结

文件下载与删除漏洞虽属「基础类」，但因业务场景广泛、危害直接（敏感文件泄露、核心文件删除、重装 Getshell），在代码审计与渗透测试中极具性价比。**核心方法论三步走**：

1. **函数定位**：搜危险函数 → 锁定调用点
2. **污点追踪**：参数回溯 → 确认可控性 → 评估校验缺失
3. **利用验证**：构造穿越/协议流 Payload → 验证回显/副作用 → 评估业务影响

建议审计者建立个人**危险函数字典**与**漏洞模式库**，持续积累各类 CMS/框架中的变种写法，形成肌肉记忆。

## 交叉引用索引

- 代码审计系列：[[code-audit-installation-reinstallation-vulnerabilities]]、[[xd-security-code-audit-notes-day50-57]]
- 文件包含相关：[[php-file-inclusion-vulnerability]]、[[xd-security-file-inclusion-notes]]
- 反序列化触发：[[php伪协议与反序列化利用]]、[[wecenter-v334-phar-deserialization-sqli]]
- 实战案例：[[arbitrary-file-download-vulnerability-analysis]]、[[catfish-cms-arbitrary-image-deletion]]、[[feifei-cms-arbitrary-file-deletion]]、[[iwebshop-cms-arbitrary-file-deletion]]
- 工具框架：[[pocsuite3-vulnerability-testing-framework]]、[[sqlmap-comprehensive-guide]]

## 来源

- [301在路上-201508-202208_085](../sources/301在路上-201508-202208_085.md)
