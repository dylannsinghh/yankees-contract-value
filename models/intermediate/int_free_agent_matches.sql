-- Matches each free agent to his Baseball-Reference player ID by name and age.
-- Two players can share a name (Luis García the reliever is 40, Luis Garcia the
-- starter is 30), so the ages must agree within a year. Only seasons since 2023
-- count, since older seasons don't feed the 2027 projection anyway.

with free_agents as (
    select * from {{ ref('stg_free_agents') }}
),

recent_seasons as (
    select
        player_id,
        {{ normalize_name('player_name') }} as match_name,
        season,
        age + (2027 - season)                as age_2027
    from {{ ref('int_player_seasons') }}
    where season >= 2023
),

candidates as (
    select
        f.free_agent_key,
        r.player_id,
        max(r.season) as last_season
    from free_agents as f
    inner join recent_seasons as r
        on f.match_name = r.match_name
       and abs(f.age_2027 - r.age_2027) <= 1
    group by f.free_agent_key, r.player_id
)

select
    f.*,
    c.player_id,
    c.last_season,
    count(c.player_id) over (partition by f.free_agent_key) as candidate_count
from free_agents as f
left join candidates as c on f.free_agent_key = c.free_agent_key
qualify row_number() over (
    partition by f.free_agent_key
    order by c.last_season desc nulls last, c.player_id
) = 1