---
title: 密码学基础：异或加密原理、二次加密攻击与流密码入门
description: 系统梳理异或加密核心原理、Two-Time-Pad 攻击实战破解流程（以 de1ctf 2019 xor 题为例）、流密码基本概念及常见算法，适合
  CTF 入门与密码学基础巩固。
category: ai-security
tags:
- 密码学
- 异或加密
- Two-Time-Pad
- 流密码
- CTF
- de1ctf
- 密钥恢复
- RC4
date: '2019-11-20'
updated: '2026-11-13'
---

## 异或运算基础

### 真值表与核心性质

异或（XOR，记作 `⊕`）是基于二进制 0/1 的逻辑运算：

| input₁ | input₂ | output |
|--------|--------|--------|
| 0      | 0      | 0      |
| 0      | 1      | 1      |
| 1      | 0      | 1      |
| 1      | 1      | 0      |

**关键性质**：

- **互反性（自逆性）**：`A ⊕ B ⊕ B = A`，即加密与解密操作完全相同。
- **模 2 加法**：数学本质是不进位的二进制加法。
- **字符空间**：判断密钥字符可行性的依据，通常为可打印 ASCII（0x20–0x7E）或特定字符集（如 `0-9a-fA-F_{}`）。

## 破解 M ⊕ K = C：Two-Time-Pad 攻击实战

### 攻击原理

当密钥 `K` 短于明文 `M` 时，通常以循环方式扩展为 `exp-K`。若同一密钥加密了多段明文（或已知部分明文），即可利用 **Two-Time-Pad** 攻击：

```
C₁ = M₁ ⊕ K
C₂ = M₂ ⊕ K
→ C₁ ⊕ C₂ = M₁ ⊕ M₂
```

若 `M₁` 部分已知，可直接推导 `K` 对应片段；若均未知，可通过字符空间约束与词频统计逐字节爆破。

### 实战复现：de1ctf 2019 `xor` 题目

#### 题目加密逻辑

```python
from itertools import cycle
from data import flag, plain

key = flag.strip("de1ctf{").strip("}")      # 长度 < 38
assert len(key) < 38
salt = "WeAreDe1taTeam"

ki = cycle(key)
si = cycle(salt)

cipher = ''.join([
    hex(ord(p) ^ ord(next(ki)) ^ ord(next(si)))[2:].zfill(2)
    for p in plain
])
print(cipher)
```

- 密钥 `key` 即 flag 去格式化后的核心部分。
- 引入固定 `salt` 以增加干扰，但本质仍是 `C = P ⊕ K ⊕ S`，其中 `S` 已知。
- `plain` 为已知长文本（约 600 字节），可视为**单次加密多块明文**，满足 Two-Time-Pad 条件。

#### 密钥恢复脚本（WriteUp by 天枢）

```python
import string

length = 30                              # 经尝试确定的密钥长度
flag_dic   = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_'
plain_dic  = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ,. '

cipher = bytes.fromhex('1e5d4c055104471c6f234f5501555b5a014e5d001c2a54470555064c443e235b4c0e590356542a130a4242335a47551a590a136f1d5d4d440b0956773613180b5f184015210e4f541c075a47064e5f001e2a4f711844430c473e2413011a100556153d1e4f45061441151901470a196f035b0c4443185b322e130806431d5a072a46385901555c5b550a541c1a2600564d5f054c453e32444c0a434d43182a0b1c540a55415a550a5e1b0f613a5c1f10021e56773a5a0206100852063c4a18581a1d15411d17111b052113460850104c472239564c0755015a13271e0a55553b5a47551a54010e2a06130b5506005a393013180c100f52072a4a1b5e1b165d50064e411d0521111f235f114c47362447094f10035c066f19025402191915110b4206182a544702100109133e394505175509671b6f0b01484e06505b061b50034a2911521e44431b5a233f13180b5508131523050154403740415503484f0c2602564d470a18407b775d031110004a54290319544e06505b060b424f092e1a770443101952333213030d554d551b2006064206555d50141c454f0c3d1b5e4d43061e453e39544c17580856581802001102105443101d111a043c03521455074c473f3213000a5b085d113c194f5e08555415180f5f433e270d131d420c1957773f560d11440d40543c060e470b55545b114e470e193c155f4d47110947343f13180c100f565a000403484e184c15050250081f2a54470545104c5536251325435302461a3b4a02484e12545c1b4265070b3b5440055543185b36231301025b084054220f4f42071b1554020f430b196f19564d4002055d79')

list_flag = []
for i in range(length):
    list_i = []
    for flag_byte in flag_dic:
        count = 0
        for j in range(i, len(cipher), length):
            # 还原明文字节：P = C ⊕ K ⊕ S → 此处 S 已在 cipher 生成时异或，故直接 C ⊕ K
            if chr(cipher[j] ^ ord(flag_byte)) in plain_dic:
                count += 1
        # 阈值：期望每个位置约 600/length 次命中
        if count >= len(cipher) // length - 1:
            list_i.append(flag_byte)
    list_flag.append(list_i)

print(list_flag)
```

