---
title: 0w1Club CTF RE 方向全难度题解合集
description: 整合 0w1Club 微信归档 RE 方向全难度题解：入门级明文搜索、Base64、APK/ELF 逆向；进阶栈溢出覆写、线性方程组求解
  Flag、凯撒移位、MD5/Base64/XOR 多重编码校验、OD 动态调试绕过花指令与反调试、C++ 标准库混淆分析。涵盖十六进制编辑器、IDA Pro、OllyDbg、DEX2JAR/JD-GUI、Python
  脚本编写、OD 动态调试等工具与技术的实战应用。
category: program-analysis
tags:
- 0w1Club
- CTF
- Reverse Engineering
- RE
- Beginner
- Advanced
- Stack Overflow
- Base64
- Android
- APK
- ELF
- Bitwise Operations
- Linear Equations
- Caesar Cipher
- MD5
- XOR
- IDA Pro
- OllyDbg
- Python
- Dynamic Analysis
- Anti-Debugging
- Obfuscation
- C++ STL
date: 2019-10-01
updated: '2026-11-14'
---

## 概述

本页面整理自 0w1Club 微信公众号发布的《题解 | RE》系列文章，记录了**萌新培养系列 RE 方向**七道题目的完整解题思路与技术细节。题目难度跨度大，覆盖了逆向工程从入门到进阶的核心技能点：

| 难度 | 题目编号 | 题目名称 | 核心考点 | 涉及工具 |
|------|----------|----------|----------|----------|
| 入门 | 1 | 小试牛刀 | 明文 Flag 搜索、字符串比对逻辑分析 | 十六进制编辑器、IDA Pro、OllyDbg |
| 入门 | 2 | 有、意思 | Base64 编码逆向、IDA 伪代码与运行时差异、Python 脚本解密 | IDA Pro、Python |
| 入门 | 3 | CrackMe | Android APK 逆向、硬编码凭证提取 | DEX2JAR、JD-GUI |
| 入门 | 4 | 无法自拔 | 64 位 ELF 双阶段位运算、假 Flag 干扰、C++ STL 字符串分析 | IDA Pro 64-bit、Python |
| 进阶 | 5 | Do you want the flag? | 栈溢出覆写局部变量、函数调用栈布局分析 | IDA Pro、十六进制编辑器 |
| 进阶 | 6 | Solve me | 凯撒移位、线性方程组求解、递归 GCD 干扰、多阶段 Flag 拼接 | IDA Pro、Python (NumPy) |
| 进阶 | 7 | You can fix this | C++ STL 混淆、花指令/反调试、MD5/Base64/XOR 多重校验、OD 动态调试 | IDA Pro、OllyDbg、PEiD/Kanal、Python |

> 这些题目适合作为 [[reverse-engineering-beginner-learning-path|逆向工程初学者学习路径]] 的实战练手素材，配合工具使用与脚本编写快速建立分析直觉。

---

## 入门级题目（萌新培养系列）

### 题目一：小试牛刀

#### 题目思路

入门级题目，可执行文件直接在内存中以**明文**存储正确 Flag，通过简单的字符串比对验证输入。

#### 解题方法

**方法 1：十六进制编辑器搜索（最快）**
1. 用十六进制编辑器（如 HxD、010 Editor）打开文件
2. `Ctrl+F` 搜索 Flag 格式特征字符串：`XJbest`
3. 直接定位到 Flag 明文位置

**方法 2：IDA Pro 静态分析**
1. 打开 `main` 函数，切换到伪代码视图（`F5`）
2. 观察输入字符串存放位置（如 `&v9`）与比对目标字符串位置（如 `&v5`）
3. 双击 `&v5` 跳转到数据段，直接查看明文字符串

**方法 3：OllyDbg 动态调试**
1. 加载程序，使用「中文搜索」或「字符串搜索」功能
2. 搜索 `XJbest` 或 `flag` 关键字
3. 在内存窗口中直接读取 Flag

> **技巧总结**：入门题优先尝试字符串搜索，无需深入分析逻辑；IDA 伪代码可快速定位比对变量，适合养成「先看数据流」的分析习惯。

---

### 题目二：有、意思

#### 题目思路

