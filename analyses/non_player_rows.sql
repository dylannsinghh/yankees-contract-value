-- Lists every non-player row (ID = -9999) so we can see what each one is.
-- Digits are masked, so dollar amounts show as patterns, not real values.

select
    row_number() over () as row_order,
    regexp_replace(coalesce("Name", '(blank)'), '[0-9]', '9', 'g') as name_text,
    regexp_replace("2026", '[0-9]', '9', 'g') as pattern_2026,
    regexp_replace("2027", '[0-9]', '9', 'g') as pattern_2027
from {{ source('bref', 'nyy_contracts') }}
where "Name-additional" = '-9999'