USE olist_ecommerce;

-- =========================================================
-- Sellers Table
-- =========================================================
-- Grain:
-- One row represents one seller.
--
-- seller_id is unique in the source dataset and is used
-- as the primary key.

CREATE TABLE sellers (
    seller_id VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix INT,
    seller_city VARCHAR(100),
    seller_state CHAR(2)
);