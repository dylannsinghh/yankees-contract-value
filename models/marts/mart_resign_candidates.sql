-- Should the Yankees try to bring back any of their own free agents?
-- A player makes sense to target when (1) his position is thin or empty without him,
-- and (2) he projects to be worth real money in 2027.
-- Fair price = projected 2027 WAR x $9.5M. Contract length follows age:
-- older players get shorter deals, because decline and injury risk rise with age.

with departing as (
    select * from {{ ref('mart_pending_free_agents') }}
),

primary_position as (
    -- The spot he played most for the Yankees in 2026. Pitchers become SP or RP.
    select
        player_id,
        case
            when position = 'P' and games_started >= games / 2.0 then 'SP'
            when position = 'P' then 'RP'
            else position
        end as position
    from {{ ref('stg_nyy_appearances') }}
    qualify row_number() over (
        partition by player_id
        order by position_games desc, position
    ) = 1
),

depth as (
    select position, status
    from {{ ref('mart_2027_position_depth') }}
)

select
    d.player_id,
    d.player_name,
    p.position,
    dp.status                          as position_without_him,
    d.age_2027,
    d.projected_war_2027,
    d.worth_2027_m                     as fair_price_m,
    d.paid_2026_m,
    case
        when d.projected_war_2027 is null or d.projected_war_2027 < 0.5
            then 'Let go: replacement-level projection'
        when dp.status in ('Gap: not enough players', 'Thin') and d.projected_war_2027 >= 2
            then 'Strong case: fills a hole and projects as a regular'
        when dp.status in ('Gap: not enough players', 'Thin')
            then 'Worth it at the right price: fills a hole as a role player'
        else 'Replaceable: position already covered'
    end                                as resign_case,
    case
        when d.age_2027 <= 30 then 'Multi-year deal is reasonable'
        when d.age_2027 <= 34 then '1 to 2 years'
        else '1 year'
    end                                as sensible_length
from departing as d
left join primary_position as p on d.player_id = p.player_id
left join depth as dp on p.position = dp.position
