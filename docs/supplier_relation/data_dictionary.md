# Supplier relationship management (uc5): data dictionary

Tables and columns of the uc5 dataset, from the raw tables to the Power BI-ready marts.
Business meaning and how to read the data: [business_context.md](business_context.md).

> The column descriptions come from the dbt files
> `dbt_demokit_pro/models/mart/uc5_supplier_relation/uc5_supplier_relation.yml` and
> `dbt_demokit_pro/models/work/uc5_supplier_relation/uc5_supplier_relation_wk.yml`.
> Those files are the source of truth: when a column changes, update the yml first, then this page.

## Lineage

```
pulse_sku_kb.xlsx (OneDrive)
  -> split_excel_tab_to_csv.py   one CSV per tab + data dictionary
  -> mask_dataset.py             masked CSVs
  -> convert_csv_to_parquet.py   Parquet in s3://offy-bi-demo/data/offybi/supplier_relation/
  -> Athena offybi.uc5_srm_*     raw tables (uc5_supplier_relation_raw.sql)
  -> dbt work offybi_work        uc5_srm_supplier_editor_wk
  -> dbt mart offybi_mart        uc5_srm_dim_* / uc5_srm_fact_*
  -> Power BI                    fabricspace/supplier_relation/
```

## Raw tables (Athena `offybi`, dbt source `uc5_supplier_relation`)

One table per tab of the workbook, columns as in the source (masked values).

| Table | One row per | Used by |
|---|---|---|
| `uc5_srm_quotes` | quote document | `fact_quotes`, `dim_customer` |
| `uc5_srm_quote_lines` | quote line | `fact_quote_lines`, `fact_quotes` (line count), `dim_sku`, `supplier_editor_wk` |
| `uc5_srm_line_prices` | price component of a line | `fact_line_prices` |
| `uc5_srm_price_matrix` | quote line, one column per kind of price | not used (same content as line prices, wide) |
| `uc5_srm_quote_adjustments` | tax, freight or one-time discount of a quote | `fact_quotes` |
| `uc5_srm_payment_schedule` | payment instalment | `fact_payment_schedule` |
| `uc5_srm_skus` | SKU | `dim_sku` |
| `uc5_srm_supplier_editor` | supplier x editor | `supplier_editor_wk` |

## Keys and relationships

| Key | Built from | Unique in |
|---|---|---|
| `quote_key` | `hash_key(oid, quote_number)`: lower-cased, trimmed, md5 | `fact_quotes` |
| `quote_line_key` | `hash_key(quote_key, line_no)` | `fact_quote_lines` |
| `supplier`, `editor`, `end_customer`, `sku_code` | the names / codes themselves | their dim |

| From (many) | To (one) | On |
|---|---|---|
| `fact_quotes` | `dim_supplier` / `dim_editor` / `dim_customer` | `supplier` / `editor` / `end_customer` |
| `fact_quotes` | `dim_calendar` | `quote_date` -> `date` |
| `fact_quote_lines` | `fact_quotes` | `quote_key` |
| `fact_payment_schedule` | `fact_quotes` | `quote_key` |
| `fact_line_prices` | `fact_quote_lines` | `quote_line_key` (its only relationship) |
| `fact_quote_lines` | `dim_sku` | `sku` -> `sku_code` |

In Power BI, the dims filter the detail facts **through** `fact_quotes` (single direction); the `supplier` and
`editor` columns of the detail facts are for display only, to avoid a second filter path.

All model names below start with `uc5_srm_`.

---

## Work model

### `supplier_editor_wk` (offybi_work)
Supplier x editor pairs: the supplier list full-joined with the pairs seen in quote lines. Feeds `dim_supplier`,
`dim_editor` and `dim_supplier_editor`.

| Column | Description |
|---|---|
| `supplier` | Supplier name |
| `editor` | Editor name |
| `supplier_type` | Supplier type from the supplier list; NULL for pairs found only in quote lines |
| `quote_count` | Number of quotes (supplier list, else distinct quote numbers in quote lines) |
| `first_seen` | First quote date from the supplier list |
| `last_seen` | Last quote date from the supplier list |

---

## Dimensions (offybi_mart)

### `dim_supplier`
One row per supplier with its type.

| Column | Description |
|---|---|
| `supplier` | Supplier name (key); joins to the facts |
| `supplier_type` | `vendor_direct`, `distributor`, `service_provider`, `internal_affiliate` |

### `dim_editor`
One row per editor (software / hardware vendor).

