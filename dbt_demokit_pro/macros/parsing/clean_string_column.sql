{#
    Clean null, empty or whitespace-only string column: trims it and replaces missing values.
    Usage: {{ clean_string('category', 'All') }}
#}
{% macro clean_string(column, replace_null_value) %}
    COALESCE(NULLIF(TRIM({{ column }}), ''), '{{ replace_null_value }}')
{% endmacro %}