---
title: 每日安全看点 2020-01-14
description: 汇总 2020 年 1 月 14 日每日安全看点，涵盖 IoT 逆向函数识别、Citrix CVE-2019-19781 目录遍历、小米路由器
  R3G 漏洞 POC、伪造 Win10 锁屏钓鱼、Shellcode 编写总结、CSRF 攻击防御原理及浏览器利用资料等安全动态。
category: ai-security
tags:
- 每日安全看点
- IoT安全
- 逆向工程
- Citrix
- CVE-2019-19781
- 小米路由器
- 钓鱼攻击
- Shellcode
- CSRF
- 浏览器利用
date: 2020-01-14
updated: '2026-11-12'
---
## 概览

本期每日安全看点聚焦于物联网逆向工程、企业级 VPN 漏洞、路由器固件漏洞、客户端钓鱼技术、底层 Shellcode 开发、Web 安全基础防御以及浏览器利用技术资料库七大方向，为安全研究人员提供技术参考与实战资源。

## IoT 设备逆向工程：函数识别技术

**来源**：[NSFOCUS 博客 - IoT设备逆向工程中的函数识别](http://blog.nsfocus.net/function-recognition-reverse-engineering-iot-equipment/#3_lscan)

文章系统阐述 IoT 固件逆向分析中函数识别的核心难点与解决思路，涵盖静态特征匹配、动态执行追踪、机器学习辅助识别等多维方法论，适用于路由器、摄像头等嵌入式设备固件分析场景。

> 关联阅读：[[secquan-bugwarning-1071987-device-credential-leak]] 中的 IoT 设备凭证泄露案例、[[daily-security-digest-20200309]] 涉及的 TCL 电视 IoT PWN 实战。

## Citrix ADC 目录遍历漏洞 (CVE-2019-19781)

**来源**：[CISA 官方检测脚本](https://github.com/cisagov/check-cve-2019-19781)

CVE-2019-19781 影响 Citrix ADC (NetScaler) 和 Citrix Gateway，未经身份验证的攻击者可通过目录遍历读取任意文件，进而实现远程代码执行。CISA 发布的检测脚本支持主动扫描与被动流量特征匹配，建议资产管理纳入常态化巡检。

> 关联背景：[[cve-digest-20200426]] 等 CVE 聚合页面持续跟踪企业级网关类漏洞利用代码公开情况。

## 小米路由器 R3G 双 CVE 漏洞 POC

**来源**：[Xiaomi_Mi_WiFi_R3G_Vulnerability_POC](https://github.com/UltramanGaia/Xiaomi_Mi_WiFi_R3G_Vulnerability_POC)

项目公开两个影响小米路由器 R3G 的漏洞利用代码，涉及栈溢出与命令注入，均可在未授权或低权限条件下获取设备 Root Shell。固件版本覆盖范围广，建议设备管理员尽快升级或关闭公网管理端口。

> 扩展视角：[[daily-security-digest-20200311]] 提及的自建 IoT 实验室指南可用于复现验证此类路由器漏洞。

## 伪造 Windows 10 锁屏界面钓鱼工具 - SharpLocker

**来源**：[SharpLocker](https://github.com/Pickfordmatt/SharpLocker)

SharpLocker 利用 C# 实现高仿真 Win10 锁屏界面，支持自定义背景、时间同步、PIN/密码输入捕获，结合社会工程学可实现实体接触场景下的凭证窃取。工具未使用恶意签名，杀软静态查杀率较低，红队演练可参考其 UI 欺骗实现细节。

> 关联专题：[[daily-security-digest-20200217]] 分析的新冠主题钓鱼攻击、[[remote-work-security-covid19-20200210]] 中的远程办公钓鱼防范建议。

## Shellcode 编写过程总结

**来源**：[先知社区 - shellcode编写过程总结](https://xz.aliyun.com/t/7072)

文章从汇编基础、系统调用号查找、字符串构造、空字节规避、编码加密、测试验证六个阶段完整复现 Linux x86/x64 Shellcode 开发生命周期，附带 NASM 编译与 C 语言测试框架代码，适合漏洞利用开发入门者系统学习。

> 进阶资源：[[daily-security-digest-20200303]] 收录的红队 Shellcode 启动器技术、[[daily-security-digest-20200117]] 中的 QEMU PWN 入门教程。

## CSRF 攻击防御原理深度解析

**来源**：[FreeBuf - CSRF攻击防御原理](https://www.freebuf.com/articles/web/224446.html)

文章从同源策略、Cookie SameSite 属性、双重提交 Cookie、自定义请求头、验证码/二次认证五个维度系统梳理 CSRF 防御体系，对比了各方案在现代浏览器环境下的有效性与局限性，提供 Java 与 Python 中间件层面的通用防护代码片段。

> 关联漏洞：[[cve-digest-20210402]]、[[cve-digest-20210408]] 等 CVE 聚合中多次出现 CSRF 组合利用链（如 Jenkins、Grav Admin 等组件）。

## 浏览器利用技术资料库

**来源**：[LiveOverflow - Browser Exploitation 标签页](https://liveoverflow.com/tag/browser-exploitation/)

LiveOverflow 持续更新的浏览器漏洞利用视频与文章系列，覆盖 V8/SpiderMonkey/JavaScriptCore 引擎内部机制、JIT 编译优化缺陷、堆喷射与堆风水、WASM 安全、沙箱逃逸等前沿专题，配套完整 PoC 代码仓库，是浏览器安全研究者的核心学习资源之一。

> 国内同步跟进：[[daily-security-digest-20200120]] 整理的浏览器利用资料库、IE 0day CVE-2020-0674 分析、[[daily-security-digest-20200316]] 中的 V8 引擎利用入门资源。

## 相关页面交叉引用

| 主题 | 关联页面 | 关联点 |
|------|----------|--------|
| IoT 固件逆向 | [[secquan-bugwarning-1071987-device-credential-leak]]、[[daily-security-digest-20200309]]、[[daily-security-digest-20200311]] | 设备凭证泄露、TCL 电视 PWN、自建 IoT 实验室 |
| 企业级网关漏洞 | [[cve-digest-20200426]]、[[cve-digest-20210325]] | CVE 聚合中的 Citrix/网关类漏洞跟踪 |
| 路由器漏洞复现 | [[daily-security-digest-20200311]] | IoT 实验室搭建指南 |
| 客户端钓鱼技术 | [[daily-security-digest-20200217]]、[[remote-work-security-covid19-20200210]] | 钓鱼攻击分析、远程办公防范 |
| Shellcode 开发 | [[daily-security-digest-20200303]]、[[daily-security-digest-20200117]] | 红队 Shellcode 启动器、QEMU PWN 教程 |
| CSRF 防御体系 | [[cve-digest-20210402]]、[[cve-digest-20210408]] | 组件级 CSRF 漏洞案例 |
| 浏览器利用研究 | [[daily-security-digest-20200120]]、[[daily-security-digest-20200316]] | 浏览器安全资料库、V8 利用入门 |

## 来源

- [0th3rs安全团队-201911-202204_095](../sources/0th3rs安全团队-201911-202204_095.md)
