#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
GRAPHQL_ENDPOINT="${GRAPHQL_ENDPOINT:-http://aspdotnetweb:5000/graphql}"
SCHEMA_FILE="${SCHEMA_FILE:-apollo/schema.graphql}"
GENERATED_DIR="${GENERATED_DIR:-apollo/generated}"
MAX_RETRIES="${MAX_RETRIES:-60}"
RETRY_DELAY="${RETRY_DELAY:-5}"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          GraphQL Setup Script v3.0                         ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️${NC}  $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

# Create placeholder files using the improved script
create_placeholders() {
    log_info "Creating placeholder files..."
    node scripts/assure-graphql-files.mjs
    log_success "Placeholder files created"
}

# Wait for GraphQL endpoint
wait_for_graphql() {
    log_info "Waiting for GraphQL endpoint..."
    
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -sf -X POST "$GRAPHQL_ENDPOINT" \
            -H "Content-Type: application/json" \
            -H "X-Allow-Introspection: true" \
            -d '{"query":"{__typename}"}' > /dev/null 2>&1; then
            log_success "GraphQL endpoint is ready"
            return 0
        fi
        
        retries=$((retries + 1))
        echo -ne "\r  Attempt $retries/$MAX_RETRIES..."
        sleep $RETRY_DELAY
    done
    
    log_error "GraphQL endpoint not available after $MAX_RETRIES attempts"
    return 1
}

# Download schema
download_schema() {
    log_info "Downloading GraphQL schema..."
    
    # Method 1: Try Apollo Rover
    if command -v rover &> /dev/null; then
        log_info "Trying with Apollo Rover..."
        
        if rover graph introspect "$GRAPHQL_ENDPOINT" \
            --header "X-Allow-Introspection:true" \
            > "$SCHEMA_FILE.tmp" 2>/dev/null; then
            
            # Validate schema
            if grep -q "type Query" "$SCHEMA_FILE.tmp" && \
               ! grep -q "error" "$SCHEMA_FILE.tmp"; then
                mv "$SCHEMA_FILE.tmp" "$SCHEMA_FILE"
                log_success "Schema downloaded via Rover"
                return 0
            fi
        fi
        rm -f "$SCHEMA_FILE.tmp"
    fi
    
    # Method 2: Try get-graphql-schema
    log_info "Trying with get-graphql-schema..."
    
    if npx -y get-graphql-schema "$GRAPHQL_ENDPOINT" \
        --header "X-Allow-Introspection=true" \
        > "$SCHEMA_FILE.tmp" 2>/dev/null; then
        
        if grep -q "type Query" "$SCHEMA_FILE.tmp" && \
           [ $(wc -c < "$SCHEMA_FILE.tmp") -gt 500 ]; then
            mv "$SCHEMA_FILE.tmp" "$SCHEMA_FILE"
            log_success "Schema downloaded via get-graphql-schema"
            return 0
        fi
    fi
    rm -f "$SCHEMA_FILE.tmp"
    
    # Method 3: Try direct introspection
    log_info "Trying direct introspection..."
    
    # Simplified introspection query
    INTROSPECTION_QUERY='query IntrospectionQuery{__schema{queryType{name}mutationType{name}subscriptionType{name}types{kind name description fields(includeDeprecated:true){name description args{name description type{...TypeRef}defaultValue}type{...TypeRef}isDeprecated deprecationReason}inputFields{...InputValue}interfaces{...TypeRef}enumValues(includeDeprecated:true){name description isDeprecated deprecationReason}possibleTypes{...TypeRef}}directives{name description locations args{...InputValue}}}}fragment InputValue on __InputValue{name description type{...TypeRef}defaultValue}fragment TypeRef on __Type{kind name ofType{kind name ofType{kind name ofType{kind name ofType{kind name ofType{kind name ofType{kind name ofType{kind name}}}}}}}}'
    
    if curl -sf -X POST "$GRAPHQL_ENDPOINT" \
        -H "Content-Type: application/json" \
        -H "X-Allow-Introspection: true" \
        --max-time 30 \
        -d "{\"query\":\"$INTROSPECTION_QUERY\"}" \
        -o "$SCHEMA_FILE.json" 2>/dev/null; then
        
        # Check if response is valid
        if command -v jq &> /dev/null && jq -e '.__schema.types' "$SCHEMA_FILE.json" >/dev/null 2>&1; then
            # Try to convert to SDL
            if command -v npx &> /dev/null; then
                if npx -y graphql-json-to-sdl "$SCHEMA_FILE.json" > "$SCHEMA_FILE" 2>/dev/null; then
                    rm -f "$SCHEMA_FILE.json"
                    log_success "Schema downloaded via introspection"
                    return 0
                fi
            fi
        fi
        rm -f "$SCHEMA_FILE.json"
    fi
    
    # Fallback: Use placeholder from assure-graphql-files
    log_warning "Could not download schema, using placeholder..."
    create_placeholders
    
    return 2
}

