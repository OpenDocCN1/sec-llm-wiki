---
title: 攻防世界Web新手练习区全题型Writeup
description: 攻防世界靶场Web新手练习区11道题目完整解题报告，涵盖view-source信息泄露、robots.txt敏感路径泄露、备份文件下载、Cookie篡改、前端按钮绕过、弱口令爆破、PHP弱类型比较绕过、GET/POST传参、XFF/Referer头伪造、Webshell连接、命令执行、JS逆向等基础Web安全技术点。
category: program-analysis
tags:
- 攻防世界
- CTF Writeup
- Web安全
- 信息泄露
- 弱口令爆破
- PHP弱类型比较
- HTTP头伪造
- Webshell
- 命令执行
- JS逆向
- 前端绕过
date: 2024-01-15
updated: '2026-11-14'
---

## 概述

本页面整理自 0w1Club 微信公众号归档文章《攻防世界-答题-WEB-新手练习区》，系统复现攻防世界靶场 Web 新手练习区 11 道题目的完整解题过程。题目涵盖 Web 入门阶段最核心的 **信息收集、前端绕过、认证绕过、输入验证绕过、HTTP 协议层攻击、服务端代码执行、客户端脚本逆向** 等技术点，适合 CTF 初学者构建 Web 攻防基础知识体系。

> 关联进阶区 Writeup：[[attack-defense-world-master-advanced-writeup]]  
> 关联 BUUCTF Web 实战合集：[[buuctf-web-writeup-collection]]  
> 关联 CTFshow Web 入门系列：[[ctfshow-web-info-gathering-brute-force]]、[[ctfshow-web-sql-injection-bypass-basics]]、[[ctf-show-php-command-execution-bypass-techniques]]

---

## 题目详解与技术点归纳

### view-source —— 响应包信息泄露

**核心技术点**：HTTP 响应包中直接返回 Flag，无需渲染到前端页面。

- 现象：前端页面右键禁用，无可见 Flag
- 解法：抓包（Burp Suite）查看 HTTP 响应体，直接发现 `cyberpeace{5239b15510f4de4c67f7f12226e91888}`
- 启示：**永远检查原始 HTTP 响应**，前端渲染层可能隐藏敏感数据

### robots —— robots.txt 敏感路径泄露

**核心技术点**：`robots.txt` 协议文件可能泄露隐藏目录/文件路径。

- 背景知识：robots.txt 告知爬虫允许/禁止抓取的路径，但也会暴露后台、备份、测试等敏感路径
- 解法：访问 `/robots.txt` 提示 `flag在 f1ag_1s_h3re.php`，直接访问该文件获取 Flag
- 实战价值：**信息收集阶段必访问 robots.txt、sitemap.xml、.well-known/ 等标准路径**

### backup —— 备份文件下载导致源码泄露

**核心技术点**：常见备份文件后缀（`.bak`、`.git`、`.svn`、`.swp`、`.bash_history` 等）可直接下载源码。

- 解法：尝试 `index.php.bak` 触发下载，打开文件获取 Flag `Cyberpeace{855A1C4B3401294CB6604CCC98BDE334}`
- 扩展：结合目录扫描工具（dirsearch、ffuf）批量探测备份文件
- 关联：[[php伪协议与反序列化利用]] 中 `php://filter` 读取源码技巧

### cookie —— Cookie 篡改与隐藏页面发现

**核心技术点**：HTTP 响应头 `Set-Cookie` 或响应体中泄露隐藏页面路径。

- 解法：抓包发现 `cookie.php` 提示 `See the http response`，查看响应包直接得到 Flag
- 技巧：**重点关注响应头、响应体中的注释、JS 变量、隐藏表单字段**

### disabled_button —— 前端按钮 `disabled` 属性绕过

**核心技术点**：前端验证完全不可信，HTML `disabled` 属性可通过开发者工具移除或修改为 `false`。

- 解法：F12 审查元素，删除 `<button>` 的 `disabled` 属性，点击获取 Flag
- 实战延伸：前端 JS 校验、隐藏表单、下拉框选项、前端加密均可绕过
- 关联：[[pikachu-target-writeup-part1-setup-brute-force]] 中 Token/验证码前端绕过案例

### weak_auth —— 弱口令爆破

