USE olist_ecommerce;


-- =========================================================
-- BUSINESS ANALYSIS
-- =========================================================
-- Analysis framework:
-- Business Question → Analysis → Insight → Recommendation
--
-- Important:
-- Recommendations are added only after the relevant drivers
-- have been investigated and supported by the data.



-- =========================================================
-- 1. Monthly Order Volume and Product Revenue
-- =========================================================

-- Business Question:
-- How have completed order volume and product revenue changed over time?


-- Metric Definitions:
-- Completed order:
--     An order with order_status = 'delivered'.
--
-- Completed orders:
--     Number of distinct delivered order_id values.
--
-- Product revenue:
--     Sum of order_items.price for delivered orders.
--     Freight is excluded from this metric.
--
-- Time dimension:
--     Orders are grouped by order_purchase_timestamp,
--     therefore the analysis represents purchase month,
--     not delivery month.


-- Grain:
-- orders      → one row per order
-- order_items → one row per item within an order
--
-- After joining orders to order_items, the resulting grain
-- becomes order-item level.
--
-- COUNT(DISTINCT order_id) is therefore required to avoid
-- counting multi-item orders more than once.
--
-- SUM(price) remains valid because product revenue originates
-- at the item level.


SELECT
    DATE_FORMAT(
        o.order_purchase_timestamp,
        '%Y-%m'
    ) AS order_month,
    COUNT(DISTINCT o.order_id) AS completed_orders,
    ROUND(
        SUM(oi.price),
        2
    ) AS product_revenue
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY order_month
ORDER BY order_month;


-- =========================================================
-- Results
-- =========================================================

-- order_month | completed_orders | product_revenue
-- -------------------------------------------------
-- 2016-09     | 1                | 134.97
-- 2016-10     | 265              | 40,325.11
-- 2016-12     | 1                | 10.90
-- 2017-01     | 750              | 111,798.36
-- 2017-02     | 1,653            | 234,223.40
-- 2017-03     | 2,546            | 359,198.85
-- 2017-04     | 2,303            | 340,669.68
-- 2017-05     | 3,546            | 489,338.25
-- 2017-06     | 3,135            | 421,923.37
-- 2017-07     | 3,872            | 481,604.52
-- 2017-08     | 4,193            | 554,699.70
-- 2017-09     | 4,150            | 607,399.67
-- 2017-10     | 4,478            | 648,247.65
-- 2017-11     | 7,289            | 987,765.37
-- 2017-12     | 5,513            | 726,033.19
-- 2018-01     | 7,069            | 924,645.00
-- 2018-02     | 6,555            | 826,437.13
-- 2018-03     | 7,003            | 953,356.25
-- 2018-04     | 6,798            | 973,534.09
-- 2018-05     | 6,749            | 977,544.69
-- 2018-06     | 6,099            | 856,077.86
-- 2018-07     | 6,159            | 867,953.46
-- 2018-08     | 6,351            | 838,576.64

-- =========================================================
-- Findings
-- =========================================================

-- The earliest period of the dataset is irregular:
--
-- 2016-09 → 1 delivered order
-- 2016-10 → 265 delivered orders
-- 2016-12 → 1 delivered order
--
-- Because this early period appears to have limited coverage,
-- strong growth conclusions should not be drawn by comparing
-- these months directly with later periods.


-- Delivered-order volume and product revenue grew substantially
-- throughout 2017.
--
-- November 2017 shows a particularly strong spike:
--
-- Completed orders: 7,289
-- Product revenue: 987,765.37
--
-- Compared with October 2017, both order volume and revenue
-- increased sharply.


-- Performance became more stable during 2018.
-- Monthly completed orders generally remained around
-- 6,000–7,000, while monthly product revenue was mostly
-- between approximately 826,000 and 978,000.


-- May 2018 generated:
--
-- Completed orders: 6,749
-- Product revenue: 977,544.69
--
-- Despite having fewer orders than November 2017,
-- May 2018 generated almost the same level of product revenue.
--
-- This suggests that order volume alone does not fully explain
-- monthly revenue performance.


-- =========================================================
-- Insight
-- =========================================================

-- Delivered-order volume and product revenue expanded strongly
-- through 2017, followed by a more stable performance pattern
-- during 2018.
--
-- Differences between monthly order volume and product revenue
-- suggest that changes in average value per order may also be
-- contributing to revenue performance.


-- =========================================================
-- Driver Hypotheses / Next Investigation
-- =========================================================

-- The observed revenue movements may potentially be driven by:
--
-- 1. Order volume
-- 2. Average Order Value (AOV)
-- 3. Product / category mix
-- 4. Higher-priced product categories
-- 5. Number of items purchased per order
-- 6. Geographic differences
-- 7. Customer composition (new vs. repeat customers)
-- 8. Seasonal demand or promotional periods
--
-- These are hypotheses only and should be tested before
-- drawing causal conclusions.


-- =========================================================
-- Recommendation
-- =========================================================

-- No business recommendation is made at this stage.
--
-- Before recommending pricing, promotion, or category actions,
-- the main drivers of the monthly revenue changes should be
-- identified.
--
-- Next step:
-- Decompose product revenue into order volume and
-- average product revenue per delivered order.



