---
title: 每日安全看点 2020-03-17
description: 汇总 2020 年 3 月 17 日每日安全看点，涵盖 IE ChakraCore CVE-2020-0768 漏洞分析、苹果设备剪贴板隐私泄漏、VSCode
  任意代码执行隐患
category: ai-security
tags:
- 每日安全看点
- CVE-2020-0768
- ChakraCore
- IE漏洞
- 苹果隐私
- 剪贴板泄漏
- VSCode
- 任意代码执行
- 2020年3月
date: 2020-03-17
updated: '2026-11-12'
---

## 概述

本期每日安全看点汇总了 2020 年 3 月 17 日的三项重要安全动态：IE ChakraCore 引擎漏洞（CVE-2020-0768）深度分析、苹果设备剪贴板隐私泄漏隐患披露、以及 VSCode 编辑器存在的任意代码执行安全隐患。

---

## IE ChakraCore 引擎漏洞（CVE-2020-0768）分析

### 漏洞基本信息

- **CVE 编号**：CVE-2020-0768
- **影响组件**：IE ChakraCore JavaScript 引擎
- **漏洞类型**：内存破坏 / 远程代码执行
- **公开分析**：[Seebug Paper 1146](https://paper.seebug.org/1146/)

### 技术细节

该漏洞存在于 ChakraCore 引擎处理 JavaScript 对象的方式中，攻击者可通过精心构造的网页触发内存破坏，进而在目标系统上以当前用户权限执行任意代码。漏洞根因涉及 JIT 编译优化过程中的类型推断逻辑缺陷，导致类型混淆进而实现越界读写。

### 影响范围

- Internet Explorer 9/10/11
- 基于 ChakraCore 的应用程序
- Windows 7/8.1/10 及对应 Server 版本

### 缓解建议

1. 及时安装微软发布的安全补丁（2020 年 3 月补丁周二已修复）
2. 启用增强保护模式（EPM）
3. 考虑迁移至 Microsoft Edge (Chromium) 等现代浏览器

---

## 苹果设备剪贴板隐私泄漏隐患

### 问题描述

iOS 与 iPadOS 系统中，任意应用在后台运行时均可无提示读取系统通用剪贴板内容。当用户在 Mac 复制敏感信息（密码、证件号、加密货币地址等）后，通过通用剪贴板同步至 iPhone/iPad，任意前台应用均可静默获取。

### 技术原理

- 苹果生态引入 **Universal Clipboard**（通用剪贴板）实现跨设备复制粘贴
- 系统未对剪贴板读取权限进行细粒度控制，且无用户感知提示
- 后台应用通过 `UIPasteboard.general.string` 等 API 即可访问

### 影响场景

| 场景 | 风险等级 | 说明 |
|------|----------|------|
| 密码管理器自动填充后复制 | 高 | 明文密码可能被恶意 App 窃取 |
| 加密货币钱包地址复制 | 高 | 攻击者可替换剪贴板地址实现劫持 |
| 身份证/银行卡号复制 | 中 | 个人敏感信息泄露 |
| 普通文本复制 | 低 | 隐私信息被采集分析 |

### 临时缓解方案

1. 复制敏感信息后立即复制一段无关文本覆盖剪贴板
2. 关闭“通用剪贴板”功能：`设置` → `通用` → `AirPlay 与隔空投送` → 关闭 `隔空投送`
3. 使用支持“自动清空剪贴板”功能的密码管理器（如 1Password、Bitwarden）

### 厂商响应

苹果在后续 iOS 14 中引入了 **剪贴板访问提示横幅**，并在 iOS 16 进一步提供了剪贴板权限管理开关，从根本上缓解了该隐患。

---

## VSCode 任意代码执行隐患

### 漏洞概况

- **发现机构**：Doyensec
- **披露时间**：2020-03-16
- **详细分析**：[VSCode Code Execution](https://blog.doyensec.com/2020/03/16/vscode_codeexec.html)
- **影响版本**：修复前的 VSCode 所有版本

### 攻击向量

VSCode 的 **工作区信任机制** 与 **任务系统** 存在设计缺陷，攻击者可通过以下路径实现代码执行：

1. **恶意工作区文件** (`*.code-workspace`)：包含预定义的 `tasks.json`、`launch.json`、`settings.json`
2. **任务自动运行**：`"runOptions": {"runOn": "folderOpen"}` 导致打开文件夹即触发任务
3. **扩展安装执行**：恶意扩展在激活时执行任意命令

### 利用链示例

```json
// 恶意 .code-workspace 文件片段
{
  "folders": [{ "path": "." }],
  "settings": {
    "task.allowAutomaticTasks": true
  },
  "tasks": {
    "version": "2.0.0",
    "tasks": [
      {
        "label": "malicious",
        "type": "shell",
        "command": "calc.exe",  // 任意命令
        "runOptions": { "runOn": "folderOpen" },
        "problemMatcher": []
      }
    ]
  }
}
```

### 核心问题

| 问题 | 说明 |
|------|------|
| 任务自动执行默认开启 | `task.allowAutomaticTasks` 默认为 `true` |
| 缺乏工作区签名验证 | 无机制验证工作区文件来源可信性 |
| 扩展权限过大 | 扩展激活即拥有完整 Node.js 运行时权限 |

### 修复时间线

1. **2020-03** Doyensec 负责任披露
2. **2020-04** VSCode 1.44 版本引入 **工作区信任** 机制
3. **后续版本** 持续强化：任务执行确认提示、扩展权限隔离、不可信工作区限制模式

### 防护建议

1. **升级 VSCode** 至 1.44 或更高版本
2. **启用工作区信任**：`Security.workspace.trust.enabled: true`
3. **谨慎打开陌生工作区**：首次打开时选择“不信任”，以只读模式浏览
4. **审查 tasks.json/launch.json**：团队共享配置需代码审查
5. **限制扩展安装来源**：优先使用官方市场验证扩展

---

## 关联阅读

- [[daily-security-digest-20200318]] — 次日安全看点，涵盖 Win10 Exp 合集、ATT&CK 欺骗防御、fastjson/Shiro/Weblogic 反序列化漏洞复现等
- [[cve-digest-20210402]] — 2021 年 4 月 CVE 聚合，包含 VSCode 扩展相关漏洞
- [[cve-digest-20210426]] — 2021 年 4 月 CVE 聚合，包含 VS Code 相关 RCE/CSRF/XSS 漏洞
- [[spring-boot-devtools-deserialization-rce]] — Spring Boot DevTools 反序列化 RCE，涉及开发工具链安全
- [[wechat-pc-v8-rce-0day-analysis]] — 微信 PC 版 V8 引擎 RCE 0day 分析，同属客户端引擎漏洞范畴

---

## 时间线摘要

| 时间 | 事件 |
|------|------|
| 2020-03-17 | 每日安全看点发布，覆盖上述三项安全动态 |
| 2020-03 (补丁周二) | 微软发布 CVE-2020-0768 官方修复补丁 |
| 2020-03-16 | Doyensec 披露 VSCode 任意代码执行隐患 |
| 2020-06 (iOS 14) | 苹果引入剪贴板访问提示横幅 |
| 2020-04 | VSCode 1.44 引入工作区信任机制修复任务自动执行问题 |

---

## 标签索引

`#每日安全看点` `#CVE-2020-0768` `#ChakraCore` `#IE漏洞` `#苹果隐私` `#剪贴板泄漏` `#VSCode` `#任意代码执行` `#2020年3月` `#工作区信任` `#Universal Clipboard`

## 来源

- [0th3rs安全团队-201911-202204_063](../sources/0th3rs安全团队-201911-202204_063.md)
