# Data platform reference

## S3 (bucket `offy-bi-demo`)
| Path | Contents |
|---|---|
| `data/offybi/<dataset>/raw/` | raw files uploaded by the team |
| `data/offybi/<dataset>/staging/` | legacy cleaned parquet from the removed Python transformer (uc1 only) |
| `data/offybi/retail_fashion/<table>/` | uc3 raw Parquet, one folder per table (`transactions_monthly/<YYYY-MM-01>/` per month) |
| `data/offybi_mart/<model>/` | dbt mart tables |
| `athena_results/` | Athena query output |

An Athena `LOCATION` is always a folder of files with one schema, never a single file.

## Raw table DDL (`src/loader/load_config/*.sql`)
- One or more `;`-separated statements per file. `create_athena_tbl.py` runs them one by one (Athena runs one statement per query), so no `;` inside string literals.
- `CREATE ... IF NOT EXISTS` skips existing tables: a changed DDL needs `DROP TABLE IF EXISTS` first (S3 data is kept). `uc3_retail_fashion_kit.sql` starts with such drops.
- CSV tables: `LazySimpleSerDe`, `'skip.header.line.count'='1'`. A value that doesn't fit its type (`date` needs `yyyy-MM-dd`, `int` rejects `12.0`) silently becomes NULL.
- `uc1_zara_product_sales_raw` reads Parquet **by position** (`parquet.column.index.access`) because the raw headers contain spaces; keep its column order in sync with the file.

## dbt (`dbt_demokit_pro`, run commands inside this folder)
| Layer | Folder | Athena database | Notes |
|---|---|---|---|
| sources | `models/sources.yml` | `offybi` | source name = use case |
| work | `models/work/<uc>/` | `offybi_work` (project `+schema: offybi` is prefixed) | uc1: `uc1_za_product_sales_stg` (view). uc3: `uc3_rtl_fsh_transactions_wk` (incremental Parquet table, partitioned by `business_month`, partition column last), `uc3_rtl_fsh_products_wk` (view) |
| mart | `models/mart/<uc>/` | `offybi_mart` | one `.sql` per model + one shared `<uc>.yml` |
| seeds | `seeds/` | `offybi` | `ref_*.csv`: calendar, time, exchange rates, color codes |

- uc1 mart reads `ref('uc1_za_product_sales_stg')`.
- uc3 mart: `uc3_dim_rtl_fsh_*` and `uc3_fact_rtl_fsh_*` read the two uc3 work models or `source('uc3_retail_fashion', ...)`; amounts are converted to EUR with the `ref_exchange_rates` seed.
- uc5 mart (`models/mart/uc5_supplier_relation/`): `uc5_srm_dim_*` / `uc5_srm_fact_*` read `source('uc5_supplier_relation', ...)` (masked supplier quotes); the supplier, editor and supplier x editor dims read the work model `uc5_srm_supplier_editor_wk` (supplier list full-joined with the pairs in quote lines). Facts link on `quote_key` (`hash_key('oid', 'quote_number')`, macro in `macros/parsing/hash_key.sql`); every model starts with `SELECT DISTINCT` because the source has exact duplicate rows.

## Python and credentials
- `src/` holds only `config.py` and the loader. `create_athena_tbl.py` (the only entry point) adds `src/` to `sys.path` for `import config`.
- Python reads AWS keys and `ATHENA_*` settings from `.env` via `src/config.py`. dbt uses the AWS CLI profile `aws_demokit_pro` (`eu-west-1`).

## Known issues
- `logs/dbt.log` is committed although generated.
- The `uc1_zara_product_sales_stg` source in `sources.yml` is unused.
- `.sqlfluff` `profiles_dir` points to an old local path; fix it before `sqlfluff lint`.
