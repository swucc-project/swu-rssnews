/* eslint-disable */
// Auto-generated GraphQL types placeholder
// Will be replaced by codegen when backend is available

import type { TypedDocumentNode as DocumentNode } from '@graphql-typed-document-node/core';

export type Maybe<T> = T | null;
export type InputMaybe<T> = Maybe<T>;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };
export type MakeOptional<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]?: Maybe<T[SubKey]> };
export type MakeMaybe<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]: Maybe<T[SubKey]> };

export type Scalars = {
  ID: string;
  String: string;
  Boolean: boolean;
  Int: number;
  Float: number;
  DateTime: string;
  Date: string;
  UUID: string;
  Decimal: number;
  Long: number;
};

// ========================================
// Types
// ========================================

export type RssItem = {
  __typename?: 'RssItem';
  itemID: Scalars['String'];
  title: Scalars['String'];
  link: Scalars['String'];
  description?: Maybe<Scalars['String']>;
  publishedDate: Scalars['String'];
  category?: Maybe<Category>;
  author?: Maybe<Author>;
};

export type Category = {
  __typename?: 'Category';
  categoryID: Scalars['Int'];
  categoryName: Scalars['String'];
};

export type Author = {
  __typename?: 'Author';
  buasriID: Scalars['String'];
  firstName: Scalars['String'];
  lastName: Scalars['String'];
};

export type Query = {
  __typename?: 'Query';
  _placeholder?: Maybe<Scalars['String']>;
  rssItems?: Maybe<Array<RssItem>>;
  rssItem?: Maybe<RssItem>;
  categories?: Maybe<Array<Category>>;
  authors?: Maybe<Array<Author>>;
};

export type Mutation = {
  __typename?: 'Mutation';
  _placeholder?: Maybe<Scalars['String']>;
  addItem?: Maybe<RssItem>;
  updateItem?: Maybe<RssItem>;
  deleteRssItem?: Maybe<Scalars['Boolean']>;
};

export type Subscription = {
  __typename?: 'Subscription';
  onItemAdded?: Maybe<RssItem>;
  onItemUpdated?: Maybe<RssItem>;
  onItemDeleted?: Maybe<Scalars['String']>;
};

// ========================================
// Input Types
// ========================================

export type AddItemInput = {
  title: Scalars['String'];
  link: Scalars['String'];
  description?: InputMaybe<Scalars['String']>;
  categoryId?: InputMaybe<Scalars['Int']>;
  authorId?: InputMaybe<Scalars['String']>;
};

export type UpdateItemInput = {
  title?: InputMaybe<Scalars['String']>;
  link?: InputMaybe<Scalars['String']>;
  description?: InputMaybe<Scalars['String']>;
  categoryId?: InputMaybe<Scalars['Int']>;
  authorId?: InputMaybe<Scalars['String']>;
};

// ========================================
// Query Variables & Results
// ========================================

export type GetRssItemsQueryVariables = Exact<{
  categoryId?: InputMaybe<Scalars['Int']>;
  skip?: InputMaybe<Scalars['Int']>;
  take?: InputMaybe<Scalars['Int']>;
}>;

export type GetRssItemsQuery = {
  __typename?: 'Query';
  rssItems?: Array<RssItem> | null;
};

export type GetCategoriesQuery = {
  __typename?: 'Query';
  categories?: Array<Category> | null;
};

export type GetAuthorsQuery = {
  __typename?: 'Query';
  authors?: Array<Author> | null;
};

// ========================================
// graphql() function for tagged templates
// ========================================

export function graphql(source: string): DocumentNode<unknown, unknown>;
export function graphql<TResult, TVariables>(
  source: string
): DocumentNode<TResult, TVariables>;
export function graphql(source: string): DocumentNode<unknown, unknown> {
  return {
    kind: 'Document',
    definitions: [],
    loc: { start: 0, end: source.length }
  } as unknown as DocumentNode<unknown, unknown>;
}

// Export documents map (empty placeholder)
export const documents: Record<string, DocumentNode<unknown, unknown>> = {};
