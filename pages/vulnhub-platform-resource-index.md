---
title: VulnHub 靶场平台资源索引
description: 汇总 VulnHub 靶场平台介绍、750+ 镜像资源合集（1053G）及知识库现有 Writeup 交叉引用，提供靶机获取方式、实战建议与学习路径指引。新增
  AdmX_new 靶机 Writeup 交叉引用，完善实战练习库。
category: program-analysis
tags:
- VulnHub
- 靶场
- 渗透测试
- OSCP备考
- 实战练习
- 资源合集
- Writeup索引
- WordPress
- MySQL UDF
- 插件上传
- 无名安全团队
date: '2025-01-15'
updated: '2026-11-14'
---

## 平台简介

**VulnHub** 是一个面向渗透测试学习者的漏洞靶机分享平台，官网地址：[https://www.vulnhub.com/](https://www.vulnhub.com/)。

平台提供数百个预配置的虚拟机镜像，涵盖 Web 应用漏洞、系统服务漏洞、权限提升、后渗透等实战场景，是巩固安全知识体系、锻炼红队攻防思维、备考 OSCP 等实战认证的核心资源库。

## 资源合集概览

| 指标 | 数值 |
|------|------|
| **镜像总数** | 750+ 个 |
| **存储总量** | 1053 GB |
| **文件组织** | 单层文件夹结构，无先后顺序分类（后期为便于上传网盘与统计整理） |
| **获取方式** | 百度网盘，后台回复 `0801` 获取链接（因阿里云盘不支持分享压缩包） |

> **提示**：原分享者曾开通迅雷会员分批下载，耗时数天完成全量归档。建议使用支持断点续传的下载工具。

## 运行环境建议

- **首选**：**VirtualBox** —— 兼容性最佳，官方镜像多基于 VirtualBox 导出（OVA/OVF 格式）。
- **备选**：VMware Workstation / Fusion —— 可用，但偶尔会出现网络适配器识别异常、USB 设备透传失败等“奇怪问题”。

> 导入镜像后，请优先检查网络模式（NAT / Host-Only / Bridged）是否与靶机预期一致，部分靶机需特定网段才能触发漏洞。

## 学习与实战建议

1. **先自主攻坚，再参考 Writeup**  
   建议按“信息收集 → 漏洞挖掘 → 利用上线 → 权限提升 → 横向移动”完整链路自主实战；仅在遇到瓶颈、长时间无进度时，再通过 Google / 百度搜索对应靶机 Writeup。

2. **按技能模块分批次练习**  
   - Web 方向：CMS 漏洞、文件上传绕过、SQL 注入、模板注入、反序列化等  
   - 系统方向：内核提权、SUID/Capabilities 滥用、计划任务劫持、Docker 逃逸等  
   - 二进制方向：栈溢出、ROP 链构造、格式化字符串、堆利用等  
   - 综合场景：多阶段渗透、内网隧道、域环境横向

3. **配合证书备考**  
   VulnHub 靶机难度跨度大，适合 OSCP、PNPT、CRTO 等实战认证的赛前热身与技能查漏补缺。

## 知识库现有 Writeup 交叉引用

本知识库已整理以下 VulnHub 靶机的完整复现文档，可作为实战参考或对照学习：

| 靶机名称 | 难度侧重 | 核心技术点 | 页面链接 |
|----------|----------|------------|----------|
| **AdmX_new** | 中等 | WordPress 后台弱口令爆破、插件上传 Getshell、Python 反弹 Shell、MySQL UDF 提权 | [[vulnhub-admx-new-writeup]] |
| **Glasgow Smile** | 中等 | Joomla CMS 爆破、反弹 Shell、多层编码密码破解、定时任务提权 | [[glasgowsmile-vulnhub-writeup]] |
| **BBS Cute 102** | 中等 | CuteNews 2.1.2 RCE、GIF89 头绕过上传、PHP 反弹 Shell、提权思路 | [[vulnhub-bbs-cute-102-writeup]] |
| **Hard Socnet2** | 高难 | 文件上传、SQL 注入、XML-RPC 暴破、CVE-2021-3493 内核提权、add_record 缓冲区溢出（PEDA/GDB/ROP） | [[vulnhub-hard-socnet2-writeup]] |
| **Infosecprep: OSCP** | 入门/中等 | WordPress 枚举、目录遍历、Base64 解码 SSH 私钥、SUID bash 提权（`bash -p`） | [[vulnhub-infosecprep-oscp-writeup]] |
| **DOUBLETROUBLE** | 中等 | Shellshock (CVE-2014-6271) CGI-BIN 利用、Dirty COW (CVE-2016-5195) 本地提权 | [[vulnhub-doubletrouble-writeup]] |
| **Pwned** | 中等 | Web枚举、FTP凭证复用、SSH密钥登录、sudo误配置提权、Docker组权限逃逸 | [[vulnhub-pwned-writeup]] |
| **DarkHole2** | 中等 | Git源码泄露审计、SQL注入、SSH登录、Webshell反弹Shell、sudo提权 | [[vulnhub-darkhole2-writeup]] |

> **关联技术文档**：  
> - [[peda-buffer-overflow-analysis-guide]] 以 `hard-socnet2` 的 `add_record` 二进制为实战案例，详细演示 PEDA 插件在 Linux 缓冲区溢出分析中的完整流程（偏移定位、ROP 链构造、提权）。  
> - 以上 Writeup 覆盖了 Web 渗透、二进制利用、内核提权、后渗透等核心环节，建议结合阅读。

## 资源获取步骤

1. 关注原发布公众号（文章来源：微信公众号归档）。
2. 后台回复关键字 **`0801`**。
3. 获取百度网盘分享链接及提取码。
4. 下载解压后，按需导入 VirtualBox 开始实战。

> **版权与合规提醒**：靶机镜像仅供个人学习、教学研究与授权渗透测试使用，请勿用于未授权目标。下载后建议在隔离网络环境（Host-Only / 内部靶场网段）中运行。

## 扩展阅读与社区资源

- **官方社区**：VulnHub 官网每个靶机页面均有用户提交的 Writeup 与讨论区。
- **聚合索引站**：  
  - [VulnHub Writeups (GitHub Awesome 列表)](https://github.com/gnxlr/vulnhub-writeups)  
  - [VulnHub 靶机分类标签页](https://www.vulnhub.com/tags/)（按难度、发布年份、技术标签筛选）
- **视频实战系列**：YouTube / B 站搜索靶机名称 + `walkthrough` 或 `writeup`，多为逐步演示，适合入门跟练。

---

> **维护说明**：本页面将随知识库新增 VulnHub 相关 Writeup 持续更新交叉引用。如发现链接失效或有新靶机复现文档入库，请在对应页面编辑时同步维护此索引。

## 来源

- [0x00实验室-202108-202304_074](../sources/0x00实验室-202108-202304_074.md)
