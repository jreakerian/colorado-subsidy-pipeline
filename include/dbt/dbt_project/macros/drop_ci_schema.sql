{% macro drop_ci_schema(schema_name, database_name) %}
  {% set sql %}
    drop schema if exists {{ database_name }}.{{ schema_name }};
  {% endset %}
  {% do run_query(sql) %}
{% endmacro %}
