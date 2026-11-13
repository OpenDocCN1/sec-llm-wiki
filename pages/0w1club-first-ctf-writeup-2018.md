---
title: 0w1Club 首届 CTF 校内赛完整题解 (2018)
description: 西安交通大学 0w1 网络安全俱乐部首届 CTF 校内赛 13 道题完整 Writeup，涵盖 Web、Reverse、Misc 三大类。记录
  JS 混淆还原、ThinkPHP 0day RCE、IDA/OllyDbg 静态动态分析、XOR/算法逆向、Base64+栅栏密码、AES 字典爆破、凯撒密码、MP3
  隐写+LSB 提取等经典入门技术点。
category: ai-security
tags:
- 0W1Club
- CTF
- Writeup
- Web安全
- 逆向工程
- 隐写术
- 密码学
- 西安交通大学
- 网络安全社团
- 微信归档
date: 2018-05-15
updated: '2026-11-14'
---

# 0w1Club 首届 CTF 校内赛完整题解 (2018)

> 来源：0w1 网络安全俱乐部微信公众号文章《CTF题解及获奖名单》
> 
> 作者：windwing (Web)、#Gxian (Reverse)、ya0guang & #Gxian (Misc)
> 
> 比赛时间：2018 年春季学期

---

## 概览

西安交通大学 0w1 网络安全俱乐部首届 CTF 校内赛共设 **13 道题目**，分为 **Web (4道)**、**Reverse (5道)**、**Misc (4道)** 三大类。本页面系统整理官方题解，提炼核心知识点与工具链，便于萌新入门复现与技术沉淀。

| 类别 | 数量 | 核心技术点 |
|------|------|------------|
| **Web** | 4 | 源码泄露、JS 混淆/ASCII 编码、目录扫描、ThinkPHP 0day RCE |
| **Reverse** | 5 | ELF 静态分析、IDA F5 反编译、XOR 逆向、算法逆向+爆破、OllyDbg 动态调试、自修改代码 |
| **Misc** | 4 | 图片隐写、Base64+栅栏密码、AES 字典攻击、凯撒密码、MP3 隐写+LSB 提取 |

---

## Web 方向 (作者：windwing)

### 0x01 Curse of Dragon —— 龙语隐写与源码审计

**考点**：HTML 注释/隐藏元素、龙语对照表、旗标提交格式

**解题流程**：

1. **F12 查看网页源代码**，发现隐藏图片标签：
   ```html
   <img src="dragon.png" style="display:none" />
   ```
2. 下载图片，识别为《上古卷轴》龙语字符
3. 使用龙语对照表逐字符翻译 → 明文：`shittyworld`
4. 提交 Flag：`shittyworld`

> 💡 **技巧**：CTF 图片类题目首选「右键另存为」→ `binwalk`/`strings`/`exiftool` 三连击；遇到虚构语言优先搜索对照表。

---

### 0x02 WTF —— JS 混淆还原与语法糖识别

**考点**：JS 混淆、ASCII 十六进制编码、括号语法糖 `obj['prop'] === obj.prop`、`String.fromCharCode` 解码

**混淆代码片段**：
```javascript
var _0x4e9d = ["\x66\x72\x6F\x6D\x43\x68\x61\x72\x43\x6F\x64\x65", "\x77\x72\x69\x74\x65"];
document[_0x4e9d[0x1]](String[_0x4e9d[0x0]](0x3c, 0x62, 0x75, ...));
```

**还原步骤**：

1. 识别数组 `_0x4e9d` 存放方法名：`["fromCharCode", "write"]`
2. 识别语法糖：`document['write']` ≡ `document.write`，`String['fromCharCode']` ≡ `String.fromCharCode`
3. 将十六进制参数批量转字符（可用浏览器 Console 直接执行 `String.fromCharCode(...)`）
4. 还原出完整 HTML：
   ```html
   <button onclick='javascript:
     if(document.getElementById("pass").value=="j00w1n"){
       alert("You WIN!");
       window.location += "?lvl_password=" + document.getElementById("pass").value
     } else { alert("WRONG! Try again!"); }
   '>Check Password</button>
   ```
5. 读取硬编码密码：`j00w1n`

