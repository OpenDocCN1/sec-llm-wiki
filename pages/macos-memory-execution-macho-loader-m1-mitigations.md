---
title: macOS 内存执行技术演进：shm_open 与 NSObjectFileImage 失败路径分析、Mach-O dyld 手工加载武器化实现、Apple
  Silicon M1 强制签名/SIP/W^X 缓解对抗
description: 系统梳理 macOS 内存执行技术演进：shm_open 与 NSObjectFileImage 两条失败路径分析、Mach-O dyld
  手工加载流程武器化实现细节，以及 Apple Silicon M1 引入的强制代码签名、SIP 与 W^X (DEP) 对红队武器开发的实战影响。
category: program-analysis
tags:
- macOS
- Memory Execution
- Mach-O
- dyld
- Apple Silicon
- M1
- Code Signing
- SIP
- W^X
- DEP
- Red Teaming
- Weapon Development
- Reflective Loading
- shm_open
- NSObjectFileImage
date: '2024-01-15'
updated: '2026-11-15'
---

## 概述

本页面系统记录 macOS 平台内存执行（Memory Execution / Reflective Loading）技术的演进历程，重点覆盖三大核心主题：

1. **两条失败探索路径**：`shm_open` 共享内存路径与 `NSObjectFileImage` 系统 API 路径的技术细节、失效原因及版本演进分析
2. **Mach-O dyld 手工加载流程武器化实现**：从文件解析、依赖加载、段映射、重定位/绑定（bytecodes 与 chained fixups 双版本）、TLS 初始化到入口点执行的完整工程化流程
3. **Apple Silicon M1 安全机制对武器开发的实战影响**：强制代码签名、系统完整性保护 (SIP)、W^X (DEP) 三大缓解措施的技术原理、绕过现状与红队工程对策

> **定位说明**：作者自述 macOS 攻防属入门水平，页面内容基于实战武器化开发过程中的研究记录整理，供同行参考交叉验证。

---

## 一、 macOS 内存执行的两条失败探索路径

### `shm_open` 共享内存路径

#### 背景与动机
Linux 下 `shm_open` + `memfd_create` 是主流无文件执行手段，macOS 同样提供 `shm_open` 且不落盘至可见文件系统，初看可复用该思路。

#### 关键差异对比

| 特性 | Linux `/dev/shm` | macOS `shm_open` |
|------|------------------|------------------|
| 文件系统可见性 | 可见于 `/dev/shm` | 不可见 |
| 匿名创建支持 | 需 `memfd_create` (Linux ≥ 3.17) | 原生支持 |
| `/dev/fd/<fd>` 可 `chmod` | ✅ | ❌ Operation not permitted |
| `/dev/fd/<fd>` 可 `execve` | ✅ | ❌ Permission denied |
| `/dev/fd/<fd>` 可 `dlopen` | ✅ | ✅ |
| `shm_open` fd 可 `read` | ✅ | ❌ Device not configured (只能 `mmap`) |
| `shm_open` fd 可 `dlopen` | ✅ | ❌ 返回 NULL |

#### 实测代码与输出摘录

```c
// 关键测试逻辑：对比普通文件 fd 与 shm_open fd 在 /dev/fd 下的行为
int dev_fd(char **argv) { open("/bin/ls", O_RDONLY); }
int dev_fd_shm(char **argv) {
    shm_unlink("ls");
    int shm_fd = shm_open("ls", O_RDWR|O_CREAT|O_EXCL, 0777);
    // ... ftruncate, mmap, read /bin/ls 到共享内存 ...
    return shm_open("ls", O_RDONLY); // 重新以 RO 打开
}
void test(int fd, char** argv) {
    char f[64]; sprintf(f, "/dev/fd/%d", fd);
    chmod(f, 0777); dlopen(f, RTLD_NOW); execve(f, argv, environ);
}
```

