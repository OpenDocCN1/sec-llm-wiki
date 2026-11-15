---
title: Catfish CMS 任意图片删除漏洞代码审计与利用复现
description: 深度分析 Catfish CMS 用户头像上传功能中任意图片删除漏洞的成因、代码溯源、利用链构造及实战复现全流程，涵盖 isLegalPicture
  校验逻辑缺陷、路径拼接处理缺陷及 unlink 任意文件删除利用链。
category: program-analysis
tags:
- Catfish CMS
- 任意文件删除
- 代码审计
- 漏洞复现
- PHP安全
- CMS漏洞
- 用户头像上传
- 路径遍历
date: 2023-04-13
updated: '2026-11-15'
---
## 漏洞概述

Catfish CMS（鲶鱼CMS）在用户头像上传功能中存在任意图片删除漏洞。攻击者可通过正常上传头像并拦截修改请求参数，将目标图片路径注入删除逻辑，实现任意图片文件删除。漏洞根因在于删除逻辑未对用户可控的路径参数进行有效校验与归一化，结合 `substr` 与 `str_replace` 处理路径分隔符时的逻辑缺陷，导致可跨目录删除任意图片文件。

> 该漏洞属于授权后漏洞，需拥有合法用户账号并完成一次正常头像上传后方可利用。

## 影响版本与组件

| 组件 | 文件路径 | 关键代码行 |
|------|----------|------------|
| 用户头像控制器 | `application/user/controller/Index.php` | 第 91–137 行 |
| 通用校验方法 | `application/user/controller/Common.php` | `isLegalPicture` 方法 |

## 代码审计溯源

### 入口点：头像上传保存逻辑

在 `Index.php` 第 111 行调用 `isLegalPicture` 校验上传文件是否为合法图片：

```php
if ($this->isLegalPicture($file)) {
    // 后续处理逻辑
}
```

### 校验函数 `isLegalPicture` 分析

位于 `Common.php`，核心逻辑：

- 对文件后缀名进行白名单校验（如 jpg、png、gif 等）
- 对路径进行基础判断
- 校验通过返回 `true`

**缺陷**：仅校验上传文件本身的后缀与路径，**未校验后续删除操作中用户可控的旧头像路径参数**。

### 获取当前用户头像地址（第 114–117 行）

```php
$user = model('User')->get(Session::get('user.id'));
$old_avatar = $user->avatar;  // 从数据库读取当前用户头像路径
```

### 获取当前域名（第 119–121 行）

```php
$domain = request()->domain();  // 获取当前域名
```

### 核心删除逻辑（第 118–124 行）

```php
// 第 118 行：判断旧头像是否为外链
if (strpos($old_avatar, $domain) !== false) {
    // 第 120 行：获取要删除图片的相对路径
    $yfile = str_replace($domain, '', $old_avatar);
    
    // 第 122 行：处理路径首字符
    if (!empty($yfile)) {
        $yfile = substr($yfile, 1);  // 去除首字符 /
    }
    
    // 第 123 行：路径分隔符替换
    $yfile = str_replace('/', '\\', $yfile);
    
    // 第 124 行：执行删除
    unlink($yfile);
}
```

### 关键缺陷分析

| 步骤 | 代码 | 缺陷说明 |
|------|------|----------|
| 路径提取 | `str_replace($domain, '', $old_avatar)` | 仅简单替换域名，未校验路径是否在允许目录内 |
| 首字符处理 | `substr($yfile, 1)` | 假设路径以 `/` 开头，去除后得到相对路径 |
| 分隔符替换 | `str_replace('/', '\\', $yfile)` | 将 Unix 风格路径转为 Windows 风格，**未阻止目录遍历序列（如 `..\\`）** |
| 文件删除 | `unlink($yfile)` | 直接使用拼接后的路径删除文件，**无任何路径归一化或安全检查** |

