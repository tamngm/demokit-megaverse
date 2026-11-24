-- uc5 supplier relation: raw tables on the masked Parquet files in
-- s3://offy-bi-demo/data/offybi/supplier_relation/<table>/ (one folder per tab of pulse_sku_kb.xlsx).
-- Values are masked (src/tool/mask_dataset.py): codes tokenised, names fake, amounts scaled, dates shifted.
-- Column types match the Parquet files. Run: .venv\Scripts\python.exe src\loader\create_athena_tbl.py uc5_supplier_relatio_raw.sql

DROP TABLE IF EXISTS `offybi`.`uc5_srm_quotes`;
DROP TABLE IF EXISTS `offybi`.`uc5_srm_quote_lines`;
DROP TABLE IF EXISTS `offybi`.`uc5_srm_price_matrix`;
DROP TABLE IF EXISTS `offybi`.`uc5_srm_line_prices`;
DROP TABLE IF EXISTS `offybi`.`uc5_srm_quote_adjustments`;
DROP TABLE IF EXISTS `offybi`.`uc5_srm_payment_schedule`;
DROP TABLE IF EXISTS `offybi`.`uc5_srm_skus`;
DROP TABLE IF EXISTS `offybi`.`uc5_srm_supplier_editor`;

-- ============ quotes: one row per quote document (59 rows) ============
CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc5_srm_quotes` (
  `oid` string COMMENT 'Opportunity id, joins to every quote-level table',
  `supplier` string COMMENT 'Supplier who issued the quote',
  `supplier_type` string COMMENT 'vendor_direct, distributor, service_provider, internal_affiliate',
  `editor` string COMMENT 'Software / hardware vendor (editor)',
  `doc_type` string COMMENT 'quote, order_form, purchase_order ...',
  `direction` string COMMENT 'BUY or SELL',
  `quote_number` string COMMENT 'Quote number, joins to the line tables',
  `revision` string COMMENT 'Quote revision',
  `quote_date` date COMMENT 'Quote date',
  `valid_until` date COMMENT 'Quote validity end',
  `bill_to` string COMMENT 'Billing entity and address',
  `end_customer` string COMMENT 'End customer',
  `project_name` string COMMENT 'Project name',
  `vendor_quote_ref` string COMMENT 'Vendor quote reference',
  `deal_reg` string COMMENT 'Deal registration id(s)',
  `currency` string COMMENT 'Quote currency (EUR, USD)',
  `fx_rate` double COMMENT 'Exchange rate used in the quote',
  `contract_start` date COMMENT 'Contract start',
  `contract_end` date COMMENT 'Contract end',
  `term_months` double COMMENT 'Contract term in months',
  `billing_frequency` string COMMENT 'monthly, annual, upfront',
  `payment_terms` string COMMENT 'Payment terms as printed',
  `incoterms` string COMMENT 'Incoterms',
  `total_list` double COMMENT 'Total at list price',
  `total_net_excl_tax` double COMMENT 'Total net, excluding tax',
  `tax_amount` double COMMENT 'Tax amount',
  `total_incl_tax` double COMMENT 'Total including tax',
  `lines` bigint COMMENT 'Number of quote lines',
  `sales_contact` string COMMENT 'Supplier sales contact',
  `business_line_from_scenario_demo` string COMMENT 'Business line (demo scenario)',
  `extraction_method` string COMMENT 'How the quote was extracted: pdf_text, xlsx_cells, msg_body ...',
  `notes` string COMMENT 'Extraction notes'
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/supplier_relation/pulse_sku_kb_quotes/';

-- ============ quote_lines: one row per quote line (450 rows) ============
CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc5_srm_quote_lines` (
  `oid` string COMMENT 'Opportunity id',
  `editor` string COMMENT 'Vendor (editor)',
  `supplier` string COMMENT 'Supplier',
  `quote_number` string COMMENT 'Quote number, joins to uc5_srm_quotes',
  `line_no` bigint COMMENT 'Line number in the quote',
  `sku` string COMMENT 'SKU, joins to uc5_srm_skus.sku_code',
  `supplier_ref` string COMMENT 'Supplier internal reference',
  `description` string COMMENT 'Line description',
  `item_type` string COMMENT 'SOFTWARE, HARDWARE, SERVICE, FEE',
  `type_status` string COMMENT 'Item type review status',
  `cdr` string COMMENT 'CDR (to input)',
  `business_line_from_scenario_demo` string COMMENT 'Business line (demo scenario)',
  `quantity` double COMMENT 'Quantity',
  `unit_of_measure` string COMMENT 'Unit of measure',
  `unit_list_price` double COMMENT 'Unit list price',
  `discount_pct` double COMMENT 'Discount % on the line',
  `unit_net_price` double COMMENT 'Unit net price',
  `line_total_list` double COMMENT 'Line total at list price',
  `line_total_net` double COMMENT 'Line total net',
  `effective_discount_pct` double COMMENT 'Effective discount % (net vs list)',
  `currency` string COMMENT 'Line currency',
  `term_months` double COMMENT 'Line term in months',
  `start_date` date COMMENT 'Line start date',
  `end_date` date COMMENT 'Line end date',
  `parent_line_no` double COMMENT 'Parent line number (support / add-on lines)',
  `covered_sku` string COMMENT 'SKU covered by this line (support, renewal)',
  `serial_number` string COMMENT 'Serial number(s) covered',
  `notes` string COMMENT 'Extraction notes'
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/supplier_relation/pulse_sku_kb_quote_lines/';

-- ============ price_matrix: same lines, one column per kind of price (450 rows) ============
CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc5_srm_price_matrix` (
  `oid` string COMMENT 'Opportunity id',
  `editor` string COMMENT 'Vendor (editor)',
  `supplier` string COMMENT 'Supplier',
  `quote_number` string COMMENT 'Quote number',
  `line_no` bigint COMMENT 'Line number',
  `sku` string COMMENT 'SKU',
  `description` string COMMENT 'Line description',
  `item_type` string COMMENT 'Item type',
  `quantity` double COMMENT 'Quantity',
  `term_months` double COMMENT 'Term in months',
  `line_total_list` double COMMENT 'Line total at list price',
  `line_total_net` double COMMENT 'Line total net',
  `effective_discount_pct` double COMMENT 'Effective discount %',
  `currencies` string COMMENT 'Currency or currencies of the line',
  `list_ext` double COMMENT 'List price, extended',
  `list_ext_year` double COMMENT 'List price, extended, per year',
  `list_unit` double COMMENT 'List price per unit',
  `list_unit_month` double COMMENT 'List price per unit per month',
  `list_unit_year` double COMMENT 'List price per unit per year',
  `disc_additional` double COMMENT 'Additional discount %',
  `disc_new_logo` double COMMENT 'New logo discount %',
  `disc_other` double COMMENT 'Other discount %',
  `disc_partner` double COMMENT 'Partner discount %',
  `disc_payment_incentive` double COMMENT 'Payment incentive discount %',
  `disc_program` double COMMENT 'Program discount %',
  `disc_standard` double COMMENT 'Standard discount %',
  `disc_term` double COMMENT 'Term discount %',
  `disc_total` double COMMENT 'Total discount %',
  `disc_volume` double COMMENT 'Volume discount %',
  `uplift_year` double COMMENT 'Yearly uplift %',
  `net_ext` double COMMENT 'Net price, extended',
  `net_ext_month` double COMMENT 'Net price, extended, per month',
  `net_ext_year` double COMMENT 'Net price, extended, per year',
  `net_unit` double COMMENT 'Net price per unit',
  `net_unit_month` double COMMENT 'Net price per unit per month',
  `net_unit_year` double COMMENT 'Net price per unit per year',
  `fee_ext` double COMMENT 'Fee, extended',
  `fee_unit` double COMMENT 'Fee per unit',
  `usage_rate_unit_month` double COMMENT 'Usage rate per unit per month',
  `sell_ext` double COMMENT 'Sell price, extended',
  `sell_unit` double COMMENT 'Sell price per unit',
  `list_year_1` double COMMENT 'List price, year 1',
  `list_year_2` double COMMENT 'List price, year 2',
  `list_year_3` double COMMENT 'List price, year 3',
  `list_year_4` double COMMENT 'List price, year 4',
  `list_year_5` double COMMENT 'List price, year 5',
  `net_year_1` double COMMENT 'Net price, year 1',
  `net_year_2` double COMMENT 'Net price, year 2',
  `net_year_3` double COMMENT 'Net price, year 3',
  `net_year_4` double COMMENT 'Net price, year 4',
  `net_year_5` double COMMENT 'Net price, year 5',
  `net_year_6` double COMMENT 'Net price, year 6'
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/supplier_relation/pulse_sku_kb_price_matrix/';

-- ============ line_prices: one row per price component of a line (1,734 rows) ============
CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc5_srm_line_prices` (
  `oid` string COMMENT 'Opportunity id',
  `editor` string COMMENT 'Vendor (editor)',
  `quote_number` string COMMENT 'Quote number',
  `line_no` bigint COMMENT 'Line number, with quote_number joins to uc5_srm_quote_lines',
  `sku` string COMMENT 'SKU',
  `description` string COMMENT 'Line description',
  `quantity` double COMMENT 'Quantity',
  `seq` bigint COMMENT 'Order of the component within the line',
  `component` string COMMENT 'NET, LIST, DISCOUNT, FEE, USAGE_RATE ...',
  `discount_type` string COMMENT 'STANDARD, PARTNER, OTHER ...',
  `basis` string COMMENT 'UNIT, EXTENDED or PERCENT (amount is a % when PERCENT)',
  `amount` double COMMENT 'Amount of the component',
  `pct` double COMMENT 'Percentage of the component',
  `currency` string COMMENT 'Currency',
  `price_period` string COMMENT 'TERM, MONTHLY, YEARLY, ONE_TIME',
  `schedule_label` string COMMENT 'Schedule label (Year 1, Year 2 ...)',
  `period_start` date COMMENT 'Period start',
  `period_end` date COMMENT 'Period end',
  `printed_label` string COMMENT 'Label as printed on the quote'
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/supplier_relation/pulse_sku_kb_line_prices/';

-- ============ quote_adjustments: tax, freight, one-time discounts per quote (41 rows) ============
CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc5_srm_quote_adjustments` (
  `oid` string COMMENT 'Opportunity id',
  `editor` string COMMENT 'Vendor (editor)',
  `quote_number` string COMMENT 'Quote number',
  `type` string COMMENT 'TAX, FREIGHT, ONE_TIME_DISCOUNT',
  `label` string COMMENT 'Label as printed',
  `amount` double COMMENT 'Adjustment amount',
  `pct` double COMMENT 'Adjustment % (e.g. VAT rate)',
  `currency` string COMMENT 'Currency'
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/supplier_relation/pulse_sku_kb_quote_adjustments/';

-- ============ payment_schedule: payment instalments per quote (66 rows) ============
CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc5_srm_payment_schedule` (
  `oid` string COMMENT 'Opportunity id',
  `editor` string COMMENT 'Vendor (editor)',
  `quote_number` string COMMENT 'Quote number',
  `seq` bigint COMMENT 'Instalment number',
  `label` string COMMENT 'Instalment label as printed',
  `due_date` date COMMENT 'Due date',
  `period_start` date COMMENT 'Period start',
  `period_end` date COMMENT 'Period end',
  `amount` double COMMENT 'Instalment amount',
  `currency` string COMMENT 'Currency'
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/supplier_relation/pulse_sku_kb_payment_schedule/';

-- ============ skus: one row per SKU (200 rows) ============
CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc5_srm_skus` (
  `editor` string COMMENT 'Vendor (editor)',
  `sku_code` string COMMENT 'SKU code (key)',
  `description` string COMMENT 'SKU description',
  `item_type` string COMMENT 'SOFTWARE, HARDWARE, SERVICE, FEE',
  `times_quoted` bigint COMMENT 'Number of quotes the SKU appears in',
  `first_seen` date COMMENT 'First quote date',
  `last_seen` date COMMENT 'Last quote date'
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/supplier_relation/pulse_sku_kb_skus/';

-- ============ supplier_editor: one row per supplier x editor (22 rows) ============
CREATE EXTERNAL TABLE IF NOT EXISTS `offybi`.`uc5_srm_supplier_editor` (
  `supplier` string COMMENT 'Supplier',
  `supplier_type` string COMMENT 'Supplier type',
  `editor` string COMMENT 'Vendor (editor)',
  `quotes` bigint COMMENT 'Number of quotes',
  `first_seen` date COMMENT 'First quote date',
  `last_seen` date COMMENT 'Last quote date'
)
STORED AS PARQUET
LOCATION 's3://offy-bi-demo/data/offybi/supplier_relation/pulse_sku_kb_supplier_editor/';