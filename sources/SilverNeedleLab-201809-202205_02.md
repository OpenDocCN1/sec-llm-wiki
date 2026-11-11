version="1.0" encoding="utf-8"?

# 从一道CTF浅尝V8源码

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247485480&idx=1&sn=491447f8926752da74ab68f2c1627268&chksm=fc30cf72cb474664ef837ad1abb0f0bbff12bddc5b9cba00ce3317b8a184d3be86566c15f177&scene=126&sessionid=1681400517#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247485480&idx=1&sn=491447f8926752da74ab68f2c1627268&chksm=fc30cf72cb474664ef837ad1abb0f0bbff12bddc5b9cba00ce3317b8a184d3be86566c15f177&scene=126&sessionid=1681400517#rd)

## 目录

* * *

#### 1.GoogleCTF 2018 - Pwn Just-In-Time

#### 2.调试环境环境搭建

#### 3.题目漏洞分析

#### 4.从失败的POC读V8

#### 5.Exploit

#### 参考

* * *

## 正文

作为刚接触浏览器安全的初学者，我个人选择了从CTF来入手浏览器的漏洞模式和利用姿势，最近看了若干历史的浏览器类题目，印象比较深的是GoogleCTF的题目Pwn just in time，另一个是34C3 CTF的V9，分别涵盖了V8 TurboFan中的两个优化阶段`TyperLowering`和`RedundancyElimination`，由于某些错误导致的`CheckBounds`和`CheckMap`守卫分别被优化而造成的数组越界和类型混淆问题。这里分享一篇个人调试Pwn just in time的记录，后续有时间再整理另一篇34C3 CTF的V9的调试记录，涉及另一部分优化代码和漏洞模式。这篇也是笔者第一次阅读调试V8代码，虽然查阅了许多资料，但肯定有理解不足或错误的地方还请包涵指正。

## Pwn Just-In-Time

题目链接：  
https://ctftime.org/task/6982  
https://github.com/google/google-ctf/tree/master/2018/finals/pwn-just-in-time/

题目给出了两个patch文件，分别关闭了浏览器的sandbox和引入一个优化阶段的漏洞。

## 环境搭建

调试环境选择了在Visual Studio下，因为我觉得第一次调试肯定会是不断查看各种对象和结构体信息的过程。如下编译windows下的debug版本V8

```

```

## 补丁分析

看一下题目给的补丁

```

```

在`TyperLowering`中增加了一个新的裁剪器`DuplicateAdditionReducer`，我对补丁中做了一些注释信息：

```

```

根据补丁信息，是对`sea of nodes`中当前op为`kNumberAdd`的node，做了如下4种情况的判断（图片来自Introduction to TurboFan）：  

![](../Images/68a932de06ac338ccfcbba371d65b255.png)

当node通过了上述的4种条件的检查，则对状态4的图做如下优化  

![](../Images/91611994bef17cfe67e7e07eaf2bac52.png)

综上，其实是做了一种类似如下的优化

```

```

看似是合法的加法结合顺序的调整，其实引入了浮点数IEEE754编码的精度丢失问题，最终导致了代码执行。

## 漏洞分析

在d8 shell执行如下代码，可以清晰的看到精度丢失的问题

```

```

### IEEE-754编码浮点数精度丢失

IEEE-754编码图示  

![](../Images/30ad8d7361f508776f69f853ac408efa.png)

V8使用IEEE-754编码浮点数，这意味着一个数字只有低52bit是用来作为value编码，因此ieee-754的最大值为`pow(2, 53) - 1 = 9007199254740991`。比这个数值大将会导致精度丢失，如上面在d8 shell中执行的一致。

我们分析一下导致精度丢失的原因。64bit的IEEE-754包括1bit的sign符号位，11bit的exponent指数位，52bit的fraction尾数位。计算IEEE-754数值的value，遵循以下公式

```

```

遵循公式分别计算一下MAX\_SAFE\_INTEGER，+1，+2，三个数值的内存如下

```

```

![](../Images/fb7f18b1236ccf84c19f9a6d8fe1a8b2.png)

最后计算value，可以使用网站(见参考3, 4, 5)计算如下算式  

![](../Images/b70f4038a0fbf255941b37a8a98d47e8.png)

