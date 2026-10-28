# DCM Projects training: DEV / QA / PRD in 40 minutes

A 40-minute, instructor-led training on Snowflake DCM Projects with a live hands-on lab. One data product ("Orders") is deployed to DEV, QA and PRD from one set of files.

## What is in this folder

| File / folder | What it is | When you use it |
|---|---|---|
| `dcm_training.html` | The training content (open in a browser, has a session timer) | During the call: what you present |
| `setup_training.sh` | **One-time prep**: sets your account in the manifests, then runs the setup | **Before** the call, once |
| `dcm_training_setup.sql` | Setup SQL (roles, project objects, source upload), called by `setup_training.sh` | **Before** the call, once |
| `dcm_training_companion.sql` | The lab, step by step (SQL) | **During** the call |
| `dcm_training_cli.sh` | The same lab steps as `snow dcm` commands (a cheat sheet, not a script) | During the call, copy one command at a time |
| `purge_training.sh` | Runs `dcm_training_purge.sql`, then resets the manifests to the placeholder | After the call |
| `dcm_training_purge.sql` | Removes everything the training created (called by `purge_training.sh`) | After the call |
| `orders_project_1-0/` | The DCM project, release 1.0 (before the feature) | Deployed first to DEV in the lab |
| `orders_project_1-1/` | The DCM project, release 1.1 (after the feature, = Git `main`) | Feature change, then promotion to QA and PRD |
| `.github/workflows/dcm.yml` | Reference CI/CD workflow | Shown in training section 5 |

### Two versions of one project

`orders_project_1-0` and `orders_project_1-1` stand in for two Git commits of the same project. The difference between them is the feature the lab promotes:

- a `CHANNEL` column on `RAW.ORDERS`;
- the `V_REVENUE_BY_CHANNEL` view and its grant;
- a task body that fills `CHANNEL`.

```bash
diff -r orders_project_1-0/sources orders_project_1-1/sources
```

They are uploaded to `@DCM_TRAINING.PROJECTS.SOURCES/release-1.0/` and `/release-1.1/`, and deployed with the matching aliases. Make your own changes in `orders_project_1-1`. Leave `orders_project_1-0` as the baseline.

**In short:** run `./setup_training.sh <connection>` once beforehand (sections 1-3), present `dcm_training.html`, run the lab from `dcm_training_companion.sql`, and clean up with `./purge_training.sh <connection>`.


---

## 1. Prerequisites (do this a few days before)

- A Snowflake account where you can use **ACCOUNTADMIN** (only the setup needs it).
- **Snowflake CLI 3.24.0 or later**:
  ```bash
  pip install --upgrade snowflake-cli      # or: uv tool install snowflake-cli
  snow --version
  ```
- A named connection in `~/.snowflake/connections.toml`, tested:
  ```bash
  snow connection test -c <connection>
  ```
  If you see *"Bad owner or permissions on connections.toml"* or *"has too wide permissions"*, run `chmod 0600 ~/.snowflake/connections.toml`. With CLI 3.31 this is a hard error: `snow` refuses to run until it is fixed.
- `jq`, for the drop-protection check in the CLI path.
- Make the two scripts executable once: `chmod +x setup_training.sh purge_training.sh` (or call them with `bash`).

## 2. Setup (the day before, about 5 minutes)

All commands run from this folder.

**Run one command:**
```bash
./setup_training.sh <connection>      # or: bash setup_training.sh <connection>
```
It is safe to re-run. It does three things in order:

1. **Points the manifests at your account.** It reads `SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME()` and writes the result into every `account_identifier` in both manifests, whatever the current value is. This has to happen before the upload in step 2.
2. **Runs `dcm_training_setup.sql`** and prints its full output. It creates:
   - the container `DCM_TRAINING.PROJECTS` and the warehouse `DCM_TRAINING_WH`;
   - the roles `DCM_DEVELOPER`, `DCM_QA_DEPLOYER`, `DCM_PROD_DEPLOYER` and `DCM_AUDITOR`, all granted to you;
   - the project objects `ORDERS_DEV`, `ORDERS_QA` and `ORDERS_PRD`;
   - the two project versions, uploaded to `@DCM_TRAINING.PROJECTS.SOURCES`.

   **It deploys nothing.**
