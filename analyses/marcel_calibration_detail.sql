-- Why does the projection run high? Two possible reasons:
--   1. Attrition: the player didn't play at all (injury, demotion, retirement), so he gave 0.
--   2. Performance: he played, but produced less than projected.
-- This splits the backtest misses into those two pieces, by projected tier.

with projections as (
    select player_id, target_season, role, projected_war
    from {{ ref('int_marcel_projections') }}
    where target_season between 2023 and 2026
),

actual as (
    select player_id, season, war_total
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
        end                       as projected_tier,
        p.projected_war,
        a.war_total               as actual_war,
        a.war_total is null       as did_not_play
    from projections as p
    left join actual as a
        on p.player_id = a.player_id
       and p.target_season = a.season
)

select
    role,
    projected_tier,
    round(avg(case when did_not_play then 1.0 else 0.0 end), 3)       as share_did_not_play,
    round(avg(projected_war), 2)                                        as avg_projected,
    round(avg(case when not did_not_play then actual_war end), 2)       as avg_actual_if_played,
    round(avg(case when not did_not_play then actual_war - projected_war end), 2) as if_played_minus_proj
from scored
group by all
order by 1, 2