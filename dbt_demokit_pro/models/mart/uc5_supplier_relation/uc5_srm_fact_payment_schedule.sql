-- Grain: one row per payment instalment of a quote (quote_key x seq).

-- exr: EUR rate per currency, to convert the instalment amounts
WITH exr AS (
    SELECT lower(trim(currency_code)) AS currency_code, eur_per_unit
    FROM {{ ref('ref_exchange_rates') }}
)
-- final: instalments with a quote_number, without exact duplicates, with the quote key and the EUR amount
SELECT
    {{ hash_key('p.oid', 'p.quote_number') }}  AS quote_key,
    p.oid,
    p.quote_number,
    p.editor,
    p.seq,
    p.label,
    p.due_date,
    p.period_start,
    p.period_end,
    p.currency,
    p.amount,
    round(p.amount * exr.eur_per_unit, 2)               AS amount_eur
FROM (SELECT DISTINCT * FROM {{ source('uc5_supplier_relation', 'uc5_srm_payment_schedule') }}) p
LEFT JOIN exr ON exr.currency_code = lower(trim(p.currency))
WHERE NULLIF(trim(p.quote_number), '') IS NOT NULL
