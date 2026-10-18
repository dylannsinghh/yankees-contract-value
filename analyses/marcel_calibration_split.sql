-- Players who play still come in under projection. Is it because they play LESS than
-- projected (playing time), or play WORSE than projected (rate)?
-- Compares projected vs actual playing time, and projected vs actual WAR per full season,
-- by projected tier. Playing time is PA for hitters, innings for pitchers.
-- Rates are totals divided by totals (sum of WAR / sum of playing time), so a player
-- with 30 innings can't swing the average as much as one with 200.

with projections as (
    select player_id, target_season, role, projected_war, projected_pt
    from {{ ref('int_marcel_projections') }}
    where target_season between 2023 and 2026
),

actual as (
    select
        player_id,
        season,
        war_total,
        coalesce(plate_appearances, 0) as pa,
        coalesce(innings_pitched, 0)   as ip
    from {{ ref('int_player_seasons') }}
),

scored as (
    select
        p.role,
        case
            when p.projected_war >= 3   then 'a: 3+ WAR'
            when p.projected_war >= 1.5 then 'b: 1.5 to 3'
            when p.projected_war >= 0.5 then 'c: 0.5 to 1.5'
            else 'd: under 0.5'
        end                                                     as projected_tier,
        p.projected_war,
        p.projected_pt,
        coalesce(a.war_total, 0)                                as actual_war,
        case when p.role = 'hitter' then coalesce(a.pa, 0)
             else coalesce(a.ip, 0) end                         as actual_pt,
        case when p.role = 'hitter' then 600 else 180 end       as scale
    from projections as p
    left join actual as a
        on p.player_id = a.player_id
       and p.target_season = a.season
)

select
    role,
    projected_tier,
    round(avg(projected_pt))                                         as avg_projected_pt,
    round(avg(actual_pt))                                            as avg_actual_pt,
    round(sum(projected_war) / nullif(sum(projected_pt), 0) * max(scale), 2) as projected_rate,
    round(sum(actual_war) / nullif(sum(actual_pt), 0) * max(scale), 2)       as actual_rate
from scored
group by all
order by 1, 2