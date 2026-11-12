---
title: 0W1 Club CTF MISC Writeup：JPEG 多层隐写分离、流量提取 ZIP 伪加密修复与 PNG 头部修复、WiFi 名称推理定位
description: 详细记录 0W1 网络安全俱乐部微信归档中 MISC 方向三道题目的完整解题过程：JPEG 多层隐写文件分离技术、Wireshark 流量分析提取
  ZIP 文件并修复伪加密与 PNG 头部校验、通过 WiFi 名称拼音声母推理地理位置。涵盖 WinHex、Wireshark、Binwalk 等工具实战用法。
category: ai-security
tags:
- 0W1Club
- CTF
- MISC
- Writeup
- 隐写术
- JPEG文件结构
- Wireshark
- 流量分析
- ZIP伪加密
- PNG头部修复
- CRC校验
- WiFi定位
- 脑洞题
- WinHex
- 取证分析
date: '2019-11-20'
updated: '2026-11-13'
---

## 概述

本页面整理自 0W1 网络安全俱乐部微信公众号归档文章「题解 | MISC」，详细记录了三道 CTF MISC 方向题目的完整解题思路与工具操作步骤。题目涵盖 **JPEG 多层隐写文件分离**、**Wireshark 流量提取 ZIP 伪加密修复与 PNG 头部 CRC 校验修复**、**WiFi 名称拼音声母推理地理位置** 三大技术点，适合 CTF 初学者与取证分析爱好者参考学习。

> 归档来源：[[0w1club-wechat-archive-201908-202207]]  
> 关联团队主页：[[0w1club-wechat-archive-201707-201903]]

---

## 题目一：再也不用担心我1T的资源被妈妈发现啦 —— JPEG 多层隐写分离

### 核心考点
- JPEG 文件结构识别（SOI `FF D8`、EOI `FF D9`）
- 文件尾部追加数据隐写
- 多层嵌套隐写分离
- WinHex 十六进制编辑器实战

### 解题步骤

#### 文件后缀欺骗与 ZIP 提取
- 用 **WinHex** 打开题目给出的图片文件，发现文件末尾 **不是标准的 JPEG 结尾（`FF D9`）**。
- 将文件后缀改为 `.zip`，直接解压得到 `interim2.jpg`。

#### 二层 JPEG 隐写分离
- 用 WinHex 打开 `interim2.jpg`，发现文件中 **存在多处 JPEG 结尾标记（`FF D9`）**，推测有另一张图片隐藏在后面。
- 定位第二张 JPEG 的起始位置（`FF D8`），将后半段数据 **导出** 为 `interim1.jpg`。

#### Flag 提取
- 用 WinHex 打开 `interim1.jpg`，查看文件尾部即可直接看到 Flag。
- 也可将隐藏文件完全分离出来查看。

### 技术总结
| 步骤 | 关键特征 | 操作工具 |
|------|----------|----------|
| 1 | 文件尾非标准 EOF，实为 ZIP | WinHex、修改后缀 |
| 2 | 单文件内多个 `FF D9` / `FF D8` | WinHex 导出数据块 |
| 3 | Flag 明文存于最内层图片尾部 | WinHex 直接查看 |

> 同类隐写技术延伸阅读：[[0w1club-week2-wifi-hijacking-arp-spoofing]]（网络流量取证基础）、[[ar-drone-2.0-penetration-testing]]（固件提取与文件系统分析）

---

## 题目二：和咩咩的PY交易 —— 流量提取 ZIP 伪加密修复 + PNG 头部修复

### 核心考点
- Wireshark HTTP 流追踪与文件导出
- ZIP 伪加密原理（全局方式标志位 `General Purpose Bit Flag`）
- PNG 文件头结构（IHDR Chunk）与 CRC32 校验修复
- 图片拼接与尺寸修复

### 解题步骤

#### Wireshark 流量分析提取 ZIP
- 用 **Wireshark** 打开流量包，过滤 `http` 协议。
- 发现 **POST 请求**，右键 → **Follow → TCP Stream**，在数据流中导出原始数据为 ZIP 文件。

#### ZIP 伪加密修复
- 用 WinRAR 打开提示 **加密**，但用 360 解压 / 7-Zip 可直接打开（自动修复）。
- **原理**：ZIP 中央目录区的 **全局方式标志（偏移 `0x06` 处，对应 `50 4B 01 02` 结构中的第 7-8 字节）** 被修改为 `09 00`（加密标志），标准值应为 `00 00`。
- **修复方法**：
  - WinHex 打开 ZIP，搜索 `50 4B 01 02`，将紧随其后的 `09 00` 改为 `00 00`。
  - 或直接使用 WinHex 菜单 **Tools → Repair Archive** 自动修复。

#### 图片合并与 PNG 头部修复
- 解压得到 `flag1`、`flag2` 两部分，合并为一张 PNG 图片。
- 打开发现 **图片不显示/损坏**，用 WinHex 检查 PNG 文件头：
  - **IHDR Chunk** 的 **宽度/高度** 被篡改。
  - **CRC32 校验值** 与计算值不匹配（IDCH 应为 IHDR，文章中有笔误）。
