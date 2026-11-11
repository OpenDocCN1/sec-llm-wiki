version="1.0" encoding="utf-8"?

# 巧用frida快速破解Android类CTF题目

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247483940&idx=1&sn=31f5121753eb3784e1d9980fdd9d3919&chksm=fc30c57ecb474c68433996d2e448780b40d68303eaa28c93a554b0f59188125d8a93930d5a87&scene=126&sessionid=1681400524#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247483940&idx=1&sn=31f5121753eb3784e1d9980fdd9d3919&chksm=fc30c57ecb474c68433996d2e448780b40d68303eaa28c93a554b0f59188125d8a93930d5a87&scene=126&sessionid=1681400524#rd)

在现在的CTF比赛赛制中，前三名解出题目的队伍都会有额外加分，如何快速的解出问题，对于参赛选手来说至关重要。因为往往就是一分之差，淘汰多支队伍。

 

我们以最近一道CTF 安卓题目为例，利用frida工具我们拿到了二血，今天我来分享一下，如何快速的capture apk’s flag

 

首先jeb来加载hw02.apk，jeb工具可自行下载

 

这里可以根据Manifest来分析出apk的主入口activity，这里是MainActivity

![](../Images/c0487ce4769f7f890d796179644eddb9.png)

Input 变量为用户的输入，从上图代码所示，判断input输入的字符串格式 “flag{”开头 ， “}” 结尾。字符串长度不能低于10。否则会报错 tryagain~ 或者 flag format error ~

 

重点逻辑在  this.checkFlag 这个native函数，它的处理逻辑在so层，输入的参数就是 flag{xxx}中间的那坨xxx。

 

 

将apk解压缩，发现有两个架构的so文件，我们的测试机是64位的，那就从arm64-v8a里获取so吧

![](../Images/6af4e71ae7085df9a52443e3acd09afe.png)

使用ida工具来分析libcheckflag.so文件

看到init\_array 有初始化的过程

![](../Images/27ce479fe64e85f3cafe4fac5a7cffc7.png)

![](../Images/5798d8bb8170d9b62cf2d5d94f7346ba.png)

这里会修改.bss段变量的值。暂时不管。

![](../Images/900e095412b79ddfea9395cacf81f766.png)

JNI\_OnLoad 函数对 checkFlag函数进行动态注册了

![](../Images/0a9ca4e83c1c640e8b44407095e0f21e.png)

主要的逻辑在于这里sub\_DD78函数了

![](../Images/8a5f9c4decd1c6172076718201ec3087.png)

看第一个箭头，v13代表字符串的长度，这里v13 长度需要超过15，低于15长度就直接退出了。

 

第二个箭头处Sub\_DFC8是干嘛的？跟进去

![](../Images/81497c0db04fbc58b346a1a659361c76.png)

GetStringUTFChars是将java层传入的jstring转化为char\*, 这里我们简单的理解就是获取用户输入的字符串的。我们知道GetStringUTFChars有三个参数，这里ida对函数优化之后，没有显示任何参数。右键选择”Force call type”，就可以看到三个参数了。

![](../Images/78b4e303880f23fdcdb93a12dd28e56b.png)

接下来，我们只需要关注下面的三个重要的函数，经过这三个函数的运算之后，会产生一个新的值，固定值"bb4ME6An/z82AwX5r0FXgwJwzp3JaFgW7JtmKc4T9Q=="进行strcmp对比。相同就可以返回true了

  

sub\_E018 我们来看一下函数内部逻辑

![](../Images/119acd51cd0907fcfc176ef9f1433669.png)

sub\_E56C

![](../Images/556a668588a9ed6d4fc8429dd3e0bad6.png)

sub\_E7F8 这个函数巨复杂，直接分析变得不可能且会耗费大量的时间

![](../Images/01d2ce7c9e05cca43ab7417503a79fe6.png)

综上所述，这三个函数内部逻辑都很复杂，如果直接去逆推，需要花很长时间，这里我们采用frida工具来帮助我们快速的解题。

 

