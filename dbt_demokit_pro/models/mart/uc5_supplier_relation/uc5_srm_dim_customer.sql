-- One row per end customer: number of quotes, first / last quote date

-- quotes: source quotes with a quote_number, without exact duplicates
WITH quotes AS (
    SELECT DISTINCT * FROM {{ source('uc5_supplier_relation', 'uc5_srm_quotes') }}
    WHERE NULLIF(trim(quote_number), '') IS NOT NULL
)
-- final: one row per customer (case-insensitive) with quote count and date range
SELECT
    max(end_customer)                                               AS end_customer,
    count(DISTINCT {{ hash_key('oid', 'quote_number') }})  AS quote_count,
    min(quote_date)                                                 AS first_quote_date,
    max(quote_date)                                                 AS last_quote_date
FROM quotes
WHERE end_customer IS NOT NULL
AND TRIM(end_customer) != ''
GROUP BY lower(trim(end_customer))
