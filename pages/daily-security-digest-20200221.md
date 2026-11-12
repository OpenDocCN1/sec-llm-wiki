---
title: 每日安全看点 2020-02-21
description: 汇总 2020 年 2 月 21 日每日安全看点，涵盖 Tomcat AJP 协议文件读取漏洞 (CVE-2020-1938)、iOS 虚拟机
  UTM、免杀工具综合评估及网安慕课资源。
category: ai-security
tags:
- 每日安全看点
- Tomcat
- AJP协议
- CVE-2020-1938
- 文件读取漏洞
- UTM
- iOS虚拟机
- 免杀工具
- 网安慕课
- 2020年2月
date: '2020-02-21'
updated: '2026-11-12'
---

## 概述

本期每日安全看点聚焦于 **Tomcat AJP 协议高危漏洞 (CVE-2020-1938)** 的 POC 与深度分析、iOS 平台虚拟机方案 **UTM**、一篇 **免杀工具综合评估** 文章，以及 **网安慕课资源汇总**。同期（2020 年 2 月下旬）的其他每日看点可参考：[[daily-security-digest-20200224]]、[[daily-security-digest-20200225]]、[[daily-security-digest-20200226]]、[[daily-security-digest-20200227]]。

---

## Tomcat AJP 协议文件读取漏洞 (CVE-2020-1938)

### 漏洞背景
Apache Tomcat 的 AJP (Apache JServ Protocol) 连接器存在缺陷，攻击者可利用该漏洞读取或包含服务器上任意文件（LFI），进而可能导致敏感信息泄露或远程代码执行（配合文件上传）。编号 **CVE-2020-1938**，国内编号 **CNVD-2020-10487**。

