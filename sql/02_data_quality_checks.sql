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
SELECT
    COUNT(*) AS unmatched_customer_records
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 8. Purchase date range
SELECT
    MIN(order_purchase_timestamp) AS first_order_date,
    MAX(order_purchase_timestamp) AS last_order_date
FROM orders;


-- 9. Missing lifecycle timestamps by order status
-- Helps distinguish expected nulls from potential data quality issues
SELECT
    order_status,
    COUNT(*) AS order_count,
    SUM(order_approved_at IS NULL) AS missing_approval,
    SUM(order_delivered_carrier_date IS NULL) AS missing_carrier_date,
    SUM(order_delivered_customer_date IS NULL) AS missing_delivery_date
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- 10. Severity of carrier-before-approval inconsistencies
SELECT
    CASE
        WHEN TIMESTAMPDIFF(
            MINUTE,
            order_delivered_carrier_date,
            order_approved_at
        ) < 60
            THEN 'Under 1 hour'

        WHEN TIMESTAMPDIFF(
            HOUR,
            order_delivered_carrier_date,
            order_approved_at
        ) <= 24
            THEN '1-24 hours'

        WHEN TIMESTAMPDIFF(
            HOUR,
            order_delivered_carrier_date,
            order_approved_at
        ) <= 168
            THEN '1-7 days'

        ELSE 'Over 7 days'
    END AS difference_bucket,
    COUNT(*) AS order_count
FROM orders
WHERE order_delivered_carrier_date < order_approved_at
GROUP BY difference_bucket
ORDER BY order_count DESC;


-- 11. Summary of carrier-before-approval time differences
SELECT
    COUNT(*) AS affected_orders,

    MIN(
        TIMESTAMPDIFF(
            HOUR,
            order_delivered_carrier_date,
            order_approved_at
        )
    ) AS min_hours_difference,

    ROUND(
        AVG(
            TIMESTAMPDIFF(
                HOUR,
                order_delivered_carrier_date,
                order_approved_at
            )
        ),
        2
    ) AS avg_hours_difference,

    MAX(
        TIMESTAMPDIFF(
            HOUR,
            order_delivered_carrier_date,
            order_approved_at
        )
    ) AS max_hours_difference

FROM orders
WHERE order_delivered_carrier_date < order_approved_at;



-- =========================================================
-- Order Items Table - Data Quality Checks
-- =========================================================


-- 1. Row count and order coverage
-- Grain: one row represents one item within an order
SELECT
    COUNT(*) AS total_order_items,
    COUNT(DISTINCT order_id) AS orders_with_items
FROM order_items;


-- 2. Maximum number of item records in a single order
-- COUNT(*) is used instead of MAX(order_item_id) because a sequence
-- number should not be assumed to equal the actual number of records
SELECT
    MAX(item_count) AS max_items_in_single_order
FROM (
    SELECT
        order_id,
        COUNT(*) AS item_count
    FROM order_items
    GROUP BY order_id
) t;


-- 3. Null value checks
SELECT
    SUM(order_id IS NULL) AS null_order_id,
    SUM(order_item_id IS NULL) AS null_order_item_id,
    SUM(product_id IS NULL) AS null_product_id,
    SUM(seller_id IS NULL) AS null_seller_id,
    SUM(shipping_limit_date IS NULL) AS null_shipping_limit_date,
    SUM(price IS NULL) AS null_price,
    SUM(freight_value IS NULL) AS null_freight_value
FROM order_items;


-- 4. Duplicate composite key check
-- order_id + order_item_id should uniquely identify an order item
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS row_count
FROM order_items
GROUP BY
    order_id,
    order_item_id
HAVING COUNT(*) > 1;


-- 5. Price and freight sanity checks
SELECT
    SUM(price <= 0) AS non_positive_price,
    SUM(freight_value < 0) AS negative_freight_value,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    MIN(freight_value) AS min_freight_value,
    MAX(freight_value) AS max_freight_value
FROM order_items;


-- 6. Order items without a matching order
SELECT
    COUNT(*) AS unmatched_order_items
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;


-- 7. Orders without matching order items by status
SELECT
    o.order_status,
    COUNT(*) AS order_count
FROM orders o
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY order_count DESC;



-- =========================================================
-- Order Payments Table - Data Quality and Initial Validation
-- =========================================================


-- 1. Row count and order coverage
-- Grain: one row represents one payment record for an order
SELECT
    COUNT(*) AS total_payment_records,
    COUNT(DISTINCT order_id) AS orders_with_payments
FROM order_payments;


-- 2. Null value checks
SELECT
    SUM(order_id IS NULL) AS null_order_id,
    SUM(payment_sequential IS NULL) AS null_payment_sequential,
    SUM(payment_type IS NULL) AS null_payment_type,
    SUM(payment_installments IS NULL) AS null_payment_installments,
    SUM(payment_value IS NULL) AS null_payment_value
FROM order_payments;


-- 3. Duplicate composite key check
-- order_id + payment_sequential should uniquely identify a payment record
SELECT
    order_id,
    payment_sequential,
    COUNT(*) AS row_count
