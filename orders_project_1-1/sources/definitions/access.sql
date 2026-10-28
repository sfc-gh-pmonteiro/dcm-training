-- Access model: database roles hold object privileges (access roles),
-- account roles hold warehouse usage and are what people get (functional roles).

DEFINE DATABASE ROLE ORDERS{{env_suffix}}.READER
    COMMENT = 'Read the SERVE layer';
DEFINE DATABASE ROLE ORDERS{{env_suffix}}.RAW_READER
    COMMENT = 'Read the RAW layer';

GRANT USAGE ON DATABASE ORDERS{{env_suffix}} TO DATABASE ROLE ORDERS{{env_suffix}}.READER;
GRANT USAGE ON DATABASE ORDERS{{env_suffix}} TO DATABASE ROLE ORDERS{{env_suffix}}.RAW_READER;

{{ grant_schema_usage('ORDERS' ~ env_suffix, 'SERVE', 'READER') }}
{{ grant_select('ORDERS' ~ env_suffix, 'SERVE', 'VIEW', ['V_DAILY_REVENUE', 'V_REVENUE_BY_CHANNEL'], 'READER') }}

{{ grant_schema_usage('ORDERS' ~ env_suffix, 'RAW', 'RAW_READER') }}
{{ grant_select('ORDERS' ~ env_suffix, 'RAW', 'TABLE', ['ORDERS'], 'RAW_READER') }}

-- Warehouses are account-level: database roles cannot get warehouse privileges.
DEFINE ROLE ORDERS_ANALYST{{env_suffix}}
    COMMENT = 'Functional role: analysts of the Orders product';
GRANT USAGE ON WAREHOUSE ORDERS_WH{{env_suffix}} TO ROLE ORDERS_ANALYST{{env_suffix}};
GRANT DATABASE ROLE ORDERS{{env_suffix}}.READER TO ROLE ORDERS_ANALYST{{env_suffix}};

-- Keep every role the project creates inside the owner's hierarchy (no orphan roles,
-- and the owner keeps control if ownership is ever transferred to these roles).
GRANT ROLE ORDERS_ANALYST{{env_suffix}} TO ROLE {{project_owner_role}};

-- One functional role per team, generated from the manifest dictionary.
{% for team in teams %}
DEFINE ROLE ORDERS_{{team.name}}{{env_suffix}}
    COMMENT = 'Team role: {{team.name}}';
GRANT ROLE ORDERS_ANALYST{{env_suffix}} TO ROLE ORDERS_{{team.name}}{{env_suffix}};
{% if team.raw_access %}
GRANT DATABASE ROLE ORDERS{{env_suffix}}.RAW_READER TO ROLE ORDERS_{{team.name}}{{env_suffix}};
{% endif %}
GRANT ROLE ORDERS_{{team.name}}{{env_suffix}} TO ROLE {{project_owner_role}};
{% endfor %}

{% for user_name in users %}
GRANT ROLE ORDERS_ANALYST{{env_suffix}} TO USER {{user_name}};
{% endfor %}
