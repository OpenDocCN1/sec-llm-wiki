---
title: 每日安全看点 2020-02-25
description: 汇总 2020 年 2 月 25 日每日安全看点，涵盖 RSAC 2020 热门产品、Docker Hub 容器扫描服务、硬件调试 SWD/OpenOCD、Linux
  文件描述符基础及 MariaDB CVE-2020-7221 提权漏洞分析
category: ai-security
tags:
- 每日安全看点
- RSAC 2020
- Docker 安全
- 硬件调试
- SWD
- OpenOCD
- Linux 基础
- 文件描述符
- MariaDB
- CVE-2020-7221
- 提权漏洞
- 2020年2月
date: 2020-02-25
updated: '2026-11-12'
---

# 每日安全看点【2020.02.25】

本期看点汇总了 RSAC 2020 大会热门安全产品榜单、Docker Hub 容器漏洞扫描服务介绍、硬件逆向调试基础（SWD/OpenOCD）、Linux 文件描述符核心概念以及 MariaDB 提权漏洞（CVE-2020-7221）深度分析五篇技术文章。

---

## RSAC 2020：最热门的 36 款网络安全产品

> 来源：[FreeBuf 资讯](https://www.freebuf.com/news/228255.html)

RSAC 2020 期间发布了众多创新安全产品，文章整理了当年最受关注的 36 款产品，涵盖威胁情报、云安全、端点检测响应 (EDR)、身份与访问管理 (IAM)、数据安全等多个赛道，反映了 2020 年网络安全技术发展的前沿趋势与厂商布局重点。

---

## Docker Hub 容器漏洞扫描服务

> 来源：[Jerry Gamblin's Blog](https://jerrygamblin.com/2020/02/23/on-demand-container-scanning-api/)

介绍了一个为 Docker Hub 提供按需容器漏洞扫描的 API 服务。该服务允许开发者在镜像拉取或部署前，通过 API 接口提交镜像名称即可获取漏洞扫描报告，帮助识别基础镜像及应用依赖中的已知 CVE 漏洞，提升容器供应链安全性。

**关联知识：** [[docker-container-security-fundamentals]] 系统梳理了 Docker 容器安全核心机制（Namespace、Cgroup、Capability、AppArmor/SELinux 等），为理解容器漏洞扫描的必要性及攻击面提供了架构基础。

---

## 硬件调试入门：SWD、OpenOCD 与 Xbox One 手柄实战

> 来源：[Wrongbaud Blog](https://wrongbaud.github.io/stm-xbox-jtag/)

面向逆向工程师的硬件调试入门指南。文章以 STM32 单片机和 Xbox One 手柄为实战靶标，详细讲解了：
- **SWD (Serial Wire Debug)** 协议原理与接线方式
- **OpenOCD** 的安装、配置及常用调试命令
- 如何通过 SWD 接口连接目标设备、读取闪存、下载固件及进行动态调试
- 针对 Xbox One 手柄主控芯片的具体调试实操步骤

适合希望从软件逆向拓展至硬件固件分析领域的安全研究人员入门参考。

---

## Linux 文件描述符介绍

> 来源：[微信公众号文章](https://mp.weixin.qq.com/s/dp1PwKnfkgGv2Zy2tlTRug)

系统性梳理 Linux 文件描述符 的核心概念与机制：
- 文件描述符的定义、数据结构（`files_struct`、`fdtable`、`file` 结构体）及在进程中的管理方式
- 标准输入/输出/错误（0/1/2）的本质
- 文件描述符的分配、复用、继承（`fork`/`exec` 行为）及限制（`ulimit`、`/proc/sys/fs/file-max`）
- `/proc/<pid>/fd/` 目录的实战查看技巧
- 常见漏洞利用场景：文件描述符泄露、竞争条件、整数溢出导致的 fd 覆盖等

为理解 Linux 进程管理、容器隔离及提权漏洞利用提供了基础理论支撑。

---

## MariaDB CVE-2020-7221 提权漏洞分析

> 来源：[Seebug Paper 1127](https://paper.seebug.org/1127/)

深度分析 MariaDB 10.3.22 及以下版本、10.4.12 及以下版本中存在的本地提权漏洞 (CVE-2020-7221)。

### 漏洞成因
MariaDB 在以 root 权限启动时，会调用 `chown` 将数据目录权限变更为 mysql 用户。由于 `chown` 遵循符号链接，攻击者可预先在数据目录下创建指向敏感文件（如 `/etc/shadow`、系统服务脚本、sudoers 文件等）的符号链接，诱导 MariaDB 启动过程修改目标文件所有者为 mysql 用户，进而实现权限提升。

### 利用条件与限制
- 需要拥有 mysql 系统用户的操作权限（或已在数据库层面获得代码执行并写入文件）
- 依赖 `datadir` 配置可控或默认路径可写
- 受限于 SELinux/AppArmor 等强制访问控制策略

### 修复方案
官方补丁采用 `fchownat` 系统调用并设置 `AT_SYMLINK_NOFOLLOW` 标志，禁止跟随符号链接，从根源阻断符号链接攻击路径。

---

## 关联阅读

- [[daily-security-digest-20200226]] —— 翌日安全看点，涵盖 LLVM/Clang Pass、账号接管、挖矿木马应急、Linux 内核栈溢出利用、Windows Defender 驱动分析等
- [[docker-container-security-fundamentals]] —— Docker 容器安全核心机制系统梳理，补充容器扫描服务的理论背景

## 来源

- [0th3rs安全团队-201911-202204_074](../sources/0th3rs安全团队-201911-202204_074.md)