Flag 不再以明文存储，程序对输入进行 **Base64 编码** 后与预存密文比对。主要难点：
1. 程序输出结果后闪退，需动态调试定格或直接提交平台验证
2. IDA 伪代码显示的字符串长度与实际运行时提取的长度不一致——**IDA 反编译结果可能与运行时行为有偏差**，需结合数据段实际内容分析

#### 解题流程

**IDA 伪代码分析主流程**
```c
// 伪代码核心逻辑
sub_4110BE(&Str, &DEST);           // Base64 编码输入字符串
for (i = 0; i < len; i++) {
    DEST[i] += i;                  // 每字节加上其索引
}
if (strcmp(DEST, Str2) == 0)       // 与预存密文比对
    success();
```

**定位关键密文 `Str2`**
- 伪代码中可见的 `Str2` 仅为前缀
- 必须在 **数据段** 查看完整内存布局，发现 `Str2` 后续非零字节仍属比对范围
- 实际参与比对的密文长度为 **24 字节**

**逆向 `sub_4110BE` 确认 Base64 逻辑**
- 代码特征：`%3` 分组、`*4` 扩展、查表 `aAbcdefghijklmn[64]`、不足补 `=`
- 标准 Base64 编码实现：3 字节 → 4 字节，索引表为 `ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/`

**解密步骤**
1. 提取完整 24 字节密文 `Str2`
2. 每字节减去其索引：`decoded[i] = Str2[i] - i`
3. 对结果进行 Base64 解码 → 得到 Flag

**Python 解密脚本参考**
```python
import base64

# 提取的 24 字节密文（示例，实际需从数据段获取）
enc = b"..."  # 24 bytes

# 步骤 1: 减去索引
step1 = bytes([enc[i] - i for i in range(len(enc))])

# 步骤 2: Base64 解码
flag = base64.b64decode(step1).decode()
print(flag)
```

> **核心收获**：
> - 结合 [[ida-pro-tips-plugins-python|IDA Pro 实用技巧]] 中的数据段浏览与字符串提取技巧
> - 遇到「伪代码长度不符」时，**以数据段实际字节为准**
> - 简单编码算法（Base64、XOR、ROT）可优先用在线工具或 Python 标准库快速验证

---

### 题目三：CrackMe

#### 题目思路

Android APK 逆向入门题，应用层逻辑极简：**硬编码用户名/密码** 直接在 Java 层比对。

#### 解题流程
1. 修改文件扩展名为 `.apk`
2. 使用 `DEX2JAR` 将 `classes.dex` 转换为 `classes-dex2jar.jar`
3. 用 `JD-GUI` 打开 Jar 包，浏览源码
4. 定位登录校验逻辑，直接读取硬编码凭证：

```java
// 伪代码还原
if (username.equals("0w1nb") && password.equals("qweasdzxc")) {
    showSuccess("成功,this_is_stupid_challenge");
}
```

5. Flag 格式化提交：`flag{this_stupid_challenge}`（题目表达歧义导致多种格式均被接受）

> **扩展**：Android 逆向进阶可关注 `smali` 代码阅读、动态调试（`frida`/`xposed`）、.native so 层分析等，超出本入门题范围。

---

### 题目四：无法自拔

#### 题目思路

64 位 ELF 程序，核心逻辑分两阶段位运算处理，且**第一阶段会产出一个假 Flag** 干扰分析。需耐心跟踪 C++ STL `std::string` 相关函数调用，结合位运算逆向还原真 Flag。

#### 解题流程

**入口函数分析（`main` 伪代码）**
```cpp
std::string input;
std::getline(std::cin, input);
std::string v6 = input;
sub_4010A2(v6);  // 核心处理函数
```

**第一阶段：`sub_4010A2` → `sub_40111A`（产出假 Flag）**

核心循环伪代码：
```c
for (i = 0; i < len; i++) {
    v2 = (a1[i] << 2) | (a1[i] >> 6);  // 循环左移 2 位 (ROL 2)
    v3 = v2 ^ i;                         // 异或索引
    if (v3 != s1[i])                     // 与预存数组比对
        goto fail;
}
sub_4012CE();  // 输出假 Flag
```
- 操作：**ROL 2 → XOR 索引**
- 逆向：`a1[i] = ROR(s1[i] ^ i, 2)`
- 构造输入通过比对后，程序输出 **假 Flag**：`flag{7h15_15_4_f4k3_F14G_=3=_rua!}`

