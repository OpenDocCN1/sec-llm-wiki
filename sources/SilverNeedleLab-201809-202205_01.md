version="1.0" encoding="utf-8"?

# BIG-IP(CVE-2022-1388)从修复方案分析出exp

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247485499&idx=1&sn=ff970b44888e1e52f36a4344f17dad04&chksm=fc30cf61cb4746776060e05114d7498e494b285e6bc49539dab304bea72d44c093dd2418c14a&scene=126&sessionid=1681400517#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247485499&idx=1&sn=ff970b44888e1e52f36a4344f17dad04&chksm=fc30cf61cb4746776060e05114d7498e494b285e6bc49539dab304bea72d44c093dd2418c14a&scene=126&sessionid=1681400517#rd)

1 漏洞详情

 根据官方漏洞通报，BIG-IP iControl REST接口存在一个认证漏洞，绕过认证后可调用后端接口执行任意命令，影响版本较广，参考：

*https://support.f5.com/csp/article/K23605346*

![](../Images/2b5b01258a1f79ba2de228a83b409deb.png)

 上一个漏洞CVE-2021-22986影响的接口也是 iControl REST接口，推测CVE-2022-1388是针对此漏洞修复的绕过，CVE-2021-22986的payload如下：

![](../Images/dfccabf22ca29676edf3a4b646e2c66b.png)

  

2 修复方案分析  

  攻击poc/exp暂未公开，尝试下手分析一波，由于BIG-IP源码未公开，因此无法通过diff新旧代码定位漏洞触发点，唯一的线索只有官方给出的手动修复方案：

![](../Images/7dd47e7c7d0021f10367bc2b7600a123.png)

   修复方式里建议对配置文件进行修改，包含三个判断逻辑，即对Connection这个header头进行set设置，查一下RFC官方文档对set方法的约定：

*https://httpd.apache.org/docs/current/mod/mod\_headers.html#requestheader*

![](../Images/b18722ccbcd9d1f5ac5bc7712306646d.png)

  根据文档，set方法的作用为，假使发现请求头里存在**foo：a**，则set foo b会将header值变为：**foo：b**，修复方案是对Connection这个头进重新赋值，到这基本可以确定漏洞绕过点就存在于Connection请求头中。

 所以问题来了，和Connection头有关的漏洞有哪些？

  

**1) HTTP request smuggling**

   HTTP请求走私漏洞，和持久化连接相关，根因为管道化连接pipeline，HTTP规范提供了两种不同的方法来指定请求的结束位置（Content-Length/Transfer-Encoding）,因此判断和此漏洞无关。

![](../Images/bb87c5cb2d1faab3b91b74f7243443cd.png)

**2) hop-by-hop headers abuse**  

  逐跳（hop-by-hop）请求头滥用是个较为生僻的漏洞，关于此漏洞可参考文章：

*https://nathandavison.com/blog/abusing-http-hop-by-hop-request-headers*

 按解析方式，http请求头有两种，逐跳请求头和端对端请求头，参考：

*https://datatracker.ietf.org/doc/html/rfc2616#section-13.5.1*

![](../Images/a08e240367758b5c6ee03ea6e972f17f.png)

   顾名思义，逐跳的意思为，当在请求中遇到这些header头时，每一跳的代理（proxy）应该对这些header进行处理，而不将它们转发到下一跳。

 如我们的请求中带有header头：**Connection: close, X-Foo, X-Bar**，原始请求在转发到代理时，逐跳处理则会将X-Foo和 X-Bar从原始请求中删除。

 利用逐跳请求头的这种特性，可以实现删除任意已有header：

![](../Images/7a28bf8efee06a1bc5b03de8941532de.png)

   原作者提出了多种利用思路，包括：删除XFF头隐藏IP、缓存中毒DoS、SSRF、绕过WAF等。

  

3） 历史CVE分析  

 根据关键字搜了一下，hop-by-hop headers abuse在几个漏洞中有利用，比如CVE-2021-32813：

![](../Images/85e52d46b2e105458135b16e4ec1d0bd.png)

 header头被删除导致的权限提升，再看下漏洞的修复方案：

*https://github.com/traefik/traefik/pull/8319/commits/cbaf86a93014a969b8accf39301932c17d0d73f9*

![](../Images/ad7b8cfc7c07fd09e2b9ef743144a4ab.png)

  熟悉的Header.set操作，删除Connection头中列举的hop-by-hop头。

 又如下面的例子，将包含关键鉴权信息的header添加到Connection中以完成权限绕过：

*   *https://github.com/clastix/capsule-proxy/issues/188*
    
*   *https://github.com/rancher/rancher/security/advisories/GHSA-pvxj-25m6-7vqr*
    

![](../Images/bd35469871cc62241a943271628a79dd.png)

 到此几乎可以确定，CVE-2022-1388就是使用Connection头中包含hop-by-hop头来绕过鉴权。

# 3 漏洞复现

 环境搭建，下载F5官网BIG-IP虚拟镜像安装：

![](../Images/adf1507c87da17fdaabc3ad95dcc284b.png)

  访问web登录页，构造payload验证上述推断：

![](../Images/886bbef899eade7652598240d7d2bceb.png)

   这里先回顾下CVE-2021-22986，思路为先通过/mgmt/shared/authn/login 接口的SSRF漏洞获取到凭证X-F5-Auth-Token头，然后访问/mgmt/tm/util/bash接口执行任意命令：

![](../Images/c8b29069f4eeddbe0961d30c878531bd.png)

  而CVE-2022-1388的区别在于，不必获取这个X-F5-Auth-Token头，而是将Connection头设置为畸形的hop-by-hop头，即Connection: Keep-alive,X-F5-Auth-Token，BIG-IP的鉴权过程发生在frontend，在后续转发到Jetty时会将此header删除，从而绕过鉴权：

![](../Images/3a87e3cbb7c622e5ef088dd1c44d28d5.png)

  至于BIG-IP后端具体的处理逻辑，还需要深入代码层分析，这里留个坑。本文也主要是提供一个从修复方案到复现oday/1day漏洞的推断和分析思路。