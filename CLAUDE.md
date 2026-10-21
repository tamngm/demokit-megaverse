# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Retail Megaverse is a demo kit for retail analytics. The stack: raw data in S3, schema-on-read with Athena, dbt models into a mart, and Power BI reports. Work is organized by **use case**, and every artifact carries the use-case prefix: `uc1_zara_sales` (Zara promotional uplift), `uc2_retail_kit`, and so on.

## Core Workflow Rules

**Plan first, execute only after approval.** For any task that changes files, runs scripts, touches AWS (S3, Athena, dbt runs) or runs git commands that write:

1. **Investigate.** Read the relevant code and config. Read-only commands are fine.
2. **Present a plan** and stop:
   - the files to create or change, with the key code or SQL snippets
   - the commands you will run, and what they affect (local files, S3, Athena, git remote)
   - risks, assumptions and open questions
3. **Wait for review.** Execute only after the user explicitly approves the final plan (e.g. "approved", "go", "execute"). Feedback or questions mean: revise the plan and present it again. Don't execute yet.
4. **Execute exactly the approved plan.** If something unexpected comes up mid-execution, such as a failing command or a needed change outside the plan, stop and report instead of improvising.
5. **Report** what was done, what was verified, and anything skipped or failed.

If a request ends with **"SUGGEST"**, give the suggestion only. Never execute, even partially.

## Working conventions

- Never push to `main`. Use one branch per logical change, following [git-how-to.md](git-how-to.md):
  - branch names: `feat/<uc>-<short-desc>`, `fix/<short-desc>`, `docs/<short-desc>` (lowercase, `-`-separated)
  - commit and PR titles: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- Platform: Windows with PowerShell. Use `.venv\Scripts\python.exe`, and quote stash refs (`'stash@{0}'`).

## Commands

```powershell
# setup (uv)
uv venv
uv pip install -r requirements.txt

# Create Athena raw tables from a DDL file in src/loader/load_config/ (filename arg is required)
.venv\Scripts\python.exe src\loader\create_athena_tbl.py uc2_retail_kit.sql
```

Run dbt from inside `dbt_demokit_pro/`, where `profiles.yml` lives:

```powershell
cd dbt_demokit_pro
dbt debug                      # verify Athena connection
dbt run                        # build all models
dbt run -s uc1_fact_sales      # single model
dbt test -s uc1_dim_season     # tests for a single model
dbt run -s path:models/work/uc1_zara_sales   # one use-case work (stg) folder
dbt run -s path:models/mart/uc1_zara_sales   # one use-case mart folder
```

There is no Python test suite. dbt tests are declared in each model's `.yml` file. `.sqlfluff` is configured with the dbt templater and the athena dialect, but its `profiles_dir` points to an old local path. Fix that path before running `sqlfluff lint`.

## Architecture

**Data flow:**

1. **S3 raw:** the team uploads raw files to S3 directly. The repo has no extraction or upload code, and none should be added.
2. **Athena raw tables:** `src/loader/create_athena_tbl.py` + `load_config/*.sql` register the S3 folders as external tables in database `offybi`.
3. **dbt (`dbt_demokit_pro`):** all transformation happens here, not in Python. Work (stg) models clean the raw `source()`s; mart models build dim and fact tables from them.
4. **Power BI (`fabricspace/`):** `.pbip` projects on top of the mart.

**S3 layout:** bucket `offy-bi-demo`.

| Path | Contents |
|---|---|
| `data/offybi/<dataset>/raw/` | raw data uploaded by the team |
| `data/offybi/<dataset>/staging/` | legacy cleaned data written by the removed Python transformer (uc1 only) |
| `data/offybi/retail_kit/<table>/` | one folder per table |
| `data/offybi_mart/<model>/` | final usage data |
| `athena_results/` | Athena query output |

An Athena `LOCATION` is always a **folder** containing files with a single schema, never a single file.

**Raw table DDL (`src/loader/load_config/`):**
- Each file holds one or more `CREATE EXTERNAL TABLE IF NOT EXISTS offybi.<table>` statements separated by `;`. Athena runs only one statement per query, so `create_athena_tbl.py` splits on `;` and runs each statement in turn. Don't put `;` inside string literals.
- CSV tables use `LazySimpleSerDe` with `'skip.header.line.count'='1'`.
- Values that don't fit a typed column (e.g. `date` needs `yyyy-MM-dd`, `int` rejects `12.0`) silently become NULL instead of failing.
- `IF NOT EXISTS` means a changed DDL has no effect until you `DROP TABLE` the old one. Dropping doesn't delete the S3 data.

**dbt:**
- Each new raw table must be registered in `models/sources.yml` (source name = use case, schema `offybi`) before models can `source()` it.
- **Work (stg) models** live in `models/work/<use_case>/` and are named `<uc>_<short-name>_stg`, e.g. `uc1_za_product_sales_stg`. They are views, with one `.yml` per model.
  - `uc1_za_product_sales_stg` reads `uc1_zara_product_sales_raw`.
  - That raw DDL reads Parquet columns **by position** (`parquet.column.index.access`), because the raw headers contain spaces.
- **Mart models** live in `models/mart/<use_case>/`: one `.sql` per model, plus **one** shared `<use_case>.yml` (e.g. `uc1_zara_sales.yml`) for all of the folder's models. They use `schema='mart'` and `materialized='table'`.
  - Mart models read work models with `ref()`, never raw `source()`s.
  - dbt-athena prefixes a custom schema with the target schema, so the mart lands in the Athena database `offybi_mart`.

**Imports and config:**
- `src/` holds only `config.py` and the loader. `create_athena_tbl.py` is the only Python entry point, and it adds `src/` to `sys.path` so that `import config` works.
- There are two separate credential paths:
  - **Python:** reads AWS keys and `ATHENA_*` settings from `.env` through `src/config.py`.
  - **dbt:** uses the AWS CLI profile `aws_demokit_pro` from `~/.aws/credentials`, region `eu-west-1`.

## Known issues

- `logs/dbt.log` is committed even though it's a generated file.
- The `work:` block in `dbt_project.yml` sets `+schema: offybi`, so work views land in `offybi_offybi` rather than `offybi`.
- The `uc1_zara_product_sales_stg` source in `sources.yml` (legacy S3 staging parquet) is no longer used by any model.
