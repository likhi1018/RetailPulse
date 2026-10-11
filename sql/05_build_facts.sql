/* =====================================================================
   RetailPulse | 05_build_facts.sql
   Purpose : Build the two fact tables.

   fact_sales  - grain: ONE ROW PER ORDER ITEM, delivered orders only.
                 Used for revenue, freight, product and seller analysis.
   fact_orders - grain: ONE ROW PER ORDER, all statuses.
                 Used for delivery, review, payment and cancellation analysis.

   Why two facts? Delivery days and review scores belong to the ORDER.
   Putting them on item rows would repeat them for multi-item orders
   and inflate averages.

   Run     : psql -d retailpulse -f sql/05_build_facts.sql
   ===================================================================== */

-- ---------------------------------------------------------------
-- fact_sales
-- ---------------------------------------------------------------
DROP TABLE IF EXISTS analytics.fact_sales;
CREATE TABLE analytics.fact_sales AS
SELECT
    i.order_id,
    i.order_item_id,
    TO_CHAR(o.order_purchase_timestamp, 'YYYYMMDD')::INT AS date_key,
    mc.customer_key,
    dp.product_key,
    ds.seller_key,
    i.price,
    i.freight_value,
    i.price + i.freight_value                            AS gross_item_value
FROM staging.order_items  i
JOIN staging.orders       o  ON o.order_id    = i.order_id
JOIN analytics.map_customer mc ON mc.customer_id = o.customer_id
JOIN analytics.dim_product  dp ON dp.product_id  = i.product_id
JOIN analytics.dim_seller   ds ON ds.seller_id   = i.seller_id
WHERE o.order_status = 'delivered';

ALTER TABLE analytics.fact_sales ADD PRIMARY KEY (order_id, order_item_id);

-- ---------------------------------------------------------------
-- fact_orders
-- ---------------------------------------------------------------
DROP TABLE IF EXISTS analytics.fact_orders;
CREATE TABLE analytics.fact_orders AS
WITH items AS (                      -- items rolled up to order level
    SELECT order_id,
           COUNT(*)            AS items_count,
           SUM(price)          AS items_value,
           SUM(freight_value)  AS freight_value
    FROM staging.order_items
    GROUP BY order_id
),
payments AS (                        -- several payments per order -> one row
    SELECT order_id,
           SUM(payment_value)          AS payment_total,
           MAX(payment_installments)   AS max_installments,
           COUNT(*)                    AS payment_count
    FROM staging.order_payments
    GROUP BY order_id
),
main_payment AS (                    -- payment type that covered the most money
    SELECT order_id, payment_type AS main_payment_type
    FROM (
        SELECT order_id, payment_type,
               ROW_NUMBER() OVER (PARTITION BY order_id
                                  ORDER BY payment_value DESC, payment_sequential) AS rn
        FROM staging.order_payments
    ) x
    WHERE rn = 1
),
latest_review AS (                   -- some orders have several reviews: keep the latest
    SELECT order_id, review_score
    FROM (
        SELECT order_id, review_score,
               ROW_NUMBER() OVER (PARTITION BY order_id
                                  ORDER BY review_answer_timestamp DESC,
                                           review_creation_date   DESC) AS rn
        FROM staging.order_reviews
    ) x
    WHERE rn = 1
)
SELECT
    o.order_id,
    TO_CHAR(o.order_purchase_timestamp, 'YYYYMMDD')::INT          AS date_key,
    mc.customer_key,
    c.customer_state                                              AS state_code,
    o.order_status,
    (o.order_status = 'delivered')::INT                           AS is_delivered,
    (o.order_status IN ('canceled', 'unavailable'))::INT          AS is_canceled,
    COALESCE(it.items_count, 0)                                   AS items_count,
    it.items_value,
    it.freight_value,
    p.payment_total,
    p.payment_count,
    p.max_installments,
    mp.main_payment_type,
    -- Delivery metrics only make sense for orders that reached the customer
    CASE WHEN o.order_delivered_customer_date IS NOT NULL
         THEN ROUND(EXTRACT(EPOCH FROM (o.order_delivered_customer_date
                                        - o.order_purchase_timestamp)) / 86400.0, 1)
    END                                                           AS delivery_days,
    CASE WHEN o.order_delivered_customer_date IS NOT NULL
         THEN o.order_delivered_customer_date::DATE
              - o.order_estimated_delivery_date::DATE
    END                                                           AS delay_days,      -- > 0 = late
    CASE WHEN o.order_delivered_customer_date IS NOT NULL
         THEN (o.order_delivered_customer_date::DATE
               > o.order_estimated_delivery_date::DATE)::INT
    END                                                           AS is_late,
    CASE
        WHEN o.order_delivered_customer_date IS NULL                       THEN NULL
        WHEN o.order_delivered_customer_date::DATE
             <= o.order_estimated_delivery_date::DATE                      THEN '1. On time'
        WHEN o.order_delivered_customer_date::DATE
             - o.order_estimated_delivery_date::DATE <= 3                  THEN '2. 1-3 days late'
        WHEN o.order_delivered_customer_date::DATE
             - o.order_estimated_delivery_date::DATE <= 7                  THEN '3. 4-7 days late'
        ELSE                                                                    '4. 8+ days late'
    END                                                           AS delay_bucket,
    lr.review_score
FROM staging.orders o
JOIN staging.customers      c  ON c.customer_id  = o.customer_id
JOIN analytics.map_customer mc ON mc.customer_id = o.customer_id
LEFT JOIN items         it ON it.order_id = o.order_id
LEFT JOIN payments      p  ON p.order_id  = o.order_id
LEFT JOIN main_payment  mp ON mp.order_id = o.order_id
LEFT JOIN latest_review lr ON lr.order_id = o.order_id;

ALTER TABLE analytics.fact_orders ADD PRIMARY KEY (order_id);

-- ---------------------------------------------------------------
-- Reconciliation: fact totals must match staging totals
-- ---------------------------------------------------------------
SELECT 'Delivered item revenue: staging' AS check_name,
       SUM(i.price) AS value
FROM staging.order_items i
JOIN staging.orders o USING (order_id)
WHERE o.order_status = 'delivered'
UNION ALL
SELECT 'Delivered item revenue: fact_sales', SUM(price) FROM analytics.fact_sales
UNION ALL
SELECT 'Orders: staging',     COUNT(*) FROM staging.orders
UNION ALL
SELECT 'Orders: fact_orders', COUNT(*) FROM analytics.fact_orders
ORDER BY check_name;
