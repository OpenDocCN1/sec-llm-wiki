---
title: BUUCTF Web Writeup Collection
description: 汇总 BUUCTF Web 方向 47 道题目的完整解题思路，按漏洞类型分类并交叉引用现有技术页面
category: program-analysis
tags:
- BUUCTF
- CTF Writeup
- Web安全
- SQL注入
- 文件包含
- 命令执行
- 文件上传
- 反序列化
- SSTI
- XXE
- 弱类型比较
- MD5碰撞
- 信息泄露
date: 2024-01-15
updated: '2026-11-14'
---

# BUUCTF Web 方向 47 道题目完整解题汇总

本页面整理自「无名安全团队」微信归档文章《BUUCTF -web安全部分 刷题分享》，覆盖 BUUCTF 靶场 Web 方向 47 道题目。按漏洞类型分类，并交叉引用知识库中已有的技术详解页面，形成结构化的知识索引。

---

## SQL注入

| 题目 | 核心技术点 | 交叉引用 |
|------|------------|----------|
| 2. easysql | 万能密码（`admin' --`） | [[ctfshow-web-sql-injection-bypass-basics]] |
| 4. 随便注 | 堆叠注入，`rename table`、`handler` 语句绕过 | [[attack-defense-world-master-advanced-writeup]]、[[mysql-duplicate-entry-error-based-sqli]] |
| 6. (SUCTF) easysql | 堆叠注入，`set sql_mode=pipes_as_concat` 拼绕过 | [[attack-defense-world-master-advanced-writeup]] |
| 9. LoveSql | 联合查询，`information_schema` 枚举库/表/列 | [[ctfshow-web-sql-injection-bypass-basics]]、[[mysql-dnslog-injection-loadfile-unc]] |
| 18. babysql | 双写绕过 `ununionion seselectlect` | [[ctfshow-web-sql-injection-bypass-basics]] |
| 25. hardsql | 报错注入 `updatexml`、`extractvalue` 无列名回显 | [[mysql-duplicate-entry-error-based-sqli]]、[[attack-defense-world-master-advanced-writeup]] |
| 26. hack world | 异或注入 `1^(ascii(substr(...))=x)` 逐位盲注 | [[sqlmap-api-automation]]、[[attack-defense-world-master-advanced-writeup]] |
| 27. babysqli | 联合查询构造虚拟行绕过登录，MD5 密码碰撞 | [[ctfshow-web-sql-injection-bypass-basics]] |
| 31. Backlist | 同题 4，`handler` 语句直接读表 | [[attack-defense-world-master-advanced-writeup]] |

---

## 文件包含与伪协议

| 题目 | 核心技术点 | 交叉引用 |
|------|------------|----------|
| 5. include1 | `php://filter/read=convert.base64-encode/resource=flag.php` 读源码 | [[php伪协议与反序列化利用]]、[[ssrf-ctf-exploitation-guide]] |
| 7. [极客大挑战 2019] Secret File | 伪协议 `php://filter` 任意文件读取 | [[php伪协议与反序列化利用]] |
| 23. nizhuansiwei | `php://input` + `text/plain` 绕过 `file_get_contents` 校验，反序列化 `__tostring` 弹 flag | [[php伪协议与反序列化利用]]、[[pikachu-target-writeup-part5]] |
| 39. ZJCTF，不过如此 | `php://filter` 读下一层 PHP，`preg_replace /e` 代码执行蚁剑连接 | [[php伪协议与反序列化利用]]、[[attack-defense-world-master-advanced-writeup]] |
| 43. had a had day | 去除 `.php` 后缀绕过 `strpos` 限制，`php://filter` 读 flag | [[php伪协议与反序列化利用]] |
| 37. 我有一个数据库 | phpMyAdmin 4.8.x `target=db_datadict.php?/../../../../../../../../flag` 文件包含 | [[vulnhub-platform-resource-index]]、[[attack-defense-world-master-advanced-writeup]] |
| 44. Fake XML cookbook | XXE 外部实体 `file:///flag` 读取，内网探测 | [[xxe-xml-dtd-fundamentals]]、[[ssrf-bypass-techniques]]、[[pikachu-target-writeup-part5]] |
| 45. Unicorn shop | Unicode 编码价格绕过大小判断 | — |

