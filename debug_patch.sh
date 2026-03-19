#!/bin/bash

# Debug version of patch.sh to troubleshoot empty JSON issue

# --- CONFIGURATION ---
GITHUB_URL="https://api.github.com/repos/UJET/ujet-server/contents/web/app/models/settings/feature_flag_setting.rb?ref=main"
VAULT="ci-pre-prod"
TEMP_FILE="flags.json"

echo "🔍 DEBUG MODE - Checking GitHub Token..."

# Check if GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ ERROR: GITHUB_TOKEN environment variable is not set!"
    echo ""
    echo "To fix this, run:"
    echo "  export GITHUB_TOKEN='your_github_personal_access_token'"
    echo ""
    echo "To create a GitHub token:"
    echo "  1. Go to https://github.com/settings/tokens"
    echo "  2. Click 'Generate new token (classic)'"
    echo "  3. Select 'repo' scope"
    echo "  4. Copy the token and export it"
    exit 1
else
    echo "✅ GITHUB_TOKEN is set (length: ${#GITHUB_TOKEN} characters)"
fi

echo ""
echo "📥 Fetching source from GitHub..."
RAW_CONTENT=$(curl -sL -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw" "$GITHUB_URL")

# Check if content was fetched
if [ -z "$RAW_CONTENT" ]; then
    echo "❌ ERROR: Failed to fetch content from GitHub!"
    echo ""
    echo "Testing GitHub API access..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_URL")
    echo "HTTP Status Code: $HTTP_CODE"
    
    if [ "$HTTP_CODE" == "401" ]; then
        echo "❌ Authentication failed - check your GITHUB_TOKEN"
    elif [ "$HTTP_CODE" == "404" ]; then
        echo "❌ File not found - check the GitHub URL"
    elif [ "$HTTP_CODE" == "403" ]; then
        echo "❌ Access forbidden - check token permissions"
    else
        echo "❌ Unexpected error - HTTP $HTTP_CODE"
    fi
    exit 1
else
    CONTENT_LENGTH=${#RAW_CONTENT}
    echo "✅ Content fetched successfully ($CONTENT_LENGTH characters)"
    echo ""
    echo "First 200 characters of content:"
    echo "${RAW_CONTENT:0:200}"
    echo "..."
fi

echo ""
echo "🏗️  Generating $TEMP_FILE with Ruby..."

# Save raw content for debugging
echo "$RAW_CONTENT" > raw_content_debug.txt
echo "📝 Raw content saved to: raw_content_debug.txt"

# Run the Ruby parsing
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
    
    body.scan(/attribute\s+:(\w+).*?default:\s*(\[.*?\]|[^,\n\s]+)/m).each do |inner_name, inner_val|
      if inner_val =~ /^\[/
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

  STDERR.puts "🔍 Found #{final_flags.size} feature flags"
  
  # Sort the output alphabetically
  sorted_flags = Hash[final_flags.sort]
  File.write("flags.json", JSON.pretty_generate(sorted_flags))
  
  STDERR.puts "✅ flags.json generated successfully"
'

RUBY_EXIT_CODE=$?

if [ $RUBY_EXIT_CODE -ne 0 ]; then
    echo "❌ Ruby parsing failed with exit code: $RUBY_EXIT_CODE"
    exit 1
fi

# Check if file was created and has content
if [ -s "$TEMP_FILE" ]; then
    FILE_SIZE=$(wc -c < "$TEMP_FILE")
    echo "✅ $TEMP_FILE created successfully ($FILE_SIZE bytes)"
    echo ""
    echo "Preview of generated flags.json:"
    head -n 20 "$TEMP_FILE"
else
    echo "❌ Error: $TEMP_FILE is empty or was not created"
    exit 1
fi

