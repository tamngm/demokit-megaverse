-- One row per SKU: the SKU list, plus SKUs found only in quote lines (so every line finds its SKU)

-- skus: the SKU list
WITH skus AS (
    SELECT * FROM {{ source('uc5_supplier_relation', 'uc5_srm_skus') }}
    WHERE sku_code IS NOT NULL
    AND TRIM(sku_code) != ''
)
-- lines_only: SKUs used in quote lines but missing from the SKU list
, lines_only AS (
    SELECT
        max(l.sku)          AS sku_code,
        max(l.editor)       AS editor,
        max(l.description)  AS description,
        max(l.item_type)    AS item_type
    FROM {{ source('uc5_supplier_relation', 'uc5_srm_quote_lines') }} l
    LEFT JOIN skus s ON lower(trim(s.sku_code)) = lower(trim(l.sku))
    WHERE l.sku IS NOT NULL AND s.sku_code IS NULL
    GROUP BY lower(trim(l.sku))
)
-- final: SKU list + missing SKUs, flagged with is_from_lines_only
SELECT sku_code, editor, description, item_type, times_quoted, first_seen, last_seen,
       false AS is_from_lines_only
FROM skus
UNION ALL
SELECT sku_code, editor, description, item_type, CAST(NULL AS bigint), CAST(NULL AS date), CAST(NULL AS date),
       true AS is_from_lines_only
FROM lines_only
