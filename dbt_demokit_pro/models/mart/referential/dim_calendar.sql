-- source "date" is text: parse it once (ISO 2025-03-14 or US 3/14/2025), NULL if unreadable
WITH src AS (
    SELECT
        COALESCE(
            try(CAST(trim("date") AS date)),
            CAST(try(date_parse(split_part(trim("date"), ' ', 1), '%m/%d/%Y')) AS date)
        ) AS "date"
    FROM {{ source('referential', 'ref_calendar') }}
)
SELECT
    "date",
    CAST(date_format("date", '%Y%m%d') AS integer)           AS date_key,          -- 20250314
    year("date")                                             AS year,
    quarter("date")                                          AS quarter,
    concat('Q', CAST(quarter("date") AS varchar))            AS quarter_desc,      -- Q1
    month("date")                                            AS month,
    date_format("date", '%M')                                AS month_name,        -- March
    date_format("date", '%b')                                AS month_short,       -- Mar
    date_format("date", '%Y-%m')                             AS year_month,        -- 2025-03
    date_trunc('month', "date")                              AS month_start,
    year_of_week("date")                                     AS iso_year,
    week_of_year("date")                                     AS iso_week,
    day("date")                                              AS day_of_month,
    day_of_week("date")                                      AS day_of_week,       -- 1 = Monday ... 7 = Sunday
    date_format("date", '%W')                                AS day_name,          -- Friday
    date_format("date", '%a')                                AS day_short,         -- Fri
    day_of_year("date")                                      AS day_of_year,
    CASE WHEN day_of_week("date") IN (6, 7) THEN 1 ELSE 0 END AS is_weekend,
    -- previous periods: the same position in the earlier period
    -- (month and year ends are clamped: 31 Mar -> 28/29 Feb, 29 Feb -> 28 Feb)
    date_add('day', -1, "date")                              AS prev_day,
    date_add('week', -1, "date")                             AS same_day_prev_week,
    date_add('month', -1, "date")                            AS same_day_prev_month,
    date_add('quarter', -1, "date")                          AS same_day_prev_quarter,
    date_add('year', -1, "date")                             AS same_day_prev_year,
    date_add('day', -364, "date")                            AS same_weekday_prev_year,     -- 52 weeks back, same weekday (retail like-for-like)

    -- previous period starts and labels (for joining or grouping at month/quarter/year level)
    date_add('month', -1, date_trunc('month', "date"))       AS prev_month_start,
    date_format(date_add('month', -1, "date"), '%Y-%m')      AS prev_year_month,
    date_add('quarter', -1, date_trunc('quarter', "date"))   AS prev_quarter_start,
    year("date") - 1                                         AS prev_year
FROM src
WHERE "date" IS NOT NULL
