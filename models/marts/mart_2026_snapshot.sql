-- One row per player on the 2026 Yankees payroll:
-- what he cost, what he produced for the Yankees, and how much of that came from
-- rate (how good he was when he played) vs availability (how much he played).

with payroll as (
    select
        c.player_id,
        c.player_name,
        c.age,
        c.service_time_seasons,
        s.salary_type,
        s.salary_usd,
        s.is_estimated
    from {{ ref('stg_nyy_contracts') }} as c
    inner join {{ ref('stg_nyy_salaries') }} as s
        on c.player_id = s.player_id
       and s.season = 2026
    where s.salary_type in ('guaranteed', 'arb_estimate', 'pre_arb')
),

cash_adjustments as (
    -- Trade cash tied to a player still on the roster changes his real cost.
    -- Dead money for players who are gone won't match anyone here, which is correct.
    select
        player_name,
        sum(amount_usd) as adjustment_usd
    from {{ ref('stg_nyy_dead_money') }}
    where season = 2026
    group by player_name
),

nyy_batting as (
    select
        player_id,
        sum(plate_appearances) as plate_appearances,
        sum(games)             as games_batting,
        sum(war)               as war_batting
    from {{ ref('stg_war_batting') }}
    where season = 2026 and team = 'NYY'
    group by player_id
),

nyy_pitching as (
    select
        player_id,
        sum(games)               as games_pitching,
        sum(games_started)       as games_started,
        sum(outs_recorded) / 3.0 as innings_pitched,
        sum(war)                 as war_pitching
    from {{ ref('stg_war_pitching') }}
    where season = 2026 and team = 'NYY'
    group by player_id
),

all_teams as (
    -- His full 2026 season with every team, used to prorate split seasons.
    select
        player_id,
        teams,
        plate_appearances as total_plate_appearances,
        innings_pitched   as total_innings_pitched
    from {{ ref('int_player_seasons') }}
    where season = 2026
),

joined as (
    select
        p.*,
        coalesce(a.adjustment_usd, 0) as cash_adjustment_usd,
        b.plate_appearances,
        b.games_batting,
        pt.games_pitching,
        pt.games_started,
        pt.innings_pitched,
        b.war_batting,
        pt.war_pitching,
        t.teams as teams_2026,
        t.total_plate_appearances,
        t.total_innings_pitched,
        b.player_id is not null or pt.player_id is not null as played_for_nyy
    from payroll as p
    left join cash_adjustments as a on p.player_name = a.player_name
    left join nyy_batting      as b  on p.player_id = b.player_id
    left join nyy_pitching     as pt on p.player_id = pt.player_id
    left join all_teams        as t  on p.player_id = t.player_id
),

with_role as (
    select
        *,
        case
            when war_batting is null and war_pitching is null then null
            else coalesce(war_batting, 0) + coalesce(war_pitching, 0)
        end as war_nyy,
        case
            when not played_for_nyy then null
            when coalesce(games_pitching, 0) >= coalesce(games_batting, 0) then
                case when games_started >= games_pitching / 2.0 then 'starter' else 'reliever' end
            else 'hitter'
        end as role
    from joined
),

with_playing_time as (
    select
        *,
        case role
            when 'hitter'   then plate_appearances / 600.0
            when 'starter'  then innings_pitched / 180.0
            when 'reliever' then innings_pitched / 65.0
        end as share_of_full_season,
        case
            when not played_for_nyy and teams_2026 is not null then 0
            when not played_for_nyy then null
            when teams_2026 = 'NYY' then 1
            when role = 'hitter' then plate_appearances / nullif(total_plate_appearances, 0)
            else innings_pitched / nullif(total_innings_pitched, 0)
        end as nyy_share_of_2026
    from with_role
),

with_cost as (
    select
        *,
        case
            when nyy_share_of_2026 is not null
                then salary_usd * nyy_share_of_2026 + cash_adjustment_usd
            when salary_type = 'guaranteed'
                then salary_usd + cash_adjustment_usd
        end as cost_2026_usd,
        case
            when not played_for_nyy and teams_2026 is not null
                then 'Joined after his 2026 games'
            when not played_for_nyy and salary_type = 'pre_arb'
                then 'No 2026 MLB games (pre-arb, likely in the minors)'
            when not played_for_nyy and salary_type = 'arb_estimate'
                then 'No 2026 MLB games (salary is an estimate)'
            when not played_for_nyy
                then 'No 2026 MLB games (paid to sit)'
        end as excluded_reason
    from with_playing_time
)

select
    player_id,
    player_name,
    age,
    service_time_seasons,
    role,
    teams_2026,
    coalesce(teams_2026 <> 'NYY', false)                  as split_season,
    played_for_nyy,
    excluded_reason,
    salary_type,
    is_estimated,
    salary_usd,
    cash_adjustment_usd,
    round(nyy_share_of_2026, 3)                           as nyy_share_of_2026,
    round(cost_2026_usd)                                  as cost_2026_usd,
    plate_appearances,
    round(innings_pitched, 1)                             as innings_pitched,
    war_nyy,
    round(share_of_full_season, 3)                        as share_of_full_season,
    round(war_nyy / nullif(share_of_full_season, 0), 2)   as war_per_full_season,
    coalesce(share_of_full_season, 0) < 0.2               as is_small_sample,
    case when war_nyy > 0 then round(cost_2026_usd / war_nyy) end as cost_per_war_usd,
    round(coalesce(war_nyy, 0) * {{ var('dollars_per_war_low') }}  - cost_2026_usd) as surplus_low_usd,
    round(coalesce(war_nyy, 0) * {{ var('dollars_per_war_base') }} - cost_2026_usd) as surplus_base_usd,
    round(coalesce(war_nyy, 0) * {{ var('dollars_per_war_high') }} - cost_2026_usd) as surplus_high_usd
from with_cost
