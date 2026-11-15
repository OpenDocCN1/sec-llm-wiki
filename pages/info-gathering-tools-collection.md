---
title: 网络安全信息收集工具大全
description: 系统梳理网络安全渗透测试与红队侦察阶段常用的信息收集工具合集，涵盖端口扫描、目录扫描、子域名枚举、指纹识别、WAF/CDN探测、空间引擎搜索、历史漏洞库、GitHub敏感信息搜集、Google
  Hacking语法等全阶段工具，并关联实战案例与自动化脚本开发指引。
category: program-analysis
tags:
- 信息收集
- 渗透测试
- 资产测绘
- 子域名枚举
- 指纹识别
- WAF探测
- CDN探测
- 端口扫描
- 目录扫描
- Google Hacking
- 空间引擎
- 红队侦察
date: 2024-01-15
updated: '2026-11-15'
---

## 概述

信息收集是渗透测试、红队演练、漏洞挖掘的**起点与核心**。本页面系统沉淀网络空间安全常用信息收集类工具，按攻击面阶段分类，并交叉引用知识库中已有的实战案例、自动化脚本开发指引、工具深度解析页面，形成可检索、可复用的结构化知识库。

> **来源**：0xfafu攻防实验室微信归档《网络安全常用工具大收集之信息收集类工具》（供稿人：A1andNS）

---

## 一、 端口扫描与 C 段探测

| 工具 | 项目地址 | 特点 | 适用场景 |
|------|----------|------|----------|
| **Nmap** | <https://nmap.org/> | 网络探测与安全审计标杆，支持主机发现、端口扫描、版本探测、OS指纹、NSE脚本 | 全阶段通用、脚本化批量扫描 |
| **masscan** | <https://github.com/robertdavidgraham/masscan> | 全互联网级高速异步扫描器，毫秒级扫完全网端口 | 大规模资产发现、C段快速存活探测 |
| **Goby** | <https://gobies.org> | 图形化攻击面映射，集成端口/服务/漏洞/弱口令/指纹识别、一键利用 | 红队资产梳理、可视化攻击面管理 |
| **御剑端口扫描** | <https://github.com/foryujian/yujianportscan> | 国产轻量级GUI工具，支持多线程、导出结果 | Windows环境快速内网/外网端口排查 |

**实战关联**
- [[vulnerability-mining-recon-aiqicha-fofa]]：资产测绘语法构造（FOFA/Quake/ZoomEye）与端口验证联动
- [[iot-reconnaissance-information-gathering]]：境外IoT设备Nmap端口验证、SNMP枚举全流程
- [[xd-security-vulnerability-discovery-notes-day42-45]]：Goby/Nessus/Nmap扫描器实战操作流程
- [[0w1club-week2-wifi-hijacking-arp-spoofing]]：内网存活主机发现（netdiscover、nmap -sn）

---

## 二、 目录/路径扫描

| 工具 | 项目地址 | 特点 |
|------|----------|------|
| **dirsearch** | <https://github.com/maurosoria/dirsearch> | Python编写，支持递归、字典自定义、状态码过滤、延迟控制 |
| **御剑目录扫描** | <https://github.com/foryujian/yjdirscan> | 国产GUI、多线程、支持自定义字典与后缀 |
| **Dirmap** | <https://github.com/H4ckForJob/dirmap> | Go语言高性能、支持递归爆破、通配符过滤、结果去重 |
| **7kbscan-WebPathBrute** | <https://github.com/7kbstorm/7kbscan-WebPathBrute> | 图形化、集成多字典、支持代理、导出报告 |

**实战关联**
- [[xd-security-pentest-basic-stage-notes]]：Web基础阶段目录扫描实战技巧
- [[ssrf-bypass-techniques]]：内网端口扫描探测与目录枚举结合利用链

---

## 三、 Whois 与 根域名/备案信息

| 类别 | 工具/平台 | 说明 |
|------|-----------|------|
| **在线Whois** | 站长之家 <http://whois.chinaz.com>、Bugscaner <http://whois.bugscaner.com>、HE.NET <https://bgp.he.net> | 域名注册信息、DNS记录、ASN归属查询 |
| **企业/备案查询** | 企查查 <https://www.qichacha.com>、备案查询网 <http://www.beianbeian.com> | 关联主体资质、ICP备案、关联域名反查 |

