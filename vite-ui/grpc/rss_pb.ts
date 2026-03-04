// /vite-ui/grpc/rss_pb.ts
/**
 * ═══════════════════════════════════════════════════════════
 * AUTO-GENERATED PLACEHOLDER - gRPC Protobuf Messages
 * ═══════════════════════════════════════════════════════════
 * This file will be replaced when proto files are compiled
 * Compatible with @improbable-eng/grpc-web
 * ═══════════════════════════════════════════════════════════
 */

// ============================================
// Base Message Interface
// ============================================
interface Message {
    serializeBinary(): Uint8Array;
    toObject(): Record<string, any>;
}

// ============================================
// RSSItem Message
// ============================================
export class RSSItem implements Message {
    private itemId: string = '';
    private title: string = '';
    private link: string = '';
    private description: string = '';
    private publishedDate: string = '';
    private category: Category | undefined;
    private author: Author | undefined;

    static displayName = 'RSSItem';

    constructor(data?: Partial<{
        itemId: string;
        title: string;
        link: string;
        description: string;
        publishedDate: string;
        category: Category;
        author: Author;
    }>) {
        if (data) {
            this.itemId = data.itemId ?? '';
            this.title = data.title ?? '';
            this.link = data.link ?? '';
            this.description = data.description ?? '';
            this.publishedDate = data.publishedDate ?? '';
            this.category = data.category;
            this.author = data.author;
        }
    }

    getItemId(): string { return this.itemId; }
    setItemId(value: string): RSSItem { this.itemId = value; return this; }

    getTitle(): string { return this.title; }
    setTitle(value: string): RSSItem { this.title = value; return this; }

    getLink(): string { return this.link; }
    setLink(value: string): RSSItem { this.link = value; return this; }

    getDescription(): string { return this.description; }
    setDescription(value: string): RSSItem { this.description = value; return this; }

    getPublishedDate(): string { return this.publishedDate; }
    setPublishedDate(value: string): RSSItem { this.publishedDate = value; return this; }

    getCategory(): Category | undefined { return this.category; }
    setCategory(value?: Category): RSSItem { this.category = value; return this; }

    getAuthor(): Author | undefined { return this.author; }
    setAuthor(value?: Author): RSSItem { this.author = value; return this; }

    serializeBinary(): Uint8Array { return new Uint8Array(); }

    toObject(): Record<string, any> {
        return {
            itemId: this.itemId,
            title: this.title,
            link: this.link,
            description: this.description,
            publishedDate: this.publishedDate,
            category: this.category?.toObject(),
            author: this.author?.toObject(),
        };
    }

    static deserializeBinary(bytes: Uint8Array): RSSItem {
        return new RSSItem();
    }

    static deserializeBinaryFromReader(message: RSSItem, reader: any): RSSItem {
        return message;
    }
}

// ============================================
// Category Message
// ============================================
export class Category implements Message {
    private categoryId: number = 0;
    private categoryName: string = '';

    static displayName = 'Category';

    constructor(data?: Partial<{ categoryId: number; categoryName: string }>) {
        if (data) {
            this.categoryId = data.categoryId ?? 0;
            this.categoryName = data.categoryName ?? '';
        }
    }

    getCategoryId(): number { return this.categoryId; }
    setCategoryId(value: number): Category { this.categoryId = value; return this; }

    getCategoryName(): string { return this.categoryName; }
    setCategoryName(value: string): Category { this.categoryName = value; return this; }

    // Aliases
    getId(): number { return this.categoryId; }
    setId(value: number): Category { return this.setCategoryId(value); }
    getName(): string { return this.categoryName; }
    setName(value: string): Category { return this.setCategoryName(value); }

    serializeBinary(): Uint8Array { return new Uint8Array(); }

    toObject(): Record<string, any> {
        return {
            categoryId: this.categoryId,
            categoryName: this.categoryName,
        };
    }

    static deserializeBinary(bytes: Uint8Array): Category {
        return new Category();
    }
}

// ============================================
// Author Message
// ============================================
export class Author implements Message {
    private authorId: string = '';
    private firstName: string = '';
    private lastName: string = '';

    static displayName = 'Author';

    constructor(data?: Partial<{ authorId: string; firstName: string; lastName: string }>) {
        if (data) {
            this.authorId = data.authorId ?? '';
            this.firstName = data.firstName ?? '';
            this.lastName = data.lastName ?? '';
        }
    }

    getAuthorId(): string { return this.authorId; }
    setAuthorId(value: string): Author { this.authorId = value; return this; }

    getFirstName(): string { return this.firstName; }
    setFirstName(value: string): Author { this.firstName = value; return this; }

    // Alias for compatibility
    getFirstname(): string { return this.firstName; }
    setFirstname(value: string): Author { return this.setFirstName(value); }

    getLastName(): string { return this.lastName; }
    setLastName(value: string): Author { this.lastName = value; return this; }

