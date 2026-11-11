version="1.0" encoding="utf-8"?

# AWD中二进制补丁的常见手工打法

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247484249&idx=1&sn=ff86c9824f3fd9abaf7cf19210bde604&chksm=fc30c403cb474d151eb8297ce4b09a925db2c42cc7b4b5c2fc72717014866ffe295dd1a5ed14&scene=126&sessionid=1681400517#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247484249&idx=1&sn=ff86c9824f3fd9abaf7cf19210bde604&chksm=fc30c403cb474d151eb8297ce4b09a925db2c42cc7b4b5c2fc72717014866ffe295dd1a5ed14&scene=126&sessionid=1681400517#rd)

## **背景介绍**

近年来CTF攻防赛（AWD）趋向于攻防对等，即主办方会想办法让漏洞的修复变难，以此来增强比赛的趣味性（想象一下，如果漏洞修复很简单，大家上来一阵修复、通防，谁还能得分呢）。有时候，打补丁是如此的重要，以至于只要能打好补丁，就可以获取很好的成绩了。

让漏洞修复变难的办法很多，例如复杂的代码逻辑让漏洞发现时间变长、逐渐加强的checker等。复杂代码逻辑的作用是有限的，因为如果搞的太复杂，以至于在比赛时间内没人能写好exp，那题目就没有效果了。所以，变态的checker才是常用的解决方案。

为了对抗通防，目前的checker在静态阶段基本上都会进行hexdiff，例如要求打补丁之后的ELF和原始ELF相差不能超过100字节、补丁不能修改某些关键的寄存器等等。动态阶段的测试用例也会比较严格。因而，稳定可靠的二进制补丁还是要靠手工，以便于精准控制过checker。

  

## **基础知识**

提前了解以下几个基础知识，对打补丁很有帮助

*   **易失、非易失寄存器**
    

| Register || 状态 || 含义 |
| --- | --- | --- |
| RAX || 易失的 || 返回值寄存器 |
| --- | --- | --- |
| RCX || 易失的 || 第一个整型参数 |
| RDX || 易失的 || 第二个整型参数 |
| R8 || 易失的 || 第三个整型参数 |
| R9 || 易失的 || 第四个整型参数 |
| R10:R11 || 易失的 || 必须根据需要由调用方保留；在 syscall/sysret 指令中使用 |
| R12:R15 || 非易失的 || 必须由被调用方保留 |
| RDI || 非易失的 || 必须由被调用方保留 |
| RSI || 非易失的 || 必须由被调用方保留 |
| RBX || 非易失的 || 必须由被调用方保留 |
| RBP || 非易失的 || 可用作帧指针；必须由被调用方保留 |
| RSP || 非易失的 || 堆栈指针 |
| XMM0 || 易失的 || 第一个 FP 参数 |
| XMM1 || 易失的 || 第二个 FP 参数 |
| XMM2 || 易失的 || 第三个 FP 参数 |
| XMM3 || 易失的 || 第四个 FP 参数 |
| XMM4:XMM5 || 易失的 || 必须根据需要由调用方保留 |
| XMM6:XMM15 || 非易失的 || 必须根据需要由被调用方保留 |

打补丁时要注意，如果需要使用寄存器的话，尽量使用易失寄存器，因为非易失寄存器可能在函数上层有汇编依赖于其值不变。

*   **关键指令理解**
    

call xxx : push rip; jmp xxx;

leave: mov rsp,rbp; pop rbp;

ret: pop rip; jmp rip;

*   **补丁中常用汇编指令**
    

\[比较\]  
cmp xx  
ja jb ：无符号判断  
jg jl  ：有符号判断  
jz jnz  / je jne  
jp jnp ：偶判断

\[移位\]  
SHL(Shift Left):  逻辑左移  
SHR(Shift Right):  逻辑右移  
SAL(Shift Arithmetic Left):  算术左移  
SAR(Shift Arithmetic Right): 算术右移

\[条件指令\]  
cmov\[a/b/g/l/ae/be/ge/le\] xxx, xxx

\[strlen\]  
(to find the length of the string whose starting address is in EDI：)

*   
*   
*   
*   
*   
*   
*   

```
sub  ecx, ecxsub  al, alnot  ecxcldrepne  scasbnot  ecxdec  ecx
```

