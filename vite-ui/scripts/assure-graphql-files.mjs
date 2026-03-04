#!/usr/bin/env node

/**
 * ═══════════════════════════════════════════════════════════
 * 🔧 GraphQL Files Assurance Script - v4.1.1
 * ═══════════════════════════════════════════════════════════
 * Purpose: Ensure all required GraphQL files exist with valid content
 *
 * Changelog v4.1.1:
 *   [BUG FIX #1] Template literal escape ผิด: `\${size}` → `${size}`
 *                ทำให้ error message แสดงข้อความ "${size} bytes" แทนที่จะเป็นตัวเลขจริง
 *   [BUG FIX #2] Timestamp ใน GRAPHQL_TS และ VALID_PLACEHOLDER_SCHEMA
 *                ทำให้ content เปลี่ยนทุกครั้งที่ script รัน → always-dirty → codegen loop
 *                แก้โดยเอา new Date().toISOString() ออกจาก file content constants
 *   [BUG FIX #3] Placeholder schema update logic วนซ้ำโดยไม่จำเป็น
 *                เมื่อ schema เป็น placeholder จะพยายาม overwrite ด้วย VALID_PLACEHOLDER_SCHEMA
 *                ที่มี timestamp เปลี่ยน → เขียนซ้ำทุกครั้ง
 *                แก้โดยเอา timestamp ออกจาก VALID_PLACEHOLDER_SCHEMA ด้วย
 * ═══════════════════════════════════════════════════════════
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import crypto from 'crypto';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ═══════════════════════════════════════════════════════════
// Configuration
// ═══════════════════════════════════════════════════════════

const SCHEMA_FILE = path.join(__dirname, '../apollo/schema.graphql');
const GENERATED_DIR = path.join(__dirname, '../apollo/generated');

const COLORS = {
  GREEN: '\x1b[32m',
  YELLOW: '\x1b[33m',
  RED: '\x1b[31m',
  BLUE: '\x1b[34m',
  CYAN: '\x1b[36m',
  RESET: '\x1b[0m',
  BOLD: '\x1b[1m'
};

// ═══════════════════════════════════════════════════════════
// Logging Helpers
// ═══════════════════════════════════════════════════════════

function logSuccess(msg) { console.log(`${COLORS.GREEN}✅ ${msg}${COLORS.RESET}`); }
function logWarning(msg) { console.log(`${COLORS.YELLOW}⚠️  ${msg}${COLORS.RESET}`); }
function logError(msg) { console.log(`${COLORS.RED}❌ ${msg}${COLORS.RESET}`); }
function logInfo(msg) { console.log(`${COLORS.CYAN}ℹ️  ${msg}${COLORS.RESET}`); }
function logHeader(msg) { console.log(`\n${COLORS.BLUE}${COLORS.BOLD}${msg}${COLORS.RESET}`); }

// ═══════════════════════════════════════════════════════════
// Valid Placeholder Schema
// ═══════════════════════════════════════════════════════════

// [BUG FIX #2, #3] ลบ new Date().toISOString() ออกจาก content
// เดิม: `# Generated: ${new Date().toISOString()}` ทำให้ content เปลี่ยนทุก run
// แก้เป็น comment แบบ static เพื่อให้ content stable ไม่ trigger unnecessary write
const VALID_PLACEHOLDER_SCHEMA = `# ═══════════════════════════════════════════════════════════
# GraphQL Schema - RSS News Project
# AUTO-GENERATED PLACEHOLDER - will be replaced on backend startup
# ═══════════════════════════════════════════════════════════

scalar DateTime

schema {
  query: Query
  mutation: Mutation
  subscription: Subscription
}

type Query {
  """
  Get all RSS items (List mode, not Connection)
  """
  rssItems: [Item!]!

  """
  Get single RSS item by ID
  """
  rssItem(id: String!): Item

  """
  Get all categories
  """
  categories: [Category!]!

  """
  Get all authors
  """
  authors: [Author!]!
}

type Mutation {
  """
  Add a new RSS item
  """
  addItem(input: AddItemInput!): Item!

  """
  Update an existing RSS item
  """
  updateItem(id: String!, input: UpdateItemInput!): Item!

  """
  Delete an RSS item
  """
  deleteRssItem(id: String!): String
}

type Subscription {
  """
  Triggered when an item is added
  """
  onItemAdded: Item!

  """
  Triggered when an item is updated
  """
  onItemUpdated: Item!

  """
  Triggered when an item is deleted (returns ID)
  """
  onItemDeleted: String!
}

"""
Represents a News/RSS Item
"""
type Item {
  itemID: String!
  title: String!
  link: String!
  description: String
  publishedDate: DateTime
  category: Category
  author: Author
  authorID: String
  categoryID: Int
}

"""
Represents a Category
"""
type Category {
  categoryID: Int!
  categoryName: String!
}

"""
Represents an Author
"""
type Author {
  buasriID: String!
  firstName: String
  lastName: String
}

"""
Input for adding an item
"""
input AddItemInput {
  title: String!
  link: String!
  description: String
  publishedDate: DateTime
  categoryId: Int
  authorId: String
}

"""
Input for updating an item
"""
input UpdateItemInput {
  title: String
  link: String
  description: String
  publishedDate: DateTime
  categoryId: Int
  authorId: String
}
`;

// ═══════════════════════════════════════════════════════════
// Generated Files Content
// ═══════════════════════════════════════════════════════════

// [BUG FIX #2] ลบ new Date().toISOString() ออกจาก GRAPHQL_TS และทุก file content
// เดิม: `* Generated: ${new Date().toISOString()}` — timestamp เปลี่ยนทุกครั้ง
// ทำให้ writeFileIfNeeded เปรียบเทียบ existing vs content แล้วพบว่า "ต่างกัน" เสมอ
// → เขียนไฟล์ทุกครั้ง → graphql-codegen คิดว่า schema เปลี่ยน → regenerate loop ไม่จบ
// แก้เป็น @generated tag แบบ static
const GRAPHQL_TS = `/* eslint-disable */
/**
 * Auto-generated GraphQL Types - RSS News Project
 * @generated by assure-graphql-files.mjs
 * Do not edit manually - will be overwritten by graphql-codegen
 */

