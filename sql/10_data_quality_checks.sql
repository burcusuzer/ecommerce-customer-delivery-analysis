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


-- =========================================================
-- Products Table - Data Quality and Initial Validation
-- =========================================================


-- 1. Row count and product ID uniqueness
-- Grain: one row represents one product
SELECT
    COUNT(*) AS total_products,
    COUNT(DISTINCT product_id) AS distinct_product_ids
FROM products;


-- 2. Null value checks
SELECT
    SUM(product_id IS NULL) AS null_product_id,
    SUM(product_category_name IS NULL) AS null_category,
    SUM(product_name_length IS NULL) AS null_name_length,
    SUM(product_description_length IS NULL) AS null_description_length,
    SUM(product_photos_qty IS NULL) AS null_photos_qty,
    SUM(product_weight_g IS NULL) AS null_weight,
    SUM(product_length_cm IS NULL) AS null_length,
    SUM(product_height_cm IS NULL) AS null_height,
    SUM(product_width_cm IS NULL) AS null_width
FROM products;


-- 3. Duplicate product ID check
-- product_id should uniquely identify a product
SELECT
    product_id,
    COUNT(*) AS row_count
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;


-- 4. Blank product category check
-- Blank strings are checked separately because they are not counted as NULL
SELECT
    COUNT(*) AS blank_category_count
FROM products
WHERE TRIM(product_category_name) = '';


-- 5. Products with missing category and descriptive metadata
-- Checks whether blank category values belong to the same products
-- that also have missing descriptive fields
SELECT
    COUNT(*) AS products_with_missing_category_and_description
FROM products
WHERE TRIM(product_category_name) = ''
  AND product_name_length IS NULL
  AND product_description_length IS NULL
  AND product_photos_qty IS NULL;


-- 6. Products with missing physical dimensions
SELECT
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM products
WHERE product_weight_g IS NULL
   OR product_length_cm IS NULL
   OR product_height_cm IS NULL
   OR product_width_cm IS NULL;



-- =========================================================
-- Products - Findings
-- =========================================================

-- Grain:
-- One row represents one product.
-- product_id uniquely identifies each product.
--
-- 32,951 product records were found.
-- All 32,951 product_id values are distinct.
--
-- No NULL product_id values were found.
-- No NULL product_category_name values were found.
--
-- 610 products have blank product_category_name values.
--
-- The same 610 products also have missing:
--   - product_name_length
--   - product_description_length
--   - product_photos_qty
--
-- This indicates that the missing category and descriptive metadata
-- are concentrated in the same group of products rather than being
-- separate missing-data issues.
--
-- 2 products have missing physical dimension data:
--   - product_weight_g
--   - product_length_cm
--   - product_height_cm
--   - product_width_cm
--
-- Analyst note:
-- Products with missing descriptive or physical metadata should not
-- automatically be removed from the dataset.
--
-- They can still be used in analyses that depend on product_id and
-- order-item price, such as overall revenue analysis.
--
-- However, the 610 products with blank category values cannot be
-- assigned to a known category and should therefore be handled as
-- uncategorized in category-level analysis.


-- =========================================================
-- Product Category Translation Table - Data Quality and Initial Validation
-- =========================================================


-- 1. Row count and category uniqueness
-- Grain: one row represents one Portuguese-to-English category mapping
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_category_name) AS distinct_categories
FROM product_category_name_translation;


-- 2. Null and blank value checks
SELECT
    SUM(product_category_name IS NULL) AS null_category_name,
    SUM(product_category_name_english IS NULL) AS null_english_name,
    SUM(TRIM(product_category_name) = '') AS blank_category_name,
    SUM(TRIM(product_category_name_english) = '') AS blank_english_name
FROM product_category_name_translation;


-- 3. Duplicate category check
-- Each Portuguese category should map to only one English category name
SELECT
    product_category_name,
    COUNT(*) AS row_count
FROM product_category_name_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;


-- 4. Check translation coverage against the products table
-- Blank product categories are excluded because they cannot be translated
SELECT
    COUNT(DISTINCT p.product_category_name) AS unmatched_categories
FROM products p
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE TRIM(p.product_category_name) <> ''
  AND t.product_category_name IS NULL;


-- 5. List unmatched product categories
-- Used to investigate missing mappings in the source translation dataset
SELECT DISTINCT
    p.product_category_name
FROM products p
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE TRIM(p.product_category_name) <> ''
  AND t.product_category_name IS NULL
