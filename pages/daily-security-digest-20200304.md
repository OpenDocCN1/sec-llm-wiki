---
title: 每日安全看点 2020-03-04
description: 汇总 2020 年 3 月 4 日每日安全看点，涵盖甲乙方职业感悟、默认密码查询网站、SOP 绕过技术、恶意程序在线沙箱、Nessus 规则库及
  CIA APT-C-39 对华长期渗透攻击披露
category: ai-security
tags:
- 每日安全看点
- 职业发展
- 默认密码
- SOP绕过
- 恶意软件分析
- Nessus
- APT-C-39
- CIA
- 威胁情报
- 2020年3月
date: 2020-03-04
updated: '2026-11-12'
---

## 概述

本期每日安全看点收录六条安全资讯与工具分享，涵盖职业发展思考、实用工具站点、浏览器安全技术、恶意代码分析平台、漏洞扫描规则库更新，以及重磅的 APT 攻击组织披露报告。

## 甲方与乙方职业感悟

> 来源：FreeBuf 文章《甲方 or 乙方》

文章从安全从业者视角剖析 **甲方（企业内部安全团队）** 与 **乙方（安全服务厂商）** 的工作差异、核心能力要求及职业发展路径，供安全人规划职业方向参考。

- 甲方侧重业务理解、风险治理体系建设、应急响应闭环
- 乙方侧重技术攻防深度、项目交付效率、工具化/平台化能力
- 两者技能栈有重叠但侧重点不同，跳槽需评估自身优势与长期目标

## 默认密码在线查询网站合集

> 来源：微信公众号分享

汇总多个**默认密码查询站点**，便于渗透测试、资产梳理、IoT 设备审计时快速核验弱口令风险。

