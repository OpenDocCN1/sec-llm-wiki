---
title: 2022 CICV 智能网联汽车漏洞挖掘赛 Writeup：扩展维吉尼亚密码与 66 层嵌套 ZIP 取证深度复盘
description: 记录 2022 智能网联汽车漏洞挖掘赛（CICV）线上赛两道高价值题目的完整解题过程：扩展维吉尼亚密码（自定义码表、IC 推测密钥长度、Quadgram
  统计迭代深化搜索密钥）与 66 层套娃 ZIP 高压缩包取证（自动化解压清理脚本、RLE/字典/定长编码原理复盘）。同时涵盖 UART 协议波形分析、USB HID
  流量取证、蓝牙 SMP Legacy Pairing 解密等车联网安全核心技术实战。
category: program-analysis
tags:
- CICV
- '2022'
- 1024安全团队
- Crypto
- Forensics
- Vigenere Cipher
- Extended Vigenere
- Index of Coincidence
- Quadgram Statistics
- Iterative Deepening Search
- Nested ZIP
- High Compression Ratio
- RLE
- Run-Length Encoding
- Dictionary Compression
- Fixed-Length Encoding
- UART Protocol
- PulseView
- USB HID
- Keyboard/Mouse Report
- tshark
- Morse Code
- Bluetooth LE
- SMP Legacy Pairing
- crackle
- BLUETOOTH_LE_LL
- Python Automation
- Automotive Security
- IoT Security
- Hardware Security
date: 2022-08-01
updated: '2026-11-15'
---
# 2022 CICV 智能网联汽车漏洞挖掘赛 Writeup：扩展维吉尼亚密码与 66 层嵌套 ZIP 取证深度复盘

> 原文来源：1024安全团队微信公众号《2022智能网联汽车漏洞挖掘赛 WP by 1024SEC》
> 赛事背景：2022 智能网联汽车漏洞挖掘赛线上赛，1024安全团队参赛复盘，涵盖协议分析、流量取证、密码学破解、压缩包嵌套自动化等车联网/物联网安全核心技术。

---

## 赛题概览

本次线上赛共包含 5 道题目，涵盖 **UART 协议波形分析**、**USB HID 键盘鼠标流量取证**、**扩展维吉尼亚密码**、**蓝牙 LE SMP Legacy Pairing 流量解密**、**66 层嵌套 ZIP 高压缩包自动化解包** 五大方向。其中 **扩展维吉尼亚密码** 与 **66 层套娃 ZIP** 为高价值题目，分别考察古典密码现代统计破解与极限压缩原理逆向分析能力。

---

## 签到题 2：UART 协议波形反转与 PulseView 解码

### UART 帧格式速记
- **起始位**：1 位逻辑 0（低电平）
- **数据位**：5~8 位，低位先行（常见 8 位）
- **校验位**：奇/偶校验，可选
- **停止位**：1/1.5/2 位逻辑 1（高电平）
- **空闲位**：高电平

### 实战流程
1. 附件为逻辑分析仪导出格式（`.sr`），使用 **PulseView** 导入。
2. 发现空闲位持续为低电平，**判断信号被反转**。
3. 在 PulseView 中对通道 `ThanOSX.0` 执行 **Invert（反转）** 操作。
4. 添加 **UART 协议解码器**，波特率自动/手动匹配，切换至二进制/ASCII 视图。
5. 去重后直接得到 Flag。

