-- One row per multi-year Yankees contract: projected value of the seasons still owed
-- vs the money still owed. Positive surplus = projected to be worth more than he's paid.

with seasons as (
    select * from {{ ref('int_remaining_contract_seasons') }}
),

totals as (
    select
        player_id,
        max(player_name)          as player_name,
        count(*)                  as seasons_owed,
        min(season)               as first_season,
        max(season)               as last_season,
        sum(cost_usd)             as remaining_cost_usd,
        round(sum(expected_war), 2) as expected_war,
        round(sum(healthy_war), 2)  as healthy_war
    from seasons
    group by player_id
)

select
    player_id,
    player_name,
    seasons_owed,
    first_season,
    last_season,
    remaining_cost_usd,
    expected_war,
    healthy_war,
    round(expected_war * {{ var('dollars_per_war_low') }}  - remaining_cost_usd) as surplus_expected_low_usd,
    round(expected_war * {{ var('dollars_per_war_base') }} - remaining_cost_usd) as surplus_expected_base_usd,
    round(expected_war * {{ var('dollars_per_war_high') }} - remaining_cost_usd) as surplus_expected_high_usd,
    round(healthy_war  * {{ var('dollars_per_war_base') }} - remaining_cost_usd) as surplus_healthy_base_usd,
    round(remaining_cost_usd / nullif(expected_war, 0)) as cost_per_expected_war_usd
from totals