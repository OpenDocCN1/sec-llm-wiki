---
title: FT232H/FT232HQ 结合 flashrom 进行 SPI 闪存固件提取实战
description: 详细记录使用 FT232H/FT232HQ 配合 flashrom 进行 SPI 闪存固件提取的完整实战流程，涵盖驱动安装、串口调试、SPI
  模式跳线、芯片识别与固件读取验证。
category: program-analysis
tags:
- FT232H
- FT232HQ
- flashrom
- SPI
- 固件提取
- 硬件安全
- IoT安全
- 闪存芯片
- Winbond W25Q32
date: 2024-01-15
updated: '2026-11-15'
---

## 概述

本页面系统沉淀 **FT232H/FT232HQ** 配合 **flashrom** 进行 **SPI 闪存固件提取** 的完整实战流程。FT232H 系列是 FTDI 推出的 USB 高速转单通道串行 UART/FIFO/JTAG/SPI/I2C 控制器，配合开源工具 flashrom 可实现对 SPI 接口闪存芯片的检测、读取、写入、验证与擦除。文章以 **Winbond W25Q32** 芯片为例，演示从硬件连接、驱动安装、串口模式自检、SPI 模式跳线配置、芯片拆焊上座、flashrom 命令行提取固件，到商业编程器交叉验证的全链路操作。

> 适用场景：IoT 设备固件提取、路由器/摄像头/智能家居设备固件分析、硬件安全研究、CTF 硬件题、固件逆向工程前置准备。

---

## 硬件准备

| 组件 | 说明 |
|------|------|
| **FT232H/FT232HQ 模块** | 支持 USB 2.0 High Speed，提供 UART、SPI、I2C、JTAG、GPIO 等多种模式 |
| **SOIC8 测试夹 / 烧录座** | 对应目标闪存芯片封装（W25Q32 为 SOIC8），建议配合热风枪拆焊后上座读取 |
| **杜邦线 / 跳线帽** | 用于 SPI 模式跳线配置、UART 自测短接、目标板连接 |
| **目标设备** | 本文以搭载 Winbond W25Q32 的路由器为例 |
| **万用表** | 用于测量目标板串口引脚（GND、TX、RX）电压与连通性 |

---

## 驱动安装与设备识别

### 获取驱动程序

访问 FTDI 官网：<https://ftdichip.com/>，搜索 **FT232H** 或 **FT232HQ**，下载对应操作系统的 VCP（Virtual COM Port）驱动。

> FT232H 系列常见型号：FT232H、FT232HQ、FT232HL。本文实测设备为 **FT232HQ**。

### 安装驱动

Windows 下运行安装程序，完成后打开 **设备管理器 → 端口 (COM 和 LPT)**，应能看到新增串口设备，例如 `USB Serial Port (COM8)`。

> 若识别为 `FT232H` 而非 `FT232HQ`，属正常现象，驱动通用。

---

## UART 模式自测与目标设备串口连接

### 回环测试验证 UART 功能

- 使用跳线帽或杜邦线将模块 **TX 与 RX 短接**
- 打开串口调试助手（如 XCOM、MobaXterm、PuTTY），配置波特率 115200、8N1、无流控
- 发送字符串 `test`，若接收区回显 `test`，说明 UART 通道正常

### 连接目标设备串口

1. 使用万用表测量目标板串口引脚：确认 **GND、TX、RX**（TX 对应目标板 RX，RX 对应目标板 TX）
2. 杜邦线连接：模块 GND → 目标 GND、模块 TX → 目标 RX、模块 RX → 目标 TX
3. 打开串口工具，上电目标设备，观察启动日志、进入 Shell 或 U-Boot 控制台

> 此步骤可验证硬件连接可靠性，也可在固件提取前获取设备启动信息、分区布局等辅助信息。

---

## SPI 模式配置与闪存芯片读取

### 切换至 SPI 模式（关键步骤）

FT232H 模块出厂默认通常为 UART 模式，**使用 flashrom 读取 SPI 闪存前，必须通过跳线帽将模块配置为 SPI 模式**。

> 具体跳线引脚定义请参考所用模块原理图/丝印，常见为将 `SPI_EN` / `CFG` 等引脚拉高/拉低，或短接特定排针。请务必查阅模块厂商提供的原理图或数据手册。

### 目标芯片识别与支持确认

访问 flashrom 官方支持列表：<https://www.flashrom.org/Supported_hardware>

搜索目标芯片型号（如 **Winbond W25Q32**），确认 `Supported` 状态。

> W25Q32 为 32M-bit (4MB) SPI NOR Flash，广泛用于路由器、摄像头、IoT 设备。

### 芯片拆焊与上座

- 使用热风枪（300~350℃）将目标板上的 SOIC8 闪存芯片拆下
- 注意标记 1 号脚方向（通常有圆点/凹槽标识）
- 将芯片放入 SOIC8 烧录座，对准 1 号脚插入模块对应排针/插槽

### flashrom 读取固件

#### 基础命令语法

```bash
flashrom -p ft2232_spi:type=232H -r spi_dump.bin
```

