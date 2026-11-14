---
title: CTFshow Web 入门第 1-28 关：信息收集与爆破专题 Writeup
description: 系统梳理 CTFshow Web 入门关卡（第 1-28 关）中信息收集与爆破类题目的核心技术点，涵盖源码泄露、版本控制残留、编辑器缓存、Cookie/域名/邮箱信息利用、探针
  phpinfo、前端硬编码、ASP/Access 数据库下载、Basic Auth 爆破、子域名枚举、PHP mt_rand 种子预测与 php_mt_seed
  破解、MySQL 空连接尝试、身份证/目录爆破等实战技巧，构建 Web 入门攻防知识体系。
category: program-analysis
tags:
- CTF
- Web
- Information Gathering
- Brute Force
- CTFshow
- Writeup
- PHP
- Source Code Leakage
- Version Control
- Editor Cache
- Cookie
- Domain
- Email
- phpinfo
- Frontend Hardcoding
- ASP
- Access
- Basic Auth
- Subdomain Enumeration
- mt_rand
- php_mt_seed
- MySQL
- ID Card
- Directory Brute Force
date: '2021-10-25'
updated: '2026-11-14'
---
## 概述

本页面整理自「无名安全团队」微信公众号归档文章《CTFshou-WEB入门-信息收集|爆破》，覆盖 CTFshow 平台 Web 入门第 1-28 关。题目围绕**信息收集**与**爆破**两大核心主题，涉及源码泄露、版本控制残留、编辑器缓存、Cookie/域名/邮箱信息利用、探针 phpinfo、前端硬编码凭证、ASP/Access 数据库下载、Basic Auth 爆破、子域名枚举、PHP `mt_rand` 种子预测与 `php_mt_seed` 破解、MySQL 空连接尝试、身份证号/目录爆破等实战技巧。旨在为 Web 安全入门者构建系统化的攻防知识体系，并通过交叉引用关联现有知识库页面，形成完整的技能树。

## 一、 信息收集技术谱系

### 源码泄露与备份文件

| 关卡 | 核心技术点 | 利用方式 | 备注 |
|------|------------|----------|------|
| Web-1 | 前端源码查看 | 直接右键查看网页源代码 / F12 Elements 面板 | 基础信息收集 |
| Web-2 | 禁用右键/F12 绕过 | URL 前加 `view-source:` 协议头 | 浏览器内置协议绕过前端限制 |
| Web-5 | `.phps` 源码文件泄露 | 直接访问 `index.phps` 下载 PHP 源码 | `.phps` 为 PHP 源码着色文件，常因误配置暴露 |
| Web-6 | 整站压缩包泄露 | 访问 `www.zip` 下载源码，再访问提示的 `fl000g.txt` | 运维误将测试压缩包部署至生产环境 |
| Web-14 | 编辑器组件目录遍历 | 访问 `/editor` 触发默认配置遍历服务器根目录，通过图片上传功能获取完整目录树，定位 flag 文件 | 幂编辑器默认配置不安全导致目录遍历 |

> **关联延伸**：源码泄露是代码审计的前置条件，后续可结合 [[vulnhub-darkhole2-writeup]] 中的 Git 源码泄露审计流程、[[huxiangbei-willphp-file-inclusion-writeup]] 中的框架漏洞代码审计思路进行深化。

### 版本控制系统残留

| 关卡 | VCS 类型 | 利用路径 | 说明 |
|------|----------|----------|------|
| Web-7 | Git | 访问 `/.git/index.php` 直接获取 flag | 生产环境未清理 `.git` 目录，可通过工具（如 GitHack）还原完整源码 |
| Web-8 | SVN | 访问 `/.svn` 目录获取 flag | Subversion 元数据目录泄露，可利用 `svn-extractor` 还原 |

> **防御建议**：部署流程中必须加入 `.git`、`.svn` 等 VCS 目录的清理或访问控制规则。

### 编辑器缓存与临时文件

| 关卡 | 文件类型 | 利用方式 |
|------|----------|----------|
| Web-9 | Vim `.swp` 缓存文件 | 直接访问 `index.php.swp` 下载，使用 `vim -r` 恢复查看内容 |

> **原理**：Vim 编辑文件时会生成 `.swp` 交换文件，记录未保存的修改。若编辑器异常退出且未清理，可能泄露敏感代码。

### Cookie、域名、邮箱等公开信息利用

