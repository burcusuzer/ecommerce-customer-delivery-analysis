# E-Commerce Customer & Delivery Analysis

An end-to-end data analytics portfolio project exploring customer behavior, order performance, payments, and delivery operations using the Brazilian E-Commerce Public Dataset by Olist.

The project is being developed as a practical **Data Analyst / Business Intelligence** case study combining SQL, Python/Pandas, MySQL, and Power BI.

The initial SQL/MySQL phase established the relational data model, validated the core transactional tables, and began business analysis focused on revenue performance and its underlying drivers.

The project is now expanding into a **Python/Pandas data ingestion and quality workflow**, which will be used to load, inspect, validate, and prepare the remaining Olist datasets before continuing deeper SQL and exploratory analysis.

## Project Objectives

The main goal is to understand how an e-commerce business can improve customer experience and operational performance through data.

The analysis will focus on questions such as:

- How do order volume and revenue change over time?
- What drives changes in revenue and Average Order Value (AOV)?
- Which customer, product, and geographic segments generate the most value?
- How frequently do customers make repeat purchases?
- Which payment methods are most commonly used?
- How effectively are orders delivered?
- How common are late deliveries?
- How does delivery performance affect customer reviews?

Each major analysis will follow the same decision-oriented structure:

> **Business Question → Analysis → Insight → Recommendation**

The goal is not only to describe what happened, but also to identify likely drivers and translate findings into practical business actions.

## Dataset

This project uses the **Brazilian E-Commerce Public Dataset by Olist**, containing approximately 100,000 orders and multiple relational datasets covering:

- Customers
- Orders
- Order items
- Payments
- Reviews
- Products
- Sellers
- Geolocation

Raw CSV files are stored locally and excluded from GitHub using `.gitignore`.

## Tools & Technologies

### Current
- SQL
- MySQL
- DBeaver
- Git
- GitHub

### Next Phase
- Python
- Pandas
- Jupyter Notebook

### Planned
- Power BI
- DAX

## Current Data Model

The project currently includes SQL setup for the following relational datasets:

```text
customers
    │
    └── orders
          ├── order_items ── products ── category_translation
          ├── order_payments
          └── order_reviews
```

Core transactional tables have already been loaded and validated in MySQL. Product and category structures have also been added, while the data ingestion workflow for reviews and remaining datasets is being moved to Python/Pandas.

### Grain

Understanding table grain is treated as a core part of the analysis:

- `customers`: one row per `customer_id`
- `orders`: one row per `order_id`
- `order_items`: one row per item within an order
- `order_payments`: one row per payment record within an order

Because `order_items` and `order_payments` are both one-to-many relationships from `orders`, joining them directly can multiply rows. Order-level analysis will therefore aggregate child tables to the required grain before joining when necessary.

## Data Quality & Validation

Data quality checks are performed before business analysis to answer a simple question:

> **Can this data be trusted for the metric being calculated?**

The project follows a non-destructive approach: raw records are preserved, anomalies are investigated in context, and records are excluded only from metrics affected by the unreliable field.

### Customers

- 99,441 customer records
- 99,441 unique `customer_id` values
- 96,096 unique customers based on `customer_unique_id`
- 2,997 repeat customers identified
- Maximum observed purchase frequency: 17
- No critical null or duplicate `customer_id` issues identified

The dataset uses two customer identifiers:

- `customer_id` connects a customer record to an individual order.
- `customer_unique_id` identifies the same customer across multiple purchases.

### Orders

- 99,441 orders
- 97.02% of orders have `delivered` status
- Lifecycle timestamp inconsistencies were identified and investigated
- Delivered orders with missing lifecycle timestamps were checked separately
- Referential integrity between `orders` and `customers` was validated
- Timestamp anomalies are preserved in raw data and will only be excluded from affected duration metrics

A key validation principle from this stage is:

> An anomaly in one field does not automatically invalidate the entire order.

