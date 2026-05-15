create or replace view
    "awsdatacatalog"."offybi_mart"."uc1_dim_material"
  as
    

WITH v_unique AS (
    SELECT DISTINCT material
    FROM "awsdatacatalog"."offybi_mart"."uc1_dim_product"
)

SELECT
    material,
    row_number() OVER (ORDER BY material ASC) AS material_id
FROM v_unique