综上，IEEE-754编码存在精度丢失问题，不能表示`9007199254740993`等，所以存在本节开始的d8 shell中执行的问题。

### 题目漏洞

那么结合题目中给出的补丁，会存在如下图示bug  

![](../Images/ec38db6e64e4535e44188cbc76dfad7d.png)

另外，新增的reducer不会更新改变的node的type，导致change后的node的type range仍为之前typer phase计算的(9007199254740992,9007199254740992)，而非reducer后导致的node的range实际为(9007199254740994,9007199254740994)。

## 从失败的POC分析V8源码

Add计算的结果9007199254740994比typer phase计算的range的最大值9007199254740992要大，下面的问题是怎么利用这个bug消除掉CheckBounds的检查？  
可以通过typer phase计算的range和数组的length比较，恒为真来消除CheckBounds结点。

这一块踩了很多的坑，因为开始不了解V8里对象的内存存储结构，比如`in-line` `out-of-line` `descriptor`等，也不了解v8的优化规则，后续也是查阅了很多资料，才勉强构造出类似如下的，但还是失败的poc，透过分析这个失败的poc的原因，笔者记录一下"被迫"调试分析一波v8源码的过程

```

```

构造如上代码，开始笔者的想法是`typer phase`阶段计算出行5 `y`的`range(1,1)`，所以可以优化掉`checkbounds`，而因为`typer lowering`阶段引入的bug导致`y`实际是`range(2,3)`从而导致越界。  
但实际执行最后print的结构都是`1.2`：(  

![](../Images/b995b1b6c64c7e6a460ee6abc86b3d6c.png)

#### （1）JIT入口代码浅析

最先引起我怀疑的是并没有执行到DuplicateAdditionReducer裁剪器。补丁中优化器的添加位置在src/compiler/pipeline.cc的1324行，位于`struct TypedLoweringPhase{}`中，由1981行的`bool PipelineImpl::CreateGraph(){}`调用。在整个CreateGraph函数中，会运行v8的多种phase

```

```

继续向上梳理数据流，找到调用位置在880行

```

```

继续向上src/compiler.cc

```

```

再向上会发现存在多条调用路径，所以我们在`OptimizedCompilationJob::PrepareJob`下个断点看一下调用栈  

![](../Images/f5617885c8d0870f71fa5e47bc5845c4.png)

上图中能看到的顶层函数是`v8.dll!v8::internal::Runtime_CompileOptimized_NotConcurrent`,大概意思是非并行执行编译优化的运行时函数。调用在类似如下的文件中

```

```

从文件名大概猜到是JIT代码的文件，顺手搜了下还有那些compiler文件  

![](../Images/26a2c4cdbf9954f51091ad57c4bebeb3.png)

回到`runtime-compiler.cc`，有如下运行时函数，有上面断点的入口函数`Runtime_CompileOptimized_NotConcurrent`

```

```

关于`Runtime_CompileOptimized_NotConcurrent`和`Runtime_CompileOptimized_Concurrent`笔者都有大概走读一遍，逻辑没有很大的区别。这里挑了`Runtime_CompileOptimized_Concurrent`记录一下走读分析

```

```

跟入`GetOptimizedCode`

```

```

继续跟读`GetOptimizedCodeLater`

```

```

#### （2）GraphBuilderPhase

如上的代码走读，找到了构造`sea of nodes`的入口`GraphBuilderPhase`，位于`PipelineImpl::CreateGraph()`中第一个调用的phase，为TurboFan优化的入口phase，从其phase_name()和构造函数大概理解到其功能是将“上层”传入的bytecodes转换为`sea of nodes`的`IR`图

```

```

跟入graph\_builder.CreateGraph()，`SetStart`和`SetEnd`分别设置Graph中的成员变量`_start`和`_end`，即为sea of nodes中的start 和 end结点，这个在后续的phase中会用到。这里生成start和end结点的参数一个是`common()->Start(actual_parameter_count)`（这个参数个数+4是哪几个内置参数我没去追代码了），另一个是`common()->End(input_count), input_count, inputs`，其中，这里的input_count表示了其父节点的个数，inputs表示其父节点的结构体  

![](../Images/3e0f0b296031db2fba3e2866516c62bb.png)

通过调试我们看到其父节点的opcode为return，正如sea of nodes所示  

![](../Images/20cd01931ee68627a71b59016b4653e4.png)

代码中间的`VisitBytecodes()`会循环遍历bytecode指令，调用对应的指令node生成函数，生成对应的node

```

```

如下是poc中opt\_me函数的bytecode  

![](../Images/73d1d35535cbe0822e7613e4e0431aec.png)

VisitBytecodes() -> VisitSingleBytecode() 会遍历每一条指令，并通过switch 宏来调用对应的生成node的函数，如这里遍历到第二条指令，会调用`BytecodeGraphBuilder::VisitLdaGlobal()`  

![](../Images/49f06febeab5f28e867cabc9d5dbcdf7.png)

```

```

此条指令处理后，会继续处理下一条指令，如此遍历bytecode生成对应node  

![](../Images/d50aeb0b42a34f93f80e5ab0101eb488.png)  
![](../Images/daccdd418a361d3669a79a915552b709.png)  
至此，我们粗略的调试了一遍`GraphBuilderPhase`，对一些基本的结构有些了解。

  

#### （3）TyperPhase

经过这个Phase的优化，`sea of nodes`的结点便都有了`Type & Range`。代码看`TyperPhase`中只添加了一个`reducer`：`Visitor`

```

```

跟入`Typer::Visitor::Reduce`,一个switch结构，根据node的`opcode`调用不同的函数`UpdateType()`

```

```

##### (3-1) SpeculativeNumberAdd node

跟踪下`SpeculateNumberAdd`结点的Typer处理，`Typer::Visitor::Reduce`行94处理  

![](../Images/70a1d15fff4cd742d114b88fbebc412a.png)

`SIMPLIFIED_SPECULATIVE_NUMBER_BINOP_LIST(V)`声明如下，宏展开即`DECLARE_CASE(SpeculativeNumberAdd)`

```

```

根据上图中`DECLARE_CASE`的声明，会调用行92`UpdateType`。先进入`TypeBinaryOp(node,x)`,条件成立最后调用`f()`

```

```

根据上下文，`f`即`SpeculativeNumberAdd`，但这里我并没有搜到`SpeculativeNumberAdd`函数的声明实现，并且调试单步跟入vs会跑丢提示找不到某些文件，所以这里查看`f`的函数地址，通过反汇编窗口找到代码如下  

![](../Images/ff8050ec8584740495fafd443bd0c95d.png)

从反汇编大概可以看到`call`到`v8::internal::compiler::OperationTyper::SpeculativeNumberAdd`。直接在反汇编断点处查看源码，会发现落到`src\compiler\typer.cc: 284`  

![](../Images/f90aecdf44b74ec19d9cb0d94896dd90.png)

原来是通过宏定义的函数，根据宏展开，依旧是找不到`SpeculativeNumberAdd`。所以我们继续在反汇编窗口跟入`call`的地址，来到如下位置，这里我们就明白了，v8通过拼接的方式声明了`SpeculativeNumberAdd`

```

```

通过上面的代码，我们可以知道，`SpeculativeNumberAdd`继续调到了`NumberAdd`，根据如下代码行31调用`AddRange()`添加`range`

```

```

继续看`AddRanger`,也就清楚了`SpeculativeNumberAdd`结点的`range`设置

```

```

##### (3-2) JSCall node

再跟踪下`jscall`结点的Typer处理，`Typer::Visitor::Reduce`#75处理

```

```

这个处理比较容易跟踪，最终在`JSCallTyper`处理，可以看到调用`Math.random()`将`return Type::PlainNumber();`

```

```

##### (3-3) NumberConstant node

![](../Images/59a68f5119df840316f42b87e8c91d15.png)

`NumberConstant`设置`range`  

![](../Images/8af65ccc068f71e136e4ccb982874749.png)

其他的node也会一一通过typerphase设置type。

#### （4）TypedLoweringPhase

直到这个phase添加了比较多的reducer，我才意识到v8对于`sea of nodes`的整体遍历逻辑：v8在开始reduce之前，会从`end`开始进行深度优先遍历，将遍历的`node`push到`stack_`中，然后从`stack_`顶部开始调用`Reduce`进行处理。`Reduce`中循环遍历`reducers_`中的全部reducer，分别调用`reducer->Reduce(node)`处理。

`bool PipelineImpl::CreateGraph(){}`调用`TypedLoweringPhase`，其中添加的Reducer包括题目中patch的`DuplicateAdditionReducer`，`TypedLoweringPhase->Run()`添加多个Reducer后，最后调用`graph_reducer.ReduceGraph()`:

```

```

`graph()->end()`即获得`Graph`类的成员变量`_end`,其指向sea of nodes的最后一个opcode为end的结点。跟入ReduceNode，走读参考添加的注释

```

```

继续跟入`GraphReducer::ReduceTop()`（分析见注释），行37有个`max_id`，可以在sea of nodes中搜索到node

```

```

跟入`GraphReducer::Reduce(Node* const node)`，在这个函数中，我们可以**尝试**定位题目添加的`DuplicateAdditionReducer -> Reduce()`处理我们的`y = y + 1 +1`结点，这是个思路，说不定这个相关结点被之前的phase处理的面目全非了

```

```

ok，重新理一下思路，回看我们失败的poc（下面的代码），我们最初的想法是当`x==0`时，`y=9007199254740991`，走到行4时，`y=9007199254740991+1+1 => y=9007199254740992 => y = y-9007199254740991 => 1`；当`x==1`时，因为题目补丁的存在（补丁对`x==0`时`y`的值无影响）`y=9007199254740992+1+1 => y=9007199254740992+2 => y=9007199254740994 => y = 9007199254740994 - 9007199254740991 => 3`

如上算式，最后`y==3`，而arr是长度为2的数组，最后return arr[y]时导致越界。这是我们最初构造poc时的想法，看似没有问题的。但poc最后`print(res)`结果为1.2，说明事实上并没有越界

```

```

按照我们之前走读的代码，我们继续深入调试一下失败的poc。如下图，首次调用到`DuplicateAdditionReducer -> Reduce()`时，当前处理的node的opcode为`NumberConstant`  

![](../Images/b8969f9bc3d8410f2f93606951ea4273.png)

那么根据我们前文对代码的分析，我们可以从sea of nodes中定位到如下`#45`结点，因为这是从`End`结点进行深度优先搜索的第一个无inputs的结点，是符合我们上面断点调试的信息  

![](../Images/ef46ad8231e98c927995c04bc45ec62c.png)

事实上从上图，我们看到`#40`和`#41`两个add的node如下图，并不是题目补丁中switch的opcode`kNumberAdd`，这难道是poc不成功的原因？  

![](../Images/b7f952c37f13503f8f57e72784cc1661.png)

答案是否定的，在调试的过程中，当`DuplicateAdditionReducer -> Reduce()`处理到`#40`结点时确实因为不匹配opcode没能进入后续处理的代码，但是后续其他的reduce在处理这个node时将`SpeculativeNumberAdd`优化为`kNumberAdd`，对`#41`也同样如此。

如下图，断在`#40`node，单步跟入`DuplicateAdditionReducer -> ReduceAddition(Node *node)`  

![](../Images/e954804791c1bf3f8134f8c41e81d992.png)

如下图查看此时参数node的信息，三个`DCHECK_EQ`是没有问题的```ControlInputCount => control_in_==0``EffectInputCount => effect_in_==0``ValueInputCount => value_in_==2```，opcode也是`kNumberAdd`  

![](../Images/9c9fbab84682528ea054ac3e57cfa440.png)

根据补丁代码，继续查看当前`node`的`left_node`的`opcode`，如下图`left->op_`为`Phi`，显然是不等于node的NumberAdd的，所以没能走入补丁的核心逻辑  

![](../Images/60a9fa40368114afba430b6a2bfb043a.png)

从sea of nodes也能看得出来left的opcode  

![](../Images/9b4e8631f756a5b616b1bf6061d526e2.png)

ok，我们本来的意图也是在下面这个NumberAdd结点进入补丁核心逻辑，从而合并右侧两个常量。  
断点断下，变量信息如下图  

![](../Images/9b7a05987e7980a9ae110dd3eb275b85.png)

从图中可以看到left的opcode为`NumberConstant`？不应该是上面的`kNumberAdd`结点吗？难道右侧结点是`kNumberAdd`左侧结点是常量？ok，我们在调试器的监视中看下右侧结点的`opcode`  

![](../Images/77c1f000033c7e255546b075af6ef791.png)

`node->inputs_.inline_[0]->op_->mnemonic_`和`node->inputs_.inline_[1]->op_->mnemonic_`分别为node结点的左右父节点的opcode的字符串表示，如上图所示，两个都是常量？我们从sea of nodes中看到的不应该是左add右常量吗？我们看下左结点的sea of nodes信息，如下图  

![](../Images/ee1c72261d3c9d6a0d7f7e9950feded6.png)

ok，到这我们大概就清楚了，左结点`#40`的type为`range(9007199254740992, 9007199254740992 )`，被优化为`NumberConstant`了，所以调试信息左右结点全显示为`NumberConstant`。

那么问题又来了，我在构造poc时已经下意识防止出现这样的优化情况，所以使用了`(x==1)? :`这样的表达式，为的就是产生`Phi`结点，防止优化成`NumberConstant`。原来是因为，`Phi`的`range(9007199254740991, 9007199254740992)`，因为`IEEE-754`精度丢失的问题，导致其中每一个元素和`+1+1`运算的结果均为`9007199254740992`，所以导致`#40`在优化过程中还是被优化为了`NumberConstant`。最终还是没能走到补丁的核心代码，至此，poc为啥失败的原因就分析清楚了。

#### （5）SimplifiedLowering Phase

阅读这个phase主要是和优化`CheckBounds`结点相关。不像之前分析的Phase，调用位置在`PipelineCompilationJob::Status PipelineCompilationJob::PrepareJobImpl()`-->`bool PipelineImpl::CreateGraph()`函数中，`SimplifiedLowering Phase`的调用位置在`PipelineCompilationJob::Status PipelineCompilationJob::ExecuteJobImpl()`-->`bool PipelineImpl::OptimizeGraph(Linkage* linkage)`中，也有很多的phase运行在这个阶段。

跟踪`SimplifiedLowering Phase`的调用流：`SimplifiedLoweringPhase::Run()`-->`SimplifiedLowering::LowerAllNodes()`-->`RepresentationSelector::Run()`-->`RepresentationSelector::VisitNode()`中使用switch opcode处理各个结点，处理`CheckBounds`代码如下

```

```

`CheckBounds`的`index`范围来自`NumberSub`结点的`range`，而在补丁代码中合并两个常量结点后，并没有去更新相关结点的`range`(更新range的相关函数`UpdateRange`)

```

```

导致了`CheckBounds`的错误消除。我们可以看`TypedLowering Phase`后的`sea of nodes`  

![](../Images/c600a8968c396ca84f61ca9c28fa8145.png)

### 成功的POC

```

```

上述poc运行结果如下，越界读取了arr的值  

![](../Images/f2475c3cf32e36de4467d8f7b9883d42.png)

分别看下`SimplifiedLowering`运行前后，`CheckBounds`结点优化的情况，优化前`LoadElement`前，`CheckBounds`结点存在；从下图的`After Typerphase`得知`CheckBounds Range(2,3)`，其就是x分别等于`9007199254740992`及`9007199254740989`计算得到，其范围恒小于数组的长度。在`SimplifiedLowering`后，`CheckBounds`被优化掉，从而导致最终的越界成功  

![](../Images/e4f234fcbe36d14cc8f8fbd1aa87dd52.png)  
![](../Images/81fb21967e38f0d8d75294c0281c3c91.png)

## Exploitation

这一节部分linux的调试信息是翻译introduction to turbofan的内容，win下的代码和linux的思路基本是一致的。文章最后贴出在win下调试的exp。

扩大越界范围

```

```

调试输出如下，行7是越界读取的数据

```

```

elements对应的内存如下，可以看到上面越界的数据位于`0x00379ae0df48`

![](../Images/e5b95d401386d5980260f17b5fd1c335.png)

### （1）Corrupting a JSArray

上图的`FixedDoubleArray`的elements里，第二个成员也是数组长度，但是这个长度仅仅是提供fixed array的内存申请的信息，最终判断数组长度的还是`JSArray`的`length`。如下的情况，`JSArray`的`length`为1，而`FixedArray`的`length`为17

```

```

通过修改poc，利用精度丢失越界读写`JSArray`的`length`。修改了arr1自身的`JSArray`的`length`

```

```

输出如下，行5看到arr对象的length修改为0x64

```

```

同样我们在内存中也可以看到`JSArray`的`length`修改为0x64  

![](../Images/0f6b0831e51317b1a39da77c04f18b26.png)

上面测试代码最后crash了，调用栈如下  

![](../Images/fbb8b549d1efbba3ab6ff133927ed39e.png)

调用栈的第5层，调试信息如下，`this`指向`FixedArray`，`index`是测试代码里越界的下标  

![](../Images/1240c506156bf1983da9b300e9978286.png)

`DCHECK`为`debug`编译时的宏代码如下，`release`时则不存在

```

```

为后续调试方便我这里直接在源码中修改后重新编译。

后续调试，`Array`的`indexOf`搜索下标，但是`debug`版本在`CSA`会检测`indexOf`的index，同样程序会crash，也是DEBUG模式的断言，这里也注释掉`CSA_ASSERT`

```

```

### （2）Getting fake object

`PACKED_ELEMENTS`类型的数组能存储指向JS OBJ的`tagged pointer`(+1)，V8的`elements kind`提供了当前JsArray存储元素的类型信息。例：  

![](../Images/a6c7375434a1bd7ff69c373a8525c8a7.png)

```

```

如果可以破坏`PACKED_ELEMENTS`的数组元素，那么就可以存入一个指向精心构造的对象的指针。所以，我们现在基本的思路就是在这样的数组中存入一个`backing_store + 1`（tagged）的地址。

进行一个简单的测试，测试一下存入`0x41414141`。  
任何object的第一个成员都是一个指向`map`的指针（`map`描述对象的类型信息），在其他的引擎中成为`Shape`或者`Structure`。  
所以，当v8将`0x41414141`解析为obj时，我们希望能得到该地址的解引用crash。

```

```

### （3）Arbitrary read/write primitive

思路是伪造一个`backing_store`可控的`ArrayBuffer`。如下demo，任意写的基本实现

```

```

输出如下

```

```

如上思路实现任意读写，或者可以伪造float类型obj，通过elements指针实现任意读写，但是写数据过程中会存在数据的破坏，ArrayBuffer不会。

### （4）Overwriting WASM RWX memory

至此，我们拥有了AAR/W能力，完成利用的最后一块拼图最简单的思路，找一块RWX的内存，写入shellcode并执行，这比`ROP`或者`JIT CODE REUSE`方便多了。  
V8以前将`JITed code`of`JSFunction`放在`RWX`的内存中，但是后来修改了：

```

```

但是，Andrea Biondo发现，WASM is still using RWX memory。  
所以，我们可以找到一个WASM实例，定位到其`JumpTableStart`，即指向`RWX`的指针。步骤如下：

*   获取JSFunction的shared function info；
    
*   从shared function info中获取WASM的exported function信息；
    
*   从exported function中获取WASM实例；
    
*   从WASM实例获取JumpTableStart域；
    

通过Jeremy\_x86开发的gdb插件可以比较轻松的识别到JumpTableStart（v8\_doare\_helpers），通过命令`%DumpObjects`识别如下

```

```

测试手动定位一下，测试代码sample\_wasm.js

```

```

通过如下的调试，可以得到相关偏移的信息（不同的checkout版本，可能偏移有差异）

```

```

定位到`JumpTableStart`后，最后将shellcode写入并执行。Of course，覆写shellcode前应当备份内存数据，执行shellcode后再修复修改的内存。

### （5）Exploit

```

```

![](../Images/b4e228710ddb7a79f75e85ca502fa36f.png)

## 参考

1.  https://doar-e.github.io/blog/2019/01/28/introduction-to-turbofan/
    
2.  https://kiprey.github.io/2021/01/v8-turboFan
    
3.  https://sagecell.sagemath.org/?z=eJzT0DXUjDNQ0FIwijM1AlIahgraIEJXwVBfAySmqakJAHo9Bo0=&lang=sage
    
4.  https://sagecell.sagemath.org/?z=eJzT0DXUjDNQ0FIwijM1BlIahgraCgaaADQcBCc=&lang=sage
    
5.  https://sagecell.sagemath.org/?z=eJzT0DXUjDNQ0FIwijM1BlIahgraCob6GkCukaYmAFdlBZ8=&lang=sage