ORDER BY p.product_category_name;


-- 6. Check product-level impact of missing category translations
SELECT
    product_category_name,
    COUNT(*) AS product_count
FROM products
WHERE product_category_name IN (
    'pc_gamer',
    'portateis_cozinha_e_preparadores_de_alimentos'
)
GROUP BY product_category_name
ORDER BY product_count DESC;


-- 7. Check sales impact of missing category translations
SELECT
    p.product_category_name,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT oi.order_id) AS orders,
    ROUND(SUM(oi.price), 2) AS product_revenue
FROM products p
JOIN order_items oi
    ON p.product_id = oi.product_id
WHERE p.product_category_name IN (
    'pc_gamer',
    'portateis_cozinha_e_preparadores_de_alimentos'
)
GROUP BY p.product_category_name
ORDER BY product_revenue DESC;


-- 8. Final translation coverage check after adding missing mappings
SELECT
    COUNT(DISTINCT p.product_category_name) AS unmatched_categories
FROM products p
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE TRIM(p.product_category_name) <> ''
  AND t.product_category_name IS NULL;



-- =========================================================
-- Product Category Translation - Findings
-- =========================================================

-- Grain:
-- One row represents one Portuguese-to-English product category mapping.
--
-- The original translation dataset contained:
--   - 71 rows
--   - 71 distinct Portuguese category names
--
-- No NULL or blank values were found in either:
--   - product_category_name
--   - product_category_name_english
--
-- No duplicate Portuguese category names were found in the original
-- translation dataset.
--
-- Coverage validation against the products table identified 2 product
-- categories without an English translation:
--   - pc_gamer
--   - portateis_cozinha_e_preparadores_de_alimentos
--
-- Product-level impact:
--   - portateis_cozinha_e_preparadores_de_alimentos: 10 products
--   - pc_gamer: 3 products
--
-- Sales impact:
--   - portateis_cozinha_e_preparadores_de_alimentos:
--       15 items sold
--       14 orders
--       product revenue = 3,968.53
--
--   - pc_gamer:
--       9 items sold
--       8 orders
--       product revenue = 1,545.95
--
-- Because both categories contain valid products and generated sales,
-- leaving them untranslated would create incomplete category-level
-- reporting.
--
-- Two missing mappings were therefore added through a documented SQL
-- script rather than manually editing the table:
--   - pc_gamer -> pc_gamer
--   - portateis_cozinha_e_preparadores_de_alimentos
--     -> portable_kitchen_food_preparation_appliances
--
-- After the missing mappings were added:
--   - 73 translation rows exist
--   - 73 distinct Portuguese categories exist
--   - 0 unmatched non-blank product categories remain
--   - no duplicate category mappings remain
--
-- Analyst note:
-- Reference and lookup tables should be validated against the business
-- tables that use them. A lookup table can be internally clean while
-- still having incomplete coverage of valid business values.


-- =========================================================
-- Order Reviews Table - Data Quality and Initial Validation
-- =========================================================

-- 1. Row count and identifier coverage
SELECT
    COUNT(*) AS total_review_rows,
    COUNT(DISTINCT review_id) AS unique_review_ids,
    COUNT(DISTINCT order_id) AS unique_order_ids
FROM order_reviews;

-- 2. Null value checks
SELECT
    SUM(review_id IS NULL) AS null_review_id,
    SUM(order_id IS NULL) AS null_order_id,
    SUM(review_score IS NULL) AS null_review_score,
    SUM(review_comment_title IS NULL) AS null_review_comment_title,
    SUM(review_comment_message IS NULL) AS null_review_comment_message,
    SUM(review_creation_date IS NULL) AS null_review_creation_date,
    SUM(review_answer_timestamp IS NULL) AS null_review_answer_timestamp
FROM order_reviews;

-- 3. Review score sanity check
SELECT
    review_score,
    COUNT(*) AS review_count
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;

-- 4. Review score values outside the expected 1-5 range
SELECT
    COUNT(*) AS invalid_review_scores
FROM order_reviews
WHERE review_score NOT BETWEEN 1 AND 5;

-- 5. Repeated review_id values
SELECT
    COUNT(*) AS repeated_review_ids
FROM (
    SELECT review_id
    FROM order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
) r;

-- 6. Maximum number of rows sharing one review_id
SELECT
    MAX(review_count) AS max_rows_per_review_id
FROM (
    SELECT
        review_id,
        COUNT(*) AS review_count
    FROM order_reviews
    GROUP BY review_id
) r;

