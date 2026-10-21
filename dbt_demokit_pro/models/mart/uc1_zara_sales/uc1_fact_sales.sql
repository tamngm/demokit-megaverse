{{
    config(
        schema='mart',
        materialized='table'
    )
}}

SELECT
    product_id,
    ROUND(SUM(sales), 2) AS sales,
    SUM(sales_volume) AS sales_volume,
    SUM(price) AS price

FROM {{ ref('uc1_za_product_sales_stg') }}
GROUP BY product_id
