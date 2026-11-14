---
title: SQLMap API 服务端/客户端模式与 Python 自动化批量扫描实战
description: 系统梳理 SQLMap REST-JSON API 的服务端/客户端两种运行模式、核心 HTTP 接口调用流程，并提供基于 Python
  的自动化批量扫描脚本实现，实现从单点手工测试向批量化、可编程化的 SQL 注入检测转型。
category: program-analysis
tags:
- SQLMap
- SQL Injection
- REST API
- Python Automation
- Penetration Testing
- Batch Scanning
- Security Tools
date: 2022-05-24
updated: '2026-11-14'
---
## 概述

SQLMap 是广泛使用的自动化 SQL 注入检测与利用工具。其内置的 `sqlmapapi.py` 提供 **REST-JSON API** 接口，支持 **服务端/客户端** 两种运行模式，并提供两种交互方式：

- **HTTP 接口模式**：通过标准 HTTP 请求调用 API，适合编写自动化脚本、集成到扫描平台
- **命令行接口模式**：`sqlmapapi.py -c` 启动交互式客户端，适合手工调试、单点测试

本页详细记录服务端部署、客户端连接、核心 API 端点调用流程，以及基于 Python `requests` 库的批量扫描自动化脚本编写实战。

## 环境准备与基础用法

### 文件位置与帮助信息

`sqlmapapi.py` 位于 SQLMap 根目录下。执行 `python sqlmapapi.py -h` 查看帮助：

| 参数 | 说明 |
|------|------|
| `-s, --server` | 以 REST-JSON API 服务端模式运行 |
| `-c, --client` | 以 REST-JSON API 客户端模式运行 |
| `-H, --host` | 服务端监听地址（默认 `127.0.0.1`） |
| `-p, --port` | 服务端监听端口（默认 `8775`） |
| `--adapter` | Bottle 服务器适配器（默认 `wsgiref`） |
| `--username/--password` | 基础认证用户名/密码（可选） |

### 启动服务端

```bash
# 本地默认启动（监听 127.0.0.1:8775）
python sqlmapapi.py -s

# 远程访问场景（监听 0.0.0.0，允许外部连接）
python sqlmapapi.py -s -H "0.0.0.0" -p 8775
```

启动成功后控制台输出示例：

```
[*] Starting REST-JSON API server at 'http://127.0.0.1:8775'
[*] Admin token: 4c812e50b5fc8bba55207303f95f4025
```

> **注意**：Admin token 用于管理任务，需妥善保管。

### 启动客户端（命令行交互模式）

```bash
# 本地连接
python sqlmapapi.py -c

# 远程连接
python sqlmapapi.py -c -H "服务端IP" -p 8775
```

客户端启动后进入交互式 Shell，提示符为 `api>`。

## 命令行客户端实战：单点检测流程

### 创建扫描任务

```bash
api> new -u "http://127.0.0.1/sql-labs/Less-1/?id=1"
```

客户端会依次请求：
1. `GET /task/new` → 创建任务，返回 `taskid`（如 `efccd829b2b38546`）
2. `POST /scan/<taskid>/start` → 启动扫描

服务端日志会显示任务创建与扫描启动信息。

### 查看扫描状态

```bash
api (8d02d1e8e97ca089)> status
```

返回状态字段：
- `running`：扫描进行中
- `terminated`：扫描结束

### 获取扫描结果

```bash
api (8d02d1e8e97ca089)> data
```

返回 JSON 包含 `data` 字段，若非空则存在注入，包含注入类型、Payload、数据库版本等详细信息。

### POST 型注入检测

将 HTTP 请求原始包保存为文件（如 `1.txt`），使用 `-r` 参数：

```bash
api> new -r C:/Users/CZ/Desktop/1.txt
```

## HTTP API 核心端点与调用流程

SQLMap API 采用 **任务驱动** 模型，完整调用链路如下：

| 步骤 | HTTP 方法 | 端点 | 作用 |
|------|-----------|------|------|
| 1 | `GET` | `/task/new` | 创建新任务，返回 `taskid` |
| 2 | `POST` | `/option/<taskid>/set` | 设置扫描参数（URL、数据、Headers 等） |
| 3 | `POST` | `/scan/<taskid>/start` | 启动扫描任务 |
| 4 | `GET` | `/scan/<taskid>/status` | 轮询扫描状态 |
| 5 | `GET` | `/scan/<taskid>/data` | 获取扫描结果 |
| 6 | `GET` | `/task/<taskid>/delete` | 删除任务，释放资源 |

> **设计提示**：所有写操作均需 `Content-Type: application/json`，请求体为 JSON 格式。

## Python 自动化批量扫描脚本实战

