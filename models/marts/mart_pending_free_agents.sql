-- Players who played for the Yankees in 2026 and become free agents this winter.
-- For each: what he did in 2026, what he's projected to do in 2027, and what that's
-- worth for one season at $9.5M per WAR. It answers "re-sign or replace?" in dollars.

with controlled_2027 as (
    select distinct player_id
    from {{ ref('int_roster_control_seasons') }}
    where season = 2027
),

departing as (
    select s.*
    from {{ ref('mart_2026_snapshot') }} as s
    left join controlled_2027 as c on s.player_id = c.player_id
    where s.played_for_nyy
      and c.player_id is null
),

projection as (
    select
        player_id,
        age_at_target,
        projected_war,
        projected_war_per_full_season,
        reliability
    from {{ ref('int_marcel_projections') }}
    where target_season = 2027
)

select
    d.player_id,
    d.player_name,
    d.role,
    p.age_at_target                                        as age_2027,
    d.war_nyy                                              as war_2026,
    d.war_per_full_season                                  as rate_2026,
    d.share_of_full_season                                 as availability_2026,
    round(d.cost_2026_usd / 1e6, 1)                        as paid_2026_m,
    p.projected_war                                        as projected_war_2027,
    p.projected_war_per_full_season                        as projected_rate_2027,
    p.reliability,
    round(p.projected_war * {{ var('dollars_per_war_base') }} / 1e6, 1) as worth_2027_m,
    case
        when p.projected_war is null then 'No projection'
        when p.projected_war_per_full_season >= 2 and d.share_of_full_season < 0.6
            then 'Buy-low: good rate, limited 2026 playing time'
        when p.projected_war >= 2   then 'Regular-caliber'
        when p.projected_war >= 0.5 then 'Role player'
        else 'Replacement level'
    end                                                    as profile
from departing as d
left join projection as p on d.player_id = p.player_id