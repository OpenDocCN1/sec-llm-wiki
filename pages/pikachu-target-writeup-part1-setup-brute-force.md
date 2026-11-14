---
title: Pikachu靶场环境搭建与暴力破解实战（Part 1）
description: 系统记录 Pikachu PHP 靶场的环境搭建流程（PHP 5.4 + Apache 2.4）、数据库配置、Burp Suite 代理设置，并详细复现基于表单的暴力破解、服务端/客户端验证码绕过、Token
  反爆破绕过四大核心实战场景，构建 Web 认证攻防基础知识体系。
category: program-analysis
tags:
- Pikachu靶场
- 暴力破解
- 验证码绕过
- Token绕过
- Burp Suite
- Web安全
- 渗透测试
- 无名安全团队
date: '2024-01-15'
updated: '2026-11-14'
---
## 概述

本页面基于无名安全团队归档文章，系统整理 **Pikachu PHP 靶场** 的环境搭建与**暴力破解**模块实战全流程。涵盖环境选型、数据库配置、代理工具链部署，以及四类认证安全策略缺失导致的暴力破解利用链：

1. **基础表单暴力破解** — 无任何防护策略
2. **服务端验证码复用绕过** — 验证码未失效、可重放
3. **客户端验证码前端绕过** — 验证逻辑暴露于页面源码
4. **Token 防爆破机制绕过** — 动态 Token 可从前端页面实时获取

页面采用**攻击视角与防御视角对照**结构，交叉引用知识库中相关技术详解页面，形成完整的 Web 认证攻防知识单元。

---

## 环境搭建

### 组件版本选型

| 组件 | 推荐版本 | 说明 |
|------|----------|------|
| Pikachu 靶场 | `php5.4.45` 分支 | GitHub: `zhuifengshaonianhanlu/pikachu` |
| PHP | **5.4.45+** | PHP 5.2 会报 `syntax error, unexpected '['`；需 5.4+ 支持短数组语法 |
| Apache | 2.4.39 | 配合 PHP 模块运行 |
| MySQL | 5.5+ / 5.7 | 默认端口 3306 |

> **关键坑点**：PHP 版本必须 ≥ 5.4，否则靶场入口文件解析失败。

### 部署步骤

1. **获取源码**  
   ```bash
   git clone https://github.com/zhuifengshaonianhanlu/pikachu.git
   # 切换到 php5.4.45 分支/标签
   ```

2. **放置网站目录**  
   将源码放入 Apache `DocumentRoot` 指定目录（如 `/var/www/html/pikachu` 或小皮面板对应站点目录）。

3. **修改数据库配置**  
   编辑 `inc/config.inc.php`（或同级配置文件），核心常量如下：

   ```php
   <?php
   session_start();
   date_default_timezone_set('Asia/Shanghai');
   header('Content-type:text/html;charset=utf-8');

   define('DBHOST', '127.0.0.1');
   define('DBUSER', 'root');
   define('DBPW',   'root');      // 按实际环境修改
   define('DBNAME', 'pikachu');
   define('DBPORT', '3306');
   ?>
   ```

4. **初始化数据库**  
   访问靶场首页，按提示点击「设置」/「初始化」按钮，自动建表并写入测试数据。完成后首页红色提示消失。

---

## 代理与抓包环境

### Firefox + Burp Suite 联动

| 设置项 | 配置值 |
|--------|--------|
| 代理 IP | `127.0.0.1` |
| 代理端口 | `8080`（Burp 默认） |
| Firefox 网络设置 | 手动配置代理 → HTTP/HTTPS 均指向上述 IP:Port |

### 导入 Burp CA 证书（解决 HTTPS 抓包报错）

1. Firefox 访问 `http://burp` → 下载 `cacert.der`（或 `.pem`）。
2. Firefox 设置 → 隐私与安全 → 证书 → 查看证书 → 证书机构 → 导入 → 勾选「信任此证书标识网站」。
3. 重启 Firefox，HTTPS 站点抓包无报错。

> 交叉引用：[[ctfshow-web-info-gathering-brute-force]] 中亦采用同款代理链路进行 Web 入门关卡复现。

