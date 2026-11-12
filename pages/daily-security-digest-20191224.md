---
title: 2019年12月24日每日安全看点汇总
description: 汇总2019年12月24日安全资讯，涵盖内网穿透端口转发合集、PHP一句话木马分析、零知识证明加密货币安全风险、PHP动态特性捕捉与逃逸、Hypervisor入门教程等安全技术资讯
category: ai-security
tags:
- 每日安全看点
- 内网穿透
- 端口转发
- PHP木马
- 零知识证明
- 加密货币安全
- PHP动态特性
- Hypervisor
- 虚拟化安全
- 2019年12月
date: '2019-12-24'
updated: '2026-11-12'
---

## 概述

本页面汇总 2019 年 12 月 24 日发布的每日安全看点，涵盖内网渗透技术、PHP WebShell 分析、区块链加密货币安全、PHP 语言动态特性利用与防御、虚拟化 Hypervisor 入门等五个方向的技术文章链接与核心知识点。

---

## 内网穿透及端口转发大合集

**来源**：先知社区  
**链接**：<https://xz.aliyun.com/t/6966>

### 核心内容
系统梳理内网渗透阶段常用的端口转发与隧道技术，涵盖：
- **LCX / PortMap / EarthWorm / Termite / reGeorg / Neo-reGeorg / Tunna / ABPTTS** 等经典转发工具用法
- **SSH 隧道**（本地/远程/动态转发）、**RDP 隧道**、**Socks4/5 代理**搭建
- **Meterpreter** 路由添加、端口转发、Socks 代理模块实战
- **frp / nps / nps-go** 等现代化内网穿透框架配置示例
- **DNS 隧道**、**ICMP 隧道**、**HTTP/HTTPS 隧道** 等隐蔽通道技术

### 关联页面
- [[frp内网渗透应用]] — frp 在内网渗透中四大典型应用场景的完整配置与拓扑说明
- [[daily-security-digest-20191225]] — 次日看点包含机器学习测试 WAF、Django 密码重置漏洞等内容
- [[daily-security-digest-20191226]] — 后续看点涵盖 FLIRT 符号恢复、Binary Ninja 去混淆、区块链教程等

---

## 浅谈 PHP 一句话木马

**来源**：先知社区  
**链接**：<https://xz.aliyun.com/t/6957>

### 核心内容
- **一句话木马分类**：`eval` 类、`assert` 类、`preg_replace /e` 修饰符类、`create_function` 类、`include/require` 文件包含类
- **免杀对抗**：编码混淆（Base64、Rot13、Unicode）、变量函数调用、动态函数构造、数组回调利用（`array_map`/`array_filter`/`uasort` 等）
- **流量特征与检测**：特征码匹配、语义分析、机器学习分类器对抗
- **实战场景**：结合文件上传、模板注入、反序列化等漏洞落地

### 关联知识点
- PHP 动态特性（见第 4 节）是一句话变形的理论基础
- 结合 [[zzzphp-cve-2021-32605-rce]]、[[zzzcms-v1.7.5-audit]] 等 CMS 审计案例可理解实战落地链条

---

## 零知识证明加密货币安全风险

**来源**：360 安全博客  
**链接**：<http://blogs.360.cn/post/Security-Risks-in-Zero-Knowledge-Proof-Cryptocurrencies.html>

### 核心风险点
| 风险类别 | 说明 |
|----------|------|
| **可信设置攻击** | Zcash 等依赖可信设置的协议，若毒化废料泄露可伪造证明 |
| **电路实现漏洞** | R1CS/Plonk 电路编码错误导致约束绕过（如双花、铸币） |
| **侧信道攻击** | 证明生成过程中的时序/功耗泄露私有输入 |
| **递归合成风险** | Halo/Plonky2 等递归零知识证明的累积误差与验证器漏洞 |
| **量子威胁** | 配对友好曲线（BLS12-381、BN254）在量子计算机下的安全性退化 |

### 防御建议
- 采用多方计算（MPC）仪式生成通用参考串（Universal Setup）
- 形式化验证电路代码（Circom + Lean/Coq）
- 监控链上异常证明提交，部署异常熔断机制

---

## PHP 动态特性捕捉与逃逸

**来源**：LTeam / 先知社区（leavesongs.com）  
**链接**：<https://www.leavesongs.com/PENETRATION/dynamic-features-and-webshell-tricks-in-php.html>