**第二阶段：`sub_401332`（真 Flag 校验）**

嵌套循环 4×8=32 次，核心表达式：
```c
v3 = a[j] | a[j-1];
v2 = a[j];
v1 = v3 & ~(v2 & a[j-1]);  // 等价于 a[j] ^ a[j-1] (XOR)
```
- 通过真值表验证：`v1 = a[j] ^ a[j-1]`
- 最终将计算结果与预存数组 `s`、`v9`、`v10`、`v11` 比对

**完整逆向链路**
1. 从第二阶段比对数组逆推 `sub_401332` 输入时的字符串状态（32 字节）
2. 该状态即为第一阶段处理**后**的字符串
3. 对第一阶段算法逆向（`ROR 2 → XOR index`）还原初始输入 Flag

**Python 逆向脚本框架**
```python
# 伪代码框架，实际需填入从 IDA 提取的具体数组值
s1 = [...]      # 第一阶段比对数组
s2 = [...]      # 第二阶段比对数组组合

# 步骤 1: 逆向第二阶段（XOR 链）
# 已知 v1[i] = a[i] ^ a[i-1] 且 v1 为已知比对值
# 需要已知 a[0] 或通过约束求解，此处假设已知初始值或通过爆破
# 逆向得到 stage1_output[32]

# 步骤 2: 逆向第一阶段
def ror2(x):
    return ((x >> 2) | (x << 6)) & 0xFF

flag_chars = []
for i in range(32):
    val = ror2(stage1_output[i] ^ i)
    flag_chars.append(val)

flag = bytes(flag_chars).decode()
print(flag)
```

> **关键技巧**：
> - **C++ STL 伪代码阅读**：`std::string` 操作在 IDA 中表现为一长串内部函数调用，关注**参数传递**与**返回值赋值**，忽略实现细节
> - **位运算等价变换**：`a | b & ~(a & b) ≡ a ^ b`，熟练识别可大幅简化分析
> - **小端序注意**：IDA 显示的数组字节序即为内存序，Python 处理时直接按顺序读取
> - **假 Flag 识别**：格式规范但语义异常（如 `fake`、`f4k3` 字样）通常为干扰，需继续分析后续逻辑

---

## 进阶题目（核心技术突破）

### 题目五：Do you want the flag?

#### 题目分析

程序要求用户输入一串字符，通过验证将输出 flag。IDA 观察主函数流程：

- 向 `s` 中读入用户输入（`s` 仅 1 字节大小）
- 判断变量 `v5` 是否为 `'g'`，不满足则报错
- `puts` 函数可向 `s` 写入 10 字节，**明显存在栈溢出**

#### 栈帧布局分析

```
... (高地址)
s (bp-5)          // 局部变量，1字节
v5 (bp-1)         // 局部变量，1字节
bp                // 栈帧基地址
Ret address       // 返回地址
Old bp            // 上一栈帧基地址
envp, argv, argc  // 参数
... (低地址)
```

`v5` 与 `s` 相差 4 字节，输入 5 字节且第 5 字节为 `'g'` 即可覆盖 `v5` 满足判断条件。

#### 解题利用

直接输入 5 字节：`XXXXg`（前 4 字节任意，第 5 字节为 `g`），程序输出 flag。

#### 备选方案：分析 `func1`

若未发现栈溢出，可直接分析 `func1` 函数：
- 从各地址取字符构成字符串
- 耐心到各地址找出数据，转换为 char 并重命名（快捷键 `n`）
- 直接在伪代码中可见 Flag 组装过程

> **核心收获**：
> - 栈溢出不仅用于控制流劫持，**覆盖相邻局部变量绕过判断** 是基础用法
> - 养成「先看栈帧布局、再看危险函数」的静态分析习惯
> - IDA 中 `N` 键重命名变量、`/` 搜索字符串是高频操作

---

### 题目六：Solve me

#### 题目概况

同类套路，但逻辑显著复杂化：输入长度校验 → 凯撒加密 → 三轮检查（线性方程组、递归干扰函数、后半段推导）。

#### 程序流程 (IDA 伪代码)

```c
// 主流程
if (strlen(input) != 16) fail();
func1(input);  // 凯撒加密
check1(); check2(); check3();  // 三轮验证
```

