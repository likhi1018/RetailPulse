# Power BI Dashboard Build Guide

Step-by-step instructions to build `powerbi/RetailPulse.pbix` from the processed data.
Plan on about 2-3 hours the first time.

---

## 0. Where to run Power BI on a Mac

Power BI Desktop runs only on Windows. Options, best first:

| Option | Notes |
|---|---|
| **Windows 11 in Parallels Desktop or UTM** | Full Power BI Desktop, saves a `.pbix`. Best result. Parallels has a free trial; UTM is free. |
| **Any Windows PC** (university lab, friend's laptop) | Copy the repo folder over and follow this guide. |
| **Power BI in the browser** (app.powerbi.com) | Needs a work/school account or a Fabric trial. You can build reports and DAX online, but loading local CSVs with Power Query in the browser requires a Fabric Dataflow Gen2. Treat it as a fallback. |

---

## 1. Load the data (Power Query)

1. Open Power BI Desktop -> **Transform data**.
2. **Manage Parameters -> New Parameter**: `DataFolder`, type Text, value = full path to `data/processed/` **ending with a backslash**.
3. For each file in [`powerquery/`](../powerquery): **New Source -> Blank Query -> Advanced Editor**, paste the script, and name the query exactly as the file name:
   `FactSales`, `FactOrders`, `DimCustomer`, `DimProduct`, `DimSeller`, `DimGeography`, `DimDate`, `CustomerRFM`, `CohortRetention`.
4. **Close & Apply**.

> `DimDate` is generated in Power Query, so you do **not** need `dim_date.csv` in Power BI.

## 2. Model the relationships (Model view)

Create these relationships (Many-to-one, **single** direction, unless noted):

| From (many) | To (one) |
|---|---|
| FactSales[date_key] | DimDate[DateKey] |
| FactOrders[date_key] | DimDate[DateKey] |
| FactSales[customer_key] | DimCustomer[customer_key] |
| FactOrders[customer_key] | DimCustomer[customer_key] |
| FactSales[product_key] | DimProduct[product_key] |
| FactSales[seller_key] | DimSeller[seller_key] |
| DimCustomer[state_code] | DimGeography[state_code] |
| CustomerRFM[customer_key] | DimCustomer[customer_key] — **one-to-one, both directions** |

`CohortRetention` has **no** relationships.

Then:
- Select `DimDate` -> **Mark as date table** -> `Date`.
- Sort `DimDate[Month]` by `MonthNum`.
- Hide all key columns (`*_key`, `DateKey`) from report view.
- Set `DimGeography[map_location]` data category to **Place**.

## 3. Add the measures (DAX)

1. **Home -> Enter data** -> name the table `_Measures` -> Load.
2. Create two what-if parameters (**Modeling -> New parameter -> Numeric range**):
   - `COGS %`: min 0.40, max 0.80, increment 0.05, default 0.60
   - `Freight Subsidy %`: min 0, max 1, increment 0.25, default 0
3. Add every measure from [`dax/measures.dax`](../dax/measures.dax) into `_Measures`, putting each in the display folder shown in the file.
4. Format: money measures `R$ #,0`, percentages `0.0%`, review scores `0.00`.
5. Delete the empty default column in `_Measures`. It becomes a measure table with a calculator icon.

**Validation:** put these on cards and compare with the SQL results in the README.

| Measure | Expected |
|---|---|
| Total Revenue | R$13,221,498 |
| Total Orders | 96,478 |
| AOV | R$137.04 |
| Unique Customers | 93,358 |
| Repeat Customer % | 3.0% |
| On-Time Rate % (delivered orders) | 93.2% |
| Avg Review Score (delivered orders) | 4.14 |

If a card doesn't match, a relationship or a filter is wrong. Fix it before building visuals.

## 4. Build the pages

Canvas: 1280 x 720. One light background, one accent color (blue) for actuals, grey for prior year, orange/red **only** for problems.
Put these slicers on every page and sync them (**View -> Sync slicers**): `DimDate[Date]` (between), `DimGeography[region]`, `DimProduct[category]`.

### Page 1 - Executive Overview
- 6 KPI cards: Total Revenue, Total Orders, AOV, Unique Customers, Avg Review Score, On-Time Rate %. Add Revenue YoY % as the card's reference label.
- Line chart: `DimDate[YearMonth]` x Total Revenue, filtered to `IsCompleteMonth = TRUE`.
- Filled map or bar chart: Total Revenue by `DimGeography[state_name]`.
- Bar chart: Top 10 categories (Top N filter on Total Revenue).

### Page 2 - Sales & Products
- Combo chart: `DimProduct[category]` x Total Revenue (bars) and Category Cumulative Revenue % (line). This is the Pareto chart.
- Matrix: category | Total Revenue | Total Orders | AOV | Freight % of Revenue | Est Gross Margin %.
- Table: Top 20 sellers (`DimSeller[seller_label]`, Total Revenue, Total Orders, Seller Rank).
- Slicer for the `COGS %` parameter, with a text box: *"Margin is estimated - the dataset contains no product cost."*

### Page 3 - Customers
- Cards: Unique Customers, Repeat Customer %, Revenue per Customer.
- Bar chart: `CustomerRFM[segment]` x RFM Revenue Share %, with RFM Customers in the tooltip.
- Matrix heat map: rows `CohortRetention[cohort_label]`, columns `month_index`, values Cohort Retention %. Use a background color scale and filter `month_index` to 1-6.
- Bar chart: Unique Customers by region.

### Page 4 - Delivery & Satisfaction
- Clustered column: `FactOrders[delay_bucket]` x Avg Review Score. Use data labels. **This is the headline chart.**
- Card: `Title Late Delivery Insight` (dynamic text).
- Line chart: `DimDate[YearMonth]` x On-Time Rate %.
- Bar chart: Late Rate % by `DimGeography[state_name]`, filtered to states with 500+ delivered orders.
- Card: Bad Review %.

### Page 5 - Insights & Actions
Text boxes with the 5 findings and recommendations from the README. Add a button or bookmark on each finding that jumps to the page with the evidence.

## 5. Finish

- Add a drill-through page: right-click a category -> see its sellers, monthly trend and reviews.
- Turn on **custom tooltips** for the trend chart (orders, AOV, YoY).
- Save as `powerbi/RetailPulse.pbix`.
- Export a screenshot of each page to `docs/images/` (`dashboard_1_overview.png` ... `dashboard_5_insights.png`) and add them to the README.
- Commit and push.
