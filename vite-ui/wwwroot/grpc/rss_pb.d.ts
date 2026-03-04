import * as jspb from 'google-protobuf'

import * as google_protobuf_timestamp_pb from 'google-protobuf/google/protobuf/timestamp_pb'; // proto import: "google/protobuf/timestamp.proto"
import * as google_protobuf_empty_pb from 'google-protobuf/google/protobuf/empty_pb'; // proto import: "google/protobuf/empty.proto"


export class Item extends jspb.Message {
  getItemId(): string;
  setItemId(value: string): Item;

  getTitle(): string;
  setTitle(value: string): Item;

  getLink(): string;
  setLink(value: string): Item;

  getDescription(): string;
  setDescription(value: string): Item;

  getPublishedDate(): google_protobuf_timestamp_pb.Timestamp | undefined;
  setPublishedDate(value?: google_protobuf_timestamp_pb.Timestamp): Item;
  hasPublishedDate(): boolean;
  clearPublishedDate(): Item;

  getCategory(): Category | undefined;
  setCategory(value?: Category): Item;
  hasCategory(): boolean;
  clearCategory(): Item;

  getAuthor(): Author | undefined;
  setAuthor(value?: Author): Item;
  hasAuthor(): boolean;
  clearAuthor(): Item;

  serializeBinary(): Uint8Array;
  toObject(includeInstance?: boolean): Item.AsObject;
  static toObject(includeInstance: boolean, msg: Item): Item.AsObject;
  static serializeBinaryToWriter(message: Item, writer: jspb.BinaryWriter): void;
  static deserializeBinary(bytes: Uint8Array): Item;
  static deserializeBinaryFromReader(message: Item, reader: jspb.BinaryReader): Item;
}

export namespace Item {
  export type AsObject = {
    itemId: string,
    title: string,
    link: string,
    description: string,
    publishedDate?: google_protobuf_timestamp_pb.Timestamp.AsObject,
    category?: Category.AsObject,
    author?: Author.AsObject,
  }
}

export class Category extends jspb.Message {
  getId(): number;
  setId(value: number): Category;

  getName(): string;
  setName(value: string): Category;

  serializeBinary(): Uint8Array;
  toObject(includeInstance?: boolean): Category.AsObject;
  static toObject(includeInstance: boolean, msg: Category): Category.AsObject;
  static serializeBinaryToWriter(message: Category, writer: jspb.BinaryWriter): void;
  static deserializeBinary(bytes: Uint8Array): Category;
  static deserializeBinaryFromReader(message: Category, reader: jspb.BinaryReader): Category;
}

export namespace Category {
  export type AsObject = {
    id: number,
    name: string,
  }
}

export class Author extends jspb.Message {
  getAuthorId(): string;
  setAuthorId(value: string): Author;

  getFirstname(): string;
  setFirstname(value: string): Author;

  getLastname(): string;
  setLastname(value: string): Author;

  serializeBinary(): Uint8Array;
  toObject(includeInstance?: boolean): Author.AsObject;
  static toObject(includeInstance: boolean, msg: Author): Author.AsObject;
  static serializeBinaryToWriter(message: Author, writer: jspb.BinaryWriter): void;
  static deserializeBinary(bytes: Uint8Array): Author;
  static deserializeBinaryFromReader(message: Author, reader: jspb.BinaryReader): Author;
}

export namespace Author {
  export type AsObject = {
    authorId: string,
    firstname: string,
    lastname: string,
  }
}

export class AddRSSItemRequest extends jspb.Message {
  getTitle(): string;
  setTitle(value: string): AddRSSItemRequest;

  getLink(): string;
  setLink(value: string): AddRSSItemRequest;

  getDescription(): string;
  setDescription(value: string): AddRSSItemRequest;

  getPublishedDate(): google_protobuf_timestamp_pb.Timestamp | undefined;
  setPublishedDate(value?: google_protobuf_timestamp_pb.Timestamp): AddRSSItemRequest;
  hasPublishedDate(): boolean;
  clearPublishedDate(): AddRSSItemRequest;

  getCategory(): Category | undefined;
  setCategory(value?: Category): AddRSSItemRequest;
  hasCategory(): boolean;
  clearCategory(): AddRSSItemRequest;

  getAuthor(): Author | undefined;
  setAuthor(value?: Author): AddRSSItemRequest;
  hasAuthor(): boolean;
  clearAuthor(): AddRSSItemRequest;

  serializeBinary(): Uint8Array;
  toObject(includeInstance?: boolean): AddRSSItemRequest.AsObject;
  static toObject(includeInstance: boolean, msg: AddRSSItemRequest): AddRSSItemRequest.AsObject;
  static serializeBinaryToWriter(message: AddRSSItemRequest, writer: jspb.BinaryWriter): void;
  static deserializeBinary(bytes: Uint8Array): AddRSSItemRequest;
  static deserializeBinaryFromReader(message: AddRSSItemRequest, reader: jspb.BinaryReader): AddRSSItemRequest;
}

export namespace AddRSSItemRequest {
  export type AsObject = {
    title: string,
    link: string,
    description: string,
    publishedDate?: google_protobuf_timestamp_pb.Timestamp.AsObject,
    category?: Category.AsObject,
    author?: Author.AsObject,
  }
}

export class GetRSSItemsRequest extends jspb.Message {
  getItemId(): string;
  setItemId(value: string): GetRSSItemsRequest;

