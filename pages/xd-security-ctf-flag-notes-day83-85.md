---
title: XD安全渗透测试课程 Day83-85 学习笔记：CTF夺旗实战
description: 整理 XD安全渗透测试课程 Day83-85 学习内容，涵盖序列化漏洞利用、SSTI模板注入、Python字符串格式化漏洞、PHP弱类型比较/preg_match绕过/RCE/反序列化、Java
  WEB-INF文件读取/XXE/反编译等核心CTF题型与绕过技巧。
category: program-analysis
tags:
- XD安全
- CTF
- 序列化
- SSTI
- Python格式化字符串
- PHP弱类型
- preg_match绕过
- RCE
- PHP反序列化
- Java WEB-INF
- XXE
- Java反编译
- 渗透测试
- 学习笔记
date: 2024-01-15
updated: '2026-11-14'
---
## 概述

本页面整理自 XD安全渗透测试课程 Day83-85 的学习笔记，聚焦 CTF 夺旗实战中的核心题型与绕过技巧。内容涵盖序列化、SSTI（服务端模板注入）、Python 字符串格式化漏洞、PHP 弱类型比较与 `preg_match` 绕过、命令执行（RCE）、PHP 反序列化、Java WEB-INF 文件读取、XXE 外部实体注入及 Java 反编译等技术点，适合 CTF 选手与渗透测试学习者查阅复现。

> 交叉引用：[[xd-security-deserialization-xxe-notes-day37-39]]、[[xd-security-file-inclusion-notes]]、[[php-file-inclusion-vulnerability]]、[[python-ssti-multi-engine-bypass]]、[[attack-defense-world-beginner-web-writeup]]、[[ctfshow-web-info-gathering-brute-force]]、[[xxe-xml-dtd-fundamentals]]、[[buuctf-web-writeup-collection]]

---

## 序列化漏洞利用

### 靶场：华北赛区 Day1 Web2 (BUUOJ shop)

- **入口**：靶机提示寻找 `v6`，编写脚本遍历 `shop?page=` 參數，在第 181 页发现 `lv6.png`。
- **逻辑漏洞**：购买商品金额不足，但前端可修改折扣券参数绕过支付校验。
- **Cookie 伪造**：抓包发现 `wtf` 字段，通过工具跑出密钥 `1kun`，伪造 Cookie 登录。
- **源码泄露**：页面源码中存在文件下载链接，下载后发现序列化构造 Payload。
- **利用链**：删除输入框 `hidden` 属性，提交反序列化 Payload，直接获取 Flag。

> 关联：[[php-file-inclusion-vulnerability]]（文件下载/源码泄露利用）、[[buuctf-web-writeup-collection]]（BUUOJ 实战题目汇总）

---

## SSTI（服务端模板注入）

### 基础检测与利用原理

- **检测**：提交 `{{7*7}}` 若返回 `49` 疑似存在 SSTI。
- **核心调用链**：
  - `"".__class__.__mro__[2].__subclasses__()` 获取 `object` 所有子类。
  - 通过 `__init__.__globals__` 查找 `os`、`popen` 等危险模块实现 RCE。
  - `config.items()` 可泄露服务器配置（如 `cookie_secret`）。

### 靶场：[WesternCTF2018] shrine 1

- **过滤点**：对 `()` 进行过滤，导致常规调用链失效。
- **绕过技巧**：
  - 使用 `url_for.__globals__`、`url_for.__globals__['current_app'].config` 绕过括号访问全局变量。
  - 绕过中括号 `[ ]`：`__bases__.__getitem__(0)`、`__subclasses__().pop(128)`。
  - 绕过逗号、双大括号：结合 `{% if ... %}1{% endif %}` 盲注输出。
- **工具辅助**：`tplmap` 自动化检测过滤规则。

> 关联：[[python-ssti-multi-engine-bypass]]（Jinja2/Tornado/Flask 多引擎绕过详解）、[[attack-defense-world-master-advanced-writeup]]（攻防世界 SSTI 实战题目）

---

## Python 字符串格式化漏洞

### 四种格式化方式及风险

| 方式 | 示例 | 风险点 |
|------|------|--------|
| `%` 操作符 | `'Hello, %s' % name` | 相对安全，但可泄露元组 |
| `string.Template` | `Template('Hey, $name!').substitute(name=name)` | 安全，仅支持简单替换 |
| `str.format()` | `'{}'.format(__import__('os').system('id'))` | **高危**，可访问 `__globals__`、`__builtins__` 执行任意代码 |
| f-Strings (Python 3.6+) | `f'{__import__("os").system("id")}'` | **极高危**，直接支持表达式执行 |

### 实战启示

- 若用户可控格式化字符串（如模板渲染、日志记录），**严禁**使用 `format()` 与 f-Strings。
- 代码审计时重点搜索 `.format(`、`f'`、`f"` 模式。

> 关联：[[python-ssti-multi-engine-bypass]]（SSTI 利用中常结合格式化字符串绕过黑名单）

---

## PHP CTF 核心绕过技巧

### 弱类型比较

- **特性**：`"1x" == 1` 为 `True`（字符串转数字时取前导数字）。
- **靶场示例**：`num=1x` 绕过 `$num === 1`（注意：`===` 不会触发弱类型，题目多为 `==`）。
- **防御**：统一使用 `===` 严格比较，或 `is_numeric()` + 类型强制转换。

> 关联：[[attack-defense-world-beginner-web-writeup]]（PHP 弱类型比较实战题目）

### `preg_match` 绕过姿势

