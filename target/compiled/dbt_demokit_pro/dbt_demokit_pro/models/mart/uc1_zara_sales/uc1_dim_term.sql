

WITH unique_terms AS (
    SELECT DISTINCT terms
    FROM "awsdatacatalog"."offybi_mart"."uc1_dim_product"
)

SELECT
    terms,
    row_number() OVER (ORDER BY terms ASC) AS term_id
FROM unique_terms