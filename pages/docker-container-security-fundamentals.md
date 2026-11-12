---
title: Docker 容器安全基础机制详解
description: 系统梳理 Docker 容器安全核心机制，涵盖架构组件、Namespace 隔离、Cgroup 资源限制、Linux Capability
  权限模型及主流加固方案（AppArmor/SELinux 等），为容器逃逸与攻击面分析奠定基础。
category: ai-security
tags:
- Docker
- 容器安全
- Namespace
- Cgroup
- Linux Capability
- AppArmor
- SELinux
- 安全架构
date: '2023-04-14'
updated: '2026-11-12'
---

## Docker 架构与核心组件

Docker 采用 **Client/Server (C/S) 架构**。客户端通过命令行或 REST API 向守护进程发送请求，守护进程负责构建、运行和分发容器。客户端与守护进程可运行在同一主机，也可通过 Socket 或远程 API 通信。

Docker 核心组件由三大部分组成：

| 组件 | 职责 |
|------|------|
| **Docker 引擎** | 运行时服务提供者，封装 Namespace、Cgroup、Capability 等底层安全技术 |
| **Docker 容器** | 承载用户业务负载的运行实例，包含应用程序及其依赖 |
| **Docker 仓库** | 集中存储、管理镜像的注册中心，支持公有/私有仓库 |

与传统虚拟化（Hypervisor + Guest OS）相比，Docker 移除了 Hypervisor 与客户操作系统层，直接在宿主内核上通过容器引擎调度，实现秒级启动与高资源利用率，但也因共享内核而引入特有攻击面。

## 核心安全隔离机制

### Namespace 隔离

Namespace 是容器隔离的基石。启动容器时，Docker 为其创建一组独立的 Namespace，使容器内进程对宿主及其他容器的资源不可见。Linux 当前支持六种 Namespace：

| Namespace 类型 | 隔离资源范围 | 系统调用常量 |
|----------------|--------------|--------------|
| **PID** | 进程 ID 编号 | `CLONE_NEWPID` |
| **NET** | 网络设备、协议栈、端口、路由表 | `CLONE_NEWNET` |
| **MNT** | 挂载点、文件系统层级 | `CLONE_NEWNS` |
| **UTS** | 主机名与域名 | `CLONE_NEWUTS` |
| **IPC** | 进程间通信（信号量、消息队列、共享内存） | `CLONE_NEWIPC` |
| **USER** | 用户 ID 与组 ID 映射 | `CLONE_NEWUSER` |

> **注意**：User Namespace 通过 UID/GID 映射可实现“容器内 root ≠ 宿主 root”，是权限降级的关键手段。

### Cgroup 资源限制

Control Groups (Cgroup) 负责**资源审计与限制**，解决多租户场景下的资源公平分配与 DoS 防护。Cgroup 以子系统形式对资源进行管控：

- **cpu / cpuset** — CPU 时间片与核心绑定
- **memory** — 物理内存、Swap 使用上限
- **blkio** — 块设备 I/O 带宽与 IOPS
- **devices** — 设备节点访问白名单
- **pids** — 进程/线程数上限（防止 Fork 炸弹）
- **freezer** — 整组挂起/恢复

通过组合子系统，可精细划定容器资源配额，缩小“资源耗尽型”攻击面。

### Linux Capability 权限模型

传统 Linux 将特权二分为 root 与非 root，Capability 将特权拆解为 **38 个细粒度标志**，实现最小权限原则。Docker 默认采用**白名单机制**，仅授予容器必要 Capability，其余一律剥离。

#### Docker 默认开启的 Capability 列表

| Capability | 说明 |
|------------|------|
| `AUDIT_WRITE` | 向内核审计日志写入记录 |
| `CHOWN` | 任意修改文件 UID/GID |
| `DAC_OVERRIDE` | 绕过文件读写权限检查 (DAC) |
| `FOWNER` | 绕过文件所有者权限检查 |
| `FSETID` | 修改文件时保留 SUID/SGID 位 |
| `KILL` | 向非自身进程发送信号 |
| `MKNOD` | 创建特殊设备文件 `mknod()` |
| `NET_BIND_SERVICE` | 绑定 <1024 端口 |
| `NET_RAW` | 使用 RAW/PACKET 套接字 |
| `SETFCAP` | 设置文件 Capability |
| `SETGID` | 修改进程 GID |
| `SETPCAP` | 转移/删除其他进程 Capability |
| `SETUID` | 修改进程 UID |
| `SYS_CHROOT` | 使用 `chroot()` 与 `setns()` 切换挂载 NS |

> **运行时调整**：`docker run --cap-add=SYS_ADMIN --cap-drop=NET_RAW` 可动态增减 Capability。

### 其他主流加固方案

Docker 仅默认启用 Capability，生产环境建议叠加以下 **强制访问控制 (MAC)** 体系：

| 方案 | 特点 | 典型场景 |
|------|------|----------|
| **AppArmor** | 基于路径的配置文件，上手易，Ubuntu 默认集成 | 限制容器文件读写、网络访问、能力调用 |
| **SELinux** | 基于标签的强制访问控制，策略更细致，Red Hat/CentOS 默认 | 多级安全 (MLS)、多类别安全 (MCS) 场景 |
| **Seccomp** | 系统调用过滤白名单，默认阻塞 `keyctl`、`bpf` 等高危调用 | 防御内核漏洞利用、容器逃逸 |
| **TOMOYO / GRSEC** | 学习模式自动生成策略 / 内核级加固补丁集 | 高安全合规环境 |

> **最佳实践**：`--security-opt apparmor=docker-default --security-opt seccomp=default.json` 叠加使用，实现纵深防御。

## 容器漏洞报告总结

笔者整理了 **2017–2020 年** 与容器相关的 CVE 漏洞报告，汇总地址：  
🔗 <https://github.com/XiaoXiaoGuaiXiaShi/Container-security-papers.git>  

后续分析将以其中典型 CVE 为例，深入剖析容器逃逸、提权及攻击面利用链。

## 来源

- [0th3rs安全团队-201911-202204_012](../sources/0th3rs安全团队-201911-202204_012.md)
