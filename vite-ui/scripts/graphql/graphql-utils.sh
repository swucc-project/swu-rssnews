#!/bin/bash
get_schema_type() {
  local schema_file="./apollo/schema.graphql"
  if [ ! -f "$schema_file" ]; then
      echo "missing"
      return
  fi
  head -n 10 "$schema_file" | grep -q "_placeholder" && echo "placeholder" || echo "real"
}

is_schema_ready() {
  [ "$(get_schema_type)" = "real" ]
}