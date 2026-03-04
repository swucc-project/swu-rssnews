#!/bin/bash
# ========================================
# rover-publish.sh
# Publish GraphQL schema to Apollo Studio
# ========================================
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

GRAPHQL_URL="${VITE_GRAPHQL_ENDPOINT:-http://aspdotnetweb:5000/graphql}"
SCHEMA_FILE="${SCHEMA_FILE:-./apollo/schema.graphql}"
GRAPH_REF="${APOLLO_GRAPH_REF:-rss-graph@swu}"
APOLLO_KEY="${APOLLO_KEY:-}"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Apollo Rover Schema Publisher                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Rover is installed
if ! command -v rover &> /dev/null; then
    echo -e "${RED}❌ Rover not found!${NC}"
    echo -e "${YELLOW}Please run: npm run rover:setup${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Rover version: $(rover --version)${NC}"
echo ""

# Check for Apollo Key
if [ -z "$APOLLO_KEY" ]; then
    echo -e "${RED}❌ APOLLO_KEY environment variable not set${NC}"
    echo ""
    echo -e "${YELLOW}To publish schemas to Apollo Studio, you need:${NC}"
    echo -e "  1. Create an account at https://studio.apollographql.com"
    echo -e "  2. Create a graph"
    echo -e "  3. Get your API key from Settings > This Graph > API Keys"
    echo -e "  4. Set the APOLLO_KEY environment variable:"
    echo -e "     export APOLLO_KEY='your-key-here'"
    echo ""
    echo -e "${BLUE}Alternative: Introspect and publish in one step:${NC}"
    echo -e "  rover graph introspect $GRAPHQL_URL \\"
    echo -e "    | rover graph publish $GRAPH_REF \\"
    echo -e "    --schema -"
    echo ""
    exit 1
fi

# Step 1: Introspect schema first
echo -e "${YELLOW}Step 1: Introspecting schema...${NC}"
echo -e "   URL: $GRAPHQL_URL"

if ! bash ./scripts/rover-introspect.sh; then
    echo -e "${RED}❌ Schema introspection failed${NC}"
    exit 1
fi

# Step 2: Validate schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
    echo -e "${RED}❌ Schema file not found: $SCHEMA_FILE${NC}"
    exit 1
fi

# Step 3: Validate schema content
if grep -q "_placeholder" "$SCHEMA_FILE"; then
    echo -e "${RED}❌ Schema is a placeholder, cannot publish${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 2: Publishing schema to Apollo Studio...${NC}"
echo -e "   Graph: $GRAPH_REF"
echo -e "   File: $SCHEMA_FILE"

# Publish schema
if rover graph publish "$GRAPH_REF" \
    --schema "$SCHEMA_FILE" 2>&1 | tee /tmp/rover-publish.log; then
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          ✅ Schema Published Successfully!                 ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}View your schema at:${NC}"
    echo -e "https://studio.apollographql.com/graph/${GRAPH_REF%%@*}"
    echo ""
    
    exit 0
else
    echo ""
    echo -e "${RED}❌ Schema publish failed${NC}"
    echo ""
    echo -e "${YELLOW}Common issues:${NC}"
    echo -e "  1. Invalid APOLLO_KEY"
    echo -e "  2. Graph not found in Apollo Studio"
    echo -e "  3. Network connectivity issues"
    echo -e "  4. Schema validation errors"
    echo ""
    echo -e "${BLUE}Check logs:${NC}"
    cat /tmp/rover-publish.log 2>/dev/null || true
    echo ""
    
    exit 1
fi