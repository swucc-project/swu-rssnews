#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ✅ ใช้ aspdotnetweb
GRAPHQL_URL="${VITE_GRAPHQL_ENDPOINT:-http://aspdotnetweb:5000/graphql}"
MAX_ATTEMPTS=30
ATTEMPT=0

echo -e "${YELLOW}🔍 Waiting for GraphQL endpoint at $GRAPHQL_URL...${NC}"

# ฟังก์ชันทดสอบ GraphQL
test_graphql() {
    curl -sf -X POST "$GRAPHQL_URL" \
        -H "Content-Type: application/json" \
        -H "X-Allow-Introspection: true" \
        -d '{"query":"{ __schema { queryType { name } } }"}' >/dev/null 2>&1
}

# รอจนกว่า GraphQL จะพร้อม
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if test_graphql; then
        echo -e "${GREEN}✅ GraphQL endpoint is ready!${NC}"
        exit 0
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
    echo -e "${YELLOW}⏳ Attempt $ATTEMPT/$MAX_ATTEMPTS - waiting (5s)...${NC}"
    sleep 5
done

echo -e "${RED}❌ GraphQL endpoint not available after $((MAX_ATTEMPTS * 5)) seconds${NC}"
echo -e "${YELLOW}💡 Troubleshooting:${NC}"
echo -e "  1. Check backend: docker compose ps aspdotnetweb"
echo -e "  2. Check logs: docker compose logs aspdotnetweb"
echo -e "  3. Test manually: curl -X POST $GRAPHQL_URL -H 'Content-Type: application/json' -d '{\"query\":\"{__typename}\"}'"
exit 1