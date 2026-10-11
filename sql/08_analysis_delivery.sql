/* =====================================================================
   RetailPulse | 08_analysis_delivery.sql
   Business question:
     Q6  Do late deliveries hurt customer satisfaction? Where is it worst?
   Note    : Uses delivered orders that have a delivery date.
             "Late" = delivered after the date promised to the customer.
   Run     : psql -d retailpulse -f sql/08_analysis_delivery.sql
   ===================================================================== */

-- ---------------------------------------------------------------
-- 8.1 Delivery KPIs
-- ---------------------------------------------------------------
SELECT
    COUNT(*)                                                      AS delivered_orders,
    ROUND(AVG(delivery_days), 1)                                  AS avg_delivery_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days)    AS median_delivery_days,
    ROUND(100.0 * AVG(1 - is_late), 1)                            AS on_time_rate_pct,
    ROUND(AVG(review_score), 2)                                   AS avg_review_score,
    ROUND(100.0 * AVG((review_score <= 2)::INT), 1)               AS bad_review_pct
FROM analytics.fact_orders
WHERE is_delivered = 1
  AND delivery_days IS NOT NULL;

-- ---------------------------------------------------------------
-- 8.2 Delay bucket vs. review score  (the key insight of the project)
-- ---------------------------------------------------------------
SELECT delay_bucket,
       COUNT(*)                                                   AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)         AS order_share_pct,
       ROUND(AVG(review_score), 2)                                AS avg_review_score,
       ROUND(100.0 * AVG((review_score <= 2)::INT), 1)            AS bad_review_pct,
       ROUND(100.0 * AVG((review_score  = 5)::INT), 1)            AS five_star_pct
FROM analytics.fact_orders
WHERE is_delivered = 1
  AND delay_bucket IS NOT NULL
  AND review_score IS NOT NULL
GROUP BY delay_bucket
ORDER BY delay_bucket;

-- What share of all 1-2 star reviews come from late orders?
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE is_late = 1) / COUNT(*), 1)
           AS pct_of_bad_reviews_from_late_orders
FROM analytics.fact_orders
WHERE is_delivered = 1
  AND is_late IS NOT NULL
  AND review_score <= 2;

-- ---------------------------------------------------------------
-- 8.3 Late-delivery rate and review score by customer region
-- ---------------------------------------------------------------
SELECT g.region,
       COUNT(*)                                        AS orders,
       ROUND(AVG(fo.delivery_days), 1)                 AS avg_delivery_days,
       ROUND(100.0 * AVG(fo.is_late), 1)               AS late_rate_pct,
       ROUND(AVG(fo.review_score), 2)                  AS avg_review_score
FROM analytics.fact_orders   fo
JOIN analytics.dim_geography g ON g.state_code = fo.state_code
WHERE fo.is_delivered = 1
  AND fo.delivery_days IS NOT NULL
GROUP BY g.region
ORDER BY late_rate_pct DESC;

-- ---------------------------------------------------------------
-- 8.4 Worst 10 states by late-delivery rate (min. 500 orders),
--     ranked with RANK()
-- ---------------------------------------------------------------
WITH by_state AS (
    SELECT fo.state_code,
           COUNT(*)                          AS orders,
           AVG(fo.delivery_days)             AS avg_delivery_days,
           AVG(fo.is_late)                   AS late_rate,
           AVG(fo.review_score)              AS avg_review
    FROM analytics.fact_orders fo
    WHERE fo.is_delivered = 1
      AND fo.delivery_days IS NOT NULL
    GROUP BY fo.state_code
    HAVING COUNT(*) >= 500
)
SELECT RANK() OVER (ORDER BY late_rate DESC)  AS late_rank,
       b.state_code,
       g.state_name,
       b.orders,
       ROUND(b.avg_delivery_days, 1)          AS avg_delivery_days,
       ROUND(100.0 * b.late_rate, 1)          AS late_rate_pct,
       ROUND(b.avg_review, 2)                 AS avg_review_score
FROM by_state b
JOIN analytics.dim_geography g USING (state_code)
ORDER BY late_rank
LIMIT 10;

-- ---------------------------------------------------------------
-- 8.5 Monthly on-time rate trend (complete months)
-- ---------------------------------------------------------------
SELECT d.year_month,
       COUNT(*)                                   AS delivered_orders,
       ROUND(100.0 * AVG(1 - fo.is_late), 1)      AS on_time_rate_pct,
       ROUND(AVG(fo.delivery_days), 1)            AS avg_delivery_days,
       ROUND(AVG(fo.review_score), 2)             AS avg_review_score
FROM analytics.fact_orders fo
JOIN analytics.dim_date    d ON d.date_key = fo.date_key
WHERE fo.is_delivered = 1
  AND fo.delivery_days IS NOT NULL
  AND d.month_start BETWEEN '2017-01-01' AND '2018-08-01'
GROUP BY d.year_month
ORDER BY d.year_month;
