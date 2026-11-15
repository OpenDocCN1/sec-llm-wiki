---
title: Python SSRF漏洞防御实战：基于requests库hooks机制的完整防护实现
description: 深度解析SSRF漏洞核心绕过场景（内网IP识别、DNS重绑定、302跳转劫持），基于Python requests库hooks机制构建生产级防御方案，覆盖IP地址整数化判断、域名解析验证、重定向链路全程拦截等关键技术点。
category: program-analysis
tags:
- Python
- SSRF
- requests
- hooks
- 安全开发
- 漏洞防御
- 内网IP识别
- DNS重绑定
- 302跳转
- Web安全
date: 2024-01-15
updated: '2026-11-16'
---

## 概述

SSRF（Server-Side Request Forgery，服务端请求伪造）是Web应用中常见的高危漏洞类型。当后端代码直接请求用户可控的URL且未进行有效验证时，攻击者可利用该漏洞探测内网拓扑、攻击内网服务（如Redis、FastCGI）、读取本地文件等。

本文基于「301在路上」微信公众号归档文章，系统梳理SSRF漏洞的四大核心绕过场景，并提供基于Python `requests` 库 `hooks` 机制的完整防御实现方案，适用于生产环境集成。

## 核心绕过场景分析

### 内网IP地址识别绕过

#### 常见内网IP段

| CIDR表示法 | 范围 | 备注 |
|------------|------|------|
| 10.0.0.0/8 | 10.0.0.0 ~ 10.255.255.255 | A类私有地址 |
| 172.16.0.0/12 | 172.16.0.0 ~ 172.31.255.255 | B类私有地址 |
| 192.168.0.0/16 | 192.168.0.0 ~ 192.168.255.255 | C类私有地址 |
| 127.0.0.0/8 | 127.0.0.0 ~ 127.255.255.255 | 回环地址，**常被忽略** |

> **关键点**：`127.0.0.1` 仅是回环地址的一个，整个 `127.0.0.0/8` 均指向本地。访问 `http://127.233.233.233/` 等同于访问 `127.0.0.1`。

#### 失效的防御方式：正则匹配

早期版本 Sec-News 使用正则判断内网IP，存在四类绕过：

1. **八进制IP**：`012.0.0.1` → `10.0.0.1`
2. **十六进制IP**：`0xa.0.0.1` → `10.0.0.1`
3. **十进制整数IP**：`167772161` → `10.0.0.1`
4. **省略写法**：`10.1` → `10.0.0.1`、`0xA000001` → `10.0.0.1`

这些变体均能绕过正则匹配，直达内网服务。

#### WordPress 方案及其局限

WordPress 采用分割数组判断 `parts[0]` 与 `parts[1]`，但曾出现进制绕过案例（[[WordPress <4.5 SSRF 分析]]），不推荐在新项目中沿用。

#### 推荐方案：IP整数化 + 位运算判断

IPv4 地址与 `0 ~ 2^32-1` 的整数一一对应。将 IP 与网段起始地址均转为整数，通过**掩码位右移**比较前缀是否相等。

```python
from socket import inet_aton
from struct import unpack

def ip2long(ip_addr: str) -> int:
    """IPv4 地址转无符号长整型（网络字节序）"""
    return unpack("!L", inet_aton(ip_addr))[0]

def is_inner_ipaddress(ip: str) -> bool:
    """判断是否为内网/回环 IP"""
    ip_long = ip2long(ip)
    return (
        (ip2long('127.0.0.0') >> 24 == ip_long >> 24) or   # 127.0.0.0/8
        (ip2long('10.0.0.0')   >> 24 == ip_long >> 24) or   # 10.0.0.0/8
        (ip2long('172.16.0.0') >> 20 == ip_long >> 20) or   # 172.16.0.0/12
        (ip2long('192.168.0.0') >> 16 == ip_long >> 16)     # 192.168.0.0/16
    )
```

> **优势**：无正则遗漏、无进制绕过、性能极高、逻辑清晰。

---

### Host 获取与 DNS 重绑定绕过

#### 正确解析 URL Host

必须使用标准库 `urllib.parse.urlparse`，禁止手写正则：

```python
from urllib.parse import urlparse

hostname = urlparse(url).hostname
```

#### 域名形式绕过：DNS 重绑定

攻击者可控域名解析到内网 IP。典型案例：`xip.io` 服务

- `127.0.0.1.xip.io` → 解析至 `127.0.0.1`
- `www.10.0.0.1.xip.io` → 解析至 `10.0.0.1`

**防御措施**：必须将 Hostname 解析为 IP 再判断。

```python
import socket

ip_address = socket.getaddrinfo(hostname, 'http')[0][4][0]
if is_inner_ipaddress(ip_address):
    raise Exception("Inner IP address attack")
```

