{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- if target.name == 'ci' -%}
        {#
            CI runs: always prefix with the ephemeral PR schema (e.g. CI_PR_25)
            so that NO models write to the shared RAW / SILVER / GOLD schemas.

            Result:
              staging     → CI_PR_25__raw
              intermediate → CI_PR_25__silver
              marts        → CI_PR_25__gold
        #}
        {{ target.schema }}{%- if custom_schema_name is not none %}__{{ custom_schema_name | trim }}{%- endif %}

    {%- else -%}
        {#
            All other targets (prod, dev): use the custom schema name as-is,
            or fall back to target.schema if no custom schema is configured.
        #}
        {%- if custom_schema_name is none -%}
            {{ target.schema }}
        {%- else -%}
            {{ custom_schema_name | trim }}
        {%- endif -%}

    {%- endif -%}

{%- endmacro %}
