-- One row per editor (software / hardware vendor) found in any uc5 table

-- editors: every editor name seen in SKUs, supplier list, quotes and quote lines
WITH 
from_line AS (
    SELECT DISTINCT 
    supplier, 
    editor, 
    count(distinct quote_number) as quote_count
    FROM {{ source('uc5_supplier_relation', 'uc5_srm_quote_lines') }}
    GROUP BY 1,2
)
, get_supplier_editor AS (
    SELECT DISTINCT 
        coalesce(a.supplier,b.supplier) supplier, 
        coalesce(a.editor,b.editor) editor, 
        a.supplier_type,
        SUM(COALESCE(a.quotes, b.quote_count)) AS quote_count,
        min(first_seen)            AS first_seen,
        max(last_seen)             AS last_seen
    FROM {{ source('uc5_supplier_relation', 'uc5_srm_supplier_editor') }} a
    FULL JOIN from_line b
    ON a.supplier = b.supplier AND a.editor = b.editor
    GROUP BY 1,2,3
)

SELECT * 
FROM get_supplier_editor
WHERE supplier IS NOT NULL
AND editor IS NOT NULL