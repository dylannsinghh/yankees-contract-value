-- 2026-27 free agents at the positions the Yankees need (2B, 3B, SS, CF, SP, RP),
-- from MLB.com's "All of the 2026-2027 free agents, position by position" (Oct 8, 2026).
-- One row per player. match_name is the name with accents, periods, and suffixes like
-- "Jr." removed, so it can be matched to Baseball-Reference names. If B-Ref uses a
-- different name (a nickname, for example), bref_name in the seed overrides it.

select
    {{ normalize_name('player_name') }} || '-' || age_2027 as free_agent_key,
    player_name,
    position,
    age_2027,
    nullif(cast(option_note as varchar), '')               as option_note,
    {{ normalize_name("coalesce(nullif(cast(bref_name as varchar), ''), player_name)") }} as match_name
from {{ ref('free_agents_2027') }}