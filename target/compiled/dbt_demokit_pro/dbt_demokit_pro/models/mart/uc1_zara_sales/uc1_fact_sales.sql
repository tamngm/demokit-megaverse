

SELECT
    product_id,
    ROUND(SUM(sales), 2) AS sales,
    SUM(sales_volume) AS sales_volume,
    SUM(price) AS price

FROM "awsdatacatalog"."offybi"."uc1_zara_product_sales_stg"
GROUP BY product_id