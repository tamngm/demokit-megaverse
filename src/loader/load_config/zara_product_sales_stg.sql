-- src/loader/queries/zara_product_sales_stg.sql
CREATE EXTERNAL TABLE IF NOT EXISTS offybi.zara_product_sales_stg (
    product_id STRING,
    product_position STRING,
    promotion BOOLEAN,
    product_category STRING,
    seasonal STRING,
    sales_volume BIGINT,
    brand STRING,
    url STRING,
    name STRING,
    description STRING,
    price DOUBLE,
    currency STRING,
    sales DOUBLE,
    terms STRING,
    section STRING,
    season STRING,
    material STRING,
    origin STRING
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/marixe_zara_product_sales/staging/'
TBLPROPERTIES ('parquet.compress'='SNAPPY');