For example, an order with an unreliable approval-to-carrier timestamp may still remain valid for revenue, customer, product, or geography analysis.

### Order Items

- 112,650 order-item records
- 98,666 orders contain at least one item
- No duplicate `(order_id, order_item_id)` combinations identified
- No non-positive product prices identified
- No negative freight values identified
- Orders without item records are concentrated primarily among unavailable and canceled orders
- Referential integrity between `order_items` and `orders` was checked

Item counts are calculated with `COUNT(*)` at order level rather than assuming that the maximum sequence number always equals the number of item records.

### Order Payments

- 103,886 payment records
- 99,440 orders have at least one payment record
- No duplicate `(order_id, payment_sequential)` combinations identified
- No null values found in the checked payment fields
- No negative payment values found
- Maximum observed payment records for a single order: 29

Payment-type distribution at **payment-record grain**:

- Credit card: approximately 74%
- Boleto: approximately 19%
- Voucher: approximately 6%
- Debit card: approximately 1.5%

These percentages describe **payment records, not unique orders**, because a single order can have multiple payment rows or payment methods.

#### Investigated payment anomalies

**Zero-value payments**

Nine zero-value payment records were identified:

- 6 voucher records
- 3 `not_defined` records

The zero-value voucher records belong to orders that also contain positive payment records, so the affected orders do not have zero total payment.

The three `not_defined` zero-value records belong to canceled orders that were never approved, which is consistent with the order lifecycle.

**Delivered order without payment data**

One delivered order has no corresponding payment record:

`bfbd0f9bdef84302105ad712db648a6c`

The order contains:

- 3 items
- Product value: 134.97
- Freight value: 8.49

The order remains usable for analyses that do not depend on payment data, but it should be handled carefully in payment-based metrics.

**Credit-card records with zero installments**

Two credit-card payment records have `payment_installments = 0`.

Both orders were delivered normally, and in both cases the recorded `payment_value` exactly matches product value plus freight. The payment amount therefore appears usable even though the installment metadata is unusual.

**Payment sequence behavior**

- 80 orders have available payment sequences that do not start at 1
- No internal sequence gaps were found
- `(order_id, payment_sequential)` remains unique

This is treated as a minor dataset quirk rather than a critical quality error.

## Data Quality Strategy

The validation workflow follows a reusable pattern:

1. Check row count and entity coverage.
2. Confirm table grain.
3. Validate uniqueness and key behavior.
4. Check null values.
5. Inspect numeric ranges and impossible values.
6. Review categorical distributions.
7. Validate relationships between tables.
8. Investigate table-specific anomalies.
9. Exclude only records or fields that affect the metric being calculated.

For unfamiliar datasets, this provides a repeatable QC framework instead of relying on ad hoc checks.

## Analysis Principles

### 1. Match the metric to the correct grain

Before joining tables, ask:

> **One row = what?**

This prevents inflated counts, revenue, or payment totals caused by one-to-many joins.

### 2. Aggregate before joining when necessary

If both `order_items` and `order_payments` are needed in an order-level analysis, each child table can first be aggregated to `order_id` before joining.

This avoids join multiplication such as:

```text
4 item rows × 3 payment rows = 12 joined rows
```

### 3. Investigate anomalies before removing data

The working pattern is:

> **Detect → Segment → Inspect → Interpret → Decide**

Unusual values are not automatically deleted. Their business and relational context is checked first.

### 4. Turn SQL results into business decisions

Each important analysis will be documented as:

> **Business Question → Analysis → Insight → Recommendation**

