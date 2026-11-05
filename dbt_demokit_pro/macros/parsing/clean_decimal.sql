{#
    Rounds a numeric (or numeric-text) column to a fixed number of decimals.
    Unreadable values become NULL instead of failing the query.

    decimal_num: 2 for amounts (sales, discount, profit), 3 for rates and ratios.

    Usage:
        {{ clean_decimal('line_total') }}            -> decimal(18,2)
        {{ clean_decimal('discount', 3) }}           -> decimal(18,3)
#}
{% macro clean_decimal(decimal_column, decimal_num=2) %}
    CAST(round(try_cast({{ decimal_column }} AS double), {{ decimal_num }}) AS decimal(18, {{ decimal_num }}))
{% endmacro %}