**实战关联**
- [[vulnerability-mining-recon-aiqicha-fofa]]：爱企查筛选目标企业工商信息、关联域名收集
- [[loan-company-penetration-test-case-study]]：爱企查、灯塔系统资产收集实战

---

## 四、 子域名枚举

| 工具 | 项目地址 | 核心能力 |
|------|----------|----------|
| **OneForAll** | <https://github.com/shmilylty/OneForAll> | 多源聚合（搜索引擎、证书透明度、DNS区域传输、API）、去重、存活探测、端口服务识别、指纹识别、导出多格式 |
| **ksubdomain** | <https://github.com/knownsec/ksubdomain> | 无状态ZMap风格高速爆破、支持泛解析过滤、适合大规模字典爆破 |
| **subDomainsBrute** | <https://github.com/lijiejie/subDomainsBrute> | 经典Python多线程爆破、支持递归、泛解析判断 |
| **Sublist3r** | <https://github.com/aboul3la/Sublist3r> | 多搜索引擎API聚合（Google、Bing、Yahoo、Virustotal等） |
| **RapidDNS** | <https://rapiddns.io/subdomain> | 在线快速查询、支持导出 |
| **wydomain** | <https://github.com/ring04h/wydomain> | 证书透明度+搜索引擎+字典爆破组合 |
| **在线平台** | 查子域 <https://chaziyu.com/>、子域名爆破 <http://scan.javasec.cn/> | 免安装快速查询 |

**实战关联**
- [[vulnerability-mining-recon-aiqicha-fofa]]：FOFA语法`domain="xxx.com"`配合子域名工具双轨收集
- [[xd-security-python-security-development-notes]]：子域名枚举自动化脚本开发（DNS查询、并发控制、结果去重）

---

## 五、 旁站与 C 段关联站点

| 平台 | 地址 | 说明 |
|------|------|------|
| 站长之家旁站查询 | <http://stool.chinaz.com/same> | 同IP绑定域名查询 |
| IP138 站点查询 | <https://site.ip138.com> | IP反查域名、历史解析记录 |

---

## 六、 真实 IP 与 CDN/WAF 穿透

| 类别 | 工具/平台 | 核心能力 |
|------|-----------|----------|
| **全球多点 Ping/解析** | <https://www.wepcc.com>、<https://tools.ipip.net/dns.php>、<https://ipchaxun.com> | 多地解析对比、判断CDN节点分布 |
| **历史DNS记录** | <https://dnsdb.io/zh-cn/> | 被动DNS数据集、历史解析记录回溯真实IP |
| **CDN探测/绕过** | **Xcdn** <https://github.com/3xp10it/xcdn>、CDN云观测 <http://cdn.chinaz.com/>、cdnplanet <https://www.cdnplanet.com/> | CDN厂商识别、边缘节点分布、真实IP回溯 |
| **WAF识别** | **WhatWaf** <https://github.com/Ekultek/WhatWaf>、**wafw00f** <https://github.com/EnableSecurity/wafw00f>、**Awesome-WAF** <https://github.com/0xInfection/Awesome-WAF> | 指纹库匹配、主动探测、绕过Payload建议 |

**实战关联**
- [[observerward-0x727-web-fingerprint-tool]]：ObserverWard/Rust指纹识别工具与FingerprintHub社区指纹库
- [[xd-security-waf-bypass-techniques-day46-49]]：安全狗/宝塔/阿里云盾三大WAF绕过策略与Payload变异体系

---

## 七、 空间测绘引擎（资产测绘/网络空间搜索引擎）

| 平台 | 地址 | 特色 |
|------|------|------|
| **FOFA** | <https://fofa.so> | 中文语法、资产图谱、API批量导出、ICP/证书/端口/标题/Body多维检索 |
| **Quake 360** | <https://quake.360.cn/quake/#/index> | 服务组件指纹丰富、支持协议/端口/漏洞/组件多维查询 |
| **Shodan** | <https://www.shodan.io> | 全球互联网设备普查、工控/物联网/数据库暴露面、历史数据 |
| **ZoomEye** | <https://www.zoomeye.org> | 知数科技、主机/Web/设备三视图、API支持、历史快照 |