| 关卡 | 信息来源 | 利用链路 |
|------|----------|----------|
| Web-10 | Cookie 值 | 抓包查看 Cookie 字段，发现编码后的 flag，URL 解码即得 |
| Web-11 | DNS TXT 记录 | 使用在线工具（如 `jsons.cn/nslookup`）查询域名 TXT 记录，flag 存放于其中 |
| Web-12 | 网站公开联系电话 | 发现后台登录入口 `/admin`，尝试弱口令 `admin` / 电话号码，成功登录获取 flag |
| Web-13 | 技术文档 PDF | 下载站点提供的技术文档，文档元数据或内容中包含默认凭证，登录后台得 flag |
| Web-15 | 邮箱/个人信息泄露 | 通过“忘记密码”功能，利用搜索引擎查询管理员 QQ 邮箱归属地（陕西西安），重置密码登录后台得 flag |

> **关联延伸**：信息收集是渗透测试的核心前置阶段，可参考 [[edu-src-penetration-test-case-study]] 中利用 FOFA 资产发现、弱口令登录的完整攻击链。

### 探针与 phpinfo 信息泄露

| 关卡 | 探针文件 | 利用方式 |
|------|----------|----------|
| Web-16 | `tz.php` (疑为 `tanzhen.php` 缩写) | 访问探针页面 -> 点击 `phpinfo()` -> 搜索 `flag` 关键字 |

> **风险**：探针页面（如 `phpinfo()`、`tanzhen.php`、`prober.php`）会暴露服务器环境变量、扩展模块、路径等敏感信息，测试后必须删除。

### 真实 IP 与 CDN 绕过

| 关卡 | 目标 | 方法 |
|------|------|------|
| Web-17 | `ctfshow.com` 真实 IP | 直接 `ping` 域名获取 IP（未使用 CDN 或 CDN 配置不当） |

> **进阶**：结合 [[c2-redirectors-malleable-c2-profiles]] 中的域名前置、CDN 隐匿技巧，理解蓝队视角的真实 IP 保护措施。

### 前端硬编码凭证与逻辑绕过

| 关卡 | 泄露形式 | 利用细节 |
|------|----------|----------|
| Web-18 | JavaScript 变量/函数 | 查看 JS 文件，发现 Base64 编码的提示，解码后访问 `110.php` 得 flag |
| Web-19 | HTML 注释/JS 变量 | 网页源码中直接硬编码账号密码，登录时前端 JS 会篡改密码输入框，需抓包修改 Authorization 字段或禁用 JS 登录 |

> **教训**：敏感凭证、逻辑判断绝不可仅依赖前端控制。

### ASP/Access 遗留架构数据库下载

| 关卡 | 架构 | 利用路径 |
|------|------|----------|
| Web-20 | ASP + Access (`.mdb`) | 猜测数据库存放路径 `/db/db.mdb` 直接下载，打开数据库表获取 flag |

> **工具提示**：Windows 下可用 Access 打开 `.mdb`；Linux/Mac 可用 `mdb-tools` (`mdb-export`) 或转换为 SQLite/CSV 分析。

## 二、 爆破技术实战谱系

### HTTP Basic Auth 爆破

| 关卡 | 认证方式 | 爆破策略 | 工具/技巧 |
|------|----------|----------|-----------|
| Web-21 | Basic Auth (`Authorization: Basic base64(user:pass)`) | 下载题目提供的字典压缩包，使用 Burp Suite **Custom Iterator** 模式，对 `user:pass` 组合进行 Base64 编码后爆破 | BP Custom Iterator 支持自定义编码处理，适合非标准认证格式 |

### 子域名枚举

| 关卡 | 目标 | 工具/平台 | 关键发现 |
|------|------|-----------|----------|
| Web-22 | `ctf.show` 子域名 | Layer 子域名挖掘机、在线工具 `phpinfo.me/domain` | 发现 `vip.ctf.show`，响应头 `flag` 字段直接泄露 flag |

> **关联延伸**：子域名枚举是攻击面测绘核心步骤，可结合 [[edu-src-penetration-test-case-study]] 中的 FOFA 资产发现、[[c2-redirectors-malleable-c2-profiles]] 中的域名基础设施管理。

### PHP mt_rand 种子预测与 php_mt_seed 破解

#### Web-23：MD5 特征位约束爆破
- **源码逻辑**：`token` 参数为 32 位字符串，要求 `token[1] == token[14] == token[17]` 且 `(intval(token[1])+intval(token[14])+intval(token[17])) / intval(token[1]) == intval(token[31])`。
- **解法**：编写脚本遍历字符集（a-z, A-Z, 0-9），仅需满足上述数学约束。最终发现只有 `3j` 满足条件（对应 MD5 特征位）。

