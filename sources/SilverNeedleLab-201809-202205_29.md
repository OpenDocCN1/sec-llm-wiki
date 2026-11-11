version="1.0" encoding="utf-8"?

# 攻城狮的游戏打开方式|DEX脱壳技术学习笔记

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247483785&idx=1&sn=1897ef0966b3ef8784b138b76086d076&chksm=fc30c6d3cb474fc55db31c033276adf165d1dd2c7a5c1803bc365057330f10d883be8b436ccc&scene=126&sessionid=1681400529#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247483785&idx=1&sn=1897ef0966b3ef8784b138b76086d076&chksm=fc30c6d3cb474fc55db31c033276adf165d1dd2c7a5c1803bc365057330f10d883be8b436ccc&scene=126&sessionid=1681400529#rd)

  

  
  

不能把游戏玩出花儿来的程序员不是好技术宅

  
  

**//**  

** 01· **

**  起因**

  
最近在steam买了一个游戏，玩了一下发现这游戏几乎全是文字描述，界面简陋，可玩性就在于考究的文字描述及情节设计。这让我不禁想起高中时期用过的文曲星NC1020，以及很多人记忆中的那款经典游戏。

网络搜索一番发现游戏公司并没有继续开发这个IP，但游戏爱好者们开发了好多版本，其中最受欢迎的就是这款。该游戏在保持原游戏汁味的基础上，又增加了很多新门派、新招式和新剧情，整体非常优秀。游戏中人物武功需要不断刷刷刷进行升级，周末玩了一整天发现其实很肝。在游戏探索的过程中，我体内技术宅的能量蠢蠢欲动。作为安卓领域的初学者，我就从这款游戏下手来学习安卓DEX脱壳和重打包技术吧。

  

![](../Images/4ea75e308d305e4b79e5405bcc801ef8.png)

  

  

** 02· **

**  游戏分析**

  
下载最新版本，使用JEB打开，先看manifest：![](../Images/9a3937be16f7660c6a5658c4799ee2d7.png)

  

直接找lostland.gmud.exv2.AndroidLauncher，没有找到，反而在MyWrapperProxyApplication中发现如下代码：![](../Images/902733842b5246bf20df6c507c48d172.png)

  

Util.libname = Util.CPUABI == "x86"  "libshellx-super.2019.so" : "shell-super.2019";

对于我这个安卓初学者来说，这种情况还是第一次遇到，直接搜索一下libshellx-super.2019.so、libshell-super就发现了乐固加固相关的资料了。原来是加壳用的so，IDA打开定位到JNI\_OnLoad，发现代码有一点OLLVM小混淆：![](../Images/5785b216ec119fd67ded34e78ae07dc6.png)通过搜索来的资料结合上面代码，可以确定这个加固原理就是将程序原始的字节码文件加密放到APK源目录下，程序运行时先通过加载libshellx-super.2019.so运行native代码解密原始字节码并跳转执行。重点防御的逻辑自然都在so中实施了，包括各种混淆、各种反调试、hooklibc函数等等。按照LINUX二进制逆向的常规思路，接下来的硬核做法就是过混淆、过反调试，一路撸到还原真实dex要跳转的地方将它从内存dump出来，实现将加固方案踩在脚下无情蹂躏。但安卓毕竟是安卓，它是一个全新的操作系统，不要老是拿它当linux的小弟一样看待，可以用更安卓一点方法来解决。LINUX二进制程序加壳后，必然会有一个解壳然后跳转新入口点过程，如果自定义一个ld（加载器，用来加载运行ELF）识别到新入口点的时候就把真实代码DUMP出来，就完成脱壳了。安卓的dex一定要交给解释器去执行的，所以同样思路，修改安卓davilk解释器加载dex的代码实现DUMP就可以了，这样无论加固策略有多么复杂，只要是加固dex，这种办法基本就可以通杀了。不知道是不是Google有意为之，各个版本通过加载dex的机制都有不同，相应的脱壳方案也就不同了，相同的是都需要一台ROOT手机。

  

网上搜集到此思路下的脱壳方案如下：

1、DexExtractor

https://github.com/lambdalang/DexExtractor2014年提出，限制安卓版本4.4，对当时的梆梆加固有效，使用者需要通过AOSP修改并编译代码，然后在虚拟机或手机中替换掉系统/system/lib/libdvm.so。在国内AOSP编译是种折磨，好在作者提供了他编译好的库。  

2、DexHunter

https://bbs.pediy.com/thread-203776.htm2015年HITCON上提出，限制安卓版本也是4.4，可以通杀当时几乎所有加固方案。这个方案相对比较复杂，仍然要修改编译AOSP源码。  

