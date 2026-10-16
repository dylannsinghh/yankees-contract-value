-- Money still owed in the remaining-value model should match the retrospective's
-- remaining guaranteed salary, plus any trade cash in those seasons.

with remaining as (
    select player_id, sum(salary_usd) as salary_usd
    from {{ ref('int_remaining_contract_seasons') }}
    group by player_id
),

retrospective as (
    select player_id, remaining_guaranteed_usd
    from {{ ref('mart_contract_retrospective') }}
    where remaining_guaranteed_usd > 0
)

select
    r.player_id,
    r.remaining_guaranteed_usd,
    m.salary_usd
from retrospective as r
left join remaining as m on r.player_id = m.player_id
where m.salary_usd is null
   or m.salary_usd <> r.remaining_guaranteed_usd