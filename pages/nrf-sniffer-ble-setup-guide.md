---
title: nRF Sniffer BLE 抓包环境部署与实战指南
description: 详细记录 nRF Sniffer（基于 nRF52840/52832）配合 Wireshark 的环境部署、Extcap 插件安装、固件烧写、多信道抓包及配对加密流量解密实战步骤，并对比
  Ubertooth One、CC2540、Hollong 等主流 BLE 空口抓包方案的优劣。
category: program-analysis
tags:
- nRF Sniffer
- BLE
- Bluetooth
- Packet Capture
- Wireshark
- Extcap
- nRF52840
- nRF52832
- IoT Security
- Hardware Security
- 1024安全团队
date: 2023-04-15
updated: '2026-11-15'
---

## 概述

本页面系统沉淀 **nRF Sniffer** 配合 **Wireshark** 进行 BLE（Bluetooth Low Energy）空口抓包的完整工程化流程，涵盖 **Extcap 插件安装**、**Python 依赖配置**、**固件烧写更新**、**多信道抓包**、**设备过滤** 与 **配对加密流量解密** 实战步骤。同时对比 **Ubertooth One**、**CC2540 + TI Packet Sniffer**、**Hollong** 三种主流抓包方案的硬件成本、信道覆盖、易用性与适用场景，提供选型参考。

> **来源**：1024安全团队微信公众号文章《BLE空口抓包方案对比》
> **适用场景**：IoT 安全研究、蓝牙协议分析、BLE 设备调试、CTF 无线题目、固件逆向配合动态抓包

---

## 方案对比速览

| 方案 | 硬件成本 | 同时抓取信道数 | 易用性 | 核心优势 | 核心劣势 |
|------|----------|------------------|--------|----------|----------|
| **nRF Sniffer (nRF52840/52832)** | ~60-160 元 | **3 个广播信道** | ⭐⭐⭐⭐⭐ | 性价比最高、支持指定设备抓包、可刷写固件复用 | Secure Connect 配对流量解密需进一步验证 |
| **Hollong** | ~800 元 | 3 个广播信道 | ⭐⭐⭐⭐⭐ | 官方软件集成度高、非 Secure Connect 配对流量可用 crackle 解密 | 价格较高、闭源 |
| **Ubertooth One** | ~800 元 | **仅 1 个信道** | ⭐⭐⭐ | 全开源、社区活跃、支持经典蓝牙 BR/EDR | 单信道易丢包、贵、配置繁琐 |
| **CC2540 + TI Packet Sniffer** | ~40 元 | **仅 1 个信道** | ⭐⭐⭐⭐ | 最便宜、官方工具开箱即用 | 单信道、仅支持 BLE、需转换 pcap 格式 |

> **结论**：**nRF52840 是性价比最高的选择**，既便宜又能同时抓取三个广播信道，还能自行刷写固件用作其他方面（如 [[0w1club-hardware-atlas]] 中的硬件租借计划可补充设备获取渠道）。

---

## nRF Sniffer 环境部署全流程

### 前置依赖准备

- **操作系统**：Windows / Linux（推荐 Ubuntu 20.04+ 或 Kali Linux）
- **Wireshark**：版本 ≥ 3.0（需支持 Extcap 接口）
- **Python**：3.7+（Extcap 插件依赖）
- **nRF Connect for Desktop**：用于固件烧写

### Extcap 插件安装

#### 下载插件包

从 Nordic 官方 GitHub 仓库下载 `nrf-sniffer-ble` 最新 Release：

```bash
# 示例：下载并解压
wget https://github.com/NordicSemiconductor/nrf-sniffer-ble/releases/download/v3.0.0/nrf-sniffer-ble-3.0.0-win64.zip
unzip nrf-sniffer-ble-3.0.0-win64.zip -d nrf-sniffer-ble
```

#### 安装 Python 依赖

进入解压目录的 `extcap` 文件夹，安装依赖：