Hook函数实现代码

**var** libhm  = Process.findModuleByName("libcheckflag.so");

        **if**(libhm != **undefined**)

        {

             **var** modulebase = libhm.base;

             console.log("base:"+modulebase);

             **var** sub\_E018 = modulebase.add(0xE018);

             **var** sub\_E56C = modulebase.add(0xE56C);

             **var** sub\_E7F8 = modulebase.add(0xE7F8);

             

            Interceptor.attach(sub\_E018,{

                   onEnter: **function**(args){

                       //console.log(Memory.readCString(args\[0\]));

                   },

               onLeave: **function**(retval){

                   //console.log("retval:"+retval);

                   //Memory.readUtf8String(retval);

                   //retval.replace(1)

                   }

               });

              

               Interceptor.attach(sub\_E56C,{

                   onEnter: **function**(args){

                       //console.log(Memory.readCString(args\[0\]));

                   },

              

               onLeave: **function**(retval){

                   //console.log("retval:"+retval);

                   //Memory.readUtf8String(retval);

                   //retval.replace(1)

                   }

               });

               Interceptor.attach(sub\_E7F8,{

                   onEnter: **function**(args){

                       //console.log(Memory.readCString(args\[0\]));

                   },

               onLeave: **function**(retval){

                   console.log("retval:"+retval);

                   **var** data = Memory.readUtf8String(retval);

               var result = “bb4ME6An/z82AwX5r0FXgwJwzp3JaFgW7JtmKc4T9Q==”;

 

                   var index= **(round-1) \*4;**

                   var result1 =result.substring(index,index+4);

                   **if**(data.substring(index,index+4) == result1)

                   {

               console.log("\[+\]Found:"+Memory.readUtf8String(retval));

                   }

                   //retval.replace(1)

                   }

               });

}

 

Frida hook了这些关键的函数之后，我们就可以看到函数的输入参数，和输出结果。

我们尝试输入不同的字符来看输出情况

最终得出结论：Input输入的字符长度，除去flag{} 之外有31位时，计算出的结果才和

bb4M E6An /z82 AwX5 r0FX gwJw zp3J aFgW7Jtm Kc4 T9Q== 一样长，这个长度是线性增加的，可以采用爆破的方法。而且每输入3个字符，对应输出结果的4个字符。

 

所以我们先找第一个三字符   xyz  对应  bb4M

第二组 三字符 xyz 对应E6An ，那这里我们以第二组为例，第一组我们爆破出来为qeo

注意上面hook函数中的var index = (round-1)\*4;这里的round对应的是第几组。

 

爆破函数实现代码

**var** MainActivity$1= Java.use("com.ssj.hw02.MainActivity$1");

    **var** MainActivity = Java.use("com.ssj.hw02.MainActivity");

    **var** ma = MainActivity.$new()

        MainActivity$1.onClick.implementation =**function**(){

            **for**(**var** j =0; j <pool.length; j++)

                {

                **for**(**var** i =0; i <pool.length; i++)

                    {

                       **for**(**var** k =0; k <pool.length; k++)

                       {

                       **var** data = "qeo"+pool\[j\]+pool\[i\]+pool\[k\]+"1111111111111111111111111";

                       console.log(data);

                       ma.checkFlag(data);

                       }

                    }

                }

        }

![](../Images/f0578dc1180d58ddc7651a2ac691b871.png)

这样就可以知道第二轮的3字符为irk

我们再重新设置爆破函数中的变量  var data = "qeoirk"+pool\[j\]+pool\[i\]+pool\[k\]+"1111111111111111111111";

将hook函数中的round=3

以此类推，将所有的字符全部猜解出。

 

qeoirklnxcvxfgiefhdweruoulksdnm

最终提交的flag为 flag{ qeoirklnxcvxfgiefhdweruoulksdnm}

 

这样就可以快速的爆破出所有的字符了，省去了大量的中间逆向和逻辑细节了，帮助你快速破解此类题目。