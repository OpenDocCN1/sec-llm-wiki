---
title: CTFd-Whale + Docker Swarm + Frp 动态靶机平台部署指南
description: 基于 CTFd-Whale 插件结合 Docker Swarm 与 Frp 实现 CTF 比赛动态靶机自动分发、端口映射及实例隔离的完整部署教程，含环境准备、核心组件配置、网络互联、插件参数调优、题目发放模式及常见报错排查。
category: uncategorized
tags:
- CTF
- CTFd
- CTFd-Whale
- Docker Swarm
- Frp
- 动态靶机
- 容器编排
- 渗透测试环境
date: '2023-04-15'
updated: '2026-11-14'
---
## 概述

本文档记录如何在 **CentOS 7** 上利用 **Docker Swarm** 集群模式，配合 **CTFd-Whale** 插件与 **Frp** 反向代理，搭建一套支持**动态实例化、自动端口映射、多容器网络隔离**的 CTF 比赛靶机平台。全流程覆盖从操作系统初始化、Docker 生态安装、核心组件编排、网络拓扑构建、插件参数调优，到题目发放验证与常见故障排查。

> 💡 适用场景：高校/企业内部 CTF 赛事、渗透测试培训平台、漏洞复现靶场自动化交付。  
> 🔗 相关基础环境搭建可参考 [[vmware-ubuntu-security-lab-setup]]、[[web-fundamentals-lamp-wordpress-setup]]。

---

## 环境准备

| 组件 | 版本/规格 | 说明 |
|------|-----------|------|
| 操作系统 | CentOS 7.9 Minimal | 推荐公网 IP 或 NAT 后映射好端口 |
| Docker Engine | 20.10.x (文中用 17.12.1.ce) | 通过阿里云镜像源安装 |
| Docker Compose | 1.25.4 | DaoCloud 加速下载 |
| Python | 3.6 (容器内) | CTFd 运行时 |
| 数据库 | MariaDB 10.4 | `docker-compose` 托管 |
| 缓存 | Redis 4 | `docker-compose` 托管 |
| 反向代理 | Nginx 1.17 | 终结 SSL、转发至 CTFd:8000 |
| Frp | v0.29.0 (服务端/客户端) | 实现动态端口穿透 |

### 系统初始化与换源

```bash
# 1. 更新/换阿里源
yum install -y wget
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all && yum makecache && yum update -y

# 2. 基础工具
yum install -y openssh-server vim git nginx mariadb mariadb-server \
  MySQL-python python-pip gcc python-devel \
  yum-utils device-mapper-persistent-data lvm2 epel-release
```

### Docker 引擎与 Compose 安装

```bash
# Docker CE 源
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum -y install docker-ce-17.12.1.ce

# DaoCloud 加速器
curl -sSL https://get.daocloud.io/daotools/set_mirror.sh | sh -s http://f1361db2.m.daocloud.io

# Docker Compose
curl -L https://get.daocloud.io/docker/compose/releases/download/1.25.4/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
systemctl start docker && systemctl enable docker
```

---

## 核心代码仓库获取

```bash
# CTFd 主程序
git clone https://github.com/glzjin/CTFd.git

# CTFd-Whale 插件（动态靶机核心）
git clone https://github.com/glzjin/CTFd-Whale.git
mv CTFd-Whale ctfd-whale
mv ctfd-whale CTFd/CTFd/plugins/

# Frp 客户端二进制
wget https://github.com/fatedier/frp/releases/download/v0.29.0/frp_0.29.0_linux_amd64.tar.gz
tar -zxvf frp_0.29.0_linux_amd64.tar.gz

# Frp 服务端 Docker 镜像构建仓库
git clone https://github.com/glzjin/Frp-Docker-For-CTFd-Whale
mv Frp-Docker-For-CTFd-Whale frp-docker-for-ctfd-whale
```

---

## Docker Swarm 集群初始化

```bash
docker swarm init
# 若报错 "Cannot connect to the Docker daemon" → systemctl start docker 再重试

# 给当前节点打标签，供 Whale 调度使用
docker node update --label-add='name=linux-1' $(docker node ls -q)
```

> 📌 **关键点**：Swarm 模式下 Whale 通过 `Docker Swarm Nodes` 标签调度容器，必须与节点标签一致。

---

## Frp 服务端部署 (`frp-docker-for-ctfd-whale`)

### 配置 `frps.ini`

```ini
[common]
token = randomme
bind_port = 6490
vhost_http_port = 80
dashboard_port = 7500
```

### 启动

```bash
cd frp-docker-for-ctfd-whale
docker-compose up -d
docker ps  # 确认 frps 容器运行
```

---

## CTFd 栈编排与构建

### 目录结构预期