> **关联阅读**：[[ssrf-bypass-techniques]] 中详细记录了 DNS 重绑定、Gopher 协议利用、FastCGI/Redis 攻击链等进阶绕过手法。

---

### 跳转劫持绕过

#### 根因

`requests` 默认 `allow_redirects=True`，自动跟随 30X 跳转。若跳转目标为内网地址，前置检查失效。

```python
# 默认行为：自动跳转
requests.get('http://t.cn/R2iwH6d')  # 302 → 内网地址
```

#### 两种解决思路对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| `allow_redirects=False` | 简单 | 破坏合法业务跳转（如 OAuth、短链接） |
| **全链路检查每一跳 Host** | 兼容业务 | 需处理相对路径、跳转缓存、最大跳转数等细节 |

---

## 完整防御实现：基于 requests hooks 机制

### hooks 机制原理

`requests` 内部通过 `dispatch_hook('response', hooks, response)` 在**每次响应返回时**调用注册的回调函数。即使开启 `allow_redirects=True`，每次跳转产生的中间响应也会触发 hook。

```python
# requests 源码片段
def dispatch_hook(key, hooks, hook_data, **kwargs):
    hooks = hooks or {}
    hooks = hooks.get(key)
    if hooks:
        if hasattr(hooks, '__call__'):
            hooks = [hooks]
        for hook in hooks:
            _hook_data = hook(hook_data, **kwargs)
            if _hook_data is not None:
                hook_data = _hook_data
    return hook_data
```

### 核心 Hook 函数设计

```python
def _request_check_location(r, *args, **kwargs):
    """响应 hook：拦截每一次 30X 跳转，检查 Location 头"""
    if not r.is_redirect:
        return
    
    url = r.headers['location']
    
    # 规范化 URL（处理相对路径、大小写、百分号编码）
    from urllib.parse import urlparse, urljoin
    from requests.utils import requote_uri
    
    parsed = urlparse(url)
    url = parsed.geturl()  # scheme 统一小写
    
    if not parsed.netloc:
        # 相对路径：基于当前响应 URL 拼接
        url = urljoin(r.url, requote_uri(url))
    else:
        url = requote_uri(url)
    
    # 核心检查
    succ, errstr = check_ssrf(url)
    if not succ:
        raise requests.exceptions.InvalidURL(f"SSRF Attack: {errstr}")
```

### 安全请求封装函数

```python
import requests
import re
import socket
from urllib.parse import urlparse
from socket import inet_aton
from struct import unpack
from requests.utils import requote_uri
from urllib.parse import urljoin

def check_ssrf(url: str) -> tuple[bool, str]:
    """统一 SSRF 检查入口：协议限制 + Host 解析 + 内网 IP 判断"""
    hostname = urlparse(url).hostname
    if not hostname:
        return False, "invalid hostname"
    
    def ip2long(ip_addr: str) -> int:
        return unpack("!L", inet_aton(ip_addr))[0]
    
    def is_inner(ip: str) -> bool:
        ip_long = ip2long(ip)
        return (
            (ip2long('127.0.0.0') >> 24 == ip_long >> 24) or
            (ip2long('10.0.0.0')   >> 24 == ip_long >> 24) or
            (ip2long('172.16.0.0') >> 20 == ip_long >> 20) or
            (ip2long('192.168.0.0') >> 16 == ip_long >> 16)
        )
    
    try:
        # 仅允许 HTTP/HTTPS
        if not re.match(r"^https?://.*/.*$", url):
            raise ValueError("url format error: only http/https allowed")
        
        # 域名解析
        ip_address = socket.getaddrinfo(hostname, 'http')[0][4][0]
        if is_inner(ip_address):
            raise ValueError("inner ip address attack")
        
        return True, "success"
    except ValueError as e:
        return False, str(e)
    except Exception:
        return False, "unknown error"


def safe_request_url(url: str, **kwargs) -> requests.Response:
    """
    生产级安全请求函数
    - 参数与 requests.get 完全兼容
    - 自动注入 SSRF 检查 hook
    - 保留用户自定义 hooks
    """
    # 1. 首次请求前检查
    success, errstr = check_ssrf(url)
    if not success:
        raise requests.exceptions.InvalidURL(f"SSRF Attack: {errstr}")
    
    # 2. 合并用户自定义 hooks 与安全 hook
    all_hooks = kwargs.get('hooks', {})
    r_hooks = all_hooks.get('response', [])
    
    if hasattr(r_hooks, '__call__'):
        r_hooks = [r_hooks]
    
    r_hooks.append(_request_check_location)
    all_hooks['response'] = r_hooks
    kwargs['hooks'] = all_hooks
    
    # 3. 发起请求（allow_redirects 默认 True，受 hook 保护）
    return requests.get(url, **kwargs)
```

