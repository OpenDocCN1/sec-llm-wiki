---
title: Web应用安全评审Checklist：SDLC需求阶段风险识别清单
description: 系统梳理Web应用在SDLC需求阶段的安全评审检查清单，覆盖业务场景威胁建模、OWASP SDL实践参考、评审实操技巧及跨阶段风险前置解决策略，助力安全左移落地。
category: program-analysis
tags:
- Web应用安全
- SDLC
- 安全评审
- 威胁建模
- OWASP SDL
- 需求阶段
- Checklist
- 安全左移
date: 2024-01-15
updated: '2026-11-15'
---

## 概述

本页面沉淀自微信公众号文章《WEB应用安全评审Checklist》，聚焦 **SDLC（软件开发生命周期）需求阶段** 的安全风险识别与评审实践。核心目标是通过结构化清单，在产品设计、编码前将安全风险前置暴露、前置解决，实现「安全左移」，大幅降低后期修复成本。

> **适用场景**：需求评审会、设计评审会、架构安全评审、上线前安全把关  
> **参考标准**：OWASP Software Assurance Maturity Model (SAMM)、OWASP SDL、Microsoft SDL、ISO 27034  
> **交付物**：风险识别清单、威胁建模文档、安全需求规格说明、评审缺陷跟踪表

---

## 一、 评审前准备：上下文收集与建模

### 业务场景拆解

| 维度 | 关键问题 | 产出物 |
|------|----------|--------|
| **核心业务流程** | 资金流向、数据流向、权限流向 | 业务流程图、数据流图 (DFD) |
| **用户角色体系** | 匿名/注册/内部/管理员/运维/三方服务商 | 角色-权限矩阵、RBAC/ABAC 模型草案 |
| **外部依赖** | 三方支付、短信网关、云存储、身份提供商 (IdP) | 供应链依赖清单、接口契约、SLA 与安全条款 |
| **合规红线** | 等保二级/三级、GDPR、个保法、PCI-DSS、行业监管 | 合规映射表、数据分级分类清单 |

> **实操技巧**：要求产品经理提供 **用例图 + 泳道图 + 异常流描述**，缺一不可。异常流往往藏着最多逻辑漏洞。

### 威胁建模轻量化落地

采用 **STRIDE + 攻击树** 混合模式，针对每个业务场景产出威胁模型：

| STRIDE 分类 | 典型需求阶段风险示例 | 对应安全需求 (示例) |
|-------------|----------------------|---------------------|
| **S** Spoofing | 手机号登录无防暴力破解、单点登录 (SSO) 令牌可重放 | 强制 MFA、令牌一次性/短时效、设备指纹绑定 |
| **T** Tampering | 订单金额前端可篡改、API 参数无签名校验 | 关键参数服务端二次计算、请求签名/摘要、防重放机制 |
| **R** Repudiation | 关键操作无审计日志、日志可被管理员删除 | 不可篡改审计链 (WORM/区块链锚定)、关键操作双人复核 |
| **I** Information Disclosure | 错误回显堆栈、接口未脱敏返回身份证/手机号 | 统一错误处理、字段级脱敏策略、API 响应白名单机制 |
| **D** Denial of Service | 无限制文件上传导致磁盘耗尽、长查询无超时 | 限流熔断、资源配额、异步削峰、查询复杂度限制 |
| **E** Elevation of Privilege | 横向越权 (IDOR)、垂直越权 (普通用户访问管理接口) | 强制服务端授权检查、资源级权限模型、零信任网络分段 |

> **工具链推荐**：Microsoft Threat Modeling Tool、OWASP Threat Dragon、IriusRisk、自研威胁建模平台  
> **交叉引用**：[[xd-security-logic-vulnerability-notes-day33-36]]（越权漏洞类型与检测）、[[xd-security-pentest-basic-stage-notes]]（基础漏洞类型速查）

---

## 二、 核心评审清单：按安全域划分

