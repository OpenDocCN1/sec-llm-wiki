---
title: Elastic Stack 2021 年 5 月安全漏洞汇总
description: 汇总 2021 年 5 月披露的 Elastic Stack 组件（Elasticsearch、Kibana、Logstash、App Search）多个安全漏洞，涵盖文档泄露、会话超时绕过、跨集群搜索权限绕过、TLS
  证书验证缺陷、Webhook DoS 及 XXE 注入等漏洞详情与影响版本。
category: ai-security
tags:
- Elastic Stack
- Elasticsearch
- Kibana
- Logstash
- App Search
- CVE-2021-22135
- CVE-2021-22136
- CVE-2021-22137
- CVE-2021-22138
- CVE-2021-22139
- CVE-2021-22140
- 文档泄露
- 会话管理
- XXE
- DoS
- TLS 验证
date: '2021-05-14'
updated: '2026-11-12'
---

## 概述

2021 年 5 月，Elastic 官方发布安全公告，披露了影响 Elastic Stack 核心组件的 6 个安全漏洞（CVE-2021-22135 至 CVE-2021-22140）。这些漏洞涉及 **Elasticsearch**、**Kibana**、**Logstash** 与 **Elastic App Search**，主要风险包括：文档/字段级安全策略绕过导致敏感数据泄露、会话超时机制失效、跨集群搜索权限校验缺失、监控功能 TLS 证书验证缺陷、Webhook 动作拒绝服务、以及 App Search 爬虫功能 XXE 注入。

> 同期披露的 Mercedes-Benz MBUX 车载系统漏洞（CVE-2021-23906 至 CVE-2021-23910）亦见于同一安全简报，详见 [[mercedes-benz-mbux-vulnerabilities-2021]]。

---

## 漏洞清单

| CVE 编号 | 组件 | 漏洞类型 | 严重程度 | 影响版本 | 修复版本 |
| --- | --- | --- | --- | --- | --- |
| CVE-2021-22135 | Elasticsearch | 文档/字段级安全绕过（Suggester & Profile API） | 中 | < 7.11.2、< 6.8.15 | 7.11.2、6.8.15 |
| CVE-2021-22136 | Kibana | 会话空闲超时设置不生效 | 低 | < 7.12.0、< 6.8.15 | 7.12.0、6.8.15 |
| CVE-2021-22137 | Elasticsearch | 跨集群搜索文档泄露 | 中 | < 7.11.2、< 6.8.15 | 7.11.2、6.8.15 |
| CVE-2021-22138 | Logstash | 监控功能 TLS 证书验证缺陷 | 中 | 6.4.0 ~ 6.8.14、7.0.0 ~ 7.11.1 | 6.8.15、7.12.0 |
| CVE-2021-22139 | Kibana | Webhook 动作 DoS（连接池耗尽） | 中 | < 7.12.1 | 7.12.1 |
| CVE-2021-22140 | Elastic App Search | Web 爬虫 Beta XXE 注入 | 高 | 7.11.0 ~ 7.11.2 | 7.12.0 |

---

## 详细分析

### CVE-2021-22135：Elasticsearch Suggester 与 Profile API 文档泄露

**影响**：启用 **Document Level Security (DLS)** 或 **Field Level Security (FLS)** 的索引中，Suggester 与 Profile API 本应被禁用，但特定查询可强制启用，导致攻击者可推断受保护文档/字段的存在性。

**技术细节**：
- DLS/FLS 启用时，Elasticsearch 会自动禁用该索引的 `_suggest` 端点与 `profile=true` 参数
- 但通过精心构造的跨索引搜索请求，可绕过该限制并触发 suggester/profiler
- 结果中返回的元数据（如 `_shards`、命中计数）可泄露受保护文档的存在信息

**缓解**：升级至 7.11.2 或 6.8.15；若暂时无法升级，可显式禁用 suggester 与 profile 功能。

---

### CVE-2021-22136：Kibana 会话空闲超时失效

**影响**：配置 `xpack.security.session.idleTimeout` 后，后台轮询请求（如保存仪表盘、检查更新）会重置空闲计时器，导致会话永不过期。

**技术细节**：
- Kibana 内部后台活动（`core/http` 轮询）被错误地视为用户交互
- 会话存储在 Elasticsearch `.kibana_task_manager` 索引中，攻击者若获得长期有效会话 Cookie 可持久访问

**缓解**：升级至 7.12.0 或 6.8.15；临时方案缩短 `lifetime` 配合 `idleTimeout` 使用。

---

### CVE-2021-22137：Elasticsearch 跨集群搜索 (CCS) 权限校验缺失

**影响**：启用 DLS/FLS 时，发起跨集群搜索请求（`cluster_one:index_a,cluster_two:index_b`）不会在远端集群正确传播安全权限，导致远端集群返回本应被过滤的文档。

**技术细节**：
- CCS 请求在协调节点解析权限后，向远端发送的子请求未携带原始用户的安全上下文
- 远端集群以协调节点身份（通常具备更高权限）执行查询，绕过 DLS/FLS

**缓解**：升级至 7.11.2 或 6.8.15；临时禁用 CCS 或在远端集群配置同等严格的 DLS/FLS 规则。

---

### CVE-2021-22138：Logstash 监控功能 TLS 证书验证缺陷