#### 关键点 1：`func1` - 凯撒加密

```c
// 伪代码特征
if (c >= 'a' && c <= 'z') c = (c - 'a' + shift) % 26 + 'a';
if (c >= 'A' && c <= 'Z') c = (c - 'A' + shift) % 26 + 'A';
```
- 对输入每字符进行移位（`shift = a2`）
- 标准凯撒密码实现，**可逆**

#### 关键点 2：`check1` - 线性方程组求解前 8 字节

- 8 个方程，8 个未知数（`a[0]~a[7]`）
- 系数矩阵 8×8，常数项向量 8×1
- IDA 伪代码直接可见系数，提取后用 Python (NumPy) 求解

**Python 求解脚本**
```python
import numpy as np

# 从 IDA 伪代码提取的系数矩阵 (8x8) 和常数向量 (8)
a = [[34457, 29380, -65705, -66743, 70493, 69309, 72977, -14053],
     [65183, 18447, 93262, -71657, -79941, -97892, 84355, -77722],
     [44907, 35698, 49847, 12606, -75734, -55390, 29059, 62651],
     [-76186, 30310, 28018, 52661, -56848, -41706, -31828, 68692],
     [46778, 61198, -13303, 61530, -16396, -73855, 92014, 21369],
     [-67206, -28601, 27769, -45427, -12766, -11359, 87788, -39439],
     [94620, -25263, 72072, -66264, -77747, -33904, 21114, -78975],
     [28631, 70263, 20010, 12166, -23578, -76995, 83730, 54892]]

b = [8105127, -8204507, 9078239, -394695, 14405025, -8311181, -10449462, 14157802]

a = np.array(a, dtype=np.float64)
b = np.array(b, dtype=np.float64)
x = np.linalg.solve(a, b)

flag_part1 = ''.join(chr(int(round(v))) for v in x)
print(flag_part1)  # 得到前 8 字符
```

#### 关键点 3：`check2` - 递归 GCD 干扰函数

```c
int check2(int a1, int a2) {
    if (a1 == a2) return a1;
    if (a1 < a2)  return check2(a2 - a1, a1 + 1);
    if (a1 > a2)  return check2(a1 - a2, a2 + 1);
}
```
- **本质**：辗转相减法求最大公约数 (GCD) 变种
- 参数一：`|a1 - a2|`（通过符号位技巧实现绝对值）
- 参数二：`min(a1, a2) + 1`
- **返回值恒非零**（除非初始均为 0），**纯干扰逻辑**，无需深究返回值

> **逆向心法**：遇到复杂递归/循环，**先观察返回值如何被使用**。若仅用于 `if (ret)` 非零判断，大概率为干扰。

#### 关键点 4：`check3` - 推导后 8 字节

```c
// 伪代码简化
y[0] = 32 + (2*c[0] - c[5]);
y[1] = 440 - c[1]*5;
y[7] = ((c[6]%10)*10 + (c[6]/10));  // 个十位交换
y[2] = y[7] - c[7] + c[2];
y[6] = 62 ^ 85;  // 常数 107
y[3] = y[6] + 1; // 108
y[4] = 4*32 - 6; // 122
y[5] = 9*9;      // 81
```
- 利用 `check1` 解出的 `c[0]~c[7]` 直接计算 `y[0]~y[7]`（即 `a[8]~a[15]`）
- 无未知数，**纯正向计算**

#### 完整 Exp 流程

1. 提取 `check1` 系数矩阵 → NumPy 求解 → 得 `c[0..7]`
2. 代入 `check3` 公式 → 算出 `y[0..7]`
3. 拼接 16 字符 → **加密后的 Flag**
4. 逆向凯撒移位（向反方向移位 `shift` 位） → **原始 Flag**

> **核心收获**：
> - **线性方程组求解** 是 CTF RE 常见模式，NumPy `linalg.solve` 秒级搞定
> - **干扰函数识别**：看返回值用途、递归收敛性、副作用
> - **多阶段 Flag 拼接**：前半段解方程、后半段推导、最后解码还原
> - 结合 [[crypto-basics-xor-stream-cipher-tutorial|异或加密原理]] 理解位运算变换思路

---

### 题目七：You can fix this

#### 题目特点