---

## 命令执行与代码执行

| 题目 | 核心技术点 | 交叉引用 |
|------|------------|----------|
| 8. exec | 直接命令执行函数 `system`、`exec` 等 | [[ctf-show-php-command-execution-bypass-techniques]]、[[php-webshell-fundamentals-chopper-analysis]] |
| 10. pingpingping | `ip` 参数命令注入，`|`、`;`、`&&` 绕过 | [[ctf-show-php-command-execution-bypass-techniques]] |
| 13. Easy Calc | `eval` 代码执行，`chr` 绕过字符过滤，`var_dump(file_get_contents(...))` 读 flag | [[attack-defense-world-master-advanced-writeup]]、[[ctf-show-php-command-execution-bypass-techniques]] |
| 15. easy_tornado | Tornado 模板 `cookie_secret` 泄露，伪造 `filehash` 签名读 `/fllllllllllllag` | [[python-ssti-multi-engine-bypass]]、[[gkctf-2021-web-writeup]] |
| 33. Online Tool | `nmap -oG` 文件写入 webshell，`escapeshellcmd` 绕过 | [[attack-defense-world-master-advanced-writeup]]、[[php-webshell-fundamentals-chopper-analysis]] |
| 35. 禁止套娃 | `.git` 源码泄露，`preg_replace` 递归正则绕过 `eval` 无参数 RCE | [[vulnhub-platform-resource-index]]、[[php伪协议与反序列化利用]] |
| 41. easy_web | MD5 弱类型绕过 `md5($_POST['a'])===md5($_POST['b'])` 后反引号命令执行，`\` 绕过过滤 | [[ctf-show-php-command-execution-bypass-techniques]]、[[attack-defense-world-master-advanced-writeup]] |
| 42. PHPWEB | 反序列化控制 `Test` 类 `func`/`p` 调用 `system` 执行 `find / -name *flag*` | [[php伪协议与反序列化利用]]、[[attack-defense-world-master-advanced-writeup]] |

---

## 文件上传绕过

| 题目 | 核心技术点 | 交叉引用 |
|------|------------|----------|
| 14. upload1 | 文件头验证绕过，上传图片马 | [[pikachu-target-writeup-part4]]、[[attack-defense-world-master-advanced-writeup]] |
| 17. upload1 (重复) | 同上 | 同上 |
| 24. checkin | `.user.ini` 配置 `auto_prepend_file` 包含图片马 | [[pikachu-target-writeup-part4]]、[[attack-defense-world-master-advanced-writeup]] |
| 28. 你传你🐎呢 | `.htaccess` 设置 `SetHandler` 解析图片马 | [[pikachu-target-writeup-part4]] |
| 32. Babyupload | 同题 28，`.htaccess` + 图片马 | [[pikachu-target-writeup-part4]] |
| 40. Mark loves cat | `.git` 源码泄露获取上传逻辑 | [[vulnhub-platform-resource-index]] |

---

## 反序列化

| 题目 | 核心技术点 | 交叉引用 |
|------|------------|----------|
| 1. WarmUp | `__wakeup` 绕过（属性计数不匹配），`private` 属性 `%00` 序列化读 `source.php` | [[php伪协议与反序列化利用]]、[[pikachu-target-writeup-part5]] |
| 16. php | 备份文件 `php.php~` 泄露源码，`__wakeup` 绕过 + `%00` 私有属性序列化 | [[php伪协议与反序列化利用]]、[[attack-defense-world-master-advanced-writeup]] |
| 23. nizhuansiwei | 见文件包含，反序列化 `Flag` 类 `__tostring` 读 flag | [[php伪协议与反序列化利用]]、[[pikachu-target-writeup-part5]] |
| 30. facebook | SQL 注入提取序列化数据，构造 `UserInfo` 类 `file://` 协议读 flag | [[php伪协议与反序列化利用]]、[[attack-defense-world-master-advanced-writeup]] |
| 35. 禁止套娃 | 见命令执行，`eval` 参数可控 | [[php伪协议与反序列化利用]] |
| 42. PHPWEB | 见命令执行，反序列化 `Test` 类实现 RCE | [[php伪协议与反序列化利用]]、[[attack-defense-world-master-advanced-writeup]] |
| 47. easy_serialize_php | `extract($_POST)` 变量覆盖 + `filter` 过滤关键字导致序列化字符串缩短，对象逃逸构造 `img` 指向 `d0g3_f1ag.php` | [[php伪协议与反序列化利用]]、[[attack-defense-world-master-advanced-writeup]] |

