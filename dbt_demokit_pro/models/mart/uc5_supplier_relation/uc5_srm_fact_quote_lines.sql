-- Grain: one row per quote line (quote_line_key = quote_key + line_no).
-- Exact duplicate rows are removed; lines without a quote_number are left out (data quality, not in this demo).
-- Amounts in the line currency and in EUR (ref_exchange_rates).

-- lines: source lines with a quote_number, without exact duplicates, with the quote key
WITH lines AS (
    SELECT
        {{ hash_key('l.oid', 'l.quote_number') }}         AS quote_key,
        l.*
    FROM (SELECT DISTINCT * FROM {{ source('uc5_supplier_relation', 'uc5_srm_quote_lines') }}) l
    WHERE NULLIF(trim(l.quote_number), '') IS NOT NULL
)
-- exr: EUR rate per currency, to convert the line amounts
, exr AS (
    SELECT lower(trim(currency_code)) AS currency_code, eur_per_unit
    FROM {{ ref('ref_exchange_rates') }}
)
-- final: one row per line with its unique key, amounts, discount and EUR amounts
SELECT
    {{ hash_key('quote_key', 'line_no') }}                          AS quote_line_key,
    quote_key,
    oid,
    quote_number,
    line_no,
    parent_line_no,
    supplier,
    editor,
    sku,
    covered_sku,
    item_type,
    description,
    unit_of_measure,
    business_line_from_scenario_demo                                AS business_line,
    start_date,
    end_date,
    term_months,
    currency,
    quantity,
    unit_list_price,
    unit_net_price,
    discount_pct,
    effective_discount_pct,
    line_total_list,
    line_total_net,
    line_total_list - line_total_net                                AS line_discount_amount,
    exr.eur_per_unit,
    round(unit_net_price * exr.eur_per_unit, 2)                     AS unit_net_price_eur,
    round(line_total_list * exr.eur_per_unit, 2)                    AS line_total_list_eur,
    round(line_total_net * exr.eur_per_unit, 2)                     AS line_total_net_eur,
    round((line_total_list - line_total_net) * exr.eur_per_unit, 2) AS line_discount_amount_eur
FROM lines
LEFT JOIN exr ON exr.currency_code = lower(trim(lines.currency))
