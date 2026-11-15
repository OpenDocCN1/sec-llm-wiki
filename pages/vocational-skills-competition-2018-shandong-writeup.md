---
title: 中职生技能大赛2018山东省赛网络空间安全赛项流量分析题解
description: 2018年山东省中职生技能大赛网络空间安全赛项「数据分析与取证」任务完整 Writeup。基于 attack.pcapng 流量包，使用
  Wireshark 还原黑客 SYN 扫描、DVWA 弱口令登录、一句话木马连接、文件下载全攻击链，提取 7 个 Flag。
category: uncategorized
tags:
- CTF
- 流量分析
- Wireshark
- 中职技能大赛
- 网络空间安全
- DVWA
- Writeup
- '2018'
date: 2018-01-01
updated: '2026-11-15'
---
## 概况

- **赛事**：中职生技能大赛 2018 山东省赛  
- **赛项**：网络空间安全  
- **任务**：任务八「数据分析与取证」  
- **环境**  
  - 目标服务器：Windows Server 2003（administrator / 空密码）  
  - 攻击机：Windows XP（administrator / 123456）  
- **素材**：`attack.pcapng`（位于 Windows XP 桌面）  
- **工具**：Wireshark  

## 题目清单与 Flag

| # | 考点 | Flag 格式 | 答案 |
|---|------|-----------|------|
| 1 | 黑客 IP | `[IP地址]` | `192.168.133.136` |
| 2 | 扫描端口（低→高） | `[端口名1,端口名2,…]` | `20,22,30,40,80,81,100` |
| 3 | 获得的用户名 | `[用户名]` | `admin` |
| 4 | 获得的密码 | `[密码]` | `password` |
| 5 | 一句话木马密码 | `[一句话密码]` | `hello112233` |
| 6 | 下载文件名 | `[文件名.后缀名]` | `BS.ZIP` |
| 7 | 文件内容 | `[文件内容]` | *(见下文图片导出内容)* |

## 解题复盘

### 确定攻击者 IP
打开 `attack.pcapng`，会话列表中仅 `192.168.133.136` 主动发起请求，直接作为 Flag 1 提交。

### 端口扫描识别
- 过滤 `tcp.flags.syn == 1 && tcp.flags.ack == 0`  
- 发现该 IP 向 `10.2.7.31` 依次发送 SYN 包，目标端口为 **20, 22, 30, 40, 80, 81, 100**  
- 目标主机对部分端口回复 SYN/ACK，确认扫描成功  
- 按升序提交 Flag 2  

> 该过程即典型 **SYN 半开扫描**，可关联 [[ctf-misc入门与工具箱]] 中“流量分析”章节的端口扫描识别技巧。

### DVWA 弱口令登录
- 在 HTTP 流中出现 `dvwa` 关键路径  
- 追踪 HTTP POST 登录包，明文可见 `username=admin&password=password`  
- Flag 3/4 直接获得  

> DVWA（Damn Vulnerable Web App）常用于 Web 安全教学，亦见于 [[ctf-flask-path-traversal-vim-crypto]] 等实战题目。

### 一句话木马连接
- 继续向下翻阅 HTTP 请求，发现 `upload` 相关路径  
- 查询字符串含 `cmd=...&pwd=hello112233` 典型 PHP 一句话特征  
- Flag 5 为 `hello112233`  

### 文件下载与导出
- 从流量尾部反向搜索 `GET` 请求，发现 `BS.ZIP` 下载响应（HTTP 200 OK）  
- 右键「Follow → HTTP Stream」→「Save As」导出 `BS.ZIP`  
- 解压查看内容，作为 Flag 7 提交（原文以图片形式展示，此处略）  

> 导出对象方法通用于 [[usb流量取证与隐写综合实战]] 中的文件提取流程。

## 附件与参考

- **原文链接**：微信公众号「启维安全」历史推文（已失效）  
- **视频讲解**：[Bilibili av53814616](https://www.bilibili.com/video/av53814616)  
- **相关训练平台**：PY-B7 靶机、磐云赛题库（文中提及）  

## 交叉引用

- [[ctf-misc入门与工具箱]] — 流量分析核心工具链与隐写/取证速查表  
- [[ctf-beginner-self-study-guide]] — Writeup 驱动学习法，适合将本题作为入门案例沉淀笔记  
- [[usb流量取证与隐写综合实战]] — 同类 PCAP 文件导出、协议还原实战链路  
- [[ctf-flask-path-traversal-vim-crypto]] — DVWA 等靶场在 CTF 题目中的常见利用模式  

## 小结

本题以 **单一 PCAP 文件串联「扫描 → 弱口令登录 → WebShell 连接 → 文件下载」完整攻击链**，考点集中在 Wireshark 显示过滤器、HTTP 明文追踪、文件导出三项基本功。适合作为 **CTF Misc/流量分析入门** 与 **中职赛前热身** 的标准练习。

## 来源

- [226安全团队-201805-202103_15](../sources/226安全团队-201805-202103_15.md)
