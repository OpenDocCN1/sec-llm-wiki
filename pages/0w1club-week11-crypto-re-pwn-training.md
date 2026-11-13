---
title: 0w1Club 第十一周萌新培养分享会：MD5 单向散列、逆向核心技术与 PWN 入门
description: 记录 0w1Club 2018 年第十一周线下培训内容，涵盖 MD5 单向散列特性与爆破思路、逆向工程核心知识点（加壳、反调试、花指令）、PWN
  入门题型概览。
category: program-analysis
tags:
- 0w1Club
- CTF
- 培训
- 密码学
- MD5
- 逆向工程
- 加壳
- 反调试
- 花指令
- PWN
- 萌新培养
date: 2018-05-13
updated: '2026-11-14'
---

## 概述

本页面整理自 0w1Club 微信公众号 2018 年 5 月 13 日发布的「培训总结 | 第十一周」文章。本次线下分享会由社团成员 **于丁** 主讲，主题为「常见加密、逆向、PWN 题目介绍」，时长 60 分钟，地点为网络安全实验室会议室。

> **主讲人简介**：于丁，计算机大三学生，热衷二进制安全，CTF 爱好者。

---

## 一、MD5 单向散列与爆破思路

### 核心特性

- **单向性**：MD5 属于单向散列加密算法，**只能正向计算，不可逆推**明文。
- **确定性**：相同输入必产生相同 128-bit（16 字节）摘要，常以 32 位十六进制字符串呈现。
- **碰撞风险**：虽已发现碰撞攻击，但在 CTF 入门题中仍常作为完整性校验或简单 Flag 校验手段。

### 实战破解路径

| 场景 | 常用手段 | 备注 |
|------|----------|------|
| 已知明文空间小（弱口令、短字符串） | **字典爆破 / 彩虹表查询** | 在线/离线工具：Hashcat、John the Ripper、在线解密站 |
| 源码/二进制中可见加密逻辑 | **还原算法 → 编写脚本离线爆破** | 需了解具体实现细节（是否加盐、多轮、截断等） |
| 仅有密文且无其他线索 | **碰撞利用 / 旁路攻击** | 入门题极少见，通常配合其他漏洞绕过校验 |

> **关联阅读**：[[crypto-basics-xor-stream-cipher-tutorial]] 中对称加密与流密码部分亦涉及「已知密文攻击」思路，可对比理解单向散列与可逆加密的破解差异。

---

## 二、逆向工程核心知识点

本次培训重点介绍三大「拦路虎」技术，均为 CTF RE 进阶必经之路。

### 加壳

- **定义**：使用加密/压缩工具（UPX、VMProtect、Themida 等）保护原始代码段，运行时在内存中自解压/解密。
- **识别特征**：
  - 区段名异常（如 `UPX0`、`UPX1`、`.vmp0`）
  - 入口点指向壳代码而非原始 `main`/`_start`
  - `strings` 几乎提取不到有效字符串
- **脱壳通用流程**：
  1. **ESP 定律 / OEP 寻找**：单步跟踪至 `POPAD` / `JMP OEP`
  2. **内存镜像导出**：使用 LordPE、Scylla 等工具 Dump 内存
  3. **IAT 修复**：重建导入表使程序可独立运行
- **工具链**：OD/x64dbg + 强力脱壳插件、IDA Pro 静态辅助分析

### 反调试

- **目的**：检测调试器存在，改变控制流或直接退出，阻碍动态分析。
- **常见技术**：
  - **API 检测**：`IsDebuggerPresent`、`CheckRemoteDebuggerPresent`、`NtQueryInformationProcess(ProcessDebugPort/ProcessDebugFlags/ProcessDebugObjectHandle)`
  - **时间检测**：`RDTSC` / `GetTickCount` / `QueryPerformanceCounter` 计算指令执行时间差
  - **自修改代码 / 校验和**：运行时校验代码段完整性
  - **硬件断点检测**：读取 `DR0-DR7` 寄存器
  - **异常处理滥用**：利用 `VEH`/`SEH` 捕获调试器产生的异常
- **对抗手段**：
  - 插件隐藏调试器（ScyllaHide、TitanHide、x64dbg 内置反反调试）
  - 手动修补关键跳转 / Hook 关键 API 返回值
  - 静态分析绕过：IDA 定位检查逻辑直接 NOP 或改写条件跳转

### 花指令

- **定义**：在正常指令流中插入**不影响程序语义**的垃圾指令，干扰反汇编器生成正确控制流图（CFG）。
- **典型形态**：
  - `JMP` 短跳转 + 无效字节
  - `CALL` / `RET` 配合栈平衡
  - `XOR EAX, EAX` / `SUB EAX, EAX` 等无效运算
  - 利用条件跳转常真/常假分支（`JZ`/`JNZ` 后跟 `NOP` 滑板）
