# Troubleshooting Guide - Empty flags.json

## Problem
When running `./patch.sh` with `restore_default`, the `flags.json` file is empty or contains only `{}`.

## Root Cause
The script requires a GitHub Personal Access Token to fetch the feature flag definitions from the UJET server repository, but the `GITHUB_TOKEN` environment variable is not set or is invalid.

---

## Solution Steps

### Step 1: Check if GITHUB_TOKEN is set

```bash
echo $GITHUB_TOKEN
```

**Expected Output:** Your GitHub token should be displayed  
**If Empty:** The token is not set - proceed to Step 2

### Step 2: Create a GitHub Personal Access Token

1. Go to [GitHub Settings > Tokens](https://github.com/settings/tokens)
2. Click **"Generate new token (classic)"**
3. Give it a descriptive name (e.g., "UJET Feature Flags Script")
4. Select the following scopes:
   - ✅ `repo` (Full control of private repositories)
5. Click **"Generate token"**
6. **Copy the token immediately** (you won't be able to see it again!)

### Step 3: Set the GITHUB_TOKEN environment variable

#### For Current Session Only:
```bash
export GITHUB_TOKEN="ghp_your_token_here"
```

#### For Permanent Setup (add to your shell profile):

**For Bash (~/.bashrc or ~/.bash_profile):**
```bash
echo 'export GITHUB_TOKEN="ghp_your_token_here"' >> ~/.bashrc
source ~/.bashrc
```

**For Zsh (~/.zshrc):**
```bash
echo 'export GITHUB_TOKEN="ghp_your_token_here"' >> ~/.zshrc
source ~/.zshrc
```

### Step 4: Verify the token is set

```bash
echo $GITHUB_TOKEN
```

You should see your token displayed.

### Step 5: Run the debug script

```bash
chmod +x debug_patch.sh
./debug_patch.sh
```

This will show you detailed information about what's happening and where it might be failing.

### Step 6: Try the original script again

```bash
./patch.sh <project_id> <url> restore_default
```

---

## Common Issues

### Issue 1: "401 Unauthorized"
**Cause:** Invalid or expired GitHub token  
**Solution:** Generate a new token and update the `GITHUB_TOKEN` variable

### Issue 2: "403 Forbidden"
**Cause:** Token doesn't have the required permissions  
**Solution:** Regenerate the token with `repo` scope selected

### Issue 3: "404 Not Found"
**Cause:** The GitHub repository URL in the script is incorrect or you don't have access  
**Solution:** Verify you have access to the `UJET/ujet-server` repository

### Issue 4: Ruby parsing errors
**Cause:** The source file format has changed  
**Solution:** Check the `raw_content_debug.txt` file created by the debug script to see what was fetched

---

## Quick Test

Test if you can access the GitHub API:

```bash
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/UJET/ujet-server/contents/web/app/models/settings/feature_flag_setting.rb?ref=main
```

**Expected:** You should see JSON response with file information  
**If Error:** Check your token and repository access

---

## Still Having Issues?

1. Run the debug script and save the output:
   ```bash
   ./debug_patch.sh > debug_output.txt 2>&1
   ```

2. Check the generated files:
   - `raw_content_debug.txt` - Raw content from GitHub
   - `debug_output.txt` - Full debug output
   - `flags.json` - Generated flags file

3. Contact the repository maintainer with:
   - The debug output
   - Any error messages
   - Your GitHub username (to verify repository access)

---

## Security Note

⚠️ **Never commit your GitHub token to version control!**

Make sure `.gitignore` includes:
```
*.token
.env
debug_output.txt
raw_content_debug.txt
```

