-- One row per multi-year contract per season still owed (2027 on).
-- Projected WAR starts from the 2027 Marcel projection and drops by a fixed amount
-- each later year (aging). Two cases:
--   expected: Marcel's playing time, which is conservative after an injury year
--   healthy:  a full season at his projected rate
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
        projected_war                 as expected_war_2027,
        projected_war_per_full_season as healthy_war_2027
    from {{ ref('int_marcel_projections') }}
    where target_season = 2027
)

select
    o.player_id || '-' || o.season as remaining_season_key,
    o.player_id,
    c.player_name,
    o.season,
    o.season - 2027                 as years_after_2027,
    o.is_buyout_only,
    o.salary_usd,
    coalesce(k.cash_usd, 0)         as cash_usd,
    o.salary_usd + coalesce(k.cash_usd, 0) as cost_usd,
    case
        when o.is_buyout_only then 0
        else greatest(p.expected_war_2027 - {{ var('war_decline_per_year') }} * (o.season - 2027), 0)
    end as expected_war,
    case
        when o.is_buyout_only then 0
        else greatest(p.healthy_war_2027 - {{ var('war_decline_per_year') }} * (o.season - 2027), 0)
    end as healthy_war
from owed as o
inner join contracts as c on o.player_id = c.player_id
left join projection_2027 as p on o.player_id = p.player_id
left join cash as k on c.player_name = k.player_name and o.season = k.season