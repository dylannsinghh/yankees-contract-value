-- Is the projection fair to every kind of player, or too harsh on stars?
-- Pools four backtests (project 2023, 2024, 2025, and 2026, each from the three seasons
-- before it), groups players by how good the projection said they'd be, and compares
-- the average projection with what actually happened.
-- Players who didn't play in the target season count as 0 WAR (that's what the team got).

with projections as (
    select player_id, target_season, role, projected_war
    from {{ ref('int_marcel_projections') }}
    where target_season between 2023 and 2026
),

actual as (
    select player_id, season, war_total
    from {{ ref('int_player_seasons') }}
)

select
    p.role,
    case
        when p.projected_war >= 3   then 'a: 3+ WAR'
        when p.projected_war >= 1.5 then 'b: 1.5 to 3'
        when p.projected_war >= 0.5 then 'c: 0.5 to 1.5'
        else 'd: under 0.5'
    end                                                       as projected_tier,
    count(*)                                                  as player_seasons,
    round(avg(p.projected_war), 2)                            as avg_projected,
    round(avg(coalesce(a.war_total, 0)), 2)                   as avg_actual,
    round(avg(coalesce(a.war_total, 0) - p.projected_war), 2) as actual_minus_proj
from projections as p
left join actual as a
    on p.player_id = a.player_id
   and p.target_season = a.season
group by all
order by 1, 2