---

## SSTI (服务端模板注入)

| 题目 | 核心技术点 | 交叉引用 |
|------|------------|----------|
| 15. easy_tornado | Tornado 模板 `handler.settings.cookie_secret` 泄露，伪造签名 | [[python-ssti-multi-engine-bypass]]、[[gkctf-2021-web-writeup]] |
| 38. The mystery of ip1 | `X-Forwarded-For` 头注入 SSTI，`{{config.__class__.__init__.__globals__}}` 等 Payload | [[python-ssti-multi-engine-bypass]]、[[attack-defense-world-master-advanced-writeup]] |
| 46. Cookie is so stable | Twig 模板 `registerUndefinedFilterCallback("exec")` 执行命令 | [[python-ssti-multi-engine-bypass]]、[[gkctf-2021-web-writeup]] |

---

## XXE (XML 外部实体注入)

| 题目 | 核心技术点 | 交叉引用 |
|------|------------|----------|
| 44. Fake XML cookbook | `DOCTYPE` 定义外部实体 `file:///flag`，回显读取 | [[xxe-xml-dtd-fundamentals]]、[[ssrf-bypass-techniques]]、[[pikachu-target-writeup-part5]] |

---

## 弱类型比较与 MD5 碰撞

| 题目 | 核心技术点 | 交叉引用 |
|------|------------|----------|
| 19. BackupFile | `intval` 弱类型 `123 == "123ffwsfwefwf24r2f32ir23jrw923rskfjwtsw54w3"` | [[ctfshow-web-sql-injection-bypass-basics]]、[[attack-defense-world-master-advanced-writeup]] |
| 21. buyflag | 科学计数法 `money=1e9` 绕过数值比较，`password=404a` 弱类型 `==` | [[ctfshow-web-sql-injection-bypass-basics]] |
| 22. easyMD5 | `md5($pass,true)` 产生二进制字符串，`0e` 开头科学计数法碰撞 | [[crypto-basics-xor-stream-cipher-tutorial]]、[[attack-defense-world-master-advanced-writeup]] |
| 29. Ez_bypass | MD5 碰撞数组绕过 `md5($id)===md5($gg)`，弱类型 `1234567c == 1234567` | [[crypto-basics-xor-stream-cipher-tutorial]]、[[attack-defense-world-master-advanced-writeup]] |
| 41. easy_web | 见命令执行，MD5 强制字符串转换绕过 | [[ctf-show-php-command-execution-bypass-techniques]] |

---

## 信息泄露 (源码泄露、备份文件、.git、web-INF)