export type Maybe<T> = T | null;
export type InputMaybe<T> = T | null | undefined;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };

export type Scalars = {
  ID: { input: string; output: string };
  String: { input: string; output: string };
  Boolean: { input: boolean; output: boolean };
  Int: { input: number; output: number };
  Float: { input: number; output: number };
  DateTime: { input: string; output: string };
};

export type Item = {
  __typename?: 'Item';
  itemID: Scalars['String']['output'];
  title: Scalars['String']['output'];
  link: Scalars['String']['output'];
  description?: Maybe<Scalars['String']['output']>;
  publishedDate?: Maybe<Scalars['DateTime']['output']>;
  category?: Maybe<Category>;
  author?: Maybe<Author>;
  authorID?: Maybe<Scalars['String']['output']>;
  categoryID?: Maybe<Scalars['Int']['output']>;
};

export type Category = {
  __typename?: 'Category';
  categoryID: Scalars['Int']['output'];
  categoryName: Scalars['String']['output'];
};

export type Author = {
  __typename?: 'Author';
  buasriID: Scalars['String']['output'];
  firstName?: Maybe<Scalars['String']['output']>;
  lastName?: Maybe<Scalars['String']['output']>;
};

export type AddItemInput = {
  title: Scalars['String']['input'];
  link: Scalars['String']['input'];
  description?: InputMaybe<Scalars['String']['input']>;
  publishedDate?: InputMaybe<Scalars['DateTime']['input']>;
  categoryId?: InputMaybe<Scalars['Int']['input']>;
  authorId?: InputMaybe<Scalars['String']['input']>;
};

export type UpdateItemInput = {
  title?: InputMaybe<Scalars['String']['input']>;
  link?: InputMaybe<Scalars['String']['input']>;
  description?: InputMaybe<Scalars['String']['input']>;
  publishedDate?: InputMaybe<Scalars['DateTime']['input']>;
  categoryId?: InputMaybe<Scalars['Int']['input']>;
  authorId?: InputMaybe<Scalars['String']['input']>;
};

export type Query = {
  __typename?: 'Query';
  rssItems: Array<Item>;
  rssItem?: Maybe<Item>;
  categories: Array<Category>;
  authors: Array<Author>;
};

