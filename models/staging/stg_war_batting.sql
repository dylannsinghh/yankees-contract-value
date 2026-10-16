-- One row per player, per season, per team stint
-- (a player traded mid-season has one row for each team)

with source as (
    select * from {{ source('bref', 'war_batting') }}
),

renamed as (
    select
        player_ID || '-' || year_ID || '-' || stint_ID as player_stint_key,
        player_ID   as player_id,
        mlb_ID      as mlbam_id,
        name_common as player_name,
        year_ID     as season,
        stint_ID    as stint,
        team_ID     as team,
        lg_ID       as league,
        age,
        PA          as plate_appearances,
        G           as games,
        WAR         as war,
        case pitcher
            when 'Y' then true
            when 'N' then false
        end         as is_pitcher
    from source
)

select * from renamed
