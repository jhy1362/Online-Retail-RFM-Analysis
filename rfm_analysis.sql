-- =============================================
-- 项目：UCI Online-Retail 电商RFM用户分析
-- 环境：MySQL5.7（不支持CTE、NTILE窗口函数）
-- 数据集：UCI公开Online-Retail数据集，原始541910行订单
-- =============================================

-- 1. 基础数据清洗，生成RFM基础指标临时表
DROP TABLE IF EXISTS temp_rfm_base;
CREATE TABLE temp_rfm_base (
    CustomerID VARCHAR(20),
    R INT,
    F INT,
    M DECIMAL(12,2)
);

INSERT INTO temp_rfm_base (CustomerID,R,F,M)
SELECT 
    CustomerID,
    DATEDIFF('2011-12-09',MAX(InvoiceDate)) AS R,
    COUNT(DISTINCT InvoiceNo) AS F,
    SUM(Quantity*UnitPrice) AS M
FROM onlineretail_clean
WHERE Quantity>0 AND UnitPrice>0 AND CustomerID IS NOT NULL
GROUP BY CustomerID;

-- 校验RFM基础数据
SELECT * FROM temp_rfm_base LIMIT 10;

-- 2. R、F、M分别打分，生成打分临时表
DROP TABLE IF EXISTS temp_r_score;
CREATE TABLE temp_r_score (CustomerID VARCHAR(20), R_score INT);
INSERT INTO temp_r_score(CustomerID,R_score)
SELECT CustomerID, CEIL(@row:=@row+1 / (@cnt/5)) AS R_score
FROM temp_rfm_base, (SELECT @row:=0, @cnt:=(SELECT COUNT(*) FROM temp_rfm_base)) AS t
ORDER BY R DESC;

DROP TABLE IF EXISTS temp_f_score;
CREATE TABLE temp_f_score (CustomerID VARCHAR(20), F_score INT);
INSERT INTO temp_f_score(CustomerID,F_score)
SELECT CustomerID, CEIL(@row2:=@row2+1 / (@cnt2/5)) AS F_score
FROM temp_rfm_base, (SELECT @row2:=0, @cnt2:=(SELECT COUNT(*) FROM temp_rfm_base)) AS t
ORDER BY F ASC;

DROP TABLE IF EXISTS temp_m_score;
CREATE TABLE temp_m_score (CustomerID VARCHAR(20), M_score INT);
INSERT INTO temp_m_score(CustomerID,M_score)
SELECT CustomerID, CEIL(@row3:=@row3+1 / (@cnt3/5)) AS M_score
FROM temp_rfm_base, (SELECT @row3:=0, @cnt3:=(SELECT COUNT(*) FROM temp_rfm_base)) AS t
ORDER BY M ASC;

-- 3. 关联打分表，输出每个用户完整RFM分层标签
SELECT 
    b.CustomerID, b.R, b.F, b.M,
    r.R_score, f.F_score, m.M_score,
    CONCAT(r.R_score,f.F_score,m.M_score) AS rfm_tag,
    CASE 
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) = '555' THEN '重要价值客户'
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) LIKE '55_' THEN '重要深耕客户'
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) LIKE '5_5' THEN '重要潜力客户'
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) LIKE '_55' THEN '重要挽留客户'
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) LIKE '5__' THEN '新客户'
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) LIKE '__5' THEN '高价值流失客户'
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) LIKE '_5_' THEN '中频流失客户'
        ELSE '流失客户'
    END AS user_segment
FROM temp_rfm_base b
JOIN temp_r_score r ON b.CustomerID = r.CustomerID
JOIN temp_f_score f ON b.CustomerID = f.CustomerID
JOIN temp_m_score m ON b.CustomerID = m.CustomerID;

-- 4. RFM分层统计：各分层用户数量及占比
SELECT 
    user_segment,
    COUNT(DISTINCT CustomerID) AS user_count,
    ROUND(COUNT(DISTINCT CustomerID) / (SELECT COUNT(DISTINCT CustomerID) FROM temp_rfm_base)*100,2) AS user_percent
FROM (
SELECT 
    b.CustomerID,
    CASE 
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) = '555' THEN '重要价值客户'
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) LIKE '55_' THEN '重要深耕客户'
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) LIKE '5_5' THEN '重要潜力客户'
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) LIKE '_55' THEN '重要挽留客户'
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) LIKE '5__' THEN '新客户'
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) LIKE '__5' THEN '高价值流失客户'
        WHEN CONCAT(r.R_score,f.F_score,m.M_score) LIKE '_5_' THEN '中频流失客户'
        ELSE '流失客户'
    END AS user_segment
FROM temp_rfm_base b
JOIN temp_r_score r ON b.CustomerID = r.CustomerID
JOIN temp_f_score f ON b.CustomerID = f.CustomerID
JOIN temp_m_score m ON b.CustomerID = m.CustomerID
) AS seg
GROUP BY user_segment
ORDER BY user_count DESC;

-- 5. 附加分析：各国订单分布
SELECT Country,COUNT(*) order_cnt FROM onlineretail_clean WHERE Quantity>0 AND UnitPrice>0 GROUP BY Country ORDER BY order_cnt DESC;

-- 6. 附加分析：月度订单与销售额趋势
SELECT 
DATE_FORMAT(InvoiceDate,'%Y-%m') AS month,
COUNT(DISTINCT InvoiceNo) AS order_count,
SUM(Quantity*UnitPrice) AS total_sales
FROM onlineretail_clean
WHERE Quantity>0 AND UnitPrice>0 AND CustomerID IS NOT NULL
GROUP BY month
ORDER BY month;
