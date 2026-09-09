{% macro create_ci_schema(schema_name, database_name) %}
  {% set sql %}
    create schema if not exists {{ database_name }}.{{ schema_name }};
  {% endset %}
  {% do run_query(sql) %}
{% endmacro %}
