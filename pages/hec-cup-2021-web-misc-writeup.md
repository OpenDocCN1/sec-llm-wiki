---
title: 2021 鹤城杯 Web 与 Misc 方向完整 Writeup
description: 2021 鹤城杯 CTF 竞赛 Web 与 Misc 方向题目完整解题报告，涵盖 PHP 黑魔法绕过、流量取证盲注、MySQL 8.0 TABLE
  语句注入、SSRF Gopher 协议攻击 MySQL、Spring Web Flow CVE-2017-4971 RCE 等实战技术。
category: program-analysis
tags:
- 鹤城杯
- CTF Writeup
- Web安全
- PHP黑魔法
- SQL注入
- MySQL 8.0
- SSRF
- Gopher协议
- Spring Web Flow
- CVE-2017-4971
- 流量取证
- 盲注
- Misc
date: 2021-04-15
updated: '2026-11-15'
---

## 概述

本页面记录 2021 年鹤城杯 CTF 竞赛中 Web 与 Misc 方向的完整解题过程。比赛涉及 PHP 特性绕过、SQL 注入变种利用、流量包分析盲注、SSRF 协议转发攻击内网 MySQL、Spring 框架已知漏洞利用等核心技术点。所有题目均来自微信公众号归档文章实战复现。

## 题目清单

| 题目名称 | 方向 | 核心技术点 | 难度 |
|---------|------|-----------|------|
| middle_magic | Web | PHP 黑魔法、弱类型比较、正则绕过 | ⭐⭐ |
| 流量取证 | Misc | Wireshark 流量分析、HTTP 流还原、盲注脚本 | ⭐⭐⭐ |
| easy_sql_2 | Web | MySQL 8.0 TABLE 语句注入、堆叠注入、SELECT 过滤绕过 | ⭐⭐⭐ |
| misc (盲注) | Misc | 盲注脚本编写、ASCII 码解码、Flag 提取 | ⭐⭐ |
| easyp | Web | PHP 黑魔法、换行符绕过、URL 解析差异 | ⭐⭐ |
| spring | Web | Spring Web Flow CVE-2017-4971 RCE、表达式语言注入 | ⭐⭐⭐ |
| easy_sql_1 | Web | SSRF Gopher 协议、Cookie 注入、MySQL 未授权访问 | ⭐⭐⭐⭐ |

---

## middle_magic —— PHP 黑魔法绕过

### 题目描述

经典的 PHP "黑魔法"题目，利用 PHP 弱类型比较、正则匹配特性绕过验证逻辑。

### 核心知识点

- **PHP 弱类型比较**：`==` 运算符在字符串与数字比较时会将字符串转为数字，如 `"0e12345" == "0e67890"` 为 `true`（均视为科学计数法 0）。
- **正则绕过**：`preg_match` 可通过数组参数绕过、换行符绕过（需 `/s` 修饰符）、或利用 PCRE 回溯限制。
- **魔术方法触发**：`__wakeup`、`__destruct`、`__toString` 等在反序列化链中的利用。

### 相关技术页面

- [[php伪协议与反序列化利用]] —— 深度解析 PHP 反序列化 `__wakeup` 绕过（对象计数不匹配）、正则过滤数字绕过（`+` 前缀）、Base64 编码差异导致的利用细节。
- [[php-webshell-fundamentals-chopper-analysis]] —— PHP 一句话木马核心执行原理、eval() 特性、客户端连接流程分析。
- [[ctfshow-web-sql-injection-bypass-basics]] —— PHP/MySQL 环境下 `intval()` 特性利用、正则过滤递进绕过、进制转换、位运算等绕过技巧。

---

## 流量取证 —— Wireshark 盲注 Flag

### 题目描述

给定流量包（pcapng），通过 Wireshark 分析 HTTP 请求，发现盲注攻击流量，编写脚本提取 Flag。

### 解题流程

1. **流量包打开**：Wireshark 打开 pcap 文件，过滤 `http` 协议。
2. **追踪 HTTP 流**：右键可疑请求 → Follow → HTTP Stream，观察请求参数变化。
3. **识别盲注特征**：
   - 请求参数中含 `id=1` 类似构造
   - 响应长度/内容差异暗示布尔盲注或时间盲注
   - 发现 ASCII 码逐字符提取的请求序列
4. **导出数据**：File → Export Objects → HTTP，或使用 `tshark` 命令行批量导出：
   ```bash
   tshark -r traffic.pcap -Y http -T fields -e http.request.uri > urls.txt
   ```
5. **编写提取脚本**：解析响应差异，还原 Flag 字符。

### Flag 结果

```
flag{w1reshARK_ez_1sntit}
```

