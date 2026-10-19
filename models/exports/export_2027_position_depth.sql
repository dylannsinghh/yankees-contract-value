{{ config(materialized='external', location='exports/position_depth_2027.csv') }}

-- 2027 depth by position for Tableau: how much of each position's playing time the
-- players the Yankees control can cover, how good they are there, and who they are.

select
    position,
    unit,
    needed,
    covered,
    coverage,
    projected_war,
    war_if_full_time,
    status,
    main_players,
    sort_order
from {{ ref('mart_2027_position_depth') }}
where position <> 'Unassigned'
order by sort_order