**输出结果**：
```
===== test /dev/fd (普通文件)
-54 -2 -70 -66 0 0 0 2 /dev/fd/3
chmod: Operation not permitted
dlopen 0x204d35460        ← 仅 dlopen 成功
execve: Permission denied

===== test /dev/fd shm (shm_open)
read: Device not configured  ← 甚至无法 read
0 0 0 0 0 0 0 0 /dev/fd/4
chmod: Bad file descriptor
dlopen 0x0                  ← 全部失败
execve: Permission denied
```

#### 结论
macOS 对 `/dev/fd` 抽象层施加了比 Linux 严格得多的限制，**`shm_open` 路径无法实现内存执行**，仅能作为极受限的共享内存 IPC 机制。

---

### `NSObjectFileImage` 系统 API 路径

#### API 链与设计意图
```c
NSCreateObjectFileImageFromMemory(buf, size, &img);  // 1. 从内存创建镜像
NSLinkModule(img, "_", NSLINKMODULE_OPTION_NONE);    // 2. 链接到全局模块
NSLookupSymbolInModule(mod, "_foo");                 // 3. 查找符号
NSAddressOfSymbol(sym);                              // 4. 获取地址并调用
```
> **官方状态**：macOS 10.5 起标记弃用，但 dyld 一直导出至 macOS 12.2+

#### 核心限制：仅支持 **Loadable Bundle** (MH_BUNDLE)
```c
// dyld 源码 NSCreateObjectFileImageFromMemory 片段
if (!mf->isBundle()) return NSObjectFileImageInappropriateFile;
```
- 需将 Mach-O `filetype` 从 `MH_EXECUTE`/`MH_DYLIB` patch 为 `MH_BUNDLE`
- Intel macOS 可通过二进制 patch 绕过；**M1 原生 ARM 程序因强制签名无法 patch**（见第三节）

#### 实测验证
```c
// 简易 loader：读取文件 → patch filetype → NSObjectFileImage 链调用
((struct mach_header_64*)buf)->filetype = MH_BUNDLE;
NSObjectFileImage img;
NSCreateObjectFileImageFromMemory(buf, s.st_size, &img);
NSModule mod = NSLinkModule(img, "_", NSLINKMODULE_OPTION_NONE);
NSSymbol sym = NSLookupSymbolInModule(mod, "_foo");
((void(*)())NSAddressOfSymbol(sym))();
```
**Intel macOS 测试通过**，可加载 dylib/executable 并执行导出函数。

---

### `NSObjectFileImage` 的隐蔽性缺陷：临时文件落盘

#### 动态特征发现
逆向 CrossC2 Beacon 观测到端点检测日志：
```
[cc2_mem]: run executable file from memory!
Created file: /private/var/folders/xx/.../T/NSCreateObjectFileImageFromMemory-Ay24wFNH
Modified file: /private/var/folders/xx/.../T/NSCreateObjectFileImageFromMemory-Ay24wFNH
Deleted file: /private/var/folders/xx/.../T/NSCreateObjectFileImageFromMemory-Ay24wFNH
```
**结论**：`NSObjectFileImage` 并非纯内存加载，会在 `$TMPDIR` 落盘临时文件，特征极其明显（固定前缀 `NSCreateObjectFileImageFromMemory-`），**隐蔽性甚至不如随机文件名 `dlopen`/`execve`**。

#### 源码溯源：dyld 版本演进
| dyld 版本 | 大致时间 | `NSLinkModule` 实现 | 落盘行为 |
|-----------|----------|---------------------|----------|
| ≤ dyld-433.5 | ~2017.9 前 | `dyld::loadFromMemory` → `ImageLoaderMachO::instantiateFromMemory` 纯内存实例化 | ❌ 无落盘 |
| ≥ dyld-519.2.1 | ~2017.9 起 | 创建 `$TMPDIR/NSCreateObjectFileImageFromMemory-XXXXXXXX` → `pwrite` 内容 → `dlopen` | ✅ 落盘 |

