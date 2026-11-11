version="1.0" encoding="utf-8"?

# 深度揭密高通4/5G移动基带消息系统和状态机

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzIxMjY0NjA2Mw==&mid=2247483706&idx=1&sn=ac274ff6efbc7cb173c841d29a08561b&chksm=9743a0faa03429ec0cf46a309f896532974d38f47f7da1a5f07ea71e714727ea7b0ac8e8b02c&scene=27#wechat\_redirect](http://mp.weixin.qq.com/s?__biz=MzIxMjY0NjA2Mw==&mid=2247483706&idx=1&sn=ac274ff6efbc7cb173c841d29a08561b&chksm=9743a0faa03429ec0cf46a309f896532974d38f47f7da1a5f07ea71e714727ea7b0ac8e8b02c&scene=27#wechat_redirect)

## 背景

MarkDown格式可以直接github上查看

https://github.com/vessial/baseband/blob/master/Qualcomm\_BaseBand\_Messaging\_and\_State\_Machine.md

本技术分析文章通过对高通的4/5G移动基带系统进行深入逆向工程提示其内部消息通信机制以及核心架构设计逻辑，本文的研究基于高通的4G基带MDM9707以及5G基带模块sdx55的固件之上分析完成，高通基带系统现在都是基于高通主流的hexagon DSP指令架构来实现，该架构非常适合应用于音视频编解码，计算机视觉等，软件无线电等应用中的浮点和向量计算，在高通骁龙处理器的子系统中大量使用，大多应用于手机，汽车，可穿戴设备以及移动通信设备中，Hexagon DSP相关信息可以从这里获取，运行在Hexagon DSP芯片上的操作系统QuRT是由高通设计的实时操作系统，高通基带系统所有的上层业务将会运行在该操作系统之上，阅读该技术分析文章之前，假定你已经对操作系统的原理有所了解，例如CPU调度，IPC(进程间通信)，以及基本的数据队列enqueue/dequeue的操作。  

## 消息机制简介

一个系统里面运行着不同的任务，不同任务在不同的运行状态在处理相应的业务逻辑时可能需要与其它任务交换数据或者同步信息，这里面就需要操作系统的底层IPC机制来完成了，3GPP组织定义了不同移动通信技术从物理层/链路层/逻辑处理层等各种标准，例如（5GNR/4GLTE/3G WCDMA/TD-SCDMA/CDMA2000/2G /GSM等通信技术），这些技术标准在基带系统里面实现会被划分成不同的任务来维护不同的状态，处理不同的消息信令，以及维护不同通信技术的切换等操作，比如现在的大部分智能手机基带系统基本上都支持2/3/4G通信相关的技术，这些基带系统根据移动运营商支持的移动通信技术和国家区域支持的标准的不同会使用相应的移动通信技术，比如中国在3G时代中国移动使用的TD-SCDMA，而中国联通使用的是WCDMA技术，为了保证移动设备的一些基本功能的可用性（语音通信和sms短信息），比如某些地方部署了4G基站，你可以在那里使用4G LTE的（Voice-over-IP/SMS-over-IP）通信技术，在一些偏远的地区可能只部署了2G基站，这时基带系统根据环境切换到GSM的协议栈，这些功能的维护与切换从基带系统层面来讲都需要系统消息机制来配合完成。

高通基带系统的消息机制建立在运行的实时操作系统QuRT之上，之前我有一篇文章有简单介绍过底层IPC机制，今天我将详细介绍上层业务逻辑相关的消息传递机制与数据结构。我们把运行在基带系统上的业务逻辑实体的最小单位定义为线程（thread），根据线程生命周期的不同分为以下两大类：

*   短生命周期线程
    

*   驱动/任务初始化线程（Driver initiator/Services Launcher)
    
*   中断服务例程（IST)
    

*   长生命周期线程
    

*   阻塞型消息接受线程
    

![](../Images/ffc64cd227b174f08d6cb65227443264.png)

消息通信底层API封装简介：

```


```
//信号发送
```

```
int rex\_send\_sigs(utcb \*dst\_task\_obj,unsigned int signal\_id);
```

```
//第一个参数为向目标任务发送消息的结构定义，第二个参数为要发送的信号id
```

```
int rex\_wait\_sigs(unsigned int recv\_sigs\_masks);
```

```
//第一个参数为可以允许接受信号id的掩码，每个任务最多可以设置可接受信号id个数为32个，每个任务可以接受多个信号id时，通过信号id的或操作来得到该任务可以接受信号的掩码，返回值为接受到的信号id
```

```

```

```
//如果是带数据的信号发送，封装底层API，类似如下
```

```
int send\_sigs\_with\_dat(utcb \*dst\_task\_obj,unsigned int signal\_id,data\_queue \*send\_data\_queue);
```

```
int recv\_sigs\_with\_dat(unsigned int recv\_sigs\_masks,data\_queue \*recv\_data\_queue);
```


```

而根据任务线程的业务功能的不同划分成以下几大类：

*   系统功能任务
    
*   通信技术协议栈分层任务
    

*   GSM/WCDMA/TDSCDMA/LTE L1/L2/L3相关的协议栈的任务等
    

*   上层应用任务
    

*   IMS volte/ecall/数据服务/包服务等
    

*   外设相关的任务
    

*   UIM/SIO/A2等
    

我在这里记录了高通MDM9607基带系统一次实时运行的任务快照列表。

## 高通基带系统消息机制

### 消息通信核心架构设计逻辑

*   兼容性
    

*   在新的基带芯片上面开发新的移动通信技术单元的同时，保证老的功能模块能够正常使用，例如在开发5G功能的同时，以往的4G/3G/2G功能都能够正常使用和切换。
    

*   可扩展性
    

*   在已有的功能模块上增加新的功能，具备灵活的扩展性，而不需要作太大的软件和硬件改动。
    

*   低耦合性
    