---

## 暴力破解核心原理

> **定义**：暴力破解是针对认证接口，利用字典/枚举自动化尝试凭证，直至命中有效账号密码的攻击手段。

### 判定「存在暴力破解漏洞」的认证安全策略清单

| 策略维度 | 缺失表现 | 风险等级 |
|----------|----------|----------|
| 密码复杂度策略 | 允许弱口令、无长度/字符类型要求 | 高 |
| 验证码/OTP | 无验证码、验证码可复用、前端校验、生成算法可预测 | 高 |
| 登录失败限流/账号锁定 | 无限制尝试次数、无 IP 封禁、无设备指纹识别 | 高 |
| 双因素认证 (2FA) | 仅单因素（密码）认证 | 中 |
| Token/CSRF Token 防重放 | 无 Token、Token 静态、Token 可从前端实时获取 | 高 |

> **理论依据**：只要计算资源与时间充足，绝大多数认证系统均可被暴力破解；防御核心在于**提升攻击成本**与**缩小成功概率**。

---

## 实战场景复现

> 所有场景均在 Pikachu 靶场「暴力破解」模块下完成，配合 **Burp Suite Intruder** 模块自动化爆破。

### 场景一：基础表单暴力破解（无任何防护）

**特征**：纯用户名/密码表单，无验证码、无 Token、无限流。

**攻击流程**：

1. 正常登录一次，抓包得到请求：
   ```http
   POST /pikachu/vul/bruteforce/bruteforce.php HTTP/1.1
   Content-Type: application/x-www-form-urlencoded

   username=admin&password=123456&submit=登录
   ```
2. 发送到 **Intruder** → **Positions** 标签 → 清除默认标记 → 选中 `password` 值 → `Add §` 标记为载荷位置。
3. **Payloads** 标签 → Payload set 1 → Runtime file → 加载弱口令字典（如 `top1000.txt`、`rockyou.txt` 截取）。
4. 点击 **Start attack** → 观察响应长度/状态码/关键字（如「登录成功」「欢迎」「flag」）差异，筛选命中结果。

**结果示例**：
| Payload | Status | Length | 备注 |
|---------|--------|--------|------|
| admin   | 200    | 5321   | 登录成功，返回欢迎页 |
| 123456  | 200    | 2145   | 登录失败，含「密码错误」 |

**防御对策**：
- 强制密码复杂度 + 登录失败计数锁定（账号/IP 维度）
- 引入验证码或 2FA
- 响应包统一长度/通用报错文案，避免侧信道泄露

---

### 场景二：服务端验证码复用绕过

**特征**：登录表单含 `vcode` 验证码字段，验证码由服务端生成并存入 Session，**但验证码未在验证后立即销毁、存在有效期窗口**。

**漏洞成因**：
- 验证码生成接口 `/vul/bruteforce/vcode.php` 返回图片，同时 `$_SESSION['vcode'] = $code;`
- 登录校验逻辑仅比对 `$_POST['vcode'] === $_SESSION['vcode']`，**校验通过后未 `unset($_SESSION['vcode'])`**。
- 导致同一验证码在有效期内可**无限次重放**。

**攻击流程**：

1. 正常访问登录页 → 右键验证码图片「查看图片」→ 地址栏得到验证码图片 URL。
2. 手动识别验证码（或调用 OCR API）得到明文，如 `a8f3`。
3. 抓包登录请求，固定 `vcode=a8f3`，仅对 `password` 位置加载字典爆破。
4. Intruder 启动，因验证码固定有效，所有尝试均通过验证码校验，直达密码比对逻辑。

**关键抓包对比**：

| 步骤 | 请求参数 | 说明 |
|------|----------|------|
| 1. 获取验证码 | `GET /vcode.php` | 返回图片，Session 写入 `vcode` |
| 2. 手动识别 | — | 人工/OCR 得到 `a8f3` |
| 3. 爆破登录 | `POST ... vcode=a8f3&password=§dict§` | 复用同一验证码遍历密码字典 |