> 🔗 交叉引用：[[automotive-protocol-analysis-uart-ble#1-uart-协议波形反转识别与-pulseview-解码实操]] 记录了同款工具链在车联网赛题中的完整操作步骤与波形截图。

---

## 我给车接了个外设打游戏：USB HID 流量取证全链路

### 核心描述符与报告格式
| 设备类型 | bInterfaceProtocol | 数据包长度 | 关键字段 |
|----------|-------------------|------------|----------|
| Keyboard | 1 (Keyboard)      | 8 字节     | 第 3 字节为 Key Code（修饰键在 Byte 0） |
| Mouse    | 2 (Mouse)         | 4 字节     | Byte 0: 按键状态；Byte 1/2: 有符号位移 (X/Y) |

### 流量提取与解析自动化
```bash
# 仅提取键盘流量 (usb.data_len == 8)
tshark -r capture.pcap -T fields -e usb.capdata 'usb.data_len == 8' > usb.dat
```
- **小键盘映射表补全**：标准 HID Usage Table 缺少 Keypad (0x54~0x63)，需手工补充 `/` `*` `-` `+` `1`~`9` `0` `.` 等映射。
- **DEL 键处理**：遇到 `0x2A` (DELETE) 时回退删除前一个字符。
- **摩斯码二次解码**：提取明文为 `.... . .-.. .-.. --- / .-- --- .-. .-.. -..` 等点划序列，转换得 Flag。

> 🔗 交叉引用：[[usb-hid-traffic-forensics]] 系统沉淀了键盘/鼠标报告描述符解析、小键盘映射表修复、DEL 键处理、摩斯码解密、扩展维吉尼亚破解脚本、66 层 ZIP 自动化解包及 RLE 编码实现的完整工具链。

### 关键 Python 脚本片段（键盘流量还原）
```python
normalKeys = {"54": "/", "55": "*", "56": "-", "57": "+",
              "59": "1", "5a": "2", "5b": "3", "5c": "4", "5d": "5",
              "5e": "6", "5f": "7", "60": "8", "61": "9", "62": "0", "63": "."}
# ... 处理 Shift、DEL(0x2a)、回退逻辑 ...
```

---

## 扩展维吉尼亚密码：自定义码表 + IC 选长 + Quadgram 迭代深化搜索

### 题目特征
- **码表扩展**：`abcdefghijklmnopqrstuvwxyz0123456789,.!{}"` (36 字符)
- **密文较短**：传统卡方统计失效，需引入更高阶语言模型评分。

### 密钥长度推测：重合指数 (IC) 法
假设密钥长度 `k`，将密文按模 `k` 分为 `k` 组子序列，计算各组 IC 平均值。英文文本 IC ≈ 0.065，随机文本 ≈ 0.038。  
实测 `k=7` 时 IC 平均值显著峰值，**确定密钥长度为 7**。

### 密钥逐位搜索：Quadgram (四元组) 统计 + Beam Search
传统逐位卡方统计因密文短、码表大而不可靠。采用 **Quadgram 负对数似然** 作为评分函数，配合 **迭代深化 Beam Search**：

1. **初始化**：枚举前 3 位密钥 (26³ ≈ 1.7 万)，保留 Top-N (N=100) 候选。
2. **迭代扩展**：对当前最佳候选，逐位追加 1 个字符 (26 选 1)，重新评分全文解密片段，再保留 Top-N。
3. **评分窗口**：第 `i` 轮仅评分已确定的前 `i+3` 位对应的密文列，避免未破解区域干扰。
4. **终止**：搜至第 7 位，输出最优密钥 `welcometocvvd`。

> 核心优势：将搜索空间从 26⁷ 压缩至 26×7×N，兼顾全局最优与计算可行性。

### 完整破解脚本架构
```python
# 依赖 quadgrams.txt (四元组频率表)
qgram = ngram_score('quadgrams.txt')
tgram = ngram_score('trigrams.txt')

Alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789,.!{}"'
Alphabet_base = 'abcdefghijklmnopqrstuvwxyz'  # 密钥仅取字母

class OptativeStore:  # 固定长度优先队列 (Max-Heap 变体)
    ...

def ProcessTriGram(KLEN):  # 前 3 位暴力 + TriGram 评分
    ...

def SolveVirginia(KLEN):   # 迭代深化：逐位扩展 + Quadgram 评分
    ...

# 主循环尝试 KLEN 3~19，自动输出最优密钥与明文
```
**解密结果**：Key=`welcometocvvd` → Flag=`flag{...}`

### 技术要点总结
| 环节 | 传统方法 | 本题改进 |
|------|----------|----------|
| 码表 | 26 字母 | 36 字符 (含数字符号) |
| 选长 | IC / 卡方 | IC 峰值定性 |
| 破解 | 逐位卡方 | Quadgram + Beam Search 迭代深化 |
| 评分 | 单字频率 | 四元组语言模型 (更鲁棒) |

---

## 蓝牙钥匙的春天：BLE SMP Legacy Pairing 流量解密与协议复盘

### 工具链适配：crackle + BLUETOOTH_LE_LL
- 官方 `crackle` 不支持 `BLUETOOTH_LE_LL` 链路层封装。
- 采用社区修复版：`git clone https://github.com/mikeryan/crackle.git` → 手动应用 Issue #45 补丁 → `make install`。
- 解密命令：`crackle -i ble.pcap -o decrypted.pcap`

### 解密前提三件套
1. 完整配对过程捕获 (Pairing Request/Response, Public Key, Confirm, Random, Encrypt Info 等)
2. 使用 **链路层加密** (非应用层自定义加密)
3. **Legacy Pairing (Just Works / Passkey Entry)**，非 LE Secure Connections (ECDH)

### 双重 Hex 解码提取 Flag
解密后流量中出现 4 组特征值，经 **两次 Hex→ASCII** 解码并拼接得到 Flag。

### SMP 配对协议关键字段速查
| 字段 | 含义 | 本题数值 |
|------|------|----------|
| IO Capability | 输入输出能力 | Initiator: Keyboard+Display (0x01), Responder: DisplayOnly (0x02) |
| OOB | 带外认证支持 | 均 0 |
| AuthReq | MITM/Bonding/SC 标志 | MITM=0, SC=0 → Legacy Just Works |
| Pairing Method | 由 IO+OOB+AuthReq 决定 | **Just Works** (无 MITM 保护，可被动解密) |

> 🔗 交叉引用：[[automotive-protocol-analysis-uart-ble#2-bluetooth-le-smp-legacy-pairing-配对流量的-crackle-工具适配-blutooth_le_ll-与双重-hex-解码取-flag-全流程]] 详细记录了 crackle 编译修补、双重 Hex 解码脚本、Wireshark 过滤器等实操细节。

---

## Big 升级包：66 层嵌套 ZIP 自动化解包与高压缩原理逆向分析

### 题目结构
- `Flag.zip` (4 位数字密码 `cvvd`) → 解压得 `666666/` 目录
- 目录下 6 个压缩包 `66-0.zip` ~ `66-5.zip`，**每个解压出 7 个下一层包** (如 `65-0.zip`~`65-6.zip`)，层层递减至 `00-*.zip`，共 **66 层**。
- 最终产出 `flag` 文件 (1 GB，全 `6` 字符 + 一行 Flag)。

### 自动化解压 + 同步清理脚本 (Python + unzip/rm)
```python
import os, time
i = 64  # 从 66-*.zip 解压后变为 65-*.zip，故起始 64
while i >= 0:
    # 解压当前层任意一个包 (均含相同 7 个下层包)
    os.system(f"unzip -o {i}-0.zip")
    # 清理当前层 7 个包
    for j in range(7):
        os.system(f"rm -f {i}-{j}.zip")
    i -= 1
    time.sleep(0.05)
```
- **关键点**：每层只需解压 1 个包即可获得下一层完整 7 个包，避免重复解压。
- **同步删除** 防止磁盘爆炸 (66 层 × 7 包 = 462 个中间文件)。

### Flag 提取
```bash
strings flag | grep -E "flag\{.*\}"  # 或 grep -a -o 'flag{.*}' flag
```

### 高压缩比原理逆向复盘：从 30 KB 到 1 GB
最终 `flag` 文件本质为 **极长重复字符串** (`666666...`)，极适合 **游程编码 (RLE)** 压缩。

| 算法 | 原理 | 本题适用性 |
|------|------|------------|
| **RLE (Run-Length Encoding)** | 连续相同字符 → `计数+字符` (如 `12W1B`) | ⭐⭐⭐ 核心算法，`6` 重复 10⁹ 次仅需 `10000000006` |
| **字典压缩 (LZ77/LZW)** | 高频子串建字典 → 索引替换 | 适用于重复模式块 (如 `666666` 视为一个词) |
| **定长编码 (Fixed-Length Coding)** | 固定位宽编码 (如 4 bits 存十六进制 0-F) | 辅助压缩字典索引或 RLE 计数值 |

#### RLE 编码演示 (Python)
```python
def encode(s):
    encoding = ""
    i = 0
    while i < len(s):
        count = 1
        while i + 1 < len(s) and s[i] == s[i + 1]:
            count += 1
            i += 1
        encoding += str(count) + s[i]
        i += 1
    return encoding

# '6'*24 -> '246'
print(encode('6'*24))  # 输出: 246
```
**压缩链路推测**：原始 `6`×10⁹ → RLE → `10000000006` (11 字节) → 字典/定长二次压缩 → 最终 30 KB ZIP。

---

## 附录：核心脚本汇总

| 脚本用途 | 关键技术点 | 文件名建议 |
|----------|------------|------------|
| UART 波形自动化解码 | PulseView CLI / sigrok-cli | `uart_decode.py` |
| USB HID 键盘流量还原 | tshark 提取 + 小键盘映射 + DEL 处理 + 摩斯解码 | `usb_hid_forensics.py` |
| 扩展维吉尼亚破解 | IC 选长 + Quadgram Beam Search | `ext_vigenere_solver.py` |
| BLE SMP 解密封装 | crackle 补丁编译 + 双重 Hex 解码 | `ble_smp_decrypt.sh` |
| 66 层 ZIP 自动化解包清理 | 层级变量拼接 + unzip/rm 管道 | `unzip_66_layers.py` |
| RLE 编码/解码验证 | 线性扫描计数 | `rle_codec.py` |

---

## 知识图谱交叉引用速查

| 技术域 | 相关知识库页面 | 核心价值 |
|--------|----------------|----------|
| 车联网协议分析 | [[automotive-protocol-analysis-uart-ble]] | UART/PulseView、BLE/crackle 实战全流程 |
| USB HID 取证 | [[usb-hid-traffic-forensics]] | 键盘/鼠标报告描述符、小键盘映射、摩斯码、维吉尼亚破解、RLE 编码完整工具链 |
| 密码学统计破解 | [[crypto-basics-xor-stream-cipher-tutorial]]、[[hec-cup-2021-crypto-writeup]] | IC/卡方/Quadgram 统计方法对比与工程化 |
| 压缩包取证与高压缩原理 | (本页新增) | RLE/字典/定长编码原理逆向分析、自动化解包工程化 |
| 蓝牙安全协议 | [[ble-packet-capture-comparison]]、[[nrf-sniffer-ble-setup-guide]] | 抓包硬件选型、Link Layer 封装差异、SMP 配对细节 |

---

## 结语与防御启示

1. **协议层可见性**：UART/USB/BLE 等物理/链路层流量若无加密或加密脆弱，极易被取证还原，**车载外设接口需强制加密与完整性校验**。
2. **古典密码现代化破解**：短密文、大码表场景下，**高阶语言模型 (Quadgram/5-gram) + 启发式搜索 (Beam/SA/GA)** 远优于单字频率统计。
3. **压缩炸弹风险**：嵌套高压缩包可构成 **解压炸弹**，解压引擎需限制 **最大层数、解压倍率、临时空间配额**。
4. **蓝牙 Legacy Pairing 淘汰**：Just Works 无 MITM 保护，**强制要求 LE Secure Connections (ECDH + 数字比对/密钥输入)** 并禁用 Legacy 模式。

> 本页面基于 1024安全团队赛后复盘文章整理，旨在将零散 Writeup 沉淀为可复用、可交叉引用的结构化知识资产，服务于车联网/物联网安全、CTF 密码取证、自动化取证工程化等方向的学习与实战。

--- 

**标签**：`CICV` `2022` `1024安全团队` `Crypto` `Forensics` `Vigenere` `Quadgram` `Beam Search` `Nested ZIP` `RLE` `UART` `PulseView` `USB HID` `Bluetooth LE` `SMP` `crackle` `Automotive Security` `IoT Security` `Python Automation`

## 来源

- [1024安全团队-202204-202209_6](../sources/1024安全团队-202204-202209_6.md)
