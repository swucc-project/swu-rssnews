#!/bin/bash
# ═══════════════════════════════════════════════════════════
# 🚀 Project Initialization Script - COMPREHENSIVE FIX
# แก้ไขปัญหา external volumes และ permissions สำหรับ SQL Server
# ═══════════════════════════════════════════════════════════

set -e

echo "═══════════════════════════════════════════════════════════"
echo "🚀 SWU RSS News - Project Initialization (Complete Fix)"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PASSWORD_MIN_LENGTH=8
PASSWORD_MAX_LENGTH=32
DIR_SECRETS="./secrets"
FILE_PASSWORD="$DIR_SECRETS/db_password.txt"
DEFAULT_MIGRATION_NAME="SWUNewsEvents"
DEFAULT_ADD_NEW_MIGRATION="true"
PROJECT_NAME="swu-rssnews"

# SQL Server Configuration
MSSQL_UID=10001
MSSQL_GID=0

# ═══════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════

is_first_migration() {
    local migrations_dir="./aspnetcore/Migrations"
    
    if [ ! -d "$migrations_dir" ]; then
        return 0
    fi
    
    local cs_files
    cs_files=$(find "$migrations_dir" -name "*.cs" 2>/dev/null | wc -l)
    if [ "$cs_files" -eq 0 ]; then
        return 0
    fi
    
    return 1
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
    
    echo -e "${GREEN}✅ Docker is ready${NC}"
}

# ═══════════════════════════════════════════════════════════
# Step 1: สร้างไดเรกทอรีที่จำเป็น
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 1: Creating required directories...${NC}"

DIRECTORIES=(
    "./aspnetcore/.aspnet/DataProtection-Keys"
    "./aspnetcore/bin"
    "./aspnetcore/obj"
    "./secrets"
    "./shared/graphql"
    "./shared/grpc"
    "./vite-ui/apollo/generated"
    "./database"
    "./backups"
)

for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "  ${GREEN}✓${NC} Created: $dir"
    else
        echo -e "  ${YELLOW}→${NC} Exists: $dir"
    fi
done

# สร้าง Migrations directory เฉพาะครั้งแรก
if is_first_migration; then
    if [ ! -d "./aspnetcore/Migrations" ]; then
        mkdir -p "./aspnetcore/Migrations"
        echo -e "  ${GREEN}✓${NC} Created: ./aspnetcore/Migrations"
    fi
else
    echo -e "  ${GREEN}✓${NC} Migrations exist: ./aspnetcore/Migrations"
fi

chmod 755 ./aspnetcore/.aspnet/DataProtection-Keys 2>/dev/null || true

echo -e "${GREEN}✅ Directories created${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# Step 2: สร้างไฟล์ .gitkeep
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 2: Creating .gitkeep files...${NC}"

GITKEEP_DIRS=(
    "./shared/graphql"
    "./shared/grpc"
    "./vite-ui/apollo/generated"
    # ✅ ไม่ใส่ bin/obj ใน .gitkeep เพราะจะถูก named volume จัดการแทน
)

if is_first_migration; then
    GITKEEP_DIRS+=("./aspnetcore/Migrations")
fi

for dir in "${GITKEEP_DIRS[@]}"; do
    if [ -d "$dir" ] && [ ! -f "$dir/.gitkeep" ]; then
        touch "$dir/.gitkeep"
        echo -e "  ${GREEN}✓${NC} Created: $dir/.gitkeep"
    fi
done

# ✅ สร้าง .gitignore สำหรับ bin/obj เพื่อไม่ให้ commit เข้า git
for dir in "./aspnetcore/bin" "./aspnetcore/obj"; do
    if [ -d "$dir" ] && [ ! -f "$dir/.gitignore" ]; then
        echo "*" > "$dir/.gitignore"
        echo "!.gitignore" >> "$dir/.gitignore"
        echo -e "  ${GREEN}✓${NC} Created: $dir/.gitignore"
    fi
done

echo -e "${GREEN}✅ .gitkeep files created${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# Step 3: สร้าง External Docker Volumes สำหรับ SQL Server
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 3: Creating EXTERNAL SQL Server volumes...${NC}"

EXTERNAL_VOLUMES=(
    "mssql-system"
    "mssql-data"
    "mssql-logs"
    "mssql-backups"
)

echo -e "${CYAN}Creating external volumes with project prefix...${NC}"