### 身份认证与会话管理

| # | 检查项 | 判断依据 | 常见缺陷模式 |
|---|--------|----------|--------------|
| AUTH-01 | 是否强制多因子认证 (MFA) 覆盖高敏感操作？ | 合规要求、威胁模型 | 仅密码登录、短信验证码可被劫持 (SIM Swap) |
| AUTH-02 | 会话 ID 生成是否使用 CSPRNG？长度 ≥ 128 bit？ | NIST SP 800-63B、OWASP ASVS | 自定义弱算法、时间戳可预测、Session Fixation |
| AUTH-03 | 会话是否设置 `Secure`、`HttpOnly`、`SameSite=Strict/Lax`？ | Cookie 安全属性标准 | 缺失属性导致 XSS 窃取、CSRF 跨站请求 |
| AUTH-04 | 登录/注册/找回密码是否实施账户枚举防护？ | OWASP Authentication Cheat Sheet | 响应时间差异、错误消息泄露用户存在性 |
| AUTH-05 | 单点登录 (SSO/OIDC/SAML) 回调地址是否严格校验？ | RFC 6749、OIDC Core | 开放重定向导致令牌劫持、RP Initiated Logout 缺失 |
| AUTH-06 | 密码策略是否符合 NIST 800-63B (禁用周期性轮换、检查泄露库)？ | 现代密码指南 | 强制复杂度导致弱密码复用、未对接 HaveIBeenPwned |
| AUTH-07 | 会话并发控制、异地登录告警、强制下线能力是否就绪？ | 业务风控需求 | 无感知账号被盗用、会话劫持持久化 |

> **关联页面**：[[jwt漏洞原理与实战利用]]（JWT 算法混淆、kid 注入、None Algorithm）、[[openid-connect-acr-amr-2fa-bypass]]（OIDC acr_values 降级绕过 2FA）

### 授权与访问控制

| # | 检查项 | 判断依据 | 常见缺陷模式 |
|---|--------|----------|--------------|
| AUTHZ-01 | 是否采用 **默认拒绝**、显式授权模型？ | 零信任原则、OWASP ASVS 4.0 | 基于角色的隐式放行、匿名接口过度暴露 |
| AUTHZ-02 | 资源级权限检查是否在 **服务端强制执行** (非前端隐藏)？ | 纵深防御 | 前端按钮隐藏即「授权」、IDOR 批量遍历 |
| AUTHZ-03 | 是否实现 **水平/垂直越权** 统一拦截框架 (Filter/Interceptor/AOP)？ | 统一授权中间件 | 每个 Controller 手写校验、漏校验、逻辑不一致 |
| AUTHZ-04 | 敏感操作是否引入 **动态风控决策** (设备、IP、行为、威胁情报)？ | 自适应认证、RBA | 静态规则易被绕过、无法应对凭证填充攻击 |
| AUTHZ-05 | API 网关/服务网格层面是否有 **细粒度授权策略** (OPA/Rego、Casbin)？ | 微服务授权最佳实践 | 网关仅做粗粒度路由、服务间调用无 mTLS/授权 |
| AUTHZ-06 | 管理后台、运维接口、定时任务、内部 RPC 是否纳入统一授权体系？ | 攻击面管理 | 端口直通内网、默认弱口令、未受审计保护 |

> **关联页面**：[[xd-security-logic-vulnerability-notes-day33-36]]（IDOR、越权检测工具链）、[[oasys-system-code-audit]]（拦截器鉴权逻辑缺陷案例）

### 输入验证与输出编码

