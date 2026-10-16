-- One row per multi-year Yankees contract: what it has returned so far
-- (WAR as a Yankee during the contract) vs what it has cost so far.
-- Cost basis:
--   free agents: actual dollars, = contract total minus what's still owed after 2026,
--                minus the 2020 pay cut, plus any trade cash. This matches the
--                remaining-value model, so the two can be added together.
--   trade acquisitions: AAV for each season as a Yankee (the contract total includes
--                years with his old team, so the subtraction doesn't work).

with seasons as (
    select
        *,
        contract_aav_usd * coalesce(nyy_share, 1) * season_pay_factor + cash_usd as season_cost_aav_usd,
        contract_aav_usd * (1 - season_pay_factor)                             as shortened_season_cut_usd
    from {{ ref('int_contract_seasons') }}
),

totals as (
    select
        player_id,
        count(*)                       as seasons_as_yankee,
        sum(case when nyy_war = 0 and teams is null then 1 else 0 end) as seasons_missed,
        round(sum(nyy_war), 2)         as war_to_date,
        sum(season_cost_aav_usd)       as cost_to_date_aav_usd,
        sum(shortened_season_cut_usd)  as shortened_season_cut_usd,
        sum(cash_usd)                  as cash_to_date_usd
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
),

costed as (
    select
        c.*,
        t.seasons_as_yankee,
        t.seasons_missed,
        t.war_to_date,
        coalesce(r.remaining_guaranteed_usd, 0) as remaining_guaranteed_usd,
        case
            when c.acquired = 'Free Agency'
                then c.contract_total_usd - coalesce(r.remaining_guaranteed_usd, 0)
                     - t.shortened_season_cut_usd + t.cash_to_date_usd
            else t.cost_to_date_aav_usd
        end as cost_to_date_usd,
        case
            when c.acquired = 'Free Agency' then 'actual dollars'
            else 'AAV estimate'
        end as cost_basis
    from {{ ref('stg_nyy_contracts') }} as c
    inner join totals as t on c.player_id = t.player_id
    left join remaining as r on c.player_id = r.player_id
)

select
    player_id,
    player_name,
    age,
    contract_status_raw,
    contract_years,
    contract_total_usd,
    contract_aav_usd,
    contract_start_season,
    contract_end_season,
    has_option,
    seasons_as_yankee,
    seasons_missed,
    war_to_date,
    cost_basis,
    round(cost_to_date_usd)                                                   as cost_to_date_usd,
    case when war_to_date > 0 then round(cost_to_date_usd / war_to_date) end  as cost_per_war_usd,
    round(war_to_date * {{ var('dollars_per_war_low') }}  - cost_to_date_usd) as surplus_to_date_low_usd,
    round(war_to_date * {{ var('dollars_per_war_base') }} - cost_to_date_usd) as surplus_to_date_base_usd,
    round(war_to_date * {{ var('dollars_per_war_high') }} - cost_to_date_usd) as surplus_to_date_high_usd,
    contract_end_season - 2026                                                as seasons_remaining,
    remaining_guaranteed_usd
from costed