-- How good is the projection? Project 2025 using only 2022-2024, then compare it with
-- what actually happened in 2025. Benchmark: the naive guess "same WAR as last season."
-- Only players with real 2025 playing time count (300+ PA or 50+ innings).

with projections as (
    select player_id, role, projected_war
    from {{ ref('int_marcel_projections') }}
    where target_season = 2025
),

actual as (
    select player_id, war_total as actual_war, plate_appearances, innings_pitched
    from {{ ref('int_player_seasons') }}
    where season = 2025
),

last_season as (
    select player_id, war_total as last_war
    from {{ ref('int_player_seasons') }}
    where season = 2024
),

scored as (
    select
        p.role,
        p.projected_war,
        a.actual_war,
        coalesce(l.last_war, 0) as naive_war
    from projections as p
    inner join actual as a on p.player_id = a.player_id
    left join last_season as l on p.player_id = l.player_id
    where a.actual_war is not null
      and (coalesce(a.plate_appearances, 0) >= 300 or coalesce(a.innings_pitched, 0) >= 50)
)

select
    role,
    count(*)                                          as players,
    round(avg(abs(projected_war - actual_war)), 2)    as marcel_avg_miss,
    round(avg(abs(naive_war - actual_war)), 2)        as naive_avg_miss,
    round(corr(projected_war, actual_war), 2)         as marcel_correlation,
    round(corr(naive_war, actual_war), 2)             as naive_correlation
from scored
group by role
order by role