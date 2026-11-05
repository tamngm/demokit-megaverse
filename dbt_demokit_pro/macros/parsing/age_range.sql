{#
    Converts a date of birth into an age band.
    Age = full years between date of birth and as_of (default: today).
    Invalid ages (NULL, <= 0 or >= 100, unreadable date) return '' (blank).

    Usage:
        {{ age_range('date_of_birth') }}                          AS age_range
        {{ age_range('date_of_birth', "DATE '2025-12-31'") }}     AS age_range_at_year_end
#}
{% macro age_range(dob_column, as_of='current_date') %}
    {%- set age = "date_diff('year', try_cast(" ~ dob_column ~ " AS date), " ~ as_of ~ ")" -%}
    CASE
        WHEN {{ age }} IS NULL OR {{ age }} <= 0 OR {{ age }} >= 100 THEN ''
        WHEN {{ age }} < 18 THEN 'Under 18'
        WHEN {{ age }} < 25 THEN '18-24'
        WHEN {{ age }} < 35 THEN '25-34'
        WHEN {{ age }} < 45 THEN '35-44'
        WHEN {{ age }} < 55 THEN '45-54'
        WHEN {{ age }} < 65 THEN '55-64'
        ELSE '65+'
    END
{% endmacro %}
