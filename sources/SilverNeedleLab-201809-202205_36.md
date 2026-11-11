version="1.0" encoding="utf-8"?

# 【Android安全】Android SSL 中间人攻击原理简析

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247483729&idx=1&sn=ca0a09621c26293e5a334f844b3b9af5&chksm=fc30c60bcb474f1d6134226ae0cbd0dd42b1f48e65adbce5689078aa84910fc0c657dd94ab3d&scene=126&sessionid=1681400534#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247483729&idx=1&sn=ca0a09621c26293e5a334f844b3b9af5&chksm=fc30c60bcb474f1d6134226ae0cbd0dd42b1f48e65adbce5689078aa84910fc0c657dd94ab3d&scene=126&sessionid=1681400534#rd)

中间人攻击（MITM）

![](../Images/38708506b36e0c064f1e28a7589be8b1.png)

1、Sniff攻击者存在自签名证书，用户侧没有对服务器证书校验，会将攻击者当成合法服务器端。

2、Sniff攻击者将接受到的用户提交的数据传递给真实服务器端，服务器端并没有校验客户端，会将Sniff攻击者当做合法的用户。

即Sniff攻击者没有被真实“用户”、真实“服务器”所感知。

  

Android HTTPS 中间人劫持漏洞可以拦截、修改、增加通讯内容。

中间人攻击漏洞源于：

1、没有对SSL证书进行校验；

2、没有对域名进行校验；

3、证书颁发机构（CA）被攻击导致私钥泄露等

攻击者可以盗取账户及密码明文、聊天内容、通讯地址、电话号码、以及信用卡支付信息等敏感信息。

第三种攻击可能性极低，不在讨论范围。我们重点探讨SSL证书校验和域名校验的场景。

  

代码中哪些地方可能会出现中间人攻击漏洞？

1）X509TrustManager 

2）HostnameVerifier

3）setHostnameVerifier (X509HostnameVerifier hostnameVerifier)

  

漏洞触发前提条件？

  开发自定义X509TrustManager逻辑，不校验证书，或者校验证书存在逻辑漏洞

  或者实现的自定义HostnameVerifier不校验域名或者接受任意域名，如setHostnameVerifier(ALLOW\_ALL\_HOSTNAME\_VERIFIER)

  

失效场景1：客户端不校验SSL证书

![](../Images/98b7a6ad62c13fe131a1b1a9cdc768c0.png)

自定义的UnsafeTrustManager类接口中的checkServerTrusted()方法为空，即不检查服务器是否可信

  

失效场景2：客户端校验SSL证书逻辑存在问题

![](../Images/d9740d8be06684fc4b7c6bab0ef18b9c.png)

开发者已经注意到对证书链的有效性进行判断，不过在具体的代码实现中，出现了逻辑错误。当证书链长度为1时，就直接走到else分支了。只去调用了 checkValidity()方法了。查看官方对checkValidity方法的介绍

  

![](../Images/80c58748dd54533eb8920964cb60764e.png)

  

checkValidity只调用了证书有效期是否过期。 所以当访问攻击者伪造的自签名恶意网址（证书链长度为1），就直接校验证书有效期，其他证书内容都不再校验，就绕过了正常的证书校验逻辑了。造成了中间人攻击的漏洞。

  

失效场景3：自定义HostnameVerfier接口时，却又不检查站点域名与证书域名是否匹配，直接返回了true

![](../Images/2159d9813a2ef66eeb4edde0b4ac39f0.png)

  

失效场景4：直接使用接受任意域名的HostnameVerifier接口

![](../Images/12bf05a32bccf8f45d7d81a2238aeee6.png)

![](../Images/6f041dc8d6218b524b3d5372aaae0722.png)

应该设置为 STRICT\_HOSTNAME\_VERIFIER 模式

  

## 如何正确使用HTTPS进行通信？

  

代码1、使用Android认可的证书颁发机构颁发的证书

![](../Images/be5337b0817addde6115ff69ddd0d2a4.png)

（上面的代码是 Android官方给出的使用HttpsURLConnection API 访问https网站的示例，由Android系统校验服务器端数字证书的合法性，用可信CA签发的数字证书的网站才可以正常访问，私有CA签发的数字证书的网站无法访问）

  

如果网站没有开启HSTS，则无法抵御SSL Strip（HTTPS降级为HTTP）攻击，这个不在本文探讨范围之内

注：Android系统已经预置了150+证书，这些证书可以在 “设置”——“安全”——“受信任的凭据”中看到。

只要我们的服务器端使用的证书是从android认可的证书颁发机构购买的证书，且在android中已经内置了这些证书。就可以直接访问而无需客户端再额外设置

  

代码2：自签名——预埋公钥 （针对无法预埋证书的场景，直接预置公钥来验证）

![](../Images/e538202fb2355133809502245a29e559.png)

  

![](../Images/943b3a6cf031430e7b1818ad32a0ca97.png)

注：这里的PUB\_KEY可以自行从自签名的证书中提取，也可以加入对证书有效期的校验以及域名hostname的判断。加强校验力度

  

代码3.1：预埋证书

直接完全重新实现checkServerTrusted()方法。包含签名CA是否合法、域名是否匹配、是否自签名证书、证书是否过期

  

![](../Images/b9b4198790b2b872e2dec25c878c3202.png)

  

代码3.2：预埋证书

预埋证书，自定义TrustManager类接口，直接调用系统自带checkServerTrusted()方法来进行证书链验证

![](../Images/da701efa40a991b5f6611ee75461bec2.png)

看一下攻击效果，当受害人连接到恶意WiFi时，攻击者可以直接获取其账号和密码

![](../Images/aa307e4493c67b9edd9b01fd5a10f6d4.png)