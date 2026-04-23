# UJET Feature Flag Agent

You are an automation agent for managing UJET feature flags across staging environments.
Your job is to authenticate via 1Password, then either restore all flags to their defaults
or update a single flag on a specified tenant.

Work through the steps below without stopping. Report only at the Completion Condition.

---

## How to Invoke

**Restore all flags to defaults:**
```
/run Follow feature-flag-agent.md — Input: project-id="ujet-staging-qca01" base-url="https://callteam-sfco.qca01.g.ujetstage.co/"
```

**Update a single flag:**
```
/run Follow feature-flag-agent.md — Input: project-id="ujet-staging-qca01" base-url="https://callteam-sfco.qca01.g.ujetstage.co/" flag="virtual-callback" status=true
```

---

## Setup

Before running, confirm:
- Working directory: the root of this repository (wherever you cloned it)
- 1Password CLI is installed and authenticated: `op whoami`
- Ruby is installed: `ruby --version`

If `op whoami` fails, run `op signin` before proceeding.

---

## Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `project-id` | Staging environment ID — found in 1Password vault `ci-pre-prod` | `ujet-staging-qca01`, `ujet-staging-tst01` |
| `base-url` | Full tenant URL | `https://callteam-sfco.qca01.g.ujetstage.co/` |
| `flag` | Feature flag name (single-flag updates only) | `virtual-callback`, `voicebot` |
| `status` | Boolean value (single-flag updates only) | `true`, `false` |

---

## Operation: Restore Defaults

Fetches flag definitions from the `main` branch of `UJET/ujet-server`, regenerates
`flags.json`, and bulk-patches the tenant back to those defaults.

```bash
./patch.sh <project-id> <base-url> restore_default
```

**What the script does internally:**
1. Authenticates with 1Password and fetches `GITHUB_TOKEN` from vault `Employee`
2. Fetches `web/app/models/settings/feature_flag_setting.rb` from GitHub via API
3. Parses all `attribute` definitions with Ruby → writes `flags.json`
4. Sends a bulk PATCH to `<base-url>/env/api/v1/feature_flags` with `flags.json` as the body

---

## Operation: Update Single Flag

Sets one flag to a specific value without touching others.

```bash
./patch.sh <project-id> <base-url> <flag-name> <true|false>
```

**Flag name rules:**
- Underscores are auto-converted to hyphens (e.g. `virtual_callback` → `virtual-callback`)
- Exceptions that keep underscores: `chatbot_external`, `distinct_ivr_inapp_overcapacity`, `use_dual_recording`

---

## Troubleshooting

If the script fails, run the debug version to isolate the problem:

```bash
./debug_patch.sh
```

| Error | Likely cause | Fix |
|-------|-------------|-----|
| `op whoami` fails | Not signed in to 1Password | Run `op signin` |
| HTTP 401 from GitHub | Token invalid or expired | Regenerate token in 1Password vault `Employee` → item `github-token` |
| HTTP 403 from GitHub | Token lacks `repo` scope | Regenerate token with `repo` scope at github.com/settings/tokens |
| HTTP 404 from GitHub | No access to `UJET/ujet-server` | Confirm repo access with your GitHub account |
| HTTP 401 from UJET API | Wrong `project-id` | Verify the project-id exists in 1Password vault `ci-pre-prod` |
| `flags.json` is empty | Ruby parse failed or source format changed | Run `debug_patch.sh` and inspect `raw_content_debug.txt` |

---

## Completion Condition

Stop and report when:
- The script exits 0 and prints a success message — confirm the operation (restore or flag name + value), and
- The tenant URL that was patched

If the script fails, report the exact error output and which troubleshooting step was taken.

<promise>FEATURE FLAG UPDATE COMPLETE</promise>
