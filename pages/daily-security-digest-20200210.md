---
title: 每日安全看点 2020-02-10
description: 汇总 2020 年 2 月 10 日每日安全看点，涵盖 ATT&CK 渗透手册、智能合约审计系列、游戏漏洞挖掘、ysoserial C3P0
  利用链、.NET C2 框架、机器学习代码相似性分析、x86 指令混淆技术，以及疫情背景下的远程办公/教育安全专题实战建议。
category: ai-security
tags:
- 每日安全看点
- ATT&CK
- 渗透测试
- 智能合约审计
- 游戏安全
- Java反序列化
- ysoserial
- C3P0
- C2框架
- Covenant
- 机器学习
- 代码相似性
- 逆向工程
- x86混淆
- 远程办公安全
- 疫情网络安全
- 网络钓鱼
- DDoS攻击
- XRed病毒
- 2020年2月
date: 2020-02-10
updated: '2026-11-12'
---

## 概述

本期每日安全看点收录了 7 个技术方向的优质资源：基于 ATT&CK 知识体系的 400 页渗透测试手册、三篇智能合约审计系列文章、两篇游戏漏洞挖掘实战分享、ysoserial C3P0 利用链深度分析、.NET 跨平台 C2 框架 Covenant、机器学习在代码相似性分析中的应用综述，以及 x86 指令混淆中的函数分析与代码块粉碎技术。

**补充专题**：针对 2020 年 2 月疫情爆发初期大规模远程办公/教育场景，新增远程办公安全事件复盘与八条实战防护建议，详见 [[remote-work-security-covid19-20200210]] 专题页面。

---

## ATT&CK 渗透测试手册