3. **Shows the check.** The last two result sets of the setup output must show 3 DCM projects, each owned by its deployer role, and 18 files (`release-1.0/...` and `release-1.1/...`).

The manifests ship with the placeholder `MYORG-MYACCOUNT`. Your identifier stays in the local files during the session, because the `snow dcm --target` commands read them. Before you share or commit the folder, run `./setup_training.sh --reset`: it puts the placeholder back and deletes the CLI's `out/` folders. `purge_training.sh` does this for you.

To run the steps by hand instead: update `account_identifier` in both manifests, then `snow sql -c <connection> -f dcm_training_setup.sql -D "root=$PWD"`.

## 3. Rehearse and choose the starting point (recommended, about 20 minutes)

1. Run the lab once from `dcm_training_companion.sql`, steps 2 to 5 (see "During the call" below).
2. Reset to a clean state so the real session starts from zero:
   ```bash
   ./purge_training.sh <connection> --yes
   ./setup_training.sh <connection>
   ```

### Choose the lab starting point

The lab changes the account state. Before the session, pick one option:

| Option | When to use | What to do beforehand |
|---|---|---|
| **A. From zero** (recommended) | First time with the group | After the rehearsal: `./purge_training.sh <your_connection> --yes`, then `./setup_training.sh <your_connection>` |
| **B. Ready state** | Short session or unreliable network | Leave DEV/QA/PRD deployed and show the empty PLAN and the history |

> Tip: for option A, rehearse the whole lab once. The DEV deploy takes about 30 s, and each PLAN 5 to 10 s.

### Cost and security

- The **PRD** environment creates a `STARTED` task that runs **every hour** on a SMALL warehouse (60 s auto-suspend). After the session, run `./purge_training.sh <connection>`, or set `task_state` to `SUSPENDED` in the PRD configuration and redeploy.
- In the lab, the instructor is granted all three deployer roles. **Say explicitly** that this is a training shortcut: in production, `DCM_PROD_DEPLOYER` is granted only to a CI service user.

---

## 4. Delivering the session (40 minutes)

### Agenda

| Minutes | Section (HTML) | Instructor goal | Mode |
|---|---|---|---|
| 0-4 | 1. Why DCM | Establish the pain and present the principles | Slides / talk |
| 4-11 | 2. Concepts | Teach the mental model: project, manifest, DEFINE, PLAN/DEPLOY | Slides + 1 code snippet |
| 11-16 | 3. Environments | One rule at a time: 1 project per environment, templating, roles, sandbox | Diagram |
| 16-34 | 4. Hands-on lab | Run it live while attendees follow | Live demo |
| 34-38 | 5. CI/CD & prod | Pipeline, gotchas, anti-patterns, tool choice | Tables |
| 38-40 | 6. Recap | Checklist and next steps | Talk |

**Core message (repeat it three times during the session):**
> "The same files go to every environment. The only difference is configuration. And nothing is applied without a reviewed PLAN."

**Use the timer** in the HTML side panel (*Start* button). It shows which phase you should be in.

### Lab cheat sheet: where each step runs

Open three things:
- `dcm_training.html` in a browser (click **Start** on the timer);
- `dcm_training_companion.sql` in Snowsight or your IDE, connected with the same connection;
- a terminal in `orders_project_1-1/` for the CLI steps.

| Lab step | Where to run it | Notes |
|---|---|---|
| 1. Bootstrap | Nothing to run | Already done by setup. Just open `dcm_training_setup.sql` and explain it |
| 2. First DEV deploy (release 1.0) | Companion SQL, step 2 | PLAN, DEPLOY, re-PLAN (empty), load data, TEST ALL |
| 3. Feature change (release 1.1) | Companion SQL, step 3 | PLAN DELTA, then full PLAN, read the changeset, DEPLOY |
| 4. Promote QA, then PRD | Companion SQL, step 4, **or** the CLI commands in `dcm_training_cli.sh` | Same engine. The CLI path shows the drop check with `jq` |
| 5. Drift, recovery, audit | Companion SQL, step 5 | Run each statement only after the previous one finishes |
| 6. Optional patterns | Read only | Do not run PURGE live |

