---
title: Mimikatz sekurlsa::pth 深度解析：LSASS 内存补丁实现 Pass-the-Hash 底层原理
description: 深度解析 mimikatz sekurlsa::pth 模块通过 LSASS 内存补丁实现 Pass-the-Hash 的底层原理，覆盖
  LogonSessionList 定位、LSA Protect 密钥提取、凭据解密与 NTLM hash 替换全流程，并附纯 Rust 实现参考
category: program-analysis
tags:
- Mimikatz
- Pass-the-Hash
- LSASS
- Windows Internals
- Memory Patching
- sekurlsa
- NTLM
- LSA Protect
- Rust
- Red Teaming
- Credential Theft
date: 2023-04-16
updated: '2026-11-15'
---

## 概述

本页面系统梳理 mimikatz `sekurlsa::pth` 模块通过 **LSASS 进程内存补丁** 实现 Pass-the-Hash (PTH) 的完整技术链路。文章基于 mimikatz 源码（`kuhl_m_sekurlsa_pth`）与作者的纯 Rust 复现实现（约 2K 行，依赖 `windows-rs`），覆盖：

- `LogonSessionList` 双向链表定位与遍历
- LSA Protect 密钥（AES-CFB / 3DES-CBC）提取与凭据解密
- `MSV1_0_PRIMARY_CREDENTIAL` 结构中 NTLM hash 替换与回写
- `CreateProcessWithLogonW` + `LOGON_NETCREDENTIALS_ONLY` 创建新 Logon Session 的机制
- 仅支持 NT6+（Vista/7/8/10+），不再覆盖 NT5（DESX 等旧算法）