**核心步骤解析**：

1. **确定密钥长度**：尝试 1–38，观察各字节候选集收敛情况，`length=30` 时每位仅剩 1–2 个候选。
2. **字符空间过滤**：`flag_dic` 限定 flag 字符集；`plain_dic` 限定明文字符集（题目 `plain` 为英文句子）。
3. **统计投票**：同一密钥位置加密的所有密文字节，解密后落入 `plain_dic` 的次数达标者视为有效候选。
4. **人工拼接**：根据候选集拼凑可读 flag，如 `de1ctf{...}`。

#### 自动化工具推荐

- **xor-analyze**：<https://github.com/ThomasHabets/xor-analyze>  
  支持自动密钥长度检测、字符空间推断、已知明文攻击等，适合快速原型验证。

## 流密码基础

### 从 OTP 到流密码

| 概念 | 说明 |
|------|------|
| **OTP (One-Time Pad)** | 密钥长度 = 明文长度、真随机、仅使用一次 → **信息论绝对安全** |
| **现实痛点** | 密钥分发/存储成本极高，工程上不可行 |
| **流密码** | 用短密钥 + 确定性算法生成**伪随机密钥流**，再与明文异或 |

### 常见流密码算法

- **RC4**：曾广泛用于 TLS、WEP，因初始化偏差导致密钥恢复攻击（如 `Fluhrer-Mantin-Shamir`），现已弃用。
- **ChaCha20**：现代标准，配合 Poly1305 认证（`ChaCha20-Poly1305`），用于 TLS 1.3、WireGuard 等。
- **AES-CTR / AES-GCM**：分组密码工作模式构建的流式加密，硬件加速友好。
- **WPA-PSK (RC4-based)**：早期 Wi-Fi 加密，因弱 IV 导致破解，已被 WPA2/3 取代。

> 💡 学习建议：先理解 **线性反馈移位寄存器 (LFSR)** 与 **非线性组合器** 的基本构造，再阅读现代算法规范（RFC 8439 for ChaCha20）。

## 交叉引用与延伸阅读

- [[mtctf-2021-crypto-writeup]] — 同类 CTF 密码学实战，涵盖 **One-Time Pad 部分已知明文攻击** 与 RSA Padding Oracle。
- [[ctftime-writeup-digest-20210325]] — 2021 年 3 月多场 CTF Writeup 汇总，含 Crypto 方向题解。
- [[daily-security-digest-20191120]] — 原文发布当期每日安全看点，包含更多入门资源链接。

## 推荐书目与文献

1. **《应用密码学——协议、算法与 C 源程序》** — Bruce Schneier  
   经典百科全书式参考，涵盖流密码、分组密码、协议设计全谱系。
2. **《深入浅出密码学——常用加密技术原理与应用》** — 适合工程视角快速建立直觉。
3. **A natural language approach to automated cryptanalysis of two-time pads** — Mason et al., CCS 2006  
   <https://www.cs.jhu.edu/~jason/papers/mason+al.ccs06.pdf>  
   利用自然语言统计特性自动化破解 Two-Time-Pad，理论与工程结合的典范。

---

> 页面来源：0th3rs 安全团队微信公众号 2019-11-20 发布的《【萌新培养】第四周：密码学入门》整理而成。  
> 如需系统性复现 de1ctf 2019 xor 全过程，建议结合本页脚本在本地环境运行调试。

## 来源

- [0w1Club-201908-202207_16](../sources/0w1Club-201908-202207_16.md)