| 题目 | 核心技术点 | 交叉引用 |
|------|------------|----------|
| 16. php | 备份文件 `php.php~` 泄露源码 | [[vulnhub-platform-resource-index]]、[[attack-defense-world-master-advanced-writeup]] |
| 19. BackupFile | 备份文件泄露 `flag.php` 源码 | [[vulnhub-platform-resource-index]] |
| 34. easy java | Java `web-INF/web.xml` 泄露，反编译 `FlagController.class` Base64 解码 flag | [[attack-defense-world-master-advanced-writeup]]、[[vulnhub-platform-resource-index]] |
| 35. 禁止套娃 | `.git` 目录泄露，源码审计发现 `eval` 无参数 RCE | [[vulnhub-platform-resource-index]]、[[attack-defense-world-master-advanced-writeup]] |
| 36. 高明的黑客 | 批量脚本扫描目录寻找可控参数文件 | [[vulnhub-platform-resource-index]] |
| 37. 我有一个数据库 | phpMyAdmin 目录扫描发现后台 | [[vulnhub-platform-resource-index]] |
| 40. Mark loves cat | `.git` 泄露 | [[vulnhub-platform-resource-index]] |

---

## 会话与认证绕过

| 题目 | 核心技术点 | 交叉引用 |
|------|------------|----------|
| 3. Havefun | 直接传参 `dog` 获得 flag | — |
| 11. Knife | 蚁剑连接现成 webshell | [[php-webshell-fundamentals-chopper-analysis]] |
| 12. http | 修改 HTTP 头 `User-Agent`、`Referer`、`X-Forwarded-For` 等绕过校验 | [[ctfshow-web-info-gathering-brute-force]] |
| 20. admin | Flask `session` 伪造 `name=admin`，利用 `SECRET_KEY` 签名 | [[jwt漏洞原理与实战利用]]、[[attack-defense-world-master-advanced-writeup]] |

---

## 其他技巧

| 题目 | 核心技术点 | 交叉引用 |
|------|------------|----------|
| 30. facebook | 结合 SQL 注入与反序列化，`extractvalue` 报错注入分段提取序列化字符串 | [[attack-defense-world-master-advanced-writeup]]、[[mysql-duplicate-entry-error-based-sqli]] |
| 33. Online Tool | `nmap -oG` 写文件，`escapeshellcmd` 单引号嵌套绕过 | [[attack-defense-world-master-advanced-writeup]] |
| 45. Unicorn shop | Unicode 编码价格绕过整数比较 | — |
| 47. easy_serialize_php | 序列化对象逃逸，利用 `filter` 过滤导致长度变化构造恶意序列化 | [[php伪协议与反序列化利用]]、[[attack-defense-world-master-advanced-writeup]] |

---

## 学习路线建议

1. **基础漏洞原理**：先阅读 [[php伪协议与反序列化利用]]、[[xxe-xml-dtd-fundamentals]]、[[python-ssti-multi-engine-bypass]]、[[ctfshow-web-sql-injection-bypass-basics]] 夯实核心原理。
2. **实战绕过技巧**：结合 [[attack-defense-world-master-advanced-writeup]]、[[pikachu-target-writeup-part4]]、[[pikachu-target-writeup-part5]] 学习 WAF/过滤绕过套路。
3. **工具链熟练度**：熟练使用 [[sqlmap-api-automation]] 自动化注入、[[php-webshell-fundamentals-chopper-analysis]] 蚁剑管理、[[frp内网渗透应用]] 内网穿透。
4. **源码审计思维**：参考 [[vulnhub-platform-resource-index]] 中的实战案例，练习从备份文件、`.git`、错误回显中还原逻辑。
5. **综合靶场演练**：按难度顺序在 BUUCTF 复现上述 47 道题，重点关注跨类型组合题（如 SQLi+反序列化、文件包含+伪协议、SSTI+模板引擎特性）。

---

> **维护说明**：本页面基于微信归档文章整理，若原文章更新或发现遗漏，请同步修正。所有交叉引用均指向知识库现有页面，确保知识图谱可达性。

## 来源

- [0x00实验室-202108-202304_080](../sources/0x00实验室-202108-202304_080.md)
