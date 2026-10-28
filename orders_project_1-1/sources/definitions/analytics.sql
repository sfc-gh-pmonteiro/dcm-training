-- Declarative pipeline: DCM orders this after RAW.ORDERS and the warehouse automatically.

DEFINE DYNAMIC TABLE ORDERS{{env_suffix}}.ANALYTICS.DAILY_REVENUE
WAREHOUSE = ORDERS_WH{{env_suffix}}
TARGET_LAG = '{{dt_lag}}'
COMMENT = 'Daily revenue and order counts'
AS
SELECT
    DATE_TRUNC('DAY', ORDER_TS)  AS ORDER_DAY,
    COUNT(*)                     AS ORDER_COUNT,
    SUM(AMOUNT)                  AS REVENUE
FROM ORDERS{{env_suffix}}.RAW.ORDERS
WHERE STATUS <> 'CANCELLED'
GROUP BY ORDER_DAY;
