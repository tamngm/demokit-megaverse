# Supplier relationship management (uc5): business context

What this dataset is, the business concepts behind it, and how to read it correctly.
For every table and column, see [data_dictionary.md](data_dictionary.md).

## 1. What the dataset is

A **knowledge base of supplier quotes**: every quote, order form and purchase order received from (or sent to)
suppliers of software, hardware and services, extracted from the original documents (PDF, Excel, e-mails) into
one workbook, `pulse_sku_kb.xlsx`.

It answers one need from the client: **document the history of each supplier relationship**, so that before the
next transaction anyone can quickly see who the supplier is, what was bought through them, at what price and
discount, on which payment terms, and what is coming up next.

| Scale (masked demo data) | |
|---|---|
| Quotes | 56 with a quote number (59 in the source) |
| Quote lines | 420 (450 in the source) |
| Projects (`oid`) | about 45 |
| Suppliers / editors | 17 / 13 |
| SKUs | 200 in the SKU list, plus a few found only in quote lines |

### Masked values

The data in this repo and in Athena is **masked**: it keeps the structure and the links between tables, but not
the real values. Masking is done by `src/tool/mask_dataset.py` (rules in the workbook's data dictionary,
key in `.env`):

- codes and ids (`oid`, `quote_number`, SKUs ...) are replaced part by part: the same value always gets the same
  mask, so joins between tables still work;
- supplier, customer and contact names are replaced by realistic fake names;
- all amounts are multiplied by one secret factor: totals, sums and discount % stay consistent;
- all dates are shifted by one secret number of days: durations and order stay correct;
- editors (Cisco, Check Point, Palo Alto Networks ...) are public vendors and are kept as they are.

The original workbook never leaves OneDrive.

## 2. Key business concepts

| Concept | Meaning |
|---|---|
| **Editor** | The vendor who makes the product (Cisco, Check Point, Splunk ...). |
| **Supplier** | The company that quotes and sells it to us. It can be the editor itself or a reseller. |
| **Supplier type** | `vendor_direct` (the editor sells directly), `distributor` (Arrow, Ingram ...), `service_provider`, `internal_affiliate`. |
| **Supplier x editor** | Which supplier can sell which editor: the "route to market". One editor can be bought through several suppliers, on different terms. |
| **Project (`oid`)** | An opportunity. One project can have several documents: quotes, revisions, then the order form and purchase order. |
| **Quote (`quote_number`)** | One commercial document of a project. `doc_type` says which kind (quote, order_form, order_confirmation, purchase_order ...), `revision` its version. |
| **Direction** | `BUY`: a supplier quotes us. `SELL`: we quote our customer. |
| **End customer** | The customer the purchase is for. |
| **SKU** | The product code of the editor (licence, appliance, support, service ...). |
| **List / net price** | List = catalogue price before discount. Net = price actually quoted after all discounts. |

A project usually goes: **quote → revised quote(s) → order form / order confirmation → purchase order**.
Comparing the documents of one `oid` shows how the deal was negotiated.

## 3. The tables and how they fit together

```
                      dim_supplier   dim_customer   dim_editor
                              \           |           /
                               v          v          v
                              fact_quotes (1 row per quote)
                               /          |           \
                              v           v            v
            fact_payment_schedule   fact_quote_lines    (adjustments: tax, freight,
            (1 row per instalment)  (1 row per line)     one-time discount -> on the quote)
                                          |      ^
                                          v      |
                                fact_line_prices  dim_sku
                                (1 row per price component of a line)
```

| Table | One row per | Business question |
|---|---|---|
| `fact_quotes` | quote | What was quoted, when, by whom, for whom, total value, terms |
| `fact_quote_lines` | line of a quote | What was bought: SKU, quantity, unit price, discount, line total |
| `fact_line_prices` | price component of a line | How the price and the discount of a line are built |
| `fact_payment_schedule` | payment instalment | When and how much we pay |
| `dim_supplier_editor` | supplier x editor | Who sells what (route to market) |

## 4. Quote lines vs line prices

Both describe the **same lines**, at two levels of detail: **`quote_lines` gives the result, `line_prices` shows
how that result was calculated**.

| | `fact_quote_lines` | `fact_line_prices` |
|---|---|---|
| Grain | **1 row per line** | **N rows per line**, one per price element (about 4 per line) |
| Pricing | The summary: unit list price, unit net price, **total discount %**, line totals | The pieces: list, **each discount by type**, fees, usage rates, net, **per year** |
| Answers | "What did this line cost, and what discount did we get overall?" | "Where did that discount come from, and how is the price spread over the years?" |

Example for one line (illustrative numbers):

