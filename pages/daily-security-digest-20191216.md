---
title: 每日安全看点 2019-12-16
description: 汇总 2019 年 12 月 16 日每日安全看点，涵盖内网渗透实战、WinRAR 逆向破解、CTF 心路历程、Docker 容器安全系列、Shodan
  Android 客户端、Real World CTF 2019 Safari 漏洞利用、CDPSvc Windows 提权、ReverseTCPShell C2
  框架及 BurpSuite JS/HTML 接口发现插件等资讯
category: ai-security
tags:
- 每日安全看点
- 2019年12月
- 内网渗透
- 逆向工程
- WinRAR
- CTF
- Docker安全
- 容器安全
- Shodan
- Safari漏洞
- RealWorldCTF
- Windows提权
- CDPSvc
- C2框架
- ReverseTCPShell
- BurpSuite插件
- JS接口发现
date: '2019-12-16'
updated: '2026-11-13'
---

## 概览

本期每日安全看点汇总了 2019 年 12 月 16 日的 11 篇安全技术资讯，涵盖 **内网渗透实战**、**逆向破解**、**CTF 竞赛心得**、**Docker 容器安全系列**（3 篇）、**安全工具**、**浏览器漏洞利用**、**Windows 本地提权**、**C2 框架** 及 **BurpSuite 插件开发** 等方向。

---

## 渗透测试与内网渗透

### 实战讲解内网渗透思路

- **来源**：阿里云安全（先知社区）
- **链接**：<https://xz.aliyun.com/t/6920>
- **要点**：系统梳理从外网入口到内网核心资产的完整渗透路径，包括信息收集、漏洞利用、权限提升、横向移动、持久化控制及痕迹清理等阶段的实战技巧与工具选型。
- **关联阅读**：[[frp内网渗透应用]] 中详细记录了 frp 在内网渗透中的 Socks5 隧道、多级隧道串联、代理 Metasploit 反弹及 RDP 端口转发等典型应用场景，可作为本文“横向移动/隧道搭建”阶段的工具落地参考。

---

## 逆向工程

### 逆向实战——32位和64位 WinRAR 破解及去广告

- **来源**：SecPulse
- **链接**：<https://www.secpulse.com/archives/120400.html>
- **要点**：详细记录对 WinRAR（32 位与 64 位）的逆向分析过程，定位注册校验逻辑与广告弹窗代码，通过修改关键跳转指令实现注册绕过与去广告，附带关键偏移地址与 Patch 示例。

---

## CTF 竞赛与心路历程

### CTF — 一部黑客心灵史

- **来源**：微信公众号
- **链接**：<https://mp.weixin.qq.com/s/wEqBaZmO8FwOyGrcWDNgYQ>
- **要点**：以第一人称视角回顾作者从接触 CTF 到深入钻研的成长轨迹，剖析比赛心态、知识体系构建、工具链演进及团队协作经验，适合初入 CTF 领域的读者参考。

---

## Docker 容器安全专题（三篇连载）

### Docker 容器安全性分析

- **来源**：FreeBuf
- **链接**：<https://www.freebuf.com/articles/system/221319.html>
- **要点**：从 Docker 架构、Namespace 隔离、Cgroups 资源限制、Capabilities 权限模型、镜像安全、网络安全、运行时安全等维度系统分析容器攻击面与防御基线。

### 攻击和审计 Docker 容器（01）

- **来源**：微信公众号
- **链接**：<https://mp.weixin.qq.com/s/_9vykBJfKA1K6J-ducLKcA>
- **要点**：实战演示容器逃逸、镜像投毒、敏感文件挂载、Docker Daemon 未授权访问等常见攻击手法，并给出对应的审计检查清单与加固建议。

### 攻击和审计 Docker 容器（02）

- **来源**：微信公众号
- **链接**：<https://mp.weixin.qq.com/s/UjSGAUIy1KIXa-hDggaLLw>
- **要点**：进阶篇，重点讲解 Kubernetes 环境下的容器安全审计、RBAC 权限滥用、Pod 安全策略绕过、供应链攻击检测及运行时异常行为监控（Falco/Sysdig 等）。

> **知识关联**：上述三篇内容与 [[docker-container-security-fundamentals]] 中系统梳理的 Docker 核心安全机制（Namespace、Cgroup、Capability、AppArmor/SELinux 加固方案）高度呼应，建议配合阅读以构建完整容器安全知识体系。

---

## 安全工具与平台

### Shodan.io Android 官方客户端