for volume_short in "${EXTERNAL_VOLUMES[@]}"; do
    volume_full="${PROJECT_NAME}_${volume_short}"
    
    if docker volume inspect "$volume_full" >/dev/null 2>&1; then
        echo -e "  ${YELLOW}→${NC} Exists: $volume_full"
    else
        if docker volume create "$volume_full" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Created: $volume_full (external)"
        else
            echo -e "  ${RED}✗${NC} Failed: $volume_full"
            exit 1
        fi
    fi
done

echo -e "${GREEN}✅ External SQL Server volumes created${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# Step 3b: ✅ สร้าง Named Volumes สำหรับ ASP.NET Core Build Artifacts
# แยก bin/obj ออกจาก host mount เพื่อป้องกันการถูกทับ
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 3b: Creating ASP.NET Core build artifact volumes...${NC}"

ASPNETCORE_BUILD_VOLUMES=(
    "aspnetcore-binary:ASP.NET bin directory"
    "aspnetcore-obj:ASP.NET obj directory"
)

for volume_entry in "${ASPNETCORE_BUILD_VOLUMES[@]}"; do
    vol_name="${volume_entry%%:*}"
    description="${volume_entry##*:}"
    volume_full="${PROJECT_NAME}_${vol_name}"
    
    if docker volume inspect "$volume_full" >/dev/null 2>&1; then
        echo -e "  ${YELLOW}→${NC} Exists: $volume_full ($description)"
    else
        if docker volume create "$volume_full" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Created: $volume_full ($description)"
        else
            echo -e "  ${RED}✗${NC} Failed: $volume_full"
        fi
    fi
done

echo -e "${GREEN}✅ ASP.NET Core build artifact volumes created${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# Step 4: ตั้งค่า Permissions สำหรับ SQL Server Volumes
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 4: Setting SQL Server permissions (UID:GID = ${MSSQL_UID}:${MSSQL_GID})...${NC}"

for volume_short in "${EXTERNAL_VOLUMES[@]}"; do
    volume_full="${PROJECT_NAME}_${volume_short}"
    echo -e "  ${CYAN}🔧${NC} Configuring $volume_short..."
    
    if docker run --rm \
        -v "$volume_full:/target" \
        alpine:latest sh -c "
            chown -R ${MSSQL_UID}:${MSSQL_GID} /target && \
            chmod -R 755 /target
        " 2>/dev/null; then
        echo -e "     ${GREEN}✓${NC} Permissions set"
    else
        echo -e "     ${YELLOW}⚠${NC} Could not set permissions (may work anyway)"
    fi
done

echo ""

# สร้าง subdirectories ภายใน mssql-system volume
echo -e "${CYAN}Creating SQL Server subdirectories...${NC}"
if docker run --rm \
    -v "${PROJECT_NAME}_mssql-system:/var/opt/mssql" \
    --user "${MSSQL_UID}:${MSSQL_GID}" \
    alpine:latest sh -c '
        mkdir -p /var/opt/mssql/.system
        mkdir -p /var/opt/mssql/secrets
        chmod 755 /var/opt/mssql/.system
        chmod 755 /var/opt/mssql/secrets
    ' 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Subdirectories created"
else
    echo -e "  ${YELLOW}⚠${NC} Could not create subdirectories"
fi

echo -e "${GREEN}✅ SQL Server permissions configured${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# Step 5: สร้าง Internal Application Volumes
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 5: Creating internal application volumes...${NC}"

INTERNAL_VOLUMES=(
    "dotnet-accessories:ASP.NET Core tools"
    "web-logs:Application logs"
    "nodejs-libraries:Node modules cache"
    "frontend-libraries:Frontend assets"
    "grpc-batch:gRPC artifacts"
    "nginx-logs:Nginx logs"
    "graphql-generated:GraphQL generated code"
)

for volume_entry in "${INTERNAL_VOLUMES[@]}"; do
    vol_name="${volume_entry%%:*}"
    description="${volume_entry##*:}"
    volume_full="${PROJECT_NAME}_${vol_name}"
    
    if docker volume inspect "$volume_full" >/dev/null 2>&1; then
        echo -e "  ${YELLOW}→${NC} $vol_name"
    else
        if docker volume create "$volume_full" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $vol_name ($description)"
        else
            echo -e "  ${RED}✗${NC} $vol_name"
        fi
    fi
done

