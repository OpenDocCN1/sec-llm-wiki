---
title: 0W1 Club CTF 密码学方向题解：easyRSA 大数分解解密与 T9 九键短信解码
description: 记录 0W1 网络安全俱乐部微信归档中 CRYPTO 方向两道题目的完整解题过程：easyRSA 利用大数分解数据库分解模数 n 获取 p、q，结合
  Python gmpy2 库或手工计算完成 RSA 解密；未知的短信（T9）利用手机九键 T9 编码规则还原明文。涵盖 Factordb 在线分解工具、RSA
  密钥生成原理、gmpy2 模逆计算、十六进制转字符串、T9 九键映射表等核心技术点。
category: ai-security
tags:
- 0W1Club
- CTF
- Crypto
- Writeup
- RSA
- 大数分解
- Factordb
- gmpy2
- T9九键
- 短信解码
- 微信归档
date: '2021-01-01'
updated: '2026-11-13'
---
## 概述

本页面整理自 0W1 网络安全俱乐部微信公众号归档文章「题解 | CRYPTO」，详细记录两道密码学方向 CTF 题目的完整解题思路与工具链：

1. **easyRSA** —— 利用大数分解数据库分解 RSA 模数 `n`，获取素因子 `p`、`q`，进而计算私钥 `d` 完成解密。
2. **未知的短信** —— 识别为手机九键 T9 编码，按「键位序号、字母序号」映射还原 Flag。

文章隶属于 [[0w1club-wechat-archive-201908-202207]] 归档周期，与同期发布的 [[0w1club-ctf-web-writeup-hash-extension-rsa]]、[[0w1club-ctf-misc-writeup-steganography-traffic-analysis]] 共同构成 0W1 Club CTF Writeup 系列。另可参考 [[mtctf-2021-crypto-writeup]] 中的 RSA Padding Oracle 与 One-Time Pad 攻击思路对比学习。

---

## 题目一：easyRSA

### 核心思路

- **已知条件**：给出 RSA 公钥参数 `(n, e)` 及密文 `c`。
- **突破口**：模数 `n` 位数较短（或为弱素数），可直接通过在线大数分解数据库分解出 `p`、`q`。
- **后续流程**：
  1. 计算欧拉函数 `φ(n) = (p-1)*(q-1)`。
  2. 计算私钥指数 `d = e^{-1} mod φ(n)`。
  3. 解密 `m = c^d mod n`。
  4. 将十六进制明文 `m` 转为 ASCII 字符串得到 Flag。

### 关键工具与资源

