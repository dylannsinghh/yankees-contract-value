{{ config(materialized='external', location='exports/snapshot_2026.csv') }}

-- 2026 snapshot for Tableau: everyone who played for the Yankees, dollars in millions.

select
    player_name,
    role,
    salary_type,
    split_season,
    is_small_sample,
    round(cost_2026_usd / 1e6, 2)    as cost_2026_m,
    war_nyy,
    share_of_full_season             as availability,
    war_per_full_season              as rate,
    round(surplus_low_usd / 1e6, 2)  as surplus_low_m,
    round(surplus_base_usd / 1e6, 2) as surplus_base_m,
    round(surplus_high_usd / 1e6, 2) as surplus_high_m
from {{ ref('mart_2026_snapshot') }}
where excluded_reason is null