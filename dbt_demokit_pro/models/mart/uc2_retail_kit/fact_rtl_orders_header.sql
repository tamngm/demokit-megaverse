SELECT
    o.order_id,
    max(o.customer_id)          AS customer_id,
    max(o.market)               AS market,
    max(o.order_region)         AS order_region,
    max(o.order_country)        AS order_country,
    max(o.order_status)         AS order_status,
    max(s.status_group)         AS status_group,
    max(s.is_final)             AS is_final,
    max(s.sort_order)           AS sort_order,
    max(s.delivery_result)      AS delivery_result,
    count(*)                    AS line_count,
    sum(o.order_item_quantity)  AS quantity,
    sum(o.sales)                AS gross_sales,
    sum(o.order_item_discount)  AS discount,
    sum(o.order_item_total)     AS net_sales,
    sum(o.order_profit_per_order) AS profit,
    min(o.purchased_dt)         AS purchased_dt,
    max(o.delivered_dt)         AS delivered_dt,
    max(o.estimated_dt)         AS estimated_dt,
    max(o.days_to_approve)      AS days_to_approve,
    max(o.days_to_ship)         AS days_to_ship,
    max(o.days_to_deliver)      AS days_to_deliver,
    max(o.is_late)              AS is_late,
    min(o.order_month)          AS order_month
FROM {{ ref('rtl_orders_wk') }} o
LEFT JOIN {{ ref('rtl_order_status_map') }} s
    ON lower(o.order_status) = lower(s.order_status)
GROUP BY o.order_id