echo -e "${GREEN}✅ Internal volumes created${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# Step 6: ตั้งค่า Permissions สำหรับ Application Volumes
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 6: Setting application volume permissions...${NC}"

# Frontend volumes
echo -e "${CYAN}  Frontend volumes...${NC}"
docker run --rm \
    -v "${PROJECT_NAME}_nodejs-libraries:/node_modules" \
    -v "${PROJECT_NAME}_frontend-libraries:/frontend" \
    -v "${PROJECT_NAME}_graphql-generated:/graphql" \
    alpine:latest sh -c '
        mkdir -p /node_modules /frontend /graphql
        chmod -R 777 /node_modules /frontend /graphql
    ' 2>/dev/null && echo -e "    ${GREEN}✓${NC} Configured"

# Log volumes
echo -e "${CYAN}  Log volumes...${NC}"
docker run --rm \
    -v "${PROJECT_NAME}_web-logs:/weblogs" \
    -v "${PROJECT_NAME}_nginx-logs:/nginx-logs" \
    alpine:latest sh -c '
        mkdir -p /weblogs /nginx-logs
        chmod -R 777 /weblogs /nginx-logs
    ' 2>/dev/null && echo -e "    ${GREEN}✓${NC} Configured"

# gRPC volume
echo -e "${CYAN}  gRPC volume...${NC}"
docker run --rm \
    -v "${PROJECT_NAME}_grpc-batch:/grpc" \
    alpine:latest sh -c '
        mkdir -p /grpc
        chmod -R 777 /grpc
    ' 2>/dev/null && echo -e "    ${GREEN}✓${NC} Configured"

# ✅ ASP.NET Core build artifact volumes - ตั้ง permission ให้ใช้ได้
echo -e "${CYAN}  ASP.NET Core build volumes...${NC}"
docker run --rm \
    -v "${PROJECT_NAME}_aspnetcore-binary:/dotnet-bin" \
    -v "${PROJECT_NAME}_aspnetcore-obj:/dotnet-obj" \
    alpine:latest sh -c '
        mkdir -p /dotnet-bin /dotnet-obj
        chmod -R 755 /dotnet-bin /dotnet-obj
    ' 2>/dev/null && echo -e "    ${GREEN}✓${NC} Configured"

echo -e "${GREEN}✅ Application permissions configured${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# Step 7: ตรวจสอบและสร้างไฟล์ secrets
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 7: Setting up secrets...${NC}"

mkdir -p "$DIR_SECRETS"

