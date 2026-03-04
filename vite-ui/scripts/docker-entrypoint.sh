#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════
# 🚀 Vite Frontend Container Entrypoint - V5.0
# ═══════════════════════════════════════════════════════════
# Enhanced with proper gRPC file handling
# ═══════════════════════════════════════════════════════════

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Logging functions
log_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "${BLUE}▶${NC} ${BOLD}$1${NC}"; }

# ═══════════════════════════════════════════════════════════
# 🎨 Header
# ═══════════════════════════════════════════════════════════

echo -e "${BLUE}${BOLD}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║           🚀 Vite Frontend Container v5.0                 ║
║              with gRPC Support                            ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# ═══════════════════════════════════════════════════════════
# 📋 Configuration
# ═══════════════════════════════════════════════════════════

NODE_ENV="${NODE_ENV:-development}"
VITE_PORT="${VITE_PORT:-5173}"
GRAPHQL_ENDPOINT="${VITE_GRAPHQL_ENDPOINT:-http://aspdotnetweb:5000/graphql}"
BACKEND_URL="${VITE_API_URL:-http://aspdotnetweb:5000}"
GRPC_URL="${VITE_GRPC_URL:-http://localhost:5000}"
STRICT_MODE="${STRICT_MODE:-false}"
CONTINUE_ON_FAIL="${CONTINUE_ON_FAIL:-true}"

# Timeouts
MAX_BACKEND_WAIT="${BACKEND_WAIT_TIMEOUT:-180}"
MAX_GRAPHQL_WAIT="${GRAPHQL_WAIT_TIMEOUT:-180}"
MAX_SCHEMA_WAIT="${SCHEMA_WAIT_TIMEOUT:-120}"
POLL_INTERVAL="${GRAPHQL_POLL_INTERVAL:-3}"

# Schema paths
SCHEMA_PATHS=(
    "/app/apollo/schema.graphql"
    "/var/www/rssnews/apollo/schema.graphql"
    "./apollo/schema.graphql"
)

echo -e "${CYAN}📋 Configuration:${NC}"
echo -e "   NODE_ENV: ${YELLOW}$NODE_ENV${NC}"
echo -e "   VITE_PORT: ${YELLOW}$VITE_PORT${NC}"
echo -e "   Backend: ${YELLOW}$BACKEND_URL${NC}"
echo -e "   GraphQL: ${YELLOW}$GRAPHQL_ENDPOINT${NC}"
echo -e "   gRPC: ${YELLOW}$GRPC_URL${NC}"
echo -e "   Strict Mode: ${YELLOW}$STRICT_MODE${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# 🔧 Helper Functions
# ═══════════════════════════════════════════════════════════

# Check if schema file is valid
is_valid_schema() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local size=$(wc -c < "$file" 2>/dev/null || echo 0)
    
    if [[ $size -lt 500 ]]; then
        return 1
    fi
    
    if grep -q "type Query" "$file" 2>/dev/null; then
        if ! grep -q "_placeholder" "$file" 2>/dev/null; then
            # ตรวจว่ามี schema block (codegen ต้องการ)
            if grep -q "schema {" "$file" 2>/dev/null || grep -q "schema{" "$file" 2>/dev/null; then
                return 0
            fi
        fi
    fi
    
    return 1
}

