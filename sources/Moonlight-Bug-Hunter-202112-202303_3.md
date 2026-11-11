version="1.0" encoding="utf-8"?

# Codeql 挖洞？

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU5Mzk3NTE0Mw==&mid=2247483672&idx=1&sn=faaa0e729158c1bed35baa1871694c11&chksm=fe090310c97e8a06a8ec3dace8aac276b1f6149e88796cee53e9d676703ed1cd5b8a3be29bba&scene=126&sessionid=1681657449#rd](http://mp.weixin.qq.com/s?__biz=MzU5Mzk3NTE0Mw==&mid=2247483672&idx=1&sn=faaa0e729158c1bed35baa1871694c11&chksm=fe090310c97e8a06a8ec3dace8aac276b1f6149e88796cee53e9d676703ed1cd5b8a3be29bba&scene=126&sessionid=1681657449#rd)

最近的 CVE-2021-44228 意外把 **codeql** 带🔥。CVE-2021-44228 本身从原理来看并没有太多值得说道的的地方，但是从效果和影响面来看，这个洞无疑是年度神洞，肯定能像当年破壳、Imagetragick、Fastjson 一样，影响往后辐射很多年。

  

除了因 log4j 影响的甲方业务、上游产品范围不断扩大发酵外，一个说 CVE-2021-44228 是作者用 codeql 挖出来的消息也在扩散。什么是 codeql，我的理解它是个用来做代码规范、SDL 的代码搜索引擎，挖洞属于是 Bonus Feature。  

  

我在17年第一次接触这玩意儿，那会儿还没有 codeql，只有一个在线网站 lgtm.com。因为那会儿自己也在写 tokenizer 和 parser 做类似的事情，查已经好久没用的 DFA 的资料时看到的。当时了解到的背景是这家创业公司（Semmle）是从牛津的一个实验室出来创业，出来前在实验室孵化了很多年了。试用了一下确实不错，一句话总结就是一个超强的正则表达式（用来查代码），提炼几个要点：  

1.  有使用门槛  
    
2.  代码控制粒度非常细，能控制到最基础的 expr
    
3.  适合挖特定类型的漏洞
    
4.  适合批量搞  
    

  

后来 Semmle 的历程，不确定先后顺序，大概就是推出了离线的 codeql，被 github 收购（后又被巨硬收购），中间还在 h1 上挂了一段时间，github 集成 codeql，然后当年收藏的一些 Semmle 和 lgtm.com 的很多在线链接没了？？？

  

17年基本上还停留在看 lgtm.com 的博客哇塞的程度，他们分享了很多用 lgtm.com 的挖掘漏洞的过程，有印象的一个哥们叫 Man Yue Mo，后来也跟着收购加入了 github 的安全实验室。之后一堆安全大手子加入 github 安全实验室，这东西又🔥了一下下，这期间国内基本上属于没动静或者偶尔有文档博客干干翻译的活儿。

  

20年看 CVE-2020-10199/10204 这两个洞时注意到，这个洞除了都知道的 EL 表达式执行，根本原因是使用了 hibernate-validator 的自定义约束违反消息机制，没有过滤好用户输入，导致用户可控数据流拼接到消息参数，最终造成rce。hibernate-validator官网其实有提到这个点  

![](../Images/4dcf2916bf3b9675f5ebd2d1768426b7.png)

具体到代码中是出现下面这种代码时（不考虑各种修复）极大概率出洞

*   
*   

```
ConstraintValidatorContext#disableDefaultConstraintViolation();ConstraintValidatorContext#buildConstraintViolationWithTemplate(用户输入拼接)
```

上面的代码两行实际上就是一个简单的漏洞模型，可以直接翻译成 codeql 语句。单纯到这儿，正则已经很难胜任这份工作了，但是这还没完。我随手找了另一个用了 hibernate-validator 的顶级开源项目试了下这么去找，发现误报很多，于是开始尝试优化，实际上就是增加约束。  

  

回到漏洞模型本身，当使用了`buildConstraintViolationWithTemplate`，且参数为用户可控字符串时，就会导致el表达式执行。防御方式据我所知有两种：

（1）官方推荐的`unwrap(HibernateConstraintValidatorContext.class)`  
（2）使用`ParameterMessageInterpolator`

  

为了把上述描述转换成 codeql 的 Query 代码，我还需要总结再具体一些：

1.  存在`isValid`，且`isValid`第0个参数是字符串或者包含字符串的复杂类型，比如`List`
    
