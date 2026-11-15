---
title: HW 红队演练作战手册：环境隔离、工具指纹清洗、上线隐匿、日志反取证与团队协作规范
description: 沉淀自实战归档文章《HW:一切为了不丢分》，系统梳理红队演练（HVV/HW）全流程作战守则：工作环境物理/逻辑隔离、渗透工具指纹清洗与流量加密、C2
  上线隐匿参数化、内网代理隧道 SSL 化、日志反取证覆盖删除、账号全生命周期管理、蜜罐识别心态建设及团队协作红绿叶法则，形成可落地的 OPSEC 标准化检查清单。
category: program-analysis
tags:
- HW
- 红队演练
- HVV
- OPSEC
- 环境隔离
- 工具指纹清洗
- 上线隐匿
- 日志反取证
- 团队协作
- Cobalt Strike
- C2 隐匿
- 内网渗透
date: 2024-01-15
updated: '2026-11-15'
---

## 核心原则

> **攻防演习成功的关键是团队协作，要互相帮助学习和进步，不要勾心斗角，每个团队的成功都需要有人当红花有人当绿叶的，外网打点与内网渗透同等重要。**

## 一、 工作环境隔离体系

### 物理与逻辑分层

| 层级 | 要求 | 备注 |
|------|------|------|
| **宿主机** | 必须安装安全防护软件、打最新补丁、卸载公司特定软件 | 物理隔离基线 |
| **渗透虚拟机** | 全程走代理 IP 上网；不登录 QQ/微信/网盘/CSDN 等个人账号 | 核心作战环境 |
| **开发/调试环境** | 与渗透环境完全分离 | 编译、测试、调试工具链隔离 |
| **样本分析环境** | 从目标下载的程序必须在单独环境运行 | 防止供应链反制 |

### 网络出口策略

- **首选**：移动 4G 网卡 → 虚拟机再接代理
- **禁用**：公司网络出口直连
- **代理链**：`物理机 4G → 代理 IP → 目标`，全链路无公司出口特征

### 账号与协作平台卫生

- fofa、cmd5、天眼查等第三方平台账号密码**不得**与公司关联
- 云协作平台（GitHub、Notion、飞书等）同理，使用独立身份

## 二、 渗透工具指纹清洗与加固

### WebShell 管理规范

| 类型 | 要求 | 推荐实现 |
|------|------|----------|
| **一句话木马** | 严禁使用普通明文一句话 | — |
| **蚁剑** | 连接端必须启用加密流量模块 | `encoder` / `decoder` 自定义 |
| **冰蝎** | 禁止使用默认版本，**必须硬编码密钥**重编译 | `pom.xml` 修改 `secretKey` 后 `mvn package` |
| **哥斯拉** | 同冰蝎，需自定义 AES 密钥与请求头特征 | 参考 [[php-webshell-fundamentals-chopper-analysis]] 哥斯拉章节 |

### 公开工具去特征化清单

| 工具 | 必清洗指纹 | 典型手段 |
|------|------------|----------|
| **sqlmap** | User-Agent、请求头顺序、报错特征 | `--random-agent`、 `--headers`、 `--tamper`、 `--delay` |
| **masscan** | 发包频率、源端口范围、Banner | `--rate 100`、 `--source-port`、 `--banners` 关闭 |
| **Cobalt Strike Beacon** | 默认证书、Malleable Profile 特征、Sleep 时间 | 替换证书、定制 Profile、设置 `sleep > 500s` |
| **fscan / Ladon** | User-Agent、指纹库版本、输出格式 | 重编译修改 UA、更新指纹库、JSON 输出解析 |

> **参数化限速**：所有扫描/爆破工具**必须**设置线程或访问频率（如 sqlmap `--delay 2`、内网扫描线程 ≤ 5），避免流量异常触发蓝队告警。

### 自研工具上传策略

- **尽量不上传**内部自研工具/脚本
- 必须上传时：重命名为系统进程名（如 `svchost.exe`、`lsass.exe`、`dllhost.exe`），修改 PE 元数据（版本信息、签名、时间戳）
- 优先使用 LOLBins / 系统自带二进制（`certutil`、`bitsadmin`、`mshta`、`regsvr32` 等）

## 三、 C2 上线隐匿与通道加密

### 域名与 CDN 前置

