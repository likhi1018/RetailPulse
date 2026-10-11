/* =====================================================================
   RetailPulse | 02_load_data.sql
   Purpose : Load the raw Olist CSVs into the staging tables.
   Run     : from the REPO ROOT folder (paths are relative):
             psql -d retailpulse -f sql/02_load_data.sql
   Note    : \copy runs on your machine (client side), so no server
             file permissions are needed.
   ===================================================================== */

TRUNCATE staging.orders, staging.order_items, staging.customers, staging.products,
         staging.sellers, staging.order_payments, staging.order_reviews,
         staging.category_translation;

\copy staging.orders               FROM 'data/raw/olist_orders_dataset.csv'               WITH (FORMAT csv, HEADER true)
\copy staging.order_items          FROM 'data/raw/olist_order_items_dataset.csv'          WITH (FORMAT csv, HEADER true)
\copy staging.customers            FROM 'data/raw/olist_customers_dataset.csv'            WITH (FORMAT csv, HEADER true)
\copy staging.products             FROM 'data/raw/olist_products_dataset.csv'             WITH (FORMAT csv, HEADER true)
\copy staging.sellers              FROM 'data/raw/olist_sellers_dataset.csv'              WITH (FORMAT csv, HEADER true)
\copy staging.order_payments       FROM 'data/raw/olist_order_payments_dataset.csv'       WITH (FORMAT csv, HEADER true)
\copy staging.order_reviews        FROM 'data/raw/olist_order_reviews_dataset.csv'        WITH (FORMAT csv, HEADER true)
\copy staging.category_translation FROM 'data/raw/product_category_name_translation.csv'  WITH (FORMAT csv, HEADER true)

-- Quick confirmation of what was loaded
SELECT 'orders' AS table_name, COUNT(*) AS rows FROM staging.orders
UNION ALL SELECT 'order_items',          COUNT(*) FROM staging.order_items
UNION ALL SELECT 'customers',            COUNT(*) FROM staging.customers
UNION ALL SELECT 'products',             COUNT(*) FROM staging.products
UNION ALL SELECT 'sellers',              COUNT(*) FROM staging.sellers
UNION ALL SELECT 'order_payments',       COUNT(*) FROM staging.order_payments
UNION ALL SELECT 'order_reviews',        COUNT(*) FROM staging.order_reviews
UNION ALL SELECT 'category_translation', COUNT(*) FROM staging.category_translation;