### 相关技术页面

- [[xd-security-incident-response-notes]] —— 应急响应中流量回溯、Web 攻击溯源、日志分析全流程，含 Wireshark 实战技巧。
- [[ssrf-ctf-exploitation-guide]] —— 基于 Pikachu 靶场实战复现 SSRF 漏洞利用中的流量分析与协议差异对比。
- [[ctfshow-web-info-gathering-brute-force]] —— CTFshow 信息收集关卡中的流量分析、目录爆破、源码泄露等实战技巧。

---

## easy_sql_2 —— MySQL 8.0 TABLE 语句注入

### 题目描述

过滤了 `SELECT` 关键字，利用 MySQL 8.0 新特性 `TABLE` 语句实现无 `SELECT` 的数据查询。

### 核心技术原理

MySQL 8.0.19+ 引入 `TABLE` 语句，语法：
```sql
TABLE table_name [ORDER BY column] [LIMIT offset, row_count];
```
等价于 `SELECT * FROM table_name`，但不包含 `SELECT` 关键字，可绕过 WAF/过滤。

### 利用链构造

1. **确定注入点**：测试参数闭合方式（引号、括号、注释）。
2. **堆叠注入验证**：尝试 `; TABLE users;--` 执行多语句。
3. **数据枚举**：
   ```sql
   ; TABLE information_schema.tables;--
   ; TABLE information_schema.columns WHERE table_schema=database();--
   ; TABLE flag_table;--
   ```
4. **绕过过滤组合**：
   - 大小写混淆：`tAbLe`
   - 内联注释：`TA/*!*/BLE`
   - 编码绕过：URL 双重编码、Unicode 编码

### 相关技术页面

- [[mysql-duplicate-entry-error-based-sqli]] —— MySQL 报错注入原理，`floor(rand(0)*2)` 与 `GROUP BY` 交互机制。
- [[ctfshow-web-sql-injection-bypass-basics]] —— 堆叠注入、报错注入、盲注、宽字节注入、二阶注入等核心技术体系。
- [[buuctf-web-writeup-collection]] —— BUUCTF 47 道 Web 题目按漏洞类型分类，含 SQL 注入变种利用链交叉引用。
- [[xd-security-pentest-basic-stage-notes]] —— XD安全渗透测试课程基础阶段 SQL 注入模块：MySQL/Oracle/MongoDB/盲注/二次注入/DNSLog/堆叠注入/WAF 绕过。

---

## misc (盲注部分) —— ASCII 码解码提取 Flag

### 题目描述

题目给出一串 ASCII 码序列，需解码还原 Flag。前序可能涉及图片隐写（未解出），此处仅记录盲注部分。

### 给定数据

```
99,100,50,99,51,101,50,102,101,97,52,54,51,100,101,100,57,97,102,56,48,48,100,55,49,53,53,98,101,55,97,113,125
```

### 解码脚本

```python
ascii_codes = [99,100,50,99,51,101,50,102,101,97,52,54,51,100,101,100,57,97,102,56,48,48,100,55,49,53,53,98,101,55,97,113,125]
flag = ''.join(chr(c) for c in ascii_codes)
print(flag)
```

### 输出结果

```
cd2c3e2fea463ded9af800d7155be7aq}
```
> 注：Flag 格式疑似不完整或题目存在多阶段，前缀 `flag{` 缺失，可能需结合隐写部分拼接。

### 相关技术页面

- [[crypto-basics-xor-stream-cipher-tutorial]] —— 异或加密核心原理、Two-Time-Pad 攻击实战、流密码基本概念及 RC4 算法。
- [[ctfshow-web-info-gathering-brute-force]] —— PHP `mt_rand` 种子预测与 `php_mt_seed` 破解、MySQL 空连接尝试、身份证/目录爆破等编码解码实战。

---

## easyp —— PHP 黑魔法进阶绕过

### 题目描述

两阶段绕过：第一阶段利用换行符绕过文件包含/函数调用检测；第二阶段利用 URL 解析差异绕过主机名校验。

### 第一阶段：换行符绕过

- **Payload**：`utils.php%0a` 或 `utils.php%0d`
- **原理**：PHP `include/require` 在处理路径时，某些版本/配置下会截断于换行符，或正则校验未加 `/s` 修饰符导致 `.` 不匹配换行符。
- **实战细节**：作者提到起初 `%0a` 可行，后需 `%0d`，暗示服务端可能做了针对性过滤或 PHP 版本差异。

### 第二阶段：URL 解析差异绕过

