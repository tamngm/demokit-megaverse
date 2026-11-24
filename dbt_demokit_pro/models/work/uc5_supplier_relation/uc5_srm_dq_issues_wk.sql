-- Data quality issues found in the uc5 raw tables: one row per issue (check x record).
-- Checks are described in uc5_srm_dq_checks_wk; counts per check in uc5_srm_dq_summary_wk.
-- "Missing" text = NULL or empty: the Parquet files store empty cells as '' (NULLIF(trim(col), '')).

-- q / ql / se / sk: raw tables without exact duplicate rows
WITH q AS (
    SELECT DISTINCT * FROM {{ source('uc5_supplier_relation', 'uc5_srm_quotes') }}
)
, ql AS (
    SELECT DISTINCT * FROM {{ source('uc5_supplier_relation', 'uc5_srm_quote_lines') }}
)
, se AS (
    SELECT DISTINCT * FROM {{ source('uc5_supplier_relation', 'uc5_srm_supplier_editor') }}
)
, sk AS (
    SELECT DISTINCT * FROM {{ source('uc5_supplier_relation', 'uc5_srm_skus') }}
)
-- exr: currencies that have an exchange rate
, exr AS (
    SELECT DISTINCT lower(trim(currency_code)) AS currency_code FROM {{ ref('ref_exchange_rates') }}
)
-- quote_keys: one row per quote (oid + quote_number) with its declared line count and net total
, quote_keys AS (
    SELECT
        lower(trim(oid))           AS oid_key,
        lower(trim(quote_number))  AS qn_key,
        max(oid)                   AS oid,
        max(quote_number)          AS quote_number,
        count(*)                   AS row_count,
        max(lines)                 AS lines_declared,
        max(total_net_excl_tax)    AS total_net_excl_tax
    FROM q
    WHERE NULLIF(trim(quote_number), '') IS NOT NULL
    GROUP BY 1, 2
)
-- line_keys: lines per quote (count and net total)
, line_keys AS (
    SELECT
        lower(trim(oid))           AS oid_key,
        lower(trim(quote_number))  AS qn_key,
        count(*)                   AS lines_found,
        sum(line_total_net)        AS lines_total_net
    FROM ql
    WHERE NULLIF(trim(quote_number), '') IS NOT NULL
    GROUP BY 1, 2
)
-- issues: one SELECT per check, all with the same columns
, issues AS (
    -- C01 quote without quote number
    SELECT 'C01' AS check_id, 'quotes' AS table_name, oid, quote_number, CAST(NULL AS bigint) AS line_no,
           concat('doc_type=', coalesce(doc_type, ''), ', supplier=', coalesce(supplier, '')) AS detail
    FROM q WHERE NULLIF(trim(quote_number), '') IS NULL

    -- C02 quote without supplier
    UNION ALL
    SELECT 'C02', 'quotes', oid, quote_number, CAST(NULL AS bigint), concat('editor=', coalesce(editor, ''))
    FROM q WHERE NULLIF(trim(supplier), '') IS NULL

    -- C03 quote without editor
    UNION ALL
    SELECT 'C03', 'quotes', oid, quote_number, CAST(NULL AS bigint), concat('supplier=', coalesce(supplier, ''))
    FROM q WHERE NULLIF(trim(editor), '') IS NULL

    -- C04 quote line without quote number
    UNION ALL
    SELECT 'C04', 'quote_lines', oid, quote_number, line_no, concat('sku=', coalesce(sku, ''))
    FROM ql WHERE NULLIF(trim(quote_number), '') IS NULL

    -- C05 quote line without SKU
    UNION ALL
    SELECT 'C05', 'quote_lines', oid, quote_number, line_no,
           concat('description=', substr(coalesce(description, ''), 1, 80))
    FROM ql WHERE NULLIF(trim(sku), '') IS NULL

    -- C06 quote line without editor
    UNION ALL
    SELECT 'C06', 'quote_lines', oid, quote_number, line_no, concat('sku=', coalesce(sku, ''))
    FROM ql WHERE NULLIF(trim(editor), '') IS NULL

    -- C07 supplier without editor (supplier list)
    UNION ALL
    SELECT 'C07', 'supplier_editor', CAST(NULL AS varchar), CAST(NULL AS varchar), CAST(NULL AS bigint),
           concat('supplier=', coalesce(supplier, ''))
    FROM se WHERE NULLIF(trim(editor), '') IS NULL

    -- C08 quote repeated (same oid + quote_number on several rows)
    UNION ALL
    SELECT 'C08', 'quotes', oid, quote_number, CAST(NULL AS bigint), concat(CAST(row_count AS varchar), ' rows')
    FROM quote_keys WHERE row_count > 1

    -- C09 quote line without its quote
    UNION ALL
    SELECT 'C09', 'quote_lines', l.oid, l.quote_number, l.line_no, concat('sku=', coalesce(l.sku, ''))
    FROM ql l
    LEFT JOIN quote_keys k ON k.oid_key = lower(trim(l.oid)) AND k.qn_key = lower(trim(l.quote_number))
    WHERE NULLIF(trim(l.quote_number), '') IS NOT NULL AND k.oid_key IS NULL

    -- C10 SKU missing from the SKU list (one row per SKU)
    UNION ALL
    SELECT 'C10', 'quote_lines', CAST(NULL AS varchar), CAST(NULL AS varchar), CAST(NULL AS bigint),
           concat('sku=', max(l.sku), ', lines=', CAST(count(*) AS varchar))
    FROM ql l
    LEFT JOIN sk s ON lower(trim(s.sku_code)) = lower(trim(l.sku))
    WHERE NULLIF(trim(l.sku), '') IS NOT NULL AND s.sku_code IS NULL
    GROUP BY lower(trim(l.sku))

    -- C11 supplier missing from the supplier list (one row per supplier)
    UNION ALL
    SELECT 'C11', 'quotes', CAST(NULL AS varchar), CAST(NULL AS varchar), CAST(NULL AS bigint),
           concat('supplier=', max(x.supplier), ', quotes=', CAST(count(*) AS varchar))
    FROM q x
    LEFT JOIN (SELECT DISTINCT lower(trim(supplier)) AS supplier_key FROM se) s
        ON s.supplier_key = lower(trim(x.supplier))
    WHERE NULLIF(trim(x.supplier), '') IS NOT NULL AND s.supplier_key IS NULL
    GROUP BY lower(trim(x.supplier))

    -- C12 declared line count differs from the lines found
    UNION ALL
    SELECT 'C12', 'quotes', k.oid, k.quote_number, CAST(NULL AS bigint),
           concat('declared=', CAST(k.lines_declared AS varchar), ', found=', CAST(coalesce(l.lines_found, 0) AS varchar))
    FROM quote_keys k
    LEFT JOIN line_keys l ON l.oid_key = k.oid_key AND l.qn_key = k.qn_key
    WHERE k.lines_declared IS NOT NULL AND k.lines_declared <> coalesce(l.lines_found, 0)

    -- C13 quote total differs from the sum of its lines
    UNION ALL
    SELECT 'C13', 'quotes', k.oid, k.quote_number, CAST(NULL AS bigint),
           concat('quote=', CAST(round(k.total_net_excl_tax, 2) AS varchar),
                  ', lines=', CAST(round(l.lines_total_net, 2) AS varchar))
    FROM quote_keys k
    JOIN line_keys l ON l.oid_key = k.oid_key AND l.qn_key = k.qn_key
    WHERE k.total_net_excl_tax IS NOT NULL AND l.lines_total_net IS NOT NULL
      AND abs(k.total_net_excl_tax - l.lines_total_net) > greatest(1, 0.005 * abs(k.total_net_excl_tax))

    -- C14 dates in the wrong order
    UNION ALL
    SELECT 'C14', 'quotes', oid, quote_number, CAST(NULL AS bigint),
           concat('quote_date=', coalesce(CAST(quote_date AS varchar), ''), ', valid_until=', coalesce(CAST(valid_until AS varchar), ''),
                  ', contract=', coalesce(CAST(contract_start AS varchar), ''), '..', coalesce(CAST(contract_end AS varchar), ''))
    FROM q
    WHERE valid_until < quote_date OR contract_end < contract_start

    -- C15 currency without exchange rate (one row per table x currency)
    UNION ALL
    SELECT 'C15', c.table_name, CAST(NULL AS varchar), CAST(NULL AS varchar), CAST(NULL AS bigint),
           concat('currency=', c.currency, ', rows=', CAST(c.row_count AS varchar))
    FROM (
        SELECT 'quotes' AS table_name, max(currency) AS currency, lower(trim(currency)) AS currency_key, count(*) AS row_count
        FROM q WHERE NULLIF(trim(currency), '') IS NOT NULL GROUP BY lower(trim(currency))
        UNION ALL
        SELECT 'quote_lines', max(currency), lower(trim(currency)), count(*)
        FROM ql WHERE NULLIF(trim(currency), '') IS NOT NULL GROUP BY lower(trim(currency))
    ) c
    LEFT JOIN exr ON exr.currency_code = c.currency_key
    WHERE exr.currency_code IS NULL

    -- C16 quote without quote date
    UNION ALL
    SELECT 'C16', 'quotes', oid, quote_number, CAST(NULL AS bigint),
           concat('doc_type=', coalesce(doc_type, ''), ', supplier=', coalesce(supplier, ''))
    FROM q WHERE quote_date IS NULL
)
-- final: issues with their check name, dimension and severity
SELECT
    c.check_id,
    c.check_name,
    c.dimension,
    c.severity,
    i.table_name,
    i.oid,
    i.quote_number,
    i.line_no,
    i.detail
FROM issues i
JOIN {{ ref('uc5_srm_dq_checks_wk') }} c ON c.check_id = i.check_id
