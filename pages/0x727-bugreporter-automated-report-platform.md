---
title: 0x727 BugReporter：漏洞报告自动化生成平台
description: 0x727安全团队开源的漏洞报告自动化生成平台，基于Python/PHP实现项目协同、漏洞管理、模板化报告导出及Nginx安全加固配置。
category: program-analysis
tags:
- '0x727'
- 漏洞管理
- 报告自动化
- Python
- PHP
- Nginx安全配置
- 项目协同
- 开源工具
date: 2023-04-14
updated: '2026-11-15'
---

## 概述

**0x727 BugReporter** 是由 0x727 安全团队开源的一款漏洞报告自动化生成平台，旨在解决安全团队在项目协同、漏洞管理、报告生成等环节的效率痛点。平台采用 **Python + PHP** 混合技术栈，提供从漏洞提交、分类统计、模板化导出到年度汇总报告的全流程自动化能力，并内置 Nginx 安全加固配置建议。

> **项目定位**：根据安全团队定制化协同管理项目安全，可快速查找历史漏洞，批量导出报告。
>
> **技术栈**：Python 3.7、PHP、HTML、JavaScript、CSS
>
> **运行环境**：CentOS / Ubuntu，需 Nginx + PHP + MySQL + Python 3
>
> **作者**：小洲（0x727 团队）

## 核心功能模块

### 首页仪表盘

- 统计团队成员提交漏洞数量
- 可视化展示整个项目漏洞类型分类分布

### 项目管理

| 子模块 | 功能描述 |
|--------|----------|
| **漏洞列表** | 直观查看成员提交的漏洞报告，支持**批量导出报告** |
| **项目分类** | 自定义创建项目分类，按漏洞挖掘需求组织资产 |
| **项目资产** | 查看当前项目关联的域名资产清单 |
| **漏洞分布图** | 图形化展示漏洞类型、严重度等分布情况 |
| **模板列表** | 自定义上传报告模板（Word 模板），导出时按类型选用 |
| **漏洞分类** | 创建漏洞类型分类体系（如：Web 安全漏洞 → XXE 注入） |

### 用户管理

- **用户管理**：创建团队成员账户，支持协同提交漏洞
- **个人中心**：修改个人信息，便于管理员识别与联系

### 网站设置与审计

| 子模块 | 功能描述 |
|--------|----------|
| **网站设置** | 配置 IP 白名单访问控制，提升后台访问权限安全性 |
| **网站日志** | 审计成员访问控制器记录，攻击行为自动记录日志 |

## 版本迭代历史

| 版本 | 核心更新内容 |
|------|--------------|
| **V1.0** | 项目批量提交、按分类批量导出、快速生成年度汇总报告 |
| **V1.1** | **防截图功能**：报告上传图片采用 RC4 加密算法加密，防止图片泄露 |
| **V1.2** | **URL 防篡改**：提升网站安全性，防止恶意构造 URL 请求 |
| **V1.3** | 增加项目资产自动归属、漏洞分布图可视化 |

## 部署与环境配置

### 目录权限要求

| 目录 | 权限 | 说明 |
|------|------|------|
| `classes` | 766 | 类文件 |
| `config` | 766 | 配置文件 |
| `index` | 766 | 主模块 |
| `lib` | 766 | 插件 |
| `public` | 766 | 公共文件 |
| `python_web` | 766 | Word 表格生成模块 |
| `runtime` | 777 | 缓存目录（必须可写） |

> **注意**：非 ROOT 或管理员组权限下运行，除 `runtime` 需 777 外，其余均为 766。

### 安装向导

访问 `http://域名/index.php?m=Install&a=index` 进入安装界面，按步骤完成：
1. 注册协议确认
2. 网站配置（数据库、管理员账号等）
3. 程序自动安装
4. 安装完成提示

### Python 环境部署（CentOS 示例）

```bash
# 安装编译工具链与依赖库
yum -y groupinstall "Development tools"
yum -y install zlib-devel bzip2-devel openssl-devel ncurses-devel \
  sqlite-devel readline-devel tk-devel gdbm-devel db4-devel \
  libpcap-devel xz-devel libffi-devel

# 下载并编译 Python 3.7.0
wget https://www.python.org/ftp/python/3.7.0/Python-3.7.0.tar.xz
tar -xvJf Python-3.7.0.tar.xz
mkdir /usr/local/python3
cd Python-3.7.0
./configure --prefix=/usr/local/python3
make && make install

# 建立软链接
ln -s /usr/local/python3/bin/python3 /usr/local/bin/python3
ln -s /usr/local/python3/bin/pip3 /usr/local/bin/pip3

# 安装报告生成核心依赖
python3 -m pip install docxtpl==0.12.0
```