**实战关联**
- [[vulnerability-mining-recon-aiqicha-fofa]]：FOFA/Quake语法构造示例库、资产收集标准化方法论
- [[iot-reconnaissance-information-gathering]]：ZoomEye/Quake侦察IoT设备、Nmap验证、SNMP枚举全链路
- [[card-game-platform-penetration-test-case-study]]：FOFA语法收集资产、AWVS扫描定位SQL注入实战
- [[xd-security-vulnerability-discovery-notes-day42-45]]：Goby/Nessus/Nmap/Metasploit/Searchsploit工具链联动

---

## 八、 历史漏洞与漏洞库

| 平台 | 地址 | 定位 |
|------|------|------|
| **乌云镜像** | <https://wooyun.x10sec.org> | 早期中文漏洞社区存档、案例复现参考 |
| **Seebug** | <https://www.seebug.org> | 知道创宇、PoC/EXP集成、纷云平台联动 |
| **Exploit Database** | <https://www.exploit-db.com> | OffSec维护、权威EXP/CVE对照 |
| **Vulners** | <https://vulners.com> | 聚合多源、API检索、插件生态 |
| **Sploitus** | <https://sploitus.com> | 搜索引擎聚合Exploit-DB、GitHub、PacketStorm |

---

## 九、 网盘/代码/文档搜索引擎

| 平台 | 地址 | 说明 |
|------|------|------|
| **盘多多** | <http://www.panduoduo.net> | 百度网盘资源检索 |
| **大力盘** | <https://dalipan.com> | 多网盘聚合搜索 |

---

## 十、 GitHub 敏感信息搜集（GitHub Hacking / Dorks）

### 常用搜索语法模板

```text
# 凭证/密钥/配置类
@xxx.com password
@xxx.com secret
@xxx.com credentials
@xxx.com token
@xxx.com config
@xxx.com pass
@xxx.com login
@xxx.com ftp
@xxx.com ssh
@xxx.com pwd

# 云/数据库/连接串类
@xxx.com security_credentials
@xxx.com connectionstring
@xxx.com JDBC
@xxx.com ssh2_auth_password
@xxx.com send_keys
```

> **技巧**：结合 `filename:`、`path:`、`extension:`、`org:`、`user:` 进一步缩小范围；配合 **GitHub Code Search**、**GitHub Dorks** 自动化工具（如 **GitDorker**、**Gitleaks**、**TruffleHog**）批量扫描。

**实战关联**
- [[xd-security-python-security-development-notes]]：GitHub敏感信息爬虫开发（Requests/LXML数据提取、API限流处理）

---

## 十一、 Google Hacking 语法速查

| 目标 | 语法示例 |
|------|----------|
| **后台/登录入口** | `site:xxx.com 管理后台/登陆/管理员/系统`<br>`site:xxx.com inurl:login/admin/system/guanli/denglu` |
| **敏感文件泄露** | `site:xxx.com filetype:pdf/doc/xls/txt`<br>`site:xxx.com filetype:log/sql/conf` |
| **测试/开发环境** | `site:xxx.com inurl:test/ceshi`<br>`site:xxx.com intitle:测试` |
| **邮箱/QQ/企业通讯** | `site:xxx.com 邮件/email`<br>`site:xxx.com qq/群/企鹅/腾讯`<br>`site:xxx.com intitle:"Outlook Web App"`<br>`site:xxx.com intitle:"mail"`<br>`site:xxx.com intitle:"webmail"` |
| **API/接口/参数** | `site:xxx.com inurl:api`<br>`site:xxx.com inurl:uid=/id=` |
| **目录遍历/索引页** | `site:xxx.com intitle:index.of "server at"` |

> **扩展**：Bing/DuckDuckGo/360搜索同理；可配合 **Googledorks**、**Pwndora**、**GSIL** 自动化批量跑语法。

---