| 技巧 | 原理 | 示例 |
|------|------|------|
| **异或构造** | 两字符串异或得新字符串，绕过关键字过滤 | `$a = "~" ^ "?";` 得到 `;` |
| **取反 + URL 编码** | `~"string"` 得到非可见字符，URL 编码传参 | `~"flag.php"` → `%9F%9E%9C%9A%8F%9E` |
| **数组绕过** | `preg_match` 仅处理字符串，传入数组返回 `false` | `?param[]=1` |
| **PCRE 回溯限制** | 超过 `pcre.backtrack_limit` (默认 1e6) 返回 `false` | 构造长字符串触发回溯耗尽 |
| **换行符绕过** | 正则未加 `s` 修饰符时 `.` 不匹配 `\n` | 多行 Payload 绕过单行匹配 |

### 靶场：hate_php

- **过滤**：`\`、`"`、`'`、`highlight_file`、`flag.php` 等函数/关键字均被过滤。
- **解法**：对 `highlight_file` 与 `flag.php` 取反并 URL 编码拼接，利用 `~` 运算符动态生成字符串调用。

### RCE 绕过：buuctf-ping ping ping

- **环境**：Linux，`ping` 命令注入。
- **过滤**：空格、`flag.php` 关键字。
- **绕过**：
  - `$IFS$2f` 替代空格与 `/`（`$IFS` 为内部字段分隔符，`$2f` 为 `/` 的十六进制）。
  - 变量拼接：`a=g;cat$IFS$2fla$a.php` → `cat flag.php`。

### PHP 反序列化：属性可见性绕过 (PHP > 7.1)

- **类结构**：`FileHandler` 含 `protected` 属性 `op`、`filename`、`content`。
- **序列化特征**：`protected` 属性序列化后名前含 `\00\00` (即 `%00%00`)，`is_valid` 方法拦截非可见字符 (ASCII 32-125)。
- **绕过**：手动构造 Payload 将 `protected` 改为 `public`，序列化后无 `\00\00`，通过 `is_valid` 校验。
- **利用链**：
  1. `op="2"` 触发 `read()` 方法读取 `filename`。
  2. `filename="flag.php"` 读取 Flag 内容。

> 关联：[[xd-security-deserialization-xxe-notes-day37-39]]（PHP 反序列化魔术方法与绕过详解）、[[php伪协议与反序列化利用]]（PHAR 反序列化、对象逃逸等进阶链）

---

## Java CTF 核心题型

### Java 逆向解密

- **场景**：下载附件（JAR/Class），使用 IDEA/JD-GUI 反编译。
- **手法**：分析加密逻辑（异或、Base64、AES 等），编写解密脚本还原 Flag。
- **工具**：IDEA、JD-GUI、Fernflower、CFR、Bytecode Viewer。

### WEB-INF 文件读取与源码审计

#### 目录结构速查

| 路径 | 说明 |
|------|------|
| `/WEB-INF/web.xml` | 应用配置，Servlet 映射、Filter、Listener 等 |
| `/WEB-INF/classes/` | 编译后的 `.class` 文件，按包名存放 |
| `/WEB-INF/lib/` | 依赖 JAR 包 |
| `/WEB-INF/src/` | 源码目录（若未清理） |
| `/WEB-INF/database.properties` | 数据库连接配置 |

#### 靶场：[RoarCTF 2019] Easy Java

- **入口**：`filename=` 参数疑似任意文件读取。
- **读取 `/WEB-INF/web.xml`** 确定 Controller 路径。
- **定位 Flag 类**：`com.ctf.FlagController` → `/WEB-INF/classes/com/wm/ctf/FlagController.class`。
- **反编译**：下载 Class 文件，IDEA 反编译得到 Base64 编码的 Flag，解码即得。

### XXE 结合文件上传：网鼎杯 2020 青龙组 filejava

- **上传点**：图片上传接口存在 `filename` 参数。
- **绕过删除**：直接上传 `web.xml` 被删除，使用 `../` 路径穿越保留文件。
- **代码审计**：下载上传后的 Class 文件反编译，定位 Flag 位置与过滤逻辑。
- **XXE 利用**：构造外部实体读取任意文件，绕过过滤获取 Flag。

> 关联：[[xxe-xml-dtd-fundamentals]]（XXE 原理、Blind XXE、UTF-16BE 绕过、自动化工具）、[[xd-security-deserialization-xxe-notes-day37-39]]（Java XXE 实战复现）

---

## 学习路线建议

1. **序列化/反序列化**：掌握 PHP `__wakeup`/`__destruct`/`__toString` 魔术方法、Java `readObject`/`AnnotationInvocationHandler` 等触发点，熟练使用 `ysoserial`、`phpggc` 生成链。
2. **SSTI 通杀**：熟记 Jinja2/Tornado/Flask 通用调用链（`__class__.__mro__.__subclasses__()`），积累绕过括号、中括号、逗号、双大括号的 Payload 库。
3. **PHP 弱类型与正则**：系统整理 `==`/`===`、`strcmp`、`md5`、`preg_match`、`parse_str` 等函数的边界行为，建立绕过 Payload 速查表。
4. **Java 审计基础**：熟悉 Maven/Gradle 项目结构、Spring/Struts2/Shiro 等框架漏洞特征，练习 JD-GUI/IDEA 反编译与动态调试（Remote Debug）。
5. **XXE 与文件读取**：掌握 `file://`、`http://`、`ftp://` 协议利用、Blind XXE 带外外带（DNSLog/FTP）、UTF-16BE 编码绕过 WAF。

---

## 参考资源

- XD安全渗透测试课程 Day83-85 原文归档
- BUUCTF / 攻防世界 / CTFshow 靶场实战
- [[xd-security-pentest-course-curriculum]]（课程大纲与知识图谱导航）
- [[xd-security-src-vulnerability-hunting-notes-day86-88]]（后续 SRC 挖掘实战笔记）

## 来源

- [0x00实验室-202108-202304_097](../sources/0x00实验室-202108-202304_097.md)
