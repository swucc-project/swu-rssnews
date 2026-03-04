#!/usr/bin/env bash
set -euo pipefail

GRAPHQL_URL="${GRAPHQL_URL:-http://backend:5000/graphql}"
OUT="${1:-./apollo/schema.graphql}"
TIMEOUT="${ROVER_TIMEOUT:-30}"

echo "🔍 Rover introspection"
echo "   URL: $GRAPHQL_URL"
echo "   OUT: $OUT"
echo "   TIMEOUT: ${TIMEOUT}s"

tmp_schema="$(mktemp)"
tmp_err="$(mktemp)"

cleanup() {
  rm -f "$tmp_schema" "$tmp_err"
}
trap cleanup EXIT

if ! command -v rover >/dev/null 2>&1; then
  echo "❌ rover not found"
  exit 1
fi

if timeout "$TIMEOUT" rover graph introspect "$GRAPHQL_URL" \
  --header "X-Allow-Introspection: true" \
  >"$tmp_schema" 2>"$tmp_err"; then

  if [[ -s "$tmp_schema" ]] && grep -q "type Query" "$tmp_schema"; then
    mkdir -p "$(dirname "$OUT")"
    mv "$tmp_schema" "$OUT"
    echo "✅ Schema saved ($(wc -c < "$OUT") bytes)"
    exit 0
  else
    echo "❌ Invalid schema output"
    head -20 "$tmp_err" || true
    exit 1
  fi
else
  echo "❌ Rover introspection failed"
  head -20 "$tmp_err" || true
  exit 1
fi