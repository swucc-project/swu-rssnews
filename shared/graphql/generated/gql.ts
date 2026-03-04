/* eslint-disable */
import * as types from "./graphql";
import type { TypedDocumentNode as DocumentNode } from "@graphql-typed-document-node/core";

/**
 * Map of all GraphQL operations in the project.
 *
 * This map has several performance disadvantages:
 * 1. It is not tree-shakeable, so it will include all operations in the project.
 * 2. It is not minifiable, so the string of a GraphQL query will be multiple times inside the bundle.
 * 3. It does not support dead code elimination, so it will add unused operations.
 *
 * Therefore it is highly recommended to use the babel or swc plugin for production.
 * Learn more about it here: https://the-guild.dev/graphql/codegen/plugins/presets/preset-client#reducing-bundle-size
 */
type Documents = {
  "\n    mutation AddRSSItem($input: AddItemInput!) {\n        addItem(input: $input) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    }\n": typeof types.AddRssItemDocument;
  "\n    query GetRssItemForDelete($id: String!) {\n        rssItem(id: $id) {\n            itemID\n            title\n        }\n    }\n": typeof types.GetRssItemForDeleteDocument;
  "\n    mutation DeleteRSSItem($id: String!) {\n        deleteRssItem(id: $id)\n    }\n": typeof types.DeleteRssItemDocument;
  "\n    query GetRssFeedItems($categoryId: Int) {\n        rssItems(categoryId: $categoryId) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    }\n": typeof types.GetRssFeedItemsDocument;
  "\n    query GetRssIndexData($categoryId: Int) {\n        rssItems(categoryId: $categoryId) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n        categories {\n            categoryID\n            categoryName\n        }\n    }\n": typeof types.GetRssIndexDataDocument;
  "\n    query GetRssItemForUpdate($id: String!) {\n        rssItem(id: $id) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n            }\n            author {\n                buasriID\n            }\n        }\n    }\n": typeof types.GetRssItemForUpdateDocument;
  "\n    mutation UpdateRssItem($id: String!, $input: UpdateItemInput!) {\n        updateItem(id: $id, input: $input) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    }\n": typeof types.UpdateRssItemDocument;
  "\n    query GetFormDataForRssForm {\n        categories {\n            categoryID\n            categoryName\n        }\n        authors {\n            buasriID\n            firstName\n            lastName\n        }\n    }\n": typeof types.GetFormDataForRssFormDocument;
  "\n        query GetFormData {\n            categories {\n                categoryID\n                categoryName\n            }\n            authors {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    ": typeof types.GetFormDataDocument;
  "\n        mutation AddItem($input: AddItemInput!) {\n            addItem(input: $input) {\n                itemID\n                title\n                link\n                description\n                publishedDate\n                category {\n                    categoryID\n                    categoryName\n                }\n                author {\n                    buasriID\n                    firstName\n                    lastName\n                }\n            }\n        }\n    ": typeof types.AddItemDocument;
  "\n        mutation UpdateItem($id: String!, $input: UpdateItemInput!) {\n            updateItem(id: $id, input: $input) {\n                itemID\n                title\n                link\n                description\n                publishedDate\n                category {\n                    categoryID\n                    categoryName\n                }\n                author {\n                    buasriID\n                    firstName\n                    lastName\n                }\n            }\n        }\n    ": typeof types.UpdateItemDocument;
};
const documents: Documents = {
  "\n    mutation AddRSSItem($input: AddItemInput!) {\n        addItem(input: $input) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    }\n":
    types.AddRssItemDocument,
  "\n    query GetRssItemForDelete($id: String!) {\n        rssItem(id: $id) {\n            itemID\n            title\n        }\n    }\n":
    types.GetRssItemForDeleteDocument,
  "\n    mutation DeleteRSSItem($id: String!) {\n        deleteRssItem(id: $id)\n    }\n":
    types.DeleteRssItemDocument,
  "\n    query GetRssFeedItems($categoryId: Int) {\n        rssItems(categoryId: $categoryId) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    }\n":
    types.GetRssFeedItemsDocument,
  "\n    query GetRssIndexData($categoryId: Int) {\n        rssItems(categoryId: $categoryId) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n        categories {\n            categoryID\n            categoryName\n        }\n    }\n":
    types.GetRssIndexDataDocument,
  "\n    query GetRssItemForUpdate($id: String!) {\n        rssItem(id: $id) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n            }\n            author {\n                buasriID\n            }\n        }\n    }\n":
    types.GetRssItemForUpdateDocument,
  "\n    mutation UpdateRssItem($id: String!, $input: UpdateItemInput!) {\n        updateItem(id: $id, input: $input) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    }\n":
    types.UpdateRssItemDocument,
  "\n    query GetFormDataForRssForm {\n        categories {\n            categoryID\n            categoryName\n        }\n        authors {\n            buasriID\n            firstName\n            lastName\n        }\n    }\n":
    types.GetFormDataForRssFormDocument,
  "\n        query GetFormData {\n            categories {\n                categoryID\n                categoryName\n            }\n            authors {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    ":
    types.GetFormDataDocument,
  "\n        mutation AddItem($input: AddItemInput!) {\n            addItem(input: $input) {\n                itemID\n                title\n                link\n                description\n                publishedDate\n                category {\n                    categoryID\n                    categoryName\n                }\n                author {\n                    buasriID\n                    firstName\n                    lastName\n                }\n            }\n        }\n    ":
    types.AddItemDocument,
  "\n        mutation UpdateItem($id: String!, $input: UpdateItemInput!) {\n            updateItem(id: $id, input: $input) {\n                itemID\n                title\n                link\n                description\n                publishedDate\n                category {\n                    categoryID\n                    categoryName\n                }\n                author {\n                    buasriID\n                    firstName\n                    lastName\n                }\n            }\n        }\n    ":
    types.UpdateItemDocument,
};

