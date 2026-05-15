{{
    config(
        schema='mart',
        materialized='view'
    )
}}

WITH v_unique AS (
    SELECT DISTINCT material
    FROM {{ ref('uc1_dim_product') }}
)

SELECT
    material,
    row_number() OVER (ORDER BY material ASC) AS material_id
FROM v_unique
