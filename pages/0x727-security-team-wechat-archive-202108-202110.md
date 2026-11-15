---
title: 0x727开源安全团队微信公众号2021年8月至10月文章归档索引
description: 0x727开源安全团队微信公众号在2021年8月至10月期间发布文章的汇总索引页面，涵盖AI安全、对抗样本、模型安全、数据投毒、联邦学习安全、隐私计算等前沿技术内容，新增SchTask计划任务持久化工具开源发布条目、漏洞报告自动化平台开源工具发布条目、MetasploitCoop后渗透协作平台开源发布条目。
category: program-analysis
tags:
- '0x727'
- 开源安全团队
- 微信归档
- 文章索引
- AI安全
- 对抗样本
- 模型安全
- 数据投毒
- 联邦学习安全
- 隐私计算
- 2021年
- 2021年8月
- 2021年9月
- 2021年10月
- SchTask
- 计划任务
- 持久化
- 权限维持
- C#
- 红队工具
- 免杀
- Windows Internals
- Task Scheduler
- 漏洞报告自动化
- 开源工具
- MetasploitCoop
- Metasploit Framework
- 后渗透
- 协作平台
- C2
- Cobalt Strike 替代品
- Docker
- 红队工具
- 开源项目
- 内网渗透
- 团队协作
date: 2021-10-31
updated: '2026-11-15'
---

## 0x727开源安全团队简介

0x727开源安全团队专注于人工智能安全领域的研究与实践，致力于探索机器学习模型在对抗环境下的鲁棒性、隐私保护、可解释性等核心问题。团队定期通过微信公众号分享前沿论文解读、漏洞分析、工具开发、竞赛复盘等技术干货。

本页面汇总整理团队在 **2021年8月至10月** 期间发布的公众号文章，按月份分类索引，便于安全研究者快速检索与回溯。

---

## 2021年10月文章汇总