```bash
cd nrf-sniffer-ble/extcap
pip3 install -r requirements.txt
# 或：python3 -m pip install pyserial pexpect
```

> **注意**：Linux 下需确保 `python3` 可用，若系统默认 `python` 指向 Python 2，建议 `sudo ln -s /usr/bin/python3 /usr/bin/python`。

#### 部署到 Wireshark Extcap 目录

1. 打开 Wireshark → **帮助** → **关于 Wireshark** → **文件夹** 标签页
2. 找到 **Global Extcap path** 路径，例如：
   - Windows: `C:\Program Files\Wireshark\extcap`
   - Linux: `/usr/lib/x86_64-linux-gnu/wireshark/extcap`
3. 将 `extcap` 文件夹内的**所有文件**复制到上述目录

#### 验证插件加载

```bash
# Windows
nrf_sniffer_ble.bat --extcap-version

# Linux
./nrf_sniffer_ble.sh --extcap-version
```

输出版本信息即表示插件识别成功。重启 Wireshark 后，在 **捕获** → **刷新接口列表** 中应出现 `nRF Sniffer for Bluetooth LE` 接口。

---

## 固件烧写与更新

### 使用 nRF Connect for Desktop

1. 安装并打开 **nRF Connect for Desktop**
2. 选择 **Programmer** 应用
3. 设备连接后，下拉列表选择对应设备（如 `nRF52840`）
4. 若设备读不出内存布局，**按住板子贴边的小按键（复位/进入 Bootloader）** 再尝试

### 选择固件文件

固件位于下载的插件包 `hex` 目录下：

```
nrf-sniffer-ble/
└── hex/
    ├── sniffer_nrf52840_3.0.0_115200.hex   # nRF52840 固件
    └── sniffer_nrf52832_3.0.0_115200.hex   # nRF52832 固件
```

根据硬件型号选择对应 `.hex` 文件，点击 **Write** 烧写。

> **提示**：烧写完成后设备会自动重启，Wireshark 刷新接口即可识别。

---

## 抓包实战操作

### 基础抓包

1. Wireshark 界面双击 `nRF Sniffer for Bluetooth LE` 开始捕获
2. 此时会同时监听 **3 个广播信道（37, 38, 39）**，无需频跳同步

### 设备过滤与指定抓包

Wireshark **视图** → **接口工具栏** 中提供交互式过滤工具：

- **Device Address Filter**：输入目标设备 MAC 地址，仅捕获该设备流量
- **RSSI Filter**：按信号强度过滤
- **Connection Filter**：建立连接后自动跟随频跳

> **实战价值**：在设备密集环境（如 [[iot-reconnaissance-information-gathering]] 场景）中快速定位目标设备流量。

### 配对加密流量解密

#### Passkey（数字密钥）模式

1. 抓包前在接口工具栏设置 **Passkey**（6 位数字）
2. 若 Passkey 错误，Wireshark 显示 `Encrypted` 无法解密
3. 设置正确后，链路层 LL_ENC_REQ / LL_START_ENC_REQ 后的数据包自动解密显示明文

![解密对比](../Images/a9ad195aad0aef8761a2000cd52fe882.png)  ![解密成功](../Images/d6ce86ff76e2ab2f7adfbda87be7952a.png)

#### Long Term Key (LTK) 导入

若已通过其他手段获取 LTK（如固件逆向、内存提取），可在 Wireshark **协议首选项** → **Bluetooth** → **BLE** 中添加 LTK 实现离线解密。

> **关联技术**：[[ble-packet-capture-comparison]] 中提到 nRF52840 抓取的 Secure Connect 配对流量无法用 crackle 解密，可能是缺少关键握手包，需结合 [[android-shelling-unshelling-techniques]] 等移动端动态分析获取密钥材料。

---

## 进阶用法与故障排查

### 多设备并发抓包