#### Web-24：mt_srand 固定种子导致 mt_rand 可预测
- **源码逻辑**：`mt_srand(372619038)` 固定种子，随后 `mt_rand()` 生成的第一个随机数固定。
- **解法**：本地搭建相同 PHP 版本环境，运行 `mt_srand(372619038); echo mt_rand();` 得到 `1155388967`，直接提交 `r=1155388967` 获取 flag。
- **注意**：PHP 5 与 PHP 7 的 `mt_rand` 算法不同，需匹配目标版本。

#### Web-25：双重 mt_rand 与 php_mt_seed 工具实战
- **源码逻辑**：
  1. 传入 `r=0` 触发 `intval(mt_rand())` 获取第一个随机数 `rand1 = 894781553`。
  2. 需要构造 Cookie `token = mt_rand() + mt_rand()`（即第二、三次随机数之和）。
- **解法**：
  1. 已知 `rand1`，使用 **php_mt_seed** 反推种子：`./php_mt_seed 894781553` 得到多个候选种子。
  2. 编写本地脚本遍历候选种子，复现 `mt_rand()` 序列，计算第二、三次随机数之和，验证哪个种子能生成正确的 `token`。
  3. 最终确定种子 `0x9192d975`，计算出 `token` 提交 Cookie 获取 flag。

