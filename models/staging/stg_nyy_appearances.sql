-- One row per player per position from B-Ref's 2026 Yankees Appearances table:
-- how many games each player played at each spot. Used to figure out who covers
-- which position in 2027. The OF column is skipped because it's just LF + CF + RF.

with source as (
    select * from {{ source('bref', 'nyy_appearances') }}
),

players as (
    select
        "Player-additional"   as player_id,
        "Player"              as player_name,
        cast("G" as integer)  as games,
        cast("GS" as integer) as games_started,
        "P", "C", "1B", "2B", "3B", "SS", "LF", "CF", "RF", "DH"
    from source
    where "Player-additional" is not null
)

select
    player_id || '-' || position  as player_position_key,
    player_id,
    player_name,
    games,
    games_started,
    position,
    cast(position_games as integer) as position_games
from players
unpivot (
    position_games for position in ("P", "C", "1B", "2B", "3B", "SS", "LF", "CF", "RF", "DH")
)
where position_games > 0