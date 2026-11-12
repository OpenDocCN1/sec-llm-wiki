# ai-security

6 个页面。本分类标签：`Actuator` `CVE-2020-5410` `DDCTF` `Eureka` `H2 Database` `JNDI Injection` `JNDI-Injection-Exploit` `JWT` `Metasploit` `RCE` `Socks5` `SpEL` `Spring Boot` `Spring Cloud Config` `Whitelabel Error Page` `XStream` `frp` `任意文件读取` `信息泄露` `内网渗透` `内网穿透` `双重编码` `垂直越权` `密钥爆破` `漏洞利用` `漏洞复现` `目录穿越` `端口转发` `算法混淆` `表达式注入` `隧道技术`

- [[frp内网渗透应用]] `frp` `内网穿透` `内网渗透` `Socks5` `Metasploit` `端口转发` `隧道技术` — 详细记录 frp 在内网渗透中的四大典型应用场景：Socks5 隧道搭建、多级隧道串联、代理本地 Metasploit 反弹、以及 RDP 等服务的远程端口转发，附完整配置示例与拓扑说明。
- [[h2-console-jndi注入rce利用]] `H2 Database` `JNDI Injection` `RCE` `Spring Boot` `漏洞复现` `JNDI-Injection-Exploit` — 详细记录 H2 Database 控制台未授权访问配合 JNDI 注入（搭配 JNDI-Injection-Exploit 工具）实现远程代码执行的实战攻击链。
- [[jwt漏洞原理与实战利用]] `JWT` `漏洞利用` `DDCTF` `垂直越权` `算法混淆` `密钥爆破` `信息泄露` — 系统梳理 JWT 结构、常见漏洞（算法混淆、密钥爆破、信息泄露）及利用工具，结合 DDCTF 实战复现垂直越权全过程。
- [[spring-boot-actuator配置不当rce利用]] `Spring Boot` `Actuator` `RCE` `H2 Database` `JNDI Injection` `Spring Cloud Config` `目录穿越` `Eureka` `XStream` `SpEL` `漏洞复现` — 详细记录 Spring Boot 2.x Actuator 暴露 env 与 restart 端点结合 H2 CREATE ALIAS 实现 RCE 的完整利用链；补充 Eureka XStream 反序列化 RCE 利用链、SpEL 表达式注入、完整 Actuator 端点清单及 /env /refresh 交互利用细节、H2 Console JNDI 注入及 Spring Cloud Config 目录穿越利用方式。
- [[spring-boot-spel表达式注入]] `Spring Boot` `SpEL` `表达式注入` `Whitelabel Error Page` `RCE` `漏洞复现` — 记录 Spring Boot Whitelabel Error Page SpEL 表达式注入原理、影响版本、验证步骤与命令执行 Payload 构造方法
- [[spring-cloud-config目录穿越漏洞]] `Spring Cloud Config` `目录穿越` `CVE-2020-5410` `双重编码` `任意文件读取` `漏洞复现` — 详细记录 Spring Cloud Config Server 目录穿越漏洞（CVE-2020-5410 等变种）的两种双重编码绕过 PoC 与任意文件读取利用方式。
