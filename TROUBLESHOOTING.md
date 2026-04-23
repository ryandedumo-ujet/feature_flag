# Troubleshooting Guide

## Common Errors

### 1Password sign-in fails

**Symptom:** `op whoami` returns an error or `op signin` prompts fail  
**Fix:** Make sure the 1Password desktop app is running and you're signed in, then run:
```bash
op signin
```

---

### HTTP 401 from UJET API

**Symptom:** `Failed to update flag (HTTP 401)` or `Bulk patch failed (HTTP 401)`  
**Cause:** Wrong `project-id` or the token in 1Password is stale  
**Fix:**
1. Verify the item name in 1Password vault `ci-pre-prod` matches your `project-id` exactly
2. Confirm the item has a field named `ENV_API_USER_TOKEN`

---

### GitHub token errors

| HTTP code | Cause | Fix |
|-----------|-------|-----|
| 401 | Token invalid or expired | Update item `github-token` in vault `Employee` with a fresh token |
| 403 | Token lacks `repo` scope | Regenerate token at [github.com/settings/tokens](https://github.com/settings/tokens) with `repo` scope |
| 404 | No access to `UJET/ujet-server` | Confirm your GitHub account has repo access |

The script reads the GitHub token from 1Password: vault `Employee`, item `github-token`, field `API_TOKEN`.

---

### `flags.json` is empty or `{}`

**Cause:** Ruby parsing failed or the source file format changed  
**Fix:** Run the debug script (see below) and inspect `raw_content_debug.txt` to see what was fetched from GitHub.

---

## Debug Script

`debug_patch.sh` tests each step in isolation and saves the raw GitHub response to `raw_content_debug.txt` for inspection.

> **Note:** The debug script reads the GitHub token from the `GITHUB_TOKEN` environment variable (not 1Password). Set it before running:

```bash
export GITHUB_TOKEN="ghp_yourtokenhere"
./debug_patch.sh
```

To save full output:
```bash
./debug_patch.sh > debug_output.txt 2>&1
```

Then check:
- `raw_content_debug.txt` — raw content fetched from GitHub
- `debug_output.txt` — full debug run output
- `flags.json` — generated flags

---

## Manual GitHub API Test

Test access directly:

```bash
export GITHUB_TOKEN="ghp_yourtokenhere"
curl -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/UJET/ujet-server/contents/web/app/models/settings/feature_flag_setting.rb?ref=main"
```

Expected: JSON with file metadata. Any error indicates a token or access issue.

---

## Security Note

Never commit tokens or debug output files to git. The `.gitignore` already excludes `raw_content_debug.txt`, `debug_output.txt`, `.env`, and `*.token`.
