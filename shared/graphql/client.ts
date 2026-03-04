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
// ✅ Import JSON โดยตรง (Vite รองรับการ import .json)
import introspectionResult from './generated/introspection.json';

// ✅ Config Endpoints (ใช้ Relative path เพื่อให้ผ่าน Vite Proxy)
// ไม่ต้อง Hardcode localhost:5000 เพราะ Proxy จะจัดการให้
const httpEndpoint = '/graphql';
// คำนวณ WebSocket URL อัตโนมัติจาก window.location
const wsEndpoint = `${window.location.protocol === 'https:' ? 'wss:' : 'ws:'}//${window.location.host}/graphql-ws`;

console.log('🔗 Apollo Client Configuration (CSR):', {
    httpEndpoint,
    wsEndpoint
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

// ✅ Auth context link
const authLink = setContext((_, { headers }) => {
    const token = localStorage.getItem('authToken');
    return {
        headers: {
            ...headers,
            ...(token && { authorization: `Bearer ${token}` }),
            'X-Allow-Introspection': 'true',
        }
    };
});

// ✅ HTTP Link
const httpLink = new HttpLink({
    uri: httpEndpoint,
    credentials: 'include', // ส่ง Cookies ไปด้วย
    fetchOptions: {
        mode: 'cors',
    },
});

// ✅ WebSocket Link (ทำงานเสมอใน Browser)
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
    keepAlive: 10000,
    on: {
        connected: () => console.log('🔌 GraphQL WebSocket connected'),
        error: (error) => console.error('🔌 GraphQL WebSocket error:', error),
    },
});

const wsLink = new GraphQLWsLink(wsClient);

// ✅ Split Link logic (HTTP vs WebSocket)
const splitLink = split(
    ({ query }) => {
        const definition = getMainDefinition(query);
        return (
            definition.kind === 'OperationDefinition' &&
            definition.operation === 'subscription'
        );
    },
    wsLink,
    httpLink
);

// ✅ Combine all links
const link = from([
    errorLink,
    authLink,
    splitLink
]);

// ✅ Apollo Client Instance
export const apolloClient = new ApolloClient({
    link,
    cache: new InMemoryCache({
        addTypename: true,
        resultCaching: true,
        possibleTypes: introspectionResult.possibleTypes || {}, // ใช้ข้อมูลจาก Import
        typePolicies: {
            Query: {
                fields: {
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
            notifyOnNetworkStatusChange: true,
        },
        query: {
            fetchPolicy: 'network-only',
            errorPolicy: 'all',
        },
        mutate: {
            errorPolicy: 'all',
            fetchPolicy: 'no-cache',
        },
    },
    connectToDevTools: import.meta.env.DEV,
    name: 'rssnews-client-csr',
    version: '1.0.0',
});

// ✅ Helper functions
export const clearApolloCache = () => apolloClient.clearStore();
export const resetApolloCache = () => apolloClient.resetStore();

export default apolloClient;