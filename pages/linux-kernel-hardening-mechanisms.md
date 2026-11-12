---
title: Linux 内核硬化机制全景
description: 系统梳理 Linux 内核主流防御机制，涵盖编译期硬化、内存保护、控制流完整性、硬件辅助防护、侧信道缓解及 Grsecurity/PaX
  核心特性
category: program-analysis
tags:
- Linux Kernel
- Hardening
- Security Mitigations
- Grsecurity
- PaX
- Memory Protection
- Control Flow Integrity
- Side-channel Mitigation
date: 2024-01-15
updated: '2026-11-12'
---

## 概述

Linux 内核安全防御体系庞大且持续演进。业界常用 `Linux Kernel Defence Map` 将防御技术分为八大类：主线防御、通用防御、主线不支持防御、Bug 检测、商用防御、漏洞利用技术、硬件防御、利用技术。本文聚焦**主线防御**、**硬件防御**与**商用/Grsecurity/PaX 移植特性**，按**防御目标**与**实现层级**重新组织，形成结构化知识页。

> 说明：文中提到的配置选项多为 `CONFIG_` 前缀的 Kconfig 符号；运行时参数多为内核命令行或 sysctl 节点。

---

## 编译期硬化

### 结构体布局随机化

| 机制 | 说明 |
|------|------|
| **RANDSTRUCT** | GCC 插件，编译期按随机种子打乱结构体字段顺序，增加漏洞利用中精准控制字段偏移的难度。 |
| **PAX_RANDSTRUCT** | PaX/Grsecurity 早期实现，思路一致。 |

### 熵增强

| 机制 | 说明 |
|------|------|
| **LATENT_ENTROPY** | GCC 插件，在标记 `__latent_entropy` 的函数中混入随机值到全局 `latent_entropy` 变量，启动早期补充熵池。 |

### 整数/尺寸溢出检测

| 机制 | 说明 |
|------|------|
| **PAX_SIZE_OVERFLOW** | GCC 插件，用 `double` 宽度保存 size 表达式计算结果并与实际分配大小比对，覆盖内存分配等关键路径。 |
| **FORTIFY_SOURCE** | 编译期/运行期检查 `memcpy`、`strcpy` 等缓冲区操作的目的缓冲区长度，检测溢出。 |
| **UBSAN_BOUNDS** | UBSan 选项，检测编译期已知数组长度的越界访问；不覆盖内存拷贝函数导致的溢出，需配合 `FORTIFY_SOURCE`。 |

### 只读化与常量化

| 机制 | 说明 |
|------|------|
| **__ro_after_init** | 内核初始化阶段可写、初始化完成后标记为只读的内存区域，解决 `const` 无法覆盖“初始化后只读”场景。 |
| **PAX_CONSTIFY_PLUGIN** | GCC 插件，将函数指针结构体标记为只读，缓解修改函数指针劫持控制流。 |

### 栈保护

| 机制 | 说明 |
|------|------|
| **STACKPROTECTOR** | 经典 Canary 机制，函数序言写入随机值，返回前校验；需 GCC ≥ 4.2 且栈帧 ≥ 8 字节。 |
| **PAX_RANDKSTACK** | 进程内核栈基址随机化，配合栈擦除（`pax_erase_kstack`）缓解信息泄漏与布局预测。 |
| **VMAP_STACK** | 使用 `vmalloc` 分配内核栈，自带 guard page，物理不连续减少碎片。 |
| **THREAD_INFO_IN_TASK** | 将 `thread_info` 嵌入 `task_struct`，避免栈溢出破坏 `thread_info` 导致检测失效。 |
| **GRKERNSEC_KSTACKOVERFLOW** | Grsecurity 栈溢出加固套件：`vmap` 与 `thread_info` 分离、双重错误 guard page 检测、指针完整性校验。 |
| **SCHED_STACK_END_CHECK** | `schedule()` 入口检查栈末尾魔数，发现损坏即触发 panic。 |
| **INIT_STACK_ALL_ZERO** | 新栈分配时全零初始化，消除未初始化栈变量泄漏。 |
| **STACKLEAK** | 系统调用/中断返回用户态时擦除内核栈内容；可与 `VMAP_STACK`、`THREAD_INFO_IN_TASK` 配合检测溢出。 |

