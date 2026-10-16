-- One row per player per season (2026-2032) from the contracts page.
-- Turns each salary cell's text into a type and a dollar amount.

with contracts as (
    select * from {{ source('bref', 'nyy_contracts') }}
    where "Name-additional" <> '-9999'
),

cells as (
    select
        "Name-additional"         as player_id,
        cast(season as integer)   as season,
        raw_value
    from contracts
    unpivot include nulls (
        raw_value for season in ("2026", "2027", "2028", "2029", "2030", "2031", "2032")
    )
),

with_position as (
    select
        *,
        count(raw_value) over (
            partition by player_id
            order by season
            rows between unbounded preceding and current row
        ) as filled_cells_so_far
    from cells
),

typed as (
    select
        player_id || '-' || season as player_season_key,
        player_id,
        season,
        raw_value,
        case
            when raw_value like '$%'      then 'guaranteed'
            when raw_value like 'Arb (~$%' then 'arb_estimate'
            when raw_value = 'Arb'        then 'arb_unknown'
            when raw_value = 'FA'         then 'free_agent'
            when raw_value is null and filled_cells_so_far = 0 then 'pre_arb'
            when raw_value is null and filled_cells_so_far > 0 then 'not_under_control'
        end as salary_type,
        {{ parse_millions('raw_value') }} as parsed_usd,
        nullif(regexp_extract(raw_value, '\[(.*)\]', 1), '') as cell_note
    from with_position
)

select
    player_season_key,
    player_id,
    season,
    raw_value,
    salary_type,
    case
        when salary_type = 'pre_arb' then {{ var('pre_arb_salary') }}
        else parsed_usd
    end as salary_usd,
    salary_type in ('pre_arb', 'arb_estimate') as is_estimated,
    cell_note
from typed