| 站点 | 特点 |
|------|------|
| [Default Passwords](https://www.defaultpasswords.com/) | 厂商/型号检索，覆盖网络设备、数据库、CMS 等 |
| [RouterPasswords](http://www.routerpasswords.com/) | 专注路由器/交换机默认凭据 |
| [CIRT.net](https://cirt.net/passwords) | 按厂商分类，提供 CSV 导出 |
| [SecLists/Default-Credentials](https://github.com/danielmiessler/SecLists/tree/master/Passwords/Default-Credentials) | GitHub 维护的结构化凭据库，便于工具集成 |

> 💡 实战建议：结合 [[frp内网渗透应用]] 内网穿透场景，对发现的默认口令设备做进一步横向移动验证。

## SOP（同源策略）绕过技术解析

> 来源：Medium 文章《SOP Bypass》 by @kenanistaken

深度剖析**浏览器同源策略（Same-Origin Policy）绕过**的多种技术路径，适合 Web 安全研究者、CTF 选手及渗透测试人员阅读。

### 核心绕过向量

| 类别 | 典型手法 | 关键点 |
|------|----------|--------|
| 协议/端口/域名放宽 | `document.domain` 降级、宽泛 CORS 配置 | 仅限同一根域名下子域互通 |
| 浏览器特性滥用 | `postMessage` 未校验 origin、JSONP 劫持、WebSocket 跨域 | 需目标页面存在可利用的监听逻辑 |
| 客户端缓存/存储 | Service Worker 注入、本地存储 XSS、IndexedDB 污染 | 需结合 XSS 或中间人条件 |
| 插件/扩展机制 | 过时 Flash/Java Applet、浏览器扩展权限过大 | 现代浏览器已大幅收敛攻击面 |
| 服务端配置错误 | `Access-Control-Allow-Origin: *` 配合凭据模式、反射型 CORS 头 | 常见于 API 网关、CDN 错配 |

> 🔗 相关技术可结合 [[java-urlconnection-ssrf-protocol-bypass]] 中 SSRF 协议绕过思路，拓展跨域数据窃取链路。

## 恶意程序在线分析沙箱——sndbox

> 地址：https://app.sndbox.com/

**sndbox** 提供云端动态行为分析，上传可疑样本（PE、APK、Office、脚本等）即可获得：

- 进程树、网络通信（DNS/HTTP/C2）、文件系统变更、注册表操作
- MITRE ATT&CK 技术标签自动映射
- IOC 导出（IP、域名、哈希、文件路径、互斥量）
- 与 VirusTotal、威胁情报平台联动查重

### 适用场景

| 场景 | 说明 |
|------|------|
| 应急响应初筛 | 快速判断可疑文件恶意性，提取 IOC 入库 |
| 红队免杀验证 | 测试载荷在主流沙箱中的行为特征与检测率 |
| 威胁狩猎 | 批量分析蜜罐捕获样本，聚类同家族活动 |

> ⚠️ 注意：公共沙箱提交样本可能泄露红队武器化细节，核心武器建议搭建私有沙箱（如 Cuckoo、Cape、VMRay）离线分析。

## Nessus 2020 年 2 月规则库离线包

> 下载：百度网盘 `https://pan.baidu.com/s/1VO_cx3MV3kQfzDYV-AWgCA` 密码 `yue4`

提供 **Nessus Professional / Tenable.io** 2020-02 插件包离线更新文件，适用于**隔离网环境**或**无公网出口**的资产扫描场景。

### 离线导入步骤

```bash
# 1. 解压获得 nessus-plugin-feed.tar.gz
# 2. 导入命令（Linux 示例）
/opt/nessus/sbin/nessuscli update nessus-plugin-feed.tar.gz

# 3. 验证插件版本
/opt/nessus/sbin/nessuscli plugin-list | head -20
```

> 💡 配合 [[cve-digest-20200426]] 等漏洞聚合页面，可交叉核对规则库是否覆盖近期高危 CVE（如 CVE-2020-0796 SMBGhost、CVE-2020-1054 Windows 内核提权等）。

## 重磅披露：CIA APT-C-39 对华十一年网络渗透攻击

> 来源：微信公众号《披露美国中央情报局 CIA 攻击组织（APT-C-39）对中国关键领域长达十一年的网络渗透攻击》

中国网络安全机构联合发布详细技术报告，披露 **APT-C-39（关联 CIA）** 自 2008 年起持续针对中国航空航天、科研院所、石油能源、大型互联网企业、政府部门等关键领域实施定向渗透。

### 攻击链总览

```
初始入口 → 权限维持 → 横向移动 → 数据窃取 → 痕迹清理
   │           │           │           │           │
   ▼           ▼           ▼           ▼           ▼
0day/钓鱼  Rootkit/   凭据导出/   加密打包/   反取证/
  利用     启动项劫持  Pass-the-Hash  分块外传   日志篡改
```

### 核心 IOC 与 TTPs（节选）

| 类别 | 指标示例 |
|------|----------|
| C2 域名 | `update.microsofts.com`、`google-analytics-api.com` 等伪装合法服务域名 |
| 木马家族 | **FlaseFont**、**ShadowPad** 变种、**PlugX** 定制版、**Carbon** 后门 |
| 利用漏洞 | CVE-2017-0199 (Office)、CVE-2018-8174 (VBScript)、CVE-2019-0708 (BlueKeep) 等 N-day |
| 横向工具 | 定制版 Mimikatz、WMIExec、PSExec、SharpHound、BloodHound 数据采集 |
| 反取证 | 事件日志清除、USN Journal 删除、时间戳篡改、文件级加密存储 |

### 归因关键证据

- 编译时间与美东时区一致，代码注释含英语母语特征
- C2 基础设施与 Vault 7 泄露工具集（Hive、Grasshopper）重叠
- 目标选择高度符合美情报优先级清单（PCD - Priority Collection Requirements）
- 攻击基础设施与 Equation Group、APT-C-06 共享代码签名证书

### 防御建议

| 层面 | 措施 |
|------|------|
| 资产暴露面收敛 | 互联网资产梳理、高危端口/服务下线、零信任网关接入 |
| 终端检测响应 (EDR) | 部署行为分析型 EDR，开启内存保护、凭据防护、AMSI 集成 |
| 威胁情报驱动 | 接入 APT-C-39 相关 IOC 威胁情报库，SIEM 联动告警 |
| 红蓝对抗演练 | 模拟 APT-C-39 TTPs 开展紫队演练，验证检测盲区 |
| 供应链安全 | 软件分发签名验证、依赖组件 SBOM 审计、防止供应链投毒 |

> 🔗 该披露属于国家级 APT 组织长期攻击案例，可对比学习 [[mercedes-benz-mbux-vulnerabilities-2021]] 等供应链/定向攻击分析方法论。

## 关联阅读

- [[daily-security-digest-20200306]] — 3 月 6 日看点：恶意软件分析公开课、POC 编写、ThinkPHP 防御、DNS 渗透、AFL++ Fuzzing
- [[daily-security-digest-20200309]] — 3 月 9 日看点：Java 白盒审计 Hades、Voyager 工具平台、TCL 电视 IoT PWN、漏洞赏金案例
- [[daily-security-digest-20200311]] — 3 月 11 日看点：SRC 漏洞挖掘、IoT 实验室搭建、逆向二进制书籍推荐
- [[daily-security-digest-20200312]] — 3 月 12 日看点：wget CVE 分析、渗透测试实战、JSC/WebKit 架构、漏洞挖掘技巧
- [[daily-security-digest-20200316]] — 3 月 16 日看点：Linux 内核调试、NETGEAR RCE、V8 利用、SSH 蠕虫、SMBGhost 分析
- [[daily-security-digest-20200317]] — 3 月 17 日看点：CVE-2020-0768 ChakraCore、苹果剪贴板隐私、VSCode RCE 隐患
- [[daily-security-digest-20200318]] — 3 月 18 日看点：Win10 Exp 合集、ATT&CK 欺骗防御、fastjson/Shiro/Weblogic 反序列化复现

## 小结

本期看点呈现**「工具实用 + 技术深度 + 威胁情报」**三维度内容：
- 职业规划类文章助力安全人明确能力建设方向
- 默认密码库、在线沙箱、Nessus 离线包为实战提效
- SOP 绕过技术拓展浏览器安全攻防视野
- APT-C-39 披露为国家级网络对抗提供珍贵技术样本，值得深入复盘并转化为防御规则与演练场景

建议安全团队将 APT-C-39 IOC 纳入威胁情报平台，结合 ATT&CK 矩阵补全检测规则，并开展针对性紫队演练验证防御有效性。

## 来源

- [0th3rs安全团队-201911-202204_069](../sources/0th3rs安全团队-201911-202204_069.md)
