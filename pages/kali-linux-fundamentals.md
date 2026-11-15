---
title: Kali Linux 安装配置与核心工具集入门指南
description: 系统梳理 Kali Linux 的安装方式、APT 源配置、软件包管理、中文化设置，以及内置核心工具集（信息收集、漏洞扫描、渗透利用、密码攻击、无线审计、取证分析）的分类与典型用法，面向网络安全初学者与
  CTF 选手。
category: uncategorized
tags:
- Kali Linux
- 渗透测试
- 网络安全入门
- 工具集
- APT包管理
- CTF
date: 2024-01-15
updated: '2026-11-15'
---

## 概述

**Kali Linux** 是基于 **Debian** 的专用 Linux 发行版，由 **Offensive Security** 维护，前身为 BackTrack。它面向 **数字取证** 与 **渗透测试**，预装大量安全工具，并承诺永久免费、开源（Git 树公开）。因其图形化桌面友好，成为网络安全初学者、CTF 选手、红队人员的首选平台。

> 来源：[[007攻防实验室]] 微信归档文章《kali-Linux简易手册》

---

## 安装部署

| 方式 | 适用场景 | 关键提示 |
|------|----------|----------|
| **物理机直装** | 高性能需求、长期使用 | 先核对官网最新硬件要求；引导界面建议选 **Graphical Install** |
| **虚拟机 (VMware / VirtualBox)** | 学习、CTF、实验环境 | 配置足够内存/CPU、启用 3D 加速、安装 VMware Tools / Guest Additions；参考 [[vmware-ubuntu-security-lab-setup]] 通用虚拟化落地流程 |
| **树莓派 (ARM)** | 便携/嵌入式渗透 | 官网提供 ARMEL/ARMHF 镜像，性能受限于 ARM 架构 |
| **U 盘 Live / Persistent** | 临时使用、无痕操作 | 用 `Win32DiskImager` / `dd` / `Rufus` 烧录 ISO；持久化存储需额外分区 |

> 官方下载：<https://www.kali.org/downloads/>

---

## 系统配置

### APT 软件源（镜像站加速）

默认官方源 (`http.kali.org`) 在国内极慢，建议替换为国内镜像。编辑 `/etc/apt/sources.list`，注释原源，追加下列任一组镜像：

```text
# 中科大
deb http://mirrors.ustc.edu.cn/kali kali-rolling main non-free contrib
deb-src http://mirrors.ustc.edu.cn/kali kali-rolling main non-free contrib

# 阿里云
deb http://mirrors.aliyun.com/kali kali-rolling main non-free contrib
deb-src http://mirrors.aliyun.com/kali kali-rolling main non-free contrib

# 清华
deb http://mirrors.tuna.tsinghua.edu.cn/kali kali-rolling main contrib non-free
deb-src https://mirrors.tuna.tsinghua.edu.cn/kali kali-rolling main contrib non-free
```

更新命令：

```bash
apt-get update           # 刷新索引
apt-get dist-upgrade     # 滚动升级（推荐）
# 或
apt-get full-upgrade     # 同义
```

> Kali 采用 **Rolling（滚动更新）** 模式，工具版本比普通稳定源更激进。

### 包管理三板斧

| 工具 | 用途 | 典型命令 |
|------|------|----------|
| **apt / apt-get** | 高层包管理，自动解决依赖 | `apt install <pkg>` / `apt remove <pkg>` / `apt search <kw>` |
| **dpkg** | 底层 .deb 包操作 | `dpkg -i pkg.deb` / `dpkg -l` / `dpkg -r <pkg>` |
| **tar + make** | 源码编译安装（无 deb 包时） | `tar -xzvf src.tar.gz && cd src && ./configure && make && make install` |

> 优先用 `apt`；仅在官方仓库无目标版本时才考虑 `dpkg` 或源码编译。

### 常用软件与中文化

```bash
# 安装谷歌拼音输入法（需重启或重登生效）
apt-get update && apt-get install -y fcitx-googlepinyin
# 设置 -> Region & Language -> 添加 "Chinese (China)" -> 登出重登 -> Ctrl+Space 切换
```

若安装后界面仍为英文：  
`Settings → Region & Language → Language → 汉语（中国） → 重启`

---

## 核心工具集速览

Kali 预装工具按渗透测试生命周期分类，下表列出**代表性工具、定位、典型场景**，并标注是否有关联实战页面。