| 日期 | 标题 | 核心标签 | 简介 |
|------|------|----------|------|
| 2021-10-?? | [0x727自动化编写报告平台](http://mp.weixin.qq.com/s?__biz=MzkwNTI3MjIyOQ==&mid=2247483774&idx=1&sn=070dfc03e056f359c6ba20616efccfcd) | 漏洞报告自动化、开源工具、Python、PHP、安全运营 | 0x727团队开源发布漏洞报告自动化编写平台，支持项目协同管理、漏洞批量导出、模板自定义、RC4加密防截图、URL防篡改等功能，基于Python+PHP技术栈，提供完整部署指南与Nginx安全配置。 |

---

## 2021年9月文章汇总

| 日期 | 标题 | 核心标签 | 简介 |
|------|------|----------|------|
| 2021-09-?? | [MetasploitCoop: 基于msf的后渗透协作平台](http://mp.weixin.qq.com/s?__biz=MzkwNTI3MjIyOQ==&mid=2247483702&idx=1&sn=13776d64c385c0dd9005403c5d66c72d) | MetasploitCoop、Metasploit Framework、后渗透、协作平台、C2、Cobalt Strike 替代品、Docker、红队工具、开源项目、内网渗透、团队协作 | 0x727团队开源发布MetasploitCoop项目，一个基于Metasploit Framework的可视化后渗透协作平台，支持团队协作、模块中文化、Docker部署、原生MSF控制台等核心功能，旨在作为Cobalt Strike的开源替代品。 |
| 2021-09-?? | [待补充] |  |  |
| 2021-09-?? | [待补充] |  |  |
| 2021-09-?? | [待补充] |  |  |

---

## 2021年8月文章汇总

| 日期 | 标题 | 核心标签 | 简介 |
|------|------|----------|------|
| 2021-08-05 | [SchTask-计划任务的进阶](http://mp.weixin.qq.com/s?__biz=MzkwNTI3MjIyOQ==&mid=2247483748&idx=1&sn=c4b1fb2229b2114c82962dabe901e6b3) | SchTask、计划任务、持久化、权限维持、C#、红队工具、免杀、Windows Internals、Task Scheduler | 0x727团队成员AnonySec开源发布SchTask工具，利用Windows API创建隐藏计划任务实现权限维持，支持随机进程名伪装、XML文件隐藏、定时触发持久化等核心功能，附技术原理详解与实战使用指南。 |
| 2021-08-?? | [待补充] |  |  |
| 2021-08-?? | [待补充] |  |  |
| 2021-08-?? | [待补充] |  |  |
| 2021-08-?? | [待补充] |  |  |

---

## 重点工具发布：SchTask 计划任务持久化工具

### 项目定位
0x727团队未来一段时间将陆续开源工具的第一款，专注于**权限维持**与**内存加载**场景，利用Windows计划任务机制实现隐蔽持久化，同时绕过安全软件阻断。

### 核心技术原理

#### 实现步骤
1. **随机进程名伪装**：选择主机随机进程名作为计划任务程序文件名
2. **文件投放路径**：将计划任务程序文件复制到 `%AppData%\Microsoft\Windows\Themes\` 目录
3. **任务命名策略**：创建的计划任务名取同一随机进程名，融入系统合法任务中
4. **触发器配置**：以分钟为单位设置无限期持续触发，保证持久化稳定性
5. **XML文件隐藏**：更改 Index、删除 SD 的键值，隐藏计划任务对应的 XML 定义文件，规避取证分析
6. **清理功能**：支持删除已添加的计划任务，便于撤离痕迹清理

#### 技术参考文档
更多技术细节请查看：[Windows计划任务的进阶](https://payloads.cn/2021/0805/advanced-windows-scheduled-tasks.html)

### 工具特性
- **语言**：C# (.NET Framework 2.0，兼容性强)
- **依赖**：内嵌 `Microsoft.Win32.TaskScheduler.dll`，Release版本单文件无依赖运行
- **隐蔽性**：随机命名、用户目录投放、XML元数据清理三重隐匿
- **持久性**：分钟级触发器无限期运行，重启后自动生效

### 使用方法

#### 下载安装
```bash
# 直接下载 Release 版本快速使用
# GitHub仓库：https://github.com/0x727/SchTask
```

#### 命令行用法
```
C:\>SchTask.exe
Usage: SchTask.exe <File Path> <Minutes>
Eg:  SchTask.exe C:\Windows\System32\cmd.exe 10
```

- **File Path**：要执行的程序路径（如载荷程序、反向Shell启动器等）
- **Minutes**：触发间隔（分钟），设置为10即每10分钟执行一次

#### 效果演示
工具运行后将在计划任务库中创建伪装的隐藏任务，任务计划程序界面中不可见，需通过注册表或专用工具枚举发现。

### 社区共建指引
SchTask 是一个免费且开源的项目，我们欢迎任何人为其开发和进步贡献力量。

- 问题反馈：提交 Issues
- Bug修复：PR 至 dev 分支
- 新功能：先创建 Issue 讨论设计方案
- 文档改进：欢迎 PR 完善说明文档（特别是英文文档）
- 稳定版发布：master 分支仅用于发布稳定可用版本
- 其他合作：发送邮件至 0x727Team@gmail.com

> 提醒：和项目相关的问题最好在 issues 中反馈，这样方便其他有类似问题的人可以快速查找解决方法，并且也避免了我们重复回答一些问题。

### 项目地址
🔗 **GitHub开源仓库**：https://github.com/0x727/SchTask

---

## 重点工具发布：0x727漏洞报告自动化编写平台

### 项目定位
根据安全团队定制化协同管理项目安全，可快速查找历史漏洞，批量导出报告。

### 技术栈
- **语言**：Python、PHP、HTML、JavaScript、CSS
- **系统**：CentOS/Ubuntu
- **环境**：nginx + php + mysql + python3

### 核心功能模块

#### 首页仪表盘
统计团队成员提交漏洞数量，展示项目漏洞类型分类分布。

#### 项目管理
- **漏洞列表**：直观查看成员提交漏洞报告，支持批量导出报告
- **项目分类**：按挖掘需求创建项目分类
- **项目资产**：查看当前项目关联域名资产
- **漏洞分布图**：可视化漏洞类型分布
- **模板列表**：自定义上传报告模板，导出时指定使用
- **漏洞分类**：创建漏洞类型分类体系（如Web安全→XXE注入）

#### 用户管理
- **团队成员账户创建**：支持协同提交漏洞
- **个人中心**：修改个人信息，便于管理员识别联系

#### 网站设置
- **IP访问控制**：限制后台访问IP，提高权限安全性
- **审计日志**：记录成员访问控制器操作，攻击行为留痕

### 版本迭代历史
| 版本 | 核心特性 |
|------|----------|
| V1.0 | 项目批量提交、按分类批量导出、快速生成年度汇总报告 |
| V1.1 | **防截图功能**：报告图片采用RC4加密算法加密，防止图片泄露 |
| V1.2 | **URL防篡改**：防止恶意获取URL请求，提升网站安全性 |
| V1.3 | 增加项目资产自动归属、漏洞分布图可视化 |

### 部署关键步骤

#### 目录权限配置
```bash
# 7个核心目录需可写权限
classes/ config/ index/ lib/ public/ python_web/  # 766
runtime/  # 777
```

#### Python 3.7 环境安装
```bash
yum -y groupinstall "Development tools"
yum -y install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel libffi-devel
wget https://www.python.org/ftp/python/3.7.0/Python-3.7.0.tar.xz
tar -xvJf Python-3.7.0.tar.xz
mkdir /usr/local/python3
cd Python-3.7.0
./configure --prefix=/usr/local/python3
make && make install
ln -s /usr/local/python3/bin/python3 /usr/local/bin/python3
ln -s /usr/local/python3/bin/pip3 /usr/local/bin/pip3
python3 -m pip install docxtpl==0.12.0
```

#### Nginx 安全配置片段
```nginx
autoindex off;
location ^~ /index/ { deny all; }
location ^~ /classes { deny all; }
location ^~ /config { deny all; }
location ^~ /lib { deny all; }
location ^~ /python_web { deny all; }
location ^~ /runtime { deny all; }
location ^~ /public/auto/ { deny all; }
location ^~ /public/img/ { deny all; }
if (!-e $request_filename) { rewrite ^(.*)$ $1.php last; }
```

### 项目地址
🔗 **GitHub开源仓库**：https://github.com/0x727/BugRepoter_0x727

### 社区共建指引
- 问题反馈：提交 Issues
- Bug修复：PR 至 dev 分支
- 新功能：先创建 Issue 讨论设计方案
- 文档改进：欢迎 PR 完善说明文档
- 稳定版发布：master 分支仅用于发布稳定版本

---

## 重点工具发布：MetasploitCoop 后渗透协作平台

### 项目定位
MetasploitCoop 是 0x727 团队开源的**可视化后渗透协作平台**，基于 Metasploit Framework 构建，旨在成为 Cobalt Strike 的开源替代品，最大限度利用 MSF 现有生态进行内网渗透与团队协作。

### 核心架构
项目采用前后端分离 + MSF 核心的多仓库架构：
- **MetasploitCoop-Backend** (https://github.com/0x727/MetasploitCoop-Backend) — 后端服务
- **MetasploitCoop-Frontend** (https://github.com/0x727/MetasploitCoop-Frontend) — 前端界面
- **metasploit-framework** (https://github.com/0x727/metasploit-framework) — 定制版 MSF 核心
- **metasploit_data_models** (https://github.com/akkuman/metasploit_data_models) — 数据模型层

### 核心功能特性

#### 可视化操作与团队协作
- **可视化 Metasploit Framework**：图形化界面替代命令行交互
- **右键功能直达**：主机右键菜单快速执行常用操作
- **协作聊天**：团队成员实时文字通信
- **多人原生 MSF Console**：支持分离会话，环境互不污染

#### 后渗透全生命周期管理
- **会话与监听管理**：一键添加监听、生成 Payload、会话上线提醒
- **模块可视化执行**：参数表单化填写，支持从文件中转区选择文件，执行结果自动回显
- **任务进程管理**：实时查看模块执行输出，支持强制结束卡顿任务
- **主机资源管理**：进程列表（重要进程高亮）、文件管理、一键截屏、文件中转区

#### 凭据与情报聚合
- **凭据展示**：集中查看横向移动收集的凭据
- **战利品与历史记录**：模块执行历史、命令历史、主机上模块执行记录无限滚动加载
- **路由与端口转发**：一键添加路由、配置端口转发

#### 扩展性与本地化
- **模块中文化**：内置绝大部分模块中文翻译，支持腾讯翻译君 API 实时翻译新增模块
- **可定制右键菜单**：管理后台动态配置右键快捷功能
- **进程高亮管理**：自定义关键进程名单高亮显示
- **扩展模块库集成**：内置 `MetasploitModules_0x727` 仓库扩展模块（mssql_powershell、clone_user、redis/unauthorized 等）

#### 容器化与持久化
- **Docker Compose 一键部署**：`docker-compose up -d` 快速启动
- **监听自动恢复**：容器重启后自动恢复之前的监听任务
- **客户端支持**：提供 Windows 客户端，前端可挂载至其他服务器

### 快速开始体验

#### Docker Compose 部署
```bash
$ git clone https://github.com/0x727/MetasploitCoop.git
$ cd MetasploitCoop
$ docker-compose up -d
```

查看日志确认启动成功：
```bash
$ docker-compose logs
# 出现 "INFO supervisord started with pid 1" 即启动完成
```

#### 环境变量配置（可选）
```yaml
# docker-compose.yml 中额外支持
TENCENT_TRANSLATE_TOKEN_ID   # 腾讯翻译君 SecretId
TENCENT_TRANSLATE_TOKEN_KEY  # 腾讯翻译君 SecretKey
# 启用后支持 MSF 模块实时中文翻译
```

#### 访问与初始化
1. 打开 https://127.0.0.1:60443
2. 首次访问需配置服务器地址与基础认证（默认用户名 `msfcoop`，密码 `DptbHd8R`，可在 docker-compose.yml 修改）
3. 注册登录后即可使用

### 典型操作流程

1. **添加监听** → 点击上方「添加监听」，端口需在 `7000-7500` 范围内，监听地址填写真实回连 IP
2. **生成 Payload** → 任务管理中右键监听任务选择「生成 Payload」，参数与 MSF 一致
3. **目标上线** → 执行 Payload 后自动提示上线
4. **后渗透操作** → 右键会话主机：截屏、进程管理、文件管理、执行模块、添加路由/端口转发
5. **团队协作** → 底部聊天区实时沟通，共享会话与执行结果

### 更新日志精选

#### 2020-10-18 版本
- 文字聊天、模块选项提示、会话路由操作、历史命令/模块记录查询
- 截图按 IP 分目录存储、会话回连公网 IP 端口展示
- 可配置右键菜单、文件管理无限滚动、主机存活状态自动更新
- 集成 `MetasploitModules_0x727` 扩展模块库
- 新增内存执行 EXE 模块（post/windows/manage/execute_pe，需 .reloc 节）
- 重启容器自动恢复监听、Windows 客户端支持、执行中任务输出查看

#### 2020-10-20 版本
- 修复模块历史记录不显示、终端历史记录解析错误
- 移除前端 BasicAuth

### 社区共建指引
MetasploitCoop 是免费开源项目，欢迎各方贡献：
- 问题反馈：提交 Issues
- Bug 修复：PR 至 dev 分支
- 新功能：先创建 Issue 讨论设计方案
- 文档改进：欢迎 PR 完善（特别是英文文档）
- 稳定版发布：master 分支仅用于发布稳定版本
- 其他合作：邮件至 0x727Team@gmail.com

> 提醒：项目相关问题请在 Issues 中反馈，方便他人检索并避免重复解答。

### 项目地址
🔗 **主仓库**：https://github.com/0x727/MetasploitCoop
🔗 **后端**：https://github.com/0x727/MetasploitCoop-Backend
🔗 **前端**：https://github.com/0x727/MetasploitCoop-Frontend
🔗 **扩展模块库**：https://github.com/0x727/MetasploitModules_0x727

---

## 专题系列文章索引（持续更新中）

### 对抗攻击与防御系列
- 待补充：FGSM/PGD/DeepFool等经典攻击算法复现
- 待补充：对抗训练、随机平滑、认证防御等防御机制分析

### 模型窃取与推理攻击系列
- 待补充：Model Extraction攻击实战
- 待补充：成员推理攻击、属性推理攻击技术详解

### 数据投毒与后门攻击系列
- 待补充：清洁标签投毒、特定目标投毒案例分析
- 待补充：BadNets、TrojanNN等后门植入与检测技术

### 联邦学习安全系列
- 待补充：联邦学习威胁模型与攻击面分析
- 待补充：梯度反演攻击、模型投毒攻击在联邦学习中的实现

### 隐私计算与可信AI系列
- 待补充：差分隐私在机器学习中的应用
- 待补充：安全多方计算（MPC）、同态加密（HE）、可信执行环境（TEE）在AI场景落地

### AI安全竞赛复盘系列
- 待补充：天池、DataCastle、Kaggle等平台AI安全赛题Writeup
- 待补充：强网杯、西湖论剑等国内顶级赛事AI安全方向复盘

### 红队工具开发系列
- [[schtask-persistence-tool]] — SchTask计划任务持久化工具技术详解（C#、Task Scheduler、XML隐藏、免杀对抗）
- [[0x727-bugreporter-automated-report-platform]] — 0x727漏洞报告自动化编写平台（Python/PHP、项目协同、模板化报告、Nginx加固）
- [[metasploitcoop-collaboration-platform]] — MetasploitCoop后渗透协作平台（Ruby/Python/JS、MSF可视化、团队协作、Docker部署、模块中文化、Cobalt Strike替代品）

---

## 相关资源与工具链接

| 资源类型 | 名称 | 链接/备注 |
|----------|------|-----------|
| 团队主页 | 0x727开源安全团队 GitHub | https://github.com/0x727 |
| 持久化工具 | SchTask | https://github.com/0x727/SchTask |
| 漏洞报告工具 | BugRepoter_0x727 | https://github.com/0x727/BugRepoter_0x727 |
| 后渗透协作平台 | MetasploitCoop | https://github.com/0x727/MetasploitCoop |
| 扩展模块库 | MetasploitModules_0x727 | https://github.com/0x727/MetasploitModules_0x727 |
| 论文复现 | Adversarial Robustness Toolbox (ART) | IBM开源对抗鲁棒性工具箱 |
| 论文复现 | CleverHans | Google开源对抗样本库 |
| 论文复现 | Foolbox | 对抗攻击基准测试框架 |
| 数据集 | RobustBench | 对抗鲁棒性标准化基准 |
| 会议跟踪 | AI安全顶会论文列表 | NeurIPS/ICML/ICLR/USENIX Security/CCS/NDSS等 |

---

## 关联知识页面

- [[0x4d5a-wechat-archive-202103-202209]] — 0x4d5a安全团队同期微信归档索引（涵盖漏洞分析、CTF实战、红蓝对抗等传统安全方向）
- [[0x536d72-wechat-archive-202112-202205]] — 0x536d72安全团队微信归档索引
- [[0th3rs-security-team-wechat-archive-201911-202204]] — 0th3rs安全团队微信归档索引（含CTF、AWD、漏洞分析等内容）
- [[apt-c-08-mobile-attack-analysis]] — APT-C-08移动端攻击分析（涉及AI驱动的恶意样本分析）
- [[mtctf-2021-crypto-writeup]] / [[mtctf-2021-web-writeup]] — MTCTF 2021竞赛题解（可能包含AI安全相关挑战）
- [[tctf-2021-1linephp-zip-include]] / [[tctf-2021-worldcup-xss-go-ssti]] — TCTF 2021竞赛题解
- [[schtask-persistence-tool]] — SchTask计划任务持久化工具深度技术解析页
- [[0x727-bugreporter-automated-report-platform]] — 0x727漏洞报告自动化编写平台深度技术解析页
- [[metasploitcoop-collaboration-platform]] — MetasploitCoop后渗透协作平台深度技术解析页
- [[process-injection-tampering-techniques]] — 进程注入与篡改技术体系（含计划任务持久化相关的进程镂空技术对比）
- [[internal-network-pivoting-techniques]] — 内网穿透与横向移动技术体系（持久化作为立足点的后续利用阶段）
- [[cobalt-strike-external-c2-smb-beacon]] — Cobalt Strike SMB Beacon 与 External C2 通信模型（对比 MetasploitCoop 的 C2 协作模式）
- [[c2-redirectors-malleable-c2-profiles]] — C2 重定向器与 Malleable C2 Profile 流量混淆（红队基础设施对比参考）

---

## 更新日志

| 版本 | 日期 | 更新内容 | 维护者 |
|------|------|----------|--------|
| 1.0 | 2021-10-31 | 初始化页面框架，建立月度索引表结构 | 知识库策展人 |
| 1.1 | 2021-10-?? | 新增0x727漏洞报告自动化编写平台开源发布文章详细条目 | 知识库策展人 |
| 1.2 | 2026-11-15 | 新增SchTask计划任务持久化工具开源发布条目（2021-08-05），完善团队工具生态脉络，新增红队工具开发系列专题索引，补充关联知识页面交叉引用 | 知识库策展人 |
| 1.3 | 2026-11-15 | 新增MetasploitCoop后渗透协作平台开源发布条目（2021-09），完善团队2021年8-10月开源工具发布脉络（SchTask→MetasploitCoop→BugReporter），新增详细技术架构、功能特性、部署流程、操作指南、更新日志，补充红队工具开发系列专题索引与关联页面交叉引用 | 知识库策展人 |

---

> **说明**：本页面为索引框架，2021年10月已补全漏洞报告自动化平台开源工具发布条目，2021年9月新增MetasploitCoop后渗透协作平台开源发布条目，2021年8月已补全SchTask计划任务持久化工具开源发布条目。8-9月其他具体文章条目待后续根据公众号历史消息列表逐条补全。如您掌握该时间段内0x727团队发布的具体文章信息，欢迎通过PR或Issue补充完善。

## 来源

- [0x727开源安全团队-202108-202110_4](../sources/0x727开源安全团队-202108-202110_4.md)
