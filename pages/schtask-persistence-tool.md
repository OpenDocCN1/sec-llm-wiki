---
title: SchTask - 0x727团队开源C#隐藏计划任务持久化工具
description: 深度解析0x727安全团队开源的SchTask工具实现原理、使用方法及绕过杀软技术细节，涵盖隐藏计划任务创建、XML文件隐藏、持久化维持等核心技术点
category: program-analysis
tags:
- '0x727'
- SchTask
- 计划任务
- 持久化
- 权限维持
- C#
- 红队工具
- 免杀
- Windows Internals
- Task Scheduler
date: '2023-04-14'
updated: '2026-11-15'
---

## 概述

**SchTask** 是 0x727 安全团队（作者 AnonySec）开源的一款 C# 编写的隐藏计划任务持久化工具。该工具利用 Windows Task Scheduler API 创建隐藏的计划任务，通过绕过安全软件的阻断机制实现持久化控制。工具已将依赖库 `Microsoft.Win32.TaskScheduler.dll` 内嵌打包，发布版本为单文件 `SchTask.exe`（.NET Framework 2.0），便于实战快速部署。

> 项目地址：https://github.com/0x727/SchTask  
> 技术细节参考：《Windows计划任务的进阶》—— https://payloads.cn/2021/0805/advanced-windows-scheduled-tasks.html

## 核心功能定位

| 属性 | 说明 |
|------|------|
| **开发团队** | 0x727 |
| **作者** | AnonySec |
| **开发语言** | C# (.NET Framework 2.0) |
| **核心定位** | 权限维持、内存加载、持久化控制 |
| **对抗目标** | 安全软件拦截、计划任务审计、XML 文件可见性 |
| **依赖库** | `Microsoft.Win32.TaskScheduler.dll`（已内嵌） |

## 实现原理深度解析

### 核心执行流程（六步法）

工具通过以下六个关键步骤实现隐蔽持久化：

#### 随机进程名选取与伪装
- 从主机当前运行进程中随机选取一个合法进程名
- 该名称同时用于：**计划任务程序文件名**、**计划任务任务名**
- 目的：混淆视听，降低被排查概率

#### 载荷文件投放路径
```
%AppData%\Microsoft\Windows\Themes\<RandomProcessName>.exe
```
- 选择用户级 AppData 目录下的 Themes 文件夹
- 该路径为用户写入权限，无需提权即可落地
- 文件名与随机进程名一致，增强伪装性

#### 计划任务创建与触发器配置
- **任务名**：同随机进程名
- **触发器类型**：分钟级重复触发
- **持续模式**：无限期持续（`Repetition.Duration = TimeSpan.Zero` 表示无限期）
- **启动边界**：当前时间或近期时间，确保快速生效

#### **关键隐藏技术：Index 与 SD 键值篡改**
这是 SchTask 区别于常规 `schtasks.exe` 创建任务的核心对抗手段：

| 操作 | 目标 | 效果 |
|------|------|------|
| 更改 `Index` 键值 | `C:\Windows\System32\Tasks\<TaskName>` 对应的注册表/文件系统索引 | 破坏任务调度器对任务的正常枚举 |
| 删除 `SD` (Security Descriptor) 键值 | 任务的安全描述符 | 导致任务在 `taskschd.msc`、`schtasks /query`、PowerShell `Get-ScheduledTask` 中**不可见** |

> **技术细节**：Windows 计划任务的 XML 定义文件存放于 `C:\Windows\System32\Tasks\`，系统通过注册表 `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{GUID}` 中的 `Index` 与 `SD` 字段索引和权限控制任务。篡改这两个字段可使任务**在管理工具中隐形，但仍由任务调度服务正常执行**。

#### 任务清理功能
- 提供删除已添加计划任务的功能
- 支持按任务名精确清理，便于痕迹擦除与测试复原

### 对抗检测机制总结

| 检测层面 | 常规创建任务 | SchTask 隐藏任务 |
|----------|--------------|------------------|
| `taskschd.msc` 图形界面 | 可见 | **不可见** |
| `schtasks /query` | 可见 | **不可见** |
| `Get-ScheduledTask` | 可见 | **不可见** |
| `C:\Windows\System32\Tasks\` XML 文件 | 存在 | 文件存在但**索引失效** |
| 任务调度服务执行 | 正常 | **正常执行** |
| 杀软行为监控 | 易触发规则 | 进程名伪装 + 路径伪装 + 索引篡改，**绕过多数规则** |

## 使用指南

### 获取方式
```bash
# 方式一：GitHub Release 下载（推荐，已打包依赖）
# https://github.com/0x727/SchTask/releases

