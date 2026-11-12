---
title: 0w1Club 萌新培养系列 RE 入门题目详解
description: 详细记录 0w1Club 萌新培养系列 RE 方向四道入门题目的解题过程：明文 Flag 搜索、Base64 编码逆向、Android APK
  逆向硬编码凭证、64 位 ELF 双阶段位运算含假 Flag 干扰。涵盖十六进制编辑器、IDA Pro、OllyDbg、DEX2JAR/JD-GUI、Python
  脚本编写等工具与技术的实战应用。
category: program-analysis
tags:
- 0w1Club
- CTF
- Reverse Engineering
- RE
- Beginner
- Base64
- Android
- APK
- ELF
- Bitwise Operations
- IDA Pro
- OllyDbg
- Python
date: 2019-10-01
updated: '2026-11-13'
---

## 概述

本页面整理自 0w1Club 微信公众号发布的《题解 | RE》文章，记录了**萌新培养系列 RE 方向**四道入门题目的完整解题思路与技术细节。四道题目难度递进，覆盖了逆向工程入门的核心技能点：

| 题目编号 | 题目名称 | 核心考点 | 涉及工具 |
|----------|----------|----------|----------|
| 1 | 小试牛刀 | 明文 Flag 搜索、字符串比对逻辑分析 | 十六进制编辑器、IDA Pro、OllyDbg |
| 2 | 有、意思 | Base64 编码逆向、IDA 伪代码与运行时差异、Python 脚本解密 | IDA Pro、Python |
| 3 | CrackMe | Android APK 逆向、硬编码凭证提取 | DEX2JAR、JD-GUI |
| 4 | 无法自拔 | 64 位 ELF 双阶段位运算、假 Flag 干扰、C++ STL 字符串分析 | IDA Pro 64-bit、Python |

> 这些题目适合作为 [[reverse-engineering-beginner-learning-path|逆向工程初学者学习路径]] 的实战练手素材，配合工具使用与脚本编写快速建立分析直觉。

---

## 题目一：小试牛刀

### 题目思路

入门级题目，可执行文件直接在内存中以**明文**存储正确 Flag，通过简单的字符串比对验证输入。

### 解题方法

#### 方法 1：十六进制编辑器搜索（最快）

1.  用十六进制编辑器（如 HxD、010 Editor）打开文件
2.  `Ctrl+F` 搜索 Flag 格式特征字符串：`XJbest`
3.  直接定位到 Flag 明文位置

#### 方法 2：IDA Pro 静态分析

1.  打开 `main` 函数，切换到伪代码视图（`F5`）
2.  观察输入字符串存放位置（如 `&v9`）与比对目标字符串位置（如 `&v5`）
3.  双击 `&v5` 跳转到数据段，直接查看明文字符串

#### 方法 3：OllyDbg 动态调试

1.  加载程序，使用「中文搜索」或「字符串搜索」功能
2.  搜索 `XJbest` 或 `flag` 关键字
3.  在内存窗口中直接读取 Flag

> **技巧总结**：入门题优先尝试字符串搜索，无需深入分析逻辑；IDA 伪代码可快速定位比对变量，适合养成「先看数据流」的分析习惯。

---

## 题目二：有、意思

### 题目思路

Flag 不再以明文存储，程序对输入进行 **Base64 编码** 后与预存密文比对。主要难点：

1.  程序输出结果后闪退，需动态调试定格或直接提交平台验证
2.  IDA 伪代码显示的字符串长度与实际运行时提取的长度不一致——**IDA 反编译结果可能与运行时行为有偏差**，需结合数据段实际内容分析

### 解题流程

#### IDA 伪代码分析主流程

```c
// 伪代码核心逻辑
sub_4110BE(&Str, &DEST);           // Base64 编码输入字符串
for (i = 0; i < len; i++) {
    DEST[i] += i;                  // 每字节加上其索引
}
if (strcmp(DEST, Str2) == 0)       // 与预存密文比对
    success();
```

#### 定位关键密文 `Str2`

- 伪代码中可见的 `Str2` 仅为前缀
- 必须在 **数据段** 查看完整内存布局，发现 `Str2` 后续非零字节仍属比对范围
- 实际参与比对的密文长度为 **24 字节**

#### 逆向 `sub_4110BE` 确认 Base64 逻辑

- 代码特征：`%3` 分组、`*4` 扩展、查表 `aAbcdefghijklmn[64]`、不足补 `=`
- 标准 Base64 编码实现：3 字节 → 4 字节，索引表为 `ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/`

#### 解密步骤

1.  提取完整 24 字节密文 `Str2`
2.  每字节减去其索引：`decoded[i] = Str2[i] - i`
3.  对结果进行 Base64 解码 → 得到 Flag

#### Python 解密脚本参考

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

## 题目三：CrackMe

### 题目思路

