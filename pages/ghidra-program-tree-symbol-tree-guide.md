---
title: Ghidra Program Tree 与 Symbol Tree 核心窗口详解
description: 系统梳理 Ghidra 逆向工程平台中 Program Tree（程序树/项目树）与 Symbol Tree（符号树）两大核心窗口的功能定位、操作指南、外部库关联技巧及命名空间管理机制，配合图示说明与实战操作步骤。
category: program-analysis
tags:
- Ghidra
- Reverse Engineering
- Program Tree
- Symbol Tree
- 二进制分析
- 逆向工程工具
- NSA
- 外部库关联
date: '2023-04-13'
updated: '2026-11-15'
---

## 概述

Ghidra 作为 NSA 开源的逆向工程平台，其 CodeBrowser 界面中 **Program Tree（程序树/项目树）** 与 **Symbol Tree（符号树）** 两大窗口是静态分析时最常交互的导航中枢。本页结合官方文档与实战经验，系统记录两窗口的核心功能、典型操作流程、外部程序关联技巧及命名空间管理机制，便于逆向分析师快速上手与查阅。

> 交叉引用：[[reverse-engineering-beginner-learning-path]] 逆向工程入门学习路径 | [[ida-pro-tips-plugins-python]] IDA Pro 实用技巧对比 | [[binary-ninja-ollvm-deobfuscation]] Binary Ninja 去混淆插件开发

---

## Program Tree（程序树/项目树）窗口

### 窗口定位与作用

- **默认位置**：CodeBrowser 界面左上角
- **核心功能**：
  1. 以树形结构组织程序内部代码单元
  2. 作为导航入口：点击节点可在反汇编/反编译视图中定位
  3. 作为过滤器：仅显示选中节点对应的代码范围

### 核心概念：文件夹 与 分段

| 概念 | 含义 | 约束 |
|------|------|------|
| **分段** | 代码单元的直接容器（函数、数据块等） | 一个代码单元**仅且只能**属于一个分段 |
| **文件夹** | 组织分段/子文件夹的逻辑容器 | 除根文件夹外，**可同时挂载在多个父文件夹下**（非传统文件系统树） |

> 当把同一分段/文件夹拖拽到另一父文件夹时，**不会创建副本**，而是建立多重父子引用关系。

### 常用操作速查

#### 创建文件夹
1. 右键点击现有文件夹
2. 选择 **Create Folder**

#### 创建分段
两种等价方式：
- **菜单法**：右键文件夹 → **Create Fragment**
- **拖拽法**：从 Listing（代码陈列窗口）选中代码单元 → 拖入目标文件夹  
  - 新分段命名规则：默认取首个地址名；若存在标签则用标签名

#### 删除节点
满足 **任一** 条件即可删除：
1. 节点为空
2. 节点仍存在于其他父文件夹中（即多重引用未完全解除）

操作：右键 → **Delete**

#### 排序
右键文件夹 → **Sort** → **by Address** / **by Name**

---

## Symbol Tree（符号树）窗口

### 窗口定位与打开

- **默认位置**：Program Tree 正下方
- **打开方式**：`Window → Symbol Tree`

### 五大顶层分类

| 分类 | 含义 | 典型用途 |
|------|------|----------|
| **Imports** | 外部库命名空间符号集合 | 查看/关联外部依赖、跳转外部函数 |
| **Exports** | 本程序导出的入口点符号 | 分析 DLL/共享库导出表 |
| **Functions** | 程序内部函数符号（不含外部函数） | 展开可看参数、局部变量符号 |
| **Labels** | 全局命名空间下的标号符号 | 定位全局数据、跳转表等 |
| **Classes** | 类命名空间（含成员函数/标号） | C++/ObjC 类结构分析 |
| **Namespaces** | 通用命名空间（可嵌套类、函数、标号、子命名空间） | 模块化代码组织、大型项目分层 |

> 图示：展开 Functions 节点可直接看到参数与变量符号，便于快速重命名或类型设定。

---

## 外部库关联与 External Location 实战

### 创建库
- 右键 **Imports** 文件夹 → **Create Library**
- 默认名 `NewLibrary`，可重命名为真实库名（如 `kernel32.dll`、`libc.so.6`）

### 关联外部程序
- 右键库节点 → **Set External Program**
- 在弹出的工程选择器中选中已导入的外部程序/库文件
- 关联后：双击 Imports 下的外部函数可直接跳转至外部程序对应地址阅读代码

### 创建/编辑 External Location（外部位置）

#### 创建流程
1. 右键库节点 → **Create External Location**
2. 填写对话框关键字段：
   - **External Program Path**：自动回填（已关联时）或手动编辑
   - **Label / Address**：二选一指定目标符号或裸地址（如 `0xdeadbeef`）
   - **Make External Function**：
     - ✓ → 创建外部**函数**（可被调用图识别）
     - ✗ → 创建非函数外部位置（数据、跳转目标等）

#### 导航差异
- 单击外部位置标签 → 定位到**引用该外部位置的源头**（调用点/引用点）
- 右键标签 → **Go To External Location** → 真正跳转到外部程序内部的目标地址

#### 编辑现有外部位置
右键外部位置/外部函数 → **Edit External Location** → 修改地址/标签/函数属性

---

## 命名空间与类管理

### 创建类
- 右键父命名空间（通常是全局命名空间） → **Create Class**
- 所有类默认位于 **全局命名空间** 下

### 创建命名空间
- 右键任意父命名空间（全局、类、或其他命名空间） → **Create Namespace**
- 支持任意层级嵌套，便于模拟 C++ `namespace`、Java `package` 或模块化结构

---

## 实战技巧速记

| 场景 | 推荐操作 |
|------|----------|
| 快速聚焦某模块代码 | Program Tree 新建文件夹 → 拖入相关函数/分段 → 仅看该文件夹 |
| 分析动态链接库调用 | Imports 建库 → Set External Program → 双击外部函数阅读库实现 |
| 处理间接调用/跳转表 | Create External Location 指向真实目标 → 修正调用图 |
| 重构 C++ 类层级 | Classes 下 Create Class + Create Namespace 还原继承/嵌套关系 |
| 批量重命名符号 | Symbol Tree 展开 Functions → 直接在树上 F2 重命名，自动同步到 Listing/Decompiler |

---

## 交叉引用导航

- [[reverse-engineering-beginner-learning-path]] 逆向工程入门学习路径（含 Ghidra 入门建议）
- [[ida-pro-tips-plugins-python]] IDA Pro 实用技巧（FLIRT 签名、Findcrypt-Yara、Keypatch 等）
- [[binary-ninja-ollvm-deobfuscation]] Binary Ninja 去 OLLVM 平坦化插件开发
- [[crackme-analysis-keygen-development-case-study]] CrackMe 算法分析与注册机编写实战
- [[pe-import-table-internals]] PE 导入表内部结构（对应 Imports 窗口底层原理）
- [[pe-export-table-internals]] PE 导出表内部结构（对应 Exports 窗口底层原理）
- [[android-shelling-unshelling-techniques]] Android 加固脱壳技术（Ghidra 分析脱壳后 DEX 常用）
- [[game-reverse-engineering-course-materials]] 游戏逆向工程课程资料（含 Ghidra 实战模块）

---

## 版本历史

| 版本 | 日期 | 变更摘要 |
|------|------|----------|
| 1.0 | 2023-04-13 | 初稿：整理 Program Tree 与 Symbol Tree 核心操作、外部库关联、命名空间管理 |

## 来源

- [0x6270安全团队-202203-202304_39](../sources/0x6270安全团队-202203-202304_39.md)