# 方式二：源码编译
git clone https://github.com/0x727/SchTask.git
# 使用 Visual Studio 打开解决方案，目标框架 .NET Framework 2.0 编译
```

### 命令行参数
```cmd
C:\> SchTask.exe
Usage: SchTask.exe <File Path> <Minutes>
Eg:    SchTask.exe C:\Windows\System32\cmd.exe 10
```

| 参数 | 说明 | 示例 |
|------|------|------|
| `<File Path>` | 要执行的程序绝对路径（建议系统签名二进制或自定义载荷） | `C:\Windows\System32\cmd.exe` |
| `<Minutes>` | 触发间隔（分钟），无限期重复 | `10` |

### 实战示例场景

#### 场景一：系统二进制持久化（Living-off-the-Land）
```cmd
SchTask.exe C:\Windows\System32\cmd.exe 5
```
- 每 5 分钟触发一次 `cmd.exe`，可配合参数执行后续命令
- 进程树：`svchost.exe (Task Scheduler) -> cmd.exe`，极难基于进程树溯源

#### 场景二：自定义载荷持久化
```cmd
# 前置：将载荷投放至伪装路径
copy beacon.exe %AppData%\Microsoft\Windows\Themes\OneDrive.exe
# 创建隐藏任务
SchTask.exe %AppData%\Microsoft\Windows\Themes\OneDrive.exe 15
```
- 载荷名伪装为 `OneDrive.exe`，路径在用户目录，权限友好
- 15 分钟心跳，平衡持久性与流量隐蔽性

#### 场景三：清理痕迹
```cmd
# 工具本身不提供直接删除命令，需手动清理：
# 1. 删除 %AppData%\Microsoft\Windows\Themes\<RandomName>.exe
# 2. 修复 C:\Windows\System32\Tasks\<RandomName> 的 Index 与 SD（或删除文件并重建索引）
# 3. 重启 Task Scheduler 服务：net stop schedule && net start schedule
```

## 检测与防御视角

### 主机层面检测思路

| 检测手段 | 实现要点 |
|----------|----------|
| **文件系统监控** | 监控 `%AppData%\Microsoft\Windows\Themes\` 下可执行文件创建/修改 |
| **注册表审计** | 监控 `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\` 下 `Index`、`SD` 键值异常变更 |
| **ETW 事件** | `Microsoft-Windows-TaskScheduler/Operational` 事件 ID 106（任务注册）、200/201（任务执行），关联进程命令行与创建者 |
| **内存扫描** | 扫描 `taskhostw.exe`、`svchost.exe` 托管的任务进程，关联异常模块加载 |
| **计划任务完整性校验** | 定期枚举 `C:\Windows\System32\Tasks\` 所有 XML，解析 `Actions`、`Triggers`、`Principals`，对比注册表索引一致性 |

### 网络/行为层面关联
- 结合 [[internal-network-pivoting-techniques]] 中的代理隧道检测，排查定时外连行为
- 关联 [[memory-scanning-tools-evasion-techniques]] 中的 UDRL 内存规避特征，识别任务启动进程的内存异常
- 参考 [[cobalt-strike-external-c2-smb-beacon]] 的心跳模式分析，识别固定间隔的 C2 通讯

### 缓解建议
1. **启用 AppLocker/WDAC** 限制 `%AppData%` 目录执行权限
2. **部署 Sysmon Event ID 1 (Process Create) + Event ID 12/13/14 (Registry)** 记录任务创建与注册表篡改
3. **定期校验任务索引完整性**，对比 `TaskCache\Tasks\{GUID}` 与 `Tasks\` 目录文件
4. **EDR 开启计划任务创建/修改/删除的行为拦截规则**，特别是针对 `Index`/`SD` 篡改

## 关联工具与技术生态

| 工具/技术 | 关联点 | 参考页面 |
|-----------|--------|----------|
| **Windows Task Scheduler API** | 核心调用接口 | [[xd-security-internal-network-penetration-notes-day65-66]] (schtasks 横向移动) |
| **Microsoft.Win32.TaskScheduler.dll** | 托管封装库 | — |
| **Cobalt Strike `execute-assembly`** | 可加载 SchTask.exe 进程内执行 | [[cobalt-strike-4.7-bof-internals]] |
| **Inceptor 框架** | 免杀加载器，可结合 SchTask 持久化 | [[inceptor-av-edr-evasion-framework]] |
| **PPL 注入绕过** | 高权限持久化替代方案 | [[ppl-injection-createprocess-bof-fix]] |
| **定时任务提权 (Linux/Windows)** | 同类持久化技术对比 | [[xd-security-privilege-escalation-notes-day58-64]] (定时任务提权) |
| **威胁溯源** | 任务创建痕迹分析 | [[threat-attribution-tracing-techniques]] |

## 进阶扩展与研究方向

### 任务触发器多样化
- **登录触发** (`LogonTrigger`)：用户登录即执行，适合交互式持久化
- **事件触发** (`EventTrigger`)：绑定特定 Event Log ID（如 4624 登录成功），隐蔽性更强
- **闲置触发** (`IdleTrigger`)：系统空闲时执行，降低用户感知

### COM 接口直接操作 (`ITaskService`, `ITaskFolder`, `ITaskDefinition`)
- 绕过托管库，直接调用 `taskschd.dll` 导出函数
- 可实现更精细的 `Principal`（运行级别：HighestAvailable）、`Settings`（多实例策略、网络条件）控制

### 远程计划任务创建 (RPC/SMB)
- 通过 `SchRpcRegisterTask` (Opnum 6) 远程注册任务
- 结合 [[smb-named-pipe-c2-communication]]、[[internal-network-pivoting-techniques]] 实现横向持久化部署

### 任务劫持与 DLL 植入
- 修改现有合法任务的 `Actions.ExecutablePath` 指向恶意 DLL/EXE
- 利用 `COM Handler` 劫持 (`CLSID` 关联) 实现无文件持久化

## 总结

SchTask 以**极简代码量（~200 行核心逻辑）**实现了**高隐蔽性的计划任务持久化**，其核心创新在于：
1. **双重伪装**：进程名随机 + 路径伪装
2. **索引篡改**：`Index` + `SD` 键值操作实现“任务存在但不可见”
3. **零依赖部署**：单文件 .NET 2.0 兼容性极强

对于红队实战，它是**轻量级、高可靠、易集成**的持久化选项；对于蓝队，重点加强**注册表键值审计**、**任务 XML 完整性校验**与**AppData 可执行文件监控**是有效防御手段。

## 交叉引用索引

- [[xd-security-internal-network-penetration-notes-day65-66]] — schtasks 横向移动与持久化实战
- [[xd-security-privilege-escalation-notes-day58-64]] — 定时任务提权技术对比
- [[internal-network-pivoting-techniques]] — 内网穿透与代理隧道关联检测
- [[memory-scanning-tools-evasion-techniques]] — 内存扫描对抗视角下的任务进程分析
- [[cobalt-strike-4.7-bof-internals]] — BOF 免杀加载器集成可能性
- [[ppl-injection-createprocess-bof-fix]] — PPL 进程注入作为高权限持久化替代方案
- [[inceptor-av-edr-evasion-framework]] — 免杀框架生态中的持久化模块定位
- [[threat-attribution-tracing-techniques]] — 计划任务创建痕迹溯源分析
- [[smb-named-pipe-c2-communication]] — 远程任务注册与 SMB 通信关联
- [[process-injection-tampering-techniques]] — 进程注入与篡改技术体系对比

## 来源

- [0x727开源安全团队-202108-202110_2](../sources/0x727开源安全团队-202108-202110_2.md)