## 十二、 微信公众号/小程序/移动端信息收集

| 平台 | 地址 | 说明 |
|------|------|------|
| **搜狗微信搜索** | <https://weixin.sogou.com> | 公众号历史文章、微信号搜索、文章内容检索 |

> **延伸**：小程序反编译（wxapkg）、Android/iOS应用静态分析、网络流量抓包、证书透明度关联域名、移动端API接口枚举——详见 [[android-shelling-unshelling-techniques]]、[[iot-reconnaissance-information-gathering]]、[[xd-security-python-security-development-notes]]。

---

## 十三、 Web 指纹识别（CMS/框架/中间件/组件/版本）

| 工具 | 形态 | 地址 | 特点 |
|------|------|------|------|
| **Wappalyzer** | 浏览器插件 | <https://www.wappalyzer.com/> | 实时识别、覆盖面广、支持导出JSON |
| **云悉指纹** | 在线/客户端 | <http://www.yunsee.cn> | 国内指纹库丰富、支持批量、API调用 |
| **WhatWeb** | CLI/在线 | <https://www.whatweb.net/>、<http://whatweb.bugscaner.com/look> | Ruby编写、插件化、支持递归、批量扫描 |
| **ObserverWard** | CLI/API服务 | <https://github.com/0x727/ObserverWard> | **Rust高性能**、指纹库社区化（**FingerprintHub**）、YAML规则、支持指纹自定义与贡献 |

**实战关联**
- [[observerward-0x727-web-fingerprint-tool]]：ObserverWard架构、指纹规则规范、社区贡献体系深度解析
- [[vulnerability-mining-recon-aiqicha-fofa]]：Wappalyzer指纹识别技术栈精准定位漏洞挖掘方向
- [[loan-company-penetration-test-case-study]]：Wappalyzer识别技术栈实战案例

---

## 十四、 JS 接口/前端资产/敏感信息提取

| 工具 | 地址 | 核心能力 |
|------|------|----------|
| **JSFinder** | <https://github.com/Threezh1/JSFinder> | 从JS文件提取URL、子域名、API接口、敏感信息、支持递归 |
| **LinkFinder** | <https://github.com/GerbenJavado/LinkFinder> | 正则提取JS中端点、支持Burp插件、CLI批量 |
| **Packer-Fuzzer** | <https://github.com/rtcatc/Packer-Fuzzer> | **Webpack**打包文件还原、SourceMap反解、模块依赖图分析、敏感信息挖掘 |

> **实战技巧**：配合 **Burp Suite**、**Chrome DevTools**、**方式一：页面搜索 `api/` `ajax` `fetch` `axios` `request` `url:` `baseURL`**；方式二：自动化爬虫+JS解析管线——详见 [[xd-security-python-security-development-notes]] 信息收集自动化脚本。

---

## 十五、 WAF/CDN 识别与绕过工具体系

| 类别 | 工具/资源 | 说明 |
|------|-----------|------|
| **WAF指纹识别** | WhatWaf、wafw00f、Awesome-WAF | 主动/被动指纹匹配、厂商识别 |
| **CDN厂商/节点探测** | Xcdn、CDN云观测、cdnplanet | 边缘节点分布、真实IP回溯 |
| **绕过技术库** | WAF绕过Payload、编码变异、分块传输、HTTP走私、协议差异 | 详见 [[xd-security-waf-bypass-techniques-day46-49]]、[[ssrf-bypass-techniques]] |

---

## 十六、 自动化信息收集工具链与开发指引

### 一站式侦察框架
- **OneForAll**：子域名+端口+指纹+漏洞检测一体化
- **Goby**：资产映射+漏洞扫描+利用一体化
- **ReconFTW** / **AutoRecon** / **bba** / **Recon-ng** / **SpiderFoot** / **Amass** / **Assetfinder** / **Subfinder** / **httpx** / **nuclei** —— 组合成现代化侦察管线

