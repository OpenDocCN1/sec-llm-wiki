---
title: USB流量取证与隐写综合实战
description: 基于赣网杯2020题目复现，系统梳理 USB 键盘流量按键码提取与 HID 映射还原明文、PDF 隐写工具 wbStego4open 解密、视频文件分离图片后结合
  Steghide 爆破与 Base85 解码的完整实战链路。
category: uncategorized
tags:
- CTF
- Misc
- USB取证
- 流量分析
- 隐写术
- PDF隐写
- 视频隐写
- Steghide
- wbStego4open
- Base85
- 赣网杯2020
date: '2020-10-01'
updated: '2026-11-12'
---
## 概述

本页面沉淀自 **007攻防实验室** 微信归档文章《赣网杯2020部分题目详解》，聚焦 **MISC 方向** 的三大核心实战场景：
1.  **USB 键盘流量取证**：从 `pcapng` 中提取 `usb.capdata`，基于 HID Usage Table 映射表还原按键明文，获取解密密码。
2.  **PDF 隐写解密**：使用工具 `wbStego4open` 配合上一步获取的密码，从载体 PDF 中提取隐藏 Flag。
3.  **视频文件深度隐写链路**：`MP4` -> `binwalk`/`foremost` 分离 `JPG` -> `Steghide` 爆破密码提取隐藏文本 -> `Base85` 解码获取最终 Flag。

文章同时包含一道 **PHP 伪协议结合反序列化** 的 Web 题目，相关知识点已整理至 [[php伪协议与反序列化利用]]。本页面定位为 **CTF Misc 实战速查手册**，工具链与脚本均可直接复用，配合 [[ctf-misc入门与工具箱]] 中的通用工具表食用效果更佳。

---

## 一、PHP 伪协议与反序列化利用（Web 0x01）

> 此节为原文 0x01 节内容摘要，完整利用链与原理分析见 [[php伪协议与反序列化利用]]。

### 核心考点
- `php://input` / `data://` 伪协议构造任意字符串绕过 `file_get_contents` 校验。
- `php://filter/read=convert.base64-encode/resource=` 读取源码。
- `__toString()` 魔术方法触发反序列化任意文件读取。

### 利用链复现
1.  **绕过 `sz_txt` 校验**  
    利用 `data://text/plain;base64,d2VsY29tZSB0byBqeHN6`（"welcome to jxsz" 的 Base64）或 `php://input` POST 原文。
2.  **读取 `useless.php` 源码**  
    `sz_file=php://filter/read=convert.base64-encode/resource=useless.php` 获取类定义。
3.  **构造反序列化对象**  
    实例化 `Flag` 类，属性 `$file="flag.php"`，序列化后传入 `password` 参数，触发 `__toString()` 读取 Flag。

---

## 二、MISC 基础知识速查（0x02）

原文归纳的 Misc 通用考点与工具链，详细版本见 [[ctf-misc入门与工具箱]]。

| 方向 | 典型考点 | 核心工具 |
| :--- | :--- | :--- |
| **编码转换** | Base64/32/16, 二进制, 摩斯, JSFuck | CyberChef, Python `base64` 模块 |
| **文件隐写** | 图片/音频/视频/PDF/文档隐写 | `binwalk`, `foremost`, `steghide`, `wbStego4open`, `stegsolve`, `exiftool` |
| **文件修复** | 文件头损坏, 结构异常 | `010 Editor`, `WinHex`, `PNGcheck` |
| **流量取证** | USB/HTTP/DNS/SSL 流量分析 | `Wireshark`, `tshark`, `USBPcap` |
| **内存取证** | 进程/网络/注册表/加密密钥提取 | `Volatility`, `Volatility3` |
| **文件识别** | 真实类型判断, 后缀欺骗 | `file` (Linux), `TrID`, `010 Editor` 模板 |

---

## 三、USB 键盘流量取证与按键还原（核心 0x03）

### 流量特征识别
- **文件**：`pig2.pcapng`
- **协议**：USB (URB_INTERRUPT in)
- **关键字段**：`Leftover Capture Data` (`usb.capdata`)
- **键盘数据包特征**：长度 **8 字节**，第 **3 字节** (Offset 2) 为按键码。
- **鼠标数据包特征**：长度 **4 字节**，第 1 字节为按键状态，第 2/3 字节为相对位移。

### 数据提取
使用 `tshark` 批量导出键盘数据域：
```bash
tshark -r pig2.pcapng -T fields -e usb.capdata > usbdata.txt
```
输出示例（每行一包，十六进制字符串）：
```text
000004000000000000000000
00001e000000000000000000
...
```

### HID 键盘映射表 (USB HID Usage Table - Keyboard/Keypad Page)
| Hex | Key | Hex | Key | Hex | Key | Hex | Key |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `0x04` | A | `0x1E` | 1 | `0x2C` | Space | `0x36` | , |
| `0x05` | B | `0x1F` | 2 | `0x2D` | - | `0x37` | . |
| `0x06` | C | `0x20` | 3 | `0x2E` | = | `0x28` | Enter |
| `0x07` | D | `0x21` | 4 | `0x2F` | [ | `0x2A` | Backspace |
| ... | ... | `0x22` | 5 | `0x30` | ] | `0xE0`~`0xE7` | Ctrl/Shift/Alt/GUI (修饰键，在第 1 字节) |
| `0x1D` | Z | `0x27` | 0 | `0x31` | \ | | |