| 类别 | 工具 | 定位与核心能力 | 典型场景 | 关联实战 |
|------|------|----------------|----------|----------|
| **信息收集** | **Nmap** | 端口扫描、服务版本探测、OS 指纹、NSE 脚本引擎 | 资产发现、攻击面测绘 | — |
| | **Recon-NG** | 模块化 Web 侦察框架（Python），支持子域名枚举、API 密钥管理 | 自动化 OSINT、子域名收集 | — |
| **漏洞扫描** | **Nessus** | 商业级漏洞扫描器，插件库 75k+，C/S 架构，NASL 脚本 | 合规扫描、资产漏洞基线 | — |
| | **Burp Suite** | Web 应用安全测试平台（代理、繁殖器、扫描器、Intruder） | 代理抓包、改包、爆破、SSRF/XSS/SQLi 验证 | [[auth-bypass-via-response-manipulation]]、[[waf-bypass-techniques-case-study-ruijie]]、[[qwb2019-随便注-sql注入复现]]、[[web-fundamentals-lamp-wordpress-setup]] |
| **渗透利用** | **Metasploit Framework (MSF)** | 漏洞利用开发/执行框架，数百 Exploit/Payload/Auxiliary/Post 模块 | 从漏洞到 Shell、横向移动、权限维持 | — |
| | **Subterfuge** | MITM 攻击框架（Python/Django/Scapy），集成 ARP 欺骗、DNS 劫持、会话劫持 | 内网中间人、凭证窃取 | — |
| **密码攻击** | **mimikatz** | Windows 凭证导出（LSASS 内存、SAM、DPAPI），已集成进 MSF (`kiwi` 模块) | 域渗透、横向移动凭证获取 | — |
| | **Hydra** | 多协议在线暴力破解（SSH、RDP、HTTP、SMB、FTP 等），支持线程/字典 | 弱口令巡航、CTF 爆破题 | — |
| **无线审计** | **aircrack-ng** | 802.11 抓包/破解套件（监听模式、Deauth、PTW/FMS/Korek 破解 WEP/WPA） | WiFi 渗透、密码恢复 | — |
| | **Gerix WiFi Cracker** | aircrack-ng 图形化前端，降低操作门槛 | 新手无线审计入门 | — |
| **取证分析** | **Wireshark** | 全协议包分析器，流图、统计、Lua 插件、导出对象 | 流量取证、协议逆向、CTF Misc | [[ctf-misc入门与工具箱]]、[[usb流量取证与隐写综合实战]] |
| | **Maltego** | 图谱化威胁情报分析，Transform API 扩展 | 攻击面可视化、实体关联分析 | — |

> **提示**：Kali 工具版本随 Rolling 更新频繁变动，实战前建议 `apt update && apt upgrade` 并阅读 `man`/`--help` 确认参数变化。

---

## 学习路径建议

1. **环境落地** → 跟随 [[vmware-ubuntu-security-lab-setup]] 在 VMware 中部署 Kali，配置共享文件夹、快照、NAT/Host-Only 网络。
2. **基础工具精通** → 依次掌握 Nmap、Burp Suite、Metasploit 三大核心；结合 [[ctf-beginner-self-study-guide]] 在 BUUCTF/adworld 实战。
3. **专题深入**  
   - Web 方向：Burp Suite 进阶 + [[web-fundamentals-lamp-wordpress-setup]] 搭建靶场  
   - 内网/域渗透：MSF + mimikatz + 横向移动  
   - 无线/硬件：aircrack-ng + SDR/RF 硬件  
   - 取证/Misc：Wireshark + Volatility + [[ctf-misc入门与工具箱]]
4. **持续更新** → 关注 Kali 官方博客、OffSec 课程、[[007攻防实验室]] 归档文章，保持工具链与战术同步。

---

## 常见问题速查

| 现象 | 排查/解决 |
|------|-----------|
| `apt update` 报 `The repository is not signed` | 导入 GPG Key：`wget -q -O - https://archive.kali.org/archive-key.asc \| apt-key add -` |
| 虚拟机网络不通 | 检查网卡模式（NAT/桥接）、关闭宿主机防火墙、重装 VMware Tools |
| 中文输入法无法切换 | `im-config -n fcitx` 后重登；确保 `fcitx` 自启动 |
| MSF 数据库连接失败 | `msfdb init` 初始化 PostgreSQL；`systemctl start postgresql` |
| 无线网卡无法开启监听模式 | 确认网卡支持监听模式（`airmon-ng check kill` 再 `airmon-ng start wlan0`） |

---

## 参考资料

1. Kali Linux 官方文档：<https://www.kali.org/docs/>  
2. 陈铁明. *网络空间安全实战基础*. 北京: 人民邮电出版社, 2018.  
3. 百度百科「Kali Linux」词条  
4. 本页面源文章：[[007攻防实验室]] 微信归档《kali-Linux简易手册》

## 来源

- [0xfafu攻防实验室-202010-202112_19](../sources/0xfafu攻防实验室-202010-202112_19.md)
