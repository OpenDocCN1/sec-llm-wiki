version="1.0" encoding="utf-8"?

# 教你实现自己的DNS隧道远控

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247483988&idx=1&sn=7b0ba64f2ea6a770d50d3ab64aa4d5da&chksm=fc30c50ecb474c18904c0dd051a75c2a8b522814c0412119a49fef6d0fcdf9bd5ef65411c2ce&scene=126&sessionid=1681400524#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247483988&idx=1&sn=7b0ba64f2ea6a770d50d3ab64aa4d5da&chksm=fc30c50ecb474c18904c0dd051a75c2a8b522814c0412119a49fef6d0fcdf9bd5ef65411c2ce&scene=126&sessionid=1681400524#rd)

## **序**

DNS隧道，通过设置NS记录和A记录控制子域名解析到我们指定的公网IP服务器地址，进而躲避内网日志监控系统、穿透内网的防火墙策略进行传输数据、远程控制，毕竟DNS查询请求与响应是众多服务都需要的基础功能，防火墙大多不会禁止。其基础知识本文不做详细介绍，读者可自行搜索。

## **程序设计**

DNS远控分为client和server两端，client放置到内网靶机，接收并执行server的命令。server运行在公网VPS上，下发命令、收取数据和会话管理。

### **如何使用DNS协议传送有效载荷**

已有的DNS隧道软件通常会使用A记录和Mail Exchange查询响应来携带数据，这里我选用更隐蔽的DNSSEC安全扩展中的Resource Record类型

*   
*   

```
client -> server: query DNSKEY, accept DNSSEC security RRsserver -> client: answer DNSKEY, publickey 可用来传输数据
```

  

一个真实DNS请求

```

```

*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
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
Frame 99: 120 bytes on wire (960 bits), 120 bytes captured (960 bits) on interface \Device\NPF_{BC6B3107-2D7F-490A-963C-710BA04C6854}, id 0Ethernet II, Src: VMware_a2:2c:80 (00:0c:29:a2:2c:80), Dst: VMware_f6:9c:9e (00:50:56:f6:9c:9e)Internet Protocol Version 4, Src: 192.168.122.130, Dst: 192.168.122.2User Datagram Protocol, Src Port: 38569, Dst Port: 53Domain Name System (query)    Transaction ID: 0x32e9    Flags: 0x0100 Standard query    Questions: 1    Answer RRs: 0    Authority RRs: 0    Additional RRs: 1    Queries        jXD/Bv8AAAAMSEFMTxxKAABf8s5i.1.xxx.website: type DNSKEY, class IN            Name: jXD/Bv8AAAAMSEFMTxxKAABf8s5i.1.xxx.website            [Name Length: 49]            [Label Count: 4]            Type: DNSKEY (DNS Public Key) (48)            Class: IN (0x0001)    Additional records        <Root>: type OPT            Name: <Root>            Type: OPT (41)            UDP payload size: 4096            Higher bits in extended RCODE: 0x00            EDNS0 version: 0            Z: 0x8000                1... .... .... .... = DO bit: Accepts DNSSEC security RRs                .000 0000 0000 0000 = Reserved: 0x0000            Data length: 0    [Response In: 100]
```

  

client发送给server的数据还是存放在query的name字符串中，域名中的每一个标签（逗号分隔）限制最大长度为63字节，整个域名的长度不超过255字节。这里是

*   

```

```

```

