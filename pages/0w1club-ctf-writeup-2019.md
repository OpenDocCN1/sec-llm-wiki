---
title: 0W1Club 第三届 CTF 竞赛完整题解
description: 西安交通大学 0W1 网络安全俱乐部第三届 CTF 校内赛全题目 Writeup，涵盖逆向工程、密码学、隐写术、Web 安全（SQL注入、Cookie
  伪造、Host 头注入）等多方向挑战，附获奖名单。
category: ai-security
tags:
- 0W1Club
- CTF
- Writeup
- 逆向工程
- 密码学
- 隐写术
- Web安全
- SQL注入
- 二维码拼图
- 获奖名单
- 西安交通大学
- 网络安全社团
- 微信归档
date: 2019-12-01
updated: '2026-11-14'
---

## 概述

本页面记录 **西安交通大学 0W1 网络安全俱乐部第三届 CTF 校内赛** 的完整题目解析。比赛设置 13 道题目，总分 1600 分，涵盖 **Reverse、Crypto、Misc、Web** 四大类别。文章原为微信公众号推送，现整理为结构化知识页面，便于交叉引用与检索。

> 关联索引：[[0w1club-wechat-archive-201707-201903]]、[[0w1club-first-ctf-writeup-2018]]、[[0w1club-ctf-web-writeup-jwt-sqli-brute]]、[[0w1club-ctf-web-writeup-hash-extension-rsa]]、[[0w1club-ctf-crypto-writeup-easyrsa-t9]]、[[0w1club-ctf-misc-writeup-steganography-traffic-analysis]]

---

## Reverse 方向

### HelloWorld-75（作者：沈俞霖）

**考点**：Windows 程序调试、PDB 符号加载、反汇编分析、字符串比对

- 程序运行后提示输入，任意输入显示 "Try again!!!"。
- 使用 Visual Studio 附加进程调试，需加载 `re.pdb`（由题目提供的 `没我你就做不出题.pdb` 重命名而来）。
- 反汇编中定位 `check` 函数，发现对输入字符串与硬编码字符串 `balabala` 进行比较。
- 输入 `balabala` 提示 "You Are Right!"，按格式加前缀得 Flag：**`0w1balabala`**。

### 解方程-300（作者：沈俞霖）

**考点**：图片隐写、Binwalk 提取、Zip 解包、线性方程组求解

- 题目给一张图片，`binwalk` 发现内嵌 Zip 文件，改后缀解压得到 `解方程.c`。
- 代码逻辑：输入字符串需满足 6 个线性方程，满足则输出 "You are right!"。
- 使用 Python / MATLAB / 在线求解器解方程组，将解转 ASCII 码得 Flag：**`0W1CTF`**。

### reverseMe-200（作者：尹赫泽）

**考点**：文件反转、文件头识别、图片翻转

- 提供二进制文件 `reverseMe`，编写 C++ 程序将字节序反转输出为 `a.jpg`。
- 十六进制查看首尾 `FF D8` / `FF D9` 确认为 JPEG。
- 打开图片发现 Flag 左右翻转，再次水平翻转得 Flag：**`flag{4f7548f93c7bef1dc6a0542cf04e796e}`**。

---

## Crypto 方向

### cipher-50（作者：尹赫泽）

**考点**：猪栏密码

