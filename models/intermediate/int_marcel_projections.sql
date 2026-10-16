-- Marcel-style WAR projection: one row per player per target season (2022-2027).
-- Based on Tom Tango's Marcel method, applied to WAR. It's a fixed formula: weight the
-- last three seasons (most recent counts most), pull the result toward league average,
-- adjust for age, then multiply by projected playing time.
-- Calibrated against 2023-2026 backtests (analyses/marcel_calibration_summary.sql):
-- WAR is noisier than the batting stats Marcel was built for, so it gets more regression
-- (3,600 PA / 720 IP instead of 1,200 / 180), and pitchers threw about 80% of the
-- innings the original formula expected, so pitcher playing time is scaled by 0.8.

{% set first_target = 2022 %}
{% set last_target = 2027 %}

with player_seasons as (
    select
        player_id,
        player_name,
        season,
        age,
        primary_role,
        coalesce(plate_appearances, 0) as pa,
        coalesce(innings_pitched, 0)   as ip,
        coalesce(games_pitching, 0)    as games_pitching,
        coalesce(games_started, 0)     as games_started,
        coalesce(war_total, 0)         as war
    from {{ ref('int_player_seasons') }}
    where season between {{ first_target - 3 }} and {{ last_target - 1 }}
),

contributions as (
    -- Each season feeds the next three target seasons (1, 2, and 3 years ahead).
    -- A missed season simply contributes nothing, instead of LAG() quietly
    -- treating an older season as "last year".
    select
        s.*,
        s.season + k.years_back as target_season,
        k.years_back
    from player_seasons as s
    cross join (values (1), (2), (3)) as k(years_back)
    where s.season + k.years_back between {{ first_target }} and {{ last_target }}
),

latest as (
    -- His most recent season before the target decides role, age, and starter share.
    select
        player_id,
        target_season,
        arg_min(primary_role, years_back)    as role,
        arg_min(age + years_back, years_back) as age_at_target,
        arg_min(
            case when games_pitching > 0 then games_started / games_pitching::double else 0 end,
            years_back
        ) as start_share
    from contributions
    group by player_id, target_season
),

weighted as (
    -- Hitters: weights 5/4/3, playing time in PA. Pitchers: weights 3/2/1, in innings.
    select
        c.player_id,
        c.target_season,
        l.role,
        l.age_at_target,
        l.start_share,
        max(c.player_name) as player_name,
        sum(case when l.role = 'hitter' then 6 - c.years_back else 4 - c.years_back end * c.war) as weighted_war,
        sum(case when l.role = 'hitter' then (6 - c.years_back) * c.pa else (4 - c.years_back) * c.ip end) as weighted_pt,
        sum(case when c.years_back = 1 then case when l.role = 'hitter' then c.pa else c.ip end else 0 end) as pt_last_season,
        sum(case when c.years_back = 2 then case when l.role = 'hitter' then c.pa else c.ip end else 0 end) as pt_two_seasons_ago,
        -- Durability: share of a full season played in each of the last three seasons
        -- (capped at 1), with the same weights. A missed season counts as 0.
        sum(
            case when l.role = 'hitter' then 6 - c.years_back else 4 - c.years_back end
            * least(
                case
                    when l.role = 'hitter'      then c.pa / 600.0
                    when l.start_share >= 0.5   then c.ip / 180.0
                    else c.ip / 65.0
                end,
                1
            )
        ) / case when l.role = 'hitter' then 12.0 else 6.0 end as weighted_availability
    from contributions as c
    inner join latest as l
        on c.player_id = l.player_id
       and c.target_season = l.target_season
    group by c.player_id, c.target_season, l.role, l.age_at_target, l.start_share
),

league_rates as (
    -- League-average WAR per PA (hitters) and per inning (pitchers) over the same three seasons.
    select
        target_season,
        sum(case when primary_role = 'hitter' then war end)
            / nullif(sum(case when primary_role = 'hitter' then pa end), 0) as hitter_war_per_pa,
        sum(case when primary_role = 'pitcher' then war end)
            / nullif(sum(case when primary_role = 'pitcher' then ip end), 0) as pitcher_war_per_ip
    from contributions
    group by target_season
),

inputs as (
    select
        w.*,
        case when w.role = 'hitter' then {{ var('marcel_regression_pa') }}
             else {{ var('marcel_regression_ip') }} end as regression_pt,
        case when w.role = 'hitter' then r.hitter_war_per_pa
             else r.pitcher_war_per_ip end as league_rate,
        case
            when w.age_at_target < 29 then 1 + (29 - w.age_at_target) * 0.006
            else 1 + (29 - w.age_at_target) * 0.003
        end as age_factor,
        case
            when w.role = 'hitter' then 0.5 * w.pt_last_season + 0.1 * w.pt_two_seasons_ago + 200
            else (0.5 * w.pt_last_season + 0.1 * w.pt_two_seasons_ago + 25 + 35 * w.start_share)
                 * {{ var('marcel_pitcher_pt_factor') }}
        end as projected_pt,
        case
            when w.role = 'hitter' then 600
            when w.start_share >= 0.5 then 180
            else 65
        end as full_season_pt
    from weighted as w
    inner join league_rates as r
        on w.target_season = r.target_season
),

projected as (
    select
        *,
        (weighted_war + regression_pt * league_rate) / (weighted_pt + regression_pt) * age_factor
            as projected_war_per_pt
    from inputs
)

select
    player_id || '-' || target_season               as projection_key,
    player_id,
    player_name,
    target_season,
    role,
    age_at_target,
    round(weighted_pt)                              as weighted_pt,
    round(weighted_pt / (weighted_pt + regression_pt), 3) as reliability,
    round(age_factor, 3)                            as age_factor,
    round(projected_pt, 1)                          as projected_pt,
    round(weighted_availability, 3)                 as weighted_availability,
    round(least(projected_pt / full_season_pt, 1), 3) as marcel_availability,
    round(projected_war_per_pt * full_season_pt, 2) as projected_war_per_full_season,
    round(projected_war_per_pt * projected_pt, 2)   as projected_war
from projected