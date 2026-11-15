---
title: MetasploitCoop：基于 Metasploit Framework 的可视化后渗透协作平台
description: 记录 0x727 团队开源的 MetasploitCoop 项目，一个基于 Metasploit Framework 的可视化后渗透协作平台，支持团队协作、模块中文化、Docker
  部署、原生 MSF 控制台等核心功能，旨在作为 Cobalt Strike 替代品。
category: program-analysis
tags:
- '0x727'
- Metasploit
- Metasploit Framework
- 后渗透
- 协作平台
- C2
- Cobalt Strike 替代品
- Docker
- 红队工具
- 开源项目
- 内网渗透
- 团队协作
date: 2020-10-20
updated: '2026-11-15'
---
## 项目概述

**MetasploitCoop** 是 0x727 安全团队开源的一款**基于 Metasploit Framework 的可视化后渗透协作平台**。项目定位为 **Cobalt Strike 的开源替代品**，旨在最大限度地利用 Metasploit Framework 现有生态进行内网渗透，提供可视化操作界面与团队协作能力。

> **核心定位**：可视化 Metasploit Framework + 团队协作 + 中文化模块 + 原生 MSF 控制台支持

### 作者与团队

| 角色 | 信息 |
|------|------|
| **作者** | Akkuman ([github.com/akkuman](https://github.com/akkuman))、三米前有蕉皮 ([github.com/cn-kali-team](https://github.com/cn-kali-team)) |
| **团队** | 0x727 安全团队 |
| **开源协议** | 免费开源，欢迎社区贡献 |
| **联系邮箱** | 0x727Team@gmail.com |

## 核心功能特性

### 可视化与交互增强
- **可视化 Metasploit Framework 操作**：右键功能直达，类似 Cobalt Strike 的图形化交互体验
- **可视化执行模块**：参数填写、文件选择（支持从文件中转区选取）、实时回显结果
- **一键端口转发、路由添加**：简化内网穿透配置流程
- **原生 Metasploit Console 支持**：多人分离会话，不污染彼此环境

### 团队协作与管理
- **协作聊天**：内置即时通讯，支持团队成员消息收发
- **任务管理**：查看 MSF 执行中的任务、实时输出观察、强制结束卡死任务
- **主机列表与状态**：主机存活状态自动更新、会话回连 IP/端口展示
- **主机进程管理**：重要进程高亮显示（高亮列表可自定义）
- **主机文件管理 / 一键截屏**：截屏文件自动归入文件中转区，按 IP 分目录存放
- **凭据展示 / 战利品列表**：支持无限滚动加载，防止渲染卡死

### 历史与审计
- **模块执行历史记录**：主机级会话命令与模块执行记录可查阅
- **终端历史记录解析**：会话历史命令回溯

### 开箱即用的生态兼容性
- **理论上支持绝大多数 MSF 模块**：**无需修改模块代码**，编写标准 MSF 模块即可直接在平台使用
- **模块说明中文化**：内置绝大部分模块翻译，支持腾讯翻译君 API 实时翻译新增模块
- **可定制化右键菜单**：管理后台支持自定义右键快捷功能
- **Docker 重建后监听自动恢复**：容器重启自动恢复之前的监听任务

## 架构与代码仓库

MetasploitCoop 采用**前后端分离 + 修改版 MSF 核心**架构，主仓库为说明文档仓库，核心代码分布在以下子仓库：

| 仓库 | 说明 | 链接 |
|------|------|------|
| **MetasploitCoop-Backend** | 后端服务，核心业务逻辑、MSF RPC 封装、任务调度 | <https://github.com/0x727/MetasploitCoop-Backend> |
| **MetasploitCoop-Frontend** | 前端界面，可视化交互、WebSocket 实时通信 | <https://github.com/0x727/MetasploitCoop-Frontend> |
| **metasploit-framework** | 0x727 维护的 MSF 分支，适配平台特性（如模块中文化钩子） | <https://github.com/0x727/metasploit-framework> |
| **metasploit_data_models** | 数据模型层，支撑后端数据持久化与查询 | <https://github.com/akkuman/metasploit_data_models> |
| **MetasploitModules_0x727** | 团队维护的扩展模块库（见下文） | <https://github.com/0x727/MetasploitModules_0x727> |

**技术栈**：Ruby (MSF 核心)、Python (后端服务)、JavaScript (前端)

## 快速开始：Docker Compose 部署

### 获取代码
```bash
git clone https://github.com/0x727/MetasploitCoop.git
cd MetasploitCoop
```

### 启动服务
```bash
docker-compose up -d
```

### 验证启动
```bash
docker-compose logs
```
出现 `INFO supervisord started with pid 1` 即表示启动成功。

### 访问平台
打开浏览器访问：`https://127.0.0.1:60443`

> **默认凭据**：`msfcoop` / `DptbHd8R`（可在 `docker-compose.yml` 中修改）

### 环境变量扩展（可选）
| 环境变量 | 用途 |
|----------|------|
| `TENCENT_TRANSLATE_TOKEN_ID` | 腾讯翻译君 API SecretId，启用后支持新增模块实时中文翻译 |
| `TENCENT_TRANSLATE_TOKEN_KEY` | 腾讯翻译君 API SecretKey |

平台已内置绝大部分模块翻译，配置该变量可覆盖增量模块。

## 使用指南

### 初始化与登录
- 首次访问需输入默认凭据并保存，随后进入注册/登录页面
- 支持修改 C2 服务器地址：前端可编译为独立客户端（当前仅 Windows），挂载至其他部署实例
- 登录后底部提供团队聊天通道

### 监听器管理
- 点击顶部 **「添加监听」** 创建监听任务
- **端口范围限制**：必须在 `docker-compose.yml` 映射的 `7000-7500` 范围内
- **监听地址**：勿填 `0.0.0.0`，需填写真实回连 IP（用于 Payload 生成）

### Payload 生成与上线
- 在 **任务管理** 中右键监听任务 → **生成 Payload**
- 参数选项与原生 MSF 一致，支持文件中转区直接选取文件型参数
- 上线后自动提示，主机列表实时刷新

### 会话交互（右键菜单）
右键在线主机可执行：
- **截屏**：自动保存至文件中转区，按 IP 分目录
- **进程管理**：查看进程列表，关键进程高亮（可在设置中编辑高亮规则）
- **文件管理**：浏览、上传、下载，支持无限滚动与搜索
- **模块执行**：可视化参数填写，执行完成自动回显；卡顿可进入任务管理查看实时输出/结束任务
- **端口转发 / 路由添加**：一键配置内网穿透

### 管理后台配置
- **右键自定义菜单**：定制快捷功能
- **模块翻译管理**：维护中文化语料
- **进程高亮管理**：设置关键进程名单
- **注册开关**：可关闭公开注册，增强安全性

## 扩展模块库：MetasploitModules_0x727

团队维护的专用模块库，已集成至平台，示例模块：

| 模块名 | 功能描述 |
|--------|----------|
| `mssql_powershell` | 凭据正确时启用 `xp_cmdshell` 并获取 System Session |
| `clone_user` | 创建账户、加入管理员/远程桌面组、克隆 Administrator（支持 RID 劫持、随机密码、尝试提权） |
| `redis/unauthorized` | 批量扫描 Redis 未授权，探测 SSH/Cron 目录权限，支持写入公钥或 Cron 反弹 |
| `post/windows/manage/execute_pe` | **内存执行 EXE**（需目标 EXE 含 `.reloc` 节，如 Go 编译二进制；架构需匹配） |

> 更多模块见：<https://github.com/0x727/MetasploitModules_0x727>

## 更新日志精选

### 2020-10-18 重大更新
- 新增：文字聊天、模块选项提示说明、会话路由操作、历史命令/模块记录查询
- 新增：截图按 IP 分目录、会话回连公网 IP 展示、关闭注册开关、可配置右键菜单
- 优化：文件管理/战利品/凭证列表无限滚动、主机用户名显示修正、列表拖拽调整列宽、主机存活状态自动更新
- 集成：`MetasploitModules_0x727` 扩展模块库
- 新增：内存执行 EXE 模块、新增模块自动翻译、容器重启监听自动恢复、Windows 客户端支持、执行中任务实时输出查看

### 2020-10-20 修复版
- 修复：模块历史记录不显示、终端历史记录偶发解析错误
- 移除：前端 BasicAuth 认证

## 贡献指南

项目采用 **GitHub Flow** 工作流：

| 贡献类型 | 操作建议 |
|----------|----------|
| **问题反馈** | 提交 Issue，便于他人检索与避免重复回复 |
| **Bug 修复** | 直接向 `dev` 分支提交 Pull Request |
| **新功能** | 先创建 Issue 描述需求与实现思路，讨论通过后再提 PR 至 `dev` 分支 |
| **文档改进** | 欢迎完善中英文文档，特别是英文版 |
| **分支策略** | `master` 仅发布稳定版，开发请基于 `dev` 分支 |

## 关联项目与交叉引用

### 0x727 团队其他开源工具
- [[0x727-bugreporter-automated-report-platform]] —— 漏洞报告自动化生成平台（Python/PHP）
- [[observerward-0x727-web-fingerprint-tool]] —— ObserverWard Web 指纹识别工具（Rust）
- [[schtask-persistence-tool]] —— SchTask 计划任务持久化工具（C#）
- [[0x727-security-team-wechat-archive-202108-202110]] —— 团队微信归档索引（含 AI 安全、红队工具等）

### 核心依赖与对标技术
- [[metasploit-framework-basics-tutorial]] —— Metasploit Framework 基础教程（安装、msfvenom、后渗透、ProFTPd 实战）
- [[cobalt-strike-4.7-bof-internals]] —— Cobalt Strike 4.7 BOF 内部实现分析（对标对象）
- [[cobalt-strike-external-c2-smb-beacon]] —— Cobalt Strike External C2 与 SMB Beacon 通信模型
- [[covenant-c2-framework-analysis]] —— Covenant C2 框架架构解析（.NET 实现，HTTP/SMB P2P）

### 实战应用场景引用
- [[internal-network-pivoting-techniques]] —— 内网穿透/横向移动技术体系（含 MSF 路由、SOCKS 代理、C2 会话传递）
- [[frp内网渗透应用]] —— frp 内网渗透应用（含代理本地 MSF 反弹）
- [[xd-security-internal-network-penetration-notes-day69-70]] —— XD安全课程 Day69-70：CS 团队服务器、MSF 路由添加、SOCKS 代理、三层内网渗透演练
- [[listed-company-penetration-test-case-study]] —— 上市公司实战：文件上传 → 哥斯拉上线 MSF → 会话传递至 CS → Socks 代理横向
- [[shiro-internal-penetration-case-study]] —— Shiro RCE 实战：火绒免杀上线 CS、NTLM 导出、FTP 横向、威胁溯源

## 总结

MetasploitCoop 通过**可视化封装 + 团队协作 + 中文化生态 + Docker 化交付**，将 Metasploit Framework 从“单人命令行工具”升级为“可协作的红队作战平台”。其核心优势在于：

1. **零成本迁移**：现有 MSF 模块无需修改即可使用
2. **原生兼容**：保留原生 `msfconsole` 能力，支持多人隔离会话
3. **工程化交付**：Docker Compose 一键部署，容器重建自动恢复监听
4. **持续演进**：团队维护扩展模块库，持续补充实战化模块（如内存执行 EXE、MSSQL/Redis 利用链）

对于寻求 **Cobalt Strike 开源替代方案**、且已有 MSF 技术栈积累的红队/渗透测试团队，MetasploitCoop 是极具落地价值的选择。

## 来源

- [0x727开源安全团队-202108-202110_4](../sources/0x727开源安全团队-202108-202110_4.md)
