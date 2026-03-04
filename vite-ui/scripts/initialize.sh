#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Vite Frontend Startup Script with Fallback Handling
# ═══════════════════════════════════════════════════════════
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
BACKEND_URL="${VITE_API_URL:-http://aspdotnetweb:5000}"
GRAPHQL_URL="${VITE_GRAPHQL_ENDPOINT:-http://aspdotnetweb:5000/graphql}"
BACKEND_MAX_WAIT="${BACKEND_WAIT_TIMEOUT:-90}"
GRAPHQL_MAX_WAIT="${GRAPHQL_WAIT_TIMEOUT:-45}"
POLL_INTERVAL="${GRAPHQL_POLL_INTERVAL:-3}"

USE_PLACEHOLDER="${USE_PLACEHOLDER_ON_FAIL:-true}"
CONTINUE_ON_FAIL="${CONTINUE_ON_GRAPHQL_FAIL:-true}"
SKIP_CODEGEN="${SKIP_GRAPHQL_CODEGEN:-false}"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}          Vite Frontend Container Starting                 ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Configuration:"
echo "  NODE_ENV: ${NODE_ENV:-development}"
echo "  BACKEND_URL: ${BACKEND_URL}"
echo "  GRAPHQL_URL: ${GRAPHQL_URL}"
echo "  WAIT_FOR_BACKEND: ${WAIT_FOR_BACKEND:-true}"
echo "  BACKEND_WAIT_TIMEOUT: ${BACKEND_MAX_WAIT}s"
echo "  GRAPHQL_WAIT_TIMEOUT: ${GRAPHQL_MAX_WAIT}s"
echo "  USE_PLACEHOLDER_ON_FAIL: ${USE_PLACEHOLDER}"
echo ""

# ═══════════════════════════════════════════════════════════
# Step 1: Ensuring placeholder files...
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 1: Ensuring placeholder files...${NC}"
npm run graphql:ensure 2>/dev/null || npm run assure-files 2>/dev/null || true
npm run grpc:ensure 2>/dev/null || npm run assure-grpc 2>/dev/null || true
echo -e "${GREEN}✅ Placeholder files ensured${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# Step 2: Checking backend availability...
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 2: Checking backend availability...${NC}"

backend_ready=false
elapsed=0

while [ $elapsed -lt $BACKEND_MAX_WAIT ]; do
    if curl -sf "${BACKEND_URL}/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Backend health endpoint ready (${elapsed}s)${NC}"
        backend_ready=true
        break
    fi
    
    echo -e "${CYAN}ℹ️  Waiting for backend at ${BACKEND_URL}/health (timeout: ${BACKEND_MAX_WAIT}s)...${NC}"
    sleep $POLL_INTERVAL
    elapsed=$((elapsed + POLL_INTERVAL))
done

if [ "$backend_ready" = false ]; then
    echo -e "${RED}❌ Backend not ready after ${BACKEND_MAX_WAIT}s${NC}"
    
    if [ "$CONTINUE_ON_FAIL" = "true" ]; then
        echo -e "${YELLOW}⚠️  Continuing anyway (CONTINUE_ON_GRAPHQL_FAIL=true)${NC}"
    else
        exit 1
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════
# Step 3: Checking GraphQL availability...
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 3: Checking GraphQL availability...${NC}"

graphql_ready=false
elapsed=0

# ✅ Only check GraphQL if backend is ready
if [ "$backend_ready" = true ]; then
    while [ $elapsed -lt $GRAPHQL_MAX_WAIT ]; do
        # Test with a simple introspection query
        response=$(curl -sf "${GRAPHQL_URL}" \
            -H "Content-Type: application/json" \
            -d '{"query":"{ __typename }"}' 2>/dev/null || echo "")
        
        if echo "$response" | grep -q '"__typename"'; then
            echo -e "${GREEN}✅ GraphQL is ready and responding (${elapsed}s)${NC}"
            graphql_ready=true
            break
        fi
        
        # Also check the health endpoint
        if curl -sf "${BACKEND_URL}/health/graphql" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ GraphQL health check passed (${elapsed}s)${NC}"
            graphql_ready=true
            break
        fi
        
        echo -e "${CYAN}ℹ️  Backend ready but GraphQL not responding yet...${NC}"
        sleep $POLL_INTERVAL
        elapsed=$((elapsed + POLL_INTERVAL))
    done
fi

# ═══════════════════════════════════════════════════════════
# Step 4: Handle GraphQL setup
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}Step 4: GraphQL setup...${NC}"

if [ "$graphql_ready" = true ]; then
    echo -e "${GREEN}✅ GraphQL is ready${NC}"
    
    if [ "$SKIP_CODEGEN" != "true" ]; then
        echo -e "${CYAN}📝 Running GraphQL code generation...${NC}"
        
        # Try to generate schema and types
        if npm run graphql:setup 2>&1 | tee /tmp/graphql-setup.log; then
            echo -e "${GREEN}✅ GraphQL setup successful${NC}"
        else
            echo -e "${YELLOW}⚠️  GraphQL setup had issues, checking logs...${NC}"
            
            # Check if it's just warnings or actual errors
            if grep -q "Error:" /tmp/graphql-setup.log; then
                echo -e "${RED}❌ GraphQL setup failed with errors${NC}"
                
                if [ "$USE_PLACEHOLDER" = "true" ]; then
                    echo -e "${YELLOW}📝 Using placeholder files as fallback${NC}"
                    npm run graphql:ensure
                fi
            else
                echo -e "${GREEN}✅ Only warnings, continuing...${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⏭️  Skipping GraphQL codegen (SKIP_GRAPHQL_CODEGEN=true)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  GraphQL not ready after ${GRAPHQL_MAX_WAIT}s${NC}"
    
    if [ "$USE_PLACEHOLDER" = "true" ]; then
        echo -e "${YELLOW}📝 Using placeholder GraphQL files...${NC}"
        npm run graphql:ensure
        echo -e "${GREEN}✅ Placeholder files ready${NC}"
    fi
    
    if [ "$CONTINUE_ON_FAIL" != "true" ]; then
        echo -e "${RED}❌ Stopping (CONTINUE_ON_GRAPHQL_FAIL=false)${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}⚠️  Continuing without GraphQL (CONTINUE_ON_GRAPHQL_FAIL=true)${NC}"
    echo -e "${YELLOW}    Frontend will start but GraphQL features may not work${NC}"
fi

# ═══════════════════════════════════════════════════════════
# Step 5: Starting Vite dev server
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}          Vite Frontend Container Starting                 ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Configuration:"
echo "  NODE_ENV: ${NODE_ENV:-development}"
echo "  BACKEND_URL: ${BACKEND_URL}"
echo "  GRAPHQL_URL: ${GRAPHQL_URL}"
echo "  WAIT_FOR_BACKEND: true"
echo "  BACKEND_WAIT_TIMEOUT: ${BACKEND_MAX_WAIT}s"
echo "  GRAPHQL_WAIT_TIMEOUT: ${GRAPHQL_MAX_WAIT}s"
echo "  USE_PLACEHOLDER_ON_FAIL: ${USE_PLACEHOLDER}"
echo ""

echo -e "${GREEN}🚀 Starting Vite dev server...${NC}"
echo -e "${CYAN}   Access at: http://localhost:5173${NC}"
echo -e "${CYAN}   HMR WebSocket: ws://localhost:24678${NC}"
echo ""

# Start Vite
exec npm run dev:docker