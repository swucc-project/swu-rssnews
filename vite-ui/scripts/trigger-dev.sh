#!/bin/bash

set -e

echo "🚀 Starting Development Environment"

# Wait for backend
echo "⏳ Waiting for backend..."
until curl -sf http://aspdotnetweb:5000/health > /dev/null 2>&1; do
    echo "   Waiting for backend..."
    sleep 2
done
echo "✅ Backend is ready"

# Generate GraphQL
echo "📦 Generating GraphQL client..."
npm run generate-graphql-client || {
    echo "⚠️ GraphQL generation failed, using fallback"
    npm run generate-graphql-client:fallback
}

# Start SSR in background
echo "🚀 Starting SSR server..."
NODE_ENV=development node hub/ssr-server.js &
SSR_PID=$!

# Wait for SSR
sleep 5

# Check if SSR is running
if ! kill -0 $SSR_PID 2>/dev/null; then
    echo "❌ SSR server failed to start"
    exit 1
fi

echo "✅ SSR server started (PID: $SSR_PID)"

# Start Vite
echo "🚀 Starting Vite dev server..."
exec npm run dev