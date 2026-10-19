{{ config(materialized='external', location='exports/dashboard_kpis.csv') }}

-- The four headline numbers for the top of the dashboard, as one row with one column each,
-- so each Tableau tile is a single field.

with outlook as (
    select * from {{ ref('mart_2027_outlook') }}
),

bullpen as (
    select needed - covered as innings_open
    from {{ ref('mart_2027_position_depth') }}
    where position = 'RP'
)

select
    max(case when metric like '2027 projected wins before%' then value end)    as wins_before_moves,
    max(case when metric = 'Wins to add to reach 95' then value end)           as wins_to_reach_95,
    arg_max(value, sort_order) filter (where metric like 'Cost of those wins%') as cost_to_reach_95_m,
    (select innings_open from bullpen)                                         as bullpen_innings_open
from outlook