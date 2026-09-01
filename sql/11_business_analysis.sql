-- =========================================================
-- OLIST E-COMMERCE - BUSINESS ANALYSIS
-- =========================================================
-- Analysis principle:
-- Business Question -> Analysis -> Insight -> Recommendation
--
-- Product revenue = SUM(order_items.price) for delivered orders.
-- Freight is excluded from product revenue.
-- Monthly analysis uses order_purchase_timestamp.
-- =========================================================

-- =========================================================
-- 1. MONTHLY DELIVERED ORDER VOLUME AND PRODUCT REVENUE
-- =========================================================
-- Business Question:
-- How have delivered-order volume and product revenue changed over time?

SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(DISTINCT o.order_id) AS completed_orders,
    ROUND(SUM(oi.price), 2) AS product_revenue
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
ORDER BY order_month;

-- Findings:
-- November 2017: 7,289 delivered orders and 987,765.37 product revenue.
-- May 2018: 6,749 delivered orders and 977,544.69 product revenue.
-- May generated almost the same product revenue as November despite fewer orders.
--
-- Insight:
-- Monthly product revenue cannot be explained by order volume alone.
-- Average value per delivered order also contributes to revenue performance.

-- =========================================================
-- 2. REVENUE DRIVER DECOMPOSITION: ORDER VOLUME VS AOV
-- =========================================================
-- Business Question:
-- Is revenue movement driven mainly by order volume or by Average Order Value?

SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_product_value_per_order
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
ORDER BY order_month;

-- Current finding:
-- Revenue differences are not driven by order volume alone.
-- During the investigated period, AOV increased while order volume decreased.
-- The next step is to decompose AOV into basket size and average item price.

-- =========================================================
-- 3. AOV DRIVER: ITEMS PER ORDER VS AVERAGE ITEM PRICE
-- =========================================================
-- Business Question:
-- Is higher AOV explained by customers buying more items,
-- or by a higher average value per item?

WITH order_level AS (
    SELECT
        o.order_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        COUNT(*) AS items_in_order,
        SUM(oi.price) AS order_product_value
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        o.order_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
)
SELECT
    order_month,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(order_product_value), 2) AS avg_product_value_per_order,
    ROUND(AVG(items_in_order), 3) AS avg_items_per_order,
    ROUND(SUM(order_product_value) / SUM(items_in_order), 2) AS avg_item_price
FROM order_level
GROUP BY order_month
ORDER BY order_month;

-- Finding:
-- Between March and May 2018, items per order increased only slightly,
-- while average item price increased more clearly.
-- This indicates that average item price was the stronger AOV driver.
--
-- Next Question:
-- Was the increase in average item price driven by category mix,
-- or by average-price movement within categories?

-- =========================================================
-- 4. MARCH VS MAY 2018: CATEGORY MIX OVERVIEW
-- =========================================================
-- Business Question:
-- Which categories gained or lost item share, and how did their
-- average item prices change between March and May 2018?

WITH category_monthly AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        COALESCE(
            NULLIF(TRIM(pct.product_category_name_english), ''),
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown'
        ) AS category,
        COUNT(*) AS items_sold,
        SUM(oi.price) AS item_revenue,
        AVG(oi.price) AS avg_item_price
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
        AND DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') IN ('2018-03', '2018-05')
    GROUP BY
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m'),
        COALESCE(
            NULLIF(TRIM(pct.product_category_name_english), ''),
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown'
        )
),
category_shares AS (
    SELECT
        order_month,
        category,
        items_sold,
        item_revenue,
        avg_item_price,
        items_sold * 100.0 / SUM(items_sold) OVER (PARTITION BY order_month) AS item_share_pct,
        item_revenue * 100.0 / SUM(item_revenue) OVER (PARTITION BY order_month) AS revenue_share_pct
    FROM category_monthly
)
SELECT
    category,
    MAX(CASE WHEN order_month = '2018-03' THEN items_sold END) AS march_items,
    MAX(CASE WHEN order_month = '2018-05' THEN items_sold END) AS may_items,
    ROUND(MAX(CASE WHEN order_month = '2018-03' THEN item_share_pct END), 2) AS march_item_share_pct,
    ROUND(MAX(CASE WHEN order_month = '2018-05' THEN item_share_pct END), 2) AS may_item_share_pct,
    ROUND(
        COALESCE(MAX(CASE WHEN order_month = '2018-05' THEN item_share_pct END), 0)
        - COALESCE(MAX(CASE WHEN order_month = '2018-03' THEN item_share_pct END), 0),
        2
    ) AS item_share_change_pp,
    ROUND(MAX(CASE WHEN order_month = '2018-03' THEN avg_item_price END), 2) AS march_avg_price,
    ROUND(MAX(CASE WHEN order_month = '2018-05' THEN avg_item_price END), 2) AS may_avg_price,
    ROUND(
        (
            MAX(CASE WHEN order_month = '2018-05' THEN avg_item_price END)
            / NULLIF(MAX(CASE WHEN order_month = '2018-03' THEN avg_item_price END), 0)
            - 1
        ) * 100,
        2
    ) AS avg_price_change_pct,
    ROUND(MAX(CASE WHEN order_month = '2018-03' THEN revenue_share_pct END), 2) AS march_revenue_share_pct,
    ROUND(MAX(CASE WHEN order_month = '2018-05' THEN revenue_share_pct END), 2) AS may_revenue_share_pct
