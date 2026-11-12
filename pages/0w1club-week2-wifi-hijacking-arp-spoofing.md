---
title: 0w1Club 萌新培养第二周教程：基于 ARP 欺骗的 WiFi 劫持与中间人攻击实战入门
description: 0w1Club 安全团队微信公众号萌新培养系列第二周教程，系统讲解 ARP 协议原理、ARP 欺骗攻击流程（探测、毒化、开启 IP 转发）、常用工具（netdiscover、arpspoof、Wireshark、ettercap、bettercap）及后续利用思路，适合网络安全初学者快速上手中间人攻击实战。
category: ai-security
tags:
- 0w1Club
- ARP欺骗
- 中间人攻击
- WiFi劫持
- 渗透测试
- 网络安全入门
- Kali Linux
- Wireshark
- netdiscover
- arpspoof
date: 2019-09-13
updated: '2026-11-13'
---

## 概述

本页面整理自 0w1Club 微信公众号「萌新培养」系列第二周教程，主题为 **基于 ARP 欺骗的 WiFi 劫持与中间人攻击实战入门**。文章从 ARP 协议基础原理切入，详细演示了在 Kali/Ubuntu 环境下使用 `netdiscover` 发现目标、`arpspoof` 实施 ARP 投毒、开启内核 IP 转发以维持通信、并配合 Wireshark 抓包分析受害机流量的完整攻击链路，最后给出了后续利用方向（DNS 欺骗、钓鱼、凭证窃取等）及拓展阅读资源。

> 原文发布时间：2019 年中秋前后（约 2019-09-13）  
> 原文链接：http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483726&idx=1&sn=b04ff0cdc115674fe820568f1058b8fa

---

## ARP 协议基础

### 定义与作用
- **全称**：Address Resolution Protocol（地址解析协议）
- **核心功能**：根据目标 IP 地址解析其对应的物理地址（MAC 地址），工作在 TCP/IP 协议栈的链路层。

### 工作流程
1. 主机欲发送数据时，构造 ARP 请求帧，包含目标 IP，广播至本地网段所有主机。
2. 目标主机识别出自己的 IP，单播回复 ARP 应答，携带自身 MAC 地址。
3. 请求主机收到应答后，将 `<IP, MAC>` 映射存入本地 **ARP 缓存**，并设置生存时间（TTL），后续通信直接查缓存，减少广播开销。

### 协议缺陷
- **无身份验证机制**：主机不会验证 ARP 应答的真实性，盲目接受并更新缓存。
- **无状态、可覆盖**：新的 ARP 应答可直接覆盖缓存中旧条目，为 **ARP 欺骗/投毒** 提供了理论基础。

> 抓包示例（Wireshark 显示 ARP 请求/应答交互）  
> ![ARP 协议工作流程](../Images/871d120084aa7d9838c8e6ccb9e57443.png)

---

## 攻击原理：ARP 欺骗与中间人攻击

### 攻击模型
```
受害机 (Target)  <--ARP 投毒-->  攻击机 (Attacker)  <--ARP 投毒-->  网关 (Gateway)
```
- 攻击机分别向受害机和网关发送伪造的 ARP 应答：
  - 告诉受害机：“网关的 MAC 是我的 MAC”
  - 告诉网关：“受害机的 MAC 是我的 MAC”
- 双方流量均经攻击机中转，攻击机实现 **中间人** 位置，可窃听、篡改、注入数据。

### 攻击示意图
![ARP 欺骗拓扑](../Images/48af75fb27201c985b2b8fe29a2537dc.png)

---

## 实验环境与工具准备

| 角色 | 推荐环境 | 核心工具 | 备选工具 |
|------|----------|----------|----------|
| 攻击机 | Kali Linux / Ubuntu | `netdiscover`、`arpspoof` (dsniff 套件)、`Wireshark` | `ettercap`、[[bettercap]] |
| 受害机 | 任意连接同一 WiFi/局域网的设备 | — | — |
| 网关 | 无线路由器 / 上层网关 | — | — |

