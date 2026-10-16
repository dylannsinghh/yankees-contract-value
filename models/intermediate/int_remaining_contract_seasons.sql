-- One row per multi-year contract per season still owed (2027 on).
-- Rate: his 2027 Marcel projection per full season, minus a fixed aging decline each
-- later year. Playing time, two cases:
--   expected: his durability over the last three seasons (weighted share of a full
--             season played, a missed season counts as 0)
--   healthy:  a full season every year
-- Marcel's own playing-time rule is built for one season ahead, so it isn't carried
-- across a multi-year contract.
-- Money is in 2026 dollars. Rising $/WAR and the time value of money roughly
-- cancel out, so neither is applied.

with contracts as (
    select player_id, player_name
    from {{ ref('mart_contract_retrospective') }}
),

owed as (
    select
        s.player_id,
        s.season,
        s.salary_usd,
        s.cell_note is not null as is_buyout_only
    from {{ ref('stg_nyy_salaries') }} as s
    inner join contracts as c on s.player_id = c.player_id
    where s.season > 2026
      and s.salary_type = 'guaranteed'
),

cash as (
    select player_name, season, sum(amount_usd) as cash_usd
    from {{ ref('stg_nyy_dead_money') }}
    group by player_name, season
),

projection_2027 as (
    select
        player_id,
        projected_war_per_full_season as rate_2027,
        weighted_availability
    from {{ ref('int_marcel_projections') }}
    where target_season = 2027
),

seasons as (
    select
        o.*,
        c.player_name,
        coalesce(k.cash_usd, 0) as cash_usd,
        p.weighted_availability,
        case
            when o.is_buyout_only then 0
            else greatest(p.rate_2027 - {{ var('war_decline_per_year') }} * (o.season - 2027), 0)
        end as war_per_full_season
    from owed as o
    inner join contracts as c on o.player_id = c.player_id
    left join projection_2027 as p on o.player_id = p.player_id
    left join cash as k on c.player_name = k.player_name and o.season = k.season
)

select
    player_id || '-' || season         as remaining_season_key,
    player_id,
    player_name,
    season,
    season - 2027                      as years_after_2027,
    is_buyout_only,
    salary_usd,
    cash_usd,
    salary_usd + cash_usd              as cost_usd,
    war_per_full_season,
    weighted_availability              as expected_availability,
    round(war_per_full_season * weighted_availability, 2) as expected_war,
    war_per_full_season                as healthy_war
from seasons