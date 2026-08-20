# E-Commerce Customer & Delivery Analysis

An end-to-end data analytics portfolio project exploring customer behavior, order performance, payments, and delivery operations using the Brazilian E-Commerce Public Dataset by Olist.

The project is being developed as a practical **Data Analyst / Business Intelligence** case study. The current phase focuses on **SQL, MySQL, relational modeling, and data quality validation**. Python/Pandas and Power BI will be added in later stages for exploratory analysis, feature engineering, dashboarding, and business storytelling.

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

### Planned
- Python / Pandas
- Power BI
- DAX
- Visual Studio Code

## Current Data Model

The core tables currently loaded and validated are:

```text
customers
    ↓
orders
    ├── order_items
    └── order_payments
```

Additional Olist datasets such as reviews, products, sellers, and geolocation will be incorporated as the project develops.

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
│   ├── 02_data_quality_checks.sql
│   ├── 03_create_orders_table.sql
│   ├── 04_create_order_items_table.sql
│   └── 05_create_order_payments_table.sql
│
├── python/
├── images/
├── README.md
└── .gitignore
```

## Planned Business Analysis

The next SQL stage will focus on:

- Order and revenue trends
- Average Order Value (AOV)
- Revenue driver analysis
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
Raw CSV Data
      ↓
MySQL
      ↓
SQL Data Quality & Validation
      ↓
Business Questions
      ↓
SQL Analysis
      ↓
Insights & Recommendations
      ↓
Python EDA & Feature Engineering
      ↓
Clean Analytical Views
      ↓
Power BI / DAX
      ↓
Dashboard Storytelling
```

Analytical views will be designed after the business-analysis stage clarifies which metrics, flags, and grains are actually required. Power BI will ultimately consume validated analytical views rather than unvalidated raw tables.

## Status

🚧 **Work in progress**

**Current phase:** Core-table data quality validation is complete for `customers`, `orders`, `order_items`, and `order_payments`.

**Next phase:** SQL business analysis using the framework:

> **Business Question → Analysis → Insight → Recommendation**

After each major step, the workflow will also be reviewed with one additional question:

> **Can this be done more simply, practically, or efficiently?**
