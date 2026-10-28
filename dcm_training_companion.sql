/* =============================================================================
   DCM PROJECTS - END-TO-END TRAINING COMPANION (DEV / QA / PRD)
   -----------------------------------------------------------------------------
   Every statement is safe to re-run:
     * setup (dcm_training_setup.sql) uses IF NOT EXISTS / idempotent GRANTs
     * PLAN never changes anything
     * DEPLOY converges to the same state; re-running it gives an empty changeset
   Destructive statements (PURGE / DROP) are commented out and marked.

   Two versions of the same project are used, standing in for two Git commits
   (see README.md):
     @DCM_TRAINING.PROJECTS.SOURCES/release-1.0/   <- orders_project_1-0  (before the feature)
     @DCM_TRAINING.PROJECTS.SOURCES/release-1.1/   <- orders_project_1-1             (after the feature, Git "main")
   In a real setup the source is a Git repository clone or a Workspace path;
   the stage simply makes the lab runnable from any SQL client.

   Labels:  [GA]  generally available     [PREVIEW]  preview feature at GA
   Docs are the source of truth: https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-overview
   ============================================================================= */


/* =============================================================================
   STEP 1 - BOOTSTRAP                                                   ~3 min
   Already done before the session by dcm_training_setup.sql:
     snow sql -c <connection> -f dcm_training_setup.sql -D "root=$PWD"
   During the call, open that file and explain it: platform container, one
   owner role per environment + auditor, one DCM project object per
   environment (each created by its own deployer role), sources on a stage.
   A project can never DEFINE its own parent database/schema.
   ============================================================================= */
SHOW DCM PROJECTS IN SCHEMA DCM_TRAINING.PROJECTS;   -- 3 projects, each owned by its deployer role
LIST @DCM_TRAINING.PROJECTS.SOURCES;                 -- release-1.0 and release-1.1

/* =============================================================================
   STEP 2 - FIRST DEV DEPLOYMENT (release-1.0)                          ~4 min
   ============================================================================= */
USE ROLE DCM_DEVELOPER;
USE WAREHOUSE DCM_TRAINING_WH;

-- [GA] PLAN = dry run. Renders Jinja, diffs against the account, sorts by
-- dependency, compiles, checks privileges. Nothing is changed.
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV
    PLAN
    USING CONFIGURATION DEV
    FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.0/';
-- Expect 16 entries: CREATE for the database (+ its PUBLIC schema), 3 schemas,
-- warehouse, table, dynamic table, view, task, 2 database roles, 3 account roles,
-- and an ALTER of DCM_DEVELOPER (it receives the new roles). Grants and the 3
-- expectations appear nested inside each object's "changes".
-- The single output column is already an OBJECT: query it with r.$1:changeset.

-- [GA] DEPLOY with an alias (think: commit message for the environment).
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV
    DEPLOY AS "release-1.0"
    USING CONFIGURATION DEV
    FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.0/';

-- Idempotency proof: same sources again -> empty changeset ("changeset": []).
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV
    PLAN
    USING CONFIGURATION DEV
    FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.0/';

-- What does the project manage now?
SHOW ENTITIES IN DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV;
SHOW GRANTS IN DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV;

-- The task was deployed SUSPENDED (DEV config). Run it once by hand to load data.
EXECUTE TASK ORDERS_DEV.RAW.TSK_LOAD_SAMPLE_ORDERS;
CALL SYSTEM$WAIT(20);   -- EXECUTE TASK is asynchronous: give it time to load the rows
SELECT COUNT(*) AS ROWS_LOADED FROM ORDERS_DEV.RAW.ORDERS;
ALTER DYNAMIC TABLE ORDERS_DEV.ANALYTICS.DAILY_REVENUE REFRESH;
SELECT * FROM ORDERS_DEV.SERVE.V_DAILY_REVENUE ORDER BY ORDER_DAY DESC LIMIT 10;

-- [PREVIEW] TEST ALL evaluates every attached expectation now.
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV TEST ALL;
-- Expect "status": "SUCCESSFUL".

-- [PREVIEW] PREVIEW returns sample rows of a definition, independent of deployed state.
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV
    PREVIEW ORDERS_DEV.SERVE.V_DAILY_REVENUE
    USING CONFIGURATION DEV
    FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.0/'
    LIMIT 5;


/* =============================================================================
   STEP 3 - FEATURE CHANGE IN DEV (release-1.1)                         ~3 min
   Diff between the two source folders (orders_project_1-0 vs orders_project_1-1):
     + RAW.ORDERS.CHANNEL column      -> ALTER TABLE ADD COLUMN (no data loss)
     + SERVE.V_REVENUE_BY_CHANNEL     -> CREATE VIEW
     + SELECT grant on the new view   -> GRANT
     ~ task body now fills CHANNEL    -> ALTER TASK
   ============================================================================= */

