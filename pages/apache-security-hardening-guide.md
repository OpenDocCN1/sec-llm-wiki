---
title: Apache HTTP Server 安全加固配置指南
description: 系统梳理 Apache HTTP Server 核心安全加固配置项：非 root 用户运行、目录访问控制、日志审计、错误页面重定向、目录列举禁用、超时防护、默认文件清理及版本信息隐藏，形成可落地的配置清单与检测验证方法。
category: program-analysis
tags:
- Apache
- HTTP Server
- 安全加固
- Web服务器
- 配置审计
- 运维安全
date: 2024-12-19
updated: '2026-11-16'
---

## 概述

本页面沉淀 Apache HTTP Server（httpd）在生产环境中的核心安全加固配置，涵盖**最小权限运行**、**访问控制**、**审计日志**、**信息隐藏**、**拒绝服务缓解**、**默认文件清理**八大维度。每项给出配置示例、生效验证命令及常见误区说明，便于运维与安全团队纳入基线核查清单。

> 来源：微信公众号「301在路上」归档文章《apache安全配置参考》

---

## 账号隔离：以非 root 用户/组运行

### 原则
- **最小权限**：Apache 进程不应以 `root` 身份长期运行，防止漏洞被利用后直接获得系统最高权限。
- **专用账号**：创建专属系统用户/组，禁止登录 Shell，家目录设为非 Web 目录。

### 配置示例
```bash
# 创建用户组与用户（按需调整 UID/GID）
groupadd -r apachegroup
useradd -r -g apachegroup -s /sbin/nologin -d /var/www -c "Apache HTTP Server" apache
```

```apache
# httpd.conf / httpd-userdir.conf
User apache
Group apachegroup
```

### 验证
```bash
ps -eo user,group,cmd | grep httpd | grep -v grep
# 预期输出：apache apachegroup /usr/sbin/httpd ...
```

### 关联实践
- 结合 [[docker-container-security-fundamentals]] 中 **User Namespace** 与 **Capability** 机制，在容器化部署时进一步收敛权限。
- 参考 [[linux-kernel-hardening-mechanisms]] 启用 **SELinux/AppArmor** 配置文件限制进程文件访问范围。

---

## 目录访问控制：默认拒绝、显式授权

### 核心策略
- **根目录全局拒绝**：`<Directory />` 设置 `Deny from all`，阻断对 Web 根目录之外任意文件的访问。
- **站点目录显式放行**：仅对 DocumentRoot 及必要子目录授予 `Allow from all`。

### 配置示例
```apache
# 全局拒绝
<Directory />
    Order Deny,Allow
    Deny from all
    Options None
    AllowOverride None
</Directory>

# 站点根目录放行
<Directory "/var/www/html">
    Order Allow,Deny
    Allow from all
    Options FollowSymLinks
    AllowOverride None
    Require all granted   # Apache 2.4+ 推荐写法
</Directory>
```

### 版本差异提示
| 版本 | 语法 | 说明 |
|------|------|------|
| 2.2 | `Order Allow,Deny` / `Allow from all` | 兼容旧配置 |
| 2.4+ | `Require all granted` | `mod_authz_host` 新语法，建议统一迁移 |

### 验证
```bash
curl -I http://<server>/etc/passwd
# 预期：403 Forbidden
```

---

## 审计日志：完整记录访问与错误

### 关键指令
| 指令 | 推荐值 | 说明 |
|------|--------|------|
| `ErrorLog` | `logs/error_log` 或 `syslog:local6` | 错误诊断日志，建议同时落盘与发送至集中日志平台 |
| `LogLevel` | `notice` | 避免 `debug` 产生过量噪音，`warn` 可能丢失关键信息 |
| `LogFormat` | `combined` 扩展格式 | 包含 `%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"` |
| `CustomLog` | `logs/access_log combined` | 访问日志轮转策略配合 `logrotate` |

### 推荐配置片段
```apache
LogLevel notice
ErrorLog logs/error_log
ErrorLog syslog:local6          # 同时送 Syslog（需 rsyslog 配合）

LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
CustomLog logs/access_log combined
```