| # | 检查项 | 判断依据 | 常见缺陷模式 |
|---|--------|----------|--------------|
| INVAL-01 | 是否建立 **统一输入验证框架** (白名单、正则、长度、类型、编码)？ | OWASP Input Validation Cheat Sheet | 分散校验、黑名单绕过、双重编码绕过 |
| INVAL-02 | 文件上传是否实施 **内容检测 + 存储隔离 + 访问控制** 三重防护？ | 《文件上传漏洞防御指南》 | 仅校验扩展名/Content-Type、解析漏洞、条件竞争 |
| INVAL-03 | 富文本/Markdown 渲染是否使用 **成熟消毒库** (DOMPurify、Bluemonday)？ | XSS 防御最佳实践 | 正则过滤标签、黑名单属性、CSP 缺失 |
| INVAL-04 | SQL/NoSQL/OS 命令/LDAP/XPath 等注入面是否 **全链路参数化/预编译**？ | OWASP Top 10 A03:2021 | 拼接语句、ORM 原生查询滥用、存储过程注入 |
| INVAL-05 | 反序列化入口 (Java/Php/Python/.NET) 是否 **禁用/白名单/签名校验**？ | 反序列化防御指南 | 任意类反序列化、Gadget Chain 利用、PHAR/YSOSERIAL |
| INVAL-06 | API 参数是否定义 **OpenAPI/Protobuf/GraphQL Schema** 并强制校验？ | 契约测试、Schema-Driven Development | 无契约、文档与实现脱节、Mass Assignment |

> **关联页面**：[[php-file-inclusion-vulnerability]]（LFI/RFI 利用链）、[[php-webshell-fundamentals-chopper-analysis]]（上传绕过实战）、[[thinkphp5-deserialization-chain-analysis]]（反序列化链分析）、[[java-preparedstatement-sql-injection-defense]]（预编译防御原理）、[[fastjson-deserialization-gadgets-shiro-anteros]]（Fastjson 黑名单绕过）

### 敏感数据保护

| # | 检查项 | 判断依据 | 常见缺陷模式 |
|---|--------|----------|--------------|
| DATA-01 | 静态存储：PII/密钥/证书是否 **加密存储** (AES-256-GCM、国密 SM4)？ | 等保、GDPR Art.32、PCI-DSS | 明文存储、自研加密、密钥硬编码、ECB 模式 |
| DATA-02 | 传输加密：全站 **TLS 1.2+**、HSTS、证书透明度、HPKP/Expect-CT？ | RFC 7540、Mozilla SSL Config | 明文 HTTP、自签证书、弱套件、证书吊销未检查 |
| DATA-03 | 密钥管理：是否引入 **KMS/HSM/密钥轮换/分级授权/审计**？ | NIST SP 800-57、云厂商 KMS | 密钥写死代码/配置/镜像、无轮换、权限过大 |
| DATA-04 | 脱敏策略：日志/报表/导出/客服工具是否 **字段级动态脱敏**？ | 最小权限、数据分级 | 全量导出、测试环境用真实数据、掩码规则可逆 |
| DATA-05 | 数据销毁：账号注销、订单归档、备份过期是否有 **不可恢复销毁流程**？ | GDPR Art.17、数据留存合规 | 仅标记删除、备份未同步销毁、碎片重组风险 |

> **关联页面**：[[cve-2023-24055-keepass-plaintext-transmission]]（配置文件明文凭据泄露）、[[lm-ntlm-hash-generation-analysis]]（Hash 生成与存储安全）

### 业务逻辑与工作流安全

| # | 检查项 | 判断依据 | 常见缺陷模式 |
|---|--------|----------|--------------|
| BIZ-01 | 关键状态机 (订单/支付/审批/提现) 是否 **形式化建模并校验状态迁移合法性**？ | 状态机设计模式、Petri Net | 并发绕过、重复提交、状态回滚、金额篡改 |
| BIZ-02 | 幂等性设计：支付/扣款/发券/发短信等 **非幂等操作是否有幂等键/去重表**？ | 分布式系统幂等模式 | 重复扣款、刷单、短信轰炸、优惠券薅羊毛 |
| BIZ-03 | 业务限流：抢购/秒杀/报名/投票是否 **应用层+网关层双重限流**？ | 令牌桶、漏桶、滑动窗口 | 仅前端限制、API 无限流、脚本秒杀 |
| BIZ-04 | 价格/折扣/积分/库存等 **核心计算逻辑是否服务端闭环、审计留痕**？ | 财务级准确性 | 前端计算、隐藏字段传价格、浮点数精度丢失 |
| BIZ-05 | 多步骤流程 (向导/分期/分账) 是否防 **步骤跳过、参数回溯、上下文污染**？ | 工作流引擎安全 | URL 直接访问后续步骤、Session 固化攻击 |
| BIZ-06 | 撤销/退款/逆向操作是否有 **对抗性风控** (频次、金额、关联账号、设备指纹)？ | 羊毛党对抗、黑产画像 | 无限制退款、自动化脚本批量撸单 |