The exact commands and expected outputs for each step are in the detailed script below.

### Detailed script

#### Section 1: Why DCM (0-4 min)

**Suggested opening (30 s):**
> "Who here has made a 'quick fix' in production from a worksheet and later couldn't remember what changed? That's what we're getting rid of today."

**Key points:**
1. The pain: manual DDL, environments that drift apart, nobody knows "what changed on Tuesday".
2. DCM Projects = **declarative, native** change management (GA in August 2026). You describe the desired state; Snowflake computes the diff, orders it and applies it.
3. The 4 pillars: *Move faster, Deploy predictably, Stay traceable, Recover quickly*.
4. The 6 principles. Highlight two:
   - **Roll forward**: fix with a new change. Restoring definitions does not restore data.
   - **One owner per object**: two tools on the same object fight forever.

**Transition:** "To apply this, we need four concepts."

---

#### Section 2: Concepts (4-11 min)

**Key points, in the HTML's order:**

1. **Layers model** (1.5 min): DCM manages the objects *inside* databases (plus warehouses and roles). It does not manage users, SSO, account creation, or catalog, notification and security integrations.
   - Useful line: "dbt does DML and transformation; DCM does the DDL and the infrastructure around it."
2. **Declarative vs imperative** (1.5 min): show the *expand, migrate, contract* example. A diff sees before and after, not intent.
3. **Building blocks** (1.5 min): project (a schema-level object), manifest, definition files, and deployments (with a number and an alias).
4. **DEFINE = CREATE OR ALTER** (1 min). Read the snippet and stress:
   - fully qualified names;
   - **removing a DEFINE drops the object** on the next deploy;
   - a project cannot define its own parent database or schema.
5. **Lifecycle and commands** (1.5 min): CREATE, DEFINE, PLAN, DEPLOY AS, VERIFY, ITERATE.
   - "DEPLOY recomputes the changeset; it does **not** replay a saved PLAN."
   - Point out the **PREVIEW** tags: TEST, PREVIEW, GitHub Actions, PIPE/STREAM, policies.

**Engagement question:** "If I delete a DEFINE TABLE line and deploy, what happens?" Answer: the table is dropped. That's why the PLAN is a mandatory PR gate.

---

#### Section 3: Environment strategy (11-16 min)

Present the **4 rules** using the HTML diagram:

1. **One project object per environment.** Deploying another configuration into the same project drops whatever that configuration doesn't define.
2. **Template every account-level name** (`{{env_suffix}}`). Open the real `manifest.yml` and show `defaults` and `configurations` (DEV, QA, PRD, SANDBOX). Resolution has three tiers: defaults, then the configuration, then runtime (`USING ... (var => value)` / `--variable`).
3. **Separate owner roles:** DEVELOPER, QA_DEPLOYER, PROD_DEPLOYER and AUDITOR (READ + MONITOR, no deploy). Explain the *lockout* protection: roles the project creates are granted to `{{project_owner_role}}`.
4. **Sandbox per ticket + project shapes A/B/C.** Rule of thumb: loops of up to about 20 iterations. Cross-project dependencies always go in one direction.

**Punchline:** "One account is the best starting point, because zero-copy cloning only works within an account."

---

#### Section 4: Hands-on lab (16-34 min)

> Run it from `dcm_training_companion.sql` (SQL path) **or** with the commands in `dcm_training_cli.sh` (CLI path). Recommendation: DEV in SQL (more visual in Snowsight), and QA/PRD in the CLI, to show it is the same engine.

