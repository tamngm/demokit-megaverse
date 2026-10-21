-- Raw Zara sales (Kaggle marixe/zara-sales-for-eda) as uploaded to S3.
-- The parquet keeps the original headers ("Product ID", "Sales Volume", ...), which Athena
-- can't map by name, so columns are read by position: keep this order in sync with the file.
CREATE EXTERNAL TABLE IF NOT EXISTS offybi.uc1_zara_product_sales_raw (
    product_id BIGINT,
    product_position STRING,
    promotion STRING,
    product_category STRING,
    seasonal STRING,
    sales_volume BIGINT,
    brand STRING,
    url STRING,
    name STRING,
    description STRING,
    price DOUBLE,
    currency STRING,
    terms STRING,
    section STRING,
    season STRING,
    material STRING,
    origin STRING
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/marixe_zara_product_sales/raw/'
TBLPROPERTIES ('parquet.compress'='SNAPPY', 'parquet.column.index.access'='true');
