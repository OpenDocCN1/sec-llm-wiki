---
title: MFC 序列化/反序列化核心机制深度解析
description: 系统梳理 MFC 序列化机制：DECLARE_SERIAL 与 IMPLEMENT_SERIAL 宏展开、CRuntimeClass 运行时类结构、版本号存储与获取、CArchive
  友元操作符重载及手动版本写入方案
category: program-analysis
tags:
- MFC
- Serialization
- C++
- CRuntimeClass
- DECLARE_SERIAL
- IMPLEMENT_SERIAL
- CArchive
- Reverse Engineering
- Binary Analysis
date: '2023-04-16'
updated: '2026-11-14'
---

## 概述

MFC 序列化是将类对象的数据成员按照特定规则转换为二进制流以便存储或传输的过程，反序列化则是逆向操作。要使一个类支持序列化，必须满足以下四个核心条件：

1.  **继承自 `CObject`**：可序列化对象必须是 `CObject` 的子类。
2.  **类内声明 `DECLARE_SERIAL` 宏**：且类中必须存在无参构造函数。
3.  **重写 `Serialize(CArchive& ar)` 虚函数**：编写针对当前类数据成员的具体序列化/反序列化逻辑。
4.  **类外声明 `IMPLEMENT_SERIAL` 宏**：关联基类并指定序列化版本号（Schema）。

典型代码范例：

```cpp
class CMyLine : public CObject
{
public:
    DECLARE_SERIAL(CMyLine)
    CPoint m_ptFrom;
    CPoint m_ptTo;
public:
    CMyLine() {}  // 必须的无参构造
    CMyLine(CPoint from, CPoint to) : m_ptFrom(from), m_ptTo(to) {}
    virtual void Serialize(CArchive& ar);
};

IMPLEMENT_SERIAL(CMyLine, CObject, 1)  // 版本号为 1

void CMyLine::Serialize(CArchive& ar)
{
    if (ar.IsStoring())
        ar << m_ptFrom << m_ptTo;
    else
        ar >> m_ptFrom >> m_ptTo;
}
```

该机制与 MFC 消息映射机制在宏设计模式上高度相似，详见 [[mfc-message-map-internals-reverse-engineering]]。

---

## 宏展开与核心结构分析

### DECLARE_SERIAL 宏展开

```cpp
#define DECLARE_SERIAL(class_name) \
    _DECLARE_DYNCREATE(class_name) \
    AFX_API friend CArchive& AFXAPI operator>>(CArchive& ar, class_name* &pOb);
```

展开后在类中声明以下关键成员：

```cpp
protected:
    static CRuntimeClass* PASCAL _GetBaseClass(); // 官方未文档化
public:
    static CRuntimeClass class##class_name;       // 运行时类对象实例
    static CRuntimeClass* PASCAL GetThisClass();  // 官方未文档化，可能用于初始化
    virtual CRuntimeClass* GetRuntimeClass() const; // 返回当前对象的 CRuntimeClass
    static CObject* PASCAL CreateObject();        // 动态创建对象，声明在另一宏中
    AFX_API friend CArchive& AFXAPI operator>>(CArchive& ar, class_name* &pOb); // 反序列化友元函数
```

### CRuntimeClass 结构体详解

`CRuntimeClass` 是 MFC 运行时类型信息（RTTI）的核心，序列化机制完全围绕该结构展开。

```cpp
struct CRuntimeClass
{
    // 属性
    LPCSTR      m_lpszClassName;                    // 类名
    int         m_nObjectSize;                      // 对象大小（字节）
    UINT        m_wSchema;                          // 架构编号（版本号），-1 表示不可序列化
    CObject*    (PASCAL* m_pfnCreateObject)();      // 动态创建函数指针（指向无参构造）
#ifdef _AFXDLL
    CRuntimeClass* (PASCAL* m_pfnGetBaseClass)();   // DLL 模式：获取基类 CRuntimeClass 的函数指针
#else
    CRuntimeClass* m_pBaseClass;                    // 静态链接模式：基类 CRuntimeClass 指针
#endif

    // 成员函数
    CObject* CreateObject();                        // 运行时创建对象
    BOOL IsDerivedFrom(const CRuntimeClass* pBaseClass) const; // 判断继承关系
    static CRuntimeClass* PASCAL FromName(LPCSTR lpszClassName); // 通过类名查找
    static CObject* PASCAL CreateObject(LPCSTR lpszClassName);   // 通过类名动态创建
    void Store(CArchive& ar) const;                 // 将 CRuntimeClass 自身序列化到归档
    static CRuntimeClass* PASCAL Load(CArchive& ar, UINT* pwSchemaNum); // 从归档加载 CRuntimeClass

    // 链表管理
    CRuntimeClass* m_pNextClass;                    // 已注册类链表
    const AFX_CLASSINIT* m_pClassInit;
};
```

关键字段含义：
- `m_wSchema`：序列化版本号，由 `IMPLEMENT_SERIAL` 第三个参数指定。
- `m_pfnCreateObject`：指向 `class_name::CreateObject`，内部 `return new class_name`，依赖无参构造。
- `m_pBaseClass` / `m_pfnGetBaseClass`：构建继承链，供 `IsDerivedFrom` 遍历使用。

### IMPLEMENT_SERIAL 宏展开

```cpp
#define IMPLEMENT_SERIAL(class_name, base_class_name, wSchema) \
    CObject* PASCAL class_name::CreateObject() \
        { return new class_name; } \
    extern AFX_CLASSINIT _init_##class_name; \
    _IMPLEMENT_RUNTIMECLASS(class_name, base_class_name, wSchema, \
        class_name::CreateObject, &_init_##class_name) \
    AFX_CLASSINIT _init_##class_name(RUNTIME_CLASS(class_name)); \
    CArchive& AFXAPI operator>>(CArchive& ar, class_name* &pOb) \
        { pOb = (class_name*) ar.ReadObject(RUNTIME_CLASS(class_name)); \
          return ar; }
```

