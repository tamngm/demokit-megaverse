{#
    Builds a key from two or three columns: lower-cased, trimmed, concatenated with '|', hashed (md5, hex).
    A NULL column counts as '' so the key is never NULL; rows with the same values get the same key.
    column_c is optional: without it the key is built from column_a and column_b only.

    Usage:
        {{ hash_key('oid', 'quote_number') }}                  -> quote key
        {{ hash_key('quote_key', 'line_no', 'line_seq') }}     -> line key
        {{ hash_key('q.store_id', 'q.business_date') }}        (non-text columns are cast to varchar)
#}
{% macro hash_key(column_a, column_b, column_c=none) %}
    lower(to_hex(md5(to_utf8(concat(
        coalesce(lower(trim(CAST({{ column_a }} AS varchar))), ''), '|',
        coalesce(lower(trim(CAST({{ column_b }} AS varchar))), '')
        {%- if column_c is not none %}, '|',
        coalesce(lower(trim(CAST({{ column_c }} AS varchar))), '')
        {%- endif %}
    )))))
{% endmacro %}
