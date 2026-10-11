/* =====================================================================
   RetailPulse | run_all.sql
   Runs the whole pipeline in order. From the REPO ROOT folder:

       createdb retailpulse
       psql -d retailpulse -f sql/run_all.sql

   Takes under a minute on a laptop.
   ===================================================================== */
\set ON_ERROR_STOP on
\echo '01 Creating staging tables...'
\i sql/01_create_staging.sql
\echo '02 Loading raw CSVs...'
\i sql/02_load_data.sql
\echo '03 Data-quality checks...'
\i sql/03_data_quality_checks.sql
\echo '04 Building dimensions...'
\i sql/04_build_dimensions.sql
\echo '05 Building facts + reconciliation...'
\i sql/05_build_facts.sql
\echo '06 Sales analysis...'
\i sql/06_analysis_sales.sql
\echo '07 Customer analysis (RFM, cohorts)...'
\i sql/07_analysis_customers.sql
\echo '08 Delivery analysis...'
\i sql/08_analysis_delivery.sql
\echo '09 Exporting processed tables...'
\i sql/09_export_processed.sql
\echo 'Done. Processed CSVs are in data/processed/'
