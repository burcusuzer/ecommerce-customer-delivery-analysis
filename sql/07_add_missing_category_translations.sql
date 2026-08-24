-- =========================================================
-- Add Missing Product Category Translations
-- =========================================================
-- Two product categories in the products table are missing
-- from the original category translation dataset.
-- Adding them prevents valid sales from remaining untranslated
-- in category-level analysis.

INSERT INTO product_category_name_translation (
    product_category_name,
    product_category_name_english
)
VALUES
    ('pc_gamer', 'pc_gamer'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_food_preparation_appliances')
ON DUPLICATE KEY UPDATE
    product_category_name_english = VALUES(product_category_name_english);