| 步骤 | 工具 / 库 | 说明 |
|------|-----------|------|
| 大数分解 | [Factordb](http://factordb.com/index.php?query=) | 在线数据库，输入 `n` 即可返回 `p`、`q` |
| 模逆计算 | Python `gmpy2.invert(e, phi)` | 推荐 Python 3 + gmpy2；原文提到 Python 2 下 `gmpy` 也可用 |
| 十六进制转字符串 | [bejson 在线转换](http://www.bejson.com/convert/ox2str/) | 或用 Python `bytes.fromhex(hex(m)[2:]).decode()` |
| 手工验证 | 纸笔 / 脚本 | 原文附带「齐智」提供的手算 RSA 示意图，便于理解原理 |

### 解题脚本示例（Python 3 + gmpy2）

```python
import gmpy2

# 已知参数（示例值，需替换为题目实值）
n = 0x...  # 模数
e = 0x10001  # 常见公钥指数
c = 0x...  # 密文

# 1. 从 Factordb 获取 p, q
p = 0x...
q = 0x...

# 2. 计算 phi 与私钥 d
phi = (p - 1) * (q - 1)
d = gmpy2.invert(e, phi)

# 3. 解密
m = pow(c, d, n)

# 4. 十六进制转字符串
flag = bytes.fromhex(hex(m)[2:]).decode()
print(flag)
```

> **提示**：若 `n` 无法在 Factordb 秒出，可尝试 `yafu`、`msieve` 等本地分解工具，或结合 [[mtctf-2021-crypto-writeup]] 中的 Padding Oracle 攻击思路寻找其他突破口。

---

## 题目二：未知的短信（T9 九键解码）

### 核心思路

- **题面提示**：「手机上的短信」「九键」。
- **编码规则**：每组数字 `(a, b)` 表示「第 `a` 个按键、该按键上的第 `b` 个字母」。
- **T9 九键映射表**：

| 按键 | 字母序列 |
|------|----------|
| 1    | 标点/功能键（通常不用） |
| 2    | A B C |
| 3    | D E F |
| 4    | G H I |
| 5    | J K L |
| 6    | M N O |
| 7    | P Q R S |
| 8    | T U V |
| 9    | W X Y Z |
| 0    | 空格 |

- **解码示例**：`(2,1)->A`、`(3,2)->E`、`(6,3)->O` …… 组合即得明文。

### 解题脚本示例（Python）

```python
t9_map = {
    '2': 'ABC', '3': 'DEF', '4': 'GHI', '5': 'JKL',
    '6': 'MNO', '7': 'PQRS', '8': 'TUV', '9': 'WXYZ'
}

def decode_t9(pairs):
    """pairs: 列表，元素为 (key_index, letter_index)，均从 1 开始"""
    res = []
    for k, idx in pairs:
        letters = t9_map.get(str(k), '')
        if 1 <= idx <= len(letters):
            res.append(letters[idx - 1])
    return ''.join(res)

# 题目给定的数对序列（示例）
pairs = [(2,1), (3,2), (6,3), ...]
print(decode_t9(pairs))  # 输出 Flag
```

> **扩展**：T9 编码在早期功能机短信、九键输入法中广泛使用；CTF 中常以「数对序列」「按键次数」「音频按键音」等形式出现，掌握映射表与快速脚本化解码是基本功。

---

## 交叉引用与延伸阅读

- [[0w1club-wechat-archive-201908-202207]] —— 0W1 Club 微信归档总索引，含更多 CTF Writeup、招新宣传、萌新培养系列。
- [[0w1club-ctf-web-writeup-hash-extension-rsa]] —— 同期 Web 方向 Writeup，含 RSA 解密、哈希长度扩展攻击、PHP 弱类型比较等。
- [[0w1club-ctf-misc-writeup-steganography-traffic-analysis]] —— 同期 MISC 方向 Writeup，涵盖 JPEG 隐写、流量分析、ZIP 伪加密、PNG CRC 修复、WiFi 定位等。
- [[mtctf-2021-crypto-writeup]] —— MTCTF 2021 Crypto 题解，RSA Padding Oracle 攻击、One-Time Pad 语义还原，适合进阶对比学习。
- [[burpsuite-basics-tutorial]] —— Burp Suite 入门教程，CTF Web 题常用抓包改包工具。
- [[java-deserialization-fundamentals]] / [[spring-boot-devtools-deserialization-rce]] —— Java 反序列化基础与实战链条，拓展 Web+Crypto 综合利用视野。

---

## 小结

| 题目 | 核心知识点 | 关键工具 | 难度 |
|------|------------|----------|------|
| easyRSA | RSA 原理、大数分解、模逆运算、十六进制编解码 | Factordb、gmpy2、Python | 入门 |
| 未知的短信 | T9 九键编码映射、脚本化批量解码 | Python 字典映射 | 入门 |

两题均属基础密码学/编码题，**适合 CTF 初学者练手**，同时也展示了「善用在线数据库 + 轻量脚本」的实战解题范式。建议初学者在复现时：

1. 亲手操作 Factordb 分解、`gmpy2.invert` 计算、`bytes.fromhex` 转码全流程。
2. 手写 T9 映射表并完成解码脚本，体会「编码即加密、映射即密钥」的思想。
3. 尝试将 easyRSA 的参数改大、或将 T9 改为多次按键次数编码（如 `222 -> C`），自行生成变体题目练习。

---

> **来源**：0W1 网络安全俱乐部微信公众号归档文章「题解 | CRYPTO」（原文链接已失效，内容基于归档快照整理）。  
> **维护者**：数字知识库策展人 · 归档于 2021 年上半年微信推文合集。

## 来源

- [0w1网络安全俱乐部-201707-201903_06](../sources/0w1网络安全俱乐部-201707-201903_06.md)