### 公开 POC 与利用代码
- **GitHub 仓库**：[YDHCUI/CNVD-2020-10487-Tomcat-Ajp-lfi](https://github.com/YDHCUI/CNVD-2020-10487-Tomcat-Ajp-lfi.git)  
  提供可直接运行的 Python/Go 版本 POC，支持批量检测与文件读取演示。

### 深度分析文章
- **微信公众号长文**：[CVE-2020-1938: Apache Tomcat 服务器任意文件读取/包含漏洞分析](https://mp.weixin.qq.com/s/GzqLkwlIQi_i3AVIXn59FQ)  
  详细拆解 AJP 协议处理流程、漏洞触发条件、属性操纵细节及修复建议。

### 影响版本与缓解
| 组件 | 受影响版本 | 修复版本 |
|------|------------|----------|
| Tomcat 9 | 9.0.0.M1 – 9.0.30 | ≥ 9.0.31 |
| Tomcat 8 | 8.5.0 – 8.5.50 | ≥ 8.5.51 |
| Tomcat 7 | 7.0.0 – 7.0.99 | ≥ 7.0.100 |
| Tomcat 6 | 全版本 | 无官方修复，建议升级 |

**临时缓解**：若暂时无法升级，可在 `server.xml` 中注释掉 AJP 连接器（`protocol="AJP/1.3"`），或在防火墙层面限制 8009 端口仅受信任 IP 访问。

---

## iOS 虚拟机：UTM

### 项目简介
**UTM** 是一款基于 QEMU 的全系统模拟器，可在 **iOS / iPadOS / macOS** 上运行 Windows、Linux、macOS 等客户机操作系统。采用 JIT 加速（需越狱或自签名），支持 SPICE/VNC 显示、USB 重定向、共享目录等功能。

### 核心特性
- **架构支持**：x86, x86_64, ARM, ARM64, RISC-V, SPARC, MIPS 等
- **图形后端**：Metal / OpenGL ES / VirtIO-GPU
- **管理方式**：原生 SwiftUI 界面，支持导入/导出 VM 配置、快照、克隆
- **分发渠道**：TestFlight 公测、GitHub Release、AltStore 自签安装

### 资源链接
- **GitHub 主页**：[utmapp/UTM](https://github.com/utmapp/UTM)
- **文档与 Wiki**：[UTM Documentation](https://docs.getutm.app/)
- **社区交流**：Reddit r/UTM、Discord 频道

### 典型用例
1. **安全研究**：在 iPad 上运行带桌面环境的 Kali Linux，配合 Frida/Objection 进行移动应用动态分析。
2. **跨平台测试**：验证 Windows/macOS 专用工具（如 IDA Pro、Ghidra）在 ARM64 下的兼容性。
3. **教学演示**：随身携带完整 Linux 内核开发环境，配合 VS Code Remote-SSH 远程编码。

---

## 免杀工具综合评估

### 文章来源
- **微信公众号**：[一篇免杀工具综合评估](https://mp.weixin.qq.com/s/WdErH1AOaI3B5Kptu7DK5Q)

### 评估维度（摘要）
| 维度 | 说明 |
|------|------|
| **静态免杀率** | 对主流 AV（Windows Defender、360、火绒、卡巴斯基等）静态查杀引擎的绕过效果 |
| **动态免杀率** | 沙箱/EDR 行为监控（API 调用序列、进程树、内存扫描）的规避能力 |
| **易用性** | 命令行参数复杂度、配置文件支持、模块化程度 |
| **维护活跃度** | 近半年提交频率、Issue 响应、规则更新速度 |
| **生态兼容性** | 对 Cobalt Strike、Metashellcode、自定义 Loader 的适配情况 |

### 典型工具对比（节选）
| 工具 | 语言 | 免杀思路 | 近期更新 |
|------|------|----------|----------|
| **Donut** | C | .NET 程序集加载 → 非托管 Shellcode | 2023 年仍活跃 |
| **sRDI** | C | 反射式 DLL 注入 + 系统调用混淆 | 2022 年归档 |
| **PeToSh** | Go | PE 转 Shellcode + 资源加密 | 2021 年停更 |
| **Freeze** | Go | 进程空洞 + 线程劫持 + 系统调用 | 2023 年维护中 |

> **提示**：免杀对抗属于攻防博弈常态，评估结果具有时效性。实战建议采用“多层免杀 + 流量混淆 + 行为模拟”组合策略，并持续对目标环境进行**定向测试**。

---

## 网安慕课资源汇总

### 平台入口
- **i春秋慕课专区**：[https://www.ichunqiu.com/mooc/course](https://www.ichunqiu.com/mooc/course?from=timeline&isappinstalled=0)

### 课程分类示例
| 方向 | 代表课程 | 难度 | 备注 |
|------|----------|------|------|
| **Web 安全** | 《SQL 注入原理与利用》《XSS 跨站脚本攻防》《文件上传绕过实战》 | 入门-进阶 | 配套靶场 |
| **二进制/逆向** | 《Windows 核心编程》《Android SO 逆向入门》《IDA Pro 权威指南实战》 | 进阶 | 需 C/C++ 基础 |
| **内网渗透** | 《域渗透核心技术》《Cobalt Strike 实战》《免杀与持久化》 | 进阶-高级 | 强调实战复现 |
| **应急响应** | 《Linux 入侵排查》《Windows 日志分析》《挖矿木马溯源》 | 入门 | 含取证工具链 |
| **代码审计** | 《PHP 代码审计入门》《Java 反序列化漏洞挖掘》《Go 安全编码规范》 | 进阶 | 需语言基础 |

### 学习建议
1. **按路径学**：先完成《网络安全入门》《Linux 基础》夯实底座，再按方向深入。
2. **动手为主**：每节课配套的靶场/脚本务必亲自跑通，记录关键命令与排坑过程。
3. **产出笔记**：将核心知识点整理为个人 Wiki（如 Obsidian/Notion），形成可检索的知识库。
4. **社群互动**：加入课程配套 QQ/微信群、i春秋论坛，参与周赛、月赛强化实战感。

---

## 关联阅读
- [[daily-security-digest-20200224]] — 2020-02-24 每日安全看点（Android 厂商漏洞披露、APT TTPs、Linux SUID 提权、疫情追踪隐私）
- [[daily-security-digest-20200225]] — 2020-02-25 每日安全看点（RSAC 2020、Docker 安全、SWD/OpenOCD、MariaDB CVE-2020-7221）
- [[daily-security-digest-20200226]] — 2020-02-26 每日安全看点（LLVM/Clang Pass、账号接管、挖矿木马应急、Linux 内核栈溢出、Windows Defender 驱动分析）
- [[daily-security-digest-20200227]] — 2020-02-27 每日安全看点（Django PostgreSQL 注入、微盟删库、sudo 历史漏洞、PHP 静态查杀绕过）

---

## 更新日志
| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2020-02-21 | 1.0 | 初始版本，汇总当日安全看点 |
| 2025-09-23 | 1.1 | 迁移至知识库，补充结构化表格、跨引用与缓解建议 |

---
*页面归档自微信公众号「每日安全看点」2020-02-21 期内容，仅供安全研究与学习参考。*

## 来源

- [0th3rs安全团队-201911-202204_077](../sources/0th3rs安全团队-201911-202204_077.md)