```

jXD/Bv8AAAAMSEFMTxxKAABf8s5i就是要传送的数据了，是经过base64编码的，编码后最大63字节，那也就是说明文最大45字节，即client一个请求只能最多携带45字节数据到server。而server->client即DNS响应使用publickey传输数据，可传输最多437字节（实际测试得出）。该请求的响应如下：

*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
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
Frame 100: 189 bytes on wire (1512 bits), 189 bytes captured (1512 bits) on interface \Device\NPF_{BC6B3107-2D7F-490A-963C-710BA04C6854}, id 0Ethernet II, Src: VMware_f6:9c:9e (00:50:56:f6:9c:9e), Dst: VMware_a2:2c:80 (00:0c:29:a2:2c:80)Internet Protocol Version 4, Src: 192.168.122.2, Dst: 192.168.122.130User Datagram Protocol, Src Port: 53, Dst Port: 38569Domain Name System (response)    Transaction ID: 0x32e9    Flags: 0x8180 Standard query response, No error    Questions: 1    Answer RRs: 1    Authority RRs: 0    Additional RRs: 0    Queries        jXD/Bv8AAAAMSEFMTxxKAABf8s5i.1.xxx.website: type DNSKEY, class IN            Name: jXD/Bv8AAAAMSEFMTxxKAABf8s5i.1.xxx.website            [Name Length: 49]            [Label Count: 4]            Type: DNSKEY (DNS Public Key) (48)            Class: IN (0x0001)    Answers        jXD/Bv8AAAAMSEFMTxxKAABf8s5i.1.xxx.website: type DNSKEY, class IN            Name: jXD/Bv8AAAAMSEFMTxxKAABf8s5i.1.xxx.website            Type: DNSKEY (DNS Public Key) (48)            Class: IN (0x0001)            Time to live: 5 (5 seconds)            Data length: 68            Flags: 0x0100            Protocol: 3            Algorithm: RSA/SHA1 + NSEC3/SHA1 (7)            [Key id: 942]            Public Key: 46384f4b017aea00000000007778722d78722d78203120726f6f7420726f6f7420202031…    [Request In: 99]    [Time: 0.054413000 seconds]
```

###   

### **可靠传输**

传统的DNS服务监听的是UDP端口，那么剩下的工作就是如何在DNS协议之上实现一个类似TCP的可靠传输协议，涉及到分包组包、重传等细节。包头设计：

*   
*   
*   
*   
*   
*   

```
struct FragmentCtrl{    unsigned short end:1;    unsigned short seqId:15;    unsigned short clientID;};
```

15 bit作为循环序号，1 bit作为是否最后一个分片标识，2 byte作为会话id区分来自不同靶机的会话。发送时采用比较简单的停等协议，client在每一个请求中都带有序列号，server在接收之后要回复ack，client只有等到当前包的ack之后才会发送下一个包，如果超时未收到ack则重传，重复此过程直到所有分片都传输完成。

### **命令下发**

传输层可靠实现之后，就要实现应用层的协议了，client定时询问server是否有命令要执行

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
client->server: Hello?server->client: 没事(隔1秒)client->server: Hello?server->client: 没事(隔1秒)client->server: Hello?server->client: getuidclient->server: uid=0(root) gid=0(root)
```

更详细的实现可以参考代码和抓包分析。

  

## **项目介绍**

https://github.com/bigBestWay/dnstunnel  
C语言编写，适用于LINUX系统

### **编译**

*   

```

```

```
域名配置

```

使用者需要在域名服务做如下配置(以gandi.net为例):  
添加一条A记录:

*   

```

```

```

再添加一条NS记录:
```

*   

```

```

```
使用说明

```

按照以上添加后, 在55.55.55.55上启动NDNS\_server

*   

```

```

```

在靶机上带参数启动NDNS_client
```

*   

```

```

```

```

支持如下命令

*   
*   
*   
*   
*   
*   
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
session <list|clientid>getuidupload <local> <remote>download <remote> <local>bash <shell cmd>move <src> <dst>mkdir <dir>rmdir <dir>rename <old> <new>listrm <file>cd <dir>pwdhostipSession[29727]>>
```

```
session

```

*   

```

```

```

列出当前所有会话
```

*   

```

```

```

切换到对应会话
```

#### **getuid**

*   

```

```

```

获取当前远程会话的用户ID
```

#### **upload**

*   

```

```

```

```

将本地文件aaa上传到远程会话机器bbb，限制文件aaa压缩后要小于430字节

#### **download**

*   

```

```

`   `

`将远程文件aaa下载到本地为bbb，下载速率大概20-30字节/秒，所以千万不要下载大文件，否则耗时超级长`

#### **bash**

*   

```

```

```

可执行任意shell命令，注意不要执行需要交互的命令
```

#### **move**

*   

```

```

```

和mv功能一致，暂未实现，可能用处很少
```

#### **mkdir**

*   

```

```

```

在远端创建文件夹aaa
```

#### **rmdir**

删除远端文件夹

#### **rename**

重命令文件

#### **list**

*   

```

```

```

在远端程序当前目录执行ls -lrt并返回结果
```

#### **rm**

删除远端文件

#### **cd**

切换远端程序当前目录

#### **pwd**

获取远端程序当前目录

#### **hostip**

获取远端机器的出口ip和主机名

## **TODO**

Beta版本还未经过很多测试，很多地方都可以改进，比如client daemonlize、无限fork躲避查杀、流量加密、停等协议改成滑动窗口等。