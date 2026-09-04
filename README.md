# E-Commerce Customer & Delivery Analysis

An end-to-end data analytics portfolio project exploring customer behavior, revenue performance, seller activity, payments, and delivery experience using the Brazilian E-Commerce Public Dataset by Olist.

The project is being developed as a practical **Data Analyst / Business Intelligence** case study using SQL, MySQL, Python/Pandas, Jupyter Notebook, and later Power BI/DAX.

The workflow now includes three main layers:

```text
Raw Olist CSV Files
        ↓
MySQL Raw / Relational Tables
        ↓
Data Quality & Validation
        ↓
Analytics-Ready Fact / Dimension Views
        ↓
SQL Business Analysis + Python/Pandas
        ↓
Insights & Recommendations
        ↓
Power BI / DAX
        ↓
Dashboard Storytelling
```

Each major analysis follows the same decision-oriented structure:

> **Business Question → Analysis → Insight → Recommendation**

The goal is not only to describe what happened, but to identify likely drivers, validate the underlying data, and translate findings into practical business actions.

## Project Objectives

The project focuses on questions such as:

- How do delivered-order volume and product revenue change over time?
- What drives changes in revenue and Average Order Value (AOV)?
- Is a higher average item price caused by broad price movement or by product/category mix?
- Which products, sellers, customer groups, and geographic segments generate the most value?
- How frequently do customers make repeat purchases?
- Which payment methods are most commonly used?
- How reliable is the delivery process?
- How common are late deliveries?
- How does delivery performance affect customer review scores?

## Dataset

This project uses the **Brazilian E-Commerce Public Dataset by Olist**, covering approximately 100,000 orders and multiple related datasets:

- Customers
- Orders
- Order items
- Payments
- Reviews
- Products
- Sellers
- Product-category translation
- Geolocation

Raw CSV files are stored locally and excluded from GitHub using `.gitignore`.

## Tools & Technologies

### Current

- SQL
- MySQL
- DBeaver
- Python
- Pandas
- SQLAlchemy / PyMySQL
- Jupyter Notebook
- Git
- GitHub

### Planned

- Power BI
- DAX

## Data Architecture

### Raw / Relational Layer

The current MySQL source model includes:

```text
customers
    │
    └── orders
          ├── order_items ── products ── product_category_name_translation
          │       │
          │       └── sellers
          ├── order_payments
          └── order_reviews
```

Raw source tables remain unchanged after ingestion. Data-quality issues are investigated rather than silently removed.

### Analytics Layer

An analytics-ready layer has now been created on top of the source tables using reusable MySQL views:

```text
dim_customers
dim_products
dim_sellers
dim_date

fact_orders
fact_order_items
```

The purpose of this layer is to centralize business logic and preserve clear grains so that SQL analysis and future Power BI reporting do not need to rebuild the same joins repeatedly.

#### `fact_orders`

**Grain: one row per `order_id`**

Contains reusable order-level attributes and metrics including:

- Customer key
- Purchase and lifecycle timestamps
- Delivery duration
- Delay relative to estimated delivery date
- Late-delivery flag
- Item count
- Distinct product count
- Seller count
- Product revenue
- Freight value
- Aggregated payment value
- Payment-record and payment-type counts
- Latest review score

Before joining to orders:

- `order_items` is aggregated to one row per order.
- `order_payments` is aggregated to one row per order.
- Multiple reviews are reduced to the **latest review** using `ROW_NUMBER()` ordered by review timestamps.

This prevents one-to-many joins from multiplying order-level metrics.

#### `fact_order_items`

**Grain: one row per `order_id + order_item_id`**

Contains item-level fields used for product and seller analysis:

- Order
- Customer
- Product
- Seller
- Purchase date
- Order status
- Shipping limit date
- Item price
- Freight value

Order-level payment and review metrics are intentionally not stored here because they would repeat across item rows and could be double-counted.

#### Dimensions

- `dim_customers`: one row per `customer_id`
- `dim_products`: one row per `product_id`, including cleaned category naming
- `dim_sellers`: one row per `seller_id`
- `dim_date`: one row per calendar date

The date dimension currently covers **2016-09-04 through 2018-11-12**, with **800 distinct calendar dates**.

### Analytics-Layer Validation

The analytics layer was validated for:

- Grain preservation
- Raw-vs-view row-count consistency
- Unique fact/dimension keys
- Complete calendar-date coverage
- Source-level referential integrity

Validated source relationships returned **0 unmatched records** for:

- `orders → customers`
- `order_items → products`
- `order_items → sellers`

Source-level referential checks are used instead of unnecessarily expensive nested view-to-view joins.

## Grain Principles

Understanding table grain is treated as a core part of the project.

- `customers`: one row per `customer_id`
- `orders`: one row per `order_id`
- `order_items`: one row per item within an order
- `order_payments`: one row per payment record within an order
- `order_reviews`: one row per review-order record
- `sellers`: one row per `seller_id`
- `fact_orders`: one row per `order_id`
- `fact_order_items`: one row per `order_id + order_item_id`

