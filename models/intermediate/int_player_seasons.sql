-- One row per player per season, all teams combined.
-- Total WAR = batting WAR + pitching WAR, the same way B-Ref adds them up.

with batting as (
    select
        player_id,
        season,
        max(player_name)                    as player_name,
        sum(plate_appearances)              as plate_appearances,
        sum(games)                          as games_batting,
        sum(war)                            as war_batting,
        string_agg(team, '/' order by stint) as teams_batting
    from {{ ref('stg_war_batting') }}
    group by player_id, season
),

pitching as (
    select
        player_id,
        season,
        max(player_name)                    as player_name,
        sum(games)                          as games_pitching,
        sum(games_started)                  as games_started,
        sum(outs_recorded) / 3.0            as innings_pitched,
        sum(war)                            as war_pitching,
        string_agg(team, '/' order by stint) as teams_pitching
    from {{ ref('stg_war_pitching') }}
    group by player_id, season
),

combined as (
    select
        coalesce(b.player_id, p.player_id)     as player_id,
        coalesce(b.season, p.season)           as season,
        coalesce(b.player_name, p.player_name) as player_name,
        coalesce(b.teams_batting, p.teams_pitching) as teams,
        b.plate_appearances,
        b.games_batting,
        p.games_pitching,
        p.games_started,
        p.innings_pitched,
        b.war_batting,
        p.war_pitching
    from batting as b
    full outer join pitching as p
        on b.player_id = p.player_id
       and b.season = p.season
)

select
    player_id || '-' || season as player_season_key,
    player_id,
    season,
    player_name,
    teams,
    case
        when coalesce(games_pitching, 0) >= coalesce(games_batting, 0) then 'pitcher'
        else 'hitter'
    end as primary_role,
    plate_appearances,
    games_batting,
    games_pitching,
    games_started,
    innings_pitched,
    war_batting,
    war_pitching,
    case
        when war_batting is null and war_pitching is null then null
        else coalesce(war_batting, 0) + coalesce(war_pitching, 0)
    end as war_total
from combined