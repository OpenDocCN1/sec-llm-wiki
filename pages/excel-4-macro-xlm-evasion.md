---
title: Excel 4.0 宏（XLM）技术原理、免杀投递实战与对抗检测机制分析
description: 系统梳理 Excel 4.0 宏（XLM）的历史渊源、宏工作表结构、Auto_Open 自动执行机制、宏隐藏与受信任记录绕过等核心技术，结合
  Office 2013/2016 实测环境复现免杀投递全流程，分析静态特征、动态行为及 AMSI/宏安全设置对抗检测的攻防要点。
category: program-analysis
tags:
- Excel 4.0 Macro
- XLM
- Macro Sheet
- Auto_Open
- Evasion
- Initial Access
- Office Security
- Red Teaming
- Trusted Records
- Macro Hiding
date: 2024-01-15
updated: '2026-11-15'
---
## 概述

Excel 4.0 宏（XLM，Excel Macro Language）是 Microsoft Excel 早期版本（Excel 4.0，1992 年发布）引入的宏语言，早于 VBA（Visual Basic for Applications）。尽管微软在后续版本中大力推广 VBA 并逐步隐藏 XLM 界面，但 **XLM 宏在所有受支持的 Office 版本中仍保留完整解析与执行能力**，成为红队初始访问、免杀投递的经典技术。

本页围绕 **宏工作表创建、Auto_Open 自启动、宏内容隐藏、受信任记录复用** 四大核心环节，结合实测环境（Windows 7 x64 + Office 2013/2016）复现完整攻击链，并延伸分析静态/动态检测对抗要点。

## 技术原理

### XLM 宏与宏工作表

- **宏工作表**：Excel 4.0 时代的宏存储载体，文件内部以 `xlSheet` 类型为 `xlExcel4MacroSheet`（值 3）的工作表存在。现代 Excel 仍可通过 **“插入” → “宏工作表”** 创建。
- **公式即代码**：XLM 以单元格公式形式编写，每个单元格可包含一条指令（如 `=EXEC("calc.exe")`），按行/列顺序或 `GOTO` 跳转执行。
- **核心函数集**：
  - `EXEC(program, args)` → 启动进程（对应 `WinExec`/`CreateProcess`）
  - `ALERT(message)` → 弹窗提示
  - `HALT()` → 停止宏执行
  - `GET.WORKSPACE(1)`、`GET.DOCUMENT(88)` 等环境探测函数常用于沙箱/虚拟机识别。

### Auto_Open 自动执行机制

- **命名单元格触发**：将任意单元格重命名为 `Auto_Open`（不区分大小写），该单元格所在行的公式在工作簿打开且宏启用时自动执行。
- **等效替代**：`Auto_Close`、`Auto_Activate`、`Auto_Deactivate` 等同名单元格对应不同事件。
- **无需 VBA 工程**：纯 XLM 宏不依赖 `VBAProject` 流，绕过基于 VBA 宏的静态特征提取（如 `oletools`、`pcodedmp` 只解析 VBA）。

### 宏隐藏与受信任记录

| 技术手段 | 原理 | 对抗效果 |
|----------|------|----------|
| **工作表隐藏** | 右键宏工作表标签 → “隐藏”，对应 `xlSheetVeryHidden`（`Visible = 2`） | 普通用户无法通过 UI 取消隐藏，需 VBA 或 `xlSheetVisible` 还原 |
| **受信任记录** | Office 在 `%APPDATA%\Microsoft\Excel\XLSTART` 或注册表 `HKEY_CURRENT_USER\Software\Microsoft\Office\<ver>\Excel\Security\Trusted Documents` 记录用户曾启用宏的文件路径/哈希 | 同名/同路径文件再次打开可 **静默启用宏**，无安全提示 |