```
CTFd/
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── nginx/
│   └── http.conf
├── frpc/
│   ├── frpc
│   ├── frpc.ini
│   ├── frpc_full.ini
│   └── LICENSE
└── CTFd/plugins/ctfd-whale/
```

### `Dockerfile` 关键点

- 基础镜像 `python:3.6-alpine`，替换 Alpine 源为阿里云
- `pip` 源指向豆瓣 (`pypi.doubanio.com`)
- **不指定 `gevent` 版本号**，避免编译失败
- 入口脚本 `docker-entrypoint.sh` 首行须为 `#!/bin/bash`

### `requirements.txt` 精简片段

```text
Flask==1.1.1
Werkzeug==0.16.0
...
gevent          # 无版本号
tzlocal==2.1    # 修复时区报错
```

### `nginx/http.conf` 核心

```nginx
upstream app_servers { server ctfd:8000; }
server {
  listen 80;
  client_max_body_size 4G;
  location /events { ... SSE 支持 ... }
  location / { proxy_pass http://app_servers; ... }
}
```

### `frpc/frpc.ini`（客户端配置）

```ini
[common]
token = randomme
server_addr = 172.1.0.4   # frps 容器 IP
server_port = 6490
pool_count = 200
tls_enable = true
admin_addr = 172.1.0.3    # frpc 自身 IP
admin_port = 7400
```

### `docker-compose.yml` 网络拓扑

```yaml
networks:
  default:
  internal:
    internal: true
  frp:
    driver: bridge
    ipam:
      config:
        - subnet: 172.1.0.0/16
  frp-containers:
    driver: overlay
    internal: true
    ipam:
      config:
        - subnet: 172.2.0.0/16

services:
  ctfd:
    networks:
      frp:
        ipv4_address: 172.1.0.2
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # 关键：Whale 调度 Docker API
  frpc:
    image: glzjin/frp:latest
    networks:
      frp:
        ipv4_address: 172.1.0.3
      frp-containers:
    volumes:
      - ./frpc:/conf/
    entrypoint: ["/usr/local/bin/frpc", "-c", "/conf/frpc.ini"]
  # db, cache, ctfd-nginx 同内部网络 internal
```

### 构建与启动

```bash
cd CTFd
docker-compose up -d
# 首次拉取镜像较慢，耐心等待
```

---

## 网络互联修复（关键步骤）

`docker-compose` 启动后，**frpc 与 frps 容器默认不在 `ctfd_frp` 网络**，需手动加入并固定 IP：

```bash
# 查看网络
docker network inspect ctfd_frp

# 加入并指定 IP
docker network connect --ip 172.1.0.3 ctfd_frp ctfd_frpc_1
docker network connect --ip 172.1.0.4 ctfd_frp frp-docker-for-ctfd-whale_frps_1

# 重启生效
docker restart ctfd_frpc_1 frp-docker-for-ctfd-whale_frps_1

# 验证
docker network inspect ctfd_frp
# 应包含 ctfd_ctfd_1(172.1.0.2)、ctfd_frpc_1(172.1.0.3)、frps(172.1.0.4)
```

> ⚠️ **frpc 容器反复重启 90% 因网络/IP 不匹配**，务必核对 `frpc.ini` 与 `frps.ini` 的 `token`、`server_addr`、`admin_addr` 三元组一致。

---

## CTFd-Whale 插件配置（Web 后台）

登录 `http://<IP>:8000` 完成初始化向导后，进入 **管理面板 → 插件 → CTFd-Whale**：

| 参数 | 示例值 | 说明 |
|------|--------|------|
| Docker API URL | `unix:///var/run/docker.sock` | 或 `tcp://<host>:2375` |
| Frp API IP | `172.1.0.3` | frpc 容器 IP |
| Frp API Port | `7400` | frpc admin 端口 |
| Frp Http Domain Suffix | `None` | 自定义域名后缀，无则留空 |
| Frp Http Port | `80` | Frp HTTP 入口端口 |
| Frp Direct IP Address | `<公网IP>` | 玩家直连地址 |
| Frp Direct Minimum Port | `30000` | 动态端口池起始 |
| Frp Direct Maximum Port | `31000` | 动态端口池结束 |
| Max Container Count | `50` | 单用户最大实例数 |
| Max Renewal Times | `3` | 续时次数 |
| Frp config template | 见下方 | 仅 `[common]` 段 |
| Docker Auto Connect Containers | `ctfd_frpc_1` | 实例自动加入的容器名 |
| Docker Dns Setting | `114.114.114.114` | 容器 DNS |
| Docker Swarm Nodes | `linux-1` | 与节点标签一致 |
| Docker Multi-Container Network Subnet | `172.2.0.0/16` | 多容器题内网大段 |
| Docker Multi-Container Network Subnet New Prefix | `24` | 每实例子网掩码 |
| Docker Container Timeout | `3600` | 实例生存秒数 |
| Docker Auto Connect Network | `ctfd_frp-containers` | Overlay 网络名 |

