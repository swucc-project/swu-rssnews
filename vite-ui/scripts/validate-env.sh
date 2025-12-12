#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Environment Variables Validation                  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

ERRORS=0
WARNINGS=0

# ✅ ฟังก์ชันตรวจสอบ
check_var() {
    local var_name=$1
    local var_value="${!var_name}"
    local is_required=${2:-true}
    
    if [ -z "$var_value" ]; then
        if [ "$is_required" = true ]; then
            echo -e "  ${RED}❌ $var_name (missing, required)${NC}"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "  ${YELLOW}⚠️  $var_name (missing, optional)${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo -e "  ${GREEN}✅ $var_name${NC}"
    fi
}

# ✅ Load .env file
if [ -f ".env" ]; then
    echo -e "${BLUE}📄 Loading .env file...${NC}"
    export $(grep -v '^#' .env | xargs)
    echo ""
else
    echo -e "${RED}❌ .env file not found!${NC}"
    exit 1
fi

# ✅ Check required variables
echo -e "${YELLOW}🔍 Required Variables:${NC}"
check_var "VITE_API_URL"
check_var "VITE_GRAPHQL_ENDPOINT"
check_var "VITE_GRAPHQL_WS_URL"
check_var "VITE_GRPC_ENDPOINT"
check_var "VITE_PUBLIC_API_URL"
check_var "VITE_PUBLIC_GRAPHQL_ENDPOINT"
check_var "VITE_PUBLIC_GRAPHQL_WS_URL"
check_var "VITE_PUBLIC_GRPC_ENDPOINT"
check_var "DATABASE_HOST"
check_var "DATABASE_NAME"
echo ""

# ✅ Check optional variables
echo -e "${YELLOW}🔍 Optional Variables:${NC}"
check_var "SSR_RENDER_URL" false
check_var "SSR_PORT" false
check_var "APOLLO_KEY" false
check_var "NODE_ENV" false
echo ""

# ✅ Validate URL formats
echo -e "${YELLOW}🔍 Validating URLs...${NC}"

validate_url() {
    local url=$1
    local name=$2
    
    if [[ "$url" =~ ^https?:// ]]; then
        echo -e "  ${GREEN}✅ $name: $url${NC}"
    else
        echo -e "  ${RED}❌ $name: Invalid format ($url)${NC}"
        ERRORS=$((ERRORS + 1))
    fi
}

validate_url "$VITE_API_URL" "VITE_API_URL"
validate_url "$VITE_GRAPHQL_ENDPOINT" "VITE_GRAPHQL_ENDPOINT"
validate_url "$VITE_PUBLIC_API_URL" "VITE_PUBLIC_API_URL"
validate_url "$VITE_PUBLIC_GRAPHQL_ENDPOINT" "VITE_PUBLIC_GRAPHQL_ENDPOINT"
echo ""

# ✅ Check for common mistakes
echo -e "${YELLOW}🔍 Checking for common issues...${NC}"

# Check if internal URLs use localhost (should use service names)
if [[ "$VITE_GRAPHQL_ENDPOINT" == *"localhost"* ]]; then
    echo -e "  ${YELLOW}⚠️  VITE_GRAPHQL_ENDPOINT uses 'localhost' (should use 'aspdotnetweb' in Docker)${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "  ${GREEN}✅ Internal GraphQL URL correct${NC}"
fi

# Check if public URLs use service names (should use localhost/domain)
if [[ "$VITE_PUBLIC_GRAPHQL_ENDPOINT" == *"aspdotnetweb"* ]]; then
    echo -e "  ${RED}❌ VITE_PUBLIC_GRAPHQL_ENDPOINT uses 'aspdotnetweb' (should use 'localhost' or public domain)${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "  ${GREEN}✅ Public GraphQL URL correct${NC}"
fi

# Check WebSocket protocol
if [[ "$VITE_GRAPHQL_WS_URL" == ws://* ]] || [[ "$VITE_GRAPHQL_WS_URL" == wss://* ]]; then
    echo -e "  ${GREEN}✅ WebSocket URL has correct protocol${NC}"
else
    echo -e "  ${RED}❌ WebSocket URL missing ws:// or wss:// protocol${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# ✅ Summary
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Validation Summary                                ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found${NC}"
    exit 0
else
    echo -e "${RED}❌ $ERRORS error(s) and $WARNINGS warning(s) found${NC}"
    echo ""
    echo -e "${YELLOW}💡 Fix the errors above before proceeding${NC}"
    exit 1
fi