---

## 内存保护与分配器硬化

### 用户空间拷贝加固

| 机制 | 说明 |
|------|------|
| **HARDENED_USERCOPY** | 在 `copy_from_user`/`copy_to_user` 中校验缓冲区边界，防止长度超限导致内核内存溢出；源自 `PAX_USERCOPY`。 |

### SLUB 分配器加固

| 机制 | 说明 |
|------|------|
| **slub_debug (Z/F/P)** | `Z` Red Zone 填充魔数检测越界；`F` free 时完整性校验；`P` 分配/释放填充 `0x5a`/`0x6b` 捕获未初始化与 UAF。 |
| **SLAB_FREELIST_HARDENED** | freelist 指针混淆（`freelist_ptr` 逆运算），使通用 freelist 攻击失效。 |
| **SLAB_FREELIST_RANDOM** | 新 slab 页 freelist 随机化，降低堆布局可预测性。 |
| **PAGE_POISONING** | 页释放后填充特征值，分配前校验，防御 UAF 与信息泄漏。 |
| **PAX_MEMORY_SANITIZE** | slab 对象释放时全擦除，配合 `SLAB_` 标志位决定范围。 |
| **init_on_free / init_on_alloc** | 页分配器与 SL[AU]B 返回/释放内存时零初始化，阻断信息泄漏与未初始化利用。 |
| **SHUFFLE_PAGE_ALLOCATOR** | 页分配器随机化，提高缓存利用率并打破页面分配确定性；可通过 `page_alloc.shuffle` 强制开启。 |
| **slab_nomerge** | 禁止相近大小 slab 合并，限制堆溢出波及面。 |

### 引用计数保护

| 机制 | 说明 |
|------|------|
| **REFCOUNT_FULL** | 引用计数操作中插入饱和检查，防止溢出变负导致过早释放触发 UAF。 |
| **PAX_REFCOUNT** | Grsecurity 同类实现。 |

### 结构体/指针泄漏缓解

| 机制 | 说明 |
|------|------|
| **PAX_MEMORY_STRUCTLEAK** | 编译期插桩，将即将拷贝到用户态的栈上局部变量零初始化。 |
| **STRUCTLEAK_BYREF_ALL** | 仅初始化被引用传递的栈变量，性能开销更小。 |

### BPF JIT 硬化

| 机制 | 说明 |
|------|------|
| **bpf_jit_harden** | 立即数拆分异或（`mov r10, imm; xor r10, key; mov eax, r10d`），缓解 JIT 喷射；`0/1/2` 分级策略。 |
| **GRKERNSEC_JIT_HARDEN** | Grsecurity 早期实现，思路一致。 |

---

## 控制流完整性 (CFI)

### 硬件辅助 CFI

| 架构 | 机制 | 说明 |
|------|------|------|
| ARM64 | **ARM64_PTR_AUTH** | 指针认证 (PAC)，对返回地址/函数指针签名验证，需 ARMv8.3+。 |
| ARM64 | **ARM64_BTI_KERNEL** | 分支目标识别 (BTI)，限制间接跳转目标，需 ARMv8.5+；配合 PAC 抗 JOP/ROP。 |
| x86 | **Intel CET** | `IBT` (间接分支跟踪) 防 JOP/COP + `SHSTK` (影子栈) 防 ROP；需硬件支持。 |

### 编译器/软件 CFI

