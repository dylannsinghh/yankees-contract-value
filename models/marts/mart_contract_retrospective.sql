-- One row per multi-year Yankees contract: what it has returned so far
-- (WAR as a Yankee during the contract) vs what it has cost so far (AAV basis).

with seasons as (
    select
        *,
        contract_aav_usd * coalesce(nyy_share, 1) * season_pay_factor + cash_usd as season_cost_usd
    from {{ ref('int_contract_seasons') }}
),

totals as (
    select
        player_id,
        count(*)                  as seasons_as_yankee,
        sum(case when nyy_war = 0 and teams is null then 1 else 0 end) as seasons_missed,
        round(sum(nyy_war), 2)    as war_to_date,
        round(sum(season_cost_usd)) as cost_to_date_usd
    from seasons
    group by player_id
),

remaining as (
    select
        player_id,
        sum(salary_usd) as remaining_guaranteed_usd
    from {{ ref('stg_nyy_salaries') }}
    where season > 2026
      and salary_type = 'guaranteed'
    group by player_id
)

select
    c.player_id,
    c.player_name,
    c.age,
    c.contract_status_raw,
    c.contract_years,
    c.contract_total_usd,
    c.contract_aav_usd,
    c.contract_start_season,
    c.contract_end_season,
    c.has_option,
    t.seasons_as_yankee,
    t.seasons_missed,
    t.war_to_date,
    t.cost_to_date_usd,
    case when t.war_to_date > 0 then round(t.cost_to_date_usd / t.war_to_date) end as cost_per_war_usd,
    round(t.war_to_date * {{ var('dollars_per_war_low') }}  - t.cost_to_date_usd) as surplus_to_date_low_usd,
    round(t.war_to_date * {{ var('dollars_per_war_base') }} - t.cost_to_date_usd) as surplus_to_date_base_usd,
    round(t.war_to_date * {{ var('dollars_per_war_high') }} - t.cost_to_date_usd) as surplus_to_date_high_usd,
    c.contract_end_season - 2026                as seasons_remaining,
    coalesce(r.remaining_guaranteed_usd, 0)     as remaining_guaranteed_usd
from {{ ref('stg_nyy_contracts') }} as c
inner join totals as t on c.player_id = t.player_id
left join remaining as r on c.player_id = r.player_id