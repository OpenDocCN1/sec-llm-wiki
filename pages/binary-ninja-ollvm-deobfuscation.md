---
title: 利用 Binary Ninja 去除 OLLVM 流程平坦化混淆
description: 索引并结构化记录微信公众号文章《利用Binary Ninja去除ollvm流程平坦化混淆》的技术主题，涵盖 OLLVM 控制流平坦化原理、Binary
  Ninja 中间表达（IL）分析、Python 插件/脚本编写思路及去平坦化自动化流程。
category: program-analysis
tags:
- Binary Ninja
- OLLVM
- Control Flow Flattening
- Deobfuscation
- Reverse Engineering
- Python
- Plugin Development
- Intermediate Language
date: 2019-12-26
updated: '2026-11-12'
---
## 概述

本页面汇总并索引 2019 年 12 月 26 日每日安全看点中收录的技术文章 **《利用 Binary Ninja 去除 ollvm 流程平坦化混淆》**。该文章探讨了如何利用 Binary Ninja 强大的中间表达（IL）体系与 Python API，针对 OLLVM (Obfuscator-LLVM) 的控制流平坦化保护进行自动化还原分析。

## 文章来源与元数据

| 属性 | 详情 |
| :--- | :--- |
| **文章标题** | 利用 Binary Ninja 去除 ollvm 流程平坦化混淆 |
| **发布平台** | 微信公众号 (每日安全看点 / 原发技术公众号) |
| **发布日期** | 2019-12-26 |
| **原文链接** | <https://mp.weixin.qq.com/s/h4rLdQ_GKxT2Nowv2F7tMg> |
| **归档上下文** | 每日安全看点【2019.12.26】 |

> **注**：当前页面基于归档摘录的标题与链接构建，原文完整技术细节（代码片段、具体 API 调用链、实战案例步骤）请访问原文链接获取。本页面旨在提供结构化的知识索引与交叉引用。

## 核心技术主题拆解

根据文章标题与逆向工程通用技术栈，该文章核心覆盖以下技术维度：

### OLLVM 控制流平坦化机制分析
- **平坦化原理**：将原有控制流图（CFG）打散为由调度器分发的基本块，引入状态变量控制执行流向。
- **关键特征**：巨大的 `switch-case` 或 `if-else` 调度分发器、基本块间无直接跳转关系、状态变量更新逻辑分散。
- **去混淆目标**：识别调度器、恢复状态变量语义、重建原始 CFG 边。

### Binary Ninja 分析优势与 API 应用
- **中间表达（IL）层级**：利用 **LLIL (Low Level IL)** / **MLIL (Medium Level IL)** / **HLIL (High Level IL)** 进行平台无关的语义分析，尤其是 MLIL 的 SSA 形式便于追踪状态变量数据流。
- **核心 API 场景**：
    - `bv.functions` / `function.mlil.ssa_form`：遍历函数获取 SSA 形式。
    - `ssa_var` / `var_def` / `var_uses`：追踪状态变量的定义与使用链。
    - `BasicBlock` / `outgoing_edges` / `dominators`：CFG 结构分析与调度器基本块识别。
    - `Architecture` / `Instruction`：指令级语义提取与模式匹配。
- **自动化脚本/插件形态**：Python 脚本 (`binaryninja` 模块) 或 插件 (Plugin Command / Background Task)。

### 典型去平坦化自动化流程
1.  **特征识别**：通过基本块出度/入度统计、指令模式匹配定位调度器基本块。
2.  **状态变量提取**：利用 SSA 形式回切，定位状态变量的 Phi 节点与更新指令。
3.  **分发逻辑建模**：解析 `switch`/`cmp-jmp` 结构，建立 `State Value -> Target Block` 映射表。
4.  **CFG 重构**：移除调度器边，根据映射表在原始基本块间建立直接跳转边。
5.  **清理与优化**：删除冗余状态更新指令、合并基本块、恢复循环/条件结构（可选 HLIL 协助）。

## 关联知识页面 (交叉引用)

- [[ida-pro-tips-plugins-python]]
  - **关联点**：对比 IDA Pro (IDAPython) 与 Binary Ninja (Python API) 在二进制分析自动化、插件生态、中间表达能力上的异同。IDA 依赖 Microcode/Decompiler API，BN 原生提供可编程 IL。
- [[oo7-spectre-defense-binary-analysis]]
  - **关联点**：展示基于污点分析的跨过程二进制漏洞挖掘，印证了中间表达（IL/IR）在复杂程序语义分析（如去混淆、漏洞挖掘）中的核心地位。
- [[linux-kernel-hardening-mechanisms]]
  - **关联点**：控制流完整性 (CFI) 等内核防御机制与混淆技术在“控制流保护/隐藏”目标上具有对偶性，理解混淆有助于理解 CFI 绕过与强化。

## 知识沉淀待办

- [ ] 获取原文全文，提取核心 Python 代码片段（如调度器识别逻辑、SSA 变量追踪函数）。
- [ ] 整理 Binary Ninja 关键 API 速查表（针对去混淆场景）。
- [ ] 补充实战案例：某 CTF 题目/商业样本的去平坦化前后 CFG 对比图。
- [ ] 扩展对抗视角：OLLVM 最新版本 (Clang 11+/14+) 新增的指令替换、虚假控制流、常量加密等混淆及对应 BN 处理策略。

## 来源

- [0th3rs安全团队-201911-202204_103](../sources/0th3rs安全团队-201911-202204_103.md)