ecx值即为strlen的值。

*   **eh\_frame**
    

当我们需要插入汇编代码时，往往会使用到这个空闲段，跳进去执行插入代码再跳回来。

*   **替换、插入**
    

有时候我们仅仅需要修改、替换指令，多余的位置nop即可，有时候复杂的patch逻辑就需要插入代码来实现；这两种模式我们称为替换模式和插入模式。

*   **keypatch**
    

IDA超好用的patch插件，我们只需要在里面写汇编，跳转偏移（机器码）之类的计算该插件会自动帮我们完成。

  

## **几种常见patch的打法**

### 1\. printf格式化串漏洞

x64补丁写法：

![](../Images/5fabfc9b4b34f402933243c2f4b78869.png)

printf前插入（加入%s参数）

*   
*   
*   

```
push 0x00007325mov rsi, rdilea rdi, [rsp]
```

printf后插入(栈平衡)

*   

```

```

x86补丁写法：

![](../Images/088eccf76371310dda86fd78a07c1920.png)

762处替换为：

*   

```

```

769处插入：

*   
*   
*   
*   
*   

```
pop ecx;push 0x00007325;push ecx;lea eax, [esp+4];push eax;
```

注：如果plt中有puts，可以尝试用puts来修复，不过强checker下可能会校验不通过。

### 2\. snprintf格式化串漏洞

![](../Images/8e7e39845baad52ea18a0dbde92344d0.png)

b60处插入：

*   
*   
*   
*   
*   

```
mov ecx, 0x00007325;mov [esp+0x10], ecx;lea ecx, [esp+0x10];mov [esp+0xc], eax;mov [esp+0x8], ecx;
```

### 3\. off by null

![](../Images/644860583f7a7cba05edffd28b2ce24c.png)

![](../Images/5558dcbc1988194ce91b395e756dd741.png)

f11处插入：

*   
*   
*   
*   

```
mov rcx, [rbp-0x20];sub rcx, 1;cmp rdx, rcx;cmova rdx, rcx;
```

修复后效果：

![](../Images/72f15890836f78f614cd2d007a2c6323.png)

### 4\. 栈溢出通用patch：添加栈cookie

有时候溢出代码异常复杂，只能试出offset和溢出缓冲区（利用FORWORD-2020 blacklist），这时候只能使用通用的patch方法，放大栈不一定彻底，加cookie更彻底，且可以当作通用栈溢出patch使用。

![](../Images/7869f34827da90544064331391b0f1de.png)

db8处替换为：

*   

```

```

dbc处替换为:

*   

```

```

dc0处插入:

*   
*   

```
mov rcx, 0x4a584e424a584e00;//cookie值可自定义mov [rbp - 0x8],  rcx;
```

dcd处插入：

*   
*   
*   
*   
*   
*   

```
mov rcx, 0x4a584e424a584e00;cmp rcx, [rbp - 0x8];jz 0x401dd2;mov rdi, 1;mov rax, 60;syscall;
```

### 5\. gets溢出

nop掉gets调用，下方插入read系统调用实现读取。

### 6\. double free

![](../Images/df208703b5706e56915b45519ce42d23.png)

![](../Images/3c2412b4a89f72170118797079e44c19.png)

在1处插入指针非空的判断：

*   
*   

```
cmp rax, 0;jz 0x400b9e;
```

在2处插入指针置空逻辑:

*   
*   
*   
*   
*   
*   

```
mov eax, [rbp-4];cdqe;shl rax, 4;mov rdx, rax;lea rax, [0x6020e0];mov dword ptr [rdx+rax], 0;
```

### 7\. 堆溢出通用patch：索引堆头size字段

（houseoforange）

![](../Images/99cb9ee449b1c19ccd0354687b414be7.png)

![](../Images/9971abfce4c8341ce7b25f162beb8582.png)

上述位置插入以下代码：

*   
*   
*   
*   
*   
*   
*   
*   
*   

```
lea rax, [0x203068];mov rax, [rax];mov rax, [rax+8];sub rax, 8;mov rcx, [rax];sub rcx, 0x8;cmp [rbp-0x18], rcx;jbe 0x10fe;mov [rbp-0x18], rcx;
```

patch效果：

![](../Images/0a022e0724630020d80fe5d45abe4c7b.png)