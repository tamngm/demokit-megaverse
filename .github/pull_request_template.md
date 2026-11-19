## What and why

<!-- One or two lines: which use case, what changed, why. -->

## Checklist

Checked automatically by `pipeline-checks` (a red ❌ in the Checks tab shows which rule failed):

- [ ] Branch `feat/<uc>-<desc>`, `fix/<desc>` or `docs/<desc>`, no commit on `main`
- [ ] No raw data or secrets committed (no `.env`, `.parquet`, `.xlsx`, CSV outside `seeds/`)
- [ ] DDL in `src/loader/load_config/<uc>_*.sql`, every table dropped before it is created
- [ ] Every new raw table in `models/sources.yml`
- [ ] Work models in `models/work/<uc>/`, listed in a `.yml`
- [ ] Dims and facts in `models/mart/<uc>/`, every column described in `<uc>_*.yml`
- [ ] Seeds named `ref_*.csv`
- [ ] `dbt parse` passes

Manual (tick when done):

- [ ] Sampling notebook in `notebook/` has no raw data output or credentials
- [ ] `dbt seed` / `dbt run` done for the changed models, results checked in Athena (row counts, NULL keys, totals)
- [ ] Power BI report refreshed, if the change affects it
