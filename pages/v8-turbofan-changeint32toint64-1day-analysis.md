---
title: V8 TurboFan ChangeInt32ToInt64 符号扩展逻辑缺陷导致的 1-day 漏洞分析
description: 深度分析 V8 TurboFan JIT 编译器中 ChangeInt32ToInt64 节点在处理无符号/有符号整数扩展时的逻辑缺陷，覆盖漏洞成因、优化阶段触发条件（EarlyOptimization
  与 LoadElimination）、Exploit 构造链（Array.shift Fast Path 与长度字段篡改）及最终任意代码执行路径。
category: program-analysis
tags:
- V8
- TurboFan
- JIT Compilation
- Vulnerability Analysis
- 1-day
- Type Confusion
- Integer Overflow
- Browser Exploitation
- ChangeInt32ToInt64
- EarlyOptimization
- LoadElimination
date: 2024-12-19
updated: '2026-11-12'
---

## 漏洞概述

本漏洞为 V8 TurboFan JIT 编译器中的类型混淆漏洞，编号为 **CVE-2021-21224**（对应修复提交 [02f84c745fc0cae5927a66dc4a3e81334e8f60a6](https://chromium.googlesource.com/v8/v8/+/02f84c745fc0cae5927a66dc4a3e81334e8f60a6)）。核心成因在于 `ChangeInt32ToInt64` 节点在降级为机器码时，未能正确区分输入值的符号性，导致无符号 32 位整数被零扩展而非符号扩展为 64 位整数，进而引发后续数组长度计算错误与越界读写。

漏洞触发需满足两个关键优化阶段的联动：
1. **EarlyOptimization 阶段**：`Word32Xor` 节点因右操作数为常量 0 被消除，导致原本带有符号标记的值变为无符号 `LoadTypedElement` 直接输入。
2. **LoadElimination 阶段**：`Array.prototype.shift` 的 Fast Path 优化中，基于推测的常量长度 0 消除循环逻辑，直接将长度字段写为 -1（0xffffffff），构造出超大数组实现越界访问。

## 根因分析：ChangeInt32ToInt64 符号扩展选择错误

### 正常语义与预期行为

- `ChangeInt32ToInt64` 节点用于将 32 位整数扩展为 64 位整数。
- **有符号输入** → 应生成 `Movsxlq`（符号扩展，保留符号位）。
- **无符号输入** → 应生成 `Movl`（零扩展，高 32 位清零）。

### 漏洞代码路径

修复前的指令选择逻辑仅依据节点的 `Signed` 标志决定指令：

```cpp
// 伪代码：简化的指令选择逻辑
if (node->IsSigned()) {
    return kX64Movsxlq;  // 符号扩展
} else {
    return kX64Movl;     // 零扩展
}
```

### 优化阶段导致的标志丢失

1. **源码层面**：`_arr[0] ^ 0` 中 `_arr` 为 `Uint32Array`，元素为无符号 32 位整数。`Word32Xor` 与常量 0 异或，按语义结果仍为无符号，但 TurboFan 早期会为异或结果标记 **有符号**（因通用整数运算默认有符号）。
2. **EarlyOptimization**：`SimplifiedOperatorReducer` 识别 `Word32Xor(x, 0)` 可化简为 `x`，直接用 `LoadTypedElement` 替换异或节点。
3. **关键缺陷**：替换后，`ChangeInt32ToInt64` 的输入变为 **无符号的 `LoadTypedElement`**，但节点自身的 `Signed` 标志 **未同步更新**，仍保留为有符号。
4. **指令选择**：后端仍按有符号处理，本应选 `Movsxlq`，实则输入为无符号大值（如 `0x80000000`），若选 `Movl` 零扩展得 `0x0000000080000000`，后续作为数组长度参数导致逻辑偏差。

> 修复补丁显式在指令选择前补充符号性推断，确保零扩展/符号扩展与运行时实际值类型一致。

## 利用链构造：从类型混淆到任意读写

### 第一阶段：构造长度异常的数组

```javascript
function trigger() {
    let _arr = new Uint32Array([0x80000000, 0]);  // 无符号大值
    let cor = new Array(0x1000).fill(1.1);        // 目标数组
    let x = _arr[0] ^ 0;                          // JIT 后触发零扩展，x = 0x80000000
    let arr = new Array(x);                       // 期望长度 0x80000000，实得长度 1
    arr.shift();                                  // 触发 Fast Path 优化，长度变 -1
    return arr;                                   // 返回 length = 0xffffffff 的数组
}
```

- `x` 经零扩展为 `0x0000000080000000`，传入 `Array` 构造函数，V8 截取低 32 位 → 长度为 1。
- `arr.shift()` 进入 `JSCallReducer::ReduceArrayPrototypeShift`，因长度 < `kMaxCopyElements (100)` 走 **Fast Path**。
- **LoadElimination**：TurboFan 推测数组长度为常量 0，循环体被消除，仅保留 `length -= 1` 写入，实际写入 `0xffffffff`。

### 第二阶段：越界读写原语构建

```javascript
let victim = trigger();          // length = 0xffffffff
let float_arr = new Float64Array(0x100);  // 相邻分配
victim[0x1000] = 0x41414141;    // 越界写覆盖 float_arr 的 length/map 等元数据
```

- 利用 `victim` 的超大长度越界写相邻堆对象 `float_arr` 的元数据（如 `length`、`backing_store` 指针）。
- 篡改 `float_arr.length` 为巨大值，或修改 `backing_store` 指向任意地址，获得 **任意地址读写原语**。

### 第三阶段：WASM RWX 内存植入 Shellcode

```javascript
let wasm_code = new Uint8Array([...]);  // WASM 模块二进制
let module = new WebAssembly.Module(wasm_code);
let instance = new WebAssembly.Instance(module);
let func = instance.exports.func;       // 可执行内存页
// 任意写将 Shellcode 写入 func 对应的 RWX 页面
// 调用 func() 触发代码执行
```

- V8 为 WASM 实例分配 **RWX 页面**（绕过 DEP）。
- 利用任意写原语将 Shellcode 写入该页面，调用导出函数即实现 **任意代码执行**。

## 关键优化阶段详解

### EarlyOptimization（简化算子归约）

- **位置**：`SimplifiedOperatorReducer::ReduceWord32Xor`
- **行为**：匹配 `Word32Xor(x, 0)` → 替换为 `x`
- **副作用**：丢弃了原节点的类型/符号信息，直接透传底层 `LoadTypedElement` 的无符号类型。

### LoadElimination（冗余加载消除）

- **位置**：`LoadElimination::ReduceShiftElements` / `JSCallReducer::ReduceArrayPrototypeShift`
- **行为**：基于 `RangeAnalysis` 推测数组长度为常量 0，判定循环不执行，仅保留长度递减存储。
- **结果**：`length = 0 - 1 = -1 (0xffffffff)` 持久化到堆对象。

## 修复方案对比

| 维度 | 修复前 | 修复后 (02f84c7) |
|------|--------|------------------|
| 指令选择依据 | 仅读节点 `Signed` 标志 | 结合输入值实际类型（`Word32`/`Word32Signed`）动态判断 |
| 零扩展指令 | `kX64Movl` | 显式校验：输入为无符号时选 `Movl`，有符号时选 `Movsxlq` |
| 防御深度 | 单一标志位 | 类型系统与指令选择联动，EarlyOptimization 后自动修正标志 |

## 关联技术专题

- [[google-ctf-2021-full-chain-v8-exploitation]] — 另一 V8 全链利用案例，涉及 `TypedArray.set` 越界写、指针压缩下的任意读写构造、MojoJS 沙箱逃逸，可对比不同漏洞类型的利用策略差异。
- V8 指针压缩与堆布局（建议新建页面） — 理解 `Array`/`TypedArray` 内存排列、Map/Elements/Properties 分离、压缩指针解引用机制，是稳定利用的基础。
- TurboFan IR 与优化管线（建议新建页面） — 系统梳理 `Graph`、`Node`、`Operator`、各 Phase（Typer、EarlyOptimization、LoadElimination、InstructionSelection）交互，定位类型混淆根因的通用方法论。

## 检测与缓解建议

1. **Fuzzing 方向**：针对 `ChangeInt32ToInt64`、`ChangeUint32ToUint64` 等类型转换节点，构造符号性不一致的输入组合（如 `Uint32Array` 元素经位运算后转换）。
2. **静态分析**：检查指令选择逻辑是否在所有类型转换节点上统一引入“输入类型→扩展模式”映射表，而非依赖单一标志位。
3. **运行时强化**：在 `Array.prototype.shift` 等内置 Fast Path 中添加长度一致性校验（如 `DCHECK_LE(length, kMaxSafeLength)`），防止优化消除导致的元数据损坏。
4. **版本管理**：确保 Chrome 稳定分支及时合并 V8 安全补丁，缩短 1-day 窗口期。

## 时间线

| 日期 | 事件 |
|------|------|
| 2021-03-?? | 漏洞被发现并私下报告 / 攻击者利用 |
| 2021-03-23 | 修复提交 `02f84c745fc0cae5927a66dc4a3e81334e8f60a6` 进入 V8 主分支 |
| 2021-04-?? | Chrome 稳定版同步修复版本 V8（~V8 9.0.257） |
| 2021-05-?? | 公开 Exploit 样本出现（Twitter / GitHub `r4j0x00/exploits`） |

## 参考资料

1. V8 修复提交：https://chromium.googlesource.com/v8/v8/+/02f84c745fc0cae5927a66dc4a3e81334e8f60a6
2. 公开 Exploit 仓库：https://github.com/r4j0x00/exploits/tree/master/chrome-0day
3. TurboFan 源码：`src/compiler/simplified-operator-reducer.cc`、`src/compiler/load-elimination.cc`、`src/compiler/js-call-reducer.cc`

## 来源

- [0th3rs安全团队-201911-202204_030](../sources/0th3rs安全团队-201911-202204_030.md)
