---
title: MFC 消息映射机制深度解析与逆向实战
description: 深度解析 MFC 消息映射机制的宏展开、结构体布局、运行时分发流程，并结合 x64dbg 逆向实战演示如何定位消息映射表以辅助二进制分析。补充对比
  MFC 序列化宏机制，分析 DECLARE_/IMPLEMENT_ 宏对的共性模式、CRuntimeClass 与消息映射表的结构相似性，以及逆向工程中识别两类宏的特征模式。
category: program-analysis
tags:
- MFC
- Message Map
- Serialization
- Reverse Engineering
- x64dbg
- Windows Internals
- C++
- Binary Analysis
- CRuntimeClass
date: 2024-01-15
updated: '2026-11-14'
---

## 概述

MFC (Microsoft Foundation Classes) 消息映射机制是 Windows 程序设计中处理窗口消息的核心架构。微软引入该机制主要为了**解决虚函数过多导致虚表膨胀**的问题，采用**静态表驱动**替代传统虚函数分发，实现消息到处理函数的高效映射。

对于逆向工程师而言，消息映射表是**定位用户业务逻辑入口**的关键突破点 —— 一旦定位到映射表，即可枚举程序处理的所有消息及其对应回调函数。

---

## 核心数据结构

### AFX_MSGMAP_ENTRY —— 单条映射项

```cpp
struct AFX_MSGMAP_ENTRY {
    UINT nMessage;    // 窗口消息 ID (如 WM_PAINT, WM_CREATE)
    UINT nCode;       // 控件通知码 / WM_NOTIFY 代码
    UINT nID;         // 控件 ID (窗口消息为 0)
    UINT nLastID;     // 用于指定控件 ID 范围的条目
    UINT_PTR nSig;    // 签名类型 / 动作标识 (AfxSig_*)
    AFX_PMSG pfn;     // 回调函数指针
};
```

- **大小**：24 字节 (x86) / 32 字节 (x64，指针变宽)
- **终止标记**：`{0, 0, 0, 0, AfxSig_end, (AFX_PMSG)0}`

### AFX_MSGMAP —— 消息映射表头

```cpp
struct AFX_MSGMAP {
    const AFX_MSGMAP* (PASCAL* pfnGetBaseMap)();  // 父类 GetThisMessageMap 地址
    const AFX_MSGMAP_ENTRY* lpEntries;            // 当前类映射项数组首地址
};
```

- 通过 `pfnGetBaseMap` 形成**继承链**，运行时可向上遍历查找父类映射表

---

## 宏展开全景

### DECLARE_MESSAGE_MAP

```cpp
#define DECLARE_MESSAGE_MAP() \
protected: \
    static const AFX_MSGMAP* PASCAL GetThisMessageMap(); \
    virtual const AFX_MSGMAP* GetMessageMap() const;
```

- 声明两个函数：静态 `GetThisMessageMap` 返回当前类映射表，虚函数 `GetMessageMap` 供运行时多态调用

### BEGIN_MESSAGE_MAP / END_MESSAGE_MAP

```cpp
// 简化展开 (以 CMFC2Dlg 为例)
const AFX_MSGMAP* CMFC2Dlg::GetMessageMap() const {
    return GetThisMessageMap();
}

const AFX_MSGMAP* PASCAL CMFC2Dlg::GetThisMessageMap() {
    typedef CMFC2Dlg ThisClass;
    typedef CDialogEx TheBaseClass;

    static const AFX_MSGMAP_ENTRY _messageEntries[] = {
        // ON_WM_PAINT() 展开
        { WM_PAINT, 0, 0, 0, AfxSig_vv,
          (AFX_PMSG)(AFX_PMSGW)
          (static_cast<void (AFX_MSG_CALL CWnd::*)(void)>(&ThisClass::OnPaint)) },

        // 终止项
        { 0, 0, 0, 0, AfxSig_end, (AFX_PMSG)0 }
    };

    static const AFX_MSGMAP messageMap = {
        &TheBaseClass::GetThisMessageMap,  // 父类映射表获取函数
        &_messageEntries[0]                // 自身映射项数组
    };

    return &messageMap;
}
```

**关键点**：
- `_messageEntries` 与 `messageMap` 均为 **静态局部变量**，存储于 `.rdata` / `.data` 段，生命周期贯穿进程
- 继承链通过 `&TheBaseClass::GetThisMessageMap` 串联

### 常用消息宏展开示例

