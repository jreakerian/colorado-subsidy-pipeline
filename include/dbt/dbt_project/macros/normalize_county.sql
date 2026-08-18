{% macro normalize_county(column) %}
  lower(
    trim(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            lower(trim({{ column }})),
            ',\\s*(co|colorado)\\s*$', ''   -- strip ", CO" or ", Colorado" suffix
          ),
          '\\s+county\\s*$', ''             -- strip trailing " county"
        ),
        '\\s+', ' '                         -- collapse internal whitespace
      )
    )
  )
{% endmacro %}
