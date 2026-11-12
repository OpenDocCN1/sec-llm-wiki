---
title: Java 反序列化基础机制
description: 系统梳理 Java 序列化/反序列化核心机制：Serializable 与 Externalizable 接口对比、serialVersionUID
  版本控制、ObjectOutputStream/ObjectInputStream 标准用法，为后续反序列化漏洞利用链分析奠定基础。
category: ai-security
tags:
- Java
- 序列化
- 反序列化
- Serializable
- Externalizable
- serialVersionUID
- ObjectOutputStream
- ObjectInputStream
- 基础机制
date: 2025-08-20
updated: '2026-11-12'
---

## 核心概念

### 什么是 Java 序列化与反序列化

- **序列化**：将 Java 对象转换为字节序列的过程。
- **反序列化**：将字节序列恢复为 Java 对象的过程。

### 为什么需要序列化

1. **对象持久化存储**  
   以面向对象方式将数据存储到磁盘文件。典型场景：Web 容器在并发量大时将 Session 对象序列化到硬盘，需要时再反序列化回内存。

2. **网络传输对象**  
   进程间远程通信时，发送方将 Java 对象转为字节序列在网络传输，接收方反序列化还原为对象。实现了进程通信间的对象传送。

## 实现序列化的两个接口

### `Serializable` 接口（标记接口）

- **定义**：`java.io.Serializable` 无任何方法或字段，仅用于标识“可序列化”语义。
- **机制**：实现该接口的类，其所有属性（含 `private`、引用对象）均会被自动序列化/反序列化。
- **排除字段**：使用 `transient` 修饰不想序列化的字段。
- **JVM 负责**完整的读写过程，开发者无需编写序列化逻辑。

### `Externalizable` 接口（完全控制）

- **继承关系**：`Externalizable extends Serializable`
- **必须实现的两个方法**：
  - `writeExternal(ObjectOutput out)` —— 自定义序列化逻辑
  - `readExternal(ObjectInput in)` —— 自定义反序列化逻辑
- **特点**：开发者完全控制序列化哪些属性，**`transient` 修饰符在此失效**。

## 版本控制：`serialVersionUID`

### 作用
反序列化时，JVM 会比对字节流中的 `serialVersionUID` 与当前类定义的值：
- **一致** → 反序列化成功
- **不一致** → 抛出 `InvalidClassException`，反序列化失败

### 定义方式
```java
public class User implements Serializable {
    private static final long serialVersionUID = 34324232342342L;
}
```

### 自动生成规则
若未显式声明，JVM 根据以下要素自动计算：
- 类名
- 类及其属性修饰符
- 实现的接口及顺序
- 成员变量
- 静态初始化块
- 构造器

**任一要素变更会导致 `serialVersionUID` 变化**，建议显式声明以保证跨版本兼容。

## 核心流类与关键方法

| 类 | 关键方法 | 说明 | 常见异常 |
|---|---|---|---|
| `ObjectOutputStream` | `writeObject(Object obj)` | 将可序列化对象写入输出流 | `NotSerializableException`（对象未实现 Serializable）<br>`InvalidClassException`（类定义有问题）<br>`IOException`（I/O 错误） |
| `ObjectInputStream` | `readObject()` | 从输入流读取并重构对象 | `ClassNotFoundException`（找不到类）<br>`InvalidClassException`<br>`IOException` |

> `NotSerializableException` 与 `InvalidClassException` 均为 `IOException` 子类。

## 完整示例：Person 对象序列化/反序列化

### 实体类
```java
import java.io.Serializable;

public class Person implements Serializable {
    private static final long serialVersionUID = 8241970228716425282L;
    private String name;

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    @Override
    public String toString() { return "Person [name=" + name + "]"; }
}
```

### 序列化写入文件
```java
import java.io.*;

public class SerializeDemo {
    public static void writeObj(Person p) {
        try (ObjectOutputStream oos = new ObjectOutputStream(
                new FileOutputStream("/tmp/a.txt"))) {
            oos.writeObject(p);
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}
```

### 反序列化读取文件
```java
public static Person readObj() {
    Person p = null;
    try (ObjectInputStream ois = new ObjectInputStream(
            new FileInputStream("/tmp/a.txt"))) {
        p = (Person) ois.readObject();
    } catch (IOException | ClassNotFoundException e) {
        e.printStackTrace();
    }
    return p;
}
```

### 运行结果
- 序列化产出二进制文件（含类元数据、serialVersionUID、字段值）
- 反序列化输出：`Person [name=shadowtest]`

## 两种接口对比速查

| 维度 | `Serializable` | `Externalizable` |
|---|---|---|
| 接口类型 | 标记接口（无方法） | 含两个抽象方法 |
| 序列化控制 | JVM 自动完成，`transient` 排除字段 | 完全由开发者手工实现，`transient` 无效 |
| 适用场景 | 绝大多数通用场景 | 需要精细控制格式、兼容旧版本、加密敏感字段等 |
| 性能 | 稍低（反射 + 元数据） | 可优化，但开发成本高 |

## 后续扩展方向

掌握上述基础后，可进一步研究：
- **反序列化漏洞成因**：`readObject()` 无安全校验、魔术方法（`readResolve`、`readObjectNoData` 等）被利用
- **常见利用链**：CommonsCollections、Spring、JDK 内部链等
- **防御手段**：`ObjectInputFilter`（JDK 9+）、RASP、禁用不必要的反序列化入口

相关实战利用链可参考：
- [[spring-boot-actuator配置不当rce利用]] 中的 XStream 反序列化 RCE
- [[h2-console-jndi注入rce利用]] 中结合 JNDI 的反序列化攻击面

## 参考资料
- [Java 序列化详解](https://www.cnblogs.com/niceyoo/p/10596657.html)
- [Java 反序列化漏洞学习](https://www.hetianlab.com/expc.do?ce=efa15bbe-8aab-4167-8d7b-6faac421de48)
- [CSDN: Java序列化与反序列化](https://blog.csdn.net/qq_39390545/article/details/105104824)
- [知乎: Java序列化原理](https://www.zhihu.com/question/47794528)
- [博客园: 深入理解Java序列化](https://www.cnblogs.com/feiqiangsheng/p/11077355.html)

## 来源

- [007攻防实验室-202007-202010_8](../sources/007攻防实验室-202007-202010_8.md)
