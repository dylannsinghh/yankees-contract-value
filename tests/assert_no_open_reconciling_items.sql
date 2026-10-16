{{ config(severity = 'warn') }}

-- Warns on every build while any reconciling item is still unexplained,
-- so an open item can't quietly turn into a permanent plug.

select season, difference_millions, reason
from {{ ref('payroll_reconciling_items') }}
where status = 'open'