**防御对策**：
- **验证码一次性**：校验通过/失败后立即 `unset($_SESSION['vcode'])`，强制每次尝试重新获取。
- 缩短验证码有效期（如 60 秒），并限制单 Session 获取次数。
- 引入**行为分析**：同一 IP/设备短时间大量请求验证码接口 → 触发风控。

> 交叉引用：[[ctfshow-web-info-gathering-brute-force]] 中「验证码绕过」板块亦覆盖服务端验证码复用、前端校验、验证码识别自动化等技巧。

---

### 场景三：客户端验证码前端绕过

**特征**：验证码校验逻辑**完全在前端 JavaScript 实现**，服务端不校验或仅作形式校验。

**漏洞成因**：
- 页面源码中直接可见：
  ```html
  <script>
  function check_vcode() {
      var vcode = document.getElementById('vcode').value;
      if (vcode != '1234') { alert('验证码错误'); return false; }
      return true;
  }
  </script>
  ```
- 验证码固定为常量 `1234`，或通过简单算法生成（如 `Math.random()` 种子可控）。

**攻击流程**：

1. 右键页面 →「查看页面源代码」→ 搜索 `vcode`/`check` 定位校验函数。
2. 直接读取/推导验证码值（如固定 `1234`）。
3. 抓包登录请求，**直接删除 `vcode` 参数或填入已知值**，Intruder 仅爆破 `password`。
4. 服务端因无校验逻辑或校验通过，直接进入密码比对。

**防御对策**：
- **验证码校验必须在服务端**，前端仅作用户体验提示。
- 使用成熟验证码库（如 Google reCAPTCHA、hCaptcha、Geetest），避免自研弱算法。
- 前端代码混淆/压缩仅能提高逆向成本，**不能替代服务端校验**。

---

### 场景四：Token 防爆破机制绕过

**特征**：登录表单隐藏字段 `token`，每次页面加载生成新值，服务端校验 Token 有效性且**一次性失效**；但 Token **直接暴露于页面 HTML 源码**中。

**漏洞成因**：
- 登录页渲染时：`<input type="hidden" name="token" value="a1b2c3d4e5">`
- 服务端校验：`$_POST['token'] === $_SESSION['token']` → 校验通过后 `unset($_SESSION['token'])`。
- **攻击者可在每次爆破尝试前，先请求登录页解析最新 Token，再携带该 Token 提交登录请求**，实现「动态 Token 实时获取 + 密码字典遍历」组合攻击。

**攻击流程（Burp Suite Intruder 双载荷联动）**：

1. **Positions 标签** → 标记两个载荷位置：
   - `password` → `§password§`
   - `token` → `§token§`
2. **Payloads** 标签 → **Payload set 1 (password)** → Runtime file → 加载密码字典。
3. **Payload set 2 (token)** → Payload type 选择 **Recursive grep**（递归提取）：
   - 请求模板：先 GET 登录页 `/bruteforce/token.php` → 响应中提取 `<input name="token" value="([^"]+)">` 正则捕获组。
   - Intruder 会在每次迭代前自动发起 GET 请求，提取最新 Token 填入当前 POST 请求。
4. 启动攻击 → 观察响应差异定位正确密码。

**关键配置截图逻辑**：

| 设置项 | 值/说明 |
|--------|---------|
| Payload set 1 | Simple list / Runtime file → 密码字典 |
| Payload set 2 | Recursive grep → Request Engine: GET `/token.php` → Extract regex: `name="token" value="([^"]+)"` |
| Attack type | Pitchfork（并行组合）或 Cluster bomb（笛卡尔积，视 Token 复用策略） |

**防御对策**：
- **Token 绑定会话而非页面**：登录流程开始时颁发 Token 存入 Session，登录结束前**不刷新 Token**，仅在登录成功/失败、Session 过期时更新。
- 引入 **CAPTCHA + Token 双重校验**，或 **设备指纹/行为分析** 识别自动化脚本。
- 限制单 IP/账号单位时间登录尝试次数（如 5 次/分钟），触发锁定/图形验证码升级。

