-- Grain: one row per price component of a quote line (list, net, each discount, fee, usage rate, by period).
-- Links to its line on quote_line_key (built like uc5_srm_fact_quote_lines: quote key + line_no).
-- Rows without a quote_number are left out. When basis = PERCENT, amount is a percentage: amount_eur is NULL.

-- exr: EUR rate per currency, to convert the component amounts
WITH exr AS (
    SELECT lower(trim(currency_code)) AS currency_code, eur_per_unit
    FROM {{ ref('ref_exchange_rates') }}
)
-- final: price components with a quote_number, without exact duplicates, with the quote and line keys
SELECT
    {{ hash_key('p.oid', 'p.quote_number') }}                              AS quote_key,
    {{ hash_key(hash_key('p.oid', 'p.quote_number'), 'p.line_no') }}       AS quote_line_key,
    p.oid,
    p.quote_number,
    p.line_no,
    p.seq,
    p.editor,
    p.sku,
    p.component,
    p.discount_type,
    p.basis,
    p.price_period,
    p.schedule_label,
    p.period_start,
    p.period_end,
    p.printed_label,
    p.currency,
    p.quantity,
    p.amount,
    p.pct,
    CASE WHEN upper(trim(p.basis)) = 'PERCENT' THEN NULL
         ELSE round(p.amount * exr.eur_per_unit, 2) END AS amount_eur
FROM 
    (SELECT DISTINCT * FROM {{ source('uc5_supplier_relation', 'uc5_srm_line_prices') }}) p
LEFT JOIN exr ON exr.currency_code = lower(trim(p.currency))
WHERE NULLIF(trim(p.quote_number), '') IS NOT NULL
