---
title: 通过篡改 HTTP 响应包绕过认证进入后台的越权漏洞利用技术详解
description: 详细记录一次 CNVD 原创漏洞挖掘实战：通过爱企查与 FOFA 定位闭源系统资产，利用默认口令配合拦截登录响应包将 false 篡改为
  true，实现认证绕过与后台越权访问，并完整复盘 CNVD 提交审核至拿证全流程。
category: uncategorized
tags:
- 认证绕过
- HTTP响应篡改
- 逻辑越权
- CNVD漏洞提交
- 闭源系统挖掘
- 信息收集
- FOFA
- 爱企查
- 默认口令
- 渗透测试实战
date: 2023-04-13
updated: '2026-11-15'
---
## 概述

本页面沉淀一次 **CNVD 原创漏洞证书** 的完整挖掘复盘，核心技术点为 **通过篡改 HTTP 登录响应包（将 `false` 改为 `true`）绕过身份认证，直接进入后台管理界面** 的逻辑越权漏洞。文章涵盖从厂商筛选、资产枚举、漏洞挖掘思路、POC 复现到 CNVD 提交审核拿证的全生命周期，适合作为“闭源系统授权绕过”典型案例的知识库条目。

> **关联页面**：[[cnvd-vulnerability-submission-certificate-case-study]] 同为 CNVD 原创漏洞证书获取实战，可交叉对比两案例在资产收集、漏洞类型、提交话术上的异同。

---

## 漏洞原理与分类

| 维度 | 说明 |
|------|------|
| **漏洞类型** | 认证绕过 / 逻辑越权 / 前台未授权访问后台 |
| **核心成因** | 服务端仅在前端通过返回 `true/false` 控制跳转，**未在后端二次校验会话合法性** |
| **利用方式** | 抓包拦截登录响应，将 `success: false` 篡改为 `success: true` 即可进入后台 |
| **影响范围** | 任意用户（甚至仅知默认账号 `1001`）可无密码登录后台，获取大量用户敏感信息 |
| **CWE 编号** | CWE-306 (Missing Authentication for Critical Function) / CWE-639 (Authorization Bypass Through User-Controlled Key) |

> **防御视角**：前端校验不可信，**所有权限判断必须在服务端会话上下文中强制执行**；登录接口应返回 `Set-Cookie` 建立会话，而非依赖前端布尔值跳转。

---

## 实战复盘：从资产收集到漏洞触发

### 厂商筛选与资产枚举

1. **爱企查** 按“注册资金 ≥ 5000 万 + 软件/设备供应商”筛选目标厂商。  
2. **FOFA** 搜索厂商官网/特征指纹，批量拉取资产列表（IP:Port/域名）。  
3. 资产去重、存活探测后建立待测目标库。

> **工具链参考**：`FOFA API` + `httpx` + `nuclei` 批量指纹识别 → 闭源系统指纹库匹配。

### 闭源系统攻击面梳理

| 攻击面 | 测试手法 | 本案例结果 |
|--------|----------|------------|
| 目录扫描 | `dirsearch` / `feroxbuster` | 无果 |
| 弱口令/默认口令 | 说明书获取默认账号 `1001`，密码任意 | 命中默认账号，但后台功能点无其他漏洞 |
| 前端信息泄露/接口越权 | JS 分析、Swagger/接口文档泄露 | 未发现 |
| **逻辑越权（核心）** | **登录响应包篡改 `false → true`** | **成功绕过认证进入后台** |
| SQLi / RCE | 常规注入/命令执行测试 | 未测出 |

> **关键信息来源**：系统**操作手册/部署文档**常泄露默认账号、接口路径、功能流程——是闭源系统挖掘的“说明书级”情报。

### POC 复现步骤

1. 访问登录页 `http://target:8093/login.aspx`  
2. 用户名填 `1001`（默认管理员），密码任意，点击“在线用户查询/登录”  
3. **Burp Suite 拦截响应包**，定位关键字段（示例）：
   ```json
   {"success": false, "msg": "密码错误", "data": null}
   ```
4. 将 `false` 修改为 `true` 并放行  
5. 浏览器自动跳转至后台主页，获取完整用户列表、配置等敏感数据

