{{
    config(
        schema='mart',
        materialized='table'
    )
}}

SELECT DISTINCT
    product_id,
    product_position,
    product_category,
    seasonal,
    brand,
    url,
    name,
    description,
    price,
    terms ,
    section ,
    season,
    material,
    origin 
FROM {{ source('uc1_zara_sales', 'uc1_zara_product_sales_stg') }}
