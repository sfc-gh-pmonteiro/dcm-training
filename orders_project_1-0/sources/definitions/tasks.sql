-- Sample-data loader. Target state ({{task_state}}) is DCM-specific and reasserted
-- on every deploy: SUSPENDED in DEV/QA, STARTED in PRD. Without it, a NEW task
-- is created suspended. To pause a STARTED task, change the definition -
-- a manual ALTER TASK ... SUSPEND is undone by the next deploy.

DEFINE TASK ORDERS{{env_suffix}}.RAW.TSK_LOAD_SAMPLE_ORDERS
    WAREHOUSE = 'ORDERS_WH{{env_suffix}}'
    SCHEDULE = '{{task_schedule}}'
    COMMENT = 'Generates 100 synthetic orders per run'
    {{task_state}}
AS
    INSERT INTO ORDERS{{env_suffix}}.RAW.ORDERS (ORDER_ID, CUSTOMER_ID, ORDER_TS, AMOUNT, STATUS)
    SELECT
        ABS(HASH(UUID_STRING())),
        UNIFORM(1, 500, RANDOM()),
        DATEADD(MINUTE, -UNIFORM(0, 10080, RANDOM()), CURRENT_TIMESTAMP())::TIMESTAMP_NTZ,
        UNIFORM(500, 50000, RANDOM()) / 100,
        ARRAY_CONSTRUCT('NEW', 'SHIPPED', 'SHIPPED', 'CANCELLED')[UNIFORM(0, 3, RANDOM())]::VARCHAR
    FROM TABLE(GENERATOR(ROWCOUNT => 100));
