// /vite-ui/grpc/index.ts
/**
 * ═══════════════════════════════════════════════════════════
 * gRPC Module Exports
 * ═══════════════════════════════════════════════════════════
 */

// Client wrapper (recommended usage)
export {
    grpcClient,
    GrpcError,
    type RSSItem,
    type AddRSSItemRequest,
    type UpdateRSSItemRequest,
    type DeleteRSSItemResponse,
    type GetRSSItemsOptions,
    type GrpcClient,
} from './feed-client';

// Low-level gRPC client (advanced usage)
export {
    RSSItemServiceClient,
    RSSItemService,
    type RSSItemServiceClientOptions,
} from './RssServiceClientPb';

// Protobuf message classes
export {
    RSSItem as PbRSSItem,
    Category as PbCategory,
    Author as PbAuthor,
    GetRSSItemsRequest,
    GetRSSItemByIDRequest,
    GetRSSItemsResponse,
    AddRSSItemRequest as PbAddRSSItemRequest,
    UpdateRSSItemRequest as PbUpdateRSSItemRequest,
    DeleteRSSItemRequest,
    DeleteRSSItemResponse as PbDeleteRSSItemResponse,
} from './rss_pb';

// Default export
export { grpcClient as default } from './feed-client';