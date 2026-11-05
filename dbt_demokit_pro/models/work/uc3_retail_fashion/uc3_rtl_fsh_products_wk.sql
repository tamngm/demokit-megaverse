{{ config(materialized='view') }}
WITH exr AS (
    SELECT upper(trim(currency_code)) AS currency_code,
           eur_per_unit
    FROM {{ ref('ref_exchange_rates') }}
),
sales AS (
    -- one row per sku: take the color/size seen in sales, else parse it from the sku
    SELECT
        upper(trim(sku)) AS sku,
        max(product_id) AS product_id,
        COALESCE(max(NULLIF(TRIM(color), '')),
                 max(NULLIF(regexp_extract(sku, '^[^-]+-([^-]*)-(.*)$', 2), ''))) AS color,
        COALESCE(max(NULLIF(TRIM(size), '')),
                 max(NULLIF(regexp_extract(sku, '^[^-]+-([^-]*)-(.*)$', 1), ''))) AS size,
        max(NULLIF(TRIM(color), '')) IS NULL                             AS is_color_from_sku,
        max(NULLIF(TRIM(size), '')) IS NULL                              AS is_size_from_sku
    FROM {{ source('uc3_retail_fashion', 'uc3_rtl_fsh_transactions') }}
    WHERE NULLIF(TRIM(sku), '') IS NOT NULL
    GROUP BY 1
)

, product AS (
SELECT
    product_id,
    category,
    sub_category,
    {{ fill_null_value('color', 'product_id') }}  AS color,
    {{ fill_null_product_size() }}                AS size,
    NULLIF(TRIM(color), '') IS NULL               AS is_color_imputed,
    NULLIF(TRIM(sizes), '') IS NULL               AS is_sizes_imputed,
    production_cost AS production_cost_usd,
    {{ clean_decimal('production_cost * eur_per_unit', 2) }} AS production_cost_eur
FROM {{ source('uc3_retail_fashion', 'uc3_rtl_fsh_products') }} a
LEFT JOIN exr ON exr.currency_code = 'USD'

)

-- product quadrant: revenue vs margin % per product, split at the medians
-- Stars (high/high), Volume Drivers (high revenue, low margin), Niche (low revenue, high margin), Dogs (low/low)
, perf AS (
    SELECT
        t.product_id,
        sum(CASE WHEN t.is_return = 1 THEN -abs(t.line_total_eur) ELSE t.line_total_eur END)        AS revenue_eur,
        sum(CASE WHEN t.is_return = 1 THEN -abs(t.quantity) ELSE t.quantity END)                     AS net_quantity
    FROM {{ ref('uc3_rtl_fsh_transactions_wk') }} t
    GROUP BY t.product_id
)

, quadrant AS (
    SELECT
        perf.product_id,
        perf.revenue_eur,
        perf.revenue_eur - perf.net_quantity * product.production_cost_eur                   AS margin_eur,
        (perf.revenue_eur - perf.net_quantity * product.production_cost_eur)
            / NULLIF(perf.revenue_eur, 0)                                                    AS margin_pct
    FROM perf
    LEFT JOIN product ON product.product_id = perf.product_id
)

, medians AS (
    SELECT approx_percentile(revenue_eur, 0.5) AS med_revenue,
           approx_percentile(margin_pct, 0.5)  AS med_margin_pct
    FROM quadrant
    WHERE revenue_eur > 0
)

SELECT
    a.sku,
    a.product_id,
    b.category,
    b.sub_category,
    COALESCE(b.color, a.color) AS color,
    a.size,
    a.is_color_from_sku,
    a.is_size_from_sku,
    b.production_cost_eur,
    {{ clean_decimal('q.revenue_eur', 2) }}  AS revenue_eur,
    {{ clean_decimal('q.margin_eur', 2) }}   AS margin_eur,
    {{ clean_decimal('q.margin_pct', 4) }}   AS margin_pct,
    CASE WHEN q.revenue_eur IS NULL OR q.revenue_eur <= 0                         THEN 'No sales'
         WHEN q.revenue_eur >= m.med_revenue AND q.margin_pct >= m.med_margin_pct THEN 'Stars'
         WHEN q.revenue_eur >= m.med_revenue                                      THEN 'Volume Drivers'
         WHEN q.margin_pct >= m.med_margin_pct                                    THEN 'Niche'
         ELSE 'Dogs' END                     AS product_quadrant
FROM sales a
LEFT JOIN product b ON a.product_id = b.product_id
LEFT JOIN quadrant q ON q.product_id = a.product_id
CROSS JOIN medians m
