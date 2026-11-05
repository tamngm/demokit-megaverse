SELECT 
    "start" AS start_date,
    "end" AS end_date,
    {{ clean_decimal('discont', 2) }} AS discounts,
    description AS discount_description,
    {{ clean_string('category', 'All') }} AS category,
    {{ clean_string('sub_category', 'All') }} AS sub_category
FROM {{ source('uc3_retail_fashion', 'uc3_rtl_fsh_discounts') }}