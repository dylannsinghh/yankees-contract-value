-- One row per player per season (2026-2032).
-- Contracts-page players: each salary cell's text is turned into a type and a dollar amount.
-- Hand-added players (seeds/roster_additions.csv): the standard path for a young player,
-- pre-arb until his first arbitration season, arbitration until free agency.

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
),

from_contracts_page as (
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
),

manual_additions as (
    select
        a.player_id || '-' || s.season as player_season_key,
        a.player_id,
        s.season,
        cast(null as varchar)          as raw_value,
        case
            when s.season < a.first_arb_season  then 'pre_arb'
            when s.season < a.free_agent_season then 'arb_unknown'
            when s.season = a.free_agent_season then 'free_agent'
            else 'not_under_control'
        end                            as salary_type,
        case
            when s.season < a.first_arb_season then {{ var('pre_arb_salary') }}
        end                            as salary_usd,
        s.season < a.first_arb_season  as is_estimated,
        cast(null as varchar)          as cell_note
    from {{ ref('roster_additions') }} as a
    cross join (select unnest(generate_series(2026, 2032)) as season) as s
)

select * from from_contracts_page
union all
select * from manual_additions