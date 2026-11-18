# Go with the pipeline: onboard a new dataset

This guide takes a dataset from an external source (Kaggle, open data, a client extract) to dim/fact tables that Power BI can use. Follow the steps in order. `uc3_retail_fashion` is the worked example throughout; copy its files when you start a new use case.

```
 Kaggle / external source
          |  1. download
          v
 local raw files ---- 2. sample in a notebook ----> sample CSVs
                                                        |  upload by hand
                                                        v
                                         SharePoint  raw_data/<domain>/
                                                        |  3. convert_csv_to_parquet.py
                                                        v
                         S3  s3://offy-bi-demo/data/offybi/<dataset>/<table>/*.parquet
                                                        |  4. DDL + create_athena_tbl.py
                                                        v
                         Athena  offybi.<uc>_*            (raw tables)
                                                        |  5. dbt_demokit_pro
                                                        v
                         offybi_work.*  -->  offybi_mart.<uc>_dim_* / <uc>_fact_*
                                                        |  7.
                                                        v
                                                    Power BI
```

## 0. Before you start

- **Environment**: run `uv venv`, then `uv pip install -r requirements.txt`. Always call Python as `.venv\Scripts\python.exe`.
- **`.env`** at the repo root. `src/config.py` lists every key: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `ATHENA_DATABASE`, `ATHENA_OUTPUT_LOCATION`, `ATHENA_WORKGROUP`, `S3_BUCKET_NAME`, `MS_TENANT_ID`, `MS_CLIENT_ID`, `SP_SITE_URL`. Never commit `.env` and never paste its values into code, notebooks or chat.
- **dbt** uses the AWS CLI profile `aws_demokit_pro` (region `eu-west-1`) in `~/.aws/credentials`.
- **Pick a use-case prefix**: the next free number plus a short name, e.g. `uc4_<name>`. Every file, folder, table and model for the dataset carries it.
- **Create a branch**: `feat/<uc>-<desc>` (e.g. `feat/uc4-customer-reviews`). Never commit to `main`. See [git-how-to.md](../git-how-to.md).

## 1. Download the raw data

Download the files by hand from Kaggle or the external source. Keep them outside the repo: raw files are not committed.

Note down the source URL, the licence and what each file contains. You will reuse this in the DDL comments (step 4) and in `sources.yml` (step 5A).

## 2. Cut the data to a sample

Demo datasets do not need millions of rows. A few thousand rows per table keeps S3, Athena and dbt runs fast and cheap.

1. Create a one-off notebook in `notebook/`, named `sample_<uc>_<dataset>.ipynb`.
2. Load each raw file, keep a sample, and export it as CSV (one CSV per table).
3. Keep the tables consistent with each other: sample the **fact** table first (e.g. transactions), then keep only the dimension rows it references (customers, products, stores...). Random sampling of every table separately breaks the joins.
4. For a large fact table that you want to load per period, split it into one file per period and name each file `<table>_YYYY-MM-DD.csv` (e.g. `transactions_monthly_2023-01-01.csv`). Step 3 turns that date suffix into an S3 subfolder, which Athena reads as a partition.
5. Upload the CSVs to SharePoint, in one folder per data domain, e.g. `raw_data/retail_kit_v3` for uc3.

## 3. Convert to Parquet and upload to S3

[src/loader/convert_csv_to_parquet.py](../src/loader/convert_csv_to_parquet.py) reads every CSV in a SharePoint folder and writes it to S3 as Parquet.

```powershell
# 1. preview: list the files that are not in S3 yet, upload nothing
.venv\Scripts\python.exe src\loader\convert_csv_to_parquet.py --sp-folder "raw_data/<domain>" --s3-prefix data/offybi/<dataset> --dry-run
# 2. upload
.venv\Scripts\python.exe src\loader\convert_csv_to_parquet.py --sp-folder "raw_data/<domain>" --s3-prefix data/offybi/<dataset>
```

What it does:

- **Sign-in**: the first call prints a link and a code; sign in with your Microsoft account in the browser. The token is reused for the rest of the run.
- **Column names** are converted to snake_case: `Invoice ID` becomes `invoice_id`.
- **One folder per file**, so one folder per Athena table:
  - `customers.csv` goes to `data/offybi/<dataset>/customers/customers.parquet`
  - `transactions_monthly_2023-01-01.csv` goes to `data/offybi/<dataset>/transactions_monthly/2023-01-01/transactions_monthly_2023-01-01.parquet`