- **RAT/C2 域名必须套 CDN**（Cloudflare、阿里云 CDN、腾讯云 CDN 等）
- 域名注册信息匿名化，Whois 隐私保护
- 备选：Domain Fronting（参考 [[c2-redirectors-malleable-c2-profiles]] 域名前置章节）

### Cobalt Strike 关键硬化参数

```ini
# Malleable C2 Profile 关键片段
set sleeptime "600000";          # > 500 秒，降低心跳频次
set jitter "30";                 # 30% 抖动
set maxdns "255";                # DNS 隧道最大长度
set dns_idle "8.8.8.8";          # 空闲 DNS 解析噪音
set dns_sleep "0";               # DNS 模式下 sleep 0
http-config {
    set headers "Server: nginx"; # 伪装 Web Server
    header "X-Powered-By" "PHP/7.4";
}
```

### 内网代理隧道 SSL 化

| 场景 | 方案 | 关键点 |
|------|------|--------|
| **SOCKS 代理** | `stinger_server.exe` + `stinger_client` + `proxy.php` | 全链路 SSL/TLS，参考 [[pystinger-socks4-proxy-webshell-pivoting]] |
| **HTTP 代理** | `goproxy` + `netsh portproxy` | DMZ 主机开 HTTP 代理，端口映射转发，参考 [[http-proxy-tunneling-goproxy-netsh]] |
| **SMB Beacon** | 命名管道 + External C2 | 防火墙默认放行，参考 [[smb-named-pipe-c2-communication]]、[[cobalt-strike-external-c2-smb-beacon]] |
| **FRP / reGeorg / nps** | 自建中转 | 证书自签、开启 `tls_only=true`、隐藏 Banner |

> **原则**：**内网渗透时尽量使用 socks 代理，在本地操作**，避免在跳板机落地二进制。

## 四、 日志反取证与痕迹清理

### 删除方式分级

| 级别 | 手法 | 适用场景 | 可恢复性 |
|------|------|----------|----------|
| **L1** | `del /f /q` / `rm -f` | 临时文件、非关键日志 | 易恢复（文件系统未覆盖） |
| **L2** | `cipher /w:C:\` / `shred -n 3 -z` | 关键二进制、WebShell、凭据导出文件 | 难恢复（多次覆盖） |
| **L3** | **仅删除指定 Event ID**（`wevtutil cl System /q` 结合 XPath 过滤） | Windows 安全/系统/应用日志 | 痕迹最小，蓝队难发现缺口 |
| **L4** | 篡改 `$MFT` / `$LogFile` / `USN Journal` | 极高隐匿需求 | 需内核驱动配合，风险高 |

> **实战口诀**：清理日志时需要以**文件覆盖的方式删除文件**，防止数据恢复，或者仅删除指定 ID 的日志。

### 常见日志清理命令速查

```cmd
:: Windows 安全日志仅删除 4624/4625/4688/4672
wevtutil qe Security /q:"*[System[(EventID=4624 or EventID=4625 or EventID=4688 or EventID=4672)]]" /f:text /rd:true /c:1 | findstr "Event\[0-9\]" | for /f "tokens=2 delims=[]" %i in ('findstr /n "^"') do wevtutil qe Security /q:"Event[System[EventRecordID=%i]]" /f:text && wevtutil cl Security /bu:C:\backup.evtx

:: 覆盖删除 WebShell
for /l %i in (1,1,3) do type nul > shell.php && cipher /w:.
```

### Linux 端清理

```bash
# 仅清除特定会话记录
sed -i '/192.168.1.100/d' /var/log/auth.log
sed -i '/sshd.*Accepted password/d' /var/log/secure