-- [GA] PLAN DELTA: fast inner loop, only changed definitions + downstream.
-- Does NOT detect drift - never use it as the pre-deploy check.
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV
    PLAN DELTA
    USING CONFIGURATION DEV
    FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.1/';

-- [GA] Full PLAN: the real gate before any deploy.
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV
    PLAN
    USING CONFIGURATION DEV
    FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.1/';

-- Read the changeset as rows (works on any PLAN/DEPLOY output).
SELECT c.value:type::STRING              AS ACTION,
       c.value:object_id:domain::STRING  AS OBJECT_TYPE,
       c.value:object_id:fqn::STRING     AS OBJECT_NAME
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) r,
     LATERAL FLATTEN(INPUT => r.$1:changeset) c
ORDER BY ACTION, OBJECT_TYPE;

EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV
    DEPLOY AS "feature-channel"
    USING CONFIGURATION DEV
    FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.1/';

EXECUTE TASK ORDERS_DEV.RAW.TSK_LOAD_SAMPLE_ORDERS;
CALL SYSTEM$WAIT(20);   -- EXECUTE TASK is asynchronous: give it time to load the rows
SELECT * FROM ORDERS_DEV.SERVE.V_REVENUE_BY_CHANNEL;


/* =============================================================================
   STEP 4 - PROMOTE: QA, then PRD. Same sources, different configuration.  ~5 min
   In CI this is: PR -> PLAN QA+PRD posted for review; merge -> deploy QA, gate,
   approval -> deploy PRD. Only the configuration differs per environment.
   ============================================================================= */

-- ---------- QA ----------
USE ROLE DCM_QA_DEPLOYER;

EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_QA
    PLAN
    USING CONFIGURATION QA
    FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.1/';

EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_QA
    DEPLOY AS "release-1.1"
    USING CONFIGURATION QA
    FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.1/';

EXECUTE TASK ORDERS_QA.RAW.TSK_LOAD_SAMPLE_ORDERS;
CALL SYSTEM$WAIT(20);   -- EXECUTE TASK is asynchronous: give it time to load the rows
ALTER DYNAMIC TABLE ORDERS_QA.ANALYTICS.DAILY_REVENUE REFRESH;

-- QA gate, option A [PREVIEW]: data quality expectations.
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_QA TEST ALL;

-- QA gate, option B [GA]: a plain SQL smoke test. FAIL => stop the pipeline.
SELECT IFF(COUNT(*) > 0
           AND COUNT_IF(ORDER_ID IS NULL) = 0
           AND COUNT(*) = COUNT(DISTINCT ORDER_ID)
           AND MIN(AMOUNT) >= 0, 'PASS', 'FAIL') AS QA_GATE,
       COUNT(*) AS ROWS_CHECKED
FROM ORDERS_QA.RAW.ORDERS;

-- ---------- PRD ----------
USE ROLE DCM_PROD_DEPLOYER;

EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_PRD
    PLAN
    USING CONFIGURATION PRD
    FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.1/';

-- Drop protection: must return ZERO rows before you are allowed to deploy.
-- (Like the sample GitHub action, this looks at containers & data objects;
--  a human still reviews the whole PLAN.)
SELECT c.value:object_id:domain::STRING AS OBJECT_TYPE,
       c.value:object_id:fqn::STRING    AS OBJECT_NAME
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) r,
     LATERAL FLATTEN(INPUT => r.$1:changeset) c
WHERE c.value:type::STRING = 'DROP'
  AND c.value:object_id:domain::STRING IN ('DATABASE', 'SCHEMA', 'TABLE', 'STAGE', 'DYNAMIC_TABLE');

-- Note: PRD config declares the task STARTED (hourly) and a SMALL warehouse.
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_PRD
    DEPLOY AS "release-1.1"
    USING CONFIGURATION PRD
    FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.1/';

SHOW TASKS IN SCHEMA ORDERS_PRD.RAW;   -- state = started


/* =============================================================================
   STEP 5 - DRIFT, CO-EXISTING GRANTS, RECOVERY, AUDIT (DEV)            ~4 min
   ============================================================================= */
USE ROLE DCM_DEVELOPER;

-- 5a. Someone "hot-fixes" DEV by hand.
ALTER WAREHOUSE ORDERS_WH_DEV SET AUTO_SUSPEND = 600;
GRANT SELECT ON VIEW ORDERS_DEV.SERVE.V_DAILY_REVENUE TO ROLE PUBLIC;

-- 5b. A full PLAN shows the warehouse drift (AUTO_SUSPEND 600 -> 60).
--     The PUBLIC grant does NOT show: DCM only manages grants it deployed.
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV
    PLAN
    USING CONFIGURATION DEV
    FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.1/';

-- 5c. Re-assert the defined state from the last deployment's rendered definitions.
--     (FROM DEPLOYMENT is the drift-remediation path; no sources needed.)
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV
    DEPLOY AS "drift-fix"
    FROM DEPLOYMENT "feature-channel";

