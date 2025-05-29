-- to check the recency of a customer -- 
WITH
  recent AS (
  SELECT
    CustomerID,
    MAX(DATE(InvoiceDate)) AS last_purchase_date,
    DATE_DIFF(DATE(MAX(InvoiceDate)), DATE('2011-12-01'), DAY) AS recency
  FROM
    `tc-da-1.turing_data_analytics.rfm`
  WHERE
    InvoiceDate BETWEEN '2010-12-01'AND '2011-12-01' AND CustomerID IS NOT NULL
  GROUP BY
    CustomerID),
  
  --counts the frequency and the sum of money a customer brings -- 
  frequent_and_money AS (
  SELECT
    customerID,
    COUNT (DISTINCT InvoiceNo) AS frequency,
    ROUND(SUM(UnitPrice * Quantity), 2) AS monetary
  FROM
    `tc-da-1.turing_data_analytics.rfm`
  GROUP BY
    CustomerID),
 
 -- uses the formulas of quartiles in separating the RFM into quarters -- 
rfm_quartiles AS (SELECT *,
r.percentiles[offset (24)] AS r_q1, -- offset 24 counts until the 25% --
r.percentiles[offset(49)] AS r_q2,
r.percentiles[offset(74)] AS r_q3,
r.percentiles[offset(99)] AS r_q4,
f.percentiles[offset(24)] AS f_q1,
f.percentiles[offset(49)] AS f_q2,
f.percentiles[offset(74)] AS f_q3,
f.percentiles[offset(99)] AS f_q4,
m.percentiles[offset(24)] AS m_q1,
m.percentiles[offset(49)] AS m_q2,
m.percentiles[offset(74)] AS m_q3,
m.percentiles[offset(99)] AS m_q4
FROM (SELECT APPROX_QUANTILES(recency, 100) percentiles FROM
    recent) AS r,
    (SELECT APPROX_QUANTILES(frequency, 100) percentiles FROM frequent_and_money) AS f,
    (SELECT APPROX_QUANTILES(monetary, 100) percentiles FROM frequent_and_money) AS m
    ),

-- SELECT
--APPROX_QUANTILES(monetary, 100)[OFFSET(25)] m25,
--APPROX_QUANTILES(monetary, 100)[OFFSET(50)] m50,
--APPROX_QUANTILES(monetary, 100)[OFFSET(75)] m75,


--APPROX_QUANTILES(frequency, 100)[OFFSET(25)] f25,
--APPROX_QUANTILES(frequency, 100)[OFFSET(50)] f50, -- a more simpler way to make the percentiles -- 
--APPROX_QUANTILES(frequency, 100)[OFFSET(75)] f75,


--APPROX_QUANTILES(recency, 100)[OFFSET(25)] r25,
--APPROX_QUANTILES(recency, 100)[OFFSET(50)] r50,
--APPROX_QUANTILES(recency, 100)[OFFSET(75)] r75,
--FROM `tc-da-1.turing_data_analytics.rfm_value` -- 
-- from the quartiles, it gives a score for R,F and M -- 
  rfm_scores AS (
    SELECT 
      r.CustomerID,
      r.recency,
      f_m.frequency,
      f_m.monetary,
     CASE 
        WHEN r.recency <= rfmq.r_q1 THEN 4  -- Most recent customers (0-25%)
        WHEN r.recency <= rfmq.r_q2 THEN 3  -- Next most recent (25-50%)
        WHEN r.recency <= rfmq.r_q3 THEN 2  -- Mid-recent (50-75%)
        ELSE 1  
      END AS r_score,
      CASE 
        WHEN f_m.frequency >= rfmq.f_q4 THEN 4 
        WHEN f_m.frequency BETWEEN rfmq.f_q3 +1 AND rfmq.f_q4 THEN 3 -- BETWEEN to make sure to check all the percentiles correctly
        WHEN f_m.frequency BETWEEN rfmq.f_q2 +1 AND rfmq.f_q3 THEN 2
        ELSE 1
      END AS f_score,
      CASE 
        WHEN f_m.monetary >= rfmq.m_q4 THEN 4
        WHEN f_m.monetary BETWEEN rfmq.m_q3 +1 AND rfmq.m_q4 THEN 3
        WHEN f_m.monetary BETWEEN rfmq.m_q2 +1 AND rfmq.m_q3 THEN 2
        ELSE 1
      END AS m_score
    FROM
      recent AS r
    JOIN
      frequent_and_money AS f_m
    ON
      r.CustomerID = f_m.CustomerID,
    rfm_quartiles AS rfmq
  )

-- final select gives the results of RFM and the score of RFM, along with a customer categorization -- 
SELECT 
  CustomerID,
  recency,
  frequency, 
  monetary, 
  r_score,
  f_score, 
  m_score,
  CAST(ROUND((f_score + m_score) / 2, 0) AS INT64) AS fm_score, -- frequency + monetary --
  CASE 
    WHEN r_score  = 4 AND CAST(ROUND((f_score + m_score) / 2, 0) AS INT64)  = 4 
    OR r_score = 3 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 4 THEN "Best Customers"
    WHEN r_score = 4 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 2
    OR r_score= 4 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 3
    OR r_score = 3 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 3 THEN "Loyal Customers"
    WHEN r_score = 2 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 4
    OR r_score = 1 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 4 THEN "Big Spenders"
    WHEN r_score = 2 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 3
    OR r_score = 3 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 2 THEN "Pontential Loyals"
    WHEN r_score = 4 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 1
    OR r_score = 3 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 1 THEN "New Customers"
    WHEN r_score = 1 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 3
    OR r_score = 2 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 2
    OR r_score = 1 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 2 THEN "Losing Customers"
    WHEN r_score = 2 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 1
    OR r_score = 1 AND CAST(ROUND((f_score + m_score) /2 ,0) AS INT64) = 1 THEN "Lost Customers"
  END AS customer_category

FROM
  rfm_scores 
ORDER BY 
  CustomerID;    
  -- to check the monetary value of the customers -- 
SELECT CustomerID, SUM(UnitPrice * Quantity)
FROM `tc-da-1.turing_data_analytics.rfm`
WHERE CustomerID = 12347
GROUP BY CustomerID


-- to check if there are all the customers in the data_set -- 
SELECT COUNT (DISTINCT CustomerID)
 FROM `tc-da-1.turing_data_analytics.rfm`
 WHERE InvoiceDate >= '2011-12-01'
 
 
 -- to check the recency is correct -- 
SELECT CustomerID, InvoiceDate
 FROM `tc-da-1.turing_data_analytics.rfm`
 WHERE InvoiceDate >= '2011-12-01' AND CustomerID = 12359