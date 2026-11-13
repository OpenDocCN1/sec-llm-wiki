---
title: 0w1Club 硬件图鉴：社团硬件租借计划设备清单与规则
description: 记录 0w1Club 社团硬件租借计划「0w1硬件图鉴」的六类设备清单（树莓派 3、Bad USB、TP-Link WN822N、Proxymark3、Ubertooth
  One、DFROBOT 开发板）、租借积分规则、免责声明与安全合规要求。
category: program-analysis
tags:
- 0w1Club
- 硬件安全
- IoT 安全
- RFID
- 蓝牙安全
- 树莓派
- Bad USB
- Proxymark3
- Ubertooth One
- 租借计划
- 网络安全法
date: 2018-01-01
updated: '2026-11-14'
---

## 概述

**0w1硬件图鉴** 是 0w1Club 社团面向成员开展的硬件租借计划，旨在让成员以低成本（积分制）体验实体安全硬件，涵盖嵌入式开发、无线射频、Bad USB 攻击、蓝牙嗅探、RFID/NFC 分析等方向。所有租借需签署免责声明，并遵守《网络安全法》等法律法规。

## 设备清单与租借规则

### 树莓派 3（Raspberry Pi 3 Model B）+ 入门工具套装
- **租借积分**：2 积分/周
- **包含内容**：树莓派 3 本体 + 完整入门工具套装（电源、SD 卡、散热片、外壳、GPIO 扩展板等）
- **典型用途**：
  - 搭建轻量级服务器 / 私有云盘（Nextcloud 等）
  - 学习 Linux 系统管理与嵌入式开发
  - 结合传感器/执行器做物联网原型（如自动喷水、迟到提醒等趣味项目）
- **上手建议**：官方 Raspberry Pi OS（原 Raspbian）预装 Python、GPIO 库，适合零基础快速上手。

### Bad USB（基于 ATtiny85 / Digispark 等实现）
- **租借积分**：1 积分/周
- **原理**：伪装成 HID 键盘设备，插入目标机器自动执行预置按键载荷（Ducky Script）。
- **典型用途**：
  - 理解 HID 攻击面与键盘注入原理
  - 合法授权环境下的渗透测试演示（如自动打开终端下载载荷）
- **安全警示**：
  - 严禁插入他人设备或未授权环境
  - 仅用于教学、授权测试与防御研究
  - 违规使用将承担法律责任，详见《网络安全法》第 27、28 条

> 相关实战案例可参考社团早期分享：[[phishing-website-creation-tutorial]]（社会工程学与钓鱼网站制作，含物理接触攻击面拓展）。

### TP-Link WN822N 无线网卡（RTL8192CU/RTL8188EUS 芯片组）
- **租借积分**：1 积分/周
- **特性**：支持监听模式、帧注入，兼容 Aircrack-ng、Kismet、Wifite 等工具链。
- **典型用途**：
  - 802.11 抓包分析（Wireshark + radiotap）
  - WPA/WPA2 握手包捕获与离线破解演示
  - 无线网络侦察、信道干扰测试（仅限授权环境）
- **驱动提示**：Linux 下可能需安装 `rtl8812au` / `rtl8188eu` 第三方驱动（DKMS），Kali 默认已集成。

> 无线安全入门可结合 [[crypto-basics-xor-stream-cipher-tutorial]] 中的流密码基础，理解 WEP/RC4 弱点。

### Proxymark3（RDV4 / Blue Shark 等主流版本）
- **租借积分**：2 积分/周
- **定位**：开源 RFID/NFC 研究瑞士军刀，支持 125 kHz (LF) 与 13.56 MHz (HF) 双频。
- **核心功能**：
  - 读取/克隆/模拟：EM4100、HID Prox、T5577（LF）；Mifare Classic/Ultralight/DESFire、IC 卡、CPU 卡（HF）
  - 嗅探读卡器-标签通信、破解 Mifare Classic 扇区密钥（Nested/Hardnested 攻击）
  - 固件可刷写，支持 Lua 脚本扩展
- **典型场景**：
  - 门禁系统安全评估（授权）
  - 校园一卡通/会员卡余额读取（仅限自有卡片）
  - NFC 支付协议逆向学习
- **安全警示**：
  - 严禁复制他人门禁/支付卡
  - 仅针对自有或已授权目标进行测试
  - 克隆卡片可能触发《刑法》第 285 条（非法侵入计算机信息系统罪）或第 287 条相关条款

### Ubertooth One
- **租借积分**：2 积分/周
- **定位**：开源蓝牙协议分析硬件，覆盖 2.4 GHz ISM 频段，支持 BR/EDR 与 BLE（Bluetooth Low Energy）。
- **核心功能**：
  - 被动嗅探蓝牙流量（需配合 `ubertooth-follow`、`ubertooth-btle`）
  - L2CAP/HCI 层面抓包，导出 PCAP 供 Wireshark 分析
  - BLE 连接劫持、广播包伪造、配对过程监听
