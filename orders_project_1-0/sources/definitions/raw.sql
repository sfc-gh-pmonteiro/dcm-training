-- Landing table. CHANGE_TRACKING enables incremental dynamic-table refresh;
-- DATA_METRIC_SCHEDULE is required for the attached expectations to run.

DEFINE TABLE ORDERS{{env_suffix}}.RAW.ORDERS (
    ORDER_ID     NUMBER        NOT NULL,
    CUSTOMER_ID  NUMBER        NOT NULL,
    ORDER_TS     TIMESTAMP_NTZ,
    AMOUNT       NUMBER(12,2),
    STATUS       VARCHAR(20)
)
CHANGE_TRACKING = TRUE
DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES'
COMMENT = 'Raw orders';
