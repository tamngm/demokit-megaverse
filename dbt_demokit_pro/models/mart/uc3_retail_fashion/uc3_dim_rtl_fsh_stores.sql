SELECT 
    DISTINCT
    store_id,
    country,
    city,
    store_name,
    number_of_employees,
    zip_code,
    latitude,
    longitude

FROM {{ source('uc3_retail_fashion', 'uc3_rtl_fsh_stores') }}