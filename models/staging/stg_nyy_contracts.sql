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
),

parsed as (
    -- Contract Status looks like "9 yrs/$360M (23-31)" or "1 yr/$22.03M (26)",
    -- sometimes with option text after it ("& 28 team option").
    select
        *,
        try_cast(regexp_extract(contract_status_raw, '^([0-9]+) yrs?/', 1) as integer) as contract_years,
        {{ parse_millions('contract_status_raw') }}                                   as contract_total_usd,
        try_cast(regexp_extract(contract_status_raw, '\(([0-9]+)', 1) as integer)          as start_yy,
        try_cast(nullif(regexp_extract(contract_status_raw, '\([0-9]+-([0-9]+)\)', 1), '') as integer) as end_yy
    from cleaned
)

select
    player_id,
    player_name,
    age,
    service_time_raw,
    service_years,
    service_days,
    round(service_years + service_days / 172.0, 3) as service_time_seasons,
    mlb_seasons_raw,
    contract_status_raw,
    contract_years,
    contract_total_usd,
    2000 + start_yy                   as contract_start_season,
    2000 + coalesce(end_yy, start_yy) as contract_end_season,
    round(contract_total_usd / nullif(contract_years, 0)) as contract_aav_usd,
    coalesce(contract_status_raw like '%option%', false) as has_option,
    acquired,
    agent
from parsed