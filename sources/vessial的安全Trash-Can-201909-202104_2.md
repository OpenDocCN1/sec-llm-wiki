version="1.0" encoding="utf-8"?

# Qualcomm QSEECOM接口漏洞（CVE-2019-14040）分析

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzIxMjY0NjA2Mw==&mid=2247483696&idx=1&sn=c38732d8d688275a649cbbd903cd6bf5&chksm=9743a0f0a03429e666c9ca4d292602b188261adad0d89739d66affd803b5043345694230c14a&scene=27#wechat\_redirect](http://mp.weixin.qq.com/s?__biz=MzIxMjY0NjA2Mw==&mid=2247483696&idx=1&sn=c38732d8d688275a649cbbd903cd6bf5&chksm=9743a0f0a03429e666c9ca4d292602b188261adad0d89739d66affd803b5043345694230c14a&scene=27#wechat_redirect)

QualcommQSEECOM接口漏洞（CVE-2019-14040）漏洞分析

 

  

 

背景：

今天看到腾讯玄武实验室推送的一篇国外的安全公司zimperium的研究人员写的一篇他们分析发现的高通的QSEECOM接口漏洞文章，https://blog.zimperium.com/multiple-kernel-vulnerabilities-affecting-all-qualcomm-devices/其中一个Use-After-Free的漏洞（CVE-2019-14041）我觉得挺有意思，但是原文有些部分写的比较生涩或者没有提到关键点上，所以我想稍微续叼写的更具体一些，以及我对这种类型漏洞的一些思考或者是对我的启发，以及安全研究人员和产品开发人员对安全的理解方式。

 

这名叫TamirZahavi-Brunner的安全研究者在2019年的7月底发现两个高通QSEECOM接口的漏洞，一个是条件竞争的漏洞CVE-2019-14041，一个就是我今天要讲的内核内存映射相关的Use-After-Free漏洞CVE-2019-14040。

 

简单介绍一下这个QSEECOM接口，它是一个内核驱动连接用户态Normal world和Secure world的一个桥梁，Secure world就是我们常说的Trustzone/TEE/Security Enclave安全运行环境，Normalworld就是非安全运行环境，这个高通的QSEECOM接口可以实现一些从用户态加载/卸载一些安全的TA（TrustApplcation）到TrustZone中去运行，比如我们手机常用的指纹/人脸识别的应用，这些应用都是在TrustZone中运行的，在这种运行环境下，可以保证我们用户的关键隐私不被窃取，这个QSEECOM架构如下。

 

要想了解这个漏洞的成因，需要先了解这个QSEECOM接口的功能处理逻辑，用户态通过ION设备（一个内存管理器，可以通过打开/dev/ion进行访问）申请的内存可以通过QSEECOM接口映射到内核地址空间，可供内核或者TrustZone访问，而对于QSEECOM驱动模型中（/dev/qseecom）提供给用户的接口有open/close/ioctl，对应着QSEECOM内核处理函数为qseecom\_open/qseecom\_ioctl/qseecom\_release。

 

**漏洞成因：**

说到Use-After-Free漏洞，我们需要先了解内存在哪里Free掉的，然后是在哪里Use的，如何Use的。

 

**Free操作过程：**

用户态每次打开qseecom设备（/dev/qseecom），都会在内核态生成一个qseecom\_dev\_handle的结构指针，这个结构指针会被关闭qseecom设备（用户态通过close函数）或者来自用户的IO操作号QSEECOM\_IOCTL\_UNLOAD\_APP\_REQ请求予以销毁，需要了解这个结构指针的销毁过程，那么得先了解这个指针的初始化过程。

 

打开qseecom设备时会调用qseecom\_open分配一个qseecom\_dev\_handle结构体

  

static int qseecom\_open(struct inode \*inode, struct file\*file)

