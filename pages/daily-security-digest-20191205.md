---
title: 每日安全看点 2019-12-05
description: 2019年12月5日每日安全看点汇总，涵盖Linux加壳脱壳、Redis主从复制RCE、iOS内核QEMU启动、恶意Python库窃密、Android
  Geost僵尸网络、GitLab路径遍历等安全资讯
category: ai-security
tags:
- 每日安全看点
- 2019年12月
- Linux逆向
- 加壳脱壳
- Redis
- RCE
- iOS内核
- QEMU
- 供应链攻击
- Python
- Android
- 僵尸网络
- Geost
- GitLab
- 路径遍历
date: 2019-12-05
updated: '2026-11-13'
---

## 概述

本期每日安全看点收录 7 条安全技术资讯，涵盖逆向工程、Web 安全、移动安全、供应链安全、漏洞利用等多个领域。重点包括 Linux 加壳脱壳技术、Redis 主从复制 RCE 利用方式、BlackHat 欧洲 2019 两个议题（iOS 内核 QEMU 启动、Android Geost 僵尸网络）、恶意 Python 第三方库窃取凭证、以及 GitLab 路径遍历漏洞导致管理员账户接管。

---

## 逆向工程

### Linux 逆向之加壳 & 脱壳

- **来源**：阿里云先知社区
- **链接**：<https://xz.aliyun.com/t/6881>
- **要点**：系统梳理 Linux 平台常见加壳保护机制与对应脱壳技术，适合逆向入门与进阶参考。

---

## 社会工程与舆情分析

### 近日某重大负面舆情的十点启示

- **来源**：微信公众号
- **链接**：<https://mp.weixin.qq.com/s/vuH7UTWHFAcyWrojUVvaow>
- **要点**：从舆情演进角度复盘典型案例，提炼应急响应、信息发布、危机公关等十条实战经验。

---

## Web 安全

### Redis 基于主从复制的 RCE 利用方式

- **来源**：lorexxar.cn
- **链接**：<https://lorexxar.cn/2019/07/10/redis-5-x-rce/>
- **要点**：深入分析 Redis 5.x 主从复制机制下的 RCE 攻击链，涵盖恶意模块加载、数据同步劫持等核心利用技术。
- **关联阅读**：[[cve-digest-20210401]] 中收录的 Redis 堆溢出漏洞；[[cve-digest-20210402]] 涉及 Redis 相关组件漏洞。

---

## 移动安全

### BlackHat EU 2019：在 QEMU 中启动 iOS 内核

- **来源**：BlackHat Europe 2019 幻灯片
- **链接**：<https://i.blackhat.com/eu-19/Wednesday/eu-19-Afek-Booting-The-iOS-Kernel-To-An-Interactive-Bash-Shell-On-QEMU.pdf>
- **要点**：演示如何在 QEMU 模拟器中完整引导 iOS 内核至交互式 Shell，为内核漏洞挖掘、Rootless 越狱研究提供可复现的动态调试环境。
- **关联阅读**：[[daily-security-digest-20191211]] 提及 iOS 12.0.4 内核漏洞分析；[[daily-security-digest-20191227]] 涵盖 iOS 代码签名与移动端渗透测试教程。

### BlackHat EU 2019：Android 僵尸网络 Geost 的发现

- **来源**：BlackHat Europe 2019 幻灯片
- **链接**：<https://i.blackhat.com/eu-19/Wednesday/eu-19-Garcia-Money-Doesnt-Stink-Cybercriminal-Business-Insight-Of-A-New-Android-Botnet.pdf>
- **要点**：披露 Geost 银行木马僵尸网络的技术架构、C2 通信协议、加密存储机制及商业化运营模型，涉及东欧多国金融机构受害。
- **关联阅读**：[[apt-c-08-mobile-attack-analysis]] 深度解析 APT-C-08 移动端攻击活动；[[daily-security-digest-20191220]] 涵盖蔓灵花 APT-C-08 移动攻击分析。

---

## 供应链安全

### 两个恶意 Python 第三方库存在窃取 SSH 和 GPG 公钥

- **来源**：Slashdot / 开发者社区
- **链接**：<https://developers.slashdot.org/story/19/12/04/1430223/two-malicious-python-libraries-caught-stealing-ssh-and-gpg-keys>
- **要点**：PyPI 上发现两个伪装成合法库的恶意包，通过 `setup.py` 窃取开发者主目录下的 SSH 私钥、GPG 密钥并外传，再次敲响软件供应链安全警钟。
- **关联阅读**：[[daily-security-digest-20200103]] 提及 Python 钓鱼包供应链攻击分析（CVE-2019-10758）。

---

## 漏洞复现与利用

### GitLab：通过路径遍历搞定管理员账户

- **来源**：安全客
- **链接**：<https://www.anquanke.com/post/id/194271>
- **要点**：详细复现 GitLab 任意文件读取/路径遍历漏洞（CVE-2019-5418 等变种），结合会话伪造实现管理员账户接管，附完整利用链与修复建议。
- **关联阅读**：[[cve-digest-20210325]]、[[cve-digest-20210326]]、[[cve-digest-20210402]]、[[cve-digest-20210413]] 均收录 GitLab 多版本漏洞详情。

---

## 关联每日安全看点

- 上一期：[[daily-security-digest-20191206]]（2019-12-06）
- 下一期：[[daily-security-digest-20191209]]（2019-12-09）
- 同期更多：[[daily-security-digest-20191210]]、[[daily-security-digest-20191211]]、[[daily-security-digest-20191212]]、[[daily-security-digest-20191216]]、[[daily-security-digest-20191217]]、[[daily-security-digest-20191218]]、[[daily-security-digest-20191219]]、[[daily-security-digest-20191220]]、[[daily-security-digest-20191223]]、[[daily-security-digest-20191224]]、[[daily-security-digest-20191225]]、[[daily-security-digest-20191226]]、[[daily-security-digest-20191227]]、[[daily-security-digest-20191230]]

---

## 标签索引

#每日安全看点 #2019年12月 #Linux逆向 #加壳脱壳 #Redis #RCE #iOS内核 #QEMU #供应链攻击 #Python #Android #僵尸网络 #Geost #GitLab #路径遍历

## 来源

- [0th3rs安全团队-201911-202204_119](../sources/0th3rs安全团队-201911-202204_119.md)
