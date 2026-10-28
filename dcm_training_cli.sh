#!/usr/bin/env bash
# =============================================================================
# DCM training - Snowflake CLI equivalents of dcm_training_companion.sql
# Requires Snowflake CLI >= 3.24.0   (pip install --upgrade snowflake-cli)
#
# THIS IS NOT A SETUP SCRIPT, AND IT IS NOT MEANT TO BE RUN END TO END.
# It is a cheat sheet for the live demo (lab steps 2-4): copy one command at a
# time into the terminal and read each PLAN before the next DEPLOY.
# Setup is done once, beforehand, with dcm_training_setup.sql (see README.md).
#
# The CLI reads targets from manifest.yml: --target picks the project object
# and the templating configuration. It does NOT switch to the manifest's
# project_owner: pass --role, or the deploy runs as the connection's role.
#   export SNOWFLAKE_CONNECTION=<your connection>; cd orders_project_1-1
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Reference only: copy the commands one by one (see README.md). Not executed."; exit 0
fi

CONN="${SNOWFLAKE_CONNECTION:-default}"   # named connection in ~/.snowflake/connections.toml

snow --version
snow connection test -c "$CONN"

# --- Inner dev loop (DEV) ----------------------------------------------------
DEV="--role DCM_DEVELOPER"; QA="--role DCM_QA_DEPLOYER"; PRD="--role DCM_PROD_DEPLOYER"
snow dcm raw-analyze --target DEV $DEV -c "$CONN"            # static analysis: errors, dependencies, lineage
snow dcm plan --target DEV $DEV --delta -c "$CONN"           # fast feedback on changed definitions only
snow dcm plan --target DEV $DEV --save-output -c "$CONN"     # full plan -> out/plan_result.json
snow dcm deploy --target DEV $DEV --alias "feature-channel" -c "$CONN"
snow dcm test --target DEV $DEV -c "$CONN"                   # [PREVIEW] TEST ALL
snow dcm preview --target DEV $DEV --object ORDERS_DEV.SERVE.V_REVENUE_BY_CHANNEL --limit 5 -c "$CONN"   # [PREVIEW]

# --- Per-ticket sandbox --------------------------------------------------------
TICKET="STORY_1234"
snow dcm create "DCM_TRAINING.PROJECTS.ORDERS_SBX_${TICKET}" --target SANDBOX $DEV --if-not-exists -c "$CONN"
snow dcm plan   "DCM_TRAINING.PROJECTS.ORDERS_SBX_${TICKET}" --target SANDBOX $DEV \
     --variable "env_suffix='_SBX_${TICKET}'" -c "$CONN"
snow dcm deploy "DCM_TRAINING.PROJECTS.ORDERS_SBX_${TICKET}" --target SANDBOX $DEV \
     --variable "env_suffix='_SBX_${TICKET}'" --alias "${TICKET}" -c "$CONN"

# --- Promotion (normally done by CI, see .github/workflows/dcm.yml) ------------
snow dcm plan   --target QA  $QA --save-output -c "$CONN"
snow dcm deploy --target QA  $QA --alias "release-1.1" -c "$CONN"
snow sql $QA -q "EXECUTE TASK ORDERS_QA.RAW.TSK_LOAD_SAMPLE_ORDERS; CALL SYSTEM\$WAIT(20)" -c "$CONN"   # load data
snow dcm refresh --target QA $QA -c "$CONN"
snow dcm test   --target QA  $QA -c "$CONN"                  # [PREVIEW] gate

snow dcm plan   --target PRD $PRD --save-output -c "$CONN"
# Drop protection on the saved plan: abort if it drops a container or data object.
if jq -e '[.changeset[] | select(.type=="DROP" and (.object_id.domain|IN("DATABASE","SCHEMA","TABLE","STAGE","DYNAMIC_TABLE")))] | length > 0' \
      out/plan_result.json >/dev/null; then
  echo "PLAN contains DROP of a data object - refusing to deploy PRD"; exit 1
fi
snow dcm deploy --target PRD $PRD --alias "release-1.1" -c "$CONN"

# --- Observability ----------------------------------------------------------------
snow dcm list-deployments --target PRD $PRD -c "$CONN"
snow sql $PRD -q "SHOW ENTITIES IN DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_PRD" -c "$CONN"
snow dcm refresh --target PRD $PRD -c "$CONN"                     # refresh managed dynamic tables after deploy

# --- Cleanup: !!! DESTRUCTIVE - drops every managed object and its data !!! ---------
# snow dcm purge "DCM_TRAINING.PROJECTS.ORDERS_SBX_${TICKET}" $DEV -c "$CONN"
# snow dcm drop  "DCM_TRAINING.PROJECTS.ORDERS_SBX_${TICKET}" $DEV -c "$CONN"