- **技术点**：PHP `parse_url()` 与浏览器/客户端对 URL 解析存在差异，可构造类似 `http://evil.com@target.com` 或 `http://target.com:80@evil.com` 绕过主机名白名单校验。
- **参考截图**：学长提供的截图记录了具体绕过构造（原文图片链接已失效，此处仅记录技术方向）。

### 相关技术页面

- [[php-file-inclusion-vulnerability]] —— PHP 文件包含漏洞成因、四大危险函数差异、目录穿越与截断绕过、`php://filter`/`php://input`/`data://` 伪协议利用链。
- [[php伪协议与反序列化利用]] —— SSRF 场景下 `file://` 本地文件读取、`gopher://` 发送原始 TCP 包攻击 FastCGI/Redis、双重 URL 编码绕过解析机制。
- [[ssrf-bypass-techniques]] —— SSRF 五大核心绕过技巧：用户信息绕过、十六进制 IP 绕过、302 跳转绕过、DNS 重绑定绕过、localhost 绕过。

---

## spring —— Spring Web Flow CVE-2017-4971 RCE

### 题目描述

原题复现：Spring Web Flow 远程代码执行漏洞（CVE-2017-4971），利用表达式语言（EL）注入实现 RCE。

### 漏洞原理

- **影响版本**：Spring Web Flow 2.4.0 - 2.4.4、2.3.0 - 2.3.3
- **根因**：`flowExecutionUrl` 参数未正确过滤，允许 SpEL (Spring Expression Language) 表达式注入。
- **攻击向量**：构造恶意 `flowExecutionUrl` 触发 `StandardEvaluationContext` 执行任意代码。

### 利用 Payload 示例

```java
// 经典 SpEL RCE 链
T(java.lang.Runtime).getRuntime().exec("cmd")
new java.lang.ProcessBuilder({"bash","-c","cmd"}).start()
```

### 参考资料

