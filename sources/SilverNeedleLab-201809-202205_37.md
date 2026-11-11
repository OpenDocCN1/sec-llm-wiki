version="1.0" encoding="utf-8"?

# AddJavaScriptInterface接口会给Android应用带来哪些安全风险？

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247483709&idx=1&sn=3f8d744371ecb662e404e175bed657bc&chksm=fc30c667cb474f7154b845beaf59fb85cc5d1d314892a3d8a147967ec6b0f1574a2a1328d963&scene=126&sessionid=1681400534#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247483709&idx=1&sn=3f8d744371ecb662e404e175bed657bc&chksm=fc30c667cb474f7154b845beaf59fb85cc5d1d314892a3d8a147967ec6b0f1574a2a1328d963&scene=126&sessionid=1681400534#rd)

Webview 是移动端应用中的一个控件，提供了可以在APP中加载网页的功能，为了能够完成端侧和HTML页面的交互，引入了addJavaScriptInterface功能。  
addJavaScriptInterface 可以将原生的java方法，暴露给javascript，供javascript侧来调用。  
这是一个非常有用的功能，可以帮助我们将一个网页传值到Android视图，也可以将Android视图的值传递到HTML网页上展示，非常的灵活方便，但是当WebView中的HTML是不可信赖的时候，则是一个非常危险的安全问题，因为那些本来需要暴露的接口信息，可能被暴露一个攻击者。  
  
Android 4.2之后提供了@JavascriptInterface对象注释的方式建立Javascript对象和android原生对象的绑定,提供给JavaScript调用的方法必须带有@JavascriptInterface。  
  
Android端的定义了一个 AndroidToast类，show方法设置了JavascriptInterface注解。即可以被暴露给远程或本地的Javascript

  

![](../Images/fb1184cc3df69b45d7863f3b710b4662.png)

  

再对webview进行设置

  

![](../Images/7169affef6c58f13468f059c779ff5dc.png)

  

addJavascriptInterface的作用是把AndroidToast类映射为Javascript中的Toast\_XXX。这个Toast\_XXX 可以理解为是这个类的别名了，在Javascript上调用Toast\_XXX，即访问了AndroidToast这个类了。addJavaScriptInterface就自然而然的成为了Javascript世界和java世界联接的桥梁作用了。  
  

再看看html中javascript是如何调用java代码的

  

![](../Images/3577944067f6e2fb75b47eb58b2972be.png)

  

通过window属性可以找到addJavascriptInterface映射的对象AndroidToast,直接调用它的show方法即可。

以上内容其实是在讲述addJavascriptInterface功能的作用，但是这里明显存在安全风险的。  
我们看到 loadUrl 是可以加载本地html，也可以加载远程url的。  
webView.**loadUrl**("file:///android\_asset/index.html");  
  
这里的url是否是应用可控的？如果被控制者控制又会存在什么样的安全风险？  
  
我们上面例子中，javascript层可以直接访问 AndroiToast类中的show方法，这个方法没有什么功能，可以不用在意，如果我们的应用代码中存在这样被暴露的接口呢？

  

![](../Images/cef2a7afc1341827e4c1936c87e36da2.png)

  

这类的java类方法是非常敏感的，一旦被泄露给其他恶意的第三方攻击者，后果是不能接受的。

现在回头来看上面的问题，URL一旦应用不可控，会造成严重的后果。  
  
案例1：某款应用没有校验域名，导致URL可以被外部攻击者所控制，攻击者可以获取大量用户敏感信息

  

![](../Images/51dc8c73241615beb9af5bcc0eadfd4a.png)

  

案例2：某款应用对域名进行了判断，但是校验的方法存在漏洞，攻击者精心构造payload，即可绕过其域名校验，获取敏感信息。

  

![](../Images/437563a71ffa5b8ae5de2b0ca774ba5c.png)![](../Images/0e10b08d5832d9b4d6a6012bc32c366f.png)

  

set集合中限定了4个域名，不过在校验时，使用了indexof来判断当前的url**是否包含**集合中的域名，包含其中一个就算通过校验了。  
  
攻击payload：**http://www.hacker.com/evil.htm#huawei.com**  
  
  

案例3：某款应用使用了正则表达式来校验当前的域名是否是业务可控的

![](../Images/0ff2247bc390583cdca6fbea12f28e06.png)

![](../Images/f613d5042423eaa26a6a3585b5b8f703.png)

这种方法是我们比较推荐的，在校验URL合法性时，一定要使用强校验策略。要么在代码中直接硬编码所要加载的url链接，要么使用正则表达式严格匹配白名单，任何逻辑上的缺陷，都可能会导致白名单校验失效。建议产品排查所有的能够从外部传入URL链接的风险点，再逐一排查URL的校验逻辑，是否存在白名单被绕过的可能性。