- 给出猪栏密码图片，按 [Wikipedia 映射表](https://en.wikipedia.org/wiki/Pigpen_cipher) 解密。
- 推测大小写格式，得 Flag：**`0w1kelabu`**。

### zip-150（作者：尹赫泽）

**考点**：多层 Base 编码嵌套

- 密文：`SlZFR0c2Q1pHSjREQ1dMTEdWWUdJVktLT0JRVkNQSjVIVT09PT09PQ==`
- 依次 Base64 → Base32 → Base64 解码，最终得：**`0w1clubNiuBii`**。

---

## Misc 方向

### 跑包-75（作者：尹赫泽）

**考点**：WPA 握手包破解、GPU 加速、Hashcat

- 工具：`cap2hccapx` 转换格式 → `hashcat -m 2500` 跑字典。
- 破解出密码：**`12345678`**。

### base-75（作者：尹赫泽）

**考点**：Zip 伪加密、标志位修复

- 外层 Zip 爆破得密码 `9527`，解压得 `res.zip`。
- 内层 Zip 爆破失败，修改加密标志位为未加密（伪加密），解压得 `res.txt`。
- Flag：**`flag{a98hd908h129ejhdi9anduba9a9scjkop09080jh912e4ausdcvbjni0dh}`**。

### 拼图-200（作者：沈俞霖）

**考点**：二维码手工拼接、QR Code 结构分析、定位图案恢复

- 6 个二维码碎片，人工识别为 0/1 矩阵，共 4 个 7×15 碎片 + 1 个 15×15 碎片。
- 推测为 Version 3 (29×29) 二维码，缺失 3 个 7×7 定位图案。
- 参考 QR Code 固定 Pattern，用 Excel 转黑白图、PS 拼接 Alignment 与 Timing Pattern。
- 最终拼得完整二维码，扫码得 Flag：**`0w1IsWatchingYou!`**。

---

## Web 方向

### 跑路的管理员-50（作者：Wind-Wing）

**考点**：前端源码审计、长行隐藏

- 页面空白，源码提示 "answer is in the 1000th line"。
- 第 1000 行极长，需横向拖动滚动条查看最右侧 Flag。

### 管理员的礼物-75（作者：Wind-Wing）

**考点**：Host 头注入、本地回环访问绕过

- 提示 "只有管理员的机器可以看见"，结合上题推测服务跑在本机。
- Burp Suite 抓包，修改 `Host: localhost:10243` 或 `127.0.0.1:10243` 重放，返回 Flag。

### 管理员的饼干-100（作者：Wind-Wing）

**考点**：Cookie 伪造、MD5 长度扩展推理

- 抓包发现 Cookie 中 `usr=5486ff055guest`。
- 分析：`5` 为 "guest" 长度，`486ff055` 为 MD5(guest)[10:18]。
- 尝试 `root`、`admin`、`administrator`，验证为 `administrator`。
- 构造 `usr=5486ff055administrator` 对应 MD5 片段，修改 Cookie 得 Flag。

### 管理员的密码-200（作者：Wind-Wing）

**考点**：SQL 注入（UNION 注入）、MD5 校验绕过、WordPress 数据库结构

- URL 参数 `id=c4ca1`，其中 `c4ca` 为 `1` 的 MD5 前 4 位校验码。
- 手工构造 UNION 注入：需匹配前查询 4 列，payload：
  ```sql
  1' union select user_login,user_pass,user_pass,user_pass from wordpress.wp_users;#
  ```
- 先算未编码 payload 的 MD5 前 4 位得 `94e51`，再 URL 编码发送。
- 成功回显管理员哈希，得 Flag。

### 管理员的迷宫-400（作者：lucky）

**考点**：基于时间序列的登录逻辑、脚本自动化、网络延迟处理

- 仅 lucky 与 syl 解出。核心：按特定时间间隔（1 秒粒度）发送请求序列完成登录。
- 需自建 PHP 环境调试，去除回显后通过脚本多次重跑抵消延迟。
- 详细脚本见原文图片序列（此处略）。

---

## 获奖名单

| 排名 | 团队 / 选手 | 得分 |
|------|-------------|------|
| 1    | lucky       | 1400 |
| 2    | syl         | 1275 |
| 3    | Wind-Wing   | 1100 |
| 4    | 尹赫泽      |  950 |
| 5    | 沈俞霖      |  875 |

> 完整榜单见图片（原文末尾），此处列出前五名。

---

## 关联知识页面

- [[0w1club-first-ctf-writeup-2018]] — 首届 CTF Writeup，包含 JS 混淆、ThinkPHP RCE、IDA 动静态分析等入门题解
- [[0w1club-ctf-web-writeup-jwt-sqli-brute]] — JWT 盐值爆破、None Alg、验证码绕过、SQL 注入等 Web 进阶题解
- [[0w1club-ctf-web-writeup-hash-extension-rsa]] — 哈希长度扩展攻击、PHP 弱类型比较、RSA 解密实战
- [[0w1club-ctf-crypto-writeup-easyrsa-t9]] — RSA 大数分解、T9 九键解码
- [[0w1club-ctf-misc-writeup-steganography-traffic-analysis]] — 音频频谱、零宽字符、PPPoE/PAP 流量分析、ZIP 修复等 Misc 实战
- [[0w1club-wechat-archive-201707-201903]] — 0W1Club 微信归档总索引（2017-2019）
- [[0w1club-wechat-archive-201908-202207]] — 0W1Club 2019 秋季招新及社团简介

## 来源

- [0w1网络安全俱乐部-201707-201903_44](../sources/0w1网络安全俱乐部-201707-201903_44.md)
