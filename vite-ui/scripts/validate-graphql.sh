#!/bin/bash
# ═══════════════════════════════════════════════════════════
# 🔍 GraphQL Setup Validation Script
# ═══════════════════════════════════════════════════════════
# Version: 1.1.0
#
# Changelog v1.1.0:
#   [BUG FIX #1] curl POST ไปยัง GraphQL endpoint ขาด "Accept: application/json" header
#                บาง server (เช่น HotChocolate) อาจ return 406 Not Acceptable
#                หรือ return content-type ที่ไม่ใช่ JSON ทำให้ RESPONSE เป็น empty string
#                แก้โดยเพิ่ม -H "Accept: application/json" ใน curl command
#   [BUG FIX #2] `npm list "$dep"` ไม่ระบุ working directory
#                ถ้า script ถูกเรียกจาก directory ที่ไม่ใช่ /app
#                npm จะหา node_modules ไม่เจอ → false negative ทุก dependency
#                แก้โดยเพิ่ม --prefix /app เพื่อให้ชี้ไปยัง project root เสมอ
# ═══════════════════════════════════════════════════════════

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}     GraphQL Setup Validation          ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

ERRORS=0
WARNINGS=0

# ─────────────────────────────────────────
# 1. Backend Connection
# ─────────────────────────────────────────
echo -e "${YELLOW}1. Checking Backend Connection...${NC}"
BACKEND_URL="http://aspdotnetweb:5000/health"
if curl -sf "$BACKEND_URL" >/dev/null 2>&1; then
    echo -e "   ${GREEN}✅ Backend health check passed${NC}"
else
    echo -e "   ${RED}❌ Backend health check failed${NC}"
    ERRORS=$((ERRORS + 1))
fi

# ─────────────────────────────────────────
# 2. GraphQL Endpoint
# ─────────────────────────────────────────
echo -e "${YELLOW}2. Checking GraphQL Endpoint...${NC}"
GRAPHQL_URL="http://aspdotnetweb:5000/graphql"

# [BUG FIX #1] เดิมไม่มี -H "Accept: application/json"
# HotChocolate และ GraphQL server อื่นๆ อาจ return 406 หรือ HTML error page
# เมื่อ client ไม่ได้ระบุว่ายอมรับ application/json
# ทำให้ RESPONSE เป็น empty string แม้ server จะทำงานปกติ
RESPONSE=$(curl -sf -X POST "$GRAPHQL_URL" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "X-Allow-Introspection: true" \
    -d '{"query":"{ __typename }"}' 2>/dev/null)

if [ -n "$RESPONSE" ]; then
    echo -e "   ${GREEN}✅ GraphQL endpoint responding${NC}"
    echo "   Response: $RESPONSE"
else
    echo -e "   ${RED}❌ GraphQL endpoint not responding${NC}"
    ERRORS=$((ERRORS + 1))
fi

# ─────────────────────────────────────────
# 3. Schema File
# ─────────────────────────────────────────
echo -e "${YELLOW}3. Checking Schema File...${NC}"
if [ -f "apollo/schema.graphql" ]; then
    if grep -q "AUTO-GENERATED PLACEHOLDER" apollo/schema.graphql; then
        echo -e "   ${YELLOW}⚠️  Placeholder schema detected — skipping strict validation${NC}"
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

# ─────────────────────────────────────────
# 4. Generated Files
# ─────────────────────────────────────────
echo -e "${YELLOW}4. Checking Generated Files...${NC}"
REQUIRED_FILES="apollo/generated/graphql.ts apollo/generated/index.ts apollo/generated/gql.ts apollo/generated/fragment-masking.ts apollo/generated/fragments.ts apollo/generated/introspection.json"

MISSING_FILES=0
for file in $REQUIRED_FILES; do
    if [ -f "$file" ]; then
        SIZE=$(wc -c < "$file")
        if [ "$SIZE" -gt 500 ]; then
            echo -e "   ${GREEN}✅ $file ($SIZE bytes)${NC}"
        else
            echo -e "   ${YELLOW}⚠️  $file ($SIZE bytes — may be placeholder)${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo -e "   ${RED}❌ $file (missing)${NC}"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ "$MISSING_FILES" -gt 0 ]; then
    ERRORS=$((ERRORS + MISSING_FILES))
fi

# ─────────────────────────────────────────
# 5. NPM Dependencies
# ─────────────────────────────────────────
echo -e "${YELLOW}5. Checking NPM Dependencies...${NC}"
REQUIRED_DEPS="@apollo/client @graphql-codegen/cli graphql"

for dep in $REQUIRED_DEPS; do
    # [BUG FIX #2] เดิม: npm list "$dep" — ไม่ระบุ prefix
    # ถ้า script ถูก invoke จาก directory ที่ไม่ใช่ /app (เช่น /app/scripts หรือ /)
    # npm จะหา node_modules ไม่เจอ แม้ว่า package จะ install อยู่ใน /app/node_modules
    # แก้โดยเพิ่ม --prefix /app เพื่อให้ชี้ไปยัง project root เสมอไม่ว่า cwd จะเป็น path ใด
    if npm list --prefix /app "$dep" >/dev/null 2>&1; then
        VERSION=$(npm list --prefix /app "$dep" --depth=0 2>/dev/null | grep "$dep@" | sed 's/.*@//')
        echo -e "   ${GREEN}✅ $dep@$VERSION${NC}"
    else
        echo -e "   ${RED}❌ $dep (not installed or not found under /app)${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# ─────────────────────────────────────────
# Summary
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}     Validation Summary                ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! GraphQL setup is complete.${NC}"
    exit 0
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found. Setup is functional.${NC}"
    exit 0
else
    echo -e "${RED}❌ $ERRORS error(s) and $WARNINGS warning(s) found.${NC}"
    exit 1
fi