```
quote_lines   ->  1 row:  list 1,000 | net 609 | discount 39.1% | total 6,090

line_prices   ->  6 rows: LIST 1,000
                          DISCOUNT standard 30%
                          DISCOUNT partner  13%     <- 1,000 x 0.70 x 0.87 = 609
                          NET unit 609
                          NET Year 1  6,090
                          NET Year 2  6,455         <- yearly uplift
```

Like a receipt: `quote_lines` is the line on the receipt, `line_prices` is the calculation behind it.

### What line prices tell you, and what they don't

- **The "how", fully**: which discounts were applied, how big each one is, and on which base (`basis`: unit,
  extended total or percentage). The path from list price to net price can be rebuilt step by step.
- **The "why", as far as the discount type says it**:

  | `discount_type` | Commercial reason |
  |---|---|
  | STANDARD | the vendor's usual discount for everyone |
  | PARTNER | our partner level with the vendor |
  | PROGRAM | a vendor program or promotion |
  | VOLUME | the quantity bought |
  | TERM | the commitment length (multi-year) |
  | NEW_LOGO | a first deal with a new customer |
  | PAYMENT_INCENTIVE | paying upfront or early |
  | ADDITIONAL / OTHER | extra, deal-specific concessions |

- **Not in the data**: the negotiation behind a discount (who asked, competing offers ...).
- **Not every line has a breakdown**: when the document only printed the net price, the line has no discount
  components.
- **Discounts may stack or add up** (1,000 x 0.70 x 0.87, or 30% + 13%) depending on the vendor's quote format:
  check a few quotes before showing a "total by discount type".
- `seq` is the order of the components inside a line, **not a version over time**. The only time split inside
  `line_prices` is the yearly schedule of multi-year lines (`schedule_label`, `period_start`, `period_end`).

### Where the price history lives

History is found **across quotes**, not inside `line_prices`:

- **same project over time**: the quotes of one `oid` (revisions, then order form, then purchase order);
- **same product over time**: the `unit_net_price` of one SKU across all quotes and suppliers in `fact_quote_lines`.

The source also has a `Price_Matrix` tab: the same information as line prices, one wide row per line
(`disc_standard`, `disc_partner`, `net_year_1` ...). It is loaded as a raw table but not used by the models.

## 5. Questions the dataset answers

1. **Relationship**: who are our key suppliers, direct or distributor, since when, growing or fading?
2. **Route to market**: for an editor, which suppliers can we buy from, and who gives the best discount?
3. **Deal history**: for a project, how many quotes and revisions, how it moved to an order, how the value changed.
4. **Price and discount**: usual discount per supplier, editor and product type; what we paid last time for a SKU.
5. **Payment and contracts**: usual payment terms and billing frequency, payments due soon, contracts ending soon.
6. **Customers**: which end customers we buy for, and through which suppliers.

## 6. Data quality and modelling choices

| Topic | In the source | What the models do |
|---|---|---|
| Missing quote number | 3 quotes, 27 lines, 4 price components have an empty `quote_number` | Left out of every fact (`NULLIF(trim(quote_number), '') IS NOT NULL`); kept in the raw tables for a later data-quality review |
| Empty text | Empty cells are stored as `''`, not NULL, in the Parquet files | Filters use `NULLIF(trim(col), '')` |
| Exact duplicate rows | One quote and its lines appear twice | Every model starts from `SELECT DISTINCT` |
| One quote repeated with small differences | 1 quote | Merged into one row in `fact_quotes`; `document_count` = 2 |
| SKUs missing from the SKU list | A few SKUs appear only in quote lines | Added to `dim_sku` with `is_from_lines_only = true` |
| Currencies | EUR and USD | Converted to EUR with one rate per currency from the `ref_exchange_rates` seed (not the rate of the quote date) |
| Declared vs actual lines | `lines` on the quote does not always match the lines found | Both kept: `line_count_declared` and `line_count` |

## 7. Where things are

| What | Where |
|---|---|
| Source workbook (original, not masked) | OneDrive `OCD\supplier\pulse_sku_kb.xlsx` |
| Split + masking tools | `src/tool/split_excel_tab_to_csv.py`, `src/tool/mask_dataset.py` |
| Masked Parquet in S3 | `s3://offy-bi-demo/data/offybi/supplier_relation/<table>/` |
| Raw tables DDL | `src/loader/load_config/uc5_supplier_relation_raw.sql` (Athena `offybi.uc5_srm_*`) |
| dbt models | `dbt_demokit_pro/models/work/uc5_supplier_relation/`, `dbt_demokit_pro/models/mart/uc5_supplier_relation/` (Athena `offybi_mart`) |
| Column descriptions (source of truth) | `uc5_supplier_relation.yml`, synced to Power BI with `src/tool/sync_dbt_descriptions_to_pbi.py` |
| Power BI | `fabricspace/supplier_relation/` |
