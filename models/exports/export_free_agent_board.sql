{{ config(materialized='external', location='exports/free_agent_board.csv') }}

-- The free-agent board for Tableau: who could fill each Yankees need and what's fair to pay.
-- Positions the Yankees need most come first; within a position, best projection first.
-- rank_among_available counts only players who will actually reach the market.

select
    position,
    rank_at_position,
    rank_among_available,
    player_name,
    age_2027,
    yankees_need,
    tier,
    projected_war_2027,
    war_per_full_season,
    fair_price_m,
    fair_price_if_healthy_m,
    is_buy_low,
    is_yankees_free_agent,
    availability
from {{ ref('mart_free_agent_board') }}
order by
    case yankees_need
        when 'Gap: not enough players' then 1
        when 'Thin' then 2
        else 3
    end,
    position,
    rank_at_position