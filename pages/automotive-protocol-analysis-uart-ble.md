---
title: 车联网协议分析实战：UART 波形反转解码与 Bluetooth LE SMP Legacy Pairing 流量解密
description: 沉淀 2022 智能网联汽车漏洞挖掘赛线上赛两大核心实战：UART 协议波形反转识别与 PulseView 解码实操、Bluetooth
  LE SMP Legacy Pairing 配对流量的 crackle 工具适配 BLUETOOTH_LE_LL 与双重 Hex 解码取 Flag 全流程。
category: program-analysis
tags:
- 车联网安全
- UART协议
- PulseView
- 波形反转
- Bluetooth LE
- SMP Legacy Pairing
- crackle
- BLUETOOTH_LE_LL
- 流量解密
- CTF实战
- 1024安全团队
date: 2022-08-15
updated: '2026-11-15'
---

## 概述

本页面沉淀自 **1024安全团队** 参加 **2022 智能网联汽车漏洞挖掘赛线上赛** 的完整 Writeup，重点结构化两大典型协议分析实战：

1. **UART 波形反转解码** —— 从逻辑分析仪导出文件（`.sr`）入手，识别空闲位异常（持续低电平），通过 PulseView 通道反转修正起始位/停止位极性，成功解析 Flag。
2. **Bluetooth LE SMP Legacy Pairing 流量解密** —— 针对 `BLUETOOTH_LE_LL` リンク层封装导致 crackle 原版无法识别的问题，对照社区 Issue 替换适配版本，完成完整配对流程捕获与 LTK 导出，进而解密应用层负载，经双重十六进制解码得到 Flag。

> 交叉引用：完整赛题复盘（含 USB HID 取证、扩展维吉尼亚密码、66 层嵌套压缩包 RLE 原理）见 [[usb-hid-traffic-forensics]]。

---

## 一、UART 协议波形反转解码实操

### UART 帧格式速查

| 字段 | 电平 | 说明 |
|------|------|------|
| 空闲位 | 高电平 (1) | 总线无数据时保持高电平 |
| 起始位 | 低电平 (0) | 1 bit，标志帧开始 |
| 数据位 | 低位在前 | 5~8 bit，常见 8 bit (1 字节) |
| 校验位 | 可选 | 奇/偶校验 |
| 停止位 | 高电平 (1) | 1/1.5/2 bit，标志帧结束 |

> 关键点：**空闲=高、起始=低、停止=高**。若采集到的波形空闲段持续为低电平，极大概率为**信号反转**（或探针接反）。

### 现场症状：PulseView 导入 `.sr` 后协议解析器无输出

- 附件重命名为 `capture.sr` 导入 PulseView。
- 观察波形：`ThanOSX.0` 通道空闲段全为 **低电平**。
- 直接添加 **UART 协议解码器**（波特率自动/手动尝试） → **无任何解码行**输出。

### 反转修正与解码步骤

1. **通道反转**  
   在 PulseView 通道列表右键 `ThanOSX.0` → **Invert**（或勾选 `Invert` 复选框）。
2. **再次添加 UART 解码器**  
   - 波特率：按题目提示或自动检测（常见 115200/9600）。  
   - 数据位：8、校验：None、停止位：1。
3. **切换到二进制/ASCII 视图**  
   解码表中即可看到连续字节流，去重后拼接为 Flag。

> 实战技巧：若波特率未知，可用 PulseView 自带 **Autobaud** 功能，或用光标测量起始位宽度 → `Baud = 1 / 起始位宽度(秒)`。

### 关键工具链

| 工具 | 用途 |
|------|------|
| **PulseView** (sigrok) | 开源逻辑分析仪上位机，支持 `.sr`/`.sr.gz`/VCD 等格式 |
| **sigrok-cli** | 命令行批量转换/解码，适合 CI 集成 |
| **Saleae Logic / DSLogic** | 硬件采集端，导出 `.sr` 供 PulseView 分析 |