**dyld-433.5 关键逻辑**：
```cpp
ImageLoader* loadFromMemory(const uint8_t* mem, uint64_t len, const char* moduleName) {
    if (isCompatibleMachO(mem, moduleName)) {
        return ImageLoaderMachO::instantiateFromMemory(moduleName, (macho_header*)mem, len, gLinkContext);
    }
    // 纯内存解析、校验、创建 ImageLoader，无文件操作
}
```

**dyld-519.2.1 关键逻辑 (APIs_macOS.cpp:153)**：
```cpp
ofi->path = ::tempnam(nullptr, "NSCreateObjectFileImageFromMemory-");
int fd = mkstemp(tempFileName);
pwrite(fd, ofi->memSource, ofi->memLength, 0);
ofi->handle = dlopen(ofi->path, openMode);  // 最终走 dlopen 文件路径
```

#### 定论
**`NSObjectFileImage` 自 2017 年起已成为攻防领域“死去的技术”**，不可用于隐蔽内存执行。

---

## 二、 Mach-O dyld 手工加载流程武器化实现

因上述两条路径均不可行，**唯一可行方案是完整实现 Mach-O 手工加载器（Manual Mapping / Reflective Loader）**，参考 [[pe-manual-mapping-loader-implementation]] 中 Windows PE 手工映射的工程化思路，结合 dyld 开源实现完成跨架构武器化。

### 整体加载流程 (8 步)

```mermaid
flowchart TD
    A[1. 解析 LC_LOAD_DYLIB 加载依赖库] --> B[2. 遍历 LC_SEGMENT_64 计算总大小 vm_allocate 分配连续内存]
    B --> C[3. 遍历 LC_SEGMENT_64 映射段内容到分配内存]
    C --> D{macOS 版本}
    D -- ≤ 11 (≤ iOS 14) --> E[4a. 解析 LC_DYLD_INFO/ONLY 处理 rebase/bind/weak_bind/lazy_bind bytecodes]
    D -- ≥ 12 (≥ iOS 15) --> F[4b. 解析 LC_DYLD_CHAINED_FIXUPS 处理 DYLD_CHAINED_IMPORT*/PTR*]
    E --> G[5. 初始化 TLS (TLV descriptors)]
    F --> G
    G --> H[6. vm_protect 恢复段保护属性 (RW→RX, R→R, 等)]
    H --> I[7. 遍历 S_INIT_FUNC_OFFSETS / S_MOD_INIT_FUNC_POINTERS 调用初始化器]
    I --> J[8. 定位入口点 (LC_MAIN/LC_UNIXTHREAD) 执行]
```

### 关键步骤技术细节

#### 步骤 1：依赖库加载 (`LC_LOAD_DYLIB`)
- 遍历加载命令，`dlopen` 各依赖 `dylib` (RTLD_NOW | RTLD_LOCAL)
- 处理 `@rpath`/`@loader_path`/`@executable_path` 展开
- 维护已加载模块句柄表供后续符号解析复用

#### 步骤 2-3：段内存分配与映射
```c
// 计算总虚拟地址跨度
vm_address_t min_addr = UINT64_MAX, max_addr = 0;
for (seg : LC_SEGMENT_64) {
    min_addr = min(min_addr, seg->vmaddr);
    max_addr = max(max_addr, seg->vmaddr + seg->vmsize);
}
size_t total_size = max_addr - min_addr;
// 分配连续可执行内存 (需绕过 W^X，见 3.2 节)
vm_allocate(mach_task_self(), &base, total_size, VM_FLAGS_ANYWHERE);
// 逐段 memcpy / mmap 映射文件内容
```

