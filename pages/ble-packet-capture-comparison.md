---
title: BLE 空口抓包方案对比：Ubertooth One、CC2540、Hollong、nRF Sniffer
description: 对比四种主流 BLE 空口抓包方案的硬件成本、信道覆盖、易用性与适用场景，提供选型参考与环境配置实操指南。重点补充 TI CC2540 Packet
  Sniffer 在 BLE 设备抓包中的实战用法及信道跳频捕获技巧。
category: program-analysis
tags:
- BLE
- Bluetooth
- Packet Capture
- Ubertooth One
- CC2540
- Hollong
- nRF Sniffer
- Wireshark
- IoT Security
- Hardware Security
date: 2023-04-15
updated: '2026-11-15'
---

## 概述

BLE（Bluetooth Low Energy）空口抓包是物联网安全研究、协议分析与漏洞挖掘的基础技能。本文对比四种主流抓包方案：**Ubertooth One**、**CC2540 (TI Packet Sniffer)**、**Hollong**、**nRF Sniffer (nRF52840/52832)**，从硬件成本、信道覆盖、易用性、固件更新、解密能力等维度给出选型建议。

> 原文来源：1024安全团队微信公众号《BLE空口抓包方案对比》

---

## 方案对比总览

| 方案 | 硬件成本（约） | 同步信道数 | 易用性 | 固件更新 | 典型适用场景 |
|------|----------------|------------|--------|----------|--------------|
| **Ubertooth One** | ~800 元 | 1 个（需跳频） | 中（需自行编译依赖、配置管道） | 支持 DFU 升级 | 开源爱好者、全栈协议研究、需二次开发 |
| **CC2540 + TI Packet Sniffer** | ~40 元 | 1 个 | 高（官方 GUI、开箱即用） | 官方工具烧录 | 低成本入门、单信道调试、教学演示、协议逆向实战 |
| **Hollong (纬图)** | ~800 元（9 通道版 ~1376 元） | 3 个广播信道（37/38/39） | 高（官方软件一键启动 Wireshark）| 官方工具烧录 | 工程化抓包、非 Secure Connections 配对破解 |
| **nRF Sniffer (nRF52840/52832)** | ~60-160 元 | 3 个广播信道 + 指定设备过滤 | 中（需部署 extcap 插件）| nRF Connect for Desktop 烧录 | **性价比最高**、日常调试、指定设备抓包、固件二次开发 |

---

## 方案一：Ubertooth One + Wireshark

### 硬件特点
- 全开源软硬件，社区维护活跃
- 单射频前端，**同一时刻只能监听一个信道**，通过快速跳频覆盖 40 个信道，易丢包
- 适合对 **连接建立全过程（Connection Initiation）** 研究、自定义协议分析

### 环境配置（Linux / 虚拟机推荐）

#### 安装依赖
```bash
sudo apt install cmake libusb-1.0-0-dev make gcc g++ libbluetooth-dev wget \
pkg-config python3-numpy python3-qtpy python3-distutils python3-setuptools
```

#### 编译安装 libbtbb
```bash
wget https://github.com/greatscottgadgets/libbtbb/archive/2020-12-R1.tar.gz -O libbtbb-2020-12-R1.tar.gz
tar -xf libbtbb-2020-12-R1.tar.gz
cd libbtbb-2020-12-R1
mkdir build && cd build
cmake .. && make
sudo make install && sudo ldconfig
```

#### 编译安装 ubertooth tools
```bash
wget https://github.com/greatscottgadgets/ubertooth/releases/download/2020-12-R1/ubertooth-2020-12-R1.tar.xz
tar -xf ubertooth-2020-12-R1.tar.xz
cd ubertooth-2020-12-R1/host
mkdir build && cd build
cmake .. && make
sudo make install && sudo ldconfig
```

#### 安装 Wireshark 并配置 BTBB / BR/EDR 插件
```bash
# BTBB 插件
cd libbtbb-2020-12-R1/wireshark/plugins/btbb
mkdir build && cd build
cmake -DCMAKE_INSTALL_LIBDIR=/usr/lib/x86_64-linux-gnu/wireshark/libwireshark3/plugins ..
make && sudo make install

# BR/EDR 插件
cd ../../../../libbtbb-2020-12-R1/wireshark/plugins/btbredr
mkdir build && cd build
cmake -DCMAKE_INSTALL_LIBDIR=/usr/lib/x86_64-linux-gnu/wireshark/libwireshark3/plugins ..
make && sudo make install
# 若提示缺 python：sudo ln -s /usr/bin/python3 /usr/bin/python
```

