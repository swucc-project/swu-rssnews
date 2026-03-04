#!/bin/bash
# ========================================
# gRPC & Protobuf Cleanup Script
# ========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Auto-detect project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    gRPC Files Cleanup Script          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo -e "${BLUE}Project: ${NC}$PROJECT_ROOT"
echo ""

# Confirm deletion
read -p "⚠️  This will delete all generated gRPC files. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ Cleanup cancelled${NC}"
    exit 0
fi

echo -e "\n${YELLOW}🧹 Cleaning up generated files...${NC}\n"

# Function to clean directory
clean_dir() {
    local dir=$1
    local desc=$2
    
    if [ -d "$dir" ]; then
        local file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
        if [ "$file_count" -gt 0 ]; then
            echo -e "${YELLOW}🗑️  Cleaning: ${NC}$dir ${RED}($desc - $file_count files)${NC}"
            rm -rf "$dir"/*
            echo -e "${GREEN}   ✅ Cleaned${NC}"
        else
            echo -e "${BLUE}   ℹ️  Already empty: ${NC}$dir"
        fi
    else
        echo -e "${BLUE}   ℹ️  Directory not found: ${NC}$dir"
    fi
}

# Clean generated files
clean_dir "$PROJECT_ROOT/shared/grpc" "C# compiled"
clean_dir "$PROJECT_ROOT/shared/graphql" "GraphQL schemas"
clean_dir "$PROJECT_ROOT/vite-ui/grpc-generated" "Frontend gRPC"
clean_dir "$PROJECT_ROOT/vite-ui/apollo/generated" "GraphQL codegen"

# Clean obj and bin directories (optional)
echo ""
read -p "🗑️  Also clean obj/bin directories? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    clean_dir "$PROJECT_ROOT/aspnetcore/obj" "Build artifacts"
    clean_dir "$PROJECT_ROOT/aspnetcore/bin" "Build outputs"
fi

echo -e "\n${GREEN}✅ Cleanup complete!${NC}"
echo -e "\n${YELLOW}💡 To regenerate:${NC}"
echo "   cd $PROJECT_ROOT"
echo "   docker compose --profile setup up --force-recreate grpc-codegen"
echo "   docker compose --profile setup up --force-recreate grpc-codegen-ts"
echo ""