/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 *
 *
 * @example
 * ```ts
 * const query = graphql(`query GetUser($id: ID!) { user(id: $id) { name } }`);
 * ```
 *
 * The query argument is unknown!
 * Please regenerate the types.
 */
export function graphql(source: string): unknown;

/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(
  source: "\n    mutation AddRSSItem($input: AddItemInput!) {\n        addItem(input: $input) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    }\n",
): (typeof documents)["\n    mutation AddRSSItem($input: AddItemInput!) {\n        addItem(input: $input) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    }\n"];
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(
  source: "\n    query GetRssItemForDelete($id: String!) {\n        rssItem(id: $id) {\n            itemID\n            title\n        }\n    }\n",
): (typeof documents)["\n    query GetRssItemForDelete($id: String!) {\n        rssItem(id: $id) {\n            itemID\n            title\n        }\n    }\n"];
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(
  source: "\n    mutation DeleteRSSItem($id: String!) {\n        deleteRssItem(id: $id)\n    }\n",
): (typeof documents)["\n    mutation DeleteRSSItem($id: String!) {\n        deleteRssItem(id: $id)\n    }\n"];
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(
  source: "\n    query GetRssFeedItems($categoryId: Int) {\n        rssItems(categoryId: $categoryId) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    }\n",
): (typeof documents)["\n    query GetRssFeedItems($categoryId: Int) {\n        rssItems(categoryId: $categoryId) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    }\n"];
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(
  source: "\n    query GetRssIndexData($categoryId: Int) {\n        rssItems(categoryId: $categoryId) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n        categories {\n            categoryID\n            categoryName\n        }\n    }\n",
): (typeof documents)["\n    query GetRssIndexData($categoryId: Int) {\n        rssItems(categoryId: $categoryId) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n        categories {\n            categoryID\n            categoryName\n        }\n    }\n"];
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(
  source: "\n    query GetRssItemForUpdate($id: String!) {\n        rssItem(id: $id) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n            }\n            author {\n                buasriID\n            }\n        }\n    }\n",
): (typeof documents)["\n    query GetRssItemForUpdate($id: String!) {\n        rssItem(id: $id) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n            }\n            author {\n                buasriID\n            }\n        }\n    }\n"];
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(
  source: "\n    mutation UpdateRssItem($id: String!, $input: UpdateItemInput!) {\n        updateItem(id: $id, input: $input) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    }\n",
): (typeof documents)["\n    mutation UpdateRssItem($id: String!, $input: UpdateItemInput!) {\n        updateItem(id: $id, input: $input) {\n            itemID\n            title\n            link\n            description\n            publishedDate\n            category {\n                categoryID\n                categoryName\n            }\n            author {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    }\n"];
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(
  source: "\n    query GetFormDataForRssForm {\n        categories {\n            categoryID\n            categoryName\n        }\n        authors {\n            buasriID\n            firstName\n            lastName\n        }\n    }\n",
): (typeof documents)["\n    query GetFormDataForRssForm {\n        categories {\n            categoryID\n            categoryName\n        }\n        authors {\n            buasriID\n            firstName\n            lastName\n        }\n    }\n"];
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(
  source: "\n        query GetFormData {\n            categories {\n                categoryID\n                categoryName\n            }\n            authors {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    ",
): (typeof documents)["\n        query GetFormData {\n            categories {\n                categoryID\n                categoryName\n            }\n            authors {\n                buasriID\n                firstName\n                lastName\n            }\n        }\n    "];
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(
  source: "\n        mutation AddItem($input: AddItemInput!) {\n            addItem(input: $input) {\n                itemID\n                title\n                link\n                description\n                publishedDate\n                category {\n                    categoryID\n                    categoryName\n                }\n                author {\n                    buasriID\n                    firstName\n                    lastName\n                }\n            }\n        }\n    ",
): (typeof documents)["\n        mutation AddItem($input: AddItemInput!) {\n            addItem(input: $input) {\n                itemID\n                title\n                link\n                description\n                publishedDate\n                category {\n                    categoryID\n                    categoryName\n                }\n                author {\n                    buasriID\n                    firstName\n                    lastName\n                }\n            }\n        }\n    "];
/**
 * The graphql function is used to parse GraphQL queries into a document that can be used by GraphQL clients.
 */
export function graphql(
  source: "\n        mutation UpdateItem($id: String!, $input: UpdateItemInput!) {\n            updateItem(id: $id, input: $input) {\n                itemID\n                title\n                link\n                description\n                publishedDate\n                category {\n                    categoryID\n                    categoryName\n                }\n                author {\n                    buasriID\n                    firstName\n                    lastName\n                }\n            }\n        }\n    ",
): (typeof documents)["\n        mutation UpdateItem($id: String!, $input: UpdateItemInput!) {\n            updateItem(id: $id, input: $input) {\n                itemID\n                title\n                link\n                description\n                publishedDate\n                category {\n                    categoryID\n                    categoryName\n                }\n                author {\n                    buasriID\n                    firstName\n                    lastName\n                }\n            }\n        }\n    "];

export function graphql(source: string) {
  return (documents as any)[source] ?? {};
}

export type DocumentType<TDocumentNode extends DocumentNode<any, any>> =
  TDocumentNode extends DocumentNode<infer TType, any> ? TType : never;
