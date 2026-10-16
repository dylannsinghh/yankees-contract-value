-- Every contract of 3+ years that has started should show up in the retrospective.
-- Returns any that are missing.

select c.player_id, c.contract_status_raw
from {{ ref('stg_nyy_contracts') }} as c
left join {{ ref('mart_contract_retrospective') }} as m
    on c.player_id = m.player_id
where c.contract_years >= 3
  and c.contract_start_season <= 2026
  and m.player_id is null