#!/bin/bash
set -e

SCHEMA_FILE="./apollo/schema.graphql"
PLACEHOLDER_SCHEMA="./apollo/schema.placeholder.graphql"
ENDPOINT="${GRAPHQL_ENDPOINT:-http://aspdotnetweb:5000/graphql}"
MAX_RETRIES=3
RETRY_DELAY=3

echo "📥 Downloading GraphQL schema from: $ENDPOINT"

# Function to test endpoint
test_endpoint() {
    curl -sf -X POST "$ENDPOINT" \
        -H "Content-Type: application/json" \
        -H "X-Allow-Introspection: true" \
        --max-time 10 \
        -d '{"query":"query{__schema{queryType{name}}}"}' \
        >/dev/null 2>&1
}

# ✅ Wait for endpoint - reduced retries
echo "⏳ Waiting for GraphQL endpoint..."
retry=0
while [ $retry -lt $MAX_RETRIES ]; do
    if test_endpoint; then
        echo "✅ Endpoint is ready"
        break
    fi
    
    retry=$((retry + 1))
    if [ $retry -lt $MAX_RETRIES ]; then
        echo "⏳ Attempt $retry/$MAX_RETRIES failed, retrying in ${RETRY_DELAY}s..."
        sleep $RETRY_DELAY
    fi
done

if [ $retry -eq $MAX_RETRIES ]; then
    echo "⚠️  Could not connect to GraphQL endpoint"
    echo "📝 Using placeholder schema"
    cp "$PLACEHOLDER_SCHEMA" "$SCHEMA_FILE" 2>/dev/null || true
    exit 0
fi

# ✅ Method 1: Direct introspection query (fastest)
echo "🔧 Method 1: Using direct introspection query..."

INTROSPECTION_QUERY='query IntrospectionQuery{__schema{queryType{name}mutationType{name}subscriptionType{name}types{kind name description fields(includeDeprecated:true){name description args{name description type{...TypeRef}defaultValue}type{...TypeRef}isDeprecated deprecationReason}inputFields{name description type{...TypeRef}defaultValue}interfaces{...TypeRef}enumValues(includeDeprecated:true){name description isDeprecated deprecationReason}possibleTypes{...TypeRef}}directives{name description locations args{name description type{...TypeRef}defaultValue}}}}fragment TypeRef on __Type{kind name ofType{kind name ofType{kind name ofType{kind name ofType{kind name ofType{kind name ofType{kind name ofType{kind name}}}}}}}}'

if timeout 30s curl -sf -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "X-Allow-Introspection: true" \
    --max-time 25 \
    -d "$INTROSPECTION_QUERY" \
    -o "$SCHEMA_FILE.json" 2>/dev/null; then
    
    echo "✅ Introspection query successful"
    
    # ✅ ตรวจสอบว่าได้ข้อมูลจริง
    if grep -q '"__schema"' "$SCHEMA_FILE.json" 2>/dev/null && \
       ! grep -q '"errors"' "$SCHEMA_FILE.json" 2>/dev/null; then
        
        # Try converting to SDL with npx
        echo "🔄 Converting JSON to SDL..."
        
        # ✅ Method A: Use graphql-json-to-sdl
        if command -v npx >/dev/null 2>&1; then
            if timeout 20s npx -y graphql-json-to-sdl "$SCHEMA_FILE.json" \
                > "$SCHEMA_FILE.tmp" 2>/dev/null; then
                
                # Validate output
                if [ -s "$SCHEMA_FILE.tmp" ] && grep -q "type Query" "$SCHEMA_FILE.tmp" 2>/dev/null; then
                    mv "$SCHEMA_FILE.tmp" "$SCHEMA_FILE"
                    rm -f "$SCHEMA_FILE.json"
                    echo "✅ Schema converted to SDL"
                    exit 0
                fi
                rm -f "$SCHEMA_FILE.tmp"
            fi
        fi
        
        # ✅ Fallback: Keep JSON format (codegen can handle it)
        echo "📝 Keeping JSON format (codegen compatible)"
        mv "$SCHEMA_FILE.json" "$SCHEMA_FILE"
        exit 0
    else
        echo "⚠️  Invalid introspection response"
        rm -f "$SCHEMA_FILE.json"
    fi
fi

# ✅ Method 2: Using Apollo Rover (if available)
echo "🔧 Method 2: Using Apollo Rover..."
if command -v rover >/dev/null 2>&1; then
    if timeout 30s rover graph introspect "$ENDPOINT" \
        --header "X-Allow-Introspection:true" \
        > "$SCHEMA_FILE.tmp" 2>/dev/null; then
        
        if [ -s "$SCHEMA_FILE.tmp" ] && grep -q "type Query" "$SCHEMA_FILE.tmp" 2>/dev/null; then
            mv "$SCHEMA_FILE.tmp" "$SCHEMA_FILE"
            echo "✅ Schema downloaded via Rover"
            exit 0
        fi
        rm -f "$SCHEMA_FILE.tmp"
    fi
    echo "⚠️  Rover failed or timeout"
fi

# ✅ Method 3: Using graphql-cli (if available)
echo "🔧 Method 3: Using graphql-cli..."
if command -v graphql >/dev/null 2>&1; then
    if timeout 30s graphql get-schema \
        --endpoint "$ENDPOINT" \
        --header "X-Allow-Introspection=true" \
        > "$SCHEMA_FILE.tmp" 2>/dev/null; then
        
        if [ -s "$SCHEMA_FILE.tmp" ] && \
           grep -q "type Query" "$SCHEMA_FILE.tmp" 2>/dev/null && \
           ! grep -q "_placeholder" "$SCHEMA_FILE.tmp" 2>/dev/null; then
            mv "$SCHEMA_FILE.tmp" "$SCHEMA_FILE"
            echo "✅ Schema downloaded via graphql-cli"
            exit 0
        fi
        rm -f "$SCHEMA_FILE.tmp"
    fi
    echo "⚠️  graphql-cli failed or timeout"
fi

# Ultimate fallback
echo "⚠️  All methods failed, using placeholder schema"
if [ -f "$PLACEHOLDER_SCHEMA" ]; then
    cp "$PLACEHOLDER_SCHEMA" "$SCHEMA_FILE"
else
    # Create minimal placeholder
    cat > "$SCHEMA_FILE" <<'EOF'
type Query {
  _placeholder: String @deprecated(reason: "Backend not ready")
}

type Mutation {
  _placeholder: String @deprecated(reason: "Backend not ready")
}

schema {
  query: Query
  mutation: Mutation
}
EOF
fi

echo "📝 Placeholder schema created"
exit 0