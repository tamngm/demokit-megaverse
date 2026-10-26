{{
    config(
        materialized='table',
        format='parquet',
        partitioned_by=['order_month']
    )
}}
WITH src AS (
    SELECT
        *,
        CAST(try(date_parse(split_part(trim(order_purchased_date), ' ', 1), '%m/%d/%Y')) AS date) AS purchased_dt,
        CAST(try(date_parse(split_part(trim(order_approved_at), ' ', 1), '%m/%d/%Y')) AS date) AS approved_dt,
        CAST(try(date_parse(split_part(trim(order_shipped_at), ' ', 1), '%m/%d/%Y')) AS date) AS shipped_dt,
        CAST(try(date_parse(split_part(trim(order_delivery_date), ' ', 1), '%m/%d/%Y')) AS date) AS delivered_dt,
        CAST(try(date_parse(split_part(trim(order_estimated_delivery_date), ' ', 1), '%m/%d/%Y')) AS date) AS estimated_dt
    FROM {{ source('uc2_retail_kit', 'rtl_order') }}
)

SELECT
    order_id, customer_id, product_id, order_user_id,
    market, order_region, order_country, order_state, order_city,
    try_cast(latitude AS double)  AS latitude,
    try_cast(longitude AS double) AS longitude,
    trim(order_status)            AS order_status,
    order_item_quantity, sales, order_item_discount, order_item_total,
    order_profit_per_order, order_item_profit_ratio,
    purchased_dt, approved_dt, shipped_dt, delivered_dt, estimated_dt,
    date_diff('day', purchased_dt, approved_dt)  AS days_to_approve,
    date_diff('day', approved_dt,  shipped_dt)   AS days_to_ship,
    date_diff('day', purchased_dt, delivered_dt) AS days_to_deliver,
    date_diff('day', estimated_dt, delivered_dt) AS days_late,        -- > 0 means late
    CASE
        WHEN delivered_dt IS NULL OR estimated_dt IS NULL THEN NULL
        WHEN delivered_dt > estimated_dt THEN 1
        ELSE 0
    END AS is_late,
    date_trunc('month', purchased_dt) AS order_month                  -- partition column must be last
FROM src