FROM category_shares
GROUP BY category
ORDER BY ABS(item_share_change_pp) DESC;

-- Key category-share movements:
-- watches_gifts: 5.25% -> 8.00% (+2.75 pp)
-- housewares: 4.86% -> 7.91% (+3.05 pp)
-- health_beauty: 8.18% -> 9.62% (+1.43 pp)
-- computers_accessories: 9.36% -> 5.80% (-3.55 pp)
-- sports_leisure: 9.13% -> 6.26% (-2.87 pp)
-- office_furniture: 2.49% -> 1.33% (-1.16 pp)

-- =========================================================
-- 5. DECOMPOSE AVERAGE ITEM PRICE CHANGE:
--    CATEGORY MIX VS WITHIN-CATEGORY AVERAGE-PRICE EFFECT
-- =========================================================
-- Business Question:
-- How much of the March-to-May increase in average item price
-- is explained by category composition versus movement within categories?
--
-- Method:
-- Counterfactual May average = May category shares valued at March category prices.
-- This is a mix-first decomposition:
--   Mix effect = counterfactual May average - March actual average
--   Within-category effect = May actual average - counterfactual May average
--
-- Categories observed in only one of the two months use their observed
-- month's average price as the available baseline. Their entry/exit effect
-- is therefore assigned to category mix rather than within-category movement.

WITH category_monthly AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        COALESCE(
            NULLIF(TRIM(pct.product_category_name_english), ''),
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown'
        ) AS category,
        COUNT(*) AS items_sold,
        AVG(oi.price) AS avg_item_price
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
        AND DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') IN ('2018-03', '2018-05')
    GROUP BY
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m'),
        COALESCE(
            NULLIF(TRIM(pct.product_category_name_english), ''),
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown'
        )
),
category_comparison AS (
    SELECT
        category,
        MAX(CASE WHEN order_month = '2018-03' THEN items_sold END) AS march_items,
        MAX(CASE WHEN order_month = '2018-05' THEN items_sold END) AS may_items,
        MAX(CASE WHEN order_month = '2018-03' THEN avg_item_price END) AS march_avg_price,
        MAX(CASE WHEN order_month = '2018-05' THEN avg_item_price END) AS may_avg_price
    FROM category_monthly
    GROUP BY category
),
totals AS (
    SELECT
        SUM(COALESCE(march_items, 0)) AS total_march_items,
        SUM(COALESCE(may_items, 0)) AS total_may_items
    FROM category_comparison
),
averages AS (
    SELECT
        SUM(COALESCE(c.march_items, 0) * COALESCE(c.march_avg_price, 0))
            / MAX(t.total_march_items) AS march_actual_avg_price,
        SUM(COALESCE(c.may_items, 0) * COALESCE(c.may_avg_price, 0))
            / MAX(t.total_may_items) AS may_actual_avg_price,
        SUM(
            COALESCE(c.may_items, 0)
            * COALESCE(c.march_avg_price, c.may_avg_price)
        ) / MAX(t.total_may_items) AS may_mix_at_march_prices
    FROM category_comparison c
    CROSS JOIN totals t
)
SELECT
    ROUND(march_actual_avg_price, 2) AS march_avg_item_price,
    ROUND(may_actual_avg_price, 2) AS may_avg_item_price,
    ROUND(may_actual_avg_price - march_actual_avg_price, 2) AS total_change_brl_per_item,
    ROUND(may_mix_at_march_prices - march_actual_avg_price, 2) AS category_mix_effect_brl_per_item,
    ROUND(may_actual_avg_price - may_mix_at_march_prices, 2) AS within_category_effect_brl_per_item,
    ROUND(
        (may_mix_at_march_prices - march_actual_avg_price)
        / NULLIF(may_actual_avg_price - march_actual_avg_price, 0) * 100,
        2
    ) AS mix_share_of_change_pct,
    ROUND(
        (may_actual_avg_price - may_mix_at_march_prices)
        / NULLIF(may_actual_avg_price - march_actual_avg_price, 0) * 100,
        2
    ) AS within_share_of_change_pct
