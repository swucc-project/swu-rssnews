#!/bin/bash
set -e

echo "🔧 Generating GraphQL Fragments..."

# สร้าง directory ถ้ายังไม่มี
mkdir -p ./apollo/generated

# รอให้ backend พร้อม (ถ้าจำเป็น)
if [ -n "$WAIT_FOR_BACKEND" ]; then
    echo "⏳ Waiting for backend at $VITE_PUBLIC_GRAPHQL_ENDPOINT..."
    max_attempts=30
    attempt=0
    
    until curl -sf "$VITE_PUBLIC_GRAPHQL_ENDPOINT" > /dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            echo "❌ Backend not ready after $max_attempts attempts"
            echo "⚠️  Continuing with placeholder files..."
            break
        fi
        echo "   Attempt $attempt/$max_attempts..."
        sleep 2
    done
fi

# ลอง generate จาก backend
if curl -sf "$VITE_PUBLIC_GRAPHQL_ENDPOINT" > /dev/null 2>&1; then
    echo "✅ Backend is ready, fetching schema..."
    
    # ดึง schema
    npx rover graph introspect "$VITE_PUBLIC_GRAPHQL_ENDPOINT" > ./apollo/schema.graphql 2>/dev/null || {
        echo "⚠️  Failed to fetch schema with rover, trying curl..."
        curl -X POST "$VITE_PUBLIC_GRAPHQL_ENDPOINT" \
            -H "Content-Type: application/json" \
            -d '{"query":"{ __schema { types { name } } }"}' \
            -o /tmp/schema-check.json 2>/dev/null || true
    }
    
    # Generate fragments
    if [ -f "./apollo/schema.graphql" ]; then
        npx @graphql-codegen/cli --config codegen.yml || echo "⚠️  Codegen failed, using placeholders"
    fi
else
    echo "⚠️  Backend not available, using placeholder files"
fi

# สร้าง placeholder files ถ้ายังไม่มี
if [ ! -f "./apollo/generated/fragments.ts" ]; then
    echo "📝 Creating placeholder fragments.ts..."
    cat > ./apollo/generated/fragments.ts <<'EOF'
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
EOF
fi

if [ ! -f "./apollo/generated/introspection.json" ]; then
    echo "📝 Creating placeholder introspection.json..."
    echo '{"possibleTypes":{}}' > ./apollo/generated/introspection.json
fi

if [ ! -f "./apollo/generated/graphql.ts" ]; then
    echo "📝 Creating placeholder graphql.ts..."
    echo 'export const documents = {};' > ./apollo/generated/graphql.ts
fi

if [ ! -f "./apollo/generated/index.ts" ]; then
    echo "📝 Creating placeholder index.ts..."
    cat > ./apollo/generated/index.ts <<'EOF'
export type Maybe<T> = T | null;
export type Scalars = {
  ID: string;
  String: string;
  Boolean: boolean;
  Int: number;
  Float: number;
};
EOF
fi

echo "✅ Fragment generation complete!"
ls -la ./apollo/generated/