| Column | Description |
|---|---|
| `editor` | Editor name (key); joins to the facts |

### `dim_supplier_editor`
One row per supplier x editor: which supplier sells which editor. A bridge between `dim_supplier` and
`dim_editor`: use it on its own ("who sells what"), not as a second path between the dims and the facts.

| Column | Description |
|---|---|
| `supplier` | Supplier name; joins to `dim_supplier` |
| `editor` | Editor name; joins to `dim_editor` |
| `supplier_type` | Supplier type; NULL for pairs found only in quote lines |
| `quote_count` | Number of quotes from this supplier for this editor |
| `first_seen` | Date of the first quote for this pair; NULL for pairs found only in quote lines |
| `last_seen` | Date of the last quote for this pair; NULL for pairs found only in quote lines |

### `dim_sku`
One row per SKU: the SKU list, plus SKUs found only in quote lines so every line finds its SKU.

| Column | Description |
|---|---|
| `sku_code` | SKU code (key); joins to `fact_quote_lines.sku` |
| `editor` | Editor of the SKU |
| `description` | SKU description |
| `item_type` | `SOFTWARE`, `HARDWARE`, `SERVICE`, `FEE` |
| `times_quoted` | Number of quotes the SKU appears in; NULL for SKUs found only in quote lines |
| `first_seen` | First quote date; NULL for SKUs found only in quote lines |
| `last_seen` | Last quote date; NULL for SKUs found only in quote lines |
| `is_from_lines_only` | true when the SKU is not in the SKU list and was added from the quote lines |

### `dim_customer`
One row per end customer.

| Column | Description |
|---|---|
| `end_customer` | End customer name (key); joins to `fact_quotes` |
| `quote_count` | Number of quotes for the customer |
| `first_quote_date` | Date of the first quote |
| `last_quote_date` | Date of the last quote |

---

## Facts (offybi_mart)

All amounts exist in the document currency (EUR or USD) and in EUR (`*_eur`, converted with the
`ref_exchange_rates` seed). Rows without a quote number are left out.

### `fact_quotes`
**Grain: one row per quote** (`quote_key` = oid + quote_number).

| Column | Description |
|---|---|
| `quote_key` | Quote key (hash of oid + quote_number); joins to the other facts |
| `oid` | Opportunity (project) id |
| `quote_number` | Quote number |
| `document_count` | Number of source rows merged into this quote (1, or 2 when the source repeats the quote) |
| `supplier` | Supplier; joins to `dim_supplier` |
| `supplier_type` | Supplier type |
| `editor` | Editor; joins to `dim_editor` |
| `end_customer` | End customer; joins to `dim_customer` |
| `doc_type` | quote, order_form, order_confirmation, purchase_order ... |
| `direction` | BUY (supplier quote to us) or SELL (our quote to the customer) |
| `revision` | Quote revision |
| `quote_date` | Quote date; joins to `dim_calendar` |
| `valid_until` | End of the quote validity |
| `validity_days` | Days from quote_date to valid_until; NULL if either date is missing |
| `contract_start` | Contract start date |
| `contract_end` | Contract end date |
| `term_months` | Contract term in months |
| `billing_frequency` | monthly, annual, upfront |
| `payment_terms` | Payment terms as printed |
| `incoterms` | Incoterms |
| `project_name` | Project name |
| `vendor_quote_ref` | Vendor quote reference |
| `deal_reg` | Deal registration id(s) |
| `sales_contact` | Supplier sales contact |
| `business_line` | Business line (demo scenario) |
| `line_count_declared` | Number of lines as declared on the quote |
| `line_count` | Number of lines found in `fact_quote_lines` |
| `currency` | Quote currency (EUR, USD) |
| `total_list` | Total at list price, quote currency |
| `total_net_excl_tax` | Total net excluding tax, quote currency |
| `tax_amount` | Tax amount, quote currency |
| `total_incl_tax` | Total including tax, quote currency |
| `freight_amount` | Freight from the quote adjustments, quote currency |
| `one_time_discount_amount` | One-time discount from the quote adjustments, quote currency |
| `eur_per_unit` | EUR for 1 unit of the quote currency |
| `total_list_eur` | Total at list price in EUR |
| `total_net_excl_tax_eur` | Total net excluding tax in EUR |
| `tax_amount_eur` | Tax amount in EUR |
| `total_incl_tax_eur` | Total including tax in EUR |
| `discount_rate` | 1 - total_net / total_list (0.25 = 25%); recompute in Power BI instead of averaging |