{

    int ret = 0;

    structqseecom\_dev\_handle \*data;

    data = kzalloc(sizeof(\*data), GFP\_KERNEL);

    if (!data)

       return -ENOMEM;

    file->private\_data= data;

    data->abort = 0;

    …

用户通过QSEECOM\_IOCTL\_SET\_MEM\_PARAM\_REQ ioctl请求通过函数qseecom\_set\_client\_mem\_param来建立用户态ion内存在内核地址空间的映射，而qseecom\_set\_client\_mem\_param函数通过copy\_from\_user函数来获取用户传递的ion用户内存的地址信息以及这个内存的长度信息，我把关键的代码标示出来。

staticint qseecom\_set\_client\_mem\_param(struct qseecom\_dev\_handle \*data,

                     void \_\_user \*argp)

{

    ion\_phys\_addr\_t pa;

    int32\_t ret;

    struct qseecom\_set\_sb\_mem\_param\_req req;

    size\_t len;

    /\* Copy the relevant information needed forloading the image \*/

    if (copy\_from\_user(&req, (void \_\_user\*)argp, sizeof(req)))

       return -EFAULT;

    ...

    data->client.ihandle =ion\_import\_dma\_buf\_fd(qseecom.ion\_clnt,

                     req.ifd\_data\_fd);

    ...

    /\* Get the physical address of the ION BUF\*/

    ret =ion\_phys(qseecom.ion\_clnt, data->client.ihandle, &pa, &len);

    if (ret) {

       pr\_err("Cannot get phys\_addr for theIon Client, ret = %d\\n",

           ret);

       return ret;

    }

    if (len < req.sb\_len) {

       pr\_err("Requested length (0x%x) is> allocated (%zu)\\n",

           req.sb\_len, len);

       return -EINVAL;

    }

    /\* Populate the structure for sending scmcall to load image \*/

    data->client.sb\_virt = (char \*)ion\_map\_kernel(qseecom.ion\_clnt,

                         data->client.ihandle);

    if (IS\_ERR\_OR\_NULL(data->client.sb\_virt)){

       pr\_err("ION memory mapping forclient shared buf failed\\n");

       return -ENOMEM;

    }

    data->client.sb\_phys = (phys\_addr\_t)pa;

    data->client.sb\_length = req.sb\_len;

    data->client.user\_virt\_sb\_base =(uintptr\_t)req.virt\_sb\_base;

    return 0;

}

这个代码流程如下：

  

 

![](../Images/d7e0fc29d1dfe1a4575e4784b3d91475.png)

  

 

 

我们从qseecom\_dev\_handle结构体上能够发现client是它的子成员结构体

 

struct qseecom\_dev\_handle {

    enumqseecom\_client\_handle\_type type;

    union {

        structqseecom\_client\_handle client;//这个指针没有置空

       structqseecom\_listener\_handle listener;

    };

    bool released;

…

 

struct qseecom\_client\_handle {

    u32  app\_id;

    u8 \*sb\_virt;

    phys\_addr\_t sb\_phys;

    unsigned longuser\_virt\_sb\_base;

    size\_t sb\_length;

    struct ion\_handle \*ihandle;     /\*Retrieve phy addr \*/

    charapp\_name\[MAX\_APP\_NAME\_SIZE\];

    u32  app\_arch;

    structqseecom\_sec\_buf\_fd\_info sec\_buf\_fd\[MAX\_ION\_FD\];

    bool from\_smcinvoke;

};

 

而销毁qseecom\_dev\_handle结构指针的时候只是把子成员结构体client的子成员ion\_handle结构指针ihandle给置空了，client结构体的其它成员并没有置空，也就是说client结构体中的sb\_virt地址还sb\_length的值还是残留的，这也为后续的freed的内存重新use提供了前提。

static int qseecom\_unmap\_ion\_allocated\_memory(struct qseecom\_dev\_handle\*data)

{

       int ret = 0;

       if(!IS\_ERR\_OR\_NULL(data->client.ihandle)) {

              ion\_unmap\_kernel(qseecom.ion\_clnt,data->client.ihandle);//解除用户态  ion内存到内核态的映射

              ion\_free(qseecom.ion\_clnt,data->client.ihandle);//

              data->client.ihandle= NULL; //只是把这个指针置空了

       }

       return ret;

}

 

 

**Use的过程：**

上面我们已经讲了qseecom\_dev\_handle的销毁的过程，接下来我们看看攻击者是如何使用释放掉的内存的。

我们知道当释放掉的内存被以同样大小以及同样的内存分配式来申请的时候，之前释放掉的内存是很容易被重新命中的，同理常见于浏览器use-after-free漏洞通过heap spray的方式进行大量内存申请来命中之前被释放掉的对象。之前我们说过了，通过qseecom\_open打开qseecom设备的时候会分配一个qseecom\_dev\_handle结构体，但是很不幸的是这个初始化过程也没有完全把这片内存给清0。

static int qseecom\_open(struct inode \*inode, struct file \*file)

{

       int ret = 0;

       structqseecom\_dev\_handle \*data;

       data =kzalloc(sizeof(\*data), GFP\_KERNEL);

       if (!data)

              return -ENOMEM;

       file->private\_data =data;

       data->abort = 0;

       data->type =QSEECOM\_GENERIC;

       data->released =false;

       memset((void\*)data->client.app\_name, 0, MAX\_APP\_NAME\_SIZE);//似乎还差一点点

      

这个初始化前后的内存对比是这样的

  

 

![](../Images/44371ff8a18a27b0553ac90f579b55ca.png)

接下来就是use过程的关键了，我们的目标就是能够使用这些free掉的结构中残留的数据，如何能够保证残留数据可用，第一，残留的关键数据不被接下来的流程所覆盖，第二，保护流程正常走下去，现有的qseecom\_dev\_handle结构不被无效的操作释放。为了保证满足第二条，我们需要满足qseecom\_dev\_handle成员client的ihandle指针不能为空（\_\_validate\_send\_service\_cmd\_inputs会检查），因为之前释放的时候这里被置空了。好的，现在只需要保证第一条，关键的残留数据不被覆盖就好了。

 

为了达到这个残留数据不被覆盖的目标，只需要用户态发送一个QSEECOM\_IOCTL\_SET\_MEM\_PARAM\_REQ ioctl请求，且用户提交的ION内存分配的长度信息大于实际用户所分配的大小即可（例如用户只分配了0x1000字节内存，但是用户提交给内核说我分配了0x2000个字节，当然内核也不是傻子，你说多少就多少，内核说我要检查一下，检查发现，好小子你才分配了0x1000字节的内存，你却告诉我有0x2000字节，是不是当我傻，内核就立即返回操作出错的信息给用户），还记得上面提到的qseecom\_set\_client\_mem\_param函数处理流程吗? 虽然内核直接返回操作错误告之给用户态，但是最重要的是qseecom\_dev\_handle指针没有被销毁，而且就是因为这个错误的操作，那个残留数据也没有被覆盖，且结构体里面的ihandle也赋值了不为空，两个条件都满足了，然后接下来的正常业务处理逻辑将会把之前残留的sb\_virt/sb\_phys地址用于内存读写操作，完成真正的use操作。

 

当然最后这个漏洞的修补过程也比较简单，把client结构成员全部清空即可。

![](../Images/76ca50d101cfe3e91821dd4d4f97ad89.png)

  

 

写到这里漏洞分析过程就结束了，这个漏洞的利用危害，我觉得比较容易实现的一点可能是泄露一些内存信息，这个需要关联上下文深入研究，作者说可能用于提权获取root权限，我觉得还是挺麻烦的，而且需要把不太可控的读写转化成可控的读写，比较复杂，最终也有可能利用不成功，因为越是复杂的系统掺杂的噪音越多，需要排查的东西也越多。

 

**最后的一些思考：**

也是我觉得比较有意思的一点，这个漏洞的根源当然是释放的内存没有清空，但是有一个很重要点就是内核态和用户态的状态机制不同步造成的（不知道这样说对不对），比如内核返回给用户说，我判断了，你给我的信息不对，你的行为不对，我警告过你了，但是用户根本不管，我继续做我认为是正确的事情，从这里可以看出安全研究人员与开发人员对于安全风险视角的不同了，或者可以看出安全研究人员是如何定位攻击面，如何挖掘漏洞的。