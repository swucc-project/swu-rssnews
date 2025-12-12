import { OpenAPIRegistry, OpenApiGeneratorV3 } from '@asteasolutions/zod-to-openapi';
import { writeFileSync } from 'fs';
import { join } from 'path';
import { z } from 'zod';
import {
    ItemSchema,
    CategorySchema,
    AuthorSchema,
    CreateItemSchema,
    UpdateItemSchema,
    ItemListResponseSchema,
    ErrorResponseSchema,
    PaginationQuerySchema,
    ItemFilterQuerySchema,
    AcceptLanguageSchema
} from '../schemas/rss-schema.js';

const LanguageHeaders = z.object({
    'Accept-Language': AcceptLanguageSchema,
});
// สร้าง registry
const registry = new OpenAPIRegistry();

// Register schemas
registry.register('Item', ItemSchema);
registry.register('Category', CategorySchema);
registry.register('Author', AuthorSchema);
registry.register('CreateItemRequest', CreateItemSchema);
registry.register('UpdateItemRequest', UpdateItemSchema);
registry.register('ItemListResponse', ItemListResponseSchema);
registry.register('ErrorResponse', ErrorResponseSchema);

// Register paths
registry.registerPath({
    method: 'get',
    path: '/api/items',
    tags: ['Items'],
    summary: 'รายการข่าว/กิจกรรมทั้งหมด',
    description: 'ดึงข้อมูลรายการข่าวและกิจกรรมพร้อมการกรองและ pagination',
    request: {
        headers: LanguageHeaders,
        query: z.object({
            page: PaginationQuerySchema.shape.page,
            pageSize: PaginationQuerySchema.shape.pageSize,
            categoryId: ItemFilterQuerySchema.shape.categoryId,
            search: ItemFilterQuerySchema.shape.search
        }),
    },
    responses: {
        200: {
            description: 'สำเร็จ',
            content: {
                'application/json': {
                    schema: ItemListResponseSchema
                }
            }
        },
        400: {
            description: 'ข้อมูลไม่ถูกต้อง',
            content: {
                'application/json': {
                    schema: ErrorResponseSchema
                }
            }
        }
    }
});

registry.registerPath({
    method: 'post',
    path: '/api/items',
    tags: ['Items'],
    summary: 'สร้างข่าว/กิจกรรมใหม่',
    description: 'ต้องมีสิทธิ์ "Admin" หรือ "Editor"',
    request: {
        headers: LanguageHeaders,
        body: {
            content: {
                'application/json': {
                    schema: CreateItemSchema
                }
            },
            required: true
        }
    },
    responses: {
        '201': {
            description: 'สร้างสำเร็จ',
            content: { 'application/json': { schema: ItemSchema } }
        },
        '401': { description: 'Unauthorized - ต้องเข้าสู่ระบบ' }, // ตาม AuthorizationOperationFilter
        '403': { description: 'Forbidden - ไม่มีสิทธิ์เข้าถึง' }, // ตาม AuthorizationOperationFilter
        '500': { description: 'Server Error' }
    },
    // *** เพิ่มส่วน security นี้ ***
    security: [
        {
            cookieAuth: [] // อ้างอิงถึง cookieAuth ที่นิยามไว้ใน components: securitySchemes
        }
    ]
});

registry.registerPath({
    method: 'post',
    path: '/api/items',
    tags: ['Items'],
    summary: 'สร้างข่าว/กิจกรรมใหม่',
    description: 'เพิ่มข่าวหรือกิจกรรมใหม่เข้าสู่ระบบ',
    request: {
        body: {
            content: {
                'application/json': {
                    schema: CreateItemSchema
                }
            }
        },
        headers: LanguageHeaders
    },
    responses: {
        201: {
            description: 'สร้างสำเร็จ',
            content: {
                'application/json': {
                    schema: ItemSchema
                }
            }
        },
        400: {
            description: 'ข้อมูลไม่ถูกต้อง',
            content: {
                'application/json': {
                    schema: ErrorResponseSchema
                }
            }
        },
        401: {
            description: 'Unauthorized - ต้องเข้าสู่ระบบ'
        },
        403: {
            description: 'Forbidden - ไม่มีสิทธิ์เข้าถึง'
        }
    },
    security: [{ cookieAuth: [] }]
});

registry.registerPath({
    method: 'get',
    path: '/api/items/{id}',
    tags: ['Items'],
    summary: 'ดูรายละเอียดข่าว/กิจกรรม',
    description: 'ดึงข้อมูลรายละเอียดของข่าว/กิจกรรมตาม ID',
    request: {
        params: z.object({
            id: z.number().int().positive()
        }),
        headers: LanguageHeaders
    },
    responses: {
        200: {
            description: 'สำเร็จ',
            content: {
                'application/json': {
                    schema: ItemSchema
                }
            }
        },
        404: {
            description: 'ไม่พบข้อมูล',
            content: {
                'application/json': {
                    schema: ErrorResponseSchema
                }
            }
        }
    }
});