##### Step 1: Bootstrap (~3 min, already done during preparation)
Don't run it live (`dcm_training_setup.sql` already did it). Open the file and explain:
- each project is **created by its own deployer role**, which is why that role owns it;
- `GRANT READ, MONITOR ON DCM PROJECT ... TO ROLE DCM_AUDITOR`.

Quick check:
```sql
SHOW DCM PROJECTS IN SCHEMA DCM_TRAINING.PROJECTS;
```
Expected: `ORDERS_DEV` (owner DCM_DEVELOPER), `ORDERS_QA` (DCM_QA_DEPLOYER), `ORDERS_PRD` (DCM_PROD_DEPLOYER).

##### Step 2: First DEV deploy (~4 min)
```sql
USE ROLE DCM_DEVELOPER;
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV
  PLAN USING CONFIGURATION DEV FROM '@DCM_TRAINING.PROJECTS.SOURCES/release-1.0/';
```
**Expected:** 16 entries in the changeset:
- CREATE for the database (and its PUBLIC schema), the RAW/ANALYTICS/SERVE schemas, the warehouse, the table, the dynamic table, the view, the task, 2 database roles and 3 account roles;
- ALTER of the `DCM_DEVELOPER` role, which receives the new roles.

Grants and expectations appear **nested** inside each object.

Then:
```sql
EXECUTE DCM PROJECT ... DEPLOY AS "release-1.0" USING CONFIGURATION DEV FROM '.../release-1.0/';
-- Run the PLAN again:
-- Expected: "changeset": []  (idempotent!)
EXECUTE TASK ORDERS_DEV.RAW.TSK_LOAD_SAMPLE_ORDERS;   -- loads 100 rows
CALL SYSTEM$WAIT(20);                                 -- EXECUTE TASK is asynchronous
EXECUTE DCM PROJECT DCM_TRAINING.PROJECTS.ORDERS_DEV TEST ALL;   -- PREVIEW
```
**Expected from TEST ALL:** `status: SUCCESSFUL`, with NON_NEGATIVE_AMOUNT, NO_NULL_ORDER_IDS and UNIQUE_ORDER_IDS not violated.

**Talking points:**
- "Nobody ordered the files. DCM created the warehouse before the dynamic table that uses it."
- The `teams` loop generated `ORDERS_FINANCE_DEV` (with RAW access) and `ORDERS_MARKETING_DEV` (without).
- The task stayed `SUSPENDED`, because that is what the DEV configuration declares.

##### Step 3: Feature change, release 1.1 (~3 min)
Show the diff between `orders_project_1-0` and `orders_project_1-1`: the CHANNEL column, the new view, the grant and the task body.
> `orders_project_1-0/` plays the role of the **previous commit** in Git. Tell attendees: "in a real project these would be two commits; here they are two folders."
```sql
EXECUTE DCM PROJECT ... PLAN DELTA USING CONFIGURATION DEV FROM '.../release-1.1/';
EXECUTE DCM PROJECT ... PLAN       USING CONFIGURATION DEV FROM '.../release-1.1/';
```
**Expected (5 entries):**
- ALTER TABLE (CHANNEL column added);
- CREATE VIEW V_REVENUE_BY_CHANNEL;
- ALTER TASK (definition changed, with `prev_value` and `value`);
- ALTER DATABASE ROLE READER (new SELECT);
- ALTER ROLE DCM_DEVELOPER (OWNERSHIP of the new view).

Use the `LATERAL FLATTEN` query to show the changeset as rows.

> **Watch out:** the PLAN output column is already an **OBJECT**. Use `r.$1:changeset`; with `PARSE_JSON(r.$1)` the query fails.

Deploy: `DEPLOY AS "feature-channel"`.

**Message:** "PLAN DELTA is for your editing loop. The *gate* is always the full PLAN, because only it sees what someone changed by hand."