- **项目地址**：<https://github.com/PaulSec/Shodan.io-mobile-app>
- **简介**：Shodan 官方发布的 Android 客户端，支持在移动端直接检索互联网资产、查看端口服务、漏洞标签、地理分布等，便于渗透测试人员随时随地开展资产侦察。

---

## 漏洞利用与浏览器安全

### Real World CTF 2019 对 Safari 漏洞的利用

- **来源**：GTS3 博客
- **链接**：<https://gts3.org/2019/Real-World-CTF-2019-Safari.html>
- **要点**：详细复现 Real World CTF 2019 中针对 Safari (WebKit/JavaScriptCore) 的漏洞利用链，涵盖漏洞成因分析、堆喷射布局、ROP 链构造、沙箱逃逸到 RCE 的完整过程，极具参考价值。

---

## Windows 本地提权

### 利用 CDPSvc 实现 Windows 本地提权

- **来源**：安课网
- **链接**：<https://www.anquanke.com/post/id/195008>
- **要点**：分析 Windows 连接设备平台服务 (CDPSvc) 在处理 DLL 加载时的权限校验缺陷，通过劫持服务加载的 DLL 实现从普通用户提升至 SYSTEM 权限，附带利用代码与影响版本范围。

---

## 红队基础设施 / C2 框架

### 红队利器：ReverseTCPShell C2 框架

- **项目地址**：<https://github.com/ZHacker13/ReverseTCPShell>
- **简介**：基于反向 TCP 连接的轻量级 C2 框架，支持多会话管理、动态加密通信、模块化插件扩展（截屏、键盘记录、文件管理、横向移动等），适合红队演练快速部署。

---

## BurpSuite 插件开发

### BurpSuite 插件：找到 JS 和 HTML 中接口

- **项目地址**：<https://github.com/j1anFen/burp_jspath>
- **功能**：自动解析 HTTP 响应中的 JavaScript 文件与 HTML 页面，提取其中的 API 路径、端点参数、AJAX 请求 URL 等，辅助渗透测试人员快速发现隐藏接口与前端路由，提升 Web 攻击面挖掘效率。

---

## 同期安全看点导航

- [[daily-security-digest-20191217]] — 12 月 17 日：鱼叉式攻击、针孔摄像头检测、CTF PWN、远控免杀
- [[daily-security-digest-20191218]] — 12 月 18 日：TP-Link 漏洞、比特币区块链隐藏 C2、Cobalt Strike 免杀、SysWhispers、Chrome UAF 沙箱逃逸
- [[daily-security-digest-20191219]] — 12 月 19 日：区块链智能合约逆向、儿童 GPS 手表隐私、DLL 镂空、网站镜像复制
- [[daily-security-digest-20191220]] — 12 月 20 日：APT-C-08 蔓灵花分析、zzzphp SQL 注入、Facebook 手机号泄露
- [[daily-security-digest-20191223]] — 12 月 23 日：ATT&CK/APT 归因、Project Zero 在野漏洞、Chrome WebSQL RCE、RealWorldCTF VMware Fusion RCE、Mozi 僵尸网络
- [[daily-security-digest-20191224]] — 12 月 24 日：内网穿透端口转发、PHP 木马、零知识证明、Hypervisor 虚拟化安全
- [[daily-security-digest-20191225]] — 12 月 25 日：机器学习测试 WAF、Django CVE-2019-19844、DarkRat、Empire 3.0
- [[daily-security-digest-20191226]] — 12 月 26 日：FLIRT 符号恢复、Binary Ninja 去混淆、OLLVM、Fuzzing 会议资料
- [[daily-security-digest-20191227]] — 12 月 27 日：Web API 安全、Google Cloud Shell 漏洞、iOS 代码签名、SOP 绕过、Nightmare 逆向入门
- [[daily-security-digest-20191230]] — 12 月 30 日：Google XSS 技巧、Metasploit DoS CVE-2019-5645、移动端渗透测试教程、Fuzzing 漏洞挖掘

---

## 小结

本期看点呈现 **“实战技能 + 基础理论 + 工具生态”** 的立体结构：内网渗透与 Windows 提权提供落地攻击技术；WinRAR 逆向与 Safari 漏洞利用深化漏洞挖掘与利用能力；Docker 三连载系统构建容器安全知识树；Shodan 移动端、ReverseTCPShell、BurpSuite 插件则拓展红队工具箱与资产侦察能力。建议读者按需深入研读，并结合关联页面（如 [[docker-container-security-fundamentals]]、[[frp内网渗透应用]]）形成完整知识闭环。

## 来源

- [0th3rs安全团队-201911-202204_113](../sources/0th3rs安全团队-201911-202204_113.md)
