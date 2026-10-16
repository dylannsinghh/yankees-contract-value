-- The snapshot should carry every 2026 payroll dollar from staging, no more, no less.
-- Catches a join that drops players or duplicates them (fan-out).

with staging as (
    select count(*) as players, sum(salary_usd) as salary_usd
    from {{ ref('stg_nyy_salaries') }}
    where season = 2026
      and salary_type in ('guaranteed', 'arb_estimate', 'pre_arb')
),

snapshot as (
    select count(*) as players, sum(salary_usd) as salary_usd
    from {{ ref('mart_2026_snapshot') }}
)

select
    staging.players as staging_players,
    snapshot.players as snapshot_players
from staging
cross join snapshot
where staging.players <> snapshot.players
   or staging.salary_usd <> snapshot.salary_usd