> **关联页面**：[[xd-security-logic-vulnerability-notes-day33-36]]（支付篡改、多阶段绕过）、[[card-game-platform-penetration-test-case-study]]（弱口令+SQL注入获取OS Shell实战）

### 基础设施与部署安全

| # | 检查项 | 判断依据 | 常见缺陷模式 |
|---|--------|----------|--------------|
| INFRA-01 | 容器镜像是否 **扫描漏洞/恶意代码/敏感信息/配置错误** (Trivy、Clair、Syft)？ | DevSecOps、SLSA | 基础镜像旧漏洞、root 运行、密钥嵌入镜像 |
| INFRA-02 | Kubernetes 运行时是否落实 **Pod Security Standards、NetworkPolicy、RBAC 最小权限、Admission Controller**？ | CIS K8s Benchmark、NSA/CISA Guidance | 特权容器、HostNetwork、默认 SA、无网络隔离 |
| INFRA-03 | 服务间通信是否 **mTLS (Istio/Linkerd/Cilium)、服务网格授权策略**？ | 零信任网络、SPIFFE/SPIRE | 明文 HTTP、服务发现泄露、横向移动无阻隔 |
| INFRA-04 | CI/CD 流水线是否集成 **SAST/DAST/SCA/秘钥扫描/镜像签名/部署审批**？ | SLSA Level 3、GitOps | 手工部署、无门禁、依赖投毒、供应链攻击 |
| INFRA-05 | 日志/指标/链路追踪是否 **结构化、脱敏、集中存储、告警覆盖安全事件**？ | 可观测性、合规审计 | 明文日志、无关联 TraceID、安全事件无告警 |
| INFRA-06 | 灾备演练：RPO/RTO 指标是否 **每季度实战演练、文档化、纳入考核**？ | 业务连续性管理、ISO 22301 | 仅有备份无恢复演练、跨地域单点故障 |

> **关联页面**：[[docker-container-security-fundamentals]]（容器逃逸、K8s渗透测试）、[[kubernetes-penetration-testing]]（凭据窃取、Master节点隔离）、[[c2-redirectors-malleable-c2-profiles]]（C2基础设施隐匿）

---

## 三、 评审实操流程与交付规范

### 评审会议模板 (建议 60-90 分钟/场景)

| 阶段 | 时长 | 主导角色 | 关键动作 | 产出 |
|------|------|----------|----------|------|
| **背景同步** | 10 min | PM/架构师 | 讲解业务流程图、DFD、数据分级、合规要求 | 共识文档 |
| **威胁枚举** | 25 min | 安全工程师 | 引导全员按 STRIDE 逐组件识别威胁，记录攻击场景 | 威胁清单 |
| **风险定级** | 15 min | 全员投票 | 采用 DREAD/CVSS 4.0/自定义模型 定性/定量评分 | 风险等级表 |
| **对策协商** | 20 min | 架构师/开发/安全 | 针对 High/Medium 风险给出 **技术对策/补偿控制/验收标准** | 整改计划单 |
| **决策归档** | 5 min | 安全负责人 | 确认残留风险、豁免审批、跟踪责任人、验收节点 | 评审纪要、Jira/Epic |

### 缺陷跟踪与验收闭环

