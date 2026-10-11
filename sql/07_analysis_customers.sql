/* =====================================================================
   RetailPulse | 07_analysis_customers.sql
   Business questions:
     Q4  Do customers come back? How many buy only once?
     Q5  Who are the most valuable customers, and who is at risk?
   Note    : A "customer" is customer_unique_id (the real person).
             Only delivered orders count as purchases.
   Run     : psql -d retailpulse -f sql/07_analysis_customers.sql
   ===================================================================== */

-- ---------------------------------------------------------------
-- 7.1 Repeat purchase rate
-- ---------------------------------------------------------------
WITH per_customer AS (
    SELECT customer_key,
           COUNT(DISTINCT order_id) AS orders,
           SUM(price)               AS revenue
    FROM analytics.fact_sales
    GROUP BY customer_key
)
SELECT
    COUNT(*)                                                      AS customers,
    COUNT(*) FILTER (WHERE orders >= 2)                           AS repeat_customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE orders >= 2) / COUNT(*), 2) AS repeat_rate_pct,
    ROUND(100.0 * SUM(revenue) FILTER (WHERE orders >= 2) / SUM(revenue), 1)
                                                                  AS revenue_share_from_repeat_pct,
    ROUND(AVG(revenue) FILTER (WHERE orders  = 1), 2)             AS avg_revenue_one_time,
    ROUND(AVG(revenue) FILTER (WHERE orders >= 2), 2)             AS avg_revenue_repeat
FROM per_customer;

-- Days between 1st and 2nd purchase for repeat customers (LEAD)
WITH orders_seq AS (
    SELECT DISTINCT fs.customer_key, fs.order_id, d.date
    FROM analytics.fact_sales fs
    JOIN analytics.dim_date d ON d.date_key = fs.date_key
),
gaps AS (
    SELECT customer_key,
           date,
           LEAD(date) OVER (PARTITION BY customer_key ORDER BY date, order_id) AS next_date,
           ROW_NUMBER() OVER (PARTITION BY customer_key ORDER BY date, order_id) AS order_seq
    FROM orders_seq
),
first_gap AS (
    SELECT next_date - date AS days_to_second_order
    FROM gaps
    WHERE order_seq = 1 AND next_date IS NOT NULL
)
SELECT COUNT(*)                                                   AS repeat_customers,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_second_order) AS median_days_to_2nd_order,
       ROUND(100.0 * COUNT(*) FILTER (WHERE days_to_second_order = 0)  / COUNT(*), 1) AS pct_same_day,
       ROUND(100.0 * COUNT(*) FILTER (WHERE days_to_second_order <= 90) / COUNT(*), 1) AS pct_within_90_days
FROM first_gap;

-- ---------------------------------------------------------------
-- 7.2 RFM segmentation
--     Recency  = days since last purchase (vs. day after last order in data)
--     Frequency= number of delivered orders (fixed rules: most customers = 1)
--     Monetary = total spend, scored 1-5 with NTILE
-- ---------------------------------------------------------------
DROP TABLE IF EXISTS analytics.customer_rfm;
CREATE TABLE analytics.customer_rfm AS
WITH cust AS (
    SELECT fs.customer_key,
           MAX(d.date)                  AS last_order_date,
           COUNT(DISTINCT fs.order_id)  AS frequency,
           SUM(fs.price)                AS monetary
    FROM analytics.fact_sales fs
    JOIN analytics.dim_date   d ON d.date_key = fs.date_key
    GROUP BY fs.customer_key
),
ref AS (
    SELECT MAX(last_order_date) + 1 AS ref_date FROM cust
),
scored AS (
    SELECT c.*,
           r.ref_date - c.last_order_date                       AS recency_days,
           NTILE(5) OVER (ORDER BY c.last_order_date)           AS r_score,  -- 5 = most recent
           NTILE(5) OVER (ORDER BY c.monetary)                  AS m_score,  -- 5 = biggest spenders
           CASE WHEN c.frequency >= 3 THEN 5
                WHEN c.frequency  = 2 THEN 3
                ELSE 1 END                                      AS f_score
    FROM cust c CROSS JOIN ref r
)
SELECT
    customer_key, last_order_date, recency_days, frequency, monetary,
    r_score, f_score, m_score,
    r_score::TEXT || f_score::TEXT || m_score::TEXT AS rfm_code,
    CASE
        WHEN r_score >= 4 AND f_score >= 3 AND m_score >= 4 THEN '1. Champions'
        WHEN f_score >= 3                                   THEN '2. Loyal'
        WHEN r_score >= 4 AND m_score >= 4                  THEN '3. Big Spenders (new)'
        WHEN r_score >= 4                                   THEN '4. Recent / Promising'
        WHEN r_score  = 3                                   THEN '5. Needs Attention'
        WHEN r_score <= 2 AND m_score >= 4                  THEN '6. At Risk (high value)'
        ELSE                                                     '7. Hibernating / Lost'
    END AS segment
FROM scored;

ALTER TABLE analytics.customer_rfm ADD PRIMARY KEY (customer_key);

-- Segment summary
SELECT segment,
       COUNT(*)                                               AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)     AS customer_share_pct,
       ROUND(SUM(monetary), 0)                                AS revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS revenue_share_pct,
       ROUND(AVG(monetary), 2)                                AS avg_spend,
       ROUND(AVG(recency_days), 0)                            AS avg_recency_days,
       ROUND(AVG(frequency), 2)                               AS avg_orders
FROM analytics.customer_rfm
GROUP BY segment
ORDER BY segment;

-- ---------------------------------------------------------------
-- 7.3 Cohort retention: % of each first-purchase cohort that bought
--     again in later months (complete cohorts Jan 2017 - Aug 2018)
-- ---------------------------------------------------------------
DROP TABLE IF EXISTS analytics.cohort_retention;
CREATE TABLE analytics.cohort_retention AS
WITH purchases AS (
    SELECT DISTINCT fs.customer_key, d.month_start AS order_month
    FROM analytics.fact_sales fs
    JOIN analytics.dim_date   d ON d.date_key = fs.date_key
),
cohorts AS (
    SELECT customer_key, MIN(order_month) AS cohort_month
    FROM purchases
    GROUP BY customer_key
),
activity AS (
    SELECT c.cohort_month,
           ((EXTRACT(YEAR  FROM p.order_month) - EXTRACT(YEAR  FROM c.cohort_month)) * 12
           + EXTRACT(MONTH FROM p.order_month) - EXTRACT(MONTH FROM c.cohort_month))::INT AS month_index,
           p.customer_key
    FROM purchases p
    JOIN cohorts   c USING (customer_key)
),
counts AS (
    SELECT cohort_month, month_index, COUNT(DISTINCT customer_key) AS active_customers
    FROM activity
    GROUP BY cohort_month, month_index
)
SELECT cohort_month,
       month_index,
       active_customers,
       FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_index) AS cohort_size,
       ROUND(100.0 * active_customers
             / FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_index), 2)
                                                           AS retention_pct
FROM counts
WHERE cohort_month BETWEEN '2017-01-01' AND '2018-08-01'
  AND cohort_month + (month_index || ' month')::INTERVAL <= '2018-08-01';

-- Average retention curve across cohorts (months 1-6 after first purchase)
SELECT month_index,
       ROUND(SUM(active_customers) * 100.0 / SUM(cohort_size), 2) AS weighted_retention_pct,
       COUNT(*)                                                    AS cohorts_included
FROM analytics.cohort_retention
WHERE month_index BETWEEN 1 AND 6
GROUP BY month_index
ORDER BY month_index;
