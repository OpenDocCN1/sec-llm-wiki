---
title: 0w1Club 第八周萌新培训：Wireshark 基础、PPPoE 凭证提取、ARP 欺骗中间人攻击与 HTTPS 对抗分析
description: 记录 0w1Club 网络安全俱乐部第八期萌新培养分享会预告与实况内容，系统讲解 Wireshark 抓包分析基础、利用 PPPoE/PAP
  协议缺陷提取宽带账号密码、基于 ARP 欺骗实施中间人攻击（Ettercap 实战）、以及 HTTPS 证书体系对抗中间人攻击的原理与实战演示。包含预告原文、主讲人简介、时间地点等元信息。
category: ai-security
tags:
- 0w1Club
- 萌新培养
- Wireshark
- PPPoE
- PAP协议
- ARP欺骗
- 中间人攻击
- Ettercap
- HTTPS
- 证书体系
- 网络安全入门
- 西安交通大学
- 网络安全社团
- 微信归档
date: 2018-04-22
updated: '2026-11-14'
---
## 概览

本页面整理自 0w1Club 微信公众号 2018 年 4 月发布的第八周萌新培训**预告文章**与**实况总结文章**。培训由主讲人 **严宋扬** 在西安交通大学网络安全实验室会议室进行，时长约 40 分钟。内容涵盖网络流量分析工具 Wireshark 入门、PPPoE 宽带拨号认证流程与 PAP 明文传输漏洞利用、ARP 协议原理与欺骗攻击实战（含 Ettercap 图形化操作）、以及 HTTPS/TLS 证书体系如何防御中间人攻击的原理剖析与演示。

> 预告原文链接：<http://mp.weixin.qq.com/s?__biz=MzUzMzEwMDk3Mg==&mid=2247483833&idx=1&sn=e1944bc56bc0df3be74b73bb2ba62276&chksm=faa8617acddfe86c4c663ea8050e6d34d70fe1f83830c9aa725da0f26ebc4aeaa1e9caeeab16&scene=27#wechat_redirect>
>
> 实况总结链接：<http://mp.weixin.qq.com/s?__biz=MzUzMzEwMDk3Mg==&mid=2247483844&idx=1&sn=7383830810df855fc0276069b49c1910>

## 训练元信息

| 项目 | 详情 |
|------|------|
| **期数** | 第八期 / 第三次小白培训 |
| **主题** | Wireshark的基本介绍、获取路由器宽带密码的演示、ARP欺骗中间人攻击、HTTPS对抗分析 |
| **时间** | 2018年4月22日（周日）19:00 |
| **时长** | 40分钟 |
| **地点** | 西安交通大学网络安全实验室会议室 |
| **主讲人** | 严宋扬（软件学院大二学生，0w1Club核心成员） |
| **难度定位** | 萌新/入门级，请大家根据难度自行选择参加 |

## 主讲人简介

**严宋扬** —— 软件学院大二学生，0w1Club 核心成员。预告原文自我介绍：「发际线堪忧的软院大二萌新，活在一堆的课和作业之中，很希望能和大家一起搞事情，安全路上永远是小白。欢迎来社团一起玩♪( ´▽｀)」。擅长网络协议分析与中间人攻击实战，培训风格偏向“演示驱动 + 工具落地”，鼓励萌新动手复现。

## 训练大纲

| 环节 | 主题 | 核心内容 |
|------|------|----------|
| 1 | **Wireshark 基础介绍与演示** | 免费开源网络封包分析软件，仅具分析功能，无侵入性；展示界面与常用过滤器 |
| 2 | **Demo：利用 PPPoE 获取宽带密码** | PPPoE 发现/会话阶段、PAP 认证明文传输缺陷、搭建伪 PPPoE 服务器抓取账号密码 |
| 3 | **Demo：基于 ARP 欺骗实现中间人攻击** | ARP 请求/应答与缓存更新机制、ARP 投毒原理、Ettercap 图形界面实施毒化、Wireshark 配合流量分析 |
| 4 | **HTTPS 与中间人攻击的对抗故事** | 证书信任链、中间人攻击在 HTTPS 下的失效原因、证书伪造/导入信任存储的实战演示 |

## 详细内容

### Wireshark 基础介绍

- **定位**：免费开源的网络封包分析软件，**本身不具备侵入/攻击能力**，仅用于流量捕获、解析、过滤、统计。
- **典型应用场景**：
  - 网络故障排查（丢包、延迟、重传分析）
  - 协议学习与逆向（HTTP、DNS、TLS 握手细节）
  - 安全审计（凭证明文传输、异常流量发现、恶意软件 C2 通信特征提取）
- **界面要素**：捕获接口选择、显示过滤器、数据包列表/详情/字节视图、统计图表。

