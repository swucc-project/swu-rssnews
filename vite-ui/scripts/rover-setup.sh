#!/bin/bash
set -e

# ปรับ auth เฉพาะตอนรันนอก container และมี $APOLLO_KEY
if [ ! -z "$APOLLO_KEY" ]; then
  if [ -t 1 ]; then
    echo "🔑 Configuring Rover with Apollo Studio..."
    rover config auth
  else
    echo "⚠️ Skipping interactive rover config (no TTY)"
  fi
fi

# Apollo Rover Setup Script
echo "🚀 Setting up Apollo Rover..."

# Check if rover is installed
if ! command -v rover &> /dev/null; then
    echo "📦 Installing Rover globally..."
    npm install -g @apollo/rover
fi

# Create schema directory
mkdir -p apollo

# Download schema
echo "📥 Downloading GraphQL schema..."
npm run rover:introspect

echo "✅ Rover setup complete!"
echo ""
echo "Available commands:"
echo "  npm run rover:introspect  - Download schema from server"
echo "  npm run rover:check       - Check schema changes"
echo "  npm run rover:publish     - Publish schema to Apollo Studio"
echo "  npm run rover:dev         - Download schema and generate types"