##### Step 4: Promote to QA and PRD (~5 min, via the CLI)
```bash
cd orders_project_1-1
snow dcm plan    --target QA --role DCM_QA_DEPLOYER --save-output -c <your_connection>
snow dcm deploy  --target QA --role DCM_QA_DEPLOYER --alias "release-1.1" -c <your_connection>
snow sql -c <your_connection> --role DCM_QA_DEPLOYER -q "EXECUTE TASK ORDERS_QA.RAW.TSK_LOAD_SAMPLE_ORDERS; CALL SYSTEM\$WAIT(20)"   # load data first
snow dcm refresh --target QA --role DCM_QA_DEPLOYER -c <your_connection>
snow dcm test    --target QA --role DCM_QA_DEPLOYER -c <your_connection>           # PREVIEW
```
**Expected:**
- `Planned 17 entities (16 to create, 1 to alter, 0 to drop)`;
- `Deployed 17 entities (16 created, 1 altered, 0 dropped)`;
- refresh: `REFRESHED +8 ... ORDERS_QA.ANALYTICS.DAILY_REVENUE`;
- `3 passed, 0 failed out of 3 total`.

> **Always pass `--role <project_owner>`.** The CLI uses the connection's role, not the manifest's `project_owner`. Without `--role`, it prints *"Role mismatch"* and the deployment history records e.g. `EXECUTOR_ROLE = ACCOUNTADMIN`, which undermines the separate-owner-role message.

The SQL *smoke test* (the GA alternative to TEST) should return `PASS | 100`.

PRD with drop protection:
```bash
snow dcm plan --target PRD --role DCM_PROD_DEPLOYER --save-output -c <your_connection>
jq '[.changeset[] | select(.type=="DROP")] | length' out/plan_result.json   # expected: 0
snow dcm deploy --target PRD --role DCM_PROD_DEPLOYER --alias "release-1.1" -c <your_connection>
```
> **Watch out:** with CLI 3.31, the file is written to `out/plan_result.json`, not `out/plan/plan_result.json`.

**Talking points:**
- In PRD the task is `started` (hourly cron) and the warehouse is **Small**. Same files, different configuration.
- The `STARTED` state is reapplied **on every deploy**: a manual `ALTER TASK ... SUSPEND` lasts only until the next release.
- Run the PLAN again: `No changes detected.`
- `snow dcm list-deployments`: `source_file_path` points to a **temporary stage** created by the CLI, and `git_commit_hash` is empty. That's why, in CI, the alias should be the commit SHA.
- A DEPLOY with no changes still records a deployment in the history, which is useful for audit.

##### Step 5: Drift, co-existing grants, recovery and audit (~4 min)
```sql
USE ROLE DCM_DEVELOPER;
ALTER WAREHOUSE ORDERS_WH_DEV SET AUTO_SUSPEND = 600;            -- "quick fix"
GRANT SELECT ON VIEW ORDERS_DEV.SERVE.V_DAILY_REVENUE TO ROLE PUBLIC;
EXECUTE DCM PROJECT ... PLAN USING CONFIGURATION DEV FROM '.../release-1.1/';
```
**Expected:** a single entry, ALTER `ORDERS_WH_DEV`, with `auto_suspend` changing from 600 to 60. **The PUBLIC grant does not appear.**

```sql
EXECUTE DCM PROJECT ... DEPLOY AS "drift-fix" FROM DEPLOYMENT "feature-channel";
SHOW WAREHOUSES LIKE 'ORDERS_WH_DEV';                 -- auto_suspend = 60
SHOW GRANTS ON VIEW ORDERS_DEV.SERVE.V_DAILY_REVENUE; -- the PUBLIC grant is still there!
REVOKE SELECT ON VIEW ORDERS_DEV.SERVE.V_DAILY_REVENUE FROM ROLE PUBLIC;
```
> **Execution tip:** run `SHOW WAREHOUSES` only **after** the deploy finishes. If it runs in parallel, you see the old value (600) and it looks as if the deploy failed.

Shape restore (PLAN only):
```sql
EXECUTE DCM PROJECT ... PLAN FROM DEPLOYMENT "release-1.0";
```
**Expected:** ALTER TABLE (removes CHANNEL), ALTER TASK, ALTER DATABASE ROLE and **DROP VIEW V_REVENUE_BY_CHANNEL**.

