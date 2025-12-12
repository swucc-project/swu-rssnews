#!/bin/bash
# Exit on error but continue on warnings
set -e

GENERATED_DIR="./apollo/generated"

echo "📝 Ensuring GraphQL placeholder files exist..."

# Create directory
mkdir -p "$GENERATED_DIR"

# ========================================
# fragments.ts
# ========================================
if [ ! -f "$GENERATED_DIR/fragments.ts" ] || [ ! -s "$GENERATED_DIR/fragments.ts" ]; then
    cat > "$GENERATED_DIR/fragments.ts" <<'EOF'
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
    echo "  ✅ fragments.ts created"
fi

# ========================================
# graphql.ts
# ========================================
if [ ! -f "$GENERATED_DIR/graphql.ts" ] || [ ! -s "$GENERATED_DIR/graphql.ts" ]; then
    cat > "$GENERATED_DIR/graphql.ts" <<'EOF'
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
    echo "  ✅ graphql.ts created"
fi

chmod 644 "$GENERATED_DIR/graphql.ts"

# ========================================
# index.ts
# ========================================
if [ ! -f "$GENERATED_DIR/index.ts" ] || [ ! -s "$GENERATED_DIR/index.ts" ]; then
    cat > "$GENERATED_DIR/index.ts" <<'EOF'
/* eslint-disable */
export * from './graphql';
export * from './gql';
export * from './fragments';
export type { Maybe, Exact, Scalars } from './graphql';
EOF
    echo "  ✅ index.ts created"
fi

chmod 644 "$GENERATED_DIR/index.ts"

# ========================================
# gql.ts
# ========================================
if [ ! -f "$GENERATED_DIR/gql.ts" ] || [ ! -s "$GENERATED_DIR/gql.ts" ]; then
    cat > "$GENERATED_DIR/gql.ts" <<'EOF'
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
    echo "  ✅ gql.ts created"
fi

chmod 644 "$GENERATED_DIR/gql.ts"

# ========================================
# fragment-masking.ts
# ========================================
if [ ! -f "$GENERATED_DIR/fragment-masking.ts" ] || [ ! -s "$GENERATED_DIR/fragment-masking.ts" ]; then
    cat > "$GENERATED_DIR/fragment-masking.ts" <<'EOF'
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
    echo "  ✅ fragment-masking.ts created"
fi

chmod 644 "$GENERATED_DIR/fragment-masking.ts"

# ========================================
# introspection.json
# ========================================
if [ ! -f "$GENERATED_DIR/introspection.json" ] || [ ! -s "$GENERATED_DIR/introspection.json" ]; then
    echo '{"possibleTypes":{}}' > "$GENERATED_DIR/introspection.json"
    echo "  ✅ introspection.json created"
fi

chmod 644 "$GENERATED_DIR/introspection.json"

echo "✅ All placeholder files ensured!"
exit 0