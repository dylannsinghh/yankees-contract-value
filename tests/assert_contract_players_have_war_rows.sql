-- Every player on the contracts page should show up in at least one WAR file.
-- Returns the players who don't. The test passes when this returns zero rows.

with war_players as (
    select player_id from {{ ref('stg_war_batting') }}
    union
    select player_id from {{ ref('stg_war_pitching') }}
)

select
    c.player_id,
    c.player_name
from {{ ref('stg_nyy_contracts') }} as c
left join war_players as w
    on c.player_id = w.player_id
where w.player_id is null