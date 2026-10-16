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
    select player_id, teams
    from {{ ref('int_player_seasons') }}
    where season = 2026
),

joined as (
    select
        p.*,
        coalesce(a.adjustment_usd, 0)                as cash_adjustment_usd,
        p.salary_usd + coalesce(a.adjustment_usd, 0) as net_cost_usd,
        b.plate_appearances,
        b.games_batting,
        pt.games_pitching,
        pt.games_started,
        pt.innings_pitched,
        b.war_batting,
        pt.war_pitching,
        t.teams as teams_2026
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
            when coalesce(games_pitching, 0) = 0 and coalesce(games_batting, 0) = 0 then null
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
        end as share_of_full_season
    from with_role
)

select
    player_id,
    player_name,
    age,
    service_time_seasons,
    role,
    teams_2026,
    coalesce(teams_2026 <> 'NYY', false)                  as split_season,
    salary_type,
    is_estimated,
    salary_usd,
    cash_adjustment_usd,
    net_cost_usd,
    plate_appearances,
    round(innings_pitched, 1)                             as innings_pitched,
    war_nyy,
    round(share_of_full_season, 3)                        as share_of_full_season,
    round(war_nyy / nullif(share_of_full_season, 0), 2)   as war_per_full_season,
    coalesce(share_of_full_season, 0) < 0.2               as is_small_sample,
    case when war_nyy > 0 then round(net_cost_usd / war_nyy) end as cost_per_war_usd,
    round(coalesce(war_nyy, 0) * {{ var('dollars_per_war_low') }}  - net_cost_usd) as surplus_low_usd,
    round(coalesce(war_nyy, 0) * {{ var('dollars_per_war_base') }} - net_cost_usd) as surplus_base_usd,
    round(coalesce(war_nyy, 0) * {{ var('dollars_per_war_high') }} - net_cost_usd) as surplus_high_usd
from with_playing_time