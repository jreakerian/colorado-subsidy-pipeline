{% macro send_slack_alert(message) %}
  {% set slack_webhook_url = env_var('SLACK_WEBHOOK_URL', '') %}
  {% if slack_webhook_url != '' %}
    {{ log("Sending Slack alert: " ~ message, info=True) }}
    {# Implementation would use a python/bash hook or dbt run operation #}
  {% else %}
    {{ log("Slack webhook URL not configured, skipping alert.", info=True) }}
  {% endif %}
{% endmacro %}