**Message:** "This restores the shape, not the data. In production, prefer *roll forward*. For data, use Time Travel or a clone."

Audit:
```sql
USE ROLE DCM_AUDITOR;
SELECT * FROM TABLE(DCM_TRAINING.INFORMATION_SCHEMA.DCM_DEPLOYMENT_HISTORY(
  PROJECT_NAME => 'DCM_TRAINING.PROJECTS.ORDERS_DEV'));
```
**Expected:** DEPLOYMENT$1 `release-1.0`, $2 `feature-channel` and $3 `drift-fix`, all `SUCCESSFUL`, with `CONFIGURATION_PROFILE` and `EXECUTOR_ROLE`. `drift-fix` shows `CONFIGURATION_PROFILE = NULL`, because `FROM DEPLOYMENT` re-uses rendered definitions and takes no configuration.

> **Secondary roles:** to show that the auditor cannot PLAN, run `USE SECONDARY ROLES NONE;` after `USE ROLE DCM_AUDITOR;`. Your user holds all deployer roles, so with the default `DEFAULT_SECONDARY_ROLES = ('ALL')` the auditor session can PLAN **and DEPLOY** through them (verified).

##### Step 6: Optional patterns and cleanup (~1 min, read only)
- Sandbox: `USING CONFIGURATION SANDBOX (env_suffix => '_SBX_STORY_1234')`. The PLAN generates the database `ORDERS_SBX_STORY_1234`.
- Seeding with a clone, hand-off (`UNSET DCM PROJECT`), PURGE and DROP: **don't run them live**, just explain them.

---

#### Section 5: CI/CD and production (34-38 min)

1. **Reference pipeline** (1.5 min): feature branch with a sandbox, then a PR with PLAN for QA and PRD, then on merge: deploy QA, gate, approval, PRD PLAN with no DROP, PRD deploy, refresh and test. Open `.github/workflows/dcm.yml` and point out:
   - `concurrency` per environment (serialized deploys);
   - `environment: PRD` (required reviewers);
   - OIDC (`id-token: write`, no password);
   - the `dcm/*` actions are in **PREVIEW**; the PRD job calls `snow` directly.
2. **Where the checks stop** (30 s): PLAN doesn't run task or procedure logic, and the drop check only looks at top-level data objects. A human still reads the PLAN.
3. **Production gotchas** (1 min): walk through the table. Highlight **partial deploys** (DDL commits as it goes; fix and redeploy) and the rule of **no secrets in definitions**.
4. **Adopting existing objects** (30 s): GET_DDL, change CREATE to DEFINE, PLAN until it shows no changes, then deploy.
5. **Anti-patterns and decision matrix** (30 s): show the table; don't discuss it row by row.

---

#### Section 6: Recap (38-40 min)

Read the **readiness checklist** aloud, item by item, and ask everyone to tick what they already have today.
Suggested close:
> "Next week, take *one* schema you maintain by hand, run GET_DDL, turn it into DEFINE and watch the PLAN come back empty. That's the first step."

---

## 5. Frequently asked questions

