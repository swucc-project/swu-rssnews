#!/bin/bash
# 🔧 gRPC Debug และ Fix Script
# สำหรับตรวจสอบและแก้ไขปัญหา gRPC code generation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Auto-detect project root (script should be in /scripts folder)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Expected namespace from proto file
EXPECTED_NAMESPACE="SwuNews"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       🔍 gRPC Diagnostics & Fix Utility               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}ℹ${NC}  Project root: $PROJECT_ROOT"
echo -e "${BLUE}ℹ${NC}  Expected namespace: $EXPECTED_NAMESPACE"
echo ""

# Counter for issues
ISSUES_FOUND=0

# ฟังก์ชันตรวจสอบไฟล์
check_file() {
    local file=$1
    local name=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅${NC} $name exists"
        return 0
    else
        echo -e "${RED}❌${NC} $name NOT found"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
        return 1
    fi
}

# ฟังก์ชันตรวจสอบ directory
check_dir() {
    local dir=$1
    local name=$2
    local is_critical=${3:-false}
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅${NC} $name exists"
        file_count=$(ls -1 "$dir" 2>/dev/null | wc -l)
        echo -e "   ${BLUE}ℹ${NC}  Contains $file_count files"
        return 0
    else
        if [ "$is_critical" = true ]; then
            echo -e "${RED}❌${NC} $name NOT found"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        else
            echo -e "${YELLOW}⚠️${NC}  $name NOT found (optional)"
        fi
        return 1
    fi
}

echo -e "${YELLOW}[1/9] Checking prerequisite files...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_file "$PROJECT_ROOT/protobuf/rss.proto" "Protobuf definition file"
check_file "$PROJECT_ROOT/aspnetcore/rssnews.csproj" "Project file"
check_file "$PROJECT_ROOT/aspnetcore/Dockerfile" "Dockerfile"
check_file "$PROJECT_ROOT/aspnetcore/Program.cs" "Program.cs"
check_file "$PROJECT_ROOT/docker-compose.yml" "Docker Compose file"
echo ""

echo -e "${YELLOW}[2/9] Checking proto file namespace...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PROTO_FILE="$PROJECT_ROOT/protobuf/rss.proto"
if [ -f "$PROTO_FILE" ]; then
    # ตรวจสอบ csharp_namespace
    CURRENT_NAMESPACE=$(grep -oP 'csharp_namespace\s*=\s*"\K[^"]+' "$PROTO_FILE" 2>/dev/null || echo "")
    
    if [ -n "$CURRENT_NAMESPACE" ]; then
        echo -e "${GREEN}✅${NC} csharp_namespace found: $CURRENT_NAMESPACE"
        
        if [ "$CURRENT_NAMESPACE" = "$EXPECTED_NAMESPACE" ]; then
            echo -e "${GREEN}✅${NC} Namespace matches expected: $EXPECTED_NAMESPACE"
        else
            echo -e "${YELLOW}⚠️${NC}  Namespace mismatch!"
            echo -e "   ${BLUE}ℹ${NC}  Expected: $EXPECTED_NAMESPACE"
            echo -e "   ${BLUE}ℹ${NC}  Found: $CURRENT_NAMESPACE"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    else
        echo -e "${RED}❌${NC} csharp_namespace NOT found in proto file"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
    
    # ตรวจสอบ package name
    PACKAGE_NAME=$(grep -oP '^package\s+\K[^;]+' "$PROTO_FILE" 2>/dev/null || echo "")
    if [ -n "$PACKAGE_NAME" ]; then
        echo -e "${GREEN}✅${NC} Package name: $PACKAGE_NAME"
    fi
else
    echo -e "${RED}❌${NC} Proto file not found"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

echo -e "${YELLOW}[3/9] Cleaning old gRPC generated files...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ASPNETCORE_PATH="$PROJECT_ROOT/aspnetcore"
OBJ_PATH="$ASPNETCORE_PATH/obj"
BIN_PATH="$ASPNETCORE_PATH/bin"