### `fact_quote_lines`
**Grain: one row per quote line** (`quote_line_key` = quote_key + line_no). The result of the pricing.

| Column | Description |
|---|---|
| `quote_line_key` | Line key (hash of quote_key + line_no); joins to `fact_line_prices` |
| `quote_key` | Quote key; joins to `fact_quotes` |
| `oid` | Opportunity id |
| `quote_number` | Quote number |
| `line_no` | Line number in the quote |
| `parent_line_no` | Parent line number (support / add-on lines) |
| `supplier` | Supplier (display only in Power BI) |
| `editor` | Editor (display only in Power BI) |
| `sku` | SKU; joins to `dim_sku.sku_code` |
| `covered_sku` | SKU covered by this line (support, renewal) |
| `item_type` | SOFTWARE, HARDWARE, SERVICE, FEE |
| `description` | Line description |
| `unit_of_measure` | Unit of measure |
| `business_line` | Business line (demo scenario) |
| `start_date` / `end_date` | Line start / end date |
| `term_months` | Line term in months |
| `currency` | Line currency |
| `quantity` | Quantity |
| `unit_list_price` / `unit_net_price` | Unit price before / after discount, line currency |
| `discount_pct` | Discount % on the line |
| `effective_discount_pct` | Effective discount % (net vs list) |
| `line_total_list` / `line_total_net` | Line total before / after discount, line currency |
| `line_discount_amount` | line_total_list - line_total_net, line currency |
| `eur_per_unit` | EUR for 1 unit of the line currency |
| `unit_net_price_eur` | Unit net price in EUR |
| `line_total_list_eur` / `line_total_net_eur` | Line totals in EUR |
| `line_discount_amount_eur` | Line discount amount in EUR |

### `fact_line_prices`
**Grain: one row per price component of a quote line** (list, net, each discount, fee, usage rate, by period).
How the line price and discount are built: see
[business_context.md, Quote lines vs line prices](business_context.md#4-quote-lines-vs-line-prices).

| Column | Description |
|---|---|
| `quote_key` | Quote key |
| `quote_line_key` | Line key; joins to `fact_quote_lines` (its only relationship in Power BI) |
| `oid` | Opportunity id |
| `quote_number` | Quote number |
| `line_no` | Line number in the quote |
| `seq` | Order of the component within the line (not a version) |
| `editor` | Editor (display only) |
| `sku` | SKU (display only) |
| `component` | NET, LIST, DISCOUNT, FEE, USAGE_RATE ... |
| `discount_type` | STANDARD, PARTNER, PROGRAM, VOLUME, OTHER ... |
| `basis` | UNIT, EXTENDED or PERCENT |
| `price_period` | TERM, MONTHLY, ONE_TIME ... |
| `schedule_label` | Schedule label (Year 1, Year 2 ...) |
| `period_start` / `period_end` | Period of the component (multi-year lines) |
| `printed_label` | Label as printed on the quote |
| `currency` | Currency |
| `quantity` | Quantity |
| `amount` | Component amount, line currency (a % when basis = PERCENT) |
| `pct` | Component percentage |
| `amount_eur` | Component amount in EUR; NULL when basis = PERCENT |

### `fact_payment_schedule`
**Grain: one row per payment instalment of a quote** (quote_key x seq).

| Column | Description |
|---|---|
| `quote_key` | Quote key; joins to `fact_quotes` |
| `oid` | Opportunity id |
| `quote_number` | Quote number |
| `editor` | Editor (display only) |
| `seq` | Instalment number |
| `label` | Instalment label as printed |
| `due_date` | Due date |
| `period_start` / `period_end` | Period paid by the instalment |
| `currency` | Currency |
| `amount` | Instalment amount, quote currency |
| `amount_eur` | Instalment amount in EUR |

## Tests (dbt)

| Model | Tests |
|---|---|
| `dim_supplier`, `dim_editor`, `dim_sku`, `dim_customer` | key `unique` + `not_null` |
| `dim_supplier_editor` | `supplier`, `editor` `not_null` |
| `fact_quotes` | `quote_key` `unique` + `not_null` |
| `fact_quote_lines` | `quote_line_key` `unique` + `not_null`; `quote_key` exists in `fact_quotes` |
| `fact_line_prices` | `quote_line_key` `not_null` and exists in `fact_quote_lines` |
| `fact_payment_schedule` | `quote_key` `not_null` |

Run: `dbt build -s "uc5_srm_*"` inside `dbt_demokit_pro/`.
