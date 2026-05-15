create or replace view
    "awsdatacatalog"."offybi"."my_second_dbt_model"
  as
    -- Use the `ref` function to select from other models

select *
from "awsdatacatalog"."offybi"."my_first_dbt_model"
where id = 1
