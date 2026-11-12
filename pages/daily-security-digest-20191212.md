---
title: 每日安全看点 2019-12-12
description: 汇总 2019 年 12 月 12 日每日安全看点，涵盖 Apple AirDos 漏洞修复、深度学习恶意软件分类论文、浏览器安全资料、威胁情报私有化生产、Microsoft
  Outlook for Android 漏洞、JQ 命令注入特性等安全资讯
category: ai-security
tags:
- 每日安全看点
- 2019年12月
- Apple
- AirDos
- 深度学习
- 恶意软件分类
- 浏览器安全
- 威胁情报
- Microsoft Outlook
- JQ
- 命令注入
date: 2019-12-12
updated: '2026-11-13'
---

## 每日安全看点【2019.12.12】

> 原文来源：[微信公众号文章](http://mp.weixin.qq.com/s?__biz=MzU5MjMzODY0NQ==&mid=2247483842&idx=1&sn=2e1d31b84a50d9ee55bbde52fa0a0554&chksm=fe200a78c957836eb322aa6ab23ef6c7f2e711da28d55d84c8158819d864458adb6d10248bc7&scene=126&sessionid=1681442955#rd)

---

### Apple 修复 AirDos 漏洞

Apple 于近日修复了一个名为 **AirDos** 的漏洞，该漏洞可导致附近的 iPhone、iPad 遭受远程拒绝服务攻击。

- **漏洞类型**：拒绝服务
- **影响设备**：iPhone、iPad 等 Apple 设备
- **攻击方式**：远程触发，无需用户交互
- **参考链接**：[Threatpost 报道](https://threatpost.com/airdos-bug-cripples-nearby-iphones/151030/)

---

### 论文翻译：深度学习方法对恶意软件系统调用序列进行分类

ArkTeam 发布了一篇论文翻译，探讨使用深度学习技术对恶意软件的系统调用序列进行分类，属于 **AI 安全** 与 **恶意软件分析** 交叉领域的研究成果。

- **核心技术**：深度学习、系统调用序列分析、恶意软件分类
- **应用场景**：恶意软件检测与分类自动化
- **参考链接**：[ArkTeam 论文翻译](http://www.arkteam.net/?p=4507)

> 该研究与当前 AI 安全领域的恶意流量检测、对抗样本生成等方向高度相关，可参考 [[daily-security-digest-20200212]] 中提到的机器学习对抗规则生成及 [[daily-security-digest-20200102]] 中的 KNN 算法检测恶意流量等内容。

---

### 浏览器安全资料汇总

GitHub 仓库 `ser4wang/BrowserSecurity` 收集整理了浏览器安全相关的技术资料、漏洞分析、利用技术等内容，适合浏览器安全研究人员参考。

- **仓库地址**：[github.com/ser4wang/BrowserSecurity](https://github.com/ser4wang/BrowserSecurity)
- **涵盖内容**：浏览器内核架构、V8/ChakraCore/JSC 引擎漏洞、沙箱逃逸、渲染进程利用等

> 关联早期每日看点中收录的浏览器安全专题：[[daily-security-digest-20200120]]（浏览器利用资料库、IE 0day CVE-2020-0674）、[[daily-security-digest-20200212]]（Chrome 运行原理与漏洞分析）、[[daily-security-digest-20200312]]（JSC/WebKit 架构资料整理）。

---

### 威胁情报的私有化生产和级联：威胁狩猎及情报共享

FreeBuf 文章探讨威胁情报的私有化生产流程、级联分发机制，以及威胁狩猎与情报共享的实践方法论。

- **核心议题**：威胁情报生产生命周期、私有化部署、情报级联共享、威胁狩猎实战
- **参考链接**：[FreeBuf 文章](https://www.freebuf.com/articles/es/222359.html)

> 该主题与 APT 攻击归因、威胁情报平台建设密切相关，可参考 [[apt-c-08-mobile-attack-analysis]] 中基于 360 威胁情报中心的归因分析，以及 [[daily-security-digest-20191223]] 涉及的 ATT&CK/APT 归因讨论、Google Project Zero 在野漏洞统计等内容。

---

### Microsoft Outlook for Android 安全漏洞

CNNVD 收录了 Microsoft Outlook for Android 存在的安全漏洞。

- **CNNVD 编号**：CNNVD-201912-319
- **影响产品**：Microsoft Outlook for Android
- **参考链接**：[CNNVD 漏洞详情](http://www.cnnvd.org.cn/web/xxk/ldxqById.tag?CNNVD=CNNVD-201912-319)

---

### JQ 命令注入特性

发现 `jq` 工具在处理特定输入时存在命令注入特性，可执行任意命令。

**PoC 示例：**
```bash
echo '{"1":"2"}' | jq .\[;whoami;\]
```

- **根因**：`jq` 对特定语法的解析处理不当，导致命令注入
- **影响版本**：需进一步验证具体版本范围
- **修复建议**：升级至最新版本，避免对不可信 JSON 数据直接管道处理

> 类似的命令注入问题常见于各类 CLI 工具，渗透测试中需注意工具链安全，参考 [[daily-security-digest-20191218]] 中的 Cobalt Strike 免杀、SysWhispers 系统调用绕过等工具链安全议题。

---

### 招聘：信息安全算法工程师（业务安全方向）

腾讯安全发布招聘信息，寻找信息安全算法工程师，侧重业务安全方向。

- **岗位方向**：业务安全、算法工程、风控模型
- **参考链接**：[招聘详情](https://mp.weixin.qq.com/s?__biz=MzI5ODE0ODA5MQ==&mid=2652279698&idx=1&sn=f0315d547ad43f32b090a4f5bc2414fa&scene=21#wechat_redirect)

---

## 关联页面

- [[daily-security-digest-20191216]] - 2019-12-16 每日安全看点
- [[daily-security-digest-20191217]] - 2019-12-17 每日安全看点
- [[daily-security-digest-20191218]] - 2019-12-18 每日安全看点
- [[daily-security-digest-20191219]] - 2019-12-19 每日安全看点
- [[daily-security-digest-20191220]] - 2019-12-20 每日安全看点
- [[apt-c-08-mobile-attack-analysis]] - APT-C-08 移动端攻击分析（威胁情报归因）
- [[daily-security-digest-20200102]] - 2020-01-02 每日安全看点（KNN 恶意流量检测）
- [[daily-security-digest-20200120]] - 2020-01-20 每日安全看点（浏览器安全资料库）
- [[daily-security-digest-20200212]] - 2020-02-12 每日安全看点（机器学习对抗、Chrome 漏洞分析）
- [[daily-security-digest-20200312]] - 2020-03-12 每日安全看点（JSC/WebKit 架构资料）

## 来源

- [0th3rs安全团队-201911-202204_114](../sources/0th3rs安全团队-201911-202204_114.md)
