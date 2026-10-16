-- The 2027 picture in one table, in plain words: how many wins the players the Yankees
-- already control are projected for, what's leaving in free agency, and how many wins
-- they'd need to add to reach a contending level.
-- Wins = replacement level (about 48 wins for a team of freely available players)
--        + the team's total WAR. That's how WAR is defined.

with controlled_2027 as (
    -- Everyone the Yankees control in 2027, with his projected wins and playing time.
    select
        r.player_id,
        r.expected_war,
        m.role,
        m.projected_pt
    from {{ ref('int_roster_control_seasons') }} as r
    inner join {{ ref('int_marcel_projections') }} as m
        on r.player_id = m.player_id
       and m.target_season = 2027
    where r.season = 2027
),

departing as (
    -- Played for the Yankees in 2026 but not under their control in 2027 (free agents).
    select
        s.player_id,
        m.projected_war
    from {{ ref('mart_2026_snapshot') }} as s
    left join controlled_2027 as c on s.player_id = c.player_id
    left join {{ ref('int_marcel_projections') }} as m
        on s.player_id = m.player_id
       and m.target_season = 2027
    where s.played_for_nyy
      and c.player_id is null
),

nyy_2026 as (
    -- Actual 2026 Yankees WAR, used to check the wins formula against the real record.
    select sum(war) as war
    from (
        select war from {{ ref('stg_war_batting') }}  where season = 2026 and team = 'NYY'
        union all
        select war from {{ ref('stg_war_pitching') }} where season = 2026 and team = 'NYY'
    )
),

totals as (
    select
        (select war from nyy_2026)                                              as war_2026,
        (select sum(expected_war) from controlled_2027)                         as war_2027_controlled,
        (select count(*) from controlled_2027)                                  as players_2027,
        (select sum(projected_pt) from controlled_2027 where role = 'hitter')   as pa_2027,
        (select sum(projected_pt) from controlled_2027 where role = 'pitcher')  as ip_2027,
        (select count(*) from departing)                                        as players_leaving,
        (select coalesce(sum(projected_war), 0) from departing)                 as war_leaving
),

calc as (
    select
        *,
        {{ var('replacement_level_wins') }} + war_2026                as implied_wins_2026,
        {{ var('replacement_level_wins') }} + war_2027_controlled     as wins_2027_before_moves
    from totals
)

select 1 as sort_order, '2026 Yankees WAR (actual)' as metric, round(war_2026, 1) as value from calc
union all
select 2, '2026 implied wins (48 + WAR); compare with the real 2026 record', round(implied_wins_2026, 1) from calc
union all
select 3, 'Players under team control for 2027', players_2027 from calc
union all
select 4, '2027 projected WAR from players under control', round(war_2027_controlled, 1) from calc
union all
select 5, '2027 projected wins before any moves', round(wins_2027_before_moves, 1) from calc
union all
select 6, 'Players leaving in free agency', players_leaving from calc
union all
select 7, 'Their projected 2027 WAR (what walks out the door)', round(war_leaving, 1) from calc
union all
select 8, 'Hitters under control: projected PA (a team uses about {{ var("team_plate_appearances") }})', round(pa_2027) from calc
union all
select 9, 'Pitchers under control: projected innings (a team uses about {{ var("team_innings") }})', round(ip_2027) from calc
union all
select 10, 'Wins to add to reach 90', round(greatest(90 - wins_2027_before_moves, 0), 1) from calc
union all
select 11, 'Cost of those wins at $9.5M per WAR ($M)', round(greatest(90 - wins_2027_before_moves, 0) * {{ var('dollars_per_war_base') }} / 1e6, 1) from calc
union all
select 12, 'Wins to add to reach 95', round(greatest(95 - wins_2027_before_moves, 0), 1) from calc
union all
select 13, 'Cost of those wins at $9.5M per WAR ($M)', round(greatest(95 - wins_2027_before_moves, 0) * {{ var('dollars_per_war_base') }} / 1e6, 1) from calc