![POC 测试示意](https://via.placeholder.com/600x300?text=Burp+Suite+Intercept+Response+false->true)

---

## CNVD 提交与拿证流程

| 阶段 | 关键动作 | 耗时 |
|------|----------|------|
| **漏洞报告撰写** | 包含：厂商证明、资产证明、漏洞详情、POC 步骤、影响评分、修复建议 | 1 天 |
| **CNVD 平台提交** | 登录 CNVD → 原创漏洞提交 → 填写表单上传佐证材料 | 0.5 天 |
| **审核周期** | 形式审查 → 技术复核 → 厂商确认 → 编号分配 | **≈ 15 个工作日** |
| **证书下载** | 审核通过后次周三/四可在个人中心下载 PDF 证书 | 审核通过即时 |

> **避坑指南**：  
> - 必须提供**厂商授权证明**或**公开资产归属佐证**（ICP备案、FOFA截图、爱企查股权穿透）  
> - POC 视频/图片需包含**时间戳、目标地址、关键篡改操作**  
> - 漏洞类型准确选“逻辑缺陷/授权绕过”，避免被归类为“弱口令”导致降级

---

## 通用化检测与防御建议

### 自动化检测思路

```python
# 伪代码：登录响应篡改通用检测
def test_auth_bypass_by_response_tamper(login_url, username, password):
    # 1. 正常登录获取响应特征
    resp = session.post(login_url, data={"user": username, "pwd": password})
    false_patterns = [b'false', b'False', b'0', b'fail', b'error', b'失败']
    if any(p in resp.content for p in false_patterns):
        # 2. 尝试篡改关键字段
        for pat in false_patterns:
            tampered = resp.content.replace(pat, pat.replace(b'false', b'true').replace(b'0', b'1'))
            if check_admin_panel_access(session, tampered):
                return True, pat
    return False, None
```

> 可集成至 **被动扫描器插件**（Burp / Xray / Nuclei 模板），批量排查同类逻辑缺陷。

### 修复与加固清单

| 层级 | 措施 |
|------|------|
| **代码层** | 登录校验逻辑后端化：`if (authenticate(u, p)) { session.setAttribute("uid", u); return redirect("/admin"); } else return 401;` |
| **会话层** | 强制使用 `HttpOnly; Secure; SameSite=Strict` Cookie，禁用 URL 重写/前端 Token 传参 |
| **接口层** | 所有后台接口统一拦截器校验 `session.getAttribute("uid") != null` |
| **审计层** | 记录登录失败/成功、IP、User-Agent，异常登录告警 |
| **SDLC** | 威胁建模阶段识别“前端校验绕过”威胁，代码审计规则纳入“前端返回值授权判断”检出 |

---

## 知识图谱交叉引用

| 相关主题 | 页面 | 关联说明 |
|----------|------|----------|
| CNVD 原创漏洞证书另一实战 | [[cnvd-vulnerability-submission-certificate-case-study]] | 同为 CNVD 拿证全流程，资产收集用爱企查+FOFA，漏洞类型为逻辑越权/授权绕过，可对比提交材料模板 |
| IoT/OT 设备授权绕过 | [[iot-device-compromise-internal-penetration]] | 内网渗透中常见设备默认配置/弱口令/未授权访问，同属“认证授权缺失”大类 |
| WAF 绕过与前端逻辑绕过 | [[waf-bypass-techniques-case-study-ruijie]] | 虽侧重 XSS/WAF，但“前端控制逻辑不可信”思想一致 |
| CTF 实战中的认证绕过 | [[ctf-beginner-self-study-guide]] | Writeup 驱动学习中常见登录绕过题型，适合作为练手靶场 |
| SQL 注入与堆叠查询 | [[qwb2019-随便注-sql注入复现]] | 对比“不同漏洞类型在闭源系统中的挖掘优先级与投入产出比” |

---

## 结语

本案例展示了 **“信息收集精准化 → 闭源系统说明书情报利用 → 简单逻辑缺陷高危化 → 规范化漏洞上报拿证”** 的完整闭环。核心启示：

1. **默认口令 + 说明书** 是闭源系统挖掘的性价比最高切入点  
2. **前端返回值控制跳转** 是典型架构反模式，代码审计/渗透测试应重点排查  
3. **CNVD 提交材料标准化**（资产归属、POC 视频、修复建议）能显著缩短审核周期

> 下一步可尝试：将该检测逻辑封装为 **Nuclei Template** 或 **Burp BCheck**，纳入常规资产巡航扫描器，实现同类漏洞的规模化发现。

---

## 更新记录

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2023-04-13 | 1.0 | 首次沉淀，结构化整理原文归档内容 |
| 2024-12-19 | 1.1 | 补充通用检测伪代码、修复清单、交叉引用表、更新记录 |

## 来源

- [0x6270安全团队-202203-202304_52](../sources/0x6270安全团队-202203-202304_52.md)