Android APK 逆向入门题，应用层逻辑极简：**硬编码用户名/密码** 直接在 Java 层比对。

### 解题流程

1.  修改文件扩展名为 `.apk`
2.  使用 `DEX2JAR` 将 `classes.dex` 转换为 `classes-dex2jar.jar`
3.  用 `JD-GUI` 打开 Jar 包，浏览源码
4.  定位登录校验逻辑，直接读取硬编码凭证：

```java
// 伪代码还原
if (username.equals("0w1nb") && password.equals("qweasdzxc")) {
    showSuccess("成功,this_is_stupid_challenge");
}
```

5.  Flag 格式化提交：`flag{this_stupid_challenge}`（题目表达歧义导致多种格式均被接受）

> **扩展**：Android 逆向进阶可关注 `smali` 代码阅读、动态调试（`frida`/`xposed`）、.native so 层分析等，超出本入门题范围。

---

## 题目四：无法自拔

### 题目思路

64 位 ELF 程序，核心逻辑分两阶段位运算处理，且**第一阶段会产出一个假 Flag** 干扰分析。需耐心跟踪 C++ STL `std::string` 相关函数调用，结合位运算逆向还原真 Flag。

### 解题流程

#### 入口函数分析（`main` 伪代码）

```cpp
std::string input;
std::getline(std::cin, input);
std::string v6 = input;
sub_4010A2(v6);  // 核心处理函数
```

#### 第一阶段：`sub_4010A2` → `sub_40111A`（产出假 Flag）

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

#### 第二阶段：`sub_401332`（真 Flag 校验）

嵌套循环 4×8=32 次，核心表达式：

```c
v3 = a[j] | a[j-1];
v2 = a[j];
v1 = v3 & ~(v2 & a[j-1]);  // 等价于 a[j] ^ a[j-1] (XOR)
```

- 通过真值表验证：`v1 = a[j] ^ a[j-1]`
- 最终将计算结果与预存数组 `s`、`v9`、`v10`、`v11` 比对

#### 完整逆向链路

1.  从第二阶段比对数组逆推 `sub_401332` 输入时的字符串状态（32 字节）
2.  该状态即为第一阶段处理**后**的字符串
3.  对第一阶段算法逆向（`ROR 2 → XOR index`）还原初始输入 Flag

#### Python 逆向脚本框架

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

## 工具与技能小结

| 技能点 | 题目体现 | 进阶参考 |
|--------|----------|----------|
| 字符串/十六进制搜索 | 小试牛刀 | [[ida-pro-tips-plugins-python#flirt-签名生成与符号恢复\|IDA 字符串窗口与签名匹配]] |
| IDA 伪代码数据流跟踪 | 小试牛刀、有、意思、无法自拔 | 练习「变量重命名 + 类型标注 + 跳转定义」三步走 |
| 动态调试定位闪退点 | 有、意思 | OllyDbg/x64dbg 断点技巧、IDA Debugger |
| 编码算法识别 | 有、意思 (Base64) | 常见编码特征：Base64 索引表、XOR 密钥重复、RC4 S 盒初始化 |
| Python 快速原型验证 | 有、意思、无法自拔 | `pwntools`、`capstone`、`keystone` 集成脚本化分析 |
| Android 静态逆向 | CrackMe | `jadx`、`apktool`、`frida` 动态 Hook |
| 64 位 ELF 分析 | 无法自拔 | IDA 64-bit 模式、System V AMD64 ABI 调用约定 |
| C++ STL 逆向 | 无法自拔 | 识别 `basic_string`、`vector`、`map` 常见成员函数模式 |
| 位运算逆向与等价简化 | 无法自拔 | 真值表法、代数简化、SMT 求解器 |

---

## 交叉引用与延伸阅读

- [[reverse-engineering-beginner-learning-path]] — 逆向工程入门学习路线与资源推荐
- [[ida-pro-tips-plugins-python]] — IDA Pro 进阶技巧：FLIRT 签名、Findcrypt-Yara、Keypatch、IDAPython 环境配置
- [[crypto-basics-xor-stream-cipher-tutorial]] — 异或加密原理与 Two-Time-Pad 攻击，对理解位运算逆向有帮助
- [[rop-linux-x86-beginner-tutorial]] — Linux x86 ROP 入门，理解栈帧与调用约定，辅助分析 ELF 程序控制流

---

## 附录：原文来源

> 文章来源：0w1Club 微信公众号《题解 | RE》  
> 原文链接：<http://mp.weixin.qq.com/s?__biz=MzUzMzEwMDk3Mg==&mid=2247484036&idx=2&sn=dbd171217ce44d2a4dfd2c4964c241f1>  
> 发布时间：约 2019 年萌新培养系列期间

## 来源

- [0w1网络安全俱乐部-201707-201903_03](../sources/0w1网络安全俱乐部-201707-201903_03.md)
