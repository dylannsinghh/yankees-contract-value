{{ config(materialized='external', location='exports/player_summary.csv') }}

-- The plain-English player table for Tableau: worth, cost, verdict, and why.
-- Dollars are in millions per season.

select
    player_name,
    position,
    status,
    worth_per_season_m,
    cost_per_season_m,
    value_per_season_m,
    verdict,
    why
from {{ ref('mart_player_summary') }}
order by section_order, value_per_season_m desc nulls last, worth_per_season_m desc
