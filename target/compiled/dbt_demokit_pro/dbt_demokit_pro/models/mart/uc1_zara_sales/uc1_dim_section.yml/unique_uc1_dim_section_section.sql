
    
    

select
    section as unique_field,
    count(*) as n_records

from "awsdatacatalog"."offybi_mart"."uc1_dim_section"
where section is not null
group by section
having count(*) > 1


