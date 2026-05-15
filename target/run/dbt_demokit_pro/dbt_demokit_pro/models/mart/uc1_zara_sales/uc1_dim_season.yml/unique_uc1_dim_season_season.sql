
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    season as unique_field,
    count(*) as n_records

from "awsdatacatalog"."offybi_mart"."uc1_dim_season"
where season is not null
group by season
having count(*) > 1



  
  
      
    ) dbt_internal_test