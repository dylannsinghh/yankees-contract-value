-- The free-agent board: every 2026-27 free agent at a position the Yankees need, with his
-- projected 2027 WAR, a fair one-year price, and whether he fills a Yankees hole.
-- Two prices: "fair price" uses his expected playing time (injury risk included), and
-- "price if healthy" assumes a full season. Aces and injured players sit far apart.
-- Same projection and same 9.5 million per WAR as the rest of the project, so these numbers
-- compare directly with the Yankees' own players and their pending free agents.

with matched as (
    select * from {{ ref('int_free_agent_matches') }}
),

projection as (
    select
        player_id,
        projected_war,
        projected_war_per_full_season,
        marcel_availability,
        reliability
    from {{ ref('int_marcel_projections') }}
    where target_season = 2027
),

depth as (
    select position, status
    from {{ ref('mart_2027_position_depth') }}
),

yankees_own as (
    select player_id
    from {{ ref('mart_pending_free_agents') }}
)

select
    m.free_agent_key,
    m.player_id,
    m.player_name,
    m.position,
    m.age_2027,
    d.status                                               as yankees_need,
    p.projected_war                                        as projected_war_2027,
    p.projected_war_per_full_season                        as war_per_full_season,
    p.reliability,
    round(p.projected_war * {{ var('dollars_per_war_base') }} / 1e6, 1) as fair_price_m,
    round(p.projected_war_per_full_season * {{ var('dollars_per_war_base') }} / 1e6, 1) as fair_price_if_healthy_m,
    case
        when p.player_id is null      then 'No recent MLB track record'
        when p.projected_war >= 3     then 'Impact (3+ WAR)'
        when p.projected_war >= 2     then 'Regular (2-3 WAR)'
        when p.projected_war >= 0.5   then 'Role player (0.5-2 WAR)'
        else 'Replacement level'
    end                                                    as tier,
    coalesce(
        p.projected_war_per_full_season >= 2 and p.marcel_availability < 0.6,
        false
    )                                                      as is_buy_low,
    y.player_id is not null                                as is_yankees_free_agent,
    case
        when m.option_note in ('Club option', 'Mutual option', 'Player option')
            then 'May not reach free agency (' || lower(m.option_note) || ')'
        when m.option_note = 'Opt-out'
            then 'Only available if he opts out'
        else 'Free agent'
    end                                                    as availability,
    row_number() over (
        partition by m.position
        order by p.projected_war desc nulls last, m.player_name
    )                                                      as rank_at_position
from matched as m
left join projection as p on m.player_id = p.player_id
left join depth as d on m.position = d.position
left join yankees_own as y on m.player_id = y.player_id