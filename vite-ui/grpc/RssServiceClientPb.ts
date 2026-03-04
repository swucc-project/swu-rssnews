// /vite-ui/grpc/RssServiceClientPb.ts
/**
 * ═══════════════════════════════════════════════════════════
 * AUTO-GENERATED PLACEHOLDER - gRPC Service Client
 * ═══════════════════════════════════════════════════════════
 * This file will be replaced when proto files are compiled
 * Compatible with @improbable-eng/grpc-web
 * ═══════════════════════════════════════════════════════════
 */

import { grpc } from '@improbable-eng/grpc-web';
import {
  RSSItem,
  GetRSSItemsRequest,
  GetRSSItemByIDRequest,
  GetRSSItemsResponse,
  AddRSSItemRequest,
  UpdateRSSItemRequest,
  DeleteRSSItemRequest,
  DeleteRSSItemResponse,
} from './rss_pb';

// ============================================
// Service Definition (Placeholder)
// ============================================
export const RSSItemService = {
  serviceName: 'rss.RSSItemService',

  GetRSSItems: {
    methodName: 'GetRSSItems',
    service: { serviceName: 'rss.RSSItemService' },
    requestStream: false,
    responseStream: false,
    requestType: GetRSSItemsRequest,
    responseType: GetRSSItemsResponse,
  },

  GetRSSItemByID: {
    methodName: 'GetRSSItemByID',
    service: { serviceName: 'rss.RSSItemService' },
    requestStream: false,
    responseStream: false,
    requestType: GetRSSItemByIDRequest,
    responseType: RSSItem,
  },

  AddRSSItem: {
    methodName: 'AddRSSItem',
    service: { serviceName: 'rss.RSSItemService' },
    requestStream: false,
    responseStream: false,
    requestType: AddRSSItemRequest,
    responseType: RSSItem,
  },

  UpdateRSSItem: {
    methodName: 'UpdateRSSItem',
    service: { serviceName: 'rss.RSSItemService' },
    requestStream: false,
    responseStream: false,
    requestType: UpdateRSSItemRequest,
    responseType: RSSItem,
  },

  DeleteRSSItem: {
    methodName: 'DeleteRSSItem',
    service: { serviceName: 'rss.RSSItemService' },
    requestStream: false,
    responseStream: false,
    requestType: DeleteRSSItemRequest,
    responseType: DeleteRSSItemResponse,
  },
};

// ============================================
// Callback Type
// ============================================
type ServiceCallback<T> = (err: grpc.Code | null, response: T) => void;

// ============================================
// Client Options
// ============================================
export interface RSSItemServiceClientOptions {
  transport?: grpc.TransportFactory;
  debug?: boolean;
}

// ============================================
// Service Client
// ============================================
export class RSSItemServiceClient {
  private serviceHost: string;
  private options: RSSItemServiceClientOptions;
  private isPlaceholder: boolean = true;

  constructor(serviceHost: string, options?: RSSItemServiceClientOptions) {
    this.serviceHost = serviceHost;
    this.options = options || {};

    if (this.options.debug || process.env.NODE_ENV === 'development') {
      console.warn(
        '⚠️ RSSItemServiceClient: Using placeholder client.\n' +
        '   Service host:', serviceHost, '\n' +
      '   Run `npm run grpc:generate` to generate real client.'
      );
    }
  }

  // ============================================
  // GetRSSItems
  // ============================================
  getRSSItems(
    request: GetRSSItemsRequest,
    metadata: grpc.Metadata | Record<string, string>,
    callback: ServiceCallback<GetRSSItemsResponse>
  ): void {
    if (this.options.debug) {
      console.log('📡 gRPC Placeholder: getRSSItems called', request.toObject());
    }

    // Return empty response after small delay (simulate network)
    setTimeout(() => {
      const response = new GetRSSItemsResponse({
        items: [],
        totalCount: 0,
      });
      callback(null, response);
    }, 50);
  }

  // ============================================
  // GetRSSItemByID
  // ============================================
  getRSSItemByID(
    request: GetRSSItemByIDRequest,
    metadata: grpc.Metadata | Record<string, string>,
    callback: ServiceCallback<RSSItem>
  ): void {
    if (this.options.debug) {
      console.log('📡 gRPC Placeholder: getRSSItemByID called', request.toObject());
    }

    setTimeout(() => {
      const response = new RSSItem({
        itemId: request.getItemId(),
        title: 'Placeholder Item',
        link: 'https://example.com',
        description: 'This is a placeholder item',
      });
      callback(null, response);
    }, 50);
  }

  // ============================================
  // AddRSSItem
  // ============================================
  addRSSItem(
    request: AddRSSItemRequest,
    metadata: grpc.Metadata | Record<string, string>,
    callback: ServiceCallback<RSSItem>
  ): void {
    if (this.options.debug) {
      console.log('📡 gRPC Placeholder: addRSSItem called', request.toObject());
    }

    setTimeout(() => {
      const response = new RSSItem({
        itemId: `placeholder-${Date.now()}`,
        title: request.getTitle(),
        link: request.getLink(),
        description: request.getDescription(),
      });
      callback(null, response);
    }, 50);
  }

  // ============================================
  // UpdateRSSItem
  // ============================================
  updateRSSItem(
    request: UpdateRSSItemRequest,
    metadata: grpc.Metadata | Record<string, string>,
    callback: ServiceCallback<RSSItem>
  ): void {
    if (this.options.debug) {
      console.log('📡 gRPC Placeholder: updateRSSItem called', request.toObject());
    }

    setTimeout(() => {
      const response = new RSSItem({
        itemId: request.getItemId(),
        title: request.getTitle(),
        link: request.getLink(),
        description: request.getDescription(),
      });
      callback(null, response);
    }, 50);
  }

  // ============================================
  // DeleteRSSItem
  // ============================================
  deleteRSSItem(
    request: DeleteRSSItemRequest,
    metadata: grpc.Metadata | Record<string, string>,
    callback: ServiceCallback<DeleteRSSItemResponse>
  ): void {
    if (this.options.debug) {
      console.log('📡 gRPC Placeholder: deleteRSSItem called', request.toObject());
    }

    setTimeout(() => {
      const response = new DeleteRSSItemResponse({
        success: true,
        message: 'Placeholder: Item deleted',
      });
      callback(null, response);
    }, 50);
  }
}

// Export default
export default RSSItemServiceClient;