FROM averages;

-- Result:
-- March average item price: 118.92 BRL
-- May average item price: 125.17 BRL
-- Total increase: +6.25 BRL per item
-- Category mix effect: +4.37 BRL per item (~69.96%)
-- Within-category average-price effect: +1.88 BRL per item (~30.04%)
--
-- Insight:
-- Under this mix-first decomposition, the majority of the increase in
-- average item price is associated with a shift in category composition.
-- The remaining increase is associated with movement in average item prices
-- within categories.

-- =========================================================
-- 6. CATEGORY CONTRIBUTION TO THE MIX EFFECT
-- =========================================================
-- Business Question:
-- Which category-share movements contributed most to the +4.37 BRL/item
-- net category-mix effect?

WITH category_monthly AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        COALESCE(
            NULLIF(TRIM(pct.product_category_name_english), ''),
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown'
        ) AS category,
        COUNT(*) AS items_sold,
        AVG(oi.price) AS avg_item_price
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
        AND DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') IN ('2018-03', '2018-05')
    GROUP BY
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m'),
        COALESCE(
            NULLIF(TRIM(pct.product_category_name_english), ''),
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown'
        )
),
category_comparison AS (
    SELECT
        category,
        MAX(CASE WHEN order_month = '2018-03' THEN items_sold END) AS march_items,
        MAX(CASE WHEN order_month = '2018-05' THEN items_sold END) AS may_items,
        MAX(CASE WHEN order_month = '2018-03' THEN avg_item_price END) AS march_avg_price,
        MAX(CASE WHEN order_month = '2018-05' THEN avg_item_price END) AS may_avg_price
    FROM category_monthly
    GROUP BY category
),
totals AS (
    SELECT
        SUM(COALESCE(march_items, 0)) AS total_march_items,
        SUM(COALESCE(may_items, 0)) AS total_may_items
    FROM category_comparison
),
contributions AS (
    SELECT
        c.category,
        COALESCE(c.march_items, 0) / t.total_march_items AS march_share,
        COALESCE(c.may_items, 0) / t.total_may_items AS may_share,
        c.march_avg_price,
        c.may_avg_price,
        COALESCE(c.march_avg_price, c.may_avg_price) AS base_price
    FROM category_comparison c
    CROSS JOIN totals t
)
SELECT
    category,
    ROUND(march_share * 100, 2) AS march_item_share_pct,
    ROUND(may_share * 100, 2) AS may_item_share_pct,
    ROUND((may_share - march_share) * 100, 2) AS share_change_pp,
    ROUND(base_price, 2) AS base_price_brl,
    ROUND(
        may_share * base_price
        - march_share * COALESCE(march_avg_price, 0),
        2
    ) AS mix_contribution_brl_per_item
FROM contributions
ORDER BY mix_contribution_brl_per_item DESC;

-- Main positive mix contributors:
-- watches_gifts: +6.25 BRL/item
-- housewares: +2.74 BRL/item
-- health_beauty: +1.85 BRL/item
-- computers: +1.11 BRL/item
-- construction_tools_construction: +1.11 BRL/item
--
-- Main negative mix contributors:
-- computers_accessories: -4.02 BRL/item
-- sports_leisure: -3.20 BRL/item
-- office_furniture: -1.79 BRL/item
-- Unknown: -1.40 BRL/item
-- cool_stuff: -1.37 BRL/item
--
-- Interpretation:
-- watches_gifts was the strongest positive mix driver, with item share
-- increasing from 5.25% to 8.00%. Positive mix effects were partly offset
-- by large share declines in computers_accessories and sports_leisure.