- C++ 编写，大量标准库调用 → IDA 伪代码极难读
- 加入**花指令**、**反调试**、**混淆手法** → 静态分析阻力大
- 使用 **MD5、Base64、XOR** 多重编码校验
- **动态调试 (OD) 为主、静态分析为辅** 的实战典范

#### 工具准备

- PEiD + Kanal 插件：识别加密算法特征（检测到 Base64、MD5）
- OllyDbg (OD)：动态调试主力
- IDA Pro：辅助定位关键地址、查看字符串/常量

---

#### 动态调试全流程 (OD)

##### 阶段 0：定位 `main` 入口

- OD 载入程序，单步 (`F8`) + 断点 (`F2`) 找到 `main` 真正开始处
- C++ 运行时启动代码较长，耐心穿过 `__tmainCRTStartup` 等桩代码

##### 阶段 1：输入获取与长度校验

- 发现 `cin` 调用读取输入 → 存入栈 `[ebp-0x94]`
- `strlen` 校验长度：`0 < len < 30` → 输入 `0W1CTF{1234567890123456789012}` 满足

##### 阶段 2：前缀格式校验 (Key 1~3)

| Key | 校验位置 | 期望值 | 对应字符 |
|-----|----------|--------|----------|
| 1 | `input[0..6]` | `0W1CTF{` | 固定前缀 |
| 2 | `input[29]` | `0x7d` | `}` |
| 3 | `input[9], [15], [18], [22]` | `0x5f` | `_` 下划线 |

> **调试技巧**：每通过一关，修改输入重新从头跑 (`Ctrl+F2` 重启)，避免状态污染。

##### 阶段 3：MD5 校验 Flag 第一段 (Key 4)

- 取 `input[7], input[8]` (即 `YQ`) → 调用 MD5 函数 (`0xE215F0`)
- 与硬编码密文 `dcfed125d6507dc8c473c49fd8ad891d` 比对
- 在线查 MD5：`md5("YQ") = dcfed125d6507dc8c473c49fd8ad891d` ✓
- 修正输入：`0W1CTF{YQ_...}`

##### 阶段 4：MD5 差值校验 Flag 第二段 (Key 5)

- 取 `input[10..14]` (5 字节) → MD5 → 得 `md5_2`
- 计算 `md5_2 - md5_1` (逐字节相减) → 与 `check` 数组比对
- `check` 数组 (从 IDA 数据段提取)：
  ```
  0xFD, 0xC2, 0xE6, 0xE3, 0x98, 0xF5, 0xDF, 0x0B,
  0x9F, 0xFD, 0xFA, 0x23, 0x9D, 0xA4, 0xCE, 0xC3
  ```
- 反推：`md5_2 = md5_1 + check` (逐字节加，模 256)
- 算得目标 MD5：`cda99cf90480d165fdd7119d76ce6aa6`
- 碰撞/查表得明文：`w4nts`
- 修正输入：`0W1CTF{YQ_w4nts_...}`

> **技巧**：MD5 逆向通常靠彩虹表/在线数据库，CTF 题目多用常见单词。

##### 阶段 5：Base64 校验 Flag 第三段 (Key 6)

- 取 `input[23..25]` (`012`) → Base64 编码 → `MDEy`
- 与硬编码 `MzR0` 比对
- 解码 `MzR0` → `34t`
- 修正输入：`0W1CTF{YQ_w4nts_89_34t_...}`

##### 阶段 6：XOR 校验 Flag 尾部 (Key 7-8)

- 取 `input[16], input[17]` (即 `8`, `9` 位置) 与数组 `a` 异或
- 数组 `a` (8 字节)：
  ```
  0x0B, 0x7C, 0x00, 0x5C, 0x20, 0x01, 0x63, 0x4D
  ```
- 校验目标：最后 8 字符 (含 `_` 和 `}`)
- 已知 `input[28] = '_' (0x5F)`, `input[29] = '}' (0x7D)`
- 逆推：
  - `input[16] = 0x5F ^ 0x0B = 0x54 = 'T'`
  - `input[17] = 0x7D ^ 0x4D = 0x30 = '0'`
- 继续逆推后 6 字节：
  - `input[20] = 0x5C ^ 0x5F = 0x03` → 非可见？实为中间校验链
  - 实测完整尾部：`LTlt17}`

#### 最终 Flag

```
0W1CTF{YQ_w4nts_T0_34t_LTlt17}
```

