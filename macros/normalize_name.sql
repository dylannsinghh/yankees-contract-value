{% macro normalize_name(column_name) %}
    trim(regexp_replace(
        regexp_replace(lower(strip_accents({{ column_name }})), '[.'']', '', 'g'),
        '\s+(jr|sr|ii|iii|iv)$', ''
    ))
{% endmacro %}