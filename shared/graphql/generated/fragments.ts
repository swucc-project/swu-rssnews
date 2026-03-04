import gql from 'graphql-tag';

// RSS Item Fields Fragment
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

// Category Fields Fragment
export const CATEGORY_FIELDS = gql`
  fragment CategoryFields on Category {
    categoryID
    categoryName
  }
`;

// Author Fields Fragment
export const AUTHOR_FIELDS = gql`
  fragment AuthorFields on Author {
    buasriID
    firstName
    lastName
  }
`;

// Fragment Types
export type RssItemFieldsFragment = {
  __typename?: 'RssItem';
  itemID: string;
  title: string;
  link: string;
  description: string;
  publishedDate: string;
  category?: {
    __typename?: 'Category';
    categoryID: number;
    categoryName: string;
  } | null;
  author?: {
    __typename?: 'Author';
    buasriID: string;
    firstName: string;
    lastName: string;
  } | null;
};

export type CategoryFieldsFragment = {
  __typename?: 'Category';
  categoryID: number;
  categoryName: string;
};

export type AuthorFieldsFragment = {
  __typename?: 'Author';
  buasriID: string;
  firstName: string;
  lastName: string;
};