/* =====================================================================
   RetailPulse | 01_create_staging.sql
   Purpose : Create the staging layer. One table per raw Olist CSV,
             with proper data types. No business logic here.
   Run     : psql -d retailpulse -f sql/01_create_staging.sql
   ===================================================================== */

DROP SCHEMA IF EXISTS staging CASCADE;
CREATE SCHEMA staging;

-- One row per order. NOTE: customer_id is a per-order id, NOT the real person.
CREATE TABLE staging.orders (
    order_id                       TEXT PRIMARY KEY,
    customer_id                    TEXT NOT NULL,
    order_status                   TEXT,
    order_purchase_timestamp       TIMESTAMP,
    order_approved_at              TIMESTAMP,
    order_delivered_carrier_date   TIMESTAMP,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP
);

-- One row per item inside an order (order_id + order_item_id).
CREATE TABLE staging.order_items (
    order_id             TEXT,
    order_item_id        INT,
    product_id           TEXT,
    seller_id            TEXT,
    shipping_limit_date  TIMESTAMP,
    price                NUMERIC(10,2),
    freight_value        NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

-- One row per order-level customer record. customer_unique_id = the real person.
CREATE TABLE staging.customers (
    customer_id               TEXT PRIMARY KEY,
    customer_unique_id        TEXT NOT NULL,
    customer_zip_code_prefix  TEXT,
    customer_city             TEXT,
    customer_state            CHAR(2)
);

-- One row per product. Category names are in Portuguese.
-- ("lenght" is misspelled in the source file; we keep the original names here.)
CREATE TABLE staging.products (
    product_id                  TEXT PRIMARY KEY,
    product_category_name       TEXT,
    product_name_lenght         INT,
    product_description_lenght  INT,
    product_photos_qty          INT,
    product_weight_g            INT,
    product_length_cm           INT,
    product_height_cm           INT,
    product_width_cm            INT
);

CREATE TABLE staging.sellers (
    seller_id               TEXT PRIMARY KEY,
    seller_zip_code_prefix  TEXT,
    seller_city             TEXT,
    seller_state            CHAR(2)
);

-- An order can have several payments (e.g. voucher + credit card).
CREATE TABLE staging.order_payments (
    order_id              TEXT,
    payment_sequential    INT,
    payment_type          TEXT,
    payment_installments  INT,
    payment_value         NUMERIC(10,2)
);

-- review_id is NOT unique in the source, and some orders have several reviews,
-- so no primary key here. We deduplicate in the modeling layer.
CREATE TABLE staging.order_reviews (
    review_id                TEXT,
    order_id                 TEXT,
    review_score             INT,
    review_comment_title     TEXT,
    review_comment_message   TEXT,
    review_creation_date     TIMESTAMP,
    review_answer_timestamp  TIMESTAMP
);

CREATE TABLE staging.category_translation (
    product_category_name          TEXT PRIMARY KEY,
    product_category_name_english  TEXT
);
