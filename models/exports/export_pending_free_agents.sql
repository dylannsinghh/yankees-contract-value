{{ config(materialized='external', location='exports/pending_free_agents.csv') }}

-- Yankees heading to free agency this winter, for Tableau.

select
    player_name,
    role,
    age_2027,
    war_2026,
    rate_2026,
    availability_2026,
    paid_2026_m,
    projected_war_2027,
    projected_rate_2027,
    worth_2027_m,
    profile
from {{ ref('mart_pending_free_agents') }}