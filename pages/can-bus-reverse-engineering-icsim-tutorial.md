---
title: CAN总线逆向入门实战：基于ICSim模拟器与can-utils工具链的环境搭建、流量捕获、二分法与脚本统计分析车门控制信号全流程
description: 详细记录使用ICSim汽车仪表盘模拟器与can-utils工具链在Linux环境下搭建CAN总线逆向分析平台的完整流程，涵盖虚拟CAN接口配置、candump流量捕获与日志记录、canplayer流量重放、cansniffer差异高亮分析、二分法定位车门控制帧ID（19B）、Python脚本统计高频ID辅助逆向等核心技术，适合车联网安全、IoT硬件安全入门者快速上手CAN协议逆向实战。
category: program-analysis
tags:
- CAN总线
- 逆向工程
- ICSim
- can-utils
- 车联网安全
- 硬件安全
- IoT安全
- 协议分析
- 0w1Club
- 二分法
- 流量重放
- Python脚本
date: 2022-06-05
updated: '2026-11-15'
---

## 概述

本页面整理自 0w1Club 微信归档文章《CAN流量逆向入门》，系统记录了在 Ubuntu 20.04 环境下，利用 **ICSim (Instrument Cluster Simulator)** 与 **can-utils** 工具链搭建 CAN 总线逆向分析环境的全过程。文章从 CAN 协议基础帧结构讲起，通过虚拟 CAN 接口 `vcan0` 启动模拟仪表盘与控制器，演示了 **观察法**、**二分法**、**Python 脚本统计分析** 三种定位车门控制信号（仲裁 ID `19B`）的实战技术路线，并展示了 `candump`/`canplayer`/`cansend`/`cansniffer` 四大核心工具的协同使用方法。

> 交叉引用：[[0w1club-hardware-atlas]] 中记录的 0w1Club 硬件租借计划包含树莓派、Proxymark3、Ubertooth One 等设备，可作为后续实车/硬件级 CAN 总线测试的物理设备补充；[[iot-reconnaissance-information-gathering]] 提供的 IoT 设备信息收集方法论可迁移至车载网络资产测绘场景。

---

## CAN 协议前置知识

### 帧类型与格式

CAN 总线自 1991 年大规模应用于汽车电子，采用 **差分信号传输**（CAN-H / CAN-L）抗干扰。数据帧共四类：

| 帧类型 | 用途 |
|--------|------|
| **数据帧** | 传输实际数据载荷 |
| **远程帧** | 请求特定 ID 的数据帧 |
| **错误帧** | 检测到总线错误时广播 |
| **重载帧** | 节点请求延迟下一帧传输 |

两种消息格式：
- **标准帧（11-bit ID）**：IDE 位 = 0
- **扩展帧（29-bit ID）**：IDE 位 = 1

### 标准帧关键字段

| 字段 | 位宽 | 说明 |
|------|------|------|
| **仲裁 ID** | 11-bit | 决定优先级，数值越小优先级越高（非破坏性仲裁） |
| **IDE** | 1-bit | 标识符扩展位，标准帧固定为 0 |
| **DLC** | 4-bit | 数据长度码（0~8 字节） |
| **Data** | 0~64-bit | 实际载荷，不足 8 字节补 0 |

> 安全隐患：CAN 总线采用**广播机制**，无发送源认证，任意节点可伪造帧注入恶意指令（如解锁车门、制动干扰），是车联网安全研究的核心攻击面。

---

## 环境搭建

### 依赖安装

```bash
sudo apt-get update
sudo apt-get install libsdl2-dev libsdl2-image-dev can-utils
```

### ICSim 编译与启动

```bash
# 克隆仓库
git clone https://github.com/zombieCraig/ICSim.git
cd ICSim

# 启动虚拟 CAN 接口
./setup_vcan.sh

# 终端 1：启动仪表盘模拟器
./icsim vcan0

# 终端 2：启动键盘控制器
./controls vcan0
```