| 字段 | 说明 | 示例 |
|------|------|------|
| **Defect ID** | SEC-REQ-YYYYMMDD-XXX | SEC-REQ-20240115-001 |
| **关联需求/用例** | 双向追踪 | REQ-ORDER-003 (并发下单扣款) |
| **威胁分类** | STRIDE + CWE | Spoofing + CWE-306 (Missing Authentication) |
| **风险等级** | Critical/High/Medium/Low/Info | High (CVSS 4.0: 8.2) |
| **整改方案** | 技术对策 + 代码/配置/流程变更 | 引入分布式锁 + 幂等键 + 数据库唯一索引 |
| **责任人/截止日期** | 开发/架构/运维 | @backend-lead / 2024-02-01 |
| **验收标准** | 自动化测试用例/渗透测试/代码审计 | 并发 1000 QPS 无重复扣款、单元测试覆盖率 ≥ 90% |
| **验收结果** | Pass/Fail/Deferred + 证据链接 | Pass - Jenkins #1234、测试报告链接 |
| **残留风险确认** | 业务方签字、安全负责人复核 | PM @zhangsan 确认接受 0.01% 极低概率竞态 |

### 评审效能度量指标

| 指标 | 目标值 | 统计口径 |
|------|--------|----------|
| **需求阶段缺陷发现率** | ≥ 60% 总安全缺陷 | (需求评审发现缺陷数 / 全生命周期安全缺陷总数) |
| **评审覆盖率** | 100% 核心业务场景 | (已评审核心场景数 / 核心场景总数) |
| **整改按时关闭率** | ≥ 95% | (按期关闭缺陷数 / 承诺关闭缺陷数) |
| **残留风险接受率** | ≤ 5% (仅 Low/Info) | (业务接受残留风险数 / 总风险数) |
| **评审人均工时** | ≤ 4 人天/场景 | 含准备、会议、纪要、跟踪 |

---

## 四、 OWASP SDL / Microsoft SDL 映射对照表

| SDL 阶段 | OWASP SAMM 业务职能 | 本 Checklist 对应章节 | 关键产出物 |
|----------|---------------------|----------------------|------------|
| **Training** | Governance → Education & Guidance | 前置知识储备 | 安全编码规范、威胁建模指南、Checklist 版本库 |
| **Requirements** | Design → Threat Assessment | **第 1-2 章** | 安全需求规格、威胁模型、风险登记册 |
| **Design** | Design → Security Requirements | 第 2 章 (技术对策设计) | 安全架构文档、数据流加密设计、授权模型 |
| **Implementation** | Implementation → Secure Build / Secure Deployment | 第 2 章 (编码规范映射) | SAST 规则集、依赖白名单、密钥管理库 |
| **Verification** | Verification → Security Testing | 第 3 章 (验收标准) | 渗透测试范围、DAST 策略、混沌工程场景 |
| **Release** | Operations → Incident Management | 第 3 章 (部署门禁) | 发布清单、应急预案、回滚演练记录 |
| **Response** | Operations → Environment Hardening | 第 2.6 章 (基础设施) | 漏洞应急响应 SLA、补丁管理、威胁情报订阅 |

> **参考资源**：
> - OWASP SDL PDF：<http://www.owasp.org.cn/OWASP_Events/SSDL.pdf>
> - SecPulse 实战解读：<https://www.secpulse.com/archives/93058.html>
> - Microsoft SDL 官方指南：<https://www.microsoft.com/en-us/securityengineering/sdl/>

---

## 五、 进阶扩展：从 Checklist 到体系化能力建设

### Checklist 迭代机制

