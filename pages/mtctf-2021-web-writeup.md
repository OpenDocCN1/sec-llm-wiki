---
title: MTCTF 2021 Web Writeup
description: MTCTF 2021 Web 方向题解：SQL 注入过滤绕过（反斜杠转义、数值型布尔盲注）、PHP 反序列化条件竞争（preload/hack
  竞争）、Session Upload Progress 利用及黑名单绕过（glob/copy/+a 技巧）
category: ai-security
tags:
- MTCTF
- '2021'
- Web
- SQL注入
- PHP反序列化
- 条件竞争
- Session Upload Progress
- 黑名单绕过
date: '2021-01-01'
updated: '2026-11-12'
---

## MTCTF 2021 Web Writeup

本页面整理 MTCTF 2021 Web 方向三道题的核心利用思路与关键技巧，涵盖 SQL 注入过滤绕过、PHP 反序列化条件竞争、Session Upload Progress 结合黑名单绕过的完整攻击链。

---

### 0x01 sql：反斜杠转义单引号 + 二进制正则盲注

- **过滤规则**：`空格 ' " - ; < = >` 被过滤。
- **核心 Trick**：在 `username` 参数末尾提交反斜杠 `\`，转义后端拼接 SQL 时的闭合单引号，使注入点落在 `password` 字段。
- **盲注手法**：使用 `REGEXP` 配合 `BINARY` 实现大小写敏感匹配，并利用 `/**/` 绕过空格过滤。

**Payload 示例**  
```text
username=\&password=||(lpad(password,1,0x2a)regexp/**/binary/**/0x3a)#
```

- 逐位爆破得到密码：`This_1s_thE_Passw0rd`，登录后台拿到 Flag。

---

### 0x02 easytricks：数值型布尔盲注 + PHP 反序列化条件竞争 + 黑名单绕过

#### SQL 注入：利用字符串隐式转数字构造布尔盲注

- **过滤差异**：`username` 过滤了 `%00 # % ' - / ; \ ^ _ | "`，但 `password` **未过滤单引号**。
- **关键 Trick**：MySQL 中纯数字字符串与数字 `0` 比较恒为真。利用 `ascii(mid(...))=N` 返回 `0/1`，再拼接 `'0.0` 使整体表达式在数值上下文中等价于 `0`，从而构造无需注释符的布尔盲注。

**Payload 示例**  
```text
user=admin&passwd=admin'+(ascii(mid(passwd,1,1))=88)+'0.0
```

- 盲注脚本跑出密码：`GoODLUcKcTFer202OHAckFuN`，登录后台下载 `admin.rar` 获取源码。

#### 代码审计与攻击面

源码审计发现三个主要攻击面：
1. 文件上传
2. Session 写入（解析不一致）
3. **反序列化（核心利用点）**

#### PHP 反序列化条件竞争（preload.php / hack.php）

- **漏洞逻辑**：`preload.php` 与 `hack.php` 存在竞争窗口，通过并发请求触发反序列化利用链。
- **环境依赖**：本地 PHP 7.3 难以复现竞争，直接针对远程环境攻击成功率高。

#### 黑名单绕过与 Session Upload Progress 利用

拿到反序列化后需绕过 `disable_functions` 与字符黑名单，实战中使用以下两种绕过技巧：

| 技巧 | 关键点 | 说明 |
|------|--------|------|
| 字符串异或构造函数名 | `'systam'|'systdm'` → `system` | 利用异或生成被过滤的危险函数名 |
| `+a` 得到整数 `0` | `glob('/fla*')[+a]` | PHP 中未定义常量 `a` 经 `+` 强制转型为 `0`，配合 `glob` 取第一个匹配文件 |
| `copy()` 回显 | `copy(src, 'output')` | 将 `/flag` 复制到 Web 可访问路径再读取 |

**实战 Payload 示例**  
```php
// 技巧一：异或绕过
'a'?><?php ['a'=>'systam'|'systdm']['a']('cat /fla*');

// 技巧二：glob + copy + +a
[];?><?=copy(glob('/fla*')[+a],'output')?>
```

> **关联技术**：Session Upload Progress 结合临时文件包含的类似利用链可参考 [[tctf-2021-1linephp-zip-include]]。

---

### 小结

| 题目 | 核心知识点 | 关键绕过/利用技巧 |
|------|------------|-------------------|
| sql | SQL 注入过滤绕过 | 反斜杠转义单引号、`BINARY` 逐位盲注 |
| easytricks | SQL 注入 + PHP 反序列化条件竞争 + 黑名单绕过 | 数值型布尔盲注（字符串隐式转数字）、preload/hack 竞争、异或构造函数名、`glob/copy/+a` 读取 Flag |

本次比赛体现了 **过滤绕过的组合拳**、**条件竞争的环境敏感性** 以及 **PHP 弱类型与字符串操作在黑名单绕过中的奇技淫巧**。

## 来源

- [0th3rs安全团队-201911-202204_006](../sources/0th3rs安全团队-201911-202204_006.md)
