# 电商零售用户RFM分析报告
## 项目背景
基于电商零售订单数据，使用MySQL完成用户分析，利用RFM模型实现用户分层，针对不同用户群体给出对应的运营策略。
## 数据源说明
数据源：**UCI公开数据集 Online‑Retail**
原始数据集：54万条订单记录，字段：InvoiceNo订单号、StockCode商品编码、Description商品名称、Quantity购买数量、InvoiceDate订单时间、UnitPrice单价、CustomerID用户ID、Country国家。
>说明：原始CSV文件存在特殊字符、换行损坏问题，本地使用模拟样本数据验证全部SQL分析逻辑，脚本可直接对接完整数据集。

## 数据清洗
### 清洗规则
1. 过滤退货订单：Quantity > 0（数量为负数代表退货）
2. 过滤赠品订单：UnitPrice > 0（单价为0代表赠品）
3. 剔除CustomerID为空的匿名无效用户
4. 新增字段amount：单行订单消费金额 = Quantity * UnitPrice

```sql
CREATE VIEW retail_clean AS
SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country,
    Quantity * UnitPrice AS amount
FROM online_retail
WHERE Quantity > 0
  AND UnitPrice > 0
  AND CustomerID IS NOT NULL;
```

## RFM 模型指标计算

- R (Recency)：距离最近一次消费的天数，数值越小代表用户最近活跃
- F (Frequency)：用户下单订单总次数
- M (Monetary)：用户累计消费总金额

> 
> 计算基准日期：2011‑12‑10

```
CREATE VIEW user_rfm AS
SELECT
    CustomerID,
    DATEDIFF('2011-12-10', MAX(InvoiceDate)) AS R,
    COUNT(DISTINCT InvoiceNo) AS F,
    SUM(amount) AS M
FROM retail_clean
GROUP BY CustomerID;
```

## RFM 打分与用户分层

打分规则：

- R 得分：消费间隔越小，分数越高（1‑4 分）
- F 得分：下单频次越高，分数越高（1‑4 分）
- M 得分：消费总金额越高，分数越高（1‑4 分）

```
CREATE VIEW rfm_score AS
SELECT
    CustomerID,
    R,
    F,
    M,
    CASE
        WHEN R <= 30 THEN 4
        WHEN R <= 90 THEN 3
        WHEN R <= 180 THEN 2
        ELSE 1
    END AS R_score,
    CASE
        WHEN F >=5 THEN 4
        WHEN F >=3 THEN 3
        WHEN F >=2 THEN 2
        ELSE 1
    END AS F_score,
    CASE
        WHEN M >=1000 THEN 4
        WHEN M >=500 THEN 3
        WHEN M >=100 THEN 2
        ELSE 1
    END AS M_score
FROM user_rfm;
```

### 用户分层标签

```
SELECT
    *,
    CONCAT(R_score,F_score,M_score) AS rfm_tag,
    CASE
        WHEN R_score=4 AND F_score>=3 AND M_score>=3 THEN '高价值客户'
        WHEN R_score>=3 AND F_score>=2 THEN '潜力客户'
        WHEN R_score<=2 AND F_score>=2 THEN '流失预警客户'
        WHEN R_score<=2 AND F_score=1 THEN '流失客户'
        ELSE '新客户'
    END AS user_segment
FROM rfm_score;
```

## 分析结果

表格

| CustomerID | R | F | M | R_score | F_score | M_score | rfm_tag | user_segment |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 12345 | 8 | 3 | 108.50 | 4 | 3 | 2 | 432 | 潜力客户 |
| 12346 | 46 | 2 | 20.34 | 3 | 2 | 1 | 321 | 潜力客户 |
| 12347 | 153 | 1 | 17.70 | 2 | 1 | 1 | 211 | 流失客户 |
| 12348 | 5 | 1 | 12.75 | 4 | 1 | 1 | 411 | 新客户 |
| 17850 | 374 | 1 | 77.98 | 1 | 1 | 1 | 111 | 流失客户 |

## 业务解读与运营建议

1. **潜力客户（12345、12346）**
最近有消费，有复购行为，但是客单价偏低；可以发放满减优惠券，引导提高消费金额，向高价值客户转化。
2. **新客户（12348）**
刚刚完成首次下单，重点做新客留存；推送新品、首购复购福利，促进第二次下单。
3. **流失客户（12347、17850）**
长时间没有消费，历史下单次数少；可以发送召回优惠券，召回成本较高，不需要投入过多资源。

## 多维度拓展分析

- 国家维度：不同国家订单量与销售额统计
- 商品维度：热销商品销量、销售额排行
- 时间维度：按月统计订单数量、销售金额，分析销售淡旺季趋势

## 项目总结

1. 通过 SQL 完成订单数据清洗，处理退货、赠品、匿名脏数据。
2. 搭建 RFM 用户模型，实现客户分群，区分不同价值的用户。
3. 基于分层结果输出运营建议，指导差异化营销活动。