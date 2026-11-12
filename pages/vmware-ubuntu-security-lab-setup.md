---
title: VMware Workstation Pro 15 与 Ubuntu 18.04 安全实验环境搭建指南
description: 详细记录 VMware Workstation Pro 15 与 Ubuntu 18.04 虚拟机的下载、安装、配置全流程，面向网络安全研究、CTF
  练习及渗透测试实验环境快速落地。
category: uncategorized
tags:
- VMware
- Ubuntu
- 实验环境
- 安全研究
- 虚拟化
- 教程
date: '2020-07-15'
updated: '2026-11-13'
---

## 概述

本页面沉淀自微信公众号归档文章《VMware workstationpro15 and ubuntu 18.04安装教程》，旨在为**网络安全研究、CTF 练习、漏洞复现、渗透测试**等场景提供一套开箱即用的本地实验环境搭建参考。

> **核心动机**：在物理主机之上通过虚拟化运行独立操作系统，既能隔离实验风险，又能随时快照回滚，是安全入门者“动手实践不破坏爱机”的最佳实践。

## 环境版本基线

| 组件 | 版本 | 备注 |
|------|------|------|
| 宿主机 OS | Windows 10 / Linux / macOS | VMware Workstation Pro 15 支持跨平台 |
| 虚拟化软件 | VMware Workstation Pro 15.0+ | 需注册码激活，官网可下载试用版 |
| 客户机 OS | Ubuntu 18.04 LTS (Bionic Beaver) | 长期支持版，软件源稳定，适合安全工具链部署 |
| 架构 | x86_64 (amd64) | 64 位镜像 |

## 资源获取

### 官方渠道
- **VMware Workstation Pro 15**  
  <https://my.vmware.com/en/web/vmware/info/slug/desktop_end_user_computing/vmware_workstation_pro/15_0>  
  （Linux / Windows 安装包均可在官网获取，注册码可自行搜索）

- **Ubuntu 18.04 LTS**  
  <https://releases.ubuntu.com/18.04/>  
  推荐下载 `ubuntu-18.04.x-desktop-amd64.iso`（桌面版，含图形安装向导）

### 备用网盘（归档时提供）
- VMware 安装包：`https://pan.baidu.com/s/1-iWSuda0YP78Jyeg7gig4A`  提取码 `vt6j`
- Ubuntu 镜像：`https://pan.baidu.com/s/19GY1u1RA66xCY4e0Rx4inA`  提取码 `emsq`

> ⚠️ 网盘链接可能失效，优先使用官方源并校验 SHA256。

## VMware Workstation Pro 15 安装要点

1. **以管理员身份运行** 安装程序（`VMware-workstation-full-15.x.x-xxxxxxx.exe` / `.bundle`）。
2. **许可证协议** → 勾选“我接受”。
3. **安装路径** → 建议非系统盘（如 `D:\VMware`），预留 ≥ 20 GB 空间。
4. **用户体验设置** → 可取消“加入用户体验改善计划”。
5. **快捷方式** → 桌面/开始菜单按需勾选。
6. **许可证密钥** → 安装完成后在“帮助 → 许可证”中输入注册码激活。
6. **重启宿主机** → 完成内核模块编译（Linux 宿主需执行 `sudo vmware-modconfig --console --install-all`）。

## Ubuntu 18.04 虚拟机创建与安装

### 新建虚拟机向导
- **典型/自定义** → 选择“典型”即可，后续可再精调。
- **安装来源** → “安装程序光盘映像文件” → 浏览选择下载的 `ubuntu-18.04-desktop-amd64.iso`。
- **易安装信息** → 填写用户名/密码/主机名（建议全英文、无空格）。
- **虚拟机名称/位置** → 统一放在专用目录（如 `D:\VMs\Ubuntu18.04-SecLab`）。

### 硬件规格建议（按宿主机资源弹性分配）

| 资源 | 最低配置 | 推荐配置（安全实验） | 说明 |
|------|----------|----------------------|------|
| CPU 核心 | 2 核 | 4 核 | 多核利于并发模糊测试、编译 |
| 内存 | 2 GB | 8 GB+ | 运行 Burp Suite、IDA、Docker 等需大内存 |
| 磁盘 | 20 GB | 60 GB+ (NVMe/SSD) | 预留快照、工具、样本空间 |
| 网络 | NAT | NAT + Host-Only 双网卡 | NAT 联网下载工具；Host-Only 便于宿主↔客户机直联、抓包 |
| 显存 | 1 GB | 2 GB+ | 开启 3D 加速可流畅运行图形化逆向工具 |