**影响**：配置 `monitoring.elasticsearch.ssl.ca` 指定可信 CA 后，Logstash 仅验证证书链是否由该 CA 签发，**未验证证书 Subject Alternative Name (SAN) 与目标主机名是否匹配**，导致中间人攻击 (MitM) 成为可能。

**技术细节**：
- 监控数据（节点统计、索引统计、管道统计）通过 HTTP 发送至 Elasticsearch 监控集群
- 攻击者若能劫持网络路由（ARP 欺骗、BGP 劫持、DNS 劫持），可使用同一 CA 签发的任意合法证书冒充监控端点
- 可导致监控数据泄露、篡改或注入虚假指标

**缓解**：升级至 6.8.15 或 7.12.0；临时方案启用 `ssl.verification_mode: full`（需 7.10+）或在网络层隔离监控流量。

---

### CVE-2021-22139：Kibana Webhook 动作拒绝服务

**影响**：拥有创建 Webhook 动作权限的攻击者可构造恶意 Webhook，指向响应极慢或返回超大响应体的端点，耗尽 Kibana 服务端 HTTP 连接池，导致所有用户无法使用 Kibana。

**技术细节**：
- Webhook 执行器（`xpack.actions.webhook`）未设置请求超时（`timeout`）与最大响应体大小限制（`maxPayloadBytes`）
- Node.js `http.Agent` 默认连接池 `maxSockets: Infinity`，配合无超时导致连接泄漏
- 攻击者可批量创建/触发 Webhook，快速耗尽文件描述符

**缓解**：升级至 7.12.1；临时方案限制 Webhook 创建权限、在反向代理层面设置超时与响应体大小限制。

---

### CVE-2021-22140：Elastic App Search Web 爬虫 XXE 注入

**影响**：App Search 7.11.0+ 引入的 **Web Crawler Beta** 在抓取 `sitemap.xml` 时使用不安全的 XML 解析器，攻击者可在受控域名下部署恶意 `sitemap.xml`，利用 XXE 读取 App Search 宿主机文件系统任意文件（如 `/etc/passwd`、JVM 密钥库、配置文件）。

**技术细节**：
- 爬虫解析 `sitemap.xml` 时启用了外部实体解析（`DOCTYPE` + `ENTITY`）
- Payload 示例：
  ```xml
  <?xml version="1.0"?>
  <!DOCTYPE root [
    <!ENTITY xxe SYSTEM "file:///etc/passwd">
  ]>
  <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url><loc>http://example.com/&xxe;</loc></url>
  </urlset>
  ```
- 爬虫以 App Search 进程权限运行，可读取进程可访问的所有文件
- 结合 `file://`、`http://`、`ftp://` 协议可实现 SSRF 与内网探测

**缓解**：升级至 7.12.0；若必须使用 7.11.x，暂时禁用 Web Crawler 功能（`crawler.enabled: false`）。

---

## 统一修复建议

| 组件 | 推荐版本 | 备注 |
| --- | --- | --- |
| Elasticsearch | 7.11.2 / 6.8.15 | 修复 CVE-2021-22135、CVE-2021-22137 |
| Kibana | 7.12.1 / 6.8.15 | 修复 CVE-2021-22136、CVE-2021-22139 |
| Logstash | 7.12.0 / 6.8.15 | 修复 CVE-2021-22138 |
| Elastic App Search | 7.12.0 | 修复 CVE-2021-22140 |

> **最佳实践**：生产环境建议统一整栈升级至同一 7.x 小版本（如 7.12.1），避免版本不匹配导致兼容性问题。

---

## 相关安全加固清单

1. **最小权限原则**
   - 为每个 Kibana Space/角色分配最小必要的索引权限
   - 禁用不使用的功能：`xpack.ml.enabled: false`、`xpack.graph.enabled: false` 等
2. **网络分段**
   - 监控流量（Logstash → Elasticsearch）走专用 VLAN/安全组
   - App Search 爬虫出站流量经受控代理，禁止直连内网
3. **审计与告警**
   - 开启 Elasticsearch Audit Logging（`xpack.security.audit.enabled: true`）
   - 监控 Kibana 会话异常存活、Webhook 触发频次、爬虫抓取异常
4. **证书管理**
   - 为所有节点间通信、监控通信、Kibana-ES 通信配置独立 PKI
   - 定期轮换证书，启用 `ssl.verification_mode: full`
5. **版本管理**
   - 订阅 Elastic 安全公告邮件列表
   - 建立定期漏洞扫描与补丁窗口机制

---

## 时间线

| 日期 | 事件 |
| --- | --- |
| 2021-05-11 | Elastic 内部发现并确认上述漏洞 |
| 2021-05-14 | 官方安全公告发布，同步释出修复版本 |
| 2021-05-14 | 本页面首次编录（基于微信公众号安全简报聚合） |

---

## 参考链接

- Elastic 官方安全公告：<https://www.elastic.co/community/security>
- CVE 详情：[CVE-2021-22135](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-22135) · [CVE-2021-22136](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-22136) · [CVE-2021-22137](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-22137) · [CVE-2021-22138](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-22138) · [CVE-2021-22139](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-22139) · [CVE-2021-22140](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-22140)
- 同期 Mercedes-Benz MBUX 漏洞分析：[[mercedes-benz-mbux-vulnerabilities-2021]]

## 来源

- [0th3rs安全团队-201911-202204_007](../sources/0th3rs安全团队-201911-202204_007.md)
