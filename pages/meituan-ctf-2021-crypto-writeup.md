---
title: 2021美团CTF密码学方向Writeup：Symbol与hamburgerRSA完整解题过程
description: 记录2021美团CTF密码学方向两道题目完整解题过程：Symbol LaTeX符号解码题与hamburgerRSA特殊拼接素数攻击题，包含LaTeX字符表查找、RSA特殊结构n与N的前后位数一致性分析、Sage脚本爆破恢复p/q、私钥计算解密全流程。
category: program-analysis
tags:
- CTF
- 密码学
- 美团CTF
- '2021'
- Symbol
- LaTeX
- hamburgerRSA
- RSA攻击
- 素数拼接
- Sage
- Writeup
- 0w1Club
date: 2021-01-01
updated: '2026-11-15'
---

## 概述

本页面整理自 0w1Club 微信归档文章，记录 **2021美团CTF** 密码学方向两道题目的完整解题过程：

- **Symbol**：LaTeX 数学符号解码题，通过查找 LaTeX 字符表还原 Flag 格式字符串
- **hamburgerRSA**：特殊结构 RSA 题目，利用拼接素数生成的模数 `n` 与普通模数 `N = p*q` 前后位数一致的特性进行爆破恢复私钥

两题均为基础密码学题目，适合 CTF 入门练习与密码学基本功巩固。相关基础密码学训练可参考 [[0w1club-week11-crypto-re-pwn-training]]、[[crypto-basics-xor-stream-cipher-tutorial]]。

---

## Symbol：LaTeX 符号解码

### 题目描述

题目给出一串奇特符号：

```
$$  \flat\lambda\alpha\gamma\{\forall\uplus\nu\_\Lambda\alpha\Tau\epsilon\Xi\_ M \approx\triangleleft\hbar\}$$
```

### 解题思路

1. **识别符号来源**：符号形似 LaTeX 数学公式字符，搜索关键字 `LaTeX` 确认
2. **查找 LaTeX 字符表**：对照 LaTeX 数学符号对照表逐个还原
3. **提取首字母**：每个 LaTeX 命令的首字母拼接得到 Flag 明文

### 符号对照表

| LaTeX 命令 | 渲染符号 | 首字母 |
|------------|----------|--------|
| `\flat`    | ♭        | f      |
| `\lambda`  | λ        | u      |
| `\alpha`   | α        | n      |
| `\gamma`   | γ        | _      |
| `\forall`  | ∀        | L      |
| `\uplus`   | ⊎        | a      |
| `\nu`      | ν        | T      |
| `\_`       | _        | e      |
| `\Lambda`  | Λ        | X      |
| `\alpha`   | α        | _      |
| `\Tau`     | Τ        | M      |
| `\epsilon` | ε        |        |
| `\Xi`      | Ξ        |        |
| `\approx`  | ≈        |        |
| `\triangleleft` | ◁   |        |
| `\hbar`    | ℏ        |        |

### Flag 还原

拼接首字母得到：`fun_LaTeX_Math`

题目要求 MD5 加密后包裹 `flag{}`：

```
flag{639220f4b70bb4a3ac80d95efcfb2353}
```

---

## hamburgerRSA：特殊拼接素数攻击

### 题目源码

```python
from Crypto.Util.number import *

flag = open('flag.txt').read()
nbit = 64
while True:
    p, q = getPrime(nbit), getPrime(nbit)
    PP = int(str(p) + str(p) + str(q) + str(q))
    QQ = int(str(q) + str(q) + str(p) + str(p))
    if isPrime(PP) and isPrime(QQ):
        break

n = PP * QQ
m = bytes_to_long(flag.encode())
c = pow(m, 65537, n)
print('n =', n)
```

### 核心观察

生成算法构造两个特殊素数：
- `PP = int(str(p) + str(p) + str(q) + str(q))`  —— p、p、q、q 拼接
- `QQ = int(str(q) + str(q) + str(p) + str(p))`  —— q、q、p、p 拼接

