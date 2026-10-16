-- One row per player the Yankees control after 2026: how many years, what kind,
-- and the projected value of those years vs what they're projected to cost.

with seasons as (
    select * from {{ ref('int_roster_control_seasons') }}
)

select
    player_id,
    max(player_name)                                              as player_name,
    count(*)                                                      as seasons_controlled,
    max(season)                                                   as controlled_through,
    sum(case when salary_type = 'guaranteed' then 1 else 0 end)   as guaranteed_seasons,
    sum(case when salary_type in ('arb_unknown', 'arb_estimate') then 1 else 0 end) as arb_seasons,
    sum(case when salary_type = 'pre_arb' then 1 else 0 end)      as pre_arb_seasons,
    case when bool_and(has_projection) then null
         else 'No recent MLB track record to project' end         as excluded_reason,
    max(expected_availability)                                    as expected_availability,
    round(sum(expected_war), 2)                                   as expected_war,
    round(sum(full_season_war), 2)                                as full_season_war,
    round(sum(expected_cost_usd))                                 as expected_cost_usd,
    round(sum(surplus_expected_low_usd))                          as surplus_expected_low_usd,
    round(sum(surplus_expected_base_usd))                         as surplus_expected_base_usd,
    round(sum(surplus_expected_high_usd))                         as surplus_expected_high_usd,
    round(sum(surplus_full_season_base_usd))                      as surplus_full_season_base_usd
from seasons
group by player_id