### 工具安装
```bash
# Ubuntu / Debian 系
sudo apt-get update
sudo apt-get install netdiscover dsniff wireshark
# Kali 默认预装上述工具
```
> `arpspoof` 隶属于 `dsniff` 包；`bettercap` 为 Go 编写的现代化替代品，功能更丰富（支持 BLE、WiFi、HID 等），可参考 [[ar-drone-2.0-penetration-testing]] 中的实战用法。

---

## 实战步骤详解

### 第一阶段：网络探测（发现目标与网关）
```bash
# 以交互模式扫描本地网段存活主机
netdiscover
```
- 输出包含 IP、MAC、厂商信息，确认 **目标 IP** 与 **网关 IP**。
- 示例变量赋值：
  ```bash
  target=192.168.0.101   # 受害机 IP
  host=192.168.0.1       # 网关 IP
  ```

### 第二阶段：ARP 投毒（发起欺骗）
```bash
# -i 指定无线网卡接口（如 wlan0），-t 指定目标，后跟网关
arpspoof -i wlan0 -t $target $host
```
- 持续发送伪造 ARP 应答，使受害机缓存中网关 MAC 指向攻击机。
- **副作用**：若攻击机未开启 IP 转发，受害机流量将被黑洞丢弃，表现为 **断网**（拒绝服务效果）。

### 第三阶段：开启 IP 转发（维持通信，隐蔽窃听）
```bash
# 查看当前转发状态（0=关闭，1=开启）
sysctl -a | grep ip_forward
# net.ipv4.ip_forward = 0

# 临时开启（重启失效）
sysctl -w net.ipv4.ip_forward=1
# net.ipv4.ip_forward = 1
```
- **永久生效**：编辑 `/etc/sysctl.conf`，添加/修改 `net.ipv4.ip_forward=1`，执行 `sysctl -p`。
- 开启后，攻击机作为路由器转发受害机与网关之间的流量，受害机无感知，攻击机可全量抓包。

### 第四阶段：流量捕获与分析
- 启动 **Wireshark**，选择无线网卡（`wlan0`）或任意接口抓包。
- 过滤器示例：
  - `ip.addr == 192.168.0.101`  仅看受害机流量
  - `http` / `dns` / `tcp.port == 443`  针对性分析
- 可获取：明文 HTTP 账号密码、DNS 请求、Cookie、访问网站指纹等。

---

## 后续利用与拓展攻击面

一旦稳居中间人位置，可衍生出多种攻击手法（原文因法律与篇幅限制仅列举，不展开）：

| 攻击类型 | 核心思路 | 相关工具/模块 |
|----------|----------|---------------|
| **DNS 欺骗** | 伪造 DNS 应答，将域名解析到恶意服务器 | `ettercap` 插件 `dns_spoof`、Bettercap `dns.spoof` |
| **HTTP 注入/钓鱼** | 篡改 HTTP 响应注入恶意 JS/iframe，或重定向至钓鱼页面 | Bettercap `http.proxy`、`inject` 模块 |
| **凭证窃取** | 解析 HTTP Basic Auth、POST 表单、Cookie、Session ID | Wireshark 导出对象、Bettercap `net.sniff` |
| **SSL/TLS 剥离** | 降级 HTTPS 为 HTTP，配合 HSTS 绕过 | `sslstrip`、`bettercap` `https.proxy` |
| **会话劫持** | 窃取 Session Cookie 直接复用登录态 | 配合 [[burpsuite-basics-tutorial]] 中 Repeater 复现请求 |
| **内网横向** | 结合 [[frp内网渗透应用]]、[[metasploit-framework-basics-tutorial]] 进一步渗透内网 | `msfconsole`、`proxychains`、Socks5 隧道 |

> ⚠️ **法律提示**：上述技术仅限授权渗透测试、CTF 靶场、个人实验环境使用。未经许可对他人网络实施 ARP 欺骗、流量窃听属违法行为。

