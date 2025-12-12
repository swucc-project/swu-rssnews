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
MAX_RETRIES="${MAX_RETRIES:-30}"
RETRY_DELAY="${RETRY_DELAY:-5}"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          GraphQL Setup Script                              ║${NC}"
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

# สร้าง placeholder fragments
create_placeholders() {
    log_info "Creating placeholder files..."
    
    mkdir -p "$GENERATED_DIR"
    
    # ✅ fragments.ts with types
    cat > "$GENERATED_DIR/fragments.ts" << 'EOF'
import gql from 'graphql-tag';

export const RSS_ITEM_FIELDS = gql`
  fragment RssItemFields on RssItem {
    itemID
    title
    link
    description
    publishedDate
    category {
      categoryID
      categoryName
    }
    author {
      buasriID
      firstName
      lastName
    }
  }
`;

export const CATEGORY_FIELDS = gql`
  fragment CategoryFields on Category {
    categoryID
    categoryName
  }
`;

export const AUTHOR_FIELDS = gql`
  fragment AuthorFields on Author {
    buasriID
    firstName
    lastName
  }
`;

export type RssItemFieldsFragment = {
  itemID: string;
  title: string;
  link: string;
  description?: string | null;
  publishedDate: string;
  category?: { categoryID: number; categoryName: string } | null;
  author?: { buasriID: string; firstName: string; lastName: string } | null;
};

export type CategoryFieldsFragment = {
  categoryID: number;
  categoryName: string;
};

export type AuthorFieldsFragment = {
  buasriID: string;
  firstName: string;
  lastName: string;
};
EOF
    
    # graphql.ts
    cat > "$GENERATED_DIR/graphql.ts" << 'EOF'
/* eslint-disable */
// Auto-generated placeholder
export type Maybe<T> = T | null;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };

export type Scalars = {
  ID: string;
  String: string;
  Boolean: boolean;
  Int: number;
  Float: number;
  DateTime: string;
  Date: string;
  Decimal: number;
  Long: number;
  UUID: string;
};

export const documents = {};
EOF

    # index.ts
    cat > "$GENERATED_DIR/index.ts" << 'EOF'
/* eslint-disable */
export * from './graphql';
export * from './gql';
export * from './fragments';
export type { Maybe, Exact, Scalars } from './graphql';
EOF

    # gql.ts  
    cat > "$GENERATED_DIR/gql.ts" << 'EOF'
/* eslint-disable */
import { TypedDocumentNode as DocumentNode } from '@graphql-typed-document-node/core';

export type DocumentType<TDocumentNode extends DocumentNode<any, any>> = 
  TDocumentNode extends DocumentNode<infer TType, any> ? TType : never;

export function gql(source: string): unknown;
export function gql(source: TemplateStringsArray, ...args: any[]): unknown;
export function gql(source: string | TemplateStringsArray, ...args: any[]): unknown {
  const documentSource = typeof source === 'string' 
    ? source 
    : source.reduce((acc, str, i) => acc + str + (args[i] || ''), '');
  
  return {
    kind: 'Document',
    definitions: [],
    loc: { start: 0, end: documentSource.length },
    __meta__: { hash: 'placeholder' }
  } as any;
}

export default gql;
EOF

    # fragment-masking.ts
    cat > "$GENERATED_DIR/fragment-masking.ts" << 'EOF'
/* eslint-disable */
import { DocumentNode } from 'graphql';

export type FragmentType<TDocumentType extends DocumentNode<any, any>> = 
  TDocumentType extends DocumentNode<infer TType, any>
    ? TType extends { ' $fragmentName'?: infer TKey }
      ? TKey extends string
        ? { ' $fragmentRefs'?: { [key in TKey]: TType } }
        : never
      : never
    : never;

export function useFragment<TType>(
  _documentNode: DocumentNode<TType, any>,
  fragmentType: FragmentType<DocumentNode<TType, any>>
): TType;

export function useFragment<TType>(
  _documentNode: DocumentNode<TType, any>,
  fragmentType: FragmentType<DocumentNode<TType, any>> | null | undefined
): TType | null | undefined;

export function useFragment<TType>(
  _documentNode: DocumentNode<TType, any>,
  fragmentType: ReadonlyArray<FragmentType<DocumentNode<TType, any>>>
): ReadonlyArray<TType>;

export function useFragment<TType>(
  _documentNode: DocumentNode<TType, any>,
  fragmentType: ReadonlyArray<FragmentType<DocumentNode<TType, any>>> | null | undefined
): ReadonlyArray<TType> | null | undefined;

export function useFragment<TType>(
  _documentNode: DocumentNode<TType, any>,
  fragmentType: FragmentType<DocumentNode<TType, any>> | ReadonlyArray<FragmentType<DocumentNode<TType, any>>> | null | undefined
): TType | ReadonlyArray<TType> | null | undefined {
  return fragmentType as any;
}

export function makeFragmentData<TType, TDocumentType extends DocumentNode<TType, any>>(
  data: TType,
  _documentNode: TDocumentType
): FragmentType<TDocumentType> {
  return data as FragmentType<TDocumentType>;
}
EOF

    # introspection.json
    echo '{"possibleTypes":{}}' > "$GENERATED_DIR/introspection.json"
    
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