# ลบ obj folder
if [ -d "$OBJ_PATH" ]; then
    echo -e "${YELLOW}🗑️${NC}  Removing obj folder..."
    rm -rf "$OBJ_PATH"
    echo -e "${GREEN}✅${NC} obj folder removed"
else
    echo -e "${BLUE}ℹ${NC}  obj folder doesn't exist (clean)"
fi

# ลบ bin folder
if [ -d "$BIN_PATH" ]; then
    echo -e "${YELLOW}🗑️${NC}  Removing bin folder..."
    rm -rf "$BIN_PATH"
    echo -e "${GREEN}✅${NC} bin folder removed"
else
    echo -e "${BLUE}ℹ${NC}  bin folder doesn't exist (clean)"
fi

# ลบไฟล์ gRPC ที่อาจค้างอยู่ในที่อื่น
STALE_FILES=$(find "$ASPNETCORE_PATH" -type f \( -name "*Grpc.cs" -o -name "Rss.cs" \) 2>/dev/null | grep -v "ServiceInterface" || true)
if [ -n "$STALE_FILES" ]; then
    echo -e "${YELLOW}🗑️${NC}  Removing stale gRPC files..."
    echo "$STALE_FILES" | while read -r file; do
        echo -e "   ${RED}✕${NC} Removing: $file"
        rm -f "$file"
    done
    echo -e "${GREEN}✅${NC} Stale files removed"
else
    echo -e "${BLUE}ℹ${NC}  No stale gRPC files found"
fi

