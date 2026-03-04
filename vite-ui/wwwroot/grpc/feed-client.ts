// /vite-ui/grpc/feed-client.ts
/**
 * ═══════════════════════════════════════════════════════════
 * gRPC Feed Client - Domain Wrapper
 * ═══════════════════════════════════════════════════════════
 * Provides a clean API for the frontend to interact with RSS service
 * ═══════════════════════════════════════════════════════════
 */

import { RSSItemServiceClient } from './RssServiceClientPb';
import {
    GetRSSItemsRequest,
    GetRSSItemByIDRequest,
    AddRSSItemRequest as PbAddRSSItemRequest,
    UpdateRSSItemRequest as PbUpdateRSSItemRequest,
    DeleteRSSItemRequest,
    RSSItem as PbRSSItem,
} from './rss_pb';
import { grpc } from '@improbable-eng/grpc-web';

// ============================================
// Domain Types (Frontend-friendly)
// ============================================
export interface RSSItem {
    itemId: string;
    title: string;
    link: string;
    description: string;
    publishedDate?: string;
    category?: {
        categoryId: number;
        categoryName: string;
    };
    author?: {
        authorId: string;
        firstName: string;
        lastName: string;
    };
}

export interface AddRSSItemRequest {
    title: string;
    link: string;
    description: string;
    publishedDate?: string;
}

export interface UpdateRSSItemRequest {
    itemId: string;
    title?: string;
    link?: string;
    description?: string;
    publishedDate?: string;
}

export interface DeleteRSSItemResponse {
    success: boolean;
    message?: string;
}

export interface GetRSSItemsOptions {
    categoryId?: number;
    skip?: number;
    take?: number;
}

// ============================================
// Client Configuration
// ============================================
const getEndpoint = (): string => {
    // Browser environment
    if (typeof window !== 'undefined') {
        return import.meta.env.VITE_PUBLIC_GRPC_ENDPOINT
            ?? import.meta.env.VITE_GRPC_ENDPOINT
            ?? 'http://localhost:5000';
    }
    // Node environment (SSR)
    return import.meta.env.VITE_GRPC_ENDPOINT ?? 'http://localhost:5000';
};

const endpoint = getEndpoint();

// Create client with appropriate transport
const client = new RSSItemServiceClient(endpoint, {
    transport: grpc.CrossBrowserHttpTransport({ withCredentials: false }),
    debug: import.meta.env.DEV,
});

// ============================================
// Mapper Functions
// ============================================
function mapRSSItem(pb: PbRSSItem): RSSItem {
    const category = pb.getCategory();
    const author = pb.getAuthor();

    return {
        itemId: pb.getItemId(),
        title: pb.getTitle(),
        link: pb.getLink(),
        description: pb.getDescription(),
        publishedDate: pb.getPublishedDate() || undefined,
        category: category ? {
            categoryId: category.getCategoryId(),
            categoryName: category.getCategoryName(),
        } : undefined,
        author: author ? {
            authorId: author.getAuthorId(),
            firstName: author.getFirstName(),
            lastName: author.getLastName(),
        } : undefined,
    };
}

// ============================================
// Error Handling
// ============================================
class GrpcError extends Error {
    constructor(
        public code: grpc.Code | null,
        message: string
    ) {
        super(message);
        this.name = 'GrpcError';
    }
}

function handleError(err: grpc.Code | null): never {
    const errorMessages: Record<number, string> = {
        [grpc.Code.OK]: 'Success',
        [grpc.Code.Cancelled]: 'Request cancelled',
        [grpc.Code.Unknown]: 'Unknown error',
        [grpc.Code.InvalidArgument]: 'Invalid argument',
        [grpc.Code.DeadlineExceeded]: 'Request timeout',
        [grpc.Code.NotFound]: 'Not found',
        [grpc.Code.AlreadyExists]: 'Already exists',
        [grpc.Code.PermissionDenied]: 'Permission denied',
        [grpc.Code.ResourceExhausted]: 'Resource exhausted',
        [grpc.Code.FailedPrecondition]: 'Failed precondition',
        [grpc.Code.Aborted]: 'Request aborted',
        [grpc.Code.OutOfRange]: 'Out of range',
        [grpc.Code.Unimplemented]: 'Not implemented',
        [grpc.Code.Internal]: 'Internal server error',
        [grpc.Code.Unavailable]: 'Service unavailable',
        [grpc.Code.DataLoss]: 'Data loss',
        [grpc.Code.Unauthenticated]: 'Unauthenticated',
    };

    const message = err !== null
        ? errorMessages[err] ?? `gRPC Error: ${err}`
        : 'Unknown gRPC error';

    throw new GrpcError(err, message);
}