### Frp config template 内容

```ini
[common]
token = randomme
server_addr = 172.1.0.4
server_port = 6490
pool_count = 200
tls_enable = true
admin_addr = 172.1.0.3
admin_port = 7400
```

保存后插件即可调度动态实例。

---

## 题目发放模式验证

### Dynamic Docker 模式（推荐 Swarm）

1. **Challenges → New → Type: Dynamic Docker**
2. **Docker Image**: `ctftraining/qwb_2019_supersqli`（或自建镜像）
3. **Redirect Type**: `http` / `direct`（按 Frp 模式选）
4. **Port**: 容器内监听端口（如 80）
5. **Flag**: 环境变量或文件路径

> 🔗 镜像来源：[CTFTraining](https://github.com/CTFTraining/CTFTraining) 维护大量现成题目镜像。

### Standard 模式（手动 docker-compose）

```bash
mkdir -p ~/CTFTraining/0ctf_2016_unserialize
cd ~/CTFTraining/0ctf_2016_unserialize
# 放入 docker-compose.yml、Dockerfile、flag 等
docker-compose up -d
# 手动在 CTFd 添加 Static 类型题目，Redirect URL 填宿主机 IP:映射端口
```

> ⚠️ Standard 模式需人工回收容器，不适合大规模比赛。

---

## 汉化（可选）

CTFd 2.3.1 可用半汉化包替换：

```bash
# 下载 https://github.com/cxaqhq/ctfd-2.3.1
# 替换 CTFd/CTFd/themes/core 与 CTFd/CTFd/plugins 目录下的模板/静态资源
```

效果：核心菜单、按钮、提示中文化；部分管理页仍为英文。

---

## 常见报错与排查速查表

| 现象 | 可能原因 | 解决命令/操作 |
|------|----------|---------------|
| `frpc` 容器反复重启 | 网络未加入 `ctfd_frp` 或 IP 冲突 | 执行 §6 网络修复；核对 `frpc.ini` `admin_addr` |
| `frpc` 日志 `connection refused` | `admin_addr` 缺失或 `frps` 未就绪 | 补全 `admin_addr=172.1.0.3`，重启 `frpc` |
| `ctfd` 容器起不来 | `docker-entrypoint.sh` 首行非 `#!/bin/bash` | 修改首行后 `docker-compose up -d --build` |
| `gevent` 编译报错 | Alpine 缺编译工具链/版本锁定 | `requirements.txt` 去掉 `gevent` 版本号 |
| `world` 模块报错 | `python`/`python-dev` 包名变动 | `Dockerfile` 改为 `python3` `python3-dev` |
| `ctfd_ctfd_1` 重启 | 缺 `tzlocal` 导致时区异常 | `requirements.txt` 加 `tzlocal==2.1` 重建 |
| MySQL 容器反复重启 | `.data/mysql` 残留数据版本不兼容 | `rm -rf .data/mysql` 后重建 |
| 动态题目长时间 `Pending` | Docker API 不通 / Swarm 节点标签不匹配 | 进 `ctfd` 容器 `python -c "import docker; docker.DockerClient(base_url='unix:///var/run/docker.sock').images.list()"` 验证 |
| Frp API `/api/reload` 404/拒绝 | `frpc.ini` 缺 `admin_addr/admin_port` | 补全配置并 `docker restart ctfd_frpc_1` |

**通用排查三板斧**：

```bash
docker logs <容器名>          # 看报错栈
docker exec -it <ctfd容器> sh # 进容器测试 Docker API / Frp API
docker network inspect <网络> # 核对 IP/连通性
```

---

## 资源与扩展阅读

- CTFd 官方：<https://github.com/CTFd/CTFd>
- CTFd-Whale：<https://github.com/glzjin/CTFd-Whale>
- Frp：<https://github.com/fatedier/frp>
- CTFTraining 题目镜像库：<https://github.com/CTFTraining/CTFTraining>
- 历年 Writeup 合集：<https://github.com/ctfs/write-ups-2016> 等
- 入门学习路线可参考 [[ctf-beginner-self-study-guide]]、[[ctf-misc入门与工具箱]]
- 训练资源避坑指南见 [[cybersecurity-training-resources-guide]]

---

## 结语

完成上述步骤后，你将拥有一套**开箱即用、支持水平扩展、自动回收实例**的 CTF 动态靶机平台。后续可结合 **Prometheus + Grafana** 监控容器资源、接入 **LDAP/OAuth** 统一认证、编写 **Ansible/Terraform** 实现基础设施即代码（IaC）交付，进一步提升运维效率。祝比赛顺利、Flag 满天飞！ 🚩

## 来源

- [0x00实验室-202108-202304_012](../sources/0x00实验室-202108-202304_012.md)
