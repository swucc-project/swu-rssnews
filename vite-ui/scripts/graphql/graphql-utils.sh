#!/bin/bash

# Get the type of schema (placeholder or real)
get_schema_type() {
  local schema_file="./apollo/schema.graphql"
  
  if [ ! -f "$schema_file" ]; then
    echo "missing"
    return
  fi
  
  if head -n 20 "$schema_file" | grep -q "_placeholder"; then
    echo "placeholder"
  else
    echo "real"
  fi
}

# Check if schema is ready for production
is_schema_ready() {
  [ "$(get_schema_type)" = "real" ]
}

# Force regenerate placeholder files
force_placeholder_generation() {
  echo "🔄 Forcing placeholder file generation..."
  node scripts/assure-graphql-files.mjs
}

# Check schema status and print info
check_schema_status() {
  local status=$(get_schema_type)
  echo "📋 Schema status: $status"
  
  case $status in
    "missing")
      echo "⚠️  Schema file not found. Run 'npm run assure-files' to create placeholders."
      return 1
      ;;
    "placeholder")
      echo "ℹ️  Using placeholder schema. Run 'npm run rover:introspect' to fetch real schema."
      return 0
      ;;
    "real")
      echo "✅ Real schema is active."
      return 0
      ;;
  esac
}

# Export functions if sourced
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  export -f get_schema_type
  export -f is_schema_ready
  export -f force_placeholder_generation
  export -f check_schema_status
fi