- **Re-runs are safe**: files already in S3 are skipped, so a re-run only uploads new files. To replace a file, delete it in S3 first.
- One failed file does not stop the run; the failures are listed at the end and the exit code is 1.

Column types are inferred from the CSV. Check them before you write the DDL (open the Parquet in a notebook, or look at the inferred types in the run log).

## 4. Create the raw tables in Athena

Write one DDL file per use case in [src/loader/load_config/](../src/loader/load_config/), named `<uc>_<dataset>.sql`. Example: [uc3_retail_fashion_kit.sql](../src/loader/load_config/uc3_retail_fashion_kit.sql).

```powershell
.venv\Scripts\python.exe src\loader\create_athena_tbl.py <uc>_<dataset>.sql
```

The tables are created in the Athena database `offybi`, named `<uc>_<short>_<table>` (e.g. `uc3_rtl_fsh_customers`).

Rules for the DDL file:

- **Start with `DROP TABLE IF EXISTS`** for every table. `CREATE ... IF NOT EXISTS` silently skips a table that already exists, so without the drop your changes are ignored. Dropping an external table keeps the S3 data.
- **`LOCATION` is a folder**, never a single file: `s3://offy-bi-demo/data/offybi/<dataset>/<table>/`.
- **Column names and order must match the Parquet file** (the snake_case names from step 3). Add a `COMMENT` per column with the meaning from the source documentation.
- **Types must fit the data.** A value that does not fit its type silently becomes NULL: an `int` column rejects `12.0`, a `date` column needs `yyyy-MM-dd`. When unsure, declare `string` and convert in dbt (for a date: `try(date_parse(split_part(trim(col),' ',1),'%m/%d/%Y'))`).
- **No `;` inside strings or comments**: the script splits the file on `;` and runs one statement at a time.
- **Partitioned tables** (one subfolder per period): use partition projection, as for `uc3_rtl_fsh_transactions`. Athena then finds new period folders without a repair command.

Check in the Athena console: `SELECT * FROM offybi.<table> LIMIT 10`. A column that is entirely NULL usually means a wrong type or a wrong column order.

## 5. Transform with dbt (`dbt_demokit_pro`)

Run every dbt command inside the `dbt_demokit_pro/` folder.

| Layer | Folder | Athena database | Naming |
|---|---|---|---|
| Sources (raw tables from step 4) | `models/sources.yml` | `offybi` | source name = use case, e.g. `uc3_retail_fashion` |
| Work | `models/work/<uc>/` | `offybi_work` | `<uc>_<short>_<table>_wk` |
| Mart | `models/mart/<uc>/` | `offybi_mart` | `<uc>_dim_<short>_<entity>`, `<uc>_fact_<short>_<subject>` |
| Seeds | `seeds/` | `offybi` | `ref_<name>` |

Keep each use case in its own folder; never put one use case inside another's folder.

### 5A. Declare the raw tables in `sources.yml`

Add a source block to [models/sources.yml](../dbt_demokit_pro/models/sources.yml) in the same change as the DDL file:

```yaml
  - name: uc4_<name>
    description: "What the dataset is, where it comes from, S3 path"
    schema: offybi
    tables:
      - name: uc4_<short>_<table>
        description: "One line per table"
```

Models then read it with `{{ source('uc4_<name>', 'uc4_<short>_<table>') }}`.

### 5B. Work tables (only when needed)

Create `models/work/<uc>/` when the raw data needs heavy work before it can feed several marts: cleaning, type conversion, pivot/unpivot, deduplication, currency conversion, enrichment. Example: [uc3_rtl_fsh_transactions_wk.sql](../dbt_demokit_pro/models/work/uc3_retail_fashion/uc3_rtl_fsh_transactions_wk.sql).

- Work models are views by default. For a big fact table, use an incremental Parquet table partitioned by a date column. The partition column must be the **last** column in the `SELECT`.
- Clean once here and reuse the macros in `macros/parsing/`: `clean_decimal`, `clean_string`, `fill_null_value`, `age_range`.
- Add a `<uc>_<short>.yml` with one description per model.