export type Mutation = {
  __typename?: 'Mutation';
  addItem: Item;
  updateItem: Item;
  deleteRssItem?: Maybe<Scalars['String']['output']>;
};

export type Subscription = {
  __typename?: 'Subscription';
  onItemAdded: Item;
  onItemUpdated: Item;
  onItemDeleted: Scalars['String']['output'];
};
`;

const INDEX_TS = `/* eslint-disable */
export * from './graphql';
export { graphql } from './gql';
export { getFragmentData } from './fragment-masking';
`;

const GQL_TS = `/* eslint-disable */
import type { DocumentNode } from 'graphql';

/**
 * graphql-codegen compatible graphql() helper
 * @generated by assure-graphql-files.mjs
 */
export function graphql(
  source: string | TemplateStringsArray,
  ...args: any[]
): DocumentNode {
  const documentSource =
    typeof source === 'string'
      ? source
      : source.reduce((acc, str, i) => acc + str + (args[i] || ''), '');

  return {
    kind: 'Document',
    definitions: [],
    loc: { start: 0, end: documentSource.length },
  } as unknown as DocumentNode;
}

export default graphql;
`;

const FRAGMENT_MASKING_TS = `/* eslint-disable */
import type { DocumentNode } from 'graphql';

export type FragmentType<TDocumentType extends DocumentNode<any, any>> = 
  TDocumentType extends DocumentNode<infer TType, any> 
    ? TType extends { ' $fragmentName'?: infer TKey }
      ? TKey extends string
        ? { ' $fragmentRefs'?: { [key in TKey]: TType } }
        : never
      : never
    : never;

