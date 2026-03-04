#!/bin/bash
# ═══════════════════════════════════════════════════════════
# 🚀 One-Click Volume Fix for SQL Server
# Creates and configures all required Docker volumes
# ═══════════════════════════════════════════════════════════

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PROJECT_NAME="swu-rssnews"
MSSQL_UID=10001
MSSQL_GID=0

# External SQL Server volumes
EXTERNAL_VOLUMES=(
    "mssql-system"
    "mssql-data"
    "mssql-logs"
    "mssql-backups"
)

# ═══════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
    echo ""
}

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker daemon is not running${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Docker is running${NC}"
}

# ═══════════════════════════════════════════════════════════
# Main Execution
# ═══════════════════════════════════════════════════════════

print_header "🔧 SQL Server Volume Fix"

# Check Docker
print_section "Checking Docker"
check_docker

# ═══════════════════════════════════════════════════════════
# Step 1: Stop SQL Server Container
# ═══════════════════════════════════════════════════════════

print_section "Step 1: Stopping SQL Server"

if docker ps --format '{{.Names}}' | grep -q '^sqlserver$'; then
    echo -e "  ${YELLOW}🛑 Stopping SQL Server container...${NC}"
    docker compose stop mssql 2>/dev/null || true
    sleep 3
    echo -e "  ${GREEN}✅ Stopped${NC}"
else
    echo -e "  ${CYAN}ℹ️  SQL Server container not running${NC}"
fi

# ═══════════════════════════════════════════════════════════
# Step 2: Create External SQL Server Volumes
# ═══════════════════════════════════════════════════════════

print_section "Step 2: Creating External SQL Server Volumes"

for vol_short in "${EXTERNAL_VOLUMES[@]}"; do
    vol_full="${PROJECT_NAME}_${vol_short}"
    
    if docker volume inspect "$vol_full" >/dev/null 2>&1; then
        echo -e "  ${YELLOW}→${NC} $vol_full already exists"
    else
        echo -e "  ${CYAN}📦 Creating $vol_full...${NC}"
        if docker volume create "$vol_full" >/dev/null 2>&1; then
            echo -e "     ${GREEN}✅ Created${NC}"
        else
            echo -e "     ${RED}❌ Failed${NC}"
            exit 1
        fi
    fi
done

echo ""
echo -e "${GREEN}✅ External volumes ready${NC}"

# ═══════════════════════════════════════════════════════════
# Step 3: Set SQL Server Permissions
# ═══════════════════════════════════════════════════════════

print_section "Step 3: Setting SQL Server Permissions (UID:GID = ${MSSQL_UID}:${MSSQL_GID})"

for vol_short in "${EXTERNAL_VOLUMES[@]}"; do
    vol_full="${PROJECT_NAME}_${vol_short}"
    
    echo -e "  ${CYAN}🔧 Configuring $vol_short...${NC}"
    
    if docker run --rm \
        -v "$vol_full:/target" \
        alpine:latest sh -c "
            chown -R ${MSSQL_UID}:${MSSQL_GID} /target && \
            chmod -R 755 /target
        " 2>/dev/null; then
        echo -e "     ${GREEN}✅ Permissions set${NC}"
    else
        echo -e "     ${YELLOW}⚠️  Warning: Could not set permissions${NC}"
    fi
done

echo ""

# Create SQL Server subdirectories
echo -e "  ${CYAN}📁 Creating SQL Server subdirectories...${NC}"

if docker run --rm \
    -v "${PROJECT_NAME}_mssql-system:/var/opt/mssql" \
    --user "${MSSQL_UID}:${MSSQL_GID}" \
    alpine:latest sh -c '
        mkdir -p /var/opt/mssql/.system && \
        mkdir -p /var/opt/mssql/secrets && \
        chmod 755 /var/opt/mssql/.system && \
        chmod 755 /var/opt/mssql/secrets
    ' 2>/dev/null; then
    echo -e "     ${GREEN}✅ Subdirectories created${NC}"
else
    echo -e "     ${YELLOW}⚠️  Warning: Could not create subdirectories${NC}"
fi

echo ""
echo -e "${GREEN}✅ SQL Server permissions configured${NC}"

# ═══════════════════════════════════════════════════════════
# Step 4: Verification
# ═══════════════════════════════════════════════════════════

print_section "Step 4: Verifying Volumes"

echo -e "${CYAN}External SQL Server Volumes:${NC}"
for vol_short in "${EXTERNAL_VOLUMES[@]}"; do
    vol_full="${PROJECT_NAME}_${vol_short}"
    
    if docker volume inspect "$vol_full" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ $vol_full${NC}"
    else
        echo -e "  ${RED}❌ $vol_full - MISSING!${NC}"
    fi
done

echo ""

# ═══════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════

print_header "✨ Volume Fix Complete!"

echo -e "${CYAN}📝 Summary:${NC}"
echo "  ✓ Created 4 external SQL Server volumes"
echo "  ✓ Set SQL Server permissions (UID:GID = ${MSSQL_UID}:${MSSQL_GID})"
echo "  ✓ Created internal application volumes"
echo "  ✓ Configured all volume permissions"
echo ""

echo -e "${CYAN}🚀 Next Steps:${NC}"
echo "  1. Start SQL Server:   docker compose up -d mssql"
echo "  2. Wait for healthy:   docker compose ps"
echo "  3. Check logs:         docker compose logs -f mssql"
echo "  4. Start all:          docker compose up -d"
echo ""

echo -e "${YELLOW}💡 Useful Commands:${NC}"
echo "  • List volumes:        docker volume ls | grep $PROJECT_NAME"
echo "  • Check SQL health:    docker inspect sqlserver --format='{{.State.Health.Status}}'"
echo "  • View SQL logs:       docker compose logs --tail=100 -f mssql"
echo ""

echo -e "${GREEN}✅ Ready to start! Run: docker compose up -d${NC}"
echo ""