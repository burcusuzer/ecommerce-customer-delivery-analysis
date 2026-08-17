USE olist_ecommerce;

-- =========================================================
-- Customers Table - Data Quality and Initial Validation
-- =========================================================


-- 1. Row count and unique customer identifiers
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;


-- 2. Null value checks
SELECT
    SUM(customer_id IS NULL) AS null_customer_id,
    SUM(customer_unique_id IS NULL) AS null_customer_unique_id,
    SUM(customer_zip_code_prefix IS NULL) AS null_zip_code,
    SUM(customer_city IS NULL) AS null_customer_city,
    SUM(customer_state IS NULL) AS null_customer_state
FROM customers;


-- 3. Duplicate customer_id check
-- customer_id is expected to be unique
SELECT
    customer_id,
    COUNT(*) AS row_count
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- 4. Identify customers with multiple customer records
-- customer_unique_id represents the same customer across purchases
SELECT
    customer_unique_id,
    COUNT(*) AS purchase_count
FROM customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
ORDER BY purchase_count DESC;


-- 5. Repeat customer summary
WITH customer_frequency AS (
    SELECT
        customer_unique_id,
        COUNT(*) AS purchase_count
    FROM customers
    GROUP BY customer_unique_id
)
SELECT
    COUNT(*) AS unique_customers,
    SUM(purchase_count > 1) AS repeat_customers,
    ROUND(
        100.0 * SUM(purchase_count > 1) / COUNT(*),
        2
    ) AS repeat_customer_rate_pct,
    MAX(purchase_count) AS max_purchase_count
FROM customer_frequency;

-- =========================================================
-- Orders Table - Data Quality Checks
-- =========================================================


-- 1. Row count and unique identifiers
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_order_ids,
    COUNT(DISTINCT customer_id) AS unique_customer_ids
FROM orders;


-- 2. General null profile
SELECT
    SUM(order_status IS NULL) AS null_order_status,
    SUM(order_purchase_timestamp IS NULL) AS null_purchase_timestamp,
    SUM(order_approved_at IS NULL) AS null_approved_at,
    SUM(order_delivered_carrier_date IS NULL) AS null_carrier_date,
    SUM(order_delivered_customer_date IS NULL) AS null_customer_delivery_date,
    SUM(order_estimated_delivery_date IS NULL) AS null_estimated_delivery_date
FROM orders;


-- 3. Order status distribution
SELECT
    order_status,
    COUNT(*) AS order_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS order_share_pct
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- 4. Business-rule validation for delivered orders
SELECT
    SUM(
        order_approved_at IS NULL
        AND order_status = 'delivered'
    ) AS delivered_orders_missing_approval,

    SUM(
        order_delivered_carrier_date IS NULL
        AND order_status = 'delivered'
    ) AS delivered_orders_missing_carrier_date,

    SUM(
        order_delivered_customer_date IS NULL
        AND order_status = 'delivered'
    ) AS delivered_orders_missing_delivery_date
FROM orders;


-- 5. Timestamp sequence validation
SELECT
    SUM(order_approved_at < order_purchase_timestamp)
        AS approval_before_purchase,
    SUM(order_delivered_carrier_date < order_approved_at)
        AS carrier_before_approval,
    SUM(order_delivered_customer_date < order_delivered_carrier_date)
        AS delivery_before_carrier
FROM orders;


-- 6. Orders with at least one timestamp sequence inconsistency
SELECT
    COUNT(*) AS orders_with_timestamp_inconsistency
FROM orders
WHERE
    order_approved_at < order_purchase_timestamp
    OR order_delivered_carrier_date < order_approved_at
    OR order_delivered_customer_date < order_delivered_carrier_date;


-- 7. Check for orders without a matching customer
SELECT COUNT(*) AS unmatched_customer_records
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 8. Purchase date range
SELECT
    MIN(order_purchase_timestamp) AS first_order_date,
    MAX(order_purchase_timestamp) AS last_order_date
FROM orders;