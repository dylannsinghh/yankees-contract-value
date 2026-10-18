-- The roster model and the contract model calculate the 7 big contracts separately.
-- Their guaranteed years should agree on WAR and money. Returns any player where they don't.

with roster as (
    select
        player_id,
        sum(expected_war)      as expected_war,
        sum(full_season_war)   as full_season_war,
        sum(expected_cost_usd) as cost_usd
    from {{ ref('int_roster_control_seasons') }}
    where salary_type = 'guaranteed'
    group by player_id
)

select
    v.player_id,
    v.expected_war,
    r.expected_war as roster_expected_war,
    v.healthy_war,
    r.full_season_war as roster_full_season_war
from {{ ref('mart_remaining_value') }} as v
left join roster as r on v.player_id = r.player_id
where r.player_id is null
   or abs(v.expected_war - r.expected_war) > 0.05
   or abs(v.healthy_war - r.full_season_war) > 0.05
   or v.remaining_cost_usd <> r.cost_usd