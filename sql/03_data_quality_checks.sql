/* =====================================================================
   RetailPulse | 03_data_quality_checks.sql
   Purpose : Profile the staging data BEFORE modeling it.
             Every check returns: check_name | issue_count.
             Results are documented in docs/data_quality_report.md
   Run     : psql -d retailpulse -f sql/03_data_quality_checks.sql
   ===================================================================== */

-- ---------------------------------------------------------------
-- 1. Uniqueness: are the keys we rely on really unique?
-- ---------------------------------------------------------------
SELECT '01. Duplicate review_id values' AS check_name,
       COUNT(*) - COUNT(DISTINCT review_id) AS issue_count
FROM staging.order_reviews
UNION ALL
SELECT '02. Orders with more than one review',
       COUNT(*)
FROM (SELECT order_id FROM staging.order_reviews GROUP BY order_id HAVING COUNT(*) > 1) x
UNION ALL
SELECT '03. Real customers (customer_unique_id) vs. per-order customer_id rows: difference',
       COUNT(*) - COUNT(DISTINCT customer_unique_id)
FROM staging.customers

-- ---------------------------------------------------------------
-- 2. Referential integrity: orphan foreign keys
-- ---------------------------------------------------------------
UNION ALL
SELECT '04. Order items with no matching order',
       COUNT(*)
FROM staging.order_items i
LEFT JOIN staging.orders o ON o.order_id = i.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT '05. Order items with no matching product',
       COUNT(*)
FROM staging.order_items i
LEFT JOIN staging.products p ON p.product_id = i.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT '06. Order items with no matching seller',
       COUNT(*)
FROM staging.order_items i
LEFT JOIN staging.sellers s ON s.seller_id = i.seller_id
WHERE s.seller_id IS NULL
UNION ALL
SELECT '07. Orders with no matching customer',
       COUNT(*)
FROM staging.orders o
LEFT JOIN staging.customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT '08. Orders with no items (mostly canceled/unavailable)',
       COUNT(*)
FROM staging.orders o
WHERE NOT EXISTS (SELECT 1 FROM staging.order_items i WHERE i.order_id = o.order_id)
UNION ALL
SELECT '09. Orders with no payment record',
       COUNT(*)
FROM staging.orders o
WHERE NOT EXISTS (SELECT 1 FROM staging.order_payments p WHERE p.order_id = o.order_id)

-- ---------------------------------------------------------------
-- 3. Completeness: nulls in important columns
-- ---------------------------------------------------------------
UNION ALL
SELECT '10. Products with no category',
       COUNT(*) FILTER (WHERE product_category_name IS NULL)
FROM staging.products
UNION ALL
SELECT '11. Product categories with no English translation',
       COUNT(DISTINCT p.product_category_name)
FROM staging.products p
LEFT JOIN staging.category_translation t USING (product_category_name)
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL
UNION ALL
SELECT '12. Delivered orders missing the customer delivery date',
       COUNT(*)
FROM staging.orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL
UNION ALL
SELECT '13. Payments with payment_type = not_defined',
       COUNT(*)
FROM staging.order_payments
WHERE payment_type = 'not_defined'

-- ---------------------------------------------------------------
-- 4. Validity: values and dates that make sense
-- ---------------------------------------------------------------
UNION ALL
SELECT '14. Items with price <= 0',
       COUNT(*)
FROM staging.order_items
WHERE price <= 0
UNION ALL
SELECT '15. Delivered to customer BEFORE handed to carrier',
       COUNT(*)
FROM staging.orders
WHERE order_delivered_customer_date < order_delivered_carrier_date
UNION ALL
SELECT '16. Delivered BEFORE purchase (impossible)',
       COUNT(*)
FROM staging.orders
WHERE order_delivered_customer_date < order_purchase_timestamp
UNION ALL
SELECT '17. Review scores outside 1-5',
       COUNT(*)
FROM staging.order_reviews
WHERE review_score NOT BETWEEN 1 AND 5

-- ---------------------------------------------------------------
-- 5. Consistency: does the money add up?
--    Payments per order should equal items + freight per order.
-- ---------------------------------------------------------------
UNION ALL
SELECT '18. Orders where payments differ from items + freight by more than $1',
       COUNT(*)
FROM (
    SELECT order_id, SUM(price + freight_value) AS item_total
    FROM staging.order_items GROUP BY order_id
) i
JOIN (
    SELECT order_id, SUM(payment_value) AS paid_total
    FROM staging.order_payments GROUP BY order_id
) p USING (order_id)
WHERE ABS(i.item_total - p.paid_total) > 1
ORDER BY check_name;

-- ---------------------------------------------------------------
-- 6. Coverage: orders per month (shows incomplete edge months)
-- ---------------------------------------------------------------
SELECT TO_CHAR(DATE_TRUNC('month', order_purchase_timestamp), 'YYYY-MM') AS month,
       COUNT(*) AS orders
FROM staging.orders
GROUP BY 1
ORDER BY 1;
