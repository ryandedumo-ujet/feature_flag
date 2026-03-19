#!/bin/bash
set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# --- CONFIGURATION ---
readonly GITHUB_URL="https://api.github.com/repos/UJET/ujet-server/contents/web/app/models/settings/feature_flag_setting.rb?ref=main"
readonly VAULT="ci-pre-prod"
readonly TEMP_FILE="flags.json"
readonly EXCEPTIONS=("chatbot_external" "distinct_ivr_inapp_overcapacity" "use_dual_recording")

# --- ARGUMENTS ---
readonly PROJECT_ID="${1:-}"
readonly BASE_URL="${2:-}"
readonly ACTION="${3:-}"
readonly STATUS="${4:-}"

# --- HELPER FUNCTIONS ---
error_exit() {
    echo "❌ ERROR: $1" >&2
    exit "${2:-1}"
}

log_info() {
    echo "$1"
}

log_success() {
    echo "✅ $1"
}

validate_args() {
    if [[ -z "$PROJECT_ID" || -z "$BASE_URL" || -z "$ACTION" ]]; then
        error_exit "Usage: ./patch.sh <project_id> <url> <action/flag_name> [value]

Examples:
  Restore defaults:  ./patch.sh myproject https://api.example.com restore_default
  Update flag:       ./patch.sh myproject https://api.example.com my-flag true" 1
    fi

    # Validate STATUS is provided when not using restore_default
    if [[ "$ACTION" != "restore_default" && -z "$STATUS" ]]; then
        error_exit "Value of feature flag:$ACTION is required when updating a specific flag" 1
    fi
}

# Normalize flag name (convert underscores to hyphens, except for exceptions)
normalize_flag_name() {
    local flag="$1"
    for exception in "${EXCEPTIONS[@]}"; do
        [[ "$flag" == "$exception" ]] && echo "$flag" && return
    done
    echo "${flag//_/-}"
}

# --- AUTH & ENDPOINT ---
get_auth_token() {
    local secret_code
    secret_code=$(op item get "$PROJECT_ID" --vault "$VAULT" --fields label=ENV_API_USER_TOKEN --reveal 2>/dev/null) || \
        error_exit "Failed to retrieve secret from 1Password. Check PROJECT_ID and vault access." 1
    echo -n "$PROJECT_ID:$secret_code" | base64
}

validate_args
readonly AUTH_TOKEN=$(get_auth_token)
readonly UJET_AUTH="Authorization: Basic $AUTH_TOKEN"
readonly FULL_ENDPOINT="${BASE_URL%/}/env/api/v1/feature_flags"

# --- GITHUB FETCH FUNCTIONS ---
fetch_github_content() {
    [[ -z "${GITHUB_TOKEN:-}" ]] && error_exit "GITHUB_TOKEN is not set. Export it in your environment or shell profile." 1

    log_info "📥 Fetching source from GitHub..."
    local content
    content=$(curl -sL -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw" "$GITHUB_URL")

    if [[ -z "$content" ]]; then
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_URL")

        case "$http_code" in
            401) error_exit "Authentication failed. GITHUB_TOKEN is invalid or expired.\n   Generate new token: https://github.com/settings/tokens" 1 ;;
            404) error_exit "File not found. Check access to UJET/ujet-server repository." 1 ;;
            403) error_exit "Access forbidden. Token may lack 'repo' scope.\n   Regenerate with proper permissions." 1 ;;
            *)   error_exit "GitHub API request failed with HTTP $http_code" 1 ;;
        esac
    fi

    log_success "Content fetched successfully (${#content} characters)"
    echo "$content"
}

# --- RUBY PARSING FUNCTION ---
generate_flags_json() {
    local raw_content="$1"

    log_info "🏗️  Generating $TEMP_FILE..."

    echo "$raw_content" | ruby -rjson -e '
      EXCEPTIONS = ["chatbot_external", "distinct_ivr_inapp_overcapacity", "use_dual_recording"]
      content = STDIN.read.gsub(/^\s*#.*$/, "")
      final_flags = {}

      def clean_val(v)
        return nil if v.nil?
        v = v.strip
        return true if v == "true"
        return false if v == "false"
        return nil if v == "nil" || v == "nil,"
        return v.to_i if v =~ /^\d+$/
        v.gsub(/[\x27\x22]/, "")
      end

      # Parse Nested Blocks
      content.scan(/attribute\s+:(\w+)\s+do\n(.+?)\n\s+end/m).each do |parent, body|
        key = EXCEPTIONS.include?(parent) ? parent : parent.gsub("_", "-")
        block_data = {}

        body.scan(/attribute\s+:(\w+).*?default:\s*(\[.*?\]|[^,\n\s]+)/m).each do |inner_name, inner_val|
          block_data[inner_name] = if inner_val =~ /^\[/
            inner_val.scan(/[\x27\x22]([^\x27\x22]+)[\x27\x22]/).flatten
          else
            clean_val(inner_val)
          end
        end
        final_flags[key] = block_data
      end

      # Parse Simple Attributes
      content.scan(/attribute\s+:(\w+).*?default:\s*([^,\n\s]+)/).each do |name, val_str|
        next if name == "enabled"
        key = EXCEPTIONS.include?(name) ? name : name.gsub("_", "-")
        final_flags[key] ||= clean_val(val_str)
      end

      STDERR.puts "✅ Parsed #{final_flags.size} feature flags"
      File.write("flags.json", JSON.pretty_generate(final_flags.sort.to_h))
    ' || error_exit "Ruby parsing failed. Source file format may have changed." "$?"

    [[ ! -s "$TEMP_FILE" ]] && error_exit "$TEMP_FILE is empty or was not created." 1

    local file_size
    file_size=$(wc -c < "$TEMP_FILE" | tr -d ' ')
    log_success "$TEMP_FILE generated successfully ($file_size bytes)"
}

# --- API PATCH FUNCTIONS ---
send_bulk_patch() {
    log_info "🚀 Sending bulk patch to: $FULL_ENDPOINT"

    local response
    response=$(curl -sS -o /dev/null -w "%{http_code}" --request PATCH "$FULL_ENDPOINT" \
        -H "$UJET_AUTH" \
        -H "Content-Type: application/json" \
        -d @"$TEMP_FILE")

    if [[ "$response" =~ ^(200|204)$ ]]; then
        log_success "Bulk patch successful! (HTTP $response)"
    else
        error_exit "Bulk patch failed (HTTP $response). Check $TEMP_FILE for correctness." 1
    fi
}

send_single_patch() {
    local flag
    flag=$(normalize_flag_name "$ACTION")

    log_info "🚀 Patching single flag: $flag -> $STATUS"

    local response
    response=$(curl -sS -w "\n%{http_code}" --request PATCH "$FULL_ENDPOINT" \
        -H "$UJET_AUTH" \
        -H "Content-Type: application/json" \
        -d "{\"$flag\": $STATUS}")

    local http_code="${response##*$'\n'}"
    local body="${response%$'\n'*}"

    if [[ "$http_code" =~ ^(200|204)$ ]]; then
        log_success "Flag updated successfully! (HTTP $http_code)"
    else
        error_exit "Failed to update flag (HTTP $http_code)\nResponse: $body" 1
    fi
}

# --- MAIN EXECUTION ---
if [[ "$ACTION" == "restore_default" ]]; then
    raw_content=$(fetch_github_content)
    generate_flags_json "$raw_content"
    send_bulk_patch

else
    send_single_patch
fi