展开后完成三件事：
1.  定义 `CreateObject` 静态函数，实现动态创建。
2.  通过 `_IMPLEMENT_RUNTIMECLASS` 初始化 `class##class_name` 静态实例，填充类名、对象大小、**版本号**、创建函数指针、基类关联。
3.  定义全局 `operator>>` 友元函数，调用 `CArchive::ReadObject` 完成反序列化时的对象构造与数据填充。

---

## 序列化版本机制与兼容性处理

### 版本号的作用

`IMPLEMENT_SERIAL` 的第三个参数 `wSchema` 写入 `CRuntimeClass::m_wSchema`。当类结构发生变化（增减成员）时，通过修改版本号实现向前/向后兼容。

### 两种兼容性处理策略

| 策略 | 适用场景 | 实现要点 |
|------|----------|----------|
| **派生新类重写 Serialize** | 旧版本数据不再维护，全新业务逻辑 | 新类继承旧类，重写 `Serialize`，版本号从 1 重新开始 |
| **同一类内按版本分支** | 需要读取旧版本归档文件 | 在 `Serialize` 中通过 `ar.GetObjectSchema()` 获取版本，配合 `if/else` 或 `switch` 分支处理 |

示例：版本分支处理

```cpp
void CMyLine::Serialize(CArchive& ar)
{
    if (ar.IsStoring()) {
        ar << m_ptFrom << m_ptTo;
    } else {
        UINT nSchema = ar.GetObjectSchema(); // 获取归档中存储的版本号
        if (nSchema == 1) {
            ar >> m_ptFrom >> m_ptTo;
        } else if (nSchema == 2) {
            ar >> m_ptFrom >> m_ptTo >> m_newMember; // 新增成员
        }
    }
}
```

---

## 版本号存储与获取的关键细节

### 问题：直接调用 `Serialize` 不写入版本号

若直接调用对象的 `Serialize` 方法：

```cpp
CFile file("1.txt", CFile::modeCreate | CFile::modeWrite);
CArchive ar(&file, CArchive::store);
CMyLine line(CPoint(0,0), CPoint(1,2));
line.Serialize(ar); // 仅序列化成员数据，不写入版本号/类信息
ar.Close();
```

生成的文件**仅包含成员二进制数据**，无 `CRuntimeClass` 信息、无版本号。随后反序列化时调用 `ar.GetObjectSchema()` 将报错或返回不可预期值。

### 解决方案一：使用 `CArchive` 友元 `operator<<` / `operator>>`（推荐）

```cpp
CFile file("1.txt", CFile::modeCreate | CFile::modeWrite);
CArchive ar(&file, CArchive::store);
CMyLine line(CPoint(0,0), CPoint(1,2));
ar << &line; // 调用全局 operator<<，内部写入类信息+版本号+成员数据
ar.Close();
file.Close();
```

该操作符重载（由 `IMPLEMENT_SERIAL` 宏生成）内部流程：
1.  调用 `CRuntimeClass::Store` 将类名、版本号等元数据写入归档。
2.  调用对象的 `Serialize` 写入成员数据。

反序列化对应：

```cpp
CFile file("1.txt", CFile::modeRead);
CArchive ar(&file, CArchive::load);
CMyLine* pLine = nullptr;
ar >> pLine; // 调用全局 operator>>，内部 ReadObject -> CreateObject -> Serialize
```

`ReadObject` 会读取归档中的类名与版本号，通过 `RUNTIME_CLASS` 核对类名，将版本号存入 `CArchive` 内部供 `GetObjectSchema()` 读取，再动态创建对象并调用其 `Serialize`。

### 解决方案二：手动写入版本号（不推荐，易出错）

若坚持调用 `Serialize`，需手动管理版本号写入/读取，需深知 `CArchive` 内部存储格式，维护成本极高。

---

## 逆向分析视角的关键点

1.  **识别可序列化类**：搜索 `IMPLEMENT_SERIAL` 字符串或 `CRuntimeClass` 结构实例，确认 `m_wSchema` 值。
2.  **定位 `Serialize` 函数**：通过 vtable 或 `CRuntimeClass` 关联的类名，找到虚函数表中的 `Serialize` 入口。
3.  **版本分支还原**：在 `Serialize` 中寻找 `GetObjectSchema` 调用（通常表现为从 `CArchive` 偏移读取 `m_nSchema` 字段），配合条件跳转还原各版本数据布局。
4.  **动态创建回调**：`m_pfnCreateObject` 指向的函数即为无参构造封装，可用于模拟对象构造。
5.  **类名字符串**：`m_lpszClassName` 以明文存储在二进制中，便于快速定位。

---

## 总结

- MFC 序列化采用 **宏声明+运行时类结构** 双层设计，`DECLARE_SERIAL`/`IMPLEMENT_SERIAL` 成对使用，类似消息映射的 `DECLARE_MESSAGE_MAP`/`BEGIN_MESSAGE_MAP`，详见 [[mfc-message-map-internals-reverse-engineering]]。
- `CRuntimeClass` 是核心枢纽，承载类名、大小、**版本号**、创建函数、基类链。
- **版本号仅在通过 `CArchive::operator<<` 序列化指针时自动写入**；直接调用 `Serialize` 会丢失版本信息，导致反序列化失败。
- 逆向时重点关注 `CRuntimeClass` 实例、`Serialize` 虚函数分支逻辑、以及 `ReadObject`/`WriteObject` 的调用链。

---

## 来源

- [0x00实验室-202108-202304_003](../sources/0x00实验室-202108-202304_003.md)