    // Alias for compatibility
    getLastname(): string { return this.lastName; }
    setLastname(value: string): Author { return this.setLastName(value); }

    serializeBinary(): Uint8Array { return new Uint8Array(); }

    toObject(): Record<string, any> {
        return {
            authorId: this.authorId,
            firstName: this.firstName,
            lastName: this.lastName,
        };
    }

    static deserializeBinary(bytes: Uint8Array): Author {
        return new Author();
    }
}

// ============================================
// GetRSSItemsRequest
// ============================================
export class GetRSSItemsRequest implements Message {
    private categoryId?: number;
    private skip: number = 0;
    private take: number = 10;

    static displayName = 'GetRSSItemsRequest';

    constructor(data?: Partial<{ categoryId?: number; skip?: number; take?: number }>) {
        if (data) {
            this.categoryId = data.categoryId;
            this.skip = data.skip ?? 0;
            this.take = data.take ?? 10;
        }
    }

    getCategoryId(): number | undefined { return this.categoryId; }
    setCategoryId(value: number): GetRSSItemsRequest { this.categoryId = value; return this; }

    getSkip(): number { return this.skip; }
    setSkip(value: number): GetRSSItemsRequest { this.skip = value; return this; }

    getTake(): number { return this.take; }
    setTake(value: number): GetRSSItemsRequest { this.take = value; return this; }

    serializeBinary(): Uint8Array { return new Uint8Array(); }

    toObject(): Record<string, any> {
        return {
            categoryId: this.categoryId,
            skip: this.skip,
            take: this.take,
        };
    }

    static deserializeBinary(bytes: Uint8Array): GetRSSItemsRequest {
        return new GetRSSItemsRequest();
    }
}

// ============================================
// GetRSSItemByIDRequest
// ============================================
export class GetRSSItemByIDRequest implements Message {
    private itemId: string = '';

    static displayName = 'GetRSSItemByIDRequest';

    constructor(data?: Partial<{ itemId: string }>) {
        if (data) {
            this.itemId = data.itemId ?? '';
        }
    }

    getItemId(): string { return this.itemId; }
    setItemId(value: string): GetRSSItemByIDRequest { this.itemId = value; return this; }

    serializeBinary(): Uint8Array { return new Uint8Array(); }

    toObject(): Record<string, any> {
        return { itemId: this.itemId };
    }

    static deserializeBinary(bytes: Uint8Array): GetRSSItemByIDRequest {
        return new GetRSSItemByIDRequest();
    }
}

// ============================================
// GetRSSItemsResponse
// ============================================
export class GetRSSItemsResponse implements Message {
    private items: RSSItem[] = [];
    private totalCount: number = 0;

    static displayName = 'GetRSSItemsResponse';

    constructor(data?: Partial<{ items: RSSItem[]; totalCount: number }>) {
        if (data) {
            this.items = data.items ?? [];
            this.totalCount = data.totalCount ?? 0;
        }
    }

    getItemsList(): RSSItem[] { return this.items; }
    setItemsList(value: RSSItem[]): GetRSSItemsResponse { this.items = value; return this; }
    addItems(value: RSSItem): GetRSSItemsResponse { this.items.push(value); return this; }

    getTotalCount(): number { return this.totalCount; }
    setTotalCount(value: number): GetRSSItemsResponse { this.totalCount = value; return this; }

    serializeBinary(): Uint8Array { return new Uint8Array(); }

    toObject(): Record<string, any> {
        return {
            items: this.items.map(item => item.toObject()),
            totalCount: this.totalCount,
        };
    }

    static deserializeBinary(bytes: Uint8Array): GetRSSItemsResponse {
        return new GetRSSItemsResponse();
    }
}

// ============================================
// AddRSSItemRequest
// ============================================
export class AddRSSItemRequest implements Message {
    private title: string = '';
    private link: string = '';
    private description: string = '';
    private publishedDate: string = '';
    private category?: Category;
    private author?: Author;

    static displayName = 'AddRSSItemRequest';

    constructor(data?: Partial<{
        title: string;
        link: string;
        description: string;
        publishedDate: string;
        category?: Category;
        author?: Author;
    }>) {
        if (data) {
            this.title = data.title ?? '';
            this.link = data.link ?? '';
            this.description = data.description ?? '';
            this.publishedDate = data.publishedDate ?? '';
            this.category = data.category;
            this.author = data.author;
        }
    }

    getTitle(): string { return this.title; }
    setTitle(value: string): AddRSSItemRequest { this.title = value; return this; }

    getLink(): string { return this.link; }
    setLink(value: string): AddRSSItemRequest { this.link = value; return this; }

    getDescription(): string { return this.description; }
    setDescription(value: string): AddRSSItemRequest { this.description = value; return this; }

    getPublishedDate(): string { return this.publishedDate; }
    setPublishedDate(value: string): AddRSSItemRequest { this.publishedDate = value; return this; }

    getCategory(): Category | undefined { return this.category; }
    setCategory(value?: Category): AddRSSItemRequest { this.category = value; return this; }

