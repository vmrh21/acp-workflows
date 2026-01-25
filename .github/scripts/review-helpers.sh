#!/bin/bash
# Helper functions for CVE review workflow

# Increment counter in temp file
increment_counter() {
  local file=$1
  local current=$(cat "$file" 2>/dev/null || echo "0")
  echo $((current + 1)) > "$file"
}

# Get counter value
get_counter() {
  local file=$1
  cat "$file" 2>/dev/null || echo "0"
}

# Analyze version change and classify risk
analyze_version_risk() {
  local current_version=$1
  local fix_version=$2
  local package_name=$3
  local ecosystem=$4

  if [[ "$fix_version" =~ ^[0-9]+ ]] && [[ "$current_version" =~ ^[0-9]+ ]]; then
    local fix_major=$(echo "$fix_version" | cut -d. -f1 | tr -d '^~>=<v')
    local current_major=$(echo "$current_version" | cut -d. -f1 | tr -d '^~>=<v')

    if [ "$fix_major" != "$current_major" ]; then
      echo "RISKY"
      increment_counter "/tmp/risky_fixes.txt"
    else
      echo "SAFE"
      increment_counter "/tmp/safe_fixes.txt"
    fi
  else
    echo "UNKNOWN"
    increment_counter "/tmp/missing_docs.txt"
  fi
}
