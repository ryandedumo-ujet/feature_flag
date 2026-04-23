# Feature Flag Repository

## Overview

This is an internal UJET tool for managing feature flags across staging environments. It can:
- Restore all feature flags on a tenant to their default values (pulled from `main` in `UJET/ujet-server`)
- Update a single feature flag on a tenant to a specific value

## Prerequisites

- **Git** 2.0+
- **Ruby** 3.0+ (required for parsing flag definitions)
- **curl** (standard on macOS/Linux)
- **1Password CLI** (`op`) v2+ — authenticated and unlocked
- Access to the private `UJET/ujet-server` GitHub repository
- The following items in 1Password:
  - Vault `ci-pre-prod`: one item per staging environment (e.g., `ujet-staging-qca01`) with field `ENV_API_USER_TOKEN`
  - Vault `Employee`: item named `github-token` with field `API_TOKEN`

## Getting Started

```bash
git clone https://github.com/ryandedumo-ujet/feature_flag.git
cd feature_flag
```

## Repository Structure

```
feature_flag/
├── patch.sh               # Main script
├── debug_patch.sh         # Debug version — isolates auth/fetch/parse failures
├── flags.json             # Default flag values (auto-updated by restore_default)
├── feature-flag-agent.md  # Claude Code agent instructions
├── TROUBLESHOOTING.md     # Detailed troubleshooting guide
└── README.md              # This file
```

## Usage

### Restore all flags to defaults

Fetches current defaults from `UJET/ujet-server` `main`, regenerates `flags.json`, and bulk-patches the tenant.

```bash
./patch.sh <project-id> <base-url> restore_default
```

**Parameters:**
- `project-id` — Staging environment ID, found in 1Password vault `ci-pre-prod` (e.g., `ujet-staging-qca01`, `ujet-staging-tst01`)
- `base-url` — Full tenant URL (e.g., `https://callteam-sfco.qca01.g.ujetstage.co/`)

**Example:**
```bash
./patch.sh ujet-staging-qca01 https://callteam-sfco.qca01.g.ujetstage.co/ restore_default
```

### Update a single flag

```bash
./patch.sh <project-id> <base-url> <flag-name> <true|false>
```

**Parameters:**
- `project-id` — Same as above
- `base-url` — Same as above
- `flag-name` — Feature flag name (e.g., `virtual-callback`, `voicebot`)
- `true|false` — New value for the flag

**Example:**
```bash
./patch.sh ujet-staging-qca01 https://callteam-sfco.qca01.g.ujetstage.co/ virtual-callback true
```

**Flag name note:** Underscores are automatically converted to hyphens, except for these flags which keep underscores: `chatbot_external`, `distinct_ivr_inapp_overcapacity`, `use_dual_recording`.

## Authentication

The script authenticates entirely through 1Password CLI. No environment variables need to be set.

When the script runs, it will:
1. Check that `op whoami` succeeds — if not, it prompts you to run `op signin`
2. Fetch `ENV_API_USER_TOKEN` from vault `ci-pre-prod`, item matching your `project-id`
3. Fetch the GitHub token from vault `Employee`, item `github-token`, field `API_TOKEN`

## Debugging

If the script fails, run the debug version which tests each step in isolation:

```bash
./debug_patch.sh
```

> **Note:** `debug_patch.sh` reads the GitHub token from the `GITHUB_TOKEN` environment variable rather than 1Password. Set it before running:
> ```bash
> export GITHUB_TOKEN="ghp_yourtokenhere"
> ./debug_patch.sh
> ```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common error resolutions.

## Using with Claude Code (feature-flag-agent.md)

The `feature-flag-agent.md` file lets Claude Code run this script as an agent. See that file for invocation instructions.
