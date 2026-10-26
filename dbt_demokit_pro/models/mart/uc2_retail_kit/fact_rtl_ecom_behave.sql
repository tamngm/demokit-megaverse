{{
    config(
        schema='mart',
        materialized='view'
    )
}}

-- raw dates are mm/dd/yyyy strings: drop any time part, parse, NULL if unreadable
SELECT
    *,
    CAST(try(date_parse(split_part(trim(order_purchased_date), ' ', 1), '%m/%d/%Y')) AS date) AS order_purchased_date_clean
FROM {{ source('uc2_retail_kit', 'rtl_ecom_behave_to_order') }}
