-- =========================================================
-- Delivery & Customer Experience Analysis
-- =========================================================
-- Business Question 1:
-- How reliable is overall delivery performance?

USE olist_ecommerce;

-- =========================================================
-- 1. Overall Delivery Performance
-- =========================================================
SELECT
    COUNT(*) AS delivered_orders,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(100.0 * AVG(is_late), 2) AS late_delivery_rate_pct,
    ROUND(AVG(CASE
        WHEN is_late = 1 THEN delay_days
    END), 2) AS avg_delay_days_for_late_orders
FROM fact_orders
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL;