-- Account-level containers for the Orders data product.
-- Every account-level name is templated so DEV/QA/PRD (and sandboxes) never collide.

DEFINE DATABASE ORDERS{{env_suffix}}
    DATA_RETENTION_TIME_IN_DAYS = {{retention_days}}
    COMMENT = 'Orders data product - managed by DCM ({{env_suffix}})';

DEFINE SCHEMA ORDERS{{env_suffix}}.RAW
    COMMENT = 'Landing layer';

DEFINE SCHEMA ORDERS{{env_suffix}}.ANALYTICS
    COMMENT = 'Transformation layer (dynamic tables)';

DEFINE SCHEMA ORDERS{{env_suffix}}.SERVE
    COMMENT = 'Consumption layer (views)';

DEFINE WAREHOUSE ORDERS_WH{{env_suffix}}
WITH
    WAREHOUSE_SIZE = '{{wh_size}}'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Orders compute ({{env_suffix}})';