# ลบไฟล์ใน shared/grpc
if [ -d "$PROJECT_ROOT/shared/grpc" ]; then
    SHARED_FILES=$(find "$PROJECT_ROOT/shared/grpc" -name "*.cs" 2>/dev/null || true)
    if [ -n "$SHARED_FILES" ]; then
        echo -e "${YELLOW}🗑️${NC}  Cleaning shared/grpc folder..."
        rm -f "$PROJECT_ROOT/shared/grpc"/*.cs 2>/dev/null || true
        echo -e "${GREEN}✅${NC} shared/grpc cleaned"
    fi
fi
echo ""

echo -e "${YELLOW}[4/9] Checking directory structure...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# สร้าง directories ที่จำเป็น
REQUIRED_DIRS=(
    "$PROJECT_ROOT/shared/grpc"
    "$PROJECT_ROOT/shared/graphql"
    "$PROJECT_ROOT/aspnetcore/Migrations"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}📁${NC} Creating: $dir"
        mkdir -p "$dir"
        echo -e "${GREEN}✅${NC} Created: $dir"
    else
        echo -e "${GREEN}✅${NC} Exists: $dir"
    fi
done

check_dir "$PROJECT_ROOT/protobuf" "Protobuf directory" true
echo ""

echo -e "${YELLOW}[5/9] Checking .csproj configuration...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CSPROJ_FILE="$PROJECT_ROOT/aspnetcore/rssnews.csproj"

# ตรวจสอบว่ามี Protobuf configuration
if grep -q '<Protobuf Include="../protobuf/rss.proto"' "$CSPROJ_FILE"; then
    echo -e "${GREEN}✅${NC} Protobuf Include configuration found"
    
    # ตรวจสอบ GrpcServices
    if grep -q 'GrpcServices="Server"' "$CSPROJ_FILE"; then
        echo -e "${GREEN}✅${NC} GrpcServices=Server configured"
    else
        echo -e "${YELLOW}⚠️${NC}  GrpcServices may need to be set to 'Server'"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
    
    # ตรวจสอบว่าไม่มี OutputDir (เพื่อใช้ default obj/ folder)
    if grep -q 'OutputDir=' "$CSPROJ_FILE" | grep -i protobuf; then
        echo -e "${YELLOW}⚠️${NC}  OutputDir is set - may cause duplicate files"
        echo -e "   ${BLUE}💡${NC} Consider removing OutputDir to use default obj/ location"
    else
        echo -e "${GREEN}✅${NC} No custom OutputDir (using default obj/)"
    fi
else
    echo -e "${RED}❌${NC} Protobuf configuration NOT found in .csproj"
    echo -e "${YELLOW}💡${NC} You need to add Protobuf configuration"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# ตรวจสอบ required packages
declare -a REQUIRED_PACKAGES=("Grpc.Tools" "Grpc.AspNetCore" "Google.Protobuf")
for package in "${REQUIRED_PACKAGES[@]}"; do
    if grep -q "$package" "$CSPROJ_FILE"; then
        echo -e "${GREEN}✅${NC} $package package reference found"
    else
        echo -e "${RED}❌${NC} $package package NOT found"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
done
echo ""

echo -e "${YELLOW}[6/9] Checking Docker setup...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ตรวจสอบว่า Docker ทำงานอยู่หรือไม่
if docker info > /dev/null 2>&1; then
    echo -e "${GREEN}✅${NC} Docker is running"
    
    # ตรวจสอบ docker compose version
    if docker compose version > /dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version --short)
        echo -e "${GREEN}✅${NC} Docker Compose available (v$COMPOSE_VERSION)"
    else
        echo -e "${YELLOW}⚠️${NC}  Docker Compose plugin not found"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
    
    # ตรวจสอบ containers
    if docker ps -a --filter "name=aspnetcore" --format '{{.Names}}' | grep -q aspnetcore; then
        echo -e "${GREEN}✅${NC} aspnetcore container exists"
        status=$(docker ps --filter "name=aspnetcore" --format '{{.Status}}')
        echo -e "   ${BLUE}ℹ${NC}  Status: $status"
    else
        echo -e "${YELLOW}⚠️${NC}  aspnetcore container not found"
    fi
else
    echo -e "${RED}❌${NC} Docker is not running"
    echo -e "${YELLOW}💡${NC} Please start Docker Desktop"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

echo -e "${YELLOW}[7/9] Checking ServiceInterface files...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SERVICE_FILE="$PROJECT_ROOT/aspnetcore/ServiceInterface/RSSItemService.cs"
if [ -f "$SERVICE_FILE" ]; then
    echo -e "${GREEN}✅${NC} RSSItemService.cs exists"
    
    # ตรวจสอบว่า using namespace ถูกต้อง
    if grep -q "using $EXPECTED_NAMESPACE;" "$SERVICE_FILE"; then
        echo -e "${GREEN}✅${NC} Correct namespace import: using $EXPECTED_NAMESPACE;"
    else
        CURRENT_USING=$(grep -oP 'using \K\w+(?=;)' "$SERVICE_FILE" | head -1)
        echo -e "${RED}❌${NC} Wrong namespace import in RSSItemService.cs"
        echo -e "   ${BLUE}ℹ${NC}  Expected: using $EXPECTED_NAMESPACE;"
        echo -e "   ${BLUE}ℹ${NC}  Found: using $CURRENT_USING;"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
    
    # ตรวจสอบ class inheritance
    if grep -q "$EXPECTED_NAMESPACE.RSSItemService.RSSItemServiceBase" "$SERVICE_FILE"; then
        echo -e "${GREEN}✅${NC} Correct base class: $EXPECTED_NAMESPACE.RSSItemService.RSSItemServiceBase"
    else
        echo -e "${YELLOW}⚠️${NC}  Base class may not match expected namespace"
    fi
else
    echo -e "${RED}❌${NC} RSSItemService.cs NOT found"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

echo -e "${YELLOW}[8/9] Testing local dotnet build...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create temporary log directory
mkdir -p /tmp/grpc-debug

if command -v dotnet &> /dev/null; then
    echo -e "${BLUE}🔨${NC} Running dotnet restore..."
    cd "$ASPNETCORE_PATH"
    
    if dotnet restore "rssnews.csproj" > /tmp/grpc-debug/restore.log 2>&1; then
        echo -e "${GREEN}✅${NC} dotnet restore successful"
        
        echo -e "${BLUE}🔨${NC} Running dotnet build..."
        if dotnet build "rssnews.csproj" --no-restore > /tmp/grpc-debug/build.log 2>&1; then
            echo -e "${GREEN}✅${NC} dotnet build successful"
            
            # ตรวจสอบไฟล์ที่ถูก generate
            GENERATED_FILES=$(find "$OBJ_PATH" -name "*.cs" 2>/dev/null | grep -i "rss\|grpc" || true)
            if [ -n "$GENERATED_FILES" ]; then
                echo -e "${GREEN}✅${NC} Generated gRPC files found:"
                echo "$GENERATED_FILES" | while read -r file; do
                    echo -e "   ${BLUE}•${NC} $file"
                    
                    # ตรวจสอบ namespace ในไฟล์ที่ generate
                    if grep -q "namespace $EXPECTED_NAMESPACE" "$file" 2>/dev/null; then
                        echo -e "     ${GREEN}✓${NC} Correct namespace: $EXPECTED_NAMESPACE"
                    fi
                done
            else
                echo -e "${YELLOW}⚠️${NC}  No gRPC files found in obj/"
            fi
        else
            echo -e "${RED}❌${NC} dotnet build failed"
            echo -e "${YELLOW}💡${NC} Check logs: cat /tmp/grpc-debug/build.log"
            echo -e "\n${RED}Last 20 lines of error log:${NC}"
            tail -n 20 /tmp/grpc-debug/build.log
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    else
        echo -e "${RED}❌${NC} dotnet restore failed"
        echo -e "${YELLOW}💡${NC} Check logs: cat /tmp/grpc-debug/restore.log"
        tail -n 10 /tmp/grpc-debug/restore.log
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
    
    cd "$PROJECT_ROOT"
else
    echo -e "${YELLOW}⚠️${NC}  dotnet CLI not found, skipping local build test"
    echo -e "${BLUE}ℹ${NC}  Will test via Docker instead"
fi
echo ""

echo -e "${YELLOW}[9/9] Summary & Recommendations${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo -e "${GREEN}✅ No critical issues found!${NC}"
    echo ""
    echo -e "${BLUE}📋 System is ready. Next steps:${NC}"
    echo "   1. Build containers:"
    echo -e "      ${GREEN}docker compose build --no-cache aspdotnetweb${NC}"
    echo "   2. Run migrations:"
    echo -e "      ${GREEN}docker compose --profile setup up queue-db-migration${NC}"
    echo -e "      ${GREEN}docker compose --profile migration up migration-db${NC}"
    echo "   3. Start services:"
    echo -e "      ${GREEN}docker compose up -d${NC}"
    echo "   4. Check logs:"
    echo -e "      ${GREEN}docker compose logs -f aspdotnetweb${NC}"
else
    echo -e "${RED}⚠️  Found $ISSUES_FOUND issue(s) that need attention${NC}"
    echo ""
    echo -e "${BLUE}📋 Recommended fix steps:${NC}"
    
    echo -e "   ${YELLOW}1.${NC} Verify proto file has correct namespace:"
    echo -e "      ${GREEN}option csharp_namespace = \"$EXPECTED_NAMESPACE\";${NC}"
    
    echo -e "   ${YELLOW}2.${NC} Update RSSItemService.cs to use correct namespace:"
    echo -e "      ${GREEN}using $EXPECTED_NAMESPACE;${NC}"
    
    echo -e "   ${YELLOW}3.${NC} Clean and rebuild:"
    echo -e "      ${GREEN}cd aspnetcore && rm -rf obj bin && dotnet restore && dotnet build${NC}"
    
    echo -e "   ${YELLOW}4.${NC} For Docker:"
    echo -e "      ${GREEN}docker compose build --no-cache aspdotnetweb migration-db${NC}"
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  📖 Expected namespace: $EXPECTED_NAMESPACE                        ║${NC}"
echo -e "${BLUE}║  📁 Debug logs saved in: /tmp/grpc-debug/             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"

# Exit with error code if issues found
exit $ISSUES_FOUND