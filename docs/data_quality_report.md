# Data Quality Report

Produced by [`sql/03_data_quality_checks.sql`](../sql/03_data_quality_checks.sql) on the raw staging tables, before any modeling.
Every issue found is listed with how it was handled, so every number in the dashboard can be traced back to a decision.

## Row counts loaded

| Table | Rows |
|---|---:|
| orders | 99,441 |
| order_items | 112,650 |
| customers | 99,441 |
| products | 32,951 |
| sellers | 3,095 |
| order_payments | 103,886 |
| order_reviews | 100,000 |
| category_translation | 71 |

## Check results

| # | Check | Issues | How it was handled |
|---|---|---:|---|
| 01 | Duplicate `review_id` values | 827 | Not used as a key. Reviews are matched to orders by `order_id`. |
| 02 | Orders with more than one review | 555 | Kept only the **latest** review per order (`ROW_NUMBER()` by answer timestamp). |
| 03 | Per-order `customer_id` rows vs. real customers | 3,345 | `customer_id` is regenerated on every order. All customer analysis uses **`customer_unique_id`** (96,096 real customers). |
| 04 | Order items with no matching order | 0 | — |
| 05 | Order items with no matching product | 0 | — |
| 06 | Order items with no matching seller | 0 | — |
| 07 | Orders with no matching customer | 0 | — |
| 08 | Orders with no items | 775 | 767 of them are canceled/unavailable. Kept in `fact_orders` (cancellation KPI), absent from `fact_sales`. |
| 09 | Orders with no payment record | 1 | Kept; payment fields are blank for that order. |
| 10 | Products with no category | 610 | Labeled **"Unknown"** so their revenue is not lost (R$170.7K, 1.3%). |
| 11 | Categories missing from the translation file | 2 | `pc_gamer` and `portateis_cozinha_e_preparadores_de_alimentos` translated manually in SQL. |
| 12 | Delivered orders missing the delivery date | 8 | Counted as revenue (they were delivered) but excluded from delivery-time metrics. |
| 13 | Payments with type `not_defined` | 3 | Left as is; too few to matter (all on canceled orders). |
| 14 | Items with price <= 0 | 0 | — |
| 15 | Delivered to customer before handed to carrier | 23 | Source timestamp errors. Kept; delivery days are measured purchase -> customer, which is unaffected. |
| 16 | Delivered before purchase | 0 | — |
| 17 | Review scores outside 1-5 | 0 | — |
| 18 | Payments differ from items + freight by > R$1 | 249 | Mostly installment interest: 229 of them were paid in installments and paid *more* than the item total. Revenue is measured from **item price**, not payments, so totals are unaffected. |

## Coverage: incomplete months

Orders per month show that the edges of the dataset are sparse:

| Month | Orders |
|---|---:|
| 2016-09 | 4 |
| 2016-10 | 324 |
| 2016-12 | 1 |
| 2018-09 | 16 |
| 2018-10 | 4 |

**Decision:** trend charts, growth rates and cohort analysis use **complete months only (Jan 2017 - Aug 2018)**.
Otherwise the last month would look like a 99% revenue crash that never happened.

## Reconciliation after modeling

[`sql/05_build_facts.sql`](../sql/05_build_facts.sql) ends with a reconciliation check. The star schema matches the source exactly:

| Check | Staging | Model |
|---|---:|---:|
| Delivered item revenue | R$13,221,498.11 | R$13,221,498.11 |
| Orders | 99,441 | 99,441 |