> `docxtpl` 用于基于 Jinja2 模板引擎渲染 Word (.docx) 报告，平台通过 `python_web` 模块调用 Python 脚本实现模板化导出。

### Nginx 安全加固配置

在站点配置中添加以下规则，防止核心目录被直接访问：

```nginx
# 禁止目录列表
autoindex off;

# 禁止访问核心业务目录
location ^~ /index/ { deny all; }
location ^~ /classes { deny all; }
location ^~ /config { deny all; }
location ^~ /lib { deny all; }
location ^~ /python_web { deny all; }
location ^~ /runtime { deny all; }

# 禁止访问静态资源敏感目录
location ^~ /public/auto/ { deny all; }
location ^~ /public/img/ { deny all; }

# 隐藏 .php 后缀（伪静态）
if (!-e $request_filename) {
    rewrite ^(.*)$ $1.php last;
}
```

**配置要点解析**：

- **目录屏蔽**：采用 `^~` 前缀匹配，优先于正则，直接拒绝访问核心代码、配置、缓存目录，防止源码泄露与缓存遍历。
- **静态资源保护**：`/public/auto/` 与 `/public/img/` 可能包含上传的漏洞截图、证明文件，屏蔽直接访问可配合 V1.1 的 RC4 加密机制双重保障。
- **伪静态重写**：隐藏 `.php` 后缀，降低攻击面暴露，配合框架路由机制使用。

## 技术架构亮点

1. **双语言协作**：PHP 负责 Web 主业务（用户、项目、漏洞 CRUD），Python 负责报告渲染（`docxtpl` + Jinja2），通过 `python_web` 模块桥接调用。
2. **模板化报告**：支持自定义上传 `.docx` 模板，变量占位符对应漏洞字段，实现**一次配置、多项目复用**。
3. **资产自动归属（V1.3）**：项目资产与漏洞自动关联，生成漏洞分布图，辅助管理层决策。
4. **安全纵深防御**：
   - 应用层：URL 防篡改、RC4 图片加密、IP 白名单
   - 服务层：Nginx 目录屏蔽、伪静态、缓存目录隔离
   - 运维层：目录最小权限原则、非 root 运行

## 社区与贡献

- **项目地址**：<https://github.com/0x727/BugRepoter_0x727>
- **问题反馈**：通过 GitHub Issues 提交 Bug 或建议
- **代码贡献**：
  - Bug 修复直接提 PR 到 `dev` 分支
  - 新功能先开 Issue 讨论设计方案，采纳后再提 PR
  - 文档改进同样欢迎 PR
- **分支策略**：`master` 仅发布稳定版，`dev` 为开发分支

## 适用场景与定位对比

| 维度 | 0x727 BugReporter | 通用漏洞管理平台（如 DefectDojo、Faraday） |
|------|-------------------|--------------------------------------------|
| **定位** | 安全团队**报告生成自动化** | 全生命周期漏洞管理、合规审计 |
| **核心优势** | Word 模板化导出、批量年度汇总、中文团队协作友好 | 集成扫描器 API、合规报表、多租户、RBAC 细粒度 |
| **技术栈** | PHP + Python（轻量） | 通常为 Python/Django 或 Java/Spring（重型） |
| **部署复杂度** | 低（LNMP + Python） | 中高（需容器编排、消息队列等） |
| **适用团队** | 中小型攻防团队、红队、SRC 挖掘组 | 大型企业 SDL、合规部门、MSSP 服务商 |

## 相关知识关联

- [[nginx-security-hardening-guide]] — Nginx 安全加固配置最佳实践与常见误区
- [[php-webshell-fundamentals-chopper-analysis]] — PHP Web 交互与文件上传安全机制，理解平台上传模块防护原理
- [[python-ssti-multi-engine-bypass]] — Python 模板引擎渲染机制，对应 `docxtpl`/Jinja2 报告生成原理
- [[vulnerability-mining-recon-aiqicha-fofa]] — 漏洞挖掘侦察方法论，平台的项目资产管理可对接此类资产收集流程
- [[internal-network-pivoting-techniques]] — 内网渗透代理技术，平台可记录横向移动阶段漏洞并生成对应报告章节
- [[threat-attribution-tracing-techniques]] — 威胁溯源取证，平台的日志审计模块可为溯源提供访问审计链

## 参考资料

- 0x727 团队微信公众号原文：《0x727自动化编写报告平台》
- GitHub 仓库：<https://github.com/0x727/BugRepoter_0x727>
- `docxtpl` 官方文档：<https://docxtpl.readthedocs.io/>
- Nginx 官方文档 `location` 匹配优先级：<http://nginx.org/en/docs/http/ngx_http_core_module.html#location>

## 来源

- [0x727开源安全团队-202108-202110_1](../sources/0x727开源安全团队-202108-202110_1.md)
