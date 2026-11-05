-- Initiate raw tables from parquet files in S3

DROP TABLE IF EXISTS `offybi`.`uc3_rtl_fsh_customers`;
DROP TABLE IF EXISTS `offybi`.`uc3_rtl_fsh_discounts`;
DROP TABLE IF EXISTS `offybi`.`uc3_rtl_fsh_employees`;
DROP TABLE IF EXISTS `offybi`.`uc3_rtl_fsh_products`;
DROP TABLE IF EXISTS `offybi`.`uc3_rtl_fsh_stores`;
DROP TABLE IF EXISTS `offybi`.`uc3_rtl_fsh_transactions`;

-- ============ customers (9 columns) ============
-- Bulk add columns (Athena console > Create table > Column details):
-- customer_id bigint, name string, email string, telephone string, city string, country string, gender string, date_of_birth date, job_title string

CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc3_rtl_fsh_customers` (
  `customer_id` bigint COMMENT 'Unique numeric identifier for the customer',
  `name` string COMMENT 'Full name (may include titles/honorifics like Mr. or professional suffixes)',
  `email` string COMMENT 'Anonymized email with fake domains (fake_gmail.com, fake_hotmail.com)',
  `telephone` string COMMENT 'Phone number with inconsistent formatting (mix of country codes and extensions)',
  `city` string COMMENT 'City',
  `country` string COMMENT 'Country',
  `gender` string COMMENT 'Gender (F, M, D) D = «diverse»',
  `date_of_birth` date COMMENT 'Birthdate in YYYY-MM-DD format',
  `job_title` string COMMENT 'Occupation (optional field- may be empty or contain multiple roles)'
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/retail_fashion/customers/';

-- ============ discounts (7 columns) ============
-- Bulk add columns (Athena console > Create table > Column details):
-- start_date date, end_date date, discount double, description string, discount_percentage double, category string, sub_category string

CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc3_rtl_fsh_discounts` (
  `start` date COMMENT 'Date when the discount becomes active, in YYYY-MM-DD format',
  `end` date COMMENT 'Date when the discount expires, in YYYY-MM-DD format',
  `discont` double COMMENT 'Decimal value representing the discount rate (e.g., 0.20 means 20% discount)',
  `description` string COMMENT 'Brief description of the discount campaign',
  `category` string COMMENT 'Product categories to which the discount applies',
  `sub_category` string COMMENT 'Product Sub Category to which the discount applies'
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/retail_fashion/discounts/';

-- ============ employees (4 columns) ============
-- Bulk add columns (Athena console > Create table > Column details):
-- employee_id bigint, store_id bigint, name string, position string

CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc3_rtl_fsh_employees` (
  `employee_id` bigint COMMENT 'Unique numeric identifier for the employee',
  `store_id` bigint COMMENT 'Foreign key linking to the Store ID location in stores.csv',
  `name` string COMMENT 'Full name in [First Name] [Last Name] format',
  `position` string COMMENT 'Role within store hierarchy (Manager oversees operations, Seller handles transactions)'
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/retail_fashion/employees/';

-- ============ products (12 columns) ============
-- Bulk add columns (Athena console > Create table > Column details):
-- product_id bigint, category string, sub_category string, description_pt string, description_de string, description_fr string, description_es string, description_en string, description_zh string, color string, sizes string, production_cost double

CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc3_rtl_fsh_products` (
  `product_id` bigint COMMENT 'Unique numeric identifier for the product',
  `category` string COMMENT 'High-level classification of the product (EN) (e.g., Feminine, Masculine, Children)',
  `sub_category` string COMMENT 'More specific classification within the category (EN)',
  `description_pt` string COMMENT 'Product description in Portuguese',
  `description_de` string COMMENT 'Product description in German',
  `description_fr` string COMMENT 'Product description in French',
  `description_es` string COMMENT 'Product description in Spanish',
  `description_en` string COMMENT 'Product description in English',
  `description_zh` string COMMENT 'Product description in Chinese',
  `color` string COMMENT 'Product Color',
  `sizes` string COMMENT 'Product Sizes Available',
  `production_cost` double COMMENT 'Cost incurred to produce the Product in USD'
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/retail_fashion/products/';

-- ============ stores (8 columns) ============
-- Bulk add columns (Athena console > Create table > Column details):
-- store_id bigint, country string, city string, store_name string, number_of_employees bigint, zip_code bigint, latitude double, longitude double

CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc3_rtl_fsh_stores` (
  `store_id` bigint COMMENT 'Unique identifier for the store location',
  `country` string COMMENT 'Country where the store is located',
  `city` string COMMENT 'City where the store is located',
  `store_name` string COMMENT 'Human-readable name following the format Store [City]',
  `number_of_employees` bigint COMMENT 'Total employees assigned to the store',
  `zip_code` string COMMENT 'Postal code for the store’s location',
  `latitude` double COMMENT 'Geographical latitude of the store location',
  `longitude` double COMMENT 'Geographical longitude of the store location'
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/retail_fashion/stores/';

-- ============ transactions (21 columns, one S3 folder per month: 
-- transactions_monthly/YYYY-MM-01/) business_month comes from the folder name (partition projection); 
-- business_date and business_timestamp are in the files.

CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc3_rtl_fsh_transactions` (
  `invoice_id` string COMMENT 'A unique identifier for each transaction, distinguishing sales and returns. It follows the format: (INV for sales or RET for returns) Country Code Store ID Sequential Counter.',
  `line` bigint COMMENT 'Sequential number representing the position of the product in the invoice. A single invoice can contain multiple line items.',
  `customer_id` bigint COMMENT 'Unique identifier referencing the customer who made the purchase, found in customers.csv.',
  `product_id` bigint COMMENT 'Unique identifier referencing the product purchased, found in products.csv.',
  `size` string COMMENT 'Product size variant (e.g., S, M, L, XL). Left blank if not applicable.',
  `color` string COMMENT 'Color variation of the product. Left blank if not applicable.',
  `unit_price` double COMMENT 'Price of a single unit of the product before any discounts are applied.',
  `quantity` bigint COMMENT 'Number of units of the product purchased within this invoice line item.',
  `date` timestamp COMMENT 'Date and time of the transaction in the format YYYY-MM-DD HH:MM:SS (24-hour format).',
  `discount` double COMMENT 'Discount applied to the line item, represented as a decimal (e.g., 0.30 = 30% discount, 0.00 = no discount), found list of discounts.csv.',
  `line_total` double COMMENT 'Total cost for the line item after applying any discounts. Calculated as: Unit Price × Quantity × (1 - Discount).',
  `store_id` bigint COMMENT 'Unique identifier referencing the store where the transaction took place, found in stores.csv.',
  `employee_id` bigint COMMENT 'Unique identifier referencing the employee who processed the transaction, found in employees.csv.',
  `currency` string COMMENT 'Three-letter ISO currency code representing the currency used for the transaction (e.g., USD, EUR, CNY, GBP).',
  `currency_symbol` string COMMENT 'Symbol associated with the transaction currency (e.g., $, €, £, ¥).',
  `sku` string COMMENT 'Stock Keeping Unit (SKU), a unique inventory code combining the Product ID, Size, and Color (e.g., FESH81-M-PINK = Product ID 81 + Size M + Color PINK).',
  `transaction_type` string COMMENT 'Specifies whether the transaction is a Sale or Return.',
  `payment_method` string COMMENT 'Method used to complete the transaction (e.g., Credit Card, Cash).',
  `invoice_total` double COMMENT 'Refers to the total value of the transaction (Invoice ID). It is the sum of all Line Total values for the same Invoice ID. This value is repeated across all line items within the same Invoice ID.',
  `business_date` date COMMENT 'business date',
  `business_timestamp` timestamp COMMENT 'business timestamp'
)
PARTITIONED BY (`business_month` date COMMENT 'Month start, from the S3 folder name (YYYY-MM-01).')
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/retail_fashion/transactions_monthly/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.business_month.type' = 'date',
  'projection.business_month.format' = 'yyyy-MM-dd',
  'projection.business_month.range' = '2023-01-01,NOW',
  'projection.business_month.interval' = '1',
  'projection.business_month.interval.unit' = 'MONTHS',
  'storage.location.template' = 's3://offy-bi-demo/data/offybi/retail_fashion/transactions_monthly/${business_month}/'
);