{{ config(materialized='external', location='exports/contract_war_by_season.csv') }}

-- Year-by-year WAR for each multi-year contract: actual through 2026, projected after.
-- Actual seasons repeat the same WAR in both columns so the lines connect in Tableau.

select
    player_name,
    season,
    'Actual'  as phase,
    nyy_war   as war_expected,
    nyy_war   as war_healthy
from {{ ref('int_contract_seasons') }}

union all

-- Repeat 2026 as the first point of the projected line, so the two lines meet.
select
    player_name,
    season,
    'Projected' as phase,
    nyy_war,
    nyy_war
from {{ ref('int_contract_seasons') }}
where season = 2026

union all

select
    player_name,
    season,
    'Projected' as phase,
    expected_war,
    healthy_war
from {{ ref('int_remaining_contract_seasons') }}