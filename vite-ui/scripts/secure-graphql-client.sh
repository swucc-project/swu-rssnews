#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Safe GraphQL Client Generation                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ฟังก์ชันตรวจสอบ schema
check_schema() {
    if [ ! -f "./apollo/schema.graphql" ]; then
        echo -e "${RED}❌ Schema file not found${NC}"
        return 1
    fi
    
    if grep -q "_placeholder" "./apollo/schema.graphql"; then
        echo -e "${YELLOW}⚠️  Schema is placeholder${NC}"
        return 1
    fi
    
    # ตรวจสอบว่ามี type อย่างน้อย 1 type
    if ! grep -q "^type " "./apollo/schema.graphql"; then
        echo -e "${RED}❌ Schema has no types${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Schema is valid${NC}"
    return 0
}

# 1. สร้าง placeholder files
echo -e "${YELLOW}Step 1: Ensuring placeholder files exist...${NC}"
npm run assure-files
echo ""

# 2. รอ GraphQL endpoint
echo -e "${YELLOW}Step 2: Waiting for GraphQL endpoint...${NC}"
MAX_RETRIES=3
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do
    if npm run wait-for-graphql 2>/dev/null; then
        echo -e "${GREEN}✅ GraphQL endpoint is ready${NC}"
        
        # 3. Introspect schema (retry logic)
        echo ""
        echo -e "${YELLOW}Step 3: Downloading schema (attempt $((RETRY+1))/$MAX_RETRIES)...${NC}"
        
        if npm run rover:introspect; then
            echo -e "${GREEN}✅ Schema downloaded${NC}"
            
            # 4. ตรวจสอบ schema
            echo ""
            echo -e "${YELLOW}Step 4: Validating schema...${NC}"
            if check_schema; then
                
                # 5. Generate client code
                echo ""
                echo -e "${YELLOW}Step 5: Generating client code...${NC}"
                
                if npm run codegen; then
                    echo -e "${GREEN}✅ Client code generated successfully${NC}"
                    
                    # ตรวจสอบว่า generated files มีจริง
                    if [ -f "./apollo/generated/graphql.ts" ] && \
                       [ -f "./apollo/generated/index.ts" ]; then
                        echo ""
                        echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
                        echo -e "${GREEN}║          ✅ GraphQL Generation Completed!                  ║${NC}"
                        echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
                        exit 0
                    else
                        echo -e "${RED}❌ Generated files not found${NC}"
                    fi
                else
                    echo -e "${RED}❌ Code generation failed${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  Schema validation failed${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Schema download failed (attempt $((RETRY+1)))${NC}"
        fi
        
        RETRY=$((RETRY+1))
        if [ $RETRY -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}Retrying in 5 seconds...${NC}"
            sleep 5
        fi
    else
        echo -e "${RED}❌ GraphQL endpoint not available${NC}"
        break
    fi
done

# Fallback
echo ""
echo -e "${YELLOW}⚠️  Using fallback mode (placeholder files)${NC}"
npm run assure-files

echo ""
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║    GraphQL generation skipped - using placeholders         ║${NC}"
echo -e "${YELLOW}║    Backend may not be ready yet                            ║${NC}"
echo -e "${YELLOW}║    Run 'make generate-graphql-safe' after backend starts   ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"

exit 0