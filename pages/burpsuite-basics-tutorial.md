---
title: Burp Suite 核心功能模块实战入门教程
description: 基于 0w1Club 安全团队微信归档文章整理，系统介绍 Burp Suite 安装、代理配置、Proxy 抓包改包、Repeater 复发、Scanner
  自动扫描、Intruder 密码爆破全流程，附官方练习平台与进阶学习资源。
category: ai-security
tags:
- Burp Suite
- 渗透测试
- Proxy
- Repeater
- Scanner
- Intruder
- 入门教程
- 0w1Club
date: 2019-11-15
updated: '2026-11-13'
---

## 概述

Burp Suite 是一款集成化的 Web 应用安全测试工具集，覆盖代理拦截、请求复发、自动漏洞扫描、暴力破解等核心渗透测试场景。本文基于 0w1Club 微信公众号 2019 年《HTTP 分析（下）》文章，梳理从安装到四大核心模块实操的完整入门路径。

> **来源归档**：[[0w1club-wechat-archive-201908-202207]] 中第八周服务器渗透萌新培训预告关联文章。

---

## 安装与环境准备

### Java 运行环境
Burp Suite 基于 Java 运行，需预先安装 JDK/JRE。参考教程：[CSDN Java 环境配置指南](https://blog.csdn.net/Liuhuaijin/article/details/77768690)（仅安装部分）。

### 破解版获取（仅供学习研究）
文章提供的百度网盘链接（提取码 `21vq`）已失效，建议通过官方渠道获取：
- **Community Edition 免费版**：<https://portswigger.net/burp/releases>
- **Professional 试用/授权**：<https://portswigger.net/burp/pro>

> ⚠️ 仅在授权测试环境中使用专业版功能（如 Scanner）。

---

## 代理配置：流量拦截的前置条件

Burp 核心原理是作为中间人代理截获浏览器 HTTP/HTTPS 流量。必须完成以下两步：

1. **Burp 端监听设置**  
   `Proxy → Options → Proxy Listeners` 默认 `127.0.0.1:8080`，确保 "Running" 勾选。
2. **浏览器/系统代理指向 Burp**  
   - Firefox 推荐安装 **FoxyProxy** 扩展快速切换
   - Chrome 可用 SwitchyOmega 或系统代理设置
   - 移动端需导入 Burp CA 证书（`http://burp/` 下载 `cacert.der`）以解密 HTTPS

> 常见问题排查参考：  
> - [安全客 Burp 代理配置详解](https://www.anquanke.com/post/id/85925)  
> - [腾讯云开发者社区配置指南](https://cloud.tencent.com/developer/news/288748)  
> - [简书图文教程](https://www.jianshu.com/p/9a0f964ce4f8)

---

## 核心功能模块实操

### Proxy —— 抓包与篡改的“灵魂”

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | `Proxy → Intercept → Intercept is on` | 开启拦截开关 |
| 2 | 浏览器访问目标站点（如 `www.baidu.com`） | 请求被 Burp 拦截，浏览器显示加载中 |
| 3 | 修改请求头/参数（Cookie、User-Agent、POST 数据等） | 构造“非法”数据包探测漏洞 |
| 4 | 点击 **Forward** 放行修改后的包 | 服务器响应返回后可在 `HTTP history` 查看完整交互 |

> **核心价值**：将合法请求篡改为恶意载荷（SQLi、XSS、越权等），人工验证漏洞触发条件。

### Repeater —— 单包精细调试利器

**适用场景**：需对同一端点反复修改参数、对比响应差异（如绕过 WAF、探测注入点）。

**操作流程**：
1. 在 `Proxy → HTTP history` 右键目标请求 → `Send to Repeater`
2. 切换到 `Repeater` 标签页，编辑请求任意字段
3. 点击 **Go** 发送，右侧实时显示响应；可创建多个标签页并行测试
4. 利用 `Render` 视图查看 HTML 响应，`Hex` 定位非打印字符

### Scanner —— 自动化漏洞扫描（Professional 版）

**一键扫描流程**：
1. `Proxy → HTTP history` 右键目标请求 → `Do an active scan`
2. `Scanner → Scan queue` 监控进度
3. `Scanner → Results` 查看漏洞列表（按严重级别分类：High/Medium/Low/Info）
4. 可导出 **渗透测试报告**（含漏洞详情、复现步骤、修复建议）

> **局限性**：仅覆盖已知特征漏洞（OWASP Top 10 等），业务逻辑漏洞、复杂链条仍需人工挖掘。

### Intruder —— 自动化载荷攻击（爆破/枚举/模糊测试）

**典型场景**：登录表单爆破、ID 枚举、参数模糊测试。

**配置步骤**：
1. 目标请求右键 → `Send to Intruder`
2. `Positions` 标签页：  
   - 选择攻击模式：`Sniper`（单载荷位轮询）、`Battering ram`（多位同一载荷）、`Pitchfork`（多载荷并行）、`Cluster bomb`（全排列）  
   - 用 `§` 标记载荷位置（如 `pwd=§test§`）
3. `Payloads` 标签页：  
   - 载荷集类型：Simple list（字典）、Runtime file（外部文件）、Character substitution（字符替换）、Case modification（大小写变形）等  
   - 加载弱口令字典（如 `rockyou.txt`、`top1000.txt`）
4. `Options` 调节线程、重试、Grep-Match 关键字高亮
5. 点击 **Start attack** → 结果表格按状态码、长度、Grep 匹配排序筛选

> **防御规避**：现代站点普遍启用账号锁定、验证码、WAF 限流，实战中需结合 IP 代理池、验证码识别、低频慢打等策略。

---

## 进阶学习资源体系

| 资源类型 | 推荐链接 | 核心价值 |
|----------|----------|----------|
| **官方权威文档** | <https://portswigger.net/web-security> | 涵盖所有模块深度用法、漏洞原理、实战案例 |
| **免费靶场练习** | <https://portswigger.net/web-security/all-labs> | 交互式实验环境，按漏洞类型分级（Apprentice → Practitioner → Expert） |
| **中文视频教程** | B 站搜索 “Burp Suite 实战/入门/插件开发” | 视觉化演示操作细节，适合快速上手 |
| **离线参考资料** | 文章附件百度网盘（提取码 `x7nv`） | 历史版本 PDF/视频合集，网络受限环境可用 |

---

## 实战避坑指南

| 问题现象 | 可能原因 | 解决方案 |
|----------|----------|----------|
| 浏览器无法访问任何站点 | 代理未生效/端口冲突/防火墙拦截 | 检查 `Proxy Listeners` 运行状态，更换端口（如 8081），关闭系统代理冲突软件 |
| HTTPS 站点抓包报错 `Certificate Unknown` | 未安装/信任 Burp CA 证书 | 重新导入 `cacert.der` 至系统/浏览器受信任根证书存储 |
| Scanner 扫描极慢/卡死 | 爬虫陷入无限链接/动态页面/认证失效 | 配置 `Scope` 限定目标范围，录制登录宏（`Project options → Sessions → Macros`），排除退出登录/注销链接 |
| Intruder 爆破即封 IP | 目标存在频率限制/WAF | 接入代理池（如 `Proxifier` + 付费代理），降低线程至 1-2，启用 `Throttle` 延迟 |

---

## 交叉引用与延伸阅读

- **同期培训体系**：[[0w1club-wechat-archive-201908-202207]] 中 2019-11-15 第八周服务器渗透培训预告（SSH、nmap、dirb、john、Kali 环境准备）
- **Web 漏洞实战案例**：
  - [[mtctf-2021-web-writeup]]（SQLi 绕过、PHP 反序列化条件竞争、Session Upload Progress 利用）
  - [[tctf-2021-1linephp-zip-include]]（ZIP 协议包含临时文件实现 RCE）
  - [[spring-boot-actuator配置不当rce利用]]（Actuator + H2 + JNDI 完整链复现，均需 Burp 调试）
- **内网穿透配合**：[[frp内网渗透应用]]（Socks5 隧道代理 Burp 流量至内网目标）

---

## 结语

Burp Suite 并非“自动化一键拿 Shell”的魔法工具，而是 **“放大器”**——它放大的是测试者对 HTTP 协议、Web 业务逻辑、漏洞成因的理解深度。建议学习路径：

1. **熟练掌握** Proxy/Repeater 手工测试全流程
2. **系统学习** PortSwigger Academy 所有漏洞专题实验
3. **实战积累** 在授权靶场（DVWA、BWAPP、VulnHub）复现 CVE/漏洞类型
4. **扩展生态** 探索 BApp Store 插件（Logger++, AuthMatrix, Turbo Intruder 等）提升效率

> “工具是手的延伸，思维才是渗透的核心。” —— 夜晓（原文作者）

## 来源

- [0w1Club-201908-202207_09](../sources/0w1Club-201908-202207_09.md)
