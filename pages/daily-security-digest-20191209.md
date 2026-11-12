---
title: 每日安全看点 2019-12-09
description: 2019年12月9日每日安全看点汇总，涵盖Linux逆向调试反调试、漏洞利用代码编写指南、Firefox漏洞利用链、Chrome DevTools调试与CSP防护、YARA规则自动生成、RIPS
  Java审计日历、开放重定向Payload列表及人脸识别隐私议题
category: ai-security
tags:
- 每日安全看点
- 2019年12月
- Linux逆向
- 反调试
- 漏洞利用
- Firefox
- CVE-2019-11708
- CVE-2019-9810
- Chrome DevTools
- CSP
- YARA
- Java代码审计
- 开放重定向
- 人脸识别隐私
date: 2019-12-09
updated: '2026-11-13'
---

## 概述

本期每日安全看点汇总了 2019 年 12 月 9 日的 8 篇技术资讯，涉及逆向工程、漏洞利用开发、浏览器安全、恶意代码特征提取、代码审计方法论、Web 攻击面梳理以及 AI 隐私伦理等多个维度。内容既包含硬核底层技术（如 Linux 反调试、Firefox 64 位完整利用链），也覆盖工程化工具与方法论（YARA 自动生成、RIPS 审计日历、重定向 Payload 列表），并延伸至人脸识别滥用的社会议题，适合安全研究员、红队人员及隐私合规从业者阅读。

## 详细目录

### Linux 逆向：调试与反调试技术
- **来源**：阿里云先知社区
- **链接**：https://xz.aliyun.com/t/6882
- **要点**：
  - 系统梳理 Linux 下常见调试手段（`ptrace`、硬件断点、GDB 脚本、LD_PRELOAD 注入等）
  - 归纳反调试检测技术：`ptrace` 状态检测、时间差检测、校验 `/proc/self/status`、`TracerPid`、信号处理器完整性校验、硬件断点寄存器（DR0-DR7）检测
  - 提供对抗思路：多进程互相 `ptrace`、信号重发、时间窗口随机化、动态加密关键代码段
- **关联阅读**：[[daily-security-digest-20191210]] 中的“Linux 逆向 Hook 与注入”、[[daily-security-digest-20191226]] 中的“FLIRT 符号恢复与 Binary Ninja 去混淆”

### 漏洞验证与利用代码编写指南
- **来源**：阿里云先知社区
- **链接**：https://xz.aliyun.com/t/6880
- **要点**：
  - 规范 PoC/EXP 编写流程：环境复现 → 根因定位 → 稳定性评估 → 利用链构造 → 后处理清理
  - 强调跨版本兼容性测试、ASLR/DEP/CFG 等缓解措施下的绕过策略记录
  - 推荐采用结构化输出（JSON/Protobuf）便于自动化平台集成
- **实践价值**：可作为红队武器库建设、漏洞赏金报告撰写的参考范式

### Firefox 64 位漏洞完整利用链（CVE-2019-11708 & CVE-2019-9810）
- **来源**：GitHub - 0vercl0k
- **链接**：https://github.com/0vercl0k/CVE-2019-11708
- **技术细节**：
  - **CVE-2019-11708**：IonMonkey JIT 编译器类型推断混淆导致的类型混淆，可实现任意读写原语
  - **CVE-2019-9810**：`Array.prototype.pop` 在稀疏数组处理时的整数溢出，配合堆喷射实现 RCE
  - 利用链完整覆盖：信息泄露 → 堆布局控制 → WASM RWX 页面劫持 → Shellcode 执行
  - 针对 64 位 Windows 10（Firefox 65.0/66.0）验证通过
- **参考价值**：现代浏览器 JIT 漏洞利用的标杆案例，适合结合 [[daily-security-digest-20191212]] “浏览器安全资料” 与 [[daily-security-digest-20191218]] “Chrome UAF 沙箱逃逸” 対照学习

### Chrome DevTools 调试 JavaScript 与 CSP 防护劫持分析
- **来源**：微信公众号
- **链接**：https://mp.weixin.qq.com/s/cQkCLr9XuADdnbX8Eog4wg
- **场景**：简书页面被注入恶意脚本，导致跳转劫持
- **调试技巧**：
  - 使用 **Sources 面板** 设置 XHR/DOM 断点定位注入入口
  - **Network 面板** 过滤 `script` 资源，对比 `Content-Security-Policy` 响应头与实际加载脚本的哈希/Nonce
  - **Console** 结合 `document.currentScript` 追踪动态创建的 `<script>` 标签
- **CSP 防护建议**：
  - 启用 `script-src 'nonce-{random}' 'strict-dynamic'` 并配合 `trusted-types` 指令
  - 部署 `Report-Only` 模式收集违规报告，再逐步收紧策略
- **延伸阅读**：[[daily-security-digest-20191212]] “浏览器安全资料”、[[daily-security-digest-20200120]] “浏览器利用资料库”