---

## 二、Bluetooth LE SMP Legacy Pairing 流量解密实战

### 题目流量包特征

- 文件：`ble.pcapng` / `ble.pcap`
- Wireshark 显示存在 **SMP (Security Manager Protocol)** 帧：  
  `Pairing Request/Response` → `Pairing Confirm/Random` → `Encryption Information` → `Master/Slave Identification` → `Encrypted Data`。
- 关键现象：**Link Layer 类型为 `BLUETOOTH_LE_LL` (256)**，而非常见的 `BLUETOOTH_LE_LL_WITH_PHDR` 或原始 `BTLE`。

### crackle 原版局限性

```bash
$ crackle -i ble.pcapng -o ble_dec.pcapng
[!] Unsupported linktype 256 (BLUETOOTH_LE_LL)
```

- 官方 FAQ 明确要求：  
  1. 完整配对过程（Pairing Request → Encrypted Data）  
  2. **链路层加密**（非应用层自实现）  
  3. **Legacy Pairing**（非 LE Secure Connections）  
  4. **链路层类型需被识别**（crackle 内部硬编码 linktype 白名单）。

### 社区适配版本获取与编译

1. **定位 Issue**  
   GitHub `mikeryan/crackle#45` / `#62` 讨论 `BLUETOOTH_LE_LL` 支持。
2. **使用 Fork 版本**  
   ```bash
   git clone https://github.com/aaaaaa123456789/crackle.git  # 示例 Fork
   cd crackle && make && sudo make install
   ```
   > 亦可手动在 `src/crackle.c` 的 `linktype_is_supported()` 白名单中添加 `DLT_BLUETOOTH_LE_LL (256)` 后重新编译。

### 解密全流程

```bash
# 1. 确认链路层类型
$ tshark -r ble.pcapng -T fields -e frame.encap_type | sort -u
256   # BLUETOOTH_LE_LL

# 2. 适配版 crackle 解密
$ crackle -i ble.pcapng -o ble_dec.pcapng
[+] Found LTK: 3a5f... (16 bytes)
[+] Decrypted 12 frames

# 3. Wireshark 打开解密包，过滤 btatt 或 btl2cap
#    可见明文 ATT Write/Notification 负载，如：
#    66 6c 61 67 7b ... 7d  → "flag{...}"
```

### 双重 Hex 解码取 Flag

解密后的应用层负载呈现 **Hex 字符串形式**（ASCII 可打印字符 `0-9a-f`），需两次解码：

```python
# 提取的负载片段示例
payload_hex_str = "666c61677b3132337d"   # 第一层 Hex (ASCII)

# 第一层：Hex -> bytes
layer1 = bytes.fromhex(payload_hex_str)   # b'flag{123}'

# 第二层：若 layer1 仍为 Hex 字符串，再解一次
flag = bytes.fromhex(layer1.decode()).decode()
print(flag)  # flag{...}
```

> 原文中提取四组不同内容，分别双重解码后拼接得到完整 Flag。

### 关键协议字段速查（用于判断配对方式）

| 字段 | 位置 | 关键取值 | 含义 |
|------|------|----------|------|
| `IO Capability` | Pairing Request/Response | `0x00` DisplayOnly, `0x01` DisplayYesNo, `0x02` KeyboardOnly, `0x03` NoInputNoOutput, `0x04` KeyboardDisplay | 设备 I/O 能力 |
| `OOB Flag` | 同上 | `0x00` 不支持, `0x01` 支持 | 是否带外认证 |
| `AuthReq` | 同上 | **Bit 0**: Bonding, **Bit 2**: MITM, **Bit 3**: SC (Secure Connections) | 认证需求 |
| `SC Flag (Bit 3)` | AuthReq | `0` = **Legacy Pairing**, `1` = LE Secure Connections | **决定 crackle 能否解密** |