3、android\_unpacker

https://github.com/CheckPointSW/android\_unpackerDEF CON 25 (2017)上提出，作者演示版本为安卓6.0，也是可以通杀当时的主流加固方案。仍然要编译修改AOSP源码。有人安卓7.0上也应用成功

https://www.freebuf.com/articles/terminal/166307.html

  

4、反射大师

仅支持安卓8.0以下。从此开始修改AOSP源码已经过时，XPOSED的诞生改写了历史。这是一个XPOSED模块，HOOK代码要比修改AOSP编译刷机不知道高明多少了。

  

5、dumpDex

https://github.com/WrBug/dumpDexhttp://liteng1220.com/blog/articles/dumpdex-principle/

同样为XPOSED模块，这款应该是支持到安卓9.0，通杀主流加固方案。

  

6、其他

有XPOSED就有frida啊，功能都差不多，但现在frida还在更新，XPOSED框架很久没更新了。https://github.com/dstmath/frida-unpack时至2020年，对DEX加固这种高(zhuo)明(lie)手段已经逐渐被弃用了，防破解还得靠应用市场签名体系对开发者的管控。

**//**  

** 03· **

**  修改存档**

  
列举了上面一堆脱壳方案，我甚至已经忘记了正题。脱壳方案肯定是系统版本越低越稳定，就像栈溢出当年没cookie没NX的时候一样。我实际测试了一下，这款游戏最低支持到安卓5，所以我选择了一个最无脑简单的方案：反射大师。

准备工作：

1、拿出Nexus 6P刷回原生安卓6.0

2、安装XPOSED框架

3、安装Magisk实现ROOT

4、安装反射大师

反射大师的使用非常简单，选择游戏并开始运行后，直接选择dex dump按钮就好，生成的dex文件就在程序data/lostland.gmud.exv2/dump下面。接下来就想办法修改游戏了，其实我一开始并没有想好要怎么修改，修改脱壳后的代码需要重新加密放回去，直到我看到如下代码：

lostland.gmud.exv2.SavingScreen

![](../Images/abf9451ed48316ae5e0bb8a9848d0a04.png)这是存档的代码，继续跟进加密函数![](../Images/b63b7d58087e895d4c38e3d75b20850f.png)唉，罢了，固定密钥加密，私人开发组的产品终究还是没那么健全。接下来我通过adb获取SharedPerference XML文件：

![](../Images/ba4bcdbbc614cf5bcf805c3be139cf09.png)

GmudII/save.dat就是密文，解密之一个Json结构就出现了

![](../Images/eddfbfbb8eb3a750f939773dac1e8732.png)

这个文件里的东西没有什么不能改的，装备、技能等等统统在这里。为了不影响可玩性，我仅修改了mc.gold（金钱）、mc.exp（经验）和mc.potential（潜能），这样就大大缩短了重复劳动的时间了。将修改后的JSON文件加密再改回到XML文件中，adb shell复制回去，加载游戏，测试成功。为了让不ROOT的手机也能玩，这时候就需要修改smali代码并重打包了，这个APK没有特殊的校验手段，重新签名即可安装游玩。游戏解壳执行真实DEX后，首先会去查找是否有存档，如果有存档就继续游戏，否则就创建角色。因此只要在解壳的代码中插入一段写存档的代码，就实现内置了一个游戏存档，完成修改。smali代码和汇编相比起来，还是非常容易看懂的。我使用android studio编译如下代码：

![](../Images/d41ee868ec8a2bca10a7cf54aabfce27.png)

Java2smali的插件太难用，经常出错，还不如编译成APK再JEB打开来得简单。使用apktool解包游戏APK，要把代码插到initProxyApplication函数![](../Images/5ab949ecbf31335fe72c011f2d092203.png)直接找MyWrapperProxyApplication.smali编辑就行了，这都比修改汇编要简单得多，完全不需要考虑空间的问题

![](../Images/8e123d6d254e38d9a509dad91f83b76f.png)

直接复制过去，注意修改一下ctx参数寄存器，这里是p1，原来方法是static的所以是p0。apktool打包，再使用jadx逆向校验一下

![](../Images/6f2670a6c88748c5b81073017fb46044.png)

确认无误，重签名，把原程序卸载，安装修改版本验证。

![](../Images/aafd9d6babbdeb31b7f4d872647c6229.png)

搞定！

  

![](../Images/dbf8883d0cc63239de68eac72e091999.png)

  

●点击屏幕上方蓝字 关注我们 ●