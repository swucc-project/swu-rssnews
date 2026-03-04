#!/bin/bash
# ========================================
# rover-introspect-publish.sh
# Introspect schema and optionally publish to Apollo Studio
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
MAX_RETRIES="${MAX_RETRIES:-10}"
RETRY_DELAY="${RETRY_DELAY:-5}"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Apollo Rover: Introspect & Publish                     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Rover is installed
if ! command -v rover &> /dev/null; then
    echo -e "${YELLOW}📦 Installing Rover...${NC}"
    curl -sSL https://rover.apollo.dev/nix/v0.36.2 | sh
    export PATH="$HOME/.rover/bin:$PATH"
    
    if ! command -v rover &> /dev/null; then
        echo -e "${RED}❌ Failed to install Rover${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Rover version: $(rover --version)${NC}"
echo ""

# Wait for GraphQL endpoint
echo -e "${YELLOW}⏳ Waiting for GraphQL endpoint...${NC}"
echo -e "   URL: $GRAPHQL_URL"

retry=0
while [ $retry -lt $MAX_RETRIES ]; do
    if curl -sf -X POST "$GRAPHQL_URL" \
        -H "Content-Type: application/json" \
        -H "X-Allow-Introspection: true" \
        -d '{"query":"{ __typename }"}' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Endpoint is ready!${NC}"
        break
    fi
    
    retry=$((retry + 1))
    if [ $retry -lt $MAX_RETRIES ]; then
        echo -e "   Attempt $retry/$MAX_RETRIES - retrying in ${RETRY_DELAY}s..."
        sleep $RETRY_DELAY
    fi
done

if [ $retry -eq $MAX_RETRIES ]; then
    echo -e "${RED}❌ GraphQL endpoint not available${NC}"
    exit 1
fi

# Create schema directory
mkdir -p "$(dirname "$SCHEMA_FILE")"

echo ""
echo -e "${YELLOW}🔍 Introspecting schema...${NC}"

# Check if Apollo Key is set for publishing
if [ -n "$APOLLO_KEY" ]; then
    echo -e "${BLUE}🚀 Apollo Key detected - will introspect and publish${NC}"
    echo -e "   Graph: $GRAPH_REF"
    echo ""
    
    # Introspect and publish in pipeline
    if rover graph introspect "$GRAPHQL_URL" \
        --header "X-Allow-Introspection:true" \
        | tee "$SCHEMA_FILE" \
        | rover graph publish "$GRAPH_REF" \
        --schema - 2>&1; then
        
        echo ""
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║     ✅ Schema Introspected & Published Successfully!       ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BLUE}📄 Schema saved to: $SCHEMA_FILE${NC}"
        echo -e "${BLUE}🌐 View in Apollo Studio:${NC}"
        echo -e "   https://studio.apollographql.com/graph/${GRAPH_REF%%@*}"
        echo ""
        
        exit 0
    else
        echo -e "${RED}❌ Introspection/publish failed${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}ℹ️  Apollo Key not set - introspecting only (no publish)${NC}"
    echo ""
    
    # Just introspect and save locally
    if rover graph introspect "$GRAPHQL_URL" \
        --header "X-Allow-Introspection:true" \
        > "$SCHEMA_FILE.tmp" 2>/dev/null; then
        
        # Validate schema
        if [ -s "$SCHEMA_FILE.tmp" ] && grep -q "type Query" "$SCHEMA_FILE.tmp" 2>/dev/null; then
            mv "$SCHEMA_FILE.tmp" "$SCHEMA_FILE"
            
            LINES=$(wc -l < "$SCHEMA_FILE")
            SIZE=$(wc -c < "$SCHEMA_FILE")
            
            echo -e "${GREEN}✅ Schema introspected successfully!${NC}"
            echo -e "   Lines: $LINES"
            echo -e "   Size: $SIZE bytes"
            echo -e "   File: $SCHEMA_FILE"
            echo ""
            echo -e "${BLUE}💡 Tip: Set APOLLO_KEY to publish to Apollo Studio${NC}"
            echo ""
            
            exit 0
        else
            echo -e "${RED}❌ Invalid schema output${NC}"
            rm -f "$SCHEMA_FILE.tmp"
            exit 1
        fi
    else
        echo -e "${RED}❌ Introspection failed${NC}"
        rm -f "$SCHEMA_FILE.tmp"
        exit 1
    fi
fi