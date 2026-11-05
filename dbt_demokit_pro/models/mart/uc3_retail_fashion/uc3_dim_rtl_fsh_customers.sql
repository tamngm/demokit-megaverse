{{ config(materialized='table') }}
-- Customer dim + RFM: Recency (days since last purchase), Frequency (sale invoices), Monetary (net spend in EUR)
WITH sales AS (
    SELECT
    customer_id,
    business_date,
    is_return,
    invoice_id,
    SUM(line_total_eur) AS line_total_eur
    FROM {{ ref('uc3_rtl_fsh_transactions_wk') }}
    GROUP BY 1, 2, 3, 4
)
,c AS (
    SELECT
    customer_id,
    name AS customer_name,
    email AS customer_email,
    telephone AS customer_phone_number,
    city AS resident_city,
    country AS resident_country,
    gender,
    {{ age_range('date_of_birth') }}  AS age_range,
    job_title

FROM {{ source('uc3_retail_fashion', 'uc3_rtl_fsh_customers') }}
)
, s AS (
    SELECT
        t.customer_id,
        min(CASE WHEN t.is_return = 0 THEN t.business_date END)              AS first_purchase_date,
        max(CASE WHEN t.is_return = 0 THEN t.business_date END)              AS last_purchase_date,
        -- how many purchases made
        count(DISTINCT CASE WHEN t.is_return = 0 THEN t.invoice_id END)      AS frequency,
        -- how much they spent
        SUM(CASE WHEN t.is_return = 1 THEN -abs(t.line_total_eur) ELSE t.line_total_eur END) AS monetary_eur
    FROM sales t
    GROUP BY t.customer_id
)
, r AS (
    SELECT s.*,
    -- days since last purchases
        date_diff('day', s.last_purchase_date,
                     (SELECT max(business_date) FROM sales)) AS recency_days
    FROM s
)
SELECT
    c.*,
    r.first_purchase_date,
    r.last_purchase_date,
    r.recency_days,
    r.frequency,
    r.monetary_eur,
    CASE WHEN r.last_purchase_date IS NULL THEN 'Never Purchased'
     WHEN r.recency_days <= 90  THEN 'Active'
     WHEN r.recency_days <= 365 THEN 'Inactive'
     ELSE 'Churned' END
    AS customer_status

FROM c
LEFT JOIN r ON r.customer_id = c.customer_id
