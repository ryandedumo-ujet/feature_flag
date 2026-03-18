#!/bin/bash

# --- CONFIGURATION ---
GITHUB_URL="https://api.github.com/repos/UJET/ujet-server/contents/web/app/models/settings/feature_flag_setting.rb?ref=main"
VAULT="ci-pre-prod"
TEMP_FILE="flags.json"

PROJECT_ID=$1; BASE_URL=$2; ACTION=$3; STATUS=$4

if [ -z "$PROJECT_ID" ] || [ -z "$BASE_URL" ] || [ -z "$ACTION" ]; then
    echo "Usage: ./patch.sh <project_id> <url> <action/flag_name> [true/false]"
    exit 1
fi

# --- AUTH & ENDPOINT ---
SECRET_CODE=$(op item get "$PROJECT_ID" --vault "$VAULT" --fields label=ENV_API_USER_TOKEN --reveal)
AUTH_TOKEN=$(echo -n "$PROJECT_ID:$SECRET_CODE" | base64)
UJET_AUTH="Authorization: Basic $AUTH_TOKEN"
FULL_ENDPOINT="${BASE_URL%/}/env/api/v1/feature_flags"

# --- EXECUTION ---
if [ "$ACTION" == "restore_default" ]; then
    echo "📥 Fetching source from GitHub..."
    RAW_CONTENT=$(curl -sL -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw" "$GITHUB_URL")

    echo "🏗️  Generating $TEMP_FILE..."
    
    echo "$RAW_CONTENT" | ruby -rjson -e '
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

      # 1. Parse Nested Blocks
      content.scan(/attribute\s+:(\w+)\s+do\n(.+?)\n\s+end/m).each do |parent, body|
        key = EXCEPTIONS.include?(parent) ? parent : parent.gsub("_", "-")
        block_data = {}
        
        # SWAPPED REGEX ORDER: Look for the [array] first, then fallback to simple words
        body.scan(/attribute\s+:(\w+).*?default:\s*(\[.*?\]|[^,\n\s]+)/m).each do |inner_name, inner_val|
          if inner_val =~ /^\[/
            # Extract all string items inside the array brackets
            block_data[inner_name] = inner_val.scan(/[\x27\x22]([^\x27\x22]+)[\x27\x22]/).flatten
          else
            block_data[inner_name] = clean_val(inner_val)
          end
        end
        final_flags[key] = block_data
      end

      # 2. Parse Simple Attributes
      content.scan(/attribute\s+:(\w+).*?default:\s*([^,\n\s]+)/).each do |name, val_str|
        next if name == "enabled"
        key = EXCEPTIONS.include?(name) ? name : name.gsub("_", "-")
        unless final_flags.has_key?(key)
          final_flags[key] = clean_val(val_str)
        end
      end

      # Sort the output alphabetically
      sorted_flags = Hash[final_flags.sort]
      File.write("flags.json", JSON.pretty_generate(sorted_flags))
    '

    # --- VERIFICATION PREVIEW ---
    if [ -s "$TEMP_FILE" ]; then
        echo "🔍 Previewing Array Extraction:"
        grep -A 10 '"amb-device-capability-overrides":' "$TEMP_FILE"
        echo "--------------------------------------"
    else
        echo "❌ Error: $TEMP_FILE generation failed."
        exit 1
    fi

    echo "🚀 Sending Bulk Patch to: $FULL_ENDPOINT"
    RESPONSE=$(curl --location --request PATCH "$FULL_ENDPOINT" \
      -s -o /dev/null -w "%{http_code}" \
      -H "$UJET_AUTH" \
      -H "Content-Type: application/json" \
      -d @"$TEMP_FILE")

    if [[ "$RESPONSE" == "200" || "$RESPONSE" == "204" ]]; then
        echo "✅ Success! (Status: $RESPONSE)"
    else
        echo "❌ Failed (Status: $RESPONSE)."
        echo "Check $TEMP_FILE — if it looks correct, the server might require smaller chunks."
    fi

else
    # Individual Manual Patch
    FLAG=$ACTION
    [[ "$FLAG" != "chatbot_external" && "$FLAG" != "distinct_ivr_inapp_overcapacity" && "$FLAG" != "use_dual_recording" ]] && FLAG="${FLAG//_/-}"
    echo "🚀 Patching single flag: $FLAG -> $STATUS"
    curl --location --request PATCH "$FULL_ENDPOINT" -i -s -H "$UJET_AUTH" -H "Content-Type: application/json" -d "{\"$FLAG\": $STATUS}" | grep "HTTP/"
fi