If the raw table is already clean, skip this layer and build the marts on the source.

### 5C. Dim and fact tables for BI

Create `models/mart/<uc>/` with one `.sql` per model, built on `source()` (5A) or `ref()` (5B). Example: [models/mart/uc3_retail_fashion/](../dbt_demokit_pro/models/mart/uc3_retail_fashion/).

- **Dims**: one row per key (customer, product, store...). Business attributes, groupings, segments.
- **Facts**: measures at a clear grain (line, day x store, month x sku...). Write the grain at the top of the file.
- **Joins on text keys**: apply `lower()` (or `upper(trim())`) to **both** sides.
- **Flags from dates** (`is_late`...): return NULL when an input date is NULL, not 0.
- **Distinct counts** (`invoice_count`, `customer_count`) cannot be summed across rows. Say so in the column description.

Add one shared `<uc>_<dataset>.yml` in the same folder, listing **every column with a description** for each dim and fact. Example: [uc3_retail_fashion.yml](../dbt_demokit_pro/models/mart/uc3_retail_fashion/uc3_retail_fashion.yml). These descriptions are what report builders read. Sources (5A) and work models (5B) only need a model description.

When you rename or delete a model, rename or remove its block in the `.yml` in the same change.

### 5D. Static reference data: seeds

For small static mapping or lookup tables (exchange rates, color codes, status mapping, calendar), add a CSV to [seeds/](../dbt_demokit_pro/seeds/) named `ref_<name>.csv` and read it with `{{ ref('ref_<name>') }}`.

```powershell
dbt seed -s ref_<name>
```

A seed is for data that people maintain by hand and that changes rarely. Data that comes from a source system goes through steps 3 and 4 instead.

## 6. Run everything and check

```powershell
cd dbt_demokit_pro
dbt parse                        # local only: checks Jinja, refs, sources and yml
dbt seed -s ref_<name>           # only if you added or changed a seed
dbt run -s <uc>_*                # or a model and everything after it: dbt run -s <model>+
dbt test -s <uc>_*               # if the models have tests
```

- `dbt parse` touches nothing in AWS. Run it after every change.
- `dbt run`, `dbt seed` and the loader scripts write to Athena and S3.
- If a dbt command fails with `'charmap' codec can't decode byte ...`, a project file contains non-ASCII characters. Run `$env:PYTHONUTF8 = '1'` in the terminal first.
- Check the mart tables in Athena: row counts, NULL keys, and a few totals compared with the source.

## 7. Machine learning and AI enrichment

Some analyses need Python rather than SQL: sentiment on customer reviews, topic detection on social listening content, clustering, forecasting. Keep the same flow, so dbt and Power BI treat the output like any other raw table:

1. Write a Python script in `src/` (e.g. `src/ml/<uc>_<task>.py`) that reads its input from Athena or S3 and computes the result.
2. Write the result as Parquet to its own folder: `s3://offy-bi-demo/data/offybi/<dataset>/<result_table>/`.
3. Add the table to the use case's DDL file (step 4) and to `sources.yml` (step 5A).
4. Join it in the marts (step 5C) like any other source.

Read credentials through `src/config.py`, never hard-coded. Write the model version or run date into the output table, so you can tell which run produced each row.

## 8. Power BI

Connect Power BI to the `offybi_mart` database in Athena and import only the `<uc>_dim_*` and `<uc>_fact_*` tables. Report files live in `fabricspace/`; the theme is in `theme/`.

## Checklist for the pull request

- [ ] Branch `feat/<uc>-<desc>`, no commit on `main`
- [ ] Sampling notebook in `notebook/`, no raw data or secrets in it
- [ ] DDL in `src/loader/load_config/<uc>_*.sql`, starting with `DROP TABLE IF EXISTS`
- [ ] Source block in `models/sources.yml` for every new raw table
- [ ] Work models (if any) in `models/work/<uc>/` with a `.yml`
- [ ] Dims and facts in `models/mart/<uc>/`, with every column described in `<uc>_*.yml`
- [ ] New seeds in `seeds/` named `ref_*`
- [ ] `dbt parse` passes; `dbt run` and checks done in Athena
