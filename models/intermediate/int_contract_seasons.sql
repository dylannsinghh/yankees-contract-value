-- One row per multi-year contract per season the player has been a Yankee under it,
-- through 2026. Cost uses the contract's average annual value (AAV), the same way
-- MLB's luxury tax counts contracts, because salaries before 2026 aren't in our data.

with contracts as (
    select *
    from {{ ref('stg_nyy_contracts') }}
    where contract_years >= 3
      and contract_start_season <= 2026
),

nyy_stints as (
    select player_id, season, plate_appearances, null as innings_pitched, war
    from {{ ref('stg_war_batting') }}
    where team = 'NYY'
    union all
    select player_id, season, null, innings_pitched, war
    from {{ ref('stg_war_pitching') }}
    where team = 'NYY'
),

nyy_seasons as (
    select
        player_id,
        season,
        sum(plate_appearances) as nyy_plate_appearances,
        sum(innings_pitched)   as nyy_innings_pitched,
        sum(war)               as nyy_war
    from nyy_stints
    group by player_id, season
),

first_nyy as (
    select
        c.player_id,
        min(n.season) as first_nyy_season
    from contracts as c
    inner join nyy_seasons as n
        on c.player_id = n.player_id
       and n.season between c.contract_start_season and c.contract_end_season
    group by c.player_id
),

spine as (
    -- Free agents were Yankees from day one of the contract. Players acquired by trade
    -- start counting the first season they played for the Yankees under it.
    select
        c.*,
        unnest(generate_series(
            case
                when c.acquired = 'Free Agency' then c.contract_start_season
                else coalesce(f.first_nyy_season, c.contract_start_season)
            end,
            least(c.contract_end_season, 2026)
        )) as season
    from contracts as c
    left join first_nyy as f on c.player_id = f.player_id
),

cash as (
    select player_name, season, sum(amount_usd) as cash_usd
    from {{ ref('stg_nyy_dead_money') }}
    group by player_name, season
)

select
    s.player_id || '-' || s.season as contract_season_key,
    s.player_id,
    s.player_name,
    s.contract_status_raw,
    s.contract_aav_usd,
    s.season,
    ps.teams,
    coalesce(n.nyy_war, 0) as nyy_war,
    case
        when ps.player_id is null then 1
        when ps.teams = 'NYY' then 1
        when ps.primary_role = 'hitter'
            then n.nyy_plate_appearances / nullif(ps.plate_appearances, 0)
        else n.nyy_innings_pitched / nullif(ps.innings_pitched, 0)
    end as nyy_share,
    case when s.season = 2020 then 60 / 162.0 else 1.0 end as season_pay_factor,
    coalesce(c.cash_usd, 0) as cash_usd
from spine as s
left join nyy_seasons as n
    on s.player_id = n.player_id and s.season = n.season
left join {{ ref('int_player_seasons') }} as ps
    on s.player_id = ps.player_id and s.season = ps.season
left join cash as c
    on s.player_name = c.player_name and s.season = c.season