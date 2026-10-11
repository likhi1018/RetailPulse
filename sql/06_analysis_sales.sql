/* =====================================================================
   RetailPulse | 06_analysis_sales.sql
   Business questions:
     Q1  How are revenue, orders and AOV trending? Is growth healthy?
     Q2  Which categories and sellers drive revenue? Is it concentrated?
     Q3  Which regions buy the most, and how much does freight cost them?
   Notes   : Money is in Brazilian reais (R$).
             Trend analysis uses complete months only: Jan 2017 - Aug 2018
             (Sep-Dec 2016 and Sep-Oct 2018 have only a handful of orders).
   Run     : psql -d retailpulse -f sql/06_analysis_sales.sql
   ===================================================================== */

-- ---------------------------------------------------------------
-- 6.1 Headline KPIs (delivered orders)
-- ---------------------------------------------------------------
SELECT
    ROUND(SUM(fs.price), 0)                                       AS total_revenue,
    COUNT(DISTINCT fs.order_id)                                   AS total_orders,
    ROUND(SUM(fs.price) / COUNT(DISTINCT fs.order_id), 2)         AS aov,
    COUNT(DISTINCT fs.customer_key)                               AS unique_customers,
    ROUND(100.0 * SUM(fs.freight_value) / SUM(fs.price), 1)       AS freight_pct_of_revenue
FROM analytics.fact_sales fs;

