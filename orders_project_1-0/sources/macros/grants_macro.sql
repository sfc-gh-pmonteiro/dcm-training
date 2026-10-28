{#
  Reusable grant macros. Files in sources/macros/ are visible to every
  definition file. Grants are imperative statements: removing a line revokes
  the grant on the next deploy.
#}

{% macro grant_schema_usage(db, schema, db_role) %}
GRANT USAGE ON SCHEMA {{ db }}.{{ schema }} TO DATABASE ROLE {{ db }}.{{ db_role }};
{% endmacro %}

{% macro grant_select(db, schema, object_type, objects, db_role) %}
{% for obj in objects %}
GRANT SELECT ON {{ object_type }} {{ db }}.{{ schema }}.{{ obj }} TO DATABASE ROLE {{ db }}.{{ db_role }};
{% endfor %}
{% endmacro %}