*   新增的功能模块与已有系统上功能模块的耦合度低，接口少，减少引入问题的接口点和测试成本。
    

基于以上的设计理念，高通设计一套灵活的消息通信系统，一直到现在5GNR的基带系统也在用，接下来我将详细介绍该消息系统的架构，相关的算法和数据结构。

### 消息通信架构

为了区分不同任务所接受到的消息以及任务所能处理相应消息的原语操作权限，通过接受到的消息来区分消息来源以及接受到相应消息后的相应的处理动作，高通的消息系统引入了任务消息接受体（msgr\_client）和UMID（Unique Message ID）的机制，任务消息接受体由相应的任务创建生成，并通过初始注册可接受消息UMID来设置任务相应原语操作的权限，每个任务可以创建一个或者多个msgr\_client，每一个UMID消息也可以注册给多个msgr\_client，每一个UMID消息标示着一次相应的原语操作，在MDM9607里面定义的UMID数量多达1万多个，而在最新高通的5G基带里面可使用的UMID高达2万多，每个UMID背后都对应着相应的原语操作，UMID的值与相应的命名规则如下。

#### UMID由32位组成，结构如下表

| Name || offset and length || Comment |
| --- | --- | --- |
| tech\_id || 24~31 8bits || eg, LTE->0x04, IMS->0x15, MDM9607 0x1b, SDX55 0x20 |
| --- | --- | --- |
| mod\_id || 16~23 8bits || eg, 0xd -> RRC 0xf -> MAC 0x11-> RLC DL |
| type\_id || 8~15 8bits || type <= 0x09) || (type >= 0x11 && type <= 0x17,totally 0x11 type\_ids |
| op\_type\_id || 4~8 4bits || Op entity ,eg IRAT\_FROM\_LTE\_TO\_G |
| op\_id || 0~3 4bits || Opcode seq, eg abort/search/startup/deinit/init/cfg etc |

注：if type\_id>9 ,type\_id=type\_id-6offset bit 8~15 8bits type\_id list

| Type\_name || value || Comment |
| --- | --- | --- |
| CMD || 1 || Command primitive |
| --- | --- | --- |
| REQ || 2 || request |
| RSP || 3 || response |
| IND || 4 || indication |
| DLM || 7 || downlink message |
| CNF || 8 || confirm |
| TMR || 9 || timer |
| REQI || 0x12 || request Internal |
| RSPI || 0x13 || Response internal |
| INDI || 0x14 || indication internal |
| CNFI || 0x15 || confirm internal |
| TMRI || 0x16 || timer internal |

举个例子UMID 0x40D120E 对应的描述原语是LTE\_RRC\_IRAT\_FROM\_LTE\_TO\_G\_RESEL\_REQI，拆分结果如下:

| name || value |
| --- | --- |
| LTE || 0x04 |
| --- | --- |
| RRC || 0x0d |
| REQI || 0x12 |
| RESEL || 0x0 |
| IRAT\_FROM\_LTE\_TO\_G || 0x0e |

注：这种UMID值的解析方法在某些定义里面并不适用，比如LTE\_ML1\_DLM\_TST\_SKIP\_RACH\_REQ的值为6，就没法用上面的方法解析，有些值并不严格遵循这种解析算法，可能是由于历史原因，定义UMID值的规则不一样。

基带系统把任务标示为多个不同的技术大类，来标示和模块化相应的子功能，以MDM9607为例：

| tech\_id || Tech\_name |
| --- | --- |
| 0 || MCS(Modem Common Service) |
| --- | --- |
| 2 || MM\_CM(0x201) UI(0x20a) (Unnumbered Information) MM\_DOM(0x202),MM\_MMOC(0x251) |
| 4 || LTE |
| 5 || FTM |
| 6 || rfa\_tech （0x600 rf\_fwrsp,0x603 rfgsm, 0x604 rf\_1x ,0x601 0x605 rf\_hdr ,0x606 rfgsm\_ftm,0x607 rf\_lte,0x608 rf\_lte\_ftm,0x60b rf\_qmi, 0x60c rf\_meas,0x40f/0x1a04 rf\_lte ,0x120f rf\_tdscdma） |
| 7 || cdma |
| 8 || hdr |
| 9 || gsm |
| 0x0a || location(gps/gnss) |
| 0x0b || wcdma |
| 0x0c || ds(data service) |
| 0x0d || 1x(csfb) |
| 0x0f || nas(0xf19 mm, 0xf1c esm) |
| 0x10 || gstk(Generic SIM Application Toolkit) |
| 0x12 || tdscdma |
| 0x13 || wms |
| 0x15 || ims |
| 0x16 || qmi |
| 0x17 || ecall 0x1701 ecall\_app ,0x1702 ecall\_ivs |
| 0x18 || policyman |
| 0x1a || rflm |

#### 模块ID

下图是MDM9607 LTE的部分子模块ID的对应关系

| tech\_id+mod\_id || name |
| --- | --- |
| 0x401 || ML1 MGR |
| --- | --- |
| 0x407 || LL1\_SRCH |
| 0x408 || LL1\_DL |
| 0x409 || LL1\_UL |
| 0x40a || LL1\_SYS |
| 0x40b || LL1\_Async |
| 0x40d || RRC |
| 0x40f || MAC |
| 0x411 || RLC DL |
| 0x412 || RLC UL |
| 0x413 || PDCP DL |
| 0x414 || PDCP UL |
| 0x41b || ML1\_GM |
| 0x41e || SW.app |
| 0x420 || ML1\_GM\_SCHDLR |
| 0x427 || TLB(Test Loop ) |
| 0x42b || ML1\_GM\_Sleep |
| 0x434 || ML1\_AFC |
| 0x43b || PDCP offload |
| 0x43e || ML1 offload |
| 0x43f || ML1 Co-existence |
| 0x441 || ML1 GM MSMGR |
| 0x442 || PDCPCOMP |
| 0x445 || ML1 SM FSCAN |

关键消息发送API:

```


```
msgr\_send(umsg \*buf,uint32 buf\_size);
```

```
struct umsg{
```

```
       struct msgr\_hdr\_struct\_type{ 
```

```
                uint32  dest\_umid;  //offset 0      ，要发送的UMID号
```

```
                uint16  src\_tech\_mod\_id; //offset 4，发送源tech\_mod\_id的标识
```

```
                uint8    num\_attach;// offset 7
```

```
                uint8    tail\_flag ;// offset 8 ，头部结尾标志0x7f
```

```
                uint8    inst\_id;// offset 9，
```

```
    }
```

```
         uint8 send\_dsm\_flag;//offset 0x10 ,置1表示发送数据通过dsm结构承载的标志
```

```
         dsm \*dsm\_obj;//offset 0x14 , 发送数据dsm结构指针
```

```

```

```
 }
```

```
msgrq\_wait(void \*msgr\_client\_ptr,void \*msg\_recv\_buf,uint32 msg\_recv\_buf\_size,uint32 \*msg\_recvd\_size\_ptr);//接受消息的函数
```

```
msgr\_register(uint16 mod\_id,void \*msgr\_client\_ptr,void \*mailbox\_obj,uint32 umid);//msgr\_client注册umid的消息路由
```


```

 

#### 消息路由

我们已经了解到UMID所对应原语操作的含义，如果需要执行相应的原语操作，只需要向注册过UMID的模块发送umid消息即可，接下来我们需要了解umid消息是如何路由到相应模块(tech\_mod\_id)的消息接收器(msgr\_client)的，下面会详细介绍相应的算法和数据结构，我整理了几张表来描述。

| map\_name || map\_size || key || value || value\_size || Memory Attribution |
| --- | --- | --- | --- | --- | --- |
| techs\_map || techs \* 8 || tech\_id || module\_counts, modules\_map || 8 bytes || Read Only |
| --- | --- | --- | --- | --- | --- |
| modules\_map || module\_counts \* 0x11 \* 2 || (mod\_id \* 0x11+type\_id) \* 2 || types\_map\_id || 2 bytes || Read Only |
| types\_map || types\_map\_ids \* 0x20 || types\_map\_id \* 0x20 +(op\_type\_id&0x1e) || tech\_mod\_type\_seq || 2 bytes || Read/Write |
| umids\_map || umid\_seq\_id \* 0x8 || 8 \* (tech\_mod\_type\_seq+op\_id) || umid, next\_umid\_seq\_id,msgr\_client\_id || 8 bytes || Read/Write |
| msgr\_clients\_map || 0x34\*total\_msgr\_client\_counts || msgr\_client\_seq\_id || msgr\_client\_desc || 0x34 || Read/Write |

```


```
struct msgr\_client\_desc{ //全局msgr\_client结构描述
```

```
    uint32 umids\_registered;
```

```
    uint16 msgr\_client\_reg\_type;//1 ->msgrq\_sig type,2-> rexq\_sig
```

```
    uint16 tech\_mod\_id;//
```

```
    union \*msg\_sig\_p{ //offset 0x10
```

```
        struct msgrq\_sig \*msgq\_p;//msgr reg type 1,4G及以后使用的mailbox消息传递系统
```

```
        struct rexq\_sig \*rexq\_p;//msgr reg type 2,兼容2G/3G时代使用的Rex IPC消息传递系统
```

```
    }
```

```
    struct msgrq \*msgrq\_p;//offset 0x14 ,if reg type 1    
```

```
    struct msgr\_client\_obj \*msgr\_client\_obj\_ptr;//offset 0x30
```

```
    
```

```
}
```

```

```

```
struct msgr\_client\_obj{//msgr\_client结构体
```

```
     unsigned int msgr\_client\_reg\_type;//1-> msgrq aka mailbox,2->rex\_q,接受消息的方式
```

```
     unsigned int register\_umid\_counts;//offset 8 ,消息接受器注册的umid的总数
```

```
     unsigned int total\_reged\_recv\_signal\_counts;//offset 0x0c,注册的接受消息的signal的个数
```

```
     union sig\_recv\_obj{
```

```
       msgrq\_sig  \*msgrq\_signal\_obj;// offset 0x10 msgrq\_sig type,4/5G未来的主流类型
```

```
       rexq\_sig \*rex\_signal\_obj;//offset 0x10  rexq\_sig type ,这个主要是为了兼容之前2/3G的系统的数据结构
```

```
     }    
```

```
     unsigned int task\_recv\_signal\_set\_mask;//offset 0x14 ,注册的接受消息的signal号的掩码
```

```
     uint32 err\_counts;//offset 0x18
```

```
     unsigned int recvd\_signal\_id;//offset 0x1c,当前接受到的signal id,msgr\_client\_reg\_type为1
```

```
     struct msgrq \*recvd\_msgrq\_ptr;//offset 0x20,当前接受消息承载的msgrq对象,msgr\_client\_reg\_type为1
```

```
     struct msgrq \*msgrq\_first\_entry;// offset 0x24,接受msgrq消息链表结构指针,msgr\_client\_reg\_type为1
```

```
     unsigned int total\_msgrq\_counts;//offset 0x28, 可以接受msgrq消息的总数,通过可以task\_recv\_signal\_set\_mask来确定,msgr\_client\_reg\_type为1
```

```
 }
```

```
 
```

```
 struct msgrq\_sig{
```

```
    uint32 sig\_ready\_flag;//must be 1
```

```
    struct sig\_def{
```

```
        uint32 signal\_id\_for\_recv;//offset 8
```

```
        uint32 signal\_reged\_wait\_mask;//offset 0xc
```

```
        void \* kernel\_msg\_queue;
```

```
        unsigned int attribute;
```

```
    };
```

```
    
```

```
    
```

```
 }
```

```
 struct rexq\_sig{ //size 0x1c, 兼容2/3G系统的数据结构
```

```
     utcb \*msgr\_client\_utcb\_ptr;//offset 0  任务接受消息使用的utcb标识
```

```
     uint32 msgr\_client\_signal\_id;//offset 4 接受消息使用的signal id
```

```
     msg\_queue \*msgr\_out\_msg\_q;//offset 0x8
```

```
     msg\_queue \*rex\_msg\_in\_q;//offset 0xc
```

```
     uint16 msg\_data\_q\_used\_size;//offset 0x10
```

```
     uint16 rexq\_id;//offset 0x12
```

```
     uint16 msg\_data\_q\_size;//offset 0x14
```

```
 }
```

```
  struct msg\_data\_q{
```

```
         struct msg\_data\_q \*prev\_q;
```

```
         struct msg\_data\_q \*next\_q;
```

```
         char data\[msg\_data\_q\_size-8\];
```

```
     }
```

```
 struct msg\_queue{
```

```
    struct msg\_data\_q \*headp;
```

```
    struct msg\_data\_q \*tailp;
```

```
    uint32 total\_q\_counts;
```

```
 }
```

```
 
```

```
 struct msgrq{
```

```
    void \*msg\_recv\_buf\_header;//offset 0
```

```
    void \*msg\_recv\_end\_buf;//offset 4
```

```
    char msgrq\_name\[16\];//offset 0x10
```

```
    int msgrq\_recvd\_seq;//ofset 0x18
```

```
    unsigned int reged\_recv\_signal\_id\_mask;//offset 0x1c,可供接受消息signal的掩码
```

```
    void \*msgr\_buf\_remain\_ptr;//offset 0x20,可供接受消息的剩余空间起始地址
```

```
    void \*msgr\_recv\_buf;//offset 0x24,当前接受到消息的buf地址
```

```
    uint32 msgr\_buf\_remain\_size;//offset 0x28
```

```
    unsigned int total\_msg\_recv\_buf\_size;//offset 0x30
```

```
    int8 is\_buf\_in\_use;//offset 0x70 ,0-> in use, 1-> not in use
```

```
    uint32 recvd\_msg\_blocks;//offset 0x58 ,收到的消息次数总和
```

```
    struct msgrq \*next\_msgrq;//offset 0x74
```

```
 }
```


```

为了更方便的理解上述的数据结构的关系与操作算法，画了一张简单的图来加深该消息系统的理解。通过以上算法和数据结构，可以很方便的完成UMID与tech\_mod\_id的消息路由的注册，消息发送等操作。

![](../Images/d4b7f539aff48d6bb62ac23d4b9f36aa.png)

需要说明的一点就是一个tech\_mod\_id可能会关联多个msgr\_client，所以msgr\_client\_id就成了消息传递的唯一标识，通过msgr\_client\_id得到全局的msgr\_client\_desc的结构定义，该结构体里面包含接受消息的任务utcb和接受消息的signal id，这里通过tech\_mod\_id 0xf19对应的MM（Mobility Management）任务进行举例。

![](../Images/66302049403fb28f108c7a8875143e47.png)

我在一个实时运行的MDM9607系统上面，描绘出所有UMID和tech\_mod\_id之间的消息路由情况，由于实在太大，可以在https://github.com/vessial/baseband/blob/master/umid\_pro.svg 进行查看。

### 消息状态机（State Machine）

高通基带系统里面的消息状态机，是实现3GPP定义功能最重要的组成部分，消息状态机在移动通信系统里面扮演着非常重要的角色，也是多模移动通信系统的核心，3GPP在定义的多个移动通信技术的分层协议栈时，不同的通信技术模式之间切换，会通过状态机来维护相应的分层逻辑的状态和可操作功能，接下来将重要介绍高通基带系统使用的状态机数据结构以及相关算法，本文将研究主要流4G LTE和5G NR系统上使用的第二代状态机消息系统，老的第一代状态机系统不在这里介绍了。

```


```
struct sm\_state\_instance{ //eg ,size 0x1c
```

```
    struct sm\_obj \*sm;//状态机对象定义
```

```
    unsigned int current\_state\_id;//状态机当前所处的状态id
```

```
    unsigned int recvd\_umid\_in\_sm\_entity\_seq;//offset 8, 状态机当前收到的umid所在状态机umid列表中的序列号
```

```
    unsigned int instance\_id;// 状态机实例编号
```

```
    uint8 sm\_state\_lock;//offset 0x11 0->state unlock,1-> state lock 状态机锁的状态
```

```
    void \*stm\_idle\_buf;//offset 0x14 状态机操作可能需要的buf空间
```

```
    unsigned int debug\_code;//offset 0x18 状态机调试码
```

```

```

```
}
```

```
struct sm\_obj{ //状态机的定义结构
```

```
    struct msgr\_stm\_obj \*stm;
```

```
    unsigned char \*stm\_obj\_name; //状态机的名称，例如LTE\_RRC\_SIB\_SM
```

```
    unsigned int stm\_obj\_name\_hash; //状态机名称的hash值
```

```
    unsigned int stm\_inst\_id;//stm instance id ，状态机的实例编号，状态机可能存在多个实例，通过这个编号来区别不同的状态机实体
```

```
}
```

```
struct msgr\_stm\_obj {
```

```
    int instance\_counts; //该状态机支持的实例个数
```

```
    int state\_cnts; //该状态机的状态数量
```

```
    struct state\_status\_def \*state\_def;//状态机每个不同状态的定义的数据结构,size state\_cnts\*0x10
```

```
    int umid\_cnts;//状态机注册的可接受umid总数
```

```
    struct umid\_msg\_list \*umid\_msg\_def;//存储umid和umid描述信息的指针,size umid\_cnts\*8
```

```
    
```

```
    struct umid\_msg\_states\_func\_cb\_list \*umid\_in\_state\_cb;//存储着所有umid对应每个状态的回调操作函数
```

```
    void \*cb\_func1;// stm enter //offset 0x18 ,进入该状态机的回调函数
```

```
    void \*cb\_func2;// stm exit  //offset 0x1c ,退出该状态机的回调函数
```

```
    void \*cb\_func3;// stm error //offset 0x20 ,状态机出错的回调函数
```

```
    void \*cb\_func4; //stm debug //offset  0x24 ,状态机调试的回调函数
```

```
    unsigned int  init\_state\_id; // default 0 ,状态机初始默认状态id
```

```

```

```
}
```

```
struct umid\_msg\_states\_func\_cb\_list {//状态机在接受到相应的umid后的原语操作回调函数
```

```
        void \*umid\_msg\_in\_states\_1\_cb\_list\[umid\_cnts\];
```

```
        void \*umid\_msg\_in\_states\_2\_cb\_list\[umid\_cnts\];
```

```
        void \*umid\_msg\_in\_states\_3\_cb\_list\[umid\_cnts\];
```

```
        ...
```

```
        void \*umid\_msg\_in\_states\_state\_cnts\_cb\_list\[umid\_cnts\];
```

```
    }
```

```
struct state\_status\_def{//每个状态的定义
```

```
    unsigned char \*state\_name; //状态名称，eg,active/inactive etc
```

```
    void \*cb\_func1; //state enter //状态机进入该状态的回调函数
```

```
    void \*cb\_func2; //state exit  //状态机退出该状态的回调函数
```

```
    void \*cb\_func3; //state debug ?//可能是调试函数
```

```
}
```

```

```

```
struct umid\_msg\_list{//状态机可接受的umid消息定义
```

```
    unsigned char \*umid\_msg\_name; //umid对应的描述名称
```

```
    unsigned int umid;            //umid
```

```
}
```

```

```

```
关键API描述
```

```
stm\_instance\_activate(struct sm\_state\_instance \*sm\_st\_inst,uint32 inst\_id,uint32 initial\_state\_id);//初始化状态机实例
```

```
stm\_instance\_process\_input(uint32 state\_id,struct sm\_state\_instance \*sm\_st\_inst,uint32 sm\_inst\_id,uint32 umid\_input,void \*stm\_payload\_ptr);//对状态机接受到的umid和数据进行原语操作
```


```

我从MDM9607固件里面提取的详细的状态机信息可以在https://github.com/vessial/baseband/blob/master/lte\_sm.log 进行查看。

3GPP定义的L3层的RRC(Radio Resource Control)的状态机是最为复杂的，高通在实现4G LTE的RRC时使用了大量的状态机进行功能管理。MDM9607 4G LTE RRC状态机类型如下:state name: LTE\_RRC\_CSG\_ASF\_SMstate name: LTE\_RRC\_DT\_SM       //state name: LTE\_RRC\_IRAT\_TO\_G\_MGR\_SMstate name: LTE\_RRC\_LLC\_SMstate name: LTE\_RRC\_CAPABILITIES\_SMstate name: LTE\_RRC\_IRAT\_FROM\_1X\_MGR\_SMstate name: LTE\_RRC\_SEC\_SM //sim认证和密钥协商管理相关的状态机state name: LTE\_RRC\_CRP\_SMstate name: LTE\_RRC\_IRAT\_FROM\_DO\_MGR\_SM //负责从CDMA-EVDO切换到LTE的管理状态机state name: LTE\_RRC\_IRAT\_FROM\_TDS\_MGR\_SM //负责从TDSCDMA切换到LTE的状态机state name: LTE\_RRC\_PAGING\_SM //寻呼管理的状态机state name: LTE\_RRC\_CONFIG\_SM state name: LTE\_RRC\_MISC\_SMstate name: LTE\_RRC\_MEAS\_SMstate name: LTE\_RRC\_CEP\_SMstate name: LTE\_RRC\_IRAT\_TO\_1X\_MGR\_SMstate name: LTE\_RRC\_IRAT\_FROM\_W\_MGR\_SMstate name: LTE\_RRC\_MDT\_SMstate name: LTE\_RRC\_IRAT\_TO\_DO\_MGR\_SMstate name: LTE\_RRC\_CONTROLLER\_SM  //关键的LTE的控制状态机，控制服务的停止和开启state name: LTE\_RRC\_IRAT\_TO\_TDS\_MGR\_SMstate name: LTE\_RRC\_IRAT\_TO\_W\_MGR\_SM  //从LTE切换到WCDMA的管理状态机state name: LTE\_RRC\_EMP\_SMstate name: LTE\_RRC\_MH\_SM   
state name: LTE\_RRC\_UEINFO\_SM  //UE信息管理的状态机state name: LTE\_RRC\_SIB\_SM     //系统信息块的管理状态机state name: LTE\_RRC\_PLMN\_SEARCH\_SM  //搜索网络使用的状态机state name: LTE\_RRC\_IRAT\_FROM\_G\_MGR\_SM  //从GSM切换到LTE的状态机state name: LTE\_RRC\_CSP\_SM  //cell search plmn状态机state name: LTE\_RRC\_ESMGR\_SM // EMBMS管理状态机state name: LTE\_RRC\_CRE\_SM

我们拿LTE\_RRC\_PAGING\_SM状态机定义作例子与之对应的数据结构作解析

```


```
LTE\_RRC\_PAGING\_SM addr 0xd10b35e0
```

```
     state machine name: LTE\_RRC\_PAGING\_SM inst\_cnts 1 total states 3  total umid 10
```

```
     state name: INITIAL state enter 0xd0b923a8 state exit 0xd0b923c8 state debug 0x0
```

```
     state name: IDLE\_CAMPED state enter 0xd0b923e0 state exit 0xd0b92400 state debug 0x0
```

```
     state name: CONNECTED state enter 0xd0b92418 state exit 0xd0b92450 state debug 0x0
```

```
0x040d140c   LTE\_RRC\_CAMPED\_INDI
```

```
0x040d0207   LTE\_RRC\_DRX\_INFO\_REQ
```

```
0x040d0206   LTE\_RRC\_SIM\_UPDATE\_REQ
```

```
0x040d0401   LTE\_RRC\_SERVICE\_IND
```

```
0x040d0710   LTE\_RRC\_PAGING\_DLM
```

```
0x040d1405   LTE\_RRC\_CONNECTED\_INDI
```

```
0x040d022a   LTE\_RRC\_MTC\_CFG\_REQ
```

```
0x040d1400   LTE\_RRC\_STOPPED\_INDI
```

```
0x040d140b   LTE\_RRC\_NOT\_CAMPED\_INDI
```

```
0x040d1402   LTE\_RRC\_SIB\_UPDATED\_INDI
```


```

下图为MDM9607 4G LTE\_RRC的状态机图谱

*   

```

```

#### 状态机操作实例  

为了更直观的理解消息状态机的操作过程，我这里提供了一个例子来展示消息传递过程以及状态机的处理过程，这个过程是在基带处理IDLE状态下，没有接入任何移动通信网络，到基带一次接入4G LTE网络到SIM认证的过程，这里只提供RRC的状态机的处理过程。

| 发送端 || 接受端 || 接受UMID号 || 描述信息 || 处理状态机 ||   |
| --- | --- | --- | --- | --- | --- |
| 0xF19 emm || LTE\_RRC || 0x40d0204 || LTE\_RRC\_SERVICE\_REQ || LTE\_RRC\_CSP\_SM ||   
 |
| --- | --- | --- | --- | --- | --- |
| 0xF19 emm || LTE\_RRC || 0x40d0204 || LTE\_RRC\_SERVICE\_REQ || LTE\_RRC\_IRAT\_FROM\_W\_MGR\_SM ||   
 |
| 0xF19 emm || LTE\_RRC || 0x40d0204 || LTE\_RRC\_SERVICE\_REQ || LTE\_RRC\_IRAT\_FROM\_G\_MGR\_SM ||   
 |
| 0xF19 emm || LTE\_RRC || 0x40d0204 || LTE\_RRC\_SERVICE\_REQ || LTE\_RRC\_IRAT\_FROM\_TDS\_MGR\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1442 || LTE\_RRC\_CLEAR\_DEPRI\_FREQ\_INDI || LTE\_RRC\_MEAS\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d120d || LTE\_RRC\_MODE\_CHANGE\_REQI || LTE\_RRC\_CONTROLLER\_SM ||   
 |
| 0x40f LTE\_MAC || LTE\_RRC || 0x40f0803 || LTE\_MAC\_START\_CNF || LTE\_RRC\_CONTROLLER\_SM ||   
 |
| 0x412 LTE\_RLCUL || LTE\_RRC || 0x4120801 || LTE\_RLCUL\_START\_CNF || LTE\_RRC\_CONTROLLER\_SM ||   
 |
| 0x411 LTE\_RLCDL || LTE\_RRC || 0x4110801 || LTE\_RLCDL\_START\_CNF || LTE\_RRC\_CONTROLLER\_SM ||   
 |
| 0x413 LTE\_PDCPDL || LTE\_RRC || 0x4130806 || LTE\_PDCPDL\_START\_CNF || LTE\_RRC\_CONTROLLER\_SM ||   
 |
| 0x414 LTE\_PDCPUL || LTE\_RRC || 0x4140807 || LTE\_PDCPUL\_START\_CNF || LTE\_RRC\_CONTROLLER\_SM ||   
 |
| 0x40c LTE\_ML1\_MGR || LTE\_RRC || 0x40c0801 || LTE\_CPHY\_START\_CNF || LTE\_RRC\_CONTROLLER\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1513 || LTE\_RRC\_MODE\_CHANGE\_CNFI || LTE\_RRC\_CSP\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1206 || LTE\_RRC\_CFG\_REQI || LTE\_RRC\_LLC\_SM ||   
 |
| 0x40c LTE\_ML1\_MGR || LTE\_RRC || 0x40c0809 || LTE\_CPHY\_SYSTEM\_SCAN\_CNF || LTE\_RRC\_CSP\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1206 || LTE\_RRC\_CFG\_REQI || LTE\_RRC\_LLC\_SM ||   
 |
| 0x40c LTE\_ML1\_MGR || LTE\_RRC || 0x40c0800 || LTE\_CPHY\_ACQ\_CNF || LTE\_RRC\_CSP\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1202 || LTE\_RRC\_GET\_SIBS\_REQI || LTE\_RRC\_SIB\_SM ||   
 |
| 0x403 LTE\_ML1\_DLM || LTE\_RRC || 0x40c0402 || LTE\_CPHY\_MIB\_IND || LTE\_RRC\_SIB\_SM ||   
 |
| 0x40F LTE\_MAC || LTE\_RRC || 0x40f0406 || LTE\_MAC\_RRC\_BCCH\_DL\_DATA\_IND || LTE\_RRC\_SIB\_SM || BCCH DL SCH SIB1 |
| 0x40c LTE\_ML1\_MGR || LTE\_RRC || 0x40c0823 || LTE\_CPHY\_TDD\_CFG\_CNF || LTE\_RRC\_SIB\_SM ||   
 |
| 0x40F LTE\_MAC || LTE\_RRC || 0x40f0406 || LTE\_MAC\_RRC\_BCCH\_DL\_DATA\_IND || LTE\_RRC\_SIB\_SM || BCCH DL SCH SI |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1514 || LTE\_RRC\_GET\_SIBS\_CNFI || LTE\_RRC\_CSP\_SM ||   
 |
| 0x40F LTE\_MAC || LTE\_RRC || 0x40f0406 || LTE\_MAC\_RRC\_BCCH\_DL\_DATA\_IND || LTE\_RRC\_SIB\_SM || BCCH DL SCH SIB1 |
| 0x40c LTE\_ML1\_MGR || LTE\_RRC || 0x40c080a || LTE\_CPHY\_CELL\_SELECT\_CNF || LTE\_RRC\_CSP\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1206 || LTE\_RRC\_CFG\_REQI || LTE\_RRC\_LLC\_SM ||   
 |
| 0x40c LTE\_ML1\_MGR || LTE\_RRC || 0x40c0804 || LTE\_CPHY\_COMMON\_CFG\_CNF || LTE\_RRC\_LLC\_SM ||   
 |
| 0x40c LTE\_ML1\_MGR || LTE\_RRC || 0x40c0805 || LTE\_CPHY\_DEDICATED\_CFG\_CNF || LTE\_RRC\_LLC\_SM ||   
 |
| 0x40f LTE\_MAC || LTE\_RRC || 0x40f0801 || LTE\_MAC\_CFG\_CNF || LTE\_RRC\_LLC\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1516 || LTE\_RRC\_CFG\_CNFI || LTE\_RRC\_CSP\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d140c || LTE\_RRC\_CAMPED\_INDI || LTE\_RRC\_SIB\_SM || inactive |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d140c || LTE\_RRC\_CAMPED\_INDI || LTE\_RRC\_SIB\_SM || active |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d140c || LTE\_RRC\_CAMPED\_INDI || LTE\_RRC\_MEAS\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d140c || LTE\_RRC\_CAMPED\_INDI || LTE\_RRC\_CAPABILITIES\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d140c || LTE\_RRC\_CAMPED\_INDI || LTE\_RRC\_CEP\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d140c || LTE\_RRC\_CAMPED\_INDI || LTE\_RRC\_MISC\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1516 || LTE\_RRC\_CFG\_CNFI || LTE\_RRC\_CONTROLLER\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1402 || LTE\_RRC\_SIB\_UPDATED\_INDI || LTE\_RRC\_CSP\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1402 || LTE\_RRC\_SIB\_UPDATED\_INDI || LTE\_RRC\_CEP\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1402 || LTE\_RRC\_SIB\_UPDATED\_INDI || LTE\_RRC\_PAGING\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1402 || LTE\_RRC\_SIB\_UPDATED\_INDI || LTE\_RRC\_MEAS\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1402 || LTE\_RRC\_SIB\_UPDATED\_INDI || LTE\_RRC\_CSG\_ASF\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1402 || LTE\_RRC\_SIB\_UPDATED\_INDI || LTE\_RRC\_IRAT\_TO\_G\_MGR\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1402 || LTE\_RRC\_SIB\_UPDATED\_INDI || LTE\_RRC\_IRAT\_TO\_TDS\_MGR\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40D0401 || LTE\_RRC\_SERVICE\_IND || LTE\_RRC\_CSG\_ASF\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40D0401 || LTE\_RRC\_SERVICE\_IND || LTE\_RRC\_PAGING\_SM ||   
 |
| 0x40c LTE\_ML1\_MGR || LTE\_RRC || 0x40c0815 || LTE\_CPHY\_IDLE\_MEAS\_CFG\_CNF || LTE\_RRC\_MEAS\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d0225 || LTE\_RRC\_AVOIDANCE\_REQ || LTE\_RRC\_CSP\_SM ||   
 |
| 0x40F LTE\_MAC || LTE\_RRC || 0x40f0406 || LTE\_MAC\_RRC\_BCCH\_DL\_DATA\_IND || LTE\_RRC\_SIB\_SM || SI |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1437 || LTE\_RRC\_INTERFREQ\_LIST\_UPDATE\_INDI || LTE\_RRC\_CSP\_SM ||   
 |
| 0xf19 EMM || LTE\_RRC || 0x40d0200 || LTE\_RRC\_CONN\_EST\_REQ || LTE\_RRC\_CEP\_SM || Attach Request NAS msg |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40D1404 || LTE\_RRC\_CONN\_ESTABLISHMENT\_STARTED\_INDI || LTE\_RRC\_CONTROLLER\_SM || RRC Connection Request |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40D143d || LTE\_RRC\_TRM\_PRIORITY\_CHANGE\_INDI || LTE\_RRC\_CONTROLLER\_SM ||   
 |
| 0xF19 EMM || LTE\_RRC || 0x40d0206 || LTE\_RRC\_SIM\_UPDATE\_REQ || LTE\_RRC\_CONTROLLER\_SM ||   
 |
| 0xF19 EMM || LTE\_RRC || 0x40d0206 || LTE\_RRC\_SIM\_UPDATE\_REQ || LTE\_RRC\_PAGING\_SM ||   
 |
| 0xF19 EMM || LTE\_RRC || 0x40d0206 || LTE\_RRC\_SIM\_UPDATE\_REQ || LTE\_RRC\_SEC\_SM || SIM Update Req received from NAS |
| 0xF19 EMM || LTE\_RRC || 0x40d0206 || LTE\_RRC\_SIM\_UPDATE\_REQ || LTE\_RRC\_CAPABILITIES\_SM ||   
 |
| 0x404 LTE\_ML1\_ULM || LTE\_RRC || 0x40c0421 || LTE\_CPHY\_RACH\_MSG1\_SCHED\_IND || LTE\_RRC\_CEP\_SM || LTE MAC RACH Attempt |
| 0x40f LTE\_MAC || LTE\_RRC || 0x40f0800 || LTE\_MAC\_ACCESS\_CNF || LTE\_RRC\_CEP\_SM ||   
 |
| 0x40f LTE\_MAC || LTE\_RRC || 0x40f0405 || LTE\_MAC\_RRC\_CCCH\_DL\_DATA\_IND || LTE\_RRC\_MH\_SM || CCCH RRC Connection Setup |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d0703 || LTE\_RRC\_RRC\_CONNECTION\_SETUP\_DLM || LTE\_RRC\_CEP\_SM || CCCH RRC Connection Setup |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1206 || LTE\_RRC\_CFG\_REQI || LTE\_RRC\_LLC\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40D1408 || LTE\_RRC\_PROCEED\_WITH\_RESEL\_INDI || LTE\_RRC\_CSP\_SM ||   
 |
| 0x411 LTE\_RLCDL || LTE\_RRC || 0x4110800 || LTE\_RLCDL\_CFG\_CNF || LTE\_RRC\_LLC\_SM ||   
 |
| 0x412 LTE\_RLCUL || LTE\_RRC || 0x4120800 || LTE\_RLCUL\_CFG\_CNF || LTE\_RRC\_LLC\_SM ||   
 |
| 0x413 LTE\_PDCPDL || LTE\_RRC || 0x4130800 || LTE\_PDCPDL\_CFG\_CNF || LTE\_RRC\_LLC\_SM ||   
 |
| 0x414 LTE\_PDCPUL || LTE\_RRC || 0x4140800 || LTE\_PDCPUL\_CFG\_CNF || LTE\_RRC\_LLC\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1516 || LTE\_RRC\_CFG\_CNFI || LTE\_RRC\_CEP\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1200 || LTE\_RRC\_SEND\_UL\_MSG\_REQI || LTE\_RRC\_MH\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1405 || LTE\_RRC\_CONNECTED\_INDI || LTE\_RRC\_SIB\_SM ||   
 |
|   
 ||   
 ||   
 ||   
 ||   
 ||   
 |
| 0x414 LTE\_PDCPUL || LTE\_RRC || 0x4140802 || LTE\_PDCPUL\_SDU\_CNF || LTE\_RRC\_MH\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1504 || LTE\_RRC\_RRC\_CONNECTION\_SETUP\_COMPLETE\_CNFI || LTE\_RRC\_CEP\_SM || UL\_DCCH RRC connection Setup Complete |
| 0x413 LTE\_PDCPDL || LTE\_RRC || 0x4130400 || LTE\_PDCPDL\_SDU\_IND || LTE\_RRC\_MH\_SM || DL\_DCCH info Transfer |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d0705 || LTE\_RRC\_DL\_INFORMATION\_TRANSFER\_DLM || LTE\_RRC\_DT\_SM || DL\_DCCH Auth Request Msg recvd |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d141f || LTE\_RRC\_DLM\_PROCESSED\_INDI || LTE\_RRC\_MH\_SM ||   
 |
| 0xF19 EMM || LTE\_RRC || 0x40d0201 || LTE\_RRC\_UL\_DATA\_REQ || LTE\_RRC\_DT\_SM || send Auth Resp data |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1200 || LTE\_RRC\_SEND\_UL\_MSG\_REQI || LTE\_RRC\_MH\_SM || UL\_DCCH ULinfo Transfer send NAS Auth resp |
| 0x414 LTE\_PDCPUL || LTE\_RRC || 0x4140802 || LTE\_PDCPUL\_SDU\_CNF || LTE\_RRC\_MH\_SM ||   
 |
| 0x40d LTE\_RRC || LTE\_RRC || 0x40d1509 || LTE\_RRC\_UL\_INFORMATION\_TRANSFER\_CNFI || LTE\_RRC\_DT\_SM ||   
 |

 

DL\_DCCH的Information Transfer字段里面包含了来自MME发送过来的认证请求数据(LTE NAS EMM信令消息id 0x52)，包含有nas key set id, 16个字节的认证随机数据auth\_param rand，以及16个字节的auth param AUTN数据，SIM卡通过收到的这两个关键信息进行认证，并计算生成Auth\_resp发送给MME进行比较完成本地端和服务器端的认证，本地端计算如下。 

本地端收到的rand(16bytes)+AUTN(16bytes)  
K为sim卡和MME都持有的sim卡的唯一隐私数据，sim卡端只有sim卡芯片可以读取。 

SIM卡端密钥派生认证过程，f1/2/3/4/5为sim卡的计算功能函数  

AK=f5(K,rand)  

IK=f4(K,rand)  

CK=f3(K,rand)  

RES=f2(K,rand) //计算给MME进行认证SIM卡的数据  

SQN=AUTN^AK  (6bytes)  
AMF=AUTN\[6:8\]  

MAC=f1(K,SQN,rand,AMF)  

SIM卡端认证MME端过程  

sim\_autn=SQN^AK(6bytes)+AMF(2bytes)+MAC(8bytes)  

比较MME发过来的AUTN和sim\_autn ，相等则认为MME合法。 

基带把sim卡计算得到的RES通过LTE NAS EMM 信令消息号0x53包裹到UL\_DCCH的InformationTransfer字段里面发给基站进而到MME进行认证。 

MME认证SIM卡的过程就比较简单了。MME端计算XRES=f2(K,rand)，然后比较收到的RES，相等表示MME认证SIM卡成功，至此认证完成。由于上述操作涉及EMM和RRC之间的交互过程比较复杂，这里只是简单提一下，EMM的状态机会在下一篇文章里面单独详细介绍。

## 结语

由于从全球公开的信息渠道中并不能获取高通基带系统的深入信息，所以花费1年多的时间通过对底层操作系统和上层3GPP实现的业务系统进行深度逆向工程，这篇文章只是系统性的介绍了高通4/5G基带系统的消息机制和消息状态机，我认为这是一个关键的架构设计，梳理清楚其消息架构对于理解3GPP实现的消息原语操作以及对移动通信技术的多模分层设计有非常大的帮助，该消息系统架构设计具有非常好的扩展性，可以很灵活的增加新的功能到该消息框架中去，可以很好的减少系统测试成本，有很多设计理念值得学习和借鉴，由于现今高通5G基带所支持的UMID操作数高达2万多个，所以这里的展示的例子只是揭示了状态机功能操作的冰山一角，后续会持续研究对于状态机安全漏洞的挖掘研究，实现高效的5G安全测试体系，通过对基带系统的深刻认知，可以更好的对基站系统和核心网系统进行安全评估。