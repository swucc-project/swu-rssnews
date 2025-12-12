import { GrpcWebFetchTransport } from '@protobuf-ts/grpcweb-transport'
import { RSSItemServiceClient } from '~grpc/rss.client'

const grpcTransport = new GrpcWebFetchTransport({
    baseUrl: import.meta.env.VITE_GRPC_ENDPOINT || '/grpc',
    format: 'binary',
    interceptors: [
        {
            interceptUnary(next, method, input, options) {
                return next(method, input, options);
            }
        }
    ],
    fetch: (input, init) => {
        const token = localStorage.getItem('authToken');
        if (token) {
            init.headers = {
                ...init.headers,
                'Authorization': `Bearer ${token}`
            };
        }
        return fetch(input, init);
    }
});

export const grpcClient = new RSSItemServiceClient(grpcTransport);