> **磁盘类型** → 选“将虚拟磁盘存储为单个文件” + “立即分配所有磁盘空间”可提升 I/O 性能；若宿主磁盘紧张可取消“立即分配”。

### 安装流程（图形向导）
1. 语言 → **English** / **中文** 均可，建议英文学习术语。
2. 键盘布局 → 默认。
3. 更新与其它软件 → **Normal installation** + 勾选“Download updates while installing” + “Install third-party software”。
4. 安装类型 → **Erase disk and install Ubuntu**（虚拟磁盘无数据风险）。
5. 时区 → 上海/北京。
6. 用户创建 → 与易安装信息一致或重新设置。
7. 等待安装完成 → 重启 → 拔除虚拟光驱 ISO。

### 首次登录后必做配置
```bash
# 1. 切换国内源（阿里/清华/中科大）加速 apt
sudo sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
sudo sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
sudo apt update && sudo apt upgrade -y

# 2. 安装 VMware Tools（增强剪贴板、共享文件夹、分辨率自适应）
sudo apt install -y open-vm-tools open-vm-tools-desktop
# 或使用 VMware 菜单 “VM → Install VMware Tools” 挂载 ISO 手动运行 vmware-install.pl

# 3. 基础安全工具链
sudo apt install -y git curl wget vim net-tools iproute2 \
    python3 python3-pip python3-venv \
    build-essential gdb strace ltrace \
    nmap wireshark tcpdump \
    docker.io docker-compose

# 4. 非 root 用户加入 docker 组
sudo usermod -aG docker $USER
newgrp docker
```

## 安全实验环境进阶建议

| 方向 | 推荐操作 | 交叉引用页面 |
|------|----------|--------------|
| **Web 渗透基础** | 搭建 LAMP + WordPress/DVWA 靶场 | [[web-fundamentals-lamp-wordpress-setup]] |
| **CTF 入门练习** | 部署 bugku/adworld/buuoj 本地镜像或连接远程平台 | [[ctf-beginner-self-study-guide]] |
| **二进制/逆向** | 安装 IDA Free / Ghidra / pwndbg / pwntools | — |
| **内网渗透** | 再克隆一台 Win7/Win10 VM 组建域环境 | [[007攻防实验室]] |
| **流量分析/取证** | 导入 PCAP 样本练习 Wireshark/Volatility | [[ctf-misc入门与工具箱]]、[[usb流量取证与隐写综合实战]] |

## 快照与备份策略

1. **基线快照**：系统更新、VMware Tools、基础工具链就绪后 → `VM → Snapshot → Take Snapshot` 命名为 `Baseline-Clean`。
2. **实验前快照**：每次开始新课题/靶机前建快照，命名含日期与主题（如 `2024-05-20-SQLi-Lab`）。
3. **导出 OVF/OVA**：定期导出整机归档至移动硬盘，防宿主机故障。

## 常见问题排查

| 现象 | 可能原因 | 解决方案 |
|------|----------|----------|
| 虚拟机无法联网 | 网络模式 NAT 未桥接、宿主防火墙拦截 | 检查 `Virtual Network Editor` → NAT 服务启动；宿主放行 `vmnet-natd.exe` |
| 分辨率固定 800×600 | VMware Tools 未生效 | 重装 `open-vm-tools-desktop` 并重启 lightdm/gdm |
| 共享文件夹不可见 | 未在 VM Settings→Options→Shared Folders 开启 | 勾选“Always enabled”并指定宿主路径，客户机挂载点 `/mnt/hgfs` |
| apt 报错 `Hash Sum mismatch` | 镜像源缓存损坏 | `sudo rm -rf /var/lib/apt/lists/* && sudo apt update` |

## 结语

完成上述步骤后，你将拥有一个**可快照回滚、工具链齐全、网络可控**的 Ubuntu 18.04 安全实验环境。后续可按需在该基线上克隆、扩展出针对 Web、二进制、内网、取证等细分方向的专用虚拟机，形成“母镜像 → 专用实例 → 快照迭代”的标准化工作流。

---

> **页面维护提示**：Ubuntu 18.04 标准支持已于 2023 年 5 月结束，新建实验建议优先使用 **Ubuntu 22.04/24.04 LTS**；本页面保留为历史教程归档与版本对照参考。

## 来源

- [0w1Club-201908-202207_26](../sources/0w1Club-201908-202207_26.md)