---

#### 核心技术总结

| 技术点 | 实战体现 | 进阶参考 |
|--------|----------|----------|
| **C++ STL 混淆应对** | `cin`/`cout`/`string` 产生海量垃圾代码 | 放弃全量静态阅读，**OD 定位关键断点** |
| **花指令识别** | `jmp $+5` / 无效算术 / 梧桐指令 | OD 单步时跳过明显无副作用块，关注内存/寄存器实质变化 |
| **反调试绕过** | 题目未显式反调，但 C++ 异常处理可干扰 | OD 设置忽略异常 (`Alt+O` → Exceptions → Ignore) |
| **加密算法识别** | PEiD/Kanal 自动标记 MD5/Base64 | [[ida-pro-tips-plugins-python#findcrypt-yara-加密常数识别\|Findcrypt-Yara]] IDA 插件同理 |
| **动态调试工作流** | 断点 → 单步 → 观察内存/寄存器 → 修改输入 → 重跑 | 养成「假设-验证-修正」循环，比死读伪代码快 10 倍 |
| **多编码组合校验** | MD5 → 差值 → Base64 → XOR 链式 | 逐层剥离，每层得明文即推进，不要试图一次性建立完整方程 |

---

## 工具与技能全景对照表

| 技能维度 | 入门题覆盖 | 进阶题覆盖 | 进阶参考资源 |
|----------|------------|------------|--------------|
| **静态分析基础** | 字符串搜索、伪代码阅读、数据段跳转 | C++ STL 伪代码解读、花指令干扰下的关键逻辑定位 | [[ida-pro-tips-plugins-python]] |
| **动态调试** | OllyDbg 字符串搜索、内存窗口读取 | OD 全流程：入口定位、断点策略、寄存器/栈观察、输入修正重跑 | 《OD 实战技巧》、x64dbg 文档 |
| **编码/加密识别** | Base64 特征识别 | PEiD/Kanal 自动识别、MD5/Base64/XOR 组合链 | [[crypto-basics-xor-stream-cipher-tutorial]] |
| **脚本化辅助** | Python Base64 解码、位运算逆向 | NumPy 线性方程组求解、MD5 碰撞查表、批量 XOR 逆推 | `pwntools`, `capstone`, `keystone` |
| **Android 逆向** | DEX2JAR + JD-GUI 硬编码提取 | — | `jadx`, `apktool`, `frida` |
| **数学建模** | — | 线性方程组、GCD 变种识别、异或链逆向 | 线性代数基础、离散数学 |
| **C++ 逆向** | STL `string` 基础操作 | 标准库混淆下的语义还原、异常处理桩代码识别 | 《C++ 逆向工程》、Itanium ABI 文档 |
| **栈/内存布局** | 栈溢出覆盖相邻变量 | — | [[rop-linux-x86-beginner-tutorial]] |

---

## 交叉引用与延伸阅读

- [[reverse-engineering-beginner-learning-path]] — 逆向工程入门学习路线与资源推荐
- [[ida-pro-tips-plugins-python]] — IDA Pro 进阶技巧：FLIRT 签名、Findcrypt-Yara、Keypatch、IDAPython 环境配置
- [[crypto-basics-xor-stream-cipher-tutorial]] — 异或加密原理与 Two-Time-Pad 攻击，对理解位运算逆向有帮助
- [[rop-linux-x86-beginner-tutorial]] — Linux x86 ROP 入门，理解栈帧与调用约定，辅助分析 ELF 程序控制流
- [[binary-ninja-ollvm-deobfuscation]] — OLLVM 控制流平坦化去混淆，进阶对抗 C++ 混淆的自动化思路

---

## 附录：原文来源

> 文章来源：0w1Club 微信公众号《题解 | RE》  
> 原文链接：<http://mp.weixin.qq.com/s?__biz=MzUzMzEwMDk3Mg==&mid=2247483865&idx=1&sn=d04e546230ca98d864620b3a46a2fb24>  
> 发布时间：约 2019 年萌新培养系列期间

## 来源

- [0w1网络安全俱乐部-201707-201903_03](../sources/0w1网络安全俱乐部-201707-201903_03.md)
- [0w1网络安全俱乐部-201707-201903_24](../sources/0w1网络安全俱乐部-201707-201903_24.md)
