# E-Commerce Customer & Delivery Analysis

An end-to-end data analytics portfolio project analyzing customer behavior, order performance, payments, and delivery operations using the Brazilian E-Commerce Public Dataset by Olist.

The project combines **SQL, MySQL, Python, and Power BI** to demonstrate a complete analytics workflow from data validation and modeling to business analysis and dashboard reporting.

## Project Objectives

The main goal of this project is to understand how an e-commerce business can improve customer experience and operational performance through data.

The analysis will focus on questions such as:

* How does order and revenue performance change over time?
* Which customer and product segments generate the most value?
* How effectively are orders delivered?
* How common are late deliveries?
* How does delivery performance affect customer reviews?
* Which payment methods are most commonly used?
* How frequently do customers make repeat purchases?

## Dataset

This project uses the **Brazilian E-Commerce Public Dataset by Olist**, containing approximately 100,000 orders and multiple relational datasets covering:

* Customers
* Orders
* Order items
* Payments
* Reviews
* Products
* Sellers
* Geolocation

Raw CSV files are stored locally and excluded from GitHub using `.gitignore`.

## Tools & Technologies

* SQL
* MySQL
* DBeaver
* Python / Pandas
* Power BI
* Visual Studio Code
* Git
* GitHub

## Current Data Model

```text
customers
    ↓
orders
    ├── order_items
    ├── order_payments
    └── order_reviews
```

Additional product and seller relationships will be added as the project develops.

## Data Quality & Validation

Initial SQL validation has been performed before starting business analysis.

### Customers

* 99,441 customer records
* 96,096 unique customers based on `customer_unique_id`
* 2,997 repeat customers identified
* Maximum observed purchase frequency: 17

The dataset uses two customer identifiers:

* `customer_id` connects customer records to individual orders.
* `customer_unique_id` identifies the same customer across multiple purchases.

### Orders

* 99,441 orders
* 97.02% of orders have `delivered` status
* Lifecycle timestamp inconsistencies were identified and investigated
* Invalid timestamps will be flagged rather than removed from the raw dataset
* Affected records will only be excluded from metrics that depend on those timestamps

### Order Items

* 112,650 order-item records
* 98,666 orders contain at least one item
* Maximum observed item sequence within a single order: 21
* No duplicate `(order_id, order_item_id)` keys identified
* No non-positive product prices or negative freight values identified

Orders without item records were primarily associated with unavailable and canceled orders.

### Payments

* 103,886 payment records
* 99,440 orders have a payment record
* Some orders contain multiple payment records
* 2,246 orders use more than one payment method
* Credit cards account for approximately 74% of payment records

Payment data has a different grain from order-item data. Payments will therefore be aggregated to **order level before joining with item-level datasets** to prevent duplicated revenue or payment values.

A small number of unusual payment records were identified and investigated, including:

* Zero-value payment records
* Credit-card records with zero installments
* One delivered order without a matching payment record

Raw records are preserved and potential anomalies will be flagged where necessary.

## Data Quality Strategy

The project follows a non-destructive validation approach:

1. Preserve raw data.
2. Identify and investigate potential anomalies.
3. Create quality flags where necessary.
4. Exclude unreliable records only from affected metrics.
5. Build clean analytical views for reporting.

Power BI will ultimately use analytical views rather than directly consuming unvalidated raw tables.

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

## Planned Analysis

The next stages will include:

* Revenue and order trends
* Average Order Value (AOV)
* Customer geographic analysis
* Repeat customer behavior
* Payment method analysis
* Product category performance
* Delivery time analysis
* Late delivery rate
* Delivery performance vs. review score
* Customer segmentation

## Planned Workflow

```text
Raw CSV Data
      ↓
MySQL
      ↓
SQL Data Quality & Validation
      ↓
Business Analysis
      ↓
Python EDA & Feature Engineering
      ↓
Clean Analytical Views
      ↓
Power BI Dashboard
      ↓
Business Insights & Recommendations
```

## Status

🚧 **Work in progress**

Current phase: **Data ingestion, relational modeling, and data quality validation.**