---

## 常见问题排查

| 现象 | 可能原因 | 解决方案 |
|------|----------|----------|
| `netdiscover` 无输出 | 网卡未开启混杂模式 / 不在同一二层网络 | `ip link set wlan0 promisc on`；确认连接同一 AP |
| `arpspoof` 报错 `Device wlan0 not found` | 网卡名称不一致（如 `wlp3s0`） | `ip link` 查看实际接口名，调整 `-i` 参数 |
| 受害机断网 | 未开启 IP 转发 | 执行 4.3 节开启转发 |
| Wireshark 抓不到受害机流量 | 抓包接口错误 / 未勾选混杂模式 | 选择正确接口，`Capture Options` 勾选 `Promiscuous mode` |
| Kali 虚拟机网络不通 | VMware 网络模式设置错误 | 参考拓展阅读 1：VMware Tools 安装与网络模式配置（NAT/桥接） |

---

## 拓展阅读与进阶资源

原文推荐的“葵花宝典”补充链接（已归档整理）：

1. **VMware Tools 安装教程** —— 虚拟机网络与共享文件夹基础  
   https://blog.csdn.net/u013142781/article/details/50539574
2. **Ubuntu 换源教程** —— 加速软件包下载  
   https://blog.csdn.net/zhangjiahao14/article/details/80554616
3. **IP 协议简介** —— 网络层基础补全  
   https://blog.csdn.net/xinyuan510214/article/details/80108216
4. **ARP 攻击骚操作之窥你屏** —— 进阶利用案例（屏幕流劫持等）  
   https://blog.csdn.net/sinat_35930259/article/details/52422915
5. **高度集成化局域网工具 ettercap 实战** —— 图形化/脚本化中间人套件  
   https://blog.csdn.net/ysynhtt/article/details/39996933
6. **星辰大海** —— Bing 搜索入口，鼓励自主探索  
   https://cn.bing.com/

### 知识库内关联页面
- [[ar-drone-2.0-penetration-testing]] —— 无人机渗透中同款 ARP 欺骗 + UDP 序列号伪造劫持控制链路
- [[burpsuite-basics-tutorial]] —— 0w1Club 系列教程之 Burp Suite 入门，配合中间人抓包做后续 Web 攻击
- [[metasploit-framework-basics-tutorial]] —— 后渗透框架基础，结合 ARP 劫持建立 Socks 隧道横向移动
- [[frp内网渗透应用]] —— 内网穿透技术，可将受控主机端口映射至公网 VPS
- [[knob-bluetooth-bredr-key-negotiation-vulnerability]] —— 蓝牙协议层面的中间人强制降级攻击（KNOB），原理对比参考
- [[bettercap]]（若存在） —— 现代化中间人瑞士军刀，支持 WiFi、BLE、HID、Ethernet 多协议

---

## 结语

> “分享会只能交个大概，功夫在平时呀。” —— 0w1Club 夜晓

本教程以 **最小可行性实验** 为核心，覆盖了从协议原理、工具链部署、攻击执行到流量分析的完整闭环。建议初学者在 **合法授权环境**（如自建靶场、CTF 平台、家庭实验网络）中完整复现一次，并尝试：
1. 使用 `ettercap` / `bettercap` 替代 `arpspoof` 实现自动化插件化攻击；
2. 结合 [[burpsuite-basics-tutorial]] 对捕获的 HTTP/HTTPS 流量做主动漏洞扫描；
3. 探索 IPv6 环境下的 NDP 欺骗（`ndp-spoof`）、VLAN 跨段 ARP 欺骗等进阶场景。

**安全之路，始于好奇，终于自律。预祝中秋快乐，探索愉快！** 🌕

---

> 页面维护：数字知识库策展人  
> 最后同步：2025-08-17  
> 来源标识：0w1Club 微信公众号「萌新培养」第二周原文归档

## 来源

- [0w1Club-201908-202207_22](../sources/0w1Club-201908-202207_22.md)
