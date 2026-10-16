-- One row per player on the 2026 Yankees contracts page.
-- B-Ref's non-player rows (blank spacers, payroll totals, dead money notes)
-- all use -9999 as their player ID, so filtering on it removes them.

with source as (
    select * from {{ source('bref', 'nyy_contracts') }}
),

players as (
    select * from source
    where "Name-additional" <> '-9999'
),

cleaned as (
    select
        "Name-additional"  as player_id,
        "Name"             as player_name,
        try_cast("Age" as integer) as age,
        "SrvTm"            as service_time_raw,
        try_cast(split_part("SrvTm", '.', 1) as integer) as service_years,
        try_cast(split_part("SrvTm", '.', 2) as integer) as service_days,
        "Yrs"              as mlb_seasons_raw,
        "Contract Status"  as contract_status_raw,
        "Acquired"         as acquired,
        "Agent"            as agent
    from players
)

select
    *,
    round(service_years + service_days / 172.0, 3) as service_time_seasons
from cleaned