> 若 `SC Flag = 1`（LE Secure Connections，ECDH），crackle **无法**解密；必须为 `0`（Legacy Pairing，TK 基于 PIN/Just Works）。

---

## 三、工具与脚本速查表

### PulseView UART 批量解码 (CLI)

```bash
# 导出所有 UART 解码行为 CSV
sigrok-cli -i capture.sr -P uart:baudrate=115200 -O csv -o uart_decoded.csv
```

### crackle 关键参数

| 参数 | 说明 |
|------|------|
| `-i <in.pcap>` | 输入捕获文件 |
| `-o <out.pcap>` | 输出解密后 pcap |
| `-l <ltk>` | 直接指定 LTK (16 字节 Hex) 跳过破解 |
| `-b <bdaddr>` | 过滤特定蓝牙地址 |
| `-v` | 详细日志 |

### 双重 Hex 解码 Python 一行流

```python
# 假设已提取 payload 列表 payloads = ["666c6167...", "7b313233..."]
flag = "".join(bytes.fromhex(bytes.fromhex(p).decode()).decode() for p in payloads)
```

---

## 四、交叉引用与延伸阅读

| 页面 | 关联点 |
|------|--------|
| [[usb-hid-traffic-forensics]] | 同源 Writeup，含 USB HID 键盘/鼠标报告描述符解析、摩斯码、扩展维吉尼亚四元组统计、66 层嵌套包 RLE 原理 |
| [[ble-packet-capture-comparison]] | BLE 空口抓包硬件选型（Ubertooth One / CC2540 / nRF Sniffer / Hollong）对比 |
| [[nrf-sniffer-ble-setup-guide]] | nRF Sniffer + Wireshark Extcap 环境搭建、固件烧写、多信道抓包、配对加密流量解密实操 |
| [[ble-smart-bracelet-protocol-analysis-attack]] | BLE 智能手环从抓包、APP 逆向到协议重构、任意消息推送全流程 |
| [[0w1club-hardware-atlas]] | 社团硬件设备清单（含 Ubertooth One、Proxmark3）租借规则，支持线下复现 |

---

## 五、常见坑位避坑指南

| 现象 | 可能原因 | 排查动作 |
|------|----------|----------|
| PulseView UART 无解码 | 波形反转/波特率错误/采样率过低 | 1. Invert 通道 2. 光标测量起始位宽反推波特率 3. 确保采样率 ≥ 4× 波特率 |
| crackle 报 `Unsupported linktype` | pcap linktype = 256 (BLUETOOTH_LE_LL) | 使用社区适配版或自行 patch `linktype_is_supported()` 重编译 |
| 解密后无明文 / LTK 未找到 | 非 Legacy Pairing (SC=1) / 配对过程不完整 / 非链路层加密 | 1. 检查 `AuthReq` Bit 3 2. 确认捕获从 Pairing Request 开始 3. 排除应用层自加密 |
| 双重 Hex 解码报错 `Non-hexadecimal digit` | 提取片段含非 Hex 字符 / 编码非 ASCII | 先 `print(repr(payload))` 确认字符集，必要时按字节切片而非按字符 |

---

## 六、小结

- **UART 反转**是硬件 CTF 高频考点：**空闲低电平 → 通道反转 → 起始位变低 → 解码器工作**三步走。
- **BLE SMP Legacy Pairing 解密**核心在于：**完整配对流 + Legacy 模式 (SC=0) + crackle 支持 linktype 256**。若任一条件不满足，需转向硬件级降级攻击或固件逆向。
- 双重 Hex 编码是 CTF 隐写常见手法，**脚本化批量提取 + 两层 `bytes.fromhex()`** 可通杀同类题型。

> 本页面仅聚焦 UART 与 BLE SMP 两大协议分析实战；完整赛题复盘（USB HID、密码学、压缩包）请移步 [[usb-hid-traffic-forensics]]。

## 来源

- [1024安全团队-202204-202209_6](../sources/1024安全团队-202204-202209_6.md)
