-- One row per pitcher, per season, per team stint

with source as (
    select * from {{ source('bref', 'war_pitching') }}
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
        G           as games,
        GS          as games_started,
        IPouts      as outs_recorded,
        IPouts / 3.0 as innings_pitched,
        WAR         as war
    from source
)

select * from renamed