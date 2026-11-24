-- One row per editor (software / hardware vendor) found in any uc5 table

SELECT DISTINCT
    editor
FROM {{ ref('uc5_srm_supplier_editor_wk') }}