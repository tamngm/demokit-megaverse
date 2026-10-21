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
    promotion,
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
FROM {{ ref('uc1_za_product_sales_stg') }}
