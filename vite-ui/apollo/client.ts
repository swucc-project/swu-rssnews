import {
    ApolloClient,
    InMemoryCache,
    HttpLink,
    split,
    from,
    ApolloLink
} from '@apollo/client/core';
import { GraphQLWsLink } from '@apollo/client/link/subscriptions';
import { getMainDefinition } from '@apollo/client/utilities';
import { onError } from '@apollo/client/link/error';
import { setContext } from '@apollo/client/link/context';
import { createClient } from 'graphql-ws';
import fetch from 'cross-fetch';

// ✅ Type-safe environment check
const isServer = typeof window === 'undefined';

// ✅ Environment variables with fallbacks
const httpEndpoint = isServer
    ? (process.env.VITE_GRAPHQL_ENDPOINT || 'http://aspdotnetweb:5000/graphql')
    : (import.meta.env.VITE_PUBLIC_GRAPHQL_ENDPOINT || 'http://localhost:5000/graphql');

const wsEndpoint = isServer
    ? (process.env.VITE_GRAPHQL_WS_URL || 'ws://aspdotnetweb:5000/graphql-ws')
    : (import.meta.env.VITE_PUBLIC_GRAPHQL_WS_URL || 'ws://localhost:5000/graphql-ws');

console.log('🔗 Apollo Client Configuration:', {
    isServer,
    httpEndpoint,
    wsEndpoint: isServer ? 'N/A (server)' : wsEndpoint
});

// ✅ Error handling link
const errorLink = onError(({ graphQLErrors, networkError, operation }) => {
    if (graphQLErrors) {
        graphQLErrors.forEach(({ message, locations, path, extensions }) => {
            console.error(
                `[GraphQL error]: Message: ${message}, Location: ${JSON.stringify(locations)}, Path: ${path}`,
                extensions
            );
        });
    }

    if (networkError) {
        console.error(`[Network error]: ${networkError.message}`, {
            operation: operation.operationName,
            endpoint: httpEndpoint
        });
    }
});

// ✅ Auth context link (สำหรับ JWT/cookies)
const authLink = setContext((_, { headers }) => {
    // ✅ รองรับทั้ง localStorage (browser) และ cookies
    const token = !isServer ? localStorage.getItem('authToken') : null;

    return {
        headers: {
            ...headers,
            ...(token && { authorization: `Bearer ${token}` }),
            'X-Allow-Introspection': 'true',
        }
    };
});

// ✅ HTTP Link with credentials
const httpLink = new HttpLink({
    uri: httpEndpoint,
    fetch,
    credentials: 'include', // ✅ สำคัญ! ส่ง cookies
    fetchOptions: {
        mode: 'cors',
    },
});

// ✅ WebSocket Link (client-side only)
let wsLink: GraphQLWsLink | null = null;

if (!isServer) {
    try {
        const wsClient = createClient({
            url: wsEndpoint,
            connectionParams: () => {
                const token = localStorage.getItem('authToken');
                return {
                    authorization: token ? `Bearer ${token}` : '',
                    'X-Allow-Introspection': 'true',
                };
            },
            retryAttempts: 5,
            shouldRetry: () => true,
            keepAlive: 10000, // ✅ Keep connection alive
            on: {
                connected: () => console.log('🔌 GraphQL WebSocket connected'),
                closed: () => console.log('🔌 GraphQL WebSocket closed'),
                error: (error) => console.error('🔌 GraphQL WebSocket error:', error),
            },
        });

        wsLink = new GraphQLWsLink(wsClient);
    } catch (error) {
        console.warn('⚠️ WebSocket initialization failed:', error);
    }
}

// ✅ Combine links
const link = !isServer && wsLink
    ? from([
        errorLink,
        authLink,
        split(
            ({ query }) => {
                const definition = getMainDefinition(query);
                return (
                    definition.kind === 'OperationDefinition' &&
                    definition.operation === 'subscription'
                );
            },
            wsLink,
            httpLink
        )
    ])
    : from([errorLink, authLink, httpLink]);

// ✅ Import introspection data (ถ้ามี)
let introspectionData: any = { possibleTypes: {} };
try {
    introspectionData = require('./generated/introspection.json');
} catch (e) {
    console.warn('⚠️ Introspection data not found, using empty schema');
}

// ✅ Apollo Client instance with proper typing
export const apolloClient = new ApolloClient({
    link,
    cache: new InMemoryCache({
        addTypename: true,
        resultCaching: true,
        possibleTypes: introspectionData.possibleTypes || {},
        typePolicies: {
            Query: {
                fields: {
                    // ✅ Merge policies สำหรับ pagination (ถ้าใช้)
                    rssItems: {
                        keyArgs: ['categoryId'],
                        merge(existing = [], incoming) {
                            return [...incoming];
                        },
                    },
                },
            },
        },
    }),
    defaultOptions: {
        watchQuery: {
            fetchPolicy: 'cache-and-network',
            errorPolicy: 'all',
            notifyOnNetworkStatusChange: true, // ✅ สำหรับ loading states
        },
        query: {
            fetchPolicy: 'network-only',
            errorPolicy: 'all',
        },
        mutate: {
            errorPolicy: 'all',
            fetchPolicy: 'no-cache', // ✅ Mutations ไม่ควร cache
        },
    },
    connectToDevTools: !isServer && import.meta.env.DEV,
    ssrMode: isServer,
    ssrForceFetchDelay: 100, // ✅ หน่วงเวลาสำหรับ SSR
    name: 'rssnews-client',
    version: '1.0.0',
});

// ✅ Export helper functions
export const clearApolloCache = () => {
    return apolloClient.clearStore();
};

export const resetApolloCache = () => {
    return apolloClient.resetStore();
};

export default apolloClient;