1. **版本化管理**：Git 仓库维护 `checklist/v{major}.{minor}.md`，每季度发布 Minor、重大事件发布 Major
2. **红队反馈闭环**：每次红队演练/HVV/真实事件复盘，提取 **新攻击面、新绕过技巧** 回炉更新 Checklist
3. **行业标准同步**：跟踪 OWASP Top 10、CWE Top 25、ATT&CK 企业矩阵、等保 2.0、关基条例新要求
4. **业务线定制化**：电商/金融/政企/医疗/物联网等垂直域建立 **领域扩展包** (如支付风控、医疗数据脱敏、工控协议安全)

### 工具化赋能

| 能力层 | 典型工具/平台 | 集成点 |
|--------|--------------|--------|
| **威胁建模自动化** | 自研/Threat Dragon API、IriusRisk CI/CD 插件 | 需求管理系统 (Jira/飞书/禅道) Webhook 触发建模任务 |
| **策略即代码** | OPA/Rego、Casbin、Cedar | API 网关、服务网格、K8s Admission Controller、CI 门禁 |
| **自动化验收** | 契约测试、安全单测模板、渗透测试编排平台 | 流水线 Quality Gate、发布审批单自动生成 |
| **知识图谱** | Neo4j/GraphDB 存储 威胁-对策-缺陷-代码-测试 用例关联 | 影响分析、回归测试选集、新人培训推荐 |

### 组织文化落地

- **安全冠军计划**：每个研发小组指定 1-2 名 Security Champion，负责 Checklist 落地、一线答疑、反馈改进
- **评审 KPI 纳入绩效**：需求阶段缺陷发现率、整改及时率、残留风险接受审批规范性
- **游戏化演练**：定期举办「威胁建模马拉松」「安全设计评审 PK 赛」，产出优秀案例库

---

## 六、 速查卡片：需求评审「三十六计」口诀版

> 便于会议前快速过脑、会中对号入座、会后自查补漏

| 类别 | 口诀 | 对应清单编号 |
|------|------|--------------|
| **认证** | MFA 全覆盖、会话强随机、Cookie 三属性、枚举要防范、SSO 严校验、密码新策略、并发有感知 | AUTH-01~07 |
| **授权** | 默认拒绝、服务端强校、统一框架管、动态风控决、网关细粒度、后台运维纳管 | AUTHZ-01~06 |
| **输入** | 白名单验证、上传三重防、富文本消毒、参数化全链路、反序列化禁/白/签、Schema 强契约 | INVAL-01~06 |
| **数据** | 存储强加密、传输 TLS 1.2+、密钥管生命周期、脱敏动态字段、销毁不可逆 | DATA-01~05 |
| **业务** | 状态机形式化、幂等键防重、双层限流抗刷、核心算服务端、流程防跳步、逆向对抗风控 | BIZ-01~06 |
| **设施** | 镜像必扫描、K8s 硬标准、服务网格 mTLS、流水线全门禁、日志结构化脱敏、灾备实战演练 | INFRA-01~06 |

---

## 七、 附录：常用资源链接库

| 分类 | 资源 | 说明 |
|------|------|------|
| **标准规范** | OWASP ASVS 4.0.3、OWASP MASVS、NIST SSDF、ISO 27034、等保 2.0 测评准则 | 合规基线 |
| **威胁建模** | Microsoft Threat Modeling Tool、OWASP Threat Dragon、IriusRisk、STRIDE/LINDDUN/ATT&CK 映射表 | 建模工具与方法 |
| **代码审计** | SonarQube/Semgrep/CodeQL 规则包、SpotBugs FindSecBugs、Gosec、Bandit、PHPStan 安全规则 | SAST 落地 |
| **依赖管理** | OWASP Dependency-Check、Snyk、Dependabot、OSV-Scanner、Syft/Grype (SBOM) | SCA/SBOM |
| **运行时防护** | OpenRASP、ModSecurity CRS 3.4、Coraza、eBPF 运行时监控 (Tetragon/Falco) | RASP/WAF/Runtime |
| **渗透测试** | Burp Suite Pro、OWASP ZAP、Nuclei Templates、SQLMap、Xray、Pocsuite3 | DAST/IAST/工具化 |
| **威胁情报** | ATT&CK Navigator、MISP、OpenCTI、VirusTotal、FOFA/Quake/ZoomEye、CVE/NVD/NHKVuln | 情报驱动防御 |
| **学习社区** | OWASP 中国、安全脉搏、FreeBuf、先知社区、各大厂安全技术博客、0x727/0x6270/226/0x00实验室等团队公众号 | 持续学习 |