Because several child tables have one-to-many relationships with orders, they are aggregated to the required grain before being joined for order-level analysis.

## Data Quality & Validation

The core question behind the quality workflow is:

> **Can this data be trusted for the metric being calculated?**

The project follows a non-destructive approach:

> **Detect → Segment → Inspect → Interpret → Decide**

An anomaly in one field does not automatically invalidate the entire record. A row is excluded only from metrics directly affected by the unreliable field.

### Customers

- 99,441 customer records
- 99,441 unique `customer_id` values
- 96,096 unique customers based on `customer_unique_id`
- 2,997 repeat customers identified
- Maximum observed purchase frequency: 17
- No critical null or duplicate `customer_id` issues

The dataset uses two customer identifiers:

- `customer_id` connects an order to a customer record.
- `customer_unique_id` identifies the same customer across multiple purchases.

### Orders

- 99,441 orders
- Approximately 97% have `delivered` status
- Lifecycle timestamp inconsistencies were investigated
- Delivered orders with missing lifecycle timestamps were checked separately
- Referential integrity with customers was validated

Timestamp anomalies remain in the source data and are excluded only from duration metrics affected by those timestamps.

### Order Items

- 112,650 order-item records
- 98,666 orders contain at least one item
- No duplicate `(order_id, order_item_id)` combinations
- No non-positive product prices identified
- No negative freight values identified
- Orders without item records are concentrated mainly among unavailable and canceled orders

Item counts are calculated using `COUNT(*)` at order level rather than assuming the maximum sequence number equals the number of item records.

### Order Payments

- 103,886 payment records
- 99,440 orders have at least one payment record
- No duplicate `(order_id, payment_sequential)` combinations
- No null values in the checked payment fields
- No negative payment values
- Maximum observed payment records for one order: 29

Payment-type distribution at **payment-record grain** is approximately:

- Credit card: 74%
- Boleto: 19%
- Voucher: 6%
- Debit card: 1.5%

These percentages describe payment records, not unique orders.

Additional payment anomalies were investigated, including zero-value payment records, a delivered order without payment data, zero-installment credit-card records, and unusual payment-sequence behavior. Raw records were preserved where the anomaly did not invalidate the underlying business metric.

### Order Reviews

The reviews CSV was loaded through Pandas because DBeaver's CSV importer produced parsing errors.

- 99,224 review records
- 98,410 unique `review_id` values
- 98,673 unique `order_id` values
- 0 fully duplicated rows
- 789 different `review_id` values appear more than once
- 547 different `order_id` values appear more than once
- Maximum observed review records for one order: 3
- No duplicate `(review_id, order_id)` combinations
- Review scores contain only values from 1 to 5
- 87,656 null review titles
- 58,247 null review messages

Neither `review_id` nor `order_id` should be assumed to be individually unique in this source.

For order-level analysis, the working rule is to use the **latest review based on review timestamps** while preserving all raw review records.

### Sellers

The sellers dataset was inspected with Pandas and loaded into the explicitly created MySQL `sellers` table.

- 3,095 seller records
- 3,095 unique `seller_id` values
- 2,246 distinct seller ZIP-code prefixes
- 0 null values in the checked fields
- 0 full duplicate rows
- 0 blank city values
- 0 blank state values
- 0 invalid two-character state-code lengths

The Pandas and MySQL validation counts matched exactly:

- Total rows: 3,095
- Unique seller IDs: 3,095
- Unique ZIP-code prefixes: 2,246

The table is structurally suitable for seller-level and geographic analysis.

## Analysis Principles

### 1. Match the metric to the correct grain

Before joining tables:

> **One row = what?**

This prevents inflated counts, revenue, payment totals, and duplicated reviews.

### 2. Aggregate before joining when necessary

If order items, payments, and reviews are needed together at order grain, each one-to-many source is first reduced to one row per order.

### 3. Investigate anomalies before removing data

Unusual values are investigated in relational and business context before any filtering decision is made.

### 4. Separate analytical usability from raw-data preservation

Source data remains intact. Cleaning rules, latest-review logic, aggregations, and derived metrics are applied in the analytics layer or analysis query where required.

### 5. Turn results into business decisions

Each important analysis follows:

> **Business Question → Analysis → Insight → Recommendation**

## Revenue Performance Analysis

### Monthly Delivered Orders & Product Revenue

Product revenue is defined as:

```text
SUM(order_items.price)
```

for delivered orders. Freight is excluded from product revenue.

Key examples:

- November 2017: **7,289 delivered orders** and **987,765.37 BRL** product revenue
- May 2018: **6,749 delivered orders** and **977,544.69 BRL** product revenue

May generated almost the same product revenue as November despite fewer orders, showing that order volume alone does not explain monthly revenue performance.