| 参数 | 含义 |
|------|------|
| `-p ft2232_spi:type=232H` | 指定编程器为 FT2232/FT232H 系列 SPI 模式，`type=232H` 适配 FT232H/FT232HQ |
| `-r spi_dump.bin` | 读取闪存内容并保存为指定文件 |

#### 执行示例与输出解读

```text
flashrom v1.2 on Linux 5.15.0-xx-generic (x86_64)
flashrom is free software, get the source code at https://flashrom.org

Using clock_gettime for delay loops (clk_id: 1, resolution: 1ns).
Found Winbond flash chip "W25Q32.V" (4096 kB, SPI) on ft2232_spi.
Reading flash... done.
```

- 识别到芯片型号 `W25Q32.V`，容量 4096 kB（4 MB）
- 读取完成，生成 `spi_dump.bin`

### 固件完整性验证

#### 文件哈希校验

```bash
md5sum spi_dump.bin
# 输出示例：6ee56da6dc43ec6657f0edf46d6e86e8  spi_dump.bin
```

#### 交叉验证（商业编程器）

使用 **RT809H / CH341A / 烧录器** 等商业设备再次读取同一芯片，保存为 `2.bin`，对比 MD5：

```bash
md5sum 2.bin
# 输出：6ee56da6dc43ec6657f0edf46d6e86e8  2.bin
```

**哈希一致** → 确认 flashrom 读取数据完整、无误码，固件提取成功。

---

## 常见问题与排查

| 现象 | 可能原因 | 排查建议 |
|------|----------|----------|
| `Error: Programmer initialization failed` | SPI 模式跳线未接/接错、驱动未绑定 libusb | 核对跳线帽、重装驱动、尝试 `-p ft2232_spi:type=232H,divisor=0` 调整时钟分频 |
| 识别到芯片但读取全 `0xFF` / 校验失败 | 供电不足、夹子接触不良、芯片已损坏 | 检查 3.3V 供电、重新上座、万用表测量 VCC/GND |
| `No EEPROM/flash device found` | 芯片型号不在支持列表、SPI 模式未生效 | 确认跳线、尝试 `-c W25Q32.V` 强制指定芯片型号 |
| 读取速度极慢 | 默认时钟分频过低 | 增加 `divisor` 参数（如 `divisor=2` 对应 6MHz），视线材质量调整 |

> `divisor` 计算：`SCLK = 60MHz / (divisor + 1)`。`divisor=0` 为 30MHz，`divisor=1` 为 15MHz，以此类推。长杜邦线建议降低频率。

---

## 后续分析建议

固件提取完成后，可进行以下分析：

1. **固件识别与解包**：`binwalk -Me spi_dump.bin` 自动提取文件系统、内核、配置文件
2. **文件系统挂载**：识别 squashfs/ubifs/jffs2 等，使用 `unsquashfs`、`ubi_reader` 等工具解包
3. **敏感信息搜集**：`grep -r "password\|admin\|key\|token" ./_extracted/`
4. **二进制逆向**：提取的 ELF/ARM/MIPS 二进制导入 IDA Pro / Ghidra / Binary Ninja 分析
5. **漏洞挖掘**：固件组件版本对比 CVE、Web 界面/后门账号/硬编码凭证分析

> 相关工具链参考：[[ghidra-reverse-engineering-framework-introduction]]、[[ghidra-decompiler-window-guide]]、[[ida-pro-tips-plugins-python]]、[[reverse-engineering-beginner-learning-path]]

---

## 交叉引用与延伸阅读

- [[0w1club-hardware-atlas]] — 0w1Club 硬件安全设备清单与租借计划，含 FT232H 类调试器资源获取路径
- [[badusb-hid-attack-arduino-leonardo]] — 另一类基于 HID 的硬件攻击实战，适合对比理解物理接触攻击面
- [[iot-reconnaissance-information-gathering]] — IoT 设备信息收集全流程，固件提取前的侦察阶段参考
- [[ble-packet-capture-comparison]] / [[nrf-sniffer-ble-setup-guide]] — 无线侧信道分析，配合固件静态分析形成完整攻击面
- [[vulnhub-platform-resource-index]] — VulnHub 靶机实战资源，可练习固件提取后的漏洞复现与提权

---

## 参考资料

- flashrom 官方手册：<https://manpages.ubuntu.com/manpages/xenial/man8/flashrom.8.html>
- flashrom 支持硬件列表：<https://www.flashrom.org/Supported_hardware>
- FTDI FT232H 数据手册：<https://ftdichip.com/products/ft232h/>
- 原文归档：1024安全团队微信公众号《硬件安全-FT232HQ获得路由器串口与读取固件》

---

## 更新记录

| 日期 | 版本 | 说明 |
|------|------|------|
| 2024-01-15 | 1.0 | 初版创建，覆盖驱动安装、UART 自测、SPI 跳线、flashrom 读取、哈希验证全流程 |

## 来源

- [1024安全团队-202204-202209_3](../sources/1024安全团队-202204-202209_3.md)