- [掘金文章：Spring Web Flow框架远程代码执行(CVE-2017-4971)](https://juejin.cn/post/7006672559714336805)

### 相关技术页面

- [[struts2-memory-shell-injection]] —— Struts2 OGNL 注入内存马注入技术，ClassLoader 隔离导致的失败原因与突破方案。
- [[shiro-internal-penetration-case-study]] —— Shiro RCE 初始访问、Cobalt Strike 免杀上线、内网横向移动全链路实战（Java 反序列化/RCE 场景对比）。
- [[cve-2023-23477-ibm-websphere-rce]] —— IBM WebSphere 反序列化 RCE 漏洞预警与修复方案（Java 企业级中间件漏洞对比）。

---

## easy_sql_1 —— SSRF Gopher 协议攻击 MySQL + Cookie 注入

### 题目描述

唯一未解出题目，赛后复盘：利用 SSRF Gopher 协议向本地 MySQL 发送构造包，配合 Cookie 位 SQL 注入获取 Flag。

### 攻击链拓扑

```
Attacker → SSRF (index.php) → Gopher://127.0.0.1:3306 → MySQL (未授权/弱口令) → Cookie 注入点 → Flag
```

### 核心技术细节

#### SSRF Gopher 协议构造 MySQL 握手包

MySQL 协议基于 TCP，Gopher 可发送原始字节流。需构造：
- **Client 握手包**：能力标志、字符集、用户名（`admin`）、密码（`admin`）认证插件响应。
- **查询包**：`COM_QUERY` 命令 + SQL 语句（注入 Payload）。

**Python 构造脚本框架**：
```python
import socket
import struct

def mysql_handshake(user, password):
    # 构造客户端握手包
    # ...
    return packet

def mysql_query(sql):
    # 构造 COM_QUERY (0x03) 包
    # packet_len (3字节) + packet_id (1字节) + 0x03 + sql
    return packet

# 生成 Gopher URL
gopher_payload = "gopher://127.0.0.1:3306/_" + urllib.parse.quote(handshake + query)
```

#### Cookie 位 SQL 注入

- **注入点**：HTTP 请求的 `Cookie` 头字段（如 `user_id=1`）。
- **绕过思路**：
  - MySQL 8.0 `TABLE` 语句（同 easy_sql_2）
  - 堆叠注入执行 `SET @sql=...; PREPARE stmt FROM @sql; EXECUTE stmt;`
  - 报错注入/盲注提取数据

#### 完整利用流程

1. 访问 `index.php`，发现 SSRF 参数（如 `url=`）。
2. 构造 Gopher Payload 发送 MySQL 认证 + 注入查询。
3. 通过 SSRF 触发，MySQL 执行注入，Flag 通过报错/带外通道回显。

### 相关技术页面

- [[ssrf-bypass-techniques]] —— SSRF 绕过技巧全集，含 Gopher/FastCGI/Redis 多协议利用链实战细节。
- [[php伪协议与反序列化利用]] —— `gopher://` 发送原始 TCP 包攻击 FastCGI/Redis、双重 URL 编码绕过、SSRF 场景下文件读取。
- [[mysql-dnslog-injection-loadfile-unc]] —— MySQL `load_file()` 配合 Windows UNC 路径实现 DNSLog 盲注数据外带原理。
- [[xd-security-pentest-basic-stage-notes]] —— SQL 注入模块含 Cookie 注入、HTTP Header 注入实战分类。
- [[named-pipe-smb-detection-sysmon]] —— SMB 命名管道通信模型，Cobalt Strike SMB Beacon 与 External C2 对比（协议层面理解）。

---

## 知识点总结与交叉引用索引

| 技术领域 | 核心知识点 | 关联页面 |
|---------|-----------|---------|
| **PHP 特性绕过** | 弱类型比较、正则绕过、换行符截断、魔术方法 | [[php伪协议与反序列化利用]]、[[php-file-inclusion-vulnerability]]、[[php-webshell-fundamentals-chopper-analysis]] |
| **SQL 注入进阶** | MySQL 8.0 TABLE 语句、堆叠注入、Cookie/Header 注入、SELECT 过滤绕过 | [[ctfshow-web-sql-injection-bypass-basics]]、[[mysql-duplicate-entry-error-based-sqli]]、[[buuctf-web-writeup-collection]] |
| **SSRF 协议利用** | Gopher 攻击 MySQL、FastCGI、Redis、双重 URL 编码、302 跳转 | [[ssrf-bypass-techniques]]、[[ssrf-ctf-exploitation-guide]]、[[php伪协议与反序列化利用]] |
| **Java 框架 RCE** | Spring Web Flow SpEL、Struts2 OGNL、Shiro 反序列化 | [[struts2-memory-shell-injection]]、[[shiro-internal-penetration-case-study]]、[[cve-2023-23477-ibm-websphere-rce]] |
| **流量取证分析** | Wireshark HTTP 流还原、盲注流量识别、tshark 批量导出 | [[xd-security-incident-response-notes]]、[[ctfshow-web-info-gathering-brute-force]] |
| **编码/解码技巧** | ASCII 码还原、Base64/URL/Unicode 多重编码、异或加密 | [[crypto-basics-xor-stream-cipher-tutorial]]、[[ctfshow-web-info-gathering-brute-force]] |

---

## 实战建议与避坑指南

1. **MySQL 8.0 新特性利用**：除 `TABLE` 语句外，关注 `VALUES ROW()`、CTE (Common Table Expressions) 等无 `SELECT` 查询方式。
2. **Gopher 协议构造工具化**：推荐使用 [Gopherus](https://github.com/tarunkant/Gopherus) 或自写脚本生成 MySQL/Redis/FastCGI 利用包，注意 URL 编码规则（Gopher 协议下 `_` 后内容需原始字节 URL 编码）。
3. **SSRF 绕过组合拳**：实战中常需组合「协议转换 + 编码绕过 + 302 跳转 + DNS 重绑定」多层绕过，建议建立个人 Payload 字典库。
4. **流量取证自动化**：编写 `tshark` + Python 批处理脚本，自动提取 HTTP 参数、响应差异、还原盲注 Flag，提升 CTF 解题效率。
5. **Java 框架漏洞版本对应**：维护「框架-版本-CVE-Payload」对照表，遇到 Spring/Struts/Shiro 目标可快速定位可用 EXP。

---

## 参考资料与原文链接

- **原文归档**：[2021-鹤城杯-WEB+Misc部分 WriteUp (微信公众号)](http://mp.weixin.qq.com/s?__biz=MzkyNzE3NjM1Mw==&mid=2247483827&idx=1&sn=feecf16b7a5b92b822a17122b4617701&chksm=c22d427df55acb6b15d1ee2b65342ef4b77f18c904f041dd7b46065fb5641d93cad10549de85&scene=126&sessionid=1681668098#rd)
- **CVE-2017-4971 详细分析**：[Spring Web Flow框架远程代码执行(CVE-2017-4971) - 掘金](https://juejin.cn/post/7006672559714336805)
- **Gopherus 工具**：https://github.com/tarunkant/Gopherus
- **MySQL 8.0 TABLE 语句官方文档**：https://dev.mysql.com/doc/refman/8.0/en/table.html

---

> 本页面基于微信公众号归档文章整理，旨在沉淀 CTF 实战技术细节，构建可检索、可关联的知识库。如有遗漏或错误，欢迎补充修正。

## 来源

- [0xfafu攻防实验室-202010-202112_09](../sources/0xfafu攻防实验室-202010-202112_09.md)