> 交叉引用：[[jwt漏洞原理与实战利用]] 中「Token 爆破与算法混淆」板块对 Token 安全性有更深度剖析；[[ssrf-ctf-exploitation-guide]] 亦涉及动态参数获取与自动化攻击链构造。

---

## 知识点交叉引用导航

| 相关主题 | 页面链接 | 关联点 |
|----------|----------|--------|
| Pikachu 靶场 XSS 实战 | [[pikachu-target-writeup-part2-xss]] | 同靶场不同漏洞模块，统一环境复用 |
| Pikachu CSRF / SQLi 实战 | [[pikachu-target-writeup-part3]] | 认证绕过后常衔接的越权/注入利用 |
| Pikachu RCE / 文件上传 / 越权 | [[pikachu-target-writeup-part4]] | 登录后攻击面拓展 |
| Pikachu 目录遍历 / XXE / SSRF | [[pikachu-target-writeup-part5]] | 信息泄露与服务端请求伪造 |
| CTF-show Web 爆破与信息收集 | [[ctfshow-web-info-gathering-brute-force]] | 同类暴力破解技巧系统化对比 |
| PHP 伪协议与反序列化（含 Pikachu 案例） | [[php伪协议与反序列化利用]] | 登录后可能触发的反序列化利用链 |
| SSRF 协议差异与绕过（Pikachu 实战） | [[ssrf-ctf-exploitation-guide]] | `file_get_contents` vs `curl` 协议支持对比 |
| PHP Webshell 基础与蚁剑连接 | [[php-webshell-fundamentals-chopper-analysis]] | Getshell 后持久化控制 |

---

## 小结与防御检查清单

| 检查项 | 加固建议 | 优先级 |
|--------|----------|--------|
| 密码策略 | 最小长度 12、强制大小写数字特殊字符、禁用常见弱口令表 | P0 |
| 验证码 | 服务端生成+校验、一次性销毁、有效期≤60s、限制获取频率 | P0 |
| 登录限流 | 账号/IP/设备三维度计数、阈值触发锁定/验证码升级/告警 | P0 |
| Token 设计 | 绑定会话生命周期、单次有效、不可从前端静态获取、配合 SameSite Cookie | P1 |
| 双因素认证 | TOTP / 短信 / 邮件 / 硬件密钥，敏感操作强制 2FA | P1 |
| 日志审计 | 记录登录成功/失败、IP、UA、设备指纹，接入 SIEM 告警 | P1 |
| 前端代码 | 混淆压缩仅作辅助，**核心校验下沉服务端** | P2 |

> **核心原则**：**认证安全策略的深度防御** —— 单一防线必然被绕过，需在「凭证强度 → 验证码/Token → 行为限流 → 双因素 → 审计溯源」多层叠加，将攻击成本推高至不可接受区间。

---

## 后续学习路径建议

1. **横向拓展**：完成 Pikachu 靶场 Part 2–5 全模块复现，构建完整 Web 漏洞利用链条。
2. **纵向深化**：
   - 验证码识别自动化：`pytesseract`、`ddddocr`、云打码 API 集成 → 实战脚本化。
   - Token 复杂场景：JWT 算法混淆、密钥爆破、None Algorithm、KID 注入 → 参考 [[jwt漏洞原理与实战利用]]。
   - 分布式爆破框架：`hydra`、`medusa`、`burp-turbo-intruder`、自研分布式任务调度。
3. **实战靶场**：攻防世界、CTF-show、BUUCTF Web 专题、VulnHub 实战靶机（如 [[vulnhub-admx-new-writeup]]、[[vulnhub-pwned-writeup]]）。
4. **蓝队视角**：部署 WAF 规则（ModSecurity CRS）、蜜罐账号、登录异常行为分析模型、态势感知联动封禁。

---

*页面维护者：数字知识库策展人*  
*最后更新：2024-01-15*  
*数据来源：无名安全团队微信公众号归档文章《pikachu靶场&环境搭建&暴力破解(一)》*

## 来源

- [0x00实验室-202108-202304_079](../sources/0x00实验室-202108-202304_079.md)