The final portfolio should answer not only **“What happened?”**, but also **“Why does it matter, and what should the business do next?”**

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
│   ├── 10_data_quality_checks.sql
│   └── 11_business_analysis.sql
│
├── python/
├── images/
├── README.md
└── .gitignore
```

## Business Analysis Progress

### 1. Monthly Order Volume & Product Revenue

**Business Question**

How have completed order volume and product revenue changed over time?

**Metric definitions**

- Completed orders: distinct orders with `order_status = 'delivered'`
- Product revenue: `SUM(order_items.price)` for delivered orders
- Freight is excluded from product revenue
- Monthly grouping is based on `order_purchase_timestamp`

**Grain consideration**

Joining `orders` to `order_items` changes the result from order grain to order-item grain. Therefore:

- `COUNT(DISTINCT order_id)` is used for completed-order volume
- `SUM(price)` is used for product revenue

**Key findings**

- Delivered-order volume and product revenue grew strongly throughout 2017.
- November 2017 shows a major spike with **7,289 delivered orders** and **987,765.37** in product revenue.
- Performance became more stable during 2018, with monthly delivered orders generally around 6,000–7,000.
- May 2018 generated **977,544.69** in product revenue from **6,749 delivered orders**, almost matching November 2017 revenue despite having fewer orders.
- This difference suggests that monthly revenue performance cannot be explained by order volume alone.

**Current insight**

Revenue growth appears to be influenced by both order volume and changes in average value per order. The next step is to decompose revenue into its main drivers before making pricing, promotion, or category recommendations.

**Driver hypotheses to test**

- Order volume
- Average Order Value (AOV)
- Product and category mix
- Higher-priced product categories
- Items purchased per order
- Geographic differences
- New vs. repeat customer composition
- Seasonal demand or promotional periods

These remain hypotheses until validated with further analysis.

### Next SQL Analysis

The next step is:

> **Revenue decomposition → Order Volume + Average Order Value (AOV)**

This will help determine whether monthly revenue changes are primarily driven by more orders, higher value per order, or a combination of both.

### Planned Later Analyses

- Customer geographic analysis
- Repeat customer behavior
- Payment method analysis
- Product category performance
- Delivery time analysis
- Late delivery rate
- Delivery performance vs. review score
- Customer segmentation

## Planned Workflow

```text
Raw Olist CSV Files
        ↓
Python / Pandas
Data Ingestion & Inspection
        ↓
Data Quality & Cleaning
        ↓
MySQL Relational Tables
        ↓
SQL Business Analysis
        ↓
Insights & Recommendations
        ↓
Python EDA & Feature Engineering
        ↓
Validated Analytical Layer
        ↓
Power BI / DAX
        ↓
Dashboard Storytelling
```

Python will serve two different purposes in the project:

**Data engineering / preparation:** reproducible CSV ingestion, schema inspection, data-quality checks, cleaning, and preparation before loading data into MySQL.

**Analytics:** exploratory analysis, distributions, feature engineering, and analyses that are more naturally handled with Pandas than SQL.

SQL will remain the primary tool for relational business analysis, while Power BI will be used for semantic modeling, KPI reporting, and final business storytelling.

Analytical views will be designed after the business-analysis stage clarifies which metrics, flags, and grains are actually required. Power BI will ultimately consume validated analytical views rather than unvalidated raw tables.

## Status

🚧 **Work in progress**

**Completed so far:**

- Relational MySQL schema setup for the core Olist datasets
- Data quality validation for customers, orders, order items, and payments
- Product and category table setup
- Order review table schema preparation
- Initial SQL business analysis of monthly delivered-order volume and product revenue
- Initial revenue-driver investigation covering order volume and Average Order Value

**Current transition:**

The next phase introduces Python/Pandas as a reproducible data-ingestion and quality layer. Remaining source datasets will be loaded and validated through Python before continuing deeper SQL business analysis.

The business-analysis workflow remains:

> **Business Question → Analysis → Insight → Recommendation**

The next major analytical goal is to continue revenue-driver analysis, including product/category mix, before moving into delivery performance and customer experience.

Recommendations are added only after the relevant drivers have been investigated and supported by the data.

After each major step, the workflow is also reviewed with one additional question:

> **Can this be done more simply, practically, or efficiently?**