### Revenue Driver Decomposition

Revenue analysis was decomposed through:

```text
Revenue
↓
Order Volume vs AOV
↓
Items per Order vs Average Item Price
↓
Category Mix vs Within-Category Average-Price Effect
```

The focused March-to-May 2018 analysis found:

- March average item price: **118.92 BRL**
- May average item price: **125.17 BRL**
- Total change: **+6.25 BRL per item**

Under the mix-first decomposition:

- **Category-mix effect:** +4.37 BRL/item, approximately **70%**
- **Within-category average-price effect:** +1.88 BRL/item, approximately **30%**

Main positive category-mix contributors included:

- watches_gifts
- housewares
- health_beauty

Main negative mix contributors included:

- computers_accessories
- sports_leisure
- office_furniture

An important example is `watches_gifts`: its category share increased strongly, producing a positive mix contribution, while its own within-category average-price contribution was negative.

### Revenue Insight

The higher average item price was driven primarily by a shift in **product/category composition**, not by a broad-based increase in prices across categories.

### Revenue Recommendation

Monitor higher-value categories gaining item share and investigate whether these shifts are seasonal, campaign-related, or persistent.

Product/category composition should be treated as a core driver when interpreting AOV and revenue movement.

**Caveat:** a within-category average-price effect does not prove that individual products became more expensive. It can also reflect a shift toward different products or SKUs within the same category.

## Delivery & Customer Experience Analysis

The next major analysis stream has now started using the new `fact_orders` analytics view.

The first business question is:

> **How reliable is overall delivery performance?**

The initial delivery analysis measures:

- Delivered-order count
- Average delivery duration
- Late-delivery rate
- Average delay among late orders

Planned follow-up questions include:

- Do late deliveries reduce review scores?
- How does customer satisfaction change as delays become longer?
- Which customer regions experience slower or less reliable delivery?
- Are there seller or geographic patterns associated with delivery performance?

This section is currently in progress.

## Python / Pandas Workflow

Python/Pandas runs in parallel with SQL.

Completed notebooks:

- `01_customer_data_inspection.ipynb`
- `02_order_reviews_ingestion_quality.ipynb`
- `03_sellers_ingestion_quality.ipynb`

Python is currently used for:

**Data preparation**

- CSV ingestion
- Schema inspection
- Null / duplicate / uniqueness checks
- Key and grain investigation
- Datetime conversion
- MySQL loading through SQLAlchemy
- Post-load validation

**Analytics**

- Exploratory analysis
- Grouping and aggregation
- Data merging
- Reproducible analysis steps
- Future deeper investigations that are more natural in Pandas than SQL

## Project Structure

```text
ecommerce-customer-delivery-analysis/
│
├── sql/
│   ├── 00_create_schema.sql
│   ├── 01_create_customers_table.sql
│   ├── 02_create_orders_table.sql
│   ├── 03_create_order_items_table.sql
│   ├── 04_create_order_payments_table.sql
│   ├── 05_create_products_table.sql
│   ├── 06_create_category_translation_table.sql
│   ├── 07_add_missing_category_translations.sql
│   ├── 08_create_order_reviews_table.sql
│   ├── 09_create_sellers_table.sql
│   ├── 10_data_quality_checks.sql
│   ├── 11_revenue_performance_analysis.sql
│   ├── 12_create_analytics_layer.sql
│   └── 13_delivery_customer_experience_analysis.sql
│
├── python/
│   ├── 01_customer_data_inspection.ipynb
│   ├── 02_order_reviews_ingestion_quality.ipynb
│   └── 03_sellers_ingestion_quality.ipynb
│
├── images/
├── README.md
└── .gitignore
```

## Current Status

🚧 **Work in progress**

### Completed

- Core MySQL relational schema
- Data-quality validation for customers, orders, order items, payments, reviews, products, and sellers
- Python ingestion / validation workflows for customers, order reviews, and sellers
- Revenue performance analysis
- AOV and average-item-price driver analysis
- Category-mix vs within-category decomposition
- Analytics-ready fact/dimension layer
- Grain and row-count validation for the analytics views
- Source-level referential-integrity checks

### Current Phase

**Delivery & Customer Experience Analysis**

The analytics foundation is now in place, so the next work focuses increasingly on:

> **What can the business learn and what should it do?**

rather than repeatedly rebuilding raw joins.

### Next Steps

1. Complete overall delivery-performance analysis.
2. Measure the relationship between late delivery and customer review score.
3. Add customer / seller / geographic deep dives.
4. Continue selected Python exploratory analysis.
5. Build the Power BI semantic model using the validated analytics layer.
6. Create the final executive and delivery/customer-experience dashboards.
7. Finalize insights, recommendations, and portfolio storytelling.

The working standard remains:

> **Business Question → Analysis → Insight → Recommendation**

After each major step, the workflow is also reviewed with one additional question:

> **Can this be done more simply, practically, or efficiently?**
