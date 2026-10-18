{{ config(severity = 'warn') }}

-- Free agents that couldn't be matched to a Baseball-Reference ID, or matched more than one.
-- A player whose name and age match someone who last played before 2023 is expected
-- (no recent MLB time, so no projection) and isn't flagged. Anyone else needs a name fix
-- in the bref_name column of seeds/free_agents_2027.csv.

with inactive as (
    select distinct
        {{ normalize_name('player_name') }} as match_name,
        age + (2027 - season)                as age_2027
    from {{ ref('int_player_seasons') }}
    where season < 2023
)

select
    m.free_agent_key,
    m.player_name,
    m.position,
    m.age_2027,
    m.candidate_count
from {{ ref('int_free_agent_matches') }} as m
where m.candidate_count > 1
   or (
        m.player_id is null
        and not exists (
            select 1
            from inactive as i
            where i.match_name = m.match_name
              and abs(i.age_2027 - m.age_2027) <= 1
        )
   )