SHOW WAREHOUSES LIKE 'ORDERS_WH_DEV';                                 -- auto_suspend back to 60
SHOW GRANTS ON VIEW ORDERS_DEV.SERVE.V_DAILY_REVENUE;                -- PUBLIC grant still there!
REVOKE SELECT ON VIEW ORDERS_DEV.SERVE.V_DAILY_REVENUE FROM ROLE PUBLIC;
-- Lesson: to enforce "no undeclared privileges", schedule a SHOW GRANTS
-- comparison or use a dedicated permissions tool.

-- 5d. Restore an earlier SHAPE. PLAN first: it shows dropping the CHANNEL column
--     and the new view. Restoring definitions is not restoring data - in PRD,
--     prefer rolling forward with a new release, and use Time Travel/clones for data.
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV
    PLAN
    FROM DEPLOYMENT "release-1.0";
-- To actually restore DEV (data in the CHANNEL column is lost):
-- EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV DEPLOY AS "restore-1.0" FROM DEPLOYMENT "release-1.0";

-- 5e. Audit trail - as the auditor role (READ + MONITOR, no deploy rights).
USE ROLE DCM_AUDITOR;
USE SECONDARY ROLES NONE;   -- otherwise your deployer roles act as secondary roles and the auditor CAN deploy
SHOW DEPLOYMENTS IN DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_PRD;
SELECT *
FROM TABLE(DCM_TRAINING.INFORMATION_SCHEMA.DCM_DEPLOYMENT_HISTORY(
           PROJECT_NAME => 'DCM_TRAINING.PROJECTS.ORDERS_DEV'));
SHOW ENTITIES IN DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_PRD;
-- This fails by design (auditor is not the owner) - only with secondary roles off:
-- EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_PRD PLAN FROM DEPLOYMENT LAST;
USE SECONDARY ROLES ALL;    -- restore the default


/* =============================================================================
   STEP 6 - OPTIONAL PATTERNS
   ============================================================================= */

-- 6a. Per-ticket sandbox (same sources, unique suffix, own project object).
USE ROLE DCM_DEVELOPER;
CREATE DCM PROJECT IF NOT EXISTS DCM_TRAINING.PROJECTS.ORDERS_SBX_STORY_1234;
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_SBX_STORY_1234
    PLAN
    USING CONFIGURATION SANDBOX (env_suffix => '_SBX_STORY_1234')
    FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.1/';

-- 6b. Seed a pre-production database from PRD with zero-copy cloning
--     (one account = cloning works). Clones keep fully-qualified references:
--     views/tasks inside still point at ORDERS_PRD until you redeploy them.
-- USE ROLE DCM_QA_DEPLOYER;
-- CREATE DATABASE IF NOT EXISTS ORDERS_QA_SEED CLONE ORDERS_PRD;

-- 6c. Hand an object off without dropping it (then remove its DEFINE before the next deploy).
-- ALTER TABLE ORDERS_DEV.RAW.ORDERS UNSET DCM PROJECT;
-- ALTER DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV UNMANAGE GRANT ...;   -- see ALTER DCM PROJECT docs


/* =============================================================================
   CLEANUP  -  !!! DESTRUCTIVE: drops every managed object and its data !!!
   PURGE is for DEV / sandboxes / demos only. Uncomment deliberately.
   DROP DCM PROJECT alone leaves the objects in place (unmanaged) and deletes history.
   ============================================================================= */
-- USE ROLE DCM_DEVELOPER;
-- EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_SBX_STORY_1234 PURGE AS "sandbox cleanup";
-- DROP DCM PROJECT IF EXISTS DCM_TRAINING.PROJECTS.ORDERS_SBX_STORY_1234;
-- EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV PURGE AS "training cleanup";
-- DROP DCM PROJECT IF EXISTS DCM_TRAINING.PROJECTS.ORDERS_DEV;
-- USE ROLE DCM_QA_DEPLOYER;
-- EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_QA PURGE AS "training cleanup";
-- DROP DCM PROJECT IF EXISTS DCM_TRAINING.PROJECTS.ORDERS_QA;
-- USE ROLE DCM_PROD_DEPLOYER;
-- EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_PRD PURGE AS "training cleanup";
-- DROP DCM PROJECT IF EXISTS DCM_TRAINING.PROJECTS.ORDERS_PRD;
-- USE ROLE ACCOUNTADMIN;
-- DROP DATABASE IF EXISTS DCM_TRAINING;
-- DROP WAREHOUSE IF EXISTS DCM_TRAINING_WH;
-- DROP ROLE IF EXISTS DCM_DEVELOPER; DROP ROLE IF EXISTS DCM_QA_DEPLOYER;
-- DROP ROLE IF EXISTS DCM_PROD_DEPLOYER; DROP ROLE IF EXISTS DCM_AUDITOR;