| 宏 | 展开关键字段 (nMessage, nSig, pfn) |
|---|---|
| `ON_WM_PAINT()` | `WM_PAINT, AfxSig_vv, &ThisClass::OnPaint` |
| `ON_WM_CREATE()` | `WM_CREATE, AfxSig_is, &ThisClass::OnCreate` |
| `ON_COMMAND(ID, func)` | `WM_COMMAND, AfxSig_vv, &ThisClass::func` (nID=ID) |
| `ON_NOTIFY(code, id, func)` | `WM_NOTIFY, AfxSig_vv, &ThisClass::func` (nCode=code, nID=id) |

---

## 运行时分发流程

### 入口：CWnd::OnWndMsg

```cpp
BOOL CWnd::OnWndMsg(UINT message, WPARAM wParam, LPARAM lParam, LRESULT* pResult) {
    // 1. 优先处理 COMMAND / NOTIFY
    if (message == WM_COMMAND) { ... }
    if (message == WM_NOTIFY) { ... }

    // 2. 遍历继承链查找映射表
    const AFX_MSGMAP* pMessageMap;
    const AFX_MSGMAP_ENTRY* lpEntry;
    for (pMessageMap = GetMessageMap(); pMessageMap != NULL; 
         pMessageMap = pMessageMap->pfnGetBaseMap()) {
        if ((lpEntry = AfxFindMessageEntry(pMessageMap->lpEntries, message, 0, 0)) != NULL)
            goto LDispatch;
    }
    return FALSE;

LDispatch:
    // 3. 根据签名分发调用
    union MessageMapFunctions mmf;
    mmf.pfn = lpEntry->pfn;
    switch (lpEntry->nSig) {
        case AfxSig_vv: (this->*mmf.pfn_vv)(); break;
        case AfxSig_vw: (this->*mmf.pfn_vw)(wParam); break;
        case AfxSig_is: (this->*mmf.pfn_is)((LPTSTR)lParam); break;
        // ... 其他签名
    }
    return TRUE;
}
```

### 查找核心：AfxFindMessageEntry

```cpp
const AFX_MSGMAP_ENTRY* AfxFindMessageEntry(
    const AFX_MSGMAP_ENTRY* lpEntry, UINT nMsg, UINT nCode, UINT nID) {
    while (lpEntry->nSig != AfxSig_end) {
        if (lpEntry->nMessage == nMsg && 
            lpEntry->nCode == nCode &&
            nID >= lpEntry->nID && nID <= lpEntry->nLastID)
            return lpEntry;
        lpEntry++;
    }
    return NULL;
}
```

**分发特征**：
- 线性查找 (映射表通常较小，性能可接受)
- 签名决定调用约定与参数传递方式
- 成员函数指针通过 `this->*mmf.pfn_xxx` 调用

---

## 逆向实战：x64dbg 定位消息映射表

### 目标程序结构

```cpp
class CMainWindow : public CFrameWnd {
    DECLARE_MESSAGE_MAP()
    afx_msg int OnCreate(LPCREATESTRUCT);
};

BEGIN_MESSAGE_MAP(CMainWindow, CFrameWnd)
    ON_WM_CREATE()
END_MESSAGE_MAP()
```

### 断点策略

| 断点位置 | 目的 |
|---|---|
| `CMainWindow::OnCreate` | 目标回调函数，验证命中 |
| `CMainWindow::GetMessageMap` | 观察映射表返回值 |
| `CFrameWnd::Create` | 窗口创建入口，触发 `WM_CREATE` 分发 |

### 实战步骤

1. **断在 `CFrameWnd::Create`**  
   窗口创建流程启动，后续会触发 `WM_CREATE` 消息分发

2. **堆栈回溯定位 `OnWndMsg`**  
   ![堆栈回溯](../Images/4c4b335492b7e102b328bd7fecb666e1.png)  
   关键调用链：`Create` → ... → `OnWndMsg` → `AfxFindMessageEntry` → 目标回调

3. **跟踪 `GetMessageMap` → `GetThisMessageMap`**  
   ![GetThisMessageMap 返回](../Images/8c0139c405df2bbedf400be66476d015.png)  
   返回值 `RAX` 指向 `AFX_MSGMAP` 结构

4. **解析 `AFX_MSGMAP` 结构**  
   ![映射表结构](../Images/bdcce5fc3379e3c93bc96aae8de9b85a.png)  
   - 第 1 字段 (QWORD)：**父类 `GetThisMessageMap` 地址**  
   - 第 2 字段 (QWORD)：**`_messageEntries` 数组首地址**

