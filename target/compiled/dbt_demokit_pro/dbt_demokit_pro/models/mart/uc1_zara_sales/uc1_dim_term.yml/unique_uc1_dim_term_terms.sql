
    
    

select
    terms as unique_field,
    count(*) as n_records

from "awsdatacatalog"."offybi_mart"."uc1_dim_term"
where terms is not null
group by terms
having count(*) > 1


