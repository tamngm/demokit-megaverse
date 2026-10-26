# Data platform reference

## S3 (bucket `offy-bi-demo`)
| Path | Contents |
|---|---|
| `data/offybi/<dataset>/raw/` | raw files uploaded by the team |
| `data/offybi/<dataset>/staging/` | legacy cleaned parquet from the removed Python transformer (uc1 only) |
| `data/offybi/retail_kit/<table>/` | uc2 raw CSVs, one folder per table |
| `data/offybi_mart/<model>/` | dbt mart tables |
| `athena_results/` | Athena query output |

An Athena `LOCATION` is always a folder of files with one schema, never a single file.

## Raw table DDL (`src/loader/load_config/*.sql`)
- One or more `;`-separated statements per file. `create_athena_tbl.py` runs them one by one (Athena runs one statement per query), so no `;` inside string literals.
- `CREATE ... IF NOT EXISTS` skips existing tables: a changed DDL needs `DROP TABLE IF EXISTS` first (S3 data is kept). `uc2_retail_kit.sql` starts with such drops.
- CSV tables: `LazySimpleSerDe`, `'skip.header.line.count'='1'`. A value that doesn't fit its type (`date` needs `yyyy-MM-dd`, `int` rejects `12.0`) silently becomes NULL.
- `uc1_zara_product_sales_raw` reads Parquet **by position** (`parquet.column.index.access`) because the raw headers contain spaces; keep its column order in sync with the file.

## dbt (`dbt_demokit_pro`, run commands inside this folder)
| Layer | Folder | Athena database | Notes |
|---|---|---|---|
| sources | `models/sources.yml` | `offybi` | source name = use case |
| work | `models/work/<uc>/` | `offybi_offybi` (project `+schema: offybi` is prefixed) | uc1: `uc1_za_product_sales_stg` (view). uc2: `rtl_orders_wk` (Parquet table, partitioned by `order_month`, partition column last) |
| mart | `models/mart/<uc>/` | `offybi_mart` | one `.sql` per model + one shared `<uc>.yml` |
| seeds | `seeds/` | `offybi` | `rtl_order_status_map.csv`: order_status → status_group, is_final, sort_order, delivery_result |

- uc1 mart reads `ref('uc1_za_product_sales_stg')`.
- uc2 mart: `dim_rtl_*` and `fact_rtl_sales` / `fact_rtl_ecom_behave` are views on `source()` with `<date>_clean` columns. Orders go through `rtl_orders_wk` → `fact_rtl_orders_header` (1 row per order, joins the status seed) and `fact_rtl_orders_daily`.
- Run order for orders: `dbt seed -s rtl_order_status_map` → `dbt run -s rtl_orders_wk+` → `dbt test -s fact_rtl_orders_header`.

## Python and credentials
- `src/` holds only `config.py` and the loader. `create_athena_tbl.py` (the only entry point) adds `src/` to `sys.path` for `import config`.
- Python reads AWS keys and `ATHENA_*` settings from `.env` via `src/config.py`. dbt uses the AWS CLI profile `aws_demokit_pro` (`eu-west-1`).

## Known issues
- `logs/dbt.log` is committed although generated.
- The `uc1_zara_product_sales_stg` source in `sources.yml` is unused.
- `.sqlfluff` `profiles_dir` points to an old local path; fix it before `sqlfluff lint`.
- `order_item_total` is `int` in the uc2 DDL; decimal values would become NULL.