> **资源链接**：[ATTCK-PenTester-Book：根据 ATT&CK 知识体系编制的长达 400 页的渗透手册](https://www.freebuf.com/articles/system/226119.html)

该手册依据 MITRE ATT&CK 矩阵系统梳理渗透测试全流程，覆盖初始访问、执行、持久化、权限提升、防御规避、凭证获取、发现、横向移动、收集、命令与控制、渗出、影响等 12 个战术阶段，每个技术附带实操命令、检测建议与缓解措施，适合红队人员按图索骥开展实战演练。

---

## 智能合约审计系列

> **资源链接**：
> - [智能合约审计系列（一）](https://xz.aliyun.com/t/4145)
> - [智能合约审计系列（二）](https://xz.aliyun.com/t/4416)
> - [智能合约审计系列（三）](https://xz.aliyun.com/t/7152)

系列文章从 Solidity 语言特性、常见漏洞模式（重入、整数溢出、访问控制缺陷、tx.origin 认证绕过、随机数可预测、时间戳依赖、短地址攻击等）入手，结合真实案例（DAO、Parity 等）演示静态分析工具（Slither、Mythril、Oyente、Securify）与人工审计相结合的完整方法论。

---

## 游戏漏洞挖掘实战

> **资源链接**：
> - [挖游戏漏洞的文章（一）](https://mp.weixin.qq.com/s/6QYQ4z4T6SI8N88kf-DYwA)
> - [挖游戏漏洞的文章（二）](https://mp.weixin.qq.com/s/CvzfpfS1Bg6DLY1k1_uNsA)

两篇文章分别从客户端协议逆向、内存篡改、逻辑漏洞（刷金币、刷道具、越权操作）、Unity/Unreal 引擎特定攻击面、反作弊绕过（Hook 检测、内存扫描对抗、驱动级保护分析）等角度，分享实战挖掘思路与工具链（Cheat Engine、IDA Pro、Frida、x64dbg、Process Hacker）。

---

## ysoserial C3P0 利用链分析

> **资源链接**：[ysoserial 的 C3P0 利用链分析](https://mp.weixin.qq.com/s/T3MCFpv7z4Li6UReCPBTFw)

文章深度剖析 ysoserial 中 `CommonsBeanutils1`、`CommonsCollections*` 之外的 **C3P0** 利用链（`PoolBackedDataSourceBase` → `Referenceable` → `JNDI` → `RCE`），梳理 `javax.naming.Reference` 与 `javax.sql.DataSource` 接口交互细节，说明为何高版本 JDK（`com.sun.jndi.ldap.object.trustURLCodebase=false`）下仍可通过 `classFactory`/`classFactoryLocation` 绕过限制。相关基础机制可参考 [[java-deserialization-fundamentals]]、[[spring-boot-devtools-deserialization-rce]]、[[h2-console-jndi注入rce利用]]。

---

## .NET 跨平台 C2 框架：Covenant

> **资源链接**：[Covenant - GitHub](https://github.com/cobbr/Covenant)

Covenant 是基于 .NET Core 开发的协作型 C2 框架，支持 Windows/Linux/macOS 跨平台运行，具备以下特性：
- **多监听器**：HTTP/HTTPS、DNS、SMB、WebSocket 等多种通信通道
- **任务并发**：异步任务队列，支持长时间后台作业
- **插件化 Grunt**：通过 `Yara`、`SharpSploit`、`Seatbelt`、`Rubeus` 等内置/外部程序集动态扩展功能
- **协作界面**：基于 ASP.NET Core + Vue 的 Web 管理端，支持多操作员实时协作、会话记录回放
- **配置文件驱动**：`Covenant.yaml` 统一定义监听器、Grunt 模板、用户权限、数据库连接等

适合红队在域环境中进行隐蔽持久化与横向移动演练。

---

## 机器学习在代码相似性分析中的应用

> **资源链接**：[【程序分析】机器学习在代码相似性分析中的应用](https://mp.weixin.qq.com/s/QGhA2LanCq5KSUYT5uBf9A)

文章综述了基于 **AST/CPG/PDG** 图结构嵌入（Graph Neural Network、code2vec、code2seq）、**Token 序列建模**（Transformer、BERT、RoBERTa）、**语义特征工程**（API 调用序列、控制流/数据流切片）的主流方案，对比了 **BCB（Big Clone Bench）**、**POJ-104**、**Google Code Jam** 等基准数据集上的检测效果（Precision/Recall/F1），并指出跨语言、跨编译优化等级、混淆代码下的泛化难点。

---

## x86 指令混淆：函数分析与代码块粉碎

> **资源链接**：[【逆向】x86 指令混淆之函数分析和代码块粉碎](https://mp.weixin.qq.com/s/zFkv6WPCzJtuCN_QNaJJEw)

文章从编译器视角拆解两类主动混淆技术：
1. **函数分析混淆**：通过 **控制流扁平化**、**不透明谓词**、**虚假控制流**、**函数内联/外联**、**栈帧伪装** 破坏 IDA/Ghidra 的函数识别与边界划分。
2. **代码块粉碎**：将基本块拆分为微指令序列，配合 **指令替换**、**寄存器重分配**、**跳转指令加密**、**自修改代码** 使静态反汇编器无法还原原始 CFG。

文中给出基于 **Capstone/Keystone/Unicorn** 的原型实现思路，并讨论动态执行追踪（Intel PT、DynamoRIO、Frida Stalker）对抗混淆的可行性。

---

## 远程办公/教育安全专题（疫情背景实战建议）

> **专题页面**：[[remote-work-security-covid19-20200210]]

2020 年 2 月 10 日正值新冠疫情爆发初期，全国大规模启动远程办公与在线教育。当日观测到三类典型安全事件：

| 事件类型 | 典型案例 | 攻击向量 |
|---------|---------|---------|
| **恶意软件攻击** | 某企业远程办公环境遭遇 **XRed 病毒** 入侵 | 利用弱口令/未授权访问的远程桌面、VPN 凭证撞库 |
| **网络钓鱼** | 以“新型冠状病毒防疫通知”、“健康打卡”、“口罩采购”为诱饵的钓鱼邮件/微信消息 | 社会工程学、恶意附件、钓鱼链接窃取凭证 |
| **DDoS 攻击** | 某远程教育直播平台遭受大流量 DDoS 攻击导致服务中断 | 反射放大攻击、应用层 CC 攻击 |

### 八条面向企业与个人的远程办公安全最佳实践

1. **提高安全意识**：不点击不明链接/邮件，警惕以“疫情防控”、“健康打卡”为诱饵的钓鱼攻击。
2. **官方渠道获取工具**：远程控制、视频会议、VPN 客户端等仅从官网下载，防止供应链投毒（重打包木马）。
3. **强化远程访问凭证**：开放远程端口前严格核查，启用 MFA，设置高强度密码，定期轮换。
4. **文件加密共享**：敏感文件通过压缩加密（AES-256）传输，避免明文在公共网盘/IM 中流转。
5. **最小权限原则**：收敛文件共享、远程桌面、数据库等服务的暴露面，禁用默认共享，配置 ACL 访问控制。
6. **疫情主题威胁专项防护**：
   - 涉疫邮件附件（.exe、.zip、.scr 等）禁止直接打开，先沙箱/杀毒引擎检测；
   - 仅信任权威媒体（央视、卫健委官网、主流门户）发布的疫情资料，不转发未经核实链接。
7. **禁用 Office 宏**：除非文档来源可信且经过数字签名验证，否则禁用宏执行。
8. **基线加固**：终端部署最新版杀毒/EDR，及时安装系统补丁（重点关注 RDP、SMB、VPN 组件漏洞），开启防火墙出站管控。

### 关联技术资源

- [[remote-work-security-covid19-20200210]] — 完整专题页面，含事件详情、防护清单、参考链接
- [[daily-security-digest-20200214]] — 后续看点涵盖工信部涉疫情网络安全风险提示、分布式暴力破解工具 Kraken
- [[daily-security-digest-20200217]] — 涵盖新冠病毒主题钓鱼攻击分析、云环境 SSRF 检测防御（以 AWS 为例）
- [[daily-security-digest-20200224]] — 涵盖手机定位追踪冠状病毒患者轨迹隐私安全讨论

---

## 关联页面

- [[daily-security-digest-20200211]] — 翌日安全看点，延续关注 JavaScript 原型链污染、RSA 2020 创新沙盒、AWS Lambda Serverless 安全等内容
- [[daily-security-digest-20200212]] — 涵盖机器学习对抗样本、Darkhotel APT 双 0day、Windows Defender 驱动分析、Chrome 漏洞分析等
- [[java-deserialization-fundamentals]] — Java 序列化/反序列化核心机制，为理解 ysoserial 利用链提供基础
- [[spring-boot-devtools-deserialization-rce]] — Spring Boot DevTools 弱默认密钥导致的反序列化 RCE 利用链
- [[h2-console-jndi注入rce利用]] — H2 Database 控制台 JNDI 注入 RCE 实战攻击链
- [[cve-digest-20200426]] — 2020 年 4 月 CVE 漏洞聚合，含 Windows 内核提权、Chrome V8 堆溢出等
- [[remote-work-security-covid19-20200210]] — 疫情背景下远程办公/教育安全专题，含八条实战防护建议与事件复盘

---

## 小结

本期看点覆盖 **红队实战手册**、**区块链审计**、**客户端游戏安全**、**Java 反序列化高阶利用链**、**跨平台 C2 基础设施**、**AI 辅助程序分析**、**二进制混淆对抗** 七大技术领域，并针对疫情特殊背景新增 **远程办公/教育安全专题**。整体体现了 2020 年初安全研究从单一漏洞利用向 **体系化、自动化、智能化** 演进，同时快速响应重大社会事件衍生的网络安全挑战的趋势。

## 来源

- [0th3rs安全团队-201911-202204_085](../sources/0th3rs安全团队-201911-202204_085.md)
- [0th3rs安全团队-201911-202204_086](../sources/0th3rs安全团队-201911-202204_086.md)
