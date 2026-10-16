-- One-line calibration summary per role, for comparing different settings.
-- "Good players" = projected 1.5+ WAR, the group the contract findings depend on.
-- rate_ratio and pt_ratio near 1.00 mean the projection is calibrated:
--   rate_ratio = actual WAR per full season / projected (below 1 = too optimistic on talent)
--   pt_ratio   = actual playing time / projected (below 1 = too optimistic on health/role)

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
        p.projected_war,
        p.projected_pt,
        p.projected_war >= 1.5                              as is_good,
        coalesce(a.war_total, 0)                            as actual_war,
        case when p.role = 'hitter' then coalesce(a.pa, 0)
             else coalesce(a.ip, 0) end                     as actual_pt
    from projections as p
    left join actual as a
        on p.player_id = a.player_id
       and p.target_season = a.season
)

select
    role,
    round(avg(abs(actual_war - projected_war)), 3)                      as avg_miss_all,
    round(
        (sum(case when is_good then actual_war end) / sum(case when is_good then actual_pt end))
        / (sum(case when is_good then projected_war end) / sum(case when is_good then projected_pt end)),
        3
    )                                                                   as rate_ratio_good,
    round(sum(case when is_good then actual_pt end)
          / sum(case when is_good then projected_pt end), 3)            as pt_ratio_good,
    round(avg(case when is_good then actual_war - projected_war end), 2) as war_bias_good
from scored
group by role
order by role