5. **Dump 映射项数组**  
   ![映射项内容](../Images/ce432b7848ddb8723a13ac59f66a3ee4.png)  
   对应 `ON_WM_CREATE()` 展开：
   ```
   nMessage = 0x1 (WM_CREATE)
   nCode    = 0
   nID      = 0
   nLastID  = 0
   nSig     = 0xD (AfxSig_is)
   pfn      = CMainWindow::OnCreate 地址
   ```

6. **验证分发命中**  
   继续运行，`OnWndMsg` 中 `AfxFindMessageEntry` 匹配 `WM_CREATE`，跳转执行 `OnCreate`  
   ![命中分发](../Images/40045beb703dc5925870703913496587.png)

---

## 逆向分析模式总结

| 场景 | 定位策略 |
|---|---|
| **已知消息 ID (如 WM_COMMAND)** | 搜索字符串 `"WM_COMMAND"` / 常量 `0x111`，交叉引用定位 `AfxFindMessageEntry` 调用点 |
| **已知回调函数地址** | 反向搜索函数地址在 `.rdata` 中的引用，定位 `_messageEntries` 数组项 |
| **类继承关系重构** | 从 `AFX_MSGMAP.pfnGetBaseMap` 追踪父类 `GetThisMessageMap`，递归还原继承树 |
| **混淆/去符号二进制** | 特征码搜索：`AfxSig_end` (0x19) + 连续 5 个 DWORD 为 0 的 24 字节模式 |

### 关键特征码 (x64)

```asm
; AFX_MSGMAP_ENTRY 终止项
00 00 00 00  00 00 00 00  00 00 00 00  00 00 00 00  19 00 00 00  00 00 00 00
; nMessage=0, nCode=0, nID=0, nLastID=0, nSig=AfxSig_end(0x19), pfn=0
```

---

## 进阶议题

### 签名类型 (AfxSig_*) 对应表

| 常量 | 值 | 函数原型 | 典型消息 |
|---|---|---|---|
| `AfxSig_vv` | 0 | `void func()` | `WM_PAINT`, `WM_DESTROY` |
| `AfxSig_vw` | 1 | `void func(WPARAM)` | `WM_TIMER` |
| `AfxSig_is` | 13 (0xD) | `int func(LPCREATESTRUCT)` | `WM_CREATE` |
| `AfxSig_lwl` | ... | `LRESULT func(WPARAM, LPARAM)` | 通用消息 |
| `AfxSig_end` | 25 (0x19) | 终止标记 | — |

完整定义见 MFC 源码 `afxwin.h` 中 `AFX_SIG` 枚举。

### 动态消息映射 (ON_REGISTERED_MESSAGE)

```cpp
ON_REGISTERED_MESSAGE(WM_MYCUSTOM, OnMyCustom)
```
- `nMessage` = `RegisterWindowMessage` 返回的运行时值
- 逆向时需结合字符串搜索 `"WM_MYCUSTOM"` 定位注册点

### 消息映射与虚函数表的共存

- `GetMessageMap` 本身是虚函数，存在于 vtable 中
- 但具体消息处理**不走虚函数分发**，避免了 vtable 膨胀
- 逆向时可同时利用：vtable 定位类对象，消息表定位业务逻辑

---

## MFC 序列化机制与消息映射的对比分析

### DECLARE_/IMPLEMENT_ 宏对的共性模式

MFC 同时使用 **DECLARE_/IMPLEMENT_ 宏对** 实现消息映射与序列化两套独立机制，二者在宏设计模式上高度同构：

| 维度 | 消息映射 | 序列化 |
|---|---|---|
| **声明宏** | `DECLARE_MESSAGE_MAP()` | `DECLARE_SERIAL(class_name)` |
| **实现宏** | `BEGIN_MESSAGE_MAP` / `END_MESSAGE_MAP` | `IMPLEMENT_SERIAL(class_name, base_class, wSchema)` |
| **核心数据结构** | `AFX_MSGMAP` + `AFX_MSGMAP_ENTRY[]` | `CRuntimeClass` |
| **静态存储** | `.rdata` 段：`_messageEntries[]` + `messageMap` | `.rdata` 段：`classCMyLine` (CRuntimeClass 实例) |
| **继承链遍历** | `AFX_MSGMAP.pfnGetBaseMap` → 父类 `GetThisMessageMap` | `CRuntimeClass.m_pBaseClass` / `m_pfnGetBaseClass` → 基类 `CRuntimeClass` |
| **终止标记** | `AfxSig_end` (0x19) 填充的 `AFX_MSGMAP_ENTRY` | `CRuntimeClass.m_pNextClass` 单向链表以 `NULL` 结束 |
| **运行时入口** | 虚函数 `GetMessageMap()` → 静态 `GetThisMessageMap()` | 虚函数 `GetRuntimeClass()` → 静态 `GetThisClass()` |
| **动态创建** | 不涉及 | `CreateObject()` 函数指针 → 无参构造函数 |

