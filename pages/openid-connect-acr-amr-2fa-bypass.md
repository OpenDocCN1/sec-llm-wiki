---
title: OpenID Connect acr_values 参数配置错误导致 2FA 绕过漏洞分析
description: 深度分析 OpenID Connect 协议中 acr_values 参数配置不当导致的双因子认证绕过漏洞，通过篡改认证方式从 OTP 降级至
  SMS 实现认证绕过，涉及 RFC 8176 AMR 标准、JWT amr 声明验证缺失等核心技术点。
category: program-analysis
tags:
- OpenID Connect
- OIDC
- acr_values
- amr
- 2FA绕过
- RFC 8176
- JWT
- 认证降级
- 身份提供者
- 安全配置错误
date: '2023-04-13'
updated: '2026-11-15'
---

## 漏洞概述

本文分析一个真实案例：目标企业拥有 50+ 全球品牌，统一使用 OpenID Connect (OIDC) 系统进行身份认证。某新纳入测试范围的品牌站点强制启用 Google Authenticator (OTP) 作为二因子认证 (2FA)，但通过篡改授权请求中的 `acr_values` 参数，将认证方式从 `otp+password` 切换为 `sms+password`，成功绕过 OTP 验证并完成登录。根因在于客户端站点虽启用了 OTP 和 SMS 双通道，但未在 UI 暴露 SMS 选项，且身份提供者 (IdP) 未校验请求的 `acr_values` 与该客户端实际允许的认证方式是否一致。

## 技术背景

### OpenID Connect 认证流程与 `acr_values`

OpenID Connect 在 OAuth 2.0 授权请求基础上引入 `acr_values` (Authentication Context Class Reference Values) 参数，允许依赖方 请求特定认证等级或方式。IdP 完成认证后，在返回的 ID Token (JWT) 中包含 `amr` (Authentication Methods References) 声明，标识实际使用的认证方法。

典型授权请求示例：

```http
GET /authorize?
  response_type=code
  &client_id=xxx
  &redirect_uri=https%3A%2F%2Fclient.example.com%2Fcallback
  &scope=openid%20profile
  &acr_values=otp+password
  &state=123456789
```

### RFC 8176 定义的 AMR 值

RFC 8176 标准化了 22 种认证方法标识符，常见值包括：

| AMR 值 | 含义 |
|--------|------|
| `pwd` | 密码认证 |
| `otp` | 一次性密码 (TOTP/HOTP) |
| `sms` | 短信验证码 |
| `mfa` | 多因子认证 (通用) |
| `swk` | 软件密钥 (如私钥) |
| `hwk` | 硬件密钥 (如 YubiKey) |
| `biometric` | 生物识别 |

> **安全提示**：RFC 8176 第 5 节明确警告：依赖特定认证方式的系统可能因认证方式随时间演变而变得脆弱，配置应确保仅接受受信任且经过验证的认证方式。

## 漏洞复现流程

### 发现异常参数

在登录请求中观察到 `acr_values=otp+password` 参数，这并非标准 OIDC 必选参数，推测为自定义配置。

### 尝试移除/篡改参数

- 移除 `acr_values` → 重定向至 IdP 登录页，但凭据正确仍返回 401
- 仅保留 `password` → 同 401 错误
- 说明 IdP 强制校验 `acr_values` 并要求满足指定认证等级

### 枚举 RFC 8176 定义的 AMR 值

尝试替换为其他标准值：`sms+password`、`mfa+password` 等。

### 成功绕过

将 `acr_values` 修改为 `sms+password` 后：

1. 正常跳转 IdP 登录页
2. 输入用户名/密码通过首因子认证
3. IdP 提示发送短信验证码而非 Google Authenticator
4. 使用一次性短信接码服务接收验证码
5. 完成二因子认证，成功登录目标站点

### 验证 JWT 中的 `amr` 声明

登录后解码 ID Token，Payload 包含：

```json
{
  "state": "123456789",
  "auth_time": 1234,
  "amr": ["pwd", "sms"],
  ...
}
```

