{{
    config(
        schema='mart'
    )
}}


SELECT DISTINCT
    season,
    CASE lower(season)
        WHEN 'spring' THEN 1
        WHEN 'summer' THEN 2
        WHEN 'autumn' THEN 3
        WHEN 'winter' THEN 4
        ELSE 0
    END AS season_id

FROM {{ ref('uc1_dim_product') }}
ORDER BY season_id