#!/bin/bash
# ========================================
# Verify gRPC Setup
# ========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      gRPC Setup Verification           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"

# Check functions
check_dir() {
    local dir=$1
    local desc=$2
    
    if [ -d "$dir" ]; then
        local count=$(find "$dir" -type f 2>/dev/null | wc -l)
        echo -e "${GREEN}✅${NC} $desc: ${BLUE}$dir${NC} (${count} files)"
        return 0
    else
        echo -e "${RED}❌${NC} $desc: ${BLUE}$dir${NC} (not found)"
        return 1
    fi
}

check_file() {
    local file=$1
    local desc=$2
    
    if [ -f "$file" ]; then
        local size=$(du -h "$file" 2>/dev/null | cut -f1)
        echo -e "${GREEN}✅${NC} $desc: ${BLUE}$file${NC} (${size})"
        return 0
    else
        echo -e "${RED}❌${NC} $desc: ${BLUE}$file${NC} (not found)"
        return 1
    fi
}

check_volume() {
    local volume=$1
    local desc=$2
    
    if docker volume inspect "$volume" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC} $desc: ${BLUE}$volume${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️${NC}  $desc: ${BLUE}$volume${NC} (not found)"
        return 1
    fi
}

# Header
echo -e "${BLUE}[1/4] Checking Host Directories...${NC}\n"

check_dir "./protobuf" "Proto source"
check_dir "./shared/grpc" "gRPC compiled"
check_dir "./shared/graphql" "GraphQL schemas"
check_dir "./vite-ui/grpc-generated" "Frontend gRPC"
check_dir "./vite-ui/apollo/generated" "GraphQL codegen"

echo -e "\n${BLUE}[2/4] Checking Proto Files...${NC}\n"

check_file "./protobuf/rss.proto" "Main proto file"

echo -e "\n${BLUE}[3/4] Checking Docker Volumes...${NC}\n"

check_volume "swu-rssnews_grpc-batch" "gRPC batch volume"
check_volume "swu-rssnews_graphql-generated" "GraphQL volume"

echo -e "\n${BLUE}[4/4] Checking Generated Files...${NC}\n"

# Check if any .ts or .js files exist in grpc-generated
if [ -d "./vite-ui/grpc-generated" ]; then
    ts_count=$(find ./vite-ui/grpc-generated -name "*.ts" 2>/dev/null | wc -l)
    js_count=$(find ./vite-ui/grpc-generated -name "*.js" 2>/dev/null | wc -l)
    
    echo -e "${BLUE}Frontend gRPC:${NC}"
    echo "  TypeScript files: $ts_count"
    echo "  JavaScript files: $js_count"
    
    if [ $ts_count -gt 0 ] || [ $js_count -gt 0 ]; then
        echo -e "${GREEN}✅ Generated files found${NC}"
    else
        echo -e "${YELLOW}⚠️  No generated files (run codegen)${NC}"
    fi
fi

# Check C# files
if [ -d "./shared/grpc" ]; then
    cs_count=$(find ./shared/grpc -name "*.cs" 2>/dev/null | wc -l)
    
    echo -e "\n${BLUE}Backend gRPC:${NC}"
    echo "  C# files: $cs_count"
    
    if [ $cs_count -gt 0 ]; then
        echo -e "${GREEN}✅ Generated files found${NC}"
    else
        echo -e "${YELLOW}⚠️  No generated files (run codegen)${NC}"
    fi
fi

echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Summary                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"

echo -e "${GREEN}Suggestions:${NC}"
echo "  1. If directories are missing: ./make-grpc-dirs.sh"
echo "  2. If volumes are missing: docker compose up -d"
echo "  3. If generated files are missing:"
echo "     docker compose --profile setup up grpc-codegen grpc-codegen-ts"

echo