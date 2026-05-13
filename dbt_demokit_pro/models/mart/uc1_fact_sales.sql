{{
    config(
        schema='mart',
        materialized='table'
    )
}}

SELECT
    product_id,
    ROUND(SUM(sales), 2) AS sales,
    SUM(sales_volume) AS sales_volume
    
FROM {{ source('uc1_zara_sales', 'uc1_zara_product_sales_stg') }}
GROUP BY product_id