### 日志字段解析
- `%h`：客户端 IP
- `%u`：认证用户（`-` 表示匿名）
- `%t`：请求时间 `[DD/Mon/YYYY:HH:MM:SS +ZZZZ]`
- `%r`：请求行 `"GET /path HTTP/1.1"`
- `%>s`：最终响应状态码
- `%b`：响应字节数（`-` 表示 0）
- `%{Referer}i` / `%{User-Agent}i`：请求头字段

### 集中化建议
- 结合 [[xd-security-incident-response-notes]] 中 **日志分析** 章节，将 Apache 日志接入 ELK / Loki / Splunk，配置**暴力破解**、**路径遍历**、**异常 User-Agent** 等告警规则。
- 启用 `mod_log_forensic` 或 `mod_security` 审计引擎获取请求体全量数据。

---

## 错误页面重定向：避免信息泄露

### 风险
默认错误页面会暴露 **Apache 版本**、**操作系统**、**模块列表**，辅助攻击者指纹识别与漏洞匹配。

### 配置示例
```apache
ErrorDocument 400 /errors/400.html
ErrorDocument 401 /errors/401.html
ErrorDocument 403 /errors/403.html
ErrorDocument 404 /errors/404.html
ErrorDocument 405 /errors/405.html
ErrorDocument 500 /errors/500.html
ErrorDocument 502 /errors/502.html
ErrorDocument 503 /errors/503.html
```

### 页面内容规范
- **统一品牌风格**，不泄露技术栈细节。
- **友好提示** + **联系方式/搜索入口**，避免堆栈跟踪、SQL 片段等敏感信息。
- 静态 HTML 存放于 Web 根目录外，通过 `Alias /errors/ /var/www/errors/` 引入，防止被直接下载。

### 验证
```bash
curl -I http://<server>/nonexistent_page_xyz
# 预期：302 -> /errors/404.html 最终 200 OK，且响应体为自定义页面
```

---

## 禁用目录列举：防止敏感文件枚举

### 原理
`Options Indexes` 导致无 `DirectoryIndex` 文件时返回目录列表，泄露备份文件、源码、配置等。

### 配置
```apache
<Directory "/var/www/html">
    Options FollowSymLinks        # 移除 Indexes
    AllowOverride None
    Require all granted
</Directory>

<IfModule dir_module>
    DirectoryIndex index.html index.php  # 明确默认首页优先级
</IfModule>
```

### 验证
```bash
mkdir -p /var/www/html/testdir
curl http://<server>/testdir/
# 预期：403 Forbidden 或 404（而非目录列表）
```

---

## 拒绝服务缓解：超时与连接控制

### 关键参数
| 参数 | 推荐值 | 说明 |
|------|--------|------|
| `Timeout` | `10`~`30` 秒 | 请求读取/响应发送总超时，防止慢速攻击 |
| `KeepAlive` | `On` | 启用持久连接，减少 TCP 握手开销 |
| `KeepAliveTimeout` | `5`~`15` 秒 | 空闲连接保持时间，过大易耗尽 worker |
| `MaxKeepAliveRequests` | `100` | 单连接最大请求数，防止单连接长期占用 |
| `AcceptFilter` | `http data` / `https data` | 内核级缓冲（Linux `TCP_DEFER_ACCEPT`），降低用户态唤醒 |

### 配置示例
```apache
Timeout 30
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 10
AcceptFilter http data
AcceptFilter https data
```

### 进阶防护
- 接入 **mod_reqtimeout** 细粒度控制请求头/体接收超时。
- 部署 **mod_evasive** / **mod_security** 速率限制规则。
- 参考 [[redteam-hw-opsec-guidelines]] 中 **流量特征对抗** 思路，配合 WAF/边界设备实施分层防护。

---

## 默认文件清理：减少攻击面

