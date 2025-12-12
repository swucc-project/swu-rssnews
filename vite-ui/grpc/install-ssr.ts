import { GrpcWebFetchTransport } from '@protobuf-ts/grpcweb-transport';
import { RSSItemServiceClient } from '~grpc/rss.client';
import fetch from 'cross-fetch';

/**
 * สร้าง gRPC Client สำหรับ SSR
 */
export function createSsrGrpcClient() {
    const grpcTransport = new GrpcWebFetchTransport({
        baseUrl: process.env.GRPC_URL || process.env.VITE_GRPC_ENDPOINT || 'http://localhost:5000/grpc',
        format: 'binary',
        fetchInit: {
            credentials: 'include',
        },
        // ใช้ cross-fetch สำหรับ SSR
        fetch: fetch as any,
    });

    return new RSSItemServiceClient(grpcTransport);
}