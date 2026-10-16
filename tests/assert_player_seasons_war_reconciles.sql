-- Combining batting and pitching shouldn't create or lose any WAR.
-- Total WAR per season in int_player_seasons must equal batting WAR + pitching WAR
-- from staging. Returns any season that's off by more than 0.01 WAR.

with staging_totals as (
    select season, sum(war) as war
    from (
        select season, war from {{ ref('stg_war_batting') }}
        union all
        select season, war from {{ ref('stg_war_pitching') }}
    )
    group by season
),

combined_totals as (
    select season, sum(war_total) as war
    from {{ ref('int_player_seasons') }}
    group by season
)

select
    s.season,
    s.war as staging_war,
    c.war as combined_war
from staging_totals as s
full outer join combined_totals as c
    on s.season = c.season
where abs(coalesce(s.war, 0) - coalesce(c.war, 0)) > 0.01