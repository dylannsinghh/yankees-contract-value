{{ config(materialized='external', location='exports/contract_value.csv') }}

-- One row per multi-year contract: value so far, value still ahead, and the full contract.
-- Surplus is at the base case ($9.5M per WAR), dollars in millions.

select
    r.player_name,
    r.contract_status_raw                              as contract,
    r.cost_basis,
    r.seasons_as_yankee,
    r.war_to_date,
    round(r.cost_to_date_usd / 1e6, 1)                 as cost_so_far_m,
    round(r.surplus_to_date_base_usd / 1e6, 1)         as surplus_so_far_m,
    coalesce(v.seasons_owed, 0)                        as seasons_owed,
    round(coalesce(v.remaining_cost_usd, 0) / 1e6, 1)  as still_owed_m,
    v.expected_availability,
    coalesce(v.expected_war, 0)                        as war_ahead_expected,
    coalesce(v.healthy_war, 0)                         as war_ahead_healthy,
    round(coalesce(v.surplus_expected_base_usd, 0) / 1e6, 1) as surplus_ahead_expected_m,
    round(coalesce(v.surplus_healthy_base_usd, 0) / 1e6, 1)  as surplus_ahead_healthy_m,
    round((r.surplus_to_date_base_usd + coalesce(v.surplus_expected_base_usd, 0)) / 1e6, 1) as surplus_whole_expected_m,
    round((r.surplus_to_date_base_usd + coalesce(v.surplus_healthy_base_usd, 0)) / 1e6, 1)  as surplus_whole_healthy_m
from {{ ref('mart_contract_retrospective') }} as r
left join {{ ref('mart_remaining_value') }} as v
    on r.player_id = v.player_id