- **分析对策**：
  - **动态调试**：单步执行观测真实指令流
  - **IDA Pro 快捷键 `C` / `U` 重新分析**配合 `Alt+F12` 追踪栈帧
  - **脚本自动化清理**：IDAPython 识别模式批量 NOP 掉垃圾指令
  - **Binary Ninja / Ghidra IL 层分析**：中间表达层天然过滤大量花指令，参考 [[binary-ninja-ollvm-deobfuscation]] 中去平坦化思路迁移应用

> **进阶实战**：[[0w1club-ctf-re-writeup-beginner-challenges]] 收录了多道涉及 **UPX 脱壳、OD 动态调试绕过花指令与反调试、C++ STL 混淆分析** 的完整 Writeup，可作配套练习。

---

## 三、PWN 入门题型概览

培训对 PWN 方向做了宏观介绍，指出新手常见入门题型：

| 题型 | 核心考点 | 典型利用链 |
|------|----------|------------|
| **栈溢出** | `gets`/`strcpy`/`scanf` 无边界读取、栈帧布局、返回地址覆盖 | `ret2text` → `ret2shellcode` → `ret2libc` → **ROP** |
| **格式化字符串** | `%n` 任意地址写、栈上参数泄露、GOT 表劫持 | 泄露栈/库基址 → 覆盖 `__stack_chk_fail`/`printf@GOT` → `system("/bin/sh")` |
| **堆基础** | `malloc`/`free` 机制、Chunk 结构、Unlink / Fastbin Attack | Off-by-null → Chunk Overlap → `__malloc_hook`/`__free_hook` 劫持 |
| **整数溢出/逻辑漏洞** | 有符号/无符号比较失误、边界检查绕过 | 绕过长度检查触发上述内存破坏 |

### 学习建议路径

1. **环境搭建**：Ubuntu 18.04/20.04 + `pwntools` + `GEF`/`pwndbg` + `libc-database`
2. **保护机制认知**：`checksec` 一键查看 **NX / ASLR / PIE / Canary / RELRO**，理解每项对应的绕过前提
3. **从零构造 Exp**：
   - 手工计算偏移 → `cyclic` 生成/定位
   - 手写 ROP 链 → `ROPgadget` / `ropper` 自动搜索
   - 调试验证：`gdb.attach()` 断点观测寄存器/栈/堆状态
4. **靶场推荐**：`pwnable.kr` 入门区、`BUUCTF` PWN 标签、《CTF 特训营》配套题目

> **系统化入门教程**：[[rop-linux-x86-beginner-tutorial]] 详细覆盖 **栈溢出原理、x86/x64 调用约定、保护机制绕过、偏移定位、Shellcode 与 ROP 实战**，可作为本节内容的深度延伸。

---

## 四、关键工具速查表

| 方向 | 静态分析 | 动态调试 | 自动化/利用开发 |
|------|----------|----------|-----------------|
| **RE** | IDA Pro / Ghidra / Binary Ninja | x64dbg / OllyDbg / OD + 插件 | IDAPython / Frida / Unicorn |
| **Crypto** | 在线解码/解密站、CyberChef | — | Python (`hashlib`, `gmpy2`, `Crypto.Util.number`) |
| **PWN** | IDA Pro / Ghidra (查 FSB/GADGET) | GDB + GEF/pwndbg | Pwntools / one_gadget / libc-database |

---

## 五、后续学习资源

- **0w1Club 历史培训专题**：
  - 第 3 周《五分钟制作钓鱼网站》 → [[phishing-website-creation-tutorial]]
  - 第 4 周《密码学入门：异或与流密码》 → [[crypto-basics-xor-stream-cipher-tutorial]]
- **逆向系统学习路线**：[[reverse-engineering-beginner-learning-path]]（书籍、视频、任务驱动法）
- **IDA Pro 进阶技巧**：[[ida-pro-tips-plugins-python]]（FLIRT 签名、Findcrypt-Yara、Keypatch、IDAPython 第三方库配置）

---

> **原文链接**：<http://mp.weixin.qq.com/s?__biz=MzUzMzEwMDk3Mg==&mid=2247483860&idx=2&sn=bb1a1c8bc0732979385a7a3e86abccdf>  
> **发布时间**：2018-05-13  
> **归档标签**：#0w1Club #培训总结 #萌新培养 #MD5 #逆向工程 #PWN

## 来源

- [0w1网络安全俱乐部-201707-201903_26](../sources/0w1网络安全俱乐部-201707-201903_26.md)