**核心技术点**：Burp Suite Intruder 模块四种爆破模式的选择与应用。

| 模式 | 适用场景 |
|------|----------|
| Sniper | 单参数、单字典逐个尝试 |
| Batteringram | 多参数使用**同一字典**同步尝试 |
| Pitchfork | 多参数对应**多字典**一一对应（取最短字典长度） |
| Cluster bomb | 多参数**笛卡尔积**全组合爆破（最全但最慢） |

- 实战：单参数 `password` 使用 Sniper 模式 + 弱口令字典，发现 `admin/123456` 返回包长度异常，获取 Flag
- 关联：[[ctfshow-web-info-gathering-brute-force]] 系统梳理爆破技巧；[[pikachu-target-writeup-part1-setup-brute-force]] 实战四类绕过

### simple_php —— PHP 弱类型比较与逻辑绕过

**核心技术点**：PHP `==` 松散比较特性 + `is_numeric()` 绕过 + 字符串数字比较规则。

```php
// 源码逻辑
$a = $_GET['a'];  // a == 0 且 a 为真
$b = $_GET['b'];  // b 非数字 且 b > 1234

// 绕过载荷
// a: ' 0' (字符串前带空格) 或 '0e...' (科学计数法字符串)
// b: '1235a' (字符串开头数字 > 1234，is_numeric 返回 false)
```

- 关键知识：
  - `' 0' == 0` 为 `true`，但非空字符串为 `true`
  - `'0e123' == 0` 为 `true`（科学计数法被解析为 0）
  - `is_numeric('1235a')` 返回 `false`，但 `'1235a' > 1234` 在字符串比较中为 `true`（PHP 按字符串比较时逐字符比对 ASCII）
- 关联：[[php伪协议与反序列化利用]] 中弱类型比较绕过专节；[[buuctf-web-writeup-collection]] 多题实战

### get_post —— GET/POST 传参切换与 Content-Type 设置

**核心技术点**：HTTP 方法切换 + `application/x-www-form-urlencoded` 正确设置。

- 两种修改 POST 方式：
  1. 火狐渗透便携版 HackBar 插件直接修改方法并发送
  2. Burp Suite 抓包修改：`GET -> POST`，添加 `Content-Type: application/x-www-form-urlencoded` 头，**空一行**后写入 `key=value` 数据
- 易错点：忘记空行分隔包头与包体，导致服务端解析失败

### xff_referer —— HTTP 头伪造

**核心技术点**：`X-Forwarded-For` (XFF) 伪造客户端 IP + `Referer` 伪造来源页面。

- XFF 原理：代理服务器在转发请求时添加，记录真实客户端 IP 链；**极易伪造**，不可用于鉴权
- Referer 原理：浏览器自动带上来源页面 URL；**可被篡改/移除**，不可作为唯一 CSRF 防御
- 解法：Burp 修改请求头
  ```
  X-Forwarded-For: 123.123.123.123
  Referer: https://www.google.com
  ```
- 关联：[[ssrf-bypass-techniques]] 中 HTTP 头绕过技巧；[[ctfshow-web-info-gathering-brute-force]] 头部信息收集

### webshell —— 一句话木马连接

**核心技术点**：PHP `eval()` 执行任意代码 + 菜刀/蚁剑客户端连接。

- 后门特征：`index.php` 中 `eval($_POST['shell'])`，密码 `shell`
- 连接流程：蚁剑填入 URL、密码 `shell`、编码器 `php/base64`，直接获取文件管理、虚拟终端、数据库管理等功能
- 关联：[[php-webshell-fundamentals-chopper-analysis]] 完整原理与流量分析；[[php-webshell-obfuscation-av-evasion]] 免杀对抗

### command_execution —— 命令注入 (RCE)

**核心技术点**：未过滤用户输入直接拼接进 `system()`/`exec()`/`shell_exec()` 等函数。

- 判断系统：`ping 127.0.0.1` 回显正常 → Linux（大小写敏感）
- 绕过技巧：`; ls`、`| ls`、`&& ls`、反引号 `` `ls` ``、`$()` 等命令分隔符/子命令执行
- 关联：[[ctf-show-php-command-execution-bypass-techniques]] 系统梳理 9-23 关绕过链；[[ssrf-bypass-techniques]] Gopher/Redis RCE 链

