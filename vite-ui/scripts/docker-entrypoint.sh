#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Starting Vite Development Server...${NC}"

# ========================================
# Working directory check
# ========================================
echo -e "${BLUE}📂 Working directory: $(pwd)${NC}"

# ========================================
# Environment check
# ========================================
echo -e "${YELLOW}🌍 Environment check:${NC}"
echo "  NODE_ENV: ${NODE_ENV}"
echo "  VITE_GRAPHQL_ENDPOINT: ${VITE_GRAPHQL_ENDPOINT}"
echo "  VITE_GRAPHQL_WS_URL: ${VITE_GRAPHQL_WS_URL}"

# ========================================
# Checking directories
# ========================================
echo -e "${YELLOW}📂 Checking directories...${NC}"
mkdir -p apollo/generated apollo/fragments grpc-generated wwwroot/grpc

# ========================================
# Ensure placeholder files exist FIRST
# ========================================
echo -e "${BLUE}📝 Creating Placeholder Files (Fallback)${NC}"
npm run assure-files || echo "⚠️  Placeholder creation had warnings (non-critical)"

# ========================================
# Wait for backend - ✅ ปรับปรุงการตรวจสอบ
# ========================================
if [ "${WAIT_FOR_BACKEND}" = "true" ]; then
    echo -e "${YELLOW}⏳ Waiting for backend...${NC}"
    
    BACKEND_URL="http://aspdotnetweb:5000/health"
    MAX_ATTEMPTS=${BACKEND_WAIT_TIMEOUT:-120}
    ATTEMPT=1
    WAIT_TIME=2
    
    while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
        echo -ne "\r  Attempt $ATTEMPT/$MAX_ATTEMPTS..."
        
        # ✅ ตรวจสอบทั้ง health และ HTTP 200
        if curl -sf "$BACKEND_URL" >/dev/null 2>&1; then
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL")
            if [ "$HTTP_CODE" = "200" ]; then
                echo -e "\n${GREEN}✅ Backend is ready! (HTTP $HTTP_CODE)${NC}"
                # ✅ รอเพิ่มอีก 10 วินาทีให้ GraphQL พร้อมจริงๆ
                echo -e "${YELLOW}⏳ Waiting 10s for GraphQL to stabilize...${NC}"
                sleep 10
                break
            fi
        fi
        
        if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
            echo -e "\n${RED}❌ Backend not ready after $MAX_ATTEMPTS attempts${NC}"
            echo -e "${YELLOW}⚠️  Continuing with placeholder files...${NC}"
            break
        fi
        
        sleep $WAIT_TIME
        ATTEMPT=$((ATTEMPT + 1))
        
        # ✅ Progressive backoff
        if [ $((ATTEMPT % 10)) -eq 0 ]; then
            WAIT_TIME=$((WAIT_TIME + 1))
            [ $WAIT_TIME -gt 5 ] && WAIT_TIME=5
        fi
    done
else
    echo -e "${BLUE}ℹ️  Skipping backend wait check${NC}"
fi

# ========================================
# Attempt GraphQL generation - ✅ ปรับปรุงการตรวจสอบ
# ========================================
echo -e "${YELLOW}🔮 Attempting to generate GraphQL...${NC}"
GRAPHQL_URL="http://aspdotnetweb:5000/graphql"

# ✅ Test GraphQL endpoint มากกว่า 1 ครั้ง
GRAPHQL_READY=false
for i in {1..3}; do
    echo -e "${BLUE}🔍 Testing GraphQL endpoint (attempt $i/3)...${NC}"
    
    if curl -sf -X POST "$GRAPHQL_URL" \
        -H "Content-Type: application/json" \
        -H "X-Allow-Introspection: true" \
        --max-time 10 \
        -d '{"query":"query{__schema{queryType{name}}}"}' >/dev/null 2>&1; then
        
        GRAPHQL_READY=true
        echo -e "${GREEN}✅ GraphQL endpoint accessible${NC}"
        break
    fi
    
    echo -e "${YELLOW}⏳ GraphQL not ready, waiting 5s...${NC}"
    sleep 5
done

