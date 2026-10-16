{{ config(materialized='external', location='exports/roster_value.csv') }}

-- Every player the Yankees control after 2026, for Tableau. Dollars in millions.
-- Totals = value of the whole asset (longer control is worth more).
-- Per season = how good a deal each year is (the fair way to compare players).

select
    player_name,
    seasons_controlled,
    controlled_through,
    guaranteed_seasons,
    arb_seasons,
    pre_arb_seasons,
    case
        when guaranteed_seasons > 0 then 'Multi-year contract'
        when arb_seasons > 0 and pre_arb_seasons = 0 then 'Arbitration'
        else 'Pre-arbitration'
    end                                             as control_type,
    excluded_reason,
    expected_availability,
    expected_war,
    full_season_war,
    round(expected_war / seasons_controlled, 2)     as expected_war_per_season,
    round(expected_cost_usd / 1e6, 1)               as expected_cost_m,
    round(surplus_expected_low_usd / 1e6, 1)        as surplus_expected_low_m,
    round(surplus_expected_base_usd / 1e6, 1)       as surplus_expected_base_m,
    round(surplus_expected_high_usd / 1e6, 1)       as surplus_expected_high_m,
    round(surplus_full_season_base_usd / 1e6, 1)    as surplus_full_season_base_m,
    round(surplus_expected_base_usd / seasons_controlled / 1e6, 1)    as surplus_per_season_m,
    round(surplus_full_season_base_usd / seasons_controlled / 1e6, 1) as surplus_full_season_per_season_m
from {{ ref('mart_roster_value') }}