| 机制 | 说明 |
|------|------|
| **PAX_RAP** | Grsecurity 核心 CFI：返回地址 `rbx ^ r12` 保护；间接调用/返回前白名单校验（嵌入魔数比对）。 |
| **Clang CFI** | 主线正在推进的精细粒度 CFI，基于控制流图白名单，性能开销可控。 |
| **SHADOW_CALL_STACK** | Clang 影子栈，单独内存区保存返回地址，防篡改；需知晓影子栈位置且可写才会失效。 |

---

## 硬件辅助内存访问控制

| 防护目标 | x86 | ARM | 说明 |
|----------|-----|-----|------|
| **禁止内核执行用户代码** | **SMEP** (CR4.SMEP) | **PXN** (ARMv7+) | 触发页错误；可通过修改控制寄存器绕过。 |
| **禁止内核访问用户数据** | **SMAP** (CR4.SMAP) | **PAN** (ARMv8.1+) | 需显式 `stac`/`clac` 或 `uaccess` 辅助宏临时开启。 |
| **ARM PAN 实现** | — | **CPU_SW_DOMAIN_PAN** / **ARM64_SW_TTBR0_PAN** | 前者用域切换，后者用 `TTBR0_EL1` 指向零页仿真。 |
| **用户模式指令防护** | **X86_INTEL_UMIP** | — | 禁止用户态执行 `SGDT/SLDT/SIDT/SMSW/STR`，泄露硬件状态。 |
| **内核/用户地址空间分离** | **PTI/KPTI** (pti=on) | **UNMAP_KERNEL_AT_EL0** (kpti=on) | 双页表隔离，缓解 Meltdown 侧信道；用户态页表剔除内核映射。 |
| **内核执行/写保护** | **STRICT_KERNEL_RWX** | **RODATA_FULL_DEFAULT_ENABLED** | `.text`/`.rodata` 只读，非代码段不可执行；模块同理 (`STRICT_MODULE_RWX`)。 |
| **PaX KERNEXEC** | 早期软件实现 NX | — | 页属性设置 (RO&NX)、模块 W^X、GCC 插件配合。 |
| **PaX UDEREF** | 分段/PCID/双页表 | — | 内核/用户页目录彻底分离，`WEAK`/`STRONG` 模式权衡性能。 |

---

## 侧信道与投机执行缓解

### 通用框架

| 参数 | 说明 |
|------|------|
| **mitigations=auto,nosmt** | `auto` 开启所有缓解；`nosmt` 关闭 SMT (超线程)。 |

### Spectre v1 (Bounds Check Bypass)

| 机制 | 说明 |
|------|------|
| **nospec barriers** | 内核 API `nospec_ptr(ptr, lo, hi)`、`array_index_nospec(idx, sz)` 在投机窗口内钳制指针/索引。 |

### Spectre v2 (Branch Target Injection)

| 参数/选项 | 说明 |
|-----------|------|
| **spectre_v2=on/off/auto** | `retpoline` 间接分支转换为 `call+pause` 序列；依赖编译器 `-mindirect-branch=thunk-extern` 与微码 (IBRS/IBPB)。 |
| **RETPOLINE** | `retpoline`/`retpoline,generic`/`retpoline,amd` 三种变体。 |

### Spectre v4 (Speculative Store Bypass)

| 架构 | 参数 | 说明 |
|------|------|------|
| x86 | **spec_store_bypass_disable=on/off/prctl/seccomp/auto** | 关闭 SSB 优化或进程级选择性关闭。 |
| ARM64 | **ssbd=force-on/force-off/kernel** | 控制 `SSBD` 位；`kernel` 仅内核开启并暴露 `prctl` 给用户态。 |

### Meltdown / L1TF / MDS 系列

| 漏洞 | x86 参数 | 核心缓解 |
|------|----------|----------|
| **Meltdown** | `pti=on` (KPTI) | 用户/内核页表隔离。 |
| **L1TF** | `l1tf=full,force` | VMENTER 前无条件 L1D flush + SMT 关闭。 |
| **MDS** | `mds=full,nosmt` | 切换到用户态清空 Store/Load/Fill Buffer + 关闭 SMT。 |

