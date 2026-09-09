{% macro drop_ci_schema(schema_name, database_name) %}
  {% set suffixes = ['', '__raw', '__silver', '__gold'] %}
  {% for suffix in suffixes %}
    {% set full_schema_name = schema_name ~ suffix %}
    {% set sql %}
      drop schema if exists {{ database_name }}.{{ full_schema_name }};
    {% endset %}
    {% do run_query(sql) %}
  {% endfor %}
{% endmacro %}
