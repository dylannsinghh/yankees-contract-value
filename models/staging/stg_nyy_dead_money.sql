-- One row per dead money item per season: money the Yankees still pay, or get back,
-- for players who were bought out, released, or traded with cash.
-- Positive = the Yankees pay. Negative = another team pays the Yankees.

with source as (
    select * from {{ source('bref', 'nyy_contracts') }}
),

dead_money_rows as (
    -- B-Ref leaves Name blank on these rows and repeats the description
    -- in six columns (Age through Contract Status), so we read it from Age.
    select * from source
    where "Name-additional" = '-9999'
      and "Name" is null
      and "Age" is not null
),

cells as (
    select
        "Age"                   as description,
        cast(season as integer) as season,
        raw_value
    from dead_money_rows
    unpivot (
        raw_value for season in ("2026", "2027", "2028", "2029", "2030", "2031", "2032")
    )
)

select
    description || '-' || season as dead_money_key,
    description,
    regexp_extract(description, '^(.*?) (buyout|released|traded)', 1) as player_name,
    case
        when description like '%buyout%'   then 'buyout'
        when description like '%released%' then 'release'
        when description like '%traded%'   then 'trade_cash'
    end as adjustment_type,
    season,
    raw_value,
    {{ parse_millions('raw_value') }} as amount_usd
from cells