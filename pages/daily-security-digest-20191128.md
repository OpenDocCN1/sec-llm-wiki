---
title: 每日安全看点 2019-11-28
description: 2019年11月28日每日安全看点汇总，涵盖AWD攻防赛经验、Visual Studio Online发布、Peach模糊测试、Chrome扩展安全入门、符号执行浅谈、最危险漏洞Top25更新、rConfig本地提权漏洞、RDP反向路径遍历RCE等安全资讯。
category: ai-security
tags:
- 每日安全看点
- 2019年11月
- AWD
- Visual Studio Online
- Peach
- 模糊测试
- Chrome扩展安全
- 符号执行
- CVE-2019-19268
- rConfig
- RDP
- 路径遍历
- RCE
- 本地提权
date: 2019-11-28
updated: '2026-11-13'
---

## 概述

本期每日安全看点汇总了 2019 年 11 月 28 日的安全技术文章与漏洞情报，涵盖攻防演练经验分享、开发工具更新、模糊测试实战、浏览器扩展安全入门、程序分析理论、漏洞排行榜更新以及多个实战漏洞利用细节。

---

## AWD 攻防赛经验分享

> **来源**：FreeBuf - [聊聊AWD攻防赛流程及准备经验](https://www.freebuf.com/articles/network/201222.html)

文章系统梳理了 AWD（Attack With Defense）攻防赛的完整流程与备战要点，包括：

- **赛前准备**：环境搭建、流量监控脚本编写、自动化打补丁工具链构建
- **比赛阶段**：服务存活监控、流量分析提取 Payload、漏洞利用脚本化、权限维持与清理痕迹
- **团队协作分工**：Web 方向、二进制方向、运维监控方向的协同配合

> **关联阅读**：[[0th3rs-security-team-wechat-archive-201911-202204]] 中记录了 0th3rs 战队在 2019 年启明星辰杯京津冀研究生网络安全大赛（AWD+CTF 双模式）中包揽总榜 4/5 名的战报。

---

## Visual Studio Online 发布

> **来源**：知乎专栏 - [重磅！微软发布 Visual Studio Online：Web 版 VS Code + 云开发环境](https://zhuanlan.zhihu.com/p/90126914)

微软正式推出 **Visual Studio Online**（后更名为 GitHub Codespaces），核心特性包括：

- **Web 版 VS Code**：浏览器中获得完整的 VS Code 编辑体验（IntelliSense、调试、终端、扩展支持）
- **云端开发环境**：按需启动的容器化环境，预装运行时、依赖与工具链，支持自定义 Dockerfile
- **即时启动**：秒级环境就绪，适配代码审查、快速修复、教学演示等场景
- **与 GitHub/Azure DevOps 集成**：无缝衔接现有 CI/CD 流水线

该发布标志着云原生开发模式进一步普及，降低了环境配置门槛，也为远程协作开发提供了新范式。

---

## Peach 模糊测试实战：从入门到放弃

> **来源**：FreeBuf - [使用Peach进行模糊测试从入门到放弃](https://www.freebuf.com/articles/ics-articles/219996.html)

文章以实战视角记录了使用 **Peach Fuzzer** 对工控协议/文件格式进行模糊测试的完整过程：

1. **数据模型构建**：定义 `DataModel` 描述协议/格式结构，包含字段类型、约束、关系
2. **状态模型设计**：用 `StateModel` 描述交互流程（如握手、命令发送、响应接收）
3. **Agent 与 Monitor 部署**：目标端运行 Peach Agent 负责用例发送与崩溃监控
4. **Fuzz 执行与结果分析**：运行模糊测试，收集崩溃样本，结合调试器定位根因
5. **常见坑点**：复杂协议状态建模困难、变异策略覆盖率不足、环境搭建繁琐、误报率高

作者总结：Peach 功能强大但学习曲线陡峭，适合有耐心深耕协议模糊测试的团体；快速验证场景下 AFL、LibFuzzer 等覆盖引导型 Fuzzer 往往更高效。

---

## Chrome 扩展安全入门（一）：了解一个 Chrome Extension

> **来源**：Lorexxar's Blog - [从0开始入门Chrome Ext安全（一）-- 了解一个Chrome Ext](https://lorexxar.cn/2019/11/22/chrome-ext-1/)

系列首篇，奠定 Chrome 扩展安全研究的基础知识体系：

- **扩展架构**：Manifest V2/V3 区别、核心组件（Background Script、Content Script、Popup、Options Page、DevTools Page）
- **权限模型**：`permissions`、`host_permissions`、`optional_permissions`、最小权限原则
- **通信机制**：Message Passing（`chrome.runtime.sendMessage`/`onMessage`）、长连接（`chrome.runtime.connect`）、外部消息（`externally_connectable`）
- **内容安全策略 (CSP)**：默认限制内联脚本、`eval()`、`new Function()`，可通过 `content_security_policy` 放宽
- **安全边界**：Content Script 与页面 DOM 共享但 JS 隔离（隔离世界）、XSS 影响面分析
- **调试技巧**：`chrome://extensions/` 开发者模式、背景页控制台、Content Script 注入调试

后续系列将深入漏洞挖掘案例（权限提升、通信劫持、CSP 绕过等）。

---

## 符号执行浅谈

> **来源**：微信公众号 - [浅谈符号执行](https://mp.weixin.qq.com/s/OBmtWCSxX8IESO50EyZRLQ)

文章从原理到工程实践系统介绍 **符号执行** 技术：

- **核心思想**：用符号值替代具体输入，程序执行路径构建路径约束（Path Constraint），配合 SMT 求解器（Z3、STP、Boolector）求解可达输入
- **关键挑战**：
  - **路径爆炸**：循环、递归、复杂分支导致路径指数增长 → 剪枝、状态合并、启发式搜索策略
  - **环境建模**：系统调用、库函数、并发、硬件交互的符号化建模难度大
  - **约束求解性能**：复杂非线性算术、位向量、数组理论的求解开销
- **主流工具/框架**：
  - **KLEE**（LLVM bitcode、C 程序）
  - **angr**（二进制、VEX IR、支持多架构、CTF 逆向常用）
  - **Manticore**（以太坊智能合约、二进制）
  - **S2E**（全系统符号执行、QEMU 集成）
  - **Triton**（动态符号执行/DSE、Pin/动态插桩）
- **应用场景**：漏洞自动挖掘、PoC 自动生成、CTF 逆向辅助、协议逆向、补丁分析

---

## 最危险漏洞 Top 25 更新（时隔 8 年）

> **来源**：BleepingComputer - [Top 25 Most Dangerous Vulnerabilities Refreshed After 8 Years](https://www.bleepingcomputer.com/news/security/top-25-most-dangerous-vulnerabilities-refreshed-after-8-years/)

MITRE 与 CWE 社区联合发布 **2019 CWE Top 25 Most Dangerous Software Weaknesses**，取代 2011 版本。排名基于 NVD 数据（CVE 数量、CVSS 严重度、攻击频次）加权计算。

**前十名**：

| 排名 | CWE ID | 弱点名称 | 典型后果 |
|------|--------|----------|----------|
| 1 | CWE-119 | 缓冲区错误操作 | RCE、DoS、信息泄露 |
| 2 | CWE-79 | 跨站脚本 (XSS) | 会话劫持、凭证窃取、恶意代码执行 |
| 3 | CWE-20 | 输入验证不当 | 绕过防护、注入攻击、逻辑漏洞 |
| 4 | CWE-125 | 越界读取 | 信息泄露、ASLR 绕过、DoS |
| 5 | CWE-89 | SQL 注入 | 数据窃取/篡改/删除、RCE |
| 6 | CWE-416 | Use After Free | RCE、沙箱逃逸、权限提升 |
| 7 | CWE-22 | 路径遍历 | 任意文件读写、RCE |
| 8 | CWE-352 | 跨站请求伪造 (CSRF) | 未授权操作执行 |
| 9 | CWE-78 | OS 命令注入 | RCE、完全控制服务器 |
| 10 | CWE-787 | 越界写入 | RCE、内存破坏、DoS |

> **趋势**：内存安全类（CWE-119/125/416/787）占据半壁江山，Web 注入类（XSS/SQLi/命令注入）依然高居榜单，路径遍历（CWE-22）排名上升。

---

## CVE-2019-19268：rConfig 3.9.2 本地提权漏洞

> **来源**：
> - [rConfig v3.9.2 Authenticated and Unauthenticated RCE (CVE-2019-16663 / CVE-2019-16662)](https://shells.systems/rconfig-v3-9-2-authenticated-and-unauthenticated-rce-cve-2019-16663-and-cve-2019-16662/)
> - [GitHub: TheCyberGeek/CVE-2019-19268](https://github.com/TheCyberGeek/CVE-2019-19268)

**影响版本**：rConfig ≤ 3.9.2  
**漏洞类型**：本地权限提升  
**CVSS**：7.8 (High)

### 漏洞原理

rConfig 是网络设备配置管理平台（PHP + MySQL）。CVE-2019-19268 存在于 `lib/ajaxHandlers/ajaxArchiveFiles.php` 中的 `exec()` 调用：

```php
// 简化代码片段
$file = $_POST['file'];  // 用户可控，未过滤
exec("tar -czf $file.tar.gz $file");  // 直接拼接命令
```

攻击者可通过 `file` 参数注入任意命令（如 `; id; #`），以 Web 服务器用户（通常为 `www-data`/`apache`）权限执行代码。

### 利用条件

- **认证绕过**：配合 CVE-2019-16662（未授权文件上传）或 CVE-2019-16663（SQL 注入获取管理员凭证），可实现**未授权 RCE 链**
- **本地提权**：若 Web 用户拥有 `sudo` 权限配置不当（如 `NOPASSWD: /bin/tar`），可进一步提升至 root

### 修复建议

- 升级至 rConfig 3.9.3 及以上版本
- 禁用 `exec()`/`shell_exec()` 等危险函数，改用 `proc_open()` + 参数数组
- 最小化 Web 服务器用户权限，审计 `sudoers` 配置

---

## RDP 反向路径遍历到 RCE (PoC)

> **来源**：GitHub - [0xedh/mstsc-path-traversal](https://github.com/0xedh/mstsc-path-traversal)

### 技术背景

Windows 远程桌面客户端 (`mstsc.exe`) 在连接 RDP 服务器时，支持**驱动器重定向**功能：客户端可将本地驱动器映射到远程会话中（显示为 `\\tsclient\C` 等）。服务端可读写客户端共享目录。

### 漏洞原理：反向路径遍历

1. **恶意 RDP 服务器** 接受客户端连接
2. 服务端枚举客户端重定向驱动器（`\\tsclient\C`）
3. 服务端构造恶意路径：`\\tsclient\C\..\..\..\Windows\System32\calc.exe`（或写入 Startup 文件夹、计划任务等）
4. 利用路径规范化缺陷，突破共享目录边界，**在客户端文件系统任意读写**

### 从文件写入到 RCE

- **写入启动项**：`\\tsclient\C\Users\<user>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\malicious.bat`
- **写入计划任务**：通过 `schtasks` 或 COM 接口创建任务
- **劫持 DLL 搜索顺序**：在应用程序目录植入恶意 DLL
- **修改注册表 Run Key**：需结合其他原语实现写入

### 影响范围

- Windows 7 / 8.1 / 10（默认开启驱动器重定向）
- 所有使用 `mstsc.exe`、`Remote Desktop` UWP 应用、第三方 RDP 客户端（FreeRDP、rdesktop 等可能受影响）

### 缓解措施

- **客户端**：组策略禁用驱动器重定向（`计算机配置 > 管理模板 > Windows 组件 > 远程桌面服务 > 远程桌面会话主机 > 设备和资源重定向 > 不允许驱动器重定向`）
- **网络层**：限制 RDP 仅连接受信任服务器，启用 NLA（网络级身份验证）
- **补丁**：微软于 2020-03-10 发布 CVE-2020-0768 修复相关路径规范化问题

> **关联技术**：RDP 协议安全长期是攻防焦点，BlueKeep (CVE-2019-0708) 为服务端预认证 RCE，本漏洞则为**客户端受害**视角，扩大了威胁模型。

---

## 关联页面

- [[0th3rs-security-team-wechat-archive-201911-202204]] - 0th3rs 安全团队微信归档索引，含 AWD 实战战报
- [[daily-security-digest-20191129]] - 翌日安全看点（Facebook XSS、Frida 绕过 SSL Pinning、小米浏览器 RCE 等）
- [[daily-security-digest-20191202]] - 后续安全看点（Frida Fuzzing、CPU 漏洞、D3CTF Writeup 等）

---

## 时间线摘要

| 时间 | 事件 |
|------|------|
| 2019-11-28 | 本期每日安全看点发布 |
| 2019-11 | 启明星辰杯 AWD+CTF 大赛，0th3rs 战队包揽前五名 |
| 2019-11 | 微软发布 Visual Studio Online（云端 VS Code） |
| 2019-11 | MITRE 发布 2019 CWE Top 25（时隔 8 年更新） |
| 2019 | rConfig 3.9.2 多个漏洞披露（CVE-2019-16662/16663/19268） |
| 2020-03-10 | 微软修复 RDP 客户端路径遍历 (CVE-2020-0768) |

## 来源

- [0th3rs安全团队-201911-202204_125](../sources/0th3rs安全团队-201911-202204_125.md)