# Find valid schema from multiple paths
find_valid_schema() {
    for path in "${SCHEMA_PATHS[@]}"; do
        if is_valid_schema "$path"; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

# Check if gRPC files exist and are valid
check_grpc_files() {
    local grpc_dir="/app/grpc"
    local required_files=(
        "rss_pb.ts"
        "RssServiceClientPb.ts"
    )
    
    for file in "${required_files[@]}"; do
        local filepath="$grpc_dir/$file"
        if [[ ! -f "$filepath" ]]; then
            return 1
        fi
        
        local size=$(wc -c < "$filepath" 2>/dev/null || echo 0)
        if [[ $size -lt 100 ]]; then
            return 1
        fi
    done
    
    return 0
}

# ═══════════════════════════════════════════════════════════
# ✅ Phase 0: gRPC Files Setup
# ═══════════════════════════════════════════════════════════

setup_grpc_files() {
    log_step "Phase 0: gRPC Files Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Ensure gRPC directories exist
    mkdir -p /app/grpc
    mkdir -p /app/grpc-generated
    
    log_info "Checking gRPC files..."
    
    if check_grpc_files; then
        log_success "gRPC files already exist"
        
        # List files
        ls -lh /app/grpc/*.ts 2>/dev/null | awk '{print "   •", $9, "("$5")"}'
    else
        log_warn "gRPC files missing or incomplete"
        log_info "Creating placeholder files..."
        
        # Create placeholder files
        if [[ -f "/app/scripts/create-grpc-placeholders.mjs" ]]; then
            if node /app/scripts/create-grpc-placeholders.mjs 2>&1; then
                log_success "Placeholder files created"
            else
                log_error "Failed to create placeholders"
                return 1
            fi
        else
            log_error "Placeholder creation script not found"
            return 1
        fi
    fi
    
    # Sync to grpc-generated
    log_info "Syncing to grpc-generated/..."
    if [[ -f "/app/scripts/synchronize-grpc.mjs" ]]; then
        if node /app/scripts/synchronize-grpc.mjs 2>&1; then
            log_success "gRPC files synchronized"
        else
            log_warn "Sync had issues, continuing..."
        fi
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════
# ✅ Phase 1: Backend Health Check
# ═══════════════════════════════════════════════════════════

wait_for_backend() {
    log_step "Phase 1: Backend Health Check"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    log_info "Checking: $BACKEND_URL/health"
    log_info "Timeout: ${MAX_BACKEND_WAIT}s"
    
    local elapsed=0
    
    while [[ $elapsed -lt $MAX_BACKEND_WAIT ]]; do
        if curl -sf "$BACKEND_URL/health" >/dev/null 2>&1; then
            log_success "Backend healthy (${elapsed}s)"
            return 0
        fi
        
        printf "\r${YELLOW}⏳${NC} Waiting for backend... %ds / %ds " "$elapsed" "$MAX_BACKEND_WAIT"
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done
    
    echo ""
    log_warn "Backend not ready after ${MAX_BACKEND_WAIT}s"
    return 1
}

# ═══════════════════════════════════════════════════════════
# ✅ Phase 2: GraphQL Endpoint Check
# ═══════════════════════════════════════════════════════════

wait_for_graphql() {
    log_step "Phase 2: GraphQL Endpoint Check"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    log_info "Testing: $GRAPHQL_ENDPOINT"
    log_info "Timeout: ${MAX_GRAPHQL_WAIT}s"
    
    local elapsed=0
    
    while [[ $elapsed -lt $MAX_GRAPHQL_WAIT ]]; do
        if curl -sf "${BACKEND_URL}/health/graphql" 2>/dev/null | grep -q "healthy"; then
            log_success "GraphQL health check passed (${elapsed}s)"
            return 0
        fi
        
        local response=$(curl -sf "$GRAPHQL_ENDPOINT" \
            -H "Content-Type: application/json" \
            -H "X-Allow-Introspection: true" \
            -d '{"query":"{ __typename }"}' \
            --connect-timeout 5 \
            --max-time 10 \
            2>/dev/null || echo "")
        
        if echo "$response" | grep -q "__typename\|Query"; then
            log_success "GraphQL endpoint responding (${elapsed}s)"
            return 0
        fi
        
        printf "\r${YELLOW}⏳${NC} Waiting for GraphQL... %ds / %ds " "$elapsed" "$MAX_GRAPHQL_WAIT"
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done
    
    echo ""
    log_warn "GraphQL not responding after ${MAX_GRAPHQL_WAIT}s"
    return 1
}

# ═══════════════════════════════════════════════════════════
# ✅ Phase 3: Wait for Schema File
# ═══════════════════════════════════════════════════════════

wait_for_schema() {
    log_step "Phase 3: Schema File Check"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    log_info "Looking for schema in:"
    for path in "${SCHEMA_PATHS[@]}"; do
        log_info "  - $path"
    done
    log_info "Timeout: ${MAX_SCHEMA_WAIT}s"
    
    local elapsed=0
    
    while [[ $elapsed -lt $MAX_SCHEMA_WAIT ]]; do
        local found_schema=$(find_valid_schema)
        
        if [[ -n "$found_schema" ]]; then
            local size=$(wc -c < "$found_schema")
            log_success "Valid schema found: $found_schema (${size} bytes)"
            
            if [[ "$found_schema" != "/app/apollo/schema.graphql" ]]; then
                mkdir -p /app/apollo
                cp "$found_schema" /app/apollo/schema.graphql
                log_info "Schema copied to /app/apollo/schema.graphql"
            fi
            
            return 0
        fi
        
        printf "\r${YELLOW}⏳${NC} Waiting for schema file... %ds / %ds " "$elapsed" "$MAX_SCHEMA_WAIT"
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done
    
    echo ""
    log_warn "Valid schema not found after ${MAX_SCHEMA_WAIT}s"
    return 1
}

# ═══════════════════════════════════════════════════════════
# ✅ Phase 4: GraphQL Files Assurance
# ═══════════════════════════════════════════════════════════

ensure_graphql_files() {
    log_step "Phase 4: GraphQL Files Assurance"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    mkdir -p /app/apollo/generated
    mkdir -p /app/apollo/fragments
    
    log_info "Running GraphQL files assurance..."
    if [[ -f "/app/scripts/assure-graphql-files.mjs" ]]; then
        if node /app/scripts/assure-graphql-files.mjs 2>&1; then
            log_success "GraphQL files ready"
        else
            log_warn "Assurance script had issues, continuing..."
        fi
    fi
    
    echo ""
    log_info "Schema Status:"
    if [[ -f "/app/apollo/schema.graphql" ]]; then
        local size=$(wc -c < /app/apollo/schema.graphql)
        local hash=$(md5sum /app/apollo/schema.graphql 2>/dev/null | cut -d' ' -f1 | head -c 12 || echo "unknown")
        
        echo -e "   File: ${YELLOW}/app/apollo/schema.graphql${NC}"
        echo -e "   Size: ${YELLOW}${size} bytes${NC}"
        echo -e "   Hash: ${YELLOW}${hash}${NC}"
        
        if is_valid_schema "/app/apollo/schema.graphql"; then
            log_success "Real schema detected"
        else
            log_warn "Schema is placeholder or invalid"
        fi
    else
        log_error "Schema file missing!"
    fi
}

# ═══════════════════════════════════════════════════════════
# ✅ Phase 5: Run Codegen (Optional)
# ═══════════════════════════════════════════════════════════

run_codegen() {
    if [[ "${SKIP_GRAPHQL_CODEGEN:-false}" == "true" ]]; then
        log_info "Codegen skipped (SKIP_GRAPHQL_CODEGEN=true)"
        return 0
    fi
    
    log_step "Phase 5: GraphQL Codegen"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if is_valid_schema "/app/apollo/schema.graphql"; then
        log_info "Running codegen with real schema..."
        
        if npm run graphql:codegen 2>&1; then
            log_success "Codegen completed successfully"
            return 0
        else
            log_warn "Codegen failed, using existing generated files"
        fi
    else
        log_info "No valid schema, skipping codegen"
    fi
    
    if [[ ! -f "/app/apollo/generated/graphql.ts" ]]; then
        log_info "Creating placeholder generated files..."
        create_placeholder_generated_files
    fi
}

# ═══════════════════════════════════════════════════════════
# 📝 Create Placeholder Generated Files
# ═══════════════════════════════════════════════════════════

create_placeholder_generated_files() {
    mkdir -p /app/apollo/generated
    
    cat > /app/apollo/generated/graphql.ts << 'TYPESCRIPT'
/* eslint-disable */
// Auto-generated placeholder

export type Maybe<T> = T | null;
export type InputMaybe<T> = Maybe<T>;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };

export type Scalars = {
  ID: { input: string; output: string };
  String: { input: string; output: string };
  Boolean: { input: boolean; output: boolean };
  Int: { input: number; output: number };
  Float: { input: number; output: number };
  DateTime: { input: string; output: string };
};

export type Query = {
  __typename?: 'Query';
  _placeholder?: Maybe<Scalars['String']['output']>;
};

export type Mutation = {
  __typename?: 'Mutation';
  _placeholder?: Maybe<Scalars['String']['output']>;
};
TYPESCRIPT

    cat > /app/apollo/generated/gql.ts << 'TYPESCRIPT'
/* eslint-disable */
import { DocumentNode } from 'graphql';

export function gql(source: string | TemplateStringsArray): DocumentNode {
  return { kind: 'Document', definitions: [] } as unknown as DocumentNode;
}

export { gql as graphql };
TYPESCRIPT

    cat > /app/apollo/generated/index.ts << 'TYPESCRIPT'
export * from './graphql';
export * from './gql';
TYPESCRIPT

    log_success "Placeholder generated files created"
}