**宏展开对比**：

```cpp
// 消息映射：DECLARE_MESSAGE_MAP()
protected:
    static const AFX_MSGMAP* PASCAL GetThisMessageMap();
    virtual const AFX_MSGMAP* GetMessageMap() const;

// 序列化：DECLARE_SERIAL(CMyLine) 展开后包含
protected:
    static CRuntimeClass* PASCAL _GetBaseClass();
public:
    static CRuntimeClass classCMyLine;        // 类静态实例
    static CRuntimeClass* PASCAL GetThisClass();
    virtual CRuntimeClass* GetRuntimeClass() const;
    static CObject* PASCAL CreateObject();    // 动态创建入口
    friend CArchive& operator>>(CArchive&, CMyLine*&); // 反序列化友元
```

```cpp
// 消息映射：BEGIN/END_MESSAGE_MAP 定义静态数组与表头
static const AFX_MSGMAP_ENTRY _messageEntries[] = { ... };
static const AFX_MSGMAP messageMap = { &Base::GetThisMessageMap, _messageEntries };

// 序列化：IMPLEMENT_SERIAL 初始化 CRuntimeClass 实例
_IMPLEMENT_RUNTIMECLASS(CMyLine, CObject, 1, CMyLine::CreateObject, &_init_CMyLine)
AFX_CLASSINIT _init_CMyLine(RUNTIME_CLASS(CMyLine)); // 注册到全局类链表
```

### CRuntimeClass 与消息映射表的结构相似性

两大核心结构体在内存布局与功能角色上呈现**结构同构**：

```cpp
// 消息映射表头：描述「类 → 消息处理函数集合」的映射
struct AFX_MSGMAP {
    const AFX_MSGMAP* (PASCAL* pfnGetBaseMap)();  // 父类映射表获取器 (继承链)
    const AFX_MSGMAP_ENTRY* lpEntries;            // 自身映射项数组 (业务逻辑索引)
};

// 运行时类信息：描述「类 → 元数据 + 创建器 + 基类」的映射
struct CRuntimeClass {
    LPCSTR m_lpszClassName;           // 类名 (标识符)
    int    m_nObjectSize;             // 对象大小 (内存布局)
    UINT   m_wSchema;                 // 版本号 (序列化兼容性)
    CObject* (PASCAL* m_pfnCreateObject)(); // 创建器 (工厂模式)
#ifdef _AFXDLL
    CRuntimeClass* (PASCAL* m_pfnGetBaseClass)(); // 基类获取器 (继承链)
#else
    CRuntimeClass* m_pBaseClass;      // 基类指针 (静态链接时直接指针)
#endif
    CRuntimeClass* m_pNextClass;      // 全局注册链表指针
    const AFX_CLASSINIT* m_pClassInit;// 初始化器
    // 方法: CreateObject, IsDerivedFrom, FromName, Load/Store...
};
```

**对应关系映射**：

| 消息映射概念 | 序列化概念 | 共同本质 |
|---|---|---|
| `AFX_MSGMAP` | `CRuntimeClass` | **类级元数据描述符** |
| `pfnGetBaseMap` | `m_pfnGetBaseClass` / `m_pBaseClass` | **继承链遍历函数/指针** |
| `lpEntries` → `AFX_MSGMAP_ENTRY[]` | `m_pfnCreateObject` + 友元 `operator>>` | **行为分发表** (消息分发 vs 对象创建/反序列化) |
| `AfxSig_*` 签名决定调用约定 | `m_wSchema` 版本决定数据布局 | **版本/签名驱动的运行时多态** |
| `GetMessageMap()` 虚函数 | `GetRuntimeClass()` 虚函数 | **运行时类型识别 (RTTI) 入口** |
| 静态 `GetThisMessageMap()` | 静态 `GetThisClass()` | **编译期绑定的类级工厂函数** |

**内存中共存模式**：
- 同一类若同时启用消息映射与序列化，在 `.rdata` 段会**相邻存在**两组静态结构：
  1. `AFX_MSGMAP` + `AFX_MSGMAP_ENTRY[]`
  2. `CRuntimeClass` 实例 (如 `classCMyLine`)
