-- The one table to read first: every player in the Yankees' 2027 decisions, in plain English.
-- Under control: what he's worth per season, what he costs per season, and a verdict.
-- Free agents this winter: what he's worth for 2027 and whether to bring him back.
-- Worth = projected WAR x 9.5 million (roughly what a win costs on the free-agent market).
-- Value = worth minus cost. Positive means the Yankees get more than they pay for.

with positions as (
    -- Where he played most for the Yankees in 2026. Pitchers become SP or RP.
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

controlled as (
    select
        player_id,
        player_name,
        controlled_through,
        excluded_reason,
        case
            when guaranteed_seasons > 0                    then 'multi-year contract'
            when pre_arb_seasons > 0 and arb_seasons > 0   then 'pre-arb years, then arbitration'
            when arb_seasons > 0                           then 'arbitration'
            else 'pre-arbitration'
        end                                                     as control_type,
        expected_war / seasons_controlled                       as war_per_season,
        expected_war / seasons_controlled
            * {{ var('dollars_per_war_base') }} / 1e6           as worth_per_season_m,
        expected_cost_usd / seasons_controlled / 1e6            as cost_per_season_m,
        surplus_expected_base_usd / seasons_controlled / 1e6    as value_per_season_m,
        surplus_full_season_base_usd / seasons_controlled / 1e6 as value_if_healthy_per_season_m
    from {{ ref('mart_roster_value') }}
),

controlled_verdicts as (
    select
        *,
        case
            when excluded_reason is not null        then 'Too early to tell'
            when value_per_season_m >= 5            then 'Core piece'
            when value_per_season_m >= 1            then 'Good value'
            when value_per_season_m > -1            then 'Fair price'
            when value_if_healthy_per_season_m >= 0 then 'Overpaid unless healthy'
            when value_per_season_m > -10           then 'Overpaid'
            else 'Big overpay'
        end as verdict
    from controlled
),

under_control as (
    select
        c.player_id,
        c.player_name,
        coalesce(p.position, 'n/a')                             as position,
        'Controlled through ' || c.controlled_through
            || ' (' || c.control_type || ')'                    as status,
        round(c.worth_per_season_m, 1)                          as worth_per_season_m,
        round(c.cost_per_season_m, 1)                           as cost_per_season_m,
        round(c.value_per_season_m, 1)                          as value_per_season_m,
        c.verdict,
        case
            when c.excluded_reason is not null then c.excluded_reason
            else printf(
                'Projects %.1f WAR a season, worth about %.1f million, and costs %.1f million a season',
                round(c.war_per_season, 1),
                round(c.worth_per_season_m, 1),
                round(c.cost_per_season_m, 1)
            )
            || case
                when c.verdict = 'Overpaid unless healthy'
                    then '. A full, healthy season is worth the money; the risk is missed time'
                else ''
            end
        end                                                     as why,
        1                                                       as section_order
    from controlled_verdicts as c
    left join positions as p on c.player_id = p.player_id
),

free_agents as (
    select
        f.player_id,
        f.player_name,
        coalesce(f.position, 'n/a')                             as position,
        'Free agent this winter'                                as status,
        f.fair_price_m                                          as worth_per_season_m,
        cast(null as double)                                    as cost_per_season_m,
        cast(null as double)                                    as value_per_season_m,
        case
            when f.resign_case like 'Strong case%' then 'Re-sign'
            when f.resign_case like 'Worth it%'    then 'Re-sign at the right price'
            else 'Let walk'
        end                                                     as verdict,
        case
            when f.projected_war_2027 is null then 'Free agent with no projection'
            when f.resign_case like 'Let go%'
                then printf('Projects %.1f WAR in 2027, about replacement level', f.projected_war_2027)
            else printf(
                'Projects %.1f WAR in 2027, worth about %.1f million. ',
                f.projected_war_2027, f.fair_price_m
            )
            || case f.position
                when 'SP' then 'The rotation'
                when 'RP' then 'The bullpen'
                else coalesce(f.position, 'His position')
            end
            || case f.position_without_him
                when 'Gap: not enough players' then ' is a gap without him'
                when 'Thin'                    then ' is thin without him'
                else ' is already covered without him'
            end
            || '. Contract length: ' || f.sensible_length
        end                                                     as why,
        2                                                       as section_order
    from {{ ref('mart_resign_candidates') }} as f
)

select * from under_control
union all
select * from free_agents