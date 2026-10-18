-- 2027 depth by position: how much of each position's playing time the players the
-- Yankees control can cover, and how good they're projected to be there.
-- Hitters: each player's projected 2027 playing time and WAR is split across positions
-- in the same proportions he played them for the Yankees in 2026.
-- Pitchers: starters vs relievers, based on how often each one started in 2026.
-- Players with no 2026 Yankees appearances are listed as "Unassigned".

with controlled as (
    select
        r.player_id,
        r.player_name,
        r.expected_war,
        m.role,
        m.projected_pt
    from {{ ref('int_roster_control_seasons') }} as r
    inner join {{ ref('int_marcel_projections') }} as m
        on r.player_id = m.player_id
       and m.target_season = 2027
    where r.season = 2027
),

hitter_positions as (
    select
        player_id,
        position,
        position_games * 1.0 / sum(position_games) over (partition by player_id) as share
    from {{ ref('stg_nyy_appearances') }}
    where position <> 'P'
),

hitters as (
    select
        coalesce(h.position, 'Unassigned') as position,
        c.player_name,
        c.projected_pt * coalesce(h.share, 1) as pt,
        c.expected_war * coalesce(h.share, 1) as war
    from controlled as c
    left join hitter_positions as h on c.player_id = h.player_id
    where c.role = 'hitter'
),

pitcher_roles as (
    select
        player_id,
        case when games_started >= games / 2.0 then 'SP' else 'RP' end as position
    from {{ ref('stg_nyy_appearances') }}
    where position = 'P'
),

pitchers as (
    select
        coalesce(p.position, 'RP') as position,
        c.player_name,
        c.projected_pt             as pt,
        c.expected_war             as war
    from controlled as c
    left join pitcher_roles as p on c.player_id = p.player_id
    where c.role = 'pitcher'
),

all_slots as (
    select * from hitters
    union all
    select * from pitchers
),

needed as (
    -- Playing time a team uses at each spot in a season.
    select
        position,
        sort_order,
        'PA' as unit,
        {{ var('team_plate_appearances') }} / 9.0 as needed_pt
    from (values
        ('C', 1), ('1B', 2), ('2B', 3), ('3B', 4), ('SS', 5),
        ('LF', 6), ('CF', 7), ('RF', 8), ('DH', 9)
    ) as v(position, sort_order)
    union all
    select 'SP', 10, 'IP', {{ var('team_starter_innings') }}
    union all
    select 'RP', 11, 'IP', {{ var('team_bullpen_innings') }}
    union all
    select 'Unassigned', 12, 'PA', null
),

by_position as (
    select
        position,
        sum(pt)  as projected_pt,
        sum(war) as projected_war,
        string_agg(
            case when pt >= 50 then player_name || ' (' || cast(round(war, 1) as varchar) || ')' end,
            ', ' order by war desc
        ) as main_players
    from all_slots
    group by position
)

select
    n.position,
    n.unit,
    round(n.needed_pt)                                         as needed,
    round(coalesce(b.projected_pt, 0))                         as covered,
    round(coalesce(b.projected_pt, 0) / n.needed_pt, 2)        as coverage,
    round(coalesce(b.projected_war, 0), 1)                     as projected_war,
    round(b.projected_war / nullif(b.projected_pt, 0) * n.needed_pt, 1) as war_if_full_time,
    case
        when n.needed_pt is null                                   then 'Not assigned to a position'
        when coalesce(b.projected_pt, 0) / n.needed_pt < 0.5        then 'Gap: not enough players'
        when coalesce(b.projected_pt, 0) / n.needed_pt < 0.9        then 'Thin'
        else 'Covered'
    end                                                        as status,
    b.main_players,
    n.sort_order
from needed as n
left join by_position as b on n.position = b.position
order by n.sort_order