> **注意**：第 1 字节为修饰键位图，第 3 字节为按键码。大写/符号需判断修饰键（Shift `0x02`），脚本中常简化处理或仅提取按键码。

### 还原脚本
```python
# usb_keyboard_extract.py
mappings = {
    0x04: "A", 0x05: "B", 0x06: "C", 0x07: "D", 0x08: "E", 0x09: "F",
    0x0A: "G", 0x0B: "H", 0x0C: "I", 0x0D: "J", 0x0E: "K", 0x0F: "L",
    0x10: "M", 0x11: "N", 0x12: "O", 0x13: "P", 0x14: "Q", 0x15: "R",
    0x16: "S", 0x17: "T", 0x18: "U", 0x19: "V", 0x1A: "W", 0x1B: "X",
    0x1C: "Y", 0x1D: "Z", 0x1E: "1", 0x1F: "2", 0x20: "3", 0x21: "4",
    0x22: "5", 0x23: "6", 0x24: "7", 0x25: "8", 0x26: "9", 0x27: "0",
    0x28: "\n", 0x2A: "[DEL]", 0x2B: "\t", 0x2C: " ", 0x2D: "-", 0x2E: "=",
    0x2F: "[", 0x30: "]", 0x31: "\\", 0x32: "~", 0x33: ";", 0x34: "'",
    0x36: ",", 0x37: "."
}

keys = open('usbdata.txt', 'r')
output = ""
nums = []

for line in keys:
    line = line.strip()
    # 简单过滤：修饰键为0 且 保留字节为0 的标准按下包 (根据实际流量调整过滤逻辑)
    # 原文逻辑检查特定偏移为 '00'，此处简化为取第 3 字节 (索引 4:6)
    if len(line) >= 8:
        key_code = int(line[4:6], 16) # 第3字节
        if key_code != 0:
            nums.append(key_code)

keys.close()

for n in nums:
    if n in mappings:
        output += mappings[n]
    else:
        output += f'[UNK:{hex(n)}]'

print("Output:\n" + output)
```

### 实战结果
运行脚本输出：
```text
DELDELDELDELTHEANSWERISDELDELDELDELDELDEL[DEL]PASSWORD381382770
```
**关键信息**：`PASSWORD381382770` 即为下一阶段 PDF 解密密码。

---

## 四、PDF 隐写解密：wbStego4open 实战（核心 0x03）

### 工具简介
**wbStego4open** 是一款经典的开源隐写工具，支持在 BMP, TXT, HTML, **PDF** 文件中隐藏任意数据，并支持密码保护（加密算法通常为 Blowfish 或类似对称加密）。
- 官网/下载：SourceForge `wbstego4open` 项目页。
- 运行环境：Java (`.jar`) 或 Windows 可执行文件。

### 实战流程
1.  打开 `wbStego4open`，选择 **"Extract"** (解密/提取)。
2.  **Carrier File**：选择 `pig.pdf`。
3.  **Password**：输入上一步获取的 `381382770` (或完整串 `PASSWORD381382770`，视工具提示而定，实战中为纯数字)。
4.  **Output File**：指定输出路径。
5.  点击提取，成功获得 Flag 文件或明文。

### 备选方案
若无图形界面环境，可尝试 `pdf-parser.py` (Didier Stevens) 分析 PDF 结构寻找 `/EmbeddedFiles` 或 `/ObjStm` 对象，但 wbStego4open 采用专有格式封装，直接使用原工具成功率最高。

---

## 五、视频文件深度隐写链路：DestroyJava（核心 0x04）

### 题目文件
- `DestroyJava.mp4` (或类似命名)

### 链路拓扑
```mermaid
graph LR
    A[DestroyJava.mp4] -->|binwalk -e / foremost| B[分离出 flag.jpg]
    B -->|steghide info| C[检测到隐藏数据]
    C -->|Steghide + 字典爆破| D[提取 output.txt]
    D -->|Base85 解码| E[Final Flag]
```

### 步骤详解

#### 步骤 1：文件分离
```bash
# 方式一：binwalk (推荐，自动识别嵌入文件系统/签名)
binwalk -e DestroyJava.mp4
# 输出目录 _DestroyJava.mp4.extracted/ 中包含 flag.jpg

# 方式二：foremost (基于文件头/尾雕刻)
foremost -i DestroyJava.mp4 -o output_foremost
```