### Demo：利用 PPPoE/PAP 获取宽带账号密码

#### PPPoE 协议流程
1. **发现阶段**：
   - `PADI`（Client → 广播）：主动发现服务
   - `PADO`（Server → Client）：服务提供通告
   - `PADR`（Client → Server）：请求会话
   - `PADS`（Server → Client）：会话确认，分配 Session-ID
2. **会话阶段**：封装 PPP 帧，进行认证（PAP/CHAP）、协商网络层参数（IPCP/IPv6CP）。
3. **终止阶段**：`PADT` 释放会话。

#### PAP 认证缺陷
- **明文传输**：PAP（Password Authentication Protocol）以**明文**发送用户名/密码，无加密、无挑战-响应机制。
- **攻击面**：任意设备伪造 PPPoE 服务器（发送 `PADO`/`PADS`），诱导客户端连接并完成 PAP 认证，即可在 Wireshark 中直接看到 `Authenticate-Request` 包内的用户名与密码。

#### 实操步骤
1. 在 Kali/Linux 上搭建并配置 PPPoE 服务端（如 `pppoe-server` 或 `rp-pppoe`），启用 PAP 认证。
2. 将目标路由器 WAN 口接入攻击机网口，或通过 VLAN/交换机镜像流量。
3. 启动 Wireshark 抓包，过滤 `pppoe && pap`。
4. 观测 `PPP PAP Authenticate-Request` 数据包，`Peer-ID` 与 `Password` 字段即为宽带账号密码明文。

