-- Hourly sales per store x transaction type x payment method x currency (traffic, peak hours, payment mix)
-- invoice_count / customer_count are distinct counts: do not sum them across rows in Power BI
SELECT
    t.business_date,
    hour(t.business_timestamp)                                      AS business_hour,
    t.store_id,
    t.transaction_type,
    t.payment_method,
    t.currency_code_local,
    count(*)                                                        AS line_count,
    count(DISTINCT t.invoice_id)                                    AS invoice_count,
    count(DISTINCT t.customer_id)                                   AS customer_count,
    sum(t.quantity)                                                 AS quantity,
    sum(t.line_total)                                               AS line_total_local,
    sum(t.gross_amount_eur)                                         AS gross_amount_eur,
    sum(t.discount_amount_eur)                                      AS discount_amount_eur,
    sum(t.line_total_eur)                                           AS line_total_eur
FROM {{ ref('uc3_rtl_fsh_transactions_wk') }} t
WHERE business_date BETWEEN DATE '2023-01-01' AND DATE '2024-12-31'

GROUP BY 1, 2, 3, 4, 5, 6
