{#
    Fills NULL, empty , whitespace values with a value picked from the columns own distinct values.
    The pick is deterministic: a hash of seed_column (e.g. product_id) chooses the value,
    so the same row always gets the same fill on every run (unlike rand()).

    column:       column to fill, e.g. 'color'
    seed_column:  stable row key, e.g. 'product_id'
    partition_by: optional group; values are only picked from the same group, e.g. 'sub_category'

    Usage:
        {{ fill_null_value('color', 'product_id') }} AS color
        {{ fill_null_value('sizes', 'product_id', 'sub_category') }} AS sizes
#}

{% macro fill_null_value(column, seed_column, partition_by=none) %}
    {%- set clean = "NULLIF(TRIM(" ~ column ~ "), '')" -%}
    {%- set pool -%}
        array_sort(filter(array_distinct(array_agg({{ clean }}) OVER ({% if partition_by %}PARTITION BY {{ partition_by }}{% endif %})), v -> v IS NOT NULL))
    {%- endset -%}
    COALESCE(
        {{ clean }},
        IF(
            cardinality({{ pool }}) = 0,
            NULL,
            element_at(
                {{ pool }},
                1 + mod(abs(from_big_endian_64(xxhash64(to_utf8(CAST({{ seed_column }} AS varchar) || '{{ column }}')))), cardinality({{ pool }}))
            )
        )
    )
{% endmacro %}


{#
    Fills missing product sizes from the size frames used within the same sub_category
    (e.g. a missing size on a shoe only gets a shoe size).

    Usage:
        {{ fill_null_product_size() }} AS sizes
#}
{% macro fill_null_product_size(size_column='sizes', seed_column='product_id', sub_category_column='sub_category') %}
    {{ fill_null_value(size_column, seed_column, "NULLIF(TRIM(" ~ sub_category_column ~ "), '')") }}
{% endmacro %}
