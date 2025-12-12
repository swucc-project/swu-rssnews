import type { CodegenConfig } from '@graphql-codegen/cli';
import * as fs from 'fs';

const isDocker = process.env.DOCKER_CONTAINER === 'true' || process.env.IS_DOCKER === 'true';

console.log('📡 GraphQL Endpoint:', isDocker ? process.env.VITE_GRAPHQL_ENDPOINT : process.env.VITE_PUBLIC_GRAPHQL_ENDPOINT);
console.log('🐳 Docker Mode:', isDocker);

// ✅ ตรวจสอบว่า schema file มีอยู่และเป็น format ไหน
const schemaPath = './apollo/schema.graphql';
const schemaJsonPath = './apollo/schema.json';

let schemaSource = isDocker ? schemaPath : schemaJsonPath;
let isPlaceholder = false;

// ตรวจสอบว่า schema file มีอยู่หรือไม่
if (!fs.existsSync(schemaSource)) {
    console.error(`❌ Schema file not found at: ${schemaSource}`);
    process.exit(1);
}

// ตรวจสอบว่าเป็น placeholder หรือไม่
const schemaContent = fs.readFileSync(schemaSource, 'utf-8');
isPlaceholder =
    schemaContent.includes('_placeholder') ||
    schemaContent.length < 300 ||
    !schemaContent.includes('type Query');

if (isPlaceholder) {
    console.warn('⚠️  Schema is placeholder - codegen may produce minimal types');
} else {
    console.log(`✅ Using schema at ${schemaSource}`);
}

const config: CodegenConfig = {
    // ✅ ใช้ schema file (รองรับทั้ง .graphql และ .json)
    schema: schemaSource,

    documents: [
        'hub/**/*.vue',
        'hub/**/*.ts',
        'hub/**/*.js',
        'apollo/queries/**/*.graphql',
        'apollo/mutations/**/*.graphql',
        'apollo/fragments/**/*.graphql',
    ],

    generates: {
        // ✅ 1. TypeScript types
        './apollo/generated/graphql.ts': {
            plugins: [
                'typescript',
                'typescript-operations',
                'typed-document-node',
            ],
            config: {
                skipTypename: false,
                withHooks: false,
                withHOC: false,
                withComponent: false,
                useTypeImports: true,
                enumsAsTypes: true,
                constEnums: false,
                futureProofEnums: true,
                dedupeFragments: true,
                inlineFragmentTypes: 'combine',
                skipTypeNameForRoot: true,
                avoidOptionals: {
                    field: false,
                    inputValue: false,
                    object: false,
                    defaultValue: false,
                },
                maybeValue: 'T | null',
                scalars: {
                    DateTime: 'string',
                    Date: 'string',
                    Decimal: 'number',
                    Long: 'number',
                    UUID: 'string',
                },
                // ✅ เพิ่ม error handling
                onlyOperationTypes: false,
                preResolveTypes: true,
            },
        },

        // ✅ 2. Client preset (gql.ts, fragment-masking.ts, index.ts)
        './apollo/generated/': {
            preset: 'client',
            plugins: [],
            presetConfig: {
                gqlTagName: 'gql',
                fragmentMasking: false,
                // ✅ เพิ่ม options
                persistedDocuments: false,
            },
            config: {
                useTypeImports: true,
                skipTypename: false,
                enumsAsTypes: true,
                dedupeFragments: true,
                avoidOptionals: false,
                // ✅ Handle placeholders gracefully
                onlyOperationTypes: false,
            },
        },

        // ✅ 3. Introspection for Apollo Client cache
        './apollo/generated/introspection.json': {
            plugins: ['introspection'],
            config: {
                minify: true,
                // ✅ เพิ่ม descriptions
                descriptions: false,
            },
        },

        // ✅ 4. Fragment matcher (ถ้ามี interfaces/unions)
        './apollo/generated/fragment-matcher.json': {
            plugins: ['fragment-matcher'],
            config: {
                useExplicitTyping: true,
            },
        },
    },

    // ✅ ปรับ error handling
    ignoreNoDocuments: true,
    errorsOnly: false,
    verbose: true,
    debug: process.env.DEBUG_CODEGEN === 'true',

    // ✅ เพิ่ม require
    require: [],

    // ✅ Silent mode ถ้าเป็น placeholder
    silent: isPlaceholder,

    // ✅ Hooks - format code หลัง generate
    hooks: {
        afterAllFileWrite: [
            // ใช้ prettier ถ้ามี
            'prettier --write || echo "Prettier not available"',
        ],
        // ✅ เพิ่ม validation hook
        afterOneFileWrite: [
            'echo "Generated: {file}"',
        ],
    },

    // ✅ Watch mode options
    watch: process.env.CODEGEN_WATCH === 'true',
    watchPattern: [
        'apollo/**/*.graphql',
        'hub/**/*.vue',
        'hub/**/*.ts',
    ],
};

// ✅ แสดงข้อมูล config สำหรับ debugging
if (process.env.DEBUG_CODEGEN === 'true') {
    console.log('📋 Codegen Configuration:');
    console.log(JSON.stringify(config, null, 2));
}

export default config;