/* =============================================================================
   DCM TRAINING - PURGE / FULL CLEANUP
   !!! DESTRUCTIVE: permanently drops every object managed by the projects,
   including table data, then removes the projects, roles and training container.
   Review before running. Run top to bottom; each section is independent.
   Safe even if nothing was deployed yet (PURGE then returns an empty changeset).

     snow sql -c <connection> -f dcm_training_purge.sql
   ============================================================================= */

-- Preview what will be dropped (read-only)
USE ROLE ACCOUNTADMIN;
SHOW DCM PROJECTS IN SCHEMA DCM_TRAINING.PROJECTS;
SHOW ENTITIES IN DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_PRD;

-- 1. PRD  (stops the hourly task, drops ORDERS_PRD, ORDERS_WH_PRD, ORDERS_*_PRD roles)
USE ROLE DCM_PROD_DEPLOYER;
USE WAREHOUSE DCM_TRAINING_WH;
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_PRD PURGE AS "training cleanup";
DROP DCM PROJECT IF EXISTS DCM_TRAINING.PROJECTS.ORDERS_PRD;

-- 2. QA
USE ROLE DCM_QA_DEPLOYER;
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_QA PURGE AS "training cleanup";
DROP DCM PROJECT IF EXISTS DCM_TRAINING.PROJECTS.ORDERS_QA;

-- 3. DEV
USE ROLE DCM_DEVELOPER;
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV PURGE AS "training cleanup";
DROP DCM PROJECT IF EXISTS DCM_TRAINING.PROJECTS.ORDERS_DEV;

-- 4. Sandbox (was only planned, never deployed: nothing to purge, just drop the project)
DROP DCM PROJECT IF EXISTS DCM_TRAINING.PROJECTS.ORDERS_SBX_STORY_1234;

-- 5. Training container, warehouse and deployer roles
USE ROLE ACCOUNTADMIN;
DROP DATABASE  IF EXISTS DCM_TRAINING;      -- also removes the SOURCES stage
DROP WAREHOUSE IF EXISTS DCM_TRAINING_WH;
DROP ROLE IF EXISTS DCM_DEVELOPER;
DROP ROLE IF EXISTS DCM_QA_DEPLOYER;
DROP ROLE IF EXISTS DCM_PROD_DEPLOYER;
DROP ROLE IF EXISTS DCM_AUDITOR;

-- 6. Verify nothing is left
SHOW DATABASES  LIKE 'ORDERS%';
SHOW WAREHOUSES LIKE 'ORDERS_WH%';
SHOW ROLES      LIKE 'ORDERS_%';
SHOW ROLES      LIKE 'DCM_%';
