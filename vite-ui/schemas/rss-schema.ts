import { z } from 'zod';
import { extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi';

// Extend Zod with OpenAPI
extendZodWithOpenApi(z);

// Base Schemas
export const ItemSchema = z.object({
    id: z.number().int().positive().openapi({
        description: 'ID ของข่าว/กิจกรรม',
        example: 1
    }),
    title: z.string().min(1).max(500).openapi({
        description: 'หัวข้อข่าว/กิจกรรม',
        example: 'ข่าวประกาศมหาวิทยาลัย'
    }),
    description: z.string().openapi({
        description: 'รายละเอียดของข่าว',
        example: 'รายละเอียดข่าวสาร...'
    }),
    link: z.string().url().openapi({
        description: 'ลิงก์ไปยังข่าวเต็ม',
        example: 'https://news.swu.ac.th/article/123'
    }),
    pubDate: z.string().datetime().openapi({
        description: 'วันที่เผยแพร่',
        example: '2024-01-01T00:00:00Z'
    }),
    categoryId: z.number().int().positive().optional().openapi({
        description: 'ID ของหมวดหมู่',
        example: 1
    }),
    authorId: z.number().int().positive().optional().openapi({
        description: 'ID ของผู้เขียน',
        example: 1
    }),
    imageUrl: z.string().url().optional().openapi({
        description: 'URL รูปภาพประกอบข่าว',
        example: 'https://news.swu.ac.th/images/news.jpg'
    })
}).openapi('Item');

export const CategorySchema = z.object({
    id: z.number().int().positive().openapi({
        description: 'ID ของหมวดหมู่',
        example: 1
    }),
    name: z.string().min(1).max(200).openapi({
        description: 'ชื่อหมวดหมู่',
        example: 'ข่าวประชาสัมพันธ์'
    }),
    description: z.string().optional().openapi({
        description: 'รายละเอียดหมวดหมู่',
        example: 'หมวดหมู่สำหรับข่าวประชาสัมพันธ์ทั่วไป'
    })
}).openapi('Category');

export const AuthorSchema = z.object({
    id: z.number().int().positive().openapi({
        description: 'ID ของผู้เขียน',
        example: 1
    }),
    name: z.string().min(1).max(200).openapi({
        description: 'ชื่อผู้เขียน',
        example: 'ฝ่ายสารสนเทศ มศว'
    }),
    email: z.string().email().openapi({
        description: 'อีเมลผู้เขียน',
        example: 'info@swu.ac.th'
    })
}).openapi('Author');

// Request Schemas
export const CreateItemSchema = ItemSchema.omit({ id: true }).openapi('CreateItemRequest');
export const UpdateItemSchema = ItemSchema.partial().omit({ id: true }).openapi('UpdateItemRequest');

export const CreateCategorySchema = CategorySchema.omit({ id: true }).openapi('CreateCategoryRequest');
export const UpdateCategorySchema = CategorySchema.partial().omit({ id: true }).openapi('UpdateCategoryRequest');

export const CreateAuthorSchema = AuthorSchema.omit({ id: true }).openapi('CreateAuthorRequest');
export const UpdateAuthorSchema = AuthorSchema.partial().omit({ id: true }).openapi('UpdateAuthorRequest');

// Response Schemas
export const ItemListResponseSchema = z.object({
    items: z.array(ItemSchema),
    total: z.number().int().nonnegative(),
    page: z.number().int().positive(),
    pageSize: z.number().int().positive()
}).openapi('ItemListResponse');

export const ErrorResponseSchema = z.object({
    message: z.string().openapi({
        description: 'ข้อความแสดงข้อผิดพลาด',
        example: 'ไม่พบข้อมูล'
    }),
    code: z.string().optional().openapi({
        description: 'รหัสข้อผิดพลาด',
        example: 'NOT_FOUND'
    }),
    details: z.record(z.any()).optional().openapi({
        description: 'รายละเอียดเพิ่มเติมของข้อผิดพลาด'
    })
}).openapi('ErrorResponse');

// Query Parameters
export const PaginationQuerySchema = z.object({
    page: z.number().int().positive().default(1).openapi({
        description: 'หน้าที่ต้องการ',
        example: 1
    }),
    pageSize: z.number().int().positive().max(100).default(10).openapi({
        description: 'จำนวนรายการต่อหน้า',
        example: 10
    })
}).openapi('PaginationQuery');

export const ItemFilterQuerySchema = PaginationQuerySchema.extend({
    categoryId: z.number().int().positive().optional().openapi({
        description: 'กรองตามหมวดหมู่',
        example: 1
    }),
    authorId: z.number().int().positive().optional().openapi({
        description: 'กรองตามผู้เขียน',
        example: 1
    }),
    search: z.string().optional().openapi({
        description: 'ค้นหาจากชื่อหรือรายละเอียด',
        example: 'มหาวิทยาลัย'
    })
}).openapi('ItemFilterQuery');

// Language Header
export const AcceptLanguageSchema = z.enum(['th-TH', 'en-US']).default('th-TH').openapi({
    description: 'ระบุภาษาที่ต้องการในการตอบกลับจาก Server\n\nรองรับภาษา:\n- `th-TH` - ภาษาไทย (ค่าเริ่มต้น)\n- `en-US` - ภาษาอังกฤษ',
    example: 'th-TH'
});