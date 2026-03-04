#!/bin/bash
# ========================================
# gRPC & Protobuf Directory Initialization
# ========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  gRPC Directory Initialization Script ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"

# Function to create directory
ensure_dir() {
    local dir=$1
    local desc=$2
    
    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}📁 Creating: ${NC}$dir ${BLUE}($desc)${NC}"
        mkdir -p "$dir"
    else
        echo -e "${GREEN}✅ Exists: ${NC}$dir"
    fi
}

# Function to check file exists
check_file() {
    local file=$1
    local desc=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ Found: ${NC}$file ${BLUE}($desc)${NC}"
        return 0
    else
        echo -e "${RED}❌ Missing: ${NC}$file ${BLUE}($desc)${NC}"
        return 1
    fi
}

# ========================================
# 1. Host-Level Directories
# ========================================
echo -e "\n${BLUE}[1/5] Creating Host Directories...${NC}\n"

ensure_dir "./protobuf" "Proto source files"
ensure_dir "./shared" "Shared output directory"
ensure_dir "./shared/grpc" "C# compiled protobuf"
ensure_dir "./shared/graphql" "GraphQL schema files"

# ========================================
# 2. ASP.NET Directories
# ========================================
echo -e "\n${BLUE}[2/5] Creating ASP.NET Directories...${NC}\n"

ensure_dir "./aspnetcore/obj" "Build artifacts"
ensure_dir "./aspnetcore/obj/grpc" "gRPC generated C# files"
ensure_dir "./aspnetcore/Migrations" "EF Core migrations"

# ========================================
# 3. Frontend Directories
# ========================================
echo -e "\n${BLUE}[3/5] Creating Frontend Directories...${NC}\n"

ensure_dir "./vite-ui/grpc-generated" "Frontend gRPC code"
ensure_dir "./vite-ui/apollo" "Apollo/GraphQL directory"
ensure_dir "./vite-ui/apollo/generated" "GraphQL codegen output"
ensure_dir "./vite-ui/apollo/fragments" "GraphQL fragments"
ensure_dir "./vite-ui/wwwroot" "Static assets"
ensure_dir "./vite-ui/wwwroot/grpc" "Public gRPC files"

# ========================================
# 4. Set Permissions
# ========================================
echo -e "\n${BLUE}[4/5] Setting Permissions...${NC}\n"

chmod -R 755 ./protobuf 2>/dev/null || true
chmod -R 755 ./shared 2>/dev/null || true
chmod -R 755 ./aspnetcore/obj 2>/dev/null || true
chmod -R 755 ./vite-ui/grpc-generated 2>/dev/null || true
chmod -R 755 ./vite-ui/apollo 2>/dev/null || true

echo -e "${GREEN}✅ Permissions updated${NC}"

# ========================================
# 4.5. Clean Old gRPC Generated Files
# ========================================
echo -e "\n${BLUE}[4.5/5] Cleaning old gRPC files...${NC}\n"

# ลบ obj/bin ใน aspnetcore
if [ -d "./aspnetcore/obj" ]; then
    echo -e "${YELLOW}🗑️  Removing: ${NC}./aspnetcore/obj"
    rm -rf ./aspnetcore/obj
fi

if [ -d "./aspnetcore/bin" ]; then
    echo -e "${YELLOW}🗑️  Removing: ${NC}./aspnetcore/bin"
    rm -rf ./aspnetcore/bin
fi

find ./aspnetcore -name "*Grpc.cs" -type f -delete 2>/dev/null || true
find ./aspnetcore -name "Rss.cs" -type f -delete 2>/dev/null || true

echo -e "${GREEN}✅ Old gRPC files cleaned${NC}"

# ========================================
# 5. Create Placeholder Proto if Missing
# ========================================
echo -e "\n${BLUE}[5/5] Checking Proto Files...${NC}\n"

if ! check_file "./protobuf/rss.proto" "Main proto file"; then
    echo -e "${YELLOW}⚠️  Creating placeholder rss.proto...${NC}"
    
    cat > ./protobuf/rss.proto << 'PROTO_EOF'
syntax = "proto3";

package rssfeed;

option csharp_namespace = "SwuNews";

import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";

service RSSItemService {
  rpc AddRSSItem (AddRSSItemRequest) returns (Item);
  rpc GetRSSItems (google.protobuf.Empty) returns (GetRSSItemsResponse);
  rpc GetRSSItemByID (GetRSSItemRequest) returns (Item);
  rpc UpdateRSSItem (UpdateRSSItemRequest) returns (Item);
  rpc DeleteRSSItem (DeleteRSSItemRequest) returns (DeleteRSSItemResponse);
}

message Item {
  string item_id = 1;
  string title = 2;
  string link = 3;
  string description = 4;
  google.protobuf.Timestamp published_date = 5;
  Category category = 6;
  Author author = 7;
}

message Category {
  int32 id = 1;
  string name = 2;
}

message Author {
  string author_id = 1;
  string firstname = 2;
  string lastname = 3;
}

message AddRSSItemRequest {
  string title = 1;
  string link = 2;
  string description = 3;
  google.protobuf.Timestamp published_date = 4;
  Category category = 5;
  Author author = 6;
}

message GetRSSItemRequest {
  string item_id = 1;
}

message GetRSSItemsResponse {
  repeated Item items = 1;
}

message UpdateRSSItemRequest {
  string item_id = 1;
  string title = 2;
  string link = 3;
  string description = 4;
  google.protobuf.Timestamp published_date = 5;
  Category category = 6;
  Author author = 7;
}

message DeleteRSSItemRequest {
  string item_id = 1;
}

message DeleteRSSItemResponse {
  bool success = 1;
}
PROTO_EOF
    
    echo -e "${GREEN}✅ Created placeholder rss.proto${NC}"
fi

# ========================================
# Summary
# ========================================
echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Directory Summary              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"

echo -e "${GREEN}📂 Host Directories:${NC}"
echo "   ./protobuf                → Proto source files"
echo "   ./shared/grpc             → C# compiled protobuf"
echo "   ./shared/graphql          → GraphQL schemas"

echo -e "\n${GREEN}📂 Backend Directories:${NC}"
echo "   ./aspnetcore/obj/grpc     → Generated C# gRPC"

echo -e "\n${GREEN}📂 Frontend Directories:${NC}"
echo "   ./vite-ui/grpc-generated  → Generated TS/JS gRPC"
echo "   ./vite-ui/apollo/generated → GraphQL codegen"

echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Next Steps                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}1.${NC} Generate gRPC code:"
echo "   docker compose --profile setup up grpc-codegen grpc-codegen-ts"

echo -e "\n${YELLOW}2.${NC} Start services:"
echo "   docker compose up -d"

echo -e "\n${GREEN}✨ Initialization complete!${NC}\n"