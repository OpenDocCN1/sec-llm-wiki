---
title: LAMP 环境搭建与 WordPress 部署实战
description: 系统梳理基于 Ubuntu 的 LAMP（Apache + MySQL + PHP）环境搭建流程，以及 WordPress CMS 的下载、配置、数据库关联与站点初始化全过程，为后续
  HTTP 抓包分析与 Web 渗透测试奠定基础环境。
category: uncategorized
tags:
- LAMP
- Apache
- MySQL
- PHP
- WordPress
- Ubuntu
- Web渗透测试
- HTTP分析
- 环境搭建
date: 2024-01-15
updated: '2026-11-13'
---

## 概述

本页面记录从零开始在 Ubuntu 系统上搭建 **LAMP（Linux + Apache + MySQL + PHP）** 栈，并在此基础上部署 **WordPress** 内容管理系统的完整操作链路。该环境旨在作为后续 **HTTP 协议抓包分析** 与 **Web 渗透测试实战** 的基础靶场，帮助理解网站运行的底层结构。

> 💡 核心思路：通过亲手搭建一个真实可访问的动态网站，直观掌握 Web 服务器、脚本解释器、数据库三者的交互关系，为后续使用 Burp Suite 等工具分析 HTTP 流量、挖掘漏洞提供实体支撑。

---

## 一、LAMP 核心组件部署

### Web 服务器：Apache + PHP

Apache 负责监听 HTTP 请求、分发静态资源，并通过模块调用 PHP 解释器处理动态脚本，是整个站点的 “大脑”。

#### 安装步骤

```bash
# 更新软件源并安装 Apache 与 PHP
sudo apt-get update
sudo apt-get install apache2
sudo apt-get install php
```

#### 验证安装

```bash
apache2 -v   # 输出版本号即成功
php -v       # 输出版本号即成功
```

#### 启动服务并访问默认页

```bash
cd /etc/init.d/
sudo ./apache2 start
```

在浏览器访问 `http://127.0.0.1`，出现 **Apache2 Ubuntu Default Page** 表示服务正常。

#### 站点根目录

- 默认文档根目录：`/var/www/html`
- 所有网站文件需放置于此目录或其子目录下。

---

### 数据库：MySQL

MySQL 负责持久化存储站点数据（用户表、文章表、配置表等），为动态内容提供支撑。

#### 安装与关联 PHP

```bash
sudo apt-get install mysql-server
sudo apt-get install php-mysql   # 让 PHP 能操作 MySQL
sudo service mysql start
```

#### 创建 WordPress 专用库与用户

进入 MySQL 交互终端：

```bash
mysql -u root
```

执行以下 SQL（示例凭据，生产环境请强化）：

```sql
-- 创建用户
CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'qwe123';

-- 创建数据库
CREATE DATABASE wordpress;

-- 授权
GRANT ALL ON wordpress.* TO 'wordpress'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

---

## 二、WordPress CMS 部署与初始化

### 下载与解压

```bash
cd /var/www/html
wget https://cn.wordpress.org/latest-zh_CN.tar.gz
tar -xzf latest-zh_CN.tar.gz
rm latest-zh_CN.tar.gz
```

解压后生成 `/var/www/html/wordpress` 目录，即 WordPress 站点根目录。

### 运行安装向导

浏览器访问 `http://127.0.0.1/wordpress`，按提示填写数据库信息：

| 字段 | 示例值 |
|------|--------|
| 数据库名 | wordpress |
| 用户名 | wordpress |
| 密码 | qwe123 |
| 数据库主机 | localhost |
| 表前缀 | wp_ （默认） |

若提示无法自动写入 `wp-config.php`，需手动创建：

```bash
cd /var/www/html/wordpress
nano wp-config.php   # 将向导给出的配置内容粘贴保存
```

### 站点基本信息设置

继续向导，填写：

- 站点标题
- 管理员用户名/密码/邮箱
- 是否对搜索引擎可见

完成后即可登录后台 `/wp-admin`，进入主题、插件、文章管理界面。

---

## 三、后续规划：HTTP 流量分析与渗透测试入门

### 工具预备：Burp Suite

- **定位**：Web 渗透测试集成平台，集代理、扫描器、重放器、解码器等模块于一体。
- **用途**：拦截、篡改、重放 HTTP/HTTPS 请求；自动化漏洞扫描；会话分析。

### 学习资源推荐

- 《图解 HTTP》—— 系统梳理 HTTP 协议细节，配合抓包实战理解极佳。
- 结合本环境，可练习：
  - 登录/发文流程的抓包与参数篡改
  - Cookie/Session 窃取与伪造
  - 文件上传、SQLi、XSS 等漏洞复现（后续结合 [[php伪协议与反序列化利用]]、[[qwb2019-随便注-sql注入复现]] 等页面深入）

---

## 四、交叉引用与延伸阅读

| 页面 | 关联点 |
|------|--------|
| [[007攻防实验室]] | 实战靶场环境搭建的宏观背景与系列文章入口 |
| [[ctf-beginner-self-study-guide]] | 新手如何以 “搭建环境 → 复现漏洞 → 沉淀笔记” 闭环推进学习 |
| [[php伪协议与反序列化利用]] | WordPress 基于 PHP，后续可结合伪协议挖掘文件读取/代码执行 |
| [[qwb2019-随便注-sql注入复现]] | MySQL 实战注入技巧，可在本环境数据库层面复现 |
| [[waf-bypass-techniques-case-study-ruijie]] | 实战 WAF 绕过思路，后续可在 WordPress 登录/评论接口尝试 |

---

## 五、常用运维速查表

| 操作 | 命令 |
|------|------|
| 启动 Apache | `sudo systemctl start apache2` |
| 重启 Apache | `sudo systemctl restart apache2` |
| 查看 Apache 状态 | `sudo systemctl status apache2` |
| 启动 MySQL | `sudo systemctl start mysql` |
| 进入 MySQL | `mysql -u wordpress -p` |
| 修改文件权限（如需） | `sudo chown -R www-data:www-data /var/www/html/wordpress` |
| 查看错误日志 | `tail -f /var/log/apache2/error.log` |

---

> 📌 **提示**：本环境仅供学习与授权测试使用，请勿部署于公网生产环境。后续文章将基于此环境演示 Burp Suite 抓包分析 HTTP 交互细节。

## 来源

- [0w1Club-201908-202207_13](../sources/0w1Club-201908-202207_13.md)