#### 界面说明

- **icsim 窗口**：显示车速表、转速表、车门状态（四门）、转向灯指示
- **controls 窗口**：焦点在此窗口时接收键盘输入

#### 控制器按键映射

| 操作 | 按键组合 |
|------|----------|
| 车速增/减 | PgUp / PgDn |
| 左/右转向灯 | Left / Right |
| 打开车门 (FL/FR/RL/RR) | Right Shift + X / Y / A / B |
| 关闭车门 | Left Shift + X / Y / A / B |
| 全关车门 | Right Shift + Left Shift |
| 全开车门 | Left Shift + Right Shift |

> 注：必须选中 controls 窗口按键才生效。

### can-utils 核心工具

| 工具 | 功能 | 典型用法 |
|------|------|----------|
| **candump** | 显示/记录 CAN 流量 | `candump -l vcan0`（`-l` 自动生成 `candump-YYYY-MM-DD_HHMMSS.log`） |
| **canplayer** | 重放日志流量 | `canplayer -I <logfile>` |
| **cansend** | 发送单帧 CAN 数据 | `cansend vcan0 19B#00000B000000` |
| **cansniffer** | 实时显示并高亮变化字节 | `cansniffer vcan0`（支持 ID 过滤） |

> 交叉引用：[[nrf-sniffer-ble-setup-guide]] 中 Wireshark + Extcap 的抓包分析流程与 `candump`/`cansniffer` 思路一致，均为「捕获 → 过滤 → 差异高亮 → 重放验证」闭环。

---

## CAN 逆向与重放实战

### 场景设定

目标：定位 **左下车门（后左门）打开/关闭** 对应的 CAN 仲裁 ID 与数据载荷。

### 方法一：观察法

使用 `cansniffer vcan0` 实时监控，人工观察按下开门按键时哪个 ID 的数据字节发生变化。配合 ID 过滤功能（交互式输入 ID）可聚焦单一 ID。

> 优点：直观、无需脚本；缺点：高频总线噪声干扰大，依赖眼力与经验。

---

### 方法二：二分法 —— 核心实战流程

#### 步骤 1：采集含目标动作的完整流量

```bash
# 终端 1：开始记录（-l 自动生成带时间戳的 log 文件）
candump -l vcan0
```

操作序列：
1. 按键打开目标车门（如 Right Shift + A）
2. 按键关闭同一车门（Left Shift + A）
3. `Ctrl+C` 停止记录

```bash
# 查看行数
wc -l candump-2022-06-05_103036.log
# 输出示例：29814 行
```

#### 步骤 2：二分切割与重放验证

```bash
# 重命名并切半
mv candump-2022-06-05_103036.log ./source
split -l 15000 source cp1
# 生成 cp1aa（前半段）、cp1ab（后半段）
```

```bash
# 重放前半段
canplayer -I cp1aa
```

- 若仪表盘执行了「开门」动作 → 目标帧在前半段
- 否则在后半段

#### 步骤 3：迭代缩小范围

重复「切半 → 重放 → 判断」约 **12 次**，可将范围缩小至个位数帧。最终定位到单帧：

```bash
# 直接发送候选帧验证
cansend vcan0 19B#00000B000000
```

> 结果：ID `19B`、Data `00 00 0B 00 00 00` 触发左下车门打开。

> 技巧：`canplayer -I` 支持任意格式日志，配合 `split -l` 实现纯命令行二分，无需图形界面交互。

---

### 方法三：Python 脚本统计分析 —— 效率倍增器

#### 采集策略调整

为产生明显的频次特征：
1. `candump -l vcan0` 开始记录
2. **连续 6 次** 打开同一车门（Right Shift + A ×6）
3. 关闭车门 1 次
4. `Ctrl+C` 停止

#### 分析脚本 `1.py`