### 微码与编译器级缓解

| 机制 | 说明 |
|------|------|
| **MICROCODE** | Intel 微码补丁 (SRAM 存储)，修复硬件层面投机行为。 |
| **RESPECTRE** | Grsecurity GCC 插件，语义级重构消除投机侧信道，性能损耗 ~0.3%。 |
| **HARDEN_BRANCH_PREDICTOR** (ARM) | 清除分支预测器状态、限制预测逻辑。 |

---

## 信息隐藏与攻击面收缩

| 机制 | 说明 |
|------|------|
| **kptr_restrict** (0/1/2) | 控制 `/proc/kallsyms` 等接口的内核指针可见性。 |
| **GRKERNSEC_HIDESYM** | 限制模块信息与 `kallsyms` 访问需 `CAP_SYS_MODULE`。 |
| **SECURITY_DMESG_RESTRICT** / **GRKERNSEC_DMESG** | `dmesg` 仅 `CAP_SYS_ADMIN` 可读，防泄露堆地址等敏感信息。 |
| **DEFAULT_MMAP_MIN_ADDR=65536** | 提高 `mmap` 最低地址，阻断空指针解引用利用链。 |
| **unprivileged_userfaultfd=0** | 禁止非特权用户使用 `userfaultfd`，避免条件竞争利用。 |
| **LDISC_AUTOLOAD=not set** | 关闭 TTY 行规程自动加载，减少模块加载攻击面。 |
| **GRKERNSEC_MODHARDEN** | 限制非特权用户触发模块自动加载。 |
| **MODULE_SIG\*** | 强制模块签名验证 (SHA1/256/512)，防恶意模块注入。 |
| **SECURITY_LOADPIN** | LSM 钩子强制内核仅加载首次引用的同一文件 (模块/固件/镜像)，防替换。 |
| **STATIC_USERMODEHELPER** | 所有 `usermodehelper` 重定向至单一不可变二进制，首参指定真实程序。 |
| **LOCKDOWN_LSM** | LSM `locked_down` 钩子锁定内核：禁无签名模块、禁 `/dev/port` 等高危操作。 |

---

## 调试与完整性检查

| 选项 | 说明 |
|------|------|
| **DEBUG_WX** | 启动时扫描 `W+X` 映射并报警，仅检查一次。 |
| **DEBUG_LIST** | 链表操作额外校验。 |
| **DEBUG_SG** | Scatter-gather 表校验，捕获驱动初始化错误。 |
| **DEBUG_CREDENTIALS** | 凭证引用计数追踪，防越界引用。 |
| **DEBUG_NOTIFIERS** | 通知链注销合法性检查。 |
| **DEBUG_VIRTUAL** | 虚拟内存转换合法性校验。 |
| **BUG_ON_DATA_CORRUPTION** | 检测到内核数据结构损坏直接触发 BUG。 |

---

## Grsecurity/PaX 核心特性对照表

