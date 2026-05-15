create or replace view
    "awsdatacatalog"."offybi_mart"."uc1_dim_material"
  as
    

SELECT DISTINCT
    material,
    row_number() over (order by material asc) as material_id
 
FROM "awsdatacatalog"."offybi_mart"."uc1_dim_product"
