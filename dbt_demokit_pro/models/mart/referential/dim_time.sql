SELECT
    time_key,
    time, 
    hour,
    minute,
    hour_label,
    am_pm,
    day_part

FROM {{ ref('ref_time') }}