| Question | Answer |
|---|---|
| Does DCM replace Terraform? | No, they co-exist. Terraform handles the account and the cloud (integrations, network, account creation); DCM handles objects inside databases. Each object has a single owner. |
| What about dbt? | Complementary. dbt transforms (DML and models); DCM manages the DDL, grants and expectations around it. For simple pipelines, dynamic tables in DCM may be enough. |
| What about schemachange? | It's imperative and great for backfills, renames and frequent breaking changes. Many teams combine them: DCM for shape, plus a tracked imperative path for data. |
| How do I roll back? | `FROM DEPLOYMENT "alias"` restores **definitions**, not data. Prefer *roll forward*; for data, use Time Travel or a clone. |
| What if the deploy fails halfway? | Changes may be partially applied. Fix the cause and deploy again: DCM converges to the defined state. |
| Does it revoke grants made outside DCM? | No. It only manages the grants it deployed. To enforce "no undeclared privileges", use a scheduled SHOW GRANTS comparison or a dedicated tool (e.g. Permifrost). |
| How do I pause a managed task? | Change the state in the **definition/manifest** and redeploy. `ALTER TASK ... SUSPEND` is undone by the next deploy. |
| Can I use one project for both DEV and PRD? | No. A project has a single deployed instance; switching configuration drops what it doesn't define. Use one project per environment. |
| Does it work across multiple accounts? | Yes. Change `account_identifier` per target; `project_name` can be the same across accounts. |
| Where do the source files live? | A Snowsight Workspace, a Git repository clone in Snowflake, a stage, or a local directory (CLI). |
| Are TEST and PREVIEW GA? | No, they are still preview at GA (as are the GitHub Actions, PIPE, STREAM and policies). Use SQL smoke tests as a GA gate. |
| Who can look without deploying? | Roles with READ (what the project manages) and MONITOR (full history and artifacts). Only the OWNER can PLAN and DEPLOY. Secondary roles count: a user who also holds the owner role can deploy from an "auditor" session unless secondary roles are off. |

---

## 6. Live troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `snow: command not found` | The CLI isn't on the PATH | `uv tool update-shell`, or use `~/.local/bin/snow` |
| "Bad owner or permissions" / "too wide permissions" error | Permissions on `connections.toml` | `chmod 0600 ~/.snowflake/connections.toml` |
| `Role mismatch: manifest target specifies project_owner ...` | CLI uses the connection's role | Add `--role <project_owner>` to every `snow dcm` command |
| Auditor PLAN/DEPLOY succeeds instead of failing | Secondary roles include the deployer roles | `USE SECONDARY ROLES NONE;` |
| `Invalid argument types for function 'PARSE_JSON': (OBJECT)` | The PLAN output is already an OBJECT | Use `r.$1:changeset` |
| `jq: Could not open file out/plan/plan_result.json` | Path changed in CLI 3.31 | Use `out/plan_result.json` |
| PLAN fails on privileges | Wrong role active | `USE ROLE <project owner>`; only the OWNER can PLAN |
| `Cannot transfer ownership ... does not inherit that role` | Lockout protection | GRANT the target role to the project owner role |
| `SHOW WAREHOUSES` still shows 600 after the drift fix | The query ran before the deploy finished | Run it again after completion |
| PUT doesn't work in a worksheet | PUT needs local file access | Use `snow sql`, SnowSQL, or a Workspace path |
| TEST ALL returns FAILED | Empty table, or data violating an expectation | Run the task (`EXECUTE TASK`, then wait) and the refresh first |

---

## 7. After the session: cleanup

The PRD configuration starts a task that runs **every hour** on a SMALL warehouse. Clean up:
```bash
./purge_training.sh <connection>      # asks you to type PURGE; add --yes to skip
```
It runs `dcm_training_purge.sql`, then, only if the purge succeeded, puts the `MYORG-MYACCOUNT` placeholder back in the manifests and deletes the `out/` folders.
This is destructive: it drops all training databases, warehouses, roles and the `DCM_TRAINING` container. Alternatively, to keep everything but stop the cost, set `task_state: 'SUSPENDED'` in the PRD configuration of `orders_project_1-1/manifest.yml` and run `snow dcm deploy --target PRD --role DCM_PROD_DEPLOYER -c <connection>`. This needs your account in the manifests: if you already ran `--reset`, run `./setup_training.sh <connection>` first.

---

## Documentation

- [DCM Projects overview](https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-overview)
- [Create and deploy DCM Projects](https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-use)
- [EXECUTE DCM PROJECT reference](https://docs.snowflake.com/en/sql-reference/sql/execute-dcm-project)
- [Collaboration and CI/CD](https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-cicd)
- [Supported entities (check GA vs preview)](https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-supported-entities)
- [DevOps with Snowflake](https://docs.snowflake.com/en/developer-guide/builders/devops-with-snowflake)

> The official documentation is the source of truth: each feature's status (GA or preview) can change.
