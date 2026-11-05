SELECT 
    employee_id,
    store_id,
    name AS employee_name,
    position AS employee_position
    
FROM {{ source('uc3_retail_fashion', 'uc3_rtl_fsh_employees') }}