- 逆向时可通过**交叉引用分析**同一类的两组结构，互相验证类名、继承关系、成员函数地址

### 逆向工程中识别两类宏的特征模式

#### 消息映射特征识别

| 特征类型 | 具体模式 | 搜索/定位方法 |
|---|---|---|
| **结构体特征码** | `AfxSig_end` (0x19) + 5 个零 DWORD (x64: 24 字节全零结尾) | IDA/Binja 字节模式搜索：`19 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00` |
| **函数特征** | `GetThisMessageMap` / `GetMessageMap` 成对出现，前者静态后者虚函数 | 交叉引用分析：虚表中指向 `GetMessageMap`，该函数尾部 `jmp GetThisMessageMap` |
| **继承链特征** | `AFX_MSGMAP` 第一个 QWORD 指向父类 `GetThisMessageMap` | 递归追踪：`AFX_MSGMAP` → `pfnGetBaseMap` → 父类 `GetThisMessageMap` → 父类 `AFX_MSGMAP` |
| **消息常量** | `nMessage` 字段为 `WM_*` 常量 (0x001-0x0400) | 搜索已知消息 ID (如 `0x111`=WM_COMMAND) 在 `.rdata` 的引用 |

#### 序列化特征识别

| 特征类型 | 具体模式 | 搜索/定位方法 |
|---|---|---|
| **CRuntimeClass 结构特征** | 固定偏移布局：`m_lpszClassName`(指针) → `m_nObjectSize`(int) → `m_wSchema`(UINT) → `m_pfnCreateObject`(指针) → 基类指针/函数 → `m_pNextClass`(指针) | 字节模式：类名字符串指针 + 非零 size + schema版本号 + 有效函数指针 + 链表指针 |
| **类名字符串** | `m_lpszClassName` 指向 `.rdata` 中的 PascalCase 类名 (如 `"CMyLine"`) | 字符串搜索 → 反向引用定位 `CRuntimeClass` 实例 |
| **动态创建函数** | `CreateObject` 返回 `new ClassName()`，极短函数 (2-3 条指令) | 搜索 `new` 操作符调用模式，或 `CreateObject` 符号 (若未剥离) |
| **反序列化友元** | `operator>>(CArchive&, ClassName*&)` 调用 `ar.ReadObject(RUNTIME_CLASS(ClassName))` | 交叉引用 `ReadObject`，参数为 `RUNTIME_CLASS` 宏展开的 `&classClassName` |
| **全局类链表** | `CRuntimeClass.m_pNextClass` 串联所有 `DECLARE_SERIAL` 类 | 从 `AFX_MODULE_STATE::m_classList` 头节点遍历，或搜索 `m_pNextClass` 非零链表 |
| **版本号字段** | `m_wSchema` (UINT) 非 0xFFFF (-1 表示不可序列化) | 在 `CRuntimeClass` 候选结构中筛选 `m_wSchema != 0xFFFFFFFF` |

#### 联合识别策略：消息映射 + 序列化双重定位

当目标类同时具备 `DECLARE_MESSAGE_MAP` 与 `DECLARE_SERIAL` 时，可实施**双重交叉验证**：

```text
类 CMyLine
├── 消息映射侧
│   ├── CMyLine::GetThisMessageMap() → AFX_MSGMAP @ 0x14000xxxx
│   │   ├── pfnGetBaseMap → CObject::GetThisMessageMap (或 CWnd)
│   │   └── lpEntries → AFX_MSGMAP_ENTRY[] @ 0x14000yyyy
│   │       ├── {WM_PAINT, ..., &CMyLine::OnPaint}
│   │       └── {0,0,0,0,0x19,0} (终止)
│   └── 虚表槽: GetMessageMap → GetThisMessageMap
│
└── 序列化侧
    ├── classCMyLine (CRuntimeClass) @ 0x14000zzzz
    │   ├── m_lpszClassName → "CMyLine"
    │   ├── m_nObjectSize = 0x18
    │   ├── m_wSchema = 1
    │   ├── m_pfnCreateObject → CMyLine::CreateObject (new CMyLine)
    │   ├── m_pBaseClass → classCObject (CObject 的 CRuntimeClass)
    │   └── m_pNextClass → 下一个注册类
    ├── CMyLine::GetRuntimeClass() → &classCMyLine
    ├── CMyLine::CreateObject() → new CMyLine()
    └── operator>>(CArchive&, CMyLine*&) → ar.ReadObject(&classCMyLine)
```

