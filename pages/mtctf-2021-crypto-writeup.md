---
title: 'MTCTF 2021 Crypto Writeup: easy_RSA'
description: RSA 填充 Oracle 攻击解密 ZIP 密码，结合 One-Time Pad 部分已知明文语义逐步还原 Flag
category: ai-security
tags:
- MTCTF
- 2021
- Crypto
- RSA
- Padding Oracle
- One-Time Pad
- ZIP
- 密码学攻击
date: 2021-04-15
updated: '2026-11-12'
---
## 概述

本页面记录 MTCTF 2021 Crypto 方向 **easy_RSA** 题目的完整解题思路。题目分两阶段：首先利用 **RSA 填充 Oracle 攻击** 解密得到 ZIP 压缩包密码；解压后获得 One-Time Pad 密文，再利用 **部分已知明文语义** 逐步还原 Flag。

同期 Web 方向题解见 [[mtctf-2021-web-writeup]]。

---

## 题目流程

### 第一阶段：RSA Padding Oracle Attack → ZIP 密码

- 题目提供 RSA 加密接口及填充校验 Oracle（返回填充是否合法）。
- 利用 Bleichenbacher 攻击（或变体）逐比特恢复明文，得到 ZIP 压缩包的解压密码。
- 关键脚本（原文未展开细节，实战中常用 `python-rsa` / 自制 Oracle 交互脚本）跑出密码后解压。

### 第二阶段：One-Time Pad 部分已知明文还原 Flag

解压得到 `one_time_cipher` 文件，内容示例：

```
280316470206017f5f163a3460100b111b2c254e103715600f13,
```

- One-Time Pad（OTP）若密钥复用或明文存在冗余/格式特征，可通过 **crib dragging / 语义猜解** 还原明文。
- 参考工具/文章：[《One-Time Pad 破解工具与思路》](https://www.jianshu.com/p/a00157b981b5)。
- 结合 Flag 格式 `flag{...}`、常见字符集、上下文语义，逐字节试错还原明文。
- 最终得到 Flag：

```
flag{it_1s_P@dd1n_@nd_p@d}
```

---

## 关键技术点回顾

| 技术点 | 说明 |
|--------|------|
| **RSA Padding Oracle** | 利用解密端对 PKCS#1 v1.5 / OAEP 填充的合法性校验差异，构造 chosen-ciphertext 攻击逐步恢复明文。 |
| **ZIP 密码保护** | 很多 CTF 题将后续载荷加在受密码保护的 ZIP 内，解密密码即可进入下一阶段。 |
| **One-Time Pad 密钥复用/语义攻击** | OTP 理论上绝对安全，但密钥复用或明文有已知结构（如 Flag 格式、ASCII 可打印字符）时可通过异或性质 `C1 ⊕ C2 = M1 ⊕ M2` 及语义猜解破解。 |
| **Crib Dragging** | 针对流密码/OTP 密钥复用场景，滑动猜测常见词（crib）并观察异或结果是否为可读文本。 |

---

## 复现要点清单

1. **搭建 Oracle 交互脚本**  
   - 自动化发送构造的密文，解析服务端返回的填充合法/非法信息。
   - 实现 Bleichenbacher 步骤：区间缩减、倍数搜索、边界收敛。

2. **解压 ZIP**  
   - 用获得的密码 `unzip -P <password> archive.zip`。

3. **OTP 语义还原**  
   - 将密文转为字节数组。
   - 假设 Flag 以 `flag{` 开头，异或得到密钥流前段。
   - 尝试将密钥流应用于后续密文，观察是否产生可读字符；根据上下文修正猜测，迭代至完整 Flag。

---

## 相关页面

- [[mtctf-2021-web-writeup]] — 同届 Web 方向题解（SQLi、PHP 反序列化条件竞争、Session Upload Progress 等）
- [[jwt漏洞原理与实战利用]] — 另一类密码学相关攻击（算法混淆、密钥爆破）
- [[h2-console-jndi注入rce利用]] — 同属 CTF 实战漏洞复现系列

---

## 参考资源

- 原文公众号文章：MTCTF 2021 Writeup（含 Web/Crypto/Pwn 全方向）
- One-Time Pad 破解思路：<https://www.jianshu.com/p/a00157b981b5>
- Bleichenbacher 攻击原版论文：《Chosen Ciphertext Attacks Against Protocols Based on the RSA Encryption Standard PKCS #1》 (1998)

## 来源

- [0th3rs安全团队-201911-202204_006](../sources/0th3rs安全团队-201911-202204_006.md)