// ============================================
// Public API
// ============================================
export const grpcClient = {
    /**
     * Get all RSS items with optional filtering
     */
    async getRSSItems(options?: GetRSSItemsOptions): Promise<RSSItem[]> {
        const req = new GetRSSItemsRequest({
            categoryId: options?.categoryId,
            skip: options?.skip ?? 0,
            take: options?.take ?? 100,
        });

        return new Promise((resolve, reject) => {
            client.getRSSItems(req, {}, (err, res) => {
                if (err) {
                    reject(new GrpcError(err, `Failed to get RSS items: ${err}`));
                    return;
                }
                if (!res) {
                    resolve([]);
                    return;
                }
                resolve(res.getItemsList().map(mapRSSItem));
            });
        });
    },

    /**
     * Get a single RSS item by ID
     */
    async getRSSItemByID(itemId: string): Promise<RSSItem | null> {
        if (!itemId) {
            throw new Error('Item ID is required');
        }

        const req = new GetRSSItemByIDRequest({ itemId });

        return new Promise((resolve, reject) => {
            client.getRSSItemByID(req, {}, (err, res) => {
                if (err) {
                    // NotFound is not an error, just return null
                    if (err === grpc.Code.NotFound) {
                        resolve(null);
                        return;
                    }
                    reject(new GrpcError(err, `Failed to get RSS item: ${err}`));
                    return;
                }
                resolve(res ? mapRSSItem(res) : null);
            });
        });
    },

    /**
     * Add a new RSS item
     */
    async addRSSItem(data: AddRSSItemRequest): Promise<RSSItem> {
        if (!data.title || !data.link) {
            throw new Error('Title and link are required');
        }

        const req = new PbAddRSSItemRequest({
            title: data.title,
            link: data.link,
            description: data.description || '',
            publishedDate: data.publishedDate || new Date().toISOString(),
        });

        return new Promise((resolve, reject) => {
            client.addRSSItem(req, {}, (err, res) => {
                if (err) {
                    reject(new GrpcError(err, `Failed to add RSS item: ${err}`));
                    return;
                }
                if (!res) {
                    reject(new Error('No response received'));
                    return;
                }
                resolve(mapRSSItem(res));
            });
        });
    },

    /**
     * Update an existing RSS item
     */
    async updateRSSItem(data: UpdateRSSItemRequest): Promise<RSSItem | null> {
        if (!data.itemId) {
            throw new Error('Item ID is required');
        }

        const req = new PbUpdateRSSItemRequest({
            itemId: data.itemId,
            title: data.title || '',
            link: data.link || '',
            description: data.description || '',
            publishedDate: data.publishedDate,
        });

        return new Promise((resolve, reject) => {
            client.updateRSSItem(req, {}, (err, res) => {
                if (err) {
                    if (err === grpc.Code.NotFound) {
                        resolve(null);
                        return;
                    }
                    reject(new GrpcError(err, `Failed to update RSS item: ${err}`));
                    return;
                }
                resolve(res ? mapRSSItem(res) : null);
            });
        });
    },

    /**
     * Delete an RSS item
     */
    async deleteRSSItem(itemId: string): Promise<DeleteRSSItemResponse> {
        if (!itemId) {
            throw new Error('Item ID is required');
        }

        const req = new DeleteRSSItemRequest({ itemId });

        return new Promise((resolve, reject) => {
            client.deleteRSSItem(req, {}, (err, res) => {
                if (err) {
                    reject(new GrpcError(err, `Failed to delete RSS item: ${err}`));
                    return;
                }
                resolve({
                    success: res?.getSuccess() ?? false,
                    message: res?.getMessage(),
                });
            });
        });
    },

    /**
     * Check if service is available (placeholder always returns true)
     */
    async healthCheck(): Promise<boolean> {
        try {
            await this.getRSSItems({ take: 1 });
            return true;
        } catch {
            return false;
        }
    },
};

// ============================================
// Type Exports
// ============================================
export type GrpcClient = typeof grpcClient;
export { GrpcError };

// Default export
export default grpcClient;