---

## 结语

**Checklist 不是终点，是起点。**  
它的价值在于：  
1. **降低认知负荷** —— 让非安全专家也能系统性思考安全风险  
2. **固化组织经验** —— 避免同类错误在不同项目、不同时间重复发生  
3. **度量安全投入产出** —— 从「主观感觉安全」转向「可量化、可追溯、可改进」  

建议每个团队 **Fork 本页面**，结合业务特性裁剪成 **《XX 业务线安全评审 Checklist v1.0》**，纳入研发规范库，并建立 **季度迭代 + 事件驱动更新** 机制。安全左移，始于需求，终于文化。

> **获取原始 Checklist 文件**：关注原公众号后台发送「我要checklist」关键字（原文提供方式）  
> **欢迎贡献**：如有补充、纠错、实战案例，请通过 Issue/PR 或内部安全平台反馈，共同完善知识库。

---

## 交叉引用索引

本页面关联的核心知识页（按引用顺序）：

- [[xd-security-logic-vulnerability-notes-day33-36]] — 逻辑漏洞/越权/支付篡改/验证绕过实战案例
- [[xd-security-pentest-basic-stage-notes]] — 渗透测试基础阶段：SQL注入/文件上传/XSS/CSRF/SSRF/RCE 速查
- [[jwt漏洞原理与实战利用]] — JWT 算法混淆、None Algorithm、kid 注入、密钥爆破、垂直越权
- [[openid-connect-acr-amr-2fa-bypass]] — OIDC acr_values 降级绕过 2FA、AMR 标准
- [[php-file-inclusion-vulnerability]] — LFI/RFI/伪协议/目录穿越/文件下载漏洞完整攻防
- [[php-webshell-fundamentals-chopper-analysis]] — PHP 一句话木马、上传绕过、Content-Type 伪造、哥斯拉/蚁剑实战
- [[thinkphp5-deserialization-chain-analysis]] — ThinkPHP 5.0.x 反序列化链、php://filter 绕过、版本影响
- [[java-preparedstatement-sql-injection-defense]] — PreparedStatement 预编译防御原理、ORDER BY 注入实战
- [[fastjson-deserialization-gadgets-shiro-anteros]] — Fastjson 1.2.66 黑名单绕过三条利用链 (Shiro/Anteros/JdbcRowSetImpl)
- [[cve-2023-24055-keepass-plaintext-transmission]] — KeePass 配置文件触发器注入明文凭据外带
- [[lm-ntlm-hash-generation-analysis]] — LM/NTLM Hash 生成算法、C++ 实现、OpenSSL 适配
- [[docker-container-security-fundamentals]] — Namespace/Cgroup/Capability/MAC、K8s 渗透测试全流程
- [[kubernetes-penetration-testing]] — K8s 凭据窃取、kubectl 探索、Master 节点隔离、容器逃逸
- [[c2-redirectors-malleable-c2-profiles]] — C2 重定向器、Malleable C2 Profile、域名前置、CDN 隐匿
- [[oasys-system-code-audit]] — Oasys 代码审计：MyBatis SQLi、Fastjson、文件上传、垂直越权、任意文件读取、存储型 XSS
- [[card-game-platform-penetration-test-case-study]] — 棋牌平台渗透：弱口令+SQL注入+xp_cmdshell 拿 OS Shell 实战

---

*页面版本：v1.0 | 最后更新：2024-01-15 | 维护者：数字知识库策展人*

## 来源

- [226安全团队-201805-202103_21](../sources/226安全团队-201805-202103_21.md)