#### 步骤 4a：经典 Rebase/Bind Bytecodes (macOS ≤ 11)
- 数据结构：`LC_DYLD_INFO` / `LC_DYLD_INFO_ONLY` 中的 `rebase_off/size`、`bind_off/size`、`weak_bind_off/size`、`lazy_bind_off/size`
- 解析参考：`ImageLoaderMachOCompressed::eachBind` [[参考 6]](https://github.com/opensource-apple/dyld/blob/3f928f32597888c5eac6003b9199d972d49857b5/src/ImageLoaderMachOCompressed.cpp#L934)
- Bytecode 指令集：`REBASE_OPCODE_*`、`BIND_OPCODE_*` 等，模拟 dyld 解释器逐条执行

#### 步骤 4b：Chained Fixups (macOS ≥ 12 / iOS ≥ 15)
- 数据结构：`LC_DYLD_CHAINED_FIXUPS` → `dyld_chained_fixups_header` → 多个 `dyld_chained_fixups` (每段一个)
- 两大类型：
  - `DYLD_CHAINED_IMPORT*`：外部符号导入绑定 (指向符号表/字符串表)
  - `DYLD_CHAINED_PTR*`：内部指针重定向 (相对/绝对地址、高位标记、认证指针 PAC)
- 解析参考：LIEF `ChainedFixup.cpp` [[参考 7]](https://github.com/lief-project/LIEF/blob/master/src/MachO/ChainedFixup.cpp)
- 核心逻辑：遍历每段的 `starts_at` 链表，按 `ptr_format` 解码每个 fixup 项，应用 `slide` 或绑定符号地址

#### 步骤 5：TLS (Thread Local Storage) 初始化
- macOS TLS 模型与 Windows 差异大：**无 `CRTStartup` 包装**，初始化器在 `__mod_init_func` 中显式调用 `__tlv_bootstrap` 等
- 处理 `LC_THREAD_LOCAL` / `__DATA/__thread_vars` / `__DATA/__tlv_*` 描述符
- 调用 `tlv_initializer` 为每个 TLS 变量分配实例

#### 步骤 6-7：保护属性恢复与初始化器执行
- `vm_protect` 按段原始 `vm_prot`/`max_prot` 还原 (RX/R/RW)
- 遍历 `__DATA/__mod_init_func` (函数指针数组) 与 `__DATA/__init_func_offsets` (偏移量数组) 调用所有构造函数
- **注意**：C++ 全局对象构造、ObjC `+load`、Go `runtime.init` 均在此阶段执行

#### 步骤 8：入口点执行
- `LC_MAIN` (现代) 或 `LC_UNIXTHREAD` (旧) 定位 `entryoff` / `thread_state.__rip`
- 调用签名：`int main(int argc, char** argv, char** envp, char** apple)`
- 武器化场景下通常调用导出函数而非 `main`

### 工程化集成策略：`fork` + 执行

```c
pid_t pid = fork();
if (pid == 0) {
    // 子进程：执行手工加载器，调用目标函数
    macho_loader_load_and_run(payload, entry_symbol, args);
    _exit(0);
} else {
    // 父进程：waitpid 捕获退出码，读取管道/共享内存获取输出
}
```
**优势** (同 Cobalt Strike `fork&run`)：
- 稳定性：崩溃隔离在子进程
- 输出捕获：管道重定向 stdout/stderr 无竞争
- 进程树隐蔽：`fork` 非敏感行为 (Unix 标准进程创建模型)

### 武器化测试矩阵

| 目标载荷 | 架构 | macOS 版本 | 测试结果 |
|----------|------|------------|----------|
| `iox.dylib` (内网穿透) | amd64 / arm64 | ≥ 12 | ✅ 成功 |
| `hack-browser-data.dylib` (凭证导出) | amd64 / arm64 | ≥ 12 | ✅ 成功 |
| CrossC2 Kit `crossc2_frp.dylib` 等 | amd64 | ≤ 11 (借用环境) | ✅ 成功 |

> **开源状态**：该加载器集成于 C2 框架并兼作 macOS 加壳免杀模块，**暂不开源**。

---

## 三、 Apple Silicon M1 安全机制对武器开发的实战影响

### 强制代码签名 (Mandatory Code Signing)

#### 机制原理
- **ARM64 原生二进制**：内核强制验证代码签名 (Code Directory + CMS 签名)，签名无效或缺失 → `SIGKILL` (Killed: 9)
- **x86_64 Rosetta 2 翻译**：**不强制验证签名**，无签名可执行

#### 实测现象
```bash
# ARM64 原生程序修改 1 字节数据段
$ ./patched_arm64_binary
Killed: 9  # 进程直接被内核终止

# 同一文件在 Rosetta 2 下运行
$ arch -x86_64 ./patched_arm64_binary
正常执行  # 无签名校验
```

#### `codesign` 验证差异
```bash
$ codesign -dv ./arm64_binary
Executable=./arm64_binary
Identifier=...
Format=Mach-O thin (arm64)
CodeDirectory v=20500 size=... flags=0x10000(runtime) hashes=...+5
Signature=...  # 编译器自动生成 ad-hoc 签名

$ codesign -dv ./x86_64_binary
Executable=./x86_64_binary
Format=Mach-O thin (x86_64)
CodeDirectory v=20500 size=... flags=0x0(none) hashes=0+0
Signature=none  # 无签名
```

#### 尝试移除签名失败
```bash
$ codesign --remove-signature ./arm64_binary
$ ./arm64_binary
Killed: 9  # 移除签名后依然被杀，内核要求必须有有效签名
```

#### 对武器开发的直接影响
| 影响场景 | 后果 | 备选方案 |
|----------|------|----------|
| **Patch 文件头 `filetype` 实现 `NSObjectFileImage` 加载** | 签名破坏 → 无法加载 | 放弃该路径，改用手工加载器 |
| **运行时 Patch 代码段/数据段 (Hook、Inline Patch)** | 签名失效 → 进程被杀 | 使用 `ptrace`/`task_for_pid` 外部修改 + 重签名 (需 SIP 关闭) |
| **生成无签名 Shellcode/Reflective DLL 类载荷** | 无法直接执行 | 仅能在 Rosetta 2 (x86_64) 下运行，或配合有效签名证书 |
| **加载未签名 dylib (插件、注入库)** | `dlopen` 失败 | 仅能加载有效签名库，或关闭 SIP (实战不可行) |

> **实战结论**：**强制签名彻底堵死了“二进制 Patch 后执行”这类传统免杀/武器化手法**，迫使红队转向：纯内存手工加载 (不落盘、不修改磁盘镜像)、Rosetta 2 x86_64 兼容模式、或获取有效开发者证书签名 (运维成本高、易溯源)。

---

### SIP (System Integrity Protection)

#### 关键受保护资源
- `/System`、`/usr` (除 `/usr/local`)、`/bin`、`/sbin`、`/var` 部分目录
- 内核扩展加载限制
- `task_for_pid` / `ptrace` 附着系统进程限制
- NVRAM 变量写入限制
- **代码签名策略强制执行** (上节机制的内核层强制点)

#### 关闭 SIP 的唯一路径
- **Recovery Mode** → `csrutil disable` → 重启
- **实战可行性**：**几乎为零** (需物理访问/重启/用户交互，留痕极重)

#### 武器化层面的应对
- **不依赖 SIP 关闭**：手工加载器完全在用户态、无需 `task_for_pid`、无需写受保护路径
- **避免触发 SIP 保护点**：不注入系统进程、不修改系统二进制、不加载内核扩展
- **绕过思路 (学术研究)**：利用 SIP 例外列表 (`/Library/Apple/System/Library/Extensions` 等) 或 TCC 数据库注入，但属后渗透阶段，非初始执行环节

---

### W^X / DEP (Write XOR Execute)

#### 机制表现
```c
// vm_protect 权限组合测试 (READ=1, WRITE=2, EXEC=4)
vm_protect(addr, size, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);   // RX → KERN_SUCCESS (0)
vm_protect(addr, size, FALSE, VM_PROT_READ | VM_PROT_WRITE);      // RW → KERN_SUCCESS (0)
vm_protect(addr, size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE); // RWX → KERN_PROTECTION_FAILURE (2)
vm_protect(addr, size, FALSE, VM_PROT_WRITE | VM_PROT_EXECUTE);   // WX  → KERN_PROTECTION_FAILURE (2)
```
- **ARM64 原生**：严格禁止 `W|X` 共存，**不存在 RWX / WX 页面**
- **Rosetta 2 x86_64**：**无此限制**，可创建 RWX

#### 对手工加载器的工程影响
| 阶段 | 需求 | M1 ARM64 解法 |
|------|------|---------------|
| **段映射 (步骤 3)** | 写入代码/数据段内容 | 先 `vm_allocate` + `VM_PROT_READ|VM_PROT_WRITE` → `memcpy` 写入 |
| **重定向/绑定 (步骤 4)** | 修正 GOT/IAT/绝对地址 | 同期仍在 RW 状态，可写 |
| **保护恢复 (步骤 6)** | 代码段变 RX，数据段变 RW/R | `vm_protect` 分段设置，**严禁 RWX** |
| **JIT / Shellcode 执行** | 动态生成代码并执行 | **双映射技术**：同一物理页映射两个虚拟地址，一 RW 一 RX (需 `vm_remap`/`mach_vm_map` + `VM_FLAGS_ALIAS_MASK`) |

#### 双映射 (Alias Mapping) 代码片段
```c
// 分配物理内存
mach_vm_address_t rw_addr, rx_addr;
mach_vm_allocate(mach_task_self(), &rw_addr, size, VM_FLAGS_ANYWHERE);
// 创建 RX 别名映射指向同一物理页
mach_vm_remap(mach_task_self(), &rx_addr, size, 0, VM_FLAGS_ALIAS_MASK,
              mach_task_self(), rw_addr, FALSE, NULL, NULL, VM_PROT_READ|VM_PROT_EXECUTE);
// RW 地址写入 Shellcode → RX 地址执行
memcpy((void*)rw_addr, shellcode, size);
((void(*)())rx_addr)();
```
> **注意**：`VM_FLAGS_ALIAS_MASK` 行为在 macOS 版本间有细微差异，需实测验证。

---

## 四、 交叉引用与对比视角

| 技术域 | 关联页面 | 共性/差异点 |
|--------|----------|-------------|
| **Windows PE 手工映射** | [[pe-manual-mapping-loader-implementation]] | 同为 Reflective Loader 核心模式；Windows 无强制签名、有 `RWX` 页面、IAT 修复更简单；macOS 增加 chained fixups、TLS 初始化器、W^X 双映射复杂度 |
| **用户态反射加载器** | [[aceldr-technical-analysis]] | AceLdr 针对 Cobalt Strike Beacon 的睡眠/堆/返回地址/内存加密规避；macOS Loader 侧重格式解析与加载流程，规避层面需结合 [[memory-scanning-tools-evasion-techniques]] |
| **内存扫描对抗** | [[memory-scanning-tools-evasion-techniques]] | moneta/pe-sieve 等工具检测 PE 特征；macOS 同类工具较少，但 `dyld` 内部镜像列表、代码签名验证、页面权限异常均为检测点 |
| **BOF/插件化加载** | [[cobalt-strike-4.7-bof-internals]] | BOF 为无重定位/无导入的简化 COFF；Mach-O 完整加载器需处理完整依赖图、重定位链、初始化器 |
| **动态导入/符号解析** | [[rust-proc-macro-win32-dynamic-import]] | Windows 侧重 `GetProcAddress`/`LoadLibrary` 哈希化；macOS 手工加载器需自行实现 `dlopen`/`dlsym` 语义 (重定位+绑定) |
| **Phantom DLL Hollowing** | [[phantom-dll-hollowing-technique]] | 利用合法 DLL 模块掩护恶意内存；macOS 可类比“劫持合法 dylib 映射区”，但强制签名使模块替换极难 |

---

## 五、 总结与防御视角

### 攻击面收敛演进
| 时期 | 可用技术 | 失效原因 |
|------|----------|----------|
| ≤ 2017 (dyld < 519) | `NSObjectFileImage` 纯内存加载 | dyld 重构引入临时文件落盘 |
| 2017–2020 (Intel macOS) | `NSObjectFileImage` + 文件头 Patch / 手工加载器 | M1 强制签名杀死 Patch 路径 |
| ≥ 2020 (Apple Silicon) | **仅手工加载器 (Manual Mapping)** | 强制签名 + SIP + W^X 三重缓解 |

### 红队工程建议
1. **标准化手工加载器**：维护跨架构 (amd64/arm64)、跨版本 (≤11/≥12) 统一代码库，隔离 bytecodes 与 chained fixups 解析器
2. **拥抱 Rosetta 2 兼容模式**：x86_64 载荷在 M1 上免签名、免 W^X，作为过渡期主力
3. **双映射实现 JIT/Shellcode**：解决 ARM64 无 RWX 限制
4. **避免任何磁盘落盘与二进制修改**：纯内存操作规避签名校验与文件监控
5. **集成进程伪装与输出捕获**：`fork&run` + 管道重定向，降低行为特征

### 蓝队检测重点
| 检测层面 | 关键指标 | 工具/机制 |
|----------|----------|-----------|
| **内存完整性** | 匿名 RW→RX 页面变更、双映射别名区域、非模块映射可执行页 | `vmmap`、`proc_regionfilename`、Endpoint Security Framework |
| **代码签名** | 无签名/签名无效 ARM64 映像加载尝试、ad-hoc 签名异常 | `codesign -dv`、内核 `vnode_check_signature` 审计 |
| **动态链接器** | 进程镜像列表 (`_dyld_image_count`) 与实际映射模块不一致、手工 `dlopen` 痕迹 | `dyld` 源码审计、DYLD_INSERT_LIBRARIES 监控 |
| **进程行为** | `fork` 后立即执行非磁盘二进制、管道输出大量二进制数据 | Auditd、OpenBSM、EDR 行为分析 |

---

## 参考资料与源码索引

| 编号 | 引用内容 | 链接 |
|------|----------|------|
| [1] | macOS 10.5 弃用声明 | https://github.com/apple-oss-distributions/dyld/blob/main/libdyld/libdyldGlue.cpp#L214 |
| [2] | `NSCreateObjectFileImageFromMemory` 实现 | https://github.com/apple-oss-distributions/dyld/blob/main/dyld/DyldAPIs.cpp#L2727 |
| [3] | `NSLinkModule` 实现 | https://github.com/apple-oss-distributions/dyld/blob/main/dyld/DyldAPIs.cpp#L2788 |
| [4] | Bundle 文件格式说明 | https://en.wikipedia.org/wiki/Bundle_(macOS) |
| [5] | Mach-O 文件格式深度解析 | https://evilpan.com/2020/09/06/macho-inside-out/ |
| [6] | `ImageLoaderMachOCompressed::eachBind` bytecodes 解析 | https://github.com/opensource-apple/dyld/blob/3f928f32597888c5eac6003b9199d972d49857b5/src/ImageLoaderMachOCompressed.cpp#L934 |
| [7] | LIEF Chained Fixups 解析实现 | https://github.com/lief-project/LIEF/blob/master/src/MachO/ChainedFixup.cpp |
| [8] | 原文微信文章 | http://mp.weixin.qq.com/s?__biz=Mzg5MjU2NTc1Mg==&mid=2247483754&idx=1&sn=49e1e46cf8f4568b7364bcedc906c33c |

---

## 更新日志

| 日期 | 版本 | 变更摘要 |
|------|------|----------|
| 2024-01-15 | 1.0 | 初稿：整合原文三大板块，补充交叉引用、对比表、工程细节与蓝红对抗视角 |

---

**分类标签**：`program-analysis` `macOS` `Memory Execution` `Mach-O` `dyld` `Apple Silicon` `M1` `Code Signing` `SIP` `W^X` `DEP` `Red Teaming` `Weapon Development` `Reflective Loading` `shm_open` `NSObjectFileImage`

## 来源

- [0x4d5a-202103-202209_06](../sources/0x4d5a-202103-202209_06.md)