# ═══════════════════════════════════════════════════════════
# 🚀 Main Execution
# ═══════════════════════════════════════════════════════════

main() {
    local grpc_ok=false
    local backend_ok=false
    local graphql_ok=false
    local schema_ok=false
    
    # Phase 0: gRPC Setup
    echo ""
    if setup_grpc_files; then
        grpc_ok=true
    fi
    
    # Phase 1: Backend Health
    echo ""
    if wait_for_backend; then
        backend_ok=true
    fi
    
    # Phase 2: GraphQL Endpoint
    echo ""
    if [[ "$backend_ok" == "true" ]]; then
        if wait_for_graphql; then
            graphql_ok=true
        fi
    else
        log_warn "Skipping GraphQL check (backend not ready)"
    fi
    
    # Phase 3: Schema File
    echo ""
    if wait_for_schema; then
        schema_ok=true
    fi
    
    # Phase 4: Ensure files
    echo ""
    ensure_graphql_files
    
    # Phase 5: Codegen
    echo ""
    run_codegen
    
    # Create ready marker
    touch /app/.ready
    
    # Summary
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${BOLD}Startup Summary${NC}                                         ${BLUE}║${NC}"
    echo -e "${BLUE}╠═══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  gRPC:     $([ "$grpc_ok" == "true" ] && echo "${GREEN}✅ Ready${NC} " || echo "${YELLOW}⚠️  Not Ready${NC}")                               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  Backend:  $([ "$backend_ok" == "true" ] && echo "${GREEN}✅ Ready${NC} " || echo "${YELLOW}⚠️  Not Ready${NC}")                               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  GraphQL:  $([ "$graphql_ok" == "true" ] && echo "${GREEN}✅ Ready${NC} " || echo "${YELLOW}⚠️  Not Ready${NC}")                               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  Schema:   $([ "$schema_ok" == "true" ] && echo "${GREEN}✅ Valid${NC} " || echo "${YELLOW}⚠️  Placeholder${NC}")                             ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ "$STRICT_MODE" == "true" ]]; then
        if [[ "$grpc_ok" == "false" ]] || [[ "$backend_ok" == "false" ]] || [[ "$graphql_ok" == "false" ]]; then
            log_error "STRICT_MODE=true and services not ready. Exiting..."
            exit 1
        fi
    fi
    
    # Start Vite
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          ${BOLD}🚀 Starting Vite Development Server${NC}${BLUE}           ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ $# -gt 0 ]]; then
        exec "$@"
    else
        exec npm run dev -- --host 0.0.0.0 --port "${VITE_PORT}"
    fi
}

# Run main function
main "$@"