# Download schema - ✅ แก้ไขให้ทำงานได้จริง
download_schema() {
    log_info "Downloading GraphQL schema..."
    
    # ✅ ลองใช้ Apollo Rover ก่อน (ถ้ามี)
    if command -v rover &> /dev/null; then
        log_info "Trying with Apollo Rover..."
        
        # ✅ ใช้ direct endpoint URL
        if rover graph introspect "$GRAPHQL_ENDPOINT" \
            --header "X-Allow-Introspection:true" \
            > "$SCHEMA_FILE.tmp" 2>/dev/null; then
            
            # Validate schema
            if grep -q "type Query" "$SCHEMA_FILE.tmp" && \
               ! grep -q "error" "$SCHEMA_FILE.tmp" && \
               ! grep -q "_placeholder" "$SCHEMA_FILE.tmp"; then
                mv "$SCHEMA_FILE.tmp" "$SCHEMA_FILE"
                log_success "Schema downloaded via Rover"
                return 0
            fi
        fi
        rm -f "$SCHEMA_FILE.tmp"
    fi
    
    # ✅ Fallback: ใช้ graphql-codegen CLI
    log_info "Trying with graphql-codegen..."
    
    if npx -y get-graphql-schema "$GRAPHQL_ENDPOINT" \
        --header "X-Allow-Introspection=true" \
        > "$SCHEMA_FILE.tmp" 2>/dev/null; then
        
        if grep -q "type Query" "$SCHEMA_FILE.tmp"; then
            mv "$SCHEMA_FILE.tmp" "$SCHEMA_FILE"
            log_success "Schema downloaded via graphql-codegen"
            return 0
        fi
    fi
    rm -f "$SCHEMA_FILE.tmp"
    
    # ✅ Last resort: Introspection query
    log_info "Trying introspection query..."
    
    INTROSPECTION_QUERY='{"query":"query IntrospectionQuery { __schema { queryType { name } mutationType { name } types { kind name description fields(includeDeprecated: true) { name description args { name description type { ...TypeRef } defaultValue } type { ...TypeRef } isDeprecated deprecationReason } inputFields { ...InputValue } interfaces { ...TypeRef } enumValues(includeDeprecated: true) { name description isDeprecated deprecationReason } possibleTypes { ...TypeRef } } directives { name description locations args { ...InputValue } } } } fragment FullType on __Type { kind name description fields(includeDeprecated: true) { name description args { ...InputValue } type { ...TypeRef } isDeprecated deprecationReason } inputFields { ...InputValue } interfaces { ...TypeRef } enumValues(includeDeprecated: true) { name description isDeprecated deprecationReason } possibleTypes { ...TypeRef } } fragment InputValue on __InputValue { name description type { ...TypeRef } defaultValue } fragment TypeRef on __Type { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name } } } } } } } }"}'
    
    if curl -sf -X POST "$GRAPHQL_ENDPOINT" \
        -H "Content-Type: application/json" \
        -H "X-Allow-Introspection: true" \
        -d "$INTROSPECTION_QUERY" \
        -o "$SCHEMA_FILE.json" 2>/dev/null; then
        
        # Convert to SDL
        if npx -y graphql-json-to-sdl "$SCHEMA_FILE.json" > "$SCHEMA_FILE" 2>/dev/null; then
            rm -f "$SCHEMA_FILE.json"
            log_success "Schema downloaded via introspection"
            return 0
        fi
        rm -f "$SCHEMA_FILE.json"
    fi
    
    # Create minimal placeholder
    log_warning "Creating placeholder schema..."
    cat > "$SCHEMA_FILE" << 'EOF'
type Query {
  _placeholder: String
}
type Mutation {
  _placeholder: String
}
schema {
  query: Query
  mutation: Mutation
}
EOF
    
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
    
    if echo "$content" | grep -q "_placeholder"; then
        log_warning "Schema is a placeholder"
        return 2
    fi
    
    if echo "$content" | grep -qE "(type Query|type Mutation)"; then
        local lines=$(wc -l < "$SCHEMA_FILE")
        log_success "Schema is valid ($lines lines)"
        return 0
    fi
    
    log_warning "Schema may be incomplete"
    return 2
}

# Run codegen
run_codegen() {
    log_info "Running GraphQL code generation..."
    
    # ✅ ใช้ --config เพื่อระบุ config file
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
    local files=("graphql.ts" "index.ts" "gql.ts" "fragment-masking.ts" "fragments.ts")
    
    for file in "${files[@]}"; do
        local filepath="$GENERATED_DIR/$file"
        if [ -f "$filepath" ]; then
            local size=$(wc -c < "$filepath")
            if [ $size -gt 100 ]; then
                log_success "$file ($size bytes)"
            else
                log_warning "$file (placeholder, $size bytes)"
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
    
    # Step 1: Create placeholders
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
            echo ""
            
            # Step 5: Run codegen
            if run_codegen; then
                echo ""
                log_success "GraphQL client generated successfully"
            else
                log_warning "Using placeholder files"
                create_placeholders
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
    log_info "If you encounter issues, run: make graphql-fix"
    echo ""
}

# Run main function
main "$@"