registry.registerPath({
    method: 'put',
    path: '/api/items/{id}',
    tags: ['Items'],
    summary: 'แก้ไขข่าว/กิจกรรม',
    description: 'อัพเดทข้อมูลข่าว/กิจกรรม',
    request: {
        params: z.object({
            id: z.number().int().positive()
        }),
        body: {
            content: {
                'application/json': {
                    schema: UpdateItemSchema
                }
            }
        },
        headers: LanguageHeaders
    },
    responses: {
        200: {
            description: 'แก้ไขสำเร็จ',
            content: {
                'application/json': {
                    schema: ItemSchema
                }
            }
        },
        400: {
            description: 'ข้อมูลไม่ถูกต้อง'
        },
        401: {
            description: 'Unauthorized - ต้องเข้าสู่ระบบ'
        },
        403: {
            description: 'Forbidden - ไม่มีสิทธิ์เข้าถึง'
        },
        404: {
            description: 'ไม่พบข้อมูล'
        }
    },
    security: [{ cookieAuth: [] }]
});

registry.registerPath({
    method: 'delete',
    path: '/api/items/{id}',
    tags: ['Items'],
    summary: 'ลบข่าว/กิจกรรม',
    description: 'ลบข่าว/กิจกรรมออกจากระบบ',
    request: {
        params: z.object({
            id: z.number().int().positive()
        }),
        headers: LanguageHeaders
    },
    responses: {
        204: {
            description: 'ลบสำเร็จ'
        },
        401: {
            description: 'Unauthorized - ต้องเข้าสู่ระบบ'
        },
        403: {
            description: 'Forbidden - ไม่มีสิทธิ์เข้าถึง'
        },
        404: {
            description: 'ไม่พบข้อมูล'
        }
    },
    security: [{ cookieAuth: [] }]
});

registry.registerPath({
    method: 'get',
    path: '/api/categories',
    tags: ['Categories'],
    summary: 'รายการหมวดหมู่ทั้งหมด',
    request: {
        headers: LanguageHeaders
    },
    responses: {
        200: {
            description: 'สำเร็จ',
            content: {
                'application/json': {
                    schema: z.array(CategorySchema)
                }
            }
        }
    }
});

registry.registerPath({
    method: 'post',
    path: '/api/categories',
    tags: ['Categories'],
    summary: 'สร้างหมวดหมู่ใหม่',
    request: {
        body: {
            content: {
                'application/json': {
                    schema: CategorySchema.omit({ id: true })
                }
            }
        },
        headers: LanguageHeaders
    },
    responses: {
        201: {
            description: 'สร้างสำเร็จ',
            content: {
                'application/json': {
                    schema: CategorySchema
                }
            }
        },
        401: {
            description: 'Unauthorized'
        },
        403: {
            description: 'Forbidden'
        }
    },
    security: [{ cookieAuth: [] }]
});

// Generate OpenAPI document
const generator = new OpenApiGeneratorV3(registry.definitions);

const openApiDocument = generator.generateDocument({
    openapi: '3.0.0',
    info: {
        title: 'API ระบบข่าวและกิจกรรม มหาวิทยาลัยศรีนครินทรวิโรฒ',
        version: '1.0.0',
        description: `
# ระบบจัดการข่าวสารและกิจกรรม มศว

API นี้รองรับการทำงานหลายรูปแบบ:

## รูปแบบการเชื่อมต่อ
- **REST API** - สำหรับ CRUD operations
- **GraphQL** - สำหรับ query ข้อมูลแบบ flexible ที่ \`/graphql\`
- **gRPC** - สำหรับ high-performance communication

## การ Authentication
ใช้ Cookie-based authentication ผ่าน ServiceStack
- Cookie Name: \`swu-news\`
- Login Endpoint: \`/auth/credentials\`

## รองรับหลายภาษา
ระบุภาษาผ่าน Header \`Accept-Language\`:
- \`th-TH\` - ภาษาไทย (ค่าเริ่มต้น)
- \`en-US\` - ภาษาอังกฤษ

## Rate Limiting
- 100 requests ต่อนาทีต่อผู้ใช้
- ใช้ชื่อผู้ใช้หรือ Host เป็น partition key
        `,
        contact: {
            name: 'ฝ่ายระบบสารสนเทศ มหาวิทยาลัยศรีนครินทรวิโรฒ',
            email: 'pavarudh@g.swu.ac.th',
            url: 'https://news.swu.ac.th'
        },
        license: {
            name: 'มหาวิทยาลัยศรีนครินทรวิโรฒ',
            url: 'https://www.swu.ac.th'
        }
    },
    servers: [
        {
            url: 'https://news.swu.ac.th',
            description: 'Production Server'
        },
        {
            url: 'https://localhost:5001',
            description: 'Development Server'
        }
    ],
    components: {
        securitySchemes: {
            cookieAuth: {
                type: 'apiKey',
                in: 'cookie',
                name: 'swu-news',
                description: 'Cookie Authentication ผ่าน ServiceStack\n\nใช้ endpoint `/auth/credentials` เพื่อเข้าสู่ระบบ'
            }
        }
    },
    tags: [
        {
            name: 'Items',
            description: 'การจัดการข่าวและกิจกรรม'
        },
        {
            name: 'Categories',
            description: 'การจัดการหมวดหมู่'
        },
        {
            name: 'Authors',
            description: 'การจัดการผู้เขียน'
        }
    ]
});

// บันทึกเป็น JSON
const outputPath = join(process.cwd(), '../aspnetcore/wwwroot/manual-api.json');
writeFileSync(outputPath, JSON.stringify(openApiDocument, null, 2));

console.log('โœ… Generated OpenAPI documentation at:', outputPath);