> **适用场景**：工作组环境下的 PTH；域环境下的 KRB 凭据替换原理相同。  
> **参考实现**：[sekurlsa::pth written in pure Rust](https://github.com/EddieIvan01/win32api-practice/tree/master/pth)

---

## Pass-the-Hash 攻击面回顾

NTLM 认证的 Type 3 消息中，Response 计算仅需 **Challenge + Hash**（v2 额外需 Nonce），因此掌握 NTLM Hash 即可完成认证，无需明文密码。

Windows 官方认证 API（`LogonUser`、`AcquireCredentialsHandle` 等）仅接受 **明文密码**，不直接接受 Hash。PTH 工具的核心任务即：**让 LSASS 在后续网络认证时使用攻击者指定的 Hash**。

---

## PTH 两大实现流派对比

| 维度 | mimikatz（内存补丁） | impacket 等（协议层重写） |
|------|----------------------|---------------------------|
| **原理** | Patch `LSASRV.dll` 中目标 Logon Session 的凭据缓存 | 在 SMB/RPC 等上层协议实现中直接替换 NTLMSSP 字段 |
| **覆盖面** | 全面：`dir \\UNC`、`wmic`、`psexec` 等均走 LSASS | 需逐协议实现，维护成本高 |
| **稳定性** | 依赖内存签名，版本强相关，需维护签名库 | 协议标准相对固定，版本兼容性好 |
| **隐蔽性** | 需 `OpenProcess(PROCESS_VM_READ/WRITE/OPERATION)`，易触发 EDR | 纯用户态协议构造，无跨进程内存操作 |

> 本页面聚焦 **mimikatz 内存补丁流派** 的完整逆向还原。

---

## sekurlsa::pth 核心流程解析

### 入口与分支：`kuhl_m_sekurlsa_pth`

主函数逻辑：

1. **参数解析**：`luid`、`user`、`domain`、`impersonate`、`run`、`[ntlm/rc4/aes128/aes256]`
2. **分支 A —— 显式 LUID**  
   若提供 `luid`，直接定位并 Patch 对应 Logon Session。
3. **分支 B —— 无 LUID（默认）**  
   - `CreateProcessWithLogonW(..., LOGON_NETCREDENTIALS_ONLY, CREATE_SUSPENDED)` 启动新进程（空密码）  
   - 从新进程 Token 中读取 `AuthenticationId`（即 LUID）  
   - Patch 该 LUID 对应的新 Logon Session
4. 通过两个回调分别处理 **MSV (NTLM)** 与 **Kerberos** 凭据：
   - `kuhl_m_sekurlsa_enum_callback_msv_pth`
   - `kuhl_m_sekurlsa_enum_callback_kerberos_pth`
5. `ResumeThread` 恢复进程，攻击生效。

> **冷知识**：`luid` 参数**文档未公开**、**命令行无提示**，仅读源码可发现。利用场景：当前用户名/域名与目标一致时，先 `sekurlsa::msv` 枚举所有 Session，再传 LUID 精准 Patch，后续启动的子进程自动继承已修改的 Session。

---

### `CreateProcessWithLogonW` 与 `LOGON_NETCREDENTIALS_ONLY`

```cpp
CreateProcessWithLogonW(
    user, domain, L"",
    LOGON_NETCREDENTIALS_ONLY,
    cmdline,
    CREATE_NEW_CONSOLE | CREATE_SUSPENDED,
    0, NULL, &si, &pi
);
```

**文档说明**：
> "The system creates a new logon session within LSA ... The system does not validate the specified credentials."

- 新进程 **复用调用者 Token**，但在 LSA 内部**新建一个 Logon Session**
- 凭据**不校验有效性** → 可用空密码启动
- 该 Session 仅用于**网络认证**，本地访问仍用原 Token

这就是为什么 PTH 默认分支必须**先起进程、再 Patch 新 Session** 的根本原因。

---

### 跨进程读取 LSASS：`kuhl_m_sekurlsa_acquireLSA`

核心步骤：

1. `OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid_lsass)`
2. 遍历 `PEB->Ldr->InMemoryOrderModuleList` 定位 `LSASRV.dll` 基址与大小
3. `ReadProcessMemory` 将 `LSASRV.dll` 镜像读入本地缓冲区
4. 获取 `OSVERSIONINFOEX`（Major/Minor/Build）用于后续签名选择

> 关键技能：**在外部进程空间安全遍历 PEB 链表、读取模块信息**，见 [[pe-manual-mapping-loader-implementation]] 中 PEB 解析章节。

---

### 定位 `LogonSessionList` 与 `LogonSessionListCount` —— 内存签名法

`LSASRV.dll` 导出符号中**不导出**这两个全局变量，只能通过**特征码**定位。

#### 签名来源

寻找**同时引用** `LogonSessionList` 与 `LogonSessionListCount` 的函数，提取其**不含寻址指令的机器码**作为 Pattern。不同 Windows 版本签名不同：

```rust
// 仅列举部分，完整表见源码
const PTRN_WN60_LogonSessionList: &[u8] = &[0x33, 0xFF, 0x45, 0x85, 0xC0, 0x41, 0x89, 0x75, 0x00, 0x4C, 0x8B, 0xE3, 0x0F, 0x84];
const PTRN_WN61_LogonSessionList: &[u8] = &[0x33, 0xF6, 0x45, 0x89, 0x2F, 0x4C, 0x8B, 0xF3, 0x85, 0xFF, 0x0F, 0x84];
const PTRN_WN63_LogonSessionList: &[u8] = &[0x8B, 0xDE, 0x48, 0x8D, 0x0C, 0x5B, 0x48, 0xC1, 0xE1, 0x05, 0x48, 0x8D, 0x05];
// ... 10_1507, 10_1703, 10_1803, 10_1903 等
```

每个 Pattern 配套两个 **相对偏移**（`offset_to_List`, `offset_to_Count`），用于从 Pattern 地址计算全局变量真实地址。

#### 64 位下的 RIP 相对寻址解析

```rust
// 读取 Pattern 处的 4 字节相对偏移
let offset: i32 = read_process_mem(pattern_addr + rel_offset)?;
let target_addr = pattern_addr + rel_offset + 4 + offset as isize; // RIP = next_instr
```

32 位则直接读取 4 字节绝对地址。

#### 遍历双向链表

`LogonSessionListCount` 给出头指针数组长度（通常为 1），`LogonSessionList` 指向 `LIST_ENTRY` 头节点。

```rust
for i in 0..count {
    let mut head_ptr: *const LIST_ENTRY = read_ptr(logon_session_list + i * ptr_size)?;
    let mut entry = read_list_entry(head_ptr)?;
    while entry.Flink != head_ptr {
        let session_struct = read_struct(entry.Flink, KIWI_MSV1_0_LIST_63_SIZE)?;
        // 解析 LUID、UserName、Domain、LogonType、Credentials 指针等
        entry = read_list_entry(entry.Flink)?;
    }
}
```

> `KIWI_MSV1_0_LIST_63` 等结构为 mimikatz 逆向还原，包含 `Flink/Blink`、`LocallyUniqueIdentifier`、`UserName`、`Domain`、`Credentials` 指针等关键字段。完整定义见源码或 [[mimikatz-source-code-architecture-golden-ticket-audit]] 中数据结构章节。

---

### LSA Protect 密钥提取与凭据解密

NT6+ 引入 **LSA Protect**，凭据在内存中加密存储。算法选择规则：

| 数据长度模 8 | 算法 |
|--------------|------|
| ≠ 0          | AES-256-CFB |
| = 0          | 3DES-CBC |

密钥材料保存在 `LSASRV.dll` 全局变量 `h3DesKey` / `hAesKey`（类型 `KIWI_BCRYPT_HANDLE_KEY`），同样通过 **Pattern 定位**。

#### 关键结构

```text
KIWI_BCRYPT_HANDLE_KEY
  tag = "UUUR" (0x55555552)
  key -> KIWI_BCRYPT_KEY / KIWI_BCRYPT_KEY8 / KIWI_BCRYPT_KEY81 (随版本变化)
        tag = "MSSK" (0x4D53534B)
        hardkey -> KIWI_HARD_KEY
                  cbSecret, data[cbSecret]  // 真正的对称密钥 + IV
```

#### 密钥派生与解密流程

1. Pattern 定位 `h3DesKey` / `hAesKey` 指针
2. 读取 `KIWI_BCRYPT_HANDLE_KEY` → 校验 tag
3. 读取嵌套的 `KIWI_BCRYPT_KEY*` → 校验 tag
4. 提取 `KIWI_HARD_KEY.data` 作为原始密钥
5. 调用 `BCryptOpenAlgorithmProvider` + `BCryptGenerateSymmetricKey` 生成句柄
6. `BCryptDecrypt` 解密 `Credentials` 指针指向的加密块

> 该过程在 [[ppldump-userland-ppl-bypass-evasion]] 中亦有类似 LSASS 密钥提取的对抗实践。

---

### Patch NTLM Hash：`MSV1_0_PRIMARY_CREDENTIAL` 结构操作

解密后的凭据缓冲区（以 Win10 1607 为例）：

```c
struct MSV1_0_PRIMARY_CREDENTIAL_10_1607 {
    UNICODE_STRING LogonDomainName;
    UNICODE_STRING UserName;
    PVOID          pNtlmCredIsoInProc;
    BYTE           isIso;
    BYTE           isNtOwfPassword;   // 1 = NTLM hash 有效
    BYTE           isLmOwfPassword;   // 0 = 禁用 LM
    BYTE           isShaOwPassword;   // 0 = 禁用 SHA
    BYTE           isDPAPIProtected;  // 0 = 禁用 DPAPI
    // ... padding
    DWORD          unkD;
    WORD           isoSize;
    BYTE           DPAPIProtected[16];
    DWORD          align3;
    BYTE           NtOwfPassword[16]; // <-- 目标 NTLM Hash (16 字节)
    BYTE           LmOwfPassword[16];
    BYTE           ShaOwPassword[20];
};
```

**Patch 逻辑**：

```rust
// 1. 清除其它凭据类型标志
cred[off_isLmOwfPassword] = 0;
cred[off_isShaOwPassword] = 0;
cred[off_isDPAPIProtected] = 0;
if off_isIso != 0 { cred[off_isIso] = 0; }

// 2. 零填充 LM / SHA / DPAPI 字段
zero(&mut cred[off_LmOwfPassword], 16);
zero(&mut cred[off_ShaOwPassword], 20);
zero(&mut cred[off_DPAPIProtected], 16);

// 3. 设置 NTLM 有效位 + 写入攻击者 Hash
cred[off_isNtOwfPassword] = 1;
copy_nonoverlapping(attacker_ntlm.as_ptr(), &mut cred[off_NtOwfPassword], 16);

// 4. 重新加密 + WriteProcessMemory 回写
nt6_encrypt_mem(&cred, true)?;
WriteProcessMemory(h_lsass, credentials_ptr, &cred, cred.len(), null_mut())?;
```

> **关键点**：仅修改 `isNtOwfPassword=1` 并写入 16 字节 Hash，其余置零/禁用，模拟“仅拥有 NTLM Hash”的纯净状态。

---

## 纯 Rust 实现关键技术点

| 模块 | 说明 |
|------|------|
| `windows-rs` | 官方 Win32 binding，`include_bindings!` 宏按需生成定义，枚举类型化，RAII 尚在完善中 |
| `read_process_mem` / `write_process_mem` | 封装 `ReadProcessMemory` / `WriteProcessMemory`，统一错误处理 |
| `pattern_scan` | 在 `LSASRV.dll` 镜像中搜索字节模式，返回偏移 |
| `rip_relative_resolve` | 64 位 RIP 相对寻址自动解析 |
| `lsa_crypt` | 封装 `BCrypt*` 系列 API，自动选择 AES/3DES 并管理密钥句柄生命周期 |
| `struct_offset_of!` | 利用 `memoffset` crate 编译期计算字段偏移，避免硬编码 |

> **痛点**：`rust-analyzer` 对 `include_bindings!` 宏展开支持有限，导致跳转定义失效；期待 `windows-rs` 进一步完善 RAII（如 `HANDLE` 自动 `CloseHandle`）。

---

## 检测与对抗视角

| 防御层面 | 典型检测点 | 对抗/规避思路 |
|----------|------------|---------------|
| **进程访问** | `OpenProcess(PROCESS_VM_READ\|WRITE\|OPERATION, ..., lsass_pid)` | [[ppl-injection-createprocess-bof-fix]]：注入 PPL 进程规避内存扫描；[[ppldump-userland-ppl-bypass-evasion]]：利用 `DefineDosDevice`/`KnownDLLs` 绕过 PPL 转储 |
| **内存扫描** | Hunt-Sleeping-Beacons、BeaconHunter、pe-sieve、Moneta 检测 LSASS 非法读写 | [[memory-scanning-tools-evasion-techniques]]：FOLIAGE/Ekko/AceLdr/Inceptor 等 UDRL 方案 |
| **凭据完整性** | LSA Protect 加密、Credential Guard (VBS) | 需结合 [[windows-token-nerfing-pplguard-trusted-labels]] 中 Token Nerfing 与 PPLGuard 机制分析 |
| **命令行审计** | `CreateProcessWithLogonW` 启动可疑进程 | [[argument-spoofing-edr-evasion]]：分离 Image 与 CommandLine 欺骗 EDR |

> 红队工具链集成参考：[[cobalt-strike-4.7-bof-internals]]（BOF 落地替代管道输出）、[[inceptor-av-edr-evasion-framework]]（Shellcode 统一转换+混淆+绕过）、[[aceldr-technical-analysis]]（反射式加载器对比）。

---

## 交叉引用索引

- [[mimikatz-source-code-architecture-golden-ticket-audit]] — Mimikatz 模块调度架构与黄金票据生成源码解析
- [[ppl-injection-createprocess-bof-fix]] — PPL 进程注入与 `CreateProcess` `bInheritHandles` 绕过
- [[ppldump-userland-ppl-bypass-evasion]] — PPLDump 利用 `DefineDosDevice`/`KnownDLLs` 绕过 PPL 转储 LSASS
- [[windows-token-nerfing-pplguard-trusted-labels]] — Token Nerfing 攻击与 PPLGuard 缓解机制
- [[memory-scanning-tools-evasion-techniques]] — 主流内存扫描工具原理与 UDRL 规避实测
- [[cobalt-strike-4.7-bof-internals]] — Cobalt Strike 4.7 BOF 加载器内部实现与 PPL 注入案例
- [[inceptor-av-edr-evasion-framework]] — Inceptor 免杀框架完整工作流
- [[aceldr-technical-analysis]] — PE 不落地执行技术体系（RDI/sRDI/Donut/Process Hollowing 等）
- [[process-injection-tampering-techniques]] — 五大进程镂空/篡改技术原理对比
- [[argument-spoofing-edr-evasion]] — Argument Spoofing 对抗 EDR 进程创建监控
- [[rust-proc-macro-win32-dynamic-import]] — Rust 过程宏实现 Win32 API 动态导入与符号哈希
- [[pe-manual-mapping-loader-implementation]] — PE 手动映射加载器全流程实现（含 PEB 遍历、导入表修复、重定位）

---

## 结语

`sekurlsa::pth` 的核心在于 **“找到 LSASS 堆上的凭据缓存 → 解密 → 仅保留 NTLM Hash → 加密回写”**。整个链路的不确定性主要来自：

1. **内存签名的版本碎片化**（需持续维护 Pattern 库）
2. **LSA Protect 密钥结构的版本演进**（`KIWI_BCRYPT_KEY` → `KEY8` → `KEY81`）
3. **EDR 对 `OpenProcess(LSASS)` 与 `WriteProcessMemory` 的深度监控**

纯 Rust 复现的价值在于：**强类型消除偏移计算错误、编译期结构布局校验、无运行时依赖便于 Shellcode/BOF 化**，为红队武器化提供可审计、可维护的基础组件。

> **完整代码仓库**：<https://github.com/EddieIvan01/win32api-practice/tree/master/pth>  
> **原文来源**：微信公众号「0x00实验室」2023-04-16 发布

---

## 附录：关键数据结构速查

| 结构 | 关键字段 | 说明 |
|------|----------|------|
| `KIWI_MSV1_0_LIST_63` | `Flink/Blink`, `LocallyUniqueIdentifier`, `UserName`, `Domain`, `Credentials` | Logon Session 链表节点 |
| `KIWI_BCRYPT_HANDLE_KEY` | `tag("UUUR")`, `key` | 密钥句柄包装 |
| `KIWI_BCRYPT_KEY/KEY8/KEY81` | `tag("MSSK")`, `hardkey` | 算法上下文 |
| `KIWI_HARD_KEY` | `cbSecret`, `data[]` | 真实对称密钥 + IV |
| `MSV1_0_PRIMARY_CREDENTIAL` | `isNtOwfPassword`, `NtOwfPassword[16]` | 最终 Patch 目标 |

---

*页面维护者：数字知识库策展人*  
*最后更新：2025-01-20*  
*标签体系版本：v1.2*

## 来源

- [0x4d5a-202103-202209_14](../sources/0x4d5a-202103-202209_14.md)