- **修复**：
  - 根据图片实际像素推算正确宽高（或通过脚本暴力枚举）。
  - 重新计算 CRC32 并写回。
- 修复后即可正常打开图片得到 Flag。

### 关键结构对照表

| 格式 | 关键偏移/字段 | 正常值 | 题目篡改值 | 修复工具 |
|------|---------------|--------|------------|----------|
| ZIP 中央目录 | General Purpose Bit Flag (offset 0x06) | `00 00` | `09 00` | WinHex / 7-Zip |
| PNG IHDR | Width / Height (4+4 bytes) | 实际尺寸 | 错误值 | WinHex + CRC 计算脚本 |
| PNG IHDR | CRC32 (4 bytes) | 标准 CRC32(IHDR+data) | 错误值 | 自动重算 |

> 相关流量分析基础：[[burpsuite-basics-tutorial]]（HTTP 抓包改包）、[[frp内网渗透应用]]（流量隧道与提取）

---

## 题目三：女神的位置 —— WiFi 名称拼音声母推理地理位置（脑洞题）

### 核心考点
- WiFi SSID 信息泄露地理位置
- 拼音声母缩写推理
- 开源情报（OSINT）结合地图搜索

### 解题思路
1. 解压包中包含聊天记录，提到 **WiFi 名称** 为 `qthjfsbg...`。
2. 猜测 `bg` 为 **“宾馆”** 拼音声母，**前 6 字母 `qthjfs`** 亦为拼音声母缩写。
3. 聊天记录提到 **“温州”**，搜索温州七天酒店不符。
4. 搜索地名发现 **“青田”**，结合 `qthjfs` → **青田皇家风尚宾馆**。
5. Flag 格式：`flag{青田皇家风尚宾馆}`。

### 技术启示
- **WiFi SSID 常泄露商户名、地名缩写**，结合地图 API（高德、百度、Google Maps）可快速定位。
- 类似技术用于 **红队侦察**、**物理渗透前期信息收集**。
- 推荐工具：`Wigle.net`、 `Kismet`、 `Airodump-ng` 采集周边 WiFi 指纹。

---

## 工具箱速查

| 工具 | 用途 | 本文涉及操作 |
|------|------|--------------|
| **WinHex** | 十六进制编辑、文件结构分析、ZIP 修复、PNG 头部修改 | 全题通用 |
| **Wireshark** | 流量包分析、TCP 流追踪、文件导出 | 题目二 |
| **7-Zip / 360解压** | 自动容错 ZIP 伪加密 | 题目二 |
| **Binwalk** | 固件/文件多层嵌套自动提取（可替代手动 WinHex） | 题目一延伸 |
| **Python (struct/zlib/crcmod)** | PNG CRC32 重算、尺寸暴力枚举脚本 | 题目二延伸 |
| **地图搜索 / Wigle.net** | WiFi SSID 地理定位 | 题目三 |

---

## 知识延伸与关联页面

| 方向 | 关联页面 | 说明 |
|------|----------|------|
| 团队文章索引 | [[0w1club-wechat-archive-201908-202207]] | 0W1 Club 2019-2022 微信归档总索引 |
| 团队早期招新 | [[0w1club-wechat-archive-201707-201903]] | 战队定位、战绩、文化介绍 |
| Web 方向 Writeup | [[0w1club-ctf-web-writeup-hash-extension-rsa]] | 哈希长度扩展、PHP 弱类型、RSA 解密 |
| 网络攻击基础 | [[0w1club-week2-wifi-hijacking-arp-spoofing]] | ARP 欺骗、中间人攻击、Wireshark 实战 |
| 无线安全 | [[knob-bluetooth-bredr-key-negotiation-vulnerability]] | KNOB 攻击、蓝牙密钥协商降级 |
| 物联网固件分析 | [[ar-drone-2.0-penetration-testing]] | 固件提取、文件系统分析、Telnet 后门 |

---

## 结语

三道题目层层递进：
1. **文件结构层面** 的多层隐写分离（JPEG + ZIP）；
2. **网络流量层面** 的文件提取 + 伪加密修复 + 图片头部校验修复；
3. **开源情报层面** 的 WiFi 指纹推理定位。

掌握 **十六进制编辑器（WinHex/010 Editor）**、**流量分析（Wireshark）**、**常见文件格式规范（ZIP/PNG/JPEG）**、**CRC32 校验算法** 与 **OSINT 思维**，即可覆盖绝大多数 CTF MISC 基础题型。建议配合 [[burpsuite-basics-tutorial]]、[[frp内网渗透应用]] 等页面，构建完整的 **取证-流量-隐写-情报** 技能树。

---

> 页面维护：数字知识库策展人 | 来源：0W1 Club 微信公众号归档 | 更新日期：2025-08-24

## 来源

- [0w1网络安全俱乐部-201707-201903_05](../sources/0w1网络安全俱乐部-201707-201903_05.md)
