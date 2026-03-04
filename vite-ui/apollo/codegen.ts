import type { CodegenConfig } from '@graphql-codegen/cli';
import fs from 'fs';
import path from 'path';

const SCHEMA_FILE = './apollo/schema.graphql';
const GENERATED_DIR = './apollo/generated';
const GRAPHQL_ENDPOINT = process.env.GRAPHQL_ENDPOINT ||
    process.env.VITE_GRAPHQL_ENDPOINT ||
    'http://aspdotnetweb:5000/graphql';

// ═══════════════════════════════════════════════════════════
// Schema Validation - More Robust
// ═══════════════════════════════════════════════════════════
function validateSchemaFile(filePath: string): { valid: boolean; reason: string; size: number } {
    if (!fs.existsSync(filePath)) {
        return { valid: false, reason: 'File does not exist', size: 0 };
    }

    const content = fs.readFileSync(filePath, 'utf8');
    const stats = fs.statSync(filePath);
    const size = stats.size;

    // ต้องมีขนาดอย่างน้อย 500 bytes (placeholder schema ควรมีอย่างน้อยนี้)
    if (size < 500) {
        return { valid: false, reason: `File too small: ${size} bytes`, size };
    }

    // ต้องมี type Query
    if (!content.includes('type Query')) {
        return { valid: false, reason: 'Missing type Query', size };
    }

    // ต้องมี schema definition หรือ Query type ที่มี field
    const hasSchemaDefinition = content.includes('schema {') ||
        (content.includes('type Query') && content.match(/type Query\s*\{[\s\S]*?\}/));

    if (!hasSchemaDefinition) {
        return { valid: false, reason: 'Missing schema definition or Query fields', size };
    }

    // ไม่ควรมี error message
    if (content.includes('Missing required type') || content.includes('# ERROR:')) {
        return { valid: false, reason: 'Schema contains error markers', size };
    }

    // Check for at least one field in Query
    const queryMatch = content.match(/type Query\s*\{([\s\S]*?)\}/);
    if (queryMatch) {
        const queryBody = queryMatch;
        // Should have at least one field (not just comments)
        const hasFields = queryBody.split('\n').some(line => {
            const trimmed = line.trim();
            return trimmed.length > 0 &&
                !trimmed.startsWith('#') &&
                !trimmed.startsWith('"""') &&
                trimmed.includes(':');
        });

        if (!hasFields) {
            return { valid: false, reason: 'Query type has no fields', size };
        }
    }

    return { valid: true, reason: 'Schema is valid', size };
}

// ═══════════════════════════════════════════════════════════
// Get Schema Source with Fallback
// ═══════════════════════════════════════════════════════════
function getSchemaSource(): string | { [url: string]: any } {
    const useLocal = process.env.USE_LOCAL_SCHEMA !== 'false';
    const forceRemote = process.env.FORCE_REMOTE_SCHEMA === 'true';

    if (!forceRemote && useLocal) {
        const validation = validateSchemaFile(SCHEMA_FILE);

        if (validation.valid) {
            console.log(`✅ Using local schema: ${SCHEMA_FILE} (${validation.size} bytes)`);
            return SCHEMA_FILE;
        } else {
            console.log(`⚠️ Local schema invalid: ${validation.reason}`);
            console.log(`   Falling back to remote endpoint...`);
        }
    }

    console.log(`🌐 Using remote schema: ${GRAPHQL_ENDPOINT}`);
    return {
        [GRAPHQL_ENDPOINT]: {
            headers: {
                'Content-Type': 'application/json',
                'X-Allow-Introspection': 'true',
            },
        },
    };
}

// ═══════════════════════════════════════════════════════════
// Ensure Generated Directory Exists
// ═══════════════════════════════════════════════════════════
function ensureGeneratedDir(): void {
    const generatedPath = path.resolve(GENERATED_DIR);
    if (!fs.existsSync(generatedPath)) {
        fs.mkdirSync(generatedPath, { recursive: true });
        console.log(`📁 Created generated directory: ${generatedPath}`);
    }
}

// Run setup
ensureGeneratedDir();

// ═══════════════════════════════════════════════════════════
// Codegen Configuration
// ═══════════════════════════════════════════════════════════
const config: CodegenConfig = {
    schema: getSchemaSource(),
    ignoreNoDocuments: true,
    documents: [
        './hub/**/*.{ts,tsx,vue}',
        './apollo/**/*.graphql',
        './apollo/**/*.gql',
        '!apollo/generated/**/*',
        '!**/node_modules/**',
    ],
    generates: {
        [GENERATED_DIR + '/']: {
            preset: 'client',
            presetConfig: {
                gqlTagName: 'gql',
                fragmentMasking: {
                    unmaskFunctionName: 'getFragmentData',
                },
                dedupeFragments: true,
            },
            config: {
                scalars: {
                    DateTime: 'string',
                    Date: 'string',
                    Time: 'string',
                    JSON: 'Record<string, any>',
                    Upload: 'File',
                    UUID: 'string',
                    Decimal: 'number',
                    Long: 'number',
                },
                skipTypename: false,
                strictScalars: false,
                enumsAsTypes: true,
                avoidOptionals: {
                    field: false,
                    inputValue: false,
                    object: false,
                    defaultValue: false,
                },
                namingConvention: {
                    typeNames: 'pascal-case#pascalCase',
                    enumValues: 'upper-case#upperCase',
                },
                // Don't fail on unknown scalars
                onlyOperationTypes: false,
                // Allow empty operations
                emitLegacyCommonJSImports: false,
            },
        },
        // Introspection result
        [GENERATED_DIR + '/introspection.json']: {
            plugins: ['introspection'],
            config: {
                minify: false,
            },
        },
        // Schema AST
        [GENERATED_DIR + '/schema.graphql']: {
            plugins: ['schema-ast'],
        },
    },
    hooks: {
        afterAllFileWrite: ['prettier --write'],
    },
    overwrite: true,
    errorsOnly: false,
};

export default config;