-- 7. Orders with more than one review record
SELECT
    COUNT(*) AS orders_with_multiple_reviews
FROM (
    SELECT order_id
    FROM order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) r;

-- 8. Maximum number of review records for one order
SELECT
    MAX(review_count) AS max_reviews_per_order
FROM (
    SELECT
        order_id,
        COUNT(*) AS review_count
    FROM order_reviews
    GROUP BY order_id
) r;

-- 9. Duplicate review_id + order_id combinations
SELECT
    review_id,
    order_id,
    COUNT(*) AS row_count
FROM order_reviews
GROUP BY review_id, order_id
HAVING COUNT(*) > 1;

-- 10. Review text length checks
SELECT
    MAX(CHAR_LENGTH(review_comment_title)) AS max_review_title_length,
    MAX(CHAR_LENGTH(review_comment_message)) AS max_review_message_length
FROM order_reviews;

-- 11. Orders without a matching order record
SELECT
    COUNT(*) AS unmatched_review_orders
FROM order_reviews r
LEFT JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Findings:
-- 99,224 review records.
-- 98,410 unique review_id values.
-- 98,673 unique order_id values.
-- No full duplicate rows were found during the Pandas validation workflow.
-- 789 distinct review_id values appear more than once.
-- Maximum occurrences of one review_id: 3.
-- 547 orders have more than one review record.
-- Maximum review records observed for a single order: 3.
-- No duplicate (review_id, order_id) combinations were found.
-- review_score values are limited to the expected 1-5 range.
-- Maximum review title length: 26 characters.
-- Maximum review message length: 208 characters.
-- 87,656 review_comment_title values are NULL.
-- 58,247 review_comment_message values are NULL.
--
-- Grain:
-- One row represents one review-order record.
-- Neither review_id nor order_id is individually unique.
-- The checked (review_id, order_id) combination is unique.
--
-- Analytical decision:
-- Raw review records are preserved.
-- When an order-level analysis requires one review score per order,
-- the latest review will be selected using review_answer_timestamp
-- to avoid giving multi-review orders additional weight.


-- =========================================================
-- Sellers Table - Data Quality and Initial Validation
-- =========================================================

-- 1. Row count and seller ID uniqueness
-- Grain: one row represents one seller
SELECT
    COUNT(*) AS total_sellers,
    COUNT(DISTINCT seller_id) AS distinct_seller_ids,
    COUNT(DISTINCT seller_zip_code_prefix) AS distinct_zip_prefixes
FROM sellers;

-- 2. Null value checks
SELECT
    SUM(seller_id IS NULL) AS null_seller_id,
    SUM(seller_zip_code_prefix IS NULL) AS null_zip_prefix,
    SUM(seller_city IS NULL) AS null_city,
    SUM(seller_state IS NULL) AS null_state
FROM sellers;

-- 3. Duplicate seller ID check
SELECT
    seller_id,
    COUNT(*) AS row_count
FROM sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- 4. Blank city and state checks
SELECT
    SUM(TRIM(seller_city) = '') AS blank_city,
    SUM(TRIM(seller_state) = '') AS blank_state
FROM sellers;

-- 5. State code format check
SELECT
    seller_state,
    COUNT(*) AS seller_count
FROM sellers
WHERE CHAR_LENGTH(TRIM(seller_state)) <> 2
GROUP BY seller_state;

-- =========================================================
-- Sellers - Findings
-- =========================================================

-- Grain:
-- One row represents one seller.
-- seller_id uniquely identifies each seller.
--
-- 3,095 seller records were found.
-- All 3,095 seller_id values are distinct.
--
-- 2,246 distinct seller ZIP-code prefixes were found.
-- ZIP-code prefix is not unique, which is expected because
-- multiple sellers can operate within the same geographic area.
--
-- No NULL values were found in the checked seller fields.
-- No full duplicate rows were found during the Pandas validation workflow.
-- No blank seller_city or seller_state values were found.
-- All seller_state values have the expected 2-character format.
--
-- Python-to-MySQL validation:
-- Pandas and MySQL results matched exactly:
--   - Total rows: 3,095
--   - Unique seller_id values: 3,095
--   - Unique ZIP-code prefixes: 2,246
--
-- This confirms that the sellers dataset was loaded into MySQL
-- without row loss or row multiplication.
--
-- Analyst note:
-- The sellers table appears structurally clean and suitable for
-- seller-level and geographic analysis.