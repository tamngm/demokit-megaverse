{{
    config(
        materialized='view'
    )
}}

-- Replaces src/transfomator/transform_zara_product_price.py:
-- derive sales, drop rows with any missing value, enforce the staging schema.
SELECT
    CAST(product_id AS VARCHAR) AS product_id,
    product_position,
    promotion,
    product_category,
    seasonal,
    CAST(sales_volume AS BIGINT) AS sales_volume,
    brand,
    url,
    name,
    description,
    CAST(price AS DOUBLE) AS price,
    currency,
    CAST(sales_volume * price AS DOUBLE) AS sales,
    terms,
    section,
    season,
    material,
    origin

FROM {{ source('uc1_zara_sales', 'uc1_zara_product_sales_raw') }}
WHERE product_id IS NOT NULL
    AND product_position IS NOT NULL
    AND promotion IS NOT NULL
    AND product_category IS NOT NULL
    AND seasonal IS NOT NULL
    AND sales_volume IS NOT NULL
    AND brand IS NOT NULL
    AND url IS NOT NULL
    AND name IS NOT NULL
    AND description IS NOT NULL
    AND price IS NOT NULL
    AND currency IS NOT NULL
    AND terms IS NOT NULL
    AND section IS NOT NULL
    AND season IS NOT NULL
    AND material IS NOT NULL
    AND origin IS NOT NULL
