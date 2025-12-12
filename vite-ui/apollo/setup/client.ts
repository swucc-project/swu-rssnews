import { ApolloClient, InMemoryCache, createHttpLink, split } from '@apollo/client/core';
import { getMainDefinition } from '@apollo/client/utilities';
import { GraphQLWsLink } from '@apollo/client/link/ws';
import { createClient as createWSClient } from 'graphql-ws';

// 1. สร้าง HTTP link สำหรับ Queries และ Mutations
const httpLink = createHttpLink({
    uri: import.meta.env.VITE_GRAPHQL_ENDPOINT, // URL ของ GraphQL Server (HTTP)
});

// 2. สร้าง WebSocket link สำหรับ Subscriptions
const wsLink = new GraphQLWsLink(
    createWSClient({
        url: import.meta.env.VITE_GRAPHQL_WS_URL, // URL ของ GraphQL Server (WebSocket)
        // สามารถเพิ่ม options สำหรับการเชื่อมต่อได้ที่นี่
        // connectionParams: {
        //   authToken: user.authToken,
        // },
    })
);

// 3. ใช้ `split` เพื่อเลือกว่าจะใช้ link ไหน
//    - ถ้าเป็น operation 'subscription' -> ใช้ wsLink
//    - นอกนั้น -> ใช้ httpLink
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

// 4. สร้าง ApolloClient instance ด้วย splitLink ใหม่
export const apolloClient = new ApolloClient({
    link: splitLink, // <-- ใช้ link ที่เรา split ไว้
    cache: new InMemoryCache(),
    connectToDevTools: true, // เปิดใช้งาน Apollo DevTools ในเบราว์เซอร์
});