#### 步骤 2：Steghide 探测与爆破
```bash
# 探测
steghide info flag.jpg
# 输出提示: "hidden data" / "passphrase required"

# 爆破脚本
# 准备 password.txt 字典 (rockyou.txt 或针对性字典)
python2 steghide_brute.py
```
**爆破脚本 (`steghide_brute.py`)**：
```python
# -*- coding: utf-8 -*-
import subprocess

stegoFile = 'flag.jpg'
extractFile = 'output.txt'
passFile = 'password.txt'  # 字典路径
errors = ['could not extract', 'steghide --help', 'Syntax error']
cmdFormat = 'steghide extract -sf "%s" -xf "%s" -p "%s" -f' # -f 强制覆盖

with open(passFile, 'r') as f:
    for line in f:
        pwd = line.strip()
        if not pwd: continue
        cmd = cmdFormat % (stegoFile, extractFile, pwd)
        # 使用 subprocess 隐藏窗口/捕获输出
        p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        content = p.stdout.read().decode('gbk', errors='ignore') # Windows 下常为 gbk
        p.wait()
        
        failed = False
        for err in errors:
            if err in content:
                failed = True
                break
        if not failed:
            print(f"[SUCCESS] Password: {pwd}")
            print(content)
            break
```

#### 步骤 3：Base85 解码
爆破成功后得到 `output.txt`，内容为 Base85 编码字符串（特征：以 `<~` 开头 `~>` 结尾，或包含 `z` `!` 等特殊字符）。

**解码方式**：
- **CyberChef**：Recipe -> `From Base85` (勾选 `IPv6` / `RFC 1924` 或 `Adobe` / `btoa` 变体，尝试即可)。
- **Python**：
  ```python
  import base64
  with open('output.txt', 'r') as f: data = f.read().strip()
  # 尝试标准 Base85 (RFC 1924)
  try: print(base64.b85decode(data).decode())
  except: pass
  # 尝试 Adobe Base85 (btoa)
  try: print(base64.a85decode(data).decode())
  except: pass
  ```

---

## 六、工具箱总结与参数速查

| 工具 | 核心用途 | 关键参数/命令 |
| :--- | :--- | :--- |
| **tshark** | USB 流量字段提取 | `-r <in.pcap> -T fields -e usb.capdata` |
| **Wireshark** | 流量可视化分析 | 过滤器: `usb.capdata`, `usbhid.data` |
| **wbStego4open** | PDF/BMP/HTML 隐写提取 | GUI 操作: Extract -> Carrier -> Password |
| **binwalk** | 固件/多媒体文件分析/分离 | `-e` (自动提取), `-M` (递归扫描), `--dd='.*'` |
| **foremost** | 文件雕刻恢复 | `-i <in> -o <out_dir> -t jpg,pdf,zip...` |
| **steghide** | JPEG/BMP/WAV/AU 隐写 | `info <file>`, `embed -cf <carrier> -ef <data>`, `extract -sf <file> -xf <out> -p <pwd>` |
| **CyberChef** | 编码/加密/压缩万能转换 | Recipe: `From Base85`, `Magic`, `Gunzip`... |
| **010 Editor** | 二进制模板分析/修复 | 模板库: `ZIP`, `PNG`, `PDF`, `MP4`, `PCAP`... |

---

## 七、关联知识库

- [[007攻防实验室]] —— 文章来源归档库，包含 2020-07 至 2020-10 微信推文合集。
- [[ctf-misc入门与工具箱]] —— Misc 方向通用知识体系、工具安装与速查表，本页面为其实战案例补充。
- [[php伪协议与反序列化利用]] —— 本文 0x01 节 Web 题目完整复现与原理深度解析。

---

## 八、实战避坑指南

1.  **USB 流量过滤**：`usb.capdata` 包含键盘/鼠标/设备握手包。脚本必须按 **数据长度** (键盘 8 字节, 鼠标 4 字节) 和 **端点地址** 过滤，否则会产生大量噪点。
2.  **HID 映射大小写**：映射表默认输出大写字母。若流量包含 Shift 修饰键 (第 1 字节 `0x02`)，需在脚本中实现大小写切换及符号转换（数字行符号 `!@#$%^&*()`）。
3.  **wbStego4open 版本兼容**：旧版本可能不支持新版 PDF 标准（PDF 1.7+），若提取失败，尝试用 `qpdf --decrypt` 解压 PDF 流后再试，或寻找 Java 版 `wbStego4open.jar` 运行。
4.  **Steghide 爆破编码**：`steghide` 密码输入需注意字符集编码。字典文件建议保存为 **UTF-8 无 BOM**，脚本读取时按系统默认编码 (Linux UTF-8, Windows GBK/CP936) 解码传参。
5.  **Base85 变体识别**：
    - **RFC 1924 (IPv6)**：字符集 `0-9A-Za-z!#$%&()*+-;<=>?@^_`{|}~`，无 `z` 短码。
    - **Adobe (btoa/Ascii85)**：字符集 `!` 到 `u`，支持 `z` 表示全零 4 字节，常用于 PDF/PostScript。
    - **ZeroMQ (Z85)**：字符集固定 85 字符，无标点符号重叠。
    *CyberChef 尝试顺序：`From Base85 (IPv6)` -> `From Base85 (Adobe)` -> `From Base85 (Z85)`。*

--- 
*页面维护者：数字知识库策展人 | 最后同步：2025-07-16*

## 来源

- [007攻防实验室-202007-202010_2](../sources/007攻防实验室-202007-202010_2.md)
