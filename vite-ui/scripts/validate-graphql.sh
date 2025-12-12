#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          GraphQL Setup Validation                         ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

ERRORS=0
WARNINGS=0

# ========================================
# 1. Check Backend Connection
# ========================================
echo -e "${YELLOW}1️⃣  Checking Backend Connection...${NC}"

BACKEND_URL="http://aspdotnetweb:5000/health"
if curl -sf "$BACKEND_URL" >/dev/null 2>&1; then
    echo -e "   ${GREEN}✅ Backend health check passed${NC}"
else
    echo -e "   ${RED}❌ Backend health check failed${NC}"
    ERRORS=$((ERRORS + 1))
fi

# ========================================
# 2. Check GraphQL Endpoint
# ========================================
echo -e "${YELLOW}2️⃣  Checking GraphQL Endpoint...${NC}"

GRAPHQL_URL="http://aspdotnetweb:5000/graphql"
RESPONSE=$(curl -sf -X POST "$GRAPHQL_URL" \
    -H "Content-Type: application/json" \
    -H "X-Allow-Introspection: true" \
    -d '{"query":"{ __typename }"}' 2>/dev/null)

if [ -n "$RESPONSE" ]; then
    echo -e "   ${GREEN}✅ GraphQL endpoint responding${NC}"
    echo "   Response: $RESPONSE"
else
    echo -e "   ${RED}❌ GraphQL endpoint not responding${NC}"
    ERRORS=$((ERRORS + 1))
fi

# ========================================
# 3. Check Schema File
# ========================================
echo -e "${YELLOW}3️⃣  Checking Schema File...${NC}"

if [ -f "apollo/schema.graphql" ]; then
    if grep -q "_placeholder" apollo/schema.graphql; then
        echo -e "   ${YELLOW}⚠️  Placeholder schema detected${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        LINES=$(wc -l < apollo/schema.graphql)
        BYTES=$(wc -c < apollo/schema.graphql)
        echo -e "   ${GREEN}✅ Real schema found ($LINES lines, $BYTES bytes)${NC}"
    fi
else
    echo -e "   ${RED}❌ Schema file not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

# ========================================
# 4. Check Generated Files
# ========================================
echo -e "${YELLOW}4️⃣  Checking Generated Files...${NC}"

REQUIRED_FILES=(
    "apollo/generated/graphql.ts"
    "apollo/generated/index.ts"
    "apollo/generated/gql.ts"
    "apollo/generated/fragment-masking.ts"
    "apollo/generated/fragments.ts"
    "apollo/generated/introspection.json"
)

MISSING_FILES=0

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(wc -c < "$file")
        if [ $SIZE -gt 500 ]; then
            echo -e "   ${GREEN}✅ $file ($SIZE bytes)${NC}"
        else
            echo -e "   ${YELLOW}⚠️  $file ($SIZE bytes - may be placeholder)${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo -e "   ${RED}❌ $file (missing)${NC}"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    ERRORS=$((ERRORS + MISSING_FILES))
fi

# ========================================
# 5. Check NPM Dependencies
# ========================================
echo -e "${YELLOW}5️⃣  Checking NPM Dependencies...${NC}"

REQUIRED_DEPS=(
    "@apollo/client"
    "@graphql-codegen/cli"
    "graphql"
)

for dep in "${REQUIRED_DEPS[@]}"; do
    if npm list "$dep" >/dev/null 2>&1; then
        VERSION=$(npm list "$dep" --depth=0 2>/dev/null | grep "$dep@" | sed 's/.*@//')
        echo -e "   ${GREEN}✅ $dep@$VERSION${NC}"
    else
        echo -e "   ${RED}❌ $dep (not installed)${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# ========================================
# Summary
# ========================================
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Validation Summary                                ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! GraphQL setup is complete.${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found. Setup is functional but could be improved.${NC}"
    exit 0
else
    echo -e "${RED}❌ $ERRORS error(s) and $WARNINGS warning(s) found.${NC}"
    echo ""
    echo -e "${YELLOW}Suggested fixes:${NC}"
    echo "  1. Run: make graphql-fix"
    echo "  2. Check backend logs: docker logs aspnetcore"
    echo "  3. Test GraphQL: make graphql-test"
    exit 1
fi