### 核心技术点
| 动态特性 | 典型利用方式 | 检测难点 |
|----------|--------------|----------|
| **变量函数/变量类/变量方法** | `$func = 'system'; $func('id');` | 静态分析难以解析动态调用图 |
| **匿名函数与闭包** | `call_user_func(function(){...});` | 运行时才确定代码块 |
| **`eval` / `assert` / `preg_replace('/e')`** | 代码字符串动态执行 | 特征码极易变形 |
| **`create_function` / `ReflectionFunction`** | 运行时构造可执行单元 | 绕过函数名黑名单 |
| **数组回调利用** | `array_map('assert', $_POST);` | 合法函数被滥用 |
| **动态文件包含** | `include $_GET['file'];` | 路径遍历+协议封装（php://filter/zip:///data://） |
| **魔术方法触发** | `__wakeup`/`__destruct`/`__call` 反序列化链 | 对象图构造复杂 |

### 逃逸与对抗思路
1. **语法层面**：利用 PHP 宽松语法（反引号执行、`${'system'}('id')`、短标签 `<?= ... ?>`）
2. **编码层面**：多层编码嵌套、字符拼接、十六进制/八进制转义
3. **运行时层面**：`register_shutdown_function`、`auto_prepend_file`、`.user.ini` 注入
4. **内存马**：`opcode` 篡改、扩展劫持、FPM 主进程注入

### 关联页面
- [[zzzcms-v1.7.5-audit]] — 模板引擎 parserIfLabel 过滤绕过导致的后台 RCE 利用链
- [[zzzphp-cve-2021-32605-rce]] — 模板渲染处理 if 标签时过滤不当导致前台无条件 RCE
- [[diwuzhijian-2020-web-writeup]] — PHP assert() RCE 绕过、反序列化不可见字符利用、Laravel POP 链构造

---

## 从头开始了解和使用 Hypervisor（第 1 部分）

**来源**：微信公众号（安全学术/虚拟化安全方向）  
**链接**：<https://mp.weixin.qq.com/s/whYu9cZMmWbnUWEYxbJ9QA>

### 核心知识框架
| 模块 | 关键概念 |
|------|----------|
| **虚拟化分类** | Type-1 (Bare-metal: VMware ESXi, Hyper-V, KVM) vs Type-2 (Hosted: VMware Workstation, VirtualBox) |
| **CPU 虚拟化扩展** | Intel VT-x (VMX)、AMD-V (SVM)、ARMv8 EL2/Hypervisor 模式 |
| **内存虚拟化** | EPT (Extended Page Tables)、NPT (Nested Page Tables)、VPID、EPT Violation/#VE |
| **I/O 虚拟化** | 完全虚拟化、准虚拟化、SR-IOV、virtio、vhost/vhost-user、VFIO |
| **核心数据结构** | VMCS (VMX)、VMCB (SVM)、VCPU、Guest/Host State Area、VM-Exit/VM-Entry 控制字段 |
| **生命周期事件** | VM-Entry、VM-Exit (External Interrupt, EPT Violation, CPUID, MSR Access, IO Instruction 等) |
| **嵌套虚拟化** | L0/L1/L2 层级、VMCS Shadowing、EPT Paging、性能开销分析 |

### 学习路径建议
1. **理论基础**：Intel SDM Vol.3C / AMD APM Vol.2 / ARM ARM DDI 0487
2. **代码阅读**：KVM (arch/x86/kvm/vmx.c, svm.c)、Hypervisor.framework、SimpleVisor、Bareflank、rust-vmm
3. **实验环境**：开启 VT-x/AMD-V 的物理机 + Linux 内核调试（kgdb/KVM-unit-tests）
4. **进阶方向**：VMM 内存安全（Rust VMM）、Hypervisor Fuzzing (kAFL、Hyper-Cube)、虚拟化逃逸漏洞挖掘 (CVE-2017-4924, CVE-2019-5544 等)

---

## 关联安全看点系列

| 日期 | 页面 | 核心看点 |
|------|------|----------|
| 2019-12-25 | [[daily-security-digest-20191225]] | 机器学习测试 WAF、Django CVE-2019-19844、BurpSuite 插件、DarkRat 面板入侵、Empire 3.0 |
| 2019-12-26 | [[daily-security-digest-20191226]] | FLIRT 符号恢复、Binary Ninja 去混淆、OLLVM、区块链教程、Fuzzing 会议 |
| 2019-12-27 | [[daily-security-digest-20191227]] | Web API 安全、Google Cloud Shell 漏洞、ATT&CK 实战、iOS 代码签名、SOP 绕过 |
| 2019-12-30 | [[daily-security-digest-20191230]] | Google XSS 技巧、Metasploit DoS CVE-2019-5645、移动端渗透测试 4-6、Fuzzing 艺术 |

---

## 标签索引

`#每日安全看点` `#内网穿透` `#端口转发` `#PHP木马` `#零知识证明` `#加密货币安全` `#PHP动态特性` `#Hypervisor` `#虚拟化安全` `#2019年12月`

## 来源

- [0th3rs安全团队-201911-202204_105](../sources/0th3rs安全团队-201911-202204_105.md)