-- ---------------------------------------------------------------
-- 6.2 Monthly trend with MoM growth, 3-month moving average and
--     running total  (CTE + LAG + AVG OVER + SUM OVER)
-- ---------------------------------------------------------------
WITH monthly AS (
    SELECT d.month_start,
           SUM(fs.price)                AS revenue,
           COUNT(DISTINCT fs.order_id)  AS orders
    FROM analytics.fact_sales fs
    JOIN analytics.dim_date   d ON d.date_key = fs.date_key
    WHERE d.month_start BETWEEN '2017-01-01' AND '2018-08-01'
    GROUP BY d.month_start
)
SELECT
    TO_CHAR(month_start, 'YYYY-MM')                               AS month,
    ROUND(revenue, 0)                                             AS revenue,
    orders,
    ROUND(revenue / orders, 2)                                    AS aov,
    ROUND(100.0 * (revenue - LAG(revenue) OVER w)
          / NULLIF(LAG(revenue) OVER w, 0), 1)                    AS mom_growth_pct,
    ROUND(AVG(revenue) OVER (ORDER BY month_start
                             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS revenue_3m_avg,
    ROUND(SUM(revenue) OVER (ORDER BY month_start), 0)            AS running_revenue
FROM monthly
WINDOW w AS (ORDER BY month_start)
ORDER BY month_start;

-- ---------------------------------------------------------------
-- 6.3 Year-over-year: Jan-Aug 2018 vs Jan-Aug 2017 (like-for-like)
-- ---------------------------------------------------------------
WITH ytd AS (
    SELECT d.year,
           SUM(fs.price)               AS revenue,
           COUNT(DISTINCT fs.order_id) AS orders
    FROM analytics.fact_sales fs
    JOIN analytics.dim_date   d ON d.date_key = fs.date_key
    WHERE d.month_num BETWEEN 1 AND 8
      AND d.year IN (2017, 2018)
    GROUP BY d.year
)
SELECT
    MAX(revenue) FILTER (WHERE year = 2017)  AS revenue_jan_aug_2017,
    MAX(revenue) FILTER (WHERE year = 2018)  AS revenue_jan_aug_2018,
    ROUND(100.0 * (MAX(revenue) FILTER (WHERE year = 2018)
                 - MAX(revenue) FILTER (WHERE year = 2017))
          / MAX(revenue) FILTER (WHERE year = 2017), 1) AS revenue_yoy_pct,
    ROUND(100.0 * (MAX(orders) FILTER (WHERE year = 2018)
                 - MAX(orders) FILTER (WHERE year = 2017))
          / MAX(orders) FILTER (WHERE year = 2017)::NUMERIC, 1) AS orders_yoy_pct
FROM ytd;

-- ---------------------------------------------------------------
-- 6.4 Top 15 categories with rank, share and cumulative share
--     (Pareto / 80-20 analysis using window functions)
-- ---------------------------------------------------------------
WITH cat AS (
    SELECT dp.category,
           SUM(fs.price)                AS revenue,
           COUNT(DISTINCT fs.order_id)  AS orders,
           SUM(fs.freight_value)        AS freight
    FROM analytics.fact_sales  fs
    JOIN analytics.dim_product dp ON dp.product_key = fs.product_key
    GROUP BY dp.category
),
ranked AS (
    SELECT cat.*,
           DENSE_RANK() OVER (ORDER BY revenue DESC)                    AS revenue_rank,
           100.0 * revenue / SUM(revenue) OVER ()                       AS revenue_share,
           100.0 * SUM(revenue) OVER (ORDER BY revenue DESC
                                      ROWS UNBOUNDED PRECEDING)
                 / SUM(revenue) OVER ()                                 AS cumulative_share,
           COUNT(*) OVER ()                                             AS total_categories
    FROM cat
)
SELECT revenue_rank, category,
       ROUND(revenue, 0)                  AS revenue,
       orders,
       ROUND(revenue / orders, 2)         AS aov,
       ROUND(100.0 * freight / revenue, 1) AS freight_pct,
       ROUND(revenue_share, 1)            AS revenue_share_pct,
       ROUND(cumulative_share, 1)         AS cumulative_share_pct
FROM ranked
ORDER BY revenue_rank
LIMIT 15;

-- How many categories make up 80% of revenue?
WITH cat AS (
    SELECT dp.category, SUM(fs.price) AS revenue
    FROM analytics.fact_sales fs
    JOIN analytics.dim_product dp ON dp.product_key = fs.product_key
    GROUP BY dp.category
),
cum AS (
    SELECT category,
           SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING)
             / SUM(revenue) OVER () AS cumulative_share
    FROM cat
)
SELECT COUNT(*) FILTER (WHERE cumulative_share <= 0.80) + 1 AS categories_for_80pct_revenue,
       COUNT(*)                                             AS total_categories
FROM cum;

-- ---------------------------------------------------------------
-- 6.5 Seller concentration: share of revenue from the top 10% of sellers
-- ---------------------------------------------------------------
WITH seller_rev AS (
    SELECT seller_key, SUM(price) AS revenue
    FROM analytics.fact_sales
    GROUP BY seller_key
),
tiered AS (
    SELECT revenue, NTILE(10) OVER (ORDER BY revenue DESC) AS decile
    FROM seller_rev
)
SELECT COUNT(*)                                                        AS active_sellers,
       ROUND(100.0 * SUM(revenue) FILTER (WHERE decile = 1) / SUM(revenue), 1)
                                                                       AS top_10pct_sellers_revenue_share
FROM tiered;

-- ---------------------------------------------------------------
-- 6.6 Revenue and freight burden by customer region
-- ---------------------------------------------------------------
SELECT dc.region,
       ROUND(SUM(fs.price), 0)                                 AS revenue,
       ROUND(100.0 * SUM(fs.price) / SUM(SUM(fs.price)) OVER (), 1) AS revenue_share_pct,
       COUNT(DISTINCT fs.order_id)                             AS orders,
       ROUND(SUM(fs.price) / COUNT(DISTINCT fs.order_id), 2)   AS aov,
       ROUND(100.0 * SUM(fs.freight_value) / SUM(fs.price), 1) AS freight_pct_of_revenue
FROM analytics.fact_sales   fs
JOIN analytics.dim_customer dc ON dc.customer_key = fs.customer_key
GROUP BY dc.region
ORDER BY revenue DESC;

-- ---------------------------------------------------------------
-- 6.7 Payment mix (all orders with a payment)
-- ---------------------------------------------------------------
SELECT main_payment_type,
       COUNT(*)                                          AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS order_share_pct,
       ROUND(AVG(payment_total), 2)                      AS avg_order_payment,
       ROUND(AVG(max_installments), 1)                   AS avg_installments
FROM analytics.fact_orders
WHERE main_payment_type IS NOT NULL
  AND is_delivered = 1
GROUP BY main_payment_type
ORDER BY orders DESC;