    getAuthor(): Author | undefined { return this.author; }
    setAuthor(value?: Author): AddRSSItemRequest { this.author = value; return this; }

    serializeBinary(): Uint8Array { return new Uint8Array(); }

    toObject(): Record<string, any> {
        return {
            title: this.title,
            link: this.link,
            description: this.description,
            publishedDate: this.publishedDate,
            category: this.category?.toObject(),
            author: this.author?.toObject(),
        };
    }

    static deserializeBinary(bytes: Uint8Array): AddRSSItemRequest {
        return new AddRSSItemRequest();
    }
}

// ============================================
// UpdateRSSItemRequest
// ============================================
export class UpdateRSSItemRequest implements Message {
    private itemId: string = '';
    private title: string = '';
    private link: string = '';
    private description: string = '';
    private publishedDate: string = '';
    private category?: Category;
    private author?: Author;

    static displayName = 'UpdateRSSItemRequest';

    constructor(data?: Partial<{
        itemId: string;
        title: string;
        link: string;
        description: string;
        publishedDate: string;
        category?: Category;
        author?: Author;
    }>) {
        if (data) {
            this.itemId = data.itemId ?? '';
            this.title = data.title ?? '';
            this.link = data.link ?? '';
            this.description = data.description ?? '';
            this.publishedDate = data.publishedDate ?? '';
            this.category = data.category;
            this.author = data.author;
        }
    }

    getItemId(): string { return this.itemId; }
    setItemId(value: string): UpdateRSSItemRequest { this.itemId = value; return this; }

    getTitle(): string { return this.title; }
    setTitle(value: string): UpdateRSSItemRequest { this.title = value; return this; }

    getLink(): string { return this.link; }
    setLink(value: string): UpdateRSSItemRequest { this.link = value; return this; }

    getDescription(): string { return this.description; }
    setDescription(value: string): UpdateRSSItemRequest { this.description = value; return this; }

    getPublishedDate(): string { return this.publishedDate; }
    setPublishedDate(value: string): UpdateRSSItemRequest { this.publishedDate = value; return this; }

    getCategory(): Category | undefined { return this.category; }
    setCategory(value?: Category): UpdateRSSItemRequest { this.category = value; return this; }

    getAuthor(): Author | undefined { return this.author; }
    setAuthor(value?: Author): UpdateRSSItemRequest { this.author = value; return this; }

    serializeBinary(): Uint8Array { return new Uint8Array(); }

    toObject(): Record<string, any> {
        return {
            itemId: this.itemId,
            title: this.title,
            link: this.link,
            description: this.description,
            publishedDate: this.publishedDate,
            category: this.category?.toObject(),
            author: this.author?.toObject(),
        };
    }

    static deserializeBinary(bytes: Uint8Array): UpdateRSSItemRequest {
        return new UpdateRSSItemRequest();
    }
}

// ============================================
// DeleteRSSItemRequest
// ============================================
export class DeleteRSSItemRequest implements Message {
    private itemId: string = '';

    static displayName = 'DeleteRSSItemRequest';

    constructor(data?: Partial<{ itemId: string }>) {
        if (data) {
            this.itemId = data.itemId ?? '';
        }
    }

    getItemId(): string { return this.itemId; }
    setItemId(value: string): DeleteRSSItemRequest { this.itemId = value; return this; }

    serializeBinary(): Uint8Array { return new Uint8Array(); }

    toObject(): Record<string, any> {
        return { itemId: this.itemId };
    }

    static deserializeBinary(bytes: Uint8Array): DeleteRSSItemRequest {
        return new DeleteRSSItemRequest();
    }
}

// ============================================
// DeleteRSSItemResponse
// ============================================
export class DeleteRSSItemResponse implements Message {
    private success: boolean = false;
    private message: string = '';

    static displayName = 'DeleteRSSItemResponse';

    constructor(data?: Partial<{ success: boolean; message: string }>) {
        if (data) {
            this.success = data.success ?? false;
            this.message = data.message ?? '';
        }
    }

    getSuccess(): boolean { return this.success; }
    setSuccess(value: boolean): DeleteRSSItemResponse { this.success = value; return this; }

    getMessage(): string { return this.message; }
    setMessage(value: string): DeleteRSSItemResponse { this.message = value; return this; }

    serializeBinary(): Uint8Array { return new Uint8Array(); }

    toObject(): Record<string, any> {
        return {
            success: this.success,
            message: this.message,
        };
    }

    static deserializeBinary(bytes: Uint8Array): DeleteRSSItemResponse {
        return new DeleteRSSItemResponse();
    }
}

// ============================================
// Development Warning
// ============================================
if (typeof window !== 'undefined' && process.env.NODE_ENV === 'development') {
    console.warn(
        '⚠️ Using gRPC placeholder messages.\n' +
        '   Run `npm run grpc:generate` to generate real types from proto files.'
    );
}