2.  使用了`buildConstraintViolationWithTemplate`且参数是非const
    
3.  没有使用`unwrap(HibernateConstraintValidatorContext.class)`
    
4.  没有使用`ParameterMessageInterpolator`
    

对以上总结解释一下：

1.  如果存在用户数据流，那它必然经过`isValid`的第0个参数，而如果存在使用`buildConstraintViolationWithTemplate`的情况，也必然在名为`isValid`的重载函数中，所以第0个参数肯定只能是`String`或者包含`String`的复杂类型 ![](../Images/82570516a17972f6b1374a85bc181e71.png)
    
      
    
2.  我没有去做数据流判断，判断是否是用户可控的数据流进入到`isValid`的第0个参数，因为做不到。即我在这里放弃了部分精度，获得了准度，之后再加上人工判断来矫正偏差
    
3.  我也没有做从`isValid`第0个参数到`buildConstraintViolationWithTemplate`参数的数据流通路判断，和2原因相同
    

  

总结完模型后，剩下就是写 codeql 查询语句，这部分基础教程就不赘述，直接给出结果。

  

（1）存在`isValid`且第0个参数是字符串或者包含字符串的复杂类型

*   
*   
*   
*   

```
from Method isValidMethod, PrimitiveType primitive_typewhere isValidMethod.isPublic() and isValidMethod.getName()="isValid" andisValidMethod.getParameterType(0) != primitive_type
```

解释：排除法，尽可能排除，我这里选择`PrimitiveType`这个QL Class，主要是为了排除整型。

  

（2）存在`buildConstraintViolationWithTemplate`且参数非const

*   
*   
*   

```
from MethodAccess call2Rcewhere call2Rce.getMethod().getQualifiedName() = "ConstraintValidatorContext.buildConstraintViolationWithTemplate" andnot call2Rce.getArgument(0).isCompileTimeConstant()
```

解释：很直观，无需解释

  

（3）没有使用`unwrap(HibernateConstraintValidatorContext.class)`

*   

```

```

解释：只要使用，不考虑语境

  

（4）没有使用`ParameterMessageInterpolator`

*   
*   

```
from ImportType import_typewhere import_type.getImportedType().getQualifiedName() = "org.hibernate.validator.messageinterpolation.ParameterMessageInterpolator"
```

解释：为了简化query，只要出现`import org.hibernate.validator.messageinterpolation.ParameterMessageInterpolator`，就认为有意识在做防御

  

以上组合形成最终的 query 语句：

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
import java
from Method isValidMethod, PrimitiveType primitive_type, MethodAccess call2Rce, ImportType import_typewhere isValidMethod.isPublic() and isValidMethod.getName()="isValid" andisValidMethod.getParameterType(0) != primitive_type and
call2Rce.getMethod().getQualifiedName() = "ConstraintValidatorContext.buildConstraintViolationWithTemplate" andnot call2Rce.getArgument(0).isCompileTimeConstant() and
not exists(MethodAccess unwrap_call| unwrap_call.getMethod().getName() = "unwrap" and unwrap_call.getArgument(0).toString() = "HibernateConstraintValidatorContext.class") and
import_type.getImportedType().getQualifiedName() = "org.hibernate.validator.messageinterpolation.ParameterMessageInterpolator"
select "Possible RCE caused by hibernate-validator", call2Rce, call2Rce.getFile()
```

  

本来信心满满地准备用这个 query 去整他喵一个排的 Rce，结果发现基本上有点名气符合条件的开源项目最近都修了这个问题，然后去翻 github 安全实验室的博客，发现已经被人干完了。。。

![](../Images/b1a2bc08f8a2f2734e3d163206558b23.png)

这个 id 很熟悉吧 。。。

  

然而最终通过批量手段我还是找到一个漏网之鱼：  

https://github.com/strongbox/strongbox

  

它的查询结果去重后也就三处：  

![](../Images/f1af93fbd2593003809d3dc1a6a9a74d.png)

然后很容易的就 Rce 了。

  

问题提交给项目方后很快就答复我修复了，参考

https://github.com/strongbox/strongbox/pull/1833

  

最后总结下：不管是之前的 lgtm.com 还是现在的 codeql，是我接触这个领域以来遇到最酷的产品。没自己写过 DFA 去做词法、语法解析的人不知道这个事儿有多繁琐，他们在此基础上还做了一层封装方便查询。好用但是也没那么好用，效果取决于规则 writer 本身的能力，就这。