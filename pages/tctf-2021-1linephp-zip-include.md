---
title: TCTF 2021 1linephp ZIP 协议任意文件包含利用链
description: 记录 2021 TCTF 1linephp 题目利用 zip:// 协议包含临时上传文件与 Session 文件，通过 ZIP 头偏移绕过
  upload_progress_ 前缀实现任意文件包含的完整利用链
category: ai-security
tags:
- TCTF
- PHP
- ZIP协议
- 文件包含
- 临时文件
- Session
- 利用链
date: '2021-01-01'
updated: '2026-11-12'
---

## 题目背景

2021 TCTF Web 赛题 `1linephp` 源自 2018 HITCON CTF Orange 出题，增加了 `.php` 后缀限制。题目核心代码仅一行：

```php
<?php
($_=@$_GET['yxxx'].'.php') && @substr(file($_)[0],0,6) === '@<?php' ? include($_) : highlight_file(__FILE__) && include('phpinfo.html');
```

通过 `phpinfo()` 发现环境与官方 PHP Apache Docker 差异在于额外启用了 `zip` 扩展，提示利用 `zip://` 协议进行文件包含。

## 核心利用链

### 临时上传文件包含尝试

PHP 文件上传会生成临时文件，命名格式为 `php` + 6 位随机字符 `[0-9a-zA-Z]`。尝试通过 `zip://http://` 形式延长临时文件生命周期至 60 秒，但爆破空间过大（62^6 ≈ 568 亿），且环境 10 分钟重启一次，实测不可行。

```text
/index.php?yxxx=compress.zlib://http://XXXX:7890/holdme%3f
```

### Session 临时文件包含（正解路径）

PHP 默认将 Session 存储在 `/var/lib/php/sessions/sess_<session_id>`，但开启 `session.upload_progress.enabled` 时，上传过程中会生成带前缀的临时文件：

```
upload_progress_XXXX
```

直接包含该文件会因 `upload_progress_` 前缀导致 ZIP 解析失败（ZIP 解析器从文件头查找 `PK\003\004` 签名）。

### ZIP 头偏移绕过前缀

根据 [PKZIP 格式规范](https://users.cs.jmu.edu/buchhofp/forensics/formats/pkzip.html)，ZIP 文件结构允许在文件头前填充任意数据（偏移量）。构造畸形 ZIP：在 `PK\003\004` 前预置 `upload_progress_` 字符串，使 PHP 的 ZIP 流封装器从偏移位置正确解析载荷。

**构造步骤**：

1. 生成包含 PHP 代码的正常 ZIP（内含 `shell.php`）
2. 在 ZIP 文件头前插入 `upload_progress_` 前缀
3. 通过 `session.upload_progress` 上传该畸形 ZIP，触发临时文件生成
4. 利用 `zip:///var/lib/php/sessions/upload_progress_<session_id>#shell.php` 包含

**关键结构示意**：

```
[upload_progress_][PK\003\004 ... ZIP 数据 ... PK\005\006]
                ↑
           ZIP 解析器从此处开始读取
```

### 完整利用流程

1. **开启 Session 上传进度**：POST 请求携带 `PHP_SESSION_UPLOAD_PROGRESS` 字段
2. **上传畸形 ZIP**：文件内容为预构造的带偏移 ZIP
3. **竞争包含**：在临时文件存在期间（约 60 秒），请求 `?yxxx=zip:///var/lib/php/sessions/upload_progress_<session_id>#shell.php`
4. **执行代码**：包含成功，`shell.php` 内容被当作 PHP 执行

## 关键技术点总结

| 技术点 | 作用 |
|--------|------|
| `zip://` 协议 | 读取 ZIP 内部文件，绕过 `.php` 后缀检查 |
| `session.upload_progress` | 生成可控内容、可预测路径的临时文件 |
| ZIP 头偏移 | 绕过 `upload_progress_` 固定前缀导致的解析失败 |
| 临时文件竞争 | 利用上传进度文件的短暂存在窗口完成包含 |

## 相关资源

- [PKZIP 格式规范](https://users.cs.jmu.edu/buchhofp/forensics/formats/pkzip.html)
- PHP 手册：[zip:// 封装协议](https://www.php.net/manual/zh/wrappers.zip.php)、[Session 上传进度](https://www.php.net/manual/zh/session.upload-progress.php)

## 同类技术关联

- [[spring-boot-actuator配置不当rce利用]] 中同样涉及文件包含与协议封装器滥用
- [[spring-cloud-config目录穿越漏洞]] 展示了另一种协议处理缺陷导致的任意读取
- [[jwt漏洞原理与实战利用]] 体现了协议/格式解析器差异被利用的通用模式

## 来源

- [0th3rs安全团队-201911-202204_003](../sources/0th3rs安全团队-201911-202204_003.md)