  serializeBinary(): Uint8Array;
  toObject(includeInstance?: boolean): GetRSSItemsRequest.AsObject;
  static toObject(includeInstance: boolean, msg: GetRSSItemsRequest): GetRSSItemsRequest.AsObject;
  static serializeBinaryToWriter(message: GetRSSItemsRequest, writer: jspb.BinaryWriter): void;
  static deserializeBinary(bytes: Uint8Array): GetRSSItemsRequest;
  static deserializeBinaryFromReader(message: GetRSSItemsRequest, reader: jspb.BinaryReader): GetRSSItemsRequest;
}

export namespace GetRSSItemsRequest {
  export type AsObject = {
    itemId: string,
  }
}

export class GetRSSItemResponse extends jspb.Message {
  getItemsList(): Array<Item>;
  setItemsList(value: Array<Item>): GetRSSItemResponse;
  clearItemsList(): GetRSSItemResponse;
  addItems(value?: Item, index?: number): Item;

  serializeBinary(): Uint8Array;
  toObject(includeInstance?: boolean): GetRSSItemResponse.AsObject;
  static toObject(includeInstance: boolean, msg: GetRSSItemResponse): GetRSSItemResponse.AsObject;
  static serializeBinaryToWriter(message: GetRSSItemResponse, writer: jspb.BinaryWriter): void;
  static deserializeBinary(bytes: Uint8Array): GetRSSItemResponse;
  static deserializeBinaryFromReader(message: GetRSSItemResponse, reader: jspb.BinaryReader): GetRSSItemResponse;
}

export namespace GetRSSItemResponse {
  export type AsObject = {
    itemsList: Array<Item.AsObject>,
  }
}

export class UpdateRSSItemRequest extends jspb.Message {
  getItemId(): string;
  setItemId(value: string): UpdateRSSItemRequest;

  getTitle(): string;
  setTitle(value: string): UpdateRSSItemRequest;

  getLink(): string;
  setLink(value: string): UpdateRSSItemRequest;

  getDescription(): string;
  setDescription(value: string): UpdateRSSItemRequest;

  getPublishedDate(): google_protobuf_timestamp_pb.Timestamp | undefined;
  setPublishedDate(value?: google_protobuf_timestamp_pb.Timestamp): UpdateRSSItemRequest;
  hasPublishedDate(): boolean;
  clearPublishedDate(): UpdateRSSItemRequest;

  getCategory(): Category | undefined;
  setCategory(value?: Category): UpdateRSSItemRequest;
  hasCategory(): boolean;
  clearCategory(): UpdateRSSItemRequest;

  getAuthor(): Author | undefined;
  setAuthor(value?: Author): UpdateRSSItemRequest;
  hasAuthor(): boolean;
  clearAuthor(): UpdateRSSItemRequest;

  serializeBinary(): Uint8Array;
  toObject(includeInstance?: boolean): UpdateRSSItemRequest.AsObject;
  static toObject(includeInstance: boolean, msg: UpdateRSSItemRequest): UpdateRSSItemRequest.AsObject;
  static serializeBinaryToWriter(message: UpdateRSSItemRequest, writer: jspb.BinaryWriter): void;
  static deserializeBinary(bytes: Uint8Array): UpdateRSSItemRequest;
  static deserializeBinaryFromReader(message: UpdateRSSItemRequest, reader: jspb.BinaryReader): UpdateRSSItemRequest;
}

export namespace UpdateRSSItemRequest {
  export type AsObject = {
    itemId: string,
    title: string,
    link: string,
    description: string,
    publishedDate?: google_protobuf_timestamp_pb.Timestamp.AsObject,
    category?: Category.AsObject,
    author?: Author.AsObject,
  }
}

export class DeleteRSSItemRequest extends jspb.Message {
  getItemId(): string;
  setItemId(value: string): DeleteRSSItemRequest;

  serializeBinary(): Uint8Array;
  toObject(includeInstance?: boolean): DeleteRSSItemRequest.AsObject;
  static toObject(includeInstance: boolean, msg: DeleteRSSItemRequest): DeleteRSSItemRequest.AsObject;
  static serializeBinaryToWriter(message: DeleteRSSItemRequest, writer: jspb.BinaryWriter): void;
  static deserializeBinary(bytes: Uint8Array): DeleteRSSItemRequest;
  static deserializeBinaryFromReader(message: DeleteRSSItemRequest, reader: jspb.BinaryReader): DeleteRSSItemRequest;
}

export namespace DeleteRSSItemRequest {
  export type AsObject = {
    itemId: string,
  }
}

export class DeleteRSSItemResponse extends jspb.Message {
  getSuccess(): boolean;
  setSuccess(value: boolean): DeleteRSSItemResponse;

  serializeBinary(): Uint8Array;
  toObject(includeInstance?: boolean): DeleteRSSItemResponse.AsObject;
  static toObject(includeInstance: boolean, msg: DeleteRSSItemResponse): DeleteRSSItemResponse.AsObject;
  static serializeBinaryToWriter(message: DeleteRSSItemResponse, writer: jspb.BinaryWriter): void;
  static deserializeBinary(bytes: Uint8Array): DeleteRSSItemResponse;
  static deserializeBinaryFromReader(message: DeleteRSSItemResponse, reader: jspb.BinaryReader): DeleteRSSItemResponse;
}

export namespace DeleteRSSItemResponse {
  export type AsObject = {
    success: boolean,
  }
}