> 参考实战教程：[利用 PPPOE 认证获取路由器中宽带账号密码](https://mp.weixin.qq.com/s?__biz=MjM5NjA0NjgyMA==&mid=2651068274&idx=2&sn=95cb96c6e0f0e4da865c529a29195a50)  
> 关联 CTF 流量分析题型：[[0w1club-ctf-misc-writeup-steganography-traffic-analysis]]（含 PPPoE/PAP 流量提取密码并修复 ZIP 文件头的完整解题过程）

### Demo：基于 ARP 欺骗的中间人攻击

#### ARP 协议核心机制
- **ARP 请求**：广播询问 “谁拥有 IP X？请把 MAC 告诉我”。
- **ARP 应答**：单播回复 “IP X 对应 MAC Y”。
- **缓存更新**：收到应答（甚至免费 ARP/Gratious ARP）即更新本地 ARP 表，**无状态、无验证**，是欺骗根因。

#### 攻击流程
1. **网络探测**：`netdiscover` / `arp-scan` / `nmap -sn` 发现网段存活主机（网关 IP、目标 IP）。
2. **ARP 投毒**：
   - 向目标发送伪造 ARP 应答：**“我是网关”**（攻击者 MAC 绑定网关 IP）。
   - 向网关发送伪造 ARP 应答：**“我是目标”**（攻击者 MAC 绑定目标 IP）。
3. **开启 IP 转发**：`echo 1 > /proc/sys/net/ipv4/ip_forward`，防止流量中断导致拒绝服务。
4. **流量截获/篡改**：目标 ↔ 网关 的所有流量经攻击机中转，可用 Wireshark 分析或 Ettercap/Bettercap 实时解析 HTTP、DNS、FTP 等明文协议凭证。

#### Ettercap 图形化实战
- **优势**：GUI 降低新手门槛，内置插件支持 DNS 欺骗、SSL 剥离、密码收集等后利用模块。
- **操作要点**：
  1. `Sniff → Unified sniffing` 选择接口。
  2. `Hosts → Scan for hosts` → `Hosts list` 添加 Target1（网关）、Target2（受害者）。
  3. `Mitm → ARP poisoning` 勾选 `Sniff remote connections`。
  4. `Start → Start sniffing` 即开始投毒。
  5. 切换到 Wireshark 或 Ettercap 自带 `View → Connections` 查看劫持到的明文凭证。

> 同类系统化教程：[[0w1club-week2-wifi-hijacking-arp-spoofing]]（涵盖 netdiscover、arpspoof、Wireshark、ettercap、bettercap 多工具对比与完整攻击链）  
> IoT 场景实战：[[ar-drone-2.0-penetration-testing]]（AR Drone 2.0 视频流 ARP 中间人劫持与 UDP 控制协议序列号伪造）

### HTTPS 与中间人攻击的对抗分析

#### 为什么 ARP 欺骗在 HTTPS 下“失效”？
- **传输层加密**：TLS 在 TCP 之上建立加密通道，**应用层数据（HTTP 报文）被加密**，中间人仅能看到 ClientHello/ServerHello、证书链、加密应用数据，无法直接解密或篡改。
- **证书信任链验证**：客户端验证服务器证书是否由受信 CA 签发、域名是否匹配、有效期、吊销状态。攻击者自签证书或伪造证书**无法通过系统/浏览器内置根 CA 信任存储的验证**，会触发证书错误警告。

#### 实战演示：如何“绕过”HTTPS 防御（教学演示环境）
1. **自签 CA 根证书**：`openssl` 生成根密钥与自签证书。
2. **为目标域名签发叶子证书**：利用私有 CA 为 `example.com` 签发证书（含 SAN 扩展）。
3. **导入受害者信任存储**：
   - Windows：`certmgr.msc` → “受信任的根证书颁发机构” → 导入根证书。
   - Linux：`/usr/local/share/ca-certificates/` + `update-ca-certificates`。
   - 浏览器：设置 → 隐私与安全 → 管理证书 → 导入。
4. **中间人代理**：运行 `mitmproxy` / `Burp Suite` / `bettercap -caplet https.proxy`，配置上游证书为步骤 2 生成的叶子证书。
5. **效果**：受害者访问 `https://example.com` 时，浏览器显示“安全”，中间人可在代理界面查看/修改明文 HTTP 报文。

#### 防御视角关键点
- **HSTS（HTTP Strict Transport Security）**：强制 HTTPS，防止 SSL Strip 降级攻击。
- **证书透明度 / CT 日志监控**：及时发现针对域名的误签/恶意签发证书。
- **HPKP（已废弃）→ Expect-CT**：防止 CA 滥签。
- **客户端证书绑定 / 证书锁定**：移动 App、IoT 设备内置公钥哈希，拒绝非预期证书。
- **用户教育**：**绝不在不可信环境（公共 Wi-Fi、实验室演示网络）手动导入根证书**，遇到证书错误应终止访问。

> 早期社团分享会记录：[[0w1club-wechat-archive-201707-201903]]（含「伪造证书搞事情」分享会预告与实况，W7 期）

## 工具与资源汇总

| 类别 | 工具/资源 | 用途 |
|------|-----------|------|
| 流量分析 | **Wireshark** | 抓包、过滤、协议解析、导出对象 |
| ARP 投毒 | **Ettercap**（GUI/CLI）、bettercap、arpspoof | 中间人攻击自动化、插件扩展 |
| 网络发现 | netdiscover、arp-scan、nmap -sn | 存活主机/网关识别 |
| PPPoE 服务端 | rp-pppoe / pppoe-server | 仿真宽带接入服务器 |
| HTTPS 代理 | mitmproxy、Burp Suite、bettercap | TLS 终端中间人、明文查看/篡改 |
| 证书操作 | OpenSSL、certutil、mkcert | 自签 CA、叶子证书生成、信任存储管理 |
| 参考教程 | [利用 PPPOE 认证获取路由器中宽带账号密码](https://mp.weixin.qq.com/s?__biz=MjM5NjA0NjgyMA==&mid=2651068274&idx=2&sn=95cb96c6e0f0e4da865c529a29195a50) | 完整图文实操步骤 |

## 关联知识页面

- [[0w1club-week2-wifi-hijacking-arp-spoofing]] — ARP 欺骗系统化教程（第二周/第六期/W6 预告/2018 分享会记录）
- [[0w1club-ctf-misc-writeup-steganography-traffic-analysis]] — CTF MISC 流量分析题：PPPoE/PAP 提取密码 + ZIP 修复 + Base64 解码
- [[ar-drone-2.0-penetration-testing]] — 无人机视频流 ARP 中间人劫持与 UDP 控制劫持实战
- [[0w1club-wechat-archive-201707-201903]] — 社团早期文章索引，含 ARP 攻击分享会、伪造证书分享会（W7）
- [[0w1club-wechat-archive-201908-202207]] — 社团后期文章索引，含萌新培养系列、实验室导航
- [[burpsuite-basics-tutorial]] — Burp Suite 代理/Repeater/Scanner/Intruder 入门，可用于 HTTPS 中间人代理实战
- [[jwt漏洞原理与实战利用]] — JWT 算法混淆/密钥爆破/None Algorithm 等漏洞，结合 0w1Club CTF 实战

## 社团背景

**0w1 网络安全俱乐部**（西安交通大学）  
- 微信公众号：`0w1Club`  
- 定期开展“萌新培养”系列分享会，涵盖 Web、逆向、PWN、密码学、网络攻防、IoT 安全等方向。  
- 历史文章归档见 [[0w1club-wechat-archive-201707-201903]] 与 [[0w1club-wechat-archive-201908-202207]]。

---

*本页面基于 0w1Club 微信公众号预告原文与实况总结整理，旨在构建结构化、可交叉引用的知识库条目，供安全入门学习者与社团成员快速检索、复现与拓展。*

## 来源

- [0w1网络安全俱乐部-201707-201903_32](../sources/0w1网络安全俱乐部-201707-201903_32.md)
