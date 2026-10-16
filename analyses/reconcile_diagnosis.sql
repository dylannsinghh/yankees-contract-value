-- Why doesn't Dollars Committed reconcile? Tests five possible definitions at once.
-- Each column is the gap (in $M) under one definition. The one near 0 is B-Ref's rule.
-- Only gaps are shown, never B-Ref's actual totals.

with summary_rows as (
    select
        "Name"                            as label,
        cast(season as integer)           as season,
        {{ parse_millions('raw_value') }} as amount_usd
    from (
        select * from {{ source('bref', 'nyy_contracts') }}
        where "Name" in ('Dollars Committed', 'Option Values')
    )
    unpivot (
        raw_value for season in ("2026", "2027", "2028", "2029", "2030", "2031", "2032")
    )
),

totals as (
    select
        season,
        sum(case when label = 'Dollars Committed' then amount_usd end) as committed_usd,
        coalesce(sum(case when label = 'Option Values' then amount_usd end), 0) as option_usd
    from summary_rows
    group by season
),

players as (
    select
        season,
        coalesce(sum(case when salary_type = 'guaranteed' then salary_usd end), 0) as guaranteed_usd,
        coalesce(sum(case when salary_type = 'arb_estimate' then salary_usd end), 0) as arb_estimate_usd,
        coalesce(sum(case when salary_type = 'guaranteed' and cell_note is not null then salary_usd end), 0) as noted_cell_usd
    from {{ ref('stg_nyy_salaries') }}
    group by season
),

dead_money as (
    select season, sum(amount_usd) as dead_money_usd
    from {{ ref('stg_nyy_dead_money') }}
    group by season
),

base as (
    select
        t.season,
        t.committed_usd,
        t.option_usd,
        coalesce(p.guaranteed_usd, 0)   as guaranteed_usd,
        coalesce(p.arb_estimate_usd, 0) as arb_estimate_usd,
        coalesce(p.noted_cell_usd, 0)   as noted_cell_usd,
        coalesce(d.dead_money_usd, 0)   as dead_money_usd
    from totals as t
    left join players as p on t.season = p.season
    left join dead_money as d on t.season = d.season
    where t.committed_usd is not null
)

select
    season,
    round((guaranteed_usd + dead_money_usd - committed_usd) / 1e6, 2)                    as gap_now,
    round((guaranteed_usd + dead_money_usd - option_usd - committed_usd) / 1e6, 2)       as gap_no_options,
    round((guaranteed_usd + dead_money_usd + arb_estimate_usd - committed_usd) / 1e6, 2) as gap_plus_arb_est,
    round((guaranteed_usd - noted_cell_usd + dead_money_usd - committed_usd) / 1e6, 2)   as gap_no_note_cell,
    round((guaranteed_usd - committed_usd) / 1e6, 2)                                     as gap_no_dead_money
from base
order by season