if [ ! -f "$FILE_PASSWORD" ]; then
    echo -e "${YELLOW}⚠️  Database password file not found${NC}"
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           Password Requirements                       ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  • Length: ${PASSWORD_MIN_LENGTH} - ${PASSWORD_MAX_LENGTH} characters                       ║${NC}"
    echo -e "${CYAN}║  • Recommended: mix of letters, numbers, symbols      ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    while true; do
        echo -e "${CYAN}Please enter your database password:${NC}"
        read -s password
        echo ""
        
        len=${#password}
        
        if [ $len -lt $PASSWORD_MIN_LENGTH ]; then
            echo -e "${RED}❌ Too short: $len characters (min: $PASSWORD_MIN_LENGTH)${NC}"
            echo ""
            continue
        fi
        
        if [ $len -gt $PASSWORD_MAX_LENGTH ]; then
            echo -e "${RED}❌ Too long: $len characters (max: $PASSWORD_MAX_LENGTH)${NC}"
            echo ""
            continue
        fi
        
        echo -e "${CYAN}Please confirm your password:${NC}"
        read -s password_confirm
        echo ""
        
        if [ "$password" = "$password_confirm" ]; then
            echo -n "$password" > "$FILE_PASSWORD"
            chmod 600 "$FILE_PASSWORD"
            echo -e "${GREEN}✅ Password created successfully${NC}"
            break
        else
            echo -e "${RED}❌ Passwords do not match${NC}"
            echo ""
        fi
    done
else
    echo -e "${GREEN}✅ Database password file exists${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════════
# Step 8: ตรวจสอบไฟล์ .env
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 8: Checking .env file...${NC}"

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✅ .env file created from .env.example${NC}"
    else
        cat > .env << 'ENVEOF'
# Development Environment
APP_URL=http://localhost:8080
FRONTEND_URL=http://localhost:8080
ASPNETCORE_ENVIRONMENT=Development
DATABASE_HOST=mssql
DATABASE_NAME=RSSActivityWeb
ADD_NEW_MIGRATION=true
MIGRATION_NAME=SWUNewsEvents
COMPOSE_PROJECT_NAME=swu-rssnews
TZ=Asia/Bangkok
ENVEOF
        echo -e "${GREEN}✅ Development .env created${NC}"
    fi
else
    echo -e "${GREEN}✅ .env file exists${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════════
# Step 9: ตรวจสอบ Docker
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 9: Final Docker check...${NC}"
check_docker
echo ""

# ═══════════════════════════════════════════════════════════
# Step 10: Verification
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 10: Verifying volumes...${NC}"

echo -e "${CYAN}External SQL Server Volumes:${NC}"
for volume_short in "${EXTERNAL_VOLUMES[@]}"; do
    volume_full="${PROJECT_NAME}_${volume_short}"
    if docker volume inspect "$volume_full" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $volume_full"
    else
        echo -e "  ${RED}✗${NC} $volume_full - MISSING!"
    fi
done

echo ""
echo -e "${CYAN}ASP.NET Core Build Volumes:${NC}"
for volume_entry in "${ASPNETCORE_BUILD_VOLUMES[@]}"; do
    vol_name="${volume_entry%%:*}"
    volume_full="${PROJECT_NAME}_${vol_name}"
    if docker volume inspect "$volume_full" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $volume_full"
    else
        echo -e "  ${RED}✗${NC} $volume_full - MISSING!"
    fi
done

echo ""
echo -e "${CYAN}Internal Application Volumes:${NC}"
for volume_entry in "${INTERNAL_VOLUMES[@]}"; do
    vol_name="${volume_entry%%:*}"
    volume_full="${PROJECT_NAME}_${vol_name}"
    if docker volume inspect "$volume_full" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $volume_full"
    else
        echo -e "  ${YELLOW}→${NC} $volume_full (will be created by Docker Compose)"
    fi
done

echo ""

# ═══════════════════════════════════════════════════════════
# Step 11: สร้างเอกสาร
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 11: Creating documentation...${NC}"

if is_first_migration && [ ! -f "./aspnetcore/Migrations/README.md" ]; then
    cat > ./aspnetcore/Migrations/README.md << 'DOCEOF'
# EF Core Migrations

This directory contains Entity Framework Core migration files.

## Commands

```bash
# First-time setup
make migration-first

# Create new migration
make migration-add NAME=AddUserTable

# Apply migrations
make migration-apply
```
DOCEOF
    echo -e "${GREEN}✅ Documentation created${NC}"
else
    echo -e "${GREEN}✅ Documentation exists${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  ✨ Initialization Complete!                              ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📝 What was done:${NC}"
echo "  ✓ Created all required directories"
echo "  ✓ Created 4 external SQL Server volumes"
echo "  ✓ Set proper SQL Server permissions (UID:GID = $MSSQL_UID:$MSSQL_GID)"
echo "  ✓ Created aspnetcore-binary / aspnetcore-obj named volumes (prevents host mount override)"
echo "  ✓ Created internal application volumes"
echo "  ✓ Created/verified secrets"
echo "  ✓ Created/verified .env file"
echo ""
echo -e "${CYAN}📋 External SQL Server Volumes:${NC}"
for volume_short in "${EXTERNAL_VOLUMES[@]}"; do
    echo "  • ${PROJECT_NAME}_${volume_short}"
done
echo ""
echo -e "${CYAN}🔧 ASP.NET Core Build Volumes (prevents bin/obj override):${NC}"
echo "  • ${PROJECT_NAME}_aspnetcore-binary"
echo "  • ${PROJECT_NAME}_aspnetcore-obj"
echo ""
echo -e "${CYAN}🚀 Next Steps:${NC}"
echo "  1. Build containers:   docker compose build"
echo "  2. Start SQL Server:   docker compose up -d mssql"
echo "  3. Wait for healthy:   docker compose ps"
echo "  4. Run migrations:     make migration-first"
echo "  5. Start all:          docker compose up -d"
echo ""
echo -e "${CYAN}💡 Useful Commands:${NC}"
echo "  • Check volumes:       docker volume ls | grep $PROJECT_NAME"
echo "  • View SQL logs:       docker compose logs -f mssql"
echo "  • Migration status:    make migration-status"
echo ""
echo -e "${GREEN}✅ Ready to start! Run: docker compose up -d${NC}"
echo ""