### YARA-Signator：基于代码特征自动生成 YARA 规则
- **来源**：Botconf 2019 Slides
- **链接**：https://pnx.tf/slides/2019-12-06-Botconf-YaraSignator.pdf
- **核心思路**：
  - 输入：恶意样本二进制/汇编片段
  - 特征提取：控制流图（CFG）子图同构匹配、常量/字符串/导入表稀有度打分
  - 规则合成：自动生成 `condition` 逻辑，平衡误报率与覆盖率
  - 输出：可直接部署的 `.yar` 规则集
- **应用场景**：大规模恶意家族聚类、APT 样本归属、威胁狩猎规则库自动化维护

### RIPS Java 代码审计日历 2019
- **来源**：RIPS Technologies
- **链接**：https://www.ripstech.com/java-security-calendar-2019/
- **内容形式**：Advent Calendar 模式，每天发布一个真实 Java 漏洞案例（共 24 个）
- **覆盖漏洞类型**：
  - 反序列化链（Commons Collections、Jackson、Spring）
  - 表达式注入（SpEL、OGNL、MVEL）
  - XXE、SSRF、JNDI 注入、模板引擎 SSTI
  - 业务逻辑越权、加密误用、随机数可预测
- **学习建议**：配合 [[java-deserialization-fundamentals]]、[[spring-boot-actuator配置不当rce利用]]、[[spring-boot-devtools-deserialization-rce]]、[[spring-boot-spel表达式注入]] 等页面构建 Java 安全知识图谱

### 开放重定向 Payload 列表
- **来源**：KitPloit
- **链接**：https://www.kitploit.com/2019/12/open-redirect-payload-list.html
- **分类收录**：
  - 基础绕过：`//evil.com`、`/\evil.com`、`///evil.com`
  - 编码变体：URL 编码、双重编码、Unicode 归一化绕过
  - 协议滥用：`javascript:alert(1)`、`data:text/html,<script>...`
  - 特殊字符：`@`、换行符、`\t`、`\r`、空字节
  - 云厂商特定：AWS、GCP、Azure 元数据服务跳转
- **用途**：SSRF 链条构造、OAuth 重定向劫持、钓鱼页面可信度提升

### 谁“偷了”我们的脸 —— 人脸识别隐私与滥用调查
- **来源**：微信公众号
- **链接**：https://mp.weixin.qq.com/s/JcdWDvaYoeeY8eYPPOTYoQ
- **核心议题**：
  - 商业摄像头、门禁、支付、APP 登录等场景大规模采集人脸生物特征
  - 数据存储合规性缺失：明文传输、未加密落盘、第三方 SDK 隐性共享
  - 黑产链条：人脸数据包交易、实时人脸替换（DeepFake）攻破活体检测、刷脸支付欺诈
  - 法律监管：《网络安全法》《个人信息安全规范》对生物识别信息的特殊保护要求
- **防御建议**：
  - 最小化采集、本地化处理、联邦学习避免原始数据出域
  - 多因子认证降低单一人脸认证风险
  - 定期开展隐私影响评估（PIA）与渗透测试

## 交叉引用导航

| 日期 | 页面 | 核心看点 |
|------|------|----------|
| 2019-12-10 | [[daily-security-digest-20191210]] | H1ve 攻防平台、Linux Hook/注入、360 杀软绕过、Nexus CVE-2019-15588、Java Web 知识库 |
| 2019-12-11 | [[daily-security-digest-20191211]] | DroneSploit、2019 网络攻击回顾、Google Play 恶意应用、PHP sprintf 漏洞、iOS 内核漏洞 |
| 2019-12-12 | [[daily-security-digest-20191212]] | Apple AirDos、深度学习恶意软件分类、浏览器安全、威胁情报私有化、Outlook 漏洞、JQ 命令注入 |
| 2019-12-16 | [[daily-security-digest-20191216]] | 内网渗透、WinRAR 逆向、Docker 容器安全、RealWorldCTF Safari 漏洞、CDPSvc 提权、C2 框架 |
| 2019-12-18 | [[daily-security-digest-20191218]] | TP-Link 漏洞、比特币隐藏 C2、Cobalt Strike 免杀、SysWhispers、Chrome UAF 沙箱逃逸 |
| 2019-12-19 | [[daily-security-digest-20191219]] | 区块链智能合约逆向、儿童 GPS 手表隐私、DLL 镂空、网站镜像复制 |
| 2019-12-20 | [[daily-security-digest-20191220]] | APT-C-08 蔓灵花、zzzphp SQL 注入、逆向资源库、Facebook 手机号泄露 |

## 标签索引

`#Linux逆向` `#反调试` `#漏洞利用开发` `#Firefox` `#CVE-2019-11708` `#CVE-2019-9810` `#ChromeDevTools` `#CSP` `#YARA` `#恶意代码特征提取` `#Java代码审计` `#RIPS` `#开放重定向` `#SSRF` `#人脸识别隐私` `#生物特征保护` `#DeepFake` `#合规`

---

> 本页面由每日安全看点 2019-12-09 原始归档整理生成，旨在构建可检索、可关联的安全知识库。如需引用原文，请访问文中提供的原始链接。

## 来源

- [0th3rs安全团队-201911-202204_117](../sources/0th3rs安全团队-201911-202204_117.md)
