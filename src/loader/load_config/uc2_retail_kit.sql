CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`rtl_customer` (
  `customer_id` string,
  `name` string,
  `gender` string,
  `age` string,
  `email` string,
  `social_media_flag` string,
  `customer_type` string,
  `customer_level` string,
  `country_nationality` string
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES ('field.delim' = ',')
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat' OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://offy-bi-demo/data/offybi/retail_kit/customer/'
TBLPROPERTIES ('classification' = 'csv', 'skip.header.line.count' = '1');

CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`rtl_ecom_behave_to_order` (
  `order_purchased_date` string,
  `order_num` int,
  `cart_num` int,
  `view_num` int,
  `remove_dummy` string,
  `remove_cart_num` string
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES ('field.delim' = ',')
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat' OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://offy-bi-demo/data/offybi/retail_kit/ecom_behave_to_order/'
TBLPROPERTIES ('classification' = 'csv', 'skip.header.line.count' = '1');

CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`rtl_order` (
  `order_id` string,
  `customer_id` string,
  `latitude` string,
  `longitude` string,
  `market` string,
  `order_city` string,
  `order_country` string,
  `order_region` string,
  `order_state` string,
  `order_user_id` string,
  `order_item_total` int,
  `order_item_discount` DECIMAL(18,2),
  `sales` DECIMAL(18,2),
  `order_item_quantity` int,
  `order_profit_per_order` DECIMAL(18,2),
  `order_item_profit_ratio` DECIMAL(18,2),
  `order_purchased_date` date,
  `order_approved_at` date,
  `order_shipped_at` date,
  `order_delivery_date` date,
  `order_estimated_delivery_date` date,
  `order_status` string,
  `product_id` string
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES ('field.delim' = ',')
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat' OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://offy-bi-demo/data/offybi/retail_kit/order/'
TBLPROPERTIES ('classification' = 'csv', 'skip.header.line.count' = '1');

CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`rtl_product` (
  `product_id` string,
  `SKU` string,
  `product_name` string,
  `product_category` string,
  `price` DECIMAL(18,2)
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES ('field.delim' = ',')
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat' OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://offy-bi-demo/data/offybi/retail_kit/product/'
TBLPROPERTIES ('classification' = 'csv', 'skip.header.line.count' = '1');

CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`rtl_sales` (
  `sales_id` string,
  `sales_date` date,
  `product_id` string,
  `customer_id` string,
  `transaction` int,
  `price` DECIMAL(18,2),
  `store_id` string,
  `sales_hour` int,
  `quantity` int,
  `traffic` int,
  `gross_profit` DECIMAL(18,2)
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES ('field.delim' = ',')
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat' OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://offy-bi-demo/data/offybi/retail_kit/sales/'
TBLPROPERTIES ('classification' = 'csv', 'skip.header.line.count' = '1');

CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`rtl_store` (
  `store_id` string,
  `store_code` string,
  `store_location` string,
  `store_manager` string,
  `store_phone` string,
  `store_country` string,
  `store_market` string
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES ('field.delim' = ',')
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat' OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://offy-bi-demo/data/offybi/retail_kit/store/'
TBLPROPERTIES ('classification' = 'csv', 'skip.header.line.count' = '1');