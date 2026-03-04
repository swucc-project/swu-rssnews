/* eslint-disable */
/**
 * ═══════════════════════════════════════════════════════════
 * gql Tag Function - Placeholder
 * ═══════════════════════════════════════════════════════════
 */

import { TypedDocumentNode as DocumentNode } from '@graphql-typed-document-node/core';

export type DocumentType<TDocumentNode extends DocumentNode<any, any>> = 
  TDocumentNode extends DocumentNode<infer TType, any> ? TType : never;

/**
 * The gql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function gql(source: string): unknown;

/**
 * The gql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function gql(source: TemplateStringsArray, ...args: any[]): unknown;

/**
 * The gql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function gql(source: string | TemplateStringsArray, ...args: any[]): unknown {
  const documentSource = typeof source === 'string' 
    ? source 
    : source.reduce((acc, str, i) => acc + str + (args[i] || ''), '');
  
  return {
    kind: 'Document',
    definitions: [],
    loc: { start: 0, end: documentSource.length },
    __meta__: { 
      hash: 'placeholder-' + Date.now(),
      isPlaceholder: true
    }
  } as any;
}

export default gql;