> 参考：[More on Trust Records, Macros, and…](http://az4n6.blogspot.com/2016/02/more-on-trust-records-macros-and.html)

## 免杀投递实战复现

### 环境准备

| 组件 | 版本 | 说明 |
|------|------|------|
| 操作系统 | Windows 7 x64 | 实测环境，Win10/11 同理 |
| Office | Office 2013 / 2016 | 全版本受影响 |
| 工具 | Excel 原生界面 | 无需额外工具 |

### 步骤 1：创建宏工作表并编写 Payload

1. 新建 Excel 工作簿 → **“开发工具”** → **“插入”** → **“宏工作表”**（或 `Alt+F11` → `Insert` → `MS Excel 4.0 Macro Sheet`）。
2. 在 **A1** 单元格输入以下公式（每行回车确认）：

```excel
=EXEC("calc.exe")
=ALERT("Hello, World")
=HALT()
```

> `EXEC` 会调用 `kernel32!WinExec` 启动进程，`ALERT` 用于验证执行流，`HALT` 防止继续执行后续空单元格报错。

### 步骤 2：设置 Auto_Open 自启动

1. 选中 **A1** 单元格 → 公式栏左侧 **“名称框”** 输入 `Auto_Open` → 回车确认。
2. 此时该单元格成为工作簿打开时的自动入口点。

### 步骤 3：保存为启用宏格式

- **“另存为”** → 选择 **“Excel 启用宏的工作簿 (*.xlsm)”** 或 **“Excel 97-2003 工作簿 (*.xls)”**。
- `.xlsm` 采用 OOXML 结构，宏工作表存储在 `xl/macrosheets/sheetX.bin` 二进制流中；`.xls` 采用 BIFF8 复合文档格式。

### 步骤 4：隐藏宏工作表（规避人工排查）

- 右键宏工作表标签（默认 `Macro1`） → **“隐藏”**。
- 此时工作表 `Visible` 属性变为 `xlSheetVeryHidden`，普通用户在“取消隐藏”列表中不可见。

### 步骤 5：实测执行效果

| Office 版本 | 打开行为 | 结果 |
|-------------|----------|------|
| **Office 2016** | 弹出“安全警告：已禁用宏” → 点击 **“启用内容”** | 成功弹出计算器与 `Hello, World` 对话框 |
| **Office 2013** | 同上 | 同成功执行 |

> 若目标机器已存在同名受信任记录，第二次打开将 **直接静默执行**，无任何提示。

## 对抗检测机制分析

### 静态特征对抗

| 检测维度 | 传统 VBA 宏 | XLM 宏 | 对抗优势 |
|----------|-------------|--------|----------|
| **文件结构** | `vbaProject.bin` + `vbaProjectSignature` | 仅 `macrosheets/sheetX.bin` (OOXML) 或 BIFF8 `BOUNDSHEET` 记录 | 无 VBA 流，基于 VBA 的 YARA/特征库失效 |
| **关键字** | `AutoOpen`、`Shell`、`CreateObject` | `EXEC`、`ALERT`、`HALT`、`Auto_Open` | 关键字集完全不同，需专用规则 |
| **熵值/混淆** | 字符串加密、控制流平坦化 | 单元格拆分、公式嵌套、`FORMULA`/`EXECUTE` 间接调用 | 天然支持单元格级混淆，易生成多态变体 |

### 动态行为对抗

| 防御层 | 检测点 | XLM 宏表现 | 绕过思路 |
|--------|--------|------------|----------|
| **AMSI** | `AmsiScanBuffer` 扫描脚本内容 | XLM 宏由 `excel.exe` 内部解释器直接执行，**不经过 AMSI** | 天然绕过 AMSI，无需 `AmsiScanBuffer` 绕过 |
| **宏安全设置** | “禁用所有宏并通知”/“禁用所有宏不通知” | 需用户点击“启用内容”或利用受信任记录 | 社工诱导点击 / 受信任记录复用 / 结合 `DDE`/`IQY` 等非宏向量 |
| **EDR 进程监控** | `CreateProcess` 调用栈回溯 | `EXEC → WinExec → CreateProcess`，调用栈含 `excel.exe` 模块 | 父进程为合法 `excel.exe`，易混入正常办公流量；可结合 [[argument-spoofing-edr-evasion|参数欺骗]]、[[phantom-dll-hollowing-technique|模块隐藏]] 进一步降噪 |
| **内存扫描** | 宏解释器堆/栈特征 | 宏字节码驻留在 `excel.exe` 进程内存，无独立 PE | 需结合 [[memory-scanning-tools-evasion-techniques|UDRL/睡眠混淆]] 技术，或转向 [[inceptor-av-edr-evasion-framework|Donut/sRDI]] 落地 Shellcode |

### 受信任记录利用链

1. **首次投递**：诱导用户启用宏 → 系统记录文件路径/哈希至 `Trusted Documents`。
2. **二次投递**：替换同名文件（或利用 WebDAV/SMB 同步覆盖）→ 用户再次打开 → **静默执行**。
3. **持久化变体**：将恶意 `.xlsm` 放入 `XLSTART` 目录 → Excel 启动自动加载 → 结合 [[windows-scheduled-task-persistence-techniques|计划任务]] 定时触发。

## 关联攻防生态

| 场景 | 关联技术 | 说明 |
|------|----------|------|
| **初始访问** | [[cobalt-strike-ssl-keystore-evasion|C2 证书伪造]]、[[c2-redirectors-malleable-c2-profiles|重定向器]] | XLM 宏落地 Beacon Stager，配合 Malleable C2 Profile 隐匿流量 |
| **免杀框架集成** | [[inceptor-av-edr-evasion-framework|Inceptor]]、[[ppl-injection-createprocess-bof-fix|PPL 注入]] | 宏中 `EXEC` 启动 Inceptor 生成的免杀 Loader，或通过 BOF 实现 PPL 进程注入 |
| **凭证获取** | [[mimikatz-sekurlsa-pth-internals|Pass-the-Hash]]、[[mimikatz-source-code-architecture-golden-ticket-audit|黄金票据]] | 落地后横向移动至域控 |
| **内网穿透** | [[frp内网渗透应用|frp]]、[[http-proxy-tunneling-goproxy-netsh|goproxy/netsh]] | 建立 SOCKS/HTTP 代理通道 |
| **蓝队溯源** | [[threat-attribution-tracing-techniques|威胁溯源]]、[[xd-security-incident-response-notes|应急响应日志分析]] | 重点排查 `excel.exe` 进程树、文件修改时间、受信任记录注册表 |

## 检测与缓解建议

### 检测规则示例（Sigma/Elastic）

```yaml
title: Suspicious Excel 4.0 Macro Execution
id: xlm-macro-exec-detection
status: experimental
logsource:
  product: windows
  category: process_creation
detection:
  selection:
    ParentImage|endswith: '\excel.exe'
    Image|endswith: 
      - '\calc.exe'
      - '\cmd.exe'
      - '\powershell.exe'
      - '\wscript.exe'
      - '\cscript.exe'
      - '\mshta.exe'
    CommandLine|contains: 'EXEC'
  condition: selection
level: high
tags:
  - attack.t1059.005
  - attack.t1204.002
```

### 缓解措施

1. **组策略强制禁用 XLM 宏**  
   `User Configuration → Administrative Templates → Microsoft Excel → Excel Options → Security → Trust Center → Macro Settings → "Disable Excel 4.0 macros"` (Office 2016+ 支持)。
2. **清理受信任记录**  
   定期清空 `%APPDATA%\Microsoft\Excel\XLSTART` 与注册表 `Trusted Documents` 键值。
3. **应用控制**  
   AppLocker/WDAC 规则限制 `excel.exe` 仅允许启动受信签名子进程。
4. **行为监控**  
   Sysmon Event ID 1 监控 `excel.exe` 创建非 Office 组件进程；结合 [[named-pipe-smb-detection-sysmon|Sysmon Event ID 17/18]] 监控命名管道通信。
5. **文件级检测**  
   部署 `oletools` 扩展插件解析 `macrosheets/` 流，提取 `EXEC`/`Auto_Open` 等特征。

## 参考资料

1. Outflank Blog – [Old School Evil: Excel 4.0 Macros (XLM)](https://outflank.nl/blog/2018/10/06/old-school-evil-excel-4-0-macros-xlm/)
2. Microsoft Docs – [Excel 4.0 Macro Functions Reference](https://learn.microsoft.com/en-us/previous-versions/office/developer/excel-2010/aa141037(v=office.14))
3. az4n6 Blog – [More on Trust Records, Macros, and…](http://az4n6.blogspot.com/2016/02/more-on-trust-records-macros-and.html)
4. MITRE ATT&CK – [T1059.005: Visual Basic](https://attack.mitre.org/techniques/T1059/005/), [T1204.002: Malicious File](https://attack.mitre.org/techniques/T1204/002/)
5. 0x727 Team – [[inceptor-av-edr-evasion-framework|Inceptor AV/EDR Evasion Framework]]
6. 0x6270 Team – [[cobalt-strike-4.7-bof-internals|Cobalt Strike 4.7 BOF Internals]]
7. 红队 OPSEC 规范 – [[redteam-hw-opsec-guidelines|HW 红队演练 OPSEC 指南]]

## 交叉引用索引

- **初始访问/免杀投递**：[[phishing-website-creation-tutorial|钓鱼网站制作]]、[[cobalt-strike-ssl-keystore-evasion|C2 证书伪造]]、[[c2-redirectors-malleable-c2-profiles|重定向器部署]]
- **内存/EDR 对抗**：[[memory-scanning-tools-evasion-techniques|内存扫描对抗]]、[[inceptor-av-edr-evasion-framework|Inceptor 框架]]、[[phantom-dll-hollowing-technique|Phantom DLL Hollowing]]、[[argument-spoofing-edr-evasion|参数欺骗]]、[[dotnet-clr-usage-log-tampering-edr-evasion|.NET CLR 日志篡改]]
- **持久化/横向**：[[windows-scheduled-task-persistence-techniques|计划任务持久化]]、[[ppl-injection-createprocess-bof-fix|PPL 注入]]、[[mimikatz-sekurlsa-pth-internals|Pass-the-Hash]]、[[frp内网渗透应用|frp 内网穿透]]
- **蓝队溯源/响应**：[[threat-attribution-tracing-techniques|威胁溯源]]、[[xd-security-incident-response-notes|应急响应笔记]]、[[named-pipe-smb-detection-sysmon|SMB 命名管道检测]]

> 本页面基于归档文章《Excel 4.0宏躲避杀软检测》整理，结合现有知识库交叉引用，形成 XLM 宏技术原理、实战免杀投递、对抗检测机制的结构化知识页。

## 来源

- [226安全团队-201805-202103_30](../sources/226安全团队-201805-202103_30.md)
