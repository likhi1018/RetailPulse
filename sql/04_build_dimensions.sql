/* =====================================================================
   RetailPulse | 04_build_dimensions.sql
   Purpose : Build the dimension tables of the star schema.
             dim_date, dim_geography, dim_customer, dim_product, dim_seller
   Run     : psql -d retailpulse -f sql/04_build_dimensions.sql
   ===================================================================== */

DROP SCHEMA IF EXISTS analytics CASCADE;
CREATE SCHEMA analytics;

-- ---------------------------------------------------------------
-- dim_date : one row per calendar day covering the whole dataset
-- ---------------------------------------------------------------
CREATE TABLE analytics.dim_date AS
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT          AS date_key,
    d::DATE                              AS date,
    EXTRACT(YEAR    FROM d)::INT         AS year,
    EXTRACT(QUARTER FROM d)::INT         AS quarter_num,
    'Q' || EXTRACT(QUARTER FROM d)       AS quarter,
    EXTRACT(MONTH   FROM d)::INT         AS month_num,
    TO_CHAR(d, 'Mon')                    AS month_name,
    TO_CHAR(d, 'YYYY-MM')                AS year_month,
    DATE_TRUNC('month', d)::DATE         AS month_start,
    EXTRACT(ISODOW  FROM d)::INT         AS weekday_num,   -- 1 = Monday
    TO_CHAR(d, 'Dy')                     AS weekday_name,
    EXTRACT(ISODOW  FROM d) IN (6, 7)    AS is_weekend
FROM GENERATE_SERIES('2016-09-01'::DATE, '2018-10-31'::DATE, INTERVAL '1 day') AS d;

ALTER TABLE analytics.dim_date ADD PRIMARY KEY (date_key);

-- ---------------------------------------------------------------
-- dim_geography : one row per Brazilian state, grouped into the
--                 5 official regions
-- ---------------------------------------------------------------
CREATE TABLE analytics.dim_geography (
    state_code  CHAR(2) PRIMARY KEY,
    state_name  TEXT,
    region      TEXT
);

INSERT INTO analytics.dim_geography VALUES
('AC','Acre','North'), ('AP','Amapa','North'), ('AM','Amazonas','North'),
('PA','Para','North'), ('RO','Rondonia','North'), ('RR','Roraima','North'),
('TO','Tocantins','North'),
('AL','Alagoas','Northeast'), ('BA','Bahia','Northeast'), ('CE','Ceara','Northeast'),
('MA','Maranhao','Northeast'), ('PB','Paraiba','Northeast'), ('PE','Pernambuco','Northeast'),
('PI','Piaui','Northeast'), ('RN','Rio Grande do Norte','Northeast'), ('SE','Sergipe','Northeast'),
('DF','Distrito Federal','Central-West'), ('GO','Goias','Central-West'),
('MT','Mato Grosso','Central-West'), ('MS','Mato Grosso do Sul','Central-West'),
('ES','Espirito Santo','Southeast'), ('MG','Minas Gerais','Southeast'),
('RJ','Rio de Janeiro','Southeast'), ('SP','Sao Paulo','Southeast'),
('PR','Parana','South'), ('RS','Rio Grande do Sul','South'), ('SC','Santa Catarina','South');

-- ---------------------------------------------------------------
-- dim_customer : one row per REAL customer (customer_unique_id).
--   customer_id in the raw data changes on every order, so it can't
--   be used to measure repeat purchases.
--   Location = the customer's most recent order address.
--   Cohort   = month of the first DELIVERED order.
-- ---------------------------------------------------------------
CREATE TABLE analytics.dim_customer AS
WITH customer_orders AS (
    SELECT c.customer_unique_id,
           c.customer_city,
           c.customer_state,
           o.order_id,
           o.order_status,
           o.order_purchase_timestamp,
           ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
                              ORDER BY o.order_purchase_timestamp DESC) AS rn_latest
    FROM staging.customers c
    JOIN staging.orders    o ON o.customer_id = c.customer_id
),
delivered_stats AS (
    SELECT customer_unique_id,
           MIN(order_purchase_timestamp)::DATE AS first_order_date,
           MAX(order_purchase_timestamp)::DATE AS last_order_date,
           COUNT(*)                            AS delivered_orders
    FROM customer_orders
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY co.customer_unique_id)::INT  AS customer_key,
    co.customer_unique_id,
    INITCAP(co.customer_city)                                AS city,
    co.customer_state                                        AS state_code,
    g.region,
    ds.first_order_date,
    ds.last_order_date,
    DATE_TRUNC('month', ds.first_order_date)::DATE           AS cohort_month,
    COALESCE(ds.delivered_orders, 0)                         AS delivered_orders,
    CASE WHEN ds.delivered_orders >= 2 THEN 'Repeat'
         WHEN ds.delivered_orders  = 1 THEN 'One-time'
         ELSE 'No delivered order' END                       AS customer_type
