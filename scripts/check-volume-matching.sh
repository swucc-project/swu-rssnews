#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  🔍 Volume Mapping Checker
#  Verify consistency between docker-compose.yml and Makefile
# ═══════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Volume Mapping Consistency Check         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

PROJECT_NAME="swu-rssnews"

# Expected volumes from docker-compose.yml
EXPECTED_VOLUMES=(
    "mssql-system"
    "mssql-data"
    "mssql-logs"
    "mssql-backups"
    "dotnet-accessories"
    "web-logs"
    "nodejs-libraries"
    "frontend-libraries"
    "grpc-batch"
    "nginx-logs"
)

echo -e "${YELLOW}📋 Expected Volumes:${NC}"
for vol in "${EXPECTED_VOLUMES[@]}"; do
    echo "  • ${PROJECT_NAME}_${vol}"
done
echo ""

echo -e "${YELLOW}🔍 Checking Docker Volumes...${NC}"
issues=0

for vol in "${EXPECTED_VOLUMES[@]}"; do
    full_name="${PROJECT_NAME}_${vol}"
    
    if docker volume inspect "$full_name" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} $vol"
    else
        echo -e "  ${RED}❌${NC} $vol - NOT FOUND"
        ((issues++))
    fi
done

echo ""

if [ $issues -eq 0 ]; then
    echo -e "${GREEN}✅ All volumes exist and are correctly named${NC}"
else
    echo -e "${RED}❌ Found $issues missing volumes${NC}"
    echo ""
    echo -e "${YELLOW}💡 To fix:${NC}"
    echo "  1. Run: make sql-volumes-init"
    echo "  2. Run: docker compose up -d"
fi

echo ""
echo -e "${YELLOW}📊 Volume Usage:${NC}"
for vol in "${EXPECTED_VOLUMES[@]}"; do
    full_name="${PROJECT_NAME}_${vol}"
    
    if docker volume inspect "$full_name" >/dev/null 2>&1; then
        size=$(docker run --rm -v "$full_name:/vol:ro" alpine:latest du -sh /vol 2>/dev/null | cut -f1 || echo "N/A")
        echo "  $vol: $size"
    fi
done

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              Check Complete                  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"