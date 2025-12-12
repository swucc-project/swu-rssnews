import { ApolloClient, InMemoryCache, createHttpLink, ApolloLink } from '@apollo/client/core';
import { setContext } from '@apollo/client/link/context';
import { onError } from '@apollo/client/link/error';
import fetch from 'cross-fetch';
import introspectionQueryResultData from '@generated/introspection.json';

/**
 * สร้าง Apollo Client สำหรับ SSR
 * ฟังก์ชันนี้จะถูกเรียกใช้สำหรับทุกๆ request
 */
export function createSsrClient(context?: any) {
    // Error handling link
    const errorLink = onError(({ graphQLErrors, networkError }) => {
        if (graphQLErrors) {
            graphQLErrors.forEach(({ message, locations, path }) => {
                console.error(
                    `[SSR GraphQL error]: Message: ${message}, Location: ${JSON.stringify(locations)}, Path: ${path}`
                );
            });
        }
        if (networkError) {
            console.error(`[SSR Network error]: ${networkError}`);
        }
    });

    // HTTP Link with full URL for SSR
    const httpLink = createHttpLink({
        uri: process.env.VITE_GRAPHQL_ENDPOINT || 'http://localhost:5000/graphql',
        fetch, // ใช้ cross-fetch สำหรับ SSR
        credentials: 'include',
        headers: {
            'X-Allow-Introspection': 'true'
        }
    });

    // Auth link (optional - สำหรับส่ง token ถ้ามี)
    const authLink = setContext((_, { headers }) => {
        // ใน SSR context อาจจะได้ token จาก cookie หรือ context
        const token = context?.token || null;

        return {
            headers: {
                ...headers,
                ...(token ? { authorization: `Bearer ${token}` } : {}),
            }
        };
    });

    // Combine links
    const link = ApolloLink.from([
        errorLink,
        authLink,
        httpLink,
    ]);

    return new ApolloClient({
        link,
        cache: new InMemoryCache({
            possibleTypes: introspectionQueryResultData.possibleTypes,
            typePolicies: {
                Query: {
                    fields: {
                        rssItems: {
                            keyArgs: ['categoryId'],
                            merge(existing = [], incoming) {
                                return incoming; // ใน SSR ไม่ต้อง merge
                            }
                        }
                    }
                },
                ItemObject: {
                    keyFields: ["itemID"],
                },
                CategoryObject: {
                    keyFields: ["categoryID"],
                },
                AuthorObject: {
                    keyFields: ["buasriID"],
                },
            }
        }),
        ssrMode: true, // สำคัญมาก!
        defaultOptions: {
            watchQuery: {
                fetchPolicy: 'network-only', // ใน SSR ควรใช้ network-only
                errorPolicy: 'all',
            },
            query: {
                fetchPolicy: 'network-only',
                errorPolicy: 'all',
            },
        },
    });
}