- **典型场景**：
  - 蓝牙键鼠/耳机/手环通信分析
  - BLE 设备固件更新（OTA）拦截与逆向
  - 蓝牙定位/资产发现（配合 Kismet）
- **局限性**：BR/EDR 嗅探需同步跳频，成功率受距离/干扰影响；BLE 嗅探相对稳定。

### DFROBOT 开发板（Gravity 系列 / FireBeetle ESP32/ESP8266 等）
- **租借积分**：1 积分/周
- **定位**：面向创客与物联网原型开发的模块化开发板生态，主控常为 ESP32、ESP8266、STM32。
- **典型用途**：
  - 快速搭建 IoT 设备原型（传感器采集、MQTT 上云、OTA 升级）
  - 学习 Arduino / MicroPython / ESP-IDF 开发流程
  - 结合传感器模块（温湿度、光照、人体红外、继电器）做智能家居 Demo
  - 理解设备端固件结构，为后续固件提取/逆向（binwalk、Ghidra）打基础
- **扩展建议**：搭配树莓派做边缘网关，或作为 Proxymark3/Ubertooth 的便携供电/数据转发节点。

## 积分获取途径

| 方式 | 说明 |
|------|------|
| 撰写心得体会 | 租借归还后提交使用报告/技术笔记（Markdown 格式） |
| 参加线下培训 | 出席社团周培训（如 RE、Crypto、PWN、Web 等专题） |
| 协助排版/运营 | 协助公众号排版、活动组织、设备维护 |
| 做技术分享 | 线下分享会/Lightning Talk 展示项目成果 |

> 社团历史培训专题可回溯：[[0w1club-week11-crypto-re-pwn-training]]、[[0w1club-ctf-re-writeup-beginner-challenges]]、[[reverse-engineering-beginner-learning-path]]。

## 租借流程与合规要求

1. **登记预约**：在社团群/文档登记设备、预计周数。
2. **签署免责声明**：纸质/电子签名确认：
   - 设备损坏/丢失按原价赔偿
   - 仅用于合法授权测试、教学研究
   - 不得用于攻击第三方系统、窃取数据、破坏设施
3. **领取与归还**：约定时间地点面交，现场核对配件完整性。
4. **逾期/违规**：超期扣积分，违规使用永久取消借用资格并上报学校网络安全管理部门。

## 法律合规底线

- **《中华人民共和国网络安全法》**（重点条款）：
  - 第 27 条：禁止为非法侵入、干扰计算机系统提供工具/程序
  - 第 28 条：禁止窃取、泄露个人信息
  - 第 44 条：网络运营者需建立安全管理制度
  - 第 63 条：违规处罚（警告、罚款、吊销许可、刑事责任）
- **《刑法》相关罪名**：
  - 第 285 条：非法侵入计算机信息系统罪
  - 第 286 条：破坏计算机信息系统罪
  - 第 287 条：利用计算机实施其他犯罪

> **核心原则**：知其功道，亦知其守道。所有硬件仅为**防御视角研究、授权渗透测试、教学演示**服务。

## 交叉引用导航

| 方向 | 相关页面 |
|------|----------|
| 无线/射频安全 | [[crypto-basics-xor-stream-cipher-tutorial]]（流密码与 WEP 弱点）、[[phishing-website-creation-tutorial]]（物理社工拓展） |
| 逆向/固件分析 | [[reverse-engineering-beginner-learning-path]]、[[ida-pro-tips-plugins-python]]、[[binary-ninja-ollvm-deobfuscation]] |
| 二进制利用/PWN | [[rop-linux-x86-beginner-tutorial]]、[[mtctf-2021-pwn-writeup]]、[[xihulunjian-2020-iot-pwn3-ezarmpwn-writeup]] |
| 浏览器/V8 漏洞 | [[v8-issue-944062-gc-arbitrary-write]]、[[v8-turbofan-changeint32toint64-1day-analysis]]、[[google-ctf-2021-full-chain-v8-exploitation]] |
| 内核/硬件底层 | [[linux-kernel-hardening-mechanisms]]、[[oo7-spectre-defense-binary-analysis]]、[[d3ctf-2021-d3dev-qemu-escape-writeup]] |
| 代码分析/克隆 | [[sourcerercc-code-clone-detection]] |

## 结语

0w1硬件图鉴以“低门槛、高上限、重合规”为宗旨，把原本昂贵、难获取的专业安全硬件变为社团成员可触达的学习资源。欢迎大家积累积分、借用设备、产出技术笔记，在**合法合规**前提下把手伸向三次元，探索软硬结合的安全边界。

---

> 页面维护：0w1Club 知识库策展组  
> 更新周期：随设备采购/规则调整同步更新  
> 来源归档：微信公众号「0w1Club」历史推文《0w1硬件图鉴》

## 来源

- [0w1网络安全俱乐部-201707-201903_34](../sources/0w1网络安全俱乐部-201707-201903_34.md)