### 核心逻辑封装

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SQLMap API 批量扫描自动化脚本
- 读取 url.txt 逐行扫描
- 结果追加写入 scan_result.txt
- 自动轮询状态、清理任务
"""
import requests
import json
import time
import sys

API_BASE = "http://127.0.0.1:8775"
HEADERS = {"Content-Type": "application/json"}

def create_task() -> str:
    """创建任务，返回 taskid"""
    resp = requests.get(f"{API_BASE}/task/new")
    resp.raise_for_status()
    data = resp.json()
    if data.get("success"):
        return data["taskid"]
    raise RuntimeError(f"创建任务失败: {data}")

def set_option(taskid: str, target_url: str) -> bool:
    """设置扫描目标 URL"""
    payload = {"url": target_url}
    resp = requests.post(
        f"{API_BASE}/option/{taskid}/set",
        data=json.dumps(payload),
        headers=HEADERS
    )
    return resp.json().get("success", False)

def start_scan(taskid: str, target_url: str) -> bool:
    """启动扫描"""
    payload = {"url": target_url}
    resp = requests.post(
        f"{API_BASE}/scan/{taskid}/start",
        data=json.dumps(payload),
        headers=HEADERS
    )
    return resp.json().get("success", False)

def wait_completion(taskid: str, interval: int = 3) -> dict:
    """轮询状态直到终止，返回 data 结果"""
    while True:
        resp = requests.get(f"{API_BASE}/scan/{taskid}/status")
        status = resp.json().get("status", "")
        if status == "running":
            time.sleep(interval)
            continue
        # terminated 或其他终态
        data_resp = requests.get(f"{API_BASE}/scan/{taskid}/data")
        return data_resp.json()

def delete_task(taskid: str) -> None:
    """删除任务释放资源"""
    requests.get(f"{API_BASE}/task/{taskid}/delete")

def scan_one(url: str) -> dict:
    """完整扫描单个 URL"""
    taskid = create_task()
    try:
        if not set_option(taskid, url):
            raise RuntimeError("设置选项失败")
        if not start_scan(taskid, url):
            raise RuntimeError("启动扫描失败")
        result = wait_completion(taskid)
        return result
    finally:
        delete_task(taskid)

def main():
    if len(sys.argv) > 1:
        url_file = sys.argv[1]
    else:
        url_file = "url.txt"

    with open(url_file, "r", encoding="utf-8") as f:
        urls = [line.strip() for line in f if line.strip()]

    print(f"[*] 共读取 {len(urls)} 个目标，开始批量扫描...")

    with open("scan_result.txt", "a", encoding="utf-8") as out:
        for url in urls:
            print(f"[+] 扫描: {url}")
            try:
                result = scan_one(url)
                out.write(f"=== {url} ===\n")
                out.write(json.dumps(result, ensure_ascii=False, indent=2))
                out.write("\n\n")
                if result.get("data"):
                    print(f"    [!] 发现注入: {url}")
                else:
                    print(f"    [-] 无注入: {url}")
            except Exception as e:
                print(f"    [x] 异常: {e}")
                out.write(f"=== {url} ===\nERROR: {e}\n\n")

    print("[*] 批量扫描完成，结果已保存至 scan_result.txt")

if __name__ == "__main__":
    main()
```

### 使用方法

1. 准备目标列表 `url.txt`（每行一个 URL）：
   ```
   http://target1.com/page?id=1
   http://target2.com/search?q=test
   ```
2. 启动 SQLMap API 服务端：
   ```bash
   python sqlmapapi.py -s -H 0.0.0.0 -p 8775
   ```
3. 运行自动化脚本：
   ```bash
   python sqlmap_batch_scan.py url.txt
   ```
4. 查看结果：
   ```bash
   cat scan_result.txt
   ```

### 进阶扩展建议

| 方向 | 说明 |
|------|------|
| **并发控制** | 使用 `threading` / `asyncio` 限制并发任务数，避免服务端过载 |
| **认证支持** | 在 `HEADERS` 中添加 `Authorization: Basic <base64(user:pass)>` |
| **POST 数据支持** | 扩展 `set_option` 接受 `data`、`cookie`、`headers` 等字段 |
| **结果结构化入库** | 解析 `data` 字段写入 SQLite / Elasticsearch，便于后续检索 |
| **Web UI 集成** | 配合 Flask/FastAPI 构建可视化任务管理面板 |

## 实战案例回顾

文章作者使用 SQL-Labs 靶场（Less-1）与真实站点验证：

| 目标 | 结果 |
|------|------|
| `http://127.0.0.1/sql-labs/Less-1/?id=1` | 检出 GET 型报错注入、布尔盲注、时间盲注、UNION 注入等多种类型 |
| 真实站点案例 | 成功识别注入点，提取数据库版本、当前用户等信息 |

批量扫描结果自动汇总至 `scan_result.txt`，便于后续人工复核与漏洞验证。

## 交叉引用与延伸阅读

- [[vulnhub-platform-resource-index]] — VulnHub 靶场资源索引，可作为 SQL 注入实战练习环境来源
- [[edu-src-penetration-test-case-study]] — 教育行业 SRC 渗透测试实战案例，包含 SQL 注入挖掘流程
- [[vulnhub-bbs-cute-102-writeup]] — CuteNews 文件上传绕过 Getshell 案例，展示 Web 漏洞组合利用链
- [[vulnhub-chronos-writeup]] — Node.js 原型链污染 RCE 与命令注入实战，体现现代 Web 技术栈注入面

## 小结

SQLMap API 将原本 CLI 单线程的注入检测能力**服务化、接口化**，配合 Python 自动化脚本可实现：

- **批量化**：百/千级目标无人值守扫描
- **可编程化**：集成 CI/CD、漏洞管理平台、资产收集流水线
- **可扩展性**：支持分布式部署、任务调度、结果结构化存储

掌握 `sqlmapapi.py` 两种模式及核心 HTTP 端点调用流程，是从「手工渗透」迈向「自动化红队/漏洞挖掘工程化」的关键一步。

## 来源

- [0x00实验室-202108-202304_036](../sources/0x00实验室-202108-202304_036.md)