```python
import sys

result_id = []
result_data = []

# 解析日志：格式 "timestamp interface ID#DATA"
for line in open(sys.argv[1], "r"):
    parts = line.split(' ')[2].split('#')
    result_id.append(parts[0])
    result_data.append(line.split(' ')[2])

# 统计每个 ID 出现次数
for i in list(set(result_id)):
    print("{}: {}".format(i, result_id.count(i)))

# 交互式查看指定 ID 的完整帧
while True:
    inp = input("please input id: ")
    try:
        for i in range(len(result_data)):
            if result_data[i].split("#")[0].find(inp) != -1:
                print(result_data[i])
    except:
        continue
```

#### 运行结果示例

```bash
python3 1.py candump-2022-06-05_110828.log
```

```
19B: 6
...
please input id: 19B
vcan0 19B#00000B000000
vcan0 19B#00000B000000
...
```

- ID `19B` 精准出现 **6 次**，与人工开门次数一致
- 数据域 `00 00 0B 00 00 00` 中第 3 字节 `0B` 疑为门索引/状态位

> 优势：自动化统计频次、过滤周期性噪声帧、秒级定位候选 ID，适合真车高噪声环境。

---

## 总结与延伸

### 核心工具链速查表

| 阶段 | 工具 | 关键参数 | 产出 |
|------|------|----------|------|
| 环境启动 | `setup_vcan.sh` / `icsim` / `controls` | `vcan0` | 虚拟车辆与控制器 |
| 流量捕获 | `candump -l vcan0` | `-l` 自动日志 | `candump-*.log` |
| 差异观察 | `cansniffer vcan0` | 交互式 ID 过滤 | 变化字节高亮 |
| 重放验证 | `canplayer -I <log>` | 任意切片日志 | 仪表盘动作复现 |
| 单帧注入 | `cansend vcan0 ID#DATA` | 标准帧格式 | 功能确证 |
| 统计分析 | `python3 1.py <log>` | 频次统计 + 交互查询 | 高频候选 ID 列表 |

### 进阶研究方向

1. **真车环境迁移**：通过 SocketCAN 硬件适配器（如 USB-CAN、CANable）接入实车 OBD-II 接口，替换 `vcan0` 为 `can0`。
2. **周期帧过滤**：编写脚本识别固定周期（如 10ms/20ms/100ms）的心跳/状态帧，降低噪声干扰。
3. **数据语义逆向**：结合 DBC 文件解析、信号解码（大小端、缩放因子、偏移量），还原物理量（车速、转速、门状态位图）。
4. **安全测试**：基于确证帧构造 Fuzzing 序列（ID 遍历、数据位翻转、长度异常），测试 ECU 异常处理鲁棒性。
5. **协议扩展**：研究 CAN FD（灵活数据速率）、CAN XL、以太网车载网络（100/1000BASE-T1）的逆向差异。

> 交叉引用：[[ble-smart-bracelet-protocol-analysis-attack]] 展示了从抓包、APP 逆向到协议重构、任意消息推送的完整 BLE 协议逆向闭环，方法论可迁移至 CAN 总线信号语义还原；[[xihulunjian-2020-iot-pwn3-ezarmpwn-writeup]] 中的 ARM 固件动态分析技巧可用于车载 ECU 固件提取与静态分析。

---

## 参考资源

- ICSim 官方仓库：https://github.com/zombieCraig/ICSim
- can-utils 官方仓库：https://github.com/linux-can/can-utils
- SocketCAN 内核文档：https://www.kernel.org/doc/Documentation/networking/can.txt
- 《智能汽车安全攻防大揭秘》—— 帧结构图片来源
- 0w1Club 硬件租借计划：[[0w1club-hardware-atlas]]（树莓派 3、Proxymark3、Ubertooth One 等设备可用于车载网络物理层测试）

## 来源

- [1024安全团队-202204-202209_5](../sources/1024安全团队-202204-202209_5.md)
