---
title: 0w1Club 第七周萌新培养分享会：栈溢出原理与 ROP 链构造基础
description: 记录 0w1Club 第七周萌新培养分享会内容，系统梳理栈溢出原理、危险函数、栈保护机制（RELRO/Canary/NX/PIE）及基本
  ROP 链构造思路，为二进制安全入门提供结构化知识框架。
category: ai-security
tags:
- 0w1Club
- 萌新培养
- 栈溢出
- ROP
- 二进制安全
- CTF
- PWN
- 西安交通大学
- 网络安全社团
- 微信归档
date: 2018-04-15
updated: '2026-11-14'
---

## 概览

本页面整理自 0w1Club 网络安全俱乐部微信公众号发布的**第七周萌新培养分享会**总结文章（原标题：《培训总结 | 第七周》）。分享会于 **2018 年 4 月 15 日（周日）19:00** 在**网络安全实验室会议室**举行，时长约 1 小时，主讲人为 **于丁**（计算机大三学生，CTF 选手，专注二进制安全）。

> [[0w1club-wechat-archive-201707-201903]] 中收录了该期分享会的索引条目；[[0w1club-wechat-archive-201908-202207]] 亦有后续萌新培养系列的汇总。

---

## 核心知识点

### 函数调用栈基础

分享会首先以**函数调用栈示意图**为切入点，说明栈帧布局、返回地址保存位置等基础概念，这是理解后续栈溢出与 ROP 的前提。

### 栈溢出

#### 触发前提
- 程序必须向栈上写入数据
- 写入的数据大小**未被限制**（缺乏边界检查）

#### 常见危险函数
| 类别 | 函数 |
|------|------|
| 输入 | `gets`、`scanf`、`vscanf` |
| 输出 | `sprintf` |
| 字符串操作 | `strcpy`、`strcat` |

> 这些函数不检查目标缓冲区大小，是栈溢出的主要诱因。

#### 简单利用步骤
1. **寻找溢出点** —— 定位调用危险函数的代码位置
2. **确定偏移距离** —— 计算从缓冲区起始到返回地址的字节数
3. **编写 Exploit** —— 构造覆盖返回地址的 Payload，劫持控制流

### 栈保护机制

| 机制 | 核心原理 | 防御目标 |
|------|----------|----------|
| **RELRO** (Relocation Read-Only) | 将 GOT 表设为只读，或启动时绑定所有动态符号 | 防止 GOT 覆写攻击 |
| **Canary** (栈保护 Cookie) | 在栈帧中插入随机值，函数返回前校验 | 检测栈缓冲区溢出 |
| **NX** (No-eXecute) / **DEP** | 标记栈/堆内存页不可执行 | 阻止直接执行 Shellcode |
| **PIE** (Position Independent Executable) / **ASLR** | 程序加载基址、库基址、栈/堆基址随机化 | 增加地址预测难度 |

> 现代 Linux 发行版通常默认开启上述全部或大部分防护，单纯栈溢出注入 Shellcode 已难以直接利用。

### ROP (Return-Oriented Programming)

#### 核心思想
在栈缓冲区溢出可控制返回地址的前提下，**利用程序现有代码片段** —— 即 **Gadgets**（以 `ret` 结尾的短指令序列） —— 串联成 **ROP 链**，实现任意寄存器/内存写入、函数调用等效果，绕过 NX 保护。

#### 利用条件
1. 程序存在可控的栈溢出，**能覆盖返回地址**
2. 能在二进制或加载的共享库中找到满足需求的 Gadgets，且**知道其地址**
3. 若开启 **PIE/ASLR**，需先通过**信息泄露**获取代码基址，再计算 Gadget 绝对地址

#### 典型 Gadget 示例
```
pop rdi; ret        # 控制第一个函数参数 (x64)
pop rsi; pop r15; ret
mov rax, [rdi]; ret # 任意地址读
syscall; ret        # 触发系统调用
```

> 图片中展示了一个简单的 ROP 链构造示意（原文配图 `a5a42b64c9b27997a6bfe463a42bf940.png`）。

---

## 主讲人简介

**于丁**
- 西安交通大学计算机专业大三学生
- CTF 资深选手（自称“拖后腿的赛狗”）
- 研究方向：二进制安全
- 乐于技术交流，欢迎各种形式的勾搭

---

## 关联资源与延伸阅读

- [[0w1club-week10-web-injection-training]] —— 第十期 Web 注入专题
- [[0w1club-week2-wifi-hijacking-arp-spoofing]] —— 第二周 WiFi 劫持与 ARP 欺骗
- [[0w1club-training-shellshock-cgi-exploitation]] —— Shellshock 漏洞渗透测试实战
- [[0w1club-week8-wireshark-arp-mitm-training]] —— 第八期 Wireshark 抓包与中间人攻击
- [[burpsuite-basics-tutorial]] —— Burp Suite 入门教程（同源 0w1Club 归档）
- [[metasploit-framework-basics-tutorial]] —— Metasploit Framework 基础教程
- [[ctftime-writeup-digest-20210325]] —— CTFtime Writeup 汇总（含 PWN 方向）
- [[daily-security-digest-20191202]] —— 每日安全看点（含 ret2dlresolve 技术分析，属于进阶 ROP 利用）

---

## 版本历史

- **2018-04-15** 初版发布（微信公众号原文）
- **2025-08-27** 知识库结构化整理，增加交叉引用与表格汇总

---

> 页面来源：0w1Club 微信公众号文章《培训总结 | 第七周》（归档于 [[0w1club-wechat-archive-201707-201903]] 与 [[0w1club-wechat-archive-201908-202207]]）。

## 来源

- [0w1网络安全俱乐部-201707-201903_33](../sources/0w1网络安全俱乐部-201707-201903_33.md)
