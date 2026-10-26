{{
    config(
        schema='mart',
        materialized='view'
    )
}}

SELECT *
FROM {{ source('uc2_retail_kit', 'rtl_store') }}