模数 `n = PP * QQ` 与普通模数 `N = p * q` 存在数值关联。

### 规律发现

编写测试脚本验证：

```python
from Crypto.Util.number import *
nbit = 64
while True:
    p, q = getPrime(nbit), getPrime(nbit)
    PP = int(str(p) + str(p) + str(q) + str(q))
    QQ = int(str(q) + str(q) + str(p) + str(p))
    if isPrime(PP) and isPrime(QQ):
        break
n = PP * QQ
N = p * q
print("n:{}".format(n))
print("N:{}".format(N))
```

运行多次观察发现：**`n` 的前 19 位与 `N` 的前 19 位一致，后 19 位也一致**。

### 爆破恢复 p、q

利用该特性，只需枚举中间位数即可分解 `N`，再推导 `PP`、`QQ`。

**Sage 爆破脚本**：

```python
n = 177269125756508652546242326065138402971542751112423326033880862868822164234452280738170245589798474033047460920552550018968571267978283756742722231922451193
n1 = str(n)[:19]
n2 = str(n)[-19:]
print(n1)
print(n2)
for i in range(10):
    N = int(n1 + str(i) + n2)
    result = factor(N)
    if len(result) == 2:
        print(result)
        break
```

**输出**：
```
9788542938580474429 * 18109858317913867117
```

得到 `p = 9788542938580474429`，`q = 18109858317913867117`。

### 解密 Flag

```python
from Crypto.Util.number import *
from gmpy2 import invert

n = 177269125756508652546242326065138402971542751112423326033880862868822164234452280738170245589798474033047460920552550018968571267978283756742722231922451193
c = 47718022601324543399078395957095083753201631332808949406927091589044837556469300807728484035581447960954603540348152501053100067139486887367207461593404096

p, q = 9788542938580474429, 18109858317913867117
PP = int(str(p) + str(p) + str(q) + str(q))
QQ = int(str(q) + str(q) + str(p) + str(p))

phi = (PP - 1) * (QQ - 1)
d = invert(65537, phi)
m = pow(c, d, n)
flag = long_to_bytes(m)
print(flag)
```

**输出**：
```
b'flag{f8d8bfa5-6c7f-14cb-908b-abc1e96946c6}'
```

---

## 技术要点总结

| 题目 | 核心知识点 | 关键技术 |
|------|------------|----------|
| Symbol | LaTeX 数学符号识别、编码转换 | 字符表查找、首字母提取、MD5 计算 |
| hamburgerRSA | RSA 特殊结构弱利用、整数拼接性质分析 | 前后位数一致性观测、Sage 分解整数、私钥重构 |

### 相关扩展阅读

- CTF 密码学基础训练：[[0w1club-week11-crypto-re-pwn-training]]、[[crypto-basics-xor-stream-cipher-tutorial]]
- 其他 CTF Writeup 参考：[[mtctf-2021-pwn-writeup]]（同届 MTCTF Pwn 方向）、[[gkctf-2021-web-writeup]]（GKCTF 2021 Web 方向）、[[attack-defense-world-beginner-web-writeup]]、[[buuctf-web-writeup-collection]]
- RSA 攻击技术延伸：[[lm-ntlm-hash-generation-analysis]]（哈希生成算法分析）、[[mysql-duplicate-entry-error-based-sqli]]（报错注入原理分析）

---

## 参考资料

- 原文来源：0w1Club 微信公众号归档文章《2021美团CTF Writeup部分》
- 文章链接：`http://mp.weixin.qq.com/s?__biz=MzkyNzE3NjM1Mw==&mid=2247483987&idx=1&sn=17d42879c0bb7d8ec46b8cafd734646c`
- 涉及工具：Python (Crypto.Util.number, gmpy2)、SageMath、LaTeX 符号对照表

## 来源

- [0xfafu攻防实验室-202010-202112_01](../sources/0xfafu攻防实验室-202010-202112_01.md)