确认 IdP 确实按请求执行了 SMS 认证，且客户端未校验 `amr` 是否符合预期 (应为 `["pwd", "otp"]`)。

## 根因分析

| 缺陷层面 | 具体表现 |
|----------|----------|
| **客户端配置错误** | 同时在 IdP 注册启用 OTP 和 SMS 两种 2FA 方式，但前端 UI 仅提供 OTP 入口，未禁用 SMS 通道 |
| **IdP 授权策略缺失** | 未将 `client_id` 与允许的 `acr_values` 绑定，任由客户端请求任意标准认证方式 |
| **客户端回调校验缺失** | 未验证 ID Token 中 `amr` 声明是否包含预期的 `otp`，盲目信任 IdP 返回结果 |
| **认证方式生命周期管理缺失** | 违反 RFC 8176 第 5 节建议：未限制仅接受受信任、经过验证的认证方式 |

## 修复建议

### 客户端侧

1. **显式声明支持的认证方式**：在 IdP 注册时仅启用业务真正需要的 2FA 方式，禁用未使用的通道
2. **校验 ID Token `amr` 声明**：回调处理逻辑中强制校验 `amr` 包含预期值 (如 `otp`)，拒绝 `sms` 等非预期方式
3. **固定 `acr_values` 值**：前端/后端硬编码授权请求参数，避免动态拼接或用户可控输入

### 身份提供者 (IdP) 侧

1. **客户端-认证方式绑定**：为每个 `client_id` 维护允许的 `acr_values` 白名单，拒绝请求非白名单方式
2. **最小权限原则**：默认仅允许客户端显式配置的认证方式，禁止回退至其他方式
3. **审计与告警**：记录 `acr_values` 请求值与实际执行 `amr` 的差异，异常时触发告警

### 架构层面

- 采用 **FAPI (Financial-grade API) 规范** 中的 `acr` 必选值机制，强制客户端声明所需认证等级
- 引入 **认证上下文类引用 (ACR) 映射表**，将业务认证等级 (如 `level-2fa-otp`) 映射至具体 AMR 组合，避免直接暴露底层 AMR 值

## 相关标准与参考

- [RFC 8176 - Authentication Method Reference Values](https://datatracker.ietf.org/doc/html/rfc8176)
- [OpenID Connect Core 1.0 - acr_values 参数定义](https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest)
- [FAPI 2.0 - 认证上下文要求](https://openid.net/specs/openid-financial-api-part-2-1_0.html)

## 交叉引用

- [[jwt漏洞原理与实战利用]] — JWT 结构解析、amr 声明验证缺失导致的垂直越权、算法混淆等漏洞场景，本文涉及的 ID Token `amr` 校验缺失属于同类 JWT 信任滥用问题
- [[oauth2-openid-connect-security]] — OAuth 2.0 与 OpenID Connect 核心安全模型、授权码流程、PKCE、客户端认证等基础知识，为理解 `acr_values` 在授权请求中的位置提供协议层面背景
- [[ssrf-bypass-techniques]] — 认证绕过后常结合 SSRF 向内网探测，本案例中成功登录后可进一步利用 SSRF 扩大攻击面
- [[xd-security-logic-vulnerability-notes-day33-36]] — 逻辑漏洞分类中「认证方式降级/绕过」属于典型垂直越权变种，可参考其中 IDOR、多阶段绕过检测思路

## 总结

该漏洞本质是 **OpenID Connect 协议层面的配置信任滥用**：客户端过度信任 IdP 会「正确」执行请求的认证方式，IdP 过度信任客户端请求的 `acr_values` 合法性，双方均未落实 RFC 8176 要求的「仅接受受信任认证方式」原则。修复核心在于 **双向绑定与校验**——客户端侧限制请求值并校验响应值，IdP 侧限制执行值并审计异常请求。此类漏洞在多租户、多品牌统一身份系统中尤为高发，建议纳入 OAuth/OIDC 安全配置审计清单重点排查。

## 来源

- [0x6270安全团队-202203-202304_47](../sources/0x6270安全团队-202203-202304_47.md)