-- =========================================================
-- 7. CATEGORY CONTRIBUTION TO WITHIN-CATEGORY EFFECT
-- =========================================================
-- Business Question:
-- Which categories contributed most to the +1.88 BRL/item
-- within-category average-price effect?

WITH category_monthly AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        COALESCE(
            NULLIF(TRIM(pct.product_category_name_english), ''),
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown'
        ) AS category,
        COUNT(*) AS items_sold,
        AVG(oi.price) AS avg_item_price
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
        AND DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') IN ('2018-03', '2018-05')
    GROUP BY
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m'),
        COALESCE(
            NULLIF(TRIM(pct.product_category_name_english), ''),
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown'
        )
),
category_comparison AS (
    SELECT
        category,
        MAX(CASE WHEN order_month = '2018-03' THEN items_sold END) AS march_items,
        MAX(CASE WHEN order_month = '2018-05' THEN items_sold END) AS may_items,
        MAX(CASE WHEN order_month = '2018-03' THEN avg_item_price END) AS march_avg_price,
        MAX(CASE WHEN order_month = '2018-05' THEN avg_item_price END) AS may_avg_price
    FROM category_monthly
    GROUP BY category
),
totals AS (
    SELECT
        SUM(COALESCE(may_items, 0)) AS total_may_items
    FROM category_comparison
)
SELECT
    c.category,
    ROUND(COALESCE(c.may_items, 0) / t.total_may_items * 100, 2) AS may_item_share_pct,
    ROUND(c.march_avg_price, 2) AS march_avg_price_brl,
    ROUND(c.may_avg_price, 2) AS may_avg_price_brl,
    ROUND(
        (c.may_avg_price / NULLIF(c.march_avg_price, 0) - 1) * 100,
        2
    ) AS avg_price_change_pct,
    ROUND(
        COALESCE(c.may_items, 0) / t.total_may_items
        * (
            COALESCE(c.may_avg_price, c.march_avg_price)
            - COALESCE(c.march_avg_price, c.may_avg_price)
        ),
        2
    ) AS within_price_contribution_brl_per_item
FROM category_comparison c
CROSS JOIN totals t
ORDER BY within_price_contribution_brl_per_item DESC;

-- Main positive within-category contributors:
-- toys: +1.21 BRL/item
-- musical_instruments: +1.09 BRL/item
-- housewares: +0.93 BRL/item
-- garden_tools: +0.92 BRL/item
-- bed_bath_table: +0.86 BRL/item
-- electronics: +0.63 BRL/item
--
-- Main negative within-category contributors:
-- watches_gifts: -2.90 BRL/item
-- baby: -1.55 BRL/item
-- small_appliances: -1.09 BRL/item
-- consoles_games: -0.71 BRL/item
-- audio: -0.49 BRL/item
--
-- Important example:
-- watches_gifts had a strong positive category-mix contribution (+6.25)
-- but a negative within-category contribution (-2.90).
-- Its share increased strongly, while its average item price decreased.

-- =========================================================
-- 8. REVENUE DRIVER ANALYSIS - FINAL BUSINESS STORY
-- =========================================================
-- Business Question:
-- Why did average item price increase from March to May 2018?
--
-- Analysis:
-- 1. Compared category item-share movements between March and May.
-- 2. Decomposed average item price into category-mix and
--    within-category average-price effects.
-- 3. Ranked positive and negative category contributions.
--
-- Insight:
-- Average item price increased from 118.92 BRL to 125.17 BRL,
-- a total increase of 6.25 BRL per item.
--
-- Under the mix-first decomposition:
-- - ~70% (+4.37 BRL/item) was associated with category-mix changes.
-- - ~30% (+1.88 BRL/item) was associated with average-price movement
--   within categories.
--
-- The strongest positive mix drivers were watches_gifts, housewares,
-- and health_beauty. Their effects were partly offset by declining
-- shares in computers_accessories, sports_leisure, and office_furniture.
--
-- Recommendation:
-- Monitor categories gaining item share, especially higher-value categories,
-- and investigate whether these shifts are seasonal, campaign-related,
-- or persistent. Product/category composition should be treated as a key
-- driver when interpreting AOV and revenue movement rather than assuming
-- that higher AOV reflects broad-based price increases.
--
-- Analytical caveat:
-- "Within-category average-price effect" does not prove that individual
-- product prices increased. It can also reflect a shift toward different
-- products/SKUs within the same category. Product-level analysis would be
-- required to distinguish true price movement from within-category product mix.
