/* =====================================================================
   RetailPulse | 09_export_processed.sql
   Purpose : Export the modeled star schema to CSV for Power BI.
   Run     : from the REPO ROOT folder:
             psql -d retailpulse -f sql/09_export_processed.sql
   Output  : one CSV per table in data/processed/
   ===================================================================== */

\copy (SELECT * FROM analytics.dim_date      ORDER BY date_key)      TO 'data/processed/dim_date.csv'      WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM analytics.dim_geography ORDER BY state_code)    TO 'data/processed/dim_geography.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM analytics.dim_customer  ORDER BY customer_key)  TO 'data/processed/dim_customer.csv'  WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM analytics.dim_product   ORDER BY product_key)   TO 'data/processed/dim_product.csv'   WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM analytics.dim_seller    ORDER BY seller_key)    TO 'data/processed/dim_seller.csv'    WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM analytics.fact_sales    ORDER BY order_id, order_item_id) TO 'data/processed/fact_sales.csv'  WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM analytics.fact_orders   ORDER BY order_id)      TO 'data/processed/fact_orders.csv'   WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM analytics.customer_rfm  ORDER BY customer_key)  TO 'data/processed/customer_rfm.csv'  WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM analytics.cohort_retention ORDER BY cohort_month, month_index) TO 'data/processed/cohort_retention.csv' WITH (FORMAT csv, HEADER true)
