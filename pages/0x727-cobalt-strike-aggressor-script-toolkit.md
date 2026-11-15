---
title: 0x727 Cobalt Strike Aggressor Script 工具包
description: 0x727团队开源的Cobalt Strike Aggressor Script工具包，集成Mimikatz凭证导出、Bloodhound域信息收集、FRP代理隧道、PrintSpooler提权、atexec横向移动、SpawnReflectiveC2域前置等红队实战功能模块
category: program-analysis
tags:
- '0x727'
- Cobalt Strike
- Aggressor Script
- 红队工具
- Mimikatz
- Bloodhound
- FRP
- PrintSpooler
- atexec
- SpawnReflectiveC2
- 域前置
- 内网渗透
- 横向移动
- 提权
- 凭证导出
date: '2020-07-10'
updated: '2026-11-15'
---

## 概述

**0x727 Cobalt Strike Aggressor Script 工具包** 是由 0x727 安全团队开源的一套基于 Cobalt Strike Aggressor Script 标准的红队渗透测试工具集。该项目将多个 Aggressor Script 与配套 PE 文件整合为单一 CNA 工具包，加载至 Cobalt Strike 后即可在图形界面中快速调用多种后渗透功能模块，覆盖凭证获取、域环境侦察、代理隧道、提权、横向移动、C2 流量隐匿等核心实战场景。

> **项目定位**：集成多个 AggressorScripts 与多个 PE 文件形成一个 CNA 工具包，只需要加载到 Cobalt Strike 上即可享受便捷、快速的渗透之旅。  
> **作者**：Rvn0xsy  
> **团队**：0x727  
> **语言**：Aggressor Script、C++、C#  

## 功能模块

### Mimikatz 系列

工具包深度集成 Mimikatz 功能，通过 Aggressor Script 封装常用命令，实现一键式凭证窃取与票据操作：

- **哈希传递** —— 直接利用 NTLM 哈希进行认证
- **DcSync** —— 域控同步获取域内所有用户哈希
- **克隆管理员到 Guest** —— 将管理员权限克隆至 Guest 账户实现权限维持
- **抓取明文密码** —— 从 LSASS 内存中提取明文凭据
- **Skeleton Key 后门** —— 部署任意认证后门（Mimikatz Skeleton）
- **获取 krbtgt Hash** —— 为黄金票据制作提供核心材料
- **创建黄金票据** —— 伪造 Kerberos TGT 实现持久化域控访问
- **访问令牌操作** —— 列举、提权、假冒访问令牌

> 相关技术深度解析：[[mimikatz-sekurlsa-pth-internals]]、[[mimikatz-source-code-architecture-golden-ticket-audit]]

### Procdump / Lazagne / Navicat 凭证导出

提供三种互补的凭证获取路径：

- **一键转储 lsass.exe 内存** —— 调用 Procdump 生成转储文件供离线分析
- **一键执行 Lazagne** —— 综合提取浏览器、数据库、邮件客户端等 100+ 软件存储的凭证（文件较大，需等待加载）
- **一键读取 Navicat 密码** —— 专门针对 Navicat 数据库管理工具的连接凭证解密

### Bloodhound 域信息收集

内置两种执行模式，适应不同目标环境：

- **PowerShell 版本** —— 适用于 PowerShell 可用的标准域环境
- **C# 版本** —— 适用于受限 PowerShell 或开启 AMSI 的环境，通过反射加载避免落地

> 域环境侦察与横向移动实战参考：[[xd-security-internal-network-penetration-notes-day67-68]]、[[xd-security-internal-network-penetration-notes-day69-70]]

### FRP 代理隧道

- **一键配置 FRP 代理** —— 自动化生成 frpc/frps 配置并部署 SOCKS5 隧道，实现内网穿透与多级代理串联

> FRP 实战配置详解：[[frp内网渗透应用]]、[[internal-network-pivoting-techniques]]

### PrintSpooler 提权 (CVE-2020-1048 / PrintNightmare 前身)

- **PrintSpool 打印机提权** —— 利用打印后台处理程序服务漏洞实现本地权限提升

### atexec 横向移动

- **atexec 横向移动** —— 基于任务调度服务通过 SMB 远程执行命令，无需落地可执行文件，适合隐蔽横向

> 横向移动技术体系：[[xd-security-internal-network-penetration-notes-day65-66]]、[[smb-named-pipe-c2-communication]]、[[named-pipe-smb-detection-sysmon]]

### SpawnReflectiveC2 域前置 C2

- **SpawnReflectiveC2 功能** —— 通过反射 DLL 注入派生域前置 C2 Beacon，利用 CDN/高信誉域名隐匿 C2 流量真实指向
- **更新 Aliyun C2 反射 DLL** —— 针对阿里云 CDN 域前置场景的专用反射加载器

> C2 基础设施隐匿技术：[[c2-redirectors-malleable-c2-profiles]]、[[cobalt-strike-external-c2-smb-beacon]]、[[covenant-c2-framework-analysis]]

### 钉钉机器人告警

- **跨平台钉钉机器人脚本** —— 重写适配 macOS、Windows 10、 Linux，实现上线提醒、关键操作告警自动化推送

## 更新日志

