# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Retail analytics demo: team uploads raw files to S3 → Athena raw tables (`src/loader`) → dbt (`dbt_demokit_pro`) → Power BI (`fabricspace/`). Every artifact carries its use-case prefix (`uc1_zara_sales`, `uc2_retail_kit`). Windows + PowerShell; use `.venv\Scripts\python.exe`.

## Rules that matter most
- **Plan first.** Sessions start in plan mode (`.claude/settings.json`). Present files, commands and risks; change nothing until the user says "approved"/"go"/"execute". A request ending in "SUGGEST" never executes.
- **Secrets never leave `.env` / `~/.aws/credentials`.** Enforced by `.claude/hooks/guard.py`. To see which settings exist, read `src/config.py`, not `.env`.

## Rules (check → instead)
- Raw CSV date columns → declare `string` in the DDL; parse in dbt with `try(date_parse(split_part(trim(col),' ',1),'%m/%d/%Y'))`.
- Joining on text keys → `lower()` both sides; never normalize case on one side only.
- New raw table → DDL in `src/loader/load_config/<uc>_*.sql` AND an entry in `models/sources.yml`, in the same change.
- Deleting or renaming a model → remove or rename its block in the folder's shared `.yml` in the same change.
- uc2 files go in `models/*/uc2_retail_kit/`, uc1 files in `models/*/uc1_zara_sales/`; never nest one use case inside another.
- Flags from dates (`is_late`, …) → return NULL when an input date is NULL, not 0.
- Checking dbt changes → `dbt parse` (local). `dbt run` / `dbt seed` / the loader touch Athena and S3: the user runs them, or they need explicit approval.
- Git: branches `feat/<uc>-<desc>`, `fix/<desc>`, `docs/<desc>`; never commit to `main` (blocked by hook). Team git steps: `git-how-to.md`.

## Commands
- Create raw tables: `.venv\Scripts\python.exe src\loader\create_athena_tbl.py <file.sql>` (the file's `DROP` lines recreate tables)
- dbt (run inside `dbt_demokit_pro/`): `dbt parse` · `dbt seed -s <seed>` · `dbt run -s <model>+` · `dbt test -s <model>`

## Reference
@.claude/docs/data-platform.md

## Corrections log
When Claude gets something wrong, add a rule above (what to check → what to do instead) and one line here.
- 2026-10: status join failed (case changed on one side only) → "lower() both sides" rule.