# 覆盖删除关键文件
shred -n 3 -z -u /tmp/exploit.py
```

## 五、 账号全生命周期管理

### 登录与持久化策略

| 动作 | 推荐做法 | 禁忌 |
|------|----------|------|
| **3389 登录** | 优先激活 `Guest`、`DefaultAccount` 等低权限内置账号 | 直接新建 `admin888`、`qax`、`qaxNB` 等显眼账号 |
| **必须新建** | 账号名与目标业务相关（如 `sql_svc`、`web_bak`、`iis_user`） | 使用友商关键词、拼音、弱口令特征名 |
| **权限维持** | 注册表 `Run`/`RunOnce`、计划任务、WMI 订阅、SSP、ACL 修改 | 单一持久化点、高频心跳 |
| **凭据清理** | 任务结束后**必须**删除账号、注销会话、清理 `NTDS.dit` 导出残留 | 留存影子用户、Skeleton Key、Golden Ticket |

### 影子账户与 SID History 技巧

- 创建账户后 `net localgroup administrators /add <user>` 立即 `net user <user> /active:no` 隐藏
- 利用 `SID History` 注入高权限 SID，配合 `msDS-AllowedToActOnBehalfOfOtherIdentity` 实现资源委派（参考 [[xd-security-internal-network-penetration-notes-day67-68]] PTH/PTK/PTT 章节）

## 六、 蜜罐识别与心态建设

> **碰到蜜罐就不要慌，多喝点花茶，这样死了会比较香。**

### 典型蜜罐特征库

| 类型 | 识别指标 | 应对 |
|------|----------|------|
| **低交互** | 端口全开、Banner 固定、无真实文件系统、响应延迟恒定 | 指纹识别阶段即标记，不深入利用 |
| **高交互** | 真实 OS、有诱饵文档、部署 EDR/日志审计、蜜签账号 | 发现异常进程/驱动/网络连接立即断联，清理痕迹撤离 |
| **蜜签** | `admin`/`administrator` 登录即触发告警、文件服务器含 `flag.txt`/`password.xlsx` | 账号枚举阶段通过 `net user /domain` 对比最后登录时间识别 |
| **流量蜜罐** | DNS/HTTP 请求被镜像、ICMP 回包异常、TLS 指纹被记录 | 全链路加密、Domain Fronting、随机化 Sleep/Jitter |

### 遭遇蜜罐后的标准动作

1. **立即停止**一切主动探测/利用动作
2. **断开**当前 C2 通道，切换备用通道或物理断网
3. **执行**预置的紧急清理脚本（覆盖删除、日志篡改、进程自杀）
4. **汇报**组长，记录蜜罐特征入库，更新团队威胁情报（参考 [[0x6270-hvv-vulnerability-threat-intelligence]]）
5. **复盘**暴露面，调整后续作战计划

## 七、 团队协作红绿叶法则

### 角色分工矩阵

| 角色 | 核心职责 | 关键交付物 | 协作接口 |
|------|----------|------------|----------|
| **红花（外网打点）** | 资产收集、漏洞验证、WebShell 获取、边界突破 | 可用入口清单、凭据、WebShell 地址 | 向绿叶移交会话/凭据/拓扑 |
| **绿叶（内网渗透）** | 横向移动、域控拿下、数据窃取、持久化 | 域控权限、核心数据、持久化方案 | 向红花反馈边界防护薄弱点 |
| **指挥/情报** | 目标画像、威胁情报、作战计划、风控决策 | 行动命令、蜜罐预警、工具分发 | 双向同步态势 |
| **工务/保障** | 环境维护、工具改马、证书申请、代理搭建、日志清理脚本 | 免杀 Loader、Malleable Profile、代理集群 | 按需响应红绿叶技术需求 |

### 信息同步最小集

- **每日站会**：进度、卡点、蜜罐遭遇、蓝队动态
- **共享仓库**（加密）：目标拓扑图、凭据库、可用 C2 通道、工具版本库
- **应急熔断词**：一旦触发，全组静默 30 分钟，仅指挥组决策

## 八、 标准化检查清单（每日/每阶段）

| 阶段 | 检查项 | 通过标准 |
|------|--------|----------|
| **环境准备** | 宿主机补丁/杀软/卸载公司软件 | ✅ 全绿 |
| | 虚拟机快照纯净、代理可用、无个人账号 | ✅ |
| | 第三方平台账号独立、云协作平台隔离 | ✅ |
| **工具上线** | WebShell 加密连接、冰蝎/哥斯拉硬编码密钥 | ✅ |
| | 公开工具去特征、限速参数生效 | ✅ |
| | 自研工具重命名、PE 元数据清洗 | ✅ |
| **C2 部署** | 域名套 CDN、证书有效、Profile 定制 | ✅ |
| | Sleep > 500s、Jitter ≥ 30%、Header 伪装 | ✅ |
| | 内网代理 SSL/TLS、SMB Beacon 命名管道可用 | ✅ |
| **作战中** | 上传文件/创建账号/修改配置全记录 | ✅ 台账完整 |
| | 敏感操作后执行日志覆盖删除 | ✅ 无残留 |
| | 遭遇异常立即熔断、汇报、清理 | ✅ 响应 < 5min |
| **收尾** | 所有 WebShell/账号/计划任务/注册表清理 | ✅ 复查无遗漏 |
| | 目标服务器日志指定 ID 删除/覆盖 | ✅ 蓝队溯源无关键链 |
| | 团队复盘产出《作战复盘报告》入库 | ✅ 知识沉淀 |

## 九、 交叉引用技术图谱

| 领域 | 核心页面 | 关联章节 |
|------|----------|----------|
| **C2 基础设施隐匿** | [[c2-redirectors-malleable-c2-profiles]] | 域名前置、CDN、Malleable Profile 实战 |
| | [[cobalt-strike-external-c2-smb-beacon]] | External C2、SMB Beacon、命名管道通信模型 |
| | [[http-proxy-tunneling-goproxy-netsh]] | goproxy + netsh 端口转发隧道 |
| | [[pystinger-socks4-proxy-webshell-pivoting]] | WebShell SOCKS4 代理转发链 |
| **内网渗透与横向移动** | [[internal-network-pivoting-techniques]] | atexec、PrintSpooler、FRP、SpawnReflectiveC2 |
| | [[xd-security-internal-network-penetration-notes-day65-66]] | 域信息收集、at/schtasks/impacket 横向 |
| | [[xd-security-internal-network-penetration-notes-day67-68]] | PTH/PTK/PTT、黄金/白银票据、Mimikatz/Kekeo |
| | [[xd-security-internal-network-penetration-notes-day69-70]] | Cobalt Strike 团队服务器、Kerberoasting、SOCKS/Frp/Ngrok 隧道 |
| **免杀与对抗** | [[memory-scanning-tools-evasion-techniques]] | Hunt-Sleeping-Beacons、BeaconHunter、FOLIAGE/Ekko/AceLdr/Inceptor 对抗 |
| | [[ppl-injection-createprocess-bof-fix]] | PPL 注入、bInheritHandles 绕过、BOF 文件落地输出 |
| | [[process-injection-tampering-techniques]] | Hollowing/Doppelganging/Ghosting/Herpaderping/Transacted Hollowing 对比 |
| **日志与取证对抗** | [[xd-security-incident-response-notes]] | Web 攻击溯源、Webshell 排查、勒索病毒处置、自动化工具箱 |
| | [[threat-attribution-tracing-techniques]] | IP 定位、钓鱼邮件反查、VPS 渗透溯源、样本沙箱分析 |
| **WebShell 与免杀** | [[php-webshell-fundamentals-chopperanalysis]] | 蚁剑/菜刀/哥斯拉流量特征、Content-Type 绕过、CNVD-2021-49104 实战 |
| | [[php-webshell-obfuscation-av-evasion]] | C++ 两阶段混淆、GBByPass Unicode 编码、主流 AV 绕过测试 |
| **团队与流程** | [[0x6270-hvv-vulnerability-threat-intelligence]] | HVV 威胁情报汇总、知识星球分享渠道 |
| | [[xd-security-pentest-basic-stage-notes]] | 渗透测试基础阶段 24 天知识清单 |
| | [[xd-security-waf-bypass-techniques-day46-49]] | 安全狗/宝塔/阿里云 WAF 绕过策略、代理池、Payload 变异 |

## 十、 版本演进与维护建议

| 版本 | 日期 | 核心变更 | 维护人 |
|------|------|----------|--------|
| 1.0 | 2024-01-15 | 初版：沉淀《HW:一切为了不丢分》全文结构化 | 知识库策展人 |
| 1.1 | 2024-03-?? | 新增：蜜罐特征库、标准化检查清单、交叉引用图谱 | — |
| 2.0 | 2024-06-?? | 计划：接入实战复盘案例、自动化清理脚本库、蓝队视角对抗矩阵 | — |

> **维护原则**：每次 HW/HVV 实战复盘后 **必须** 更新检查清单与蜜罐特征库，工具指纹清洗清单随主流工具版本迭代同步更新，团队协作流程随人员变动动态调整。

---

**标签**：`#HW` `#红队演练` `#HVV` `#OPSEC` `#环境隔离` `#工具指纹清洗` `#上线隐匿` `#日志反取证` `#团队协作` `#Cobalt Strike` `#C2隐匿` `#内网渗透`

## 来源

- [226安全团队-201805-202103_03](../sources/226安全团队-201805-202103_03.md)
