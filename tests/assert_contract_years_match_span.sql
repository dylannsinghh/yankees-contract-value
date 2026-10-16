-- "9 yrs/$360M (23-31)" says 9 years, and 2023 through 2031 is 9 seasons.
-- If the parsed length and the parsed span ever disagree, the parsing is wrong.

select
    player_id,
    contract_status_raw,
    contract_years,
    contract_start_season,
    contract_end_season
from {{ ref('stg_nyy_contracts') }}
where contract_years is not null
  and contract_end_season - contract_start_season + 1 <> contract_years