- 单个 nRF Sniffer 同一时刻只能跟随**一条连接**的频跳
- 需同时抓取多条连接时，准备多个 nRF52840 硬件，分别指定不同 Device Address

### 固件版本兼容性

| 固件版本 | 支持芯片 | 最大波特率 | 备注 |
|----------|----------|------------|------|
| 3.x | nRF52840, nRF52832 | 1 Mbps | 当前主流稳定版 |
| 4.x (Beta) | nRF52840 | 2 Mbps (PHY coded) | 支持 Long Range，实验性 |

### 常见问题

| 现象 | 原因 | 解决 |
|------|------|------|
| Wireshark 无 nRF Sniffer 接口 | Extcap 路径错误 / Python 依赖缺失 | 检查 Global Extcap path、重装 requirements.txt |
| 抓包无任何包 | 固件未烧写 / 硬件未识别 | 重新烧写固件、检查 `lsusb` / 设备管理器 |
| 解密失败显示 Encrypted | Passkey 错误 / 缺少配对阶段包 | 确认 Passkey、尝试从连接建立阶段开始抓包 |
| Linux 权限错误 | 非 root 无法访问 USB 设备 | `sudo usermod -a -G plugdev $USER` 并重登 |

---

## 交叉引用与延伸阅读

| 页面 | 关联说明 |
|------|----------|
| [[ble-packet-capture-comparison]] | 四大 BLE 抓包方案详细对比表、选型指南 |
| [[0w1club-hardware-atlas]] | 0w1Club 硬件租借计划，可低成本借用 nRF52840、Ubertooth One 等设备 |
| [[iot-reconnaissance-information-gathering]] | IoT 设备信息收集全流程，BLE 抓包作为无线侦察关键环节 |
| [[android-shelling-unshelling-techniques]] | Android APP 脱壳动态分析，配合 BLE 抓包还原移动端与外设交互逻辑 |
| [[cobalt-strike-external-c2-smb-beacon]] | 红队 C2 通道隐匿技术，BLE 作为隐蔽通信信道的潜在研究方向 |

---

## 附录：关键命令速查表

```bash
# === Linux 环境一键部署脚本示例 ===
#!/bin/bash
set -e

# 1. 安装系统依赖
sudo apt update && sudo apt install -y wireshark python3-pip python3-serial

# 2. 下载 nRF Sniffer 插件（以 v3.0.0 为例）
cd /tmp
wget -q https://github.com/NordicSemiconductor/nrf-sniffer-ble/releases/download/v3.0.0/nrf-sniffer-ble-3.0.0-linux64.tar.gz
tar -xzf nrf-sniffer-ble-3.0.0-linux64.tar.gz

# 3. 安装 Python 依赖
cd nrf-sniffer-ble/extcap
pip3 install -r requirements.txt

# 4. 部署到 Wireshark Extcap 目录
EXTCAP_DIR="/usr/lib/x86_64-linux-gnu/wireshark/extcap"
sudo cp * "$EXTCAP_DIR/"
sudo chmod +x "$EXTCAP_DIR/nrf_sniffer_ble.sh"

# 5. 验证
"$EXTCAP_DIR/nrf_sniffer_ble.sh" --extcap-version

echo "[+] 部署完成，重启 Wireshark 即可使用"
```

---

## 更新日志

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2023-04-15 | 1.0 | 初版：整合 1024安全团队原文，结构化部署流程、固件烧写、解密实战、方案对比 |
| 2024-01-20 | 1.1 | 新增 Linux 一键部署脚本、故障排查表、交叉引用关联页面 |
| 2024-06-10 | 1.2 | 补充 LTK 离线导入解密、多设备并发抓包说明、固件版本兼容性表 |

---

> **免责声明**：本页面仅供安全研究、教学演示及授权渗透测试使用。未经授权抓取、解密他人蓝牙通信流量可能违反相关法律法规，请在合规前提下开展工作。

## 来源

- [1024安全团队-202204-202209_1](../sources/1024安全团队-202204-202209_1.md)