### Python 自动化脚本开发核心模块（参考 [[xd-security-python-security-development-notes]]）
| 模块 | 关键库/工具 | 实现要点 |
|------|-------------|----------|
| **DNS查询/子域名枚举** | `dnspython`、`aiodns`、`massdns` | 异步并发、泛解析过滤、AXFR尝试、证书透明度API |
| **Whois/备案/企业信息** | `python-whois`、`requests`+爱企查/天眼查/FOFA API | 反爬处理、结构化解析、关联图谱构建 |
| **端口/服务探测** | `python-nmap`、`masscan` XML解析、`naabu`、`httpx` | 存活探测→端口扫描→服务识别→指纹匹配管线 |
| **Web指纹/指纹库** | `Wappalyzer` Python绑定、ObserverWard API、自建YAML指纹库 | 规则热更新、置信度评分、误报抑制 |
| **JS接口/敏感信息提取** | `requests`+`lxml`/`regex`/`jsbeautifier`+`esprima` | 静态资源下载→解混淆→AST分析→端点/密钥提取 |
| **空间引擎API批量查询** | FOFA/Quake/Shodan/ZoomEye/GitHub API | 分页、限流重试、字段标准化、去重入库 |
| **结果存储与可视化** | `sqlite`/`postgresql`/`elasticsearch` + `Kibana`/`Grafana`/`React`前端 | 资产画像、攻击面图谱、变更监控告警 |

### 容器化部署与CI/CD集成
- **Docker Compose** 编排：扫描器集群、任务队列、结果聚合
- **GitLab CI / GitHub Actions** 定时触发资产巡检、新增资产告警
- **Kubernetes CronJob** 大规模分布式扫描调度

---

## 十七、 实战案例交叉索引

| 场景 | 知识库页面 | 核心工具/技术点 |
|------|------------|-----------------|
| **漏洞挖掘侦察标准化** | [[vulnerability-mining-recon-aiqicha-fofa]] | 爱企查筛选→FOFA语法→指纹识别→子域名枚举→端口验证 |
| **IoT设备境外侦察** | [[iot-reconnaissance-information-gathering]] | ZoomEye/Quake→Nmap验证→SNMPwalk枚举→地理定位/rDNS确权 |
| **棋牌平台渗透测试** | [[card-game-platform-penetration-test-case-study]] | FOFA资产收集→AWVS扫描→sqlmap验证→xp_cmdshell拿Shell |
| **贷款公司内网渗透** | [[loan-company-penetration-test-case-study]] | 爱企查/FOFA/灯塔系统→Wappalyzer指纹→堡垒机漏洞→会话审计提权 |
| **医疗系统内网渗透** | [[medical-system-internal-penetration-case-study]] | Web越权上传→凭证导出→横向移动→敏感数据泄露 |
| **上市公司内网渗透** | [[listed-company-penetration-test-case-study]] | 弱口令上传→哥斯拉/MSF/CS会话传递→Socks代理横向→MSSQL/IoT/OT设备失陷 |
| **Shiro RCE内网渗透** | [[shiro-internal-penetration-case-study]] | Shiro RCE初始访问→火绒免杀上线CS→NTLM导出→FTP横向→威胁溯源 |
| **红队基础设施隐匿** | [[c2-redirectors-malleable-c2-profiles]]、[[cobalt-strike-external-c2-smb-beacon]] | 重定向器/Malleable C2/CDN/域名前置/SMB Beacon/External C2 |
| **内存免杀与规避** | [[inceptor-av-edr-evasion-framework]]、[[memory-scanning-tools-evasion-techniques]] | Donut/sRDI/PE2SHC/OLLVM/全卸载/直接系统调用/内存扫描对抗 |
| **应急响应与溯源** | [[threat-attribution-tracing-techniques]]、[[xd-security-incident-response-notes]] | IP定位/钓鱼邮件反查/VPS渗透/恶意样本分析/主机入侵排查/流量回溯 |

---

## 十八、 学习路线与进阶建议

