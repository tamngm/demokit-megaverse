{{ config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    format='parquet',
    partitioned_by=['business_month']
) }}
-- First load: dbt run -s fact_rtl_fsh_transactions --full-refresh
-- Daily, after the convert script: dbt run -s fact_rtl_fsh_transactions
WITH src AS (
    SELECT
        *
    FROM {{ source('uc3_retail_fashion', 'uc3_rtl_fsh_transactions') }}
    {% if is_incremental() %}
    -- lookback: re-process the last 3 loaded days (late or corrected files); insert_overwrite replaces only those days
    WHERE business_month >= (SELECT max(business_month) - INTERVAL '1' MONTH FROM {{ this }})
    {% endif %}
)
, exr AS (
    SELECT upper(trim(currency_code)) AS currency_code,
           eur_per_unit
    FROM {{ ref('ref_exchange_rates') }}
)
SELECT
    -- keys
    upper(trim(invoice_id))                                 AS invoice_id,
    line                                                    AS line_no,
    customer_id,
    product_id,
    store_id,
    employee_id,
    upper(trim(sku))                                        AS sku,

    -- dates
    business_date,
    business_timestamp,

    -- type and payment
    {{ clean_string('transaction_type', 'Unknown') }}       AS transaction_type,
    CASE WHEN lower(trim(transaction_type)) = 'return' THEN 1 ELSE 0 END AS is_return,
    {{ clean_string('payment_method', 'Unknown') }}         AS payment_method,
    upper(trim(currency))                                   AS currency_code_local,
    trim(currency_symbol)                                   AS currency_symbol,

    -- measures
    quantity,
    {{ clean_decimal('unit_price', 2) }}                    AS unit_price,
    {{ clean_decimal('unit_price * quantity', 2) }}         AS gross_amount,
    {{ clean_decimal('discount', 2) }}                      AS discount_rate,
    {{ clean_decimal('unit_price * quantity - line_total', 2) }} AS discount_amount,
    {{ clean_decimal('line_total', 2) }}                    AS line_total,
    {{ clean_decimal('invoice_total', 2) }}                 AS invoice_total,

    -- measures in EUR (local amount x eur_per_unit of the line's currency)
    exr.eur_per_unit,
    {{ clean_decimal('unit_price * exr.eur_per_unit', 2) }}                  AS unit_price_eur,
    {{ clean_decimal('unit_price * quantity * exr.eur_per_unit', 2) }}       AS gross_amount_eur,
    {{ clean_decimal('(unit_price * quantity - line_total) * exr.eur_per_unit', 2) }} AS discount_amount_eur,
    {{ clean_decimal('line_total * exr.eur_per_unit', 2) }}                  AS line_total_eur,
    {{ clean_decimal('invoice_total * exr.eur_per_unit', 2) }}               AS invoice_total_eur,
    CASE WHEN NULLIF(TRIM(sku), '') IS NULL OR customer_id IS NULL OR store_id IS NULL
         THEN 1 ELSE 0 END                                  AS is_incomplete,

    -- partition column should be at the end 
    business_month
FROM src
LEFT JOIN exr ON exr.currency_code = upper(trim(src.currency))
