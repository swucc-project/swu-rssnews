# assure-graphql-files.ps1
# Ensure GraphQL placeholder files exist (Windows PowerShell version)

$ErrorActionPreference = "Stop"

# Colors
$GREEN = "`e[32m"
$CYAN = "`e[36m"
$NC = "`e[0m"

Write-Host "${CYAN}🔍 Ensuring GraphQL placeholder files exist...${NC}"

# ✅ Detect correct directory
$GENERATED_DIR = if (Test-Path ".\apollo") {
    ".\apollo\generated"
}
elseif (Test-Path ".\vite-ui\apollo") {
    ".\vite-ui\apollo\generated"
}
else {
    ".\grpc-generated"
}

Write-Host "${CYAN}📂 Target directory: $GENERATED_DIR${NC}"

# Create directory
if (-not (Test-Path $GENERATED_DIR)) {
    New-Item -Path $GENERATED_DIR -ItemType Directory -Force | Out-Null
}

# ========================================
# Helper function
# ========================================
function New-PlaceholderFile {
    param(
        [string]$Path,
        [string]$Content
    )
    
    $filename = Split-Path $Path -Leaf
    
    if (-not (Test-Path $Path) -or (Get-Item $Path).Length -eq 0) {
        Set-Content -Path $Path -Value $Content -NoNewline -Encoding UTF8
        Write-Host "  ${GREEN}✅ $filename created${NC}"
    }
    else {
        Write-Host "  ✓ $filename already exists"
    }
}

# ========================================
# Create files
# ========================================

# fragments.ts
$fragmentsContent = @'
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
'@

New-PlaceholderFile -Path "$GENERATED_DIR\fragments.ts" -Content $fragmentsContent

# graphql.ts
$graphqlContent = @'
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
'@

New-PlaceholderFile -Path "$GENERATED_DIR\graphql.ts" -Content $graphqlContent

# index.ts
$indexContent = @'
/* eslint-disable */
export * from './graphql';
export * from './gql';
export * from './fragments';
export type { Maybe, Exact, Scalars } from './graphql';
'@

New-PlaceholderFile -Path "$GENERATED_DIR\index.ts" -Content $indexContent

# gql.ts
$gqlContent = @'
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
'@

New-PlaceholderFile -Path "$GENERATED_DIR\gql.ts" -Content $gqlContent

# fragment-masking.ts
$fragmentMaskingContent = @'
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
'@

New-PlaceholderFile -Path "$GENERATED_DIR\fragment-masking.ts" -Content $fragmentMaskingContent

# introspection.json
$introspectionContent = '{"possibleTypes":{}}'
New-PlaceholderFile -Path "$GENERATED_DIR\introspection.json" -Content $introspectionContent

Write-Host ""
Write-Host "${GREEN}✅ All placeholder files ensured!${NC}"
Write-Host "${CYAN}📂 Location: $GENERATED_DIR${NC}"

Get-ChildItem $GENERATED_DIR | Format-Table Name, Length, LastWriteTime -AutoSize

exit 0