{{
    config(
        schema='mart'
    )
}}

WITH v_unique AS (
    SELECT DISTINCT section
    FROM {{ ref('uc1_dim_product') }}
)

SELECT
    section,
    row_number() OVER (ORDER BY section ASC) AS section_id
FROM v_unique