#### 固件升级
从 [GitHub Releases](https://github.com/greatscottgadgets/ubertooth/releases) 下载 `bluetooth_rxtx.dfu`，执行：
```bash
ubertooth-dfu -d bluetooth_rxtx.dfu
```
> 虚拟机中烧录会导致 USB 重枚举，需重新挂载设备。

### 抓包操作流程
1. 创建命名管道：`mkfifo /tmp/pipe`
2. Wireshark → 捕获 → 选项 → 管理接口 → 新建管道 `/tmp/pipe`
3. 启动抓包：`ubertooth-btle -f -c /tmp/pipe`
4. Wireshark 即可实时显示 BLE 流量

---

## 方案二：CC2540 + TI Packet Sniffer

### 硬件特点
- **极低成本**（~40 元），基于 TI CC2540 SoC
- 同样**单信道**，需手动切换或跳频
- 官方 **Packet Sniffer 2** 提供 Windows GUI，开箱即用

### 实战用法与信道跳频捕获技巧

#### 设备识别与准备
1. **确定目标设备 MAC 地址**：使用手机 APP（如 nRF Connect、厂商官方 APP）扫描连接目标 BLE 设备，记录其 MAC 地址（例：`A4:C1:38:6A:1C:BF`）
2. **解除现有绑定**：在手机蓝牙设置中取消配对/绑定，确保抓包捕获完整的连接建立与配对过程

#### 信道跳频捕获核心难点与应对
> **关键限制**：BLE 广播使用 3 个广播信道（37、38、39），连接建立后在 37 个数据信道间跳频。CC2540 单射频前端**同一时刻只能监听一个信道**。

**实战捕获策略**：
1. 打开 TI Packet Sniffer 2，选择协议类型为 **Bluetooth Low Energy**
2. 点击 Start 开始抓包，**先于手机端发起连接操作**
3. 由于广播信道随机，**可能需要多次尝试**（重置设备、重新扫描连接）才能捕获到广播包与连接请求
4. 观察捕获窗口：`M->S` 表示手机发送给设备，`S->M` 表示设备发送给手机
5. 重点关注 **Connection Request**（连接请求）与 **Feature Exchange**（特性交换）阶段数据包

#### 数据包分析实战示例（以某智能手环为例）

**步骤 1：识别关键数据包**
- 捕获到的数据包中，标记包含特征数据的包（如步数 `0x64` = 100）
- 典型模式：手机发送请求（`M->S`）→ 设备响应数据（`S->M`）
- 特殊功能指令：如"查找手环"震动指令在捕获末尾出现

**步骤 2：配合 Android 动态分析还原协议**
- 使用 **AndroidKiller** 连接手机捕获 APP 日志
- 过滤 `ble` 关键字定位通信流程：扫描 → 连接 → 绑定指令 → 配置同步 → 业务指令
- 关键指令示例：
  - `430000dc`：绑定指令
  - `0100000b`：获取设备信息
  - `02000006`：获取设备状态
  - `27000074`：获取电量
  - `2001000070`：获取步数/卡路里/距离
  - `1008000000000001000000c00000000000000000`：查找手环（震动）

**步骤 3：APP 逆向工程验证协议结构**
- 使用 **jadx** 反编译 APK，定位日志对应的代码类（如 `CmdHelper.java`）
- 分析消息推送协议构造函数 `setMessage2`，还原指令格式：
  - 固定头 `0a`
  - 长度字段（数据长度 + 1）
  - 类型标识（01=昵称，02=消息内容）
  - ASCII 数据载荷
  - 校验码：`sum(bytes) * 86 + 90` 取低字节

**步骤 4：使用 gatttool 实战验证与攻击**
```bash
# 激活蓝牙适配器
hciconfig hci0 up

# 进入交互模式连接目标设备
gatttool -I -b A4:C1:38:6A:1C:BF

# 内部命令
connect                    # 建立连接
char-read-hnd 0x11         # 读取特征值句柄
char-write-req 0x11 430000dc  # 发送绑定指令
char-write-req 0x11 <构造的指令>  # 发送业务指令（如消息推送）
```
> 实测可成功实现**任意消息推送**、触发震动、读取传感器数据等攻击效果。

### 使用流程总结
1. 安装 [TI Packet Sniffer](https://www.ti.com/tool/PACKET-SNIFFER-2)
2. 选择协议类型为 **Bluetooth Low Energy**
3. 点击 Start 即可抓包，保存格式为 `.psd`
4. 转换为 Wireshark 可识别的 `.pcap`：
   ```bash
   # 使用开源转换工具
   git clone https://github.com/.../psd2pcap.git
   python psd2pcap.py input.psd output.pcap
   ```

### 优缺点深度对比
| 优点 | 缺点 | 实战补救建议 |
|------|------|--------------|
| 价格极低，适合大量采购教学 | 单信道、仅支持 Windows 官方软件 | 多次重试捕获广播包；配合手机端强制重连 |
| 官方 GUI 友好，无需编译 | .psd 需转换才能进 Wireshark 深度分析 | 使用 psd2pcap 转换后用 Wireshark 过滤分析 |
| 适合简单连接调试、广播包分析 | 无法同步抓取 3 个广播信道，易丢连接包 | **核心技巧**：先用 CC2540 捕获连接建立阶段，再切换 nRF/Hollong 定频深度抓包 |
| 官方工具链完整，固件烧录简单 | 无指定设备过滤、无 Passkey 解密功能 | 配合 AndroidKiller + jadx 逆向还原协议，用 gatttool 重放验证 |

---

## 方案三：Hollong (纬图) + Wireshark

### 硬件特点
- 国产商业化产品，**原生同步监听 3 个广播信道 (37/38/39)**，无跳频丢包
- 9 通道版可同时监听所有 40 信道（~1376 元）
- 官方软件集成 Wireshark 启动，**操作最简单**

### 使用流程
1. 安装官方软件（Windows）
2. 配置 Wireshark 安装路径
3. 界面右侧勾选需抓取的信道，点击“开始”
4. 自动拉起 Wireshark 实时显示

### 独特优势：配对流量解密
- 对 **Legacy Pairing / Just Works / Passkey Entry**（非 Secure Connections）抓到的配对流量，**可直接用 [crackle](https://github.com/mikeryan/crackle) 破解 LTK**
- nRF Sniffer 抓取的同类流量目前**无法被 crackle 解密**（可能缺少关键数据包），需进一步排查

---

## 方案四：nRF Sniffer (nRF52840 / nRF52832) + Wireshark

### 硬件特点
- **性价比之王**：信驰达 nRF52840 Dongle 仅 ~60 元，原版 ~160 元
- **同步 3 广播信道**，支持 **指定设备地址过滤**、**设置 Passkey 解密加密链路**
- 基于 Nordic 官方固件，**可刷写自定义固件** 用作开发板、Fuzzer、中继器等

### 环境配置

#### 获取 extcap 插件
下载地址：[Nordic Semiconductor/nrf-sniffer-ble](https://github.com/NordicSemiconductor/nrf-sniffer-ble) → Releases → `nrf_sniffer_ble_extcap_<version>.zip`

#### 安装 Python 依赖
```bash
cd nrf_sniffer_ble/extcap
pip install -r requirements.txt
# 或：python -m pip install -r requirements.txt
```

#### 部署到 Wireshark Extcap 目录
- Wireshark → 帮助 → 关于 Wireshark → 文件夹 → **Global Extcap path**
- 将 `extcap` 目录下所有文件复制到该路径

#### 验证安装
```bash
# Linux/macOS
./nrf_sniffer_ble.py --extcap-interfaces
# Windows
nrf_sniffer_ble.bat --extcap-interfaces
```
输出包含 `nRF Sniffer for Bluetooth LE` 即成功。

### 抓包操作
1. 插入 Dongle，Wireshark → 捕获 → 刷新接口列表 → 双击 `nRF Sniffer for Bluetooth LE`
2. **视图 → 接口工具栏** 可设置：
   - **Device Filter**：仅抓取指定 MAC 地址
   - **Passkey**：输入 6 位配对码，实时解密加密流量
3. 抓包结果直接在 Wireshark 中分析

### 固件升级
1. 安装 [nRF Connect for Desktop](https://www.nordicsemi.com/Products/Development-tools/nRF-Connect-for-desktop)
2. 打开 **Programmer** 应用
3. 选择设备（若未识别，按住板载小按键复位进入 DFU 模式）
4. 选择下载固件包内 `hex/sniffer_<board>_<version>.hex`
5. 点击 **Write** 完成烧录

---

## 选型建议与最佳实践

| 场景 | 推荐方案 | 理由 |
|------|----------|------|
| **预算极低、仅需抓广播包** | CC2540 | ~40 元入门，GUI 傻瓜化 |
| **需完整捕获连接建立、自定义协议研究** | Ubertooth One | 开源可改、社区资料多、支持 BR/EDR |
| **工程化日常调试、需破解 Legacy Pairing LTK** | Hollong | 3 信道同步、官方软件稳、crackle 兼容性最好 |
| **性价比最高、需指定设备抓包、Passkey 解密、固件二次开发** | **nRF52840 Dongle** | 60 元买三信道+过滤+解密+可刷机，**首选** |
| **BLE 协议逆向实战入门（抓包+逆向+重放完整链路）** | **CC2540 + AndroidKiller + jadx + gatttool** | 成本最低、工具链成熟、覆盖从空口抓包到协议还原再到攻击验证的完整流程 |

### 组合使用技巧
- **nRF Sniffer 抓包 + crackle 离线解密**：若 nRF 抓到的 Legacy Pairing 流量 crackle 解密失败，可尝试同时插 **Hollong** 同步抓包，取其配对阶段数据包补全。
- **Ubertooth One 做信道跳频扫描**，发现目标连接后切换到 **nRF/Hollong** 定频深度抓包。
- **CC2540 捕获连接建立阶段**，配合 **Android 动态分析 + APP 逆向** 还原应用层协议，再用 **gatttool/nRF** 验证攻击。
- **固件二次开发**：nRF52840 可刷入 [Zephyr](https://zephyrproject.org/) / [FreeRTOS](https://www.freertos.org/) 当开发板，或烧写 [btlejack](https://github.com/virtualabs/btlejack) 变身中继/注入工具。

---

## 相关资源与交叉引用

- [[0w1club-hardware-atlas]] — 0w1Club 硬件图鉴收录 Ubertooth One、Proxmark3 等射频设备租借信息
- [[badusb-hid-attack-arduino-leonardo]] — 硬件安全入门视角下的 BadUSB 与 Arduino 实战
- [[ble-smart-bracelet-protocol-analysis-attack]] — 完整复现某款 BLE 智能手环从 CC2540 抓包、APP 逆向到协议重构并实现任意消息推送的实战案例
- [[iot-reconnaissance-information-gathering]] — IoT 设备信息收集全流程，含 BLE 资产侦察
- [[named-pipe-smb-detection-sysmon]] — 命名管道通信原理，对比 BLE 抓包中管道数据流转思路
- [[pystinger-socks4-proxy-webshell-pivoting]] — 内网穿透代理技术，对比 BLE 中继/注入场景的数据转发模型

---

## 更新日志

| 日期 | 变更说明 |
|------|----------|
| 2023-04-15 | 初版发布，整合 1024安全团队原文四大方案配置与对比 |
| 2024-01-10 | 补充 nRF Sniffer Passkey 解密实测截图、Hollong 9 通道版信息、crackle 兼容性对比 |
| 2026-11-15 | **重大更新**：补充 TI CC2540 Packet Sniffer 实战用法详解（信道跳频捕获技巧、AndroidKiller 动态分析配合、jadx 逆向还原协议、gatttool 攻击验证完整链路），新增 CC2540 组合拳实战选型建议 |

---

> **免责声明**：本页面仅供安全研究与教学用途，抓包分析需在授权范围内进行，遵守《网络安全法》等法律法规。

## 来源

- [1024安全团队-202204-202209_2](../sources/1024安全团队-202204-202209_2.md)
