-- One row per player per season the Yankees control him after 2026 (through 2032):
-- guaranteed contract years, arbitration years, and pre-arbitration years.
-- Same projection logic as the contract model, extended to the whole roster:
--   rate:      2027 Marcel projection per full season, minus 0.5 WAR a year once he's past 30
--   expected:  established players (3+ years of service) use their durability over the last
--              three seasons; younger players use Marcel's playing-time estimate, because a
--              short season for them usually means a mid-season call-up, not an injury
--   full:      a full season every year
-- Cost: guaranteed years use the contract, pre-arb years the league minimum, and
-- arbitration years a share of his projected value (arbitration pays a fraction of
-- what he'd get as a free agent), never less than the minimum.

with control as (
    select
        player_id,
        season,
        salary_type,
        salary_usd,
        cell_note is not null as is_buyout_only
    from {{ ref('stg_nyy_salaries') }}
    where season > 2026
      and salary_type in ('guaranteed', 'arb_estimate', 'arb_unknown', 'pre_arb')
),

players as (
    select player_id, player_name, service_time_seasons
    from {{ ref('stg_nyy_contracts') }}
),

projection_2027 as (
    select
        player_id,
        age_at_target                 as age_2027,
        projected_war_per_full_season as rate_2027,
        weighted_availability,
        marcel_availability
    from {{ ref('int_marcel_projections') }}
    where target_season = 2027
),

cash as (
    select player_name, season, sum(amount_usd) as cash_usd
    from {{ ref('stg_nyy_dead_money') }}
    group by player_name, season
),

seasons as (
    select
        c.*,
        p.player_name,
        p.service_time_seasons,
        pr.player_id is not null as has_projection,
        case
            when p.service_time_seasons < 3 then pr.marcel_availability
            else pr.weighted_availability
        end as expected_availability,
        case
            when c.is_buyout_only then 0
            else greatest(
                pr.rate_2027 - {{ var('war_decline_per_year') }}
                    * greatest(least(c.season - 2027, pr.age_2027 + (c.season - 2027) - 30), 0),
                0
            )
        end as war_per_full_season,
        case
            when c.salary_type = 'guaranteed'   then c.salary_usd + coalesce(k.cash_usd, 0)
            when c.salary_type = 'arb_estimate' then c.salary_usd
            when c.salary_type = 'pre_arb'      then {{ var('pre_arb_salary') }}
        end as fixed_cost_usd
    from control as c
    inner join players as p on c.player_id = p.player_id
    left join projection_2027 as pr on c.player_id = pr.player_id
    left join cash as k on p.player_name = k.player_name and c.season = k.season
),

with_war as (
    select
        *,
        round(war_per_full_season * expected_availability, 2) as expected_war,
        war_per_full_season                                   as full_season_war
    from seasons
)

select
    player_id || '-' || season as control_season_key,
    player_id,
    player_name,
    season,
    salary_type,
    is_buyout_only,
    has_projection,
    expected_availability,
    war_per_full_season,
    expected_war,
    full_season_war,
    coalesce(
        fixed_cost_usd,
        greatest({{ var('arb_share_of_value') }} * expected_war * {{ var('dollars_per_war_base') }}, {{ var('pre_arb_salary') }})
    ) as expected_cost_usd,
    {% for level in ['low', 'base', 'high'] %}
    expected_war * {{ var('dollars_per_war_' ~ level) }} - coalesce(
        fixed_cost_usd,
        greatest({{ var('arb_share_of_value') }} * expected_war * {{ var('dollars_per_war_' ~ level) }}, {{ var('pre_arb_salary') }})
    ) as surplus_expected_{{ level }}_usd,
    {% endfor %}
    full_season_war * {{ var('dollars_per_war_base') }} - coalesce(
        fixed_cost_usd,
        greatest({{ var('arb_share_of_value') }} * full_season_war * {{ var('dollars_per_war_base') }}, {{ var('pre_arb_salary') }})
    ) as surplus_full_season_base_usd
from with_war