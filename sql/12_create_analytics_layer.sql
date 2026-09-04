-- =========================================================
-- Analytics Layer
-- =========================================================
-- Purpose:
-- Create analysis-ready views on top of the raw Olist tables.
-- Raw source tables remain unchanged.

USE olist_ecommerce;

-- =========================================================
-- Dimension: Customers
-- Grain: one row per customer_id
-- =========================================================
CREATE OR REPLACE VIEW dim_customers AS
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM customers;

-- =========================================================
-- Validation: dim_customers
-- =========================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS distinct_customer_ids
FROM dim_customers;

SELECT
    (SELECT COUNT(*) FROM customers) AS raw_customer_rows,
    (SELECT COUNT(*) FROM dim_customers) AS dimension_rows;

-- =========================================================
-- Dimension: Products
-- Grain: one row per product_id
-- =========================================================
CREATE OR REPLACE VIEW dim_products AS
SELECT
    p.product_id,
    p.product_category_name AS category_name_original,
    COALESCE(
        NULLIF(TRIM(pct.product_category_name_english), ''),
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown'
    ) AS product_category,
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM products p
LEFT JOIN product_category_name_translation pct
    ON p.product_category_name = pct.product_category_name;

-- =========================================================
-- Validation: dim_products
-- =========================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS distinct_product_ids
FROM dim_products;

SELECT
    (SELECT COUNT(*) FROM products) AS raw_product_rows,
    (SELECT COUNT(*) FROM dim_products) AS dimension_rows;

-- =========================================================
-- Dimension: Sellers
-- Grain: one row per seller_id
-- =========================================================
CREATE OR REPLACE VIEW dim_sellers AS
SELECT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM sellers;

-- =========================================================
-- Validation: dim_sellers
-- =========================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT seller_id) AS distinct_seller_ids
FROM dim_sellers;

SELECT
    (SELECT COUNT(*) FROM sellers) AS raw_seller_rows,
    (SELECT COUNT(*) FROM dim_sellers) AS dimension_rows;

-- =========================================================
-- Fact: Orders
-- Grain: one row per order_id
-- =========================================================
CREATE OR REPLACE VIEW fact_orders AS
SELECT
    o.order_id,
    o.customer_id,
    DATE(o.order_purchase_timestamp) AS purchase_date,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    ROUND(
        TIMESTAMPDIFF(
            HOUR,
            o.order_purchase_timestamp,
            o.order_delivered_customer_date
        ) / 24.0,
        2
    ) AS delivery_days,
    ROUND(
        TIMESTAMPDIFF(
            HOUR,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        ) / 24.0,
        2
    ) AS delay_days,
    CASE
        WHEN o.order_delivered_customer_date IS NULL
            OR o.order_estimated_delivery_date IS NULL
            THEN NULL
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 1
        ELSE 0
    END AS is_late,
    oi.item_count,
    oi.distinct_product_count,
    oi.seller_count,
    oi.product_revenue,
    oi.freight_value,
    op.payment_value,
    op.payment_record_count,
    op.payment_type_count,
    r.review_id,
    r.review_score,
    r.review_answer_timestamp
FROM orders o
LEFT JOIN (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        COUNT(DISTINCT product_id) AS distinct_product_count,
        COUNT(DISTINCT seller_id) AS seller_count,
        SUM(price) AS product_revenue,
        SUM(freight_value) AS freight_value
    FROM order_items
    GROUP BY order_id
) oi
    ON o.order_id = oi.order_id
LEFT JOIN (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value,
        COUNT(*) AS payment_record_count,
        COUNT(DISTINCT payment_type) AS payment_type_count
    FROM order_payments
    GROUP BY order_id
) op
    ON o.order_id = op.order_id