**实战定位流程**：

1. **入口点选择**：优先从已知业务函数 (如 `OnPaint`、`Serialize`) 反向搜索引用
2. **双结构锚定**：
   - 消息侧：定位 `AFX_MSGMAP_ENTRY.pfn` = 目标函数 → 所在 `_messageEntries` → `AFX_MSGMAP`
   - 序列化侧：定位 `CRuntimeClass.m_pfnCreateObject` 或 `operator>>` 引用 → `CRuntimeClass` 实例
3. **类名绑定**：`CRuntimeClass.m_lpszClassName` 给出确切类名；消息映射无直接类名，需通过 `GetThisMessageMap` 符号推断
4. **继承树重构**：
   - 消息侧：沿 `pfnGetBaseMap` 向上
   - 序列化侧：沿 `m_pBaseClass`/`m_pfnGetBaseClass` 向上
   - 两者应收敛于同一基类 (如 `CObject`/`CWnd`)
5. **版本/签名交叉**：
   - `CRuntimeClass.m_wSchema` 对应序列化版本
   - `AFX_MSGMAP_ENTRY.nSig` 对应消息处理签名
   - 均为**运行时分发决策的关键字段**

#### 自动化提取脚本思路 (IDA Python / Binary Ninja)

```python
# 伪代码：同时提取消息映射表与 CRuntimeClass
def extract_mfc_structures():
    # 1. 扫描 CRuntimeClass 候选 (基于类名字符串 + 结构布局)
    runtime_classes = find_cruntimeclass_instances()
    
    # 2. 扫描 AFX_MSGMAP 候选 (基于 AfxSig_end 终止模式)
    message_maps = find_afx_msgmap_instances()
    
    # 3. 关联分析：通过类名、函数地址重叠、继承链一致性匹配
    for rc in runtime_classes:
        cls_name = get_string(rc.m_lpszClassName)
        # 查找同名类的消息映射
        mm = find_msgmap_by_classname(cls_name)  # 启发式：GetThisMessageMap 符号包含类名
        if mm:
            correlate(rc, mm)  # 输出类综合报告
```

---

## 相关资源与引用

- [[reverse-engineering-beginner-learning-path]] — 逆向工程入门学习路线，含汇编、工具链、实战建议
- [[crackme-analysis-keygen-development-case-study]] — 完整逆向实战案例：从字符串定位到注册机编写
- [[ida-pro-tips-plugins-python]] — IDA Pro 进阶技巧：FLIRT 签名、Findcrypt-Yara、Keypatch、IDAPython
- [[binary-ninja-ollvm-deobfuscation]] — Binary Ninja IL 层去混淆，思路可迁移至 MFC 映射表自动化提取

---

## 小结

MFC 消息映射机制以**静态结构体数组 + 继承链遍历 + 签名分发**替代虚函数表，兼顾了内存占用与扩展性。MFC 序列化机制则通过 `CRuntimeClass` 实现**运行时类型识别 + 动态创建 + 版本化持久化**。两者在宏设计、数据结构、继承链遍历、运行时分发决策上呈现**深度同构**：

1. **宏对模式统一**：`DECLARE_` 声明静态工厂函数与虚函数入口，`IMPLEMENT_` 定义静态数据结构并注册到全局/继承链
2. **结构体同构**：`AFX_MSGMAP` 与 `CRuntimeClass` 均为「类级元数据描述符」，含继承链指针、行为分发表指针、终止标记
3. **逆向识别互补**：消息映射通过 `AfxSig_end` 特征码定位，序列化通过类名字符串与 `CRuntimeClass` 布局定位；两者交叉引用可重构完整类层级与业务逻辑图
4. **工具化潜力大**：可编写插件同时解析 `.rdata` 中的映射表与运行时类表，生成 MFC 程序的**类继承树 + 消息分发表 + 序列化版本表**三维视图

> 本页技术细节参考《Windows 程序设计（第3版）》及 MFC 源码 (afxwin.h, winocc.cpp, winmsg.cpp, afx.h)。序列化机制分析参考微信公众号文章《关于MFC的序列化与反序列化机制》。实战截图来源于微信公众号文章《关于MFC消息映射机制浅解》。
## 来源

- [0x00实验室-202108-202304_002](../sources/0x00实验室-202108-202304_002.md)
- [0x00实验室-202108-202304_003](../sources/0x00实验室-202108-202304_003.md)