1. **基础掌握**：Nmap/dirsearch/OneForAll/Wappalyzer/FOFA/Google Hacking 熟练单工具操作
2. **管线化**：编写/二开自动化侦察脚本（子域名→存活→端口→指纹→漏洞扫描→报告），参考 [[xd-security-python-security-development-notes]]
3. **规模化**：引入 Amass/Subfinder/httpx/nuclei/naabu/Goby/ObserverWard 构建分布式侦察集群
4. **实战化**：结合真实渗透项目（[[vulnerability-mining-recon-aiqicha-fofa]]、[[loan-company-penetration-test-case-study]]、[[shiro-internal-penetration-case-study]]）复盘侦察盲区与失误
5. **对抗化**：WAF/CDN识别绕过（[[xd-security-waf-bypass-techniques-day46-49]]）、内存免杀（[[inceptor-av-edr-evasion-framework]]）、C2隐匿（[[c2-redirectors-malleable-c2-profiles]]）、溯源反制（[[threat-attribution-tracing-techniques]]）
6. **工程化**：CI/CD集成、资产变更监控、知识图谱构建、攻击面可视化、红蓝对抗复盘体系

---

## 十九、 常用工具速查卡（Mini Cheatsheet）

```bash
# Nmap 常用模板
nmap -sS -sV -O -A -T4 -p- --script vuln -oA scan_target target.com
nmap -sn -n 192.168.1.0/24 -oG - | awk '/Up$/{print $2}'  # 存活主机发现

# masscan 全端口快速扫
masscan -p1-65535 --rate=10000 -oG masscan.gnmap target.com

# OneForAll 一键跑子域名+存活+端口+指纹
python3 oneforall.py --target example.com --brute True --port all --alive True --banner True --finger True --export json

# httpx 批量探活+指纹+标题+技术栈
cat subs.txt | httpx -silent -status-code -title -tech-detect -cdn -ip -cname -asn -json -o httpx.json

# nuclei 基于模板的漏洞扫描
nuclei -l httpx.json -t cves/ -t vulnerabilities/ -t misconfiguration/ -t exposures/ -severity critical,high,medium -o nuclei.txt

# ObserverWard 批量指纹识别
observerward -i subs.txt -o finger.json --fmt json

# JSFinder 提取JS接口
python3 JSFinder.py -u https://target.com -ou js_urls.txt -od js_files

# wafw00f 识别WAF
wafw00f https://target.com

# Xcdn CDN探测真实IP
python3 xcdn.py -d target.com --thread 50

# FOFA CLI (需配置API Key)
fofa -q 'domain="example.com" && country="CN"' -f ip,port,title,server -n 1000 -o fofa.csv
```

---

## 二十、 参考与延伸阅读

- **0xfafu攻防实验室原文**：《网络安全常用工具大收集之信息收集类工具》
- **知识库交叉引用索引**：
  - 资产测绘与侦察方法论：[[vulnerability-mining-recon-aiqicha-fofa]]
  - IoT侦察全流程：[[iot-reconnaissance-information-gathering]]
  - 指纹识别工程化：[[observerward-0x727-web-fingerprint-tool]]
  - 渗透测试基础阶段笔记：[[xd-security-pentest-basic-stage-notes]]
  - 漏洞发现工具链实战：[[xd-security-vulnerability-discovery-notes-day42-45]]
  - Python安全开发自动化脚本：[[xd-security-python-security-development-notes]]
  - WAF绕过技术体系：[[xd-security-waf-bypass-techniques-day46-49]]
  - SSRF绕过与内网探测：[[ssrf-bypass-techniques]]
  - 多个实战渗透案例（棋牌/贷款/医疗/上市公司/Shiro/内网横向/红队基建/免杀/应急溯源）

---

> **维护提示**：工具链迭代极快，建议每季度核验工具可用性、更新指纹库、补充新工具（如 **AttackSurfaceMapper**、**MapCIDR**、**Dnsx**、**Shuffledns**、**Goaltdns**、**Altdns**、**Massdns**、**Puredns**、**Subfinder**、**Assetfinder**、**Findomain**、**Crobat**、**Chaos Client**、**Amass**、**ReconFTW**、**AutoRecon**、**Bba**、**FinalRecon**、**Recon-ng**、**SpiderFoot** 等现代化侦察生态），并同步更新实战案例交叉引用。

## 来源

- [0xfafu攻防实验室-202010-202112_12](../sources/0xfafu攻防实验室-202010-202112_12.md)