### 使用示例

```python
# 业务代码仅需替换 requests.get → safe_request_url
try:
    resp = safe_request_url(
        "http://example.com/api",
        timeout=10,
        headers={"User-Agent": "MyApp/1.0"}
    )
    print(resp.status_code, resp.text[:200])
except requests.exceptions.InvalidURL as e:
    logger.warning(f"SSRF 拦截: {e}")
    # 返回友好错误页面
except requests.RequestException as e:
    logger.error(f"请求异常: {e}")
```

---

## 关键技术点总结

| 防御层面 | 关键措施 | 代码实现位置 |
|----------|----------|--------------|
| **协议限制** | 仅允许 `http/https`，禁止 `file/gopher/dict` 等 | `check_ssrf()` 正则校验 |
| **Host 解析** | `urlparse().hostname` 标准库解析，避免 `@` `#` 绕过 | `check_ssrf()` 首行 |
| **DNS 重绑定** | `socket.getaddrinfo()` 解析域名 → IP 再判断 | `check_ssrf()` 中段 |
| **内网 IP 判断** | 整数化 + 掩码位右移，覆盖 4 大私有/回环段 | `is_inner_ipaddress()` |
| **302 跳转链** | `hooks={'response': _request_check_location}` 全链路拦截 | `safe_request_url()` 注入 |
| **相对路径跳转** | `urljoin(r.url, requote_uri(location))` 规范化 | `_request_check_location()` |
| **兼容性** | 保留用户自定义 hooks，不破坏扩展性 | `safe_request_url()` 合并逻辑 |

---

## 扩展与最佳实践

### 生产环境加固建议

1. **超时控制**：强制设置 `timeout=(connect, read)`，防止挂起
2. **证书验证**：内网 HTTPS 服务建议配置 `verify=CA_BUNDLE_PATH`，避免 `verify=False`
3. **请求频率限制**：同一用户/同一目标域名的请求频率限流
4. **审计日志**：记录被拦截的 SSRF 尝试（URL、IP、用户 ID、时间），便于事后分析
5. **IPv6 支持**：扩展 `is_inner_ipaddress` 覆盖 `::1/128`、`fc00::/7` (ULA) 等 IPv6 私有段

### 与其他语言/框架对比

| 语言/框架 | 典型防御方案 | 关键机制 |
|-----------|--------------|----------|
| **Java** | `HttpClient` + `RequestInterceptor` / `HttpClientContext` | 拦截器链 |
| **Go** | 自定义 `http.Client.CheckRedirect` + `DialContext` | 重定向回调 + 自定义拨号 |
| **Node.js** | `axios` / `got` + `beforeRedirect` hook | 重定向前置钩子 |
| **PHP** | `curl_setopt(CURLOPT_FOLLOWLOCATION, false)` + 手动跟随 | 禁用自动跳转 + 手动循环 |

> 核心思想一致：**解析 → 解析域名 → 判断内网 → 请求 → 每跳重复**。

---

## 相关知识页面交叉引用

- [[ssrf-bypass-techniques]] — SSRF 绕过技术全景（Gopher、FastCGI、Redis、DNS 重绑定、文件协议等）
- [[ssrf-ctf-exploitation-guide]] — CTF 实战视角的 SSRF 利用（`file_get_contents` vs `curl` 协议差异、伪协议利用）
- [[xd-security-csrf-ssrf-rce-notes-day29-30]] — XD安全课程 SSRF 章节（Pikachu 靶场、Webmin CVE-2019-15107、Struts2、HFS 经典案例）
- [[gkctf-2021-web-writeup]] — GKCTF 2021 CheckBot 题目（SSRF + XSS 窃取 Flag）
- [[hec-cup-2021-web-misc-writeup]] — 2021 鹤城杯 easy_sql_1（Gopher 协议攻击内网 MySQL + Cookie 位注入）
- [[python-pickle-deserialization-rce]] — Python 反序列化 RCE，常与 SSRF 组合利用
- [[cicv-2022-crypto-forensics-writeup]] — 车联网安全赛题中的 SSRF 相关技术点

---

## 参考资料

- 原文：[如何在Python开发中拒绝SSRF漏洞？](http://mp.weixin.qq.com/s?__biz=MzIwMTQ2NzY4NA==&mid=2652521309&idx=1&sn=7b21619e42eca7d40af6139eaedf784d) — 301在路上
- Requests 官方文档：[Event Hooks](http://docs.python-requests.org/en/master/user/advanced/?highlight=hook#event-hooks)
- RFC 7231：HTTP/1.1 语义与内容（重定向相对路径规范）
- RFC 3986：URI 通用语法（百分号编码规范）

## 来源

- [301在路上-201508-202208_042](../sources/301在路上-201508-202208_042.md)