| PaX/Grsecurity 特性 | 主线对应/移植状态 | 备注 |
|---------------------|-------------------|------|
| `PAX_KERNEXEC` | `STRICT_KERNEL_RWX` / `STRICT_MODULE_RWX` | 内核 NX/RO 实现 |
| `PAX_UDEREF` | `PTI` + `SMAP`/`PAN` | 地址空间分离 |
| `PAX_USERCOPY` | `HARDENED_USERCOPY` | 拷贝边界校验 |
| `PAX_MEMORY_SANITIZE` | `PAGE_POISONING` / `init_on_free` | 释放内存擦除 |
| `PAX_MEMORY_STACKLEAK` | `STACKLEAK` | 栈擦除+溢出检测 |
| `PAX_REFCOUNT` | `REFCOUNT_FULL` | 引用计数饱和保护 |
| `PAX_RANDKSTACK` | 部分 (栈随机化) | 主线无完整对应 |
| `PAX_RAP` | 无直接对应 | 独创软件 CFI 方案 |
| `PAX_CONSTIFY_PLUGIN` | 无直接对应 | 函数指针只读化 |
| `PAX_SIZE_OVERFLOW` | `FORTIFY_SOURCE` + `UBSAN_BOUNDS` | 尺寸溢出检测 |
| `GRKERNSEC_KSTACKOVERFLOW` | `VMAP_STACK` + `THREAD_INFO_IN_TASK` + `SCHED_STACK_END_CHECK` | 栈溢出综合加固 |
| `GRKERNSEC_JIT_HARDEN` | `bpf_jit_harden` | BPF JIT 立即数混淆 |
| `GRKERNSEC_HIDESYM` | `kptr_restrict` + `modules_disabled` | 符号隐藏 |
| `GRKERNSEC_DMESG` | `SECURITY_DMESG_RESTRICT` | 日志访问控制 |
| `GRKERNSEC_MODHARDEN` | `modules_disabled` / `module_sig_enforce` | 模块加载限制 |
| `RESPECTRE` | 无主线对应 | 编译器级 Spectre 缓解 |

---

## 启动参数速查

| 参数 | 作用 |
|------|------|
| `pti=on` / `nopti` | 强制开启/关闭 KPTI |
| `kpti=on` (ARM) | 同 PTI |
| `spectre_v2=on/off/auto` | Spectre v2 缓解策略 |
| `spec_store_bypass_disable=on/prctl/seccomp/auto` | SSB 缓解 |
| `ssbd=force-on/force-off/kernel` (ARM) | SSBD 控制 |
| `mds=full,nosmt` | MDS 缓解 + 关 SMT |
| `l1tf=full,force` | L1TF 缓解 + 关 SMT |
| `mitigations=auto,nosmt` | 一键开启所有缓解并关 SMT |
| `page_alloc.shuffle=1` | 强制页分配器随机化 |
| `slub_debug=ZFP` | 开启 SLUB 红区/完整性/毒化 |
| `rodata=off` (ARM) | 运行时关闭 `RODATA_FULL_DEFAULT_ENABLED` |
| `lockdown=confidentiality/integrity` | LSM Lockdown 模式 |

---

## 总结与演进趋势

1. **纵深防御分层**：编译期 (随机化/插桩) → 运行时 (Canary/边界/只读) → 硬件 (SMEP/SMAP/PAC/BTI/CET) → 微架构 (KPTI/Retpoline/Flush) → 策略 (Lockdown/模块签名)。
2. **Grsecurity/PaX 为源头创新**：主线内核大量硬化特性源自 Grsecurity/PaX 移植或受其启发，两者仍在前沿探索 (RAP、RESPECTRE、STRONG UDEREF 等)。
3. **硬件与编译器协同成主流**：PAC/BTI/CET、Shadow Call Stack、Clang CFI 等将安全下沉至 ISA 与编译器，降低软件开销。
4. **侧信道缓解常态化**：`mitigations=` 一键参数与微码更新成为标配运维动作。
5. **攻击面收缩持续推进**：`kptr_restrict`、`dmesg_restrict`、`unprivileged_userfaultfd=0`、`LOCKDOWN_LSM` 等最小权限原则落地。

---

## 相关知识页

- 编译器安全硬化技术对比 (待建立)
- 现代 CPU 投机执行漏洞与缓解原理 (待建立)
- Linux 内核漏洞利用技术演进 (待建立)
- Grsecurity/PaX 补丁集深度解析 (待建立)

> 本页基于 [安全客文章《Linux 内核安全机制总结》](http://mp.weixin.qq.com/s?__biz=MzU5MjMzODY0NQ==&mid=2247484511&idx=1&sn=db1a9d4f831b8d97baf8f7d5009b3304) 与内核官方文档、LWN、Grsecurity 文档整理而成，旨在提供结构化检索与交叉引用。

## 来源

- [0th3rs安全团队-201911-202204_005](../sources/0th3rs安全团队-201911-202204_005.md)