| 日期 | 核心变更 |
|------|----------|
| 2020-01-08 | 新增 Mimikatz 全套功能（哈希传递、DcSync、Skeleton Key、黄金票据、令牌操作等） |
| 2020-01-08 | 新增 FRP 一键代理、Navicat 密码读取、浏览器密码导出 |
| 2020-03-11 | 新增钉钉机器人提醒功能 |
| 2020-07-07 | 新增 PrintSpooler 提权、atexec 横向移动、整合提权脚本至 elevate.cna、SpawnReflectiveC2 域前置、钉钉机器人跨平台重写、修复 PowerShell 脚本加载问题 |
| 2020-07-10 | 更新阿里云 CDN 域前置专用反射 DLL（暂建议使用 x86 版本，Cobalt Strike 4.0 进程位数判断存在已知问题） |

## 相关知识点与学习资源

项目文档建议配合以下技术专题学习：

1. **Cobalt Strike Aggressor Script（第一课/第二课）** —— 脚本语法、API、UI 扩展、事件驱动模型
2. **反射 DLL 注入构建后渗透模块（第一课）** —— BOF 开发、内存加载、导入表修复
3. **如何实现 atexec** —— 任务调度服务 RPC 接口、SMB 命名管道通信、输出回读机制
4. **如何实现 psexec** —— 服务控制管理器远程创建服务、管道通信、服务清理

> Cobalt Strike 核心组件技术内幕：[[cobalt-strike-4.7-bof-internals]]、[[cobalt-strike-external-c2-smb-beacon]]、[[ppl-injection-createprocess-bof-fix]]

## 贡献指南

项目遵循标准开源协作流程：

- **问题反馈** —— 通过 GitHub Issues 提交，便于检索与去重
- **Bug 修复** —— 直接向 `dev` 分支提交 Pull Request
- **新功能** —— 先创建 Issue 描述需求与实现思路，讨论通过后再提交 PR
- **文档改进** —— 欢迎完善中英文文档，降低上手门槛
- **分支策略** —— `dev` 分支接受开发提交，`master` 仅用于发布稳定版
- **联系方式** —— 0x727Team@gmail.com

## 0x727 团队生态关联项目

| 项目 | 说明 | 交叉引用 |
|------|------|----------|
| **MetasploitCoop** | 基于 Metasploit Framework 的可视化后渗透协作平台，旨在作为 Cobalt Strike 替代品 | [[metasploitcoop-collaboration-platform]] |
| **ObserverWard** | Rust 编写的 Web 指纹识别工具，配套社区化指纹库 FingerprintHub | [[observerward-0x727-web-fingerprint-tool]] |
| **SchTask** | 计划任务持久化工具，支持隐藏 XML、XML 文件隐藏、绕过 EDR 检测 | [[schtask-persistence-tool]] |
| **BugReporter** | 漏洞报告自动化生成平台，支持项目协同、模板化导出、Nginx 安全加固 | [[0x727-bugreporter-automated-report-platform]] |
| **团队微信归档** | 2021.08-2021.10 文章索引，含 AI 安全、红队工具开源发布记录 | [[0x727-security-team-wechat-archive-202108-202110]] |

## 实战案例交叉引用

以下实战案例展示了本工具包核心功能在真实红队行动中的组合应用：

- **Shiro RCE 内网渗透全链路** —— 初始访问 → 火绒免杀上线 CS → NTLM 导出 → FTP 大规模横向 → 威胁溯源发现前置攻击者痕迹：[[shiro-internal-penetration-case-study]]
- **上市公司渗透测试** —— 文件上传 Getshell → 哥斯拉上线 MSF → 会话传递 CS → SOCKS 代理横向 → MSSQL xp_cmdshell → IoT/OT 设备失陷：[[listed-company-penetration-test-case-study]]
- **0x6270 安服实战** —— SQL 注入 DBA → xp_cmdshell OS Shell → CS 上线 → 影子用户 + SOCKS 代理 → fscan/RDP/IPC$/WMI/FTP 组合横向 → 两天拿下 40+ 主机：[[0x6270-penetration-test-case-study-2023]]
- **XD安全内网渗透课程实战** —— 域环境信息收集、凭证获取、atexec/smbexec/wmiexec 横向、Kerberoasting、CS 团队服务器部署、SOCKS 代理三层内网穿透：[[xd-security-internal-network-penetration-notes-day65-66]]、[[xd-security-internal-network-penetration-notes-day67-68]]、[[xd-security-internal-network-penetration-notes-day69-70]]

## 使用方法

1. 启动 Cobalt Strike 客户端连接 Team Server
2. `Script Manager` → `Load` 选择本工具包 `.cna` 文件
3. 在 Beacon 右键菜单或顶部工具栏中调用对应功能模块
4. 部分功能（如 Lazagne、FRP）需等待依赖文件释放完成

> **注意**：Cobalt Strike 4.0 存在进程位数判断问题，SpawnReflectiveC2 相关模块建议暂时使用 x86 版本测试。

## 参考链接

- 原文发布：0x727 团队微信公众号（2020-07-10 更新版）
- 项目托管：GitHub（详见原文「阅读原文」下载链接）

## 来源

- [0x727开源安全团队-202108-202110_6](../sources/0x727开源安全团队-202108-202110_6.md)
