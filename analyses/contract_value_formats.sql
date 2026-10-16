-- Profiles the FORMAT of each messy contracts column before we parse it.
-- Every digit is replaced with 9, so the output shows patterns, not real values.

with contracts as (
    select * from {{ source('bref', 'nyy_contracts') }}
    where "Name-additional" <> '-9999'
),

salary_cells as (
    select season, raw_value
    from contracts
    unpivot include nulls (
        raw_value for season in ("2026", "2027", "2028", "2029", "2030", "2031", "2032")
    )
)

select 'salary' as field, regexp_replace(raw_value, '[0-9]', '9', 'g') as pattern, count(*) as cells
from salary_cells
group by all

union all

select 'service_time', regexp_replace("SrvTm", '[0-9]', '9', 'g'), count(*)
from contracts
group by all

union all

select 'contract_status', regexp_replace("Contract Status", '[0-9]', '9', 'g'), count(*)
from contracts
group by all

union all

select 'yrs', regexp_replace("Yrs", '[0-9]', '9', 'g'), count(*)
from contracts
group by all

order by field, cells desc
