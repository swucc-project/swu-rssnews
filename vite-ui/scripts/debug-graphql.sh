#!/bin/bash
# ========================================
# debug-graphql.sh
# Debug GraphQL endpoint issues
# ========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

GRAPHQL_URL="${GRAPHQL_ENDPOINT:-${VITE_GRAPHQL_ENDPOINT:-http://aspdotnetweb:5000/graphql}}"
BACKEND_URL="${VITE_API_URL:-http://aspdotnetweb:5000}"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          GraphQL Endpoint Debugger                        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "GraphQL URL: $GRAPHQL_URL"
echo -e "Backend URL: $BACKEND_URL"
echo ""

# =====================================================
# Test 1: Backend Health
# =====================================================
echo -e "${CYAN}Test 1: Backend Health Check${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if curl -sf "$BACKEND_URL/health" 2>&1 | head -20; then
    echo -e "\n${GREEN}✅ Backend health endpoint responding${NC}\n"
else
    echo -e "\n${RED}❌ Backend health endpoint not responding${NC}\n"
fi

# =====================================================
# Test 2: GraphQL Endpoint Connectivity
# =====================================================
echo -e "${CYAN}Test 2: GraphQL Endpoint Connectivity${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if curl -v "$GRAPHQL_URL" 2>&1 | head -30; then
    echo -e "\n${GREEN}✅ Can connect to GraphQL URL${NC}\n"
else
    echo -e "\n${RED}❌ Cannot connect to GraphQL URL${NC}\n"
fi

# =====================================================
# Test 3: Simple GraphQL Query
# =====================================================
echo -e "${CYAN}Test 3: Simple GraphQL Query (__typename)${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

response=$(curl -sf -X POST "$GRAPHQL_URL" \
    -H "Content-Type: application/json" \
    -H "X-Allow-Introspection: true" \
    -d '{"query":"{ __typename }"}' 2>&1)

if [ -n "$response" ]; then
    echo "Response:"
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
    
    if echo "$response" | grep -q '"data"'; then
        echo -e "\n${GREEN}✅ GraphQL responding correctly${NC}\n"
    elif echo "$response" | grep -q '"errors"'; then
        echo -e "\n${RED}❌ GraphQL returned errors${NC}\n"
    else
        echo -e "\n${YELLOW}⚠️ Unexpected response format${NC}\n"
    fi
else
    echo -e "${RED}❌ No response from GraphQL endpoint${NC}\n"
fi

# =====================================================
# Test 4: Introspection Query
# =====================================================
echo -e "${CYAN}Test 4: Introspection Query (__schema)${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

response=$(curl -sf -X POST "$GRAPHQL_URL" \
    -H "Content-Type: application/json" \
    -H "X-Allow-Introspection: true" \
    -d '{"query":"{ __schema { queryType { name } } }"}' 2>&1)

if [ -n "$response" ]; then
    echo "Response:"
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
    
    if echo "$response" | grep -q '"__schema"'; then
        echo -e "\n${GREEN}✅ Introspection is enabled${NC}\n"
    elif echo "$response" | grep -qi "introspection.*disabled"; then
        echo -e "\n${RED}❌ Introspection is DISABLED on server${NC}"
        echo -e "${YELLOW}Solution: Enable introspection in backend GraphQL config${NC}\n"
    else
        echo -e "\n${YELLOW}⚠️ Introspection query failed${NC}\n"
    fi
else
    echo -e "${RED}❌ No response from introspection query${NC}\n"
fi

# =====================================================
# Test 5: Full Introspection
# =====================================================
echo -e "${CYAN}Test 5: Full Introspection Query${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

introspection_query='{"query":"query IntrospectionQuery{__schema{types{name kind}}}"}'

response=$(curl -sf -X POST "$GRAPHQL_URL" \
    -H "Content-Type: application/json" \
    -H "X-Allow-Introspection: true" \
    --max-time 30 \
    -d "$introspection_query" 2>&1)

if [ -n "$response" ]; then
    echo "Response (first 500 chars):"
    echo "$response" | head -c 500
    echo "..."
    
    if echo "$response" | grep -q '"types"'; then
        type_count=$(echo "$response" | grep -o '"name"' | wc -l)
        echo -e "\n${GREEN}✅ Full introspection works (found ~$type_count types)${NC}\n"
    else
        echo -e "\n${RED}❌ Full introspection failed${NC}\n"
    fi
else
    echo -e "${RED}❌ No response from full introspection${NC}\n"
fi

# =====================================================
# Test 6: Check Backend Logs
# =====================================================
echo -e "${CYAN}Test 6: Recent Backend Logs${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v docker >/dev/null 2>&1; then
    echo "Last 30 lines from backend container:"
    docker logs aspdotnetweb-latest 2>&1 | tail -30 | sed 's/^/  /'
    echo ""
else
    echo -e "${YELLOW}⚠️ Docker not available, cannot check logs${NC}\n"
fi

# =====================================================
# Summary
# =====================================================
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Debug Summary                                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}If introspection is disabled, check your backend config:${NC}"
echo -e "  builder.Services.AddGraphQLServer()"
echo -e "      .AllowIntrospection(true);"
echo ""
echo -e "${YELLOW}If you see SchemaException errors, check:${NC}"
echo -e "  1. Type registration order"
echo -e "  2. Circular dependencies in types"
echo -e "  3. Missing type definitions"
echo -e "  4. Backend startup logs for detailed errors"
echo ""