FROM customer_orders co
LEFT JOIN delivered_stats         ds USING (customer_unique_id)
LEFT JOIN analytics.dim_geography g  ON g.state_code = co.customer_state
WHERE co.rn_latest = 1;

ALTER TABLE analytics.dim_customer ADD PRIMARY KEY (customer_key);
CREATE UNIQUE INDEX ON analytics.dim_customer (customer_unique_id);

-- Bridge used while building facts: per-order customer_id -> customer_key
CREATE TABLE analytics.map_customer AS
SELECT c.customer_id, dc.customer_key
FROM staging.customers c
JOIN analytics.dim_customer dc USING (customer_unique_id);
CREATE UNIQUE INDEX ON analytics.map_customer (customer_id);

-- ---------------------------------------------------------------
-- dim_product : one row per product, English category names.
--   Two categories are missing from the translation file and 610
--   products have no category; both are handled explicitly.
-- ---------------------------------------------------------------
CREATE TABLE analytics.dim_product AS
WITH translated AS (
    SELECT p.product_id,
           p.product_category_name AS category_pt,
           COALESCE(
               t.product_category_name_english,
               CASE p.product_category_name
                    WHEN 'pc_gamer' THEN 'pc_gamer'
                    WHEN 'portateis_cozinha_e_preparadores_de_alimentos'
                         THEN 'portable_kitchen_appliances'
               END,
               'unknown') AS category_raw,
           p.product_weight_g,
           p.product_photos_qty
    FROM staging.products p
    LEFT JOIN staging.category_translation t USING (product_category_name)
)
SELECT
    ROW_NUMBER() OVER (ORDER BY product_id)::INT         AS product_key,
    product_id,
    COALESCE(category_pt, 'unknown')                     AS category_pt,
    INITCAP(REPLACE(category_raw, '_', ' '))             AS category,
    product_weight_g,
    CASE WHEN product_weight_g IS NULL  THEN 'Unknown'
         WHEN product_weight_g <  500   THEN '1. Light (<0.5 kg)'
         WHEN product_weight_g < 2000   THEN '2. Medium (0.5-2 kg)'
         WHEN product_weight_g < 10000  THEN '3. Heavy (2-10 kg)'
         ELSE                                '4. Very heavy (10+ kg)' END AS weight_class,
    product_photos_qty
FROM translated;

ALTER TABLE analytics.dim_product ADD PRIMARY KEY (product_key);
CREATE UNIQUE INDEX ON analytics.dim_product (product_id);

-- ---------------------------------------------------------------
-- dim_seller : one row per seller
-- ---------------------------------------------------------------
CREATE TABLE analytics.dim_seller AS
SELECT
    ROW_NUMBER() OVER (ORDER BY s.seller_id)::INT  AS seller_key,
    s.seller_id,
    INITCAP(s.seller_city)                         AS city,
    s.seller_state                                 AS state_code,
    g.region
FROM staging.sellers s
LEFT JOIN analytics.dim_geography g ON g.state_code = s.seller_state;

ALTER TABLE analytics.dim_seller ADD PRIMARY KEY (seller_key);
CREATE UNIQUE INDEX ON analytics.dim_seller (seller_id);

-- Row counts for a quick sanity check
SELECT 'dim_date' AS table_name, COUNT(*) AS rows FROM analytics.dim_date
UNION ALL SELECT 'dim_geography', COUNT(*) FROM analytics.dim_geography
UNION ALL SELECT 'dim_customer',  COUNT(*) FROM analytics.dim_customer
UNION ALL SELECT 'dim_product',   COUNT(*) FROM analytics.dim_product
UNION ALL SELECT 'dim_seller',    COUNT(*) FROM analytics.dim_seller
ORDER BY table_name;
