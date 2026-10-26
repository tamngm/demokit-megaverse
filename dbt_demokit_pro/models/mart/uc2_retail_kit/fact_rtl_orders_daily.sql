-- Overview KPIs: one row per order date x market x region x country
SELECT
    purchased_dt                                AS order_date,
    market,
    order_region,
    order_country,
    count(DISTINCT order_id)                    AS orders,
    count(*)                                    AS lines,
    sum(order_item_quantity)                    AS quantity,
    sum(sales)                                  AS gross_sales,
    sum(order_item_discount)                    AS discount,
    sum(order_item_total)                       AS net_sales,
    sum(order_profit_per_order)                 AS profit,
    CAST(sum(order_profit_per_order) AS double) / nullif(sum(order_item_total), 0) AS margin_pct,
    CAST(sum(order_item_total) AS double) / nullif(count(DISTINCT order_id), 0)    AS avg_order_value,
    CAST(sum(order_item_discount) AS double) / nullif(sum(sales), 0)               AS discount_rate
FROM {{ ref('rtl_orders_wk') }}
GROUP BY purchased_dt, market, order_region, order_country
