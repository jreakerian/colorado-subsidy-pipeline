{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set env = target.name -%}  {# Evaluates to 'dev' or 'prod' based on CLI target #}

    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}_{{ env }}
    {%- endif -%}
{%- endmacro %}