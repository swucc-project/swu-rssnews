#!/bin/bash

# ═══════════════════════════════════════════════════════════
# 🔧 Apply GraphQL Connection Fixes
# ═══════════════════════════════════════════════════════════
# Bash Script for Linux/Mac
# ═══════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}🔧 Applying GraphQL Connection Fixes${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Function to check if file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✅ Found: $1${NC}"
        return 0
    else
        echo -e "${RED}❌ Not found: $1${NC}"
        return 1
    fi
}

# Function to backup file
backup_file() {
    if [ -f "$1" ]; then
        backup_path="$1.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$1" "$backup_path"
        echo -e "${YELLOW}📦 Backup created: $backup_path${NC}"
    fi
}

# Step 1: Stop containers
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Step 1: Stopping containers...${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if docker compose down; then
    echo -e "${GREEN}✅ Containers stopped successfully${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: Could not stop containers${NC}"
fi
echo ""

# Step 2: Backup existing files
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Step 2: Creating backups...${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

files_to_backup=(
    "./aspnetcore/Program.cs"
    "./aspnetcore/Properties/launchSettings.json"
    "./.env"
)

for file in "${files_to_backup[@]}"; do
    if [ -f "$file" ]; then
        backup_file "$file"
    fi
done
echo ""

# Step 3: Apply fixes
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Step 3: Applying fixes...${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if fix files exist
all_files_exist=true

if ! check_file "Program.cs"; then
    all_files_exist=false
    echo -e "${RED}❌ Fix file not found: Program.cs${NC}"
    echo -e "${YELLOW}   Please ensure you have downloaded all the fix files${NC}"
fi

if ! check_file "launchSettings.json"; then
    all_files_exist=false
    echo -e "${RED}❌ Fix file not found: launchSettings.json${NC}"
    echo -e "${YELLOW}   Please ensure you have downloaded all the fix files${NC}"
fi

if ! check_file ".env"; then
    all_files_exist=false
    echo -e "${RED}❌ Fix file not found: .env${NC}"
    echo -e "${YELLOW}   Please ensure you have downloaded all the fix files${NC}"
fi

if [ "$all_files_exist" = false ]; then
    echo ""
    echo -e "${RED}❌ Cannot proceed - missing fix files${NC}"
    exit 1
fi

# Copy fix files
echo ""
echo "Copying fixed files..."

cp "Program.cs" "./aspnetcore/Program.cs"
echo -e "${GREEN}✅ Program.cs updated${NC}"

mkdir -p "./aspnetcore/Properties"
cp "launchSettings.json" "./aspnetcore/Properties/launchSettings.json"
echo -e "${GREEN}✅ launchSettings.json updated${NC}"

cp ".env" "./.env"
echo -e "${GREEN}✅ .env updated${NC}"

echo ""

# Step 4: Rebuild containers
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Step 4: Rebuilding containers...${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Building backend..."
docker compose build --no-cache aspdotnetweb

echo "Building frontend..."
docker compose build --no-cache frontend

echo -e "${GREEN}✅ Containers rebuilt${NC}"
echo ""

# Step 5: Start containers
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Step 5: Starting containers...${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if docker compose up -d; then
    echo -e "${GREEN}✅ Containers started successfully${NC}"
else
    echo -e "${RED}❌ Failed to start containers${NC}"
    exit 1
fi

echo ""

# Step 6: Wait and verify
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Step 6: Waiting for services to be ready...${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${YELLOW}Waiting 30 seconds for services to initialize...${NC}"
sleep 30

# Verify backend
echo ""
echo "Checking backend health..."
if curl -sf http://localhost:5000/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend is healthy${NC}"
else
    echo -e "${YELLOW}⚠️  Backend health check failed${NC}"
fi

# Verify GraphQL
echo ""
echo "Checking GraphQL endpoint..."
if curl -sf http://localhost:5000/graphql \
    -H "Content-Type: application/json" \
    -d '{"query":"{ __typename }"}' >/dev/null 2>&1; then
    echo -e "${GREEN}✅ GraphQL endpoint is responding${NC}"
else
    echo -e "${YELLOW}⚠️  GraphQL check failed${NC}"
fi

echo ""

# Step 7: Show logs
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Step 7: Checking for warnings...${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo "Backend logs (checking for override warning):"
if docker logs aspnetcore 2>&1 | grep -i "override" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Warning found:${NC}"
    docker logs aspnetcore 2>&1 | grep -i "override" | sed 's/^/   /'
else
    echo -e "${GREEN}✅ No override warnings found${NC}"
fi

echo ""
echo "Frontend logs (checking GraphQL connection):"
frontend_logs=$(docker logs vite-user-interface 2>&1 | grep -i "GraphQL" | tail -5)
if [ -n "$frontend_logs" ]; then
    echo "$frontend_logs" | sed 's/^/   /'
else
    echo -e "${YELLOW}ℹ️  No GraphQL messages found yet${NC}"
fi

# Summary
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✨ Fix Application Complete!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📋 Next Steps:${NC}"
echo "   1. Monitor logs: docker compose logs -f"
echo "   2. Check backend: http://localhost:5000/health"
echo "   3. Check GraphQL: http://localhost:5000/graphql"
echo "   4. Access app: http://localhost:8080"
echo ""
echo -e "${CYAN}📝 To view detailed logs:${NC}"
echo "   Backend:  docker logs -f aspnetcore"
echo "   Frontend: docker logs -f vite-user-interface"
echo ""