FROM order_payments
GROUP BY
    order_id,
    payment_sequential
HAVING COUNT(*) > 1;


-- 4. Payment value and installment sanity checks
SELECT
    SUM(payment_value < 0) AS negative_payment_values,
    SUM(payment_value = 0) AS zero_payment_values,
    SUM(payment_installments < 0) AS negative_installments,
    SUM(payment_installments = 0) AS zero_installments,
    MIN(payment_value) AS min_payment_value,
    MAX(payment_value) AS max_payment_value,
    MIN(payment_installments) AS min_installments,
    MAX(payment_installments) AS max_installments
FROM order_payments;


-- 5. Payment type distribution
-- Percentages below represent payment records, not unique orders
SELECT
    payment_type,
    COUNT(*) AS payment_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS payment_share_pct
FROM order_payments
GROUP BY payment_type
ORDER BY payment_count DESC;


-- 6. Investigate zero-value payment records by payment type
SELECT
    payment_type,
    COUNT(*) AS zero_payment_count
FROM order_payments
WHERE payment_value = 0
GROUP BY payment_type
ORDER BY zero_payment_count DESC;


-- 7. Zero-total-payment orders by status
-- Aggregating first prevents multiple payment rows from being interpreted
-- as multiple orders
WITH payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment_value
    FROM order_payments
    GROUP BY order_id
)
SELECT
    o.order_status,
    COUNT(*) AS order_count
FROM payment_totals pt
JOIN orders o
    ON pt.order_id = o.order_id
WHERE pt.total_payment_value = 0
GROUP BY o.order_status
ORDER BY order_count DESC;


-- 8. Orders without a matching payment record
SELECT
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_customer_date
FROM orders o
LEFT JOIN order_payments op
    ON o.order_id = op.order_id
WHERE op.order_id IS NULL;


-- 9. Orders with multiple payment records
SELECT
    COUNT(*) AS multi_payment_orders
FROM (
    SELECT
        order_id
    FROM order_payments
    GROUP BY order_id
    HAVING COUNT(*) > 1
) t;


-- 10. Orders using multiple payment methods
SELECT
    COUNT(*) AS multi_method_orders
FROM (
    SELECT
        order_id
    FROM order_payments
    GROUP BY order_id
    HAVING COUNT(DISTINCT payment_type) > 1
) t;


-- 11. Credit card payment records with zero installments
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM order_payments
WHERE payment_type = 'credit_card'
  AND payment_installments = 0;


-- 12. Orders whose available payment sequence does not start at 1
SELECT
    COUNT(*) AS orders_not_starting_at_1
FROM (
    SELECT
        order_id
    FROM order_payments
    GROUP BY order_id
    HAVING MIN(payment_sequential) <> 1
) t;


-- 13. Check for internal gaps in payment sequences
-- Example of an internal gap: 1, 2, 4
SELECT
    order_id,
    COUNT(*) AS payment_records,
    MIN(payment_sequential) AS min_sequence,
    MAX(payment_sequential) AS max_sequence
FROM order_payments
GROUP BY order_id
HAVING COUNT(*) <> MAX(payment_sequential) - MIN(payment_sequential) + 1;


-- 14. Orders with the highest number of payment records
-- COUNT(*) is used rather than MAX(payment_sequential)
SELECT
    order_id,
    COUNT(*) AS payment_count
FROM order_payments
GROUP BY order_id
ORDER BY payment_count DESC
LIMIT 10;



-- =========================================================
-- Order Payments - Findings
-- =========================================================

-- Grain:
-- One row represents one payment record for an order.
-- The combination of order_id + payment_sequential is unique.
--
-- 103,886 payment records exist across 99,440 orders.
--
-- No null values were found in the checked payment fields.
-- No duplicate (order_id, payment_sequential) combinations were found.
-- No negative payment values were found.
--
-- 9 zero-value payment records were found:
--   - 6 voucher records
--   - 3 not_defined records
--
-- The zero-value voucher records belong to orders that also contain
-- other positive payment records, so the orders themselves do not
-- have zero total payment.
--
-- The 3 not_defined zero-value payment records belong to cancelled
-- orders that were never approved.
--
-- One delivered order has no corresponding payment record:
-- order_id = bfbd0f9bdef84302105ad712db648a6c
--
-- This order contains:
--   - 3 items
--   - product value = 134.97
--   - freight value = 8.49
--
-- The order remains usable for analyses that do not depend on
-- payment data, but should be handled carefully in payment-based metrics.
--
-- Two credit-card payment records have payment_installments = 0.
-- Both orders were delivered normally.
-- In both cases, payment_value exactly matches product value + freight,
-- suggesting that the payment amount is usable even though the
-- installment metadata is unusual.
--
-- 80 orders have available payment sequences that do not start at 1.
-- No internal sequence gaps were found.
-- This is treated as a minor data quirk rather than a critical error.
--
-- Maximum payment records observed for a single order: 29.
--
-- Analyst note:
-- An anomaly in one field does not necessarily invalidate the entire row.
-- Records should be excluded only from metrics affected by the anomalous field.