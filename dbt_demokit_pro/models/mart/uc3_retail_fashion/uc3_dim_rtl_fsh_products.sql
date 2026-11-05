SELECT
    sku,
    product_id,
    category,
    sub_category,
    a.color,
    size,
    production_cost_eur,
    revenue_eur,
    margin_eur,
    margin_pct,
    product_quadrant,
    b.hex AS color_hex
FROM {{ ref('uc3_rtl_fsh_products_wk') }} a
LEFT JOIN {{ ref('ref_color_codes') }} b ON a.color = b.color
