version="1.0" encoding="utf-8"?

# 过期的 airflow rce

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU5Mzk3NTE0Mw==&mid=2247483676&idx=1&sn=8da89293ca50b7f6de0b34a76d92c18a&chksm=fe090314c97e8a02a82d9251576873ff625f21ca80281c1cc6d08c574a35f0dff6800732eee9&scene=126&sessionid=1681657449#rd](http://mp.weixin.qq.com/s?__biz=MzU5Mzk3NTE0Mw==&mid=2247483676&idx=1&sn=8da89293ca50b7f6de0b34a76d92c18a&chksm=fe090314c97e8a02a82d9251576873ff625f21ca80281c1cc6d08c574a35f0dff6800732eee9&scene=126&sessionid=1681657449#rd)

这个洞只影响 airflow 1.x，authed rce。调 superset 2020 那个 rce 时顺手挖的，挖完忘了交了，去年再提给官方他们说不支持了，不支持了那就公开吧。。。 

  

原理也和superset那个洞一样，airflow 的 web console 有个编辑sql的地方，靠 Google dork  捡到的🕳️，代码都不用看。