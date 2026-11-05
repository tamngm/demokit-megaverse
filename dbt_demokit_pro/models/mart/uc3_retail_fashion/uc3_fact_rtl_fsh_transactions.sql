{{ config(materialized='view') }}
-- Hourly KPIs per store x transaction type x currency (view on the incremental work table)

SELECT
    business_date,
    hour(business_timestamp)                    AS business_hour,
    store_id,
    customer_id,
    sku,
    employee_id,
    transaction_type,
    is_return,
    currency_code_local,
    payment_method,
    count(*)                                    AS line_count,
    count(DISTINCT invoice_id)                  AS invoice_count,
    sum(quantity)  AS quantity,
    sum(gross_amount_eur)                       AS gross_amount_eur,
    sum(discount_amount_eur)                    AS discount_amount_eur,
    sum(line_total)                             AS line_total,
    sum(is_incomplete)                          AS incomplete_line_count
FROM {{ ref('uc3_rtl_fsh_transactions_wk') }} a
WHERE business_date BETWEEN DATE '2023-01-01' AND DATE '2024-12-31'

GROUP BY 1,2,3,4,5,6,7,8,9,10
