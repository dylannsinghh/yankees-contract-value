{{ config(severity = 'warn') }}

-- Checks our rule that a blank cell before any filled cell means pre-arb.
-- Pre-arb normally lasts about 3 seasons, so a player with more than 3
-- pre-arb seasons probably means the rule misread his row.
-- Set to warn, not fail: it flags rows to look at, it doesn't block the build.

select
    player_id,
    count(*) as pre_arb_seasons
from {{ ref('stg_nyy_salaries') }}
where salary_type = 'pre_arb'
group by player_id
having count(*) > 3