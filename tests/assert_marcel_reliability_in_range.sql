-- Reliability is how much of the projection comes from the player's own record
-- (the rest is league average). It has to fall between 0 and 1.

select projection_key, reliability
from {{ ref('int_marcel_projections') }}
where reliability < 0 or reliability > 1