# Validate schema
validate_schema() {
    log_info "Validating schema..."
    
    if [ ! -f "$SCHEMA_FILE" ]; then
        log_error "Schema file not found"
        return 1
    fi
    
    local content=$(cat "$SCHEMA_FILE")
    local size=$(wc -c < "$SCHEMA_FILE")
    
    # Check for error messages
    if echo "$content" | grep -q "Missing required type"; then
        log_error "Schema contains error messages"
        return 1
    fi
    
    # Check for placeholder
    if echo "$content" | grep -q "_placeholder"; then
        log_warning "Schema is a placeholder ($size bytes)"
        return 2
    fi
    
    # Check for valid GraphQL
    if echo "$content" | grep -qE "(type Query|type Mutation)"; then
        local lines=$(wc -l < "$SCHEMA_FILE")
        log_success "Schema is valid ($lines lines, $size bytes)"
        return 0
    fi
    
    log_warning "Schema may be incomplete"
    return 2
}

# Run codegen
run_codegen() {
    log_info "Running GraphQL code generation..."
    
    # Use the TypeScript config file
    if npx @graphql-codegen/cli --config apollo/codegen.ts 2>&1 | tee /tmp/codegen.log; then
        log_success "Code generation completed"
        return 0
    else
        log_error "Code generation failed"
        cat /tmp/codegen.log 2>/dev/null || true
        return 1
    fi
}

# Check generated files
check_generated() {
    log_info "Checking generated files..."
    
    local all_ok=true
    local files=("graphql.ts" "index.ts" "gql.ts" "fragment-masking.ts" "fragments.ts" "introspection.json")
    
    for file in "${files[@]}"; do
        local filepath="$GENERATED_DIR/$file"
        if [ -f "$filepath" ]; then
            local size=$(wc -c < "$filepath")
            if [ $size -gt 500 ]; then
                log_success "$file ($size bytes)"
            else
                log_warning "$file (may be placeholder, $size bytes)"
            fi
        else
            log_error "$file (missing)"
            all_ok=false
        fi
    done
    
    if $all_ok; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    log_info "Starting GraphQL setup..."
    echo ""
    
    # Step 1: Create placeholders first (ensures app can start)
    create_placeholders || {
        log_error "Failed to create placeholders"
        exit 1
    }
    echo ""
    
    # Step 2: Wait for GraphQL
    if wait_for_graphql; then
        echo ""
        
        # Step 3: Download schema
        download_schema
        schema_status=$?
        echo ""
        
        # Step 4: Validate schema
        if [ $schema_status -eq 0 ]; then
            validate_schema
            validation_status=$?
            echo ""
            
            # Step 5: Run codegen if schema is good
            if [ $validation_status -eq 0 ]; then
                if run_codegen; then
                    echo ""
                    log_success "GraphQL client generated successfully"
                else
                    log_warning "Codegen failed, keeping placeholder files"
                    create_placeholders
                    echo ""
                fi
            else
                log_warning "Schema validation failed, keeping placeholders"
                echo ""
            fi
        else
            log_warning "Schema download failed, using placeholders"
            echo ""
        fi
    else
        log_warning "GraphQL endpoint not available, using placeholders"
        echo ""
    fi
    
    # Step 6: Check results
    check_generated
    echo ""
    
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          GraphQL Setup Complete                            ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_info "Application can now start with placeholder files"
    log_info "Real schema will be generated when backend is ready"
    log_info "To manually regenerate: npm run graphql:introspect"
    echo ""
}

# Run main function
main "$@"