if [ "$GRAPHQL_READY" = true ]; then
    echo -e "${BLUE}📥 Attempting schema download...${NC}"
    
    # ✅ Run schema download with strict timeout
    SCHEMA_SUCCESS=false
    (
        timeout 90s bash ./scripts/download-schema.sh 2>&1 | tee /tmp/schema-download.log
    ) &
    SCHEMA_PID=$!
    
    # Wait with progress indicator
    WAITED=0
    while [ $WAITED -lt 90 ]; do
        if ! kill -0 $SCHEMA_PID 2>/dev/null; then
            wait $SCHEMA_PID
            SCHEMA_EXIT=$?
            if [ $SCHEMA_EXIT -eq 0 ]; then
                SCHEMA_SUCCESS=true
            fi
            break
        fi
        
        printf "\r  Schema download progress: ${WAITED}s/90s"
        sleep 2
        WAITED=$((WAITED + 2))
    done
    echo ""
    
    # Timeout handling
    if kill -0 $SCHEMA_PID 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Schema download timeout (90s)${NC}"
        kill -TERM $SCHEMA_PID 2>/dev/null || true
        sleep 2
        kill -KILL $SCHEMA_PID 2>/dev/null || true
    fi
    
    # ✅ Validate schema file
    if [ "$SCHEMA_SUCCESS" = true ] && \
       [ -f "apollo/schema.graphql" ] && \
       [ -s "apollo/schema.graphql" ]; then
        
        # ✅ เพิ่มการตรวจสอบเนื้อหา
        if grep -q "type Query" "apollo/schema.graphql" 2>/dev/null || \
           grep -q '"__schema"' "apollo/schema.graphql" 2>/dev/null; then
            
            LINES=$(wc -l < "apollo/schema.graphql")
            echo -e "${GREEN}✅ Schema downloaded successfully ($LINES lines)${NC}"
            
            # Try codegen with timeout
            echo -e "${BLUE}🔧 Running codegen...${NC}"
            
            CODEGEN_SUCCESS=false
            (
                timeout 120s npm run codegen 2>&1 | tee /tmp/codegen.log
            ) &
            CODEGEN_PID=$!
            
            WAITED=0
            while [ $WAITED -lt 120 ]; do
                if ! kill -0 $CODEGEN_PID 2>/dev/null; then
                    wait $CODEGEN_PID
                    CODEGEN_EXIT=$?
                    if [ $CODEGEN_EXIT -eq 0 ]; then
                        CODEGEN_SUCCESS=true
                    fi
                    break
                fi
                
                printf "\r  Codegen progress: ${WAITED}s/120s"
                sleep 2
                WAITED=$((WAITED + 2))
            done
            echo ""
            
            if kill -0 $CODEGEN_PID 2>/dev/null; then
                echo -e "${YELLOW}⚠️  Codegen timeout (120s)${NC}"
                kill -TERM $CODEGEN_PID 2>/dev/null || true
                sleep 2
                kill -KILL $CODEGEN_PID 2>/dev/null || true
            fi
            
            # ✅ ตรวจสอบ generated files
            if [ "$CODEGEN_SUCCESS" = true ]; then
                REQUIRED_FILES=(
                    "apollo/generated/graphql.ts"
                    "apollo/generated/index.ts"
                    "apollo/generated/gql.ts"
                )
                
                ALL_EXISTS=true
                for file in "${REQUIRED_FILES[@]}"; do
                    if [ ! -f "$file" ] || [ ! -s "$file" ]; then
                        ALL_EXISTS=false
                        break
                    fi
                done
                
                if [ "$ALL_EXISTS" = true ]; then
                    echo -e "${GREEN}✅ Codegen completed successfully${NC}"
                else
                    echo -e "${YELLOW}⚠️  Some generated files missing, using placeholders${NC}"
                    npm run assure-files || true
                fi
            else
                echo -e "${YELLOW}⚠️  Codegen failed, using placeholders${NC}"
                tail -n 30 /tmp/codegen.log 2>/dev/null || true
                npm run assure-files || true
            fi
        else
            echo -e "${YELLOW}⚠️  Schema file invalid, using placeholders${NC}"
            npm run assure-files || true
        fi
    else
        echo -e "${YELLOW}⚠️  Schema download failed, using placeholders${NC}"
        tail -n 20 /tmp/schema-download.log 2>/dev/null || true
        npm run assure-files || true
    fi
else
    echo -e "${YELLOW}⚠️  GraphQL endpoint not accessible${NC}"
    echo -e "${BLUE}📝 Using placeholder files${NC}"
    npm run assure-files || true
fi

# ========================================
# Syncing gRPC files
# ========================================
echo -e "${YELLOW}📋 Syncing gRPC files...${NC}"
if [ -f "./scripts/unify-grpc.sh" ]; then
    ./scripts/unify-grpc.sh || echo -e "${YELLOW}⚠️  gRPC sync warning (non-critical)${NC}"
fi

if [ -d "./grpc-generated" ]; then
    echo -e "${YELLOW}📋 Copying gRPC files...${NC}"
    cp -r ./grpc-generated/* ./wwwroot/grpc/ 2>/dev/null || true
    echo -e "${GREEN}✅ gRPC files synced!${NC}"
fi

# ========================================
# Start development servers
# ========================================
echo -e "${GREEN}🎉 Starting development servers...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Start SSR server in background
echo -e "${YELLOW}🔥 Starting SSR server on port 13714...${NC}"
npm run dev:ssr &
SSR_PID=$!

# Give SSR server time to start
sleep 5

# Check if SSR started successfully
if kill -0 $SSR_PID 2>/dev/null; then
    echo -e "${GREEN}✅ SSR server started (PID: $SSR_PID)${NC}"
else
    echo -e "${RED}⚠️  SSR server may have failed to start${NC}"
fi

# Start Vite dev server
echo -e "${YELLOW}⚡ Starting Vite dev server on port 5173...${NC}"
exec npm run dev

# ========================================
# Cleanup on exit
# ========================================
trap "kill $SSR_PID 2>/dev/null || true" EXIT