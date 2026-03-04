#!/bin/bash
set -e

echo "🚀 Starting Development Environment"
echo "📅 $(date)"
echo "📁 Working directory: $(pwd)"

# ============================================
# Configuration
# ============================================

BACKEND_URL="${VITE_API_URL:-http://aspdotnetweb:5000}"
GRAPHQL_URL="${VITE_GRAPHQL_ENDPOINT:-http://aspdotnetweb:5000/graphql}"
BACKEND_TIMEOUT="${BACKEND_WAIT_TIMEOUT:-120}"
GRAPHQL_TIMEOUT="${GRAPHQL_WAIT_TIMEOUT:-60}"

VITE_PID=""

# ============================================
# Cleanup Handler
# ============================================

cleanup() {
    echo ""
    echo "🛑 Shutting down..."
    
    [ -n "$VITE_PID" ] && kill $VITE_PID 2>/dev/null || true
    
    # Kill any remaining node processes
    pkill -f "vite" 2>/dev/null || true
    
    echo "✅ Cleanup complete"
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT EXIT

# ============================================
# Helper Functions
# ============================================

ensure_placeholder_files() {
    echo "📁 Ensuring placeholder files..."
    
    node scripts/assure-grpc-files.mjs 2>/dev/null || {
        echo "⚠️ Creating minimal gRPC placeholders..."
        mkdir -p grpc grpc-generated
        
        [ ! -f "grpc/rss.ts" ] && cat > grpc/rss.ts << 'EOF'
export interface RSSItem { itemId: number; title: string; }
export interface GetRSSItemsRequest {}
export interface GetRSSItemsResponse { items: RSSItem[]; }
EOF
        
        [ ! -f "grpc/rss.client.ts" ] && cat > grpc/rss.client.ts << 'EOF'
export class RSSItemServiceClient {
    constructor(transport: any) {}
    async getRSSItems() { return { response: { items: [] } }; }
}
EOF
    }
    
    node scripts/assure-graphql-files.mjs 2>/dev/null || echo "⚠️ GraphQL placeholders skipped"
}

wait_for_backend() {
    echo "⏳ Waiting for backend at ${BACKEND_URL}..."
    
    local elapsed=0
    while [ $elapsed -lt $BACKEND_TIMEOUT ]; do
        if curl -sf "${BACKEND_URL}/health" >/dev/null 2>&1; then
            echo "✅ Backend is ready!"
            return 0
        fi
        
        echo "   Waiting... (${elapsed}s/${BACKEND_TIMEOUT}s)"
        sleep 3
        elapsed=$((elapsed + 3))
    done
    
    echo "⚠️ Backend timeout after ${BACKEND_TIMEOUT}s, continuing anyway..."
    return 0
}

wait_for_graphql() {
    echo "⏳ Checking GraphQL endpoint at ${GRAPHQL_URL}..."
    
    local elapsed=0
    while [ $elapsed -lt $GRAPHQL_TIMEOUT ]; do
        local response=$(curl -sf -X POST "${GRAPHQL_URL}" \
            -H "Content-Type: application/json" \
            -d '{"query":"{ __typename }"}' 2>/dev/null || echo "")
        
        if echo "$response" | grep -q "__typename"; then
            echo "✅ GraphQL endpoint is ready!"
            return 0
        fi
        
        echo "   Waiting for GraphQL... (${elapsed}s/${GRAPHQL_TIMEOUT}s)"
        sleep 3
        elapsed=$((elapsed + 3))
    done
    
    echo "⚠️ GraphQL timeout, will use placeholder files"
    return 1
}

generate_clients() {
    echo "📦 Generating clients..."
    
    # GraphQL
    if npm run graphql:generate 2>/dev/null; then
        echo "✅ GraphQL client generated"
    else
        echo "⚠️ GraphQL generation skipped (using placeholders)"
    fi
    
    # gRPC
    if [ -f "./protobuf/rss.proto" ]; then
        npm run generate-grpc:safe 2>/dev/null || echo "⚠️ gRPC generation skipped"
        npm run sync-grpc 2>/dev/null || true
    fi
}

start_vite_server() {
    echo "🔥 Starting Vite dev server on port 5173..."
    
    npm run dev:docker &
    VITE_PID=$!
    echo "   Vite PID: $VITE_PID"
    
    # Wait for Vite (shorter initial wait)
    for i in $(seq 1 30); do
        if curl -sf http://localhost:5173 >/dev/null 2>&1; then
            echo "✅ Vite server is ready"
            return 0
        fi
        
        if ! kill -0 $VITE_PID 2>/dev/null; then
            echo "⚠️ Vite process stopped, restarting..."
            npm run dev:docker &
            VITE_PID=$!
            sleep 3
        fi
        
        echo "   Waiting for Vite... (${i}/30)"
        sleep 2
    done
    
    echo "⚠️ Vite may not be fully ready"
}

monitor_servers() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "🎉 Development servers starting!"
    echo "═══════════════════════════════════════════════════════════"
    echo "   Vite Dev:    http://localhost:5173"
    echo "   Backend:     ${BACKEND_URL}"
    echo "   GraphQL:     ${GRAPHQL_URL}"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "📡 Monitoring servers..."
    
    while true; do
        # Check Vite
        if [ -n "$VITE_PID" ] && ! kill -0 $VITE_PID 2>/dev/null; then
            echo "⚠️ Vite died, restarting..."
            npm run dev:docker &
            VITE_PID=$!
        fi
        
        sleep 15
    done
}

# ============================================
# Main Execution
# ============================================

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "              Development Environment Setup                 "
echo "═══════════════════════════════════════════════════════════"
echo ""

# Step 1: Ensure placeholder files exist
ensure_placeholder_files

# Step 2: Verify critical files
echo "🔍 Verifying files..."
for file in "grpc/rss.client.ts" "grpc/rss.ts" "apollo/generated/graphql.ts"; do
    [ -f "$file" ] && echo "   ✅ $file" || echo "   ⚠️ $file missing"
done

# Step 3: Create required directories
mkdir -p wwwroot/volume grpc-generated

# Step 4: Wait for backend (non-blocking)
wait_for_backend

# Step 5: Try GraphQL (non-blocking)
wait_for_graphql && generate_clients

# Step 6: Start servers
start_vite_server

# Step 7: Monitor and keep alive
monitor_servers