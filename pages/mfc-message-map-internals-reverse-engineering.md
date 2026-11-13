---
title: MFC 消息映射机制深度解析与逆向实战
description: 深度解析 MFC 消息映射机制的宏展开、结构体布局、运行时分发流程，并结合 x64dbg 逆向实战演示如何定位消息映射表以辅助二进制分析。
category: program-analysis
tags:
- MFC
- Message Map
- Reverse Engineering
- x64dbg
- Windows Internals
- C++
- Binary Analysis
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

## 相关资源与引用

- [[reverse-engineering-beginner-learning-path]] — 逆向工程入门学习路线，含汇编、工具链、实战建议
- [[crackme-analysis-keygen-development-case-study]] — 完整逆向实战案例：从字符串定位到注册机编写
- [[ida-pro-tips-plugins-python]] — IDA Pro 进阶技巧：FLIRT 签名、Findcrypt-Yara、Keypatch、IDAPython
- [[binary-ninja-ollvm-deobfuscation]] — Binary Ninja IL 层去混淆，思路可迁移至 MFC 映射表自动化提取

---

## 小结

MFC 消息映射机制以**静态结构体数组 + 继承链遍历 + 签名分发**替代虚函数表，兼顾了内存占用与扩展性。对于二进制分析：

1. **映射表即业务地图** —— 定位 `_messageEntries` 即枚举所有消息处理入口
2. **`GetThisMessageMap` 是锚点** —— 从该函数返回值或交叉引用切入最稳健
3. **签名决定调用约定** —— 逆向还原参数个数/类型需查阅 `AfxSig_*` 表
4. **工具化潜力大** — — 可编写 IDA/Binary Ninja 插件自动解析 `.rdata` 中的映射表，生成类层级与消息分发图

> 本页技术细节参考《Windows 程序设计（第3版）》及 MFC 源码 (afxwin.h, winocc.cpp, winmsg.cpp)。实战截图来源于微信公众号文章《关于MFC消息映射机制浅解》。

## 来源

- [0x00实验室-202108-202304_002](../sources/0x00实验室-202108-202304_002.md)
