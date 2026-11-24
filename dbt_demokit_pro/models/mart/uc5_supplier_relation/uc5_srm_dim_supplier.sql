-- One row per supplier: type, number of editors, quotes, first / last seen

-- final: supplier x editor rows rolled up to one row per supplier (case-insensitive)
SELECT DISTINCT
    supplier, supplier_type
FROM {{ ref('uc5_srm_supplier_editor_wk') }}