LEFT JOIN (
    SELECT
        order_id,
        review_id,
        review_score,
        review_answer_timestamp
    FROM (
        SELECT
            order_id,
            review_id,
            review_score,
            review_creation_date,
            review_answer_timestamp,
            ROW_NUMBER() OVER (
                PARTITION BY order_id
                ORDER BY review_answer_timestamp DESC,
                    review_creation_date DESC,
                    review_id DESC
            ) AS rn
        FROM order_reviews
    ) ranked_reviews
    WHERE rn = 1
) r
    ON o.order_id = r.order_id;

-- =========================================================
-- Validation: fact_orders
-- =========================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_order_ids
FROM fact_orders;

SELECT
    (SELECT COUNT(*) FROM orders) AS raw_order_rows,
    (SELECT COUNT(*) FROM fact_orders) AS fact_order_rows;


-- =========================================================
-- Fact: Order Items
-- Grain: one row per order_id + order_item_id
-- =========================================================
CREATE OR REPLACE VIEW fact_order_items AS
SELECT
    oi.order_id,
    oi.order_item_id,
    o.customer_id,
    oi.product_id,
    oi.seller_id,
    DATE(o.order_purchase_timestamp) AS purchase_date,
    o.order_status,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id;

-- =========================================================
-- Validation: fact_order_items
-- =========================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id, order_item_id) AS distinct_order_item_keys
FROM fact_order_items;

SELECT
    (SELECT COUNT(*) FROM order_items) AS raw_order_item_rows,
    (SELECT COUNT(*) FROM fact_order_items) AS fact_order_item_rows;

-- =========================================================
-- Date Range Check
-- =========================================================
SELECT
    MIN(DATE(order_purchase_timestamp)) AS min_purchase_date,
    MAX(DATE(order_estimated_delivery_date)) AS max_relevant_date
FROM orders;

-- =========================================================
-- Dimension: Date
-- Grain: one row per calendar date
-- =========================================================
CREATE OR REPLACE VIEW dim_date AS
WITH RECURSIVE date_series AS (
    SELECT MIN(DATE(order_purchase_timestamp)) AS date_value
    FROM orders
    UNION ALL
    SELECT DATE_ADD(date_value, INTERVAL 1 DAY)
    FROM date_series
    WHERE date_value < (
        SELECT MAX(DATE(order_estimated_delivery_date))
        FROM orders
    )
)
SELECT
    date_value AS calendar_date,
    YEAR(date_value) AS calendar_year,
    QUARTER(date_value) AS quarter_number,
    MONTH(date_value) AS month_number,
    MONTHNAME(date_value) AS month_name,
    DATE_FORMAT(date_value, '%Y-%m') AS year_month_label,
    DAY(date_value) AS day_of_month,
    DAYOFWEEK(date_value) AS day_of_week_number,
    DAYNAME(date_value) AS day_name
FROM date_series;

-- =========================================================
-- Validation: dim_date
-- =========================================================
SELECT
    COUNT(*) AS total_dates,
    COUNT(DISTINCT calendar_date) AS distinct_dates,
    MIN(calendar_date) AS min_date,
    MAX(calendar_date) AS max_date
FROM dim_date;

SELECT
    DATEDIFF(MAX(calendar_date), MIN(calendar_date)) + 1 AS expected_date_count,
    COUNT(*) AS actual_date_count
FROM dim_date;

-- =========================================================
-- Referential Integrity Validation
-- =========================================================
-- Source-level checks are used here to avoid unnecessary
-- nested view expansion during validation.

-- orders -> customers
SELECT
    COUNT(*) AS unmatched_customers
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- order_items -> products
SELECT
    COUNT(*) AS unmatched_products
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- order_items -> sellers
SELECT
    COUNT(*) AS unmatched_sellers
FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- =========================================================
-- Referential Integrity Findings
-- =========================================================
-- Unmatched customers: 0
-- Unmatched products: 0
-- Unmatched sellers: 0
--
-- All key relationships required by the analytics layer
-- have valid matching records in their source dimension tables.
--
-- Note:
-- Referential integrity is validated at the source-table level
-- rather than by joining analytics views to each other.
-- This provides the same key-integrity check with lower query cost.


