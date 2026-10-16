{#
    Turns B-Ref money text into whole dollars.
    '$40M' -> 40000000, 'Arb (~$2.2M)' -> 2200000, '-$9.9M' -> -9900000.
    Text with no dollar amount ('Arb', 'FA', blank) returns NULL.
#}

{% macro parse_millions(column_name) %}
    cast(round(
        try_cast(regexp_extract({{ column_name }}, '\$([0-9.]+)M', 1) as double)
        * 1000000
        * case when {{ column_name }} like '%-$%' then -1 else 1 end
    ) as bigint)
{% endmacro %}