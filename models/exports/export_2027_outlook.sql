{{ config(materialized='external', location='exports/outlook_2027.csv') }}

-- The 2027 outlook in plain words, for the dashboard's headline numbers.

select
    sort_order,
    metric,
    value
from {{ ref('mart_2027_outlook') }}
order by sort_order