export function getFragmentData<TType>(
  _documentNode: DocumentNode<TType, any>,
  fragmentType: FragmentType<DocumentNode<TType, any>> | ReadonlyArray<FragmentType<DocumentNode<TType, any>>> | null | undefined
): TType | ReadonlyArray<TType> | null | undefined {
  return fragmentType as any;
}
`;

const FRAGMENTS_TS = `/* eslint-disable */
// Fragment definitions placeholder
export {};
`;

const INTROSPECTION_JSON = `{
  "__schema": {
    "queryType": { "name": "Query" },
    "mutationType": { "name": "Mutation" },
    "subscriptionType": { "name": "Subscription" },
    "types": [],
    "directives": []
  }
}`;

// ═══════════════════════════════════════════════════════════
// File Management Functions
// ═══════════════════════════════════════════════════════════

function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
    logInfo(`Created directory: ${path.relative(process.cwd(), dirPath)}`);
  }
}

function getFileHash(content) {
  return crypto.createHash('md5').update(content).digest('hex').substring(0, 12);
}

function validateSchemaFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return { valid: false, reason: 'File does not exist', isPlaceholder: false, size: 0 };
  }

  const content = fs.readFileSync(filePath, 'utf8');
  const size = content.length;

  if (size < 100) {
    // [BUG FIX #1] เดิม: `Too small (\${size} bytes)` — backslash escape ทำให้ interpolation ถูก suppress
    // ผลลัพธ์ที่ได้คือ string "${size} bytes" ตัวอักษร ไม่ใช่ตัวเลขจริง
    // แก้เป็น: `Too small (${size} bytes)` — interpolation ปกติ
    return {
      valid: false, reason: `Too small (${size} bytes)`, isPlaceholder: false, size
    };
  }

  if (!content.includes('type Query')) {
    return { valid: false, reason: 'Missing type Query', isPlaceholder: false, size };
  }

  const isPlaceholder = content.includes('AUTO-GENERATED PLACEHOLDER') || content.includes('RSS News Project');

  return { valid: true, reason: 'Valid', isPlaceholder, size };
}

function writeFileIfNeeded(filePath, content, description) {
  const relativePath = path.relative(process.cwd(), filePath);

  if (fs.existsSync(filePath)) {
    const existing = fs.readFileSync(filePath, 'utf8');

    // Don't overwrite real schema if it looks like a full export from backend
    if (description === 'Schema' &&
      existing.includes('type Item') &&
      !existing.includes('AUTO-GENERATED PLACEHOLDER') &&
      !existing.includes('RSS News Project')) {
      logInfo(`Keeping real schema: ${relativePath}`);
      return false;
    }

    if (existing.trim() === content.trim()) {
      // [BUG FIX #2] ด้วย content ที่ stable (ไม่มี timestamp) การเปรียบเทียบนี้จะ work ถูกต้อง
      // เมื่อ content เหมือนกัน ไม่ต้องเขียนใหม่ → ป้องกัน codegen loop
      return false;
    }
  }

  fs.writeFileSync(filePath, content, 'utf8');
  logSuccess(`Created: ${relativePath} (${content.length} bytes, hash: ${getFileHash(content)})`);
  return true;
}

// ═══════════════════════════════════════════════════════════
// Main Function
// ═══════════════════════════════════════════════════════════

function main() {
  logHeader('🔧 GraphQL Files Assurance Script v4.1.1');
  console.log('');

  let filesCreated = 0;
  let filesSkipped = 0;

  // Step 1: Ensure directories
  logInfo('Step 1: Ensuring directories...');
  ensureDir(path.dirname(SCHEMA_FILE));
  ensureDir(GENERATED_DIR);
  console.log('');

  // Step 2: Validate schema
  logInfo('Step 2: Checking schema file...');
  const validation = validateSchemaFile(SCHEMA_FILE);

  if (!validation.valid) {
    logWarning(`Schema issue: ${validation.reason}`);
    logInfo('Creating valid placeholder schema...');
    if (writeFileIfNeeded(SCHEMA_FILE, VALID_PLACEHOLDER_SCHEMA, 'Schema')) {
      filesCreated++;
    } else {
      filesSkipped++;
    }
  } else {
    if (validation.isPlaceholder) {
      // [BUG FIX #3] เดิม: พยายาม overwrite placeholder ทุกครั้งโดยไม่จำเป็น
      // เพราะ VALID_PLACEHOLDER_SCHEMA เดิมมี timestamp ทำให้ content ต่างกันเสมอ
      // ตอนนี้ VALID_PLACEHOLDER_SCHEMA เป็น static content แล้ว
      // writeFileIfNeeded จะ skip ถ้า content เหมือนกัน
      logInfo(`Schema is placeholder (${validation.size} bytes) — checking if update needed...`);
      if (writeFileIfNeeded(SCHEMA_FILE, VALID_PLACEHOLDER_SCHEMA, 'Schema')) {
        filesCreated++;
      } else {
        logInfo('Placeholder schema is up-to-date, skipping.');
        filesSkipped++;
      }
    } else {
      logSuccess(`Real schema found (${validation.size} bytes) — keeping as-is`);
      filesSkipped++;
    }
  }
  console.log('');

  // Step 3: Create generated files
  logInfo('Step 3: Creating generated files...');

  const files = [
    { path: path.join(GENERATED_DIR, 'graphql.ts'), content: GRAPHQL_TS },
    { path: path.join(GENERATED_DIR, 'index.ts'), content: INDEX_TS },
    { path: path.join(GENERATED_DIR, 'gql.ts'), content: GQL_TS },
    { path: path.join(GENERATED_DIR, 'fragment-masking.ts'), content: FRAGMENT_MASKING_TS },
    { path: path.join(GENERATED_DIR, 'fragments.ts'), content: FRAGMENTS_TS },
    { path: path.join(GENERATED_DIR, 'introspection.json'), content: INTROSPECTION_JSON }
  ];

  for (const file of files) {
    if (writeFileIfNeeded(file.path, file.content, path.basename(file.path))) {
      filesCreated++;
    } else {
      filesSkipped++;
    }
  }
  console.log('');

  // Step 4: Summary
  logHeader('📊 Summary');
  logInfo(`Files created/updated : ${filesCreated}`);
  logInfo(`Files skipped (no-op) : ${filesSkipped}`);
  console.log('');
  logSuccess('GraphQL files assurance complete!');
  console.log('');
}

// ═══════════════════════════════════════════════════════════
// Execute
// ═══════════════════════════════════════════════════════════

try {
  main();
  process.exit(0);
} catch (error) {
  console.error(`${COLORS.RED}❌ Fatal error: ${error.message}${COLORS.RESET}`);
  console.error(error);
  process.exit(1);
}