### 必删清单
| 路径/类型 | 风险 | 清理命令 |
|-----------|------|----------|
| `/usr/local/apache2/htdocs/*` | 默认欢迎页泄露版本/路径 | `rm -rf /usr/local/apache2/htdocs/*` |
| `/usr/local/apache2/cgi-bin/*` | 示例 CGI 脚本可能含漏洞 | `rm -rf /usr/local/apache2/cgi-bin/*` |
| `/usr/local/apache2/manual/` | 手册页面泄露版本/模块 | `rm -rf /usr/local/apache2/manual` |
| 源码包 `/path/to/httpd-*.tar.gz` | 便于攻击者本地分析漏洞 | `rm -rf /path/to/httpd-*` |

### 自动化建议
- 将清理步骤写入 **Ansible/ SaltStack/ Dockerfile** 部署流程，实现不可变基础设施。
- 结合 [[cisp-pte-penetration-testing-exam-guide]] 中 **文件上传/目录遍历** 检测思路，定期扫描 Web 目录残留敏感文件。

---

## 隐藏版本信息：最小化指纹暴露

### 核心指令
| 指令 | 推荐值 | 作用 |
|------|--------|------|
| `ServerTokens` | `Prod` | `Server: Apache`（仅产品名） |
| `ServerSignature` | `Off` | 错误页面底部不显示版本/OS 信息 |

### 配置
```apache
ServerTokens Prod
ServerSignature Off
```

### 验证
```bash
curl -I http://<server>/
# 预期：Server: Apache （无版本号、无 OS 信息）

curl -I http://<server>/nonexistent
# 预期：错误页面无 Apache 版本签名
```

### 进阶：Header 重写
```apache
# 需加载 mod_headers
Header unset Server
Header always set Server "WebServer"
```
> 注：`Header unset Server` 需在 `ServerTokens Prod` 之后生效，建议结合 **mod_security** 规则 `SecServerSignature` 统一篡改。

---

## 配置变更管理与合规核查

### 变更流程
1. **备份**：`cp httpd.conf httpd.conf.bak.$(date +%F)`
2. **语法检查**：`apachectl configtest` / `httpd -t`
3. **灰度发布**：`apachectl graceful` 平滑重载
4. **验证**：自动化脚本核对上述 8 项检查点
5. **记录**：纳入 CMDB 变更单，关联工单号

### 自动化核查脚本片段
```bash
#!/usr/bin/env bash
# apache_hardening_audit.sh
CONF="/etc/httpd/conf/httpd.conf"

check() {
  local pattern="$1" desc="$2"
  if grep -Eq "$pattern" "$CONF"; then
    echo "[PASS] $desc"
  else
    echo "[FAIL] $desc"
  fi
}

check '^User\s+apache$'           "非 root 用户运行"
check '^Group\s+apachegroup$'     "非 root 组运行"
check 'ServerTokens\s+Prod'       "隐藏版本号"
check 'ServerSignature\s+Off'     "隐藏签名"
check 'Options.*FollowSymLinks'   "无 Indexes"
check 'ErrorDocument\s+404'       "自定义错误页"
check 'LogLevel\s+notice'         "日志级别"
check 'Timeout\s+[0-9]+'          "超时设置"
```

---

## 交叉引用与延伸阅读

| 主题 | 关联页面 | 说明 |
|------|----------|------|
| Web 服务器指纹识别与对抗 | [[observerward-0x727-web-fingerprint-tool]] | ObserverWard 指纹库规则编写 |
| 容器化 Apache 加固 | [[docker-container-security-fundamentals]] | Namespace/Capability/Seccomp 落地 |
| 日志审计与应急响应 | [[xd-security-incident-response-notes]] | 统一日志接入、溯源取证流程 |
| 红队视角的 Web 攻击面 | [[info-gathering-tools-collection]] | 资产测绘、目录扫描、指纹识别工具链 |
| 内核级防护机制 | [[linux-kernel-hardening-mechanisms]] | Grsecurity/PaX、内存保护、CFI |
| 渗透测试基线核查 | [[cisp-pte-penetration-testing-exam-guide]] | 合规检查项映射 |

---

## 变更记录
| 日期 | 版本 | 变更摘要 |
|------|------|----------|
| 2024-12-19 | 1.0 | 初始版本，基于「301在路上」归档文章结构化沉淀 |

## 来源

- [301在路上-201508-202208_030](../sources/301在路上-201508-202208_030.md)