> 🔗 相关技术：[[0w1club-ctf-web-writeup-jwt-sqli-brute#jwt-md5-盐值爆破]] 中亦涉及 JS 逆向与弱类型比较绕过。

---

### 0x03 Real Task 1 —— 目录扫描与越权访问

**考点**：`dirsearch` 目录爆破、框架默认后台路径、缺失鉴权逻辑

**解题流程**：

1. `dirsearch -u http://target/` 扫描发现 `/admin` 目录
2. 访问 `/admin` 直接进入后台，**无任何权限校验**
3. 任意账号登录即可获取后台权限 → Flag

> 💡 实战中常见框架默认后台：`/admin`、`/manager`、`/backend`、`/wp-admin`、`/phpmyadmin` 等。

---

### 0x04 Real Task 2 —— ThinkPHP 0day RCE 实战

**考点**：ThinkPHP 框架 0day 远程代码执行、结合 Apache 配置 Getshell

**官方题解引用**：[FreeBuf 文章《ThinkPHP 5.0.x 远程代码执行漏洞分析》](http://www.freebuf.com/articles/web/153286.html)

**核心利用链**：

1. 利用 ThinkPHP 5.0.x `Request` 类 `method` 过滤不当触发 RCE
2. 结合 `application` 目录下具体业务代码构造 Payload
3. 利用 Apache 解析漏洞/配置不当写入 Webshell
4. 蚁剑/冰蝎连接 Getshell → 读取 Flag

> ⚠️ **历史背景**：该漏洞为 2018 年末震惊全网的 ThinkPHP 5.0.x RCE (CVE-2018-20062 等变种)，属于当时最火的「0day 实战」题目。
> 
> 🔗 同类框架漏洞复现：[[spring-boot-actuator配置不当rce利用]]、[[spring-boot-devtools-deserialization-rce]]、[[zzzphp-cve-2021-32605-rce]]

---

## Reverse 方向 (作者：#Gxian)

### 0x01 RE1 —— 32-bit ELF 静态分析入门

**工具**：`binwalk`、`IDA Pro 32-bit`、F5 反编译

**解题流程**：

1. `binwalk re1` 确认：32 位 ELF 可执行文件
2. IDA32 打开，`F5` 反编译 `main` 函数
3. 观察到仅调用两次 `puts` 输出字符串，且向内存写入数据
4. 右键数据区 → `R` 转字符数组 → 得到逆序字符串
5. 逆序还原 Flag：`FLAG-4092849uio2jfklsj4kl`

> 💡 **核心技巧**：IDA 中 `Shift+F12` 查字符串、`F5` 看伪代码、`R` 转字符串、`/` 搜十六进制是逆向「四大金刚」。

---

### 0x02 RE2 —— 多层编码嵌套 + Python 逻辑逆向

**工具**：在线 URL Decode、Base64 解码、Python 执行

**解题流程**：

1. 文件打开为 URL 编码文本 → 在线解码得 PHP 代码
2. PHP 代码关键逻辑：
   ```php
   $p = base64_decode($p);
   $p = str_replace('pb24', $password, $p);
   ```
3. 对 `$p` 再次 Base64 解码 → 得到 Python 代码片段
4. Python 核心判断：
   ```python
   if p == 'ASSHAIR':
       print('YES, the flag is', md5(password))
   ```
5. 逆向推导：`password` 需满足替换后 `p == 'ASSHAIR'`
6. 直接对候选 `password` 计算 MD5 → Flag

> 🔗 编码嵌套套路常见于 [[0w1club-ctf-misc-writeup-steganography-traffic-analysis#base64-解码结合-telegram-社工获取-flag]]、[[0w1club-ctf-crypto-writeup-easyrsa-t9#easyrsa-利用大数分解数据库分解模数-n-获取-pq]]。

---

### 0x03 RE3 —— 64-bit ELF XOR 算法逆向

**工具**：`binwalk`、`IDA Pro 64-bit`、Shift+F12 字符串搜索

**解题流程**：

1. `binwalk` 确认 64 位 ELF
2. IDA64 打开，`Shift+F12` 搜字符串定位关键函数 `sub_4007BD`
3. 分析伪代码逻辑：
   - 检查输入前 5 字符 == `flag{`
   - 第 5~7 位与 `7` 异或
   - 第 8~15 位与 `8` 异或
   - 结果需等于 `flag{PbkD7j4 X|8Wz;~; z_O1}`
4. 利用 XOR 可逆性：`plaintext = ciphertext ^ key`
5. 编写脚本逐字节异或还原 → Flag：`flag{WelC0m3_t0_r3v3r_O1}`

> 💡 **XOR 逆向模板**：
> ```python
> cipher = b'PbkD7j4 X|8Wz;~; z_O1'
> key1, key2 = 7, 8
> flag = 'flag{'
> for i, c in enumerate(cipher):
>     k = key1 if i < 3 else key2
>     flag += chr(c ^ k)
> print(flag)
> ```

---

### 0x04 RE4 —— 注册算法逆向 + Python 爆破

**工具**：`IDA Pro 32-bit`、Alt+T 字符串搜索、交叉引用 `X`、F5 伪代码分析

**解题流程**：

1. 运行程序提示 `Wrong`，IDA 搜 `Wrong` 旁意外发现 `Correct` 字符串
2. `X` 交叉引用定位关键验证函数
3. F5 伪代码分析算法逻辑（伪代码见原文图片）：
   - 循环处理输入字符
   - 累加/异或/移位等不可逆运算
   - 最终比较计算值与硬编码常量
4. 算法不可逆 → 编写 Python 爆破脚本遍历字符空间
5. 筛选符合题目要求「末位为 p」的解 → Flag

> 🔗 算法逆向爆破思路参考：[[0w1club-ctf-web-writeup-hash-extension-rsa#哈希长度扩展攻击利用-hashpump]] 中的 `hashpump` 自动化工具用法。

---

### 0x05 RE5 —— OllyDbg 动态调试 + 自修改代码分析

**工具**：`OllyDbg (OD)`、API 断点、单步跟踪、内存修改

**解题流程**：

1. OD 加载程序，`Ctrl+N` 查名字表 → 定位 `GetDlgItemInt` API
2. 右键「在每个参考点上设置断点」→ 运行程序中断于读取输入处
3. 向下分析发现两个条件跳转阻挡 `Correct` 代码路径
4. **关键发现**：`0040106C` 处调用一个「捣乱函数」，将 `0x90` (NOP) 写入 `DS:[EAX]`，导致程序崩溃
5. 动态分析得 `EAX = 0x601605CB + input_value`
6. 目标：让该函数 NOP 掉 `00401071` 处的跳转指令
   - 目标地址 `0x00401071` (考虑 32 位溢出实为 `0x100401071`)
   - 方程：`0x601605CB + input = 0x100401071`
   - 解得 `input = 2687109798`
7. 输入该数字 → 程序输出 `Correct` → Flag

> 💡 **精华技巧**：
> - OD 中 `F7` 单步进、`F8` 单步过
> - 自修改代码 (SMC) 常用 `0x90` NOP 破坏控制流
> - 溢出地址计算需考虑架构位宽 (32 位 `0xFFFFFFFF` 回绕)

> 🔗 动态调试进阶：[[0w1club-week7-stack-overflow-rop-training#栈溢出原理与-rop-链构造]]、[[tctf-2021-1linephp-zip-include#利用链复现]]。

---

## Misc 方向 (作者：ya0guang & #Gxian)

### 0x01 如来神掌 —— 图片隐写 + Base64 + 栅栏密码

**工具**：`binwalk`、`WinHex`/`010Editor`、在线 Base64/栅栏解码

**解题流程**：

1. `binwalk buddha.png` 发现文件尾部追加数据
2. `WinHex` 打开提取尾部字符串：
   ```
   VF95c0s5XzVyaGtfX3VGTXR9M0Vse251QEUg
   ```
3. 识别 Base64 特征 (字符集 A-Za-z0-9+/、末尾 `=`) → 解码得：
   ```
   T_ysK9_5rhk__uFMt}3El{nu@E
   ```
4. 观察到 `}{` 乱序特征 → 猜测栅栏密码 (栅栏密码/栅栏置换)
5. 在线栅栏解密 (每组 3 字符) → Flag：`Th3_kEy_ls_{Kun9Fu_M@5tEr}`

> 🔗 同类隐写组合拳：[[0w1club-ctf-misc-writeup-steganography-traffic-analysis#音频频谱隐写]]、[[0w1club-ctf-misc-writeup-steganography-traffic-analysis#零宽字符隐写统计]]。

---

### 0x02 AES —— 字典爆破 AES 密钥

**工具**：`openssl`、Python `pycryptodome`、字典文件

**题目给出**：密文文件、加密算法 AES-CBC、已知明文、IV、Salt

**解题思路**：

1. 观察密文文件头含 `Salted__` 标识 → OpenSSL 格式、含 Salt
2. 爆破脚本逻辑：
   ```python
   from Crypto.Cipher import AES
   import hashlib
   
   def derive_key_iv(password, salt):
       # OpenSSL EVP_BytesToKey 默认 MD5
       d = b''
       while len(d) < 48:  # 32 bytes key + 16 bytes IV
           d += hashlib.md5(d + password + salt).digest()
       return d[:32], d[32:48]
   
   for pwd in open('dict.txt'):
       pwd = pwd.strip().encode()
       key, iv = derive_key_iv(pwd, salt)
       cipher = AES.new(key, AES.MODE_CBC, iv)
       dec = cipher.decrypt(ciphertext)
       if known_plaintext in dec:
           print('Found:', pwd)
           break
   ```
3. 验证密钥 `31a20926` 解密成功 → Flag

> ⚠️ **坑点**：OpenSSL `Salted__` 格式前 16 字节固定：`Salted__` + 8 字节 Salt
> 
> 🔗 密码学爆破延伸：[[0w1club-ctf-crypto-writeup-easyrsa-t9#easyrsa-利用大数分解数据库分解模数-n-获取-pq]]、[[mtctf-2021-crypto-writeup#rsa-填充-oracle-攻击解密-zip-密码]]。

---

### 0x03 最简单的替换密码 —— 凯撒密码 (ROT6/ROT17)

**线索**：题目提示 `Rome` → 罗马 → 凯撒大帝 → 凯撒密码

**解题流程**：

1. 密文为纯字母文本，疑似移位加密
2. 使用在线工具 [planetcalc.com/1434](http://planetcalc.com/1434/) 一键列举 26 种移位
3. 识别出 `Rot6` (或 `Rot17`) 还原为可读英文
4. 明文提示：*The flag is the combination of the first character of each line in plain text.*
5. 按**真实换行符** (非编辑器自动换行) 提取每行首字母拼接 → Flag

> 💡 **凯撒密码识别特征**：字母频率分布平移、仅含字母、单词长度不变。

---

### 0x04 stegano —— MP3 隐写 + 图片提取 + LSB 隐写

**工具**：`binwalk`、`dd`、`LSB-Steganography` (GitHub: RobinDavid/LSB-Steganography)

**解题流程**：

1. `binwalk dream.mp3` 发现 MP3 内嵌两张图片 (JPEG 文件头 `FF D8 FF`)
2. `dd if=dream.mp3 of=img1.jpg bs=1 skip=<offset1> count=<size1>` 提取图片
3. 两张图片均尝试，第二张为「灵梦」角色图
4. 怀疑 LSB 隐写 → 使用 `LSB-Steganography` 工具：
   ```bash
   git clone https://github.com/RobinDavid/LSB-Steganography.git
   python lsb_reveal.py -i img2.jpg
   ```
5. 成功提取 Flag

> 🔗 音频/图片隐写综合案例：[[0w1club-ctf-misc-writeup-steganography-traffic-analysis#音频频谱隐写]]、[[ar-drone-2.0-penetration-testing#视频流-arp-欺骗中间人攻击]] (视频流分析)。

---

## 知识点总结表

| 技术点 | 涉及题目 | 核心工具/命令 | 进阶延伸 |
|--------|----------|---------------|----------|
| **JS 混淆还原** | WTF | 浏览器 Console、AST 还原 (babel) | [[0w1club-ctf-web-writeup-jwt-sqli-brute]] |
| **目录扫描** | Real Task 1 | `dirsearch`、`ffuf`、`gobuster` | [[burpsuite-basics-tutorial#intruder-密码爆破]] |
| **ThinkPHP RCE** | Real Task 2 | PoC 构造、蚁剑/冰蝎 | [[spring-boot-actuator配置不当rce利用]] |
| **IDA 静态分析** | RE1, RE2, RE3, RE4 | F5、Shift+F12、交叉引用 X | [[0w1club-week7-stack-overflow-rop-training]] |
| **XOR 逆向** | RE3 | Python 异或脚本、线性代数思维 | [[mtctf-2021-crypto-writeup]] |
| **算法逆向爆破** | RE4 | Python `itertools`、约束剪枝 | [[0w1club-ctf-web-writeup-hash-extension-rsa]] |
| **OD 动态调试** | RE5 | API 断点、单步、内存布局分析 | [[0w1club-training-shellshock-cgi-exploitation]] |
| **多层编码解码** | 如来神掌 | `base64 -d`、在线栅栏、CyberChef | [[0w1club-ctf-misc-writeup-steganography-traffic-analysis]] |
| **AES 字典攻击** | AES | OpenSSL EVP_BytesToKey、已知明文攻击 | [[h2-console-jndi注入rce利用]] (链式利用思维) |
| **凯撒密码** | 最简单的替换密码 | ROT13/ROTn、频率分析 | [[0w1club-ctf-crypto-writeup-easyrsa-t9]] |
| **MP3 隐写提取** | stegano | `binwalk -e`、`dd`、LSB 工具链 | [[0w1club-ctf-misc-writeup-steganography-traffic-analysis#音频频谱隐写]] |

---

## 复现环境建议

| 环境 | 推荐版本 | 用途 |
|------|----------|------|
| **Linux** | Kali 2023+ / Ubuntu 22.04 | 主攻击机、工具链完备 |
| **Windows** | Win10/11 + WSL2 | OD、IDA Pro (Windows 版更稳) |
| **IDA Pro** | 7.6+ (含 Hex-Rays Decompiler) | 核心静态分析 |
| **OllyDbg** | 2.01 + 插件 (StrongOD、PhantOm) | 32 位动态调试 |
| **Python** | 3.10+ + `pycryptodome` `pwntools` `requests` | 爆破/解密/交互脚本 |
| **在线工具** | CyberChef、Base64.guru、Quipqiup、Factordb | 快速验证编码/密码 |

---

## 相关页面交叉引用

- 0w1Club 微信归档索引：[[0w1club-wechat-archive-201707-201903]]、[[0w1club-wechat-archive-201908-202207]]
- Web 方向专题：[[0w1club-ctf-web-writeup-hash-extension-rsa]]、[[0w1club-ctf-web-writeup-jwt-sqli-brute]]、[[0w1club-week10-web-injection-training]]
- Reverse 方向专题：[[0w1club-week7-stack-overflow-rop-training]]、[[tctf-2021-1linephp-zip-include]]
- Misc/Crypto 方向专题：[[0w1club-ctf-misc-writeup-steganography-traffic-analysis]]、[[0w1club-ctf-crypto-writeup-easyrsa-t9]]、[[mtctf-2021-crypto-writeup]]
- 社团运营与培训体系：[[0w1club-tiesan-training-camp]]、[[0w1club-training-shellshock-cgi-exploitation]]

---

## 结语

本届校内赛题目难度循序渐进，**Web 侧重框架漏洞与前端逆向**、**Reverse 覆盖静态/动态分析全链路**、**Misc 融合隐写与古典密码**，极适合 CTF 入门者构建完整知识树。建议读者：

1. **搭建环境逐题复现**，体会「从断点到 Flag」的完整闭环
2. **总结通用脚本模板** (XOR 解码、AES 爆破、LSB 提取)，沉淀个人工具箱
3. **关联阅读上文交叉引用页面**，将零散 Writeup 编织成结构化知识图谱

> 「安全之路，始于复现，终于创新。」—— 0w1 Club

--- 

*页面维护：数字知识库策展人 | 最后更新：2025-01-15*

## 来源

- [0w1网络安全俱乐部-201707-201903_40](../sources/0w1网络安全俱乐部-201707-201903_40.md)