> **工具链**：[php_mt_seed](https://www.openwall.com/php_mt_seed/) 是专门针对 PHP `mt_rand` 种子破解的高性能工具，支持已知单次/多次随机数输出反推种子。
> **关联延伸**：伪随机数生成器（PRNG）安全性是密码学基础，可参考 [[crypto-basics-xor-stream-cipher-tutorial]] 中流密码密钥流预测原理。

### MySQL 空连接/弱凭证尝试

| 关卡 | 漏洞类型 | 利用方式 |
|------|----------|----------|
| Web-26 | MySQL 空用户名/密码登录 | 抓包登录请求，直接提交空用户名、空密码，服务端未校验即连接成功返回 flag |

> **本质**：数据库配置错误，允许匿名或空密码登录。实战中常结合 [[mysql-duplicate-entry-error-based-sqli]]、[[mysql-dnslog-injection-loadfile-unc]] 等注入技术进一步利用。

### 身份证号/个人信息爆破

| 关卡 | 场景 | 爆破空间 | 爆破结果 |
|------|------|----------|----------|
| Web-27 | 录取查询系统，已知姓名、身份证前 6 位 (621022) 和出生年份范围 (1990-1999) | `19900000-19999999` (约 1000 万) | 身份证号 `621022199002015237`，学号 `02015237`，密码即身份证号 |

> **技巧**：利用身份证编码规则（地址码+出生日期+顺序码+校验码）大幅缩小爆破空间，结合 Burp Suite **Intruder** 数字载荷类型高效枚举。

### 多级目录/文件枚举爆破

| 关卡 | URL 结构 | 爆破参数 | 爆破模式 |
|------|----------|----------|----------|
| Web-28 | `http://.../0/1/2.txt` | 目录层级 `0`、`1` (数字) | Burp Suite **Cluster Bomb** (集束炸弹) 模式，两个位置分别加载数字字典，末尾添加后缀 `/` |

> **注意**：目录爆破需处理响应码、内容长度过滤，避免误报。

## 三、 知识图谱与交叉引用

```mermaid
graph TD
    A[CTFshow Web 1-28 信息收集与爆破] --> B[源码泄露]
    A --> C[版本控制残留]
    A --> D[编辑器缓存]
    A --> E[公开信息利用]
    A --> F[探针/phpinfo]
    A --> G[前端硬编码]
    A --> H[ASP/Access DB]
    A --> I[Basic Auth 爆破]
    A --> J[子域名枚举]
    A --> K[mt_rand 种子预测]
    A --> L[MySQL 空连接]
    A --> M[身份证/目录爆破]

    B --> B1[.phps / www.zip / editor遍历]
    C --> C1[.git / .svn]
    D --> D1[.swp]
    E --> E1[Cookie / DNS TXT / 电话 / 文档 / 邮箱]
    F --> F1[tz.php -> phpinfo]
    G --> G1[JS变量 / HTML注释 / 前端篡改绕过]
    H --> H1[/db/db.mdb]
    I --> I1[Custom Iterator + Base64]
    J --> J1[Layer / phpinfo.me]
    K --> K1[固定种子 / php_mt_seed 反推]
    L --> L1[匿名登录]
    M --> M1[身份证编码规则缩小空间 / Cluster Bomb]

    %% 交叉引用现有页面
    B -.->|代码审计前置| V1[[vulnhub-darkhole2-writeup]]
    B -.->|框架漏洞审计| V2[[huxiangbei-willphp-file-inclusion-writeup]]
    E -.->|资产发现与弱口令| V3[[edu-src-penetration-test-case-study]]
    F -.->|C2基础设施隐匿视角| V4[[c2-redirectors-malleable-c2-profiles]]
    J -.->|子域名枚举与资产测绘| V3
    K -.->|PRNG安全性与流密码| V5[[crypto-basics-xor-stream-cipher-tutorial]]
    L -.->|MySQL注入进阶利用| V6[[mysql-duplicate-entry-error-based-sqli]]
    L -.->|DNSLog数据外带| V7[[mysql-dnslog-injection-loadfile-unc]]
```

## 四、 实战工具箱速查

| 场景 | 推荐工具/脚本 | 关键参数/用法 |
|------|---------------|---------------|
| Git 泄露利用 | GitHack, git-dumper | `python GitHack.py http://target/.git/` |
| SVN 泄露利用 | svn-extractor | `python svn_extractor.py http://target/.svn/ target_dir` |
| Vim swap 恢复 | vim 原生 | `vim -r index.php.swp` |
| 子域名枚举 | Layer, subfinder, amass, 在线: phpinfo.me/domain | `subfinder -d target.com -o subs.txt` |
| Basic Auth 爆破 | Burp Suite Custom Iterator | 设置 Payload Sets: user, pass; Payload Processing: Base64 encode `user:pass` |
| mt_rand 种子破解 | php_mt_seed (C 语言, 需编译) | `./php_mt_seed <known_rand1> [<known_rand2> ...]` |
| 身份证号生成/校验 | Python `id-validator` 库 / 自写脚本 | `pip install id-validator` |
| 目录/文件爆破 | dirsearch, ffuf, Burp Intruder Cluster Bomb | `ffuf -u http://target/FUZZ -w dict.txt` |
| .mdb 分析 (Linux) | mdb-tools | `mdb-export db.mdb table_name > out.csv` |

## 五、 防御与加固清单

1. **部署流程强制清理**：`.git`、`.svn`、`.swp`、`.bak`、`.zip`、`.phps`、探针文件 (`phpinfo.php`, `tz.php` 等)。
2. **敏感信息最小化**：Cookie 不存明文/弱加密 flag；DNS TXT 记录不存业务敏感数据；技术文档脱敏后再发布；前端代码不硬编码凭证、逻辑判断。
3. **数据库加固**：禁止空/弱口令登录；最小权限原则；Access/MDB 等文件型数据库严禁放在 Web 目录下。
4. **随机数安全**：**勿使用 `mt_rand`/`rand` 生成安全令牌、会话 ID、重置密码 token**；必须使用 `random_bytes()`、`openssl_random_pseudo_bytes()` 或 PHP 7+ 的 `random_int()`。
5. **访问控制**：后台入口 (`/admin` 等) 强制 MFA、IP 白名单、限流；Basic Auth 仅用于内网/测试环境，生产环境改用 OAuth2/JWT 等现代认证。
6. **信息泄露监控**：定期扫描子域名、GitHub/Gitee 代码泄露、历史快照；配置 WAF 规则拦截 `.git/`、`.svn/` 等敏感路径访问。

## 六、 结语

CTFshow Web 入门 1-28 关虽定位“入门”，却浓缩了 Web 信息收集与爆破的经典攻击面：**从被动观察 (源码、Cookie、DNS、文档) 到主动探测 (探针、目录、子域名、弱口令)，再到密码学层面的 PRNG 状态恢复 (mt_rand/php_mt_seed)**。掌握这些技术的组合拳，配合工具链自动化，即可应对大多数实战渗透测试的前期立足点获取阶段。建议读者在复现过程中，重点体会**“信息收集贯穿始终”**与**“爆破空间压缩技巧 (身份证编码、Cluster Bomb、php_mt_seed 反推种子)”**两大核心思想，并结合本库其他实战页面 ([[vulnhub-darkhole2-writeup]], [[edu-src-penetration-test-case-study]], [[crypto-basics-xor-stream-cipher-tutorial]] 等) 形成完整的攻防知识闭环。

## 来源

- [0x00实验室-202108-202304_060](../sources/0x00实验室-202108-202304_060.md)
