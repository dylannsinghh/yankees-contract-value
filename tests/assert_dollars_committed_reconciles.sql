-- B-Ref's "Dollars Committed" row should equal guaranteed player salaries
-- plus dead money, season by season, after documented reconciling items.
-- Returns any season where the gap isn't explained by seeds/payroll_reconciling_items.csv
-- (within $0.25M, because B-Ref rounds what it displays).

with committed as (
    select
        cast(season as integer)          as season,
        {{ parse_millions('raw_value') }} as committed_usd
    from (
        select * from {{ source('bref', 'nyy_contracts') }}
        where "Name" = 'Dollars Committed'
    )
    unpivot (
        raw_value for season in ("2026", "2027", "2028", "2029", "2030", "2031", "2032")
    )
),

players as (
    select season, sum(salary_usd) as player_usd
    from {{ ref('stg_nyy_salaries') }}
    where salary_type = 'guaranteed'
    group by season
),

dead_money as (
    select season, sum(amount_usd) as dead_money_usd
    from {{ ref('stg_nyy_dead_money') }}
    group by season
),

documented as (
    select season, sum(difference_millions) * 1000000 as documented_usd
    from {{ ref('payroll_reconciling_items') }}
    group by season
),

compared as (
    select
        c.season,
        coalesce(p.player_usd, 0) + coalesce(d.dead_money_usd, 0) - c.committed_usd as difference_usd,
        coalesce(r.documented_usd, 0) as documented_usd
    from committed as c
    left join players as p on c.season = p.season
    left join dead_money as d on c.season = d.season
    left join documented as r on c.season = r.season
)

select
    season,
    round(difference_usd / 1000000.0, 2) as difference_millions,
    round(documented_usd / 1000000.0, 2) as documented_millions
from compared
where abs(difference_usd - documented_usd) > 250000