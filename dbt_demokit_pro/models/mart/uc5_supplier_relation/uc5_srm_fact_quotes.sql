-- Grain: one row per quote (quote_key = oid + quote_number).
-- Exact duplicate rows are removed; quotes without a quote_number are left out (data quality, not in this demo).
-- Amounts in the quote currency and in EUR (ref_exchange_rates).

-- quotes: source rows with a quote_number, without exact duplicates, with the quote key
WITH quotes AS (
    SELECT {{ hash_key('q.oid', 'q.quote_number') }} AS quote_key, q.*
    FROM (SELECT DISTINCT * FROM {{ source('uc5_supplier_relation', 'uc5_srm_quotes') }}) q
    WHERE NULLIF(trim(q.quote_number), '') IS NOT NULL
)
-- header: one row per quote key (one quote appears twice in the source with small differences)
, header AS (
    SELECT
        quote_key,
        max(oid)                                AS oid,
        max(quote_number)                       AS quote_number,
        count(*)                                AS document_count,
        max(supplier)                           AS supplier,
        max(supplier_type)                      AS supplier_type,
        max(editor)                             AS editor,
        max(end_customer)                       AS end_customer,
        max(doc_type)                           AS doc_type,
        max(direction)                          AS direction,
        max(revision)                           AS revision,
        min(quote_date)                         AS quote_date,
        max(valid_until)                        AS valid_until,
        min(contract_start)                     AS contract_start,
        max(contract_end)                       AS contract_end,
        max(term_months)                        AS term_months,
        max(billing_frequency)                  AS billing_frequency,
        max(payment_terms)                      AS payment_terms,
        max(incoterms)                          AS incoterms,
        max(currency)                           AS currency,
        max(project_name)                       AS project_name,
        max(vendor_quote_ref)                   AS vendor_quote_ref,
        max(deal_reg)                           AS deal_reg,
        max(sales_contact)                      AS sales_contact,
        max(business_line_from_scenario_demo)   AS business_line,
        sum(lines)                              AS line_count_declared,
        sum(total_list)                         AS total_list,
        sum(total_net_excl_tax)                 AS total_net_excl_tax,
        sum(tax_amount)                         AS tax_amount,
        sum(total_incl_tax)                     AS total_incl_tax
    FROM quotes
    GROUP BY quote_key
)
-- adjustments: freight and one-time discount per quote (tax is already on the quote header)
, adjustments AS (
    SELECT
        {{ hash_key('oid', 'quote_number') }}                        AS quote_key,
        sum(CASE WHEN upper(trim(type)) = 'FREIGHT' THEN amount END)           AS freight_amt_qadj,
        sum(CASE WHEN upper(trim(type)) = 'ONE_TIME_DISCOUNT' THEN amount END) AS onetime_disc_amt_qadj,
        sum(CASE WHEN upper(trim(type)) = 'TAX' THEN amount END) AS tax_amt_qadj
    FROM (SELECT DISTINCT * FROM {{ source('uc5_supplier_relation', 'uc5_srm_quote_adjustments') }})
    WHERE NULLIF(trim(quote_number), '') IS NOT NULL
    GROUP BY 1
)
-- lines: number of lines actually found per quote, to compare with the declared count
, lines AS (
    SELECT
        {{ hash_key('oid', 'quote_number') }}  AS quote_key,
        count(*)                                        AS line_count
    FROM (SELECT DISTINCT * FROM {{ source('uc5_supplier_relation', 'uc5_srm_quote_lines') }})
    WHERE NULLIF(trim(quote_number), '') IS NOT NULL
    GROUP BY 1
)
-- exr: EUR rate per currency, to convert the totals
, exr AS (
    SELECT lower(trim(currency_code)) AS currency_code, eur_per_unit
    FROM {{ ref('ref_exchange_rates') }}
)
-- final: quote header + adjustments + line count + EUR amounts and discount rate
SELECT
    h.quote_key,
    h.oid,
    h.quote_number,
    h.document_count,
    h.supplier,
    h.supplier_type,
    h.editor,
    h.end_customer,
    h.doc_type,
    h.direction,
    h.revision,
    h.quote_date,
    h.valid_until,
    date_diff('day', h.quote_date, h.valid_until)          AS validity_days,
    h.contract_start,
    h.contract_end,
    h.term_months,
    h.billing_frequency,
    h.payment_terms,
    h.incoterms,
    h.project_name,
    h.vendor_quote_ref,
    h.deal_reg,
    h.sales_contact,
    h.business_line,
    h.line_count_declared,
    coalesce(l.line_count, 0)                              AS line_count,
    -- h.currency,
    -- h.total_list,
    -- h.total_net_excl_tax,
    -- h.tax_amount,
    -- h.total_incl_tax,

    exr.eur_per_unit,
    round(a.tax_amt_qadj * exr.eur_per_unit, 2)  AS tax_amt_qadj_eur,
    round(a.freight_amt_qadj * exr.eur_per_unit, 2)  AS freight_amt_qadj_eur,
    round(a.onetime_disc_amt_qadj * exr.eur_per_unit, 2)  AS onetime_disc_amt_qadj_eur,
    round(h.total_list * exr.eur_per_unit, 2)              AS total_list_eur,
    round(h.total_net_excl_tax * exr.eur_per_unit, 2)      AS total_net_excl_tax_eur,
    round(h.tax_amount * exr.eur_per_unit, 2)              AS tax_amount_eur,
    round(h.total_incl_tax * exr.eur_per_unit, 2)          AS total_incl_tax_eur,
    round(1 - h.total_net_excl_tax / nullif(h.total_list, 0), 4) AS discount_rate
FROM header h
LEFT JOIN adjustments a ON a.quote_key = h.quote_key
LEFT JOIN lines l       ON l.quote_key = h.quote_key
LEFT JOIN exr           ON exr.currency_code = lower(trim(h.currency))