### simple_js —— JavaScript 逆向与混淆还原

**核心技术点**：前端 JS 逻辑混淆、十六进制/Unicode 编码、动态解密。

- 现象：输入任意密码提示 `FAUX PASSWORD HAHA`
- 分析：查看源码发现混淆 JS，核心解密函数 `dechiffre()` 中硬编码了密码数组
- 解法：提取数组 `pass = "70,65,85,88,32,80,65,83,83,87,79,82,68,32,72,65,72,65"`，ASCII 解码得 `PAUX PASSWORD HAHA`，实际 Flag 为 `786OsErtk12`（需按题目 Flag 格式提交）
- 工具辅助：浏览器 Console 直接执行解密函数、在线 JS 格式化/去混淆工具（JSNice、deobfuscate.io）
- 关联：[[gkctf-2021-web-writeup]] 中 Node.js 原型链污染/JS 逆向；[[binary-ninja-ollvm-deobfuscation]] 二进制层面去混淆思路迁移

---

## 核心技术点总结表

| 类别 | 题目 | 核心技术 | 关联进阶知识页 |
|------|------|----------|----------------|
| 信息收集 | view-source | HTTP 响应包直接泄露 | [[ctfshow-web-info-gathering-brute-force]] |
| 信息收集 | robots | robots.txt 敏感路径泄露 | 同上 |
| 信息收集 | backup | 备份文件后缀枚举下载 | [[php伪协议与反序列化利用]] php://filter |
| 前端绕过 | cookie | 响应头/体隐藏信息 | — |
| 前端绕过 | disabled_button | HTML 属性/JS 校验绕过 | [[pikachu-target-writeup-part1-setup-brute-force]] |
| 认证攻击 | weak_auth | Burp Intruder 四模式爆破 | 同上、[[ctfshow-web-info-gathering-brute-force]] |
| 逻辑绕过 | simple_php | PHP 弱类型 `==`、`is_numeric` 绕过 | [[php伪协议与反序列化利用]]、[[buuctf-web-writeup-collection]] |
| 协议层 | get_post | HTTP 方法切换、Content-Type | — |
| 协议层 | xff_referer | XFF/Referer 头伪造 | [[ssrf-bypass-techniques]] |
| 代码执行 | webshell | PHP eval 一句话 + 蚁剑连接 | [[php-webshell-fundamentals-chopper-analysis]]、[[php-webshell-obfuscation-av-evasion]] |
| 代码执行 | command_execution | 命令注入分隔符绕过 | [[ctf-show-php-command-execution-bypass-techniques]] |
| 逆向分析 | simple_js | JS 混淆还原、ASCII 解码 | [[gkctf-2021-web-writeup]]、[[binary-ninja-ollvm-deobfuscation]] |

---

## 学习路线建议

1. **基础巩固**：逐题复现上述 11 道题，掌握 Burp Suite 核心功能、HTTP 协议细节、PHP 常见绕过模式
2. **工具精通**：熟练使用 Burp Intruder/Repeater/Decoder、浏览器开发者工具、蚁剑/菜刀、在线编解码工具
3. **知识迁移**：对照 [[ctfshow-web-info-gathering-brute-force]]、[[ctf-show-php-command-execution-bypass-techniques]] 等系统化页面，将零散技巧串联成完整攻击链
4. **实战进阶**：挑战 [[attack-defense-world-master-advanced-writeup]] 高手进阶区、[[buuctf-web-writeup-collection]] 实战题库、[[pikachu-target-writeup-part1-setup-brute-force]] 靶场全系列
5. **代码审计视角**：从「利用」转向「挖掘」，阅读 [[php伪协议与反序列化利用]]、[[huxiangbei-willphp-file-inclusion-writeup]] 等源码级分析，理解漏洞成因与修复

---

## 参考资源

- 原文归档：0w1Club 微信公众号《攻防世界-答题-WEB-新手练习区》
- 攻防世界靶场：https://adworld.xctf.org.cn/
- 0w1Club 社团知识库：本站 `program-analysis` 分类下 Web 安全系列页面

## 来源

- [0x00实验室-202108-202304_081](../sources/0x00实验室-202108-202304_081.md)