**核心问题**：`$old_avatar` 来源于数据库，但在更新头像时，攻击者可通过构造请求控制新头像的保存路径（或通过其他注入手段污染数据库字段），导致 `$old_avatar` 指向任意目标图片。删除逻辑未验证路径是否在上传目录内，且 `str_replace` 仅替换 `/` 为 `\`，未过滤 `..` 等遍历序列，配合 Windows 路径特性可实现任意文件删除。

## 漏洞利用复现

### 利用前提

1. 拥有合法用户账号并登录前台
2. 已完成至少一次正常头像上传并保存（数据库中存在 `avatar` 字段）

### 利用步骤

1. **正常上传头像并抓包**  
   在用户中心上传一张正常图片作为头像，点击保存时使用 Burp Suite 拦截请求。

   ```http
   POST /index/user/index/save_avatar.html HTTP/1.1
   Content-Type: multipart/form-data; boundary=----WebKitFormBoundary...
   
   ------WebKitFormBoundary...
   Content-Disposition: form-data; name="file"; filename="avatar.jpg"
   Content-Type: image/jpeg
   
   [图片二进制数据]
   ------WebKitFormBoundary...--
   ```

2. **获取目标图片完整 URL**  
   找到站点中任意一篇包含图片的文章，复制图片地址，例如：  
   `http://target.com/upload/2023/04/13/secret_image.jpg`

3. **篡改请求中的图片路径**  
   将抓包请求中上传的图片文件内容替换为目标图片的 **相对路径**（或通过其他参数注入方式，视具体前端交互而定），关键是使服务端在更新数据库 `avatar` 字段时存入目标图片路径。

   > 实战中通常通过修改上传接口返回的路径、或利用前端回显可控的字段实现。原文演示为直接在保存请求中修改图片地址参数。

4. **发送篡改后的请求**  
   点击 Go 发送修改后的请求，服务端将目标图片路径写入数据库 `avatar` 字段。

5. **再次上传头像触发删除**  
   再次访问头像上传页面，上传任意新图片并保存。服务端读取数据库中被污染的 `avatar` 字段，执行删除逻辑，**删除目标图片**。

### 验证结果

- 原头像消失
- 目标文章中的图片同时消失，确认任意图片删除成功

## 修复建议

1. **路径归一化与边界校验**  
   删除前使用 `realpath` 获取绝对路径，校验其是否在允许的上传目录（如 `./upload/avatar/`）内：

   ```php
   $baseDir = realpath('./upload/avatar/');
   $targetPath = realpath($yfile);
   if (strpos($targetPath, $baseDir) !== 0) {
       throw new \Exception('非法路径');
   }
   ```

2. **禁止目录遍历序列**  
   过滤 `..`、符号链接等路径遍历载荷：

   ```php
   if (strpos($yfile, '..') !== false) {
       throw new \Exception('路径包含非法字符');
   }
   ```

3. **数据库字段完整性保护**  
   头像路径写入数据库时，应由服务端生成安全路径，不可直接使用用户可控输入。

4. **最小权限原则**  
   Web 进程仅对上传目录拥有写入/删除权限，其他目录设为只读或不可访问。

5. **增加 CSRF Token 与操作审计**  
   关键操作（头像更新、删除）需验证 Token，并记录操作日志便于事后溯源。

## 交叉引用与关联知识

- [[catfish-cms-stored-xss-analysis]] — Catfish CMS 另一漏洞：存储型 XSS（`filterJs` 过滤绕过）
- [[feifei-cms-arbitrary-file-deletion]] — 飞飞CMS 后台数据库恢复功能任意文件删除漏洞审计
- [[iwebshop-cms-arbitrary-file-deletion]] — IWebShopCMS 后台数据库备份管理任意文件删除漏洞
- [[arbitrary-file-download-vulnerability-analysis]] — HDWiki 任意文件下载与删除漏洞代码审计通用模式
- [[php-file-inclusion-vulnerability]] — PHP 文件包含漏洞中路径遍历与截断绕过技巧对比
- [[race-condition-vulnerability-analysis]] — 条件竞争视角下的文件操作安全性分析

## 时间线

| 日期 | 事件 |
|------|------|
| 2023-04-13 | 微信公众号发布漏洞分析文章（归档来源） |
| 2023-04-13 | 本知识页面建立 |

## 参考资料

- 原文链接：`http://mp.weixin.qq.com/s?__biz=MzI4MDE5ODExNQ==&mid=2652901300&idx=1&sn=b25348946d8363f3165419cfef7c87a8`
- Catfish CMS 官方仓库（如有）
- PHP `unlink` / `realpath` / `str_replace` 官方文档

## 来源

- [226安全团队-201805-202103_47](../sources/226安全团队-201805-202103_47.md)
