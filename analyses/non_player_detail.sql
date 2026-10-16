-- Shows every filled column for the dead money rows,
-- so we can see which column B-Ref puts the description text in.

with numbered as (
    select
        row_number() over () as row_order,
        *
    from {{ source('bref', 'nyy_contracts') }}
    where "Name-additional" = '-9999'
)

select
    row_order,
    column_name,
    regexp_replace(cell, '[0-9]', '9', 'g') as pattern
from numbered
unpivot (
    cell for column_name in (columns(* exclude (row_order, "Name-additional")))
)
where row_order between 2 and 6
order by row_order
